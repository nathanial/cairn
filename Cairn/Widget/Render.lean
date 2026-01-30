/-
  Cairn/Widget/Render.lean - 3D rendering logic for voxel scene widget
-/

import Afferent
import Linalg
import Cairn.Widget.Core
import Cairn.Mesh

namespace Cairn.Widget

open Afferent Afferent.FFI Afferent.Render
open Linalg
open Cairn.World

/-- Render the voxel scene to the given viewport -/
def renderVoxelScene (renderer : FFI.Renderer) (width height : Float)
    (state : VoxelSceneState) (config : VoxelSceneConfig) : IO Unit := do
  -- Calculate projection matrix
  let aspect := width / height
  let proj := Mat4.perspective config.fovY aspect config.nearPlane config.farPlane

  -- Get view matrix from camera
  let view := state.camera.viewMatrix

  -- Camera position for fog/lighting calculations
  let cameraPos := #[state.camera.x, state.camera.y, state.camera.z]

  -- Render all chunk meshes
  for (_, mesh) in state.world.getMeshes do
    if mesh.indexCount > 0 then
      -- Model matrix is identity (world positions already in vertices)
      let model := Mat4.identity
      let mvp := proj * view * model

      Renderer.drawMesh3D
        renderer
        mesh.vertices
        mesh.indices
        mvp.toArray
        model.toArray
        config.lightDir
        config.ambient
        cameraPos
        config.fogColor
        config.fogStart
        config.fogEnd

/-- Render the voxel scene with optional block highlight overlay -/
def renderVoxelSceneWithHighlight (renderer : FFI.Renderer) (width height : Float)
    (state : VoxelSceneState) (config : VoxelSceneConfig)
    (highlightPos : Option (Int × Int × Int)) : IO Unit := do
  -- Render the main scene
  renderVoxelScene renderer width height state config

  -- Render highlight if provided
  match highlightPos with
  | some (bx, blockY, bz) =>
    let aspect := width / height
    let proj := Mat4.perspective config.fovY aspect config.nearPlane config.farPlane
    let view := state.camera.viewMatrix
    let cameraPos := #[state.camera.x, state.camera.y, state.camera.z]

    -- Helper to convert Int to Float
    let intToFloat (i : Int) : Float :=
      if i >= 0 then i.toNat.toFloat else -((-i).toNat.toFloat)

    -- Position highlight at block center
    let blockXF := intToFloat bx + 0.5
    let blockYF := intToFloat blockY + 0.5
    let blockZF := intToFloat bz + 0.5
    let highlightModel := Mat4.translation blockXF blockYF blockZF
    let highlightMVP := proj * view * highlightModel

    Renderer.drawMesh3D
      renderer
      Cairn.Mesh.highlightVertices
      Cairn.Mesh.highlightIndices
      highlightMVP.toArray
      highlightModel.toArray
      config.lightDir
      1.0  -- Full ambient for highlight (no shading)
      cameraPos
      config.fogColor
      0.0 0.0  -- Fog disabled for highlight
  | none => pure ()

end Cairn.Widget
