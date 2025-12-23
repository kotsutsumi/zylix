//! Zylix Gesture - Gesture Recognizers
//!
//! Individual gesture recognizer implementations.

const std = @import("std");
const types = @import("types.zig");

pub const Point = types.Point;
pub const Touch = types.Touch;
pub const TouchEvent = types.TouchEvent;
pub const TouchPhase = types.TouchPhase;
pub const GestureState = types.GestureState;
pub const SwipeDirection = types.SwipeDirection;
pub const Velocity = types.Velocity;

// === Base Recognizer ===

/// Base gesture recognizer configuration
pub const RecognizerConfig = struct {
    id: u32 = 0,
    enabled: bool = true,
    cancels_touches_in_view: bool = true,
    delays_touches_began: bool = false,
    delays_touches_ended: bool = false,
    requires_exclusive_touch: bool = false,
};

// === Tap Recognizer ===

/// Tap gesture configuration
pub const TapConfig = struct {
    base: RecognizerConfig = .{},
    number_of_taps_required: u8 = 1,
    number_of_touches_required: u8 = 1,
    max_tap_duration_ms: u32 = 500,
    max_tap_distance: f64 = 10, // Max movement allowed
    max_time_between_taps_ms: u32 = 300, // For multi-tap
};

/// Tap gesture recognizer
pub const TapRecognizer = struct {
    config: TapConfig = .{},
    state: GestureState = .possible,
    location: Point = .{},
    tap_count: u8 = 0,
    start_time: i64 = 0,
    start_location: Point = .{},
    last_tap_time: i64 = 0,

    callback: ?*const fn (*TapRecognizer) void = null,

    const Self = @This();

    pub fn init(config: TapConfig) Self {
        return .{ .config = config };
    }

    pub fn reset(self: *Self) void {
        self.state = .possible;
        self.tap_count = 0;
    }

    pub fn handleTouch(self: *Self, event: TouchEvent) void {
        if (!self.config.base.enabled) return;
        if (event.touch_count != self.config.number_of_touches_required) {
            self.state = .failed;
            return;
        }

        const touch = event.touches[0] orelse return;

        switch (touch.phase) {
            .began => {
                self.start_time = touch.timestamp;
                self.start_location = touch.location;
                self.location = touch.location;
            },
            .moved => {
                // Check if moved too far
                if (self.start_location.distance(touch.location) > self.config.max_tap_distance) {
                    self.state = .failed;
                }
            },
            .ended => {
                const duration = touch.timestamp - self.start_time;
                if (duration > self.config.max_tap_duration_ms) {
                    self.state = .failed;
                    return;
                }

                // Check distance from start
                if (self.start_location.distance(touch.location) > self.config.max_tap_distance) {
                    self.state = .failed;
                    return;
                }

                // Increment tap count
                self.tap_count += 1;
                self.location = touch.location;

                // Check if we reached required taps
                if (self.tap_count >= self.config.number_of_taps_required) {
                    self.state = .ended;
                    if (self.callback) |cb| cb(self);
                    self.reset();
                } else {
                    self.last_tap_time = touch.timestamp;
                }
            },
            .cancelled => {
                self.state = .cancelled;
                self.reset();
            },
            else => {},
        }
    }
};

// === Long Press Recognizer ===

/// Long press configuration
pub const LongPressConfig = struct {
    base: RecognizerConfig = .{},
    minimum_press_duration_ms: u32 = 500,
    number_of_touches_required: u8 = 1,
    allowable_movement: f64 = 10,
};

/// Long press recognizer
pub const LongPressRecognizer = struct {
    config: LongPressConfig = .{},
    state: GestureState = .possible,
    location: Point = .{},
    start_time: i64 = 0,
    start_location: Point = .{},

    callback: ?*const fn (*LongPressRecognizer) void = null,

    const Self = @This();

    pub fn init(config: LongPressConfig) Self {
        return .{ .config = config };
    }

    pub fn reset(self: *Self) void {
        self.state = .possible;
    }

    pub fn handleTouch(self: *Self, event: TouchEvent) void {
        if (!self.config.base.enabled) return;
        if (event.touch_count != self.config.number_of_touches_required) {
            self.state = .failed;
            return;
        }

        const touch = event.touches[0] orelse return;

        switch (touch.phase) {
            .began => {
                self.start_time = touch.timestamp;
                self.start_location = touch.location;
                self.location = touch.location;
            },
            .moved => {
                self.location = touch.location;
                if (self.start_location.distance(touch.location) > self.config.allowable_movement) {
                    if (self.state.isActive()) {
                        self.state = .cancelled;
                        if (self.callback) |cb| cb(self);
                    } else {
                        self.state = .failed;
                    }
                }
            },
            .stationary => {
                // Check if long press duration reached
                const duration = touch.timestamp - self.start_time;
                if (self.state == .possible and duration >= self.config.minimum_press_duration_ms) {
                    self.state = .began;
                    if (self.callback) |cb| cb(self);
                }
            },
            .ended => {
                if (self.state.isActive()) {
                    self.state = .ended;
                    if (self.callback) |cb| cb(self);
                }
                self.reset();
            },
            .cancelled => {
                if (self.state.isActive()) {
                    self.state = .cancelled;
                    if (self.callback) |cb| cb(self);
                }
                self.reset();
            },
        }
    }

    /// Update for timer-based recognition (call periodically)
    pub fn update(self: *Self, current_time: i64) void {
        if (self.state != .possible) return;

        const duration = current_time - self.start_time;
        if (duration >= self.config.minimum_press_duration_ms) {
            self.state = .began;
            if (self.callback) |cb| cb(self);
        }
    }
};

