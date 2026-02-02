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
  let pendingChunks ← IO.mkRef #[]
  let loadingChunks ← IO.mkRef {}
  let pendingMeshes ← IO.mkRef #[]
  let meshingChunks ← IO.mkRef {}
  return {
    chunks := {}
    meshes := {}
    terrainConfig := config
    renderDistance := renderDist
    pendingChunks
    loadingChunks
    pendingMeshes
    meshingChunks
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

/-! ## Async Chunk Loading -/

/-- Request chunk generation (non-blocking). Spawns a background task. -/
def requestChunk (world : World) (pos : ChunkPos) : IO Unit := do
  -- Skip if already loaded
  if (world ^? chunkAt pos).isSome then return

  -- Skip if already in-flight
  let loading ← world.loadingChunks.get
  if loading.contains pos then return

  -- Mark as loading
  world.loadingChunks.modify (·.insert pos)

  -- Spawn background task
  let config := world ^. worldTerrainConfig
  let pendingRef := world.pendingChunks
  let loadingRef := world.loadingChunks
  let _ ← IO.asTask (prio := .dedicated) do
    let chunk := generateChunk config pos
    pendingRef.modify (·.push { pos, chunk })
    loadingRef.modify (·.erase pos)

/-- Poll completed chunks and integrate them into World. Call once per frame. -/
def pollPendingChunks (world : World) : IO World := do
  let pending ← world.pendingChunks.modifyGet fun arr => (arr, #[])
  let mut w := world
  for p in pending do
    w := w & worldChunks %~ (·.insert p.pos p.chunk)
    w := markNeighborChunksDirty w p.pos
  return w

/-- Request chunks around position (non-blocking) -/
def requestChunksAround (world : World) (centerX centerZ : Int) : IO Unit := do
  let center := blockToChunkPos centerX centerZ
  let renderDist := world ^. worldRenderDistance
  let rd : Int := renderDist
  for dxNat in [:renderDist * 2 + 1] do
    for dzNat in [:renderDist * 2 + 1] do
      let dx : Int := dxNat - rd
      let dz : Int := dzNat - rd
      let pos : ChunkPos := { x := center.x + dx, z := center.z + dz }
      requestChunk world pos

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

/-! ## Async Mesh Generation -/

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

/-- Request mesh generation (non-blocking). Spawns a background task. -/
def requestMesh (world : World) (pos : ChunkPos) : IO Unit := do
  -- Skip if chunk not loaded or not dirty
  match world ^? chunkAt pos ∘ chunkIsDirty with
  | some true => pure ()  -- Continue
  | some false =>
    -- Not dirty - skip unless no mesh exists
    if (world ^? meshAt pos).isSome then return
  | none => return  -- Chunk not loaded

  -- Skip if already being meshed
  let meshing ← world.meshingChunks.get
  if meshing.contains pos then return

  -- Get neighborhood snapshot
  match getChunkNeighborhood world pos with
  | some hood =>
    -- Mark as meshing
    world.meshingChunks.modify (·.insert pos)

    -- Spawn background task
    let pendingRef := world.pendingMeshes
    let meshingRef := world.meshingChunks
    let _ ← IO.asTask (prio := .dedicated) do
      let mesh := generateMeshFromNeighborhood hood
      pendingRef.modify (·.push { pos, mesh })
      meshingRef.modify (·.erase pos)
  | none => return

/-- Poll completed meshes and integrate them into World. Call once per frame. -/
def pollPendingMeshes (world : World) : IO World := do
  let pending ← world.pendingMeshes.modifyGet fun arr => (arr, #[])
  let mut w := world
  for p in pending do
    w := w & worldMeshes %~ (·.insert p.pos p.mesh)
    -- Clear dirty flag
    w := w & chunkAt p.pos ∘ chunkIsDirty .~ false
  return w

/-- Request mesh generation for chunks around position (non-blocking) -/
def requestMeshesAround (world : World) (centerX centerZ : Int) : IO Unit := do
  let center := blockToChunkPos centerX centerZ
  let renderDist := world ^. worldRenderDistance
  let rd : Int := renderDist
  for dxNat in [:renderDist * 2 + 1] do
    for dzNat in [:renderDist * 2 + 1] do
      let dx : Int := dxNat - rd
      let dz : Int := dzNat - rd
      let pos : ChunkPos := { x := center.x + dx, z := center.z + dz }
      requestMesh world pos

end World

end Cairn.World
