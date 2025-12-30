/-
  Cairn/World/World.lean - World methods
-/

import Cairn.World.Types
import Cairn.World.Terrain
import Cairn.Optics
import Collimator

namespace Cairn.World

open Cairn.Core
open Cairn.Optics
open Collimator
open scoped Collimator.Operators

namespace World

/-- Create empty world -/
def empty (config : TerrainConfig := {}) (renderDist : Nat := 3) : World :=
  { chunks := {}
  , meshes := {}
  , terrainConfig := config
  , renderDistance := renderDist }

/-- Get block at world position -/
def getBlock (world : World) (pos : BlockPos) : Block :=
  let chunkPos := pos.toChunkPos
  let localPos := pos.toLocalPos
  (world ^? chunkAt chunkPos).map (·.getBlock localPos) |>.getD Block.air

/-- Callback for neighbor block lookup during mesh generation -/
def getNeighborBlock (world : World) (chunkPos : ChunkPos) (localPos : LocalPos) : Block :=
  (world ^? chunkAt chunkPos).map (·.getBlock localPos) |>.getD Block.air

/-- Load or generate a chunk -/
def ensureChunk (world : World) (pos : ChunkPos) : World :=
  if (world ^? chunkAt pos).isSome then world
  else
    let config := world ^. worldTerrainConfig
    let chunk := generateChunk config pos
    world & worldChunks %~ (·.insert pos chunk)

/-- Generate mesh for a chunk if dirty -/
def ensureMesh (world : World) (pos : ChunkPos) : World :=
  (world ^? chunkAt pos).map (fun chunk =>
    if !(chunk ^. chunkIsDirty) && (world ^? meshAt pos).isSome then world
    else
      let mesh := ChunkMesh.generate chunk (getNeighborBlock world)
      let updatedChunk := chunk & chunkIsDirty .~ false
      world
        & worldChunks %~ (·.insert pos updatedChunk)
        & worldMeshes %~ (·.insert pos mesh)
  ) |>.getD world

/-- Get chunk position from world block coordinates -/
def blockToChunkPos (x z : Int) : ChunkPos :=
  let floorDiv (a : Int) (b : Nat) : Int :=
    if a >= 0 then a / b else (a + 1) / b - 1
  { x := floorDiv x chunkSize, z := floorDiv z chunkSize }

/-- Load chunks around a position within render distance -/
def loadChunksAround (world : World) (centerX centerZ : Int) : World := Id.run do
  let mut w := world
  let center := blockToChunkPos centerX centerZ
  let renderDist := world ^. worldRenderDistance
  let rd : Int := renderDist

  for dxNat in [:renderDist * 2 + 1] do
    for dzNat in [:renderDist * 2 + 1] do
      let dx : Int := dxNat - rd
      let dz : Int := dzNat - rd
      let pos : ChunkPos := { x := center.x + dx, z := center.z + dz }
      w := w.ensureChunk pos
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
  let chunkPos := pos.toChunkPos
  let localPos := pos.toLocalPos
  (world ^? chunkAt chunkPos).map (fun chunk =>
    let newChunk := chunk.setBlock localPos block
    world & worldChunks %~ (·.insert chunkPos newChunk)
  ) |>.getD world

end World

end Cairn.World