// === Pan Recognizer ===

/// Pan (drag) configuration
pub const PanConfig = struct {
    base: RecognizerConfig = .{},
    minimum_number_of_touches: u8 = 1,
    maximum_number_of_touches: u8 = 10,
    min_translation: f64 = 10, // Min movement to recognize
};

/// Pan recognizer
pub const PanRecognizer = struct {
    config: PanConfig = .{},
    state: GestureState = .possible,
    translation: Point = .{},
    velocity: Velocity = .{},
    start_location: Point = .{},
    current_location: Point = .{},
    last_location: Point = .{},
    last_time: i64 = 0,

    callback: ?*const fn (*PanRecognizer) void = null,

    const Self = @This();

    pub fn init(config: PanConfig) Self {
        return .{ .config = config };
    }

    pub fn reset(self: *Self) void {
        self.state = .possible;
        self.translation = .{};
        self.velocity = .{};
    }

    pub fn handleTouch(self: *Self, event: TouchEvent) void {
        if (!self.config.base.enabled) return;
        if (event.touch_count < self.config.minimum_number_of_touches or
            event.touch_count > self.config.maximum_number_of_touches)
        {
            if (self.state.isActive()) {
                self.state = .ended;
                if (self.callback) |cb| cb(self);
            }
            return;
        }

        // Calculate centroid of all touches
        var sum_x: f64 = 0;
        var sum_y: f64 = 0;
        var count: f64 = 0;
        for (event.touches[0..event.touch_count]) |t| {
            if (t) |touch| {
                sum_x += touch.location.x;
                sum_y += touch.location.y;
                count += 1;
            }
        }
        const centroid = Point{ .x = sum_x / count, .y = sum_y / count };

        const touch = event.touches[0] orelse return;

        switch (touch.phase) {
            .began => {
                self.start_location = centroid;
                self.current_location = centroid;
                self.last_location = centroid;
                self.last_time = touch.timestamp;
            },
            .moved => {
                self.current_location = centroid;
                self.translation = centroid.subtract(self.start_location);

                // Calculate velocity
                const time_delta = @as(f64, @floatFromInt(touch.timestamp - self.last_time)) / 1000.0;
                if (time_delta > 0) {
                    self.velocity = .{
                        .x = (centroid.x - self.last_location.x) / time_delta,
                        .y = (centroid.y - self.last_location.y) / time_delta,
                    };
                }

                // Check if should begin
                if (self.state == .possible) {
                    const dist = self.start_location.distance(centroid);
                    if (dist >= self.config.min_translation) {
                        self.state = .began;
                        if (self.callback) |cb| cb(self);
                    }
                } else if (self.state == .began or self.state == .changed) {
                    self.state = .changed;
                    if (self.callback) |cb| cb(self);
                }

                self.last_location = centroid;
                self.last_time = touch.timestamp;
            },
            .ended => {
                if (self.state.isActive()) {
                    self.state = .ended;
                    if (self.callback) |cb| cb(self);
                }
                self.reset();
            },
            .cancelled => {
                if (self.state.isActive()) {
                    self.state = .cancelled;
                    if (self.callback) |cb| cb(self);
                }
                self.reset();
            },
            else => {},
        }
    }

    /// Set translation (for resetting relative movement)
    pub fn setTranslation(self: *Self, translation: Point) void {
        self.start_location = self.current_location.subtract(translation);
        self.translation = translation;
    }
};

// === Swipe Recognizer ===

