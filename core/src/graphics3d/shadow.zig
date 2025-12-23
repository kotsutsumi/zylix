// ============================================================================
// Zylix Game Engine - Shadow Mapping System
// ============================================================================
// Comprehensive shadow mapping with support for:
// - Directional light shadows with Cascaded Shadow Maps (CSM)
// - Point light shadows with omnidirectional cube maps
// - Spot light shadows with perspective projection
// - PCF soft shadows and variance shadow maps
// ============================================================================

const std = @import("std");
const types = @import("types.zig");
const lighting = @import("lighting.zig");
const camera_mod = @import("camera.zig");

const Vec2 = types.Vec2;
const Vec3 = types.Vec3;
const Vec4 = types.Vec4;
const Mat4 = types.Mat4;
const AABB = types.AABB;
const Frustum = types.Frustum;
const Camera = camera_mod.Camera;
const DirectionalLight = lighting.DirectionalLight;
const PointLight = lighting.PointLight;
const SpotLight = lighting.SpotLight;

// ============================================================================
// Shadow Map Types
// ============================================================================

/// Shadow map texture format
pub const ShadowFormat = enum {
    depth16,
    depth24,
    depth32,
    depth32f,

    pub fn getBytesPerPixel(self: ShadowFormat) u32 {
        return switch (self) {
            .depth16 => 2,
            .depth24 => 3,
            .depth32, .depth32f => 4,
        };
    }
};

/// Shadow filtering mode
pub const ShadowFilter = enum {
    /// No filtering - hard shadows
    none,
    /// PCF 2x2 kernel
    pcf_2x2,
    /// PCF 3x3 kernel
    pcf_3x3,
    /// PCF 5x5 kernel
    pcf_5x5,
    /// Poisson disk sampling
    poisson,
    /// Variance Shadow Maps
    vsm,
    /// Exponential Shadow Maps
    esm,
};

/// Shadow map quality preset
pub const ShadowQuality = enum {
    low, // 512x512
    medium, // 1024x1024
    high, // 2048x2048
    ultra, // 4096x4096

    pub fn getResolution(self: ShadowQuality) u32 {
        return switch (self) {
            .low => 512,
            .medium => 1024,
            .high => 2048,
            .ultra => 4096,
        };
    }
};

// ============================================================================
// Shadow Map
// ============================================================================

/// Individual shadow map texture
pub const ShadowMap = struct {
    /// Resolution (width and height)
    resolution: u32,

    /// Texture format
    format: ShadowFormat,

    /// Light-space view-projection matrix
    light_view_proj: Mat4,

    /// View matrix from light's perspective
    light_view: Mat4,

    /// Projection matrix from light's perspective
    light_proj: Mat4,

    /// Near/far planes
    near_plane: f32,
    far_plane: f32,

    /// Depth bias to prevent shadow acne
    bias: f32,

    /// Normal offset bias
    normal_bias: f32,

    /// GPU texture handle (set by renderer)
    texture_handle: ?u64,

    /// Framebuffer handle (set by renderer)
    framebuffer_handle: ?u64,

    /// Is the shadow map dirty (needs re-render)
    dirty: bool,

    pub fn init(resolution: u32, format: ShadowFormat) ShadowMap {
        return .{
            .resolution = resolution,
            .format = format,
            .light_view_proj = Mat4.identity(),
            .light_view = Mat4.identity(),
            .light_proj = Mat4.identity(),
            .near_plane = 0.1,
            .far_plane = 100.0,
            .bias = 0.005,
            .normal_bias = 0.02,
            .texture_handle = null,
            .framebuffer_handle = null,
            .dirty = true,
        };
    }

    /// Update matrices for directional light
    pub fn updateDirectional(self: *ShadowMap, light_dir: Vec3, scene_bounds: AABB) void {
        // Calculate light view matrix (looking along light direction)
        const light_pos = scene_bounds.center().sub(light_dir.scale(scene_bounds.diagonal() * 0.5));
        const target = scene_bounds.center();
        const up = if (@abs(light_dir.y) > 0.99) Vec3.init(0, 0, 1) else Vec3.init(0, 1, 0);

        self.light_view = Mat4.lookAt(light_pos, target, up);

        // Calculate orthographic projection to encompass scene
        const radius = scene_bounds.diagonal() * 0.5;
        self.light_proj = Mat4.orthographic(-radius, radius, -radius, radius, -radius * 2, radius * 2);

        self.light_view_proj = self.light_proj.mul(self.light_view);
        self.dirty = true;
    }

    /// Update matrices for spot light
    pub fn updateSpot(self: *ShadowMap, position: Vec3, direction: Vec3, outer_angle: f32, range: f32) void {
        const target = position.add(direction);
        const up = if (@abs(direction.y) > 0.99) Vec3.init(0, 0, 1) else Vec3.init(0, 1, 0);

        self.light_view = Mat4.lookAt(position, target, up);

        // Use outer cone angle for FOV
        const fov = outer_angle * 2.0;
        self.near_plane = 0.1;
        self.far_plane = range;
        self.light_proj = Mat4.perspective(fov, 1.0, self.near_plane, self.far_plane);

        self.light_view_proj = self.light_proj.mul(self.light_view);
        self.dirty = true;
    }

    /// Get texel size for PCF filtering
    pub fn getTexelSize(self: *const ShadowMap) f32 {
        return 1.0 / @as(f32, @floatFromInt(self.resolution));
    }
};

