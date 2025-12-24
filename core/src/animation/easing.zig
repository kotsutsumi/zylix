//! Easing Functions - Mathematical easing for smooth animations
//!
//! Provides a comprehensive library of easing functions following
//! standard naming conventions (ease-in, ease-out, ease-in-out).
//!
//! All functions take a normalized time value (0.0 to 1.0) and
//! return a normalized progress value.
//!
//! ## Usage
//!
//! ```zig
//! const easing = @import("easing.zig");
//!
//! // Simple usage
//! const progress = easing.easeOutCubic(t);
//!
//! // Custom bezier curve
//! const custom = easing.CubicBezier.init(0.42, 0, 0.58, 1);
//! const bezier_progress = custom.evaluate(t);
//! ```

const std = @import("std");
const math = std.math;

/// PI constant
const PI: f32 = 3.14159265358979323846;

// === Linear ===

/// Linear interpolation (no easing)
pub fn linear(t: f32) f32 {
    return t;
}

// === Quadratic (power of 2) ===

/// Quadratic ease-in: accelerate from zero velocity
pub fn easeInQuad(t: f32) f32 {
    return t * t;
}

/// Quadratic ease-out: decelerate to zero velocity
pub fn easeOutQuad(t: f32) f32 {
    return t * (2 - t);
}

/// Quadratic ease-in-out: accelerate until halfway, then decelerate
pub fn easeInOutQuad(t: f32) f32 {
    if (t < 0.5) {
        return 2 * t * t;
    } else {
        return -1 + (4 - 2 * t) * t;
    }
}

// === Cubic (power of 3) ===

/// Cubic ease-in
pub fn easeInCubic(t: f32) f32 {
    return t * t * t;
}

/// Cubic ease-out
pub fn easeOutCubic(t: f32) f32 {
    const f = t - 1;
    return f * f * f + 1;
}

/// Cubic ease-in-out
pub fn easeInOutCubic(t: f32) f32 {
    if (t < 0.5) {
        return 4 * t * t * t;
    } else {
        const f = 2 * t - 2;
        return 0.5 * f * f * f + 1;
    }
}

// === Quartic (power of 4) ===

/// Quartic ease-in
pub fn easeInQuart(t: f32) f32 {
    return t * t * t * t;
}

/// Quartic ease-out
pub fn easeOutQuart(t: f32) f32 {
    const f = t - 1;
    return 1 - f * f * f * f;
}

/// Quartic ease-in-out
pub fn easeInOutQuart(t: f32) f32 {
    if (t < 0.5) {
        return 8 * t * t * t * t;
    } else {
        const f = t - 1;
        return 1 - 8 * f * f * f * f;
    }
}

// === Quintic (power of 5) ===

/// Quintic ease-in
pub fn easeInQuint(t: f32) f32 {
    return t * t * t * t * t;
}

/// Quintic ease-out
pub fn easeOutQuint(t: f32) f32 {
    const f = t - 1;
    return 1 + f * f * f * f * f;
}

/// Quintic ease-in-out
pub fn easeInOutQuint(t: f32) f32 {
    if (t < 0.5) {
        return 16 * t * t * t * t * t;
    } else {
        const f = 2 * t - 2;
        return 0.5 * f * f * f * f * f + 1;
    }
}

// === Sinusoidal ===

/// Sinusoidal ease-in
pub fn easeInSine(t: f32) f32 {
    return 1 - @cos(t * PI / 2);
}

/// Sinusoidal ease-out
pub fn easeOutSine(t: f32) f32 {
    return @sin(t * PI / 2);
}

/// Sinusoidal ease-in-out
pub fn easeInOutSine(t: f32) f32 {
    return 0.5 * (1 - @cos(PI * t));
}

// === Exponential ===

/// Exponential ease-in
pub fn easeInExpo(t: f32) f32 {
    if (t == 0) return 0;
    return math.pow(f32, 2, 10 * (t - 1));
}

/// Exponential ease-out
pub fn easeOutExpo(t: f32) f32 {
    if (t == 1) return 1;
    return 1 - math.pow(f32, 2, -10 * t);
}

/// Exponential ease-in-out
pub fn easeInOutExpo(t: f32) f32 {
    if (t == 0) return 0;
    if (t == 1) return 1;
    if (t < 0.5) {
        return 0.5 * math.pow(f32, 2, 20 * t - 10);
    } else {
        return 1 - 0.5 * math.pow(f32, 2, -20 * t + 10);
    }
}

// === Circular ===

/// Circular ease-in
pub fn easeInCirc(t: f32) f32 {
    return 1 - @sqrt(1 - t * t);
}

