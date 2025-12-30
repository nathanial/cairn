/-
  Cairn/Core/Face.lean - Block face direction
-/

namespace Cairn.Core

/-- Face direction for rendering and culling -/
inductive Face where
  | top     -- +Y
  | bottom  -- -Y
  | north   -- +Z
  | south   -- -Z
  | east    -- +X
  | west    -- -X
  deriving Repr, BEq

/-- All six faces -/
def Face.all : Array Face := #[.top, .bottom, .north, .south, .east, .west]

end Cairn.Core
