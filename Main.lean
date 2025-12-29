/-
  Cairn - A Minecraft-style voxel game using Afferent
  Main entry point with game loop, FPS camera, and cube rendering
-/
import Afferent
import Cairn

open Afferent Afferent.FFI Afferent.Render
open Linalg

/-- macOS key codes for WASD + Q/E movement -/
def keyW : UInt16 := 13
def keyA : UInt16 := 0
def keyS : UInt16 := 1
def keyD : UInt16 := 2
def keyQ : UInt16 := 12  -- Down
def keyE : UInt16 := 14  -- Up
def keyEscape : UInt16 := 53

def main : IO Unit := do
  IO.println "Cairn - Voxel Game"
  IO.println "=================="
  IO.println "Controls:"
  IO.println "  WASD - Move horizontally"
  IO.println "  Q/E  - Move down/up"
  IO.println "  Mouse - Look around (when captured)"
  IO.println "  Click or Escape - Toggle mouse capture"
  IO.println ""

  -- Initialize FFI
  FFI.init

  -- Get screen scale for Retina displays
  let screenScale ← FFI.getScreenScale

  -- Window dimensions
  let baseWidth : Float := 1280.0
  let baseHeight : Float := 720.0
  let physWidth := (baseWidth * screenScale).toUInt32
  let physHeight := (baseHeight * screenScale).toUInt32

  -- Create window
  let mut canvas ← Canvas.create physWidth physHeight "Cairn"

  -- Initialize camera
  let mut camera := Cairn.Camera.defaultCamera

  -- Track time for delta calculation
  let mut lastTime ← IO.monoMsNow

  -- Main game loop
  while !(← canvas.shouldClose) do
    canvas.pollEvents

    -- Calculate delta time
    let now ← IO.monoMsNow
    let dt := (now - lastTime).toFloat / 1000.0
    lastTime := now

    -- Handle pointer lock (for FPS camera)
    let mut locked ← FFI.Window.getPointerLock canvas.ctx.window
    let hasKey ← canvas.hasKeyPressed
    if hasKey then
      let keyCode ← canvas.getKeyCode
      if keyCode == keyEscape then
        FFI.Window.setPointerLock canvas.ctx.window (!locked)
        locked := !locked
        canvas.clearKey

    -- Click to capture mouse
    if !locked then
      let click ← FFI.Window.getClick canvas.ctx.window
      match click with
      | some ce =>
        FFI.Window.clearClick canvas.ctx.window
        if ce.button == 0 then
          FFI.Window.setPointerLock canvas.ctx.window true
          locked := true
      | none => pure ()

    -- Check movement keys
    let wDown ← FFI.Window.isKeyDown canvas.ctx.window keyW
    let aDown ← FFI.Window.isKeyDown canvas.ctx.window keyA
    let sDown ← FFI.Window.isKeyDown canvas.ctx.window keyS
    let dDown ← FFI.Window.isKeyDown canvas.ctx.window keyD
    let qDown ← FFI.Window.isKeyDown canvas.ctx.window keyQ
    let eDown ← FFI.Window.isKeyDown canvas.ctx.window keyE

    -- Get mouse delta (only when pointer locked)
    let (dx, dy) ←
      if locked then
        FFI.Window.getMouseDelta canvas.ctx.window
      else
        pure (0.0, 0.0)

    -- Update camera
    camera := camera.update dt wDown sDown aDown dDown eDown qDown dx dy

    -- Begin frame with sky blue background
    let ok ← canvas.beginFrame (Color.rgba 0.5 0.7 1.0 1.0)

    if ok then
      -- Get current window size for aspect ratio
      let (currentW, currentH) ← canvas.ctx.getCurrentSize
      let aspect := currentW / currentH

      -- Setup projection and view matrices
      let proj := Mat4.perspective Cairn.Camera.fovY aspect Cairn.Camera.nearPlane Cairn.Camera.farPlane
      let view := camera.viewMatrix

      -- Light direction (from upper-right-front, normalized)
      let lightDir := #[0.5, 0.8, 0.3]
      let ambient := 0.4

      -- Draw a grid of cubes to test rendering
      for row in [:5] do
        for col in [:5] do
          let x := (col.toFloat - 2.0) * 2.0
          let z := (row.toFloat - 2.0) * 2.0
          let y := 0.0

          -- Model matrix: translate to position
          let model := Mat4.translation x y z

          -- MVP = projection * view * model
          let mvp := proj * view * model

          -- Draw the cube
          Renderer.drawMesh3D
            canvas.ctx.renderer
            Mesh.cubeVertices
            Mesh.cubeIndices
            mvp.toArray
            model.toArray
            lightDir
            ambient

      canvas ← canvas.endFrame

  -- Cleanup
  IO.println "Cleaning up..."
  canvas.destroy
  IO.println "Done!"
