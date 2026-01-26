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
  IO.println "  WASD  - Move horizontally"
  IO.println "  Space - Jump"
  IO.println "  Mouse - Look around (when captured)"
  IO.println "  Left click - Destroy block"
  IO.println "  Right click - Place selected block"
  IO.println "  1-7 - Select block type"
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

  -- Load debug font
  let debugFont ← Afferent.Font.load "/System/Library/Fonts/Monaco.ttf" (14 * screenScale).toUInt32

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

    -- Hotbar blocks (keys 1-7)
    let hotbarBlocks : Array Block := #[
      Block.stone, Block.dirt, Block.grass, Block.sand, Block.wood, Block.leaves, Block.water
    ]

    -- Handle hotbar number key presses
    let hasKey ← FFI.Window.hasKeyPressed canvas.ctx.window
    if hasKey then
      let keyCode ← FFI.Window.getKeyCode canvas.ctx.window
      for i in [:hotbarBlocks.size] do
        if keyCode == Keys.hotbarKey i then
          if h : i < hotbarBlocks.size then
            state := { state with selectedBlock := hotbarBlocks[i] }
          canvas.clearKey

    -- Click to capture mouse
    if !input.pointerLocked then
      match input.clickEvent with
      | some ce =>
        FFI.Window.clearClick canvas.ctx.window
        if ce.button == 0 then
          FFI.Window.setPointerLock canvas.ctx.window true
      | none => pure ()

    -- Update look direction from mouse
    let yaw := state.camera.yaw + input.mouseDeltaX * state.camera.lookSensitivity
    let pitchClamp (v : Float) : Float :=
      if v < -Float.halfPi * 0.99 then -Float.halfPi * 0.99
      else if v > Float.halfPi * 0.99 then Float.halfPi * 0.99
      else v
    let pitch := pitchClamp (state.camera.pitch - input.mouseDeltaY * state.camera.lookSensitivity)
    state := { state with camera := { state.camera with yaw, pitch } }

    -- Update movement (fly mode or physics)
    if state.flyMode then
      let (newX, newY, newZ) := Cairn.Physics.updatePlayerFly
        state.camera.x state.camera.y state.camera.z yaw input dt
      state := { state with camera := { state.camera with x := newX, y := newY, z := newZ } }
    else
      let (newX, newY, newZ, newVx, newVy, newVz, nowGrounded) :=
        Cairn.Physics.updatePlayer state.world
          state.camera.x state.camera.y state.camera.z
          state.velocityX state.velocityY state.velocityZ state.isGrounded
          yaw input dt
      state := { state with
        camera := { state.camera with x := newX, y := newY, z := newZ }
        velocityX := newVx
        velocityY := newVy
        velocityZ := newVz
        isGrounded := nowGrounded
      }

    -- Raycast for block targeting (used for both actions and debug display)
    let raycastHit : Option RaycastHit :=
      if input.pointerLocked then
        let (origin, dir) := cameraRay state.camera
        raycast state.world origin dir 5.0  -- 5 block reach
      else
        none

    -- Handle block placement/destruction when pointer is locked
    if input.pointerLocked then
      match input.clickEvent with
      | some ce =>
        FFI.Window.clearClick canvas.ctx.window
        match raycastHit with
        | some hit =>
          if ce.button == 0 then
            -- Left click: destroy block
            state := { state with world := state.world.setBlock hit.blockPos Block.air }
          else if ce.button == 1 then
            -- Right click: place selected block
            let placePos := hit.adjacentPos
            let targetBlock := state.world.getBlock placePos
            if !targetBlock.isSolid then
              state := { state with world := state.world.setBlock placePos state.selectedBlock }
        | none => pure ()
      | none => pure ()

    -- Update world chunks based on camera position (fully async)
    let playerX := state.camera.x.floor.toInt64.toInt
    let playerZ := state.camera.z.floor.toInt64.toInt
    -- Request new chunks (spawns background terrain gen tasks)
    state.world.requestChunksAround playerX playerZ
    -- Integrate completed chunks from background tasks
    let world ← state.world.pollPendingChunks
    -- Request mesh generation (spawns background mesh gen tasks)
    world.requestMeshesAround playerX playerZ
    -- Integrate completed meshes from background tasks
    let world ← world.pollPendingMeshes
    state := { state with world }

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
            #[state.camera.x, state.camera.y, state.camera.z]  -- cameraPos
            #[0.5, 0.7, 1.0]  -- fogColor (sky blue)
            0.0 0.0  -- fogStart, fogEnd (0 to disable)

      -- Render block selection highlight
      match raycastHit with
      | some hit =>
        -- Helper to convert Int to Float
        let intToFloat (i : Int) : Float :=
          if i >= 0 then i.toNat.toFloat else -((-i).toNat.toFloat)
        -- Position highlight at block center
        let blockX := intToFloat hit.blockPos.x + 0.5
        let blockY := intToFloat hit.blockPos.y + 0.5
        let blockZ := intToFloat hit.blockPos.z + 0.5
        let highlightModel := Mat4.translation blockX blockY blockZ
        let highlightMVP := proj * view * highlightModel

        Renderer.drawMesh3D
          canvas.ctx.renderer
          Cairn.Mesh.highlightVertices
          Cairn.Mesh.highlightIndices
          highlightMVP.toArray
          highlightModel.toArray
          lightDir
          1.0  -- Full ambient for highlight (no shading)
          #[state.camera.x, state.camera.y, state.camera.z]  -- cameraPos
          #[0.5, 0.7, 1.0]  -- fogColor
          0.0 0.0  -- fogStart, fogEnd (disabled)
      | none => pure ()

      -- Debug text overlay
      let textColor := Color.white
      let startY := 50.0
      let lineHeight := 28.0

      -- Helper to format floats with 1 decimal place
      let fmt1 (f : Float) : String := s!"{(f * 10).floor / 10}"

      -- Position
      canvas.ctx.fillTextXY s!"Pos: ({fmt1 state.camera.x}, {fmt1 state.camera.y}, {fmt1 state.camera.z})" 10 startY debugFont textColor
      -- Look direction
      canvas.ctx.fillTextXY s!"Look: yaw={fmt1 state.camera.yaw} pitch={fmt1 state.camera.pitch}" 10 (startY + lineHeight) debugFont textColor
      -- Raycast hit
      match raycastHit with
      | some hit =>
        let block := state.world.getBlock hit.blockPos
        canvas.ctx.fillTextXY s!"Hit: ({hit.blockPos.x}, {hit.blockPos.y}, {hit.blockPos.z}) {repr hit.face}" 10 (startY + lineHeight * 2) debugFont textColor
        canvas.ctx.fillTextXY s!"Block: {repr block}" 10 (startY + lineHeight * 3) debugFont textColor
      | none =>
        canvas.ctx.fillTextXY "Hit: none" 10 (startY + lineHeight * 2) debugFont textColor
      -- Chunk info
      canvas.ctx.fillTextXY s!"Chunks: {state.world.chunks.size}" 10 (startY + lineHeight * 4) debugFont textColor
      -- Selected block
      canvas.ctx.fillTextXY s!"Selected: {repr state.selectedBlock}" 10 (startY + lineHeight * 5) debugFont textColor

      canvas ← canvas.endFrame

  -- Cleanup
  IO.println "Cleaning up..."
  debugFont.destroy
  canvas.destroy
  IO.println "Done!"
