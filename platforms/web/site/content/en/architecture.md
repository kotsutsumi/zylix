---
title: "Architecture"
weight: 3
---

# Architecture

## Overview

```
                    ┌─────────────────────────────┐
                    │     Zylix Core (Zig)        │
                    │  ┌───────────────────────┐  │
                    │  │ State Management      │  │
                    │  │ Business Logic        │  │
                    │  │ ViewModel Generation  │  │
                    │  │ Diff Calculation      │  │
                    │  │ Event Handling        │  │
                    │  └───────────────────────┘  │
                    └─────────────┬───────────────┘
                                  │
                              C ABI
                                  │
        ┌─────────┬─────────┬─────┼─────┬─────────┬─────────┐
        ▼         ▼         ▼     ▼     ▼         ▼         ▼
   ┌─────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐
   │   iOS   │ │Android │ │ macOS  │ │Windows │ │ Linux  │ │  Web   │
   │ SwiftUI │ │Compose │ │SwiftUI │ │ WinUI  │ │  GTK4  │ │  WASM  │
   └─────────┘ └────────┘ └────────┘ └────────┘ └────────┘ └────────┘
```

## Core Components

### State Management

All application state lives in Zig:

```zig
pub const AppState = struct {
    counter: i64 = 0,
    user_name: [256]u8 = undefined,
    user_name_len: usize = 0,
    is_authenticated: bool = false,
};
```

### Event System

Events flow from UI to Core:

```zig
pub const EventType = enum(u32) {
    none = 0,
    increment = 1,
    decrement = 2,
    reset = 3,
    set_value = 4,
};

pub fn dispatch(event_type: EventType, payload: ?*const anyopaque) void {
    switch (event_type) {
        .increment => state.counter += 1,
        .decrement => state.counter -= 1,
        // ...
    }
}
```

### C ABI Boundary

Zero-cost interop via C ABI:

```zig
// Export for native platforms
pub export fn zylix_init() i32;
pub export fn zylix_dispatch(event_type: u32, payload: ?*const anyopaque) i32;
pub export fn zylix_get_counter() i64;
```

## Platform Shells

### iOS/macOS (SwiftUI)

```swift
import ZylixCore

struct ContentView: View {
    @State private var counter: Int64 = 0

    var body: some View {
        VStack {
            Text("\(counter)")
            Button("Increment") {
                zylix_dispatch(1, nil)
                counter = zylix_get_counter()
            }
        }
    }
}
```

### Android (Jetpack Compose)

```kotlin
@Composable
fun CounterScreen() {
    var counter by remember { mutableStateOf(0L) }

    Column {
        Text("$counter")
        Button(onClick = {
            ZylixCore.dispatch(1, null)
            counter = ZylixCore.getCounter()
        }) {
            Text("Increment")
        }
    }
}
```

### Web (WASM)

```javascript
const wasm = await WebAssembly.instantiate(wasmBytes);
const { zylix_init, zylix_dispatch, zylix_wasm_get_counter } = wasm.instance.exports;

zylix_init();
document.getElementById('increment').onclick = () => {
    zylix_dispatch(1, 0);
    document.getElementById('counter').textContent = zylix_wasm_get_counter();
};
```

## Memory Model

### Ownership Rules

1. **Zig allocates → Zig frees**
2. **Host allocates → Host frees**
3. **Transfer ownership → Explicit handoff functions**
4. **Shared read → Immutable pointer, Zig lifetime**

### Memory Layout

```zig
// GPU-aligned for zero-copy transfer
pub const Vertex = extern struct {
    position: Vec3,  // 16 bytes (padded)
    color: Vec4,     // 16 bytes
};

// 256-byte uniform buffer (WebGPU requirement)
pub const Uniforms = extern struct {
    model: Mat4,      // 64 bytes
    view: Mat4,       // 64 bytes
    projection: Mat4, // 64 bytes
    _padding: [64]u8, // Pad to 256
};
```

## Build System

Single toolchain for all targets:

```bash
# Build for all platforms
zig build all

# Individual targets
zig build ios          # iOS ARM64
zig build ios-sim      # iOS Simulator
zig build android-arm64
zig build macos-arm64
zig build windows-x64
zig build linux-x64
zig build wasm         # WebAssembly
```

## Comparison

| Aspect | Flutter | Electron | Tauri | Zylix |
|--------|---------|----------|-------|-------|
| UI Rendering | Skia (custom) | Chromium | WebView | **OS Native** |
| Runtime | Dart VM | Node.js | Rust + WebView | **None** |
| Binary Size | ~15MB+ | ~150MB+ | ~3MB+ | **<1MB** |
| Memory | High | Very High | Medium | **Low** |
| OS Integration | Limited | Limited | Medium | **Full** |
| IME/A11y | Custom | Chromium | WebView | **Native** |
