/-
  Cairn/World/World.lean - World methods
-/

import Cairn.World.Types
import Cairn.World.Terrain
import Cairn.Optics
import Cairn.Render.MeshGen
import Collimator

namespace Cairn.World

open Cairn.Core
open Cairn.Optics
open Cairn.Render
open Collimator
open scoped Collimator.Operators

namespace World

/-- Create empty world with async loading state -/
def create (config : TerrainConfig := {}) (renderDist : Nat := 3) : IO World := do
  return {
    chunks := {}
    meshes := {}
    terrainConfig := config
    renderDistance := renderDist
  }

/-- Create empty world. Alias for `create` for backward compatibility. -/
def empty (config : TerrainConfig := {}) (renderDist : Nat := 3) : IO World :=
  create config renderDist

/-- Get block at world position -/
def getBlock (world : World) (pos : BlockPos) : Block :=
  world ^?? blockAt pos | Block.air

/-- Mark a chunk dirty if it exists in the world. -/
private def markChunkDirty (world : World) (pos : ChunkPos) : World :=
  world & chunkAt pos ∘ chunkIsDirty .~ true

/-- Cardinal neighbors of a chunk (N/S/E/W). -/
private def neighborChunkPositions (pos : ChunkPos) : Array ChunkPos :=
  #[
    { x := pos.x + 1, z := pos.z }
  , { x := pos.x - 1, z := pos.z }
  , { x := pos.x, z := pos.z + 1 }
  , { x := pos.x, z := pos.z - 1 }
  ]

/-- Mark neighbor chunks dirty to refresh meshes when boundaries change. -/
private def markNeighborChunksDirty (world : World) (pos : ChunkPos) : World :=
  (neighborChunkPositions pos).foldl markChunkDirty world

/-- Neighbor chunks affected by a block edit at the given position. -/
private def neighborChunksForBlock (pos : BlockPos) : Array ChunkPos := Id.run do
  let localPos := pos.toLocalPos
  let base := pos.toChunkPos
  let mut neighbors : Array ChunkPos := #[]
  if localPos.x == 0 then
    neighbors := neighbors.push { x := base.x - 1, z := base.z }
  if localPos.x == chunkSize - 1 then
    neighbors := neighbors.push { x := base.x + 1, z := base.z }
  if localPos.z == 0 then
    neighbors := neighbors.push { x := base.x, z := base.z - 1 }
  if localPos.z == chunkSize - 1 then
    neighbors := neighbors.push { x := base.x, z := base.z + 1 }
  return neighbors

/-- Load or generate a chunk -/
def ensureChunk (world : World) (pos : ChunkPos) : World :=
  if (world ^? chunkAt pos).isSome then world
  else
    let config := world ^. worldTerrainConfig
    let chunk := generateChunk config pos
    let world := world & worldChunks %~ (·.insert pos chunk)
    markNeighborChunksDirty world pos

/-- Generate mesh for a chunk if dirty -/
def ensureMesh (world : World) (pos : ChunkPos) : World :=
  match world ^? chunkAt pos ∘ chunkIsDirty with
  | some true =>
    let mesh := generateMesh world pos
    world
      & chunkAt pos ∘ chunkIsDirty .~ false
      & worldMeshes %~ (·.insert pos mesh)
  | some false => if (world ^? meshAt pos).isSome then world
                  else world & worldMeshes %~ (·.insert pos (generateMesh world pos))
  | none => world

/-- Get chunk position from world block coordinates -/
def blockToChunkPos (x z : Int) : ChunkPos :=
  { x := x / chunkSize, z := z / chunkSize }

