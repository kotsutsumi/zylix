# Performance & Optimization Module

> **Module**: `core/src/perf/`
> **Version**: v0.25.0 (Released in v0.23.0)

## Overview

The Performance module provides a comprehensive optimization toolkit for Zylix applications. It includes Virtual DOM diff optimization, memory pooling, render batching, error boundaries, analytics, and bundle optimization.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Performance Module                           │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │   VDom      │  │   Memory    │  │      Render             │ │
│  │  Optimizer  │  │    Pool     │  │      Batcher            │ │
│  │  (Caching)  │  │ (Allocation)│  │  (Frame Scheduling)     │ │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘ │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │   Error     │  │  Analytics  │  │       Bundle            │ │
│  │  Boundary   │  │   & Crash   │  │      Analyzer           │ │
│  │ (Isolation) │  │  Reporter   │  │   (Tree Shaking)        │ │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Sub-modules

| Module | File | Description |
|--------|------|-------------|
| VDom Optimizer | `vdom_opt.zig` | Virtual DOM diff caching and optimization |
| Memory | `memory.zig` | Memory pools and allocation optimization |
| Batch | `batch.zig` | Render batching and frame scheduling |
| Error Boundary | `error_boundary.zig` | Error isolation and recovery |
| Analytics | `analytics.zig` | Analytics hooks and crash reporting |
| Bundle | `bundle.zig` | Bundle analysis and tree shaking |

## Quick Start

```zig
const perf = @import("perf/perf.zig");

// Create profiler with default config
var profiler = try perf.Profiler.init(allocator, .{});
defer profiler.deinit();

// Measure render performance
var section = profiler.beginSection("render");
// ... render code ...
const duration = profiler.endSection(&section);

// Check metrics
const metrics = profiler.getMetrics();
if (!metrics.isWithinTarget(16_666_667)) {
    std.debug.print("Render too slow: {d}ms\n", .{duration / 1_000_000});
}
```

## Configuration

### PerfConfig

```zig
pub const PerfConfig = struct {
    /// Enable Virtual DOM diff caching
    enable_diff_cache: bool = true,

    /// Maximum diff cache size (entries)
    max_diff_cache_size: usize = 1000,

    /// Enable memory pooling
    enable_memory_pool: bool = true,

    /// Memory pool initial size (bytes)
    pool_initial_size: usize = 1024 * 1024, // 1MB

    /// Enable render batching
    enable_render_batching: bool = true,

    /// Target frame time (nanoseconds)
    target_frame_time_ns: u64 = 16_666_667, // ~60fps

    /// Enable error boundaries
    enable_error_boundaries: bool = true,

    /// Enable analytics
    enable_analytics: bool = false,

    /// Enable crash reporting
    enable_crash_reporting: bool = false,

    /// Bundle optimization level
    optimization_level: OptimizationLevel = .balanced,
};
```

### OptimizationLevel

```zig
pub const OptimizationLevel = enum {
    none,      // Minimal optimization, fastest builds
    balanced,  // Balance between size and speed
    size,      // Aggressive size optimization
    speed,     // Aggressive speed optimization
};
```

## Core Types

### Profiler

Main performance profiler that orchestrates all optimization subsystems.

```zig
const perf = @import("perf/perf.zig");

// Initialize with custom config
var profiler = try perf.Profiler.init(allocator, .{
    .enable_diff_cache = true,
    .target_frame_time_ns = 8_333_333, // 120fps target
});
defer profiler.deinit();

// Access sub-systems
if (profiler.vdom_optimizer) |opt| {
    // Use VDOM optimizer
}

if (profiler.memory_pool) |pool| {
    // Use memory pool
}
```

### PerfMetrics

Performance metrics collection.

```zig
pub const PerfMetrics = struct {
    total_render_time_ns: u64,
    render_count: u64,
    avg_render_time_ns: u64,
    max_render_time_ns: u64,
    min_render_time_ns: u64,
    diff_cache_hit_rate: f64,
    pool_utilization: f64,
    frames_dropped: u64,
    errors_caught: u64,
};
```

