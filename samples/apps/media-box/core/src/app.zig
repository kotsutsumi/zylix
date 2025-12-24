//! Media Box - Application State

const std = @import("std");

pub const Screen = enum(u8) {
    library = 0,
    now_playing = 1,
    playlists = 2,
    search = 3,

    pub fn title(self: Screen) []const u8 {
        return switch (self) {
            .library => "Library",
            .now_playing => "Now Playing",
            .playlists => "Playlists",
            .search => "Search",
        };
    }
};

pub const PlayState = enum(u8) {
    stopped = 0,
    playing = 1,
    paused = 2,
};

pub const RepeatMode = enum(u8) {
    off = 0,
    all = 1,
    one = 2,
};

pub const Track = struct {
    id: u32 = 0,
    title: [64]u8 = [_]u8{0} ** 64,
    title_len: usize = 0,
    artist: [32]u8 = [_]u8{0} ** 32,
    artist_len: usize = 0,
    album: [32]u8 = [_]u8{0} ** 32,
    album_len: usize = 0,
    duration: u32 = 0, // seconds
};

pub const Playlist = struct {
    id: u32 = 0,
    name: [32]u8 = [_]u8{0} ** 32,
    name_len: usize = 0,
    track_count: u32 = 0,
};

pub const max_tracks = 50;
pub const max_playlists = 10;
pub const max_queue = 20;

pub const AppState = struct {
    initialized: bool = false,
    current_screen: Screen = .library,

    // Library
    tracks: [max_tracks]Track = undefined,
    track_count: usize = 0,

    // Playlists
    playlists: [max_playlists]Playlist = undefined,
    playlist_count: usize = 0,
    selected_playlist: ?u32 = null,

    // Playback
    play_state: PlayState = .stopped,
    current_track: ?u32 = null,
    position: f32 = 0, // 0.0 - 1.0
    volume: f32 = 0.8, // 0.0 - 1.0
    shuffle: bool = false,
    repeat: RepeatMode = .off,

    // Queue
    queue: [max_queue]u32 = [_]u32{0} ** max_queue,
    queue_count: usize = 0,
    queue_index: usize = 0,
};

var app_state: AppState = .{};

pub fn init() void {
    app_state = .{ .initialized = true };
    addSampleData();
}

pub fn deinit() void {
    app_state.initialized = false;
}

pub fn getState() *const AppState {
    return &app_state;
}

fn addSampleData() void {
    // Add tracks
    _ = addTrack("Midnight Dreams", "Luna Wave", "Nightscapes", 234);
    _ = addTrack("Electric Soul", "The Sparks", "Voltage", 198);
    _ = addTrack("Ocean Breeze", "Coastal", "Horizons", 267);
    _ = addTrack("City Lights", "Urban Echo", "Metropolis", 215);
    _ = addTrack("Mountain High", "Peak", "Summit", 189);
    _ = addTrack("Sunset Drive", "Golden Hour", "Evening", 242);

    // Add playlists
    _ = addPlaylist("Favorites", 12);
    _ = addPlaylist("Workout", 8);
    _ = addPlaylist("Chill", 15);
}

fn addTrack(title: []const u8, artist: []const u8, album: []const u8, duration: u32) ?u32 {
    if (app_state.track_count >= max_tracks) return null;

    var t = &app_state.tracks[app_state.track_count];
    t.id = @intCast(app_state.track_count + 1);

    const title_len = @min(title.len, t.title.len);
    @memcpy(t.title[0..title_len], title[0..title_len]);
    t.title_len = title_len;

    const artist_len = @min(artist.len, t.artist.len);
    @memcpy(t.artist[0..artist_len], artist[0..artist_len]);
    t.artist_len = artist_len;

    const album_len = @min(album.len, t.album.len);
    @memcpy(t.album[0..album_len], album[0..album_len]);
    t.album_len = album_len;

    t.duration = duration;

    app_state.track_count += 1;
    return t.id;
}

