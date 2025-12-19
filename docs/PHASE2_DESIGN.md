# Phase 2: Core Enhancement Design

## Overview

Phase 2 transforms the hardcoded PoC into a flexible, production-ready state management system.

## Current State (Phase 1)

```
┌─────────────────────────────────────────┐
│ state.zig                               │
│  ├─ AppState (hardcoded: counter, text) │
│  ├─ global_state: State                 │
│  └─ handleIncrement/Decrement/Reset()   │
└────────────────┬────────────────────────┘
                 │ direct mutation
┌────────────────▼────────────────────────┐
│ events.zig                              │
│  └─ dispatch() → immediate execution    │
└─────────────────────────────────────────┘
```

**Problems:**
- AppState is hardcoded to counter app
- No change tracking (UI polls entire state)
- No event queueing (blocking dispatch)
- Memory patterns not formalized

---

## Phase 2 Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Zylix Core (Phase 2)                 │
│                                                         │
│  ┌─────────────────┐     ┌─────────────────────────┐   │
│  │ Store(T)        │     │ EventQueue              │   │
│  │  ├─ state: T    │◄────│  ├─ ring_buffer[64]     │   │
│  │  ├─ version: u64│     │  ├─ priority_levels     │   │
│  │  ├─ diff: Diff  │     │  └─ dispatch()          │   │
│  │  └─ reducers    │     └─────────────────────────┘   │
│  └────────┬────────┘                                    │
│           │                                             │
│  ┌────────▼────────┐     ┌─────────────────────────┐   │
│  │ Diff Engine     │     │ Memory Arena            │   │
│  │  ├─ changed[]   │     │  ├─ scratch: 4KB        │   │
│  │  ├─ field_mask  │     │  ├─ alloc/reset         │   │
│  │  └─ serialize() │     │  └─ lifetime tracking   │   │
│  └─────────────────┘     └─────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

---

## 2.1 Generic State Container

### Design

```zig
/// Generic store with change tracking
pub fn Store(comptime T: type) type {
    return struct {
        const Self = @This();

        state: T,
        version: u64,
        prev_state: T,  // For diff calculation

        pub fn init(initial: T) Self { ... }
        pub fn update(self: *Self, updater: fn(*T) void) void { ... }
        pub fn getState(self: *const Self) *const T { ... }
        pub fn hasChanged(self: *const Self) bool { ... }
    };
}
```

### Benefits
- Any app can define its own state type
- Compile-time type safety
- No runtime allocations for state struct

### C ABI Compatibility
- `view_data` pointer remains generic `*const anyopaque`
- Platform shells cast to known type via bridging header
- Size reported via `view_data_size`

---

## 2.2 Diff Calculation Engine

### Design

```zig
pub const FieldChange = struct {
    field_id: u16,      // Comptime field index
    offset: usize,      // Byte offset in struct
    size: usize,        // Field size
};

pub fn Diff(comptime T: type) type {
    return struct {
        changed_mask: u64,  // Bitmask of changed fields (up to 64)
        changes: [MAX_FIELDS]FieldChange,
        change_count: u8,

        pub fn calculate(old: *const T, new: *const T) @This() { ... }
        pub fn hasFieldChanged(self: *const @This(), field_id: u16) bool { ... }
    };
}
```

### C ABI Extension

```c
typedef struct {
    uint64_t changed_mask;   // Bitmask of changed fields
    uint8_t  change_count;   // Number of changed fields
} zylix_diff_t;

const zylix_diff_t* zylix_get_diff(void);
bool zylix_field_changed(uint16_t field_id);
```

### Benefits
- UI only updates changed components
- Efficient binary diff (no string comparison)
- Supports up to 64 top-level fields

---

## 2.3 Event Queue System

### Design

```zig
pub const Event = struct {
    type: u32,
    payload: [MAX_PAYLOAD]u8,
    payload_len: u16,
    priority: Priority,
    timestamp: u64,

    pub const Priority = enum(u2) {
        low = 0,
        normal = 1,
        high = 2,
        immediate = 3,  // Bypass queue
    };
};

pub const EventQueue = struct {
    buffer: [QUEUE_SIZE]Event,
    head: u16,
    tail: u16,

    pub fn push(self: *EventQueue, event: Event) !void { ... }
    pub fn pop(self: *EventQueue) ?Event { ... }
    pub fn process(self: *EventQueue, max_events: u16) u16 { ... }
    pub fn processUntilEmpty(self: *EventQueue) void { ... }
};
```

