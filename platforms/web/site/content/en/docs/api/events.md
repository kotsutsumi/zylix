---
title: "Events"
weight: 3
---

# Event System

The events module (`events.zig`) defines event types and handles event dispatching from platform shells to Zylix Core.

## Overview

Events flow unidirectionally from platform shells to Zylix Core:

```
┌─────────────┐        ┌─────────────┐        ┌─────────────┐
│  Platform   │ ─────▶ │   Events    │ ─────▶ │    State    │
│   Shell     │  C ABI │   Module    │        │   Update    │
└─────────────┘        └─────────────┘        └─────────────┘
```

## Event Types

Events are identified by 32-bit type codes organized into categories:

### Event Type Ranges

| Range | Category | Description |
|-------|----------|-------------|
| `0x0000 - 0x00FF` | Lifecycle | Application lifecycle events |
| `0x0100 - 0x01FF` | User Interaction | Button presses, text input, gestures |
| `0x0200 - 0x02FF` | Navigation | Screen navigation events |
| `0x1000+` | Application | Application-specific events |

### EventType Enum

```zig
pub const EventType = enum(u32) {
    // Lifecycle events (0x0000 - 0x00FF)
    app_init = 0x0001,
    app_terminate = 0x0002,
    app_foreground = 0x0003,
    app_background = 0x0004,
    app_low_memory = 0x0005,

    // User interaction (0x0100 - 0x01FF)
    button_press = 0x0100,
    text_input = 0x0101,
    text_commit = 0x0102,
    selection = 0x0103,
    scroll = 0x0104,
    gesture = 0x0105,

    // Navigation (0x0200 - 0x02FF)
    navigate = 0x0200,
    navigate_back = 0x0201,
    tab_switch = 0x0202,

    // Counter PoC events (0x1000+)
    counter_increment = 0x1000,
    counter_decrement = 0x1001,
    counter_reset = 0x1002,

    // Unknown/custom events
    _,

    pub fn fromInt(value: u32) EventType;
};
```

## Event Payloads

### ButtonEvent

Payload for `button_press` events.

```zig
pub const ButtonEvent = extern struct {
    button_id: u32,
};
```

**C equivalent:**

```c
typedef struct {
    uint32_t button_id;
} ZylixButtonEvent;
```

**Usage:**

```c
ZylixButtonEvent btn = { .button_id = 0 };  // Increment button
zylix_dispatch(0x0100, &btn, sizeof(btn));
```

### TextEvent

Payload for `text_input` and `text_commit` events.

```zig
pub const TextEvent = extern struct {
    text_ptr: ?[*]const u8,
    text_len: usize,
    field_id: u32,
};
```

**C equivalent:**

```c
typedef struct {
    const char* text_ptr;
    size_t text_len;
    uint32_t field_id;
} ZylixTextEvent;
```

**Usage:**

```c
const char* text = "Hello";
ZylixTextEvent txt = {
    .text_ptr = text,
    .text_len = strlen(text),
    .field_id = 0
};
zylix_dispatch(0x0101, &txt, sizeof(txt));
```

### NavigateEvent

Payload for `navigate` events.

```zig
pub const NavigateEvent = extern struct {
    screen_id: u32,
    params_ptr: ?*const anyopaque,
    params_len: usize,
};
```

**C equivalent:**

```c
typedef struct {
    uint32_t screen_id;
    const void* params_ptr;
    size_t params_len;
} ZylixNavigateEvent;
```

**Screen IDs:**

| ID | Screen |
|----|--------|
| 0 | home |
| 1 | detail |
| 2 | settings |

## Dispatch Function

### dispatch

```zig
pub fn dispatch(
    event_type: u32,
    payload: ?*const anyopaque,
    payload_len: usize
) DispatchResult
```

Dispatch an event to the appropriate handler.

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `event_type` | `u32` | Event type identifier |
| `payload` | `?*const anyopaque` | Event payload (optional) |
| `payload_len` | `usize` | Payload size in bytes |

**Returns:** `DispatchResult` indicating success or failure.

### DispatchResult

```zig
pub const DispatchResult = enum {
    ok,
    not_initialized,
    unknown_event,
    invalid_payload,
};
```

| Value | Description |
|-------|-------------|
| `ok` | Event dispatched successfully |
| `not_initialized` | State not initialized (call `zylix_init()` first) |
| `unknown_event` | Unknown event type |
| `invalid_payload` | Payload missing or too small |

## Event Handling

### Lifecycle Events

