/-
  Cairn/Optics/Chunk.lean - Optics for Chunk (no downstream dependencies)
-/

import Collimator
import Collimator.Derive.Lenses
import Collimator.Combinators
import Cairn.Core.Coords
import Cairn.Core.Block
import Cairn.World.Chunk

namespace Cairn.Optics

open Collimator
open Collimator.Derive
open Cairn.Core
open Cairn.World

-- Auto-generate lenses for Chunk
makeLenses Chunk

/-- Affine traversal for accessing a block at a local position within a chunk.
    Returns none if position is invalid or out of bounds. -/
def localBlockAt (pos : LocalPos) : AffineTraversal' Chunk Block :=
  Collimator.Combinators.affineFromPartial
    (fun chunk => if pos.isValid then chunk.blocks[pos.toIndex]? else none)
    (fun chunk block =>
      if pos.isValid && pos.toIndex < chunk.blocks.size then
        { chunk with blocks := chunk.blocks.set! pos.toIndex block }
      else chunk)

end Cairn.Optics
