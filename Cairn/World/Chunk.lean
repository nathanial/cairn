/-
  Cairn/World/Chunk.lean - Chunk methods
-/

import Cairn.World.Types

namespace Cairn.World

open Cairn.Core

namespace Chunk

/-- Create an empty chunk (all air) -/
def empty (pos : ChunkPos) : Chunk :=
  { pos := pos
  , blocks := Array.replicate blocksPerChunk Block.air
  , isDirty := true }

/-- Check if chunk has any non-air blocks -/
def isEmpty (chunk : Chunk) : Bool :=
  chunk.blocks.all (· == Block.air)

/-- Fill a region with a block type -/
def fillRegion (chunk : Chunk) (minPos maxPos : LocalPos) (block : Block) : Chunk := Id.run do
  let mut blocks := chunk.blocks
  for y in [minPos.y : maxPos.y + 1] do
    for z in [minPos.z : maxPos.z + 1] do
      for x in [minPos.x : maxPos.x + 1] do
        let pos : LocalPos := { x := x, y := y, z := z }
        if pos.isValid && pos.toIndex < blocks.size then
          blocks := blocks.set! pos.toIndex block
  return { chunk with blocks := blocks, isDirty := true }

/-- Count non-air blocks in chunk -/
def blockCount (chunk : Chunk) : Nat :=
  chunk.blocks.foldl (fun acc b => if b != Block.air then acc + 1 else acc) 0

end Chunk

end Cairn.World
