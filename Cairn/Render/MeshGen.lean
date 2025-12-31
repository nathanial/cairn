/-
  Cairn/Render/MeshGen.lean - Mesh generation with face culling
-/

import Cairn.Core.Block
import Cairn.Core.Coords
import Cairn.Core.Face
import Cairn.World.ChunkMesh
import Cairn.World.Types
import Cairn.Optics

namespace Cairn.Render

open Cairn.Core
open Cairn.World
open Cairn.Optics
open scoped Collimator.Operators

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

/-- Compute neighbor block position (None = world boundary) -/
def neighborBlockPos (pos : BlockPos) (face : Face) : Option BlockPos :=
  match face with
  | .top    => if pos.y + 1 >= chunkHeight then none else some (pos & blockPosY %~ (· + 1))
  | .bottom => if pos.y <= 0 then none else some (pos & blockPosY %~ (· - 1))
  | .north  => some (pos & blockPosZ %~ (· + 1))
  | .south  => some (pos & blockPosZ %~ (· - 1))
  | .east   => some (pos & blockPosX %~ (· + 1))
  | .west   => some (pos & blockPosX %~ (· - 1))

/-- Get neighbor block using world optics -/
def getNeighborBlock (world : World) (pos : BlockPos) (face : Face) : Block :=
  match neighborBlockPos pos face with
  | some pos' => (world ^? blockAt pos').getD Block.air
  | none => Block.air

/-- Check if a face should be rendered (neighbor is air or transparent) -/
private def shouldRenderFace (world : World) (pos : BlockPos) (face : Face) : Bool :=
  !(getNeighborBlock world pos face).isSolid

/-- Get block from a chunk by local position -/
private def getBlockFromChunk (chunk : Chunk) (lx ly lz : Nat) : Block :=
  let idx := lx + lz * chunkSize + ly * chunkSize * chunkSize
  chunk.blocks[idx]?.getD Block.air

/-- Get block from chunk neighborhood by world position -/
private def getBlockFromNeighborhood (hood : ChunkNeighborhood) (pos : BlockPos) : Block :=
  let cp := hood.center.pos
  let baseX := cp.x * chunkSize
  let baseZ := cp.z * chunkSize
  let relX := pos.x - baseX
  let relZ := pos.z - baseZ

  -- Check if in center chunk
  if relX >= 0 && relX < chunkSize && relZ >= 0 && relZ < chunkSize then
    getBlockFromChunk hood.center relX.toNat pos.y.toNat relZ.toNat
  -- Check neighbors
  else if relZ >= chunkSize then  -- North (+Z)
    match hood.north with
    | some chunk => getBlockFromChunk chunk relX.toNat pos.y.toNat (relZ - chunkSize).toNat
    | none => Block.air
  else if relZ < 0 then  -- South (-Z)
    match hood.south with
    | some chunk => getBlockFromChunk chunk relX.toNat pos.y.toNat (relZ + chunkSize).toNat
    | none => Block.air
  else if relX >= chunkSize then  -- East (+X)
    match hood.east with
    | some chunk => getBlockFromChunk chunk (relX - chunkSize).toNat pos.y.toNat relZ.toNat
    | none => Block.air
  else if relX < 0 then  -- West (-X)
    match hood.west with
    | some chunk => getBlockFromChunk chunk (relX + chunkSize).toNat pos.y.toNat relZ.toNat
    | none => Block.air
  else
    Block.air

/-- Get neighbor block from neighborhood -/
private def getNeighborBlockFromHood (hood : ChunkNeighborhood) (pos : BlockPos) (face : Face) : Block :=
  match neighborBlockPos pos face with
  | some pos' => getBlockFromNeighborhood hood pos'
  | none => Block.air

/-- Check if face should render using neighborhood -/
private def shouldRenderFaceFromHood (hood : ChunkNeighborhood) (pos : BlockPos) (face : Face) : Bool :=
  !(getNeighborBlockFromHood hood pos face).isSolid

/-- Generate mesh from chunk neighborhood (for background tasks) -/
def generateMeshFromNeighborhood (hood : ChunkNeighborhood) : ChunkMesh := Id.run do
  let mut vertices : Array Float := #[]
  let mut indices : Array UInt32 := #[]
  let mut vertexCount : Nat := 0

  let cp := hood.center.pos
  let baseX : Int := cp.x * chunkSize
  let baseZ : Int := cp.z * chunkSize

  for ly in [:chunkHeight] do
    for lz in [:chunkSize] do
      for lx in [:chunkSize] do
        let pos : BlockPos := { x := baseX + lx, y := ly, z := baseZ + lz }
        let block := getBlockFromChunk hood.center lx ly lz

        if block != Block.air && block.isSolid then
          let worldX := intToFloat pos.x
          let worldY := intToFloat pos.y
          let worldZ := intToFloat pos.z
          for face in Face.all do
            if shouldRenderFaceFromHood hood pos face then
              let (verts', inds') := addFace vertices indices vertexCount
                                              worldX worldY worldZ face (block.faceColor face)
              vertices := verts'
              indices := inds'
              vertexCount := vertexCount + 4

  { vertices, indices, vertexCount, indexCount := indices.size }

/-- Generate mesh for a chunk with face culling -/
def generateMesh (world : World) (cp : ChunkPos) : ChunkMesh := Id.run do
  let mut vertices : Array Float := #[]
  let mut indices : Array UInt32 := #[]
  let mut vertexCount : Nat := 0

  -- Base world coordinates for this chunk
  let baseX : Int := cp.x * chunkSize
  let baseZ : Int := cp.z * chunkSize

  for ly in [:chunkHeight] do
    for lz in [:chunkSize] do
      for lx in [:chunkSize] do
        let pos : BlockPos := { x := baseX + lx, y := ly, z := baseZ + lz }
        let block := (world ^? blockAt pos).getD Block.air

        if block != Block.air && block.isSolid then
          let worldX := intToFloat pos.x
          let worldY := intToFloat pos.y
          let worldZ := intToFloat pos.z
          for face in Face.all do
            if shouldRenderFace world pos face then
              let (verts', inds') := addFace vertices indices vertexCount
                                              worldX worldY worldZ face (block.faceColor face)
              vertices := verts'
              indices := inds'
              vertexCount := vertexCount + 4

  { vertices, indices, vertexCount, indexCount := indices.size }

end Cairn.Render
