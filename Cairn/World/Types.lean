/-
  Cairn/World/Types.lean - World type definition (separate to avoid circular imports)
-/

import Cairn.Core.Coords
import Cairn.World.Chunk
import Cairn.World.ChunkMesh
import Cairn.World.Terrain
import Batteries.Lean.HashMap

namespace Cairn.World

open Cairn.Core

/-- World state managing all chunks -/
structure World where
  chunks : Std.HashMap ChunkPos Chunk
  meshes : Std.HashMap ChunkPos ChunkMesh
  terrainConfig : TerrainConfig
  renderDistance : Nat
  deriving Inhabited

end Cairn.World
