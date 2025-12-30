/-
  Cairn/Core/Coords.lean - Coordinate types for chunk-based voxel world
-/

namespace Cairn.Core

/-- Size of a chunk in blocks (horizontal) -/
def chunkSize : Nat := 16

/-- Height of a chunk in blocks (vertical) -/
def chunkHeight : Nat := 128

/-- Chunk position in chunk coordinates (each unit = 16 blocks) -/
structure ChunkPos where
  x : Int
  z : Int
  deriving Repr, BEq, Hashable, Inhabited

/-- Local position within a chunk (0-15 for x/z, 0-127 for y) -/
structure LocalPos where
  x : Nat
  y : Nat
  z : Nat
  deriving Repr, BEq, Inhabited

/-- World position in block coordinates -/
structure BlockPos where
  x : Int
  y : Int
  z : Int
  deriving Repr, BEq, Inhabited

namespace ChunkPos

def origin : ChunkPos := { x := 0, z := 0 }

def add (a b : ChunkPos) : ChunkPos :=
  { x := a.x + b.x, z := a.z + b.z }

def sub (a b : ChunkPos) : ChunkPos :=
  { x := a.x - b.x, z := a.z - b.z }

instance : Add ChunkPos := ⟨add⟩
instance : Sub ChunkPos := ⟨sub⟩

end ChunkPos

namespace LocalPos

def origin : LocalPos := { x := 0, y := 0, z := 0 }

/-- Convert to flat array index (x + z*16 + y*256) -/
def toIndex (pos : LocalPos) : Nat :=
  pos.x + pos.z * chunkSize + pos.y * chunkSize * chunkSize

/-- Check if position is within valid chunk bounds -/
def isValid (pos : LocalPos) : Bool :=
  pos.x < chunkSize && pos.y < chunkHeight && pos.z < chunkSize

end LocalPos

namespace BlockPos

def origin : BlockPos := { x := 0, y := 0, z := 0 }

/-- Floor division that handles negative numbers correctly -/
private def floorDiv (a : Int) (b : Nat) : Int :=
  if a >= 0 then a / b
  else (a + 1) / b - 1

/-- Modulo that always returns positive result -/
private def posMod (a : Int) (b : Nat) : Nat :=
  ((a % b) + b).toNat % b

/-- Convert world block position to chunk position -/
def toChunkPos (pos : BlockPos) : ChunkPos :=
  { x := floorDiv pos.x chunkSize
  , z := floorDiv pos.z chunkSize }

/-- Convert world block position to local position within its chunk -/
def toLocalPos (pos : BlockPos) : LocalPos :=
  { x := posMod pos.x chunkSize
  , y := pos.y.toNat  -- Y is always positive
  , z := posMod pos.z chunkSize }

/-- Decompose into chunk and local position -/
def decompose (pos : BlockPos) : ChunkPos × LocalPos :=
  (pos.toChunkPos, pos.toLocalPos)

end BlockPos

/-- Convert chunk + local position to world block position -/
def toBlockPos (chunk : ChunkPos) (local_ : LocalPos) : BlockPos :=
  { x := chunk.x * chunkSize + local_.x
  , y := local_.y
  , z := chunk.z * chunkSize + local_.z }

/-- Convert flat array index to local position -/
def indexToLocal (idx : Nat) : LocalPos :=
  let y := idx / (chunkSize * chunkSize)
  let remainder := idx % (chunkSize * chunkSize)
  let z := remainder / chunkSize
  let x := remainder % chunkSize
  { x := x, y := y, z := z }

end Cairn.Core
