//! Animation Types - Common types for Zylix Animation module
//!
//! Defines fundamental types used across all animation subsystems:
//! - Time and duration handling
//! - Color and transform types
//! - Animation state and events
//! - Callback signatures

const std = @import("std");

// === Time Types ===

/// Time value in milliseconds
pub const TimeMs = i64;

/// Duration value in milliseconds
pub const DurationMs = u64;

/// Normalized time (0.0 = start, 1.0 = end)
pub const NormalizedTime = f32;

/// Frame number (for frame-based animations)
pub const FrameNumber = u32;

/// Frames per second
pub const FrameRate = f32;

// === Color Types ===

/// RGBA color with 8-bit components
pub const Color = struct {
    r: u8 = 255,
    g: u8 = 255,
    b: u8 = 255,
    a: u8 = 255,

    pub const white = Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
    pub const black = Color{ .r = 0, .g = 0, .b = 0, .a = 255 };
    pub const transparent = Color{ .r = 0, .g = 0, .b = 0, .a = 0 };
    pub const red = Color{ .r = 255, .g = 0, .b = 0, .a = 255 };
    pub const green = Color{ .r = 0, .g = 255, .b = 0, .a = 255 };
    pub const blue = Color{ .r = 0, .g = 0, .b = 255, .a = 255 };

    /// Create from normalized floats (0.0 - 1.0)
    pub fn fromFloat(r: f32, g: f32, b: f32, a: f32) Color {
        return Color{
            .r = @intFromFloat(@max(0, @min(255, r * 255))),
            .g = @intFromFloat(@max(0, @min(255, g * 255))),
            .b = @intFromFloat(@max(0, @min(255, b * 255))),
            .a = @intFromFloat(@max(0, @min(255, a * 255))),
        };
    }

    /// Convert to normalized floats
    pub fn toFloat(self: Color) [4]f32 {
        return .{
            @as(f32, @floatFromInt(self.r)) / 255.0,
            @as(f32, @floatFromInt(self.g)) / 255.0,
            @as(f32, @floatFromInt(self.b)) / 255.0,
            @as(f32, @floatFromInt(self.a)) / 255.0,
        };
    }

    /// Linear interpolation between two colors
    pub fn lerp(self: Color, other: Color, t: f32) Color {
        const t_clamped = @max(0, @min(1, t));
        const inv_t = 1.0 - t_clamped;
        return Color{
            .r = @intFromFloat(@as(f32, @floatFromInt(self.r)) * inv_t + @as(f32, @floatFromInt(other.r)) * t_clamped),
            .g = @intFromFloat(@as(f32, @floatFromInt(self.g)) * inv_t + @as(f32, @floatFromInt(other.g)) * t_clamped),
            .b = @intFromFloat(@as(f32, @floatFromInt(self.b)) * inv_t + @as(f32, @floatFromInt(other.b)) * t_clamped),
            .a = @intFromFloat(@as(f32, @floatFromInt(self.a)) * inv_t + @as(f32, @floatFromInt(other.a)) * t_clamped),
        };
    }
};

// === Transform Types ===

/// 2D Point
pub const Point2D = struct {
    x: f32 = 0,
    y: f32 = 0,

    pub const zero = Point2D{ .x = 0, .y = 0 };

    pub fn add(self: Point2D, other: Point2D) Point2D {
        return .{ .x = self.x + other.x, .y = self.y + other.y };
    }

    pub fn sub(self: Point2D, other: Point2D) Point2D {
        return .{ .x = self.x - other.x, .y = self.y - other.y };
    }

    pub fn scale(self: Point2D, s: f32) Point2D {
        return .{ .x = self.x * s, .y = self.y * s };
    }

    pub fn lerp(self: Point2D, other: Point2D, t: f32) Point2D {
        return .{
            .x = self.x + (other.x - self.x) * t,
            .y = self.y + (other.y - self.y) * t,
        };
    }
};

/// 2D Size
pub const Size2D = struct {
    width: f32 = 0,
    height: f32 = 0,

    pub const zero = Size2D{ .width = 0, .height = 0 };

    pub fn lerp(self: Size2D, other: Size2D, t: f32) Size2D {
        return .{
            .width = self.width + (other.width - self.width) * t,
            .height = self.height + (other.height - self.height) * t,
        };
    }
};

/// 2D Rectangle
pub const Rect2D = struct {
    origin: Point2D = Point2D.zero,
    size: Size2D = Size2D.zero,

    pub fn contains(self: Rect2D, point: Point2D) bool {
        return point.x >= self.origin.x and
            point.x <= self.origin.x + self.size.width and
            point.y >= self.origin.y and
            point.y <= self.origin.y + self.size.height;
    }
};

