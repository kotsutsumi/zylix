//! Web PWA - Entry Point and C ABI Exports

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

// Service Worker
export fn app_is_sw_registered() bool {
    return app.isSwRegistered();
}

export fn app_register_sw() void {
    app.registerSw();
}

export fn app_update_sw() void {
    app.updateSw();
}

export fn app_is_sw_update_available() bool {
    return app.getState().sw_update_available;
}

// Network
export fn app_is_online() bool {
    return app.getState().is_online;
}

export fn app_set_online(online: bool) void {
    app.setOnline(online);
}

// Cache
export fn app_set_cache_strategy(strategy: u8) void {
    const strategy_count = @typeInfo(app.CacheStrategy).@"enum".fields.len;
    if (strategy < strategy_count) {
        app.setCacheStrategy(@enumFromInt(strategy));
    }
}

export fn app_get_cache_strategy() u8 {
    return @intFromEnum(app.getState().cache_strategy);
}

export fn app_get_cached_count() u32 {
    return @intCast(app.getState().cached_count);
}

export fn app_get_cache_size() u32 {
    return app.getCacheSize();
}

export fn app_clear_cache() void {
    app.clearCache();
}

// Push
export fn app_get_push_permission() u8 {
    return @intFromEnum(app.getState().push_permission);
}

export fn app_request_push_permission() void {
    app.requestPushPermission();
}

export fn app_is_push_enabled() bool {
    return app.getState().push_enabled;
}

export fn app_set_push_enabled(enabled: bool) void {
    app.setPushEnabled(enabled);
}

export fn app_get_pending_notifications() u32 {
    return app.getState().pending_notifications;
}

export fn app_clear_pending_notifications() void {
    app.clearPendingNotifications();
}

// Install
export fn app_can_install() bool {
    return app.canInstall();
}

export fn app_is_installed() bool {
    return app.getState().is_installed;
}

export fn app_prompt_install() void {
    app.promptInstall();
}

export fn app_mark_installed() void {
    app.markInstalled();
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

test "service worker" {
    init();
    defer deinit();

    try std.testing.expect(app_is_sw_registered());
}

test "cache" {
    init();
    defer deinit();

    try std.testing.expect(app_get_cached_count() > 0);
    try std.testing.expect(app_get_cache_size() > 0);
}

test "push" {
    init();
    defer deinit();

    app_request_push_permission();
    try std.testing.expectEqual(@as(u8, 1), app_get_push_permission());
}

test "install" {
    init();
    defer deinit();

    try std.testing.expect(app_can_install());
    app_mark_installed();
    try std.testing.expect(app_is_installed());
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
