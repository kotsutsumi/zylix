# Puzzle World

Sample demonstrating puzzle game mechanics with multiple puzzle types.

## Overview

This sample showcases puzzle game development:
- Match-3 mechanics
- Sliding puzzles
- Logic puzzles
- Scoring and progression
- Hint system

## Project Structure

```
puzzle-world/
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

### Match-3 Mode
- Gem swapping
- Chain reactions
- Special gems
- Combo scoring

### Sliding Puzzle
- 3x3, 4x4, 5x5 boards
- Move counter
- Shuffle and solve

### Logic Puzzles
- Pattern matching
- Memory games
- Sequence solving

## Quick Start

```bash
cd core && zig build
zig build test
zig build wasm
```

## C ABI Exports

```c
// Game control
void puzzle_init(void);
void puzzle_select_mode(uint8_t mode);
void puzzle_start(void);
void puzzle_reset(void);

// Match-3
void match3_select(uint8_t row, uint8_t col);
void match3_swap(uint8_t dir);

// Sliding
void sliding_move(uint8_t dir);

// State
uint32_t puzzle_get_score(void);
uint32_t puzzle_get_moves(void);
```

## License

MIT License