**Methods:**

```zig
// Record render time
metrics.recordRender(render_time_ns);

// Check if within target
if (metrics.isWithinTarget(16_666_667)) {
    // Performance is good
}

// Get summary
const summary = try metrics.summary(allocator);
defer allocator.free(summary);
std.debug.print("{s}\n", .{summary});

// Reset metrics
metrics.reset();
```

## VDom Optimizer

Optimizes Virtual DOM diff calculations through caching and memoization.

```zig
const vdom_opt = perf.vdom_opt;

var optimizer = try vdom_opt.VDomOptimizer.init(allocator, 1000);
defer optimizer.deinit();

// Check cache before computing diff
if (optimizer.getCached(old_hash, new_hash)) |cached_diff| {
    return cached_diff;
}

// Compute and cache diff
const diff = computeDiff(old_vdom, new_vdom);
optimizer.cache(old_hash, new_hash, diff);
```

## Memory Pool

High-performance memory allocation for hot paths.

```zig
const memory = perf.memory;

// Fixed-size block pool
var pool = try memory.MemoryPool.initWithBlockSize(allocator, 1024 * 1024, 64);
defer pool.deinit();

// Allocate from pool (O(1))
if (pool.alloc()) |block| {
    // Use block...
    pool.free(block);
}

// Check utilization
const utilization = pool.getUtilization();
```

### ObjectPool

Generic typed object pool.

```zig
const memory = perf.memory;

const MyObject = struct {
    value: u32,
    data: [64]u8,
};

var pool = memory.ObjectPool(MyObject).init(allocator);
defer pool.deinit();

// Pre-allocate objects
try pool.preallocate(100);

// Acquire object
const obj = try pool.acquire();
obj.value = 42;

// Release back to pool
try pool.release(obj);

// Get stats
const stats = pool.getStats();
std.debug.print("In use: {d}\n", .{stats.in_use});
```

## Render Batching

Batch render operations for optimal frame pacing.

```zig
const batch = perf.batch;

var batcher = try batch.RenderBatcher.init(allocator);
defer batcher.deinit();

// Queue render operations
try batcher.queue(.{
    .component_id = 1,
    .priority = .high,
    .callback = renderComponent,
});

// Process batch
batcher.flush();
```

### FrameScheduler

Frame-aware task scheduling.

```zig
const batch = perf.batch;

var scheduler = try batch.FrameScheduler.init(allocator, 16_666_667); // 60fps
defer scheduler.deinit();

// Begin frame
var frame = scheduler.beginFrame();

// Schedule work within frame budget
while (frame.hasRemainingBudget()) {
    if (scheduler.getNextTask()) |task| {
        task.execute();
    } else break;
}

// End frame
scheduler.endFrame(&frame);
```

## Error Boundaries

Isolate and recover from component errors.

```zig
const error_boundary = perf.error_boundary;

var boundary = try error_boundary.ErrorBoundary.init(allocator, "MainApp");
defer boundary.deinit();

// Configure
_ = boundary
    .onError(handleError)
    .fallback(renderFallback)
    .withMaxRetries(3);

// Catch errors
boundary.catchError(error_boundary.ErrorContext.init(
    "Component render failed",
    .@"error"
).withComponentPath("App.Header.Logo"));

// Try recovery
if (boundary.tryRecover()) {
    // Retry render
} else {
    // Render fallback
    if (boundary.renderFallback()) |fallback_content| {
        // Use fallback
    }
}

// Get summary
const summary = boundary.getErrorSummary();
std.debug.print("Errors: {d}, Retries: {d}\n", .{
    summary.error_count,
    summary.retry_count
});
```

### ErrorRecovery

Global error recovery strategies.

```zig
const error_boundary = perf.error_boundary;

var recovery = try error_boundary.ErrorRecovery.init(allocator);
defer recovery.deinit();

// Configure strategies per severity
try recovery.setStrategy(.info, .ignore);
try recovery.setStrategy(.warning, .ignore);
try recovery.setStrategy(.@"error", .fallback);
try recovery.setStrategy(.critical, .propagate);

// Handle error
const strategy = recovery.handleError(error_context);
switch (strategy) {
    .retry => attemptRetry(),
    .skip => skipComponent(),
    .fallback => renderFallback(),
    .propagate => return error,
    .ignore => {},
}
```

