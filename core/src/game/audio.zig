//! Audio System - Sound effects and background music
//!
//! Provides comprehensive audio playback including sound effects,
//! background music, positional audio, and audio control features.

const std = @import("std");
const sprite = @import("sprite.zig");

const Vec2 = sprite.Vec2;

/// Audio format
pub const AudioFormat = enum(u8) {
    mp3 = 0,
    ogg = 1,
    wav = 2,
    aac = 3,
    flac = 4,
};

/// Audio state
pub const AudioState = enum(u8) {
    stopped = 0,
    playing = 1,
    paused = 2,
    loading = 3,
};

/// Audio channel category
pub const AudioCategory = enum(u8) {
    master = 0,
    music = 1,
    sfx = 2,
    voice = 3,
    ambient = 4,
    ui = 5,
};

/// Audio source handle
pub const AudioSourceId = u32;

/// Sound effect - short audio clips
pub const SoundEffect = struct {
    id: AudioSourceId = 0,
    name: []const u8 = "",
    data: ?[]const u8 = null, // Raw audio data
    format: AudioFormat = .wav,
    sample_rate: u32 = 44100,
    channels: u8 = 2,
    duration: f32 = 0, // seconds
    loaded: bool = false,

    // Playback settings
    volume: f32 = 1.0,
    pitch: f32 = 1.0,
    pan: f32 = 0.0, // -1 (left) to 1 (right)
    loop: bool = false,
    category: AudioCategory = .sfx,
};

/// Music track - streaming audio for background music
pub const MusicTrack = struct {
    id: AudioSourceId = 0,
    name: []const u8 = "",
    path: []const u8 = "", // File path for streaming
    format: AudioFormat = .mp3,
    duration: f32 = 0,
    state: AudioState = .stopped,

    // Playback settings
    volume: f32 = 1.0,
    loop: bool = true,
    fade_duration: f32 = 1.0, // Crossfade duration
    category: AudioCategory = .music,

    // Current state
    position: f32 = 0, // Current playback position
    target_volume: f32 = 1.0, // For fading
};

/// Audio instance - playing sound instance
pub const AudioInstance = struct {
    id: u32 = 0,
    source_id: AudioSourceId = 0,
    state: AudioState = .stopped,
    volume: f32 = 1.0,
    pitch: f32 = 1.0,
    pan: f32 = 0.0,
    loop: bool = false,
    position: f32 = 0, // playback position
    category: AudioCategory = .sfx,

    // 2D positional audio
    world_position: ?Vec2 = null,
    min_distance: f32 = 100,
    max_distance: f32 = 1000,
    rolloff: f32 = 1.0,

    // Fade
    fade_target: f32 = 1.0,
    fade_speed: f32 = 0,
};

/// Listener for positional audio
pub const AudioListener = struct {
    position: Vec2 = .{},
    velocity: Vec2 = .{},
    orientation: f32 = 0, // radians

    pub fn calculatePan(self: *const AudioListener, source_position: Vec2) f32 {
        const delta = source_position.sub(self.position);
        const angle = std.math.atan2(delta.y, delta.x) - self.orientation;
        return @sin(angle);
    }

    pub fn calculateVolume(self: *const AudioListener, source: *const AudioInstance) f32 {
        if (source.world_position == null) return source.volume;

        const dist = source.world_position.?.sub(self.position).length();

        if (dist <= source.min_distance) return source.volume;
        if (dist >= source.max_distance) return 0;

        const range = source.max_distance - source.min_distance;
        const factor = (source.max_distance - dist) / range;

        return source.volume * std.math.pow(f32, factor, source.rolloff);
    }
};

