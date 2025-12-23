//! Zylix Gesture - Common Types
//!
//! Shared types for gesture recognition system.

const std = @import("std");

// === Point and Touch Types ===

/// 2D point
pub const Point = struct {
    x: f64 = 0,
    y: f64 = 0,

    pub fn distance(self: Point, other: Point) f64 {
        const dx = other.x - self.x;
        const dy = other.y - self.y;
        return @sqrt(dx * dx + dy * dy);
    }

    pub fn midpoint(self: Point, other: Point) Point {
        return .{
            .x = (self.x + other.x) / 2,
            .y = (self.y + other.y) / 2,
        };
    }

    pub fn add(self: Point, other: Point) Point {
        return .{ .x = self.x + other.x, .y = self.y + other.y };
    }

    pub fn subtract(self: Point, other: Point) Point {
        return .{ .x = self.x - other.x, .y = self.y - other.y };
    }
};

/// Touch phase
pub const TouchPhase = enum(u8) {
    began = 0,
    moved = 1,
    stationary = 2,
    ended = 3,
    cancelled = 4,
};

/// Touch type
pub const TouchType = enum(u8) {
    direct = 0, // Finger on screen
    indirect = 1, // Trackpad
    pencil = 2, // Apple Pencil
    stylus = 3, // Generic stylus
};

/// Individual touch point
pub const Touch = struct {
    id: u32 = 0, // Unique touch identifier
    location: Point = .{},
    previous_location: Point = .{},
    phase: TouchPhase = .began,
    touch_type: TouchType = .direct,
    timestamp: i64 = 0,
    force: f64 = 0, // 0.0 - 1.0 (if supported)
    major_radius: f64 = 0, // Touch area
    altitude_angle: f64 = 0, // Stylus angle from surface (radians)
    azimuth_angle: f64 = 0, // Stylus direction (radians)

    /// Get velocity (points per second)
    pub fn velocity(self: Touch, time_delta: f64) Point {
        if (time_delta <= 0) return .{};
        const dx = self.location.x - self.previous_location.x;
        const dy = self.location.y - self.previous_location.y;
        return .{
            .x = dx / time_delta,
            .y = dy / time_delta,
        };
    }
};

/// Touch event containing all current touches
pub const TouchEvent = struct {
    touches: [10]?Touch = [_]?Touch{null} ** 10,
    touch_count: usize = 0,
    timestamp: i64 = 0,

    pub fn addTouch(self: *TouchEvent, touch: Touch) bool {
        if (self.touch_count >= 10) return false;
        self.touches[self.touch_count] = touch;
        self.touch_count += 1;
        return true;
    }

    pub fn getTouch(self: *const TouchEvent, id: u32) ?Touch {
        for (self.touches[0..self.touch_count]) |t| {
            if (t) |touch| {
                if (touch.id == id) return touch;
            }
        }
        return null;
    }

    pub fn activeTouches(self: *const TouchEvent) []const ?Touch {
        return self.touches[0..self.touch_count];
    }
};

// === Gesture State ===

/// Gesture recognizer state
pub const GestureState = enum(u8) {
    possible = 0, // Default state, gesture may begin
    began = 1, // Gesture has been recognized
    changed = 2, // Gesture is in progress
    ended = 3, // Gesture completed successfully
    cancelled = 4, // Gesture was cancelled
    failed = 5, // Gesture recognition failed

    pub fn isActive(self: GestureState) bool {
        return self == .began or self == .changed;
    }

    pub fn isEnded(self: GestureState) bool {
        return self == .ended or self == .cancelled or self == .failed;
    }
};

// === Direction Types ===

/// Swipe direction
pub const SwipeDirection = enum(u8) {
    up = 0,
    down = 1,
    left = 2,
    right = 3,

    pub fn isHorizontal(self: SwipeDirection) bool {
        return self == .left or self == .right;
    }

    pub fn isVertical(self: SwipeDirection) bool {
        return self == .up or self == .down;
    }

    pub fn opposite(self: SwipeDirection) SwipeDirection {
        return switch (self) {
            .up => .down,
            .down => .up,
            .left => .right,
            .right => .left,
        };
    }
};

/// Edge for edge gestures
pub const Edge = enum(u8) {
    top = 0,
    bottom = 1,
    left = 2,
    right = 3,
    all = 255,
};