## Analytics & Crash Reporting

Track performance and report crashes.

```zig
const analytics = perf.analytics;

// Crash Reporter
var reporter = try analytics.CrashReporter.init(allocator);
defer reporter.deinit();

// Add breadcrumbs for debugging
try reporter.addBreadcrumb("User clicked button", "ui");
try reporter.addBreadcrumb("API request started", "network");

// Report crash with context
try reporter.reportCrash("Unhandled exception", .critical);
try reporter.reportCrashWithTrace("Memory allocation failed", .fatal, @errorReturnTrace());

// Analytics Hook
var hook = try analytics.AnalyticsHook.init(allocator);
defer hook.deinit();

// Track events
try hook.track(.page_view, "home_screen");
try hook.trackPerformance("render_time", 16_500_000); // nanoseconds

// A/B Testing
var test = try analytics.ABTest.init(allocator, "button_color");
defer test.deinit();

const variant = test.getVariant("user_123");
// Use variant...
```

## Bundle Optimization

Analyze and optimize bundle size.

```zig
const bundle_mod = perf.bundle;

// Bundle Analyzer
var analyzer = try bundle_mod.BundleAnalyzer.init(allocator);
defer analyzer.deinit();

// Add modules to analyze
try analyzer.addModule("core", 150_000);
try analyzer.addModule("ui", 80_000);
try analyzer.addModule("utils", 20_000);

// Get analysis
const analysis = analyzer.analyze();
std.debug.print("Total size: {d} bytes\n", .{analysis.total_size});
std.debug.print("Largest: {s}\n", .{analysis.largest_module});

// Tree Shaker
var shaker = try bundle_mod.TreeShaker.init(allocator);
defer shaker.deinit();

// Mark used symbols
try shaker.markUsed("main");
try shaker.markUsed("render");

// Get unused symbols for removal
const unused = shaker.getUnused();
for (unused) |symbol| {
    std.debug.print("Unused: {s}\n", .{symbol});
}
```

## Performance Best Practices

### 1. Profile Before Optimizing

```zig
var profiler = try perf.Profiler.init(allocator, .{});

// Measure actual performance
var section = profiler.beginSection("critical_path");
criticalOperation();
const duration = profiler.endSection(&section);

// Only optimize if needed
if (duration > 16_666_667) {
    // Optimization needed
}
```

### 2. Use Memory Pools for Hot Paths

```zig
// Bad: Allocating in hot loop
while (running) {
    const obj = try allocator.create(Object); // Slow!
    defer allocator.destroy(obj);
}

// Good: Use object pool
var pool = memory.ObjectPool(Object).init(allocator);
while (running) {
    const obj = try pool.acquire(); // Fast!
    defer try pool.release(obj);
}
```

### 3. Batch Render Operations

```zig
// Bad: Render each change immediately
for (changes) |change| {
    render(change); // Many repaints!
}

// Good: Batch changes
for (changes) |change| {
    try batcher.queue(change);
}
batcher.flush(); // Single repaint
```

### 4. Use Error Boundaries for Isolation

```zig
// Wrap risky components
var boundary = try ErrorBoundary.init(allocator, "UserWidget");
defer boundary.deinit();

// If one component fails, others continue
if (renderUserWidget()) |_| {
    // Success
} else |err| {
    boundary.catchError(ErrorContext.init(@errorName(err), .@"error"));
    // Render fallback instead of crashing
}
```

## Module API Reference

- [VDom Optimizer](./vdom_opt.md)
- [Memory](./memory.md)
- [Batch](./batch.md)
- [Error Boundary](./error_boundary.md)
- [Analytics](./analytics.md)
- [Bundle](./bundle.md)

## Related Documentation

- [State Management](../core/state.md)
- [Events](../core/events.md)
- [VDOM](../core/vdom.md)
