# Animation Studio Showcase

Comprehensive demonstration of Zylix animation capabilities.

## Overview

This showcase demonstrates all animation features in Zylix:
- Timeline-based keyframe animations
- State machine for complex animation flows
- Lottie animation format support
- Live2D character animation support

## Project Structure

```
animation-studio/
├── README.md
├── core/
│   ├── build.zig
│   └── src/
│       ├── main.zig        # Entry point
│       ├── app.zig         # App state
│       └── studio.zig      # Animation UI
└── platforms/
```

## Features

### Timeline Animations
- Keyframe-based animation system
- Multiple easing functions (linear, ease-in-out, bounce, etc.)
- Loop modes (none, loop, pingpong)
- Playback controls (play, pause, seek, speed)

### State Machine
- Multi-state animation controller
- Transition conditions and blending
- Event-driven state changes
- Layer-based compositing

### Format Support
- **Lottie**: JSON-based vector animations
- **Live2D**: Interactive character animations

## Quick Start

```bash
cd core && zig build
zig build test
zig build wasm
```

## Demo Scenes

1. **Basic Animations**: Transform, opacity, color animations
2. **Character Controller**: State machine with idle/walk/run/jump
3. **Lottie Player**: Playback of Lottie JSON files
4. **Live2D Viewer**: Interactive character with expressions

## Related Templates

- [Blank App](../../templates/blank-app/) - Minimal starter
- [Component Gallery](../component-gallery/) - UI components

## License

MIT License