/// 2D Transform (translation, rotation, scale)
pub const Transform2D = struct {
    position: Point2D = Point2D.zero,
    rotation: f32 = 0, // radians
    scale: Point2D = Point2D{ .x = 1, .y = 1 },
    anchor: Point2D = Point2D{ .x = 0.5, .y = 0.5 }, // normalized (0-1)
    opacity: f32 = 1.0,

    pub const identity = Transform2D{};

    /// Linear interpolation between transforms
    pub fn lerp(self: Transform2D, other: Transform2D, t: f32) Transform2D {
        return .{
            .position = self.position.lerp(other.position, t),
            .rotation = self.rotation + (other.rotation - self.rotation) * t,
            .scale = self.scale.lerp(other.scale, t),
            .anchor = self.anchor.lerp(other.anchor, t),
            .opacity = self.opacity + (other.opacity - self.opacity) * t,
        };
    }
};

/// 3x3 Transformation Matrix
pub const Matrix3x3 = struct {
    m: [9]f32 = .{ 1, 0, 0, 0, 1, 0, 0, 0, 1 },

    pub const identity = Matrix3x3{};

    pub fn multiply(self: Matrix3x3, other: Matrix3x3) Matrix3x3 {
        var result = Matrix3x3{ .m = undefined };
        for (0..3) |row| {
            for (0..3) |col| {
                var sum: f32 = 0;
                for (0..3) |k| {
                    sum += self.m[row * 3 + k] * other.m[k * 3 + col];
                }
                result.m[row * 3 + col] = sum;
            }
        }
        return result;
    }

    pub fn fromTransform(transform: Transform2D) Matrix3x3 {
        const cos_r = @cos(transform.rotation);
        const sin_r = @sin(transform.rotation);
        const sx = transform.scale.x;
        const sy = transform.scale.y;
        const tx = transform.position.x;
        const ty = transform.position.y;

        return Matrix3x3{
            .m = .{
                cos_r * sx, -sin_r * sy, tx,
                sin_r * sx, cos_r * sy,  ty,
                0,          0,           1,
            },
        };
    }
};

// === Animation State ===

/// Animation playback state
pub const PlaybackState = enum(u8) {
    stopped = 0,
    playing = 1,
    paused = 2,
    finished = 3,
};

/// Animation loop mode
pub const LoopMode = enum(u8) {
    none = 0, // Play once
    loop = 1, // Loop forever
    ping_pong = 2, // Play forward then backward
    loop_count = 3, // Loop N times
};

/// Animation direction
pub const PlayDirection = enum(u8) {
    forward = 0,
    reverse = 1,
};

/// Animation blend mode
pub const BlendMode = enum(u8) {
    normal = 0,
    additive = 1,
    multiply = 2,
    screen = 3,
    overlay = 4,
};

/// Fill mode (what happens before/after animation)
pub const FillMode = enum(u8) {
    none = 0, // No effect outside animation
    forwards = 1, // Keep final state
    backwards = 2, // Apply initial state before start
    both = 3, // Both forwards and backwards
};

// === Animation Events ===

/// Animation event type
pub const AnimationEventType = enum(u8) {
    started = 0,
    paused = 1,
    resumed = 2,
    stopped = 3,
    completed = 4,
    loop_completed = 5,
    frame_changed = 6,
    marker_reached = 7,
};

/// Animation event data
pub const AnimationEvent = struct {
    event_type: AnimationEventType,
    animation_id: u32,
    current_frame: FrameNumber = 0,
    current_time: TimeMs = 0,
    loop_count: u32 = 0,
    marker_name: ?[]const u8 = null,
};

// === Callback Types ===

/// Animation event callback
pub const AnimationCallback = *const fn (event: AnimationEvent) void;

/// Frame update callback
pub const FrameCallback = *const fn (frame: FrameNumber, time: NormalizedTime) void;

/// Progress callback (0.0 to 1.0)
pub const ProgressCallback = *const fn (progress: f32) void;

// === Configuration ===

/// Animation playback configuration
pub const PlaybackConfig = struct {
    speed: f32 = 1.0, // Playback speed multiplier
    loop_mode: LoopMode = .none,
    loop_count: u32 = 0, // For loop_count mode
    direction: PlayDirection = .forward,
    auto_play: bool = false,
    fill_mode: FillMode = .none,
    start_frame: ?FrameNumber = null,
    end_frame: ?FrameNumber = null,
    start_time: ?TimeMs = null,
    end_time: ?TimeMs = null,
};

