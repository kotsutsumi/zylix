# iOS Exclusive

Sample demonstrating iOS and Apple platform-specific features.

## Overview

This sample showcases features unique to the Apple ecosystem:
- Face ID / Touch ID authentication
- Haptic feedback
- HealthKit integration
- Siri shortcuts
- Home screen widgets
- Live Activities

## Project Structure

```
ios-exclusive/
├── README.md
├── core/
│   ├── build.zig
│   └── src/
│       ├── main.zig    # Entry point
│       ├── app.zig     # App state
│       └── ui.zig      # UI components
└── platforms/
    └── ios/            # iOS-specific shell
```

## Features

### Authentication
- Face ID integration
- Touch ID fallback
- Keychain storage

### Haptics
- Impact feedback
- Selection feedback
- Notification feedback

### HealthKit
- Step count access
- Heart rate data
- Workout sessions

### Siri
- Custom intents
- Shortcuts integration
- Voice commands

### Widgets
- Home screen widgets
- Lock screen widgets
- Live Activities

## Quick Start

```bash
cd core && zig build
zig build test
zig build wasm
```

## C ABI Exports

```c
// Authentication
bool app_authenticate_biometric(void);
bool app_is_biometric_available(void);

// Haptics
void app_haptic_impact(uint8_t style);
void app_haptic_selection(void);
void app_haptic_notification(uint8_t type);

// HealthKit
void app_request_health_auth(void);
uint32_t app_get_step_count(void);
```

## Platform Requirements

- iOS 15.0+
- Face ID or Touch ID capable device
- HealthKit entitlement (optional)

## License

MIT License
