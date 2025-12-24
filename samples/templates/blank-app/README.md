# Blank App Template

A minimal Zylix application template to start building your cross-platform app.

## Overview

This template provides the bare minimum structure for a Zylix application:
- Single view with a welcome message
- Basic state management
- Event handling foundation
- Platform-ready structure

## Project Structure

```
blank-app/
├── README.md           # This file
├── core/
│   ├── build.zig       # Zig build configuration
│   └── src/
│       ├── main.zig    # Application entry point
│       ├── app.zig     # App state and logic
│       └── ui.zig      # UI components
└── platforms/
    ├── ios/            # iOS shell (SwiftUI)
    ├── android/        # Android shell (Compose)
    └── web/            # Web shell (WASM)
```

## Quick Start

### 1. Build the Core

```bash
cd core
zig build
```

### 2. Run Tests

```bash
zig build test
```

### 3. Build for Web (WASM)

```bash
zig build -Dtarget=wasm32-freestanding -Doptimize=ReleaseSmall
```

### 4. Build for iOS

```bash
zig build -Dtarget=aarch64-macos
```

### 5. Build for Android

```bash
zig build -Dtarget=aarch64-linux-android
```

## Customization

### Adding State

Edit `src/app.zig` to add your application state:

```zig
pub const AppState = struct {
    // Add your state fields here
    user_name: []const u8 = "Guest",
    is_logged_in: bool = false,
};
```

### Adding UI Components

Edit `src/ui.zig` to create your UI:

```zig
pub fn buildMainView(state: *const AppState) VNode {
    return div(.{}, .{
        text("Welcome, "),
        text(state.user_name),
    });
}
```

### Adding Event Handlers

Edit `src/app.zig` to handle events:

```zig
pub fn handleEvent(event: Event) void {
    switch (event.type) {
        .button_click => handleButtonClick(event),
        .text_input => handleTextInput(event),
        else => {},
    }
}
```

## Platform Integration

### iOS (SwiftUI)

The iOS shell in `platforms/ios/` provides:
- SwiftUI wrapper for Zylix views
- Native navigation integration
- iOS-specific features (haptics, notifications)

### Android (Jetpack Compose)

The Android shell in `platforms/android/` provides:
- Compose wrapper for Zylix views
- Material Design integration
- Android-specific features (permissions, services)

### Web (WASM)

The Web shell in `platforms/web/` provides:
- HTML/JS bridge for Zylix
- DOM manipulation layer
- Web-specific features (localStorage, fetch)

## Next Steps

1. Define your app's state model in `app.zig`
2. Create UI components in `ui.zig`
3. Implement event handlers
4. Test on each target platform
5. Deploy!

## Related Templates

- [Tab Navigation](../tab-navigation/) - Multi-tab app structure
- [Drawer Navigation](../drawer-navigation/) - Side drawer navigation
- [Dashboard Layout](../dashboard-layout/) - Dashboard with widgets

## License

MIT License - Use freely in your projects.
