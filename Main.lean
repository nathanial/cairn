/-
  Cairn - A Minecraft-style voxel game using Afferent
  Main entry point with game loop, FPS camera, and chunk-based terrain

  Uses Reactive FRP for state management:
  - SceneStates held in a Dynamic, updated via foldDynM
  - Game loop fires gameFrameTrigger each frame
  - Tab changes fire tabChangeTrigger
  - Voxel widget uses dynWidget for reactive rebuilding
-/
import Afferent
import Afferent.Widget
import Afferent.Canopy
import Afferent.Canopy.Reactive
import Afferent.Canopy.Widget.Layout.TabView
import Reactive
import Cairn
import Cairn.World.Async

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
  /-- Game frame trigger function (fires each frame with input + dt) -/
  fireGameFrame : GameFrameInput → IO Unit
  /-- Block select trigger function (fires when hotbar key pressed) -/
  fireBlockSelect : Block → IO Unit
  /-- World update trigger (fires after async chunk loading) -/
  fireWorldUpdate : World → IO Unit
  /-- Highlight position update trigger -/
  fireHighlightUpdate : Option (Int × Int × Int) → IO Unit
  /-- World loading worker pool handle -/
  worldLoader : WorldLoader
  /-- The reactive Dynamic holding all scene states -/
  sceneStatesDyn : Dynamic Spider SceneStates

/-- Clamp pitch to avoid gimbal lock -/
private def clampPitch (v : Float) : Float :=
  if v < -Float.halfPi * 0.99 then -Float.halfPi * 0.99
  else if v > Float.halfPi * 0.99 then Float.halfPi * 0.99
  else v

/-- Update camera look direction from mouse input -/
private def updateCameraLook (camera : FPSCamera) (input : InputState) : FPSCamera :=
  if input.pointerLocked then
    let yaw := camera.yaw + input.mouseDeltaX * camera.lookSensitivity
    let pitch := clampPitch (camera.pitch - input.mouseDeltaY * camera.lookSensitivity)
    { camera with yaw, pitch }
  else
    camera

/-- Apply frame update to the scene states (pure function for accumulation).
    Returns updated states. World loading is handled via FRP worker pool. -/
