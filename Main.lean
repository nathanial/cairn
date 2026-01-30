/-
  Cairn - A Minecraft-style voxel game using Afferent
  Main entry point with game loop, FPS camera, and chunk-based terrain
-/
import Afferent
import Afferent.Widget
import Afferent.Canopy
import Afferent.Canopy.Reactive
import Afferent.Canopy.Widget.Layout.TabView
import Reactive
import Cairn

open Afferent Afferent.FFI Afferent.Render
open Afferent.Arbor (build BoxStyle)
open Afferent.Widget (renderArborWidgetWithCustom)
open Afferent.Canopy (TabDef TabViewResult tabView)
open Afferent.Canopy.Reactive (ReactiveEvents ReactiveInputs createInputs runWidget ComponentRender
  WidgetM emit column' row' dynWidget)
open Reactive
open Reactive.Host
open Linalg
open Cairn.Core
open Cairn.World
open Cairn.State
open Cairn.Input
open Cairn.Widget
open Cairn.Scene

/-- State refs for all scene modes -/
structure SceneRefs where
  /-- Game world state (full interactive mode) -/
  gameWorldRef : IO.Ref VoxelSceneState
  /-- Solid chunk preview state -/
  solidChunkRef : IO.Ref VoxelSceneState
  /-- Single block preview state -/
  singleBlockRef : IO.Ref VoxelSceneState
  /-- Terrain preview state -/
  terrainPreviewRef : IO.Ref VoxelSceneState
  /-- Currently active scene mode -/
  activeModeRef : IO.Ref SceneMode
  /-- Block highlight position (game world only) -/
  highlightRef : IO.Ref (Option (Int × Int × Int))

/-- Canopy FRP state that persists across frames -/
structure CanopyState where
  /-- The Spider environment (keeps FRP network alive) -/
  spiderEnv : SpiderEnv
  /-- Reactive event streams for widget subscriptions -/
  events : ReactiveEvents
  /-- Trigger functions to fire input events -/
  inputs : ReactiveInputs
  /-- Render function that samples all dynamics and returns widget tree -/
  render : ComponentRender
  /-- Tab change trigger function -/
  fireTabChange : Nat → IO Unit

/-- Name for the voxel scene widget (used for click detection) -/
def voxelSceneWidgetName : String := "voxel-scene"

/-- Create a voxel scene widget that reads from a ref based on active mode.
    The active mode is checked in the draw callback so it updates each frame. -/
def voxelSceneWidgetForMode (refs : SceneRefs) (config : VoxelSceneConfig := {}) : Afferent.Arbor.WidgetBuilder := do
  Afferent.Arbor.namedCustom voxelSceneWidgetName (spec := {
    measure := fun _ _ => (0, 0)
    collect := fun _ => #[]
    draw := some (fun layout => do
      -- Sample current mode and state from refs in draw callback
      let mode ← refs.activeModeRef.get
      let stateRef := match mode with
        | .gameWorld => refs.gameWorldRef
        | .solidChunk => refs.solidChunkRef
        | .singleBlock => refs.singleBlockRef
        | .terrainPreview => refs.terrainPreviewRef
      let state ← stateRef.get
      let highlightPos ← refs.highlightRef.get

      let rect := layout.contentRect
      Afferent.CanvasM.save
      Afferent.CanvasM.setBaseTransform (Transform.translate rect.x rect.y)
      Afferent.CanvasM.resetTransform
      Afferent.CanvasM.clip (Rect.mk' 0 0 rect.width rect.height)
      let renderer ← Afferent.CanvasM.getRenderer
      Cairn.Widget.renderVoxelSceneWithHighlight renderer rect.width rect.height state config highlightPos
      Afferent.CanvasM.restore
    )
    skipCache := true
  }) (style := BoxStyle.fill)

/-- Initialize Canopy FRP infrastructure with tab view -/
def initCanopyWithTabs (fontRegistry : FontRegistry) (refs : SceneRefs) : IO CanopyState := do
  -- Create SpiderEnv (keeps FRP network alive)
  let spiderEnv ← SpiderEnv.new Reactive.Host.defaultErrorHandler

  -- Run FRP setup within SpiderEnv
  let (events, inputs, render, fireTabChange) ← (do
    -- Create reactive event infrastructure
    let (events, inputs) ← createInputs fontRegistry Afferent.Canopy.Theme.dark none

    -- Create a trigger event for tab changes from outside FRP
    let (tabChangeTrigger, fireTab) ← Reactive.newTriggerEvent

    -- Build widget tree using WidgetM
    let (_, render) ← Afferent.Canopy.Reactive.ReactiveM.run events do
      runWidget do
        -- Define tabs
        let tabs : Array TabDef := #[
          { label := "Game World", content := pure () },
          { label := "Solid Chunk", content := pure () },
          { label := "Single Block", content := pure () },
          { label := "Terrain Preview", content := pure () }
        ]

        -- Create tab view widget
        let tabResult ← tabView tabs 0

        -- Subscribe to tab changes and update active mode ref
        let tabAction ← Event.mapM (fun tabIdx => do
          let mode := SceneMode.fromTabIndex tabIdx
          refs.activeModeRef.set mode
        ) tabResult.onTabChange
        performEvent_ tabAction

        -- Also handle external tab change triggers (for keyboard shortcuts etc)
        let externalTabAction ← Event.mapM (fun tabIdx => do
          let mode := SceneMode.fromTabIndex tabIdx
          refs.activeModeRef.set mode
        ) tabChangeTrigger
        performEvent_ externalTabAction

        -- Emit the voxel scene widget that reads from active mode's ref
        emit (pure (voxelSceneWidgetForMode refs {}))


    pure (events, inputs, render, fireTab)
  ).run spiderEnv

  -- Fire post-build event to finalize FRP network
  spiderEnv.postBuildTrigger ()

  pure { spiderEnv, events, inputs, render, fireTabChange }

