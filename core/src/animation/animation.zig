//! Zylix Animation - Unified Animation Module
//!
//! Cross-platform animation system supporting:
//! - Lottie vector animations (JSON-based)
//! - Live2D character animations (Cubism SDK)
//! - Timeline-based sequencing
//! - Easing functions library
//! - Animation state machine
//!
//! ## Design Principles
//!
//! 1. **Unified API**: Same animation API across all platforms
//! 2. **Performance**: Optimized for 60fps on all platforms
//! 3. **Composable**: Animations can be combined and layered
//! 4. **Platform Optimized**: Native renderers where beneficial
//!
//! ## Usage
//!
//! ```zig
//! const animation = @import("animation/animation.zig");
//!
//! // Initialize
//! animation.init();
//! defer animation.deinit();
//!
//! // Lottie animation
//! const lottie_id = animation.lottie.loadFromJson(json_data);
//! animation.lottie.play(lottie_id);
//!
//! // Timeline animation
//! var timeline = animation.Timeline.init(allocator);
//! timeline.addPropertyTrack(f32, "opacity", 0)
//!     .addKeyframe(0, 0)
//!     .addKeyframe(1000, 1);
//! timeline.play();
//!
//! // State machine
//! var sm = animation.StateMachine.init(allocator);
//! sm.addState("idle", .{});
//! sm.addState("walk", .{});
//! sm.addTransition("idle", "walk");
//! ```

const std = @import("std");

// === Module Re-exports ===

/// Common animation types (Time, Color, Transform, State, etc.)
pub const types = @import("types.zig");
pub const TimeMs = types.TimeMs;
pub const DurationMs = types.DurationMs;
pub const NormalizedTime = types.NormalizedTime;
pub const FrameNumber = types.FrameNumber;
pub const FrameRate = types.FrameRate;
pub const Color = types.Color;
pub const Point2D = types.Point2D;
pub const Size2D = types.Size2D;
pub const Rect2D = types.Rect2D;
pub const Transform2D = types.Transform2D;
pub const Matrix3x3 = types.Matrix3x3;
pub const PlaybackState = types.PlaybackState;
pub const LoopMode = types.LoopMode;
pub const PlayDirection = types.PlayDirection;
pub const BlendMode = types.BlendMode;
pub const FillMode = types.FillMode;
pub const AnimationEventType = types.AnimationEventType;
pub const AnimationEvent = types.AnimationEvent;
pub const AnimationCallback = types.AnimationCallback;
pub const PlaybackConfig = types.PlaybackConfig;
pub const RenderConfig = types.RenderConfig;
pub const RenderQuality = types.RenderQuality;
pub const AnimationResult = types.AnimationResult;
pub const AnimationError = types.AnimationError;

/// Easing functions (quadratic, cubic, elastic, bounce, etc.)
pub const easing = @import("easing.zig");
pub const EasingType = easing.EasingType;
pub const CubicBezier = easing.CubicBezier;
pub const Spring = easing.Spring;

/// Timeline animation (keyframes, tracks, sequences)
pub const timeline = @import("timeline.zig");
pub const Timeline = timeline.Timeline;
pub const PropertyTrack = timeline.PropertyTrack;
pub const Marker = timeline.Marker;
pub const SequenceBuilder = timeline.SequenceBuilder;
pub const ParallelGroup = timeline.ParallelGroup;

/// Animation state machine (states, transitions, parameters)
pub const state_machine = @import("state_machine.zig");
pub const StateMachine = state_machine.StateMachine;
pub const State = state_machine.State;
pub const Transition = state_machine.Transition;
pub const TransitionConfig = state_machine.TransitionConfig;
pub const TransitionBlendMode = state_machine.TransitionBlendMode;
pub const Condition = state_machine.Condition;
pub const CompareOp = state_machine.CompareOp;
pub const ParameterType = state_machine.ParameterType;
pub const ParameterValue = state_machine.ParameterValue;
pub const AnimationLayer = state_machine.AnimationLayer;
pub const AnimationController = state_machine.AnimationController;

