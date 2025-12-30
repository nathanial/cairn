/-
  Cairn/World/ChunkMesh.lean - Chunk mesh data structure
-/

namespace Cairn.World

/-- Chunk mesh data ready for GPU -/
structure ChunkMesh where
  vertices : Array Float   -- 10 floats per vertex: x,y,z, nx,ny,nz, r,g,b,a
  indices : Array UInt32
  vertexCount : Nat
  indexCount : Nat
  deriving Inhabited

namespace ChunkMesh

/-- Empty mesh -/
def empty : ChunkMesh :=
  { vertices := #[]
  , indices := #[]
  , vertexCount := 0
  , indexCount := 0 }

/-- Check if mesh is empty -/
def isEmpty (mesh : ChunkMesh) : Bool :=
  mesh.indexCount == 0

end ChunkMesh

end Cairn.World
