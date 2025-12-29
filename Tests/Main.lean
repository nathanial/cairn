/-
  Cairn Tests - Test entry point
-/
import Crucible
import Cairn

open Crucible
open Cairn.Core

testSuite "Block Tests"

test "block solid check" := do
  ensure Block.stone.isSolid "stone should be solid"
  ensure Block.dirt.isSolid "dirt should be solid"
  ensure (!Block.air.isSolid) "air should not be solid"
  ensure (!Block.water.isSolid) "water should not be solid"

test "block transparency check" := do
  ensure Block.air.isTransparent "air should be transparent"
  ensure Block.water.isTransparent "water should be transparent"
  ensure Block.leaves.isTransparent "leaves should be transparent"
  ensure (!Block.stone.isTransparent) "stone should not be transparent"

test "block colors" := do
  let (r, g, b, a) := Block.grass.color
  ensure (r > 0.0 && g > 0.0 && b > 0.0 && a > 0.0) "grass color should have positive components"
  let (r, g, b, a) := Block.air.color
  ensure (a == 0.0) "air should be fully transparent"

#generate_tests

def main : IO UInt32 := runAllSuites
