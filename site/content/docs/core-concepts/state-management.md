---
title: State Management
weight: 2
---

Zylix uses centralized, version-tracked state management. All application state lives in Zig and is exposed read-only to platform shells. State changes are atomic, versioned, and trigger automatic re-renders.

## Terms

- **State**: The full application data owned by Zig.
- **Version**: Monotonic counter incremented on each committed change.
- **Diff**: A change mask used to update UI efficiently.
- **Store**: Generic container that manages current/previous snapshots.

## Concept

## Core Principles

1. **Single Source of Truth**: One global state store owns all application data
2. **Immutable Updates**: State transitions create new state versions
3. **Version Tracking**: Every change increments a version number
4. **Diff Detection**: Changes are tracked for efficient rendering

## Implementation

### Application State

```zig
pub const AppState = struct {
    /// Example: Counter value
    counter: i64 = 0,

    /// Example: Form input
    input_text: [256]u8 = [_]u8{0} ** 256,
    input_len: usize = 0,

    /// Get view data pointer for ABI
    pub fn getViewData(self: *const AppState) ?*const anyopaque {
        return @ptrCast(self);
    }

    /// Get view data size for ABI
    pub fn getViewDataSize(self: *const AppState) usize {
        return @sizeOf(AppState);
    }
};
```

### UI State

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

### Combined State

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

    /// Increment version after state change
    pub fn bumpVersion(self: *State) void {
        self.version +%= 1;
    }
};
```

### Generic State Store

The `Store` provides type-safe state management with automatic versioning:

```zig
pub fn Store(comptime T: type) type {
    return struct {
        const Self = @This();

        current: T,
        previous: T,
        version: u64 = 0,
        dirty: bool = false,

        pub fn init(initial: T) Self {
            return .{
                .current = initial,
                .previous = initial,
            };
        }

        /// Get current state (read-only)
        pub fn getState(self: *const Self) *const T {
            return &self.current;
        }

        /// Get mutable state (internal use)
        pub fn getStateMut(self: *Self) *T {
            return &self.current;
        }

        /// Get previous state (for diffing)
        pub fn getPrevState(self: *const Self) *const T {
            return &self.previous;
        }

        /// Commit pending changes
        pub fn commit(self: *Self) void {
            if (self.dirty) {
                self.previous = self.current;
                self.version += 1;
                self.dirty = false;
            }
        }

        /// Update state with a function and commit
        pub fn updateAndCommit(self: *Self, update_fn: *const fn (*T) void) void {
            update_fn(&self.current);
            self.dirty = true;
            self.commit();
        }
    };
}
```

### State Access

### Reading State

```zig
const state = @import("state.zig");

// Get current state (read-only)
const current = state.getState();
std.debug.print("Counter: {d}\n", .{current.app.counter});

// Get state version
const version = state.getVersion();
std.debug.print("Version: {d}\n", .{version});

// Check initialization
if (state.isInitialized()) {
    // State is ready
}
```

### State Reducers

State changes are handled through reducer functions:

```zig
/// Handle increment event
pub fn handleIncrement() void {
    const increment = struct {
        fn f(app: *AppState) void {
            app.counter += 1;
        }
    }.f;
    global_store.updateAndCommit(&increment);
    _ = calculateDiff();
}

/// Handle decrement event
pub fn handleDecrement() void {
    const decrement = struct {
        fn f(app: *AppState) void {
            app.counter -= 1;
        }
    }.f;
    global_store.updateAndCommit(&decrement);
    _ = calculateDiff();
}

/// Handle reset event
pub fn handleReset() void {
    const reset_counter = struct {
        fn f(app: *AppState) void {
            app.counter = 0;
        }
    }.f;
    global_store.updateAndCommit(&reset_counter);
    _ = calculateDiff();
}
```

### Text Input Handling

For complex state updates like text input:

```zig
/// Handle text input event
pub fn handleTextInput(text: []const u8) void {
    const app = global_store.getStateMut();

    // Copy text to state buffer
    const copy_len = @min(text.len, app.input_text.len - 1);
    @memcpy(app.input_text[0..copy_len], text[0..copy_len]);
    app.input_text[copy_len] = 0;  // Null terminate
    app.input_len = copy_len;

    // Mark dirty and commit
    global_store.dirty = true;
    global_store.commit();
    _ = calculateDiff();
}
```

## Diff Tracking

Zylix tracks what changed between state versions:

```zig
pub fn Diff(comptime T: type) type {
    return struct {
        const Self = @This();

        changed: bool = false,
        version: u64 = 0,
        fields_changed: u32 = 0,

        pub fn init() Self {
            return .{};
        }

        pub fn calculate(old: *const T, new: *const T, version: u64) Self {
            var result = Self{
                .version = version,
            };

            // Compare fields to detect changes
            if (!std.mem.eql(u8, std.mem.asBytes(old), std.mem.asBytes(new))) {
                result.changed = true;
                result.fields_changed = countChangedFields(old, new);
            }

            return result;
        }
    };
}
```

### Using Diffs

```zig
// Calculate diff after state change
const diff = state.calculateDiff();

if (diff.changed) {
    std.debug.print("State changed! Fields: {d}\n", .{diff.fields_changed});

    // Trigger re-render
    reconciler.scheduleRender();
}
```

## ABI-Compatible State

For cross-language interop, state is exposed via C ABI:

```zig
/// ABI-compatible state structure for C interop
pub const ABIState = extern struct {
    version: u64,
    screen: u32,
    loading: bool,
    error_message: ?[*:0]const u8,
    view_data: ?*const anyopaque,
    view_data_size: usize,
};

