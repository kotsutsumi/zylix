//! Low-Latency Audio Clip Player Module
//!
//! Short audio clip playback with minimal latency:
//! - Preloading support for instant playback
//! - Volume control per clip
//! - Multiple simultaneous playback
//! - Spatial audio support
//!
//! Platform implementations:
//! - iOS: AVAudioEngine
//! - Android: AudioTrack/Oboe
//! - Web: Web Audio API
//! - Desktop: miniaudio
//!
//! IMPORTANT: String lifetimes
//! - clip.id strings are stored by reference, not copied.
//! - Callers must ensure AudioClip.id strings outlive their use in the player.
//! - For long-lived clips, use string literals or allocator-owned strings.

const std = @import("std");

/// Audio clip error types
pub const AudioClipError = error{
    NotAvailable,
    NotInitialized,
    ClipNotFound,
    LoadFailed,
    DecodeFailed,
    PlaybackFailed,
    InvalidFormat,
    TooManyVoices,
    OutOfMemory,
};

/// Audio format
pub const AudioFormat = enum(u8) {
    wav = 0,
    mp3 = 1,
    ogg = 2,
    flac = 3,
    aac = 4,
    opus = 5,
    raw_pcm = 255,
};

/// Sample format
pub const SampleFormat = enum(u8) {
    u8 = 0,
    s16 = 1,
    s24 = 2,
    s32 = 3,
    f32 = 4,
};

/// Audio clip definition
pub const AudioClip = struct {
    /// Unique clip identifier
    id: []const u8,
    /// Path to audio file
    path: ?[]const u8 = null,
    /// Raw audio data (alternative to path)
    data: ?[]const u8 = null,
    /// Audio format (for raw data)
    format: AudioFormat = .wav,
    /// Sample rate (for raw PCM)
    sample_rate: u32 = 44100,
    /// Number of channels (for raw PCM)
    channels: u8 = 2,
    /// Sample format (for raw PCM)
    sample_format: SampleFormat = .s16,
    /// Whether to loop playback
    loop: bool = false,
    /// Default volume (0.0-1.0)
    default_volume: f32 = 1.0,
    /// Priority for voice stealing
    priority: u8 = 128,
};

/// Loaded clip info
pub const LoadedClip = struct {
    id: []const u8,
    duration_ms: u32,
    sample_rate: u32,
    channels: u8,
    sample_format: SampleFormat,
    size_bytes: usize,
    loaded: bool = false,
};

/// Playback state
pub const PlaybackState = enum(u8) {
    stopped = 0,
    playing = 1,
    paused = 2,
    finished = 3,
};

/// Voice handle for controlling active playback
pub const VoiceHandle = struct {
    id: u64,
    clip_id: []const u8,
    state: PlaybackState = .stopped,

    pub fn isPlaying(self: *const VoiceHandle) bool {
        return self.state == .playing;
    }
};

/// Spatial audio position
pub const SpatialPosition = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,

    pub fn distanceTo(self: SpatialPosition, other: SpatialPosition) f32 {
        const dx = self.x - other.x;
        const dy = self.y - other.y;
        const dz = self.z - other.z;
        return @sqrt(dx * dx + dy * dy + dz * dz);
    }
};

/// Audio clip player configuration
pub const AudioClipConfig = struct {
    /// Maximum simultaneous voices
    max_voices: u8 = 32,
    /// Enable spatial audio
    spatial_audio: bool = false,
    /// Listener position (for spatial audio)
    listener_position: SpatialPosition = .{},
    /// Master volume (0.0-1.0)
    master_volume: f32 = 1.0,
    /// Enable low-latency mode
    low_latency: bool = true,
    /// Buffer size in samples (lower = less latency, more CPU)
    buffer_size: u32 = 256,
    /// Sample rate for output
    output_sample_rate: u32 = 44100,
    /// Enable debug logging
    debug: bool = false,
};

/// Future result wrapper for async operations
pub fn Future(comptime T: type) type {
    return struct {
        const Self = @This();

        result: ?T = null,
        err: ?AudioClipError = null,
        completed: bool = false,
        callback: ?*const fn (?T, ?AudioClipError) void = null,

        pub fn init() Self {
            return .{};
        }

        pub fn complete(self: *Self, value: T) void {
            self.result = value;
            self.completed = true;
            if (self.callback) |cb| {
                cb(value, null);
            }
        }

        pub fn fail(self: *Self, err: AudioClipError) void {
            self.err = err;
            self.completed = true;
            if (self.callback) |cb| {
                cb(null, err);
            }
        }

        pub fn isCompleted(self: *const Self) bool {
            return self.completed;
        }

        pub fn get(self: *const Self) AudioClipError!T {
            if (self.err) |e| return e;
            if (self.result) |r| return r;
            return AudioClipError.NotInitialized;
        }

        pub fn onComplete(self: *Self, callback: *const fn (?T, ?AudioClipError) void) void {
            self.callback = callback;
            if (self.completed) {
                callback(self.result, self.err);
            }
        }
    };
}

