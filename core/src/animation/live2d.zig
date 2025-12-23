//! Live2D Integration - Character animation support
//!
//! Provides integration with Live2D Cubism SDK for 2D character
//! animations with physics simulation and expression support.
//!
//! ## Features
//!
//! - Live2D model loading and rendering
//! - Motion playback and blending
//! - Expression system
//! - Physics simulation (hair, clothes)
//! - Eye tracking and lip sync
//! - Parameter control
//!
//! ## Platform Backends
//!
//! - iOS/macOS: Metal renderer
//! - Android: OpenGL ES renderer
//! - Windows: DirectX/OpenGL renderer
//! - Web: WebGL renderer
//!
//! ## Requirements
//!
//! - Cubism SDK v5-r.4.1 or later
//! - Platform-specific graphics API support
//!
//! ## Usage
//!
//! ```zig
//! const live2d = @import("live2d.zig");
//!
//! var model = live2d.Model.load("model.moc3", "model.model3.json");
//! model.startMotion("idle");
//! model.setParameter("ParamEyeLOpen", 1.0);
//!
//! // In render loop
//! model.update(delta_ms);
//! model.draw();
//! ```

const std = @import("std");
const types = @import("types.zig");

const TimeMs = types.TimeMs;
const DurationMs = types.DurationMs;
const Point2D = types.Point2D;
const Size2D = types.Size2D;
const Color = types.Color;
const PlaybackState = types.PlaybackState;
const LoopMode = types.LoopMode;
const AnimationEvent = types.AnimationEvent;
const AnimationEventType = types.AnimationEventType;

// === Live2D Constants ===

/// Standard Live2D parameter IDs
pub const StandardParams = struct {
    // Head
    pub const ParamAngleX = "ParamAngleX";
    pub const ParamAngleY = "ParamAngleY";
    pub const ParamAngleZ = "ParamAngleZ";

    // Body
    pub const ParamBodyAngleX = "ParamBodyAngleX";
    pub const ParamBodyAngleY = "ParamBodyAngleY";
    pub const ParamBodyAngleZ = "ParamBodyAngleZ";

    // Eyes
    pub const ParamEyeLOpen = "ParamEyeLOpen";
    pub const ParamEyeROpen = "ParamEyeROpen";
    pub const ParamEyeLSmile = "ParamEyeLSmile";
    pub const ParamEyeRSmile = "ParamEyeRSmile";
    pub const ParamEyeBallX = "ParamEyeBallX";
    pub const ParamEyeBallY = "ParamEyeBallY";

    // Brow
    pub const ParamBrowLY = "ParamBrowLY";
    pub const ParamBrowRY = "ParamBrowRY";
    pub const ParamBrowLX = "ParamBrowLX";
    pub const ParamBrowRX = "ParamBrowRX";
    pub const ParamBrowLAngle = "ParamBrowLAngle";
    pub const ParamBrowRAngle = "ParamBrowRAngle";
    pub const ParamBrowLForm = "ParamBrowLForm";
    pub const ParamBrowRForm = "ParamBrowRForm";

    // Mouth
    pub const ParamMouthForm = "ParamMouthForm";
    pub const ParamMouthOpenY = "ParamMouthOpenY";

    // Breath
    pub const ParamBreath = "ParamBreath";

    // Cheek
    pub const ParamCheek = "ParamCheek";
};

// === Blend Mode ===

/// Live2D blend mode
pub const Live2DBlendMode = enum(u8) {
    normal = 0,
    additive = 1,
    multiply = 2,
};

// === Motion Priority ===

/// Motion priority levels
pub const MotionPriority = enum(u8) {
    none = 0,
    idle = 1,
    normal = 2,
    force = 3,
};

// === Parameter ===

/// Live2D model parameter
pub const Parameter = struct {
    id: []const u8,
    value: f32 = 0,
    default_value: f32 = 0,
    min_value: f32 = -30,
    max_value: f32 = 30,

    /// Set value with clamping
    pub fn setValue(self: *Parameter, value: f32) void {
        self.value = @max(self.min_value, @min(self.max_value, value));
    }

    /// Add to current value
    pub fn addValue(self: *Parameter, delta: f32) void {
        self.setValue(self.value + delta);
    }

    /// Reset to default
    pub fn reset(self: *Parameter) void {
        self.value = self.default_value;
    }

    /// Get normalized value (0-1)
    pub fn getNormalized(self: *const Parameter) f32 {
        const range = self.max_value - self.min_value;
        if (range == 0) return 0;
        return (self.value - self.min_value) / range;
    }
};

