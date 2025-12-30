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
makeLenses BlockPos

end Cairn.Optics