/// Voice info for active playback
const ActiveVoice = struct {
    handle: u64,
    clip_id: []const u8,
    state: PlaybackState,
    volume: f32,
    pan: f32,
    position: SpatialPosition,
    playback_position: u64, // Sample position
    created_at: i64,
};

/// Audio Clip Player
pub const AudioClipPlayer = struct {
    allocator: std.mem.Allocator,
    config: AudioClipConfig,
    initialized: bool = false,
    loaded_clips: std.StringHashMapUnmanaged(LoadedClip) = .{},
    active_voices: std.ArrayListUnmanaged(ActiveVoice) = .{},
    next_voice_id: u64 = 1,
    muted: bool = false,

    // Platform-specific handle
    platform_handle: ?*anyopaque = null,

    pub fn init(allocator: std.mem.Allocator, config: AudioClipConfig) AudioClipPlayer {
        return .{
            .allocator = allocator,
            .config = config,
        };
    }

    pub fn deinit(self: *AudioClipPlayer) void {
        self.stopAll();
        self.unloadAll();
        self.loaded_clips.deinit(self.allocator);
        self.active_voices.deinit(self.allocator);
        self.initialized = false;
    }

    /// Initialize the audio system
    pub fn initialize(self: *AudioClipPlayer) *Future(void) {
        const future = self.allocator.create(Future(void)) catch {
            const err_future = self.allocator.create(Future(void)) catch unreachable;
            err_future.* = Future(void).init();
            err_future.fail(AudioClipError.OutOfMemory);
            return err_future;
        };
        future.* = Future(void).init();

        // Platform-specific audio initialization would happen here
        self.initialized = true;
        future.complete({});

        return future;
    }

    /// Preload audio clips for instant playback
    pub fn preload(self: *AudioClipPlayer, clips: []const AudioClip) *Future(void) {
        const future = self.allocator.create(Future(void)) catch {
            const err_future = self.allocator.create(Future(void)) catch unreachable;
            err_future.* = Future(void).init();
            err_future.fail(AudioClipError.OutOfMemory);
            return err_future;
        };
        future.* = Future(void).init();

        if (!self.initialized) {
            future.fail(AudioClipError.NotInitialized);
            return future;
        }

        // Load each clip
        for (clips) |clip| {
            const loaded = LoadedClip{
                .id = clip.id,
                .duration_ms = 0, // Would be calculated from actual audio
                .sample_rate = clip.sample_rate,
                .channels = clip.channels,
                .sample_format = clip.sample_format,
                .size_bytes = if (clip.data) |d| d.len else 0,
                .loaded = true,
            };
            self.loaded_clips.put(self.allocator, clip.id, loaded) catch {
                future.fail(AudioClipError.OutOfMemory);
                return future;
            };
        }

        future.complete({});
        return future;
    }

    /// Load a single clip
    pub fn load(self: *AudioClipPlayer, clip: AudioClip) *Future(LoadedClip) {
        const future = self.allocator.create(Future(LoadedClip)) catch {
            const err_future = self.allocator.create(Future(LoadedClip)) catch unreachable;
            err_future.* = Future(LoadedClip).init();
            err_future.fail(AudioClipError.OutOfMemory);
            return err_future;
        };
        future.* = Future(LoadedClip).init();

        if (!self.initialized) {
            future.fail(AudioClipError.NotInitialized);
            return future;
        }

        // Platform-specific audio loading would happen here
        const loaded = LoadedClip{
            .id = clip.id,
            .duration_ms = 0,
            .sample_rate = clip.sample_rate,
            .channels = clip.channels,
            .sample_format = clip.sample_format,
            .size_bytes = if (clip.data) |d| d.len else 0,
            .loaded = true,
        };

        self.loaded_clips.put(self.allocator, clip.id, loaded) catch {
            future.fail(AudioClipError.OutOfMemory);
            return future;
        };

        future.complete(loaded);
        return future;
    }

    /// Unload a clip
    pub fn unload(self: *AudioClipPlayer, clip_id: []const u8) void {
        // Stop any active playback of this clip
        self.stop(clip_id);

        // Remove from loaded clips
        _ = self.loaded_clips.remove(clip_id);
    }

    /// Unload all clips
    pub fn unloadAll(self: *AudioClipPlayer) void {
        self.stopAll();
        self.loaded_clips.clearRetainingCapacity();
    }

    /// Check if a clip is loaded
    pub fn isLoaded(self: *const AudioClipPlayer, clip_id: []const u8) bool {
        if (self.loaded_clips.get(clip_id)) |clip| {
            return clip.loaded;
        }
        return false;
    }

    /// Play a clip with default settings
    pub fn play(self: *AudioClipPlayer, clip_id: []const u8, volume: f32) VoiceHandle {
        return self.playAdvanced(clip_id, .{
            .volume = volume,
        });
    }

    /// Advanced play options
    pub const PlayOptions = struct {
        volume: f32 = 1.0,
        pan: f32 = 0.0, // -1.0 (left) to 1.0 (right)
        pitch: f32 = 1.0,
        loop: bool = false,
        position: SpatialPosition = .{},
        start_time_ms: u32 = 0,
    };

    /// Play with advanced options
    pub fn playAdvanced(self: *AudioClipPlayer, clip_id: []const u8, options: PlayOptions) VoiceHandle {
        if (!self.initialized or self.muted) {
            return .{ .id = 0, .clip_id = clip_id, .state = .stopped };
        }

        if (!self.isLoaded(clip_id)) {
            return .{ .id = 0, .clip_id = clip_id, .state = .stopped };
        }

        // Check voice limit
        if (self.active_voices.items.len >= self.config.max_voices) {
            // Voice stealing would happen here based on priority
            return .{ .id = 0, .clip_id = clip_id, .state = .stopped };
        }

        const voice_id = self.next_voice_id;
        self.next_voice_id += 1;

        const voice = ActiveVoice{
            .handle = voice_id,
            .clip_id = clip_id,
            .state = .playing,
            .volume = options.volume * self.config.master_volume,
            .pan = options.pan,
            .position = options.position,
            .playback_position = 0,
            .created_at = std.time.milliTimestamp(),
        };

        self.active_voices.append(self.allocator, voice) catch {
            return .{ .id = 0, .clip_id = clip_id, .state = .stopped };
        };

        // Platform-specific playback start would happen here

        return .{ .id = voice_id, .clip_id = clip_id, .state = .playing };
    }

    /// Stop playback of a clip (all instances)
    pub fn stop(self: *AudioClipPlayer, clip_id: []const u8) void {
        var i: usize = 0;
        while (i < self.active_voices.items.len) {
            if (std.mem.eql(u8, self.active_voices.items[i].clip_id, clip_id)) {
                _ = self.active_voices.swapRemove(i);
            } else {
                i += 1;
            }
        }
    }

    /// Stop a specific voice
    pub fn stopVoice(self: *AudioClipPlayer, handle: VoiceHandle) void {
        for (self.active_voices.items, 0..) |voice, i| {
            if (voice.handle == handle.id) {
                _ = self.active_voices.swapRemove(i);
                break;
            }
        }
    }

    /// Stop all playback
    pub fn stopAll(self: *AudioClipPlayer) void {
        self.active_voices.clearRetainingCapacity();
    }

    /// Pause a specific voice
    pub fn pauseVoice(self: *AudioClipPlayer, handle: VoiceHandle) void {
        for (self.active_voices.items) |*voice| {
            if (voice.handle == handle.id) {
                voice.state = .paused;
                break;
            }
        }
    }

    /// Resume a specific voice
    pub fn resumeVoice(self: *AudioClipPlayer, handle: VoiceHandle) void {
        for (self.active_voices.items) |*voice| {
            if (voice.handle == handle.id and voice.state == .paused) {
                voice.state = .playing;
                break;
            }
        }
    }

    /// Set volume for a specific voice
    pub fn setVoiceVolume(self: *AudioClipPlayer, handle: VoiceHandle, volume: f32) void {
        for (self.active_voices.items) |*voice| {
            if (voice.handle == handle.id) {
                voice.volume = @max(0.0, @min(1.0, volume)) * self.config.master_volume;
                break;
            }
        }
    }

    /// Set master volume
    pub fn setMasterVolume(self: *AudioClipPlayer, volume: f32) void {
        self.config.master_volume = @max(0.0, @min(1.0, volume));
    }

    /// Get master volume
    pub fn getMasterVolume(self: *const AudioClipPlayer) f32 {
        return self.config.master_volume;
    }

    /// Mute/unmute all audio
    pub fn setMuted(self: *AudioClipPlayer, muted: bool) void {
        self.muted = muted;
        if (muted) {
            // Platform-specific mute
        }
    }

    /// Check if muted
    pub fn isMuted(self: *const AudioClipPlayer) bool {
        return self.muted;
    }

    /// Get number of active voices
    pub fn getActiveVoiceCount(self: *const AudioClipPlayer) usize {
        return self.active_voices.items.len;
    }

    /// Update listener position (for spatial audio)
    pub fn setListenerPosition(self: *AudioClipPlayer, position: SpatialPosition) void {
        self.config.listener_position = position;
    }

    /// Check if audio clip player is available
    pub fn isAvailable() bool {
        // Platform detection would happen here
        return false;
    }
};

