/-
  Cairn/Optics.lean - Auto-generated optics for Cairn data structures
-/

import Collimator
import Collimator.Derive.Lenses
import Cairn.Core.Coords
import Cairn.Core.Block
import Cairn.World.Chunk
import Cairn.World.ChunkMesh
import Cairn.World.Terrain
import Cairn.World.Types

namespace Cairn.Optics

open Collimator
open Collimator.Derive
open Cairn.Core
open Cairn.World

-- Auto-generate lenses for all structures
makeLenses ChunkPos
makeLenses LocalPos
makeLenses BlockPos
makeLenses Chunk
makeLenses ChunkMesh
makeLenses TerrainConfig
makeLenses World

-- Prisms for Block variants
def _stone : Prism' Block Unit := ctorPrism% Block.stone
def _dirt : Prism' Block Unit := ctorPrism% Block.dirt
def _grass : Prism' Block Unit := ctorPrism% Block.grass
def _water : Prism' Block Unit := ctorPrism% Block.water
def _sand : Prism' Block Unit := ctorPrism% Block.sand
def _wood : Prism' Block Unit := ctorPrism% Block.wood
def _leaves : Prism' Block Unit := ctorPrism% Block.leaves
def _air : Prism' Block Unit := ctorPrism% Block.air

end Cairn.Optics