/// Lottie vector animation support
pub const lottie = @import("lottie.zig");
pub const LottieAnimation = lottie.Animation;
pub const LottieManager = lottie.LottieManager;
pub const LottieLayer = lottie.Layer;
pub const LottieMarker = lottie.LottieMarker;
pub const LayerType = lottie.LayerType;
pub const ShapeType = lottie.ShapeType;
pub const ShapeElement = lottie.ShapeElement;
pub const BezierPath = lottie.BezierPath;

/// Live2D character animation support
pub const live2d = @import("live2d.zig");
pub const Live2DModel = live2d.Model;
pub const Live2DManager = live2d.Live2DManager;
pub const Motion = live2d.Motion;
pub const Expression = live2d.Expression;
pub const PhysicsRig = live2d.PhysicsRig;
pub const EyeBlink = live2d.EyeBlink;
pub const LipSync = live2d.LipSync;
pub const Phoneme = live2d.Phoneme;
pub const StandardParams = live2d.StandardParams;

// === Constants ===

/// Zylix Animation module version
pub const VERSION: u32 = 0x00_0B_00; // v0.11.0

/// Version string
pub const VERSION_STRING = "0.11.0";

// === Global State ===

var initialized: bool = false;
var global_allocator: ?std.mem.Allocator = null;

// === Global Managers ===

var lottie_manager: ?LottieManager = null;
var live2d_manager: ?Live2DManager = null;

// === Initialization ===

/// Initialize the animation module
pub fn init() void {
    initWithAllocator(std.heap.page_allocator);
}

/// Initialize with custom allocator
pub fn initWithAllocator(allocator: std.mem.Allocator) void {
    if (initialized) return;

    global_allocator = allocator;
    lottie_manager = LottieManager.init(allocator);
    live2d_manager = Live2DManager.init(allocator);
    initialized = true;
}

/// Deinitialize the animation module
pub fn deinit() void {
    if (!initialized) return;

    if (lottie_manager) |*manager| {
        manager.deinit();
        lottie_manager = null;
    }

    if (live2d_manager) |*manager| {
        manager.deinit();
        live2d_manager = null;
    }

    global_allocator = null;
    initialized = false;
}

/// Check if module is initialized
pub fn isInitialized() bool {
    return initialized;
}

// === Global Lottie API ===

/// Load a Lottie animation from JSON
pub fn loadLottie(json_str: []const u8) !u32 {
    if (lottie_manager) |*manager| {
        return manager.loadFromJson(json_str);
    }
    return error.NotInitialized;
}

/// Get Lottie animation by ID
pub fn getLottie(id: u32) ?*LottieAnimation {
    if (lottie_manager) |*manager| {
        return manager.getAnimation(id);
    }
    return null;
}

/// Unload Lottie animation
pub fn unloadLottie(id: u32) void {
    if (lottie_manager) |*manager| {
        manager.unload(id);
    }
}

// === Global Live2D API ===

/// Create a new Live2D model
pub fn createLive2D() !u32 {
    if (live2d_manager) |*manager| {
        return manager.createModel();
    }
    return error.NotInitialized;
}

/// Get Live2D model by ID
pub fn getLive2D(id: u32) ?*Live2DModel {
    if (live2d_manager) |*manager| {
        return manager.getModel(id);
    }
    return null;
}

/// Destroy Live2D model
pub fn destroyLive2D(id: u32) void {
    if (live2d_manager) |*manager| {
        manager.destroyModel(id);
    }
}

// === Global Update ===

/// Update all animations (call each frame)
pub fn updateAll(delta_ms: TimeMs) void {
    if (lottie_manager) |*manager| {
        manager.updateAll(delta_ms);
    }
    if (live2d_manager) |*manager| {
        manager.updateAll(delta_ms);
    }
}

