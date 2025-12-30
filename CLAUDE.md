# Cairn

A Minecraft-style voxel game written in Lean 4 using Afferent for Metal GPU rendering.

## Build Commands

**Important:** Use the shell scripts instead of direct `lake` commands due to macOS framework linking requirements.

```bash
./build.sh        # Build the project
./run.sh          # Build and run the game
./test.sh         # Build and run tests
```

For prototyping or REPL work, use `lake env`:
```bash
lake env lean     # Run Lean with correct environment
```

## Architecture

### Module Structure

```
Cairn/
├── Core/           # Fundamental types
│   ├── Block.lean    # Block types (stone, dirt, grass, etc.)
│   ├── Coords.lean   # ChunkPos, LocalPos, BlockPos, WorldPos
│   └── Face.lean     # Block face enum (top, bottom, north, south, east, west)
├── World/          # World state and terrain
│   ├── Types.lean    # World, Chunk, TerrainConfig structures
│   ├── Chunk.lean    # Chunk data (16x128x16 blocks)
│   ├── Terrain.lean  # Procedural terrain generation (noise-based)
│   ├── World.lean    # World operations (load chunks, set/get blocks)
│   ├── ChunkMesh.lean # Mesh data structure
│   └── Raycast.lean  # Block raycasting for interaction
├── Render/         # Rendering
│   └── MeshGen.lean  # Chunk mesh generation with face culling
├── Physics/        # Player physics
│   └── Player.lean   # AABB collision, gravity, movement
├── Input/          # Input handling
│   └── State.lean    # InputState capture
├── State/          # Game state
│   └── GameState.lean # Consolidated mutable state
├── Optics/         # Collimator optics
│   ├── Chunk.lean    # Chunk field lenses, localBlockAt
│   └── Coords.lean   # Coordinate lenses (wpChunkX, wpLocalY, etc.)
├── Optics.lean     # World-level optics (blockAt, chunkAt, meshAt)
├── Camera.lean     # Camera constants
└── Mesh.lean       # Highlight mesh for block selection
```

### Coordinate System

- **BlockPos** - World coordinates (Int x, Int y, Int z). Use this for most operations.
- **ChunkPos** - Chunk coordinates (Int x, Int z). Each chunk is 16x16 blocks horizontally.
- **LocalPos** - Position within a chunk (Nat x, Nat y, Nat z). Range: 0-15 for x/z, 0-127 for y.
- **WorldPos** - Composite of ChunkPos + LocalPos. Mostly internal use.

Conversion: `BlockPos.decompose` splits into WorldPos, `WorldPos.toBlockPos` combines back.

### Optics (Collimator)

The codebase uses profunctor optics for nested data access:

```lean
open scoped Collimator.Operators

-- View a block
world ^? blockAt pos

-- Set a block
world & blockAt pos .~ Block.stone

-- Modify a coordinate
pos & blockPosY %~ (· + 1)
```

Key optics:
- `blockAt : BlockPos → AffineTraversal' World Block`
- `chunkAt : ChunkPos → AffineTraversal' World Chunk`
- `blockPosX/Y/Z : Lens' BlockPos Int`
- `wpChunkX/Z`, `wpLocalX/Y/Z` - Composed lenses for WorldPos

### Chunk Loading

Chunks are loaded lazily around the player. The loading happens in two passes:
1. Generate terrain for all chunks in range
2. Generate meshes (requires neighbors for face culling)

Face culling: only render faces where the neighbor block is air/transparent.

## Dependencies

- **afferent** - Metal GPU rendering, window management, fonts
- **collimator** - Profunctor optics
- **linalg** - Vectors, matrices, quaternions (via afferent)
- **crucible** - Test framework

## Controls

| Key | Action |
|-----|--------|
| WASD | Move horizontally |
| Space/E | Move up (fly mode) |
| Q | Move down (fly mode) |
| Mouse | Look around |
| Left click | Destroy block |
| Right click | Place block |
| 1-7 | Select block type |
| Escape | Release mouse |
