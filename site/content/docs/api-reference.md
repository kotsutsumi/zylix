---
title: API Reference
weight: 50
---

# Zylix API Reference

Complete API documentation for all Zylix modules. This reference covers the public APIs for building cross-platform applications with Zylix.

## Module Overview

### Core Modules

| Module | Description |
|--------|-------------|
| **State** | Application state management with diff tracking |
| **Events** | Event system for user interactions |
| **VDOM** | Virtual DOM implementation |
| **Component** | Component system with lifecycle |
| **Router** | Client-side routing |
| **ABI** | C ABI for platform integration |

### Feature Modules

| Module | Description |
|--------|-------------|
| **AI** | AI/ML integration (LLM, Whisper) |
| **Animation** | Timeline, state machine, Lottie, Live2D |
| **Graphics3D** | 3D rendering with scene graph |
| **Server** | HTTP/gRPC server runtime |
| **Edge** | Edge platform adapters (Cloudflare, Vercel, AWS) |
| **Database** | Database connectivity |

### Productivity Modules

| Module | Description |
|--------|-------------|
| **PDF** | PDF generation and parsing |
| **Excel** | Excel file handling |
| **NodeFlow** | Node-based UI system |

### Performance Modules

| Module | Description |
|--------|-------------|
| **Performance** | Profiling, memory pools, render batching |
| **Error Boundary** | Error isolation and recovery |
| **Analytics** | Crash reporting and analytics |
| **Bundle** | Bundle analysis and tree shaking |

## Quick Reference

### State Management

```zig
const zylix = @import("zylix");

// Initialize state
zylix.state.init();
defer zylix.state.deinit();

// Access state
const current = zylix.state.getState();
std.debug.print("Counter: {d}\n", .{current.app.counter});

// Modify state
zylix.state.handleIncrement();

// Get diff for UI updates
const diff = zylix.state.calculateDiff();
```

### Event Handling

```zig
const events = zylix.events;

// Dispatch event
const result = events.dispatch(
    @intFromEnum(events.EventType.counter_increment),
    null,
    0
);

// With payload
const payload = events.ButtonEvent{ .button_id = 0 };
_ = events.dispatch(
    @intFromEnum(events.EventType.button_press),
    @ptrCast(&payload),
    @sizeOf(events.ButtonEvent)
);
```

### HTTP Server

```zig
const server = zylix.server;

var app = try server.Zylix.init(allocator, .{
    .port = 8080,
    .workers = 4,
});
defer app.deinit();

app.get("/", handleIndex);
app.get("/api/users", handleUsers);
app.post("/api/users", createUser);

try app.listen();
```

### Performance Profiling

```zig
const perf = zylix.perf;

var profiler = try perf.Profiler.init(allocator, .{
    .enable_diff_cache = true,
    .target_frame_time_ns = 16_666_667, // 60fps
});
defer profiler.deinit();

// Measure section
var section = profiler.beginSection("render");
renderFrame();
const duration = profiler.endSection(&section);

// Check metrics
const metrics = profiler.getMetrics();
if (!metrics.isWithinTarget(16_666_667)) {
    std.debug.print("Slow frame: {d}ms\n", .{duration / 1_000_000});
}
```

### Error Boundaries

```zig
const error_boundary = zylix.perf.error_boundary;

var boundary = try error_boundary.ErrorBoundary.init(allocator, "App");
defer boundary.deinit();

_ = boundary
    .onError(handleError)
    .fallback(renderFallback)
    .withMaxRetries(3);

// Catch errors
boundary.catchError(
    error_boundary.ErrorContext.init("Render failed", .@"error")
);

// Recovery
if (boundary.tryRecover()) {
    // Retry
} else {
    // Use fallback
}
```

## Type Reference

### Core Types

```zig
// State types
pub const State = zylix.State;
pub const AppState = zylix.AppState;
pub const UIState = zylix.UIState;

// Event types
pub const EventType = zylix.EventType;

// Server types
pub const Zylix = zylix.Zylix;
pub const HttpRequest = zylix.HttpRequest;
pub const HttpResponse = zylix.HttpResponse;

// Performance types
pub const Profiler = zylix.Profiler;
pub const PerfConfig = zylix.PerfConfig;
pub const PerfMetrics = zylix.PerfMetrics;

// Edge types
pub const EdgePlatform = zylix.EdgePlatform;
pub const CloudflareAdapter = zylix.CloudflareAdapter;
pub const VercelAdapter = zylix.VercelAdapter;
```

### Configuration Types

```zig
// Performance configuration
pub const PerfConfig = struct {
    enable_diff_cache: bool = true,
    max_diff_cache_size: usize = 1000,
    enable_memory_pool: bool = true,
    pool_initial_size: usize = 1024 * 1024,
    enable_render_batching: bool = true,
    target_frame_time_ns: u64 = 16_666_667,
    enable_error_boundaries: bool = true,
    enable_analytics: bool = false,
    enable_crash_reporting: bool = false,
    optimization_level: OptimizationLevel = .balanced,
};
```

## Build Commands

```bash
# Native build
cd core && zig build

# Run tests
cd core && zig build test

# Cross-compilation
zig build -Dtarget=wasm32-freestanding    # WebAssembly
zig build -Dtarget=aarch64-macos          # macOS ARM64
zig build -Dtarget=aarch64-linux-android  # Android ARM64
zig build -Dtarget=x86_64-linux           # Linux x64
zig build -Dtarget=x86_64-windows         # Windows x64
```

## Full API Documentation

For complete API documentation with all types, functions, and examples, see:

- [GitHub: docs/API/](https://github.com/kotsutsumi/zylix/tree/main/docs/API)
- [Core Modules](https://github.com/kotsutsumi/zylix/tree/main/docs/API/core)
- [Performance Module](https://github.com/kotsutsumi/zylix/tree/main/docs/API/perf)

## Related Resources

- [Getting Started](../getting-started) - Quick start guide
- [Core Concepts](../core-concepts) - Understanding Zylix architecture
- [Architecture](../architecture) - Deep dive into internals
