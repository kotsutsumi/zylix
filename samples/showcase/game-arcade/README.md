# Game Arcade Showcase

Demonstration of Zylix game engine features and mini-games.

## Overview

This showcase demonstrates game development capabilities:
- Game loop and timing
- Input handling (touch, keyboard, gamepad)
- Sprite rendering and animation
- Collision detection
- Score and state management

## Project Structure

```
game-arcade/
├── README.md
├── core/
│   ├── build.zig
│   └── src/
│       ├── main.zig        # Entry point
│       ├── app.zig         # App state
│       └── arcade.zig      # Arcade UI
└── platforms/
```

## Mini-Games

### Breakout Clone
- Paddle and ball physics
- Brick destruction
- Power-ups and scoring

### Snake
- Grid-based movement
- Growing snake mechanics
- Food spawning

### Pong
- Two-player or AI opponent
- Ball physics and scoring

### Memory Match
- Card flipping animation
- Match detection
- Timer and score

## Features

### Game Loop
- Fixed timestep updates
- Frame rate control
- Delta time handling

### Input
- Touch/mouse input
- Keyboard controls
- Virtual gamepad

### Rendering
- Sprite batching
- Animation frames
- Particle effects

## Quick Start

```bash
cd core && zig build
zig build test
zig build wasm
```

## Related Showcases

- [Animation Studio](../animation-studio/) - Animation system
- [3D Viewer](../3d-viewer/) - 3D graphics

## License

MIT License
