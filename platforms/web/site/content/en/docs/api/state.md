---
title: "State Management"
weight: 2
---

# State Management

The state module (`state.zig`) manages all application state in Zylix Core using a generic Store with diff tracking.

## Overview

State is owned entirely by Zig and exposed read-only to platform shells. The state management system provides:

- Immutable state access for thread safety
- Automatic diff tracking for efficient UI updates
- Type-safe reducers for state mutations
- Scratch arena for temporary allocations

## Architecture

```
┌─────────────────────────────────────────────┐
│                  Store<T>                    │
│  ┌─────────────┐    ┌─────────────┐         │
│  │ Current     │    │ Previous    │         │
│  │ State       │    │ State       │         │
│  └─────────────┘    └─────────────┘         │
│         │                  │                 │
│         └────────┬─────────┘                 │
│                  ▼                           │
│           ┌─────────────┐                    │
│           │    Diff     │                    │
│           └─────────────┘                    │
└─────────────────────────────────────────────┘
```

## Types

### State

Main state container combining application and UI state.

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

    /// Convert to ABI-compatible structure
    pub fn toABI(self: *const State) ABIState;

    /// Increment version after state change
    pub fn bumpVersion(self: *State) void;
};
```

### AppState

Application-specific state (customizable per application).

```zig
pub const AppState = struct {
    /// Counter value (PoC example)
    counter: i64 = 0,

    /// Form text (PoC example)
    input_text: [256]u8 = [_]u8{0} ** 256,
    input_len: usize = 0,

    /// Get view data pointer for ABI
    pub fn getViewData(self: *const AppState) ?*const anyopaque;

    /// Get view data size for ABI
    pub fn getViewDataSize(self: *const AppState) usize;
};
```

### UIState

UI state hints for platform shells.

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

ABI-compatible structure for C interop.

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

### Lifecycle

#### init

```zig
pub fn init() void
```

Initialize the global state. Must be called before any state operations.

#### deinit

```zig
pub fn deinit() void
```

Deinitialize state and release resources.

#### isInitialized

```zig
pub fn isInitialized() bool
```

Check if state is initialized.

### State Access

#### getState

```zig
pub fn getState() *const State
```

Get current state (read-only). Returns a pointer to the synchronized state with the store.

#### getAppState

```zig
pub fn getAppState() *const AppState
```

Get app state directly from the store.

#### getVersion

```zig
pub fn getVersion() u64
```

Get the current state version.

#### getStore

```zig
pub fn getStore() *Store(AppState)
```

Get the global store for advanced operations.

### Diff Tracking

#### getDiff

```zig
pub fn getDiff() *const Diff(AppState)
```

Get the last calculated diff.

#### calculateDiff

```zig
pub fn calculateDiff() *const Diff(AppState)
```

Calculate and return diff since last commit.

**Example:**

```zig
// After state modification
const diff = state.calculateDiff();
if (diff.hasChanges()) {
    if (diff.hasFieldChangedByName("counter")) {
        // Counter changed, update UI
    }
}
```

### Scratch Arena

#### getScratchArena

```zig
pub fn getScratchArena() *Arena(4096)
```

Get scratch arena for temporary allocations. Reset after each event dispatch cycle.

#### resetScratchArena

```zig
pub fn resetScratchArena() void
```

Reset the scratch arena. Called automatically after processing events.

### State Reducers

State mutations are handled through reducer functions:

#### handleIncrement

```zig
pub fn handleIncrement() void
```

Increment the counter and commit the change.

#### handleDecrement

```zig
pub fn handleDecrement() void
```

Decrement the counter and commit the change.

#### handleReset

```zig
pub fn handleReset() void
```

Reset the counter to zero.

#### handleTextInput

```zig
pub fn handleTextInput(text: []const u8) void
```

Handle text input, copying to the input buffer.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `text` | `[]const u8` | Input text (truncated to 255 chars) |

#### handleNavigate

```zig
pub fn handleNavigate(screen: UIState.Screen) void
```

Handle navigation to a different screen.

### Error Handling

#### setError

```zig
pub fn setError(err: ?[]const u8) void
```

Set the last error message. Pass `null` to clear.

## Store Generic Type

The `Store(T)` type provides efficient state management with diff tracking:

```zig
pub fn Store(comptime T: type) type {
    return struct {
        current: T,
        previous: T,
        version: u64,
        dirty: bool,

        /// Initialize with default state
        pub fn init(initial: T) Store(T);

        /// Get current state (read-only)
        pub fn getState(self: *const Self) *const T;

        /// Get mutable state (internal use)
        pub fn getStateMut(self: *Self) *T;

        /// Get previous state for diffing
        pub fn getPrevState(self: *const Self) *const T;

        /// Update state with reducer function
        pub fn update(self: *Self, reducer: *const fn(*T) void) void;

        /// Commit changes (increment version, copy to previous)
        pub fn commit(self: *Self) void;

        /// Get current version
        pub fn getVersion(self: *const Self) u64;
    };
}
```

## Usage Example

### Swift (iOS)

```swift
import ZylixCore

class AppViewModel: ObservableObject {
    @Published var counter: Int64 = 0
    @Published var inputText: String = ""

    private var lastVersion: UInt64 = 0

    func refresh() {
        guard let state = zylix_get_state() else { return }

        // Only update if version changed
        if state.pointee.version > lastVersion {
            lastVersion = state.pointee.version

            // Check what changed using diff
            if zylix_field_changed(0) {  // counter field
                counter = zylix_get_counter()
            }
        }
    }

    func increment() {
        zylix_dispatch(0x1000, nil, 0)
        refresh()
    }
}
```

### Kotlin (Android)

```kotlin
class AppViewModel : ViewModel() {
    private val _counter = MutableStateFlow(0L)
    val counter: StateFlow<Long> = _counter.asStateFlow()

    private var lastVersion = 0L

    fun refresh() {
        val version = ZylixCore.getStateVersion()
        if (version > lastVersion) {
            lastVersion = version

            if (ZylixCore.fieldChanged(0)) {
                _counter.value = ZylixCore.getCounter()
            }
        }
    }

    fun increment() {
        ZylixCore.dispatch(0x1000, null, 0)
        refresh()
    }
}
```