/// Swipe configuration
pub const SwipeConfig = struct {
    base: RecognizerConfig = .{},
    direction: SwipeDirection = .right,
    number_of_touches_required: u8 = 1,
    min_velocity: f64 = 300, // Points per second
    min_distance: f64 = 50, // Minimum swipe distance
    max_angle_deviation: f64 = 45, // Degrees from horizontal/vertical
};

/// Swipe recognizer
pub const SwipeRecognizer = struct {
    config: SwipeConfig = .{},
    state: GestureState = .possible,
    location: Point = .{},
    start_location: Point = .{},
    start_time: i64 = 0,

    callback: ?*const fn (*SwipeRecognizer) void = null,

    const Self = @This();

    pub fn init(config: SwipeConfig) Self {
        return .{ .config = config };
    }

    pub fn reset(self: *Self) void {
        self.state = .possible;
    }

    pub fn handleTouch(self: *Self, event: TouchEvent) void {
        if (!self.config.base.enabled) return;
        if (event.touch_count != self.config.number_of_touches_required) {
            self.state = .failed;
            return;
        }

        const touch = event.touches[0] orelse return;

        switch (touch.phase) {
            .began => {
                self.start_location = touch.location;
                self.start_time = touch.timestamp;
            },
            .ended => {
                self.location = touch.location;
                const dx = touch.location.x - self.start_location.x;
                const dy = touch.location.y - self.start_location.y;
                const distance = self.start_location.distance(touch.location);
                const time_delta = @as(f64, @floatFromInt(touch.timestamp - self.start_time)) / 1000.0;

                if (distance < self.config.min_distance or time_delta <= 0) {
                    self.state = .failed;
                    return;
                }

                const velocity = distance / time_delta;
                if (velocity < self.config.min_velocity) {
                    self.state = .failed;
                    return;
                }

                // Determine actual direction
                const angle = std.math.atan2(dy, dx) * 180 / std.math.pi;
                const detected_direction = detectDirection(angle);

                if (detected_direction == self.config.direction) {
                    self.state = .ended;
                    if (self.callback) |cb| cb(self);
                } else {
                    self.state = .failed;
                }

                self.reset();
            },
            .cancelled => {
                self.state = .cancelled;
                self.reset();
            },
            else => {},
        }
    }

    fn detectDirection(angle: f64) SwipeDirection {
        // angle: -180 to 180 degrees
        if (angle >= -45 and angle < 45) return .right;
        if (angle >= 45 and angle < 135) return .down;
        if (angle >= -135 and angle < -45) return .up;
        return .left;
    }
};

// === Pinch Recognizer ===

/// Pinch configuration
pub const PinchConfig = struct {
    base: RecognizerConfig = .{},
    min_scale_threshold: f64 = 0.05, // Min scale change to recognize
};

/// Pinch (zoom) recognizer
pub const PinchRecognizer = struct {
    config: PinchConfig = .{},
    state: GestureState = .possible,
    scale: f64 = 1.0,
    velocity: f64 = 0, // Scale per second
    initial_distance: f64 = 0,
    current_distance: f64 = 0,
    center: Point = .{},
    last_scale: f64 = 1.0,
    last_time: i64 = 0,

    callback: ?*const fn (*PinchRecognizer) void = null,

    const Self = @This();

    pub fn init(config: PinchConfig) Self {
        return .{ .config = config };
    }

    pub fn reset(self: *Self) void {
        self.state = .possible;
        self.scale = 1.0;
        self.velocity = 0;
    }

    pub fn handleTouch(self: *Self, event: TouchEvent) void {
        if (!self.config.base.enabled) return;
        if (event.touch_count < 2) {
            if (self.state.isActive()) {
                self.state = .ended;
                if (self.callback) |cb| cb(self);
            }
            return;
        }

        const touch1 = event.touches[0] orelse return;
        const touch2 = event.touches[1] orelse return;

        self.current_distance = touch1.location.distance(touch2.location);
        self.center = touch1.location.midpoint(touch2.location);

        switch (touch1.phase) {
            .began => {
                self.initial_distance = self.current_distance;
                self.last_time = touch1.timestamp;
                self.last_scale = 1.0;
            },
            .moved => {
                if (self.initial_distance > 0) {
                    self.scale = self.current_distance / self.initial_distance;

                    // Calculate velocity
                    const time_delta = @as(f64, @floatFromInt(touch1.timestamp - self.last_time)) / 1000.0;
                    if (time_delta > 0) {
                        self.velocity = (self.scale - self.last_scale) / time_delta;
                    }

                    // Check if should begin
                    if (self.state == .possible) {
                        if (@abs(self.scale - 1.0) >= self.config.min_scale_threshold) {
                            self.state = .began;
                            if (self.callback) |cb| cb(self);
                        }
                    } else if (self.state == .began or self.state == .changed) {
                        self.state = .changed;
                        if (self.callback) |cb| cb(self);
                    }

                    self.last_scale = self.scale;
                    self.last_time = touch1.timestamp;
                }
            },
            .ended, .cancelled => {
                if (self.state.isActive()) {
                    self.state = if (touch1.phase == .ended) .ended else .cancelled;
                    if (self.callback) |cb| cb(self);
                }
                self.reset();
            },
            else => {},
        }
    }
};

