/-
  Cairn/World/World.lean - World manager for chunk loading and rendering
-/

import Cairn.Core.Coords
import Cairn.World.Chunk
import Cairn.World.ChunkMesh
import Cairn.World.Terrain
import Batteries.Lean.HashMap

namespace Cairn.World

open Cairn.Core

/-- World state managing all chunks -/
structure World where
  chunks : Std.HashMap ChunkPos Chunk
  meshes : Std.HashMap ChunkPos ChunkMesh
  terrainConfig : TerrainConfig
  renderDistance : Nat  -- Chunks to render in each direction
  deriving Inhabited

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
  match world.chunks[chunkPos]? with
  | some chunk => chunk.getBlock localPos
  | none => Block.air

/-- Callback for neighbor block lookup during mesh generation -/
def getNeighborBlock (world : World) (chunkPos : ChunkPos) (localPos : LocalPos) : Block :=
  match world.chunks[chunkPos]? with
  | some chunk => chunk.getBlock localPos
  | none => Block.air

/-- Load or generate a chunk -/
def ensureChunk (world : World) (pos : ChunkPos) : World :=
  if world.chunks.contains pos then world
  else
    let chunk := generateChunk world.terrainConfig pos
    { world with chunks := world.chunks.insert pos chunk }

/-- Generate mesh for a chunk if dirty -/
def ensureMesh (world : World) (pos : ChunkPos) : World :=
  match world.chunks[pos]? with
  | none => world
  | some chunk =>
    if !chunk.isDirty && world.meshes.contains pos then world
    else
      let mesh := ChunkMesh.generate chunk (getNeighborBlock world)
      let updatedChunk := chunk.markClean
      { world with
        chunks := world.chunks.insert pos updatedChunk
        meshes := world.meshes.insert pos mesh }

/-- Get chunk position from world block coordinates -/
def blockToChunkPos (x z : Int) : ChunkPos :=
  let floorDiv (a : Int) (b : Nat) : Int :=
    if a >= 0 then a / b else (a + 1) / b - 1
  { x := floorDiv x chunkSize, z := floorDiv z chunkSize }

/-- Load chunks around a position within render distance -/
def loadChunksAround (world : World) (centerX centerZ : Int) : World := Id.run do
  let mut w := world
  let center := blockToChunkPos centerX centerZ
  let rd : Int := world.renderDistance

  for dxNat in [:world.renderDistance * 2 + 1] do
    for dzNat in [:world.renderDistance * 2 + 1] do
      let dx : Int := dxNat - rd
      let dz : Int := dzNat - rd
      let pos : ChunkPos := { x := center.x + dx, z := center.z + dz }
      w := w.ensureChunk pos
      w := w.ensureMesh pos

  return w

/-- Get all meshes for rendering -/
def getMeshes (world : World) : List (ChunkPos × ChunkMesh) :=
  world.meshes.toList

/-- Get number of loaded chunks -/
def chunkCount (world : World) : Nat :=
  world.chunks.size

/-- Get number of cached meshes -/
def meshCount (world : World) : Nat :=
  world.meshes.size

/-- Unload chunks outside render distance -/
def unloadDistantChunks (world : World) (centerX centerZ : Int) : World :=
  let center := blockToChunkPos centerX centerZ
  let isNear (pos : ChunkPos) : Bool :=
    (pos.x - center.x).natAbs ≤ world.renderDistance &&
    (pos.z - center.z).natAbs ≤ world.renderDistance

  let chunks := world.chunks.filter (fun pos _ => isNear pos)
  let meshes := world.meshes.filter (fun pos _ => isNear pos)
  { world with chunks := chunks, meshes := meshes }

/-- Set block at world position (marks chunk dirty) -/
def setBlock (world : World) (pos : BlockPos) (block : Block) : World :=
  let chunkPos := pos.toChunkPos
  let localPos := pos.toLocalPos
  match world.chunks[chunkPos]? with
  | some chunk =>
    let newChunk := chunk.setBlock localPos block
    { world with chunks := world.chunks.insert chunkPos newChunk }
  | none => world  -- Chunk not loaded, ignore

end World

end Cairn.World
