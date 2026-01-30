/-
  Cairn/Widget/Update.lean - State update logic for voxel scene widget
-/

import Afferent.FFI.Window
import Cairn.Widget.Core
import Cairn.Input.Keys

namespace Cairn.Widget

open Afferent.FFI
open Cairn.World
open Cairn.Input

/-- Update voxel scene state based on keyboard input (fly mode only).
    Uses direct FFI.Window calls for input polling. -/
def updateVoxelSceneState (window : Window) (state : VoxelSceneState)
    (dt : Float) : IO VoxelSceneState := do
  -- Read keyboard state
  let wDown ← Window.isKeyDown window Keys.w
  let aDown ← Window.isKeyDown window Keys.a
  let sDown ← Window.isKeyDown window Keys.s
  let dDown ← Window.isKeyDown window Keys.d
  let qDown ← Window.isKeyDown window Keys.q
  let eDown ← Window.isKeyDown window Keys.e

  -- Read mouse delta if pointer is locked
  let locked ← Window.getPointerLock window
  let (dx, dy) ←
    if locked then Window.getMouseDelta window
    else pure (0.0, 0.0)

  -- Update camera (fly mode: WASD for horizontal, Q/E for vertical)
  let camera := state.camera.update dt wDown sDown aDown dDown eDown qDown dx dy

  -- Update chunks based on new camera position
  let playerX := camera.x.floor.toInt64.toInt
  let playerZ := camera.z.floor.toInt64.toInt

  -- Request new chunks (spawns background terrain gen tasks)
  state.world.requestChunksAround playerX playerZ

  -- Integrate completed chunks from background tasks
  let world ← state.world.pollPendingChunks

  -- Request mesh generation (spawns background mesh gen tasks)
  world.requestMeshesAround playerX playerZ

  -- Integrate completed meshes from background tasks
  let world ← world.pollPendingMeshes

  pure { state with camera, world }

/-- Update voxel scene state with custom input state.
    Useful when input is captured elsewhere. -/
def updateVoxelSceneStateWithInput (state : VoxelSceneState)
    (forward back left right up down : Bool)
    (mouseDeltaX mouseDeltaY : Float)
    (dt : Float) : IO VoxelSceneState := do
  -- Update camera
  let camera := state.camera.update dt forward back left right up down mouseDeltaX mouseDeltaY

  -- Update chunks based on new camera position
  let playerX := camera.x.floor.toInt64.toInt
  let playerZ := camera.z.floor.toInt64.toInt

  -- Request and poll chunks
  state.world.requestChunksAround playerX playerZ
  let world ← state.world.pollPendingChunks
  world.requestMeshesAround playerX playerZ
  let world ← world.pollPendingMeshes

  pure { state with camera, world }

/-- Poll world updates without changing camera position.
    Useful when camera is updated externally. -/
def pollWorldUpdates (state : VoxelSceneState) : IO VoxelSceneState := do
  let playerX := state.camera.x.floor.toInt64.toInt
  let playerZ := state.camera.z.floor.toInt64.toInt

  state.world.requestChunksAround playerX playerZ
  let world ← state.world.pollPendingChunks
  world.requestMeshesAround playerX playerZ
  let world ← world.pollPendingMeshes

  pure { state with world }

end Cairn.Widget
