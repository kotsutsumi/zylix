//! Application State and Event Handling
//!
//! This module defines the core application state and event handling logic.
//! Customize this file to add your own state fields and event handlers.

const std = @import("std");

// ============================================================================
// Application State
// ============================================================================

/// Main application state structure
/// Add your own fields to track application data
pub const AppState = struct {
    /// Application name
    app_name: []const u8 = "Blank App",

    /// Version string
    version: []const u8 = "1.0.0",

    /// Whether the app has been initialized
    initialized: bool = false,

    /// Current view/screen identifier
    current_view: []const u8 = "main",

    /// Example counter (remove or modify as needed)
    counter: i32 = 0,

    // Add your custom state fields below:
    // user_name: []const u8 = "Guest",
    // is_logged_in: bool = false,
    // theme: Theme = .light,
};

// Global application state instance
var app_state: AppState = .{};

// ============================================================================
// Event System
// ============================================================================

/// Event types that the application can handle
pub const EventType = enum(u32) {
    // Lifecycle events
    app_start = 0,
    app_pause = 1,
    app_resume = 2,
    app_stop = 3,

    // UI events
    button_click = 10,
    text_input = 11,
    list_select = 12,

    // Navigation events
    navigate = 20,
    back = 21,

    // Custom events (add your own starting from 100)
    increment = 100,
    decrement = 101,
    reset = 102,
    _,
};

/// Event structure passed to handlers
pub const Event = struct {
    type: EventType,
    payload: ?*const anyopaque = null,

    /// Helper to cast payload to a specific type
    pub fn getPayload(self: *const Event, comptime T: type) ?*const T {
        if (self.payload) |p| {
            return @ptrCast(@alignCast(p));
        }
        return null;
    }
};

// ============================================================================
// Lifecycle Functions
// ============================================================================

/// Initialize the application state
pub fn init() void {
    app_state = .{
        .initialized = true,
    };
}

/// Deinitialize and cleanup
pub fn deinit() void {
    app_state.initialized = false;
}

/// Get read-only access to current state
pub fn getState() *const AppState {
    return &app_state;
}

/// Get mutable access to state (use carefully)
pub fn getStateMut() *AppState {
    return &app_state;
}

// ============================================================================
// Event Handlers
// ============================================================================

/// Main event dispatcher
/// Returns true if the event was handled
pub fn handleEvent(event: Event) bool {
    switch (event.type) {
        // Lifecycle events
        .app_start => {
            handleAppStart();
            return true;
        },
        .app_pause => {
            handleAppPause();
            return true;
        },
        .app_resume => {
            handleAppResume();
            return true;
        },
        .app_stop => {
            handleAppStop();
            return true;
        },

        // Example counter events (customize or remove)
        .increment => {
            app_state.counter += 1;
            return true;
        },
        .decrement => {
            app_state.counter -= 1;
            return true;
        },
        .reset => {
            app_state.counter = 0;
            return true;
        },

        // Navigation
        .navigate => {
            if (event.getPayload(NavigatePayload)) |nav| {
                app_state.current_view = nav.destination;
                return true;
            }
            return false;
        },
        .back => {
            app_state.current_view = "main";
            return true;
        },

        // Unhandled events
        else => return false,
    }
}

// ============================================================================
// Event Payload Types
// ============================================================================

pub const NavigatePayload = struct {
    destination: []const u8,
};

pub const ButtonPayload = struct {
    button_id: u32,
};

pub const TextInputPayload = struct {
    text: []const u8,
};

// ============================================================================
// Private Handlers
// ============================================================================

fn handleAppStart() void {
    // Called when the application starts
    // Initialize resources, load saved state, etc.
}

fn handleAppPause() void {
    // Called when the application is paused (backgrounded)
    // Save state, pause animations, etc.
}

fn handleAppResume() void {
    // Called when the application is resumed
    // Restore state, resume animations, etc.
}

fn handleAppStop() void {
    // Called when the application is stopping
    // Cleanup resources, save final state, etc.
}

// ============================================================================
// Tests
// ============================================================================

test "state initialization" {
    init();
    defer deinit();

    const state = getState();
    try std.testing.expect(state.initialized);
    try std.testing.expectEqual(@as(i32, 0), state.counter);
}

test "counter events" {
    init();
    defer deinit();

    _ = handleEvent(.{ .type = .increment });
    try std.testing.expectEqual(@as(i32, 1), app_state.counter);

    _ = handleEvent(.{ .type = .increment });
    try std.testing.expectEqual(@as(i32, 2), app_state.counter);

    _ = handleEvent(.{ .type = .decrement });
    try std.testing.expectEqual(@as(i32, 1), app_state.counter);

    _ = handleEvent(.{ .type = .reset });
    try std.testing.expectEqual(@as(i32, 0), app_state.counter);
}

test "navigation events" {
    init();
    defer deinit();

    const nav = NavigatePayload{ .destination = "settings" };
    _ = handleEvent(.{ .type = .navigate, .payload = @ptrCast(&nav) });
    try std.testing.expectEqualStrings("settings", app_state.current_view);

    _ = handleEvent(.{ .type = .back });
    try std.testing.expectEqualStrings("main", app_state.current_view);
}
