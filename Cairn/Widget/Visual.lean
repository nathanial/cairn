/-
  Cairn/Widget/Visual.lean - Arbor widget builder for 3D voxel scene
-/

import Afferent
import Afferent.Arbor
import Trellis
import Cairn.Widget.Core
import Cairn.Widget.Render

namespace Cairn.Widget

open Afferent Afferent.Arbor Afferent.FFI
open CanvasM

/-- Helper to set up clipping and transform for content rect rendering -/
private def withContentRect (layout : Trellis.ComputedLayout)
    (draw : Float → Float → CanvasM Unit) : CanvasM Unit := do
  let rect := layout.contentRect
  save
  setBaseTransform (Transform.translate rect.x rect.y)
  resetTransform
  clip (Rect.mk' 0 0 rect.width rect.height)
  draw rect.width rect.height
  restore

/-- Create a voxel scene widget that renders 3D voxels.

    This widget follows the Seascape demo pattern:
    - Uses `CustomSpec.draw` callback for 3D rendering via `getRenderer`
    - State is passed in, managed externally via `IO.Ref`
    - Widget fills available space via `BoxStyle.growFill`

    Example usage:
    ```lean
    let stateRef ← IO.mkRef initialState
    -- In render loop:
    let state ← stateRef.get
    let widget := voxelSceneWidget state config
    -- After rendering, update state:
    let newState ← updateVoxelSceneState window state dt
    stateRef.set newState
    ```
-/
def voxelSceneWidget (state : VoxelSceneState)
    (config : VoxelSceneConfig := {}) : WidgetBuilder := do
  Arbor.custom (spec := {
    measure := fun _ _ => (0, 0)
    collect := fun _ => #[]
    draw := some (fun layout => do
      withContentRect layout fun w h => do
        let renderer ← getRenderer
        renderVoxelScene renderer w h state config
    )
    skipCache := true  -- 3D scene changes every frame
  }) (style := BoxStyle.fill)

/-- Create a voxel scene widget with block highlight overlay.

    Same as `voxelSceneWidget` but with optional block selection highlight.
-/
def voxelSceneWidgetWithHighlight (state : VoxelSceneState)
    (config : VoxelSceneConfig := {})
    (highlightPos : Option (Int × Int × Int) := none) : WidgetBuilder := do
  Arbor.custom (spec := {
    measure := fun _ _ => (0, 0)
    collect := fun _ => #[]
    draw := some (fun layout => do
      withContentRect layout fun w h => do
        let renderer ← getRenderer
        renderVoxelSceneWithHighlight renderer w h state config highlightPos
    )
    skipCache := true
  }) (style := BoxStyle.fill)

/-- Create a voxel scene widget with custom style.

    Allows overriding the default `BoxStyle.growFill` for custom layouts.
-/
def voxelSceneWidgetStyled (state : VoxelSceneState)
    (config : VoxelSceneConfig := {})
    (style : BoxStyle := BoxStyle.growFill) : WidgetBuilder := do
  Arbor.custom (spec := {
    measure := fun _ _ => (0, 0)
    collect := fun _ => #[]
    draw := some (fun layout => do
      withContentRect layout fun w h => do
        let renderer ← getRenderer
        renderVoxelScene renderer w h state config
    )
    skipCache := true
  }) (style := style)

/-- Create a voxel scene widget that reads state from an IO.Ref.
    This is designed for use with Canopy where the widget tree is built once
    but state changes every frame.

    The render function samples the refs each frame to get current state. -/
def voxelSceneWidgetFromRef
    (stateRef : IO.Ref VoxelSceneState)
    (highlightRef : IO.Ref (Option (Int × Int × Int)))
    (config : VoxelSceneConfig := {}) : WidgetBuilder := do
  Arbor.custom (spec := {
    measure := fun _ _ => (0, 0)
    collect := fun _ => #[]
    draw := some (fun layout => do
      -- Sample current state from refs
      let state ← stateRef.get
      let highlightPos ← highlightRef.get
      withContentRect layout fun w h => do
        let renderer ← getRenderer
        renderVoxelSceneWithHighlight renderer w h state config highlightPos
    )
    skipCache := true
  }) (style := BoxStyle.fill)

end Cairn.Widget
