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
