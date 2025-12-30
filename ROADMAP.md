# Cairn Roadmap

This document tracks improvement opportunities, feature proposals, and code cleanup tasks for the Cairn voxel game.

---

## Feature Proposals

### ~~[Priority: High] Chunk System for Voxel World~~ ✅ COMPLETED

**Status:** Implemented in December 2025.

**What was built:**
- `Cairn/Core/Coords.lean` - ChunkPos, LocalPos, BlockPos coordinate types
- `Cairn/World/Chunk.lean` - 16x16x128 chunk storage with flat Array Block
- `Cairn/World/ChunkMesh.lean` - Mesh generation with face culling
- `Cairn/World/Terrain.lean` - Procedural terrain using linalg noise
- `Cairn/World/World.lean` - Chunk manager with HashMap storage
- `Main.lean` - Integrated world system with dynamic chunk loading

**Features:**
- Render distance of 2 chunks (5x5 = 25 chunks loaded)
- Face culling (only renders faces adjacent to air/transparent)
- Cross-chunk neighbor lookup for proper boundary meshing

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

### ~~[Priority: High] Block Raycasting~~ ✅ COMPLETED

**Status:** Implemented in December 2025.

**What was built:**
- `Cairn/World/Raycast.lean` - DDA voxel raycast (Amanatides-Woo algorithm)
- `RaycastHit` structure with blockPos, face, point, distance
- `cameraForward` / `cameraRay` helpers for FPSCamera
- `Face.toNormal` and `RaycastHit.adjacentPos` utilities
- 8 raycast tests covering all face directions

---

### ~~[Priority: High] Block Placement and Destruction~~ ✅ COMPLETED

**Status:** Implemented in December 2025.

**What was built:**
- Left click: destroy block (set to air)
- Right click: place stone block on adjacent face
- 5 block reach distance (Minecraft-like)
- Placement validation (only in non-solid blocks)
- Automatic chunk remeshing via dirty flag

**Implementation:** Added ~15 lines to Main.lean game loop using existing raycast and World.setBlock infrastructure.

---

### ~~[Priority: High] Block Face Colors and Textures~~ ✅ COMPLETED

**Status:** Implemented in December 2025.

**What was built:**
- `Cairn/Core/Face.lean` - Face enum (top, bottom, north, south, east, west)
- `Block.faceColor` method in Block.lean with per-face colors
- Grass: green top, dirt bottom, grassy-brown sides
- Wood: light cut ends, bark sides
- Other blocks: uniform color (fallback to Block.color)

---

### ~~[Priority: Medium] Procedural Terrain Generation~~ ✅ COMPLETED

**Status:** Implemented in December 2025 as part of chunk system.

**What was built:**
- `Cairn/World/Terrain.lean` - Terrain generator using linalg noise
- Uses `fbmSimplex2D` (4 octaves) for heightmap
- Uses `simplex3D` for cave carving
- Block layering: grass → dirt → stone with depth
- Caves carved underground (skip near surface)
- Configurable via `TerrainConfig` (seed, sea level, height scale, noise scale)

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

### ~~[Priority: High] Extract Game State Structure~~ ✅ COMPLETED

**Status:** Implemented in December 2025.

**What was built:**
- `Cairn/State/GameState.lean` - GameState structure with camera, world, lastTime
- Refactored `Main.lean` to use single `let mut state : GameState`

**Benefits:** Cleaner code organization, easier testing, foundation for save/load.

---

### ~~[Priority: High] Separate Input Handling Module~~ ✅ COMPLETED

**Status:** Implemented in December 2025.

**What was built:**
- `Cairn/Input/Keys.lean` - Named macOS key code constants
- `Cairn/Input/State.lean` - InputState structure with capture function
- Refactored `Main.lean` to use InputState.capture for cleaner game loop

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

### ~~[Priority: Low] Test Script~~ ✅ COMPLETED

**Status:** Added `test.sh` in December 2025.

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

1. ~~Add `test.sh` script~~ ✅
2. ~~Update README Lean version (4.16.0 -> 4.26.0)~~ ✅
3. ~~Add doc comments to Camera.lean constants~~ ✅
4. ~~Implement or remove `coloredCubeAt` stub~~ ✅ (removed - ChunkMesh handles colored faces)
5. ~~Add comprehensive Block enum tests~~ ✅ (10 tests covering all block types)
6. ~~Add Face enum for future face-specific colors~~ ✅ (added in ChunkMesh.lean)

---

## Milestones

### Milestone 1: Basic World (MVP) ✅ COMPLETED
- [x] Chunk data structure
- [x] Basic chunk meshing
- [x] Single chunk rendering
- [x] Extract GameState structure

### Milestone 2: Infinite World ✅ COMPLETED
- [x] Multiple chunk loading/unloading
- [x] Procedural terrain generation
- [x] Chunk view distance management

### Milestone 3: Interactivity ✅ COMPLETED
- [x] Block raycasting
- [x] Block placement and destruction
- [x] Block selection highlight
- [x] Basic hotbar UI (keys 1-7 select block type)

### Milestone 4: Physics
- [ ] Player collision with blocks
- [ ] Gravity and jumping
- [ ] Swimming in water

### Milestone 5: Persistence
- [ ] Chunk serialization
- [ ] World save/load
- [ ] Auto-save

---

*Last updated: 2025-12-30 (Milestone 3 complete - block highlight and hotbar added)*
