//! Dashboard Layout Template
//!
//! A business dashboard with header, sidebar, content area, and widget grid.

const std = @import("std");
const app = @import("app.zig");
const dashboard = @import("dashboard.zig");

pub const AppState = app.AppState;
pub const Widget = app.Widget;
pub const VNode = dashboard.VNode;

pub fn init() void {
    app.init();
}

pub fn deinit() void {
    app.deinit();
}

pub fn getState() *const AppState {
    return app.getState();
}

pub fn navigateTo(index: usize) void {
    app.navigateTo(index);
}

pub fn toggleSidebar() void {
    app.toggleSidebar();
}

pub fn toggleTheme() void {
    app.toggleTheme();
}

pub fn render() VNode {
    return dashboard.buildApp(app.getState());
}

// C ABI Exports
export fn app_init() void {
    init();
}

export fn app_deinit() void {
    deinit();
}

export fn app_navigate_to(index: u32) void {
    if (index >= app.nav_items.len) return;
    navigateTo(index);
}

export fn app_toggle_sidebar() void {
    toggleSidebar();
}

export fn app_toggle_theme() void {
    toggleTheme();
}

export fn app_is_sidebar_collapsed() i32 {
    return if (getState().sidebar_collapsed) 1 else 0;
}

export fn app_get_theme() i32 {
    return if (getState().theme == .dark) 1 else 0;
}

export fn app_get_notification_count() u32 {
    return getState().notification_count;
}

// Tests
test "initialization" {
    init();
    defer deinit();
    try std.testing.expect(getState().initialized);
}

test "navigation" {
    init();
    defer deinit();
    navigateTo(2);
    try std.testing.expectEqual(@as(usize, 2), getState().current_nav);
}

test "sidebar toggle" {
    init();
    defer deinit();
    try std.testing.expect(!getState().sidebar_collapsed);
    toggleSidebar();
    try std.testing.expect(getState().sidebar_collapsed);
}

test "theme toggle" {
    init();
    defer deinit();
    try std.testing.expectEqual(app.Theme.light, getState().theme);
    toggleTheme();
    try std.testing.expectEqual(app.Theme.dark, getState().theme);
}
