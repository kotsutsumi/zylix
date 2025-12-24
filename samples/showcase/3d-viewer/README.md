# 3D Viewer Showcase

Demonstration of Zylix 3D graphics rendering capabilities.

## Overview

This showcase demonstrates 3D rendering features:
- Scene graph management
- Camera controls (orbit, pan, zoom)
- Lighting and materials
- Model loading and display
- Basic transformations

## Project Structure

```
3d-viewer/
├── README.md
├── core/
│   ├── build.zig
│   └── src/
│       ├── main.zig        # Entry point
│       ├── app.zig         # App state
│       └── viewer.zig      # 3D viewer UI
└── platforms/
```

## Features

### Scene Management
- Hierarchical scene graph
- Transform nodes (translate, rotate, scale)
- Object selection and manipulation

### Camera System
- Orbit camera controls
- Pan and zoom
- Perspective/orthographic projection
- Camera presets (front, top, side)

### Rendering
- Basic shapes (cube, sphere, cylinder, plane)
- Wireframe and solid modes
- Grid and axis helpers
- Background color customization

### Lighting
- Ambient, directional, point lights
- Shadow placeholder
- Material properties

## Quick Start

```bash
cd core && zig build
zig build test
zig build wasm
```

## Demo Scenes

1. **Primitives**: Basic 3D shapes showcase
2. **Scene Graph**: Parent-child transformations
3. **Materials**: Different material properties
4. **Lighting**: Light types and shadows

## Related Showcases

- [Animation Studio](../animation-studio/) - Animation system
- [Game Arcade](../game-arcade/) - Game engine features

## License

MIT License
