/-
  Cairn/Widget/Core.lean - Core types and state for voxel scene widget
-/

import Afferent.Render.FPSCamera
import Cairn.World.Types
import Cairn.World.World
import Cairn.Camera
import Linalg

namespace Cairn.Widget

open Afferent.Render
open Cairn.World
open Cairn.Camera
open Linalg

/-- Configuration for voxel scene rendering -/
structure VoxelSceneConfig where
  /-- Vertical field of view in radians -/
  fovY : Float := Float.pi / 3.0
  /-- Near clipping plane distance -/
  nearPlane : Float := 0.1
  /-- Far clipping plane distance -/
  farPlane : Float := 500.0
  /-- Light direction (normalized) -/
  lightDir : Array Float := #[0.5, 0.8, 0.3]
  /-- Ambient light intensity -/
  ambient : Float := 0.4
  /-- Fog color (sky blue by default) -/
  fogColor : Array Float := #[0.5, 0.7, 1.0]
  /-- Fog start distance (0 to disable) -/
  fogStart : Float := 0.0
  /-- Fog end distance (0 to disable) -/
  fogEnd : Float := 0.0
  deriving Repr, Inhabited

namespace VoxelSceneConfig

/-- Default configuration using Cairn.Camera constants -/
def default : VoxelSceneConfig := {
  fovY := Cairn.Camera.fovY
  nearPlane := Cairn.Camera.nearPlane
  farPlane := Cairn.Camera.farPlane
}

end VoxelSceneConfig

/-- State for the voxel scene widget -/
structure VoxelSceneState where
  /-- FPS camera for view/movement -/
  camera : FPSCamera
  /-- Voxel world data -/
  world : World
  /-- Whether fly mode is enabled (no gravity) -/
  flyMode : Bool := true

namespace VoxelSceneState

/-- Create initial voxel scene state -/
def create (config : TerrainConfig) (renderDistance : Nat := 2) (startY : Float := 60.0) : IO VoxelSceneState := do
  let world ← World.create config renderDistance
  return {
    camera := { defaultCamera with y := startY }
    world
  }

end VoxelSceneState

end Cairn.Widget