/// Convenience function to create a player
pub fn createPlayer(allocator: std.mem.Allocator, config: AudioClipConfig) AudioClipPlayer {
    return AudioClipPlayer.init(allocator, config);
}

/// Convenience function with default config
pub fn createDefaultPlayer(allocator: std.mem.Allocator) AudioClipPlayer {
    return AudioClipPlayer.init(allocator, .{});
}

// Tests
test "AudioClipPlayer initialization" {
    const allocator = std.testing.allocator;
    var player = createDefaultPlayer(allocator);
    defer player.deinit();

    const future = player.initialize();
    try std.testing.expect(future.isCompleted());
    try std.testing.expect(player.initialized);
}

test "Clip loading" {
    const allocator = std.testing.allocator;
    var player = createDefaultPlayer(allocator);
    defer player.deinit();

    _ = player.initialize();

    const clips = [_]AudioClip{
        .{ .id = "click", .data = "dummy" },
        .{ .id = "beep", .data = "dummy" },
    };

    const future = player.preload(&clips);
    try std.testing.expect(future.isCompleted());

    try std.testing.expect(player.isLoaded("click"));
    try std.testing.expect(player.isLoaded("beep"));
    try std.testing.expect(!player.isLoaded("unknown"));
}

test "Playback control" {
    const allocator = std.testing.allocator;
    var player = createDefaultPlayer(allocator);
    defer player.deinit();

    _ = player.initialize();

    const clips = [_]AudioClip{.{ .id = "test", .data = "dummy" }};
    _ = player.preload(&clips);

    const handle = player.play("test", 0.5);
    try std.testing.expect(handle.id > 0);
    try std.testing.expectEqual(@as(usize, 1), player.getActiveVoiceCount());

    player.stopVoice(handle);
    try std.testing.expectEqual(@as(usize, 0), player.getActiveVoiceCount());
}

