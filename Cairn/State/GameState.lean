/-
  Cairn/State/GameState.lean - Consolidated game state
-/

import Afferent.Render.FPSCamera
import Cairn.Core.Block
import Cairn.World.Types
import Cairn.World.World
import Cairn.Camera
import Cairn.Input.State
import Cairn.Scene.Modes
import Cairn.Widget.Core

namespace Cairn.State

open Afferent.Render
open Cairn.Core
open Cairn.World
open Cairn.Camera
open Cairn.Input
open Cairn.Scene
open Cairn.Widget

/-- All mutable game state in a single structure -/
structure GameState where
  camera : FPSCamera
  world : World
  lastTime : Nat
  selectedBlock : Block := Block.stone  -- Currently selected block for placement
  -- Physics state
  velocityX : Float := 0.0
  velocityY : Float := 0.0
  velocityZ : Float := 0.0
  isGrounded : Bool := false
  flyMode : Bool := true  -- Start in fly mode (no physics)

namespace GameState

/-- Create initial game state with terrain configuration -/
def create (config : TerrainConfig) (renderDistance : Nat := 2) (startY : Float := 60.0) : IO GameState := do
  let now ← IO.monoMsNow
  let world ← World.create config renderDistance
  return {
    camera := { defaultCamera with y := startY }
    world
    lastTime := now
  }

end GameState

/-! ## FRP Types for Reactive State Management -/

/-- Input event fired each frame -/
structure GameFrameInput where
  input : InputState
  dt : Float
  deriving Inhabited

/-- Combined scene state (single structure holds all modes) -/
structure SceneStates where
  gameWorld : VoxelSceneState
  solidChunk : VoxelSceneState
  singleBlock : VoxelSceneState
  terrainPreview : VoxelSceneState
  activeMode : SceneMode
  highlightPos : Option (Int × Int × Int)
  -- Game world specific state
  selectedBlock : Block
  velocityX : Float
  velocityY : Float
  velocityZ : Float
  isGrounded : Bool
  lastUnloadChunk : Option ChunkPos := none

namespace SceneStates

/-- Get the VoxelSceneState for the currently active mode -/
def getActiveState (states : SceneStates) : VoxelSceneState :=
  match states.activeMode with
  | .gameWorld => states.gameWorld
  | .solidChunk => states.solidChunk
  | .singleBlock => states.singleBlock
  | .terrainPreview => states.terrainPreview

/-- Update the VoxelSceneState for the currently active mode -/
def updateActiveState (states : SceneStates) (f : VoxelSceneState → VoxelSceneState) : SceneStates :=
  match states.activeMode with
  | .gameWorld => { states with gameWorld := f states.gameWorld }
  | .solidChunk => { states with solidChunk := f states.solidChunk }
  | .singleBlock => { states with singleBlock := f states.singleBlock }
  | .terrainPreview => { states with terrainPreview := f states.terrainPreview }

end SceneStates

/-- Update types for foldDynM -/
inductive StateUpdate
  | frame (input : GameFrameInput)
  | tabChange (idx : Nat)
  | selectBlock (block : Block)
  | worldUpdate (world : World)
  | worldChunkReady (pending : PendingChunk)
  | worldMeshReady (pending : PendingMesh)
  | highlightUpdate (pos : Option (Int × Int × Int))

end Cairn.State
