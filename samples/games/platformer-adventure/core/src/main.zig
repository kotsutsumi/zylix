//! Platformer Adventure - Entry Point and C ABI Exports

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

export fn game_restart() void {
    app.restartLevel();
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

export fn game_get_lives() u8 {
    return app.getState().lives;
}

export fn game_get_level() u8 {
    return app.getState().current_level;
}

// Player input
export fn player_move_left() void {
    app.moveLeft();
}

export fn player_move_right() void {
    app.moveRight();
}

export fn player_stop() void {
    app.stopMove();
}

export fn player_jump() void {
    app.jump();
}

// Player position (for rendering)
export fn player_get_x() f32 {
    return app.getState().player.position.x;
}

export fn player_get_y() f32 {
    return app.getState().player.position.y;
}

export fn player_is_on_ground() bool {
    return app.getState().player.on_ground;
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

test "player input" {
    init();
    defer deinit();
    game_start();

    const initial_x = player_get_x();
    player_move_right();
    game_update(0.1);
    try std.testing.expect(player_get_x() > initial_x);
}

test "score tracking" {
    init();
    defer deinit();
    game_start();
    try std.testing.expectEqual(@as(u32, 0), game_get_score());
}

test "lives tracking" {
    init();
    defer deinit();
    game_start();
    try std.testing.expectEqual(@as(u8, 3), game_get_lives());
}

test "ui render" {
    init();
    defer deinit();
    const root = game_render();
    try std.testing.expectEqual(ui.Tag.column, root[0].tag);
}
