//! Zylix 3D Graphics - Lighting System
//!
//! Various light types for 3D scene illumination.

const std = @import("std");
const types = @import("types.zig");

const Vec3 = types.Vec3;
const Color = types.Color;
const Transform = types.Transform;

// ============================================================================
// Light Types
// ============================================================================

/// Type of light source
pub const LightType = enum {
    directional,
    point,
    spot,
    area,
};

/// Shadow quality settings
pub const ShadowQuality = enum {
    off,
    low, // 512x512
    medium, // 1024x1024
    high, // 2048x2048
    ultra, // 4096x4096
};

/// Shadow map resolution based on quality
pub fn getShadowResolution(quality: ShadowQuality) u32 {
    return switch (quality) {
        .off => 0,
        .low => 512,
        .medium => 1024,
        .high => 2048,
        .ultra => 4096,
    };
}

// ============================================================================
// Base Light
// ============================================================================

/// Common light properties
pub const LightBase = struct {
    enabled: bool = true,
    color: Color = Color.white(),
    intensity: f32 = 1.0,

    // Shadow settings
    cast_shadows: bool = false,
    shadow_quality: ShadowQuality = .medium,
    shadow_bias: f32 = 0.005,
    shadow_normal_bias: f32 = 0.4,

    // Culling
    culling_mask: u32 = 0xFFFFFFFF,

    pub fn getEffectiveColor(self: LightBase) Color {
        return Color.rgba(
            self.color.r * self.intensity,
            self.color.g * self.intensity,
            self.color.b * self.intensity,
            self.color.a,
        );
    }
};

// ============================================================================
// Directional Light
// ============================================================================

/// Directional light (sun-like, infinite distance)
pub const DirectionalLight = struct {
    base: LightBase = .{},
    transform: Transform = Transform.identity(),

    // Cascade shadow settings
    cascade_count: u8 = 4,
    cascade_split_lambda: f32 = 0.5, // Practical split scheme lambda

    pub fn init() DirectionalLight {
        var light = DirectionalLight{};
        // Default direction: pointing down and forward (-Y, -Z)
        light.transform.rotation = types.Quaternion.fromEuler(std.math.pi / 4.0, 0, 0);
        return light;
    }

    pub fn getDirection(self: DirectionalLight) Vec3 {
        return self.transform.rotation.rotateVec3(Vec3.init(0, 0, -1)).normalize();
    }

    pub fn setDirection(self: *DirectionalLight, direction: Vec3) void {
        const dir = direction.normalize();
        // Calculate rotation to align forward vector with direction
        const forward = Vec3.init(0, 0, -1);
        const axis = forward.cross(dir);
        if (axis.length() > 0.0001) {
            const angle = std.math.acos(std.math.clamp(forward.dot(dir), -1.0, 1.0));
            self.transform.rotation = types.Quaternion.fromAxisAngle(axis.normalize(), angle);
        }
    }
};

// ============================================================================
// Point Light
// ============================================================================

/// Point light (omni-directional, local position)
pub const PointLight = struct {
    base: LightBase = .{},
    transform: Transform = Transform.identity(),

    // Attenuation
    range: f32 = 10.0,
    constant_attenuation: f32 = 1.0,
    linear_attenuation: f32 = 0.09,
    quadratic_attenuation: f32 = 0.032,

    pub fn init() PointLight {
        return .{};
    }

    pub fn initWithRange(range: f32) PointLight {
        var light = PointLight{};
        light.range = range;
        // Auto-calculate attenuation based on range
        light.calculateAttenuation();
        return light;
    }

    /// Calculate attenuation coefficients based on range
    pub fn calculateAttenuation(self: *PointLight) void {
        // These values give a natural falloff where intensity is ~5% at range
        self.constant_attenuation = 1.0;
        self.linear_attenuation = 4.5 / self.range;
        self.quadratic_attenuation = 75.0 / (self.range * self.range);
    }

    /// Get attenuation factor at distance
    pub fn getAttenuation(self: PointLight, distance: f32) f32 {
        if (distance >= self.range) return 0;

        const attenuation = 1.0 / (self.constant_attenuation +
            self.linear_attenuation * distance +
            self.quadratic_attenuation * distance * distance);

        // Smooth falloff at range boundary
        const smooth_factor = 1.0 - std.math.pow(f32, distance / self.range, 4);
        return attenuation * std.math.clamp(smooth_factor, 0, 1);
    }

    /// Get bounding sphere for culling
    pub fn getBoundingSphere(self: PointLight) types.BoundingSphere {
        return .{
            .center = self.transform.position,
            .radius = self.range,
        };
    }
};

