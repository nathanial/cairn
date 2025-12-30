/-
  Cairn/World/ChunkMesh.lean - Mesh generation with face culling
-/

import Cairn.Core.Block
import Cairn.Core.Coords
import Cairn.World.Chunk

namespace Cairn.World

open Cairn.Core

/-- Face direction for culling -/
inductive Face where
  | top     -- +Y
  | bottom  -- -Y
  | north   -- +Z
  | south   -- -Z
  | east    -- +X
  | west    -- -X
  deriving Repr, BEq

/-- Chunk mesh data ready for GPU -/
structure ChunkMesh where
  vertices : Array Float   -- 10 floats per vertex: x,y,z, nx,ny,nz, r,g,b,a
  indices : Array UInt32
  vertexCount : Nat
  indexCount : Nat
  deriving Inhabited

namespace ChunkMesh

/-- Empty mesh -/
def empty : ChunkMesh :=
  { vertices := #[]
  , indices := #[]
  , vertexCount := 0
  , indexCount := 0 }

/-- Face vertex positions (4 corners) and normal for each face -/
private def faceData (face : Face) : (Array (Nat × Nat × Nat)) × (Float × Float × Float) :=
  match face with
  | .top =>    (#[(0,1,0), (1,1,0), (1,1,1), (0,1,1)], (0.0, 1.0, 0.0))
  | .bottom => (#[(0,0,1), (1,0,1), (1,0,0), (0,0,0)], (0.0, -1.0, 0.0))
  | .north =>  (#[(1,0,1), (0,0,1), (0,1,1), (1,1,1)], (0.0, 0.0, 1.0))
  | .south =>  (#[(0,0,0), (1,0,0), (1,1,0), (0,1,0)], (0.0, 0.0, -1.0))
  | .east =>   (#[(1,0,0), (1,0,1), (1,1,1), (1,1,0)], (1.0, 0.0, 0.0))
  | .west =>   (#[(0,0,1), (0,0,0), (0,1,0), (0,1,1)], (-1.0, 0.0, 0.0))

/-- Convert Int to Float -/
private def intToFloat (i : Int) : Float :=
  if i >= 0 then i.toNat.toFloat
  else -((-i).toNat.toFloat)

/-- Add face vertices and indices to mesh builder -/
private def addFace (vertices : Array Float) (indices : Array UInt32)
    (baseVertex : Nat) (worldX worldY worldZ : Float)
    (face : Face) (color : Float × Float × Float × Float)
    : Array Float × Array UInt32 := Id.run do
  let (r, g, b, a) := color
  let vi := baseVertex.toUInt32
  let (faceVerts, (nx, ny, nz)) := faceData face

  -- Add 4 vertices for the face
  let mut verts := vertices
  for (dx, dy, dz) in faceVerts do
    verts := verts.push (worldX + dx.toFloat)
    verts := verts.push (worldY + dy.toFloat)
    verts := verts.push (worldZ + dz.toFloat)
    verts := verts.push nx
    verts := verts.push ny
    verts := verts.push nz
    verts := verts.push r
    verts := verts.push g
    verts := verts.push b
    verts := verts.push a

  -- Add 6 indices for 2 triangles (CCW winding)
  let mut inds := indices
  inds := inds.push vi
  inds := inds.push (vi + 1)
  inds := inds.push (vi + 2)
  inds := inds.push vi
  inds := inds.push (vi + 2)
  inds := inds.push (vi + 3)

  return (verts, inds)

/-- Get neighbor block within same chunk or via callback for cross-chunk -/
private def getNeighborBlock (chunk : Chunk) (pos : LocalPos) (face : Face)
    (getExternal : ChunkPos → LocalPos → Block) : Block :=
  match face with
  | .top =>
    if pos.y + 1 >= chunkHeight then Block.air
    else chunk.getBlock { pos with y := pos.y + 1 }
  | .bottom =>
    if pos.y == 0 then Block.air  -- Render bottom of world
    else chunk.getBlock { pos with y := pos.y - 1 }
  | .north =>  -- +Z
    if pos.z + 1 >= chunkSize then
      getExternal { chunk.pos with z := chunk.pos.z + 1 } { pos with z := 0 }
    else chunk.getBlock { pos with z := pos.z + 1 }
  | .south =>  -- -Z
    if pos.z == 0 then
      getExternal { chunk.pos with z := chunk.pos.z - 1 } { pos with z := chunkSize - 1 }
    else chunk.getBlock { pos with z := pos.z - 1 }
  | .east =>   -- +X
    if pos.x + 1 >= chunkSize then
      getExternal { chunk.pos with x := chunk.pos.x + 1 } { pos with x := 0 }
    else chunk.getBlock { pos with x := pos.x + 1 }
  | .west =>   -- -X
    if pos.x == 0 then
      getExternal { chunk.pos with x := chunk.pos.x - 1 } { pos with x := chunkSize - 1 }
    else chunk.getBlock { pos with x := pos.x - 1 }

/-- Check if a face should be rendered (neighbor is air or transparent) -/
private def shouldRenderFace (chunk : Chunk) (pos : LocalPos) (face : Face)
    (getExternal : ChunkPos → LocalPos → Block) : Bool :=
  let neighborBlock := getNeighborBlock chunk pos face getExternal
  !neighborBlock.isSolid

/-- All six faces -/
private def allFaces : Array Face := #[.top, .bottom, .north, .south, .east, .west]

/-- Generate mesh for a chunk with face culling -/
def generate (chunk : Chunk)
    (getExternal : ChunkPos → LocalPos → Block) : ChunkMesh := Id.run do
  let mut vertices : Array Float := #[]
  let mut indices : Array UInt32 := #[]
  let mut vertexCount : Nat := 0

  for ly in [:chunkHeight] do
    for lz in [:chunkSize] do
      for lx in [:chunkSize] do
        let localPos : LocalPos := { x := lx, y := ly, z := lz }
        let block := chunk.getBlock localPos

        if block != Block.air && block.isSolid then
          let worldX := intToFloat (chunk.pos.x * chunkSize + lx)
          let worldY := ly.toFloat
          let worldZ := intToFloat (chunk.pos.z * chunkSize + lz)
          let color := block.color

          -- Check each face
          for face in allFaces do
            if shouldRenderFace chunk localPos face getExternal then
              let (verts', inds') := addFace vertices indices vertexCount
                                              worldX worldY worldZ face color
              vertices := verts'
              indices := inds'
              vertexCount := vertexCount + 4

  { vertices := vertices
  , indices := indices
  , vertexCount := vertexCount
  , indexCount := indices.size }

/-- Check if mesh is empty -/
def isEmpty (mesh : ChunkMesh) : Bool :=
  mesh.indexCount == 0

end ChunkMesh

end Cairn.World
