//! Lottie Animation - Vector animation support
//!
//! Provides parsing and playback of Lottie JSON animations.
//! Lottie is a JSON-based animation format created by Airbnb.
//!
//! ## Features
//!
//! - JSON animation parsing
//! - Playback control (play, pause, seek, loop)
//! - Animation events and callbacks
//! - Responsive scaling
//! - Marker support
//!
//! ## Platform Backends
//!
//! - iOS: Lottie-ios / Core Animation
//! - Android: Lottie-android
//! - Web: lottie-web / Bodymovin
//! - Desktop: Cross-platform renderer
//!
//! ## Usage
//!
//! ```zig
//! const lottie = @import("lottie.zig");
//!
//! var animation = lottie.Animation.loadFromJson(json_data);
//! animation.setLoopMode(.loop);
//! animation.play();
//!
//! // In render loop
//! animation.update(delta_ms);
//! const frame = animation.getCurrentFrame();
//! ```

const std = @import("std");
const types = @import("types.zig");
const easing = @import("easing.zig");

const TimeMs = types.TimeMs;
const DurationMs = types.DurationMs;
const FrameNumber = types.FrameNumber;
const FrameRate = types.FrameRate;
const PlaybackState = types.PlaybackState;
const LoopMode = types.LoopMode;
const PlayDirection = types.PlayDirection;
const Color = types.Color;
const Point2D = types.Point2D;
const Size2D = types.Size2D;
const Transform2D = types.Transform2D;
const AnimationEvent = types.AnimationEvent;
const AnimationEventType = types.AnimationEventType;
const AnimationError = types.AnimationError;
const PlaybackConfig = types.PlaybackConfig;
const RenderConfig = types.RenderConfig;

// === Lottie Layer Types ===

/// Lottie layer type
pub const LayerType = enum(u8) {
    precomp = 0, // Precomposition
    solid = 1, // Solid color
    image = 2, // Image
    null_layer = 3, // Null (transform only)
    shape = 4, // Shape layer
    text = 5, // Text layer
    audio = 6, // Audio layer
    video_placeholder = 7, // Video placeholder
    image_sequence = 8, // Image sequence
    video = 9, // Video layer
    image_placeholder = 10, // Image placeholder
    guide = 11, // Guide
    adjustment = 12, // Adjustment layer
    camera = 13, // Camera (3D)
    light = 14, // Light (3D)
    data = 15, // Data layer
};

/// Lottie blend mode
pub const LottieBlendMode = enum(u8) {
    normal = 0,
    multiply = 1,
    screen = 2,
    overlay = 3,
    darken = 4,
    lighten = 5,
    color_dodge = 6,
    color_burn = 7,
    hard_light = 8,
    soft_light = 9,
    difference = 10,
    exclusion = 11,
    hue = 12,
    saturation = 13,
    color = 14,
    luminosity = 15,
};

/// Lottie matte type
pub const MatteType = enum(u8) {
    none = 0,
    add = 1,
    invert = 2,
    luma = 3,
    luma_invert = 4,
};

// === Shape Types ===

/// Shape type enum
pub const ShapeType = enum(u8) {
    group = 0, // gr
    rectangle = 1, // rc
    ellipse = 2, // el
    polystar = 3, // sr
    path = 4, // sh
    fill = 5, // fl
    stroke = 6, // st
    gradient_fill = 7, // gf
    gradient_stroke = 8, // gs
    merge = 9, // mm
    trim = 10, // tm
    round = 11, // rd
    repeater = 12, // rp
    transform = 13, // tr
};

/// Path vertex
pub const PathVertex = struct {
    position: Point2D,
    in_tangent: Point2D,
    out_tangent: Point2D,
};

/// Bezier path data
pub const BezierPath = struct {
    vertices: std.ArrayList(PathVertex),
    closed: bool = false,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) BezierPath {
        return BezierPath{
            .vertices = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *BezierPath) void {
        self.vertices.deinit(self.allocator);
    }
};

/// Shape element (union of shape types)
pub const ShapeElement = struct {
    shape_type: ShapeType,
    name: []const u8 = "",
    hidden: bool = false,

    // Rectangle specific
    rect_size: ?Point2D = null,
    rect_position: ?Point2D = null,
    rect_corner_radius: ?f32 = null,

    // Ellipse specific
    ellipse_size: ?Point2D = null,
    ellipse_position: ?Point2D = null,

    // Path specific
    path: ?BezierPath = null,

    // Fill specific
    fill_color: ?Color = null,
    fill_opacity: f32 = 100,

    // Stroke specific
    stroke_color: ?Color = null,
    stroke_width: f32 = 1,
    stroke_opacity: f32 = 100,
    line_cap: u8 = 0, // 0=butt, 1=round, 2=square
    line_join: u8 = 0, // 0=miter, 1=round, 2=bevel

    // Transform
    transform: ?Transform2D = null,
};