// ============================================================================
// Cascaded Shadow Maps (for Directional Lights)
// ============================================================================

/// Cascade split scheme
pub const CascadeSplitScheme = enum {
    /// Uniform split
    uniform,
    /// Logarithmic split
    logarithmic,
    /// Practical split (PSSM)
    practical,
};

/// Single cascade in CSM
pub const ShadowCascade = struct {
    /// Shadow map for this cascade
    shadow_map: ShadowMap,

    /// Near split distance (view space)
    near_split: f32,

    /// Far split distance (view space)
    far_split: f32,

    /// Cascade index
    index: u32,
};

/// Cascaded Shadow Map system for directional lights
pub const CascadedShadowMap = struct {
    allocator: std.mem.Allocator,

    /// Number of cascades
    cascade_count: u32 = 4,

    /// Individual cascades
    cascades: std.ArrayListUnmanaged(ShadowCascade) = .{},

    /// Split scheme
    split_scheme: CascadeSplitScheme = .practical,

    /// Lambda for practical split scheme (0-1)
    split_lambda: f32 = 0.5,

    /// Base resolution for cascade 0
    base_resolution: u32 = 2048,

    /// Shadow format
    format: ShadowFormat = .depth32f,

    /// Blend between cascades
    cascade_blend_distance: f32 = 5.0,

    /// Visualization mode (debug)
    debug_visualization: bool = false,

    pub fn init(allocator: std.mem.Allocator, cascade_count: u32, quality: ShadowQuality) CascadedShadowMap {
        return .{
            .allocator = allocator,
            .cascade_count = cascade_count,
            .base_resolution = quality.getResolution(),
        };
    }

    pub fn deinit(self: *CascadedShadowMap) void {
        self.cascades.deinit(self.allocator);
    }

    /// Initialize cascades for camera
    pub fn setup(self: *CascadedShadowMap, cam: *const Camera, light_dir: Vec3, scene_bounds: AABB) !void {
        self.cascades.clearRetainingCapacity();

        // Calculate split distances
        const near = cam.near;
        const far = @min(cam.far, 500.0); // Limit shadow distance

        for (0..self.cascade_count) |i| {
            const idx: u32 = @intCast(i);
            const splits = self.calculateSplits(near, far, idx);

            // Calculate cascade resolution (can decrease for far cascades)
            const resolution = @max(self.base_resolution >> @min(idx, 2), 256);

            var cascade = ShadowCascade{
                .shadow_map = ShadowMap.init(resolution, self.format),
                .near_split = splits.near,
                .far_split = splits.far,
                .index = idx,
            };

            // Calculate light-space matrix for this cascade
            self.updateCascadeMatrix(&cascade, cam, light_dir, scene_bounds);

            try self.cascades.append(self.allocator, cascade);
        }
    }

    /// Calculate split distances for cascade
    fn calculateSplits(self: *const CascadedShadowMap, near: f32, far: f32, index: u32) struct { near: f32, far: f32 } {
        const n = self.cascade_count;
        const i_f = @as(f32, @floatFromInt(index));
        const n_f = @as(f32, @floatFromInt(n));

        var split_near: f32 = undefined;
        var split_far: f32 = undefined;

        switch (self.split_scheme) {
            .uniform => {
                split_near = near + (far - near) * i_f / n_f;
                split_far = near + (far - near) * (i_f + 1.0) / n_f;
            },
            .logarithmic => {
                split_near = near * std.math.pow(f32, far / near, i_f / n_f);
                split_far = near * std.math.pow(f32, far / near, (i_f + 1.0) / n_f);
            },
            .practical => {
                // PSSM practical split
                const log_near = near * std.math.pow(f32, far / near, i_f / n_f);
                const log_far = near * std.math.pow(f32, far / near, (i_f + 1.0) / n_f);
                const uni_near = near + (far - near) * i_f / n_f;
                const uni_far = near + (far - near) * (i_f + 1.0) / n_f;

                split_near = self.split_lambda * log_near + (1.0 - self.split_lambda) * uni_near;
                split_far = self.split_lambda * log_far + (1.0 - self.split_lambda) * uni_far;
            },
        }

        return .{ .near = split_near, .far = split_far };
    }

    /// Update cascade matrix for current view
    fn updateCascadeMatrix(self: *CascadedShadowMap, cascade: *ShadowCascade, cam: *const Camera, light_dir: Vec3, scene_bounds: AABB) void {
        _ = self;
        _ = scene_bounds;

        // Get frustum corners for this cascade split
        const corners = getFrustumCornersWorldSpace(cam, cascade.near_split, cascade.far_split);

        // Calculate frustum center
        var center = Vec3.zero();
        for (corners) |corner| {
            center = center.add(corner);
        }
        center = center.scale(1.0 / 8.0);

        // Calculate bounding sphere radius
        var radius: f32 = 0;
        for (corners) |corner| {
            const dist = corner.sub(center).length();
            radius = @max(radius, dist);
        }

        // Round to prevent shadow swimming
        const texels_per_unit = @as(f32, @floatFromInt(cascade.shadow_map.resolution)) / (radius * 2.0);
        center = center.scale(texels_per_unit);
        center = Vec3.init(
            @floor(center.x),
            @floor(center.y),
            @floor(center.z),
        );
        center = center.scale(1.0 / texels_per_unit);

        // Build light view matrix
        const light_pos = center.sub(light_dir.scale(radius));
        const up = if (@abs(light_dir.y) > 0.99) Vec3.init(0, 0, 1) else Vec3.init(0, 1, 0);

        cascade.shadow_map.light_view = Mat4.lookAt(light_pos, center, up);
        cascade.shadow_map.light_proj = Mat4.orthographic(-radius, radius, -radius, radius, 0.0, radius * 2.0);
        cascade.shadow_map.light_view_proj = cascade.shadow_map.light_proj.mul(cascade.shadow_map.light_view);
        cascade.shadow_map.dirty = true;
    }

    /// Get cascade index for given view depth
    pub fn getCascadeIndex(self: *const CascadedShadowMap, view_depth: f32) u32 {
        for (self.cascades.items, 0..) |cascade, i| {
            if (view_depth <= cascade.far_split) {
                return @intCast(i);
            }
        }
        return self.cascade_count - 1;
    }

    /// Get blend factor between cascades
    pub fn getCascadeBlend(self: *const CascadedShadowMap, view_depth: f32, cascade_idx: u32) f32 {
        if (cascade_idx >= self.cascade_count - 1) return 0.0;

        const cascade = self.cascades.items[cascade_idx];
        const blend_start = cascade.far_split - self.cascade_blend_distance;

        if (view_depth < blend_start) return 0.0;

        return (view_depth - blend_start) / self.cascade_blend_distance;
    }
};