// ============================================================================
// Spot Light
// ============================================================================

/// Spot light (cone-shaped, local position and direction)
pub const SpotLight = struct {
    base: LightBase = .{},
    transform: Transform = Transform.identity(),

    // Cone settings
    inner_cone_angle: f32 = std.math.pi / 6.0, // 30 degrees
    outer_cone_angle: f32 = std.math.pi / 4.0, // 45 degrees

    // Attenuation
    range: f32 = 10.0,
    constant_attenuation: f32 = 1.0,
    linear_attenuation: f32 = 0.09,
    quadratic_attenuation: f32 = 0.032,

    pub fn init() SpotLight {
        return .{};
    }

    pub fn getDirection(self: SpotLight) Vec3 {
        return self.transform.rotation.rotateVec3(Vec3.init(0, 0, -1)).normalize();
    }

    pub fn setDirection(self: *SpotLight, direction: Vec3) void {
        const dir = direction.normalize();
        const forward = Vec3.init(0, 0, -1);
        const axis = forward.cross(dir);
        if (axis.length() > 0.0001) {
            const angle = std.math.acos(std.math.clamp(forward.dot(dir), -1.0, 1.0));
            self.transform.rotation = types.Quaternion.fromAxisAngle(axis.normalize(), angle);
        }
    }

    /// Get spot intensity factor based on angle from center
    pub fn getSpotFactor(self: SpotLight, to_light_dir: Vec3) f32 {
        const light_dir = self.getDirection().negate();
        const cos_angle = to_light_dir.dot(light_dir);

        const cos_inner = @cos(self.inner_cone_angle);
        const cos_outer = @cos(self.outer_cone_angle);

        if (cos_angle >= cos_inner) return 1.0;
        if (cos_angle <= cos_outer) return 0.0;

        // Smooth interpolation in penumbra
        const t = (cos_angle - cos_outer) / (cos_inner - cos_outer);
        return t * t * (3.0 - 2.0 * t); // smoothstep
    }

    /// Get attenuation at distance
    pub fn getAttenuation(self: SpotLight, distance: f32) f32 {
        if (distance >= self.range) return 0;

        const attenuation = 1.0 / (self.constant_attenuation +
            self.linear_attenuation * distance +
            self.quadratic_attenuation * distance * distance);

        const smooth_factor = 1.0 - std.math.pow(f32, distance / self.range, 4);
        return attenuation * std.math.clamp(smooth_factor, 0, 1);
    }

    /// Get bounding cone for culling (approximated as sphere)
    pub fn getBoundingSphere(self: SpotLight) types.BoundingSphere {
        return .{
            .center = self.transform.position,
            .radius = self.range,
        };
    }
};

// ============================================================================
// Area Light
// ============================================================================

/// Area light (rectangular emissive surface)
pub const AreaLight = struct {
    base: LightBase = .{},
    transform: Transform = Transform.identity(),

    // Area dimensions
    width: f32 = 1.0,
    height: f32 = 1.0,

    // Attenuation
    range: f32 = 10.0,

    // Light texture (for shaped lights)
    use_cookie: bool = false,

    pub fn init() AreaLight {
        return .{};
    }

    pub fn initWithSize(width: f32, height: f32) AreaLight {
        return .{
            .width = width,
            .height = height,
        };
    }

    pub fn getCorners(self: AreaLight) [4]Vec3 {
        const half_w = self.width * 0.5;
        const half_h = self.height * 0.5;

        const corners = [4]Vec3{
            Vec3.init(-half_w, -half_h, 0),
            Vec3.init(half_w, -half_h, 0),
            Vec3.init(half_w, half_h, 0),
            Vec3.init(-half_w, half_h, 0),
        };

        var world_corners: [4]Vec3 = undefined;
        for (corners, 0..) |corner, i| {
            world_corners[i] = self.transform.rotation.rotateVec3(corner).add(self.transform.position);
        }

        return world_corners;
    }

    pub fn getNormal(self: AreaLight) Vec3 {
        return self.transform.rotation.rotateVec3(Vec3.init(0, 0, -1)).normalize();
    }

    pub fn getArea(self: AreaLight) f32 {
        return self.width * self.height;
    }
};

