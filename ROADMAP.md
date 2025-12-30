# Cairn Roadmap

This document tracks improvement opportunities, feature proposals, and code cleanup tasks for the Cairn voxel game.

---

## Feature Proposals

### [Priority: High] Chunk System for Voxel World

**Description:** Implement a chunk-based world storage system where the world is divided into fixed-size chunks (e.g., 16x16x16 blocks). Each chunk would be loaded, rendered, and managed independently.

**Rationale:** The current demo only renders a fixed 5x5 grid of cubes. A real voxel game requires an unbounded world that loads and unloads chunks based on player position. This is the foundational system for all other voxel features.

**Affected Files:**
- New file: `Cairn/World/Chunk.lean` (chunk data structure, block storage)
- New file: `Cairn/World/World.lean` (chunk management, coordinate transforms)
- New file: `Cairn/World/ChunkMesh.lean` (chunk mesh generation)
- `Main.lean` (integrate world system)

**Estimated Effort:** Large

**Dependencies:** None. Foundation for terrain generation and block placement.

---

### [Priority: High] Greedy Mesh Generation

**Description:** Implement greedy meshing algorithm to combine adjacent same-type block faces into larger quads, significantly reducing vertex count.

**Rationale:** Naive voxel rendering (one cube per block) generates 36 vertices per visible block. A 16x16x16 chunk could have 4,096 blocks. Greedy meshing can reduce vertex counts by 80-95% for typical terrain.

**Affected Files:**
- New file: `Cairn/Render/GreedyMesh.lean` (greedy meshing algorithm)
- `Cairn/Mesh.lean` (mesh generation utilities)
- `Cairn/Core/Block.lean` (may need face-specific colors)

**Estimated Effort:** Large

**Dependencies:** Chunk system should be in place first.

---

### [Priority: High] Block Placement and Destruction

**Description:** Allow players to place and destroy blocks using mouse input. Implement ray casting to determine which block is being targeted.

**Rationale:** Core Minecraft-style gameplay. Without block manipulation, the game is just a viewer.

**Affected Files:**
- New file: `Cairn/World/Raycast.lean` (block raycasting using linalg Ray/AABB)
- New file: `Cairn/Input/BlockAction.lean` (place/destroy logic)
- `Main.lean` (add mouse button handling)
- `Cairn/World/Chunk.lean` (block modification, dirty flag for remeshing)

**Estimated Effort:** Medium

**Dependencies:** Chunk system, basic world structure.

---

### [Priority: High] Block Face Colors and Textures

**Description:** Support different colors/textures per block face (e.g., grass has green top, brown sides). Currently `Block.color` returns a single color for all faces.

**Rationale:** Makes blocks visually distinct and recognizable. Grass blocks should look like grass, not just green cubes.

**Affected Files:**
- `Cairn/Core/Block.lean` (add `faceColor : Block -> Face -> Color`)
- New enum: `Cairn/Core/Face.lean` (Top, Bottom, North, South, East, West)
- Mesh generation (pass face-specific colors to vertices)

**Estimated Effort:** Small

**Dependencies:** None.

---

### [Priority: Medium] Procedural Terrain Generation

**Description:** Generate terrain using noise functions (Perlin/Simplex). Include basic biomes, terrain height variation, and ore placement.

**Rationale:** Hand-placing blocks is tedious. Procedural terrain provides instant playable worlds.

**Affected Files:**
- New file: `Cairn/World/Terrain.lean` (terrain generator)
- New file: `Cairn/World/Noise.lean` (noise functions, or use linalg Noise module)
- `Cairn/World/Chunk.lean` (integrate terrain generation on chunk load)

**Estimated Effort:** Medium

**Dependencies:** Chunk system. Can use `Linalg.Noise` from the linalg dependency.

---

### [Priority: Medium] Collision Detection and Physics

**Description:** Implement player collision with solid blocks to prevent walking through walls and falling through floors. Add basic gravity.

**Rationale:** Without collision, the player is essentially a ghost camera. Collision is essential for gameplay.

**Affected Files:**
- New file: `Cairn/Physics/Collision.lean` (AABB-based collision with voxels)
- New file: `Cairn/Physics/Player.lean` (player physics state, velocity, gravity)
- `Cairn/Camera.lean` (integrate physics constraints)
- `Main.lean` (physics update in game loop)

**Estimated Effort:** Medium

**Dependencies:** Chunk system (to query blocks for collision).

---

### [Priority: Medium] Block Selection Highlight

**Description:** Render a wireframe or highlighted outline around the block the player is looking at.

