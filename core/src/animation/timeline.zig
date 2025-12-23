//! Timeline - Animation sequencing and coordination
//!
//! Provides timeline-based animation management for coordinating
//! multiple animations, creating sequences, and controlling playback.
//!
//! ## Features
//!
//! - Sequential and parallel animation tracks
//! - Keyframe-based property animation
//! - Markers and labels for synchronization
//! - Time manipulation (speed, seek, reverse)
//!
//! ## Usage
//!
//! ```zig
//! const timeline = @import("timeline.zig");
//!
//! var tl = timeline.Timeline.init();
//! tl.addTrack("position", .{ .x = 0, .y = 0 })
//!   .to(1000, .{ .x = 100, .y = 50 })
//!   .to(2000, .{ .x = 200, .y = 100 });
//! tl.play();
//! ```

const std = @import("std");
const types = @import("types.zig");
const easing = @import("easing.zig");

const TimeMs = types.TimeMs;
const DurationMs = types.DurationMs;
const NormalizedTime = types.NormalizedTime;
const PlaybackState = types.PlaybackState;
const LoopMode = types.LoopMode;
const PlayDirection = types.PlayDirection;
const AnimationEvent = types.AnimationEvent;
const AnimationEventType = types.AnimationEventType;

// === Track Types ===

/// Property track for animating a single value over time
pub fn PropertyTrack(comptime T: type) type {
    return struct {
        const Self = @This();

        /// Keyframe entry
        pub const Keyframe = struct {
            time: TimeMs,
            value: T,
            easing_fn: *const fn (f32) f32 = easing.linear,
        };

        keyframes: std.ArrayList(Keyframe),
        name: []const u8,
        current_value: T,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, name: []const u8, initial_value: T) Self {
            var track = Self{
                .keyframes = .{},
                .name = name,
                .current_value = initial_value,
                .allocator = allocator,
            };
            // Add initial keyframe at time 0
            track.keyframes.append(allocator, .{ .time = 0, .value = initial_value }) catch {};
            return track;
        }

        pub fn deinit(self: *Self) void {
            self.keyframes.deinit(self.allocator);
        }

        /// Add a keyframe at specified time
        pub fn addKeyframe(self: *Self, time: TimeMs, value: T) *Self {
            self.keyframes.append(self.allocator, .{ .time = time, .value = value }) catch {};
            return self;
        }

        /// Add a keyframe with custom easing
        pub fn addKeyframeWithEasing(self: *Self, time: TimeMs, value: T, easing_fn: *const fn (f32) f32) *Self {
            self.keyframes.append(self.allocator, .{
                .time = time,
                .value = value,
                .easing_fn = easing_fn,
            }) catch {};
            return self;
        }

        /// Get the interpolated value at a given time
        pub fn getValueAt(self: *Self, time: TimeMs) T {
            if (self.keyframes.items.len == 0) return self.current_value;
            if (self.keyframes.items.len == 1) return self.keyframes.items[0].value;

            // Find surrounding keyframes
            var prev_idx: usize = 0;
            var next_idx: usize = 0;

            for (self.keyframes.items, 0..) |kf, i| {
                if (kf.time <= time) {
                    prev_idx = i;
                }
                if (kf.time >= time) {
                    next_idx = i;
                    break;
                }
                next_idx = i;
            }

            const prev_kf = self.keyframes.items[prev_idx];
            const next_kf = self.keyframes.items[next_idx];

            // Same keyframe or exact match
            if (prev_idx == next_idx or prev_kf.time == next_kf.time) {
                return prev_kf.value;
            }

            // Calculate normalized time between keyframes
            const duration = next_kf.time - prev_kf.time;
            const elapsed = time - prev_kf.time;
            const t = @as(f32, @floatFromInt(elapsed)) / @as(f32, @floatFromInt(duration));
            const eased_t = next_kf.easing_fn(t);

            // Interpolate based on type
            return interpolateValue(T, prev_kf.value, next_kf.value, eased_t);
        }

        /// Get the total duration of this track
        pub fn getDuration(self: *const Self) TimeMs {
            if (self.keyframes.items.len == 0) return 0;
            return self.keyframes.items[self.keyframes.items.len - 1].time;
        }
    };
}