// === Part ===

/// Live2D model part (drawable group)
pub const Part = struct {
    id: []const u8,
    opacity: f32 = 1.0,
    parent_index: ?u32 = null,
};

// === Drawable ===

/// Live2D drawable (mesh)
pub const Drawable = struct {
    id: []const u8,
    texture_index: u32 = 0,
    blend_mode: Live2DBlendMode = .normal,
    is_inverted_mask: bool = false,
    is_visible: bool = true,
    opacity: f32 = 1.0,
    draw_order: i32 = 0,
    render_order: u32 = 0,

    // Mesh data (would be populated from .moc3)
    vertex_count: u32 = 0,
    index_count: u32 = 0,

    // Clipping mask
    mask_count: u32 = 0,
};

// === Motion Segment ===

/// Motion curve segment types
pub const SegmentType = enum(u8) {
    linear = 0,
    bezier = 1,
    stepped = 2,
    inverse_stepped = 3,
};

/// Motion curve segment
pub const MotionSegment = struct {
    time: f32,
    value: f32,
    segment_type: SegmentType = .linear,
    // Bezier control points (if bezier type)
    control_points: ?[4]f32 = null,
};

/// Motion curve for a single parameter
pub const MotionCurve = struct {
    target_type: enum(u8) { model, parameter, part_opacity } = .parameter,
    target_id: []const u8,
    segments: std.ArrayList(MotionSegment),
    fade_in_time: f32 = 0,
    fade_out_time: f32 = 0,

    pub fn init(allocator: std.mem.Allocator, target_id: []const u8) MotionCurve {
        return MotionCurve{
            .target_id = target_id,
            .segments = std.ArrayList(MotionSegment).init(allocator),
        };
    }

    pub fn deinit(self: *MotionCurve) void {
        self.segments.deinit();
    }

    /// Get value at time with interpolation
    pub fn getValueAt(self: *const MotionCurve, time: f32) f32 {
        if (self.segments.items.len == 0) return 0;
        if (self.segments.items.len == 1) return self.segments.items[0].value;

        // Find surrounding segments
        var prev_idx: usize = 0;
        for (self.segments.items, 0..) |seg, i| {
            if (seg.time <= time) {
                prev_idx = i;
            } else {
                break;
            }
        }

        const next_idx = @min(prev_idx + 1, self.segments.items.len - 1);
        if (prev_idx == next_idx) return self.segments.items[prev_idx].value;

        const prev = self.segments.items[prev_idx];
        const next = self.segments.items[next_idx];

        // Guard against division by zero
        const time_diff = next.time - prev.time;
        if (time_diff == 0) return prev.value;
        const t = (time - prev.time) / time_diff;

        return switch (prev.segment_type) {
            .linear => prev.value + (next.value - prev.value) * t,
            .stepped => prev.value,
            .inverse_stepped => next.value,
            .bezier => blk: {
                // Cubic bezier interpolation
                if (prev.control_points) |cp| {
                    const t2 = t * t;
                    const t3 = t2 * t;
                    const mt = 1 - t;
                    const mt2 = mt * mt;
                    const mt3 = mt2 * mt;
                    break :blk mt3 * prev.value + 3 * mt2 * t * cp[1] + 3 * mt * t2 * cp[3] + t3 * next.value;
                }
                break :blk prev.value + (next.value - prev.value) * t;
            },
        };
    }
};

// === Motion ===

