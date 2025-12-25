//! Touch Input Abstraction for M5Stack CoreS3
//!
//! High-level touch input handling with state tracking,
//! coordinate transformation, and multi-touch support.
//!
//! Features:
//! - Touch state machine (up, down, move)
//! - Coordinate transformation for display rotation
//! - Touch history for velocity calculation
//! - Multi-touch point tracking
//! - Debouncing and filtering

const std = @import("std");
const ft6336u = @import("../drivers/ft6336u.zig");

/// Touch phase (follows UIKit convention)
pub const TouchPhase = enum {
    began, // Touch started
    moved, // Touch moved
    stationary, // Touch stationary
    ended, // Touch lifted
    cancelled, // Touch cancelled
};

/// Touch point with extended information
pub const Touch = struct {
    id: u4, // Touch ID (0-1 for FT6336U)
    x: i32, // X coordinate (can be negative after transformation)
    y: i32, // Y coordinate
    phase: TouchPhase,
    timestamp: u64, // Microseconds since boot
    pressure: f32, // Normalized pressure (0.0-1.0)

    // Previous position for delta calculation
    prev_x: i32 = 0,
    prev_y: i32 = 0,

    // Start position for gesture recognition
    start_x: i32 = 0,
    start_y: i32 = 0,
    start_time: u64 = 0,

    /// Get delta X from previous position
    pub fn deltaX(self: Touch) i32 {
        return self.x - self.prev_x;
    }

    /// Get delta Y from previous position
    pub fn deltaY(self: Touch) i32 {
        return self.y - self.prev_y;
    }

    /// Get total distance from start
    pub fn distanceFromStart(self: Touch) f32 {
        const dx = @as(f32, @floatFromInt(self.x - self.start_x));
        const dy = @as(f32, @floatFromInt(self.y - self.start_y));
        return @sqrt(dx * dx + dy * dy);
    }

    /// Get duration since touch began
    pub fn duration(self: Touch) u64 {
        return self.timestamp - self.start_time;
    }
};

/// Touch input configuration
pub const TouchConfig = struct {
    // Display dimensions for coordinate transformation
    display_width: u16 = 320,
    display_height: u16 = 240,

    // Rotation (matches display rotation)
    rotation: Rotation = .portrait,

    // Touch filtering
    debounce_ms: u16 = 10, // Minimum time between reports
    move_threshold: u16 = 3, // Minimum pixels to register as move

    // Pressure sensitivity
    pressure_min: u8 = 10, // Minimum weight to register
    pressure_max: u8 = 200, // Maximum weight for normalization

    pub const Rotation = enum(u2) {
        portrait = 0,
        landscape = 1,
        portrait_inverted = 2,
        landscape_inverted = 3,
    };
};

/// Touch state for a single touch point
const TouchState = struct {
    active: bool = false,
    touch: Touch = undefined,
    last_report_time: u64 = 0,
};

