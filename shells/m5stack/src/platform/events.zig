//! Platform Events Bridge for Zylix
//!
//! Bridges M5Stack touch and gesture events to Zylix Core event system.
//! Translates platform-specific events into ABI-compatible format.
//!
//! Event Flow:
//! M5Stack Touch → Platform Events → Zylix Core → App Handler

const std = @import("std");
const touch_input = @import("../touch/input.zig");
const gesture_mod = @import("../touch/gesture.zig");
const touch_events = @import("../touch/events.zig");

/// Zylix Core event types (matches core/src/events.zig)
pub const ZylixEventType = enum(u32) {
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

    // Touch events (0x0300 - 0x03FF) - M5Stack specific
    touch_began = 0x0300,
    touch_moved = 0x0301,
    touch_ended = 0x0302,
    touch_cancelled = 0x0303,

    // Gesture events (0x0400 - 0x04FF) - M5Stack specific
    gesture_tap = 0x0400,
    gesture_double_tap = 0x0401,
    gesture_long_press = 0x0402,
    gesture_swipe_left = 0x0410,
    gesture_swipe_right = 0x0411,
    gesture_swipe_up = 0x0412,
    gesture_swipe_down = 0x0413,
    gesture_pinch = 0x0420,
    gesture_rotate = 0x0421,
    gesture_pan = 0x0422,

    // Navigation (0x0200 - 0x02FF)
    navigate = 0x0200,
    navigate_back = 0x0201,
    tab_switch = 0x0202,

    // Counter PoC events (0x1000+)
    counter_increment = 0x1000,
    counter_decrement = 0x1001,
    counter_reset = 0x1002,

    _,
};

/// ABI-compatible touch event payload
pub const TouchPayload = extern struct {
    x: i32,
    y: i32,
    touch_id: u8,
    pressure: f32,
    timestamp: u64,
};

/// ABI-compatible gesture event payload
pub const GesturePayload = extern struct {
    gesture_type: u32,
    x: i32,
    y: i32,
    delta_x: i32,
    delta_y: i32,
    scale: f32,
    rotation: f32,
    velocity: f32,
    timestamp: u64,
};

/// ABI-compatible button event payload (for virtual buttons)
pub const ButtonPayload = extern struct {
    button_id: u32,
    x: i32,
    y: i32,
};

/// Event dispatch result
pub const DispatchResult = enum {
    ok,
    not_initialized,
    unknown_event,
    invalid_payload,
    queue_full,
};

