# Desktop Native

Sample demonstrating desktop platform-specific features.

## Overview

This sample showcases desktop-native capabilities:
- System tray integration
- File system access
- Native notifications
- Keyboard shortcuts
- Window management

## Project Structure

```
desktop-native/
├── README.md
├── core/
│   ├── build.zig
│   └── src/
│       ├── main.zig    # Entry point
│       ├── app.zig     # App state
│       └── ui.zig      # UI components
└── platforms/
    └── desktop/        # Desktop shell
```

## Features

### System Tray
- Tray icon
- Context menu
- Quick actions

### File System
- Open/save dialogs
- Recent files
- File watching

### Notifications
- Native toasts
- Action buttons
- Badge counts

### Shortcuts
- Global shortcuts
- Menu shortcuts
- Custom bindings

### Window
- Multiple windows
- Always on top
- Fullscreen mode

## Quick Start

```bash
cd core && zig build
zig build test
zig build wasm
```

## C ABI Exports

```c
// System Tray
void app_set_tray_icon(const char* icon);
void app_set_tray_tooltip(const char* tooltip);

// File System
void app_open_file_dialog(void);
void app_save_file_dialog(void);

// Notifications
void app_show_notification(const char* title, const char* body);

// Shortcuts
void app_register_shortcut(const char* keys, uint32_t action_id);

// Window
void app_set_always_on_top(bool enabled);
void app_toggle_fullscreen(void);
```

## Platform Requirements

- Windows 10+, macOS 10.15+, or Linux with GTK3

## License

MIT License
