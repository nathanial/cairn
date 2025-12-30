/-
  Cairn/Core/Block.lean - Block type definitions
-/

import Cairn.Core.Face

namespace Cairn.Core

/-- Block types in the voxel world -/
inductive Block where
  | air
  | stone
  | dirt
  | grass
  | sand
  | water
  | wood
  | leaves
  deriving Repr, BEq, Inhabited

/-- Check if a block is solid (can be collided with) -/
def Block.isSolid : Block → Bool
  | .air => false
  | .water => false
  | _ => true

/-- Check if a block is transparent (light passes through) -/
def Block.isTransparent : Block → Bool
  | .air => true
  | .water => true
  | .leaves => true
  | _ => false

/-- Get the default color for a block (r, g, b, a) -/
def Block.color : Block → Float × Float × Float × Float
  | .air => (0.0, 0.0, 0.0, 0.0)
  | .stone => (0.5, 0.5, 0.5, 1.0)
  | .dirt => (0.55, 0.35, 0.2, 1.0)
  | .grass => (0.3, 0.7, 0.2, 1.0)
  | .sand => (0.9, 0.85, 0.6, 1.0)
  | .water => (0.2, 0.4, 0.8, 0.7)
  | .wood => (0.55, 0.35, 0.15, 1.0)
  | .leaves => (0.2, 0.6, 0.2, 0.9)

/-- Get face-specific color for a block (r, g, b, a) -/
def Block.faceColor : Block → Face → Float × Float × Float × Float
  -- Grass: green top, dirt/brown sides and bottom (like Minecraft)
  | .grass, .top    => (0.3, 0.7, 0.2, 1.0)
  | .grass, _       => (0.55, 0.35, 0.2, 1.0)
  -- Wood: light cut ends, bark sides
  | .wood, .top     => (0.65, 0.5, 0.3, 1.0)
  | .wood, .bottom  => (0.65, 0.5, 0.3, 1.0)
  | .wood, _        => (0.45, 0.3, 0.15, 1.0)
  -- All other blocks: same color for all faces
  | block, _        => block.color

end Cairn.Core