/// Get frustum corners in world space for given near/far
fn getFrustumCornersWorldSpace(cam: *const Camera, near: f32, far: f32) [8]Vec3 {
    const inv_view_proj = cam.getViewMatrix().mul(cam.getProjectionMatrix()).inverse() orelse Mat4.identity();

    // NDC corners
    const ndc_corners = [8][3]f32{
        .{ -1, -1, 0 }, // near bottom-left
        .{ 1, -1, 0 }, // near bottom-right
        .{ 1, 1, 0 }, // near top-right
        .{ -1, 1, 0 }, // near top-left
        .{ -1, -1, 1 }, // far bottom-left
        .{ 1, -1, 1 }, // far bottom-right
        .{ 1, 1, 1 }, // far top-right
        .{ -1, 1, 1 }, // far top-left
    };

    var corners: [8]Vec3 = undefined;

    for (ndc_corners, 0..) |ndc, i| {
        const clip = Vec4.init(ndc[0], ndc[1], ndc[2], 1.0);
        var world = inv_view_proj.transformVec4(clip);
        world = world.scale3(1.0 / world.w);

        // Interpolate between original near/far and custom near/far
        const original_near = cam.near;
        const original_far = cam.far;
        const t = if (ndc[2] < 0.5)
            (near - original_near) / (original_far - original_near)
        else
            (far - original_near) / (original_far - original_near);

        _ = t;
        corners[i] = Vec3.init(world.x, world.y, world.z);
    }

    return corners;
}

