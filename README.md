# Cairn

A Minecraft-style voxel game written in Lean 4 using [Afferent](https://github.com/nathanial/afferent) for Metal GPU rendering.

## Features

- **FPS Camera** - WASD + mouse look navigation
- **3D Rendering** - Metal-based GPU rendering with lighting
- **Block System** - Foundational block types for voxel worlds

## Requirements

- macOS (Metal rendering)
- Lean 4.26.0
- Homebrew dependencies: `freetype`, `assimp`

## Building

**Important:** Use `./build.sh` instead of `lake build` directly (sets `LEAN_CC=/usr/bin/clang` for macOS framework linking).

```bash
# Build the project
./build.sh

# Build and run
./run.sh

# Run tests
./build.sh cairn_tests && .lake/build/bin/cairn_tests
```

## Controls

| Key | Action |
|-----|--------|
| W/S | Move forward/backward |
| A/D | Strafe left/right |
| Q/E | Move down/up |
| Mouse | Look around (when captured) |
| Click/Escape | Toggle mouse capture |

## Project Structure

```
cairn/
├── build.sh           # Build script
├── run.sh             # Build and run script
├── lakefile.lean      # Lake build configuration
├── Main.lean          # Game entry point
├── Cairn.lean         # Library root
├── Cairn/
│   ├── Core/
│   │   └── Block.lean # Block type definitions
│   ├── Camera.lean    # Camera configuration
│   └── Mesh.lean      # Mesh helpers
└── Tests/
    └── Main.lean      # Test suite
```

## Dependencies

- **afferent** - Graphics rendering (Metal GPU)
- **linalg** - Linear algebra (via afferent)
- **crucible** - Test framework

## License

MIT License - see [LICENSE](LICENSE) for details.
