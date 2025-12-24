//! VTuber Demo - Entry Point and C ABI Exports

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

export fn vtuber_init() void {
    init();
}

export fn vtuber_deinit() void {
    deinit();
}

export fn vtuber_update(delta: f32) void {
    app.update(delta);
}

// Expression
export fn vtuber_set_expression(expr: u8) void {
    const expr_count = @typeInfo(app.Expression).@"enum".fields.len;
    if (expr < expr_count) {
        app.setExpression(@enumFromInt(expr));
    }
}

export fn vtuber_get_expression() u8 {
    return @intFromEnum(app.getState().character.expression);
}

// Eyes
export fn vtuber_set_eye_position(x: f32, y: f32) void {
    app.setEyePosition(x, y);
}

export fn vtuber_get_eye_x() f32 {
    return app.getState().character.eye_position.x;
}

export fn vtuber_get_eye_y() f32 {
    return app.getState().character.eye_position.y;
}

// Mouth
export fn vtuber_set_mouth_open(amount: f32) void {
    app.setMouthOpen(amount);
}

export fn vtuber_get_mouth_open() f32 {
    return app.getState().character.mouth_open;
}

// Head
export fn vtuber_set_head_rotation(x: f32, y: f32) void {
    app.setHeadRotation(x, y);
}

// Motion
export fn vtuber_play_motion(motion: u8) void {
    const motion_count = @typeInfo(app.Motion).@"enum".fields.len;
    if (motion < motion_count) {
        app.playMotion(@enumFromInt(motion));
    }
}

export fn vtuber_get_current_motion() u8 {
    return @intFromEnum(app.getState().character.current_motion);
}

// Accessories
export fn vtuber_toggle_accessory(id: u8) void {
    app.toggleAccessory(id);
}

export fn vtuber_set_accessory(id: u8, enabled: bool) void {
    app.setAccessory(id, enabled);
}

export fn vtuber_get_accessory(id: u8) bool {
    if (id < 4) {
        return app.getState().character.accessories[id];
    }
    return false;
}

// Background
export fn vtuber_set_background(bg: u8) void {
    const bg_count = @typeInfo(app.Background).@"enum".fields.len;
    if (bg < bg_count) {
        app.setBackground(@enumFromInt(bg));
    }
}

export fn vtuber_get_background() u8 {
    return @intFromEnum(app.getState().background);
}

// Interaction
export fn vtuber_on_touch(x: f32, y: f32) void {
    app.onTouch(x, y);
}

// UI rendering
export fn vtuber_render() [*]const ui.VNode {
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

test "expression" {
    init();
    defer deinit();

    vtuber_set_expression(1); // happy
    try std.testing.expectEqual(@as(u8, 1), vtuber_get_expression());
}

test "eye tracking" {
    init();
    defer deinit();

    vtuber_set_eye_position(0.5, 0.3);
    vtuber_update(0.1);

    try std.testing.expect(vtuber_get_eye_x() > 0);
}

test "mouth sync" {
    init();
    defer deinit();

    vtuber_set_mouth_open(0.8);
    vtuber_update(0.5);

    try std.testing.expect(vtuber_get_mouth_open() > 0);
}

test "motion" {
    init();
    defer deinit();

    vtuber_play_motion(1); // wave
    try std.testing.expectEqual(@as(u8, 1), vtuber_get_current_motion());
}

test "accessories" {
    init();
    defer deinit();

    try std.testing.expect(!vtuber_get_accessory(0));
    vtuber_toggle_accessory(0);
    try std.testing.expect(vtuber_get_accessory(0));
}

test "background" {
    init();
    defer deinit();

    vtuber_set_background(2); // outdoor
    try std.testing.expectEqual(@as(u8, 2), vtuber_get_background());
}

test "touch interaction" {
    init();
    defer deinit();

    vtuber_on_touch(100, 100);
    try std.testing.expectEqual(@as(u8, 2), vtuber_get_expression()); // surprised
}

test "ui render" {
    init();
    defer deinit();
    const root = vtuber_render();
    try std.testing.expectEqual(ui.Tag.column, root[0].tag);
}