### Constants
- `QUEUE_SIZE = 64` (ring buffer)
- `MAX_PAYLOAD = 64` bytes inline

### C ABI Extension

```c
// Queue event (returns immediately)
int32_t zylix_queue_event(uint32_t event_type, const void* payload, size_t len, uint8_t priority);

// Process queued events (call from main loop)
uint32_t zylix_process_events(uint32_t max_events);

// Get queue depth
uint32_t zylix_queue_depth(void);
```

### Backward Compatibility
- `zylix_dispatch()` remains synchronous (immediate priority)
- New `zylix_queue_event()` for async
- Platform shells can choose mode

---

## 2.4 Memory Management Patterns

### Arena Allocator

```zig
pub const Arena = struct {
    buffer: [ARENA_SIZE]u8,
    offset: usize,

    pub fn alloc(self: *Arena, comptime T: type, count: usize) ?[]T { ... }
    pub fn reset(self: *Arena) void { ... }
    pub fn checkpoint(self: *Arena) usize { ... }
    pub fn restore(self: *Arena, checkpoint: usize) void { ... }
};
```

### Constants
- `ARENA_SIZE = 4096` bytes (configurable)
- Used for temporary allocations within single dispatch

### Ownership Rules (Formalized)

| Allocation Site | Owner | Lifetime | Free Responsibility |
|-----------------|-------|----------|---------------------|
| State struct | Zig Core | App lifetime | `zylix_deinit()` |
| Event payload (queued) | EventQueue | Until processed | Automatic |
| Arena alloc | Arena | Until `reset()` | Caller must reset |
| String copy (`zylix_copy_string`) | Shell | Shell decides | Shell |

### No-Allocation Paths
- Counter operations: zero allocations
- Simple events: inline payload only
- State access: pointer return, no copy

---

## Implementation Order

1. **Store(T)** - Generic container with version tracking
2. **Diff(T)** - Change calculation (depends on Store)
3. **EventQueue** - Ring buffer with priorities
4. **Arena** - Scratch allocator for complex operations
5. **Integration** - Wire together, update ABI
6. **Tests** - Comprehensive test suite
7. **Platform Updates** - Update iOS/Android/macOS shells

---

## Binary Size Impact

| Component | Estimated Size |
|-----------|----------------|
| Store(T) | +200 bytes (comptime, no runtime overhead) |
| Diff(T) | +400 bytes |
| EventQueue | +2KB (64 events × 32 bytes) |
| Arena | +4KB buffer + 100 bytes code |
| **Total** | ~7KB additional |

Target: Core library < 15KB (currently ~5KB)

---

## Testing Strategy

```zig
// Store tests
test "store update and version" { ... }
test "store comptime field access" { ... }

// Diff tests
test "diff detects single field change" { ... }
test "diff handles no changes" { ... }
test "diff bitmask correctness" { ... }

// EventQueue tests
test "queue push/pop FIFO" { ... }
test "queue priority ordering" { ... }
test "queue overflow handling" { ... }

// Arena tests
test "arena alloc and reset" { ... }
test "arena checkpoint/restore" { ... }
```

---

## Migration Path

### Phase 1 → Phase 2

```zig
// Before (Phase 1)
pub const AppState = struct {
    counter: i64 = 0,
};
var global_state: State = .{};

// After (Phase 2)
pub const AppState = struct {
    counter: i64 = 0,
};
var store = Store(AppState).init(.{});
```

### C ABI Compatibility
- All Phase 1 functions remain unchanged
- New functions are additive
- `ZYLIX_ABI_VERSION` bumped to 2

---

## Success Criteria

- [ ] Generic Store works with any struct type
- [ ] Diff correctly identifies changed fields
- [ ] EventQueue handles 64 events without allocation
- [ ] Arena provides scratch memory efficiently
- [ ] Binary size < 15KB
- [ ] All Phase 1 tests still pass
- [ ] New comprehensive test suite passes
- [ ] iOS/Android/macOS shells updated and working