/// Render quality settings
pub const RenderQuality = enum(u8) {
    low = 0, // Fast, lower quality
    medium = 1, // Balanced
    high = 2, // Best quality
};

/// Render configuration
pub const RenderConfig = struct {
    quality: RenderQuality = .medium,
    anti_aliasing: bool = true,
    scale_factor: f32 = 1.0,
    background_color: ?Color = null,
};

// === Result Types ===

/// Animation operation result
pub const AnimationResult = union(enum) {
    success: void,
    @"error": AnimationError,
};

/// Animation error types
pub const AnimationError = enum(u8) {
    none = 0,
    invalid_id = 1,
    invalid_frame = 2,
    invalid_time = 3,
    invalid_data = 4,
    parse_error = 5,
    render_error = 6,
    resource_not_found = 7,
    unsupported_format = 8,
    out_of_memory = 9,
    platform_error = 10,
};

// === Keyframe Types ===

/// Keyframe with value and timing
pub fn Keyframe(comptime T: type) type {
    return struct {
        time: NormalizedTime,
        value: T,
        easing: ?*const fn (f32) f32 = null, // Custom easing function
    };
}

/// Common keyframe types
pub const FloatKeyframe = Keyframe(f32);
pub const Point2DKeyframe = Keyframe(Point2D);
pub const ColorKeyframe = Keyframe(Color);
pub const TransformKeyframe = Keyframe(Transform2D);

// ============================================================================
// Tests
// ============================================================================

test "Color preset values" {
    try std.testing.expectEqual(@as(u8, 255), Color.white.r);
    try std.testing.expectEqual(@as(u8, 255), Color.white.g);
    try std.testing.expectEqual(@as(u8, 255), Color.white.b);
    try std.testing.expectEqual(@as(u8, 255), Color.white.a);

    try std.testing.expectEqual(@as(u8, 0), Color.black.r);
    try std.testing.expectEqual(@as(u8, 0), Color.black.g);
    try std.testing.expectEqual(@as(u8, 0), Color.black.b);
    try std.testing.expectEqual(@as(u8, 255), Color.black.a);

    try std.testing.expectEqual(@as(u8, 0), Color.transparent.a);

    try std.testing.expectEqual(@as(u8, 255), Color.red.r);
    try std.testing.expectEqual(@as(u8, 0), Color.red.g);

    try std.testing.expectEqual(@as(u8, 255), Color.green.g);
    try std.testing.expectEqual(@as(u8, 0), Color.green.r);

    try std.testing.expectEqual(@as(u8, 255), Color.blue.b);
    try std.testing.expectEqual(@as(u8, 0), Color.blue.r);
}

test "Color fromFloat" {
    const white = Color.fromFloat(1.0, 1.0, 1.0, 1.0);
    try std.testing.expectEqual(@as(u8, 255), white.r);
    try std.testing.expectEqual(@as(u8, 255), white.g);
    try std.testing.expectEqual(@as(u8, 255), white.b);
    try std.testing.expectEqual(@as(u8, 255), white.a);

    const black = Color.fromFloat(0.0, 0.0, 0.0, 1.0);
    try std.testing.expectEqual(@as(u8, 0), black.r);
    try std.testing.expectEqual(@as(u8, 0), black.g);
    try std.testing.expectEqual(@as(u8, 0), black.b);

    const half = Color.fromFloat(0.5, 0.5, 0.5, 0.5);
    try std.testing.expect(half.r >= 127 and half.r <= 128);
    try std.testing.expect(half.a >= 127 and half.a <= 128);
}

test "Color toFloat" {
    const floats = Color.white.toFloat();
    try std.testing.expectEqual(@as(f32, 1.0), floats[0]);
    try std.testing.expectEqual(@as(f32, 1.0), floats[1]);
    try std.testing.expectEqual(@as(f32, 1.0), floats[2]);
    try std.testing.expectEqual(@as(f32, 1.0), floats[3]);

    const black_floats = Color.black.toFloat();
    try std.testing.expectEqual(@as(f32, 0.0), black_floats[0]);
    try std.testing.expectEqual(@as(f32, 0.0), black_floats[1]);
    try std.testing.expectEqual(@as(f32, 0.0), black_floats[2]);
}