// === Utility Functions ===

/// Create a simple tween animation
/// Returns null if allocation fails
pub fn tween(
    allocator: std.mem.Allocator,
    comptime T: type,
    from: T,
    to: T,
    duration_ms: DurationMs,
    easing_type: EasingType,
) ?Timeline {
    var tl = Timeline.init(allocator);
    const track = tl.addPropertyTrack(T, "value", from) orelse {
        tl.deinit();
        return null;
    };
    _ = track.addKeyframeWithEasing(@intCast(duration_ms), to, easing_type.getFunction());
    return tl;
}

/// Create a spring animation
/// Returns null if allocation fails
pub fn springTo(
    allocator: std.mem.Allocator,
    comptime T: type,
    from: T,
    to: T,
    spring_config: Spring,
) ?Timeline {
    var tl = Timeline.init(allocator);
    const track = tl.addPropertyTrack(T, "value", from) orelse {
        tl.deinit();
        return null;
    };

    // Sample spring at intervals (60 samples over 2 seconds)
    const samples: u32 = 60;
    const duration_ms: TimeMs = 2000;

    var i: u32 = 0;
    while (i <= samples) : (i += 1) {
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(samples));
        const progress = spring_config.evaluate(t * 2); // 2 second spring duration
        const time_ms: TimeMs = @intFromFloat(t * @as(f32, @floatFromInt(duration_ms)));

        switch (@typeInfo(T)) {
            .float => {
                const value = from + (to - from) * progress;
                _ = track.addKeyframe(time_ms, value);
            },
            .@"struct" => {
                if (@hasDecl(T, "lerp")) {
                    _ = track.addKeyframe(time_ms, from.lerp(to, progress));
                }
            },
            else => {},
        }
    }

    // Ensure final keyframe at exact end value
    switch (@typeInfo(T)) {
        .float => _ = track.addKeyframe(duration_ms, to),
        .@"struct" => {
            if (@hasDecl(T, "lerp")) {
                _ = track.addKeyframe(duration_ms, to);
            }
        },
        else => {},
    }

    return tl;
}

/// Convert duration to frames
pub fn msToFrames(ms: DurationMs, fps: FrameRate) FrameNumber {
    return @intFromFloat(@as(f32, @floatFromInt(ms)) / 1000.0 * fps);
}

/// Convert frames to duration
pub fn framesToMs(frames: FrameNumber, fps: FrameRate) DurationMs {
    return @intFromFloat(@as(f32, @floatFromInt(frames)) / fps * 1000.0);
}

// === Tests ===

test "animation initialization" {
    init();
    defer deinit();

    try std.testing.expect(isInitialized());
}

test "easing functions" {
    // Linear
    try std.testing.expectEqual(@as(f32, 0.5), easing.linear(0.5));

    // Ease in quad
    try std.testing.expectEqual(@as(f32, 0.25), easing.easeInQuad(0.5));

    // Ease out quad
    try std.testing.expectEqual(@as(f32, 0.75), easing.easeOutQuad(0.5));
}

test "timeline basic" {
    const allocator = std.testing.allocator;

    var tl = Timeline.init(allocator);
    defer tl.deinit();

    const track = tl.addPropertyTrack(f32, "opacity", 0) orelse {
        try std.testing.expect(false); // Allocation should not fail in tests
        return;
    };
    _ = track.addKeyframe(0, 0);
    _ = track.addKeyframe(1000, 1);

    try std.testing.expectEqual(@as(TimeMs, 1000), tl.getDuration());
}

test "state machine basic" {
    const allocator = std.testing.allocator;

    var sm = StateMachine.init(allocator);
    defer sm.deinit();

    _ = sm.addSimpleState("idle");
    _ = sm.addSimpleState("walk");

    try std.testing.expect(sm.setState("idle"));
    try std.testing.expectEqualStrings("idle", sm.getCurrentStateName().?);
}