private def applyFrameUpdate (fi : GameFrameInput) (states : SceneStates) : SceneStates :=
  let input := fi.input
  let dt := fi.dt
  match states.activeMode with
  | .gameWorld =>
    let camera := updateCameraLook states.gameWorld.camera input
    let (newCamera, newVx, newVy, newVz, nowGrounded) :=
      if input.pointerLocked then
        let flyMode := states.gameWorld.flyMode
        if flyMode then
          let (newX, newY, newZ) := Cairn.Physics.updatePlayerFly camera.x camera.y camera.z camera.yaw input dt
          ({ camera with x := newX, y := newY, z := newZ }, states.velocityX, states.velocityY, states.velocityZ, states.isGrounded)
        else
          let (newX, newY, newZ, nextVx, nextVy, nextVz, nextGrounded) :=
            Cairn.Physics.updatePlayer states.gameWorld.world
              camera.x camera.y camera.z
              states.velocityX states.velocityY states.velocityZ states.isGrounded
              camera.yaw input dt
          ({ camera with x := newX, y := newY, z := newZ }, nextVx, nextVy, nextVz, nextGrounded)
      else
        (camera, states.velocityX, states.velocityY, states.velocityZ, states.isGrounded)

    let playerX := newCamera.x.floor.toInt64.toInt
    let playerZ := newCamera.z.floor.toInt64.toInt
    let currentChunk := World.blockToChunkPos playerX playerZ
    let (world', lastUnloadChunk') :=
      match states.lastUnloadChunk with
      | some lastChunk =>
        if lastChunk == currentChunk then
          (states.gameWorld.world, some lastChunk)
        else
          (World.unloadDistantChunks states.gameWorld.world playerX playerZ, some currentChunk)
      | none =>
        (World.unloadDistantChunks states.gameWorld.world playerX playerZ, some currentChunk)

    { states with
        gameWorld := { states.gameWorld with camera := newCamera, world := world' }
        velocityX := newVx
        velocityY := newVy
        velocityZ := newVz
        isGrounded := nowGrounded
        lastUnloadChunk := lastUnloadChunk'
    }
  | .solidChunk =>
    let camera := updateCameraLook states.solidChunk.camera input
    if input.pointerLocked then
      let (newX, newY, newZ) := Cairn.Physics.updatePlayerFly camera.x camera.y camera.z camera.yaw input dt
      let newCamera := { camera with x := newX, y := newY, z := newZ }
      { states with solidChunk := { states.solidChunk with camera := newCamera } }
    else
      { states with solidChunk := { states.solidChunk with camera := camera } }
  | .singleBlock =>
    let camera := updateCameraLook states.singleBlock.camera input
    if input.pointerLocked then
      let (newX, newY, newZ) := Cairn.Physics.updatePlayerFly camera.x camera.y camera.z camera.yaw input dt
      let newCamera := { camera with x := newX, y := newY, z := newZ }
      { states with singleBlock := { states.singleBlock with camera := newCamera } }
    else
      { states with singleBlock := { states.singleBlock with camera := camera } }
  | .terrainPreview =>
    let camera := updateCameraLook states.terrainPreview.camera input
    if input.pointerLocked then
      let (newX, newY, newZ) := Cairn.Physics.updatePlayerFly camera.x camera.y camera.z camera.yaw input dt
      let newCamera := { camera with x := newX, y := newY, z := newZ }
      { states with terrainPreview := { states.terrainPreview with camera := newCamera } }
    else
      { states with terrainPreview := { states.terrainPreview with camera := camera } }

/-- Apply a state update to the SceneStates (used with foldDynM) -/
private def applyUpdate (update : StateUpdate) (states : SceneStates) : IO SceneStates := do
  match update with
  | .frame fi => pure (applyFrameUpdate fi states)
  | .tabChange idx =>
    let newMode := SceneMode.fromTabIndex idx
    -- Clear highlight when switching away from game world
    let highlightPos := if newMode == .gameWorld then states.highlightPos else none
    pure { states with activeMode := newMode, highlightPos }
  | .selectBlock block => pure { states with selectedBlock := block }
  | .worldUpdate world =>
    -- Update the game world's World with newly loaded chunks/meshes
    pure { states with gameWorld := { states.gameWorld with world } }
  | .worldChunkReady pending =>
    let world := World.integratePendingChunk states.gameWorld.world pending
    pure { states with gameWorld := { states.gameWorld with world } }
  | .worldMeshReady pending =>
    let world := World.integratePendingMesh states.gameWorld.world pending
    pure { states with gameWorld := { states.gameWorld with world } }
  | .highlightUpdate pos => pure { states with highlightPos := pos }

/-- Name for the voxel scene widget (used for click detection) -/
def voxelSceneWidgetName : String := "voxel-scene"

/-- Create a voxel scene widget that samples the SceneStates Dynamic each frame.
    Uses the active mode to determine which scene state to render. -/
def voxelSceneWidgetFRP (statesDyn : Dynamic Spider SceneStates) (config : VoxelSceneConfig := {})
    : Afferent.Arbor.WidgetBuilder := do
  Afferent.Arbor.namedCustom voxelSceneWidgetName (spec := {
    measure := fun _ _ => (0, 0)
    collect := fun _ => #[]
    draw := some (fun layout => do
      -- Sample current states from the Dynamic in draw callback
      let states ← statesDyn.sample
      let currentState := states.getActiveState
      let highlightPos := states.highlightPos

      let rect := layout.contentRect
      Afferent.CanvasM.save
      Afferent.CanvasM.setBaseTransform (Transform.translate rect.x rect.y)
      Afferent.CanvasM.resetTransform
      Afferent.CanvasM.clip (Rect.mk' 0 0 rect.width rect.height)
      let renderer ← Afferent.CanvasM.getRenderer
      Cairn.Widget.renderVoxelSceneWithHighlight renderer rect.width rect.height currentState config highlightPos
      Afferent.CanvasM.restore
    )
    skipCache := true
  }) (style := BoxStyle.fill)

/-- Tab view variant that allows overriding layout dimensions. -/
private def tabViewWithDims (tabs : Array TabDef) (initialTab : Nat := 0)
    (dims : Afferent.Canopy.TabView.Dimensions := {}) : WidgetM TabViewResult := do
  let theme ← Afferent.Canopy.Reactive.getThemeW
  let containerName ← Afferent.Canopy.Reactive.registerComponentW "tabview" (isInteractive := false)

  let mut headerNames : Array String := #[]
  for _ in tabs do
    let name ← Afferent.Canopy.Reactive.registerComponentW "tab-header"
    headerNames := headerNames.push name
  let headerNameFn (i : Nat) : String := headerNames.getD i ""

  -- Pre-run all tab contents to get their renders
  let mut tabContentRenders : Array (Array ComponentRender) := #[]
  for tab in tabs do
    let (_, renders) ← Afferent.Canopy.Reactive.runWidgetChildren tab.content
    tabContentRenders := tabContentRenders.push renders

  let allClicks ← Afferent.Canopy.Reactive.useAllClicks

  let findClickedTab (data : Afferent.Canopy.Reactive.ClickData) : Option Nat :=
    (List.range tabs.size).findSome? fun i =>
      if Afferent.Canopy.Reactive.hitWidget data (headerNameFn i) then some i else none

  let tabChanges ← Event.mapMaybeM findClickedTab allClicks
  let activeTab ← Reactive.holdDyn initialTab tabChanges
  let onTabChange := tabChanges

  let hoverChanges ← StateT.lift (Afferent.Canopy.Reactive.hoverIndexEvent headerNames)
  let hoveredTab ← Reactive.holdDyn none hoverChanges

  let tabsRef := tabs

  -- Use dynWidget for efficient change-driven rebuilds
  let renderState ← Dynamic.zipWithM (fun a h => (a, h)) activeTab hoveredTab
  let _ ← dynWidget renderState fun (active, hovered) => do
    emit do
      let mut tabDefs : Array (String × Afferent.Arbor.WidgetBuilder) := #[]
      for i in [:tabsRef.size] do
        let tab := tabsRef[i]!
        let renders := tabContentRenders[i]!
        let contentWidgets ← renders.mapM id
        let contentStyle : BoxStyle := {
          flexItem := some (Trellis.FlexItem.growing 1)
          width := .percent 1.0
          height := .percent 1.0
        }
        let content := Afferent.Arbor.column (gap := 0) (style := contentStyle) contentWidgets
        tabDefs := tabDefs.push (tab.label, content)
      pure (Afferent.Canopy.tabViewVisual containerName headerNameFn tabDefs active hovered theme dims)

  pure { onTabChange, activeTab }

/-- Initialize Canopy FRP infrastructure with tab view and reactive state -/
def initCanopyWithTabs (fontRegistry : FontRegistry) (initialStates : SceneStates) : IO CanopyState := do
  -- Create SpiderEnv (keeps FRP network alive)
  let spiderEnv ← SpiderEnv.new Reactive.Host.defaultErrorHandler

  -- Run FRP setup within SpiderEnv
  let (events, inputs, render, fireTabChange, fireGameFrame, fireBlockSelect, fireWorldUpdate, fireHighlightUpdate, sceneStatesDyn, worldLoader) ← (do
    -- Create reactive event infrastructure
    let (events, inputs) ← createInputs fontRegistry Afferent.Canopy.Theme.dark none

    -- Create trigger events for external inputs
    let (tabChangeTrigger, fireTab) ← Reactive.newTriggerEvent
    let (gameFrameTrigger, fireFrame) ← Reactive.newTriggerEvent
    let (blockSelectTrigger, fireBlock) ← Reactive.newTriggerEvent
    let (worldUpdateTrigger, fireWorld) ← Reactive.newTriggerEvent
    let (worldChunkReadyTrigger, fireWorldChunkReady) ← Reactive.newTriggerEvent
    let (worldMeshReadyTrigger, fireWorldMeshReady) ← Reactive.newTriggerEvent
    let (highlightUpdateTrigger, fireHighlight) ← Reactive.newTriggerEvent
    let (worldCommandEvt, fireWorldCommand) ← Reactive.newTriggerEvent
      (t := Spider) (a := PoolCommand WorldJobId WorldJob)

    -- Map events to StateUpdate variants
    let frameUpdates ← Event.mapM StateUpdate.frame gameFrameTrigger
    let tabUpdates ← Event.mapM StateUpdate.tabChange tabChangeTrigger
    let blockUpdates ← Event.mapM StateUpdate.selectBlock blockSelectTrigger
    let worldUpdates ← Event.mapM StateUpdate.worldUpdate worldUpdateTrigger
    let worldChunkUpdates ← Event.mapM StateUpdate.worldChunkReady worldChunkReadyTrigger
    let worldMeshUpdates ← Event.mapM StateUpdate.worldMeshReady worldMeshReadyTrigger
    let highlightUpdates ← Event.mapM StateUpdate.highlightUpdate highlightUpdateTrigger

    -- Merge all update sources
    let allUpdates ← Event.leftmostM [
      frameUpdates,
      tabUpdates,
      blockUpdates,
      worldUpdates,
      worldChunkUpdates,
      worldMeshUpdates,
      highlightUpdates
    ]

    -- Create world loading worker pool
    let poolConfig : WorkerPoolConfig := { workerCount := 4 }
    let (poolOutput, poolHandle) ← WorkerPool.fromCommandsWithShutdown
      poolConfig
      processWorldJob
      worldCommandEvt

    -- Forward pool results to state updates
    let _ ← poolOutput.completed.subscribe fun (_, _, result) => do
      match result with
      | .chunk pending => fireWorldChunkReady pending
      | .mesh pending => fireWorldMeshReady pending

    -- Ignore duplicate job errors; log anything else
    let _ ← poolOutput.errored.subscribe fun (_id, msg) => do
      if msg != "duplicate job ID" then
        IO.eprintln s!"World loader error: {msg}"

    -- Build the main state Dynamic using foldDynM
    let statesDyn ← foldDynM (fun update state => applyUpdate update state) initialStates allUpdates

    -- Build widget tree using WidgetM
    let (_, render) ← Afferent.Canopy.Reactive.ReactiveM.run events do
      runWidget do
        let sceneContent : WidgetM Unit := do
          emit (pure (voxelSceneWidgetFRP statesDyn {}))

        -- Define tabs
        let tabs : Array TabDef := #[
          { label := "Game World", content := sceneContent },
          { label := "Solid Chunk", content := sceneContent },
          { label := "Single Block", content := sceneContent },
          { label := "Terrain Preview", content := sceneContent }
        ]

        -- Create tab view widget
        let tabResult ← tabViewWithDims tabs 0 (dims := { contentPadding := 0 })

        -- Subscribe to tab changes and fire to the trigger (which feeds foldDynM)
        let tabAction ← Event.mapM (fun tabIdx => do
          fireTab tabIdx
        ) tabResult.onTabChange
        performEvent_ tabAction


    let worldLoader : WorldLoader := { fireCommand := fireWorldCommand, poolHandle := poolHandle }
    pure (events, inputs, render, fireTab, fireFrame, fireBlock, fireWorld, fireHighlight, statesDyn, worldLoader)
  ).run spiderEnv

  -- Fire post-build event to finalize FRP network
  spiderEnv.postBuildTrigger ()

  pure {
    spiderEnv
    events
    inputs
    render
    fireTabChange := fireTabChange
    fireGameFrame := fireGameFrame
    fireBlockSelect := fireBlockSelect
    fireWorldUpdate := fireWorldUpdate
    fireHighlightUpdate := fireHighlightUpdate
    worldLoader := worldLoader
    sceneStatesDyn := sceneStatesDyn
  }

def main : IO Unit := do
  IO.println "Cairn - Voxel Game (FRP Edition)"
  IO.println "================================"
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
  let gameState ← GameState.create terrainConfig

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

  -- Build initial SceneStates (FRP replaces IO.Refs)
  let initialStates : SceneStates := {
    gameWorld := { camera := gameState.camera, world := gameState.world, flyMode := gameState.flyMode }
    solidChunk := { camera := solidChunkCamera, world := solidChunkWorld, flyMode := true }
    singleBlock := { camera := singleBlockCamera, world := singleBlockWorld, flyMode := true }
    terrainPreview := { camera := terrainPreviewCamera, world := terrainPreviewWorld, flyMode := true }
    activeMode := .gameWorld
    highlightPos := none
    selectedBlock := gameState.selectedBlock
    velocityX := 0.0
    velocityY := 0.0
    velocityZ := 0.0
    isGrounded := false
    lastUnloadChunk := some (World.blockToChunkPos
      gameState.camera.x.floor.toInt64.toInt
      gameState.camera.z.floor.toInt64.toInt)
  }

  -- Initialize Canopy FRP infrastructure with tabs
  let fontRegistry : FontRegistry := { fonts := #[debugFont] }
  let canopy ← initCanopyWithTabs fontRegistry initialStates

  -- Track last time for delta calculation
  let lastTimeRef ← IO.mkRef (← IO.monoMsNow)

  IO.println s!"Generating initial terrain..."

  -- Hotbar blocks (keys 1-7)
  let hotbarBlocks : Array Block := #[
    Block.stone, Block.dirt, Block.grass, Block.sand, Block.wood, Block.leaves, Block.water
  ]

  -- Main game loop
  while !(← canvas.shouldClose) do
    canvas.pollEvents

    -- Calculate delta time
    let now ← IO.monoMsNow
    let lastTime ← lastTimeRef.get
    let dt := (now - lastTime).toFloat / 1000.0
    lastTimeRef.set now

    -- Capture input state
    let input ← InputState.capture canvas.ctx.window

    -- Handle pointer lock toggle (escape key)
    if input.escapePressed then
      FFI.Window.setPointerLock canvas.ctx.window (!input.pointerLocked)
      canvas.clearKey

    -- Handle hotbar number key presses - fire block select event
    let hasKey ← FFI.Window.hasKeyPressed canvas.ctx.window
    if hasKey then
      let keyCode ← FFI.Window.getKeyCode canvas.ctx.window
      for i in [:hotbarBlocks.size] do
        if keyCode == Keys.hotbarKey i then
          if h : i < hotbarBlocks.size then
            canopy.fireBlockSelect hotbarBlocks[i]
          canvas.clearKey

    -- Fire game frame event with input and dt (this drives all state updates via foldDynM)
    canopy.fireGameFrame { input, dt }

    -- Sample current state to handle IO operations that can't be in pure update
    let states ← canopy.sceneStatesDyn.sample

    -- Handle game world specific IO operations (async chunk loading, block interaction)
    if states.activeMode == .gameWorld then
      -- Raycast for block targeting (needs current world state)
      let raycastHit : Option RaycastHit :=
        if input.pointerLocked then
          let (origin, dir) := cameraRay states.gameWorld.camera
          raycast states.gameWorld.world origin dir 5.0
        else
          none

      -- Update highlight position via FRP
      let highlightPos := raycastHit.map fun hit => (hit.blockPos.x, hit.blockPos.y, hit.blockPos.z)
      canopy.fireHighlightUpdate highlightPos

      -- Handle block placement/destruction when pointer is locked
      if input.pointerLocked then
        match input.clickEvent with
        | some ce =>
          FFI.Window.clearClick canvas.ctx.window
          match raycastHit with
          | some hit =>
            -- Block modifications - update world and fire to FRP
            let world := if ce.button == 0 then
              states.gameWorld.world.setBlock hit.blockPos Block.air
            else if ce.button == 1 then
              let placePos := hit.adjacentPos
              let targetBlock := states.gameWorld.world.getBlock placePos
              if !targetBlock.isSolid then
                states.gameWorld.world.setBlock placePos states.selectedBlock
              else
                states.gameWorld.world
            else
              states.gameWorld.world
            canopy.fireWorldUpdate world
          | none => pure ()
        | none => pure ()

      -- Update world chunks based on camera position (fully async)
      let playerX := states.gameWorld.camera.x.floor.toInt64.toInt
      let playerZ := states.gameWorld.camera.z.floor.toInt64.toInt
      canopy.worldLoader.requestAround states.gameWorld.world playerX playerZ
    else
      -- Clear highlight when not in game world mode
      canopy.fireHighlightUpdate none

    -- Begin frame with dark gray background (match afferent-demos)
    let ok ← canvas.beginFrame Color.darkGray

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

      -- Debug text overlay (sample state again after FRP propagation)
      let states ← canopy.sceneStatesDyn.sample
      let textColor := Color.white
      let lineHeight := 28.0
      -- Position at bottom left (7 lines max, plus margin)
      let startY := currentH - (7 * lineHeight) - 20.0

      -- Helper to format floats with 1 decimal place
      let fmt1 (f : Float) : String := s!"{(f * 10).floor / 10}"

      -- Get current camera for display based on mode
      let (displayCamera, displayMode) := match states.activeMode with
        | .gameWorld => (states.gameWorld.camera, "Game World")
        | .solidChunk => (states.solidChunk.camera, "Solid Chunk")
        | .singleBlock => (states.singleBlock.camera, "Single Block")
        | .terrainPreview => (states.terrainPreview.camera, "Terrain Preview")

      -- Mode indicator
      canvas.ctx.fillTextXY s!"Mode: {displayMode}" 10 startY debugFont textColor
      -- Position
      canvas.ctx.fillTextXY s!"Pos: ({fmt1 displayCamera.x}, {fmt1 displayCamera.y}, {fmt1 displayCamera.z})" 10 (startY + lineHeight) debugFont textColor
      -- Look direction
      canvas.ctx.fillTextXY s!"Look: yaw={fmt1 displayCamera.yaw} pitch={fmt1 displayCamera.pitch}" 10 (startY + lineHeight * 2) debugFont textColor

      -- Game-world specific info
      if states.activeMode == .gameWorld then
        let raycastHit : Option RaycastHit :=
          if input.pointerLocked then
            let (origin, dir) := cameraRay states.gameWorld.camera
            raycast states.gameWorld.world origin dir 5.0
          else none
        match raycastHit with
        | some hit =>
          let block := states.gameWorld.world.getBlock hit.blockPos
          canvas.ctx.fillTextXY s!"Hit: ({hit.blockPos.x}, {hit.blockPos.y}, {hit.blockPos.z}) {repr hit.face}" 10 (startY + lineHeight * 3) debugFont textColor
          canvas.ctx.fillTextXY s!"Block: {repr block}" 10 (startY + lineHeight * 4) debugFont textColor
        | none =>
          canvas.ctx.fillTextXY "Hit: none" 10 (startY + lineHeight * 3) debugFont textColor
        canvas.ctx.fillTextXY s!"Chunks: {states.gameWorld.world.chunks.size}" 10 (startY + lineHeight * 5) debugFont textColor
        canvas.ctx.fillTextXY s!"Selected: {repr states.selectedBlock}" 10 (startY + lineHeight * 6) debugFont textColor

      canvas ← canvas.endFrame

  -- Cleanup
  IO.println "Cleaning up..."
  canopy.worldLoader.poolHandle.shutdown
  debugFont.destroy
  canvas.destroy
  IO.println "Done!"
