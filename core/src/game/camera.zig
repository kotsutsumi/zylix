//! Camera System
//!
//! Provides 2D camera functionality including following targets,
//! screen shake, zoom, and viewport management.

const std = @import("std");
const sprite = @import("sprite.zig");

const Vec2 = sprite.Vec2;
const Rect = sprite.Rect;

/// Camera follow mode
pub const FollowMode = enum(u8) {
    none = 0, // No following
    instant = 1, // Instant snap to target
    smooth = 2, // Smooth interpolation
    deadzone = 3, // Only move when target leaves deadzone
    lookahead = 4, // Anticipate target movement
};

/// Screen shake effect
pub const ScreenShake = struct {
    intensity: f32 = 0, // Shake amplitude
    duration: f32 = 0, // Remaining duration
    frequency: f32 = 10, // Oscillation frequency
    decay: f32 = 1, // Decay rate (1 = linear)
    offset: Vec2 = .{}, // Current shake offset
    time: f32 = 0, // Internal timer

    pub fn start(self: *ScreenShake, intensity: f32, duration: f32) void {
        self.intensity = intensity;
        self.duration = duration;
        self.time = 0;
    }

    pub fn update(self: *ScreenShake, delta_time: f32) void {
        if (self.duration <= 0) {
            self.offset = .{};
            return;
        }

        self.time += delta_time;
        self.duration -= delta_time;

        // Calculate decay factor
        const decay_factor = std.math.pow(f32, self.duration / (self.duration + delta_time), self.decay);
        const current_intensity = self.intensity * decay_factor;

        // Perlin-like noise simulation using sine waves
        const t = self.time * self.frequency;
        self.offset = .{
            .x = @sin(t * 1.0) * @cos(t * 0.7) * current_intensity,
            .y = @cos(t * 1.1) * @sin(t * 0.8) * current_intensity,
        };
    }

    pub fn stop(self: *ScreenShake) void {
        self.intensity = 0;
        self.duration = 0;
        self.offset = .{};
    }

    pub fn isActive(self: *const ScreenShake) bool {
        return self.duration > 0;
    }
};

/// Camera bounds constraint
pub const CameraBounds = struct {
    enabled: bool = false,
    min_x: f32 = 0,
    min_y: f32 = 0,
    max_x: f32 = std.math.floatMax(f32),
    max_y: f32 = std.math.floatMax(f32),

    pub fn fromRect(rect: Rect) CameraBounds {
        return .{
            .enabled = true,
            .min_x = rect.x,
            .min_y = rect.y,
            .max_x = rect.x + rect.width,
            .max_y = rect.y + rect.height,
        };
    }

    pub fn constrain(self: *const CameraBounds, position: Vec2, viewport_width: f32, viewport_height: f32) Vec2 {
        if (!self.enabled) return position;

        const half_w = viewport_width / 2;
        const half_h = viewport_height / 2;

        const min_x = self.min_x + half_w;
        const max_x = self.max_x - half_w;
        const min_y = self.min_y + half_h;
        const max_y = self.max_y - half_h;

        // Handle case where viewport exceeds bounds (center on bounds)
        return .{
            .x = if (min_x >= max_x) (self.min_x + self.max_x) / 2 else std.math.clamp(position.x, min_x, max_x),
            .y = if (min_y >= max_y) (self.min_y + self.max_y) / 2 else std.math.clamp(position.y, min_y, max_y),
        };
    }
};

/// Deadzone configuration
pub const Deadzone = struct {
    width: f32 = 100,
    height: f32 = 100,
    offset_x: f32 = 0,
    offset_y: f32 = 0,
};