// ============================================================================
// Point Light Shadow (Omnidirectional/Cube Map)
// ============================================================================

/// Cube face directions
pub const CubeFace = enum(u32) {
    positive_x = 0, // Right
    negative_x = 1, // Left
    positive_y = 2, // Top
    negative_y = 3, // Bottom
    positive_z = 4, // Front
    negative_z = 5, // Back

    pub fn getDirection(self: CubeFace) Vec3 {
        return switch (self) {
            .positive_x => Vec3.init(1, 0, 0),
            .negative_x => Vec3.init(-1, 0, 0),
            .positive_y => Vec3.init(0, 1, 0),
            .negative_y => Vec3.init(0, -1, 0),
            .positive_z => Vec3.init(0, 0, 1),
            .negative_z => Vec3.init(0, 0, -1),
        };
    }

    pub fn getUp(self: CubeFace) Vec3 {
        return switch (self) {
            .positive_x => Vec3.init(0, -1, 0),
            .negative_x => Vec3.init(0, -1, 0),
            .positive_y => Vec3.init(0, 0, 1),
            .negative_y => Vec3.init(0, 0, -1),
            .positive_z => Vec3.init(0, -1, 0),
            .negative_z => Vec3.init(0, -1, 0),
        };
    }
};

/// Point light shadow using cube map
pub const PointShadowMap = struct {
    /// Resolution of each cube face
    resolution: u32,

    /// Light position
    position: Vec3,

    /// Light range
    range: f32,

    /// View-projection matrices for each face
    face_matrices: [6]Mat4,

    /// Depth bias
    bias: f32,

    /// Cube map texture handle (set by renderer)
    cube_texture_handle: ?u64,

    /// Framebuffer handles for each face
    face_framebuffers: [6]?u64,

    /// Is dirty
    dirty: bool,

    pub fn init(resolution: u32) PointShadowMap {
        var self = PointShadowMap{
            .resolution = resolution,
            .position = Vec3.zero(),
            .range = 10.0,
            .face_matrices = undefined,
            .bias = 0.05,
            .cube_texture_handle = null,
            .face_framebuffers = .{ null, null, null, null, null, null },
            .dirty = true,
        };

        // Initialize matrices
        for (0..6) |i| {
            self.face_matrices[i] = Mat4.identity();
        }

        return self;
    }

    /// Update matrices for new position/range
    pub fn update(self: *PointShadowMap, position: Vec3, range: f32) void {
        self.position = position;
        self.range = range;

        const proj = Mat4.perspective(std.math.pi / 2.0, 1.0, 0.1, range);

        inline for (0..6) |i| {
            const face: CubeFace = @enumFromInt(i);
            const dir = face.getDirection();
            const up = face.getUp();
            const target = position.add(dir);

            const view = Mat4.lookAt(position, target, up);
            self.face_matrices[i] = proj.multiply(view);
        }

        self.dirty = true;
    }

    /// Get matrix for specific face
    pub fn getFaceMatrix(self: *const PointShadowMap, face: CubeFace) Mat4 {
        return self.face_matrices[@intFromEnum(face)];
    }
};

// ============================================================================
// Spot Light Shadow
// ============================================================================

