//! Media Box - Entry Point and C ABI Exports

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

// Playback controls
export fn app_play() void {
    app.play();
}

export fn app_pause() void {
    app.pause();
}

export fn app_stop() void {
    app.stop();
}

export fn app_toggle_play_pause() void {
    app.togglePlayPause();
}

export fn app_next_track() void {
    app.nextTrack();
}

export fn app_prev_track() void {
    app.prevTrack();
}

export fn app_seek(position: f32) void {
    app.seek(position);
}

export fn app_set_volume(volume: f32) void {
    app.setVolume(volume);
}

export fn app_toggle_shuffle() void {
    app.toggleShuffle();
}

export fn app_cycle_repeat() void {
    app.cycleRepeat();
}

export fn app_select_track(id: u32) void {
    app.selectTrack(id);
}

export fn app_select_playlist(id: u32) void {
    if (id == 0) {
        app.selectPlaylist(null);
    } else {
        app.selectPlaylist(id);
    }
}

// Queries
export fn app_get_track_count() u32 {
    return @intCast(app.getState().track_count);
}

export fn app_get_playlist_count() u32 {
    return @intCast(app.getState().playlist_count);
}

export fn app_get_play_state() u8 {
    return @intFromEnum(app.getState().play_state);
}

export fn app_get_current_track() u32 {
    return app.getState().current_track orelse 0;
}

export fn app_get_position() f32 {
    return app.getState().position;
}

export fn app_get_volume() f32 {
    return app.getState().volume;
}

export fn app_is_shuffle() i32 {
    return if (app.getState().shuffle) 1 else 0;
}

export fn app_get_repeat() u8 {
    return @intFromEnum(app.getState().repeat);
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

test "playback controls" {
    init();
    defer deinit();

    app_play();
    try std.testing.expectEqual(@as(u8, 1), app_get_play_state()); // playing

    app_pause();
    try std.testing.expectEqual(@as(u8, 2), app_get_play_state()); // paused

    app_stop();
    try std.testing.expectEqual(@as(u8, 0), app_get_play_state()); // stopped
}

test "track selection" {
    init();
    defer deinit();

    app_select_track(1);
    try std.testing.expectEqual(@as(u32, 1), app_get_current_track());
    try std.testing.expectEqual(@as(u8, 1), app_get_play_state());
}

test "track navigation" {
    init();
    defer deinit();

    app_select_track(1);
    app_next_track();
    try std.testing.expectEqual(@as(u32, 2), app_get_current_track());

    app_prev_track();
    try std.testing.expectEqual(@as(u32, 1), app_get_current_track());
}

test "volume and seek" {
    init();
    defer deinit();

    app_set_volume(0.5);
    try std.testing.expectEqual(@as(f32, 0.5), app_get_volume());

    app_seek(0.25);
    try std.testing.expectEqual(@as(f32, 0.25), app_get_position());
}

test "shuffle and repeat" {
    init();
    defer deinit();

    try std.testing.expectEqual(@as(i32, 0), app_is_shuffle());
    app_toggle_shuffle();
    try std.testing.expectEqual(@as(i32, 1), app_is_shuffle());

    try std.testing.expectEqual(@as(u8, 0), app_get_repeat()); // off
    app_cycle_repeat();
    try std.testing.expectEqual(@as(u8, 1), app_get_repeat()); // all
}

test "navigation" {
    init();
    defer deinit();

    app_set_screen(2); // playlists
    try std.testing.expectEqual(@as(u8, 2), app_get_screen());
}

test "ui render" {
    init();
    defer deinit();

    const root = app_render();
    try std.testing.expectEqual(ui.Tag.column, root[0].tag);
}
