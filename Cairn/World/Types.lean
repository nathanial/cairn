/-
  Cairn/World/Types.lean - All world-related type definitions
-/

import Cairn.Core.Block
import Cairn.Core.Coords
import Cairn.Core.Face
import Batteries.Lean.HashMap
import Linalg

namespace Cairn.World

open Cairn.Core
open Linalg

/-- Total blocks in a chunk -/
def blocksPerChunk : Nat := chunkSize * chunkHeight * chunkSize

/-- A chunk of voxel data -/
structure Chunk where
  pos : ChunkPos
  blocks : Array Block  -- Flat array, size = blocksPerChunk
  isDirty : Bool        -- Needs mesh rebuild
  deriving Inhabited

/-- Chunk mesh data ready for GPU -/
structure ChunkMesh where
  vertices : Array Float   -- 10 floats per vertex: x,y,z, nx,ny,nz, r,g,b,a
  indices : Array UInt32
  vertexCount : Nat
  indexCount : Nat
  deriving Inhabited

/-- Terrain generation configuration -/
structure TerrainConfig where
  seed : UInt64 := 12345
  seaLevel : Nat := 32
  baseHeight : Nat := 45
  heightScale : Float := 25.0
  noiseScale : Float := 0.015  -- Lower = larger features
  caveThreshold : Float := 0.45
  caveScale : Float := 0.05
  deriving Repr, Inhabited

/-- Result of a successful voxel raycast -/
structure RaycastHit where
  blockPos : BlockPos    -- Which block was hit
  face : Face            -- Which face of the block was hit
  point : Vec3           -- Exact hit point in world space
  distance : Float       -- Distance from ray origin
  deriving Repr, BEq

/-- A chunk that has been generated but not yet integrated into World -/
structure PendingChunk where
  pos : ChunkPos
  chunk : Chunk

/-- A mesh that has been generated but not yet integrated into World -/
structure PendingMesh where
  pos : ChunkPos
  mesh : ChunkMesh

/-- Snapshot of a chunk and its neighbors for background mesh generation -/
structure ChunkNeighborhood where
  center : Chunk
  north : Option Chunk   -- +Z
  south : Option Chunk   -- -Z
  east : Option Chunk    -- +X
  west : Option Chunk    -- -X

/-- World state managing all chunks -/
structure World where
  chunks : Std.HashMap ChunkPos Chunk
  meshes : Std.HashMap ChunkPos ChunkMesh
  terrainConfig : TerrainConfig
  renderDistance : Nat
  -- Async loading handled via FRP WorkerPool

end Cairn.World