/// Spot light shadow map
pub const SpotShadowMap = struct {
    /// Base shadow map
    shadow_map: ShadowMap,

    /// Light position
    position: Vec3,

    /// Light direction
    direction: Vec3,

    /// Outer cone angle (radians)
    outer_angle: f32,

    /// Light range
    range: f32,

    pub fn init(resolution: u32) SpotShadowMap {
        return .{
            .shadow_map = ShadowMap.init(resolution, .depth32f),
            .position = Vec3.zero(),
            .direction = Vec3.init(0, -1, 0),
            .outer_angle = std.math.pi / 4.0,
            .range = 10.0,
        };
    }

    /// Update shadow map matrices
    pub fn update(self: *SpotShadowMap) void {
        self.shadow_map.updateSpot(self.position, self.direction, self.outer_angle, self.range);
    }
};

// ============================================================================
// Shadow Manager
// ============================================================================

/// Manages all shadow maps in the scene
pub const ShadowManager = struct {
    allocator: std.mem.Allocator,

    /// Default shadow quality
    quality: ShadowQuality = .high,

    /// Default shadow filter
    filter: ShadowFilter = .pcf_3x3,

    /// Cascaded shadow map for directional light
    directional_shadow: ?CascadedShadowMap = null,

    /// Point light shadow maps
    point_shadows: std.ArrayListUnmanaged(PointShadowMap) = .{},

    /// Spot light shadow maps
    spot_shadows: std.ArrayListUnmanaged(SpotShadowMap) = .{},

    /// Maximum shadow distance
    max_shadow_distance: f32 = 100.0,

    /// Global shadow intensity (0-1)
    shadow_intensity: f32 = 1.0,

    /// Enable shadow fading at distance
    fade_shadows: bool = true,

    /// Fade start distance (as ratio of max distance)
    fade_start_ratio: f32 = 0.8,

    /// Statistics
    stats: ShadowStats = .{},

    pub fn init(allocator: std.mem.Allocator, quality: ShadowQuality) ShadowManager {
        return .{
            .allocator = allocator,
            .quality = quality,
        };
    }

    pub fn deinit(self: *ShadowManager) void {
        if (self.directional_shadow) |*csm| {
            csm.deinit();
        }
        self.point_shadows.deinit(self.allocator);
        self.spot_shadows.deinit(self.allocator);
    }

    /// Setup directional light shadow (CSM)
    pub fn setupDirectionalShadow(self: *ShadowManager, cascade_count: u32) void {
        if (self.directional_shadow) |*csm| {
            csm.deinit();
        }
        self.directional_shadow = CascadedShadowMap.init(self.allocator, cascade_count, self.quality);
    }

    /// Add point light shadow
    pub fn addPointShadow(self: *ShadowManager, position: Vec3, range: f32) !usize {
        var shadow = PointShadowMap.init(self.quality.getResolution() / 2); // Lower res for point lights
        shadow.update(position, range);
        try self.point_shadows.append(self.allocator, shadow);
        return self.point_shadows.items.len - 1;
    }

    /// Add spot light shadow
    pub fn addSpotShadow(self: *ShadowManager, position: Vec3, direction: Vec3, outer_angle: f32, range: f32) !usize {
        var shadow = SpotShadowMap.init(self.quality.getResolution());
        shadow.position = position;
        shadow.direction = direction;
        shadow.outer_angle = outer_angle;
        shadow.range = range;
        shadow.update();
        try self.spot_shadows.append(self.allocator, shadow);
        return self.spot_shadows.items.len - 1;
    }

    /// Update all shadow maps for current frame
    pub fn update(self: *ShadowManager, cam: *const Camera, dir_light: ?*const DirectionalLight, scene_bounds: AABB) !void {
        self.stats.reset();

        // Update directional shadow
        if (self.directional_shadow) |*csm| {
            if (dir_light) |light| {
                try csm.setup(cam, light.direction, scene_bounds);
                self.stats.cascade_count = csm.cascade_count;
            }
        }

        // Update point shadows
        for (self.point_shadows.items) |*shadow| {
            if (shadow.dirty) {
                self.stats.point_shadow_updates += 1;
            }
        }

        // Update spot shadows
        for (self.spot_shadows.items) |*shadow| {
            if (shadow.shadow_map.dirty) {
                shadow.update();
                self.stats.spot_shadow_updates += 1;
            }
        }

        self.stats.total_shadow_maps = 1 + // directional
            self.point_shadows.items.len * 6 + // 6 faces per point
            self.spot_shadows.items.len;
    }

    /// Get shadow fade factor for given distance
    pub fn getShadowFade(self: *const ShadowManager, distance: f32) f32 {
        if (!self.fade_shadows) return 1.0;

        const fade_start = self.max_shadow_distance * self.fade_start_ratio;
        if (distance < fade_start) return 1.0;
        if (distance > self.max_shadow_distance) return 0.0;

        return 1.0 - (distance - fade_start) / (self.max_shadow_distance - fade_start);
    }

    /// Set quality for all shadow maps
    pub fn setQuality(self: *ShadowManager, quality: ShadowQuality) void {
        self.quality = quality;

        if (self.directional_shadow) |*csm| {
            csm.base_resolution = quality.getResolution();
        }

        // Note: Existing shadow maps would need to be recreated
        // This is typically done on next frame
    }
};

