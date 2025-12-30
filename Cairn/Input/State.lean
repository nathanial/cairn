/-
  Cairn/Input/State.lean - Input state capture
-/

import Afferent.FFI.Window
import Cairn.Input.Keys

namespace Cairn.Input

open Afferent.FFI

/-- Input state captured from a single frame -/
structure InputState where
  forward : Bool
  back : Bool
  left : Bool
  right : Bool
  up : Bool
  down : Bool
  jump : Bool           -- Space key for jumping
  mouseDeltaX : Float
  mouseDeltaY : Float
  escapePressed : Bool
  pointerLocked : Bool
  clickEvent : Option ClickEvent
  deriving Inhabited

namespace InputState

/-- Capture current input state from the window -/
def capture (window : Window) : IO InputState := do
  -- Movement keys
  let forward ← Window.isKeyDown window Keys.w
  let back ← Window.isKeyDown window Keys.s
  let left ← Window.isKeyDown window Keys.a
  let right ← Window.isKeyDown window Keys.d
  let up ← Window.isKeyDown window Keys.e
  let down ← Window.isKeyDown window Keys.q
  let jump ← Window.isKeyDown window Keys.space

  -- Mouse
  let pointerLocked ← Window.getPointerLock window
  let (mouseDeltaX, mouseDeltaY) ←
    if pointerLocked then Window.getMouseDelta window
    else pure (0.0, 0.0)

  -- Key press events
  let hasKey ← Window.hasKeyPressed window
  let escapePressed ←
    if hasKey then do
      let keyCode ← Window.getKeyCode window
      pure (keyCode == Keys.escape)
    else pure false

  -- Click events
  let clickEvent ← Window.getClick window

  return {
    forward, back, left, right, up, down, jump
    mouseDeltaX, mouseDeltaY
    escapePressed, pointerLocked, clickEvent
  }

/-- Clear consumed input events -/
def clearEvents (window : Window) (input : InputState) : IO Unit := do
  if input.escapePressed then
    Window.clearKey window
  if input.clickEvent.isSome then
    Window.clearClick window

end InputState

end Cairn.Input
