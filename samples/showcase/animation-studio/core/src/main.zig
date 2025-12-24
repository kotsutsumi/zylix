//! Animation Studio Showcase
//!
//! Comprehensive demonstration of Zylix animation capabilities.

const std = @import("std");
const app = @import("app.zig");
const studio = @import("studio.zig");

pub const AppState = app.AppState;
pub const DemoScene = app.DemoScene;
pub const EasingType = app.EasingType;
pub const LoopMode = app.LoopMode;
pub const AnimationState = app.AnimationState;
pub const Expression = app.Expression;
pub const VNode = studio.VNode;

pub fn init() void {
    app.init();
}

pub fn deinit() void {
    app.deinit();
}

pub fn getState() *const AppState {
    return app.getState();
}

pub fn update(delta_time: f32) void {
    app.update(delta_time);
}

pub fn render() VNode {
    return studio.buildApp(app.getState());
}

// C ABI Exports
export fn app_init() void {
    init();
}

export fn app_deinit() void {
    deinit();
}

export fn app_update(delta_time: f32) void {
    update(delta_time);
}

export fn app_select_scene(scene: u32) void {
    const max_scene = @typeInfo(DemoScene).@"enum".fields.len;
    if (scene >= max_scene) return;
    app.selectScene(@enumFromInt(scene));
}

export fn app_play() void {
    app.play();
}

export fn app_pause() void {
    app.pause();
}

export fn app_stop() void {
    app.stop();
}

export fn app_seek(time: f32) void {
    app.seek(time);
}

export fn app_set_speed(speed: f32) void {
    app.setSpeed(speed);
}

export fn app_set_easing(easing: u8) void {
    const max_easing = @typeInfo(EasingType).@"enum".fields.len;
    if (easing >= max_easing) return;
    app.setEasing(@enumFromInt(easing));
}

export fn app_set_loop_mode(mode: u8) void {
    const max_mode = @typeInfo(LoopMode).@"enum".fields.len;
    if (mode >= max_mode) return;
    app.setLoopMode(@enumFromInt(mode));
}

export fn app_set_character_state(state: u8) void {
    const max_state = @typeInfo(AnimationState).@"enum".fields.len;
    if (state >= max_state) return;
    app.setCharacterState(@enumFromInt(state));
}

export fn app_set_expression(expr: u8) void {
    const max_expr = @typeInfo(Expression).@"enum".fields.len;
    if (expr >= max_expr) return;
    app.setExpression(@enumFromInt(expr));
}

export fn app_is_playing() i32 {
    return if (getState().is_playing) 1 else 0;
}

export fn app_get_current_time() f32 {
    return getState().current_time;
}

export fn app_get_duration() f32 {
    return getState().duration;
}

// Tests
test "initialization" {
    init();
    defer deinit();
    try std.testing.expect(getState().initialized);
    try std.testing.expectEqual(DemoScene.basic, getState().current_scene);
}

test "playback" {
    init();
    defer deinit();
    app.play();
    try std.testing.expect(getState().is_playing);
    update(0.5);
    try std.testing.expect(getState().current_time > 0);
}

test "scene selection" {
    init();
    defer deinit();
    app.selectScene(.character);
    try std.testing.expectEqual(DemoScene.character, getState().current_scene);
}

test "render" {
    init();
    defer deinit();
    const view = render();
    try std.testing.expectEqual(studio.Tag.column, view.tag);
}