/// Shadow rendering statistics
pub const ShadowStats = struct {
    total_shadow_maps: usize = 0,
    cascade_count: u32 = 0,
    point_shadow_updates: u32 = 0,
    spot_shadow_updates: u32 = 0,
    shadow_casters_rendered: u32 = 0,
    total_render_time_ms: f32 = 0,

    pub fn reset(self: *ShadowStats) void {
        self.* = .{};
    }
};

// ============================================================================
// Shadow Shader Utilities
// ============================================================================

/// PCF kernel offsets for different filter sizes
pub const PCFKernel = struct {
    pub const pcf_2x2 = [4][2]f32{
        .{ -0.5, -0.5 },
        .{ 0.5, -0.5 },
        .{ -0.5, 0.5 },
        .{ 0.5, 0.5 },
    };

    pub const pcf_3x3 = [9][2]f32{
        .{ -1, -1 },
        .{ 0, -1 },
        .{ 1, -1 },
        .{ -1, 0 },
        .{ 0, 0 },
        .{ 1, 0 },
        .{ -1, 1 },
        .{ 0, 1 },
        .{ 1, 1 },
    };

    pub const pcf_5x5 = [25][2]f32{
        .{ -2, -2 }, .{ -1, -2 }, .{ 0, -2 }, .{ 1, -2 }, .{ 2, -2 },
        .{ -2, -1 }, .{ -1, -1 }, .{ 0, -1 }, .{ 1, -1 }, .{ 2, -1 },
        .{ -2, 0 },  .{ -1, 0 },  .{ 0, 0 },  .{ 1, 0 },  .{ 2, 0 },
        .{ -2, 1 },  .{ -1, 1 },  .{ 0, 1 },  .{ 1, 1 },  .{ 2, 1 },
        .{ -2, 2 },  .{ -1, 2 },  .{ 0, 2 },  .{ 1, 2 },  .{ 2, 2 },
    };

    /// Poisson disk samples for soft shadows
    pub const poisson_disk = [16][2]f32{
        .{ -0.94201624, -0.39906216 },
        .{ 0.94558609, -0.76890725 },
        .{ -0.094184101, -0.92938870 },
        .{ 0.34495938, 0.29387760 },
        .{ -0.91588581, 0.45771432 },
        .{ -0.81544232, -0.87912464 },
        .{ -0.38277543, 0.27676845 },
        .{ 0.97484398, 0.75648379 },
        .{ 0.44323325, -0.97511554 },
        .{ 0.53742981, -0.47373420 },
        .{ -0.26496911, -0.41893023 },
        .{ 0.79197514, 0.19090188 },
        .{ -0.24188840, 0.99706507 },
        .{ -0.81409955, 0.91437590 },
        .{ 0.19984126, 0.78641367 },
        .{ 0.14383161, -0.14100790 },
    };
};

