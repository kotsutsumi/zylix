//! Fit Track - Entry Point and C ABI Exports

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

// Workouts
export fn app_log_workout(workout_type: u8, duration: u32, calories: u32, distance: u32) u32 {
    const type_count = @typeInfo(app.WorkoutType).@"enum".fields.len;
    if (workout_type < type_count) {
        return app.logWorkout(@enumFromInt(workout_type), duration, calories, distance) orelse 0;
    }
    return 0;
}

export fn app_get_workout_count() u32 {
    return @intCast(app.getState().workout_count);
}

// Daily tracking
export fn app_add_steps(steps: u32) void {
    app.addSteps(steps);
}

export fn app_get_steps_today() u32 {
    return app.getState().today.steps;
}

export fn app_get_calories_today() u32 {
    return app.getState().today.calories_burned;
}

export fn app_get_active_minutes_today() u32 {
    return app.getState().today.active_minutes;
}

// Goals
export fn app_set_step_goal(steps: u32) void {
    app.setStepGoal(steps);
}

export fn app_set_calorie_goal(calories: u32) void {
    app.setCalorieGoal(calories);
}

export fn app_get_step_goal() u32 {
    return app.getState().goal.steps;
}

export fn app_get_calorie_goal() u32 {
    return app.getState().goal.calories;
}

// Progress
export fn app_get_step_progress() f32 {
    return app.getStepProgress();
}

export fn app_get_calorie_progress() f32 {
    return app.getCalorieProgress();
}

export fn app_get_current_streak() u32 {
    return app.getState().current_streak;
}

export fn app_get_weekly_average() u32 {
    return app.getWeeklyAverage();
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

test "log workout" {
    init();
    defer deinit();

    const initial = app_get_workout_count();
    const id = app_log_workout(0, 30, 300, 5000); // running
    try std.testing.expect(id > 0);
    try std.testing.expectEqual(initial + 1, app_get_workout_count());
}

test "step tracking" {
    init();
    defer deinit();

    const initial = app_get_steps_today();
    app_add_steps(500);
    try std.testing.expectEqual(initial + 500, app_get_steps_today());
}

test "goals" {
    init();
    defer deinit();

    app_set_step_goal(12000);
    try std.testing.expectEqual(@as(u32, 12000), app_get_step_goal());

    app_set_calorie_goal(600);
    try std.testing.expectEqual(@as(u32, 600), app_get_calorie_goal());
}

test "progress" {
    init();
    defer deinit();

    const step_progress = app_get_step_progress();
    try std.testing.expect(step_progress >= 0 and step_progress <= 1);

    try std.testing.expect(app_get_current_streak() > 0);
    try std.testing.expect(app_get_weekly_average() > 0);
}

test "navigation" {
    init();
    defer deinit();

    app_set_screen(1); // workouts
    try std.testing.expectEqual(@as(u8, 1), app_get_screen());
}

test "ui render" {
    init();
    defer deinit();

    const root = app_render();
    try std.testing.expectEqual(ui.Tag.column, root[0].tag);
}
