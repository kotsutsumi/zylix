# Fit Track

Fitness tracking application demonstrating workout logging, goals, and progress tracking.

## Overview

Fit Track showcases fitness app patterns:
- Workout logging
- Goal tracking
- Progress charts
- Activity history
- Health metrics

## Project Structure

```
fit-track/
├── README.md
├── core/
│   ├── build.zig
│   └── src/
│       ├── main.zig    # Entry point
│       ├── app.zig     # App state
│       └── ui.zig      # UI components
└── platforms/
```

## Features

### Workouts
- Log workouts
- Exercise library
- Custom routines
- Workout history

### Goals
- Daily step goals
- Calorie targets
- Weekly activity goals
- Streak tracking

### Progress
- Weight tracking
- Activity charts
- Achievement badges

## Quick Start

```bash
cd core && zig build
zig build test
zig build wasm
```

## C ABI Exports

```c
// Initialization
void app_init(void);
void app_deinit(void);

// Workouts
void app_log_workout(uint8_t type, uint32_t duration, uint32_t calories);
void app_complete_workout(uint32_t id);

// Goals
void app_set_step_goal(uint32_t steps);
void app_add_steps(uint32_t steps);
uint32_t app_get_steps_today(void);
```

## Data Model

### Workout
```zig
const Workout = struct {
    id: u32,
    type: WorkoutType,
    duration: u32,  // minutes
    calories: u32,
    completed_at: i64,
};
```

## License

MIT License
