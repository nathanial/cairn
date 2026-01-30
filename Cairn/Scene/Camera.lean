/-
  Cairn/Scene/Camera.lean - Orbit camera for static scene viewing
-/

import Afferent.Render.FPSCamera
import Linalg

namespace Cairn.Scene

open Afferent.Render
open Linalg

/-- Orbit camera state for static scenes.
    The camera orbits around a target point at a fixed distance. -/
structure OrbitCamera where
  /-- X coordinate of the point to orbit around -/
  targetX : Float := 8.0
  /-- Y coordinate of the point to orbit around -/
  targetY : Float := 64.0
  /-- Z coordinate of the point to orbit around -/
  targetZ : Float := 8.0
  /-- Distance from the target point -/
  distance : Float := 20.0
  /-- Horizontal angle (radians), 0 = looking from +Z toward target -/
  yaw : Float := 0.0
  /-- Vertical angle (radians), negative = looking down at target -/
  pitch : Float := -0.3
  deriving Repr, BEq, Inhabited

namespace OrbitCamera

/-- Default orbit camera -/
def default : OrbitCamera := {}

/-- Convert orbit camera to FPSCamera for rendering.
    Computes position from orbit parameters and sets look direction toward target. -/
def toFPSCamera (oc : OrbitCamera) : FPSCamera :=
  -- Compute camera position based on orbit around target
  -- Camera is at: target + spherical offset based on yaw/pitch/distance
  let cosPitch := Float.cos oc.pitch
  let sinPitch := Float.sin oc.pitch
  let cosYaw := Float.cos oc.yaw
  let sinYaw := Float.sin oc.yaw

  -- Position on sphere around target
  -- At yaw=0, pitch=0: camera is at +Z from target
  let x := oc.targetX + oc.distance * cosPitch * sinYaw
  let y := oc.targetY + oc.distance * sinPitch
  let z := oc.targetZ + oc.distance * cosPitch * cosYaw

  -- Calculate look direction toward target (opposite of offset direction)
  -- The FPSCamera yaw/pitch determine view direction
  -- We want to look from (x,y,z) toward (targetX, targetY, targetZ)
  let lookYaw := Float.atan2 (oc.targetX - x) (oc.targetZ - z)
  let dx := oc.targetX - x
  let dy := oc.targetY - y
  let dz := oc.targetZ - z
  let horizontalDist := Float.sqrt (dx * dx + dz * dz)
  let lookPitch := Float.atan2 dy horizontalDist

  { x, y, z
    yaw := lookYaw
    pitch := lookPitch
    moveSpeed := 0  -- Not used for orbit camera
    lookSensitivity := 0.003 }

/-- Update orbit camera from mouse drag.
    Horizontal movement rotates yaw, vertical movement changes pitch. -/
def updateFromMouse (oc : OrbitCamera) (dx dy : Float) (sensitivity : Float := 0.005) : OrbitCamera :=
  let newYaw := oc.yaw + dx * sensitivity
  -- Clamp pitch to avoid gimbal lock (slightly less than ±90°)
  let maxPitch := Float.halfPi * 0.9
  let newPitch := Float.min maxPitch (Float.max (-maxPitch) (oc.pitch + dy * sensitivity))
  { oc with yaw := newYaw, pitch := newPitch }

/-- Update orbit camera distance from scroll/zoom input -/
def updateDistance (oc : OrbitCamera) (delta : Float) (minDist : Float := 5.0) (maxDist : Float := 100.0) : OrbitCamera :=
  let newDist := Float.min maxDist (Float.max minDist (oc.distance + delta))
  { oc with distance := newDist }

end OrbitCamera

/-! ## Preset Orbit Cameras for Each Scene -/

/-- Orbit camera preset for viewing a solid 16x16x16 chunk.
    Centered on the cube, far enough to see the whole thing. -/
def solidChunkOrbit : OrbitCamera := {
  targetX := 8.0   -- Center of chunk X
  targetY := 64.0  -- Center of the solid region Y
  targetZ := 8.0   -- Center of chunk Z
  distance := 35.0 -- Far enough to see full cube
  yaw := 0.5       -- Slight angle for 3D perspective
  pitch := -0.35   -- Looking down slightly
}

/-- Orbit camera preset for viewing a single block.
    Close to the block for detailed viewing. -/
def singleBlockOrbit : OrbitCamera := {
  targetX := 8.5   -- Center of block
  targetY := 64.5  -- Center of block
  targetZ := 8.5   -- Center of block
  distance := 8.0  -- Close up view
  yaw := 0.6       -- Angled view
  pitch := -0.3    -- Looking down slightly
}

/-- Orbit camera preset for terrain preview.
    Higher up and farther back to see terrain features. -/
def terrainPreviewOrbit : OrbitCamera := {
  targetX := 8.0
  targetY := 50.0  -- Lower to show terrain better
  targetZ := 8.0
  distance := 50.0 -- Far enough to see terrain chunk
  yaw := 0.4
  pitch := -0.45   -- Looking down more to see terrain
}

end Cairn.Scene
