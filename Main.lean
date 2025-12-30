/-
  Cairn - A Minecraft-style voxel game using Afferent
  Main entry point with game loop, FPS camera, and chunk-based terrain
-/
import Afferent
import Cairn

open Afferent Afferent.FFI Afferent.Render
open Linalg
open Cairn.Core
open Cairn.World
open Cairn.State
open Cairn.Input

def main : IO Unit := do
  IO.println "Cairn - Voxel Game"
  IO.println "=================="
  IO.println "Controls:"
  IO.println "  WASD - Move horizontally"
  IO.println "  Q/E  - Move down/up"
  IO.println "  Mouse - Look around (when captured)"
  IO.println "  Left click - Destroy block"
  IO.println "  Right click - Place stone block"
  IO.println "  Escape - Release mouse"
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

    -- Capture input state
    let input ← InputState.capture canvas.ctx.window

    -- Handle pointer lock toggle
    if input.escapePressed then
      FFI.Window.setPointerLock canvas.ctx.window (!input.pointerLocked)
      canvas.clearKey

    -- Click to capture mouse
    if !input.pointerLocked then
      match input.clickEvent with
      | some ce =>
        FFI.Window.clearClick canvas.ctx.window
        if ce.button == 0 then
          FFI.Window.setPointerLock canvas.ctx.window true
      | none => pure ()

    -- Update camera
    state := { state with
      camera := state.camera.update dt
        input.forward input.back input.left input.right
        input.up input.down input.mouseDeltaX input.mouseDeltaY
    }

    -- Handle block placement/destruction when pointer is locked
    if input.pointerLocked then
      match input.clickEvent with
      | some ce =>
        FFI.Window.clearClick canvas.ctx.window
        let (origin, dir) := cameraRay state.camera
        match raycast state.world origin dir 5.0 with  -- 5 block reach
        | some hit =>
          if ce.button == 0 then
            -- Left click: destroy block
            state := { state with world := state.world.setBlock hit.blockPos Block.air }
          else if ce.button == 1 then
            -- Right click: place stone block
            let placePos := hit.adjacentPos
            let targetBlock := state.world.getBlock placePos
            if !targetBlock.isSolid then
              state := { state with world := state.world.setBlock placePos Block.stone }
        | none => pure ()
      | none => pure ()

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
