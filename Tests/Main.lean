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
open Linalg
open Afferent.Render

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

testSuite "Block Face Color Tests"

test "grass has different face colors" := do
  let topColor := Block.grass.faceColor Face.top
  let sideColor := Block.grass.faceColor Face.north
  ensure (topColor != sideColor) "grass top should differ from sides (green vs brown)"

test "wood has different face colors" := do
  let topColor := Block.wood.faceColor Face.top
  let sideColor := Block.wood.faceColor Face.east
  ensure (topColor != sideColor) "wood ends should differ from bark"

test "stone has same color for all faces" := do
  let topColor := Block.stone.faceColor Face.top
  let sideColor := Block.stone.faceColor Face.north
  let bottomColor := Block.stone.faceColor Face.bottom
  ensure (topColor == sideColor) "stone should be uniform"
  ensure (topColor == bottomColor) "stone should be uniform"

test "all face colors are valid" := do
  for block in allBlocks do
    for face in Face.all do
      let (r, g, b, a) := block.faceColor face
      ensure (!r.isNaN) s!"{repr block} {repr face} has NaN red"
      ensure (!g.isNaN) s!"{repr block} {repr face} has NaN green"
      ensure (!b.isNaN) s!"{repr block} {repr face} has NaN blue"
      ensure (!a.isNaN) s!"{repr block} {repr face} has NaN alpha"

testSuite "Block Prism Tests"

test "stone prism matches stone" := do
  ensure (Block.stone ^? _stone).isSome "should match stone"
  ensure (Block.grass ^? _stone).isNone "should not match grass"

test "grass prism matches grass" := do
  ensure (Block.grass ^? _grass).isSome "should match grass"
  ensure (Block.stone ^? _grass).isNone "should not match stone"

test "air prism matches air" := do
  ensure (Block.air ^? _air).isSome "should match air"

testSuite "Coordinate Conversion Tests"

test "positive BlockPos to ChunkPos" := do
  ensure ((BlockPos.mk 0 0 0).toChunkPos == { x := 0, z := 0 }) "origin"
  ensure ((BlockPos.mk 15 0 15).toChunkPos == { x := 0, z := 0 }) "chunk 0 edge"
  ensure ((BlockPos.mk 16 0 16).toChunkPos == { x := 1, z := 1 }) "chunk 1 start"
  ensure ((BlockPos.mk 31 0 31).toChunkPos == { x := 1, z := 1 }) "chunk 1 edge"

test "negative BlockPos to ChunkPos" := do
  -- Chunk -1 covers blocks [-16, -1]
  ensure ((BlockPos.mk (-1) 0 0).toChunkPos == { x := -1, z := 0 }) "block -1 → chunk -1"
  ensure ((BlockPos.mk (-16) 0 0).toChunkPos == { x := -1, z := 0 }) "block -16 → chunk -1"
  -- Chunk -2 covers blocks [-32, -17]
  ensure ((BlockPos.mk (-17) 0 0).toChunkPos == { x := -2, z := 0 }) "block -17 → chunk -2"
  ensure ((BlockPos.mk (-32) 0 0).toChunkPos == { x := -2, z := 0 }) "block -32 → chunk -2"
  ensure ((BlockPos.mk (-33) 0 0).toChunkPos == { x := -3, z := 0 }) "block -33 → chunk -3"

test "negative BlockPos to LocalPos" := do
  ensure ((BlockPos.mk (-1) 0 0).toLocalPos == { x := 15, y := 0, z := 0 }) "block -1 → local 15"
  ensure ((BlockPos.mk (-16) 0 0).toLocalPos == { x := 0, y := 0, z := 0 }) "block -16 → local 0"
  ensure ((BlockPos.mk (-17) 0 0).toLocalPos == { x := 15, y := 0, z := 0 }) "block -17 → local 15"

