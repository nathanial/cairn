/-
  Cairn Tests - Test entry point
-/
import Crucible
import Cairn
import Collimator

open Crucible
open Cairn.Core
open Cairn.World
open Cairn.Optics
open Collimator
open scoped Collimator.Operators

testSuite "Block Tests"

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

test "air block properties" := do
  ensure (!Block.air.isSolid) "air should not be solid"
  ensure Block.air.isTransparent "air should be transparent"

test "stone block properties" := do
  ensure Block.stone.isSolid "stone should be solid"
  ensure (!Block.stone.isTransparent) "stone should not be transparent"

test "water block properties" := do
  ensure (!Block.water.isSolid) "water should not be solid"
  ensure Block.water.isTransparent "water should be transparent"

testSuite "Block Prism Tests"

test "stone prism matches stone" := do
  ensure (Block.stone ^? _stone).isSome "should match stone"
  ensure (Block.grass ^? _stone).isNone "should not match grass"

test "grass prism matches grass" := do
  ensure (Block.grass ^? _grass).isSome "should match grass"
  ensure (Block.stone ^? _grass).isNone "should not match stone"

test "air prism matches air" := do
  ensure (Block.air ^? _air).isSome "should match air"

testSuite "Generated Lens Tests"

test "ChunkPos lenses work" := do
  let pos : ChunkPos := { x := 5, z := 10 }
  ensure (pos ^. chunkPosX == 5) "x should be 5"
  ensure (pos ^. chunkPosZ == 10) "z should be 10"
  let newPos := pos & chunkPosX .~ 20
  ensure (newPos ^. chunkPosX == 20) "x should be 20 after set"

test "Chunk isDirty lens works" := do
  let chunk := Chunk.empty { x := 0, z := 0 }
  ensure (chunk ^. chunkIsDirty) "new chunks are dirty"
  let clean := chunk & chunkIsDirty .~ false
  ensure (!(clean ^. chunkIsDirty)) "should be clean after set"

test "TerrainConfig lenses work" := do
  let config : TerrainConfig := default
  let newConfig := config & terrainConfigSeed .~ 12345
  ensure (newConfig ^. terrainConfigSeed == 12345) "seed should be 12345"

test "World lenses work" := do
  let world := World.empty {} 5
  ensure (world ^. worldRenderDistance == 5) "render distance should be 5"

test "Composed lenses work" := do
  let config : TerrainConfig := { seed := 42, seaLevel := 50, baseHeight := 45, heightScale := 25.0, noiseScale := 0.015, caveThreshold := 0.45, caveScale := 0.05 }
  let world := World.empty config 3
  ensure (world ^. (worldTerrainConfig ∘ terrainConfigSeaLevel) == 50) "should read nested seaLevel"

#generate_tests

def main : IO UInt32 := runAllSuites