/// Platform event bridge to Zylix Core
pub const EventBridge = struct {
    /// Event callback type (for Zylix Core integration)
    pub const EventCallback = *const fn (event_type: u32, payload: ?*const anyopaque, payload_len: usize) DispatchResult;

    /// Zylix Core event dispatcher callback
    zylix_dispatcher: ?EventCallback = null,

    /// Event statistics
    events_sent: u64 = 0,
    events_failed: u64 = 0,

    /// Virtual button definitions
    buttons: [MAX_BUTTONS]?VirtualButton = [_]?VirtualButton{null} ** MAX_BUTTONS,
    button_count: usize = 0,

    const MAX_BUTTONS = 16;

    /// Virtual button for hit testing
    pub const VirtualButton = struct {
        id: u32,
        x: i32,
        y: i32,
        width: u16,
        height: u16,
        enabled: bool = true,
    };

    /// Initialize event bridge
    pub fn init() EventBridge {
        return .{};
    }

    /// Set Zylix Core event dispatcher
    pub fn setDispatcher(self: *EventBridge, dispatcher: EventCallback) void {
        self.zylix_dispatcher = dispatcher;
    }

    /// Register a virtual button for hit testing
    pub fn registerButton(self: *EventBridge, button: VirtualButton) ?usize {
        if (self.button_count >= MAX_BUTTONS) return null;

        for (self.buttons, 0..) |maybe_btn, index| {
            if (maybe_btn == null) {
                self.buttons[index] = button;
                self.button_count += 1;
                return index;
            }
        }
        return null;
    }

    /// Unregister a virtual button
    pub fn unregisterButton(self: *EventBridge, index: usize) void {
        if (index >= MAX_BUTTONS) return;
        if (self.buttons[index] != null) {
            self.buttons[index] = null;
            self.button_count -= 1;
        }
    }

    /// Process touch event and dispatch to Zylix Core
    pub fn processTouchEvent(self: *EventBridge, touch: touch_input.Touch) DispatchResult {
        // Map touch phase to event type
        const event_type: ZylixEventType = switch (touch.phase) {
            .began => .touch_began,
            .moved => .touch_moved,
            .ended => .touch_ended,
            .cancelled => .touch_cancelled,
            .stationary => return .ok, // Skip stationary events
        };

        // Create ABI payload
        const payload = TouchPayload{
            .x = touch.x,
            .y = touch.y,
            .touch_id = touch.id,
            .pressure = touch.pressure,
            .timestamp = touch.timestamp,
        };

        // Check for button hit on touch began
        if (touch.phase == .began) {
            if (self.hitTestButtons(touch.x, touch.y)) |button_id| {
                return self.dispatchButtonPress(button_id, touch.x, touch.y);
            }
        }

        return self.dispatchToZylix(@intFromEnum(event_type), &payload, @sizeOf(TouchPayload));
    }

    /// Process gesture event and dispatch to Zylix Core
    pub fn processGestureEvent(self: *EventBridge, gesture: gesture_mod.GestureEvent) DispatchResult {
        // Map gesture type to event type
        const event_type: ZylixEventType = switch (gesture) {
            .tap => |t| if (t.tap_count == 2) .gesture_double_tap else .gesture_tap,
            .long_press => .gesture_long_press,
            .swipe => |s| switch (s.direction) {
                .left => .gesture_swipe_left,
                .right => .gesture_swipe_right,
                .up => .gesture_swipe_up,
                .down => .gesture_swipe_down,
            },
            .pinch => .gesture_pinch,
            .rotate => .gesture_rotate,
            .pan => .gesture_pan,
        };

        // Create ABI payload
        const payload = self.createGesturePayload(gesture);

        return self.dispatchToZylix(@intFromEnum(event_type), &payload, @sizeOf(GesturePayload));
    }

    /// Create gesture payload from gesture event
    fn createGesturePayload(self: *EventBridge, gesture: gesture_mod.GestureEvent) GesturePayload {
        _ = self;
        return switch (gesture) {
            .tap => |t| .{
                .gesture_type = @intFromEnum(ZylixEventType.gesture_tap),
                .x = t.x,
                .y = t.y,
                .delta_x = 0,
                .delta_y = 0,
                .scale = 1.0,
                .rotation = 0,
                .velocity = 0,
                .timestamp = t.timestamp,
            },
            .long_press => |l| .{
                .gesture_type = @intFromEnum(ZylixEventType.gesture_long_press),
                .x = l.x,
                .y = l.y,
                .delta_x = 0,
                .delta_y = 0,
                .scale = 1.0,
                .rotation = 0,
                .velocity = 0,
                .timestamp = l.timestamp,
            },
            .swipe => |s| .{
                .gesture_type = @intFromEnum(switch (s.direction) {
                    .left => ZylixEventType.gesture_swipe_left,
                    .right => ZylixEventType.gesture_swipe_right,
                    .up => ZylixEventType.gesture_swipe_up,
                    .down => ZylixEventType.gesture_swipe_down,
                }),
                .x = s.start_x,
                .y = s.start_y,
                .delta_x = s.end_x - s.start_x,
                .delta_y = s.end_y - s.start_y,
                .scale = 1.0,
                .rotation = 0,
                .velocity = s.velocity,
                .timestamp = s.timestamp,
            },
            .pinch => |p| .{
                .gesture_type = @intFromEnum(ZylixEventType.gesture_pinch),
                .x = p.center_x,
                .y = p.center_y,
                .delta_x = 0,
                .delta_y = 0,
                .scale = p.scale,
                .rotation = 0,
                .velocity = p.velocity,
                .timestamp = p.timestamp,
            },
            .rotate => |r| .{
                .gesture_type = @intFromEnum(ZylixEventType.gesture_rotate),
                .x = r.center_x,
                .y = r.center_y,
                .delta_x = 0,
                .delta_y = 0,
                .scale = 1.0,
                .rotation = r.rotation,
                .velocity = r.velocity,
                .timestamp = r.timestamp,
            },
            .pan => |p| .{
                .gesture_type = @intFromEnum(ZylixEventType.gesture_pan),
                .x = p.x,
                .y = p.y,
                .delta_x = p.delta_x,
                .delta_y = p.delta_y,
                .scale = 1.0,
                .rotation = 0,
                .velocity = 0,
                .timestamp = p.timestamp,
            },
        };
    }

    /// Hit test against registered virtual buttons
    fn hitTestButtons(self: *EventBridge, x: i32, y: i32) ?u32 {
        for (self.buttons) |maybe_btn| {
            if (maybe_btn) |btn| {
                if (btn.enabled and
                    x >= btn.x and x < btn.x + @as(i32, btn.width) and
                    y >= btn.y and y < btn.y + @as(i32, btn.height))
                {
                    return btn.id;
                }
            }
        }
        return null;
    }

    /// Dispatch button press event
    fn dispatchButtonPress(self: *EventBridge, button_id: u32, x: i32, y: i32) DispatchResult {
        const payload = ButtonPayload{
            .button_id = button_id,
            .x = x,
            .y = y,
        };

        return self.dispatchToZylix(@intFromEnum(ZylixEventType.button_press), &payload, @sizeOf(ButtonPayload));
    }

    /// Dispatch event to Zylix Core
    fn dispatchToZylix(
        self: *EventBridge,
        event_type: u32,
        payload: ?*const anyopaque,
        payload_len: usize,
    ) DispatchResult {
        if (self.zylix_dispatcher) |dispatcher| {
            const result = dispatcher(event_type, payload, payload_len);
            if (result == .ok) {
                self.events_sent += 1;
            } else {
                self.events_failed += 1;
            }
            return result;
        }
        return .not_initialized;
    }

    /// Send lifecycle event
    pub fn sendLifecycleEvent(self: *EventBridge, event_type: ZylixEventType) DispatchResult {
        return self.dispatchToZylix(@intFromEnum(event_type), null, 0);
    }

    /// Send app init event
    pub fn sendAppInit(self: *EventBridge) DispatchResult {
        return self.sendLifecycleEvent(.app_init);
    }

    /// Send app terminate event
    pub fn sendAppTerminate(self: *EventBridge) DispatchResult {
        return self.sendLifecycleEvent(.app_terminate);
    }

    /// Send counter increment event (for PoC)
    pub fn sendCounterIncrement(self: *EventBridge) DispatchResult {
        return self.dispatchToZylix(@intFromEnum(ZylixEventType.counter_increment), null, 0);
    }

    /// Send counter decrement event (for PoC)
    pub fn sendCounterDecrement(self: *EventBridge) DispatchResult {
        return self.dispatchToZylix(@intFromEnum(ZylixEventType.counter_decrement), null, 0);
    }

    /// Send counter reset event (for PoC)
    pub fn sendCounterReset(self: *EventBridge) DispatchResult {
        return self.dispatchToZylix(@intFromEnum(ZylixEventType.counter_reset), null, 0);
    }

    /// Get event statistics
    pub fn getStats(self: *const EventBridge) struct { sent: u64, failed: u64 } {
        return .{
            .sent = self.events_sent,
            .failed = self.events_failed,
        };
    }
};