/-- Load chunks around a position within render distance -/
def loadChunksAround (world : World) (centerX centerZ : Int) : World := Id.run do
  let mut w := world
  let center := blockToChunkPos centerX centerZ
  let renderDist := world ^. worldRenderDistance
  let rd : Int := renderDist

  -- Pass 1: Load all chunks first (so neighbors exist for mesh generation)
  for dxNat in [:renderDist * 2 + 1] do
    for dzNat in [:renderDist * 2 + 1] do
      let dx : Int := dxNat - rd
      let dz : Int := dzNat - rd
      let pos : ChunkPos := { x := center.x + dx, z := center.z + dz }
      w := w.ensureChunk pos

  -- Pass 2: Generate meshes (all neighbors now loaded)
  for dxNat in [:renderDist * 2 + 1] do
    for dzNat in [:renderDist * 2 + 1] do
      let dx : Int := dxNat - rd
      let dz : Int := dzNat - rd
      let pos : ChunkPos := { x := center.x + dx, z := center.z + dz }
      w := w.ensureMesh pos

  return w

/-- Get all meshes for rendering -/
def getMeshes (world : World) : List (ChunkPos × ChunkMesh) :=
  (world ^. worldMeshes).toList

/-- Get number of loaded chunks -/
def chunkCount (world : World) : Nat :=
  (world ^. worldChunks).size

/-- Get number of cached meshes -/
def meshCount (world : World) : Nat :=
  (world ^. worldMeshes).size

/-- Unload chunks outside render distance -/
def unloadDistantChunks (world : World) (centerX centerZ : Int) : World :=
  let center := blockToChunkPos centerX centerZ
  let renderDist := world ^. worldRenderDistance
  let isNear (pos : ChunkPos) : Bool :=
    (pos.x - center.x).natAbs <= renderDist &&
    (pos.z - center.z).natAbs <= renderDist

  world
    & worldChunks %~ (·.filter (fun pos _ => isNear pos))
    & worldMeshes %~ (·.filter (fun pos _ => isNear pos))

/-- Set block at world position (marks chunk dirty) -/
def setBlock (world : World) (pos : BlockPos) (block : Block) : World :=
  let world := world & blockAt pos .~ block
                    & chunkAt pos.toChunkPos ∘ chunkIsDirty .~ true
  (neighborChunksForBlock pos).foldl markChunkDirty world

/-- Generate meshes for loaded chunks around position (synchronous) -/
def ensureMeshesAround (world : World) (centerX centerZ : Int) : World := Id.run do
  let center := blockToChunkPos centerX centerZ
  let renderDist := world ^. worldRenderDistance
  let rd : Int := renderDist
  let mut w := world
  for dxNat in [:renderDist * 2 + 1] do
    for dzNat in [:renderDist * 2 + 1] do
      let dx : Int := dxNat - rd
      let dz : Int := dzNat - rd
      let pos : ChunkPos := { x := center.x + dx, z := center.z + dz }
      w := w.ensureMesh pos
  return w

/-! ## Mesh Generation Helpers -/

/-- Build chunk neighborhood snapshot for mesh generation -/
def getChunkNeighborhood (world : World) (pos : ChunkPos) : Option ChunkNeighborhood :=
  match world ^? chunkAt pos with
  | some center =>
    some {
      center
      north := world ^? chunkAt { pos with z := pos.z + 1 }
      south := world ^? chunkAt { pos with z := pos.z - 1 }
      east := world ^? chunkAt { pos with x := pos.x + 1 }
      west := world ^? chunkAt { pos with x := pos.x - 1 }
    }
  | none => none

/-! ## Async Integration Helpers -/

/-- Integrate a generated chunk into the world and mark neighbors dirty. -/
def integratePendingChunk (world : World) (pending : PendingChunk) : World :=
  let world := world & worldChunks %~ (·.insert pending.pos pending.chunk)
  markNeighborChunksDirty world pending.pos

/-- Integrate a generated mesh into the world and clear dirty flag. -/
def integratePendingMesh (world : World) (pending : PendingMesh) : World :=
  world
    & worldMeshes %~ (·.insert pending.pos pending.mesh)
    & chunkAt pending.pos ∘ chunkIsDirty .~ false

end World

end Cairn.World
