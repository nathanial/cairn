/-
  Cairn/World/Async.lean - FRP worker-pool based async world loading
-/

import Cairn.World.Types
import Cairn.World.World
import Cairn.World.Terrain
import Cairn.Render.MeshGen
import Cairn.Optics
import Collimator
import Reactive
import Reactive.Host.Spider.WorkerPool

namespace Cairn.World

open Cairn.Core
open Cairn.Render
open Cairn.Optics
open Collimator
open Reactive.Host
open scoped Collimator.Operators

/-- Kind discriminator for world jobs. -/
inductive WorldJobKind where
  | chunk
  | mesh
  deriving Repr, BEq, Hashable, Inhabited

/-- Unique job id for worker pool de-duplication. -/
structure WorldJobId where
  kind : WorldJobKind
  pos : ChunkPos
  deriving Repr, BEq, Hashable, Inhabited

/-- Async jobs for world loading. -/
inductive WorldJob where
  | generateChunk (config : TerrainConfig) (pos : ChunkPos)
  | generateMesh (pos : ChunkPos) (hood : ChunkNeighborhood)
  deriving Inhabited

/-- Async job result for world loading. -/
inductive WorldJobResult where
  | chunk (pending : PendingChunk)
  | mesh (pending : PendingMesh)

/-- Derive job id from job payload. -/
def jobId : WorldJob → WorldJobId
  | .generateChunk _ pos => { kind := .chunk, pos := pos }
  | .generateMesh pos _ => { kind := .mesh, pos := pos }

/-- Process a world job in the background. -/
def processWorldJob : WorldJob → IO WorldJobResult
  | .generateChunk config pos =>
      let chunk := generateChunk config pos
      return .chunk { pos, chunk }
  | .generateMesh pos hood =>
      let mesh := generateMeshFromNeighborhood hood
      return .mesh { pos, mesh }

/-- Worker pool handle for world loading. -/
structure WorldLoader where
  fireCommand : PoolCommand WorldJobId WorldJob → IO Unit
  poolHandle : WorkerPool.PoolHandle

namespace WorldLoader

/-- Compute chunk positions within render distance for a center point. -/
def chunkPositionsAround (world : World) (centerX centerZ : Int) : Array ChunkPos := Id.run do
  let center := World.blockToChunkPos centerX centerZ
  let renderDist := world ^. worldRenderDistance
  let rd : Int := renderDist
  let mut positions : Array ChunkPos := #[]
  for dxNat in [:renderDist * 2 + 1] do
    for dzNat in [:renderDist * 2 + 1] do
      let dx : Int := dxNat - rd
      let dz : Int := dzNat - rd
      positions := positions.push { x := center.x + dx, z := center.z + dz }
  return positions

/-- Priority for a chunk based on distance to center (closer = higher). -/
def chunkPriority (center pos : ChunkPos) : Int := Id.run do
  let dx : Nat := (pos.x - center.x).natAbs
  let dz : Nat := (pos.z - center.z).natAbs
  return -Int.ofNat (dx + dz)

def needsMesh (world : World) (pos : ChunkPos) : Bool :=
  match world ^? chunkAt pos ∘ chunkIsDirty with
  | some true => true
  | some false => (world ^? meshAt pos).isNone
  | none => false

/-- Submit missing chunk generation jobs around a player position. -/
def requestChunksAround (loader : WorldLoader) (world : World) (centerX centerZ : Int) : IO Unit := do
  let center := World.blockToChunkPos centerX centerZ
  let positions := chunkPositionsAround world centerX centerZ
  let config := world ^. worldTerrainConfig
  for pos in positions do
    if (world ^? chunkAt pos).isNone then
      let job : WorldJob := .generateChunk config pos
      let priority := chunkPriority center pos
      loader.fireCommand (.submit (jobId job) job priority)

/-- Submit mesh generation jobs around a player position. -/
def requestMeshesAround (loader : WorldLoader) (world : World) (centerX centerZ : Int) : IO Unit := do
  let center := World.blockToChunkPos centerX centerZ
  let positions := chunkPositionsAround world centerX centerZ
  for pos in positions do
    if needsMesh world pos then
      match World.getChunkNeighborhood world pos with
      | some hood =>
          let job : WorldJob := .generateMesh pos hood
          let priority := chunkPriority center pos
          loader.fireCommand (.submit (jobId job) job priority)
      | none => pure ()

/-- Submit chunk and mesh jobs around a player position. -/
def requestAround (loader : WorldLoader) (world : World) (centerX centerZ : Int) : IO Unit := do
  loader.requestChunksAround world centerX centerZ
  loader.requestMeshesAround world centerX centerZ

end WorldLoader

end Cairn.World