/// Shadow map uniform data for shaders
pub const ShadowUniforms = struct {
    /// Light-space matrix
    light_space_matrix: Mat4,

    /// Shadow map texel size
    texel_size: f32,

    /// Depth bias
    bias: f32,

    /// Normal offset bias
    normal_bias: f32,

    /// Shadow intensity
    intensity: f32,

    /// For CSM: cascade split distances
    cascade_splits: [4]f32,

    /// For CSM: cascade matrices (up to 4)
    cascade_matrices: [4]Mat4,

    /// For point lights: light position
    light_position: Vec3,

    /// For point lights: far plane distance
    far_plane: f32,

    pub fn init() ShadowUniforms {
        return .{
            .light_space_matrix = Mat4.identity(),
            .texel_size = 1.0 / 1024.0,
            .bias = 0.005,
            .normal_bias = 0.02,
            .intensity = 1.0,
            .cascade_splits = .{ 10, 25, 50, 100 },
            .cascade_matrices = .{ Mat4.identity(), Mat4.identity(), Mat4.identity(), Mat4.identity() },
            .light_position = Vec3.zero(),
            .far_plane = 100.0,
        };
    }

    /// Update from CSM
    pub fn updateFromCSM(self: *ShadowUniforms, csm: *const CascadedShadowMap) void {
        for (csm.cascades.items, 0..) |cascade, i| {
            if (i >= 4) break;
            self.cascade_splits[i] = cascade.far_split;
            self.cascade_matrices[i] = cascade.shadow_map.light_view_proj;
        }
    }

    /// Update from shadow map
    pub fn updateFromShadowMap(self: *ShadowUniforms, shadow_map: *const ShadowMap) void {
        self.light_space_matrix = shadow_map.light_view_proj;
        self.texel_size = shadow_map.getTexelSize();
        self.bias = shadow_map.bias;
        self.normal_bias = shadow_map.normal_bias;
    }

    /// Update from point shadow
    pub fn updateFromPointShadow(self: *ShadowUniforms, point_shadow: *const PointShadowMap) void {
        self.light_position = point_shadow.position;
        self.far_plane = point_shadow.range;
        self.bias = point_shadow.bias;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "ShadowMap initialization" {
    const shadow = ShadowMap.init(1024, .depth32f);
    try std.testing.expect(shadow.resolution == 1024);
    try std.testing.expect(shadow.dirty);
}

test "ShadowQuality resolution" {
    try std.testing.expect(ShadowQuality.low.getResolution() == 512);
    try std.testing.expect(ShadowQuality.medium.getResolution() == 1024);
    try std.testing.expect(ShadowQuality.high.getResolution() == 2048);
    try std.testing.expect(ShadowQuality.ultra.getResolution() == 4096);
}

test "CubeFace directions" {
    const px = CubeFace.positive_x.getDirection();
    try std.testing.expect(px.x == 1 and px.y == 0 and px.z == 0);

    const ny = CubeFace.negative_y.getDirection();
    try std.testing.expect(ny.x == 0 and ny.y == -1 and ny.z == 0);
}

test "PointShadowMap initialization" {
    var shadow = PointShadowMap.init(512);
    try std.testing.expect(shadow.resolution == 512);
    try std.testing.expect(shadow.dirty);

    shadow.update(Vec3.init(1, 2, 3), 15.0);
    try std.testing.expect(shadow.position.x == 1);
    try std.testing.expect(shadow.range == 15.0);
}

test "ShadowManager initialization" {
    const allocator = std.testing.allocator;
    var manager = ShadowManager.init(allocator, .high);
    defer manager.deinit();

    try std.testing.expect(manager.quality == .high);
    try std.testing.expect(manager.shadow_intensity == 1.0);
}

test "ShadowManager fade calculation" {
    const allocator = std.testing.allocator;
    var manager = ShadowManager.init(allocator, .medium);
    defer manager.deinit();

    manager.max_shadow_distance = 100.0;
    manager.fade_start_ratio = 0.8;

    // Before fade start
    try std.testing.expect(manager.getShadowFade(50.0) == 1.0);

    // At fade start
    try std.testing.expect(manager.getShadowFade(80.0) == 1.0);

    // Beyond max distance
    try std.testing.expect(manager.getShadowFade(110.0) == 0.0);
}

test "PCFKernel sizes" {
    try std.testing.expect(PCFKernel.pcf_2x2.len == 4);
    try std.testing.expect(PCFKernel.pcf_3x3.len == 9);
    try std.testing.expect(PCFKernel.pcf_5x5.len == 25);
    try std.testing.expect(PCFKernel.poisson_disk.len == 16);
}

test "ShadowUniforms initialization" {
    const uniforms = ShadowUniforms.init();
    try std.testing.expect(uniforms.intensity == 1.0);
    try std.testing.expect(uniforms.bias == 0.005);
}