test "Color lerp" {
    const result_start = Color.black.lerp(Color.white, 0.0);
    try std.testing.expectEqual(@as(u8, 0), result_start.r);

    const result_end = Color.black.lerp(Color.white, 1.0);
    try std.testing.expectEqual(@as(u8, 255), result_end.r);

    const result_mid = Color.black.lerp(Color.white, 0.5);
    try std.testing.expect(result_mid.r >= 127 and result_mid.r <= 128);

    // Test clamping
    const clamped_low = Color.black.lerp(Color.white, -0.5);
    try std.testing.expectEqual(@as(u8, 0), clamped_low.r);

    const clamped_high = Color.black.lerp(Color.white, 1.5);
    try std.testing.expectEqual(@as(u8, 255), clamped_high.r);
}

test "Point2D zero constant" {
    try std.testing.expectEqual(@as(f32, 0), Point2D.zero.x);
    try std.testing.expectEqual(@as(f32, 0), Point2D.zero.y);
}

test "Point2D add" {
    const p1 = Point2D{ .x = 1, .y = 2 };
    const p2 = Point2D{ .x = 3, .y = 4 };
    const result = p1.add(p2);
    try std.testing.expectEqual(@as(f32, 4), result.x);
    try std.testing.expectEqual(@as(f32, 6), result.y);
}

test "Point2D sub" {
    const p1 = Point2D{ .x = 5, .y = 7 };
    const p2 = Point2D{ .x = 2, .y = 3 };
    const result = p1.sub(p2);
    try std.testing.expectEqual(@as(f32, 3), result.x);
    try std.testing.expectEqual(@as(f32, 4), result.y);
}

test "Point2D scale" {
    const p = Point2D{ .x = 2, .y = 3 };
    const result = p.scale(2.5);
    try std.testing.expectEqual(@as(f32, 5), result.x);
    try std.testing.expectEqual(@as(f32, 7.5), result.y);
}

test "Point2D lerp" {
    const p1 = Point2D{ .x = 0, .y = 0 };
    const p2 = Point2D{ .x = 10, .y = 20 };

    const result_start = p1.lerp(p2, 0.0);
    try std.testing.expectEqual(@as(f32, 0), result_start.x);
    try std.testing.expectEqual(@as(f32, 0), result_start.y);

    const result_end = p1.lerp(p2, 1.0);
    try std.testing.expectEqual(@as(f32, 10), result_end.x);
    try std.testing.expectEqual(@as(f32, 20), result_end.y);

    const result_mid = p1.lerp(p2, 0.5);
    try std.testing.expectEqual(@as(f32, 5), result_mid.x);
    try std.testing.expectEqual(@as(f32, 10), result_mid.y);
}

test "Size2D zero constant" {
    try std.testing.expectEqual(@as(f32, 0), Size2D.zero.width);
    try std.testing.expectEqual(@as(f32, 0), Size2D.zero.height);
}

test "Size2D lerp" {
    const s1 = Size2D{ .width = 100, .height = 200 };
    const s2 = Size2D{ .width = 200, .height = 400 };

    const result = s1.lerp(s2, 0.5);
    try std.testing.expectEqual(@as(f32, 150), result.width);
    try std.testing.expectEqual(@as(f32, 300), result.height);
}

test "Rect2D contains" {
    const rect = Rect2D{
        .origin = Point2D{ .x = 10, .y = 10 },
        .size = Size2D{ .width = 100, .height = 50 },
    };

    // Point inside
    try std.testing.expect(rect.contains(Point2D{ .x = 50, .y = 30 }));

    // Point on edge (should be contained)
    try std.testing.expect(rect.contains(Point2D{ .x = 10, .y = 10 }));
    try std.testing.expect(rect.contains(Point2D{ .x = 110, .y = 60 }));

    // Point outside
    try std.testing.expect(!rect.contains(Point2D{ .x = 5, .y = 30 }));
    try std.testing.expect(!rect.contains(Point2D{ .x = 50, .y = 5 }));
    try std.testing.expect(!rect.contains(Point2D{ .x = 120, .y = 30 }));
    try std.testing.expect(!rect.contains(Point2D{ .x = 50, .y = 70 }));
}

test "Transform2D identity" {
    const t = Transform2D.identity;
    try std.testing.expectEqual(@as(f32, 0), t.position.x);
    try std.testing.expectEqual(@as(f32, 0), t.position.y);
    try std.testing.expectEqual(@as(f32, 0), t.rotation);
    try std.testing.expectEqual(@as(f32, 1), t.scale.x);
    try std.testing.expectEqual(@as(f32, 1), t.scale.y);
    try std.testing.expectEqual(@as(f32, 0.5), t.anchor.x);
    try std.testing.expectEqual(@as(f32, 0.5), t.anchor.y);
    try std.testing.expectEqual(@as(f32, 1.0), t.opacity);
}

