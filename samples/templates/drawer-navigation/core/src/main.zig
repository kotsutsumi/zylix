//! Drawer Navigation Template
//!
//! A side drawer navigation app with hamburger menu and nested sections.

const std = @import("std");
const app = @import("app.zig");
const drawer = @import("drawer.zig");

pub const AppState = app.AppState;
pub const Screen = app.Screen;
pub const VNode = drawer.VNode;

pub fn init() void {
    app.init();
}

pub fn deinit() void {
    app.deinit();
}

pub fn getState() *const AppState {
    return app.getState();
}

pub fn navigateTo(screen: Screen) void {
    app.navigateTo(screen);
}

pub fn toggleDrawer() void {
    app.toggleDrawer();
}

pub fn render() VNode {
    return drawer.buildApp(app.getState());
}

// C ABI Exports
export fn app_init() void {
    init();
}

export fn app_deinit() void {
    deinit();
}

export fn app_navigate_to(screen: u32) void {
    const max_screen = @typeInfo(Screen).@"enum".fields.len;
    if (screen >= max_screen) return;
    navigateTo(@enumFromInt(screen));
}

export fn app_toggle_drawer() void {
    toggleDrawer();
}

export fn app_is_drawer_open() i32 {
    return if (getState().drawer_open) 1 else 0;
}

// Tests
test "initialization" {
    init();
    defer deinit();
    try std.testing.expect(getState().initialized);
    try std.testing.expectEqual(Screen.home, getState().current_screen);
}

test "navigation" {
    init();
    defer deinit();
    navigateTo(.dashboard);
    try std.testing.expectEqual(Screen.dashboard, getState().current_screen);
}

test "drawer toggle" {
    init();
    defer deinit();
    try std.testing.expect(!getState().drawer_open);
    toggleDrawer();
    try std.testing.expect(getState().drawer_open);
    toggleDrawer();
    try std.testing.expect(!getState().drawer_open);
}
