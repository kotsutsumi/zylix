# Android Exclusive

Sample demonstrating Android platform-specific features.

## Overview

This sample showcases features unique to the Android platform:
- Material You dynamic colors
- Home screen widgets
- Work profile support
- Rich notifications
- App shortcuts

## Project Structure

```
android-exclusive/
├── README.md
├── core/
│   ├── build.zig
│   └── src/
│       ├── main.zig    # Entry point
│       ├── app.zig     # App state
│       └── ui.zig      # UI components
└── platforms/
    └── android/        # Android-specific shell
```

## Features

### Material You
- Dynamic color extraction
- Themed components
- System accent colors

### Widgets
- Home screen widgets
- Glance widgets
- Widget configuration

### Work Profile
- Managed profile detection
- Cross-profile data
- Work mode toggle

### Notifications
- Notification channels
- Rich notifications
- Notification actions

### App Shortcuts
- Static shortcuts
- Dynamic shortcuts
- Pinned shortcuts

## Quick Start

```bash
cd core && zig build
zig build test
zig build wasm
```

## C ABI Exports

```c
// Material You
uint32_t app_get_primary_color(void);
uint32_t app_get_secondary_color(void);
void app_set_dynamic_colors(bool enabled);

// Notifications
void app_show_notification(uint8_t channel, const char* title, const char* body);
void app_create_channel(uint8_t id, const char* name);

// Shortcuts
void app_add_shortcut(const char* id, const char* label);
void app_remove_shortcut(const char* id);
```

## Platform Requirements

- Android 8.0+ (API 26)
- Material You requires Android 12+ (API 31)

## License

MIT License