/// Interpolate between two values of any supported type
fn interpolateValue(comptime T: type, a: T, b: T, t: f32) T {
    const type_info = @typeInfo(T);

    switch (type_info) {
        .float => return a + (b - a) * t,
        .int => return @intFromFloat(@as(f32, @floatFromInt(a)) + (@as(f32, @floatFromInt(b)) - @as(f32, @floatFromInt(a))) * t),
        .@"struct" => {
            // Handle struct types with lerp method
            if (@hasDecl(T, "lerp")) {
                return a.lerp(b, t);
            }
            // Manual field interpolation for known types
            var result: T = undefined;
            inline for (std.meta.fields(T)) |field| {
                const field_a = @field(a, field.name);
                const field_b = @field(b, field.name);
                @field(result, field.name) = interpolateValue(field.type, field_a, field_b, t);
            }
            return result;
        },
        else => return if (t < 0.5) a else b, // Discrete for unsupported types
    }
}

// === Marker ===

/// Timeline marker for labeling specific points
pub const Marker = struct {
    name: []const u8,
    time: TimeMs,
    callback: ?*const fn () void = null,
};

// === Timeline ===

/// Main timeline controller
pub const Timeline = struct {
    const Self = @This();

    /// Track reference (type-erased for heterogeneous tracks)
    const TrackRef = struct {
        ptr: *anyopaque,
        update_fn: *const fn (*anyopaque, TimeMs) void,
        get_duration_fn: *const fn (*anyopaque) TimeMs,
        deinit_fn: *const fn (*anyopaque) void,
    };

    // Fields
    allocator: std.mem.Allocator,
    tracks: std.ArrayList(TrackRef),
    markers: std.ArrayList(Marker),
    state: PlaybackState,
    current_time: TimeMs,
    previous_time: TimeMs, // Track previous time for marker detection
    duration: TimeMs,
    speed: f32,
    loop_mode: LoopMode,
    loop_count: u32,
    current_loop: u32,
    direction: PlayDirection,
    start_time: ?i64,
    callbacks: std.ArrayList(*const fn (AnimationEvent) void),

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .tracks = .{},
            .markers = .{},
            .state = .stopped,
            .current_time = 0,
            .previous_time = 0,
            .duration = 0,
            .speed = 1.0,
            .loop_mode = .none,
            .loop_count = 0,
            .current_loop = 0,
            .direction = .forward,
            .start_time = null,
            .callbacks = .{},
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.tracks.items) |track| {
            track.deinit_fn(track.ptr);
        }
        self.tracks.deinit(self.allocator);
        self.markers.deinit(self.allocator);
        self.callbacks.deinit(self.allocator);
    }

    /// Add a property track to the timeline
    /// Returns null if allocation fails
    pub fn addPropertyTrack(self: *Self, comptime T: type, name: []const u8, initial_value: T) ?*PropertyTrack(T) {
        const track = self.allocator.create(PropertyTrack(T)) catch return null;
        track.* = PropertyTrack(T).init(self.allocator, name, initial_value);

        const ref = TrackRef{
            .ptr = track,
            .update_fn = struct {
                fn update(ptr: *anyopaque, time: TimeMs) void {
                    const t: *PropertyTrack(T) = @ptrCast(@alignCast(ptr));
                    t.current_value = t.getValueAt(time);
                }
            }.update,
            .get_duration_fn = struct {
                fn getDuration(ptr: *anyopaque) TimeMs {
                    const t: *const PropertyTrack(T) = @ptrCast(@alignCast(ptr));
                    return t.getDuration();
                }
            }.getDuration,
            .deinit_fn = struct {
                fn deinitTrack(ptr: *anyopaque) void {
                    const t: *PropertyTrack(T) = @ptrCast(@alignCast(ptr));
                    const allocator = t.allocator;
                    t.deinit();
                    allocator.destroy(t);
                }
            }.deinitTrack,
        };

        self.tracks.append(self.allocator, ref) catch {
            track.deinit();
            self.allocator.destroy(track);
            return null;
        };
        self.updateDuration();
        return track;
    }

    /// Add a marker at specified time
    pub fn addMarker(self: *Self, name: []const u8, time: TimeMs) *Self {
        self.markers.append(self.allocator, .{ .name = name, .time = time }) catch {};
        return self;
    }

    /// Add a marker with callback
    pub fn addMarkerWithCallback(self: *Self, name: []const u8, time: TimeMs, callback: *const fn () void) *Self {
        self.markers.append(self.allocator, .{ .name = name, .time = time, .callback = callback }) catch {};
        return self;
    }

    /// Set playback speed
    pub fn setSpeed(self: *Self, speed: f32) *Self {
        self.speed = speed;
        return self;
    }

    /// Set loop mode
    pub fn setLoopMode(self: *Self, mode: LoopMode) *Self {
        self.loop_mode = mode;
        return self;
    }

    /// Set loop count (for loop_count mode)
    pub fn setLoopCount(self: *Self, count: u32) *Self {
        self.loop_count = count;
        return self;
    }

    /// Start playback
    pub fn play(self: *Self) void {
        if (self.state == .paused) {
            self.state = .playing;
            self.emitEvent(.resumed);
        } else {
            self.state = .playing;
            self.start_time = std.time.milliTimestamp();
            self.emitEvent(.started);
        }
    }

    /// Pause playback
    pub fn pause(self: *Self) void {
        if (self.state == .playing) {
            self.state = .paused;
            self.emitEvent(.paused);
        }
    }

    /// Stop playback and reset to start
    pub fn stop(self: *Self) void {
        self.state = .stopped;
        self.current_time = 0;
        self.previous_time = 0;
        self.current_loop = 0;
        self.start_time = null;
        self.emitEvent(.stopped);
    }

    /// Seek to specific time
    pub fn seek(self: *Self, time: TimeMs) void {
        const duration = self.getDuration();
        self.current_time = @max(0, @min(time, duration));
        self.updateTracks();
    }

    /// Seek to marker by name
    pub fn seekToMarker(self: *Self, name: []const u8) bool {
        for (self.markers.items) |marker| {
            if (std.mem.eql(u8, marker.name, name)) {
                self.seek(marker.time);
                return true;
            }
        }
        return false;
    }

    /// Update timeline (call each frame)
    pub fn update(self: *Self, delta_ms: TimeMs) void {
        if (self.state != .playing) return;

        // Store previous time for marker detection
        self.previous_time = self.current_time;

        const adjusted_delta = @as(TimeMs, @intFromFloat(@as(f32, @floatFromInt(delta_ms)) * self.speed));

        if (self.direction == .forward) {
            self.current_time += adjusted_delta;
        } else {
            self.current_time -= adjusted_delta;
        }

        // Check markers (using previous_time to current_time range)
        self.checkMarkers();

        // Get duration dynamically from tracks
        const duration = self.getDuration();

        // Handle end of timeline
        if (self.current_time >= duration) {
            switch (self.loop_mode) {
                .none => {
                    self.current_time = duration;
                    self.state = .finished;
                    self.emitEvent(.completed);
                },
                .loop => {
                    self.current_time = @mod(self.current_time, duration);
                    self.current_loop += 1;
                    self.emitEvent(.loop_completed);
                },
                .ping_pong => {
                    self.direction = if (self.direction == .forward) .reverse else .forward;
                    self.current_time = duration;
                    self.current_loop += 1;
                    self.emitEvent(.loop_completed);
                },
                .loop_count => {
                    self.current_loop += 1;
                    if (self.current_loop >= self.loop_count) {
                        self.current_time = duration;
                        self.state = .finished;
                        self.emitEvent(.completed);
                    } else {
                        self.current_time = @mod(self.current_time, duration);
                        self.emitEvent(.loop_completed);
                    }
                },
            }
        } else if (self.current_time < 0) {
            // Handle reverse direction
            if (self.loop_mode == .ping_pong) {
                self.direction = .forward;
                self.current_time = 0;
            } else {
                self.current_time = 0;
            }
        }

        self.updateTracks();
    }

    /// Register event callback
    /// Returns error if allocation fails
    pub fn onEvent(self: *Self, callback: *const fn (AnimationEvent) void) !void {
        try self.callbacks.append(self.allocator, callback);
    }

    // === Private Methods ===

    fn updateDuration(self: *Self) void {
        var max_duration: TimeMs = 0;
        for (self.tracks.items) |track| {
            const track_duration = track.get_duration_fn(track.ptr);
            if (track_duration > max_duration) {
                max_duration = track_duration;
            }
        }
        self.duration = max_duration;
    }

    fn updateTracks(self: *Self) void {
        for (self.tracks.items) |track| {
            track.update_fn(track.ptr, self.current_time);
        }
    }

    fn checkMarkers(self: *Self) void {
        for (self.markers.items) |marker| {
            // Check if marker time falls within the time range [previous_time, current_time)
            // This handles both forward and reverse playback correctly
            const crossed = if (self.direction == .forward)
                self.previous_time < marker.time and self.current_time >= marker.time
            else
                self.previous_time > marker.time and self.current_time <= marker.time;

            if (crossed) {
                if (marker.callback) |callback| {
                    callback();
                }
                self.emitMarkerEvent(marker.name);
            }
        }
    }

    fn emitEvent(self: *Self, event_type: AnimationEventType) void {
        const event = AnimationEvent{
            .event_type = event_type,
            .animation_id = 0,
            .current_time = self.current_time,
            .loop_count = self.current_loop,
        };
        for (self.callbacks.items) |callback| {
            callback(event);
        }
    }

    fn emitMarkerEvent(self: *Self, marker_name: []const u8) void {
        const event = AnimationEvent{
            .event_type = .marker_reached,
            .animation_id = 0,
            .current_time = self.current_time,
            .marker_name = marker_name,
        };
        for (self.callbacks.items) |callback| {
            callback(event);
        }
    }

    // === Getters ===

    pub fn getState(self: *const Self) PlaybackState {
        return self.state;
    }

    pub fn getCurrentTime(self: *const Self) TimeMs {
        return self.current_time;
    }

    pub fn getDuration(self: *const Self) TimeMs {
        // Calculate duration dynamically from tracks
        var max_duration: TimeMs = 0;
        for (self.tracks.items) |track| {
            const track_duration = track.get_duration_fn(track.ptr);
            if (track_duration > max_duration) {
                max_duration = track_duration;
            }
        }
        return max_duration;
    }

    pub fn getProgress(self: *const Self) f32 {
        const duration = self.getDuration();
        if (duration == 0) return 0;
        return @as(f32, @floatFromInt(self.current_time)) / @as(f32, @floatFromInt(duration));
    }

    pub fn isPlaying(self: *const Self) bool {
        return self.state == .playing;
    }

    pub fn isFinished(self: *const Self) bool {
        return self.state == .finished;
    }
};

