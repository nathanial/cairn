/-
  Cairn/World/Terrain.lean - Procedural terrain generation using noise
-/

import Cairn.World.Types
import Cairn.World.Chunk
import Cairn.Optics.Chunk
import Linalg

namespace Cairn.World

open Cairn.Core
open Cairn.Optics
open scoped Collimator.Operators
open Linalg.Noise

namespace TerrainConfig

def default : TerrainConfig := {}

end TerrainConfig

/-- FBM config for terrain generation -/
private def terrainFbmConfig : FractalConfig :=
  { octaves := 4
  , persistence := 0.5
  , lacunarity := 2.0 }

/-- Convert Int to Float -/
private def intToFloat (i : Int) : Float :=
  if i >= 0 then i.toNat.toFloat
  else -((-i).toNat.toFloat)

/-- Generate terrain height at world (x, z) coordinates -/
def getTerrainHeight (config : TerrainConfig) (worldX worldZ : Int) : Nat :=
  let x := intToFloat worldX * config.noiseScale
  let z := intToFloat worldZ * config.noiseScale
  -- Use FBM simplex for natural-looking terrain
  let noise := fbmSimplex2D x z terrainFbmConfig
  -- Map from [-1, 1] to height range
  let normalizedNoise := (noise + 1.0) / 2.0
  let height := config.baseHeight.toFloat + normalizedNoise * config.heightScale
  height.toUInt64.toNat

/-- Check if position should be a cave -/
def isCave (config : TerrainConfig) (worldX worldY worldZ : Int) : Bool :=
  let x := intToFloat worldX * config.caveScale
  let y := intToFloat worldY * config.caveScale
  let z := intToFloat worldZ * config.caveScale
  let noise := simplex3D x y z
  -- Caves occur where 3D noise exceeds threshold
  noise > config.caveThreshold

/-- Determine block type based on depth and position -/
def getBlockType (surfaceHeight : Nat) (y : Nat) (config : TerrainConfig) : Block :=
  if y > surfaceHeight then
    -- Above surface: air or water
    if y <= config.seaLevel then Block.water else Block.air
  else if y == surfaceHeight then
    -- Surface block
    if surfaceHeight <= config.seaLevel then Block.sand
    else Block.grass
  else if y >= surfaceHeight - 3 then
    -- Near surface: dirt
    Block.dirt
  else
    -- Deep underground: stone
    Block.stone

/-- Generate a complete chunk -/
def generateChunk (config : TerrainConfig) (chunkPos : ChunkPos) : Chunk := Id.run do
  let mut chunk := Chunk.empty chunkPos

  for lx in [:chunkSize] do
    for lz in [:chunkSize] do
      let worldX := chunkPos.x * chunkSize + lx
      let worldZ := chunkPos.z * chunkSize + lz
      let surfaceHeight := getTerrainHeight config worldX worldZ

      for ly in [:chunkHeight] do
        let localPos : LocalPos := { x := lx, y := ly, z := lz }
        let block := getBlockType surfaceHeight ly config

        -- Apply cave carving (but not too close to surface or below y=5)
        let finalBlock :=
          if block.isSolid && ly >= 5 && ly < surfaceHeight - 4 then
            if isCave config worldX ly worldZ then Block.air
            else block
          else
            block

        if finalBlock != Block.air then
          chunk := chunk & localBlockAt localPos .~ finalBlock

  chunk & chunkIsDirty .~ true

end Cairn.World