**Rationale:** Essential for knowing which block will be placed/destroyed. Standard UX in all voxel games.

**Affected Files:**
- New file: `Cairn/Render/Highlight.lean` (wireframe cube rendering)
- `Main.lean` (raycast and render highlight each frame)

**Estimated Effort:** Small

**Dependencies:** Block raycasting.

---

### [Priority: Medium] Inventory and Block Selection

**Description:** Implement a basic hotbar inventory allowing players to select which block type to place.

**Rationale:** Without inventory, players can only place one block type. Core feature for creative building.

**Affected Files:**
- New file: `Cairn/UI/Hotbar.lean` (hotbar widget/rendering)
- New file: `Cairn/State/Inventory.lean` (inventory state)
- `Main.lean` (number key handling for slot selection)

**Estimated Effort:** Medium

**Dependencies:** Block placement system.

---

### [Priority: Medium] Chunk Serialization

**Description:** Save and load chunks to/from disk for world persistence.

**Rationale:** Without persistence, all progress is lost when the game closes.

**Affected Files:**
- New file: `Cairn/World/ChunkIO.lean` (chunk serialization/deserialization)
- `Cairn/World/World.lean` (save/load coordination)

**Estimated Effort:** Medium

**Dependencies:** Chunk system.

---

### [Priority: Low] Day/Night Cycle

**Description:** Implement time-based lighting with sun position affecting light direction and sky color.

**Rationale:** Adds atmosphere and visual variety. Standard feature in Minecraft-style games.

**Affected Files:**
- New file: `Cairn/World/Time.lean` (game time, sun position calculation)
- `Main.lean` (update light direction based on time)

**Estimated Effort:** Small

**Dependencies:** None.

---

### [Priority: Low] Water Rendering

**Description:** Special rendering for water blocks with transparency and simple wave animation.

**Rationale:** Water is defined in Block types but not rendered specially. Transparent/animated water improves visuals.

**Affected Files:**
- `Cairn/Render/` (water-specific rendering pass)
- Mesh generation (separate opaque and transparent meshes)

**Estimated Effort:** Medium

**Dependencies:** Chunk meshing system.

---

### [Priority: Low] Sound Effects

**Description:** Add ambient sounds and block interaction sounds using the fugue audio library.

**Rationale:** Audio feedback enhances immersion.

**Affected Files:**
- New files under `Cairn/Audio/`
- `lakefile.lean` (add fugue dependency)
- `Main.lean` (audio initialization and playback)

**Estimated Effort:** Medium

**Dependencies:** Requires adding fugue dependency.

---

## Code Improvements

### [Priority: High] Extract Game State Structure

**Current State:** Game state (camera, time) is tracked via local `mut` variables in `Main.lean`.

**Proposed Change:** Create a `GameState` structure containing all mutable state (camera, world, time, input state). Use a proper state monad or pass state explicitly.

**Benefits:** Cleaner code organization, easier testing, foundation for save/load.

**Affected Files:**
- New file: `Cairn/State/GameState.lean`
- `Main.lean` (refactor to use GameState)

**Estimated Effort:** Small

---

### [Priority: High] Separate Input Handling Module

**Current State:** Input handling (key codes, mouse input) is hardcoded in `Main.lean` with raw key code constants.

**Proposed Change:** Create an input module with named key constants and input state tracking (pressed, released, held).

**Benefits:** Cleaner input code, easier key rebinding, reusable across game states.

**Affected Files:**
- New file: `Cairn/Input/Keys.lean` (named key constants)
- New file: `Cairn/Input/State.lean` (input state tracking)
- `Main.lean` (use input module)

**Estimated Effort:** Small

---

### [Priority: Medium] Implement coloredCubeAt Function

**Current State:** The `Mesh.coloredCubeAt` function is a stub that ignores color parameters and returns the standard cube mesh.

**Proposed Change:** Either implement proper colored vertex generation or remove the function if not needed.

**Benefits:** Complete the API or reduce dead code.

**Affected Files:**
- `Cairn/Mesh.lean` (lines 16-19)

**Estimated Effort:** Small

---

### [Priority: Medium] Camera Configuration as Structure

**Current State:** Camera configuration (fovY, nearPlane, farPlane) are separate `def` constants in `Cairn/Camera.lean`.

**Proposed Change:** Bundle into a `CameraConfig` structure that can be passed around and modified.

**Benefits:** Easier to adjust FOV (e.g., for zoom/sprint), cleaner API.

**Affected Files:**
- `Cairn/Camera.lean`

