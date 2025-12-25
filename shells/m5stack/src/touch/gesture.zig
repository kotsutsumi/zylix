//! Gesture Recognition for M5Stack CoreS3
//!
//! Recognizes common touch gestures:
//! - Tap (single, double, triple)
//! - Long press
//! - Swipe (4 directions)
//! - Pinch (zoom in/out)
//! - Rotate
//! - Pan (drag)
//!
//! Gesture state machine processes touch events and emits
//! gesture callbacks when recognized.

const std = @import("std");
const input = @import("input.zig");
const Touch = input.Touch;
const TouchPhase = input.TouchPhase;

/// Gesture types
pub const GestureType = enum {
    tap,
    double_tap,
    triple_tap,
    long_press,
    swipe_left,
    swipe_right,
    swipe_up,
    swipe_down,
    pinch,
    rotate,
    pan,
};

/// Swipe direction
pub const SwipeDirection = enum {
    left,
    right,
    up,
    down,
};

/// Gesture state
pub const GestureState = enum {
    possible, // Gesture may begin
    began, // Gesture started
    changed, // Gesture in progress (continuous gestures)
    ended, // Gesture completed successfully
    cancelled, // Gesture cancelled
    failed, // Gesture failed to match
};

/// Tap gesture data
pub const TapGesture = struct {
    x: i32,
    y: i32,
    tap_count: u8,
    timestamp: u64,
};

/// Long press gesture data
pub const LongPressGesture = struct {
    x: i32,
    y: i32,
    duration_ms: u32,
    state: GestureState,
};

/// Swipe gesture data
pub const SwipeGesture = struct {
    direction: SwipeDirection,
    start_x: i32,
    start_y: i32,
    end_x: i32,
    end_y: i32,
    velocity: f32, // pixels per second
    duration_ms: u32,
};

/// Pinch gesture data
pub const PinchGesture = struct {
    center_x: i32,
    center_y: i32,
    scale: f32, // 1.0 = no change, >1.0 = zoom in, <1.0 = zoom out
    velocity: f32, // scale change per second
    state: GestureState,
};

/// Rotate gesture data
pub const RotateGesture = struct {
    center_x: i32,
    center_y: i32,
    rotation: f32, // radians
    velocity: f32, // radians per second
    state: GestureState,
};

/// Pan gesture data
pub const PanGesture = struct {
    x: i32,
    y: i32,
    delta_x: i32,
    delta_y: i32,
    velocity_x: f32,
    velocity_y: f32,
    state: GestureState,
};

/// Generic gesture event
pub const GestureEvent = union(GestureType) {
    tap: TapGesture,
    double_tap: TapGesture,
    triple_tap: TapGesture,
    long_press: LongPressGesture,
    swipe_left: SwipeGesture,
    swipe_right: SwipeGesture,
    swipe_up: SwipeGesture,
    swipe_down: SwipeGesture,
    pinch: PinchGesture,
    rotate: RotateGesture,
    pan: PanGesture,
};

/// Gesture configuration
pub const GestureConfig = struct {
    // Tap detection
    tap_max_duration_ms: u32 = 300, // Max time for a tap
    tap_max_distance: u16 = 20, // Max movement for a tap
    double_tap_max_interval_ms: u32 = 300, // Max time between taps
    double_tap_max_distance: u16 = 40, // Max distance between taps

    // Long press
    long_press_min_duration_ms: u32 = 500, // Min time for long press
    long_press_max_movement: u16 = 10, // Max movement during long press

    // Swipe detection
    swipe_min_distance: u16 = 50, // Min distance for swipe
    swipe_min_velocity: f32 = 200.0, // Min velocity (px/s)
    swipe_max_duration_ms: u32 = 500, // Max duration for swipe
    swipe_direction_threshold: f32 = 0.5, // Ratio for direction detection

    // Pinch/Rotate
    pinch_min_distance_change: f32 = 10.0, // Min distance change
    rotate_min_angle: f32 = 0.1, // Min rotation angle (radians)

    // Pan
    pan_min_distance: u16 = 5, // Min distance to start pan
};

