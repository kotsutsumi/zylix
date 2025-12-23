//! Zylix Device - Audio Module
//!
//! Audio playback and recording for all platforms.
//! Supports background audio, audio session management, and recording.

const std = @import("std");
const types = @import("types.zig");

pub const Result = types.Result;
pub const Permission = types.Permission;
pub const PermissionStatus = types.PermissionStatus;

// === Audio Session ===

/// Audio session category
pub const SessionCategory = enum(u8) {
    ambient = 0, // Mixes with other audio, silenced by screen lock
    solo_ambient = 1, // Silences other audio, silenced by screen lock
    playback = 2, // For playing audio (background capable)
    record = 3, // For recording (silences other audio)
    play_and_record = 4, // For VoIP, voice chat
    multi_route = 5, // Multiple audio routes simultaneously
};

/// Audio session mode
pub const SessionMode = enum(u8) {
    default = 0,
    voice_chat = 1, // Optimized for voice chat
    video_chat = 2, // Optimized for video chat
    game_chat = 3, // For gaming with voice
    video_recording = 4, // For video recording
    measurement = 5, // For audio measurement apps
    movie_playback = 6, // For movie playback
    spoken_audio = 7, // For podcasts, audiobooks
};

/// Audio session options
pub const SessionOptions = struct {
    mix_with_others: bool = false,
    duck_others: bool = false, // Lower volume of other apps
    allow_bluetooth: bool = true,
    allow_bluetooth_a2dp: bool = true,
    allow_air_play: bool = true,
    default_to_speaker: bool = false,
    interrupt_spoken_audio: bool = false,
};

/// Audio session configuration
pub const AudioSession = struct {
    category: SessionCategory = .playback,
    mode: SessionMode = .default,
    options: SessionOptions = .{},
    is_active: bool = false,

    // Platform handle
    platform_handle: ?*anyopaque = null,

    const Self = @This();

    pub fn init() Self {
        return .{};
    }

    /// Set audio session category
    pub fn setCategory(self: *Self, category: SessionCategory, mode: SessionMode, options: SessionOptions) Result {
        self.category = category;
        self.mode = mode;
        self.options = options;
        // Platform-specific implementation
        return .ok;
    }

    /// Activate audio session
    pub fn activate(self: *Self) Result {
        self.is_active = true;
        // Platform-specific implementation
        return .ok;
    }

    /// Deactivate audio session
    pub fn deactivate(self: *Self) Result {
        self.is_active = false;
        // Platform-specific implementation
        return .ok;
    }

    /// Check if another app is playing audio
    pub fn isOtherAudioPlaying(_: *Self) bool {
        // Platform-specific implementation
        return false;
    }
};

// === Audio Player ===

/// Audio player state
pub const PlayerState = enum(u8) {
    idle = 0,
    loading = 1,
    ready = 2,
    playing = 3,
    paused = 4,
    stopped = 5,
    failed = 6,
};

/// Audio player configuration
pub const PlayerConfig = struct {
    volume: f32 = 1.0, // 0.0 - 1.0
    rate: f32 = 1.0, // Playback rate (0.5 - 2.0)
    pan: f32 = 0.0, // Stereo pan (-1.0 left, 1.0 right)
    loops: i32 = 0, // -1 = infinite, 0 = no loop, n = loop n times
    enable_rate_adjustment: bool = true,
    enable_time_pitch_algorithm: bool = true,
};

/// Audio player progress
pub const Progress = struct {
    current_time: f64, // seconds
    duration: f64, // seconds
    buffered_time: f64, // seconds (for streaming)

    pub fn percentage(self: Progress) f64 {
        if (self.duration <= 0) return 0;
        return (self.current_time / self.duration) * 100;
    }

    pub fn remaining(self: Progress) f64 {
        return @max(0, self.duration - self.current_time);
    }
};

/// Player event callback
pub const PlayerCallback = *const fn (event: PlayerEvent) void;

/// Player events
pub const PlayerEvent = union(enum) {
    state_changed: PlayerState,
    progress: Progress,
    finished: void,
    @"error": Result,
    buffering: f32, // 0.0 - 1.0
    metadata: Metadata,

    pub const Metadata = struct {
        title: types.StringBuffer(256) = types.StringBuffer(256).init(),
        artist: types.StringBuffer(256) = types.StringBuffer(256).init(),
        album: types.StringBuffer(256) = types.StringBuffer(256).init(),
        duration: f64 = 0,
        artwork_url: types.StringBuffer(512) = types.StringBuffer(512).init(),
    };
};

