/-
  Cairn/Mesh.lean - Mesh generation helpers for voxels
-/

import Afferent.Render.Mesh

namespace Cairn.Mesh

/-- Re-export cube mesh from Afferent for convenience -/
def cubeVertices : Array Float := Afferent.Render.Mesh.cubeVertices
def cubeIndices : Array UInt32 := Afferent.Render.Mesh.cubeIndices

end Cairn.Mesh