/// Circular ease-out
pub fn easeOutCirc(t: f32) f32 {
    const f = t - 1;
    return @sqrt(1 - f * f);
}

/// Circular ease-in-out
pub fn easeInOutCirc(t: f32) f32 {
    if (t < 0.5) {
        return 0.5 * (1 - @sqrt(1 - 4 * t * t));
    } else {
        return 0.5 * (@sqrt(1 - math.pow(f32, -2 * t + 2, 2)) + 1);
    }
}

// === Back (overshoot) ===

const BACK_C1: f32 = 1.70158;
const BACK_C2: f32 = BACK_C1 * 1.525;
const BACK_C3: f32 = BACK_C1 + 1;

/// Back ease-in: slight overshoot at start
pub fn easeInBack(t: f32) f32 {
    return BACK_C3 * t * t * t - BACK_C1 * t * t;
}

/// Back ease-out: slight overshoot at end
pub fn easeOutBack(t: f32) f32 {
    const f = t - 1;
    return 1 + BACK_C3 * f * f * f + BACK_C1 * f * f;
}

/// Back ease-in-out: overshoot at both ends
pub fn easeInOutBack(t: f32) f32 {
    if (t < 0.5) {
        return (math.pow(f32, 2 * t, 2) * ((BACK_C2 + 1) * 2 * t - BACK_C2)) / 2;
    } else {
        return (math.pow(f32, 2 * t - 2, 2) * ((BACK_C2 + 1) * (t * 2 - 2) + BACK_C2) + 2) / 2;
    }
}

// === Elastic ===

const ELASTIC_C4: f32 = (2 * PI) / 3;
const ELASTIC_C5: f32 = (2 * PI) / 4.5;

/// Elastic ease-in: elastic effect at start
pub fn easeInElastic(t: f32) f32 {
    if (t == 0) return 0;
    if (t == 1) return 1;
    return -math.pow(f32, 2, 10 * t - 10) * @sin((t * 10 - 10.75) * ELASTIC_C4);
}

/// Elastic ease-out: elastic effect at end
pub fn easeOutElastic(t: f32) f32 {
    if (t == 0) return 0;
    if (t == 1) return 1;
    return math.pow(f32, 2, -10 * t) * @sin((t * 10 - 0.75) * ELASTIC_C4) + 1;
}

/// Elastic ease-in-out: elastic effect at both ends
pub fn easeInOutElastic(t: f32) f32 {
    if (t == 0) return 0;
    if (t == 1) return 1;
    if (t < 0.5) {
        return -(math.pow(f32, 2, 20 * t - 10) * @sin((20 * t - 11.125) * ELASTIC_C5)) / 2;
    } else {
        return (math.pow(f32, 2, -20 * t + 10) * @sin((20 * t - 11.125) * ELASTIC_C5)) / 2 + 1;
    }
}

// === Bounce ===

const BOUNCE_N1: f32 = 7.5625;
const BOUNCE_D1: f32 = 2.75;

/// Bounce ease-out helper
fn bounceOut(t: f32) f32 {
    if (t < 1 / BOUNCE_D1) {
        return BOUNCE_N1 * t * t;
    } else if (t < 2 / BOUNCE_D1) {
        const tt = t - 1.5 / BOUNCE_D1;
        return BOUNCE_N1 * tt * tt + 0.75;
    } else if (t < 2.5 / BOUNCE_D1) {
        const tt = t - 2.25 / BOUNCE_D1;
        return BOUNCE_N1 * tt * tt + 0.9375;
    } else {
        const tt = t - 2.625 / BOUNCE_D1;
        return BOUNCE_N1 * tt * tt + 0.984375;
    }
}

/// Bounce ease-in: bouncing at start
pub fn easeInBounce(t: f32) f32 {
    return 1 - bounceOut(1 - t);
}

/// Bounce ease-out: bouncing at end
pub fn easeOutBounce(t: f32) f32 {
    return bounceOut(t);
}

/// Bounce ease-in-out: bouncing at both ends
pub fn easeInOutBounce(t: f32) f32 {
    if (t < 0.5) {
        return (1 - bounceOut(1 - 2 * t)) / 2;
    } else {
        return (1 + bounceOut(2 * t - 1)) / 2;
    }
}

// === Step Functions ===

/// Step function: jumps to 1 at specified point
pub fn step(comptime threshold: f32) fn (f32) f32 {
    return struct {
        fn f(t: f32) f32 {
            return if (t >= threshold) 1 else 0;
        }
    }.f;
}