// === Velocity ===

/// 2D velocity (points per second)
pub const Velocity = struct {
    x: f64 = 0,
    y: f64 = 0,

    pub fn magnitude(self: Velocity) f64 {
        return @sqrt(self.x * self.x + self.y * self.y);
    }

    pub fn direction(self: Velocity) f64 {
        return std.math.atan2(self.y, self.x);
    }
};

// === Transform Types ===

/// 2D affine transform
pub const Transform = struct {
    a: f64 = 1, // scale x
    b: f64 = 0, // shear y
    c: f64 = 0, // shear x
    d: f64 = 1, // scale y
    tx: f64 = 0, // translate x
    ty: f64 = 0, // translate y

    pub const identity = Transform{};

    pub fn scale(sx: f64, sy: f64) Transform {
        return .{ .a = sx, .d = sy };
    }

    pub fn translate(tx: f64, ty: f64) Transform {
        return .{ .tx = tx, .ty = ty };
    }

    pub fn rotate(angle: f64) Transform {
        const cos_a = @cos(angle);
        const sin_a = @sin(angle);
        return .{ .a = cos_a, .b = sin_a, .c = -sin_a, .d = cos_a };
    }

    pub fn concat(self: Transform, other: Transform) Transform {
        return .{
            .a = self.a * other.a + self.b * other.c,
            .b = self.a * other.b + self.b * other.d,
            .c = self.c * other.a + self.d * other.c,
            .d = self.c * other.b + self.d * other.d,
            .tx = self.tx * other.a + self.ty * other.c + other.tx,
            .ty = self.tx * other.b + self.ty * other.d + other.ty,
        };
    }

    pub fn apply(self: Transform, point: Point) Point {
        return .{
            .x = self.a * point.x + self.c * point.y + self.tx,
            .y = self.b * point.x + self.d * point.y + self.ty,
        };
    }
};

// === Callback Types ===

/// Generic gesture callback
pub const GestureCallback = *const fn (gesture_id: u32, state: GestureState, data: ?*anyopaque) void;

// === Tests ===

test "Point operations" {
    const p1 = Point{ .x = 0, .y = 0 };
    const p2 = Point{ .x = 3, .y = 4 };

    try std.testing.expectApproxEqAbs(@as(f64, 5.0), p1.distance(p2), 0.001);

    const mid = p1.midpoint(p2);
    try std.testing.expectApproxEqAbs(@as(f64, 1.5), mid.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 2.0), mid.y, 0.001);
}

test "Touch velocity" {
    const touch = Touch{
        .location = .{ .x = 100, .y = 200 },
        .previous_location = .{ .x = 90, .y = 180 },
    };
    const vel = touch.velocity(0.1); // 100ms
    try std.testing.expectApproxEqAbs(@as(f64, 100), vel.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 200), vel.y, 0.001);
}

test "GestureState checks" {
    try std.testing.expect(GestureState.began.isActive());
    try std.testing.expect(GestureState.changed.isActive());
    try std.testing.expect(!GestureState.ended.isActive());
    try std.testing.expect(GestureState.ended.isEnded());
}

test "SwipeDirection" {
    try std.testing.expect(SwipeDirection.left.isHorizontal());
    try std.testing.expect(SwipeDirection.up.isVertical());
    try std.testing.expectEqual(SwipeDirection.down, SwipeDirection.up.opposite());
}

test "Transform operations" {
    const scale = Transform.scale(2, 2);
    const point = Point{ .x = 10, .y = 20 };
    const scaled = scale.apply(point);
    try std.testing.expectApproxEqAbs(@as(f64, 20), scaled.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 40), scaled.y, 0.001);
}

test "TouchEvent management" {
    var event = TouchEvent{};
    try std.testing.expect(event.addTouch(.{ .id = 1, .location = .{ .x = 100, .y = 200 } }));
    try std.testing.expect(event.addTouch(.{ .id = 2, .location = .{ .x = 150, .y = 250 } }));
    try std.testing.expectEqual(@as(usize, 2), event.touch_count);

    const touch = event.getTouch(1);
    try std.testing.expect(touch != null);
    try std.testing.expectApproxEqAbs(@as(f64, 100), touch.?.location.x, 0.001);
}