/// Live2D motion
pub const Motion = struct {
    const Self = @This();

    name: []const u8 = "",
    duration: f32 = 0, // seconds
    loop: bool = false,
    fade_in_time: f32 = 0.5, // seconds
    fade_out_time: f32 = 0.5, // seconds

    curves: std.ArrayList(MotionCurve),

    // Playback state
    state: PlaybackState = .stopped,
    current_time: f32 = 0,
    weight: f32 = 1.0, // Blend weight
    is_fading_in: bool = false,
    is_fading_out: bool = false,
    fade_progress: f32 = 0,

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .curves = std.ArrayList(MotionCurve).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.curves.items) |*curve| {
            curve.deinit();
        }
        self.curves.deinit();
    }

    /// Start playing the motion
    pub fn play(self: *Self) void {
        self.state = .playing;
        self.current_time = 0;
        self.is_fading_in = self.fade_in_time > 0;
        self.fade_progress = 0;
    }

    /// Stop the motion
    pub fn stop(self: *Self) void {
        self.state = .stopped;
        self.current_time = 0;
        self.weight = 0;
    }

    /// Start fade out
    pub fn fadeOut(self: *Self) void {
        if (self.state == .playing) {
            self.is_fading_out = true;
            self.fade_progress = 0;
        }
    }

    /// Update motion
    pub fn update(self: *Self, delta_sec: f32) void {
        if (self.state != .playing) return;

        self.current_time += delta_sec;

        // Handle fade in
        if (self.is_fading_in) {
            self.fade_progress += delta_sec / self.fade_in_time;
            if (self.fade_progress >= 1.0) {
                self.fade_progress = 1.0;
                self.is_fading_in = false;
            }
            self.weight = self.fade_progress;
        }

        // Handle fade out
        if (self.is_fading_out) {
            self.fade_progress += delta_sec / self.fade_out_time;
            if (self.fade_progress >= 1.0) {
                self.state = .finished;
                self.weight = 0;
                return;
            }
            self.weight = 1.0 - self.fade_progress;
        }

        // Handle loop/finish
        if (self.current_time >= self.duration) {
            if (self.loop) {
                self.current_time = @mod(self.current_time, self.duration);
            } else {
                self.current_time = self.duration;
                self.state = .finished;
            }
        }
    }

    /// Get parameter value at current time
    pub fn getParameterValue(self: *const Self, param_id: []const u8) ?f32 {
        for (self.curves.items) |curve| {
            if (std.mem.eql(u8, curve.target_id, param_id)) {
                return curve.getValueAt(self.current_time) * self.weight;
            }
        }
        return null;
    }
};

// === Expression ===

/// Live2D expression
pub const Expression = struct {
    const Self = @This();

    name: []const u8 = "",
    fade_in_time: f32 = 0.5,
    fade_out_time: f32 = 0.5,

    /// Parameter overrides
    parameters: std.StringHashMap(struct {
        value: f32,
        blend_type: enum { add, multiply, override } = .add,
    }),

    // State
    weight: f32 = 0,
    is_active: bool = false,

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .parameters = std.StringHashMap(struct {
                value: f32,
                blend_type: enum { add, multiply, override },
            }).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.parameters.deinit();
    }
};

// === Physics ===

/// Physics settings for a parameter
pub const PhysicsParameter = struct {
    id: []const u8,
    target_id: []const u8, // Target parameter to affect
    weight: f32 = 1.0,
};

/// Physics input type
pub const PhysicsInputType = enum(u8) {
    x = 0,
    y = 1,
    angle = 2,
};

/// Physics output type
pub const PhysicsOutputType = enum(u8) {
    x = 0,
    y = 1,
    angle = 2,
};

/// Physics pendulum settings
pub const PhysicsPendulum = struct {
    length: f32 = 1.0,
    air_resistance: f32 = 0.5,
    gravity: f32 = 1.0,
};

/// Physics rig for simulation
pub const PhysicsRig = struct {
    const Self = @This();

    settings: std.ArrayList(struct {
        id: []const u8,
        inputs: std.ArrayList(PhysicsParameter),
        outputs: std.ArrayList(PhysicsParameter),
        pendulum: PhysicsPendulum,
        // Simulation state
        position: Point2D,
        velocity: Point2D,
    }),

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .settings = std.ArrayList(struct {
                id: []const u8,
                inputs: std.ArrayList(PhysicsParameter),
                outputs: std.ArrayList(PhysicsParameter),
                pendulum: PhysicsPendulum,
                position: Point2D,
                velocity: Point2D,
            }).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.settings.items) |*setting| {
            setting.inputs.deinit();
            setting.outputs.deinit();
        }
        self.settings.deinit();
    }

    /// Update physics simulation
    pub fn update(self: *Self, delta_sec: f32) void {
        for (self.settings.items) |*setting| {
            // Simple pendulum physics
            const gravity = setting.pendulum.gravity;
            const air_res = setting.pendulum.air_resistance;

            // Apply gravity
            setting.velocity.y += gravity * delta_sec;

            // Apply air resistance
            setting.velocity.x *= (1.0 - air_res * delta_sec);
            setting.velocity.y *= (1.0 - air_res * delta_sec);

            // Update position
            setting.position.x += setting.velocity.x * delta_sec;
            setting.position.y += setting.velocity.y * delta_sec;

            // Clamp to reasonable range
            setting.position.x = @max(-30, @min(30, setting.position.x));
            setting.position.y = @max(-30, @min(30, setting.position.y));
        }
    }
};

