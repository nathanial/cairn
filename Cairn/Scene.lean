/-
  Cairn/Scene.lean - Scene module exports
-/

import Cairn.Scene.Camera
import Cairn.Scene.Modes

namespace Cairn

-- Re-export scene types and functions
export Scene (
  SceneMode
  OrbitCamera
  createSolidChunkWorld
  createSingleBlockWorld
  createTerrainPreviewWorld
  solidChunkOrbit
  singleBlockOrbit
  terrainPreviewOrbit
)

end Cairn