// Convert to ABI format
pub fn toABI(self: *const State) ABIState {
    return .{
        .version = self.version,
        .screen = @intFromEnum(self.ui.screen),
        .loading = self.ui.loading,
        .error_message = if (self.last_error) |err|
            @ptrCast(err.ptr)
        else
            null,
        .view_data = self.app.getViewData(),
        .view_data_size = self.app.getViewDataSize(),
    };
}
```

### Platform Access

```swift
// Swift
let state = zylix_get_state()
print("Counter: \(state.pointee.counter)")
```

```kotlin
// Kotlin
val state = ZylixBridge.getState()
println("Counter: ${state.counter}")
```

```javascript
// JavaScript (WASM)
const state = zylix.getState();
console.log(`Counter: ${state.counter}`);
```

## Memory Arena

Zylix uses arena allocation for temporary state operations:

```zig
/// Scratch arena for temporary allocations
var scratch_arena: Arena(4096) = Arena(4096).init();

/// Get scratch arena for temporary allocations
pub fn getScratchArena() *Arena(4096) {
    return &scratch_arena;
}

/// Reset scratch arena (call after each event dispatch cycle)
pub fn resetScratchArena() void {
    scratch_arena.reset();
}
```

### Using the Scratch Arena

```zig
// Get arena for temporary work
const arena = state.getScratchArena();

// Allocate temporary buffer
const buf = arena.alloc(u8, 256) orelse return;

// Use buffer...
formatMessage(buf, "Hello");

// Reset after processing (in dispatch cycle)
state.resetScratchArena();
```

## Lifecycle

### Initialization

```zig
pub fn init() void {
    global_store = Store(AppState).init(.{});
    global_state = .{};
    last_diff = Diff(AppState).init();
    scratch_arena.reset();
    initialized = true;
}
```

### Deinitialization

```zig
pub fn deinit() void {
    global_store = Store(AppState).init(.{});
    global_state = .{};
    last_diff = Diff(AppState).init();
    scratch_arena.reset();
    initialized = false;
}
```

## Best Practices

### 1. Keep State Flat

```zig
// Good: Flat state
pub const AppState = struct {
    todos: [MAX_TODOS]Todo = undefined,
    todo_count: usize = 0,
    selected_id: ?u32 = null,
    filter: Filter = .all,
};

// Avoid: Deeply nested state
pub const AppState = struct {
    ui: struct {
        list: struct {
            items: struct {
                todos: [MAX_TODOS]Todo,
            },
        },
    },
};
```

### 2. Use Enums for Finite States

```zig
// Good: Explicit states
pub const LoadingState = enum {
    idle,
    loading,
    success,
    error,
};

// Avoid: Boolean flags
pub const State = struct {
    is_loading: bool,
    has_error: bool,
    is_success: bool,  // Inconsistent states possible
};
```

### 3. Version Check Before Render

```zig
var last_rendered_version: u64 = 0;

fn shouldRender() bool {
    const current_version = state.getVersion();
    if (current_version > last_rendered_version) {
        last_rendered_version = current_version;
        return true;
    }
    return false;
}
```

### 4. Batch Related Updates

```zig
// Good: Single commit for related changes
pub fn handleTodoComplete(id: u32) void {
    const app = global_store.getStateMut();

    // Multiple related updates
    if (findTodo(app, id)) |todo| {
        todo.completed = true;
        app.completed_count += 1;
        app.active_count -= 1;
    }

    // Single commit
    global_store.dirty = true;
    global_store.commit();
}
```

## Testing State

```zig
test "state initialization" {
    init();
    try std.testing.expect(isInitialized());
    try std.testing.expectEqual(@as(u64, 0), getVersion());

    deinit();
    try std.testing.expect(!isInitialized());
}

test "counter increment" {
    init();
    defer deinit();

    try std.testing.expectEqual(@as(i64, 0), getState().app.counter);

    handleIncrement();
    try std.testing.expectEqual(@as(i64, 1), getState().app.counter);
    try std.testing.expectEqual(@as(u64, 1), getVersion());

    handleIncrement();
    try std.testing.expectEqual(@as(i64, 2), getState().app.counter);
    try std.testing.expectEqual(@as(u64, 2), getVersion());
}
```

## Pitfalls

- Reading state before `zylix_init()` completes returns null or default values.
- Mutating state without committing leads to stale versions and missing diffs.
- Holding ABI pointers across dispatch calls can invalidate the view.

## Implementation Links

- [core/src/state.zig](https://github.com/kotsutsumi/zylix/blob/main/core/src/state.zig)
- [core/src/store.zig](https://github.com/kotsutsumi/zylix/blob/main/core/src/store.zig)
- [core/src/diff.zig](https://github.com/kotsutsumi/zylix/blob/main/core/src/diff.zig)

## Samples

- [samples/counter-wasm](https://github.com/kotsutsumi/zylix/tree/main/samples/counter-wasm)
- [platforms/ios/Zylix](https://github.com/kotsutsumi/zylix/tree/main/platforms/ios/Zylix)

## Next Steps

- [Components](../components) - Build UI that reflects state
- [Events](../events) - Trigger state changes from user actions
- [Virtual DOM](../virtual-dom) - Render state as UI