test "BlockPos round-trip through WorldPos" := do
  let testPositions := [
    BlockPos.mk 0 50 0,
    BlockPos.mk 15 50 15,
    BlockPos.mk 16 50 16,
    BlockPos.mk (-1) 50 (-1),
    BlockPos.mk (-16) 50 (-16),
    BlockPos.mk (-17) 50 (-17),
    BlockPos.mk (-32) 50 (-32)
  ]
  for pos in testPositions do
    let roundTrip := pos.decompose.toBlockPos
    ensure (roundTrip == pos) s!"round-trip failed for {repr pos}, got {repr roundTrip}"

test "negative Z coordinates" := do
  ensure ((BlockPos.mk 0 0 (-1)).toChunkPos == { x := 0, z := -1 }) "z=-1 → chunk z=-1"
  ensure ((BlockPos.mk 0 0 (-16)).toChunkPos == { x := 0, z := -1 }) "z=-16 → chunk z=-1"
  ensure ((BlockPos.mk 0 0 (-17)).toChunkPos == { x := 0, z := -2 }) "z=-17 → chunk z=-2"

test "negative Y treated as air" := do
  let mut world ← World.empty {} 1
  let chunkPos : ChunkPos := { x := 0, z := 0 }
  world := world & worldChunks %~ (·.insert chunkPos (Chunk.empty chunkPos))
  let pos : BlockPos := { x := 0, y := -1, z := 0 }
  world := World.setBlock world pos Block.stone
  ensure (World.getBlock world pos == Block.air) "negative y should be air"

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
  let world ← World.empty {} 5
  ensure (world ^. worldRenderDistance == 5) "render distance should be 5"

test "Composed lenses work" := do
  let config : TerrainConfig := ⟨42, 50, 45, 25.0, 0.015, 0.45, 0.05⟩
  let world ← World.empty config 3
  ensure (world ^. (worldTerrainConfig ∘ terrainConfigSeaLevel) == 50) "should read nested seaLevel"

testSuite "Raycast Tests"

-- Helper to insert an empty chunk at a position
def insertEmptyChunk (world : World) (pos : ChunkPos) : World :=
  world & worldChunks %~ (·.insert pos (Chunk.empty pos))

test "raycast hits solid block in front" := do
  -- Create empty world with empty chunk and place a stone block
  let mut world ← World.empty {} 3
  let targetPos : BlockPos := { x := 5, y := 5, z := 5 }
  world := insertEmptyChunk world targetPos.toChunkPos
  world := World.setBlock world targetPos Block.stone

  -- Cast ray from origin toward the block
  let origin : Vec3 := ⟨0.5, 5.5, 5.5⟩
  let direction : Vec3 := Vec3.unitX  -- Looking +X

  match raycast world origin direction 100.0 with
  | some hit =>
    ensure (hit.blockPos.x == 5) s!"should hit x=5, got {hit.blockPos.x}"
    ensure (hit.face == Face.west) s!"should hit west face, got {repr hit.face}"
  | none => ensure false "should have hit a block"

test "raycast misses in empty space" := do
  let world ← World.empty {} 3
  let origin : Vec3 := ⟨0.0, 5.0, 0.0⟩
  let direction : Vec3 := Vec3.unitX

  ensure (raycast world origin direction 10.0).isNone "should miss in empty world"

test "raycast returns none for zero direction" := do
  let world ← World.empty {} 3
  let origin : Vec3 := ⟨0.0, 0.0, 0.0⟩
  let direction : Vec3 := ⟨0.0, 0.0, 0.0⟩
  ensure (raycast world origin direction 10.0).isNone "zero direction should miss"

test "raycast detects starting inside block" := do
  let mut world ← World.empty {} 3
  let targetPos : BlockPos := { x := 1, y := 1, z := 1 }
  world := insertEmptyChunk world targetPos.toChunkPos
  world := World.setBlock world targetPos Block.stone
  let origin : Vec3 := ⟨1.2, 1.2, 1.2⟩
  let direction : Vec3 := Vec3.unitX
  match raycast world origin direction 10.0 with
  | some hit =>
    ensure (hit.blockPos == targetPos) "should hit starting block"
    ensure (hit.distance == 0.0) "distance should be 0 when inside"
  | none => ensure false "should hit block when starting inside"