// === Eye Blink ===

/// Eye blink controller
pub const EyeBlink = struct {
    const Self = @This();

    // Parameters to control
    left_eye_id: []const u8 = StandardParams.ParamEyeLOpen,
    right_eye_id: []const u8 = StandardParams.ParamEyeROpen,

    // Timing
    blink_interval_min: f32 = 2.0, // seconds
    blink_interval_max: f32 = 5.0, // seconds
    blink_duration: f32 = 0.15, // seconds (closing + opening)

    // State
    time_until_next_blink: f32 = 2.0,
    is_blinking: bool = false,
    blink_progress: f32 = 0,

    /// Update eye blink
    pub fn update(self: *Self, delta_sec: f32) struct { left: f32, right: f32 } {
        if (self.is_blinking) {
            self.blink_progress += delta_sec / self.blink_duration;
            if (self.blink_progress >= 1.0) {
                self.is_blinking = false;
                self.blink_progress = 0;
                self.scheduleNextBlink();
            }
        } else {
            self.time_until_next_blink -= delta_sec;
            if (self.time_until_next_blink <= 0) {
                self.is_blinking = true;
                self.blink_progress = 0;
            }
        }

        // Calculate eye openness (1 = open, 0 = closed)
        var openness: f32 = 1.0;
        if (self.is_blinking) {
            // Close then open (triangle wave)
            if (self.blink_progress < 0.5) {
                openness = 1.0 - (self.blink_progress * 2.0);
            } else {
                openness = (self.blink_progress - 0.5) * 2.0;
            }
        }

        return .{ .left = openness, .right = openness };
    }

    fn scheduleNextBlink(self: *Self) void {
        // Random interval between min and max
        const range = self.blink_interval_max - self.blink_interval_min;
        // Simple pseudo-random using current time
        const seed = @as(u32, @truncate(@as(u64, @bitCast(std.time.milliTimestamp()))));
        const random = @as(f32, @floatFromInt(seed % 1000)) / 1000.0;
        self.time_until_next_blink = self.blink_interval_min + (range * random);
    }
};

// === Lip Sync ===

/// Lip sync controller
pub const LipSync = struct {
    const Self = @This();

    mouth_param_id: []const u8 = StandardParams.ParamMouthOpenY,

    // Current mouth openness (0-1)
    current_value: f32 = 0,
    target_value: f32 = 0,
    smoothing: f32 = 0.3, // Lower = more smoothing

    /// Update from audio amplitude
    pub fn updateFromAmplitude(self: *Self, amplitude: f32, delta_sec: f32) f32 {
        self.target_value = @max(0, @min(1, amplitude));
        // Smooth interpolation
        self.current_value += (self.target_value - self.current_value) * self.smoothing * delta_sec * 60;
        return self.current_value;
    }

    /// Update from phoneme (viseme)
    pub fn updateFromPhoneme(self: *Self, phoneme: Phoneme, delta_sec: f32) f32 {
        self.target_value = phoneme.getMouthOpenness();
        self.current_value += (self.target_value - self.current_value) * self.smoothing * delta_sec * 60;
        return self.current_value;
    }
};

/// Basic phoneme/viseme types
pub const Phoneme = enum(u8) {
    silent = 0, // Mouth closed
    a = 1, // Open mouth
    e = 2, // Wide mouth
    i = 3, // Narrow mouth
    o = 4, // Round mouth
    u = 5, // Pursed lips

    pub fn getMouthOpenness(self: Phoneme) f32 {
        return switch (self) {
            .silent => 0.0,
            .a => 1.0,
            .e => 0.6,
            .i => 0.3,
            .o => 0.7,
            .u => 0.4,
        };
    }
};

// === Model ===

