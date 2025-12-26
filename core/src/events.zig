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

test "event dispatch - counter decrement" {
    state.init();
    defer state.deinit();

    // First increment to have a positive value
    _ = dispatch(@intFromEnum(EventType.counter_increment), null, 0);
    try std.testing.expectEqual(@as(i64, 1), state.getState().app.counter);

    // Then decrement
    const result = dispatch(@intFromEnum(EventType.counter_decrement), null, 0);
    try std.testing.expectEqual(DispatchResult.ok, result);
    try std.testing.expectEqual(@as(i64, 0), state.getState().app.counter);
}

test "event dispatch - counter reset" {
    state.init();
    defer state.deinit();

    // Increment a few times
    _ = dispatch(@intFromEnum(EventType.counter_increment), null, 0);
    _ = dispatch(@intFromEnum(EventType.counter_increment), null, 0);
    try std.testing.expectEqual(@as(i64, 2), state.getState().app.counter);

    // Reset
    const result = dispatch(@intFromEnum(EventType.counter_reset), null, 0);
    try std.testing.expectEqual(DispatchResult.ok, result);
    try std.testing.expectEqual(@as(i64, 0), state.getState().app.counter);
}

test "event dispatch - button press decrement" {
    state.init();
    defer state.deinit();

    const btn = ButtonEvent{ .button_id = 1 }; // Decrement
    const result = dispatch(@intFromEnum(EventType.button_press), @ptrCast(&btn), @sizeOf(ButtonEvent));
    try std.testing.expectEqual(DispatchResult.ok, result);
    try std.testing.expectEqual(@as(i64, -1), state.getState().app.counter);
}

test "event dispatch - button press reset" {
    state.init();
    defer state.deinit();

    // First increment
    _ = dispatch(@intFromEnum(EventType.counter_increment), null, 0);

    // Reset via button
    const btn = ButtonEvent{ .button_id = 2 }; // Reset
    const result = dispatch(@intFromEnum(EventType.button_press), @ptrCast(&btn), @sizeOf(ButtonEvent));
    try std.testing.expectEqual(DispatchResult.ok, result);
    try std.testing.expectEqual(@as(i64, 0), state.getState().app.counter);
}

test "event dispatch - button press unknown button" {
    state.init();
    defer state.deinit();

    const btn = ButtonEvent{ .button_id = 999 }; // Unknown button
    const result = dispatch(@intFromEnum(EventType.button_press), @ptrCast(&btn), @sizeOf(ButtonEvent));
    try std.testing.expectEqual(DispatchResult.ok, result);
    // Counter should remain unchanged
    try std.testing.expectEqual(@as(i64, 0), state.getState().app.counter);
}

test "event dispatch - button press invalid payload" {
    state.init();
    defer state.deinit();

    const small_data: u8 = 0;
    const result = dispatch(@intFromEnum(EventType.button_press), @ptrCast(&small_data), 1);
    try std.testing.expectEqual(DispatchResult.invalid_payload, result);
}

test "event dispatch - text input" {
    state.init();
    defer state.deinit();

    const text = "Hello";
    const txt = TextEvent{
        .text_ptr = text.ptr,
        .text_len = text.len,
        .field_id = 0,
    };
    const result = dispatch(@intFromEnum(EventType.text_input), @ptrCast(&txt), @sizeOf(TextEvent));
    try std.testing.expectEqual(DispatchResult.ok, result);
    try std.testing.expectEqual(@as(usize, 5), state.getState().app.input_len);
}

test "event dispatch - text commit" {
    state.init();
    defer state.deinit();

    const text = "World";
    const txt = TextEvent{
        .text_ptr = text.ptr,
        .text_len = text.len,
        .field_id = 0,
    };
    const result = dispatch(@intFromEnum(EventType.text_commit), @ptrCast(&txt), @sizeOf(TextEvent));
    try std.testing.expectEqual(DispatchResult.ok, result);
    try std.testing.expectEqual(@as(usize, 5), state.getState().app.input_len);
}

test "event dispatch - text input invalid payload" {
    state.init();
    defer state.deinit();

    const small_data: u8 = 0;
    const result = dispatch(@intFromEnum(EventType.text_input), @ptrCast(&small_data), 1);
    try std.testing.expectEqual(DispatchResult.invalid_payload, result);
}

