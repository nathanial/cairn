/-
  Cairn Tests - Test entry point
-/
import Crucible
import Cairn

open Crucible
open Cairn.Core

testSuite "Block Tests"

-- All block types for comprehensive testing
def allBlocks : List Block := [
  Block.air, Block.stone, Block.dirt, Block.grass,
  Block.sand, Block.water, Block.wood, Block.leaves
]

test "all blocks have valid colors" := do
  for block in allBlocks do
    let (r, g, b, a) := block.color
    ensure (!r.isNaN) s!"block {repr block} has NaN red component"
    ensure (!g.isNaN) s!"block {repr block} has NaN green component"
    ensure (!b.isNaN) s!"block {repr block} has NaN blue component"
    ensure (!a.isNaN) s!"block {repr block} has NaN alpha component"
    ensure (r >= 0.0 && r <= 1.0) s!"block {repr block} red out of range"
    ensure (g >= 0.0 && g <= 1.0) s!"block {repr block} green out of range"
    ensure (b >= 0.0 && b <= 1.0) s!"block {repr block} blue out of range"
    ensure (a >= 0.0 && a <= 1.0) s!"block {repr block} alpha out of range"

test "solid opaque blocks are not transparent" := do
  -- Most solid blocks should be opaque, except leaves which is special
  for block in allBlocks do
    if block.isSolid && block != Block.leaves then
      ensure (!block.isTransparent) s!"solid block {repr block} should not be transparent"

test "air block properties" := do
  ensure (!Block.air.isSolid) "air should not be solid"
  ensure Block.air.isTransparent "air should be transparent"
  let (_, _, _, a) := Block.air.color
  ensure (a == 0.0) "air should be fully transparent"

test "stone block properties" := do
  ensure Block.stone.isSolid "stone should be solid"
  ensure (!Block.stone.isTransparent) "stone should not be transparent"
  let (r, g, b, a) := Block.stone.color
  ensure (a == 1.0) "stone should be fully opaque"
  ensure (r == g && g == b) "stone should be gray"

test "dirt block properties" := do
  ensure Block.dirt.isSolid "dirt should be solid"
  ensure (!Block.dirt.isTransparent) "dirt should not be transparent"
  let (r, _, _, a) := Block.dirt.color
  ensure (a == 1.0) "dirt should be fully opaque"
  ensure (r > 0.0) "dirt should have color"

test "grass block properties" := do
  ensure Block.grass.isSolid "grass should be solid"
  ensure (!Block.grass.isTransparent) "grass should not be transparent"
  let (r, g, b, a) := Block.grass.color
  ensure (a == 1.0) "grass should be fully opaque"
  ensure (g > r && g > b) "grass should be predominantly green"

test "sand block properties" := do
  ensure Block.sand.isSolid "sand should be solid"
  ensure (!Block.sand.isTransparent) "sand should not be transparent"
  let (r, g, _, a) := Block.sand.color
  ensure (a == 1.0) "sand should be fully opaque"
  ensure (r > 0.8 && g > 0.8) "sand should be light colored"

test "water block properties" := do
  ensure (!Block.water.isSolid) "water should not be solid"
  ensure Block.water.isTransparent "water should be transparent"
  let (_, _, b, a) := Block.water.color
  ensure (a < 1.0 && a > 0.0) "water should be semi-transparent"
  ensure (b > 0.5) "water should be predominantly blue"

test "wood block properties" := do
  ensure Block.wood.isSolid "wood should be solid"
  ensure (!Block.wood.isTransparent) "wood should not be transparent"
  let (r, g, b, a) := Block.wood.color
  ensure (a == 1.0) "wood should be fully opaque"
  ensure (r > g && r > b) "wood should be brown-ish"

test "leaves block properties" := do
  ensure Block.leaves.isSolid "leaves should be solid"
  ensure Block.leaves.isTransparent "leaves should be transparent"
  let (_, g, _, a) := Block.leaves.color
  ensure (a < 1.0 && a > 0.0) "leaves should be semi-transparent"
  ensure (g > 0.5) "leaves should be predominantly green"

#generate_tests

def main : IO UInt32 := runAllSuites
