# watchOS Companion

Sample demonstrating Apple Watch companion app features.

## Overview

This sample showcases watchOS capabilities:
- Watch complications
- Workout sessions
- Heart rate monitoring
- Notifications
- Watch connectivity

## Project Structure

```
watchos-companion/
├── README.md
├── core/
│   ├── build.zig
│   └── src/
│       ├── main.zig    # Entry point
│       ├── app.zig     # App state
│       └── ui.zig      # UI components
└── platforms/
    └── watchos/        # watchOS shell
```

## Features

### Complications
- Circular complications
- Modular complications
- Graphic complications

### Workouts
- Start/pause/end
- Workout types
- Metrics tracking

### Health
- Heart rate
- Steps
- Calories

### Connectivity
- iPhone sync
- Data transfer
- Message passing

## Quick Start

```bash
cd core && zig build
zig build test
zig build wasm
```

## C ABI Exports

```c
// Complications
void app_update_complication(uint8_t family, uint32_t value);

// Workouts
void app_start_workout(uint8_t type);
void app_pause_workout(void);
void app_end_workout(void);

// Health
uint32_t app_get_heart_rate(void);
uint32_t app_get_steps(void);

// Connectivity
bool app_is_phone_connected(void);
void app_send_message(const char* data);
```

## Platform Requirements

- watchOS 8.0+
- Paired iPhone with iOS 15+

## License

MIT License