/// Live2D model
pub const Model = struct {
    const Self = @This();

    // Identity
    name: []const u8 = "",
    moc_path: []const u8 = "",
    model_path: []const u8 = "",

    // Canvas
    canvas_width: f32 = 0,
    canvas_height: f32 = 0,
    pixels_per_unit: f32 = 1,

    // Parameters
    parameters: std.StringHashMap(Parameter),

    // Parts
    parts: std.ArrayList(Part),

    // Drawables
    drawables: std.ArrayList(Drawable),

    // Textures (paths or IDs)
    textures: std.ArrayList([]const u8),

    // Motions
    motions: std.StringHashMap(Motion),
    active_motion: ?[]const u8 = null,
    motion_priority: MotionPriority = .none,

    // Expressions
    expressions: std.StringHashMap(Expression),
    active_expression: ?[]const u8 = null,

    // Physics
    physics: ?PhysicsRig = null,
    physics_enabled: bool = true,

    // Eye blink
    eye_blink: EyeBlink = .{},
    auto_blink_enabled: bool = true,

    // Lip sync
    lip_sync: LipSync = .{},

    // Transform
    position: Point2D = Point2D.zero,
    scale: f32 = 1.0,
    rotation: f32 = 0,
    opacity: f32 = 1.0,

    // Callbacks
    callbacks: std.ArrayList(*const fn (AnimationEvent) void),

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .parameters = std.StringHashMap(Parameter).init(allocator),
            .parts = std.ArrayList(Part).init(allocator),
            .drawables = std.ArrayList(Drawable).init(allocator),
            .textures = std.ArrayList([]const u8).init(allocator),
            .motions = std.StringHashMap(Motion).init(allocator),
            .expressions = std.StringHashMap(Expression).init(allocator),
            .callbacks = std.ArrayList(*const fn (AnimationEvent) void).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.parameters.deinit();
        self.parts.deinit();
        self.drawables.deinit();
        self.textures.deinit();

        var motion_it = self.motions.iterator();
        while (motion_it.next()) |entry| {
            var motion = entry.value_ptr;
            motion.deinit();
        }
        self.motions.deinit();

        var expr_it = self.expressions.iterator();
        while (expr_it.next()) |entry| {
            var expr = entry.value_ptr;
            expr.deinit();
        }
        self.expressions.deinit();

        if (self.physics) |*physics| {
            physics.deinit();
        }

        self.callbacks.deinit();
    }

    // === Parameter Control ===

    /// Set parameter value
    pub fn setParameter(self: *Self, param_id: []const u8, value: f32) void {
        if (self.parameters.getPtr(param_id)) |param| {
            param.setValue(value);
        }
    }

    /// Get parameter value
    pub fn getParameter(self: *const Self, param_id: []const u8) ?f32 {
        if (self.parameters.get(param_id)) |param| {
            return param.value;
        }
        return null;
    }

    /// Add to parameter value
    pub fn addParameter(self: *Self, param_id: []const u8, delta: f32) void {
        if (self.parameters.getPtr(param_id)) |param| {
            param.addValue(delta);
        }
    }

    /// Reset all parameters to default
    pub fn resetParameters(self: *Self) void {
        var it = self.parameters.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.reset();
        }
    }

    // === Motion Control ===

    /// Start a motion
    pub fn startMotion(self: *Self, motion_name: []const u8, priority: MotionPriority) bool {
        if (@intFromEnum(priority) < @intFromEnum(self.motion_priority)) {
            return false; // Current motion has higher priority
        }

        if (self.motions.getPtr(motion_name)) |motion| {
            // Fade out current motion
            if (self.active_motion) |current_name| {
                if (self.motions.getPtr(current_name)) |current| {
                    current.fadeOut();
                }
            }

            // Start new motion
            motion.play();
            self.active_motion = motion_name;
            self.motion_priority = priority;

            self.emitEvent(.started);
            return true;
        }
        return false;
    }

    /// Stop current motion
    pub fn stopMotion(self: *Self) void {
        if (self.active_motion) |motion_name| {
            if (self.motions.getPtr(motion_name)) |motion| {
                motion.fadeOut();
            }
        }
        self.motion_priority = .none;
    }

    // === Expression Control ===

    /// Set expression
    pub fn setExpression(self: *Self, expression_name: []const u8) bool {
        // Deactivate current expression
        if (self.active_expression) |current_name| {
            if (self.expressions.getPtr(current_name)) |expr| {
                expr.is_active = false;
            }
        }

        // Activate new expression
        if (self.expressions.getPtr(expression_name)) |expr| {
            expr.is_active = true;
            expr.weight = 1.0;
            self.active_expression = expression_name;
            return true;
        }
        return false;
    }

    // === Eye Tracking ===

    /// Look at a screen position
    pub fn lookAt(self: *Self, target_x: f32, target_y: f32) void {
        // Convert screen position to head angle
        // This is a simplified implementation
        const dx = target_x - self.position.x;
        const dy = target_y - self.position.y;

        // Normalize to -30 to 30 degree range
        const angle_x = @max(-30, @min(30, dx * 0.1));
        const angle_y = @max(-30, @min(30, -dy * 0.1));

        self.setParameter(StandardParams.ParamAngleX, angle_x);
        self.setParameter(StandardParams.ParamAngleY, angle_y);
        self.setParameter(StandardParams.ParamEyeBallX, angle_x / 30.0);
        self.setParameter(StandardParams.ParamEyeBallY, angle_y / 30.0);
    }

    // === Update ===

    /// Update model (call each frame)
    pub fn update(self: *Self, delta_ms: TimeMs) void {
        const delta_sec = @as(f32, @floatFromInt(delta_ms)) / 1000.0;

        // Update active motion
        if (self.active_motion) |motion_name| {
            if (self.motions.getPtr(motion_name)) |motion| {
                motion.update(delta_sec);

                // Apply motion parameters
                for (motion.curves.items) |curve| {
                    if (motion.getParameterValue(curve.target_id)) |value| {
                        self.addParameter(curve.target_id, value);
                    }
                }

                // Check if motion finished
                if (motion.state == .finished) {
                    self.active_motion = null;
                    self.motion_priority = .none;
                    self.emitEvent(.completed);
                }
            }
        }

        // Update eye blink
        if (self.auto_blink_enabled) {
            const blink = self.eye_blink.update(delta_sec);
            self.setParameter(StandardParams.ParamEyeLOpen, blink.left);
            self.setParameter(StandardParams.ParamEyeROpen, blink.right);
        }

        // Update physics
        if (self.physics_enabled) {
            if (self.physics) |*physics| {
                physics.update(delta_sec);
            }
        }

        // Update expression
        if (self.active_expression) |expr_name| {
            if (self.expressions.get(expr_name)) |expr| {
                var it = expr.parameters.iterator();
                while (it.next()) |entry| {
                    const param_value = entry.value_ptr;
                    switch (param_value.blend_type) {
                        .add => self.addParameter(entry.key_ptr.*, param_value.value * expr.weight),
                        .multiply => if (self.getParameter(entry.key_ptr.*)) |current| {
                            self.setParameter(entry.key_ptr.*, current * (1.0 + (param_value.value - 1.0) * expr.weight));
                        },
                        .override => self.setParameter(entry.key_ptr.*, param_value.value * expr.weight),
                    }
                }
            }
        }
    }

    // === Getters ===

    /// Get model size
    pub fn getSize(self: *const Self) Size2D {
        return Size2D{ .width = self.canvas_width, .height = self.canvas_height };
    }

    /// Check if motion is playing
    pub fn isMotionPlaying(self: *const Self) bool {
        return self.active_motion != null;
    }

    // === Events ===

    /// Register event callback
    pub fn onEvent(self: *Self, callback: *const fn (AnimationEvent) void) !void {
        try self.callbacks.append(callback);
    }

    /// Remove all event callbacks
    pub fn clearEventCallbacks(self: *Self) void {
        self.callbacks.clearRetainingCapacity();
    }

    fn emitEvent(self: *Self, event_type: AnimationEventType) void {
        const event = AnimationEvent{
            .event_type = event_type,
            .animation_id = 0,
        };
        for (self.callbacks.items) |callback| {
            callback(event);
        }
    }
};

// === Live2D Manager ===

/// Manager for multiple Live2D models
pub const Live2DManager = struct {
    const Self = @This();

    models: std.AutoHashMap(u32, *Model),
    next_id: u32,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .models = std.AutoHashMap(u32, *Model).init(allocator),
            .next_id = 1,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        var it = self.models.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit();
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.models.deinit();
    }

    /// Create a new model
    pub fn createModel(self: *Self) !u32 {
        const model = try self.allocator.create(Model);
        model.* = Model.init(self.allocator);

        const id = self.next_id;
        self.next_id += 1;

        try self.models.put(id, model);
        return id;
    }

    /// Get model by ID
    pub fn getModel(self: *Self, id: u32) ?*Model {
        return self.models.get(id);
    }

    /// Destroy model
    pub fn destroyModel(self: *Self, id: u32) void {
        if (self.models.fetchRemove(id)) |entry| {
            entry.value.deinit();
            self.allocator.destroy(entry.value);
        }
    }

    /// Update all models
    pub fn updateAll(self: *Self, delta_ms: TimeMs) void {
        var it = self.models.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.update(delta_ms);
        }
    }
};
