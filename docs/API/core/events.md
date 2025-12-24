# Events API

> **Module**: `core/src/events.zig`
> **Version**: v0.24.0

## Overview

The Events module defines event types and handles event dispatching. Events flow from platform shells to Zylix Core, triggering state changes and side effects.

## Architecture

```
┌────────────────────────────────────────────────────────────┐
│                     Platform Shell                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │  Button  │  │  Input   │  │   Nav    │  │ Lifecycle│   │
│  │  Press   │  │  Text    │  │  Change  │  │  Events  │   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘   │
└───────┼─────────────┼─────────────┼─────────────┼──────────┘
        │             │             │             │
        ▼             ▼             ▼             ▼
┌────────────────────────────────────────────────────────────┐
│                     Event Dispatcher                        │
│                    events.dispatch()                        │
└────────────────────────────────────────────────────────────┘
        │
        ▼
┌────────────────────────────────────────────────────────────┐
│                     State Module                            │
│              (state.handleIncrement(), etc.)                │
└────────────────────────────────────────────────────────────┘
```

## Event Types

### EventType Enum

All supported event types organized by category.

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
};
```

### Event Categories

| Category | Range | Description |
|----------|-------|-------------|
| Lifecycle | 0x0000 - 0x00FF | App lifecycle events |
| User Interaction | 0x0100 - 0x01FF | User input events |
| Navigation | 0x0200 - 0x02FF | Screen navigation events |
| Custom | 0x1000+ | Application-specific events |

## Payload Types

### ButtonEvent

Payload for button press events.

```zig
pub const ButtonEvent = extern struct {
    button_id: u32,
};
```

### TextEvent

Payload for text input events.

```zig
pub const TextEvent = extern struct {
    text_ptr: ?[*]const u8,
    text_len: usize,
    field_id: u32,
};
```

### NavigateEvent

Payload for navigation events.

```zig
pub const NavigateEvent = extern struct {
    screen_id: u32,
    params_ptr: ?*const anyopaque,
    params_len: usize,
};
```

## Dispatch Result

```zig
pub const DispatchResult = enum {
    ok,              // Event handled successfully
    not_initialized, // State not initialized
    unknown_event,   // Unknown event type
    invalid_payload, // Invalid payload data
};
```

## Functions

### `dispatch(event_type, payload, payload_len)`

Main event dispatch function. Routes events to appropriate handlers.

```zig
pub fn dispatch(
    event_type: u32,
    payload: ?*const anyopaque,
    payload_len: usize
) DispatchResult
```

**Parameters:**
- `event_type`: Event type identifier (u32)
- `payload`: Optional pointer to event payload
- `payload_len`: Size of payload in bytes

**Returns:** `DispatchResult` indicating success or failure

**Example:**
```zig
const events = @import("events.zig");

// Dispatch simple event (no payload)
const result = events.dispatch(
    @intFromEnum(events.EventType.counter_increment),
    null,
    0
);

if (result != .ok) {
    std.debug.print("Event dispatch failed: {}\n", .{result});
}
```

### `EventType.fromInt(value)`

Convert u32 to EventType.

```zig
pub fn fromInt(value: u32) EventType
```

## Usage Examples

### Dispatching Button Press

```zig
const events = @import("events.zig");

pub fn handleButtonTap(buttonId: u32) void {
    const payload = events.ButtonEvent{
        .button_id = buttonId,
    };

    _ = events.dispatch(
        @intFromEnum(events.EventType.button_press),
        @ptrCast(&payload),
        @sizeOf(events.ButtonEvent)
    );
}
```

### Dispatching Text Input

```zig
const events = @import("events.zig");

pub fn handleTextChange(text: []const u8, fieldId: u32) void {
    const payload = events.TextEvent{
        .text_ptr = text.ptr,
        .text_len = text.len,
        .field_id = fieldId,
    };

    _ = events.dispatch(
        @intFromEnum(events.EventType.text_input),
        @ptrCast(&payload),
        @sizeOf(events.TextEvent)
    );
}
```

### Dispatching Navigation

```zig
const events = @import("events.zig");

pub fn navigateToScreen(screenId: u32) void {
    const payload = events.NavigateEvent{
        .screen_id = screenId,
        .params_ptr = null,
        .params_len = 0,
    };

    _ = events.dispatch(
        @intFromEnum(events.EventType.navigate),
        @ptrCast(&payload),
        @sizeOf(events.NavigateEvent)
    );
}
```

## Platform Integration

### iOS (Swift)

```swift
// Queue event from Swift to Zylix Core
func buttonTapped(id: UInt32) {
    var event = ButtonEvent(button_id: id)
    withUnsafePointer(to: &event) { ptr in
        zylix_queue_event(
            EventType.button_press.rawValue,
            ptr,
            UInt(MemoryLayout<ButtonEvent>.size)
        )
    }
    zylix_process_events()
}
```

### Android (Kotlin)

```kotlin
// Queue event from Kotlin to Zylix Core
fun buttonTapped(id: Int) {
    val event = ButtonEvent(button_id = id)
    ZylixCore.queueEvent(
        EventType.BUTTON_PRESS,
        event.toByteArray(),
        event.size
    )
    ZylixCore.processEvents()
}
```

### Web (JavaScript)

```javascript
// Queue event from JavaScript to WASM module
function buttonTapped(id) {
    const event = new Uint32Array([id]);
    zylixModule.queueEvent(
        EventType.BUTTON_PRESS,
        event.buffer,
        event.byteLength
    );
    zylixModule.processEvents();
}
```

## Event Flow

1. **Platform triggers event** (button tap, text input, etc.)
2. **Event is queued** via ABI (`zylix_queue_event`)
3. **Events are processed** via ABI (`zylix_process_events`)
4. **Dispatcher routes** event to appropriate handler
5. **State is updated** via state reducers
6. **Diff is calculated** for UI updates
7. **Platform reads new state** via ABI (`zylix_get_state`)

## Adding Custom Events

### Step 1: Define Event Type

```zig
// In events.zig
pub const EventType = enum(u32) {
    // ... existing events ...

    // Custom app events (0x2000+)
    custom_action = 0x2000,
    custom_submit = 0x2001,
};
```

### Step 2: Define Payload (optional)

```zig
pub const CustomActionEvent = extern struct {
    action_id: u32,
    value: i64,
};
```

### Step 3: Handle in Dispatcher

```zig
.custom_action => {
    if (payload) |p| {
        if (payload_len >= @sizeOf(CustomActionEvent)) {
            const action: *const CustomActionEvent = @ptrCast(@alignCast(p));
            handleCustomAction(action.action_id, action.value);
        }
    }
},
```

### Step 4: Implement Handler

```zig
fn handleCustomAction(action_id: u32, value: i64) void {
    // Update state based on action
    const store = state.getStore();
    // ... perform state updates ...
}
```

## Best Practices

1. **Always check dispatch result**: Handle error cases appropriately.
2. **Validate payloads**: Ensure payload size matches expected structure.
3. **Initialize state first**: Events require state to be initialized.
4. **Use typed payloads**: Prefer structured payloads over raw bytes.
5. **Keep handlers fast**: Minimize processing in event handlers.

## Related Modules

- [State](./state.md) - State management that responds to events
- [ABI](./abi.md) - C ABI for platform integration