test "Transform2D lerp" {
    const t1 = Transform2D{
        .position = Point2D{ .x = 0, .y = 0 },
        .rotation = 0,
        .scale = Point2D{ .x = 1, .y = 1 },
        .opacity = 0,
    };
    const t2 = Transform2D{
        .position = Point2D{ .x = 100, .y = 200 },
        .rotation = std.math.pi,
        .scale = Point2D{ .x = 2, .y = 2 },
        .opacity = 1,
    };

    const result = t1.lerp(t2, 0.5);
    try std.testing.expectEqual(@as(f32, 50), result.position.x);
    try std.testing.expectEqual(@as(f32, 100), result.position.y);
    try std.testing.expectApproxEqAbs(@as(f32, std.math.pi / 2.0), result.rotation, 0.001);
    try std.testing.expectEqual(@as(f32, 1.5), result.scale.x);
    try std.testing.expectEqual(@as(f32, 0.5), result.opacity);
}

test "Matrix3x3 identity" {
    const m = Matrix3x3.identity;
    try std.testing.expectEqual(@as(f32, 1), m.m[0]);
    try std.testing.expectEqual(@as(f32, 0), m.m[1]);
    try std.testing.expectEqual(@as(f32, 0), m.m[2]);
    try std.testing.expectEqual(@as(f32, 0), m.m[3]);
    try std.testing.expectEqual(@as(f32, 1), m.m[4]);
    try std.testing.expectEqual(@as(f32, 0), m.m[5]);
    try std.testing.expectEqual(@as(f32, 0), m.m[6]);
    try std.testing.expectEqual(@as(f32, 0), m.m[7]);
    try std.testing.expectEqual(@as(f32, 1), m.m[8]);
}

test "Matrix3x3 multiply identity" {
    const m = Matrix3x3.identity;
    const result = m.multiply(Matrix3x3.identity);

    // Identity * Identity = Identity
    try std.testing.expectEqual(@as(f32, 1), result.m[0]);
    try std.testing.expectEqual(@as(f32, 0), result.m[1]);
    try std.testing.expectEqual(@as(f32, 0), result.m[3]);
    try std.testing.expectEqual(@as(f32, 1), result.m[4]);
    try std.testing.expectEqual(@as(f32, 1), result.m[8]);
}

test "Matrix3x3 fromTransform no rotation" {
    const t = Transform2D{
        .position = Point2D{ .x = 10, .y = 20 },
        .rotation = 0,
        .scale = Point2D{ .x = 2, .y = 3 },
    };
    const m = Matrix3x3.fromTransform(t);

    // Scale x
    try std.testing.expectEqual(@as(f32, 2), m.m[0]);
    // Scale y
    try std.testing.expectEqual(@as(f32, 3), m.m[4]);
    // Translation x
    try std.testing.expectEqual(@as(f32, 10), m.m[2]);
    // Translation y
    try std.testing.expectEqual(@as(f32, 20), m.m[5]);
}

test "Matrix3x3 fromTransform with rotation" {
    const t = Transform2D{
        .position = Point2D.zero,
        .rotation = std.math.pi / 2.0, // 90 degrees
        .scale = Point2D{ .x = 1, .y = 1 },
    };
    const m = Matrix3x3.fromTransform(t);

    // cos(90) ≈ 0, sin(90) ≈ 1
    try std.testing.expectApproxEqAbs(@as(f32, 0), m.m[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -1), m.m[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1), m.m[3], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), m.m[4], 0.001);
}

test "PlaybackState enum values" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(PlaybackState.stopped));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(PlaybackState.playing));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(PlaybackState.paused));
    try std.testing.expectEqual(@as(u8, 3), @intFromEnum(PlaybackState.finished));
}

test "LoopMode enum values" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(LoopMode.none));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(LoopMode.loop));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(LoopMode.ping_pong));
    try std.testing.expectEqual(@as(u8, 3), @intFromEnum(LoopMode.loop_count));
}

test "PlayDirection enum values" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(PlayDirection.forward));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(PlayDirection.reverse));
}

test "BlendMode enum values" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(BlendMode.normal));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(BlendMode.additive));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(BlendMode.multiply));
    try std.testing.expectEqual(@as(u8, 3), @intFromEnum(BlendMode.screen));
    try std.testing.expectEqual(@as(u8, 4), @intFromEnum(BlendMode.overlay));
}