/// Audio player - main audio management
pub const AudioPlayer = struct {
    allocator: std.mem.Allocator,

    // Sources
    sound_effects: std.ArrayListUnmanaged(SoundEffect) = .{},
    music_tracks: std.ArrayListUnmanaged(MusicTrack) = .{},
    instances: std.ArrayListUnmanaged(AudioInstance) = .{},
    next_source_id: AudioSourceId = 1,
    next_instance_id: u32 = 1,

    // Volume controls
    master_volume: f32 = 1.0,
    music_volume: f32 = 1.0,
    sfx_volume: f32 = 1.0,
    voice_volume: f32 = 1.0,
    ambient_volume: f32 = 1.0,
    ui_volume: f32 = 1.0,
    muted: bool = false,

    // Listener for positional audio
    listener: AudioListener = .{},

    // Current music
    current_music: ?*MusicTrack = null,
    next_music: ?*MusicTrack = null,
    crossfade_progress: f32 = 0,

    // Instance limit
    max_instances: usize = 32,

    // Platform backend (placeholder for platform-specific implementation)
    backend: ?*anyopaque = null,

    pub fn init(allocator: std.mem.Allocator) AudioPlayer {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *AudioPlayer) void {
        self.sound_effects.deinit(self.allocator);
        self.music_tracks.deinit(self.allocator);
        self.instances.deinit(self.allocator);
    }

    /// Load a sound effect
    pub fn loadSound(self: *AudioPlayer, name: []const u8, data: []const u8, format: AudioFormat) !*SoundEffect {
        var sfx = SoundEffect{
            .id = self.next_source_id,
            .name = name,
            .data = data,
            .format = format,
            .loaded = true,
        };
        self.next_source_id += 1;

        try self.sound_effects.append(self.allocator, sfx);
        return &self.sound_effects.items[self.sound_effects.items.len - 1];
    }

    /// Load a music track (streaming)
    pub fn loadMusic(self: *AudioPlayer, name: []const u8, path: []const u8, format: AudioFormat) !*MusicTrack {
        var track = MusicTrack{
            .id = self.next_source_id,
            .name = name,
            .path = path,
            .format = format,
        };
        self.next_source_id += 1;

        try self.music_tracks.append(self.allocator, track);
        return &self.music_tracks.items[self.music_tracks.items.len - 1];
    }

    /// Play a sound effect
    pub fn playSound(self: *AudioPlayer, sfx: *const SoundEffect) !*AudioInstance {
        return self.playSoundEx(sfx, .{
            .volume = sfx.volume,
            .pitch = sfx.pitch,
            .pan = sfx.pan,
            .loop = sfx.loop,
        });
    }

    /// Play a sound effect with options
    pub fn playSoundEx(self: *AudioPlayer, sfx: *const SoundEffect, options: struct {
        volume: f32 = 1.0,
        pitch: f32 = 1.0,
        pan: f32 = 0.0,
        loop: bool = false,
        position: ?Vec2 = null,
    }) !*AudioInstance {
        // Limit instances
        if (self.instances.items.len >= self.max_instances) {
            // Remove oldest non-looping instance
            for (self.instances.items, 0..) |inst, i| {
                if (!inst.loop and inst.state == .playing) {
                    _ = self.instances.swapRemove(i);
                    break;
                }
            }
        }

        var instance = AudioInstance{
            .id = self.next_instance_id,
            .source_id = sfx.id,
            .state = .playing,
            .volume = options.volume,
            .pitch = options.pitch,
            .pan = options.pan,
            .loop = options.loop,
            .category = sfx.category,
            .world_position = options.position,
        };
        self.next_instance_id += 1;

        try self.instances.append(self.allocator, instance);
        return &self.instances.items[self.instances.items.len - 1];
    }

    /// Play background music
    pub fn playMusic(self: *AudioPlayer, track: *MusicTrack) void {
        self.playMusicEx(track, .{});
    }

    /// Play background music with crossfade
    pub fn playMusicEx(self: *AudioPlayer, track: *MusicTrack, options: struct {
        fade_in: f32 = 0,
        loop: bool = true,
        restart: bool = false,
    }) void {
        // Store the intended final volume before modifying track.volume
        const final_volume: f32 = 1.0;

        if (self.current_music) |current| {
            if (current == track and !options.restart) return;

            // Start crossfade
            self.next_music = track;
            self.crossfade_progress = 0;
            track.volume = 0;
            track.target_volume = final_volume; // Target is what we fade TO, not FROM
        } else {
            self.current_music = track;
            if (options.fade_in > 0) {
                track.volume = 0;
                track.target_volume = final_volume; // Target is what we fade TO, not FROM
            }
        }

        track.state = .playing;
        track.loop = options.loop;
        if (options.restart) {
            track.position = 0;
        }
    }

    /// Stop music
    pub fn stopMusic(self: *AudioPlayer, fade_out: f32) void {
        if (self.current_music) |track| {
            if (fade_out > 0) {
                track.target_volume = 0;
            } else {
                track.state = .stopped;
                track.position = 0;
                self.current_music = null;
            }
        }
    }

    /// Pause music
    pub fn pauseMusic(self: *AudioPlayer) void {
        if (self.current_music) |track| {
            track.state = .paused;
        }
    }

    /// Resume music
    pub fn resumeMusic(self: *AudioPlayer) void {
        if (self.current_music) |track| {
            if (track.state == .paused) {
                track.state = .playing;
            }
        }
    }

    /// Stop a specific sound instance
    pub fn stopInstance(self: *AudioPlayer, instance: *AudioInstance) void {
        instance.state = .stopped;
    }

    /// Stop all sounds
    pub fn stopAll(self: *AudioPlayer) void {
        for (self.instances.items) |*inst| {
            inst.state = .stopped;
        }
        self.stopMusic(0);
    }

    /// Pause all sounds
    pub fn pauseAll(self: *AudioPlayer) void {
        for (self.instances.items) |*inst| {
            if (inst.state == .playing) {
                inst.state = .paused;
            }
        }
        self.pauseMusic();
    }

    /// Resume all sounds
    pub fn resumeAll(self: *AudioPlayer) void {
        for (self.instances.items) |*inst| {
            if (inst.state == .paused) {
                inst.state = .playing;
            }
        }
        self.resumeMusic();
    }

    /// Set master volume
    pub fn setMasterVolume(self: *AudioPlayer, volume: f32) void {
        self.master_volume = std.math.clamp(volume, 0, 1);
    }

    /// Set category volume
    pub fn setCategoryVolume(self: *AudioPlayer, category: AudioCategory, volume: f32) void {
        const clamped = std.math.clamp(volume, 0, 1);
        switch (category) {
            .master => self.master_volume = clamped,
            .music => self.music_volume = clamped,
            .sfx => self.sfx_volume = clamped,
            .voice => self.voice_volume = clamped,
            .ambient => self.ambient_volume = clamped,
            .ui => self.ui_volume = clamped,
        }
    }

    /// Get category volume
    pub fn getCategoryVolume(self: *const AudioPlayer, category: AudioCategory) f32 {
        return switch (category) {
            .master => self.master_volume,
            .music => self.music_volume,
            .sfx => self.sfx_volume,
            .voice => self.voice_volume,
            .ambient => self.ambient_volume,
            .ui => self.ui_volume,
        };
    }

    /// Mute/unmute all audio
    pub fn setMuted(self: *AudioPlayer, muted: bool) void {
        self.muted = muted;
    }

    /// Toggle mute
    pub fn toggleMute(self: *AudioPlayer) void {
        self.muted = !self.muted;
    }

    /// Calculate effective volume for an instance
    pub fn getEffectiveVolume(self: *const AudioPlayer, instance: *const AudioInstance) f32 {
        if (self.muted) return 0;

        var vol = instance.volume * self.master_volume;
        vol *= self.getCategoryVolume(instance.category);

        // Apply positional attenuation
        if (instance.world_position != null) {
            vol *= self.listener.calculateVolume(instance);
        }

        return vol;
    }

    /// Update audio system (call each frame)
    pub fn update(self: *AudioPlayer, delta_time: f32) void {
        // Update crossfade
        if (self.next_music) |next| {
            if (self.current_music) |current| {
                self.crossfade_progress += delta_time / current.fade_duration;

                if (self.crossfade_progress >= 1.0) {
                    current.state = .stopped;
                    current.position = 0;
                    self.current_music = next;
                    self.next_music = null;
                    next.volume = next.target_volume;
                } else {
                    current.volume = current.target_volume * (1.0 - self.crossfade_progress);
                    next.volume = next.target_volume * self.crossfade_progress;
                }
            }
        }

        // Update music fade
        if (self.current_music) |track| {
            if (track.volume != track.target_volume) {
                const diff = track.target_volume - track.volume;
                const step = delta_time / track.fade_duration;

                if (@abs(diff) < step) {
                    track.volume = track.target_volume;
                    if (track.target_volume == 0) {
                        track.state = .stopped;
                        track.position = 0;
                        self.current_music = null;
                    }
                } else {
                    track.volume += if (diff > 0) step else -step;
                }
            }

            // Update position
            if (track.state == .playing) {
                track.position += delta_time;
                if (track.position >= track.duration) {
                    if (track.loop) {
                        track.position = 0;
                    } else {
                        track.state = .stopped;
                        self.current_music = null;
                    }
                }
            }
        }

        // Update instance fades
        for (self.instances.items) |*inst| {
            if (inst.fade_speed != 0) {
                inst.volume += inst.fade_speed * delta_time;
                if ((inst.fade_speed > 0 and inst.volume >= inst.fade_target) or
                    (inst.fade_speed < 0 and inst.volume <= inst.fade_target))
                {
                    inst.volume = inst.fade_target;
                    inst.fade_speed = 0;
                    if (inst.volume == 0) {
                        inst.state = .stopped;
                    }
                }
            }
        }

        // Remove stopped instances
        var i: usize = 0;
        while (i < self.instances.items.len) {
            if (self.instances.items[i].state == .stopped) {
                _ = self.instances.swapRemove(i);
            } else {
                i += 1;
            }
        }
    }

    /// Find sound effect by name
    pub fn findSound(self: *const AudioPlayer, name: []const u8) ?*const SoundEffect {
        for (self.sound_effects.items) |*sfx| {
            if (std.mem.eql(u8, sfx.name, name)) {
                return sfx;
            }
        }
        return null;
    }

    /// Find music track by name
    pub fn findMusic(self: *const AudioPlayer, name: []const u8) ?*MusicTrack {
        for (self.music_tracks.items) |*track| {
            if (std.mem.eql(u8, track.name, name)) {
                return track;
            }
        }
        return null;
    }

    /// Get number of playing instances
    pub fn getPlayingCount(self: *const AudioPlayer) usize {
        var count: usize = 0;
        for (self.instances.items) |inst| {
            if (inst.state == .playing) count += 1;
        }
        return count;
    }
};

