//! Event System Module
//!
//! Defines event types and handles event dispatching.
//! Events flow from platform shells to Zylix Core.

const std = @import("std");
const state = @import("state.zig");

/// Event type identifiers (matches ABI specification)
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

    // Unknown
    _,

    pub fn fromInt(value: u32) EventType {
        return @enumFromInt(value);
    }
};

/// Button event payload
pub const ButtonEvent = extern struct {
    button_id: u32,
};

/// Text event payload
pub const TextEvent = extern struct {
    text_ptr: ?[*]const u8,
    text_len: usize,
    field_id: u32,
};

/// Navigation event payload
pub const NavigateEvent = extern struct {
    screen_id: u32,
    params_ptr: ?*const anyopaque,
    params_len: usize,
};

/// Dispatch result
pub const DispatchResult = enum {
    ok,
    not_initialized,
    unknown_event,
    invalid_payload,
};

/// Dispatch an event
pub fn dispatch(event_type: u32, payload: ?*const anyopaque, payload_len: usize) DispatchResult {
    if (!state.isInitialized()) {
        return .not_initialized;
    }

    const evt = EventType.fromInt(event_type);

    switch (evt) {
        // Lifecycle
        .app_init => {
            // Already initialized
        },
        .app_terminate => {
            state.deinit();
        },
        .app_foreground, .app_background, .app_low_memory => {
            // Handle lifecycle events
        },

        // User interaction
        .button_press => {
            if (payload) |p| {
                if (payload_len >= @sizeOf(ButtonEvent)) {
                    const btn: *const ButtonEvent = @ptrCast(@alignCast(p));
                    handleButtonPress(btn.button_id);
                } else {
                    return .invalid_payload;
                }
            }
        },
        .text_input, .text_commit => {
            if (payload) |p| {
                if (payload_len >= @sizeOf(TextEvent)) {
                    const txt: *const TextEvent = @ptrCast(@alignCast(p));
                    if (txt.text_ptr) |text_ptr| {
                        const text = text_ptr[0..txt.text_len];
                        state.handleTextInput(text);
                    }
                } else {
                    return .invalid_payload;
                }
            }
        },

        // Navigation
        .navigate => {
            if (payload) |p| {
                if (payload_len >= @sizeOf(NavigateEvent)) {
                    const nav: *const NavigateEvent = @ptrCast(@alignCast(p));
                    const screen = std.meta.intToEnum(state.UIState.Screen, nav.screen_id) catch .home;
                    state.handleNavigate(screen);
                } else {
                    return .invalid_payload;
                }
            }
        },
        .navigate_back => {
            state.handleNavigate(.home);
        },

        // Counter PoC events
        .counter_increment => {
            state.handleIncrement();
        },
        .counter_decrement => {
            state.handleDecrement();
        },
        .counter_reset => {
            state.handleReset();
        },

        else => {
            return .unknown_event;
        },
    }

    return .ok;
}

/// Handle button press by ID
fn handleButtonPress(button_id: u32) void {
    switch (button_id) {
        0 => state.handleIncrement(), // Increment button
        1 => state.handleDecrement(), // Decrement button
        2 => state.handleReset(), // Reset button
        else => {},
    }
}

// === Tests ===

test "event dispatch - counter increment" {
    state.init();
    defer state.deinit();

    const result = dispatch(@intFromEnum(EventType.counter_increment), null, 0);
    try std.testing.expectEqual(DispatchResult.ok, result);
    try std.testing.expectEqual(@as(i64, 1), state.getState().app.counter);
}

test "event dispatch - button press" {
    state.init();
    defer state.deinit();

    const btn = ButtonEvent{ .button_id = 0 }; // Increment
    const result = dispatch(@intFromEnum(EventType.button_press), @ptrCast(&btn), @sizeOf(ButtonEvent));
    try std.testing.expectEqual(DispatchResult.ok, result);
    try std.testing.expectEqual(@as(i64, 1), state.getState().app.counter);
}

test "event dispatch - not initialized" {
    const result = dispatch(@intFromEnum(EventType.counter_increment), null, 0);
    try std.testing.expectEqual(DispatchResult.not_initialized, result);
}
