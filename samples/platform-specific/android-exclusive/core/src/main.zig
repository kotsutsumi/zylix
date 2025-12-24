//! Android Exclusive - Entry Point and C ABI Exports

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

// Material You
export fn app_set_dynamic_colors(enabled: bool) void {
    app.setDynamicColorsEnabled(enabled);
}

export fn app_is_dynamic_colors_enabled() bool {
    return app.getState().dynamic_colors_enabled;
}

export fn app_get_primary_color() u32 {
    return app.getPrimaryColor();
}

export fn app_get_secondary_color() u32 {
    return app.getSecondaryColor();
}

// Widgets
export fn app_get_widget_count() u32 {
    return @intCast(app.getState().widget_count);
}

export fn app_place_widget(widget_id: u32) void {
    app.placeWidget(widget_id);
}

export fn app_remove_widget(widget_id: u32) void {
    app.removeWidget(widget_id);
}

// Notifications
export fn app_set_channel_enabled(channel: u8, enabled: bool) void {
    const channel_count = @typeInfo(app.NotificationChannel).@"enum".fields.len;
    if (channel < channel_count) {
        app.setChannelEnabled(@enumFromInt(channel), enabled);
    }
}

export fn app_is_channel_enabled(channel: u8) bool {
    const channel_count = @typeInfo(app.NotificationChannel).@"enum".fields.len;
    if (channel < channel_count) {
        return app.isChannelEnabled(@enumFromInt(channel));
    }
    return false;
}

export fn app_get_notification_count() u32 {
    return app.getState().notification_count;
}

export fn app_clear_notifications() void {
    app.clearNotifications();
}

// Shortcuts
export fn app_get_shortcut_count() u32 {
    return @intCast(app.getState().shortcut_count);
}

export fn app_pin_shortcut(shortcut_id: u32) void {
    app.pinShortcut(shortcut_id);
}

export fn app_toggle_shortcut(shortcut_id: u32) void {
    app.toggleShortcut(shortcut_id);
}

// Work profile
export fn app_is_work_profile() bool {
    return app.getState().is_work_profile;
}

export fn app_set_work_mode(enabled: bool) void {
    app.setWorkModeEnabled(enabled);
}

export fn app_is_work_mode_enabled() bool {
    return app.getState().work_mode_enabled;
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

test "material you" {
    init();
    defer deinit();

    try std.testing.expect(app_is_dynamic_colors_enabled());
    try std.testing.expect(app_get_primary_color() != 0);
}

test "widgets" {
    init();
    defer deinit();

    try std.testing.expect(app_get_widget_count() > 0);
}

test "notifications" {
    init();
    defer deinit();

    try std.testing.expect(app_is_channel_enabled(0));
    app_set_channel_enabled(0, false);
    try std.testing.expect(!app_is_channel_enabled(0));
}

test "shortcuts" {
    init();
    defer deinit();

    try std.testing.expect(app_get_shortcut_count() > 0);
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
    try std.testing.expectEqual(ui.Tag.column, root[0].tag);
}