/// 2D Camera
pub const Camera2D = struct {
    // Position (center of viewport)
    position: Vec2 = .{},
    target_position: Vec2 = .{},

    // Viewport
    viewport_width: f32 = 800,
    viewport_height: f32 = 600,

    // Zoom
    zoom: f32 = 1.0,
    target_zoom: f32 = 1.0,
    min_zoom: f32 = 0.1,
    max_zoom: f32 = 10.0,
    zoom_speed: f32 = 5.0,

    // Rotation
    rotation: f32 = 0, // radians
    target_rotation: f32 = 0,
    rotation_speed: f32 = 5.0,

    // Following
    follow_mode: FollowMode = .none,
    follow_target: ?*const Vec2 = null,
    follow_speed: f32 = 5.0,
    follow_offset: Vec2 = .{}, // Offset from target
    lookahead_factor: f32 = 0.5, // For lookahead mode

    // Deadzone
    deadzone: Deadzone = .{},

    // Bounds
    bounds: CameraBounds = .{},

    // Effects
    shake: ScreenShake = .{},

    // Previous target velocity (for lookahead)
    prev_target_pos: Vec2 = .{},

    pub fn init(viewport_width: f32, viewport_height: f32) Camera2D {
        return .{
            .viewport_width = viewport_width,
            .viewport_height = viewport_height,
        };
    }

    /// Update camera state
    pub fn update(self: *Camera2D, delta_time: f32) void {
        // Update follow target
        if (self.follow_target) |target| {
            self.updateFollow(target.*, delta_time);
        }

        // Smooth position interpolation
        if (self.follow_mode != .instant) {
            self.position = self.lerp(self.position, self.target_position, self.follow_speed * delta_time);
        } else {
            self.position = self.target_position;
        }

        // Constrain to bounds
        self.position = self.bounds.constrain(self.position, self.viewport_width / self.zoom, self.viewport_height / self.zoom);

        // Smooth zoom interpolation
        self.zoom = self.lerp1D(self.zoom, self.target_zoom, self.zoom_speed * delta_time);
        self.zoom = std.math.clamp(self.zoom, self.min_zoom, self.max_zoom);

        // Smooth rotation interpolation
        self.rotation = self.lerpAngle(self.rotation, self.target_rotation, self.rotation_speed * delta_time);

        // Update shake
        self.shake.update(delta_time);
    }

    fn updateFollow(self: *Camera2D, target_pos: Vec2, delta_time: f32) void {
        const target_with_offset = target_pos.add(self.follow_offset);

        switch (self.follow_mode) {
            .none => {},
            .instant => {
                self.target_position = target_with_offset;
            },
            .smooth => {
                self.target_position = target_with_offset;
            },
            .deadzone => {
                // Only move if target leaves deadzone
                const dz = self.deadzone;
                const rel_x = target_with_offset.x - self.target_position.x;
                const rel_y = target_with_offset.y - self.target_position.y;

                if (@abs(rel_x) > dz.width / 2) {
                    self.target_position.x = target_with_offset.x - std.math.sign(rel_x) * dz.width / 2;
                }
                if (@abs(rel_y) > dz.height / 2) {
                    self.target_position.y = target_with_offset.y - std.math.sign(rel_y) * dz.height / 2;
                }
            },
            .lookahead => {
                // Anticipate movement (guard against division by zero)
                if (delta_time > 0) {
                    const velocity = Vec2{
                        .x = (target_pos.x - self.prev_target_pos.x) / delta_time,
                        .y = (target_pos.y - self.prev_target_pos.y) / delta_time,
                    };
                    const lookahead = velocity.scale(self.lookahead_factor);
                    self.target_position = target_with_offset.add(lookahead);
                } else {
                    self.target_position = target_with_offset;
                }
                self.prev_target_pos = target_pos;
            },
        }
    }

    /// Set camera to follow a target
    pub fn follow(self: *Camera2D, target: *const Vec2, mode: FollowMode) void {
        self.follow_target = target;
        self.follow_mode = mode;
        self.prev_target_pos = target.*;
    }

    /// Stop following
    pub fn unfollow(self: *Camera2D) void {
        self.follow_target = null;
        self.follow_mode = .none;
    }

    /// Set camera position directly
    pub fn setPosition(self: *Camera2D, x: f32, y: f32) void {
        self.position = .{ .x = x, .y = y };
        self.target_position = self.position;
    }

    /// Move camera by delta
    pub fn move(self: *Camera2D, dx: f32, dy: f32) void {
        self.target_position.x += dx;
        self.target_position.y += dy;
    }

    /// Set zoom level
    pub fn setZoom(self: *Camera2D, zoom: f32) void {
        self.target_zoom = std.math.clamp(zoom, self.min_zoom, self.max_zoom);
    }

    /// Zoom by factor
    pub fn zoomBy(self: *Camera2D, factor: f32) void {
        self.setZoom(self.target_zoom * factor);
    }

    /// Set rotation
    pub fn setRotation(self: *Camera2D, radians: f32) void {
        self.target_rotation = radians;
    }

    /// Rotate by delta
    pub fn rotate(self: *Camera2D, delta_radians: f32) void {
        self.target_rotation += delta_radians;
    }

    /// Start screen shake
    pub fn startShake(self: *Camera2D, intensity: f32, duration: f32) void {
        self.shake.start(intensity, duration);
    }

    /// Stop screen shake
    pub fn stopShake(self: *Camera2D) void {
        self.shake.stop();
    }

    /// Set camera bounds
    pub fn setBounds(self: *Camera2D, bounds: Rect) void {
        self.bounds = CameraBounds.fromRect(bounds);
    }

    /// Remove camera bounds
    pub fn removeBounds(self: *Camera2D) void {
        self.bounds.enabled = false;
    }

    /// Get the view matrix components
    pub fn getViewTransform(self: *const Camera2D) [6]f32 {
        const effective_pos = self.position.add(self.shake.offset);

        const cos_r = @cos(-self.rotation);
        const sin_r = @sin(-self.rotation);

        // Scale -> Rotate -> Translate
        const a = cos_r * self.zoom;
        const b = sin_r * self.zoom;
        const c = -sin_r * self.zoom;
        const d = cos_r * self.zoom;
        const tx = -effective_pos.x * a - effective_pos.y * c + self.viewport_width / 2;
        const ty = -effective_pos.x * b - effective_pos.y * d + self.viewport_height / 2;

        return .{ a, b, c, d, tx, ty };
    }

    /// Convert screen coordinates to world coordinates
    pub fn screenToWorld(self: *const Camera2D, screen_x: f32, screen_y: f32) Vec2 {
        const effective_pos = self.position.add(self.shake.offset);

        // Translate to camera center
        const cx = screen_x - self.viewport_width / 2;
        const cy = screen_y - self.viewport_height / 2;

        // Inverse zoom
        const ux = cx / self.zoom;
        const uy = cy / self.zoom;

        // Inverse rotation
        const cos_r = @cos(self.rotation);
        const sin_r = @sin(self.rotation);
        const rx = ux * cos_r - uy * sin_r;
        const ry = ux * sin_r + uy * cos_r;

        // Translate back
        return .{
            .x = rx + effective_pos.x,
            .y = ry + effective_pos.y,
        };
    }

    /// Convert world coordinates to screen coordinates
    pub fn worldToScreen(self: *const Camera2D, world_x: f32, world_y: f32) Vec2 {
        const effective_pos = self.position.add(self.shake.offset);

        // Translate relative to camera
        const dx = world_x - effective_pos.x;
        const dy = world_y - effective_pos.y;

        // Apply rotation
        const cos_r = @cos(-self.rotation);
        const sin_r = @sin(-self.rotation);
        const rx = dx * cos_r - dy * sin_r;
        const ry = dx * sin_r + dy * cos_r;

        // Apply zoom and center
        return .{
            .x = rx * self.zoom + self.viewport_width / 2,
            .y = ry * self.zoom + self.viewport_height / 2,
        };
    }

    /// Get visible world bounds
    pub fn getVisibleBounds(self: *const Camera2D) Rect {
        const half_w = (self.viewport_width / self.zoom) / 2;
        const half_h = (self.viewport_height / self.zoom) / 2;
        const effective_pos = self.position.add(self.shake.offset);

        return .{
            .x = effective_pos.x - half_w,
            .y = effective_pos.y - half_h,
            .width = half_w * 2,
            .height = half_h * 2,
        };
    }

    /// Check if a point is visible
    pub fn isPointVisible(self: *const Camera2D, point: Vec2) bool {
        return self.getVisibleBounds().contains(point);
    }

    /// Check if a rect is visible
    pub fn isRectVisible(self: *const Camera2D, rect: Rect) bool {
        return self.getVisibleBounds().intersects(rect);
    }

    // Helper functions
    fn lerp(self: *const Camera2D, a: Vec2, b: Vec2, t: f32) Vec2 {
        _ = self;
        const clamped_t = std.math.clamp(t, 0, 1);
        return .{
            .x = a.x + (b.x - a.x) * clamped_t,
            .y = a.y + (b.y - a.y) * clamped_t,
        };
    }

    fn lerp1D(self: *const Camera2D, a: f32, b: f32, t: f32) f32 {
        _ = self;
        const clamped_t = std.math.clamp(t, 0, 1);
        return a + (b - a) * clamped_t;
    }

    fn lerpAngle(self: *const Camera2D, a: f32, b: f32, t: f32) f32 {
        _ = self;
        var diff = b - a;

        // Normalize to -PI to PI
        while (diff > std.math.pi) diff -= 2 * std.math.pi;
        while (diff < -std.math.pi) diff += 2 * std.math.pi;

        return a + diff * std.math.clamp(t, 0, 1);
    }
};