// === Rotation Recognizer ===

/// Rotation configuration
pub const RotationConfig = struct {
    base: RecognizerConfig = .{},
    min_rotation_threshold: f64 = 0.05, // Radians
};

/// Rotation recognizer
pub const RotationRecognizer = struct {
    config: RotationConfig = .{},
    state: GestureState = .possible,
    rotation: f64 = 0, // Radians
    velocity: f64 = 0, // Radians per second
    initial_angle: f64 = 0,
    center: Point = .{},
    last_rotation: f64 = 0,
    last_time: i64 = 0,

    callback: ?*const fn (*RotationRecognizer) void = null,

    const Self = @This();

    pub fn init(config: RotationConfig) Self {
        return .{ .config = config };
    }

    pub fn reset(self: *Self) void {
        self.state = .possible;
        self.rotation = 0;
        self.velocity = 0;
    }

    pub fn handleTouch(self: *Self, event: TouchEvent) void {
        if (!self.config.base.enabled) return;
        if (event.touch_count < 2) {
            if (self.state.isActive()) {
                self.state = .ended;
                if (self.callback) |cb| cb(self);
            }
            return;
        }

        const touch1 = event.touches[0] orelse return;
        const touch2 = event.touches[1] orelse return;

        const dx = touch2.location.x - touch1.location.x;
        const dy = touch2.location.y - touch1.location.y;
        const current_angle = std.math.atan2(dy, dx);

        self.center = touch1.location.midpoint(touch2.location);

        switch (touch1.phase) {
            .began => {
                self.initial_angle = current_angle;
                self.last_time = touch1.timestamp;
                self.last_rotation = 0;
            },
            .moved => {
                self.rotation = normalizeAngle(current_angle - self.initial_angle);

                // Calculate velocity
                const time_delta = @as(f64, @floatFromInt(touch1.timestamp - self.last_time)) / 1000.0;
                if (time_delta > 0) {
                    self.velocity = (self.rotation - self.last_rotation) / time_delta;
                }

                // Check if should begin
                if (self.state == .possible) {
                    if (@abs(self.rotation) >= self.config.min_rotation_threshold) {
                        self.state = .began;
                        if (self.callback) |cb| cb(self);
                    }
                } else if (self.state == .began or self.state == .changed) {
                    self.state = .changed;
                    if (self.callback) |cb| cb(self);
                }

                self.last_rotation = self.rotation;
                self.last_time = touch1.timestamp;
            },
            .ended, .cancelled => {
                if (self.state.isActive()) {
                    self.state = if (touch1.phase == .ended) .ended else .cancelled;
                    if (self.callback) |cb| cb(self);
                }
                self.reset();
            },
            else => {},
        }
    }

    fn normalizeAngle(angle: f64) f64 {
        var a = angle;
        while (a > std.math.pi) a -= 2 * std.math.pi;
        while (a < -std.math.pi) a += 2 * std.math.pi;
        return a;
    }
};

// === Tests ===

test "TapRecognizer initialization" {
    const recognizer = TapRecognizer.init(.{});
    try std.testing.expectEqual(GestureState.possible, recognizer.state);
    try std.testing.expectEqual(@as(u8, 1), recognizer.config.number_of_taps_required);
}

test "PanRecognizer translation" {
    var recognizer = PanRecognizer.init(.{});
    recognizer.current_location = .{ .x = 100, .y = 200 };
    recognizer.setTranslation(.{ .x = 50, .y = 50 });
    try std.testing.expectApproxEqAbs(@as(f64, 50), recognizer.translation.x, 0.001);
}

test "SwipeRecognizer direction detection" {
    const recognizer = SwipeRecognizer.init(.{ .direction = .right });
    try std.testing.expectEqual(SwipeDirection.right, recognizer.config.direction);
}

test "PinchRecognizer initialization" {
    const recognizer = PinchRecognizer.init(.{});
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), recognizer.scale, 0.001);
}

test "RotationRecognizer initialization" {
    const recognizer = RotationRecognizer.init(.{});
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), recognizer.rotation, 0.001);
}
