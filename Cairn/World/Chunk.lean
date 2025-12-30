/-
  Cairn/World/Chunk.lean - Chunk data structure for voxel storage
-/

import Cairn.Core.Block
import Cairn.Core.Coords

namespace Cairn.World

open Cairn.Core

/-- Total blocks in a chunk -/
def blocksPerChunk : Nat := chunkSize * chunkHeight * chunkSize

/-- A chunk of voxel data -/
structure Chunk where
  pos : ChunkPos
  blocks : Array Block  -- Flat array, size = blocksPerChunk
  isDirty : Bool        -- Needs mesh rebuild
  deriving Inhabited

namespace Chunk

/-- Create an empty chunk (all air) -/
def empty (pos : ChunkPos) : Chunk :=
  { pos := pos
  , blocks := Array.replicate blocksPerChunk Block.air
  , isDirty := true }

/-- Get block at local position (returns air if out of bounds) -/
def getBlock (chunk : Chunk) (pos : LocalPos) : Block :=
  if pos.isValid then
    chunk.blocks.getD pos.toIndex Block.air
  else
    Block.air

/-- Set block at local position -/
def setBlock (chunk : Chunk) (pos : LocalPos) (block : Block) : Chunk :=
  if pos.isValid then
    { chunk with
      blocks := chunk.blocks.set! pos.toIndex block
      isDirty := true }
  else
    chunk

/-- Check if chunk has any non-air blocks -/
def isEmpty (chunk : Chunk) : Bool :=
  chunk.blocks.all (· == Block.air)

/-- Mark chunk as needing mesh rebuild -/
def markDirty (chunk : Chunk) : Chunk :=
  { chunk with isDirty := true }

/-- Mark chunk as clean (mesh is up to date) -/
def markClean (chunk : Chunk) : Chunk :=
  { chunk with isDirty := false }

/-- Fill a region with a block type -/
def fillRegion (chunk : Chunk) (minPos maxPos : LocalPos) (block : Block) : Chunk := Id.run do
  let mut c := chunk
  for y in [minPos.y : maxPos.y + 1] do
    for z in [minPos.z : maxPos.z + 1] do
      for x in [minPos.x : maxPos.x + 1] do
        c := c.setBlock { x := x, y := y, z := z } block
  return c

/-- Count non-air blocks in chunk -/
def blockCount (chunk : Chunk) : Nat :=
  chunk.blocks.foldl (fun acc b => if b != Block.air then acc + 1 else acc) 0

end Chunk

end Cairn.World
