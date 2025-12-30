/-
  Cairn/Mesh.lean - Mesh generation helpers for voxels
-/

import Afferent.Render.Mesh

namespace Cairn.Mesh

/-- Re-export cube mesh from Afferent for convenience -/
def cubeVertices : Array Float := Afferent.Render.Mesh.cubeVertices
def cubeIndices : Array UInt32 := Afferent.Render.Mesh.cubeIndices

/-- Highlight cube vertices: slightly larger (1.02) with semi-transparent white
    Each vertex: x, y, z, nx, ny, nz, r, g, b, a (10 floats) -/
def highlightVertices : Array Float :=
  let s : Float := 0.51  -- Half-size, slightly larger than 0.5
  let c : Float := 1.0   -- White color
  let a : Float := 0.25  -- Low alpha for transparency
  #[
    -- Front face (z = +s)
    -s, -s,  s,   0, 0, 1,   c, c, c, a,
     s, -s,  s,   0, 0, 1,   c, c, c, a,
     s,  s,  s,   0, 0, 1,   c, c, c, a,
    -s,  s,  s,   0, 0, 1,   c, c, c, a,
    -- Back face (z = -s)
     s, -s, -s,   0, 0, -1,  c, c, c, a,
    -s, -s, -s,   0, 0, -1,  c, c, c, a,
    -s,  s, -s,   0, 0, -1,  c, c, c, a,
     s,  s, -s,   0, 0, -1,  c, c, c, a,
    -- Right face (x = +s)
     s, -s,  s,   1, 0, 0,   c, c, c, a,
     s, -s, -s,   1, 0, 0,   c, c, c, a,
     s,  s, -s,   1, 0, 0,   c, c, c, a,
     s,  s,  s,   1, 0, 0,   c, c, c, a,
    -- Left face (x = -s)
    -s, -s, -s,  -1, 0, 0,   c, c, c, a,
    -s, -s,  s,  -1, 0, 0,   c, c, c, a,
    -s,  s,  s,  -1, 0, 0,   c, c, c, a,
    -s,  s, -s,  -1, 0, 0,   c, c, c, a,
    -- Top face (y = +s)
    -s,  s,  s,   0, 1, 0,   c, c, c, a,
     s,  s,  s,   0, 1, 0,   c, c, c, a,
     s,  s, -s,   0, 1, 0,   c, c, c, a,
    -s,  s, -s,   0, 1, 0,   c, c, c, a,
    -- Bottom face (y = -s)
    -s, -s, -s,   0, -1, 0,  c, c, c, a,
     s, -s, -s,   0, -1, 0,  c, c, c, a,
     s, -s,  s,   0, -1, 0,  c, c, c, a,
    -s, -s,  s,   0, -1, 0,  c, c, c, a
  ]

/-- Highlight cube indices (same as regular cube) -/
def highlightIndices : Array UInt32 := Afferent.Render.Mesh.cubeIndices

end Cairn.Mesh
