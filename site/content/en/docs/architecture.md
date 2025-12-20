---
title: Architecture
weight: 2
prev: getting-started
next: platforms
---

Understanding the Zylix architecture.

## Overview

Zylix follows a layered architecture that separates concerns and maximizes code reuse across platforms.

```
┌─────────────────────────────────────────────────────────┐
│                   Platform Layer                         │
│  SwiftUI │ Compose │ GTK4 │ WinUI 3 │ HTML/JS           │
└─────────────────────────────────────────────────────────┘
                            │
                            │ C ABI / WASM
                            ▼
┌─────────────────────────────────────────────────────────┐
│                   Zylix Core (Zig)                       │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐        │
│  │  VDOM   │ │  Diff   │ │ Events  │ │  State  │        │
│  └─────────┘ └─────────┘ └─────────┘ └─────────┘        │
└─────────────────────────────────────────────────────────┘
```

## Core Components

### Virtual DOM (`vdom.zig`)

The Virtual DOM is a lightweight representation of the UI tree.

```zig
pub const VNode = struct {
    tag: Tag,
    key: ?[]const u8,
    props: Props,
    children: []const VNode,
    text: ?[]const u8,
};
```

Key features:
- **Immutable by default**: VNodes are never mutated
- **Arena allocation**: Efficient memory management
- **Keyed reconciliation**: Optimal updates with keys

### Diff Algorithm (`diff.zig`)

The diffing algorithm compares old and new VNode trees to produce minimal patches.

```zig
pub const Patch = union(enum) {
    replace: VNode,
    update_props: Props,
    update_text: []const u8,
    insert_child: struct { index: usize, node: VNode },
    remove_child: usize,
    move_child: struct { from: usize, to: usize },
};
```

Performance characteristics:
- **O(n)** time complexity for tree comparison
- **Minimal patches**: Only necessary changes are generated
- **Keyed optimization**: O(1) lookup for keyed children

### Event System (`events.zig`)

Type-safe event handling with discriminated unions.

```zig
pub const Event = union(enum) {
    counter_increment,
    counter_decrement,
    counter_reset,
    todo_add: []const u8,
    todo_toggle: u32,
    todo_remove: u32,
    todo_clear_completed,
    todo_set_filter: Filter,
};
```

### State Management (`state.zig`)

Centralized state with version tracking.

```zig
pub const State = struct {
    version: u64,
    screen: Screen,
    loading: bool,
    error_message: ?[]const u8,
    view_data: ?*anyopaque,
};
```

## Platform Integration

### C ABI (`abi.zig`)

All core functions are exposed via C ABI for cross-language interoperability.

```zig
export fn zylix_init() c_int;
export fn zylix_deinit() c_int;
export fn zylix_dispatch(event_type: u32, payload: ?*anyopaque, len: usize) c_int;
export fn zylix_get_state() ?*State;
```

### WASM (`wasm.zig`)

WebAssembly-specific bindings with JavaScript interop.

```zig
export fn wasm_alloc(len: usize) ?[*]u8;
export fn wasm_free(ptr: [*]u8, len: usize) void;
export fn wasm_render() void;
```

## Data Flow

```
User Action → Platform Event → Zylix Dispatch → State Update → VDOM Rebuild → Diff → Patches → Platform Apply
```

1. **User Action**: Touch, click, keyboard input
2. **Platform Event**: Native event converted to Zylix event
3. **Dispatch**: Event processed by Zylix core
4. **State Update**: Immutable state transition
5. **VDOM Rebuild**: New virtual tree generated
6. **Diff**: Patches computed from old vs new
7. **Platform Apply**: Native UI updated

## Memory Management

Zylix uses arena allocation for predictable performance:

```zig
pub const Arena = struct {
    buffer: []u8,
    offset: usize,

    pub fn alloc(self: *Arena, comptime T: type, n: usize) ?[]T;
    pub fn reset(self: *Arena) void;
};
```

Benefits:
- **No GC pauses**: Deterministic deallocation
- **Cache-friendly**: Contiguous memory layout
- **Fast allocation**: O(1) bump allocation
