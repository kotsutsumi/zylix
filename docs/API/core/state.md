# State Management API

> **Module**: `core/src/state.zig`
> **Version**: v0.25.0

## Overview

The State module manages all application state in Zylix Core. State is owned entirely by Zig and exposed read-only to platform shells (iOS, Android, Web, Desktop).

## Architecture

```
┌─────────────────────────────────────────────────┐
│                  Platform Shell                  │
│            (iOS / Android / Web)                 │
└─────────────────────┬───────────────────────────┘
                      │ Read-only access
                      ▼
┌─────────────────────────────────────────────────┐
│                   State Module                   │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────┐ │
│  │   AppState  │  │   UIState   │  │  Store  │ │
│  │  (counter,  │  │  (screen,   │  │  (diff  │ │
│  │   input)    │  │   loading)  │  │tracking)│ │
│  └─────────────┘  └─────────────┘  └─────────┘ │
└─────────────────────────────────────────────────┘
```

## Types

### State

Main state container that holds all application state.

```zig
pub const State = struct {
    /// State version (monotonically increasing)
    version: u64 = 0,

    /// Application-specific state
    app: AppState = .{},

    /// UI state hints
    ui: UIState = .{},

    /// Last error message
    last_error: ?[]const u8 = null,
};
```

### AppState

Application-specific state structure. Customize per application.

```zig
pub const AppState = struct {
    /// Counter value
    counter: i64 = 0,

    /// Form text input
    input_text: [256]u8 = [_]u8{0} ** 256,
    input_len: usize = 0,
};
```

### UIState

UI state hints for the platform shell.

```zig
pub const UIState = struct {
    /// Current screen
    screen: Screen = .home,

    /// Loading indicator
    loading: bool = false,

    pub const Screen = enum(u32) {
        home = 0,
        detail = 1,
        settings = 2,
    };
};
```

### ABIState

ABI-compatible state structure for C interop.

```zig
pub const ABIState = extern struct {
    version: u64,
    screen: u32,
    loading: bool,
    error_message: ?[*:0]const u8,
    view_data: ?*const anyopaque,
    view_data_size: usize,
};
```

## Functions

### Initialization

#### `init()`

Initialize the state module.

```zig
pub fn init() void
```

**Example:**
```zig
const state = @import("state.zig");

pub fn main() void {
    state.init();
    defer state.deinit();

    // Use state...
}
```

#### `deinit()`

Deinitialize and clean up state.

```zig
pub fn deinit() void
```

#### `isInitialized()`

Check if state is initialized.

```zig
pub fn isInitialized() bool
```

### State Access

#### `getState()`

Get current state (read-only).

```zig
pub fn getState() *const State
```

**Example:**
```zig
const current = state.getState();
std.debug.print("Counter: {d}\n", .{current.app.counter});
```

#### `getVersion()`

Get current state version.

```zig
pub fn getVersion() u64
```

#### `getStore()`

Get the global store (Phase 2).

```zig
pub fn getStore() *Store(AppState)
```

#### `getAppState()`

Get app state directly from store.

```zig
pub fn getAppState() *const AppState
```

### Diff Tracking

#### `getDiff()`

Get last calculated diff.

```zig
pub fn getDiff() *const Diff(AppState)
```

#### `calculateDiff()`

Calculate and return diff since last commit.

```zig
pub fn calculateDiff() *const Diff(AppState)
```

**Example:**
```zig
// After state changes
const diff = state.calculateDiff();
if (diff.has_changes) {
    // Update UI with changes
}
```

### State Reducers

#### `handleIncrement()`

Increment the counter.

```zig
pub fn handleIncrement() void
```

#### `handleDecrement()`

Decrement the counter.

```zig
pub fn handleDecrement() void
```

#### `handleReset()`

Reset the counter to zero.

```zig
pub fn handleReset() void
```

#### `handleTextInput(text: []const u8)`

Handle text input event.

```zig
pub fn handleTextInput(text: []const u8) void
```

#### `handleNavigate(screen: UIState.Screen)`

Handle navigation to a new screen.

```zig
pub fn handleNavigate(screen: UIState.Screen) void
```

### Scratch Arena

#### `getScratchArena()`

Get scratch arena for temporary allocations.

```zig
pub fn getScratchArena() *Arena(4096)
```

#### `resetScratchArena()`

Reset scratch arena (call after each event dispatch cycle).

```zig
pub fn resetScratchArena() void
```

## Usage Patterns

### Basic State Access

```zig
const state = @import("state.zig");

pub fn displayCurrentState() void {
    const current = state.getState();

    std.debug.print("Version: {d}\n", .{current.version});
    std.debug.print("Counter: {d}\n", .{current.app.counter});
    std.debug.print("Screen: {}\n", .{current.ui.screen});
}
```

### State Updates with Diff Tracking

```zig
const state = @import("state.zig");

pub fn updateCounter() void {
    // Perform update
    state.handleIncrement();

    // Get diff for incremental UI updates
    const diff = state.calculateDiff();

    if (diff.has_changes) {
        // Only update changed UI elements
        applyUIChanges(diff);
    }
}
```

### Custom State Updates via Store

```zig
const state = @import("state.zig");

pub fn customUpdate() void {
    const store = state.getStore();

    // Define update function
    const update = struct {
        fn f(app: *state.AppState) void {
            app.counter = 100;
        }
    }.f;

    // Apply update and commit
    store.updateAndCommit(&update);

    // Calculate diff
    _ = state.calculateDiff();
}
```

## Platform Integration

### iOS (Swift)

```swift
// Get state from Zylix Core
let statePtr = zylix_get_state()
let state = statePtr.pointee

// Access counter value
let counter = state.view_data?.assumingMemoryBound(to: AppState.self).pointee.counter
```

### Android (Kotlin)

```kotlin
// Get state from Zylix Core
val statePtr = ZylixCore.getState()
val counter = statePtr.counter
```

### Web (JavaScript)

```javascript
// Get state from WASM module
const state = zylixModule.getState();
const counter = state.counter;
```

## Best Practices

1. **Always initialize before use**: Call `state.init()` at application startup.
2. **Use diff tracking**: Calculate diffs for efficient UI updates.
3. **Clean up scratch arena**: Reset after each event dispatch cycle.
4. **Version checking**: Use state version for cache invalidation.

## Related Modules

- [Events](./events.md) - Event system that triggers state changes
- [Store](./store.md) - Generic store implementation with diff tracking
- [Diff](./diff.md) - Diff calculation for state changes
- [ABI](./abi.md) - C ABI exports for platform integration
