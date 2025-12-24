//! iOS Exclusive - Entry Point and C ABI Exports

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

// Biometrics
export fn app_is_biometric_available() bool {
    return app.isBiometricAvailable();
}

export fn app_get_biometric_type() u8 {
    return @intFromEnum(app.getState().biometric_type);
}

export fn app_authenticate() bool {
    return app.authenticate();
}

export fn app_is_authenticated() bool {
    return app.getState().is_authenticated;
}

export fn app_logout() void {
    app.logout();
}

// Haptics
export fn app_set_haptics_enabled(enabled: bool) void {
    app.setHapticsEnabled(enabled);
}

export fn app_is_haptics_enabled() bool {
    return app.getState().haptics_enabled;
}

export fn app_trigger_haptic(style: u8) void {
    const style_count = @typeInfo(app.HapticStyle).@"enum".fields.len;
    if (style < style_count) {
        app.triggerHaptic(@enumFromInt(style));
    }
}

export fn app_trigger_notification(notification_type: u8) void {
    const type_count = @typeInfo(app.NotificationType).@"enum".fields.len;
    if (notification_type < type_count) {
        app.triggerNotification(@enumFromInt(notification_type));
    }
}

// HealthKit
export fn app_request_health_auth() void {
    app.requestHealthAuthorization();
}

export fn app_is_health_authorized() bool {
    return app.getState().health_authorized;
}

export fn app_get_health_value(data_type: u8) u32 {
    const type_count = @typeInfo(app.HealthDataType).@"enum".fields.len;
    if (data_type < type_count) {
        return app.getHealthValue(@enumFromInt(data_type));
    }
    return 0;
}

export fn app_get_steps_today() u32 {
    return app.getState().steps_today;
}

export fn app_get_heart_rate() u32 {
    return app.getState().heart_rate;
}

// Siri shortcuts
export fn app_get_shortcut_count() u32 {
    return @intCast(app.getState().shortcut_count);
}

export fn app_toggle_shortcut(shortcut_id: u32) void {
    app.toggleShortcut(shortcut_id);
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

test "biometrics" {
    init();
    defer deinit();

    try std.testing.expect(app_is_biometric_available());
    try std.testing.expect(app_authenticate());
    try std.testing.expect(app_is_authenticated());
}

test "haptics" {
    init();
    defer deinit();

    try std.testing.expect(app_is_haptics_enabled());
    app_trigger_haptic(2); // heavy
}

test "health" {
    init();
    defer deinit();

    try std.testing.expect(app_is_health_authorized());
    try std.testing.expect(app_get_steps_today() > 0);
    try std.testing.expect(app_get_heart_rate() > 0);
}

test "navigation" {
    init();
    defer deinit();

    app_set_screen(1); // biometrics
    try std.testing.expectEqual(@as(u8, 1), app_get_screen());
}

test "ui render" {
    init();
    defer deinit();

    const root = app_render();
    try std.testing.expectEqual(ui.Tag.column, root[0].tag);
}
