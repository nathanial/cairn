/-
  Cairn/Optics.lean - Auto-generated optics for Cairn data structures
-/

import Collimator
import Collimator.Derive.Lenses
import Collimator.Combinators
import Cairn.Core.Block
import Cairn.Optics.Chunk
import Cairn.Optics.Coords
import Cairn.World.ChunkMesh
import Cairn.World.Terrain
import Cairn.World.Types

namespace Cairn.Optics

open Collimator
open Collimator.Derive
open Cairn.Core
open Cairn.World

-- Auto-generate lenses for downstream types
makeLenses ChunkMesh
makeLenses TerrainConfig
makeLenses World

-- Prisms for Block variants
def _stone : Prism' Block Unit := ctorPrism% Block.stone
def _dirt : Prism' Block Unit := ctorPrism% Block.dirt
def _grass : Prism' Block Unit := ctorPrism% Block.grass
def _water : Prism' Block Unit := ctorPrism% Block.water
def _sand : Prism' Block Unit := ctorPrism% Block.sand
def _wood : Prism' Block Unit := ctorPrism% Block.wood
def _leaves : Prism' Block Unit := ctorPrism% Block.leaves
def _air : Prism' Block Unit := ctorPrism% Block.air

-- Affine lenses for HashMap access
-- These compose a lens to the HashMap with indexed access

/-- Affine lens for accessing a chunk at a specific position.
    Composes worldChunks with HashMap's indexed access to focus on
    at most one Chunk value. -/
def chunkAt (pos : ChunkPos) : AffineTraversal' World Chunk :=
  worldChunks ∘ Collimator.Indexed.atLens pos ∘ Collimator.Instances.Option.somePrism' Chunk

/-- Affine lens for accessing a mesh at a specific position.
    Composes worldMeshes with HashMap's indexed access to focus on
    at most one ChunkMesh value. -/
def meshAt (pos : ChunkPos) : AffineTraversal' World ChunkMesh :=
  worldMeshes ∘ Collimator.Indexed.atLens pos ∘ Collimator.Instances.Option.somePrism' ChunkMesh

/-- Affine traversal for accessing a block at a world position.
    Composes chunk lookup with local block access. -/
def blockAt (pos : BlockPos) : AffineTraversal' World Block :=
  match pos.toLocalPos? with
  | some localPos => chunkAt pos.toChunkPos ∘ localBlockAt localPos
  | none =>
    Collimator.Combinators.affineFromPartial
      (fun _ => none)
      (fun world _ => world)

/-- Affine traversal for accessing a block via WorldPos.
    Composes chunk lookup with local block access. -/
def blockAtWorld (pos : WorldPos) : AffineTraversal' World Block :=
  chunkAt pos.chunk ∘ localBlockAt pos.localPos

end Cairn.Optics
