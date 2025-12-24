//! Puzzle World - Entry Point and C ABI Exports

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

export fn puzzle_init() void {
    init();
}

export fn puzzle_deinit() void {
    deinit();
}

// Mode selection
export fn puzzle_select_mode(mode: u8) void {
    const mode_count = @typeInfo(app.PuzzleMode).@"enum".fields.len;
    if (mode < mode_count) {
        app.selectMode(@enumFromInt(mode));
    }
}

export fn puzzle_get_mode() u8 {
    return @intFromEnum(app.getState().mode);
}

// Game control
export fn puzzle_start() void {
    app.startGame();
}

export fn puzzle_pause() void {
    app.pauseGame();
}

export fn puzzle_resume() void {
    app.resumeGame();
}

export fn puzzle_reset() void {
    app.resetGame();
}

export fn puzzle_menu() void {
    app.returnToMenu();
}

export fn puzzle_get_state() u8 {
    return @intFromEnum(app.getState().state);
}

// Match-3
export fn match3_select(row: u8, col: u8) void {
    app.match3Select(row, col);
}

export fn match3_get_score() u32 {
    return app.getState().match3.score;
}

export fn match3_get_moves() u32 {
    return app.getState().match3.moves;
}

// Sliding puzzle
export fn sliding_move(dir: u8) void {
    const dir_count = @typeInfo(app.Direction).@"enum".fields.len;
    if (dir < dir_count) {
        app.slidingMove(@enumFromInt(dir));
    }
}

export fn sliding_get_moves() u32 {
    return app.getState().sliding.moves;
}

// Memory game
export fn memory_select(index: u8) void {
    app.memorySelect(index);
}

export fn memory_check() void {
    app.memoryCheck();
}

export fn memory_get_moves() u32 {
    return app.getState().memory.moves;
}

export fn memory_get_pairs_found() u8 {
    return app.getState().memory.pairs_found;
}

// High score
export fn puzzle_get_high_score() u32 {
    return app.getState().high_score;
}

// UI rendering
export fn puzzle_render() [*]const ui.VNode {
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

test "mode selection" {
    init();
    defer deinit();

    puzzle_select_mode(1); // match3
    try std.testing.expectEqual(@as(u8, 1), puzzle_get_mode());
}

test "game start" {
    init();
    defer deinit();

    puzzle_select_mode(1);
    puzzle_start();
    try std.testing.expectEqual(@as(u8, 1), puzzle_get_state()); // playing
}

test "pause resume" {
    init();
    defer deinit();

    puzzle_select_mode(1);
    puzzle_start();
    puzzle_pause();
    try std.testing.expectEqual(@as(u8, 2), puzzle_get_state()); // paused
    puzzle_resume();
    try std.testing.expectEqual(@as(u8, 1), puzzle_get_state()); // playing
}

test "match3 tracking" {
    init();
    defer deinit();

    puzzle_select_mode(1);
    puzzle_start();
    try std.testing.expectEqual(@as(u32, 0), match3_get_score());
}

test "ui render" {
    init();
    defer deinit();
    const root = puzzle_render();
    try std.testing.expectEqual(ui.Tag.column, root[0].tag);
}
