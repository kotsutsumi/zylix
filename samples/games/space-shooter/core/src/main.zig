//! Space Shooter - Entry Point and C ABI Exports

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

export fn game_init() void {
    init();
}

export fn game_deinit() void {
    deinit();
}

export fn game_update(delta: f32) void {
    app.update(delta);
}

// Game control
export fn game_start() void {
    app.startGame();
}

export fn game_pause() void {
    app.pauseGame();
}

export fn game_resume() void {
    app.resumeGame();
}

export fn game_menu() void {
    app.returnToMenu();
}

export fn game_get_state() u8 {
    return @intFromEnum(app.getState().state);
}

export fn game_get_score() u32 {
    return app.getState().score;
}

export fn game_get_high_score() u32 {
    return app.getState().high_score;
}

export fn game_get_lives() u8 {
    return app.getState().lives;
}

export fn game_get_wave() u8 {
    return app.getState().current_wave;
}

// Player input
export fn player_move(dx: f32, dy: f32) void {
    app.setMove(dx, dy);
}

export fn player_fire(firing: bool) void {
    app.setFiring(firing);
}

export fn player_special() void {
    app.fireSpecial();
}

// Player state
export fn player_get_x() f32 {
    return app.getState().player.x;
}

export fn player_get_y() f32 {
    return app.getState().player.y;
}

export fn player_get_weapon_level() u8 {
    return app.getState().player.weapon_level;
}

export fn player_get_shield() u8 {
    return app.getState().player.shield;
}

export fn player_get_special_ammo() u8 {
    return app.getState().player.special_ammo;
}

// UI rendering
export fn game_render() [*]const ui.VNode {
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

test "game flow" {
    init();
    defer deinit();

    try std.testing.expectEqual(@as(u8, 0), game_get_state()); // menu

    game_start();
    try std.testing.expectEqual(@as(u8, 1), game_get_state()); // playing

    game_pause();
    try std.testing.expectEqual(@as(u8, 2), game_get_state()); // paused

    game_resume();
    try std.testing.expectEqual(@as(u8, 1), game_get_state()); // playing
}

test "player movement" {
    init();
    defer deinit();
    game_start();

    const initial_x = player_get_x();
    player_move(1.0, 0);
    game_update(0.1);
    try std.testing.expect(player_get_x() > initial_x);
}

test "initial state" {
    init();
    defer deinit();
    game_start();

    try std.testing.expectEqual(@as(u8, 3), game_get_lives());
    try std.testing.expectEqual(@as(u8, 1), game_get_wave());
    try std.testing.expectEqual(@as(u32, 0), game_get_score());
}

test "weapon level" {
    init();
    defer deinit();
    game_start();
    try std.testing.expectEqual(@as(u8, 1), player_get_weapon_level());
}

test "ui render" {
    init();
    defer deinit();
    const root = game_render();
    try std.testing.expectEqual(ui.Tag.column, root[0].tag);
}
