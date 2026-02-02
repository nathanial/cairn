/-
  Cairn/World/Raycast.lean - DDA voxel raycasting (Amanatides-Woo algorithm)
-/

import Cairn.World.Types
import Cairn.World.World
import Linalg
import Afferent.Render.FPSCamera

namespace Cairn.World

open Cairn.Core
open Linalg
open Afferent.Render

/-- Get normal vector for a face -/
def Face.toNormal : Face → Vec3
  | .top    => Vec3.unitY
  | .bottom => Vec3.down
  | .north  => Vec3.unitZ
  | .south  => Vec3.forward   -- -Z
  | .east   => Vec3.unitX
  | .west   => Vec3.left      -- -X

/-- Get forward direction from FPSCamera -/
def cameraForward (cam : FPSCamera) : Vec3 :=
  let cosPitch := Float.cos cam.pitch
  let sinPitch := Float.sin cam.pitch
  let cosYaw := Float.cos cam.yaw
  let sinYaw := Float.sin cam.yaw
  ⟨cosPitch * sinYaw, sinPitch, -cosPitch * cosYaw⟩

/-- Get ray origin and direction from FPSCamera -/
def cameraRay (cam : FPSCamera) : Vec3 × Vec3 :=
  (⟨cam.x, cam.y, cam.z⟩, cameraForward cam)

/-- Small epsilon for floating point comparisons -/
private def epsilon : Float := 1e-8

/-- Large value representing infinity for axis-aligned rays -/
private def infinity : Float := 1e30

/-- Convert Int to Float -/
private def intToFloat (i : Int) : Float :=
  if i >= 0 then i.toNat.toFloat
  else -((-i).toNat.toFloat)

/-- Convert Float to Int via floor -/
private def floorToInt (f : Float) : Int :=
  f.floor.toInt64.toInt

/-- Check if a direction vector is effectively zero. -/
private def isZeroDir (dir : Vec3) : Bool :=
  dir.x.abs < epsilon && dir.y.abs < epsilon && dir.z.abs < epsilon

/-- DDA voxel raycast through the world.
    Returns the first solid block hit along the ray, or none if no hit within maxDistance. -/
def raycast (world : World) (origin : Vec3) (direction : Vec3) (maxDistance : Float)
    : Option RaycastHit := Id.run do
  -- Current voxel position (floor of origin)
  let mut voxelX : Int := floorToInt origin.x
  let mut voxelY : Int := floorToInt origin.y
  let mut voxelZ : Int := floorToInt origin.z

  -- Track which face was crossed last (for hit detection)
  -- Start with top since we typically look down at terrain
  let mut lastFace : Face := .top
  let mut t : Float := 0.0

  -- Check if we start inside a solid block
  let startBlock := World.getBlock world { x := voxelX, y := voxelY, z := voxelZ }
  if startBlock.isSolid then
    return some {
      blockPos := { x := voxelX, y := voxelY, z := voxelZ }
      face := .top  -- Arbitrary face when inside
      point := origin
      distance := 0.0
    }

  if maxDistance <= 0.0 then
    return none

  if isZeroDir direction then
    return none

  -- Normalize direction
  let dir := direction.normalize

  -- Step direction: +1 or -1 for each axis
  let stepX : Int := if dir.x >= 0.0 then 1 else -1
  let stepY : Int := if dir.y >= 0.0 then 1 else -1
  let stepZ : Int := if dir.z >= 0.0 then 1 else -1

  -- tDelta: how far along ray (in t) to move one voxel in each axis
  let tDeltaX := if dir.x.abs < epsilon then infinity else (1.0 / dir.x).abs
  let tDeltaY := if dir.y.abs < epsilon then infinity else (1.0 / dir.y).abs
  let tDeltaZ := if dir.z.abs < epsilon then infinity else (1.0 / dir.z).abs

  -- tMax: distance to next voxel boundary for each axis
  let mut tMaxX :=
    if dir.x >= 0.0 then
      ((intToFloat voxelX + 1.0) - origin.x) * tDeltaX
    else
      (origin.x - intToFloat voxelX) * tDeltaX

  let mut tMaxY :=
    if dir.y >= 0.0 then
      ((intToFloat voxelY + 1.0) - origin.y) * tDeltaY
    else
      (origin.y - intToFloat voxelY) * tDeltaY

  let mut tMaxZ :=
    if dir.z >= 0.0 then
      ((intToFloat voxelZ + 1.0) - origin.z) * tDeltaZ
    else
      (origin.z - intToFloat voxelZ) * tDeltaZ

  -- Derive iteration cap from maxDistance (one voxel per unit in worst case)
  let maxIterations : Nat :=
    (Float.ceil maxDistance).toUInt64.toNat + 2

  -- DDA loop
  for _ in [:maxIterations] do
    if t >= maxDistance then
      return none

    -- Step to next voxel (smallest tMax determines which axis boundary is closest)
    if tMaxX < tMaxY then
      if tMaxX < tMaxZ then
        voxelX := voxelX + stepX
        t := tMaxX
        tMaxX := tMaxX + tDeltaX
        lastFace := if stepX > 0 then .west else .east
      else
        voxelZ := voxelZ + stepZ
        t := tMaxZ
        tMaxZ := tMaxZ + tDeltaZ
        lastFace := if stepZ > 0 then .south else .north
    else
      if tMaxY < tMaxZ then
        voxelY := voxelY + stepY
        t := tMaxY
        tMaxY := tMaxY + tDeltaY
        lastFace := if stepY > 0 then .bottom else .top
      else
        voxelZ := voxelZ + stepZ
        t := tMaxZ
        tMaxZ := tMaxZ + tDeltaZ
        lastFace := if stepZ > 0 then .south else .north

    -- Check current voxel for solid block
    let block := World.getBlock world { x := voxelX, y := voxelY, z := voxelZ }
    if block.isSolid then
      let hitPoint := origin + dir.scale t
      return some {
        blockPos := { x := voxelX, y := voxelY, z := voxelZ }
        face := lastFace
        point := hitPoint
        distance := t
      }

  return none

/-- Get the position of the block adjacent to a hit face.
    Useful for block placement - place block on the face that was hit. -/
def RaycastHit.adjacentPos (hit : RaycastHit) : BlockPos :=
  let offset := match hit.face with
    | .top    => (0, 1, 0)
    | .bottom => (0, -1, 0)
    | .north  => (0, 0, 1)
    | .south  => (0, 0, -1)
    | .east   => (1, 0, 0)
    | .west   => (-1, 0, 0)
  { x := hit.blockPos.x + offset.1
  , y := hit.blockPos.y + offset.2.1
  , z := hit.blockPos.z + offset.2.2 }

end Cairn.World