**Estimated Effort:** Small

---

### [Priority: Low] Use Float.pi Instead of Literal

**Current State:** `fovY` is defined using `Float.pi` (good), but the README says Lean 4.16.0 while `lean-toolchain` says v4.26.0.

**Proposed Change:** Update README to reflect actual Lean version.

**Benefits:** Accurate documentation.

**Affected Files:**
- `README.md` (line 14)

**Estimated Effort:** Trivial

---

## Code Cleanup

### [Priority: High] Add Block Type Tests

**Issue:** Block tests only cover `isSolid`, `isTransparent`, and basic color checks. No tests for all block types.

**Location:** `Tests/Main.lean`

**Action Required:**
- Add tests for all Block enum variants
- Test that all blocks have valid colors (non-NaN values)
- Test that solid/transparent classifications are mutually consistent

**Estimated Effort:** Small

---

### [Priority: Medium] Add Documentation Comments

**Issue:** Only `Block.lean` has doc comments. Other modules lack documentation.

**Location:**
- `Cairn/Camera.lean` (missing doc comments on constants)
- `Cairn/Mesh.lean` (has partial docs)
- `Main.lean` (has comments but not doc-style)

**Action Required:** Add `/-- -/` doc comments to all public definitions.

**Estimated Effort:** Small

---

### [Priority: Medium] Consistent Namespace Usage

**Issue:** `Block` is in `Cairn.Core` namespace, but `Camera` and `Mesh` are in `Cairn.Camera` and `Cairn.Mesh` namespaces respectively. Inconsistent organization.

**Location:**
- `Cairn/Core/Block.lean` (Cairn.Core namespace)
- `Cairn/Camera.lean` (Cairn.Camera namespace)
- `Cairn/Mesh.lean` (Cairn.Mesh namespace)

**Action Required:** Consider whether Camera and Mesh should be under `Cairn.Core` or if Block should be at `Cairn.Block`. Establish consistent convention.

**Estimated Effort:** Small

---

### [Priority: Low] Test Script

**Issue:** README documents `./build.sh cairn_tests && .lake/build/bin/cairn_tests` but there is no `test.sh` script like other projects in the workspace.

**Location:** Project root

**Action Required:** Add `test.sh` script for consistency with other projects:
```bash
#!/bin/bash
./build.sh cairn_tests && .lake/build/bin/cairn_tests
```

**Estimated Effort:** Trivial

---

### [Priority: Low] Expand README Controls Section

**Issue:** README shows controls but does not document all interactions (e.g., mouse capture behavior).

**Location:** `README.md` (Controls section)

**Action Required:** Add notes about click-to-capture and pointer lock behavior.

**Estimated Effort:** Trivial

---

## Architecture Considerations

### Game Loop Structure

The current game loop in `Main.lean` handles input, update, and render in a single while loop. As the game grows, consider separating these into distinct phases:
1. Input processing (collect all input state)
2. Update (game logic, physics)
3. Render (draw frame)

This separation enables fixed timestep updates for physics while allowing variable framerate rendering.

### Entity-Component System

For future features (items, mobs, particles), consider implementing a simple ECS or at least a component-based architecture rather than hardcoding all entity types.

### Render Batching

Currently each cube is drawn with a separate `drawMesh3D` call. For better performance with many cubes, batch all cubes into a single vertex buffer per chunk and draw with one call.

---

## Quick Wins

These items can be addressed quickly with minimal risk:

1. Add `test.sh` script
2. Update README Lean version (4.16.0 -> 4.26.0)
3. Add doc comments to Camera.lean constants
4. Implement or remove `coloredCubeAt` stub
5. Add comprehensive Block enum tests
6. Add Face enum for future face-specific colors

---

## Milestones

### Milestone 1: Basic World (MVP)
- [ ] Chunk data structure
- [ ] Basic chunk meshing
- [ ] Single chunk rendering
- [ ] Extract GameState structure

### Milestone 2: Infinite World
- [ ] Multiple chunk loading/unloading
- [ ] Procedural terrain generation
- [ ] Chunk view distance management

### Milestone 3: Interactivity
- [ ] Block raycasting
- [ ] Block placement and destruction
- [ ] Block selection highlight
- [ ] Basic hotbar UI

### Milestone 4: Physics
- [ ] Player collision with blocks
- [ ] Gravity and jumping
- [ ] Swimming in water

### Milestone 5: Persistence
- [ ] Chunk serialization
- [ ] World save/load
- [ ] Auto-save

---

*Last updated: 2025-12-29*