// === Keyframe Types ===

/// Animated value with keyframes
pub fn AnimatedValue(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const Keyframe = struct {
            frame: FrameNumber,
            value: T,
            easing_in: ?[2]f32 = null, // Bezier control point
            easing_out: ?[2]f32 = null,
            hold: bool = false, // Step interpolation
        };

        keyframes: std.ArrayList(Keyframe),
        is_animated: bool,
        static_value: T,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, initial_value: T) Self {
            return Self{
                .keyframes = .{},
                .is_animated = false,
                .static_value = initial_value,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.keyframes.deinit(self.allocator);
        }

        /// Get value at specific frame
        pub fn getValueAt(self: *const Self, frame: f32) T {
            if (!self.is_animated or self.keyframes.items.len == 0) {
                return self.static_value;
            }

            const items = self.keyframes.items;
            if (items.len == 1) return items[0].value;

            // Find surrounding keyframes
            var prev_idx: usize = 0;
            var next_idx: usize = items.len - 1;

            for (items, 0..) |kf, i| {
                if (@as(f32, @floatFromInt(kf.frame)) <= frame) {
                    prev_idx = i;
                }
                if (@as(f32, @floatFromInt(kf.frame)) >= frame) {
                    next_idx = i;
                    break;
                }
            }

            const prev_kf = items[prev_idx];
            const next_kf = items[next_idx];

            if (prev_idx == next_idx or prev_kf.hold) {
                return prev_kf.value;
            }

            // Calculate interpolation factor
            const frame_range = @as(f32, @floatFromInt(next_kf.frame - prev_kf.frame));
            const frame_offset = frame - @as(f32, @floatFromInt(prev_kf.frame));
            var t = frame_offset / frame_range;

            // Apply easing if present
            if (prev_kf.easing_out != null and next_kf.easing_in != null) {
                // Cubic bezier interpolation
                const bezier = easing.CubicBezier{
                    .x1 = prev_kf.easing_out.?[0],
                    .y1 = prev_kf.easing_out.?[1],
                    .x2 = next_kf.easing_in.?[0],
                    .y2 = next_kf.easing_in.?[1],
                };
                t = bezier.evaluate(t);
            }

            return interpolateValue(T, prev_kf.value, next_kf.value, t);
        }

        fn interpolateValue(comptime V: type, a: V, b: V, t: f32) V {
            const type_info = @typeInfo(V);
            switch (type_info) {
                .float => return a + (b - a) * t,
                .int => return @intFromFloat(@as(f32, @floatFromInt(a)) * (1 - t) + @as(f32, @floatFromInt(b)) * t),
                .@"struct" => {
                    if (@hasDecl(V, "lerp")) {
                        return a.lerp(b, t);
                    }
                    var result: V = undefined;
                    inline for (std.meta.fields(V)) |field| {
                        @field(result, field.name) = interpolateValue(field.type, @field(a, field.name), @field(b, field.name), t);
                    }
                    return result;
                },
                else => return if (t < 0.5) a else b,
            }
        }
    };
}

// === Layer ===

