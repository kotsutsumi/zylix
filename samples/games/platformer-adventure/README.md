# Platformer Adventure

Sample demonstrating a 2D platformer game with physics and level progression.

## Overview

This sample showcases platformer game development:
- Player physics and controls
- Platform collision detection
- Collectibles and scoring
- Enemy AI patterns
- Level management

## Project Structure

```
platformer-adventure/
├── README.md
├── core/
│   ├── build.zig
│   └── src/
│       ├── main.zig    # Entry point
│       ├── app.zig     # Game state
│       └── ui.zig      # UI components
└── platforms/
    └── web/            # Web shell
```

## Features

### Player Physics
- Gravity and jumping
- Horizontal movement
- Ground detection
- Double jump

### Platforms
- Static platforms
- Moving platforms
- One-way platforms

### Collectibles
- Coins with scoring
- Power-ups (speed, jump boost)
- Health pickups

### Enemies
- Patrol behavior
- Chase behavior
- Contact damage

## Quick Start

```bash
cd core && zig build
zig build test
zig build wasm
```

## C ABI Exports

```c
// Game control
void game_init(void);
void game_update(float delta);
void game_render(void);

// Player input
void player_move_left(void);
void player_move_right(void);
void player_jump(void);
void player_stop(void);

// Game state
uint8_t game_get_state(void);
uint32_t game_get_score(void);
uint32_t game_get_lives(void);
```

## Game States

| State | Description |
|-------|-------------|
| menu | Main menu screen |
| playing | Active gameplay |
| paused | Game paused |
| game_over | Player lost |
| victory | Level completed |

## License

MIT License
