/-
  Cairn/Optics/Coords.lean - Optics for coordinate types
-/

import Collimator
import Collimator.Derive.Lenses
import Cairn.Core.Coords

namespace Cairn.Optics

open Collimator.Derive
open Cairn.Core

makeLenses ChunkPos
makeLenses LocalPos
makeLenses WorldPos
makeLenses BlockPos

open Collimator
open scoped Collimator.Operators

-- Composed lenses for WorldPos → inner coordinates
def wpChunkX : Lens' WorldPos Int := worldPosChunk ∘ chunkPosX
def wpChunkZ : Lens' WorldPos Int := worldPosChunk ∘ chunkPosZ
def wpLocalX : Lens' WorldPos Nat := worldPosLocalPos ∘ localPosX
def wpLocalY : Lens' WorldPos Nat := worldPosLocalPos ∘ localPosY
def wpLocalZ : Lens' WorldPos Nat := worldPosLocalPos ∘ localPosZ

end Cairn.Optics