/// Gesture recognizer
pub const GestureRecognizer = struct {
    config: GestureConfig,

    // Touch tracking
    touch_start: ?Touch = null,
    touch_current: ?Touch = null,
    previous_touches: [2]?Touch = .{ null, null },

    // Tap tracking
    last_tap_time: u64 = 0,
    last_tap_x: i32 = 0,
    last_tap_y: i32 = 0,
    tap_count: u8 = 0,

    // Long press tracking
    long_press_started: bool = false,
    long_press_triggered: bool = false,

    // Multi-touch tracking
    initial_distance: f32 = 0,
    initial_angle: f32 = 0,

    // Pan tracking
    is_panning: bool = false,

    // Velocity tracker
    velocity_tracker: input.VelocityTracker = .{},

    // Current time
    current_time: u64 = 0,

    // Callbacks
    on_gesture: ?*const fn (GestureEvent) void = null,

    /// Initialize gesture recognizer
    pub fn init(config: GestureConfig) GestureRecognizer {
        return .{
            .config = config,
        };
    }

    /// Set gesture callback
    pub fn setOnGesture(self: *GestureRecognizer, callback: *const fn (GestureEvent) void) void {
        self.on_gesture = callback;
    }

    /// Process touch event
    pub fn processTouchEvent(self: *GestureRecognizer, touch: Touch, timestamp_us: u64) void {
        self.current_time = timestamp_us;

        switch (touch.phase) {
            .began => self.handleTouchBegan(touch),
            .moved => self.handleTouchMoved(touch),
            .stationary => self.handleTouchStationary(touch),
            .ended => self.handleTouchEnded(touch),
            .cancelled => self.handleTouchCancelled(touch),
        }
    }

    /// Handle touch began
    fn handleTouchBegan(self: *GestureRecognizer, touch: Touch) void {
        self.touch_start = touch;
        self.touch_current = touch;
        self.long_press_started = true;
        self.long_press_triggered = false;
        self.is_panning = false;
        self.velocity_tracker.clear();
        self.velocity_tracker.addSample(touch.x, touch.y, touch.timestamp);
    }

    /// Handle touch moved
    fn handleTouchMoved(self: *GestureRecognizer, touch: Touch) void {
        self.touch_current = touch;
        self.velocity_tracker.addSample(touch.x, touch.y, touch.timestamp);

        // Check if movement exceeds long press threshold
        if (self.touch_start) |start| {
            const distance = self.distance(start.x, start.y, touch.x, touch.y);
            if (distance > @as(f32, @floatFromInt(self.config.long_press_max_movement))) {
                self.long_press_started = false;
            }
        }

        // Check for pan gesture
        if (!self.is_panning and self.touch_start != null) {
            const start = self.touch_start.?;
            const distance = self.distance(start.x, start.y, touch.x, touch.y);
            if (distance >= @as(f32, @floatFromInt(self.config.pan_min_distance))) {
                self.is_panning = true;
                self.emitGesture(.{ .pan = .{
                    .x = touch.x,
                    .y = touch.y,
                    .delta_x = touch.x - start.x,
                    .delta_y = touch.y - start.y,
                    .velocity_x = 0,
                    .velocity_y = 0,
                    .state = .began,
                } });
            }
        } else if (self.is_panning) {
            // Continue pan
            const velocity = self.velocity_tracker.getVelocity(self.current_time);
            const prev = self.previous_touches[0] orelse self.touch_start.?;
            self.emitGesture(.{ .pan = .{
                .x = touch.x,
                .y = touch.y,
                .delta_x = touch.x - prev.x,
                .delta_y = touch.y - prev.y,
                .velocity_x = velocity.vx,
                .velocity_y = velocity.vy,
                .state = .changed,
            } });
        }

        self.previous_touches[0] = touch;
    }

    /// Handle touch stationary (check for long press)
    fn handleTouchStationary(self: *GestureRecognizer, touch: Touch) void {
        if (self.long_press_started and !self.long_press_triggered) {
            if (self.touch_start) |start| {
                const duration = (self.current_time - start.timestamp) / 1000;
                if (duration >= self.config.long_press_min_duration_ms) {
                    self.long_press_triggered = true;
                    self.emitGesture(.{ .long_press = .{
                        .x = touch.x,
                        .y = touch.y,
                        .duration_ms = @intCast(duration),
                        .state = .began,
                    } });
                }
            }
        }
    }

    /// Handle touch ended
    fn handleTouchEnded(self: *GestureRecognizer, touch: Touch) void {
        defer self.resetState();

        const start = self.touch_start orelse return;
        const duration_ms = (touch.timestamp - start.timestamp) / 1000;
        const travel_distance = self.distance(start.x, start.y, touch.x, touch.y);
        const velocity = self.velocity_tracker.getVelocity(self.current_time);
        const speed = @sqrt(velocity.vx * velocity.vx + velocity.vy * velocity.vy);

        // Check for tap
        if (duration_ms <= self.config.tap_max_duration_ms and
            travel_distance <= @as(f32, @floatFromInt(self.config.tap_max_distance)))
        {
            self.handlePotentialTap(touch);
            return;
        }

        // Check for swipe
        if (duration_ms <= self.config.swipe_max_duration_ms and
            travel_distance >= @as(f32, @floatFromInt(self.config.swipe_min_distance)) and
            speed >= self.config.swipe_min_velocity)
        {
            self.handleSwipe(start, touch, speed, @intCast(duration_ms));
            return;
        }

        // End pan if active
        if (self.is_panning) {
            self.emitGesture(.{ .pan = .{
                .x = touch.x,
                .y = touch.y,
                .delta_x = 0,
                .delta_y = 0,
                .velocity_x = velocity.vx,
                .velocity_y = velocity.vy,
                .state = .ended,
            } });
        }

        // End long press if active
        if (self.long_press_triggered) {
            self.emitGesture(.{ .long_press = .{
                .x = touch.x,
                .y = touch.y,
                .duration_ms = @intCast(duration_ms),
                .state = .ended,
            } });
        }
    }

    /// Handle touch cancelled
    fn handleTouchCancelled(self: *GestureRecognizer, touch: Touch) void {
        if (self.is_panning) {
            self.emitGesture(.{ .pan = .{
                .x = touch.x,
                .y = touch.y,
                .delta_x = 0,
                .delta_y = 0,
                .velocity_x = 0,
                .velocity_y = 0,
                .state = .cancelled,
            } });
        }

        if (self.long_press_triggered) {
            self.emitGesture(.{ .long_press = .{
                .x = touch.x,
                .y = touch.y,
                .duration_ms = 0,
                .state = .cancelled,
            } });
        }

        self.resetState();
    }

    /// Handle potential tap (may be single, double, or triple)
    fn handlePotentialTap(self: *GestureRecognizer, touch: Touch) void {
        const time_since_last_tap = (self.current_time - self.last_tap_time) / 1000;
        const distance_from_last_tap = self.distance(
            self.last_tap_x,
            self.last_tap_y,
            touch.x,
            touch.y,
        );

        if (time_since_last_tap <= self.config.double_tap_max_interval_ms and
            distance_from_last_tap <= @as(f32, @floatFromInt(self.config.double_tap_max_distance)) and
            self.tap_count > 0)
        {
            // Multi-tap
            self.tap_count += 1;

            if (self.tap_count == 2) {
                self.emitGesture(.{ .double_tap = .{
                    .x = touch.x,
                    .y = touch.y,
                    .tap_count = 2,
                    .timestamp = touch.timestamp,
                } });
            } else if (self.tap_count >= 3) {
                self.emitGesture(.{ .triple_tap = .{
                    .x = touch.x,
                    .y = touch.y,
                    .tap_count = self.tap_count,
                    .timestamp = touch.timestamp,
                } });
                self.tap_count = 0; // Reset after triple tap
            }
        } else {
            // Single tap
            self.tap_count = 1;
            self.emitGesture(.{ .tap = .{
                .x = touch.x,
                .y = touch.y,
                .tap_count = 1,
                .timestamp = touch.timestamp,
            } });
        }

        self.last_tap_time = self.current_time;
        self.last_tap_x = touch.x;
        self.last_tap_y = touch.y;
    }

    /// Handle swipe gesture
    fn handleSwipe(self: *GestureRecognizer, start: Touch, end: Touch, velocity: f32, duration_ms: u32) void {
        const dx = end.x - start.x;
        const dy = end.y - start.y;
        const abs_dx = @abs(dx);
        const abs_dy = @abs(dy);

        const direction: SwipeDirection = blk: {
            if (abs_dx > abs_dy) {
                // Horizontal swipe
                const ratio = @as(f32, @floatFromInt(abs_dy)) / @as(f32, @floatFromInt(abs_dx));
                if (ratio <= self.config.swipe_direction_threshold) {
                    break :blk if (dx > 0) SwipeDirection.right else SwipeDirection.left;
                }
            } else {
                // Vertical swipe
                const ratio = @as(f32, @floatFromInt(abs_dx)) / @as(f32, @floatFromInt(abs_dy));
                if (ratio <= self.config.swipe_direction_threshold) {
                    break :blk if (dy > 0) SwipeDirection.down else SwipeDirection.up;
                }
            }
            return; // Not a clear directional swipe
        };

        const swipe_data = SwipeGesture{
            .direction = direction,
            .start_x = start.x,
            .start_y = start.y,
            .end_x = end.x,
            .end_y = end.y,
            .velocity = velocity,
            .duration_ms = duration_ms,
        };

        const gesture: GestureEvent = switch (direction) {
            .left => .{ .swipe_left = swipe_data },
            .right => .{ .swipe_right = swipe_data },
            .up => .{ .swipe_up = swipe_data },
            .down => .{ .swipe_down = swipe_data },
        };

        self.emitGesture(gesture);
    }

    /// Process multi-touch events (for pinch/rotate)
    pub fn processMultiTouch(self: *GestureRecognizer, touches: []const Touch, timestamp_us: u64) void {
        self.current_time = timestamp_us;

        if (touches.len < 2) {
            // End multi-touch gestures
            if (self.initial_distance > 0) {
                self.emitGesture(.{ .pinch = .{
                    .center_x = 0,
                    .center_y = 0,
                    .scale = 1.0,
                    .velocity = 0,
                    .state = .ended,
                } });
                self.initial_distance = 0;
            }
            return;
        }

        const t0 = touches[0];
        const t1 = touches[1];

        const center_x = @divTrunc(t0.x + t1.x, 2);
        const center_y = @divTrunc(t0.y + t1.y, 2);
        const current_distance = self.distance(t0.x, t0.y, t1.x, t1.y);
        const current_angle = std.math.atan2(
            @as(f32, @floatFromInt(t1.y - t0.y)),
            @as(f32, @floatFromInt(t1.x - t0.x)),
        );

        if (self.initial_distance == 0) {
            // Start of multi-touch
            self.initial_distance = current_distance;
            self.initial_angle = current_angle;

            self.emitGesture(.{ .pinch = .{
                .center_x = center_x,
                .center_y = center_y,
                .scale = 1.0,
                .velocity = 0,
                .state = .began,
            } });
        } else {
            // Continued multi-touch
            const scale = current_distance / self.initial_distance;
            const rotation = current_angle - self.initial_angle;

            // Emit pinch
            if (@abs(scale - 1.0) > 0.01) {
                self.emitGesture(.{ .pinch = .{
                    .center_x = center_x,
                    .center_y = center_y,
                    .scale = scale,
                    .velocity = 0, // Would need time tracking for velocity
                    .state = .changed,
                } });
            }

            // Emit rotation
            if (@abs(rotation) >= self.config.rotate_min_angle) {
                self.emitGesture(.{ .rotate = .{
                    .center_x = center_x,
                    .center_y = center_y,
                    .rotation = rotation,
                    .velocity = 0,
                    .state = .changed,
                } });
            }
        }
    }

    /// Emit gesture event
    fn emitGesture(self: *GestureRecognizer, gesture: GestureEvent) void {
        if (self.on_gesture) |callback| {
            callback(gesture);
        }
    }

    /// Calculate distance between two points
    fn distance(self: *GestureRecognizer, x1: i32, y1: i32, x2: i32, y2: i32) f32 {
        _ = self;
        const dx = @as(f32, @floatFromInt(x2 - x1));
        const dy = @as(f32, @floatFromInt(y2 - y1));
        return @sqrt(dx * dx + dy * dy);
    }

    /// Reset gesture state
    fn resetState(self: *GestureRecognizer) void {
        self.touch_start = null;
        self.touch_current = null;
        self.long_press_started = false;
        self.long_press_triggered = false;
        self.is_panning = false;
        self.initial_distance = 0;
        self.initial_angle = 0;
        self.velocity_tracker.clear();
    }

    /// Update (call every frame to check for long press)
    pub fn update(self: *GestureRecognizer, timestamp_us: u64) void {
        self.current_time = timestamp_us;

        // Check for long press trigger
        if (self.long_press_started and !self.long_press_triggered and self.touch_current != null) {
            self.handleTouchStationary(self.touch_current.?);
        }
    }
};

// Tests
test "GestureConfig defaults" {
    const config = GestureConfig{};
    try std.testing.expectEqual(@as(u32, 300), config.tap_max_duration_ms);
    try std.testing.expectEqual(@as(u32, 500), config.long_press_min_duration_ms);
}

test "SwipeDirection enum" {
    try std.testing.expectEqual(SwipeDirection.left, SwipeDirection.left);
    try std.testing.expectEqual(SwipeDirection.right, SwipeDirection.right);
}

test "GestureState enum" {
    try std.testing.expectEqual(GestureState.began, GestureState.began);
    try std.testing.expectEqual(GestureState.ended, GestureState.ended);
}

test "TapGesture initialization" {
    const tap = TapGesture{
        .x = 100,
        .y = 150,
        .tap_count = 2,
        .timestamp = 1000,
    };
    try std.testing.expectEqual(@as(i32, 100), tap.x);
    try std.testing.expectEqual(@as(u8, 2), tap.tap_count);
}