test "raycast respects max distance" := do
  let mut world ← World.empty {} 3
  let targetPos : BlockPos := { x := 50, y := 5, z := 5 }
  world := insertEmptyChunk world targetPos.toChunkPos
  world := World.setBlock world targetPos Block.stone

  let origin : Vec3 := ⟨0.5, 5.5, 5.5⟩
  let direction : Vec3 := Vec3.unitX

  -- Block at distance ~50, max distance 20 - should miss
  ensure (raycast world origin direction 20.0).isNone "should miss beyond max distance"

test "raycast hits diagonal target" := do
  let mut world ← World.empty {} 3
  let targetPos : BlockPos := { x := 1, y := 1, z := 1 }
  world := insertEmptyChunk world targetPos.toChunkPos
  world := World.setBlock world targetPos Block.stone
  let origin : Vec3 := ⟨0.1, 0.1, 0.1⟩
  let direction : Vec3 := ⟨1.0, 1.0, 1.0⟩
  match raycast world origin direction 10.0 with
  | some hit => ensure (hit.blockPos == targetPos) "should hit diagonal block"
  | none => ensure false "should hit diagonal block"

test "raycast detects top face (ray going down)" := do
  let mut world ← World.empty {} 3
  let targetPos : BlockPos := { x := 5, y := 0, z := 5 }
  world := insertEmptyChunk world targetPos.toChunkPos
  world := World.setBlock world targetPos Block.stone

  -- Ray going downward should hit top face
  let origin : Vec3 := ⟨5.5, 10.0, 5.5⟩
  let direction : Vec3 := Vec3.down  -- -Y

  match raycast world origin direction 100.0 with
  | some hit =>
    ensure (hit.face == Face.top) s!"should hit top face, got {repr hit.face}"
  | none => ensure false "should have hit a block"

test "raycast detects bottom face (ray going up)" := do
  let mut world ← World.empty {} 3
  let targetPos : BlockPos := { x := 5, y := 10, z := 5 }
  world := insertEmptyChunk world targetPos.toChunkPos
  world := World.setBlock world targetPos Block.stone

  -- Ray going upward should hit bottom face
  let origin : Vec3 := ⟨5.5, 0.0, 5.5⟩
  let direction : Vec3 := Vec3.unitY  -- +Y

  match raycast world origin direction 100.0 with
  | some hit =>
    ensure (hit.face == Face.bottom) s!"should hit bottom face, got {repr hit.face}"
  | none => ensure false "should have hit a block"

test "cameraRay returns correct direction at yaw=0 pitch=0" := do
  let cam : FPSCamera := { x := 10.0, y := 20.0, z := 30.0, yaw := 0.0, pitch := 0.0 }
  let (origin, dir) := cameraRay cam

  ensure (origin.x == 10.0) s!"origin x should be 10, got {origin.x}"
  ensure (origin.y == 20.0) s!"origin y should be 20, got {origin.y}"
  ensure (origin.z == 30.0) s!"origin z should be 30, got {origin.z}"
  -- With yaw=0, pitch=0, forward should be (0, 0, -1)
  ensure (dir.x.abs < 0.001) s!"dir.x should be ~0, got {dir.x}"
  ensure (dir.y.abs < 0.001) s!"dir.y should be ~0, got {dir.y}"
  ensure ((dir.z + 1.0).abs < 0.001) s!"dir.z should be ~-1, got {dir.z}"

test "adjacentPos returns correct neighbor" := do
  let hit : RaycastHit := {
    blockPos := { x := 5, y := 5, z := 5 }
    face := Face.top
    point := ⟨5.5, 6.0, 5.5⟩
    distance := 1.0
  }
  let adj := hit.adjacentPos
  ensure (adj.x == 5 && adj.y == 6 && adj.z == 5) s!"top adjacent should be above, got ({adj.x}, {adj.y}, {adj.z})"

  let hitWest : RaycastHit := { hit with face := Face.west }
  let adjWest := hitWest.adjacentPos
  ensure (adjWest.x == 4) s!"west adjacent should have x=4, got {adjWest.x}"

def main : IO UInt32 := runAllSuites
