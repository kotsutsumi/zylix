# Analytics Pro

Dashboard and data visualization application demonstrating charts, metrics, and real-time data.

## Overview

Analytics Pro showcases data visualization patterns:
- Dashboard widgets
- Chart rendering
- Metric cards
- Data aggregation
- Time-series data

## Project Structure

```
analytics-pro/
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

### Dashboard
- Overview widgets
- Key metrics
- Quick actions
- Recent activity

### Charts
- Line charts
- Bar charts
- Pie charts
- Area charts

### Data
- Real-time updates
- Historical data
- Data filtering
- Export options

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

// Navigation
void app_set_screen(uint8_t screen);
void app_set_time_range(uint8_t range);

// Data
uint32_t app_get_metric_value(uint8_t metric_id);
float app_get_change_percent(uint8_t metric_id);
```

## Data Model

### Metric
```zig
const Metric = struct {
    id: u32,
    name: [32]u8,
    value: u32,
    change_percent: f32,
    trend: Trend,
};
```

### DataPoint
```zig
const DataPoint = struct {
    timestamp: i64,
    value: f32,
};
```

## License

MIT License
