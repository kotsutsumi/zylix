# Space Shooter

Sample demonstrating a classic space shooter game with waves and power-ups.

## Overview

This sample showcases shoot-em-up game development:
- Player ship controls
- Enemy wave system
- Bullet patterns
- Power-ups and upgrades
- Boss battles

## Project Structure

```
space-shooter/
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

### Player Ship
- Movement controls
- Primary and secondary fire
- Shield system
- Lives and continues

### Enemies
- Wave spawning
- Formation patterns
- Multiple enemy types
- Boss encounters

### Power-ups
- Weapon upgrades
- Shield restore
- Speed boost
- Special weapons

### Scoring
- Enemy kills
- Combo multiplier
- Time bonus
- High score tracking

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
void game_start(void);
void game_pause(void);

// Player input
void player_move(float dx, float dy);
void player_fire(void);
void player_special(void);

// State
uint32_t game_get_score(void);
uint8_t game_get_lives(void);
uint8_t game_get_wave(void);
```

## Controls

| Input | Action |
|-------|--------|
| Arrow Keys / WASD | Move ship |
| Space / Z | Primary fire |
| X | Special weapon |
| P | Pause |

## License

MIT License