fn addPlaylist(name: []const u8, track_count: u32) ?u32 {
    if (app_state.playlist_count >= max_playlists) return null;

    var p = &app_state.playlists[app_state.playlist_count];
    p.id = @intCast(app_state.playlist_count + 1);

    const name_len = @min(name.len, p.name.len);
    @memcpy(p.name[0..name_len], name[0..name_len]);
    p.name_len = name_len;

    p.track_count = track_count;

    app_state.playlist_count += 1;
    return p.id;
}

// Navigation
pub fn setScreen(screen: Screen) void {
    app_state.current_screen = screen;
}

// Playback controls
pub fn play() void {
    if (app_state.current_track != null) {
        app_state.play_state = .playing;
    } else if (app_state.track_count > 0) {
        app_state.current_track = 1;
        app_state.play_state = .playing;
    }
}

pub fn pause() void {
    if (app_state.play_state == .playing) {
        app_state.play_state = .paused;
    }
}

pub fn stop() void {
    app_state.play_state = .stopped;
    app_state.position = 0;
}

pub fn togglePlayPause() void {
    if (app_state.play_state == .playing) {
        pause();
    } else {
        play();
    }
}

pub fn nextTrack() void {
    if (app_state.current_track) |current| {
        if (current < app_state.track_count) {
            app_state.current_track = current + 1;
            app_state.position = 0;
        } else if (app_state.repeat == .all) {
            app_state.current_track = 1;
            app_state.position = 0;
        }
    }
}

pub fn prevTrack() void {
    if (app_state.current_track) |current| {
        if (current > 1) {
            app_state.current_track = current - 1;
            app_state.position = 0;
        } else if (app_state.repeat == .all) {
            app_state.current_track = @intCast(app_state.track_count);
            app_state.position = 0;
        }
    }
}

pub fn seek(position: f32) void {
    app_state.position = @max(0, @min(1, position));
}

pub fn setVolume(volume: f32) void {
    app_state.volume = @max(0, @min(1, volume));
}

pub fn toggleShuffle() void {
    app_state.shuffle = !app_state.shuffle;
}

pub fn cycleRepeat() void {
    app_state.repeat = switch (app_state.repeat) {
        .off => .all,
        .all => .one,
        .one => .off,
    };
}

pub fn selectTrack(id: u32) void {
    app_state.current_track = id;
    app_state.position = 0;
    app_state.play_state = .playing;
    app_state.current_screen = .now_playing;
}

pub fn selectPlaylist(id: ?u32) void {
    app_state.selected_playlist = id;
}

// Queries
pub fn getTrack(id: u32) ?*const Track {
    for (app_state.tracks[0..app_state.track_count]) |*t| {
        if (t.id == id) return t;
    }
    return null;
}

pub fn getCurrentTrack() ?*const Track {
    if (app_state.current_track) |id| {
        return getTrack(id);
    }
    return null;
}

pub fn formatDuration(seconds: u32) struct { min: u32, sec: u32 } {
    return .{ .min = seconds / 60, .sec = seconds % 60 };
}

// Tests
test "state init" {
    init();
    defer deinit();
    try std.testing.expect(app_state.initialized);
    try std.testing.expect(app_state.track_count > 0);
}

test "playback" {
    init();
    defer deinit();
    play();
    try std.testing.expectEqual(PlayState.playing, app_state.play_state);
    pause();
    try std.testing.expectEqual(PlayState.paused, app_state.play_state);
}

test "track navigation" {
    init();
    defer deinit();
    selectTrack(1);
    try std.testing.expectEqual(@as(?u32, 1), app_state.current_track);
    nextTrack();
    try std.testing.expectEqual(@as(?u32, 2), app_state.current_track);
    prevTrack();
    try std.testing.expectEqual(@as(?u32, 1), app_state.current_track);
}

test "volume" {
    init();
    defer deinit();
    setVolume(0.5);
    try std.testing.expectEqual(@as(f32, 0.5), app_state.volume);
}

test "seek" {
    init();
    defer deinit();
    seek(0.75);
    try std.testing.expectEqual(@as(f32, 0.75), app_state.position);
}
