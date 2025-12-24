//! Tab Navigation Template
//!
//! A multi-tab application with bottom tab bar navigation,
//! state preservation, and multiple screens.

const std = @import("std");
const app = @import("app.zig");
const router = @import("router.zig");

// Re-export public API
pub const AppState = app.AppState;
pub const Tab = router.Tab;
pub const VNode = router.VNode;

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

/// Navigate to a tab
pub fn navigateTo(tab: Tab) void {
    app.navigateTo(tab);
}

/// Get current tab
pub fn currentTab() Tab {
    return app.getState().current_tab;
}

/// Render the current UI
pub fn render() VNode {
    return router.buildApp(app.getState());
}

// ============================================================================
// C ABI Exports
// ============================================================================

export fn app_init() void {
    init();
}

export fn app_deinit() void {
    deinit();
}

export fn app_navigate_to(tab: u32) void {
    // Validate tab is in valid range before enum conversion
    const max_tab = @typeInfo(Tab).@"enum".fields.len;
    if (tab >= max_tab) {
        return;
    }
    navigateTo(@enumFromInt(tab));
}

export fn app_get_current_tab() u32 {
    return @intFromEnum(currentTab());
}

// ============================================================================
// Tests
// ============================================================================

test "app initialization" {
    init();
    defer deinit();

    const state = getState();
    try std.testing.expect(state.initialized);
    try std.testing.expectEqual(Tab.home, state.current_tab);
}

test "tab navigation" {
    init();
    defer deinit();

    navigateTo(.search);
    try std.testing.expectEqual(Tab.search, currentTab());

    navigateTo(.profile);
    try std.testing.expectEqual(Tab.profile, currentTab());

    navigateTo(.home);
    try std.testing.expectEqual(Tab.home, currentTab());
}

test "C ABI tab validation" {
    init();
    defer deinit();

    // Valid tab
    app_navigate_to(1); // search
    try std.testing.expectEqual(Tab.search, currentTab());

    // Invalid tab (out of range) - should be ignored
    app_navigate_to(100);
    try std.testing.expectEqual(Tab.search, currentTab());
}