def main : IO Unit := do
  IO.println "Cairn - Voxel Game"
  IO.println "=================="
  IO.println "Controls:"
  IO.println "  WASD  - Move horizontally (Game World mode)"
  IO.println "  Space - Jump (Game World mode)"
  IO.println "  Mouse - Look around / Orbit camera"
  IO.println "  Left click - Destroy block (Game World mode)"
  IO.println "  Right click - Place selected block (Game World mode)"
  IO.println "  1-7 - Select block type"
  IO.println "  Escape - Release mouse"
  IO.println "  Tab - Switch scene modes"
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

  -- Initialize terrain config for game world
  let terrainConfig : TerrainConfig := {
    seed := 42
    seaLevel := 32
    baseHeight := 45
    heightScale := 25.0
    noiseScale := 0.015
    caveThreshold := 0.45
    caveScale := 0.05
  }

  -- Initialize game state for game world
  let mut gameState ← GameState.create terrainConfig

  IO.println "Creating scene worlds..."

  -- Create worlds for each scene mode
  let solidChunkWorld ← createSolidChunkWorld
  let singleBlockWorld ← createSingleBlockWorld
  let terrainPreviewWorld ← createTerrainPreviewWorld terrainConfig

  IO.println "Worlds created."

  -- Create FPS cameras for each static scene with good starting positions
  -- Solid chunk: 16x16x16 cube from y=56 to y=71, centered at (8, 64, 8)
  let solidChunkCamera : FPSCamera := {
    x := 30.0, y := 70.0, z := 30.0  -- Far corner looking toward cube
    yaw := -2.4, pitch := -0.3       -- Looking toward center
    moveSpeed := 10.0, lookSensitivity := 0.003
  }
  -- Single block: block at (8, 64, 8)
  let singleBlockCamera : FPSCamera := {
    x := 12.0, y := 66.0, z := 12.0  -- Close to block
    yaw := -2.4, pitch := -0.2
    moveSpeed := 5.0, lookSensitivity := 0.003
  }
  -- Terrain preview: terrain chunk at origin
  let terrainPreviewCamera : FPSCamera := {
    x := 40.0, y := 80.0, z := 40.0  -- High up to see terrain
    yaw := -2.4, pitch := -0.4       -- Looking down at terrain
    moveSpeed := 15.0, lookSensitivity := 0.003
  }

  -- Create refs for each scene mode
  let gameWorldRef ← IO.mkRef (VoxelSceneState.mk gameState.camera gameState.world gameState.flyMode)
  let solidChunkRef ← IO.mkRef (VoxelSceneState.mk solidChunkCamera solidChunkWorld true)
  let singleBlockRef ← IO.mkRef (VoxelSceneState.mk singleBlockCamera singleBlockWorld true)
  let terrainPreviewRef ← IO.mkRef (VoxelSceneState.mk terrainPreviewCamera terrainPreviewWorld true)

  -- Active mode and highlight refs
  let activeModeRef ← IO.mkRef SceneMode.gameWorld
  let highlightRef ← IO.mkRef (none : Option (Int × Int × Int))

  let refs : SceneRefs := {
    gameWorldRef, solidChunkRef, singleBlockRef, terrainPreviewRef
    activeModeRef, highlightRef
  }

  -- Initialize Canopy FRP infrastructure with tabs
  let fontRegistry : FontRegistry := { fonts := #[debugFont] }
  let canopy ← initCanopyWithTabs fontRegistry refs

  IO.println s!"Generating initial terrain..."

  -- Main game loop
  while !(← canvas.shouldClose) do
    canvas.pollEvents

    -- Calculate delta time
    let now ← IO.monoMsNow
    let dt := (now - gameState.lastTime).toFloat / 1000.0
    gameState := { gameState with lastTime := now }

    -- Capture input state
    let input ← InputState.capture canvas.ctx.window

    -- Get current active mode
    let activeMode ← activeModeRef.get

    -- Handle pointer lock toggle
    if input.escapePressed then
      FFI.Window.setPointerLock canvas.ctx.window (!input.pointerLocked)
      canvas.clearKey

    -- Hotbar blocks (keys 1-7) - only in game mode
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
            gameState := { gameState with selectedBlock := hotbarBlocks[i] }
          canvas.clearKey

    -- Mode-specific updates
    match activeMode with
    | .gameWorld =>
      -- Full game mode: WASD movement, block interaction
      -- (pointer capture is handled via Canopy click events on the voxel scene widget)

      -- Update look direction from mouse when pointer locked
      if input.pointerLocked then
        let yaw := gameState.camera.yaw + input.mouseDeltaX * gameState.camera.lookSensitivity
        let pitchClamp (v : Float) : Float :=
          if v < -Float.halfPi * 0.99 then -Float.halfPi * 0.99
          else if v > Float.halfPi * 0.99 then Float.halfPi * 0.99
          else v
        let pitch := pitchClamp (gameState.camera.pitch - input.mouseDeltaY * gameState.camera.lookSensitivity)
        gameState := { gameState with camera := { gameState.camera with yaw, pitch } }

        -- Update movement (fly mode or physics)
        if gameState.flyMode then
          let (newX, newY, newZ) := Cairn.Physics.updatePlayerFly
            gameState.camera.x gameState.camera.y gameState.camera.z yaw input dt
          gameState := { gameState with camera := { gameState.camera with x := newX, y := newY, z := newZ } }
        else
          let (newX, newY, newZ, newVx, newVy, newVz, nowGrounded) :=
            Cairn.Physics.updatePlayer gameState.world
              gameState.camera.x gameState.camera.y gameState.camera.z
              gameState.velocityX gameState.velocityY gameState.velocityZ gameState.isGrounded
              yaw input dt
          gameState := { gameState with
            camera := { gameState.camera with x := newX, y := newY, z := newZ }
            velocityX := newVx
            velocityY := newVy
            velocityZ := newVz
            isGrounded := nowGrounded
          }

      -- Raycast for block targeting
      let raycastHit : Option RaycastHit :=
        if input.pointerLocked then
          let (origin, dir) := cameraRay gameState.camera
          raycast gameState.world origin dir 5.0
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
              gameState := { gameState with world := gameState.world.setBlock hit.blockPos Block.air }
            else if ce.button == 1 then
              let placePos := hit.adjacentPos
              let targetBlock := gameState.world.getBlock placePos
              if !targetBlock.isSolid then
                gameState := { gameState with world := gameState.world.setBlock placePos gameState.selectedBlock }
          | none => pure ()
        | none => pure ()

      -- Update world chunks based on camera position (fully async)
      let playerX := gameState.camera.x.floor.toInt64.toInt
      let playerZ := gameState.camera.z.floor.toInt64.toInt
      gameState.world.requestChunksAround playerX playerZ
      let world ← gameState.world.pollPendingChunks
      world.requestMeshesAround playerX playerZ
      let world ← world.pollPendingMeshes
      gameState := { gameState with world }

      -- Update refs for widget
      gameWorldRef.set { camera := gameState.camera, world := gameState.world, flyMode := gameState.flyMode }
      highlightRef.set (raycastHit.map fun hit => (hit.blockPos.x, hit.blockPos.y, hit.blockPos.z))

    | .solidChunk =>
      -- FPS camera mode: WASD movement, mouse look, no block interaction
      highlightRef.set none
      if input.pointerLocked then
        let state ← solidChunkRef.get
        let camera := state.camera
        -- Update look direction
        let yaw := camera.yaw + input.mouseDeltaX * camera.lookSensitivity
        let pitchClamp (v : Float) : Float :=
          if v < -Float.halfPi * 0.99 then -Float.halfPi * 0.99
          else if v > Float.halfPi * 0.99 then Float.halfPi * 0.99
          else v
        let pitch := pitchClamp (camera.pitch - input.mouseDeltaY * camera.lookSensitivity)
        -- Use same fly movement as game mode
        let (newX, newY, newZ) := Cairn.Physics.updatePlayerFly camera.x camera.y camera.z yaw input dt
        solidChunkRef.set { state with camera := { camera with x := newX, y := newY, z := newZ, yaw, pitch } }

    | .singleBlock =>
      highlightRef.set none
      if input.pointerLocked then
        let state ← singleBlockRef.get
        let camera := state.camera
        let yaw := camera.yaw + input.mouseDeltaX * camera.lookSensitivity
        let pitchClamp (v : Float) : Float :=
          if v < -Float.halfPi * 0.99 then -Float.halfPi * 0.99
          else if v > Float.halfPi * 0.99 then Float.halfPi * 0.99
          else v
        let pitch := pitchClamp (camera.pitch - input.mouseDeltaY * camera.lookSensitivity)
        let (newX, newY, newZ) := Cairn.Physics.updatePlayerFly camera.x camera.y camera.z yaw input dt
        singleBlockRef.set { state with camera := { camera with x := newX, y := newY, z := newZ, yaw, pitch } }

    | .terrainPreview =>
      highlightRef.set none
      if input.pointerLocked then
        let state ← terrainPreviewRef.get
        let camera := state.camera
        let yaw := camera.yaw + input.mouseDeltaX * camera.lookSensitivity
        let pitchClamp (v : Float) : Float :=
          if v < -Float.halfPi * 0.99 then -Float.halfPi * 0.99
          else if v > Float.halfPi * 0.99 then Float.halfPi * 0.99
          else v
        let pitch := pitchClamp (camera.pitch - input.mouseDeltaY * camera.lookSensitivity)
        let (newX, newY, newZ) := Cairn.Physics.updatePlayerFly camera.x camera.y camera.z yaw input dt
        terrainPreviewRef.set { state with camera := { camera with x := newX, y := newY, z := newZ, yaw, pitch } }

    -- Begin frame with sky blue background
    let ok ← canvas.beginFrame (Color.rgba 0.5 0.7 1.0 1.0)

    if ok then
      -- Get current window size for aspect ratio
      let (currentW, currentH) ← canvas.ctx.getCurrentSize

      -- Build Canopy widget tree
      let widgetBuilder ← canopy.render
      let widget := build widgetBuilder

      -- Measure and layout widget tree (needed for click hit testing)
      -- Use runWithFonts to provide TextMeasurer instance for measureWidget
      let measureResult ← runWithFonts fontRegistry
        (Afferent.Arbor.measureWidget widget currentW currentH)
      let layoutNode := measureResult.node
      let measuredWidget := measureResult.widget
      let layouts := Trellis.layout layoutNode currentW currentH

      -- Build hit test index for efficient click detection
      let hitIndex := Afferent.Arbor.buildHitTestIndex measuredWidget layouts

      -- Handle click events - route to Canopy for tab handling
      match input.clickEvent with
      | some ce =>
        -- Get hit path for the click
        let hitPath := Afferent.Arbor.hitTestPathIndexed hitIndex ce.x ce.y

        -- Fire click to Canopy so tabs can process it
        let clickData : Afferent.Canopy.Reactive.ClickData := {
          click := ce
          hitPath := hitPath
          widget := measuredWidget
          layouts := layouts
          nameMap := hitIndex.nameMap  -- Use nameMap from hit test index
        }
        canopy.inputs.fireClick clickData

        -- Capture pointer only if clicking on the voxel scene widget
        -- Look up the voxel scene widget by name and check if it's in the hit path
        let voxelSceneClicked := match hitIndex.nameMap.get? voxelSceneWidgetName with
          | some voxelSceneId => hitPath.any (· == voxelSceneId)
          | none => false
        if !input.pointerLocked && voxelSceneClicked then
          FFI.Window.setPointerLock canvas.ctx.window true

        FFI.Window.clearClick canvas.ctx.window
      | none => pure ()

      -- Fire animation frame event (propagates FRP network after click handling)
      canopy.inputs.fireAnimationFrame dt

      -- Render the widget tree
      let renderCommands ← Afferent.Arbor.collectCommandsCached canvas.renderCache measuredWidget layouts
      canvas ← CanvasM.run' canvas (Afferent.Widget.executeCommandsBatched fontRegistry renderCommands)
      canvas ← CanvasM.run' canvas (Afferent.Widget.renderCustomWidgets measuredWidget layouts)

      -- Debug text overlay
      let textColor := Color.white
      let startY := 50.0
      let lineHeight := 28.0

      -- Helper to format floats with 1 decimal place
      let fmt1 (f : Float) : String := s!"{(f * 10).floor / 10}"

      -- Get current camera for display based on mode
      let (displayCamera, displayMode) ← do
        match activeMode with
        | .gameWorld => pure (gameState.camera, "Game World")
        | .solidChunk =>
          let state ← solidChunkRef.get
          pure (state.camera, "Solid Chunk")
        | .singleBlock =>
          let state ← singleBlockRef.get
          pure (state.camera, "Single Block")
        | .terrainPreview =>
          let state ← terrainPreviewRef.get
          pure (state.camera, "Terrain Preview")

      -- Mode indicator
      canvas.ctx.fillTextXY s!"Mode: {displayMode}" 10 startY debugFont textColor
      -- Position
      canvas.ctx.fillTextXY s!"Pos: ({fmt1 displayCamera.x}, {fmt1 displayCamera.y}, {fmt1 displayCamera.z})" 10 (startY + lineHeight) debugFont textColor
      -- Look direction
      canvas.ctx.fillTextXY s!"Look: yaw={fmt1 displayCamera.yaw} pitch={fmt1 displayCamera.pitch}" 10 (startY + lineHeight * 2) debugFont textColor

      -- Game-world specific info
      if activeMode == .gameWorld then
        let raycastHit : Option RaycastHit :=
          if input.pointerLocked then
            let (origin, dir) := cameraRay gameState.camera
            raycast gameState.world origin dir 5.0
          else none
        match raycastHit with
        | some hit =>
          let block := gameState.world.getBlock hit.blockPos
          canvas.ctx.fillTextXY s!"Hit: ({hit.blockPos.x}, {hit.blockPos.y}, {hit.blockPos.z}) {repr hit.face}" 10 (startY + lineHeight * 3) debugFont textColor
          canvas.ctx.fillTextXY s!"Block: {repr block}" 10 (startY + lineHeight * 4) debugFont textColor
        | none =>
          canvas.ctx.fillTextXY "Hit: none" 10 (startY + lineHeight * 3) debugFont textColor
        canvas.ctx.fillTextXY s!"Chunks: {gameState.world.chunks.size}" 10 (startY + lineHeight * 5) debugFont textColor
        canvas.ctx.fillTextXY s!"Selected: {repr gameState.selectedBlock}" 10 (startY + lineHeight * 6) debugFont textColor

      canvas ← canvas.endFrame

  -- Cleanup
  IO.println "Cleaning up..."
  debugFont.destroy
  canvas.destroy
  IO.println "Done!"
