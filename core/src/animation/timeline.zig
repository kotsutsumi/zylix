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

        // Threshold for switching to binary search
        const BINARY_SEARCH_THRESHOLD = 8;

        keyframes: std.ArrayList(Keyframe),
        name: []const u8,
        current_value: T,
        allocator: std.mem.Allocator,
        // Performance: cached duration (updated on keyframe add)
        cached_duration: TimeMs = 0,
        // Performance: last accessed keyframe index for temporal coherence
        last_keyframe_idx: usize = 0,
        // Error tracking: set to true if any allocation fails
        allocation_failed: bool = false,

        pub fn init(allocator: std.mem.Allocator, name: []const u8, initial_value: T) Self {
            var track = Self{
                .keyframes = .{},
                .name = name,
                .current_value = initial_value,
                .allocator = allocator,
                .cached_duration = 0,
                .last_keyframe_idx = 0,
                .allocation_failed = false,
            };
            // Add initial keyframe at time 0
            track.keyframes.append(allocator, .{ .time = 0, .value = initial_value }) catch {
                track.allocation_failed = true;
            };
            return track;
        }

        /// Check if any allocation has failed
        pub fn hasAllocationError(self: *const Self) bool {
            return self.allocation_failed;
        }

        pub fn deinit(self: *Self) void {
            self.keyframes.deinit(self.allocator);
        }

        /// Add a keyframe at specified time
        pub fn addKeyframe(self: *Self, time: TimeMs, value: T) *Self {
            self.keyframes.append(self.allocator, .{ .time = time, .value = value }) catch {
                self.allocation_failed = true;
                return self;
            };
            self.updateCachedDuration();
            return self;
        }

        /// Add a keyframe with custom easing
        pub fn addKeyframeWithEasing(self: *Self, time: TimeMs, value: T, easing_fn: *const fn (f32) f32) *Self {
            self.keyframes.append(self.allocator, .{
                .time = time,
                .value = value,
                .easing_fn = easing_fn,
            }) catch {
                self.allocation_failed = true;
                return self;
            };
            self.updateCachedDuration();
            return self;
        }

        /// Update cached duration after keyframe modification
        fn updateCachedDuration(self: *Self) void {
            if (self.keyframes.items.len == 0) {
                self.cached_duration = 0;
            } else {
                self.cached_duration = self.keyframes.items[self.keyframes.items.len - 1].time;
            }
        }

        /// Binary search to find keyframe index for a given time
        fn binarySearchKeyframe(keyframes: []const Keyframe, time: TimeMs) usize {
            if (keyframes.len == 0) return 0;

            var left: usize = 0;
            var right: usize = keyframes.len;

            while (left < right) {
                const mid = left + (right - left) / 2;
                if (keyframes[mid].time <= time) {
                    left = mid + 1;
                } else {
                    right = mid;
                }
            }

            return if (left > 0) left - 1 else 0;
        }

        /// Get the interpolated value at a given time
        pub fn getValueAt(self: *Self, time: TimeMs) T {
            if (self.keyframes.items.len == 0) return self.current_value;
            if (self.keyframes.items.len == 1) return self.keyframes.items[0].value;

            // Find surrounding keyframes
            var prev_idx: usize = 0;
            var next_idx: usize = 0;

            // Performance: use binary search for many keyframes
            if (self.keyframes.items.len >= BINARY_SEARCH_THRESHOLD) {
                prev_idx = binarySearchKeyframe(self.keyframes.items, time);
                next_idx = @min(prev_idx + 1, self.keyframes.items.len - 1);
            } else {
                // Linear search with temporal coherence optimization
                // Start from last accessed index for sequential playback
                const start = if (self.last_keyframe_idx < self.keyframes.items.len)
                    self.last_keyframe_idx
                else
                    0;

                // Check if we can use cached position
                if (start > 0 and self.keyframes.items[start - 1].time <= time and
                    (start >= self.keyframes.items.len or self.keyframes.items[start].time > time))
                {
                    prev_idx = start - 1;
                    next_idx = start;
                } else {
                    // Full linear search
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
                }
            }

            // Cache for next lookup
            self.last_keyframe_idx = next_idx;

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

        /// Get the total duration of this track (cached for performance)
        pub fn getDuration(self: *const Self) TimeMs {
            return self.cached_duration;
        }

        /// Force recalculation of cached duration
        pub fn invalidateDurationCache(self: *Self) void {
            self.updateCachedDuration();
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
    speed: f32,
    loop_mode: LoopMode,
    loop_count: u32,
    current_loop: u32,
    direction: PlayDirection,
    start_time: ?i64,
    callbacks: std.ArrayList(*const fn (AnimationEvent) void),
    // Error tracking: set to true if any allocation fails
    allocation_failed: bool = false,

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .tracks = .{},
            .markers = .{},
            .state = .stopped,
            .current_time = 0,
            .previous_time = 0,
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

    /// Check if any allocation has failed
    pub fn hasAllocationError(self: *const Self) bool {
        return self.allocation_failed;
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
        return track;
    }

    /// Add a marker at specified time
    pub fn addMarker(self: *Self, name: []const u8, time: TimeMs) *Self {
        self.markers.append(self.allocator, .{ .name = name, .time = time }) catch {
            self.allocation_failed = true;
            return self;
        };
        return self;
    }

    /// Add a marker with callback
    pub fn addMarkerWithCallback(self: *Self, name: []const u8, time: TimeMs, callback: *const fn () void) *Self {
        self.markers.append(self.allocator, .{ .name = name, .time = time, .callback = callback }) catch {
            self.allocation_failed = true;
            return self;
        };
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
        // Always calculate from tracks since tracks can be modified independently
        // Note: Each PropertyTrack has its own cached duration, making this O(n) where n = track count
        // Timeline-level caching is intentionally avoided because PropertyTrack.addKeyframe()
        // doesn't have a reference to invalidate the parent Timeline's cache
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
    // Error tracking: set to true if any allocation fails
    allocation_failed: bool = false,

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .timelines = .{},
            .allocator = allocator,
            .state = .stopped,
            .allocation_failed = false,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.timelines.items) |tl| {
            tl.deinit();
            self.allocator.destroy(tl);
        }
        self.timelines.deinit(self.allocator);
    }

    /// Check if any allocation has failed
    pub fn hasAllocationError(self: *const Self) bool {
        return self.allocation_failed;
    }

    /// Add a timeline to the group
    pub fn add(self: *Self, timeline: *Timeline) *Self {
        self.timelines.append(self.allocator, timeline) catch {
            self.allocation_failed = true;
            return self;
        };
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

// ============================================================================
// Tests
// ============================================================================

test "PropertyTrack initialization" {
    const allocator = std.testing.allocator;
    var track = PropertyTrack(f32).init(allocator, "opacity", 1.0);
    defer track.deinit();

    try std.testing.expectEqualStrings("opacity", track.name);
    try std.testing.expectEqual(@as(f32, 1.0), track.current_value);
    // Initial keyframe at time 0
    try std.testing.expectEqual(@as(usize, 1), track.keyframes.items.len);
}

test "PropertyTrack add keyframes" {
    const allocator = std.testing.allocator;
    var track = PropertyTrack(f32).init(allocator, "scale", 1.0);
    defer track.deinit();

    _ = track.addKeyframe(500, 1.5);
    _ = track.addKeyframe(1000, 2.0);

    try std.testing.expectEqual(@as(usize, 3), track.keyframes.items.len);
    try std.testing.expectEqual(@as(TimeMs, 1000), track.getDuration());
}

test "PropertyTrack interpolation at boundaries" {
    const allocator = std.testing.allocator;
    var track = PropertyTrack(f32).init(allocator, "value", 0.0);
    defer track.deinit();

    _ = track.addKeyframe(1000, 100.0);

    // At start
    try std.testing.expectEqual(@as(f32, 0.0), track.getValueAt(0));

    // At end
    try std.testing.expectEqual(@as(f32, 100.0), track.getValueAt(1000));
}

test "PropertyTrack interpolation midpoint" {
    const allocator = std.testing.allocator;
    var track = PropertyTrack(f32).init(allocator, "position", 0.0);
    defer track.deinit();

    _ = track.addKeyframe(1000, 100.0);

    // At midpoint (with linear easing)
    const mid_value = track.getValueAt(500);
    try std.testing.expectApproxEqAbs(@as(f32, 50.0), mid_value, 0.01);
}

test "PropertyTrack with custom easing" {
    const allocator = std.testing.allocator;
    var track = PropertyTrack(f32).init(allocator, "eased", 0.0);
    defer track.deinit();

    _ = track.addKeyframeWithEasing(1000, 100.0, easing.easeInQuad);

    // easeInQuad at t=0.5 gives t^2 = 0.25
    const mid_value = track.getValueAt(500);
    try std.testing.expectApproxEqAbs(@as(f32, 25.0), mid_value, 0.01);
}

test "Timeline initialization" {
    const allocator = std.testing.allocator;
    var timeline = Timeline.init(allocator);
    defer timeline.deinit();

    try std.testing.expectEqual(PlaybackState.stopped, timeline.getState());
    try std.testing.expectEqual(@as(TimeMs, 0), timeline.getCurrentTime());
    try std.testing.expectEqual(@as(TimeMs, 0), timeline.getDuration());
    try std.testing.expectEqual(false, timeline.isPlaying());
}

test "Timeline add property track" {
    const allocator = std.testing.allocator;
    var timeline = Timeline.init(allocator);
    defer timeline.deinit();

    const track = timeline.addPropertyTrack(f32, "opacity", 1.0);
    try std.testing.expect(track != null);

    if (track) |t| {
        _ = t.addKeyframe(1000, 0.0);
        try std.testing.expectEqual(@as(TimeMs, 1000), timeline.getDuration());
    }
}

test "Timeline markers" {
    const allocator = std.testing.allocator;
    var timeline = Timeline.init(allocator);
    defer timeline.deinit();

    _ = timeline.addMarker("start", 0);
    _ = timeline.addMarker("middle", 500);
    _ = timeline.addMarker("end", 1000);

    try std.testing.expectEqual(@as(usize, 3), timeline.markers.items.len);
    try std.testing.expectEqualStrings("middle", timeline.markers.items[1].name);
    try std.testing.expectEqual(@as(TimeMs, 500), timeline.markers.items[1].time);
}

test "Timeline playback states" {
    const allocator = std.testing.allocator;
    var timeline = Timeline.init(allocator);
    defer timeline.deinit();

    // Initial state
    try std.testing.expectEqual(PlaybackState.stopped, timeline.getState());

    // Play
    timeline.play();
    try std.testing.expectEqual(PlaybackState.playing, timeline.getState());
    try std.testing.expect(timeline.isPlaying());

    // Pause
    timeline.pause();
    try std.testing.expectEqual(PlaybackState.paused, timeline.getState());
    try std.testing.expect(!timeline.isPlaying());

    // Resume
    timeline.play();
    try std.testing.expectEqual(PlaybackState.playing, timeline.getState());

    // Stop
    timeline.stop();
    try std.testing.expectEqual(PlaybackState.stopped, timeline.getState());
    try std.testing.expectEqual(@as(TimeMs, 0), timeline.getCurrentTime());
}

test "Timeline seek" {
    const allocator = std.testing.allocator;
    var timeline = Timeline.init(allocator);
    defer timeline.deinit();

    const track = timeline.addPropertyTrack(f32, "value", 0.0);
    if (track) |t| {
        _ = t.addKeyframe(1000, 100.0);
    }

    timeline.seek(500);
    try std.testing.expectEqual(@as(TimeMs, 500), timeline.getCurrentTime());

    // Seek beyond duration should clamp
    timeline.seek(2000);
    try std.testing.expectEqual(@as(TimeMs, 1000), timeline.getCurrentTime());

    // Seek negative should clamp to 0
    timeline.seek(-100);
    try std.testing.expectEqual(@as(TimeMs, 0), timeline.getCurrentTime());
}

test "Timeline seek to marker" {
    const allocator = std.testing.allocator;
    var timeline = Timeline.init(allocator);
    defer timeline.deinit();

    const track = timeline.addPropertyTrack(f32, "value", 0.0);
    if (track) |t| {
        _ = t.addKeyframe(1000, 100.0);
    }

    _ = timeline.addMarker("halfway", 500);

    const found = timeline.seekToMarker("halfway");
    try std.testing.expect(found);
    try std.testing.expectEqual(@as(TimeMs, 500), timeline.getCurrentTime());

    const not_found = timeline.seekToMarker("nonexistent");
    try std.testing.expect(!not_found);
}

test "Timeline speed multiplier" {
    const allocator = std.testing.allocator;
    var timeline = Timeline.init(allocator);
    defer timeline.deinit();

    _ = timeline.setSpeed(2.0);
    try std.testing.expectEqual(@as(f32, 2.0), timeline.speed);

    _ = timeline.setSpeed(0.5);
    try std.testing.expectEqual(@as(f32, 0.5), timeline.speed);
}

test "Timeline loop mode" {
    const allocator = std.testing.allocator;
    var timeline = Timeline.init(allocator);
    defer timeline.deinit();

    _ = timeline.setLoopMode(.loop);
    try std.testing.expectEqual(LoopMode.loop, timeline.loop_mode);

    _ = timeline.setLoopMode(.ping_pong);
    try std.testing.expectEqual(LoopMode.ping_pong, timeline.loop_mode);
}

test "Timeline loop count" {
    const allocator = std.testing.allocator;
    var timeline = Timeline.init(allocator);
    defer timeline.deinit();

    _ = timeline.setLoopCount(3);
    try std.testing.expectEqual(@as(u32, 3), timeline.loop_count);
}

test "Timeline progress" {
    const allocator = std.testing.allocator;
    var timeline = Timeline.init(allocator);
    defer timeline.deinit();

    const track = timeline.addPropertyTrack(f32, "value", 0.0);
    if (track) |t| {
        _ = t.addKeyframe(1000, 100.0);
    }

    try std.testing.expectEqual(@as(f32, 0.0), timeline.getProgress());

    timeline.seek(500);
    try std.testing.expectEqual(@as(f32, 0.5), timeline.getProgress());

    timeline.seek(1000);
    try std.testing.expectEqual(@as(f32, 1.0), timeline.getProgress());
}

test "SequenceBuilder initialization" {
    const allocator = std.testing.allocator;
    var timeline = Timeline.init(allocator);
    defer timeline.deinit();

    var builder = SequenceBuilder.init(&timeline);
    try std.testing.expectEqual(@as(TimeMs, 0), builder.getCurrentTime());
}

test "SequenceBuilder delay" {
    const allocator = std.testing.allocator;
    var timeline = Timeline.init(allocator);
    defer timeline.deinit();

    var builder = SequenceBuilder.init(&timeline);
    _ = builder.delay(500);
    try std.testing.expectEqual(@as(TimeMs, 500), builder.getCurrentTime());

    _ = builder.delay(300);
    try std.testing.expectEqual(@as(TimeMs, 800), builder.getCurrentTime());
}

test "SequenceBuilder mark" {
    const allocator = std.testing.allocator;
    var timeline = Timeline.init(allocator);
    defer timeline.deinit();

    var builder = SequenceBuilder.init(&timeline);
    _ = builder.delay(500);
    _ = builder.mark("checkpoint");

    try std.testing.expectEqual(@as(usize, 1), timeline.markers.items.len);
    try std.testing.expectEqualStrings("checkpoint", timeline.markers.items[0].name);
    try std.testing.expectEqual(@as(TimeMs, 500), timeline.markers.items[0].time);
}

test "ParallelGroup initialization" {
    const allocator = std.testing.allocator;
    var group = ParallelGroup.init(allocator);
    defer group.deinit();

    try std.testing.expectEqual(PlaybackState.stopped, group.state);
    try std.testing.expectEqual(@as(usize, 0), group.timelines.items.len);
}

test "ParallelGroup playback control" {
    const allocator = std.testing.allocator;
    var group = ParallelGroup.init(allocator);
    defer group.deinit();

    group.play();
    try std.testing.expectEqual(PlaybackState.playing, group.state);

    group.pause();
    try std.testing.expectEqual(PlaybackState.paused, group.state);

    group.stop();
    try std.testing.expectEqual(PlaybackState.stopped, group.state);
}

test "interpolateValue float" {
    const result = interpolateValue(f32, 0.0, 100.0, 0.5);
    try std.testing.expectEqual(@as(f32, 50.0), result);
}

test "interpolateValue int" {
    const result = interpolateValue(i32, 0, 100, 0.5);
    try std.testing.expectEqual(@as(i32, 50), result);
}

test "interpolateValue struct with lerp" {
    const result = interpolateValue(types.Point2D, types.Point2D{ .x = 0, .y = 0 }, types.Point2D{ .x = 100, .y = 200 }, 0.5);
    try std.testing.expectEqual(@as(f32, 50), result.x);
    try std.testing.expectEqual(@as(f32, 100), result.y);
}

// === Performance Optimization Tests ===

test "PropertyTrack cached duration" {
    const allocator = std.testing.allocator;
    var track = PropertyTrack(f32).init(allocator, "cached", 0.0);
    defer track.deinit();

    // Initial duration should be 0
    try std.testing.expectEqual(@as(TimeMs, 0), track.cached_duration);

    // Add keyframes and check cached duration is updated
    _ = track.addKeyframe(500, 50.0);
    try std.testing.expectEqual(@as(TimeMs, 500), track.cached_duration);

    _ = track.addKeyframe(1000, 100.0);
    try std.testing.expectEqual(@as(TimeMs, 1000), track.cached_duration);

    // getDuration should return cached value
    try std.testing.expectEqual(@as(TimeMs, 1000), track.getDuration());
}

test "PropertyTrack binary search threshold" {
    const allocator = std.testing.allocator;
    var track = PropertyTrack(f32).init(allocator, "many_keyframes", 0.0);
    defer track.deinit();

    // Add enough keyframes to trigger binary search (>= 8)
    var i: TimeMs = 100;
    while (i <= 1000) : (i += 100) {
        _ = track.addKeyframe(i, @as(f32, @floatFromInt(i)));
    }

    // Should have 11 keyframes (initial + 10 added)
    try std.testing.expectEqual(@as(usize, 11), track.keyframes.items.len);

    // Test interpolation at various points
    const val_250 = track.getValueAt(250);
    try std.testing.expectApproxEqAbs(@as(f32, 250.0), val_250, 1.0);

    const val_750 = track.getValueAt(750);
    try std.testing.expectApproxEqAbs(@as(f32, 750.0), val_750, 1.0);
}

test "PropertyTrack temporal coherence" {
    const allocator = std.testing.allocator;
    var track = PropertyTrack(f32).init(allocator, "sequential", 0.0);
    defer track.deinit();

    // Add a few keyframes (below binary search threshold)
    _ = track.addKeyframe(250, 25.0);
    _ = track.addKeyframe(500, 50.0);
    _ = track.addKeyframe(750, 75.0);
    _ = track.addKeyframe(1000, 100.0);

    // Simulate sequential playback
    var time: TimeMs = 0;
    while (time <= 1000) : (time += 50) {
        const val = track.getValueAt(time);
        // Verify value is reasonable
        const expected = @as(f32, @floatFromInt(time)) / 10.0;
        try std.testing.expectApproxEqAbs(expected, val, 1.0);
    }

    // last_keyframe_idx should have been updated
    try std.testing.expect(track.last_keyframe_idx > 0);
}

test "Timeline duration from tracks" {
    const allocator = std.testing.allocator;
    var timeline = Timeline.init(allocator);
    defer timeline.deinit();

    // Add track
    const track = timeline.addPropertyTrack(f32, "test", 0.0);

    // Adding keyframes to track updates track's cache
    if (track) |t| {
        _ = t.addKeyframe(1000, 100.0);
        // Track's cache is updated
        try std.testing.expectEqual(@as(TimeMs, 1000), t.getDuration());
    }

    // Timeline getDuration always recalculates from tracks
    // Each track has its own cached duration, so this is efficient
    try std.testing.expectEqual(@as(TimeMs, 1000), timeline.getDuration());

    // Add another track with longer duration
    const track2 = timeline.addPropertyTrack(f32, "test2", 0.0);
    if (track2) |t| {
        _ = t.addKeyframe(2000, 200.0);
    }

    // Timeline returns the maximum duration across all tracks
    try std.testing.expectEqual(@as(TimeMs, 2000), timeline.getDuration());
}

test "PropertyTrack invalidateDurationCache" {
    const allocator = std.testing.allocator;
    var track = PropertyTrack(f32).init(allocator, "invalidate", 0.0);
    defer track.deinit();

    _ = track.addKeyframe(500, 50.0);
    try std.testing.expectEqual(@as(TimeMs, 500), track.cached_duration);

    // Manually set a wrong cached duration
    track.cached_duration = 999;

    // Invalidate should recalculate
    track.invalidateDurationCache();
    try std.testing.expectEqual(@as(TimeMs, 500), track.cached_duration);
}
