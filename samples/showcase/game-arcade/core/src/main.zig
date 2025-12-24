//! Game Arcade Showcase
//!
//! Demonstration of Zylix game engine features and mini-games.

const std = @import("std");
const app = @import("app.zig");
const arcade = @import("arcade.zig");

pub const AppState = app.AppState;
pub const Game = app.Game;
pub const GameState = app.GameState;
pub const Direction = app.Direction;
pub const VNode = arcade.VNode;

pub fn init() void {
    app.init();
}

pub fn deinit() void {
    app.deinit();
}

pub fn getState() *const AppState {
    return app.getState();
}

pub fn update(dt: f32) void {
    app.update(dt);
}

pub fn render() VNode {
    return arcade.buildApp(app.getState());
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

export fn app_select_game(game: u32) void {
    const max_game = @typeInfo(Game).@"enum".fields.len;
    if (game >= max_game) return;
    app.selectGame(@enumFromInt(game));
}

export fn app_start_game() void {
    app.startGame();
}

export fn app_pause_game() void {
    app.pauseGame();
}

export fn app_set_input(x: f32, y: f32, action: i32) void {
    app.setInput(x, y, action != 0);
}

export fn app_set_snake_direction(dir: u8) void {
    const max_dir = @typeInfo(Direction).@"enum".fields.len;
    if (dir >= max_dir) return;
    app.setSnakeDirection(@enumFromInt(dir));
}

export fn app_flip_card(index: u32) void {
    app.flipCard(index);
}

export fn app_get_score() u32 {
    return getState().score;
}

export fn app_get_lives() u8 {
    return getState().lives;
}

export fn app_get_game_state() u8 {
    return @intFromEnum(getState().game_state);
}

export fn app_is_playing() i32 {
    return if (getState().game_state == .playing) 1 else 0;
}

// Tests
test "initialization" {
    init();
    defer deinit();
    try std.testing.expect(getState().initialized);
    try std.testing.expectEqual(Game.breakout, getState().current_game);
}

test "game selection" {
    init();
    defer deinit();
    app.selectGame(.snake);
    try std.testing.expectEqual(Game.snake, getState().current_game);
}

test "game start" {
    init();
    defer deinit();
    app.startGame();
    try std.testing.expectEqual(GameState.playing, getState().game_state);
}

test "update" {
    init();
    defer deinit();
    app.startGame();
    update(0.016);
    try std.testing.expect(getState().frame_count > 0);
}

test "render" {
    init();
    defer deinit();
    const view = render();
    try std.testing.expectEqual(arcade.Tag.column, view.tag);
}