/// Playlist for sequential music playback
pub const Playlist = struct {
    allocator: std.mem.Allocator,
    tracks: std.ArrayListUnmanaged(*MusicTrack) = .{},
    current_index: usize = 0,
    shuffle: bool = false,
    repeat_mode: enum { none, one, all } = .all,
    rng: std.rand.DefaultPrng, // Persistent RNG for shuffle

    pub fn init(allocator: std.mem.Allocator) Playlist {
        return .{
            .allocator = allocator,
            .rng = std.rand.DefaultPrng.init(@intCast(std.time.timestamp())),
        };
    }

    pub fn deinit(self: *Playlist) void {
        self.tracks.deinit(self.allocator);
    }

    pub fn add(self: *Playlist, track: *MusicTrack) !void {
        try self.tracks.append(self.allocator, track);
    }

    pub fn current(self: *const Playlist) ?*MusicTrack {
        if (self.tracks.items.len == 0) return null;
        return self.tracks.items[self.current_index];
    }

    pub fn next(self: *Playlist) ?*MusicTrack {
        if (self.tracks.items.len == 0) return null;

        if (self.shuffle) {
            // Use persistent RNG for proper shuffle randomness
            self.current_index = self.rng.random().intRangeLessThan(usize, 0, self.tracks.items.len);
        } else {
            self.current_index = (self.current_index + 1) % self.tracks.items.len;
        }

        return self.tracks.items[self.current_index];
    }

    pub fn previous(self: *Playlist) ?*MusicTrack {
        if (self.tracks.items.len == 0) return null;

        if (self.current_index == 0) {
            self.current_index = self.tracks.items.len - 1;
        } else {
            self.current_index -= 1;
        }

        return self.tracks.items[self.current_index];
    }

    pub fn clear(self: *Playlist) void {
        self.tracks.clearRetainingCapacity();
        self.current_index = 0;
    }
};

