/-
  Cairn/Mesh.lean - Mesh generation helpers for voxels
-/

import Afferent.Render.Mesh

namespace Cairn.Mesh

/-- Re-export cube mesh from Afferent for convenience -/
def cubeVertices : Array Float := Afferent.Render.Mesh.cubeVertices
def cubeIndices : Array UInt32 := Afferent.Render.Mesh.cubeIndices

/-- Generate vertices for a cube at a specific position with a specific color
    Returns (vertices, indices) ready for rendering
    Vertex format: [x, y, z, nx, ny, nz, r, g, b, a] (10 floats per vertex) -/
def coloredCubeAt (_x _y _z _r _g _b _a : Float) : Array Float × Array UInt32 :=
  -- For now, just use the standard cube and we'll handle transforms in the shader
  -- In the future, we can generate colored vertex data here
  (cubeVertices, cubeIndices)

end Cairn.Mesh
