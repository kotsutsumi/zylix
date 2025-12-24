//! watchOS Companion - Entry Point and C ABI Exports

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

// Workout
export fn app_start_workout(workout_type: u8) void {
    const type_count = @typeInfo(app.WorkoutType).@"enum".fields.len;
    if (workout_type < type_count) {
        app.startWorkout(@enumFromInt(workout_type));
    }
}

export fn app_pause_workout() void {
    app.pauseWorkout();
}

export fn app_resume_workout() void {
    app.resumeWorkout();
}

export fn app_end_workout() void {
    app.endWorkout();
}

export fn app_get_workout_state() u8 {
    return @intFromEnum(app.getState().workout_state);
}

export fn app_get_workout_duration() u32 {
    return app.getState().workout_duration;
}

export fn app_get_workout_calories() u32 {
    return app.getState().workout_calories;
}

export fn app_update_workout(duration: u32, calories: u32, distance: u32) void {
    app.updateWorkout(duration, calories, distance);
}

// Health
export fn app_get_heart_rate() u32 {
    return app.getState().heart_rate;
}

export fn app_update_heart_rate(rate: u32) void {
    app.updateHeartRate(rate);
}

export fn app_get_steps_today() u32 {
    return app.getState().steps_today;
}

export fn app_add_steps(steps: u32) void {
    app.addSteps(steps);
}

export fn app_get_calories_today() u32 {
    return app.getState().calories_today;
}

export fn app_get_active_minutes() u32 {
    return app.getState().active_minutes;
}

// Connectivity
export fn app_is_phone_connected() bool {
    return app.getState().is_phone_connected;
}

export fn app_set_phone_connected(connected: bool) void {
    app.setPhoneConnected(connected);
}

export fn app_sync_with_phone() void {
    app.syncWithPhone();
}

export fn app_get_pending_messages() u32 {
    return app.getState().pending_messages;
}

// Settings
export fn app_is_haptics_enabled() bool {
    return app.getState().haptics_enabled;
}

export fn app_set_haptics_enabled(enabled: bool) void {
    app.setHapticsEnabled(enabled);
}

export fn app_is_always_on_display() bool {
    return app.getState().always_on_display;
}

export fn app_set_always_on_display(enabled: bool) void {
    app.setAlwaysOnDisplay(enabled);
}

export fn app_is_water_lock() bool {
    return app.getState().water_lock;
}

export fn app_toggle_water_lock() void {
    app.toggleWaterLock();
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

test "workout" {
    init();
    defer deinit();

    app_start_workout(0); // running
    try std.testing.expectEqual(@as(u8, 1), app_get_workout_state()); // active

    app_pause_workout();
    try std.testing.expectEqual(@as(u8, 2), app_get_workout_state()); // paused

    app_end_workout();
    try std.testing.expectEqual(@as(u8, 0), app_get_workout_state()); // idle
}

test "health" {
    init();
    defer deinit();

    try std.testing.expect(app_get_heart_rate() > 0);
    try std.testing.expect(app_get_steps_today() > 0);
}

test "connectivity" {
    init();
    defer deinit();

    try std.testing.expect(app_is_phone_connected());
    app_set_phone_connected(false);
    try std.testing.expect(!app_is_phone_connected());
}

test "settings" {
    init();
    defer deinit();

    try std.testing.expect(app_is_haptics_enabled());
    app_set_haptics_enabled(false);
    try std.testing.expect(!app_is_haptics_enabled());
}

test "navigation" {
    init();
    defer deinit();

    app_set_screen(1); // workout
    try std.testing.expectEqual(@as(u8, 1), app_get_screen());
}

test "ui render" {
    init();
    defer deinit();

    const root = app_render();
    try std.testing.expectEqual(ui.Tag.column, root[0].tag);
}