/// Audio player
pub const AudioPlayer = struct {
    state: PlayerState = .idle,
    config: PlayerConfig = .{},
    progress: Progress = .{ .current_time = 0, .duration = 0, .buffered_time = 0 },

    // Source
    source_url: types.StringBuffer(1024) = types.StringBuffer(1024).init(),
    is_streaming: bool = false,

    // Callbacks
    callback: ?PlayerCallback = null,

    // Platform handle
    platform_handle: ?*anyopaque = null,

    const Self = @This();

    pub fn init() Self {
        return .{};
    }

    pub fn deinit(self: *Self) void {
        self.stop();
        self.platform_handle = null;
    }

    /// Load audio from URL (local file or remote)
    pub fn load(self: *Self, url: []const u8) Result {
        self.source_url.set(url);
        self.state = .loading;
        self.is_streaming = std.mem.startsWith(u8, url, "http://") or
            std.mem.startsWith(u8, url, "https://");
        // Platform-specific implementation
        return .ok;
    }

    /// Play audio
    pub fn play(self: *Self) Result {
        if (self.state != .ready and self.state != .paused) {
            return .not_initialized;
        }
        self.state = .playing;
        // Platform-specific implementation
        return .ok;
    }

    /// Pause playback
    pub fn pause(self: *Self) Result {
        if (self.state != .playing) {
            return .not_initialized;
        }
        self.state = .paused;
        // Platform-specific implementation
        return .ok;
    }

    /// Stop playback
    pub fn stop(self: *Self) void {
        self.state = .stopped;
        self.progress.current_time = 0;
        // Platform-specific implementation
    }

    /// Seek to time
    pub fn seek(self: *Self, time: f64) Result {
        if (self.state == .idle) {
            return .not_initialized;
        }
        if (time < 0 or time > self.progress.duration) {
            return .invalid_arg;
        }
        self.progress.current_time = time;
        // Platform-specific implementation
        return .ok;
    }

    /// Set volume
    pub fn setVolume(self: *Self, volume: f32) Result {
        if (volume < 0 or volume > 1) {
            return .invalid_arg;
        }
        self.config.volume = volume;
        // Platform-specific implementation
        return .ok;
    }

    /// Set playback rate
    pub fn setRate(self: *Self, rate: f32) Result {
        if (rate < 0.5 or rate > 2.0) {
            return .invalid_arg;
        }
        self.config.rate = rate;
        // Platform-specific implementation
        return .ok;
    }

    /// Set callback
    pub fn setCallback(self: *Self, callback: ?PlayerCallback) void {
        self.callback = callback;
    }

    // === Internal callbacks ===

    pub fn onEvent(self: *Self, event: PlayerEvent) void {
        switch (event) {
            .state_changed => |s| self.state = s,
            .progress => |p| self.progress = p,
            else => {},
        }
        if (self.callback) |cb| cb(event);
    }
};

// === Audio Recorder ===

/// Audio format for recording
pub const RecordingFormat = enum(u8) {
    aac = 0, // AAC (recommended)
    wav = 1, // Uncompressed WAV
    mp3 = 2, // MP3 (not available on all platforms)
    m4a = 3, // MPEG-4 Audio
    opus = 4, // Opus
};

/// Recording quality
pub const RecordingQuality = enum(u8) {
    low = 0, // Voice quality
    medium = 1, // Standard quality
    high = 2, // High quality
    max = 3, // Maximum quality

    pub fn toSampleRate(self: RecordingQuality) u32 {
        return switch (self) {
            .low => 16000,
            .medium => 22050,
            .high => 44100,
            .max => 48000,
        };
    }

    pub fn toBitRate(self: RecordingQuality) u32 {
        return switch (self) {
            .low => 64000,
            .medium => 128000,
            .high => 192000,
            .max => 320000,
        };
    }
};

/// Recording configuration
pub const RecordingConfig = struct {
    format: RecordingFormat = .aac,
    quality: RecordingQuality = .medium,
    sample_rate: ?u32 = null, // Override quality preset
    channels: u8 = 1, // 1 = mono, 2 = stereo
    bit_depth: u8 = 16, // 16 or 24 bit
};

/// Recorder state
pub const RecorderState = enum(u8) {
    idle = 0,
    preparing = 1,
    ready = 2,
    recording = 3,
    paused = 4,
    stopped = 5,
    failed = 6,
};

/// Recording callback
pub const RecorderCallback = *const fn (event: RecorderEvent) void;

/// Recorder events
pub const RecorderEvent = union(enum) {
    state_changed: RecorderState,
    level: f32, // Audio level (0.0 - 1.0)
    duration: f64, // Recording duration in seconds
    finished: types.StringBuffer(1024), // File path
    @"error": Result,
};

