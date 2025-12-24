# Zylix API Reference

> **Version**: v0.24.0
> **Last Updated**: 2025-12-24

## Overview

This directory contains comprehensive API documentation for all Zylix modules. Each module has detailed documentation including types, functions, and usage examples.

## Module Index

### Core Modules

| Module | Description | Documentation |
|--------|-------------|---------------|
| [State](./core/state.md) | Application state management | ✅ |
| [Events](./core/events.md) | Event system and handlers | ✅ |
| [ABI](./core/abi.md) | C ABI exports for FFI | ✅ |
| [VDOM](./core/vdom.md) | Virtual DOM implementation | ✅ |
| [Component](./core/component.md) | Component system | ✅ |
| [Router](./core/router.md) | Routing system | ✅ |

### Platform Modules

| Module | Description | Documentation |
|--------|-------------|---------------|
| [Animation](./animation/README.md) | Animation system with timeline, state machine, Lottie, Live2D | ✅ |
| [Graphics3D](./graphics3d/README.md) | 3D graphics rendering | ✅ |
| [AI](./ai/README.md) | AI integration (LLM, Whisper) | ✅ |
| [WASM](./wasm/README.md) | WebAssembly support | ✅ |

### Enterprise Modules

| Module | Description | Documentation |
|--------|-------------|---------------|
| [Server](./server/README.md) | HTTP/gRPC server runtime | ✅ |
| [Edge](./edge/README.md) | Edge platform adapters | ✅ |
| [Database](./database/README.md) | Database connectivity | ✅ |
| [mBaaS](./mbaas/README.md) | Mobile Backend as a Service | ✅ |

### Productivity Modules

| Module | Description | Documentation |
|--------|-------------|---------------|
| [PDF](./pdf/README.md) | PDF generation and parsing | ✅ |
| [Excel](./excel/README.md) | Excel file handling | ✅ |
| [NodeFlow](./nodeflow/README.md) | Node-based UI system | ✅ |

### Developer Tools

| Module | Description | Documentation |
|--------|-------------|---------------|
| [Tooling](./tooling/README.md) | Developer tooling APIs | ✅ |
| [Performance](./perf/README.md) | Performance optimization | ✅ |
| [Test](./test/README.md) | Testing framework | ✅ |

## Quick Start

### Import the Zylix Core

```zig
const zylix = @import("zylix");

// Access core types
const State = zylix.State;
const AppState = zylix.AppState;

// Access modules
const ai = zylix.ai;
const animation = zylix.animation;
const server = zylix.server;
```

### Common Patterns

#### State Management

```zig
const state = zylix.state;

// Create application state
var app_state = state.AppState.init();
app_state.setCounter(0);

// Get state diff for UI updates
const diff = app_state.getDiff();
```

#### Event Handling

```zig
const events = zylix.events;

// Create event handler
var handler = events.EventHandler.init(allocator);
handler.on(.click, handleClick);
handler.on(.keydown, handleKeyDown);
```

#### HTTP Server

```zig
const server = zylix.server;

// Create HTTP server
var app = try server.Zylix.init(allocator, .{
    .port = 8080,
    .workers = 4,
});

app.get("/", handleIndex);
app.get("/api/users", handleUsers);

try app.listen();
```

## Version Compatibility

| Zylix Version | Zig Version | Notes |
|---------------|-------------|-------|
| v0.24.0 | 0.15.x | Current |
| v0.23.0 | 0.15.x | Performance Optimization |
| v0.22.0 | 0.15.x | Server Runtime |

## Build Targets

```bash
# Native build
zig build

# Cross-compilation
zig build -Dtarget=aarch64-macos        # macOS ARM64
zig build -Dtarget=x86_64-linux         # Linux x64
zig build -Dtarget=wasm32-freestanding  # WebAssembly
zig build -Dtarget=aarch64-linux-android # Android ARM64
```

## Additional Resources

- [Getting Started Guide](../../site/content/docs/getting-started.md)
- [Architecture Overview](../ARCHITECTURE.md)
- [Contributing Guide](../../CONTRIBUTING.md)
- [Changelog](../../CHANGELOG.md)