test "Camera2D basic" {
    var camera = Camera2D.init(800, 600);

    camera.setPosition(100, 200);
    try std.testing.expectEqual(@as(f32, 100), camera.position.x);
    try std.testing.expectEqual(@as(f32, 200), camera.position.y);
}

test "Camera2D screen to world conversion" {
    var camera = Camera2D.init(800, 600);
    camera.setPosition(0, 0);
    camera.update(0);

    // Center of screen should be camera position
    const world = camera.screenToWorld(400, 300);
    try std.testing.expectApproxEqAbs(@as(f32, 0), world.x, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0), world.y, 0.01);
}

test "Camera2D zoom" {
    var camera = Camera2D.init(800, 600);

    camera.setZoom(2.0);
    camera.zoom = camera.target_zoom; // Skip interpolation

    const bounds = camera.getVisibleBounds();

    // At 2x zoom, visible area should be half size
    try std.testing.expectApproxEqAbs(@as(f32, 400), bounds.width, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 300), bounds.height, 0.01);
}

test "Camera2D bounds constraint" {
    var camera = Camera2D.init(800, 600);
    camera.setBounds(.{ .x = 0, .y = 0, .width = 1000, .height = 800 });

    // Try to move outside bounds
    camera.setPosition(-100, -100);
    camera.update(0);

    // Should be constrained
    try std.testing.expect(camera.position.x >= 0);
    try std.testing.expect(camera.position.y >= 0);
}

test "ScreenShake basic" {
    var shake = ScreenShake{};

    shake.start(10, 1);
    try std.testing.expect(shake.isActive());

    shake.update(0.5);
    try std.testing.expect(shake.isActive());
    try std.testing.expect(shake.offset.x != 0 or shake.offset.y != 0);

    shake.update(0.6);
    try std.testing.expect(!shake.isActive());
}
