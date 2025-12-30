/-
  Cairn/World/ChunkMesh.lean - Chunk mesh methods
-/

import Cairn.World.Types

namespace Cairn.World

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