// === Sequence Builder ===

/// Builder for creating animation sequences
pub const SequenceBuilder = struct {
    const Self = @This();

    timeline: *Timeline,
    current_time: TimeMs,

    pub fn init(timeline: *Timeline) Self {
        return Self{
            .timeline = timeline,
            .current_time = 0,
        };
    }

    /// Add a delay
    pub fn delay(self: *Self, duration: DurationMs) *Self {
        self.current_time += @as(TimeMs, @intCast(duration));
        return self;
    }

    /// Add a marker at current position
    pub fn mark(self: *Self, name: []const u8) *Self {
        _ = self.timeline.addMarker(name, self.current_time);
        return self;
    }

    /// Get current time position
    pub fn getCurrentTime(self: *const Self) TimeMs {
        return self.current_time;
    }
};

// === Parallel Group ===

/// Group of animations that play in parallel
pub const ParallelGroup = struct {
    const Self = @This();

    timelines: std.ArrayList(*Timeline),
    allocator: std.mem.Allocator,
    state: PlaybackState,

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .timelines = .{},
            .allocator = allocator,
            .state = .stopped,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.timelines.items) |tl| {
            tl.deinit();
            self.allocator.destroy(tl);
        }
        self.timelines.deinit(self.allocator);
    }

    /// Add a timeline to the group
    pub fn add(self: *Self, timeline: *Timeline) *Self {
        self.timelines.append(self.allocator, timeline) catch {};
        return self;
    }

    /// Play all timelines
    pub fn play(self: *Self) void {
        self.state = .playing;
        for (self.timelines.items) |tl| {
            tl.play();
        }
    }

    /// Pause all timelines
    pub fn pause(self: *Self) void {
        self.state = .paused;
        for (self.timelines.items) |tl| {
            tl.pause();
        }
    }

    /// Stop all timelines
    pub fn stop(self: *Self) void {
        self.state = .stopped;
        for (self.timelines.items) |tl| {
            tl.stop();
        }
    }

    /// Update all timelines
    pub fn update(self: *Self, delta_ms: TimeMs) void {
        if (self.state != .playing) return;

        var all_finished = true;
        for (self.timelines.items) |tl| {
            tl.update(delta_ms);
            if (!tl.isFinished()) {
                all_finished = false;
            }
        }

        if (all_finished) {
            self.state = .finished;
        }
    }
};