/// Lottie layer
pub const Layer = struct {
    // Identity
    id: u32 = 0,
    name: []const u8 = "",
    layer_type: LayerType = .shape,

    // Hierarchy
    parent_id: ?u32 = null,
    index: u32 = 0,

    // Timing
    in_point: FrameNumber = 0,
    out_point: FrameNumber = 0,
    start_time: FrameNumber = 0,
    time_stretch: f32 = 1.0,

    // Transform (animated)
    anchor_point: AnimatedValue(Point2D),
    position: AnimatedValue(Point2D),
    scale: AnimatedValue(Point2D),
    rotation: AnimatedValue(f32),
    opacity: AnimatedValue(f32),

    // Appearance
    blend_mode: LottieBlendMode = .normal,
    matte_mode: MatteType = .none,
    matte_target: ?u32 = null,
    hidden: bool = false,

    // Content
    shapes: std.ArrayList(ShapeElement),
    masks: std.ArrayList(BezierPath),

    // For precomp layers
    ref_id: ?[]const u8 = null,

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Layer {
        return Layer{
            .anchor_point = AnimatedValue(Point2D).init(allocator, Point2D.zero),
            .position = AnimatedValue(Point2D).init(allocator, Point2D.zero),
            .scale = AnimatedValue(Point2D).init(allocator, Point2D{ .x = 100, .y = 100 }),
            .rotation = AnimatedValue(f32).init(allocator, 0),
            .opacity = AnimatedValue(f32).init(allocator, 100),
            .shapes = .{},
            .masks = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Layer) void {
        self.anchor_point.deinit();
        self.position.deinit();
        self.scale.deinit();
        self.rotation.deinit();
        self.opacity.deinit();
        self.shapes.deinit(self.allocator);
        for (self.masks.items) |*mask| {
            mask.deinit();
        }
        self.masks.deinit(self.allocator);
    }

    /// Check if layer is visible at given frame
    pub fn isVisibleAt(self: *const Layer, frame: FrameNumber) bool {
        return !self.hidden and frame >= self.in_point and frame < self.out_point;
    }

    /// Get transform at frame
    pub fn getTransformAt(self: *const Layer, frame: f32) Transform2D {
        const anchor = self.anchor_point.getValueAt(frame);
        const pos = self.position.getValueAt(frame);
        const scl = self.scale.getValueAt(frame);
        const rot = self.rotation.getValueAt(frame);
        const opa = self.opacity.getValueAt(frame);

        return Transform2D{
            .position = pos,
            .rotation = rot * std.math.pi / 180.0, // Convert to radians
            .scale = Point2D{ .x = scl.x / 100.0, .y = scl.y / 100.0 },
            .anchor = anchor,
            .opacity = opa / 100.0,
        };
    }
};

// === Animation Marker ===

/// Lottie animation marker
pub const LottieMarker = struct {
    name: []const u8,
    time: FrameNumber, // Frame number
    duration: FrameNumber = 0, // Optional duration in frames
};

// === Animation ===

/// Lottie animation
pub const Animation = struct {
    const Self = @This();

    // Metadata
    name: []const u8 = "",
    version: []const u8 = "",

    // Dimensions
    width: f32 = 0,
    height: f32 = 0,

    // Timing
    frame_rate: FrameRate = 30,
    in_point: FrameNumber = 0,
    out_point: FrameNumber = 0,

    // Content
    layers: std.ArrayList(Layer),
    markers: std.ArrayList(LottieMarker),
    assets: std.StringHashMap([]const u8), // Asset ID -> data

    // Playback state
    state: PlaybackState = .stopped,
    current_frame: f32 = 0,
    loop_mode: LoopMode = .none,
    loop_count: u32 = 0,
    current_loop: u32 = 0,
    speed: f32 = 1.0,
    direction: PlayDirection = .forward,

    // Callbacks
    callbacks: std.ArrayList(*const fn (AnimationEvent) void),

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .layers = .{},
            .markers = .{},
            .assets = std.StringHashMap([]const u8).init(allocator),
            .callbacks = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        // Free duplicated strings
        if (self.name.len > 0) {
            self.allocator.free(self.name);
        }
        if (self.version.len > 0) {
            self.allocator.free(self.version);
        }

        for (self.layers.items) |*layer| {
            layer.deinit();
        }
        self.layers.deinit(self.allocator);

        // Free marker names
        for (self.markers.items) |marker| {
            if (marker.name.len > 0) {
                self.allocator.free(marker.name);
            }
        }
        self.markers.deinit(self.allocator);

        self.assets.deinit();
        self.callbacks.deinit(self.allocator);
    }

    /// Load animation from JSON string
    pub fn loadFromJson(allocator: std.mem.Allocator, json_str: []const u8) !Self {
        var animation = Self.init(allocator);

        // Parse JSON
        const parsed = std.json.parseFromSlice(std.json.Value, allocator, json_str, .{}) catch {
            return error.ParseError;
        };
        defer parsed.deinit();

        const root = parsed.value;

        // Parse metadata (duplicate strings to avoid dangling pointers)
        if (root.object.get("nm")) |name| {
            if (name == .string) {
                animation.name = allocator.dupe(u8, name.string) catch "";
            }
        }
        if (root.object.get("v")) |version| {
            if (version == .string) {
                animation.version = allocator.dupe(u8, version.string) catch "";
            }
        }

        // Parse dimensions
        if (root.object.get("w")) |w| {
            animation.width = switch (w) {
                .integer => @floatFromInt(w.integer),
                .float => @floatCast(w.float),
                else => 0,
            };
        }
        if (root.object.get("h")) |h| {
            animation.height = switch (h) {
                .integer => @floatFromInt(h.integer),
                .float => @floatCast(h.float),
                else => 0,
            };
        }

        // Parse timing
        if (root.object.get("fr")) |fr| {
            animation.frame_rate = switch (fr) {
                .integer => @floatFromInt(fr.integer),
                .float => @floatCast(fr.float),
                else => 30,
            };
        }
        if (root.object.get("ip")) |ip| {
            animation.in_point = switch (ip) {
                .integer => @intCast(ip.integer),
                .float => @intFromFloat(ip.float),
                else => 0,
            };
        }
        if (root.object.get("op")) |op| {
            animation.out_point = switch (op) {
                .integer => @intCast(op.integer),
                .float => @intFromFloat(op.float),
                else => 0,
            };
        }

        // Parse markers
        if (root.object.get("markers")) |markers_array| {
            if (markers_array == .array) {
                for (markers_array.array.items) |marker_obj| {
                    if (marker_obj == .object) {
                        var marker = LottieMarker{
                            .name = "",
                            .time = 0,
                        };
                        if (marker_obj.object.get("cm")) |cm| {
                            if (cm == .string) {
                                marker.name = allocator.dupe(u8, cm.string) catch "";
                            }
                        }
                        if (marker_obj.object.get("tm")) |tm| {
                            marker.time = switch (tm) {
                                .integer => @intCast(tm.integer),
                                .float => @intFromFloat(tm.float),
                                else => 0,
                            };
                        }
                        if (marker_obj.object.get("dr")) |dr| {
                            marker.duration = switch (dr) {
                                .integer => @intCast(dr.integer),
                                .float => @intFromFloat(dr.float),
                                else => 0,
                            };
                        }
                        animation.markers.append(allocator, marker) catch {};
                    }
                }
            }
        }

        // Note: Full layer parsing would be more complex
        // This is a simplified version

        animation.current_frame = @floatFromInt(animation.in_point);
        return animation;
    }

    // === Playback Control ===

    /// Start playback
    pub fn play(self: *Self) void {
        if (self.state == .paused) {
            self.state = .playing;
            self.emitEvent(.resumed);
        } else {
            self.state = .playing;
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

    /// Stop playback and reset
    pub fn stop(self: *Self) void {
        self.state = .stopped;
        self.current_frame = @floatFromInt(self.in_point);
        self.current_loop = 0;
        self.emitEvent(.stopped);
    }

    /// Seek to specific frame
    pub fn seekToFrame(self: *Self, frame: FrameNumber) void {
        self.current_frame = @floatFromInt(@max(self.in_point, @min(frame, self.out_point)));
        self.emitEvent(.frame_changed);
    }

    /// Seek to normalized progress (0-1)
    pub fn seekToProgress(self: *Self, progress: f32) void {
        const total_frames = self.out_point - self.in_point;
        const frame = self.in_point + @as(FrameNumber, @intFromFloat(@as(f32, @floatFromInt(total_frames)) * @max(0, @min(1, progress))));
        self.seekToFrame(frame);
    }

    /// Seek to marker by name
    pub fn seekToMarker(self: *Self, name: []const u8) bool {
        for (self.markers.items) |marker| {
            if (std.mem.eql(u8, marker.name, name)) {
                self.seekToFrame(marker.time);
                self.emitMarkerEvent(marker.name);
                return true;
            }
        }
        return false;
    }

    /// Set playback speed
    pub fn setSpeed(self: *Self, speed: f32) void {
        self.speed = speed;
    }

    /// Set loop mode
    pub fn setLoopMode(self: *Self, mode: LoopMode) void {
        self.loop_mode = mode;
    }

    /// Set loop count (for loop_count mode)
    pub fn setLoopCount(self: *Self, count: u32) void {
        self.loop_count = count;
    }

    /// Set playback direction
    pub fn setDirection(self: *Self, dir: PlayDirection) void {
        self.direction = dir;
    }

    // === Update ===

    /// Update animation (call each frame)
    pub fn update(self: *Self, delta_ms: TimeMs) void {
        if (self.state != .playing) return;

        // Calculate frame delta
        const frame_delta = (@as(f32, @floatFromInt(delta_ms)) / 1000.0) * self.frame_rate * self.speed;

        // Update current frame
        if (self.direction == .forward) {
            self.current_frame += frame_delta;
        } else {
            self.current_frame -= frame_delta;
        }

        // Handle end of animation
        const end_frame = @as(f32, @floatFromInt(self.out_point));
        const start_frame = @as(f32, @floatFromInt(self.in_point));

        if (self.current_frame >= end_frame) {
            switch (self.loop_mode) {
                .none => {
                    self.current_frame = end_frame;
                    self.state = .finished;
                    self.emitEvent(.completed);
                },
                .loop => {
                    self.current_frame = start_frame + @mod(self.current_frame - start_frame, end_frame - start_frame);
                    self.current_loop += 1;
                    self.emitEvent(.loop_completed);
                },
                .ping_pong => {
                    self.direction = .reverse;
                    self.current_frame = end_frame;
                    self.current_loop += 1;
                    self.emitEvent(.loop_completed);
                },
                .loop_count => {
                    self.current_loop += 1;
                    if (self.current_loop >= self.loop_count) {
                        self.current_frame = end_frame;
                        self.state = .finished;
                        self.emitEvent(.completed);
                    } else {
                        self.current_frame = start_frame;
                        self.emitEvent(.loop_completed);
                    }
                },
            }
        } else if (self.current_frame < start_frame) {
            if (self.loop_mode == .ping_pong) {
                self.direction = .forward;
                self.current_frame = start_frame;
            } else {
                self.current_frame = start_frame;
            }
        }
    }

    // === Getters ===

    /// Get current frame number
    pub fn getCurrentFrame(self: *const Self) FrameNumber {
        return @intFromFloat(self.current_frame);
    }

    /// Get current progress (0-1)
    pub fn getProgress(self: *const Self) f32 {
        const total = @as(f32, @floatFromInt(self.out_point - self.in_point));
        if (total == 0) return 0;
        return (self.current_frame - @as(f32, @floatFromInt(self.in_point))) / total;
    }

    /// Get total frame count
    pub fn getTotalFrames(self: *const Self) FrameNumber {
        return self.out_point - self.in_point;
    }

    /// Get duration in milliseconds
    pub fn getDurationMs(self: *const Self) DurationMs {
        const frames = self.out_point - self.in_point;
        return @intFromFloat(@as(f32, @floatFromInt(frames)) / self.frame_rate * 1000.0);
    }

    /// Get playback state
    pub fn getState(self: *const Self) PlaybackState {
        return self.state;
    }

    /// Check if playing
    pub fn isPlaying(self: *const Self) bool {
        return self.state == .playing;
    }

    /// Get size
    pub fn getSize(self: *const Self) Size2D {
        return Size2D{ .width = self.width, .height = self.height };
    }

    // === Event Handling ===

    /// Register event callback
    pub fn onEvent(self: *Self, callback: *const fn (AnimationEvent) void) void {
        self.callbacks.append(self.allocator, callback) catch {};
    }

    fn emitEvent(self: *Self, event_type: AnimationEventType) void {
        const event = AnimationEvent{
            .event_type = event_type,
            .animation_id = 0,
            .current_frame = @intFromFloat(self.current_frame),
            .current_time = @intFromFloat(self.current_frame / self.frame_rate * 1000),
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
            .current_frame = @intFromFloat(self.current_frame),
            .marker_name = marker_name,
        };
        for (self.callbacks.items) |callback| {
            callback(event);
        }
    }
};

// === Lottie Manager ===

/// Manager for multiple Lottie animations
pub const LottieManager = struct {
    const Self = @This();

    animations: std.AutoHashMap(u32, *Animation),
    next_id: u32,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .animations = std.AutoHashMap(u32, *Animation).init(allocator),
            .next_id = 1,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        var it = self.animations.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit();
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.animations.deinit();
    }

    /// Load animation from JSON and return ID
    pub fn loadFromJson(self: *Self, json_str: []const u8) !u32 {
        const animation = try self.allocator.create(Animation);
        animation.* = try Animation.loadFromJson(self.allocator, json_str);

        const id = self.next_id;
        self.next_id += 1;

        try self.animations.put(id, animation);
        return id;
    }

    /// Get animation by ID
    pub fn getAnimation(self: *Self, id: u32) ?*Animation {
        return self.animations.get(id);
    }

    /// Unload animation
    pub fn unload(self: *Self, id: u32) void {
        if (self.animations.fetchRemove(id)) |entry| {
            entry.value.deinit();
            self.allocator.destroy(entry.value);
        }
    }

    /// Update all animations
    pub fn updateAll(self: *Self, delta_ms: TimeMs) void {
        var it = self.animations.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.update(delta_ms);
        }
    }
};