/// Step start: 1 immediately
pub fn stepStart(t: f32) f32 {
    _ = t;
    return 1;
}

/// Step end: 1 at t=1
pub fn stepEnd(t: f32) f32 {
    return if (t >= 1) 1 else 0;
}

// === Cubic Bezier ===

/// Cubic bezier easing with control points
/// Similar to CSS cubic-bezier(x1, y1, x2, y2)
pub const CubicBezier = struct {
    x1: f32,
    y1: f32,
    x2: f32,
    y2: f32,

    /// CSS ease preset
    pub const ease = CubicBezier{ .x1 = 0.25, .y1 = 0.1, .x2 = 0.25, .y2 = 1.0 };
    /// CSS ease-in preset
    pub const ease_in = CubicBezier{ .x1 = 0.42, .y1 = 0, .x2 = 1.0, .y2 = 1.0 };
    /// CSS ease-out preset
    pub const ease_out = CubicBezier{ .x1 = 0, .y1 = 0, .x2 = 0.58, .y2 = 1.0 };
    /// CSS ease-in-out preset
    pub const ease_in_out = CubicBezier{ .x1 = 0.42, .y1 = 0, .x2 = 0.58, .y2 = 1.0 };

    /// Evaluate the bezier curve at time t
    pub fn evaluate(self: CubicBezier, t: f32) f32 {
        // Newton-Raphson iteration to find x for given t
        var x = t;
        for (0..8) |_| {
            const x_est = self.sampleCurveX(x) - t;
            if (@abs(x_est) < 0.0001) break;
            const d = self.sampleCurveDerivativeX(x);
            if (@abs(d) < 0.0001) break;
            x = x - x_est / d;
        }
        return self.sampleCurveY(x);
    }

    fn sampleCurveX(self: CubicBezier, t: f32) f32 {
        return ((1 - 3 * self.x2 + 3 * self.x1) * t + (3 * self.x2 - 6 * self.x1)) * t * t + 3 * self.x1 * t;
    }

    fn sampleCurveY(self: CubicBezier, t: f32) f32 {
        return ((1 - 3 * self.y2 + 3 * self.y1) * t + (3 * self.y2 - 6 * self.y1)) * t * t + 3 * self.y1 * t;
    }

    fn sampleCurveDerivativeX(self: CubicBezier, t: f32) f32 {
        return (3 - 9 * self.x2 + 9 * self.x1) * t * t + (6 * self.x2 - 12 * self.x1) * t + 3 * self.x1;
    }
};

// === Spring Physics ===

/// Spring-based easing for natural motion
pub const Spring = struct {
    mass: f32 = 1.0,
    stiffness: f32 = 100.0,
    damping: f32 = 10.0,
    initial_velocity: f32 = 0.0,

    /// Default spring preset
    pub const default = Spring{};
    /// Gentle spring
    pub const gentle = Spring{ .stiffness = 120, .damping = 14 };
    /// Wobbly spring
    pub const wobbly = Spring{ .stiffness = 180, .damping = 12 };
    /// Stiff spring
    pub const stiff = Spring{ .stiffness = 210, .damping = 20 };
    /// Slow spring
    pub const slow = Spring{ .stiffness = 280, .damping = 60 };

    /// Epsilon for float comparison
    const EPSILON: f32 = 1e-6;

    /// Evaluate spring at time t (0-1 normalized)
    pub fn evaluate(self: Spring, t: f32) f32 {
        const omega = @sqrt(self.stiffness / self.mass);
        const zeta = self.damping / (2 * @sqrt(self.stiffness * self.mass));

        if (zeta < 1.0 - EPSILON) {
            // Underdamped
            const omega_d = omega * @sqrt(1 - zeta * zeta);
            const decay = @exp(-zeta * omega * t);
            return 1 - decay * (@cos(omega_d * t) + (zeta * omega / omega_d) * @sin(omega_d * t));
        } else if (@abs(zeta - 1.0) < EPSILON) {
            // Critically damped
            const decay = @exp(-omega * t);
            return 1 - decay * (1 + omega * t);
        } else {
            // Overdamped
            const s1 = -omega * (zeta - @sqrt(zeta * zeta - 1));
            const s2 = -omega * (zeta + @sqrt(zeta * zeta - 1));
            const c1 = (s2) / (s2 - s1);
            const c2 = (-s1) / (s2 - s1);
            return 1 - c1 * @exp(s1 * t) - c2 * @exp(s2 * t);
        }
    }
};

// === Easing Type Enum ===

