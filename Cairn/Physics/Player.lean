/-
  Cairn/Physics/Player.lean - Player physics with AABB collision
-/

import Afferent.Render.FPSCamera
import Cairn.Core.Block
import Cairn.Core.Coords
import Cairn.World.World
import Cairn.Input.State

namespace Cairn.Physics

open Afferent.Render
open Cairn.Core
open Cairn.World
open Cairn.Input

-- Physics constants
def gravity : Float := 25.0          -- blocks/sec²
def jumpSpeed : Float := 8.0         -- blocks/sec
def maxFallSpeed : Float := 50.0     -- terminal velocity
def moveSpeed : Float := 5.0         -- blocks/sec horizontal
def airControl : Float := 0.3        -- reduced control in air
def playerWidth : Float := 0.6       -- AABB width/depth (full, not half)
def playerHeight : Float := 1.8      -- AABB height
def eyeOffset : Float := 1.6         -- camera Y from feet

/-- Convert Int to Float -/
def intToFloat (i : Int) : Float :=
  if i >= 0 then i.toNat.toFloat else -((-i).toNat.toFloat)

/-- Clamp a Float to a range -/
def clamp (v lo hi : Float) : Float :=
  if v < lo then lo else if v > hi then hi else v

/-- Get all block positions that an AABB might intersect -/
def getBlocksInAABB (x y z : Float) (hw hh : Float) : List BlockPos := Id.run do
  let halfW := hw / 2.0
  let minX := (x - halfW).floor.toInt64.toInt
  let maxX := (x + halfW).floor.toInt64.toInt
  let minY := y.floor.toInt64.toInt
  let maxY := (y + hh).floor.toInt64.toInt
  let minZ := (z - halfW).floor.toInt64.toInt
  let maxZ := (z + halfW).floor.toInt64.toInt

  let mut blocks : List BlockPos := []
  -- Iterate over the bounding box
  let mut yi := minY
  while yi <= maxY do
    let mut zi := minZ
    while zi <= maxZ do
      let mut xi := minX
      while xi <= maxX do
        blocks := { x := xi, y := yi, z := zi } :: blocks
        xi := xi + 1
      zi := zi + 1
    yi := yi + 1
  return blocks

/-- Check if a point is inside a block's unit cube -/
private def pointInBlock (px py pz : Float) (bx by_ bz : Int) : Bool :=
  let bxf := intToFloat bx
  let byf := intToFloat by_
  let bzf := intToFloat bz
  px >= bxf && px < bxf + 1.0 &&
  py >= byf && py < byf + 1.0 &&
  pz >= bzf && pz < bzf + 1.0

/-- Check if AABB intersects a block -/
private def aabbIntersectsBlock (x y z hw hh : Float) (bx by_ bz : Int) : Bool :=
  let halfW := hw / 2.0
  let bxf := intToFloat bx
  let byf := intToFloat by_
  let bzf := intToFloat bz
  -- AABB-AABB intersection test
  x + halfW > bxf && x - halfW < bxf + 1.0 &&
  y + hh > byf && y < byf + 1.0 &&
  z + halfW > bzf && z - halfW < bzf + 1.0

/-- Move and collide on Y axis. Returns (newY, newVelY, grounded) -/
def moveY (world : World) (x y z vy : Float) (hw hh : Float) (dt : Float)
    : Float × Float × Bool := Id.run do
  let newY := y + vy * dt
  let blocks := getBlocksInAABB x newY z hw hh

  let mut finalY := newY
  let mut finalVy := vy
  let mut grounded := false

  for pos in blocks do
    if (world.getBlock pos).isSolid then
      if aabbIntersectsBlock x newY z hw hh pos.x pos.y pos.z then
        let blockTop := intToFloat pos.y + 1.0
        let blockBottom := intToFloat pos.y
        if vy < 0.0 then
          -- Falling down, land on top of block
          finalY := blockTop
          finalVy := 0.0
          grounded := true
        else if vy > 0.0 then
          -- Moving up, hit bottom of block
          finalY := blockBottom - hh
          finalVy := 0.0

  return (finalY, finalVy, grounded)

/-- Move and collide on X axis. Returns (newX, newVelX) -/
def moveX (world : World) (x y z vx : Float) (hw hh : Float) (dt : Float)
    : Float × Float := Id.run do
  let newX := x + vx * dt
  let blocks := getBlocksInAABB newX y z hw hh

  let mut finalX := newX
  let mut finalVx := vx

  for pos in blocks do
    if (world.getBlock pos).isSolid then
      if aabbIntersectsBlock newX y z hw hh pos.x pos.y pos.z then
        let halfW := hw / 2.0
        let blockLeft := intToFloat pos.x
        let blockRight := intToFloat pos.x + 1.0
        if vx > 0.0 then
          -- Moving right, stop at left edge of block
          finalX := blockLeft - halfW - 0.001
          finalVx := 0.0
        else if vx < 0.0 then
          -- Moving left, stop at right edge of block
          finalX := blockRight + halfW + 0.001
          finalVx := 0.0

  return (finalX, finalVx)

