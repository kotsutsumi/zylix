//! Blank App - Minimal Zylix Application Template
//!
//! This template provides the foundation for building cross-platform
//! applications with Zylix. Customize the app state, UI components,
//! and event handlers to create your application.

const std = @import("std");
const app = @import("app.zig");
const ui = @import("ui.zig");

// Re-export public API
pub const AppState = app.AppState;
pub const Event = app.Event;
pub const EventType = app.EventType;

/// Initialize the application
pub fn init() void {
    app.init();
}

/// Deinitialize the application
pub fn deinit() void {
    app.deinit();
}

/// Get current application state
pub fn getState() *const AppState {
    return app.getState();
}

/// Dispatch an event to the application
pub fn dispatch(event: Event) bool {
    return app.handleEvent(event);
}

/// Render the current UI
pub fn render() ui.VNode {
    return ui.buildMainView(app.getState());
}

// ============================================================================
// C ABI Exports (for platform integration)
// ============================================================================

/// Initialize application (C ABI)
export fn zylix_init() void {
    init();
}

/// Deinitialize application (C ABI)
export fn zylix_deinit() void {
    deinit();
}

/// Dispatch event (C ABI)
/// Note: EventType is a non-exhaustive enum, so @enumFromInt is safe for any u32.
/// Unknown values are handled by the `_` wildcard in handleEvent.
export fn zylix_dispatch(event_type: u32, payload: ?*const anyopaque, payload_size: usize) i32 {
    _ = payload_size;
    const event = Event{
        .type = @enumFromInt(event_type),
        .payload = payload,
    };
    return if (dispatch(event)) 1 else 0;
}

// ============================================================================
// Tests
// ============================================================================

test "app initialization" {
    init();
    defer deinit();

    const state = getState();
    try std.testing.expect(state.initialized);
    try std.testing.expectEqualStrings("Blank App", state.app_name);
}

test "event dispatch" {
    init();
    defer deinit();

    const event = Event{
        .type = .app_start,
        .payload = null,
    };
    const result = dispatch(event);
    try std.testing.expect(result);
}
