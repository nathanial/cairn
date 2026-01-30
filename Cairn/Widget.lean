/-
  Cairn/Widget.lean - Canopy widget for rendering voxel scenes
-/

import Cairn.Widget.Core
import Cairn.Widget.Render
import Cairn.Widget.Update
import Cairn.Widget.Visual

namespace Cairn

-- Re-export main types and functions
export Widget (
  VoxelSceneConfig
  VoxelSceneState
  renderVoxelScene
  renderVoxelSceneWithHighlight
  updateVoxelSceneState
  updateVoxelSceneStateWithInput
  pollWorldUpdates
  voxelSceneWidget
  voxelSceneWidgetWithHighlight
  voxelSceneWidgetStyled
)

end Cairn