// ============================================================================
// Ambient Light
// ============================================================================

/// Global ambient light settings
pub const AmbientLight = struct {
    color: Color = Color.rgb(0.1, 0.1, 0.1),
    intensity: f32 = 1.0,

    // Sky ambient (gradient from horizon to zenith)
    use_sky_ambient: bool = false,
    sky_color: Color = Color.rgb(0.5, 0.6, 0.8),
    horizon_color: Color = Color.rgb(0.8, 0.8, 0.9),
    ground_color: Color = Color.rgb(0.3, 0.25, 0.2),

    pub fn init() AmbientLight {
        return .{};
    }

    pub fn getAmbientColor(self: AmbientLight, normal: Vec3) Color {
        if (!self.use_sky_ambient) {
            return Color.rgba(
                self.color.r * self.intensity,
                self.color.g * self.intensity,
                self.color.b * self.intensity,
                1.0,
            );
        }

        // Blend between ground, horizon, and sky based on normal Y
        const y = normal.y;
        if (y > 0) {
            // Upper hemisphere: blend horizon to sky
            return self.horizon_color.lerp(self.sky_color, y);
        } else {
            // Lower hemisphere: blend horizon to ground
            return self.ground_color.lerp(self.horizon_color, y + 1.0);
        }
    }
};

// ============================================================================
// Light Manager
// ============================================================================

/// Light reference for type-erased storage
pub const LightRef = struct {
    ptr: *anyopaque,
    light_type: LightType,
    get_base_fn: *const fn (*anyopaque) *LightBase,
    get_transform_fn: *const fn (*anyopaque) *Transform,

    pub fn getBase(self: LightRef) *LightBase {
        return self.get_base_fn(self.ptr);
    }

    pub fn getTransform(self: LightRef) *Transform {
        return self.get_transform_fn(self.ptr);
    }
};