/// Touch input manager
pub const TouchInput = struct {
    config: TouchConfig,
    driver: ?ft6336u.FT6336U = null,

    // Touch state tracking (2 points max)
    touches: [2]TouchState = .{ .{}, .{} },
    active_count: u8 = 0,

    // Timing
    current_time: u64 = 0,

    // Callbacks
    on_touch_began: ?*const fn (Touch) void = null,
    on_touch_moved: ?*const fn (Touch) void = null,
    on_touch_ended: ?*const fn (Touch) void = null,

    /// Initialize touch input
    pub fn init(config: TouchConfig) !TouchInput {
        var input = TouchInput{
            .config = config,
        };

        // Initialize touch driver
        input.driver = ft6336u.FT6336U.init(0x38) catch null;

        return input;
    }

    /// Deinitialize touch input
    pub fn deinit(self: *TouchInput) void {
        if (self.driver) |*driver| {
            driver.deinit();
        }
    }

    /// Update touch state (call every frame)
    pub fn update(self: *TouchInput, timestamp_us: u64) void {
        self.current_time = timestamp_us;

        // Read touch data from driver
        var driver = self.driver orelse return;
        const data = driver.readAll() catch return;

        // Process each potential touch point
        self.processPoint(0, if (data.count >= 1) data.points[0] else null);
        self.processPoint(1, if (data.count >= 2) data.points[1] else null);

        // Update active count
        self.active_count = 0;
        for (self.touches) |state| {
            if (state.active) self.active_count += 1;
        }
    }

    /// Process a single touch point
    fn processPoint(self: *TouchInput, index: usize, raw_point: ?ft6336u.TouchPoint) void {
        var state = &self.touches[index];

        if (raw_point) |point| {
            // Transform coordinates
            const transformed = self.transformCoordinates(point.x, point.y);
            const pressure = self.normalizePressure(point.weight);

            // Check debounce
            const time_since_last = self.current_time -| state.last_report_time;
            if (time_since_last < @as(u64, self.config.debounce_ms) * 1000) {
                return;
            }

            if (!state.active) {
                // New touch
                state.active = true;
                state.touch = Touch{
                    .id = point.id,
                    .x = transformed.x,
                    .y = transformed.y,
                    .phase = .began,
                    .timestamp = self.current_time,
                    .pressure = pressure,
                    .prev_x = transformed.x,
                    .prev_y = transformed.y,
                    .start_x = transformed.x,
                    .start_y = transformed.y,
                    .start_time = self.current_time,
                };
                state.last_report_time = self.current_time;

                if (self.on_touch_began) |callback| {
                    callback(state.touch);
                }
            } else {
                // Existing touch - check for movement
                const dx = @abs(transformed.x - state.touch.x);
                const dy = @abs(transformed.y - state.touch.y);

                if (dx >= self.config.move_threshold or dy >= self.config.move_threshold) {
                    // Touch moved
                    state.touch.prev_x = state.touch.x;
                    state.touch.prev_y = state.touch.y;
                    state.touch.x = transformed.x;
                    state.touch.y = transformed.y;
                    state.touch.phase = .moved;
                    state.touch.timestamp = self.current_time;
                    state.touch.pressure = pressure;
                    state.last_report_time = self.current_time;

                    if (self.on_touch_moved) |callback| {
                        callback(state.touch);
                    }
                } else {
                    state.touch.phase = .stationary;
                    state.touch.timestamp = self.current_time;
                }
            }
        } else if (state.active) {
            // Touch ended
            state.touch.phase = .ended;
            state.touch.timestamp = self.current_time;
            state.active = false;

            if (self.on_touch_ended) |callback| {
                callback(state.touch);
            }
        }
    }

    /// Transform raw coordinates based on rotation
    fn transformCoordinates(self: *TouchInput, raw_x: u16, raw_y: u16) struct { x: i32, y: i32 } {
        const x = @as(i32, raw_x);
        const y = @as(i32, raw_y);
        const w = @as(i32, self.config.display_width);
        const h = @as(i32, self.config.display_height);

        return switch (self.config.rotation) {
            .portrait => .{ .x = x, .y = y },
            .landscape => .{ .x = y, .y = w - 1 - x },
            .portrait_inverted => .{ .x = w - 1 - x, .y = h - 1 - y },
            .landscape_inverted => .{ .x = h - 1 - y, .y = x },
        };
    }

    /// Normalize pressure value to 0.0-1.0 range
    fn normalizePressure(self: *TouchInput, weight: u8) f32 {
        if (weight < self.config.pressure_min) return 0.0;
        if (weight >= self.config.pressure_max) return 1.0;

        const range = @as(f32, @floatFromInt(self.config.pressure_max - self.config.pressure_min));
        const value = @as(f32, @floatFromInt(weight - self.config.pressure_min));
        return value / range;
    }

    /// Get all active touches
    pub fn getActiveTouches(self: *TouchInput) []const Touch {
        var result: [2]Touch = undefined;
        var count: usize = 0;

        for (self.touches) |state| {
            if (state.active) {
                result[count] = state.touch;
                count += 1;
            }
        }

        return result[0..count];
    }

    /// Get primary touch (first active touch)
    pub fn getPrimaryTouch(self: *TouchInput) ?Touch {
        for (self.touches) |state| {
            if (state.active) return state.touch;
        }
        return null;
    }

    /// Check if any touch is active
    pub fn isTouched(self: *TouchInput) bool {
        return self.active_count > 0;
    }

    /// Check if multi-touch is active
    pub fn isMultiTouch(self: *TouchInput) bool {
        return self.active_count > 1;
    }

    /// Set touch began callback
    pub fn setOnTouchBegan(self: *TouchInput, callback: *const fn (Touch) void) void {
        self.on_touch_began = callback;
    }

    /// Set touch moved callback
    pub fn setOnTouchMoved(self: *TouchInput, callback: *const fn (Touch) void) void {
        self.on_touch_moved = callback;
    }

    /// Set touch ended callback
    pub fn setOnTouchEnded(self: *TouchInput, callback: *const fn (Touch) void) void {
        self.on_touch_ended = callback;
    }

    /// Calculate distance between two touch points (for pinch)
    pub fn getTouchDistance(self: *TouchInput) ?f32 {
        if (self.active_count < 2) return null;

        const t0 = self.touches[0].touch;
        const t1 = self.touches[1].touch;

        if (!self.touches[0].active or !self.touches[1].active) return null;

        const dx = @as(f32, @floatFromInt(t1.x - t0.x));
        const dy = @as(f32, @floatFromInt(t1.y - t0.y));
        return @sqrt(dx * dx + dy * dy);
    }

    /// Get center point between two touches (for pinch/rotate)
    pub fn getTouchCenter(self: *TouchInput) ?struct { x: i32, y: i32 } {
        if (self.active_count < 2) return null;

        const t0 = self.touches[0].touch;
        const t1 = self.touches[1].touch;

        if (!self.touches[0].active or !self.touches[1].active) return null;

        return .{
            .x = @divTrunc(t0.x + t1.x, 2),
            .y = @divTrunc(t0.y + t1.y, 2),
        };
    }
};