test "FillMode enum values" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(FillMode.none));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(FillMode.forwards));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(FillMode.backwards));
    try std.testing.expectEqual(@as(u8, 3), @intFromEnum(FillMode.both));
}

test "AnimationEventType enum values" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(AnimationEventType.started));
    try std.testing.expectEqual(@as(u8, 4), @intFromEnum(AnimationEventType.completed));
    try std.testing.expectEqual(@as(u8, 7), @intFromEnum(AnimationEventType.marker_reached));
}

test "AnimationError enum values" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(AnimationError.none));
    try std.testing.expectEqual(@as(u8, 5), @intFromEnum(AnimationError.parse_error));
    try std.testing.expectEqual(@as(u8, 9), @intFromEnum(AnimationError.out_of_memory));
    try std.testing.expectEqual(@as(u8, 10), @intFromEnum(AnimationError.platform_error));
}

test "RenderQuality enum values" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(RenderQuality.low));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(RenderQuality.medium));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(RenderQuality.high));
}

test "AnimationEvent default values" {
    const event = AnimationEvent{
        .event_type = .started,
        .animation_id = 42,
    };
    try std.testing.expectEqual(AnimationEventType.started, event.event_type);
    try std.testing.expectEqual(@as(u32, 42), event.animation_id);
    try std.testing.expectEqual(@as(FrameNumber, 0), event.current_frame);
    try std.testing.expectEqual(@as(TimeMs, 0), event.current_time);
    try std.testing.expectEqual(@as(u32, 0), event.loop_count);
    try std.testing.expectEqual(@as(?[]const u8, null), event.marker_name);
}

test "PlaybackConfig default values" {
    const config = PlaybackConfig{};
    try std.testing.expectEqual(@as(f32, 1.0), config.speed);
    try std.testing.expectEqual(LoopMode.none, config.loop_mode);
    try std.testing.expectEqual(@as(u32, 0), config.loop_count);
    try std.testing.expectEqual(PlayDirection.forward, config.direction);
    try std.testing.expectEqual(false, config.auto_play);
    try std.testing.expectEqual(FillMode.none, config.fill_mode);
}

test "RenderConfig default values" {
    const config = RenderConfig{};
    try std.testing.expectEqual(RenderQuality.medium, config.quality);
    try std.testing.expectEqual(true, config.anti_aliasing);
    try std.testing.expectEqual(@as(f32, 1.0), config.scale_factor);
    try std.testing.expectEqual(@as(?Color, null), config.background_color);
}

test "AnimationResult union" {
    const success = AnimationResult{ .success = {} };
    try std.testing.expect(success == .success);

    const err = AnimationResult{ .@"error" = .invalid_id };
    try std.testing.expect(err == .@"error");
    try std.testing.expectEqual(AnimationError.invalid_id, err.@"error");
}

test "Keyframe generic type" {
    const keyframe = FloatKeyframe{
        .time = 0.5,
        .value = 100.0,
        .easing = null,
    };
    try std.testing.expectEqual(@as(NormalizedTime, 0.5), keyframe.time);
    try std.testing.expectEqual(@as(f32, 100.0), keyframe.value);
    try std.testing.expectEqual(@as(?*const fn (f32) f32, null), keyframe.easing);
}

test "Point2DKeyframe" {
    const keyframe = Point2DKeyframe{
        .time = 0.75,
        .value = Point2D{ .x = 50, .y = 100 },
    };
    try std.testing.expectEqual(@as(NormalizedTime, 0.75), keyframe.time);
    try std.testing.expectEqual(@as(f32, 50), keyframe.value.x);
    try std.testing.expectEqual(@as(f32, 100), keyframe.value.y);
}

test "ColorKeyframe" {
    const keyframe = ColorKeyframe{
        .time = 1.0,
        .value = Color.red,
    };
    try std.testing.expectEqual(@as(NormalizedTime, 1.0), keyframe.time);
    try std.testing.expectEqual(@as(u8, 255), keyframe.value.r);
    try std.testing.expectEqual(@as(u8, 0), keyframe.value.g);
}

test "TransformKeyframe" {
    const keyframe = TransformKeyframe{
        .time = 0.0,
        .value = Transform2D.identity,
    };
    try std.testing.expectEqual(@as(NormalizedTime, 0.0), keyframe.time);
    try std.testing.expectEqual(@as(f32, 0), keyframe.value.rotation);
}
