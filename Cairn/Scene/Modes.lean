/-
  Cairn/Scene/Modes.lean - Scene modes and world creation functions
-/

import Cairn.Core.Block
import Cairn.Core.Coords
import Cairn.World.Types
import Cairn.World.Chunk
import Cairn.World.World
import Cairn.Render.MeshGen

namespace Cairn.Scene

open Cairn.Core
open Cairn.World

/-- Scene modes for different voxel configurations -/
inductive SceneMode where
  | solidChunk     -- 16x16x16 solid cube
  | singleBlock    -- One block at origin
  | terrainPreview -- Single terrain chunk
  | gameWorld      -- Full game mode with interaction
  deriving Repr, BEq, Inhabited

namespace SceneMode

/-- Display name for each scene mode -/
def name : SceneMode → String
  | .solidChunk => "Solid Chunk"
  | .singleBlock => "Single Block"
  | .terrainPreview => "Terrain Preview"
  | .gameWorld => "Game World"

/-- Convert tab index to scene mode -/
def fromTabIndex (idx : Nat) : SceneMode :=
  match idx with
  | 0 => .gameWorld
  | 1 => .solidChunk
  | 2 => .singleBlock
  | 3 => .terrainPreview
  | _ => .gameWorld

/-- Convert scene mode to tab index -/
def toTabIndex : SceneMode → Nat
  | .gameWorld => 0
  | .solidChunk => 1
  | .singleBlock => 2
  | .terrainPreview => 3

end SceneMode

/-- Create a world with a single solid 16x16x16 cube of stone -/
def createSolidChunkWorld : IO World := do
  let world ← World.create {} 1  -- minimal render distance
  -- Create chunk with a solid 16x16x16 cube
  let chunk := Chunk.empty { x := 0, z := 0 }
  -- Fill from y=56 to y=71 (16 blocks high, centered around y=64)
  let chunk := chunk.fillRegion
    { x := 0, y := 56, z := 0 }
    { x := 15, y := 71, z := 15 }
    Block.stone
  -- Insert chunk and generate mesh
  let world := { world with chunks := world.chunks.insert { x := 0, z := 0 } chunk }
  let world := world.ensureMesh { x := 0, z := 0 }
  pure world

/-- Create a world with a single block at the center -/
def createSingleBlockWorld : IO World := do
  let world ← World.create {} 1
  -- Create chunk with a single block at center
  let mut chunk := Chunk.empty { x := 0, z := 0 }
  -- Place a single stone block at local position (8, 64, 8)
  let idx : Nat := 8 + 8 * chunkSize + 64 * chunkSize * chunkSize
  if idx < chunk.blocks.size then
    chunk := { chunk with blocks := chunk.blocks.set! idx Block.stone }
  -- Insert chunk and generate mesh
  let world := { world with chunks := world.chunks.insert { x := 0, z := 0 } chunk }
  let world := world.ensureMesh { x := 0, z := 0 }
  pure world

/-- Create a world with one terrain chunk -/
def createTerrainPreviewWorld (config : TerrainConfig) : IO World := do
  let world ← World.create config 1
  -- Generate terrain for a single chunk at origin
  let world := world.ensureChunk { x := 0, z := 0 }
  let world := world.ensureMesh { x := 0, z := 0 }
  pure world

end Cairn.Scene
