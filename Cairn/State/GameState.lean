/-
  Cairn/State/GameState.lean - Consolidated game state
-/

import Afferent.Render.FPSCamera
import Cairn.Core.Block
import Cairn.World.Types
import Cairn.World.World
import Cairn.Camera

namespace Cairn.State

open Afferent.Render
open Cairn.Core
open Cairn.World
open Cairn.Camera

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
  deriving Inhabited

namespace GameState

/-- Create initial game state with terrain configuration -/
def create (config : TerrainConfig) (renderDistance : Nat := 2) (startY : Float := 60.0) : IO GameState := do
  let now ← IO.monoMsNow
  return {
    camera := { defaultCamera with y := startY }
    world := World.empty config renderDistance
    lastTime := now
  }

end GameState

end Cairn.State