test "AudioPlayer basic" {
    const allocator = std.testing.allocator;
    var player = AudioPlayer.init(allocator);
    defer player.deinit();

    player.setMasterVolume(0.8);
    try std.testing.expectEqual(@as(f32, 0.8), player.master_volume);

    player.setMuted(true);
    try std.testing.expect(player.muted);
}

test "SoundEffect creation" {
    const allocator = std.testing.allocator;
    var player = AudioPlayer.init(allocator);
    defer player.deinit();

    const data = [_]u8{ 0, 1, 2, 3 };
    const sfx = try player.loadSound("test", &data, .wav);

    try std.testing.expectEqual(@as(u32, 1), sfx.id);
    try std.testing.expect(sfx.loaded);
}

test "MusicTrack creation" {
    const allocator = std.testing.allocator;
    var player = AudioPlayer.init(allocator);
    defer player.deinit();

    const track = try player.loadMusic("bgm", "/music/track1.mp3", .mp3);

    try std.testing.expectEqual(@as(u32, 1), track.id);
    try std.testing.expect(std.mem.eql(u8, track.name, "bgm"));
}

test "AudioListener positional" {
    var listener = AudioListener{};
    listener.position = .{ .x = 0, .y = 0 };

    var instance = AudioInstance{
        .volume = 1.0,
        .world_position = .{ .x = 100, .y = 0 },
        .min_distance = 50,
        .max_distance = 200,
    };

    const vol = listener.calculateVolume(&instance);
    try std.testing.expect(vol > 0 and vol < 1.0);
}

test "Playlist basic" {
    const allocator = std.testing.allocator;
    var playlist = Playlist.init(allocator);
    defer playlist.deinit();

    var track1 = MusicTrack{ .id = 1, .name = "track1" };
    var track2 = MusicTrack{ .id = 2, .name = "track2" };

    try playlist.add(&track1);
    try playlist.add(&track2);

    try std.testing.expectEqual(@as(usize, 2), playlist.tracks.items.len);

    const current = playlist.current();
    try std.testing.expect(current != null);
    try std.testing.expectEqual(@as(u32, 1), current.?.id);
}
