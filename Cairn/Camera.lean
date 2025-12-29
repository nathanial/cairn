/-
  Cairn/Camera.lean - Camera configuration and helpers
-/

import Afferent.Render.FPSCamera
import Linalg

namespace Cairn.Camera

open Afferent.Render Linalg

/-- Default camera settings for the voxel game -/
def defaultCamera : FPSCamera := {
  x := 0.0
  y := 5.0   -- Start above ground
  z := 10.0  -- Start back from origin
  yaw := 0.0
  pitch := 0.0
  moveSpeed := 8.0       -- Blocks per second
  lookSensitivity := 0.002
}

/-- Camera configuration constants -/
def fovY : Float := Float.pi / 3.0  -- 60 degrees
def nearPlane : Float := 0.1
def farPlane : Float := 500.0

end Cairn.Camera