test "Volume control" {
    const allocator = std.testing.allocator;
    var player = createDefaultPlayer(allocator);
    defer player.deinit();

    _ = player.initialize();

    try std.testing.expectApproxEqAbs(@as(f32, 1.0), player.getMasterVolume(), 0.001);

    player.setMasterVolume(0.5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), player.getMasterVolume(), 0.001);

    // Clamping test
    player.setMasterVolume(1.5);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), player.getMasterVolume(), 0.001);

    player.setMasterVolume(-0.5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), player.getMasterVolume(), 0.001);
}

test "Mute control" {
    const allocator = std.testing.allocator;
    var player = createDefaultPlayer(allocator);
    defer player.deinit();

    try std.testing.expect(!player.isMuted());

    player.setMuted(true);
    try std.testing.expect(player.isMuted());

    player.setMuted(false);
    try std.testing.expect(!player.isMuted());
}

test "SpatialPosition distance" {
    const p1 = SpatialPosition{ .x = 0, .y = 0, .z = 0 };
    const p2 = SpatialPosition{ .x = 3, .y = 4, .z = 0 };

    try std.testing.expectApproxEqAbs(@as(f32, 5.0), p1.distanceTo(p2), 0.001);
}

test "Stop all" {
    const allocator = std.testing.allocator;
    var player = createDefaultPlayer(allocator);
    defer player.deinit();

    _ = player.initialize();

    const clips = [_]AudioClip{.{ .id = "test", .data = "dummy" }};
    _ = player.preload(&clips);

    _ = player.play("test", 1.0);
    _ = player.play("test", 1.0);
    _ = player.play("test", 1.0);

    try std.testing.expectEqual(@as(usize, 3), player.getActiveVoiceCount());

    player.stopAll();
    try std.testing.expectEqual(@as(usize, 0), player.getActiveVoiceCount());
}

test "Availability check" {
    try std.testing.expect(!AudioClipPlayer.isAvailable());
}
