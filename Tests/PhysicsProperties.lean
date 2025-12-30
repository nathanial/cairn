/-
  Property-based tests for Cairn physics using Plausible.
  These tests verify invariants that should hold for all valid inputs.
-/

import Cairn
import Plausible
import Crucible

namespace Tests.PhysicsProperties

open Plausible
open Crucible
open Cairn.Physics

/-! ## Helper Functions -/

/-- Check if two floats are approximately equal. -/
def floatNear (a b : Float) (eps : Float := 0.0001) : Bool :=
  Float.abs (a - b) < eps

/-! ## Random Generators -/

/-- Generate a random Float in a physics-relevant range. -/
def genPhysicsFloat : Gen Float := do
  let n ← Gen.choose Nat 0 200 (by omega)
  return n.val.toFloat - 100.0

/-- Generate a random positive Float for velocities. -/
def genVelocity : Gen Float := do
  let n ← Gen.choose Nat 0 50 (by omega)
  return n.val.toFloat

/-- Generate a small positive Float for delta time (0.001 to 0.1 seconds). -/
def genDeltaTime : Gen Float := do
  let n ← Gen.choose Nat 1 100 (by omega)
  return n.val.toFloat / 1000.0

/-- Wrapper for physics floats. -/
structure PhysFloat where
  val : Float
  deriving Repr

instance : Arbitrary PhysFloat where
  arbitrary := do
    let f ← genPhysicsFloat
    return ⟨f⟩

instance : Shrinkable PhysFloat where
  shrink pf :=
    let v := pf.val
    let candidates := [0.0, 1.0, -1.0, v / 2.0].filter (· != v)
    candidates.map (⟨·⟩)

/-- Wrapper for positive floats (velocities). -/
structure PosFloat where
  val : Float
  deriving Repr

instance : Arbitrary PosFloat where
  arbitrary := do
    let f ← genVelocity
    return ⟨f⟩

instance : Shrinkable PosFloat where
  shrink pf :=
    let v := pf.val
    let candidates := [0.0, 1.0, v / 2.0].filter (fun x => x != v && x >= 0.0)
    candidates.map (⟨·⟩)

/-- Wrapper for delta time values. -/
structure DeltaTime where
  val : Float
  deriving Repr

instance : Arbitrary DeltaTime where
  arbitrary := do
    let f ← genDeltaTime
    return ⟨f⟩

instance : Shrinkable DeltaTime where
  shrink dt :=
    let v := dt.val
    let candidates := [0.001, 0.016, v / 2.0].filter (fun x => x != v && x > 0.0)
    candidates.map (⟨·⟩)

/-! ## Physics Constants Properties -/

-- Player dimensions are positive
#test playerWidth > 0.0

#test playerHeight > 0.0

-- Eye offset is within player height
#test eyeOffset > 0.0 ∧ eyeOffset < playerHeight

-- Gravity is positive (pulls down)
#test gravity > 0.0

-- Max fall speed exceeds jump speed
#test maxFallSpeed > jumpSpeed

-- Jump speed is positive
#test jumpSpeed > 0.0

-- Air control is reduced (less than 1)
#test airControl > 0.0 ∧ airControl < 1.0

-- Move speed is positive
#test moveSpeed > 0.0

/-! ## Clamp Properties -/

-- Clamp keeps values in bounds
#test ∀ (pf : PhysFloat),
  let v := pf.val
  let clamped := clamp v (-maxFallSpeed) maxFallSpeed
  clamped >= -maxFallSpeed ∧ clamped <= maxFallSpeed

-- Clamp is idempotent
#test ∀ (pf : PhysFloat),
  let v := pf.val
  let once := clamp v (-maxFallSpeed) maxFallSpeed
  let twice := clamp once (-maxFallSpeed) maxFallSpeed
  once == twice

-- Clamp preserves values already in range
#test ∀ (pf : PosFloat),
  let v := pf.val  -- Always in [0, 50], subset of [-50, 50]
  let clamped := clamp v (-maxFallSpeed) maxFallSpeed
  clamped == v

/-! ## Gravity Properties -/

-- Gravity always reduces upward velocity
#test ∀ (pf : PosFloat) (dt : DeltaTime),
  let vy := pf.val + 1.0  -- Ensure positive (upward)
  let newVy := vy - gravity * dt.val
  newVy < vy

-- Gravity accumulates over time
#test ∀ (dt : DeltaTime),
  let dt1 := dt.val
  let dt2 := dt.val * 2.0
  -- Larger dt means more velocity change
  gravity * dt2 > gravity * dt1

/-! ## AABB Block Enumeration Properties -/

-- AABB at integer position includes that block
#test ∀ (pf : PhysFloat),
  let x := pf.val.floor
  let y := pf.val.floor
  let z := pf.val.floor
  let blocks := getBlocksInAABB x y z playerWidth playerHeight
  -- Should contain at least one block
  blocks.length > 0

-- Larger AABB includes at least as many blocks
#test ∀ (pf : PhysFloat),
  let x := pf.val
  let small := getBlocksInAABB x 0.0 x 0.5 0.5
  let large := getBlocksInAABB x 0.0 x 2.0 2.0
  large.length >= small.length

/-! ## Movement Properties -/

-- Normalized wish direction has magnitude <= 1
#test ∀ (pf1 pf2 : PhysFloat),
  let wx := pf1.val
  let wz := pf2.val
  let len := Float.sqrt (wx * wx + wz * wz)
  if len > 0.001 then
    let nx := wx / len
    let nz := wz / len
    let normLen := Float.sqrt (nx * nx + nz * nz)
    floatNear normLen 1.0 0.01
  else
    true  -- Zero vector is valid

-- Air control reduces effective speed
#test ∀ (pf : PosFloat),
  let groundSpeed := pf.val * 1.0  -- Full control
  let airSpeed := pf.val * airControl
  airSpeed <= groundSpeed

/-! ## IntToFloat Properties -/

-- intToFloat preserves sign
#test ∀ (pf : PhysFloat),
  let i := pf.val.floor.toInt64.toInt
  let f := intToFloat i
  if i > 0 then f > 0.0
  else if i < 0 then f < 0.0
  else f == 0.0

-- intToFloat of 0 is 0
#test floatNear (intToFloat 0) 0.0

-- intToFloat of 1 is 1
#test floatNear (intToFloat 1) 1.0

-- intToFloat of -1 is -1
#test floatNear (intToFloat (-1)) (-1.0)

end Tests.PhysicsProperties