/// Velocity tracker for smooth scrolling
pub const VelocityTracker = struct {
    const HISTORY_SIZE = 10;
    const MAX_AGE_US = 100_000; // 100ms

    history: [HISTORY_SIZE]Sample = undefined,
    count: usize = 0,
    index: usize = 0,

    pub const Sample = struct {
        x: i32,
        y: i32,
        timestamp: u64,
    };

    /// Add a sample
    pub fn addSample(self: *VelocityTracker, x: i32, y: i32, timestamp: u64) void {
        self.history[self.index] = .{
            .x = x,
            .y = y,
            .timestamp = timestamp,
        };
        self.index = (self.index + 1) % HISTORY_SIZE;
        if (self.count < HISTORY_SIZE) self.count += 1;
    }

    /// Calculate velocity in pixels per second
    pub fn getVelocity(self: *VelocityTracker, current_time: u64) struct { vx: f32, vy: f32 } {
        if (self.count < 2) return .{ .vx = 0, .vy = 0 };

        // Find oldest valid sample
        var oldest_idx: ?usize = null;
        var newest_idx: ?usize = null;

        var i: usize = 0;
        while (i < self.count) : (i += 1) {
            const idx = (self.index + HISTORY_SIZE - 1 - i) % HISTORY_SIZE;
            const sample = self.history[idx];
            const age = current_time -| sample.timestamp;

            if (age <= MAX_AGE_US) {
                if (newest_idx == null) newest_idx = idx;
                oldest_idx = idx;
            }
        }

        if (oldest_idx == null or newest_idx == null or oldest_idx == newest_idx) {
            return .{ .vx = 0, .vy = 0 };
        }

        const oldest = self.history[oldest_idx.?];
        const newest = self.history[newest_idx.?];

        const dt = @as(f32, @floatFromInt(newest.timestamp - oldest.timestamp)) / 1_000_000.0;
        if (dt < 0.001) return .{ .vx = 0, .vy = 0 };

        return .{
            .vx = @as(f32, @floatFromInt(newest.x - oldest.x)) / dt,
            .vy = @as(f32, @floatFromInt(newest.y - oldest.y)) / dt,
        };
    }

    /// Clear history
    pub fn clear(self: *VelocityTracker) void {
        self.count = 0;
        self.index = 0;
    }
};

// Tests
test "Touch delta calculation" {
    var touch = Touch{
        .id = 0,
        .x = 150,
        .y = 100,
        .phase = .moved,
        .timestamp = 1000,
        .pressure = 0.5,
        .prev_x = 140,
        .prev_y = 95,
        .start_x = 100,
        .start_y = 50,
        .start_time = 0,
    };

    try std.testing.expectEqual(@as(i32, 10), touch.deltaX());
    try std.testing.expectEqual(@as(i32, 5), touch.deltaY());
}

test "Touch distance from start" {
    var touch = Touch{
        .id = 0,
        .x = 130,
        .y = 90,
        .phase = .moved,
        .timestamp = 1000,
        .pressure = 0.5,
        .start_x = 100,
        .start_y = 50,
        .start_time = 0,
    };

    const distance = touch.distanceFromStart();
    try std.testing.expect(distance > 49.0 and distance < 51.0); // ~50
}

test "TouchConfig defaults" {
    const config = TouchConfig{};
    try std.testing.expectEqual(@as(u16, 320), config.display_width);
    try std.testing.expectEqual(@as(u16, 240), config.display_height);
    try std.testing.expectEqual(TouchConfig.Rotation.portrait, config.rotation);
}

test "VelocityTracker" {
    var tracker = VelocityTracker{};

    tracker.addSample(0, 0, 0);
    tracker.addSample(100, 50, 100_000); // 100ms later

    const velocity = tracker.getVelocity(100_000);
    try std.testing.expect(velocity.vx > 900.0 and velocity.vx < 1100.0); // ~1000 px/s
}