/// Standard easing types for serialization
pub const EasingType = enum(u8) {
    linear = 0,
    ease_in_quad = 1,
    ease_out_quad = 2,
    ease_in_out_quad = 3,
    ease_in_cubic = 4,
    ease_out_cubic = 5,
    ease_in_out_cubic = 6,
    ease_in_quart = 7,
    ease_out_quart = 8,
    ease_in_out_quart = 9,
    ease_in_quint = 10,
    ease_out_quint = 11,
    ease_in_out_quint = 12,
    ease_in_sine = 13,
    ease_out_sine = 14,
    ease_in_out_sine = 15,
    ease_in_expo = 16,
    ease_out_expo = 17,
    ease_in_out_expo = 18,
    ease_in_circ = 19,
    ease_out_circ = 20,
    ease_in_out_circ = 21,
    ease_in_back = 22,
    ease_out_back = 23,
    ease_in_out_back = 24,
    ease_in_elastic = 25,
    ease_out_elastic = 26,
    ease_in_out_elastic = 27,
    ease_in_bounce = 28,
    ease_out_bounce = 29,
    ease_in_out_bounce = 30,

    /// Get the easing function for this type
    pub fn getFunction(self: EasingType) *const fn (f32) f32 {
        return switch (self) {
            .linear => linear,
            .ease_in_quad => easeInQuad,
            .ease_out_quad => easeOutQuad,
            .ease_in_out_quad => easeInOutQuad,
            .ease_in_cubic => easeInCubic,
            .ease_out_cubic => easeOutCubic,
            .ease_in_out_cubic => easeInOutCubic,
            .ease_in_quart => easeInQuart,
            .ease_out_quart => easeOutQuart,
            .ease_in_out_quart => easeInOutQuart,
            .ease_in_quint => easeInQuint,
            .ease_out_quint => easeOutQuint,
            .ease_in_out_quint => easeInOutQuint,
            .ease_in_sine => easeInSine,
            .ease_out_sine => easeOutSine,
            .ease_in_out_sine => easeInOutSine,
            .ease_in_expo => easeInExpo,
            .ease_out_expo => easeOutExpo,
            .ease_in_out_expo => easeInOutExpo,
            .ease_in_circ => easeInCirc,
            .ease_out_circ => easeOutCirc,
            .ease_in_out_circ => easeInOutCirc,
            .ease_in_back => easeInBack,
            .ease_out_back => easeOutBack,
            .ease_in_out_back => easeInOutBack,
            .ease_in_elastic => easeInElastic,
            .ease_out_elastic => easeOutElastic,
            .ease_in_out_elastic => easeInOutElastic,
            .ease_in_bounce => easeInBounce,
            .ease_out_bounce => easeOutBounce,
            .ease_in_out_bounce => easeInOutBounce,
        };
    }
};

// === Utility Functions ===

/// Apply easing to interpolate between two values
pub fn interpolate(comptime T: type, start: T, end: T, t: f32, easing_fn: *const fn (f32) f32) T {
    const eased_t = easing_fn(t);
    return switch (@typeInfo(T)) {
        .float => start + (end - start) * eased_t,
        .int => @intFromFloat(@as(f32, @floatFromInt(start)) + (@as(f32, @floatFromInt(end)) - @as(f32, @floatFromInt(start))) * eased_t),
        else => @compileError("Unsupported type for interpolation"),
    };
}

/// Clamp time to 0-1 range
pub fn clamp01(t: f32) f32 {
    return @max(0, @min(1, t));
}

// ============================================================================
// Tests
// ============================================================================

test "linear easing" {
    try std.testing.expectEqual(@as(f32, 0.0), linear(0.0));
    try std.testing.expectEqual(@as(f32, 0.5), linear(0.5));
    try std.testing.expectEqual(@as(f32, 1.0), linear(1.0));
}

test "quadratic easing boundary values" {
    // All easings should return 0 at t=0 and 1 at t=1
    try std.testing.expectEqual(@as(f32, 0.0), easeInQuad(0.0));
    try std.testing.expectEqual(@as(f32, 1.0), easeInQuad(1.0));
    try std.testing.expectEqual(@as(f32, 0.0), easeOutQuad(0.0));
    try std.testing.expectEqual(@as(f32, 1.0), easeOutQuad(1.0));
    try std.testing.expectEqual(@as(f32, 0.0), easeInOutQuad(0.0));
    try std.testing.expectEqual(@as(f32, 1.0), easeInOutQuad(1.0));
}

