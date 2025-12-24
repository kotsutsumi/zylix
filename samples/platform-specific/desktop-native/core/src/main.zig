//! Desktop Native - Entry Point and C ABI Exports

const std = @import("std");
pub const app = @import("app.zig");
pub const ui = @import("ui.zig");

// ============================================================================
// Initialization
// ============================================================================

pub fn init() void {
    app.init();
}

pub fn deinit() void {
    app.deinit();
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

// Navigation
export fn app_set_screen(screen: u8) void {
    const screen_count = @typeInfo(app.Screen).@"enum".fields.len;
    if (screen < screen_count) {
        app.setScreen(@enumFromInt(screen));
    }
}

export fn app_get_screen() u8 {
    return @intFromEnum(app.getState().current_screen);
}

// System Tray
export fn app_set_tray_visible(visible: bool) void {
    app.setTrayVisible(visible);
}

export fn app_is_tray_visible() bool {
    return app.getState().tray_visible;
}

export fn app_set_badge_count(count: u32) void {
    app.setBadgeCount(count);
}

export fn app_get_badge_count() u32 {
    return app.getState().badge_count;
}

export fn app_clear_badge() void {
    app.clearBadge();
}

// Files
export fn app_get_recent_file_count() u32 {
    return @intCast(app.getState().recent_file_count);
}

export fn app_clear_recent_files() void {
    app.clearRecentFiles();
}

export fn app_pin_recent_file(index: u32) void {
    app.pinRecentFile(@intCast(index));
}

export fn app_get_watching_paths() u32 {
    return app.getState().watching_paths;
}

export fn app_add_watch_path() void {
    app.addWatchPath();
}

export fn app_remove_watch_path() void {
    app.removeWatchPath();
}

// Shortcuts
export fn app_get_shortcut_count() u32 {
    return @intCast(app.getState().shortcut_count);
}

export fn app_toggle_shortcut(shortcut_id: u32) void {
    app.toggleShortcut(shortcut_id);
}

// Window
export fn app_is_fullscreen() bool {
    return app.getState().is_fullscreen;
}

export fn app_set_fullscreen(fullscreen: bool) void {
    app.setFullscreen(fullscreen);
}

export fn app_toggle_fullscreen() void {
    app.toggleFullscreen();
}

export fn app_is_always_on_top() bool {
    return app.getState().is_always_on_top;
}

export fn app_set_always_on_top(enabled: bool) void {
    app.setAlwaysOnTop(enabled);
}

export fn app_is_maximized() bool {
    return app.getState().is_maximized;
}

export fn app_set_maximized(maximized: bool) void {
    app.setMaximized(maximized);
}

// Notifications
export fn app_is_notifications_enabled() bool {
    return app.getState().notifications_enabled;
}

export fn app_set_notifications_enabled(enabled: bool) void {
    app.setNotificationsEnabled(enabled);
}

// UI rendering
export fn app_render() [*]const ui.VNode {
    return ui.render();
}

// ============================================================================
// Tests
// ============================================================================

test "initialization" {
    init();
    defer deinit();
    try std.testing.expect(app.getState().initialized);
}

test "tray" {
    init();
    defer deinit();

    try std.testing.expect(app_is_tray_visible());
    app_set_badge_count(5);
    try std.testing.expectEqual(@as(u32, 5), app_get_badge_count());
}

test "files" {
    init();
    defer deinit();

    try std.testing.expect(app_get_recent_file_count() > 0);
}

test "shortcuts" {
    init();
    defer deinit();

    try std.testing.expect(app_get_shortcut_count() > 0);
}

test "window" {
    init();
    defer deinit();

    try std.testing.expect(!app_is_fullscreen());
    app_toggle_fullscreen();
    try std.testing.expect(app_is_fullscreen());
}

test "navigation" {
    init();
    defer deinit();

    app_set_screen(1);
    try std.testing.expectEqual(@as(u8, 1), app_get_screen());
}

test "ui render" {
    init();
    defer deinit();

    const root = app_render();
    try std.testing.expectEqual(ui.Tag.row, root[0].tag);
}