/// Manages all lights in a scene
pub const LightManager = struct {
    directional_lights: std.ArrayList(*DirectionalLight),
    point_lights: std.ArrayList(*PointLight),
    spot_lights: std.ArrayList(*SpotLight),
    area_lights: std.ArrayList(*AreaLight),
    ambient: AmbientLight = AmbientLight.init(),
    allocator: std.mem.Allocator,

    // Limits
    max_directional: u8 = 4,
    max_point: u16 = 256,
    max_spot: u16 = 128,
    max_area: u16 = 32,

    pub fn init(allocator: std.mem.Allocator) LightManager {
        return .{
            .directional_lights = .{},
            .point_lights = .{},
            .spot_lights = .{},
            .area_lights = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *LightManager) void {
        self.directional_lights.deinit(self.allocator);
        self.point_lights.deinit(self.allocator);
        self.spot_lights.deinit(self.allocator);
        self.area_lights.deinit(self.allocator);
    }

    pub fn addDirectionalLight(self: *LightManager, light: *DirectionalLight) !void {
        if (self.directional_lights.items.len >= self.max_directional) return error.MaxLightsReached;
        try self.directional_lights.append(self.allocator, light);
    }

    pub fn addPointLight(self: *LightManager, light: *PointLight) !void {
        if (self.point_lights.items.len >= self.max_point) return error.MaxLightsReached;
        try self.point_lights.append(self.allocator, light);
    }

    pub fn addSpotLight(self: *LightManager, light: *SpotLight) !void {
        if (self.spot_lights.items.len >= self.max_spot) return error.MaxLightsReached;
        try self.spot_lights.append(self.allocator, light);
    }

    pub fn addAreaLight(self: *LightManager, light: *AreaLight) !void {
        if (self.area_lights.items.len >= self.max_area) return error.MaxLightsReached;
        try self.area_lights.append(self.allocator, light);
    }

    pub fn removeDirectionalLight(self: *LightManager, light: *DirectionalLight) void {
        for (self.directional_lights.items, 0..) |l, i| {
            if (l == light) {
                _ = self.directional_lights.orderedRemove(i);
                return;
            }
        }
    }

    pub fn removePointLight(self: *LightManager, light: *PointLight) void {
        for (self.point_lights.items, 0..) |l, i| {
            if (l == light) {
                _ = self.point_lights.orderedRemove(i);
                return;
            }
        }
    }

    pub fn removeSpotLight(self: *LightManager, light: *SpotLight) void {
        for (self.spot_lights.items, 0..) |l, i| {
            if (l == light) {
                _ = self.spot_lights.orderedRemove(i);
                return;
            }
        }
    }

    pub fn removeAreaLight(self: *LightManager, light: *AreaLight) void {
        for (self.area_lights.items, 0..) |l, i| {
            if (l == light) {
                _ = self.area_lights.orderedRemove(i);
                return;
            }
        }
    }

    /// Get lights affecting a point (for forward rendering)
    pub fn getAffectingPointLights(self: *const LightManager, point: Vec3, result: *std.ArrayList(*PointLight)) void {
        result.clearRetainingCapacity();
        for (self.point_lights.items) |light| {
            if (!light.base.enabled) continue;
            const distance = point.sub(light.transform.position).length();
            if (distance < light.range) {
                result.append(self.allocator, light) catch {};
            }
        }
    }

    /// Get lights affecting a point (spot lights)
    pub fn getAffectingSpotLights(self: *const LightManager, point: Vec3, result: *std.ArrayList(*SpotLight)) void {
        result.clearRetainingCapacity();
        for (self.spot_lights.items) |light| {
            if (!light.base.enabled) continue;
            const distance = point.sub(light.transform.position).length();
            if (distance < light.range) {
                result.append(self.allocator, light) catch {};
            }
        }
    }

    /// Get total light count
    pub fn getTotalLightCount(self: *const LightManager) usize {
        return self.directional_lights.items.len +
            self.point_lights.items.len +
            self.spot_lights.items.len +
            self.area_lights.items.len;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "DirectionalLight direction" {
    var light = DirectionalLight.init();
    light.setDirection(Vec3.init(0, -1, 0)); // Pointing straight down

    const dir = light.getDirection();
    try std.testing.expectApproxEqAbs(@as(f32, 0), dir.x, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, -1), dir.y, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0), dir.z, 0.01);
}

test "PointLight attenuation" {
    var light = PointLight.initWithRange(10.0);

    // At distance 0, attenuation should be 1
    try std.testing.expectApproxEqAbs(@as(f32, 1), light.getAttenuation(0), 0.01);

    // At range, attenuation should be 0
    try std.testing.expectApproxEqAbs(@as(f32, 0), light.getAttenuation(10.0), 0.01);

    // Midpoint should be between 0 and 1
    const mid = light.getAttenuation(5.0);
    try std.testing.expect(mid > 0 and mid < 1);
}

test "SpotLight cone factor" {
    var light = SpotLight.init();
    light.inner_cone_angle = std.math.pi / 6.0; // 30 degrees
    light.outer_cone_angle = std.math.pi / 4.0; // 45 degrees

    // Direction aligned with light should have factor 1
    const factor_center = light.getSpotFactor(Vec3.init(0, 0, 1)); // Pointing at light
    try std.testing.expectApproxEqAbs(@as(f32, 1), factor_center, 0.01);
}

test "AmbientLight sky ambient" {
    var ambient = AmbientLight.init();
    ambient.use_sky_ambient = true;

    // Up-facing normal should get sky color
    const sky_ambient = ambient.getAmbientColor(Vec3.up());
    try std.testing.expect(sky_ambient.r > 0);

    // Down-facing normal should get ground color
    const ground_ambient = ambient.getAmbientColor(Vec3.down());
    try std.testing.expect(ground_ambient.r > 0);
}