| Event | Handler |
|-------|---------|
| `app_init` | No-op (already initialized) |
| `app_terminate` | Calls `state.deinit()` |
| `app_foreground` | Reserved for future use |
| `app_background` | Reserved for future use |
| `app_low_memory` | Reserved for future use |

### User Interaction Events

| Event | Handler |
|-------|---------|
| `button_press` | Routes to button handler by ID |
| `text_input` | Calls `state.handleTextInput()` |
| `text_commit` | Calls `state.handleTextInput()` |

**Button ID Mapping:**

| ID | Action |
|----|--------|
| 0 | Increment counter |
| 1 | Decrement counter |
| 2 | Reset counter |

### Navigation Events

| Event | Handler |
|-------|---------|
| `navigate` | Calls `state.handleNavigate()` with screen |
| `navigate_back` | Navigates to home screen |

### Counter Events

| Event | Handler |
|-------|---------|
| `counter_increment` | Calls `state.handleIncrement()` |
| `counter_decrement` | Calls `state.handleDecrement()` |
| `counter_reset` | Calls `state.handleReset()` |

## Platform Examples

### Swift (iOS)

```swift
import ZylixCore

// Simple counter increment
zylix_dispatch(0x1000, nil, 0)

// Button press with payload
var btn = ZylixButtonEvent(button_id: 0)
withUnsafePointer(to: &btn) { ptr in
    zylix_dispatch(0x0100, ptr, MemoryLayout<ZylixButtonEvent>.size)
}

// Text input
let text = "Hello, World!"
text.withCString { cString in
    var txt = ZylixTextEvent(
        text_ptr: cString,
        text_len: text.utf8.count,
        field_id: 0
    )
    withUnsafePointer(to: &txt) { ptr in
        zylix_dispatch(0x0101, ptr, MemoryLayout<ZylixTextEvent>.size)
    }
}

// Navigation
var nav = ZylixNavigateEvent(
    screen_id: 1,  // detail screen
    params_ptr: nil,
    params_len: 0
)
withUnsafePointer(to: &nav) { ptr in
    zylix_dispatch(0x0200, ptr, MemoryLayout<ZylixNavigateEvent>.size)
}
```

### Kotlin (Android)

```kotlin
// Simple counter increment
ZylixCore.dispatch(0x1000, null, 0)

// Text input (using JNI helper)
ZylixCore.dispatchTextInput("Hello, World!", 0)

// Navigation
ZylixCore.navigate(1)  // detail screen
```

### JavaScript (WASM)

```javascript
// Simple counter increment
wasm.exports.zylix_dispatch(0x1000, 0, 0);

// For complex payloads, allocate memory and write data
const textBytes = new TextEncoder().encode("Hello");
const ptr = wasm.exports.zylix_alloc(textBytes.length);
new Uint8Array(wasm.exports.memory.buffer, ptr, textBytes.length).set(textBytes);

// Create TextEvent in WASM memory
const eventPtr = wasm.exports.zylix_alloc(24); // sizeof(TextEvent)
const view = new DataView(wasm.exports.memory.buffer);
view.setUint32(eventPtr, ptr, true);      // text_ptr
view.setBigUint64(eventPtr + 8, BigInt(textBytes.length), true);  // text_len
view.setUint32(eventPtr + 16, 0, true);   // field_id

wasm.exports.zylix_dispatch(0x0101, eventPtr, 24);

// Free memory
wasm.exports.zylix_free(ptr);
wasm.exports.zylix_free(eventPtr);
```

## Adding Custom Events

To add custom events:

1. **Define event type** in the `EventType` enum:

```zig
// In events.zig
pub const EventType = enum(u32) {
    // ... existing events ...

    // Custom events (0x2000+)
    my_custom_event = 0x2000,
    _,
};
```

2. **Define payload structure** (if needed):

```zig
pub const MyCustomEvent = extern struct {
    data_field: u32,
    other_field: i64,
};
```

3. **Add handler** in the dispatch switch:

```zig
.my_custom_event => {
    if (payload) |p| {
        if (payload_len >= @sizeOf(MyCustomEvent)) {
            const evt: *const MyCustomEvent = @ptrCast(@alignCast(p));
            handleMyCustomEvent(evt);
        } else {
            return .invalid_payload;
        }
    }
},
```

4. **Implement handler function**:

```zig
fn handleMyCustomEvent(evt: *const MyCustomEvent) void {
    // Update state based on event
    const app = state.getStore().getStateMut();
    app.my_field = evt.data_field;
    state.getStore().dirty = true;
    _ = state.calculateDiff();
    state.getStore().commit();
}
```