/-- Move and collide on Z axis. Returns (newZ, newVelZ) -/
def moveZ (world : World) (x y z vz : Float) (hw hh : Float) (dt : Float)
    : Float × Float := Id.run do
  let newZ := z + vz * dt
  let blocks := getBlocksInAABB x y newZ hw hh

  let mut finalZ := newZ
  let mut finalVz := vz

  for pos in blocks do
    if (world.getBlock pos).isSolid then
      if aabbIntersectsBlock x y newZ hw hh pos.x pos.y pos.z then
        let halfW := hw / 2.0
        let blockBack := intToFloat pos.z
        let blockFront := intToFloat pos.z + 1.0
        if vz > 0.0 then
          -- Moving forward (+Z), stop at back edge
          finalZ := blockBack - halfW - 0.001
          finalVz := 0.0
        else if vz < 0.0 then
          -- Moving backward (-Z), stop at front edge
          finalZ := blockFront + halfW + 0.001
          finalVz := 0.0

  return (finalZ, finalVz)

def flySpeed : Float := 10.0  -- Faster in fly mode

/-- Update player in fly mode (no gravity, no collisions) -/
def updatePlayerFly (camX camY camZ : Float) (yaw : Float) (input : InputState) (dt : Float)
    : Float × Float × Float := Id.run do
  -- Calculate forward/right vectors
  let fwdX := Float.sin yaw
  let fwdZ := -Float.cos yaw
  let rightX := Float.cos yaw
  let rightZ := Float.sin yaw

  -- Horizontal movement
  let mut moveX := 0.0
  let mut moveZ := 0.0
  if input.forward then moveX := moveX + fwdX; moveZ := moveZ + fwdZ
  if input.back then moveX := moveX - fwdX; moveZ := moveZ - fwdZ
  if input.right then moveX := moveX + rightX; moveZ := moveZ + rightZ
  if input.left then moveX := moveX - rightX; moveZ := moveZ - rightZ

  -- Normalize horizontal
  let len := Float.sqrt (moveX * moveX + moveZ * moveZ)
  if len > 0.001 then
    moveX := moveX / len
    moveZ := moveZ / len

  -- Vertical movement (space/E = up, Q = down)
  let mut moveY := 0.0
  if input.jump || input.up then moveY := moveY + 1.0
  if input.down then moveY := moveY - 1.0

  -- Apply movement
  let newX := camX + moveX * flySpeed * dt
  let newY := camY + moveY * flySpeed * dt
  let newZ := camZ + moveZ * flySpeed * dt

  return (newX, newY, newZ)

/-- Update player physics for one frame -/
def updatePlayer (world : World)
    (camX camY camZ : Float) (_vx vy _vz : Float) (grounded : Bool)
    (yaw : Float) (input : InputState) (dt : Float)
    : Float × Float × Float × Float × Float × Float × Bool := Id.run do

  -- Player feet position (camera is at eye level)
  let feetY := camY - eyeOffset

  -- Calculate wish direction from input
  let fwdX := Float.sin yaw
  let fwdZ := -Float.cos yaw
  let rightX := Float.cos yaw
  let rightZ := Float.sin yaw

  let mut wishX := 0.0
  let mut wishZ := 0.0
  if input.forward then wishX := wishX + fwdX; wishZ := wishZ + fwdZ
  if input.back then wishX := wishX - fwdX; wishZ := wishZ - fwdZ
  if input.right then wishX := wishX + rightX; wishZ := wishZ + rightZ
  if input.left then wishX := wishX - rightX; wishZ := wishZ - rightZ

  -- Normalize wish direction
  let wishLen := Float.sqrt (wishX * wishX + wishZ * wishZ)
  if wishLen > 0.001 then
    wishX := wishX / wishLen
    wishZ := wishZ / wishLen

  -- Apply acceleration (reduced in air)
  let control := if grounded then 1.0 else airControl
  let accel := moveSpeed * control
  let mut newVx := wishX * accel
  let mut newVz := wishZ * accel

  -- Apply gravity
  let mut newVy := vy - gravity * dt
  newVy := clamp newVy (-maxFallSpeed) maxFallSpeed

  -- Handle jump
  if input.jump && grounded then
    newVy := jumpSpeed

  -- Move and collide on each axis (Y first for ground detection)
  let (newFeetY, finalVy, nowGrounded) := moveY world camX feetY camZ newVy playerWidth playerHeight dt
  let (newX, _) := moveX world camX newFeetY camZ newVx playerWidth playerHeight dt
  let (newZ, _) := moveZ world newX newFeetY camZ newVz playerWidth playerHeight dt

  -- Convert feet back to camera position
  let newCamY := newFeetY + eyeOffset

  -- Return post-collision Y velocity; Z velocity remains the desired horizontal speed.
  return (newX, newCamY, newZ, newVx, finalVy, newVz, nowGrounded)

end Cairn.Physics