/// Scroll event helper
pub const ScrollEvent = struct {
    x: i32,
    y: i32,
    delta_x: i32,
    delta_y: i32,
    velocity_x: f32,
    velocity_y: f32,

    /// Create from pan gesture
    pub fn fromPan(pan: gesture_mod.PanData) ScrollEvent {
        return .{
            .x = pan.x,
            .y = pan.y,
            .delta_x = pan.delta_x,
            .delta_y = pan.delta_y,
            .velocity_x = 0, // Would calculate from velocity tracker
            .velocity_y = 0,
        };
    }
};

/// Navigation helper for swipe-based navigation
pub const NavigationHelper = struct {
    /// Minimum swipe distance for navigation
    min_swipe_distance: i32 = 50,

    /// Process gesture for navigation
    pub fn processGesture(self: *NavigationHelper, gesture: gesture_mod.GestureEvent) ?ZylixEventType {
        _ = self;
        switch (gesture) {
            .swipe => |s| {
                // Swipe right from left edge = back navigation
                if (s.direction == .right and s.start_x < 30) {
                    return .navigate_back;
                }
            },
            else => {},
        }
        return null;
    }
};

// Tests
test "ZylixEventType values" {
    try std.testing.expectEqual(@as(u32, 0x0001), @intFromEnum(ZylixEventType.app_init));
    try std.testing.expectEqual(@as(u32, 0x0100), @intFromEnum(ZylixEventType.button_press));
    try std.testing.expectEqual(@as(u32, 0x0300), @intFromEnum(ZylixEventType.touch_began));
    try std.testing.expectEqual(@as(u32, 0x0400), @intFromEnum(ZylixEventType.gesture_tap));
}

test "EventBridge initialization" {
    var bridge = EventBridge.init();
    try std.testing.expectEqual(@as(u64, 0), bridge.events_sent);
    try std.testing.expectEqual(@as(u64, 0), bridge.events_failed);
}

test "Virtual button registration" {
    var bridge = EventBridge.init();

    const btn = EventBridge.VirtualButton{
        .id = 1,
        .x = 10,
        .y = 10,
        .width = 100,
        .height = 50,
    };

    const index = bridge.registerButton(btn);
    try std.testing.expect(index != null);
    try std.testing.expectEqual(@as(usize, 1), bridge.button_count);

    bridge.unregisterButton(index.?);
    try std.testing.expectEqual(@as(usize, 0), bridge.button_count);
}

test "TouchPayload size" {
    // Ensure ABI compatibility
    try std.testing.expect(@sizeOf(TouchPayload) > 0);
    try std.testing.expect(@sizeOf(GesturePayload) > 0);
    try std.testing.expect(@sizeOf(ButtonPayload) > 0);
}
