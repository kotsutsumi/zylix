# VTuber Demo

Sample demonstrating VTuber/Live2D-style character animation and interaction.

## Overview

This sample showcases Live2D-inspired animation:
- Character model rendering
- Expression system
- Motion blending
- Face tracking simulation
- Interactive accessories

## Project Structure

```
vtuber-demo/
├── README.md
├── core/
│   ├── build.zig
│   └── src/
│       ├── main.zig    # Entry point
│       ├── app.zig     # Character state
│       └── ui.zig      # UI components
└── platforms/
    └── web/            # Web shell
```

## Features

### Character System
- Multiple character models
- Part-based rendering
- Physics simulation (hair, accessories)
- Breathing animation

### Expression System
- Preset expressions
- Eye tracking
- Mouth sync
- Blush effects

### Motion System
- Idle animations
- Wave/greet motions
- Head tilt
- Body movement

### Interaction
- Mouse/touch tracking
- Click reactions
- Accessory toggles
- Background changes

## Quick Start

```bash
cd core && zig build
zig build test
zig build wasm
```

## C ABI Exports

```c
// Character
void vtuber_init(void);
void vtuber_update(float delta);
void vtuber_set_character(uint8_t id);

// Expression
void vtuber_set_expression(uint8_t expr);
void vtuber_set_mouth_open(float amount);
void vtuber_set_eye_position(float x, float y);

// Motion
void vtuber_play_motion(uint8_t motion);
void vtuber_set_head_rotation(float x, float y);

// Interaction
void vtuber_on_touch(float x, float y);
void vtuber_toggle_accessory(uint8_t id);
```

## Expressions

| Expression | Description |
|------------|-------------|
| neutral | Default expression |
| happy | Smiling, eyes curved |
| surprised | Wide eyes, small mouth |
| sad | Downturned eyes |
| angry | Furrowed brows |
| wink | One eye closed |

## License

MIT License