test "cubic easing boundary values" {
    try std.testing.expectEqual(@as(f32, 0.0), easeInCubic(0.0));
    try std.testing.expectEqual(@as(f32, 1.0), easeInCubic(1.0));
    try std.testing.expectEqual(@as(f32, 0.0), easeOutCubic(0.0));
    try std.testing.expectEqual(@as(f32, 1.0), easeOutCubic(1.0));
}

test "quartic easing boundary values" {
    try std.testing.expectEqual(@as(f32, 0.0), easeInQuart(0.0));
    try std.testing.expectEqual(@as(f32, 1.0), easeInQuart(1.0));
    try std.testing.expectEqual(@as(f32, 0.0), easeOutQuart(0.0));
    try std.testing.expectEqual(@as(f32, 1.0), easeOutQuart(1.0));
}

test "quintic easing boundary values" {
    try std.testing.expectEqual(@as(f32, 0.0), easeInQuint(0.0));
    try std.testing.expectEqual(@as(f32, 1.0), easeInQuint(1.0));
    try std.testing.expectEqual(@as(f32, 0.0), easeOutQuint(0.0));
    try std.testing.expectEqual(@as(f32, 1.0), easeOutQuint(1.0));
}

test "sinusoidal easing" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), easeInSine(0.0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), easeInSine(1.0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), easeOutSine(0.0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), easeOutSine(1.0), 0.0001);
}

test "exponential easing" {
    try std.testing.expectEqual(@as(f32, 0.0), easeInExpo(0.0));
    try std.testing.expectEqual(@as(f32, 1.0), easeInExpo(1.0));
    try std.testing.expectEqual(@as(f32, 0.0), easeOutExpo(0.0));
    try std.testing.expectEqual(@as(f32, 1.0), easeOutExpo(1.0));
}

test "circular easing" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), easeInCirc(0.0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), easeInCirc(1.0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), easeOutCirc(0.0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), easeOutCirc(1.0), 0.0001);
}

test "elastic easing boundary values" {
    try std.testing.expectEqual(@as(f32, 0.0), easeInElastic(0.0));
    try std.testing.expectEqual(@as(f32, 1.0), easeInElastic(1.0));
    try std.testing.expectEqual(@as(f32, 0.0), easeOutElastic(0.0));
    try std.testing.expectEqual(@as(f32, 1.0), easeOutElastic(1.0));
}

test "bounce easing" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), easeInBounce(0.0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), easeInBounce(1.0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), easeOutBounce(0.0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), easeOutBounce(1.0), 0.0001);
}

test "back easing" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), easeInBack(0.0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), easeInBack(1.0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), easeOutBack(0.0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), easeOutBack(1.0), 0.0001);
}

test "step functions" {
    try std.testing.expectEqual(@as(f32, 1.0), stepStart(0.0));
    try std.testing.expectEqual(@as(f32, 1.0), stepStart(0.5));
    try std.testing.expectEqual(@as(f32, 0.0), stepEnd(0.0));
    try std.testing.expectEqual(@as(f32, 0.0), stepEnd(0.5));
    try std.testing.expectEqual(@as(f32, 1.0), stepEnd(1.0));
}

test "cubic bezier presets" {
    const ease = CubicBezier.ease;
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), ease.evaluate(0.0), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), ease.evaluate(1.0), 0.01);

    const ease_in = CubicBezier.ease_in;
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), ease_in.evaluate(0.0), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), ease_in.evaluate(1.0), 0.01);
}

test "spring physics" {
    const spring = Spring.default;
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), spring.evaluate(0.0), 0.01);
    // Spring approaches 1.0 but may overshoot
    try std.testing.expect(spring.evaluate(5.0) > 0.9);

    const stiff = Spring.stiff;
    try std.testing.expect(stiff.evaluate(3.0) > 0.9);
}

test "easing type enum" {
    const fn_linear = EasingType.linear.getFunction();
    try std.testing.expectEqual(@as(f32, 0.5), fn_linear(0.5));

    const fn_quad = EasingType.ease_in_quad.getFunction();
    try std.testing.expectEqual(@as(f32, 0.25), fn_quad(0.5));
}

test "interpolate utility" {
    const result = interpolate(f32, 0.0, 100.0, 0.5, linear);
    try std.testing.expectEqual(@as(f32, 50.0), result);

    const result_eased = interpolate(f32, 0.0, 100.0, 0.5, easeInQuad);
    try std.testing.expectEqual(@as(f32, 25.0), result_eased);
}

test "clamp01" {
    try std.testing.expectEqual(@as(f32, 0.0), clamp01(-0.5));
    try std.testing.expectEqual(@as(f32, 0.5), clamp01(0.5));
    try std.testing.expectEqual(@as(f32, 1.0), clamp01(1.5));
}
