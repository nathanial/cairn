/-
  Cairn - A Minecraft-style voxel game using Afferent
  Main entry point with game loop, FPS camera, and chunk-based terrain
-/
import Afferent
import Cairn

open Afferent Afferent.FFI Afferent.Render
open Linalg
open Cairn.World
open Cairn.State

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

  -- Initialize game state
  let terrainConfig : TerrainConfig := {
    seed := 42
    seaLevel := 32
    baseHeight := 45
    heightScale := 25.0
    noiseScale := 0.015
    caveThreshold := 0.45
    caveScale := 0.05
  }

  let mut state ← GameState.create terrainConfig

  IO.println s!"Generating initial terrain..."

  -- Main game loop
  while !(← canvas.shouldClose) do
    canvas.pollEvents

    -- Calculate delta time
    let now ← IO.monoMsNow
    let dt := (now - state.lastTime).toFloat / 1000.0
    state := { state with lastTime := now }

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
    state := { state with camera := state.camera.update dt wDown sDown aDown dDown eDown qDown dx dy }

    -- Update world chunks based on camera position
    let playerX := state.camera.x.floor.toInt64.toInt
    let playerZ := state.camera.z.floor.toInt64.toInt
    state := { state with world := state.world.loadChunksAround playerX playerZ }

    -- Begin frame with sky blue background
    let ok ← canvas.beginFrame (Color.rgba 0.5 0.7 1.0 1.0)

    if ok then
      -- Get current window size for aspect ratio
      let (currentW, currentH) ← canvas.ctx.getCurrentSize
      let aspect := currentW / currentH

      -- Setup projection and view matrices
      let proj := Mat4.perspective Cairn.Camera.fovY aspect Cairn.Camera.nearPlane Cairn.Camera.farPlane
      let view := state.camera.viewMatrix

      -- Light direction (from upper-right-front, normalized)
      let lightDir := #[0.5, 0.8, 0.3]
      let ambient := 0.4

      -- Render all chunk meshes
      for (_, mesh) in state.world.getMeshes do
        if mesh.indexCount > 0 then
          -- Model matrix is identity (world positions already in vertices)
          let model := Mat4.identity
          let mvp := proj * view * model

          Renderer.drawMesh3D
            canvas.ctx.renderer
            mesh.vertices
            mesh.indices
            mvp.toArray
            model.toArray
            lightDir
            ambient

      canvas ← canvas.endFrame

  -- Cleanup
  IO.println "Cleaning up..."
  canvas.destroy
  IO.println "Done!"
