# Web PWA

Sample demonstrating Progressive Web App features.

## Overview

This sample showcases PWA capabilities:
- Service Worker caching
- Offline support
- Push notifications
- Install prompt
- Background sync

## Project Structure

```
web-pwa/
├── README.md
├── core/
│   ├── build.zig
│   └── src/
│       ├── main.zig    # Entry point
│       ├── app.zig     # App state
│       └── ui.zig      # UI components
└── platforms/
    └── web/            # Web shell with SW
```

## Features

### Service Worker
- Cache-first strategy
- Network fallback
- Background updates

### Offline
- Offline page support
- Cached content access
- Sync when online

### Push Notifications
- Permission request
- Notification display
- Click handling

### Install
- Install prompt
- Add to home screen
- Standalone mode

## Quick Start

```bash
cd core && zig build
zig build test
zig build wasm
```

## C ABI Exports

```c
// Service Worker
bool app_is_sw_registered(void);
void app_update_sw(void);

// Offline
bool app_is_online(void);
uint32_t app_get_cached_count(void);

// Push
bool app_has_push_permission(void);
void app_request_push_permission(void);

// Install
bool app_can_install(void);
void app_prompt_install(void);
bool app_is_installed(void);
```

## Platform Requirements

- Modern browser with Service Worker support
- HTTPS required for production

## License

MIT License