test "event dispatch - navigate" {
    state.init();
    defer state.deinit();

    const nav = NavigateEvent{
        .screen_id = 1, // detail
        .params_ptr = null,
        .params_len = 0,
    };
    const result = dispatch(@intFromEnum(EventType.navigate), @ptrCast(&nav), @sizeOf(NavigateEvent));
    try std.testing.expectEqual(DispatchResult.ok, result);
    try std.testing.expectEqual(state.UIState.Screen.detail, state.getState().ui.screen);
}

test "event dispatch - navigate to settings" {
    state.init();
    defer state.deinit();

    const nav = NavigateEvent{
        .screen_id = 2, // settings
        .params_ptr = null,
        .params_len = 0,
    };
    const result = dispatch(@intFromEnum(EventType.navigate), @ptrCast(&nav), @sizeOf(NavigateEvent));
    try std.testing.expectEqual(DispatchResult.ok, result);
    try std.testing.expectEqual(state.UIState.Screen.settings, state.getState().ui.screen);
}

test "event dispatch - navigate invalid screen falls back to home" {
    state.init();
    defer state.deinit();

    // First navigate to detail
    const nav1 = NavigateEvent{
        .screen_id = 1,
        .params_ptr = null,
        .params_len = 0,
    };
    _ = dispatch(@intFromEnum(EventType.navigate), @ptrCast(&nav1), @sizeOf(NavigateEvent));
    try std.testing.expectEqual(state.UIState.Screen.detail, state.getState().ui.screen);

    // Navigate with invalid screen ID - should fall back to home
    const nav2 = NavigateEvent{
        .screen_id = 999,
        .params_ptr = null,
        .params_len = 0,
    };
    const result = dispatch(@intFromEnum(EventType.navigate), @ptrCast(&nav2), @sizeOf(NavigateEvent));
    try std.testing.expectEqual(DispatchResult.ok, result);
    try std.testing.expectEqual(state.UIState.Screen.home, state.getState().ui.screen);
}

test "event dispatch - navigate invalid payload" {
    state.init();
    defer state.deinit();

    const small_data: u8 = 0;
    const result = dispatch(@intFromEnum(EventType.navigate), @ptrCast(&small_data), 1);
    try std.testing.expectEqual(DispatchResult.invalid_payload, result);
}

test "event dispatch - navigate back" {
    state.init();
    defer state.deinit();

    // First navigate to detail
    const nav = NavigateEvent{
        .screen_id = 1,
        .params_ptr = null,
        .params_len = 0,
    };
    _ = dispatch(@intFromEnum(EventType.navigate), @ptrCast(&nav), @sizeOf(NavigateEvent));
    try std.testing.expectEqual(state.UIState.Screen.detail, state.getState().ui.screen);

    // Navigate back
    const result = dispatch(@intFromEnum(EventType.navigate_back), null, 0);
    try std.testing.expectEqual(DispatchResult.ok, result);
    try std.testing.expectEqual(state.UIState.Screen.home, state.getState().ui.screen);
}

test "event dispatch - unknown event" {
    state.init();
    defer state.deinit();

    const result = dispatch(0xFFFF, null, 0);
    try std.testing.expectEqual(DispatchResult.unknown_event, result);
}

test "event dispatch - app lifecycle events" {
    state.init();
    defer state.deinit();

    // These should all succeed without changing state
    var result = dispatch(@intFromEnum(EventType.app_init), null, 0);
    try std.testing.expectEqual(DispatchResult.ok, result);

    result = dispatch(@intFromEnum(EventType.app_foreground), null, 0);
    try std.testing.expectEqual(DispatchResult.ok, result);

    result = dispatch(@intFromEnum(EventType.app_background), null, 0);
    try std.testing.expectEqual(DispatchResult.ok, result);

    result = dispatch(@intFromEnum(EventType.app_low_memory), null, 0);
    try std.testing.expectEqual(DispatchResult.ok, result);
}

test "event dispatch - app terminate deinitializes state" {
    state.init();
    try std.testing.expect(state.isInitialized());

    const result = dispatch(@intFromEnum(EventType.app_terminate), null, 0);
    try std.testing.expectEqual(DispatchResult.ok, result);
    try std.testing.expect(!state.isInitialized());
}

test "EventType.fromInt" {
    try std.testing.expectEqual(EventType.counter_increment, EventType.fromInt(0x1000));
    try std.testing.expectEqual(EventType.counter_decrement, EventType.fromInt(0x1001));
    try std.testing.expectEqual(EventType.counter_reset, EventType.fromInt(0x1002));
    try std.testing.expectEqual(EventType.button_press, EventType.fromInt(0x0100));
    try std.testing.expectEqual(EventType.navigate, EventType.fromInt(0x0200));
}