/// Audio recorder
pub const AudioRecorder = struct {
    state: RecorderState = .idle,
    config: RecordingConfig = .{},
    permission_status: PermissionStatus = .not_determined,
    current_duration: f64 = 0,
    current_level: f32 = 0,

    // Output
    output_path: types.StringBuffer(1024) = types.StringBuffer(1024).init(),

    // Callback
    callback: ?RecorderCallback = null,

    // Platform handle
    platform_handle: ?*anyopaque = null,

    const Self = @This();

    pub fn init() Self {
        return .{};
    }

    pub fn deinit(self: *Self) void {
        _ = self.stop();
        self.platform_handle = null;
    }

    /// Request microphone permission
    pub fn requestPermission(self: *Self) Result {
        _ = self;
        // Platform-specific implementation
        return .not_available;
    }

    /// Prepare for recording
    pub fn prepare(self: *Self, output_path: []const u8, config: RecordingConfig) Result {
        if (!self.permission_status.isAuthorized()) {
            return .permission_denied;
        }
        self.output_path.set(output_path);
        self.config = config;
        self.state = .preparing;
        // Platform-specific implementation
        return .ok;
    }

    /// Start recording
    pub fn record(self: *Self) Result {
        if (self.state != .ready and self.state != .paused) {
            return .not_initialized;
        }
        self.state = .recording;
        // Platform-specific implementation
        return .ok;
    }

    /// Pause recording
    pub fn pause(self: *Self) Result {
        if (self.state != .recording) {
            return .not_initialized;
        }
        self.state = .paused;
        // Platform-specific implementation
        return .ok;
    }

    /// Stop recording and save
    pub fn stop(self: *Self) Result {
        if (self.state == .idle or self.state == .stopped) {
            return .ok;
        }
        self.state = .stopped;
        // Platform-specific implementation
        return .ok;
    }

    /// Delete recording (if exists)
    pub fn deleteRecording(self: *Self) Result {
        if (self.output_path.len == 0) {
            return .invalid_arg;
        }
        // Platform-specific implementation
        return .ok;
    }

    /// Set callback
    pub fn setCallback(self: *Self, callback: ?RecorderCallback) void {
        self.callback = callback;
    }

    // === Internal callbacks ===

    pub fn onEvent(self: *Self, event: RecorderEvent) void {
        switch (event) {
            .state_changed => |s| self.state = s,
            .duration => |d| self.current_duration = d,
            .level => |l| self.current_level = l,
            else => {},
        }
        if (self.callback) |cb| cb(event);
    }
};

// === Global Instances ===

var global_session: ?AudioSession = null;
var global_player: ?AudioPlayer = null;
var global_recorder: ?AudioRecorder = null;

pub fn getSession() *AudioSession {
    if (global_session == null) {
        global_session = AudioSession.init();
    }
    return &global_session.?;
}

pub fn getPlayer() *AudioPlayer {
    if (global_player == null) {
        global_player = AudioPlayer.init();
    }
    return &global_player.?;
}

pub fn getRecorder() *AudioRecorder {
    if (global_recorder == null) {
        global_recorder = AudioRecorder.init();
    }
    return &global_recorder.?;
}

pub fn init() Result {
    _ = getSession();
    _ = getPlayer();
    _ = getRecorder();
    return .ok;
}

pub fn deinit() void {
    if (global_player) |*p| p.deinit();
    if (global_recorder) |*r| r.deinit();
    if (global_session) |*s| _ = s.deactivate();
    global_player = null;
    global_recorder = null;
    global_session = null;
}

// === Convenience Functions ===

/// Play audio file
pub fn playFile(path: []const u8) Result {
    const player = getPlayer();
    const load_result = player.load(path);
    if (load_result != .ok) return load_result;
    return player.play();
}

// === Tests ===

test "AudioPlayer initialization" {
    var player = AudioPlayer.init();
    defer player.deinit();

    try std.testing.expectEqual(PlayerState.idle, player.state);
    try std.testing.expectEqual(@as(f32, 1.0), player.config.volume);
}

test "Progress calculation" {
    const progress = Progress{
        .current_time = 30,
        .duration = 120,
        .buffered_time = 60,
    };
    try std.testing.expectApproxEqAbs(@as(f64, 25.0), progress.percentage(), 0.1);
    try std.testing.expectApproxEqAbs(@as(f64, 90.0), progress.remaining(), 0.1);
}

test "RecordingQuality presets" {
    try std.testing.expectEqual(@as(u32, 44100), RecordingQuality.high.toSampleRate());
    try std.testing.expectEqual(@as(u32, 192000), RecordingQuality.high.toBitRate());
}

test "AudioRecorder initialization" {
    var recorder = AudioRecorder.init();
    defer recorder.deinit();

    try std.testing.expectEqual(RecorderState.idle, recorder.state);
    try std.testing.expectEqual(@as(u8, 1), recorder.config.channels);
}
