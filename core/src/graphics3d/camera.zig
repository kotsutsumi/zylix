//! Zylix 3D Graphics - Camera System
//!
//! Perspective and orthographic cameras with various control modes.

const std = @import("std");
const types = @import("types.zig");

const Vec3 = types.Vec3;
const Mat4 = types.Mat4;
const Quaternion = types.Quaternion;
const Transform = types.Transform;
const Frustum = types.Frustum;
const Ray = types.Ray;

// ============================================================================
// Camera Types
// ============================================================================

/// Camera projection type
pub const ProjectionType = enum {
    perspective,
    orthographic,
};

/// Camera clear flags
pub const ClearFlags = enum {
    skybox,
    solid_color,
    depth_only,
    nothing,
};

// ============================================================================
// Camera
// ============================================================================

/// 3D camera for scene rendering
pub const Camera = struct {
    // Transform
    transform: Transform = Transform.identity(),

    // Projection settings
    projection_type: ProjectionType = .perspective,

    // Perspective settings
    field_of_view: f32 = std.math.pi / 4.0, // 45 degrees
    aspect_ratio: f32 = 16.0 / 9.0,

    // Orthographic settings
    ortho_size: f32 = 5.0,

    // Clipping planes
    near_clip: f32 = 0.1,
    far_clip: f32 = 1000.0,

    // Viewport (0.0 - 1.0 normalized)
    viewport_x: f32 = 0,
    viewport_y: f32 = 0,
    viewport_width: f32 = 1,
    viewport_height: f32 = 1,

    // Render settings
    clear_flags: ClearFlags = .solid_color,
    clear_color: types.Color = types.Color.rgb(0.2, 0.3, 0.4),
    depth: i32 = 0, // Render order (lower = earlier)
    culling_mask: u32 = 0xFFFFFFFF, // Layer mask for culling

    // Cached matrices
    cached_view: ?Mat4 = null,
    cached_projection: ?Mat4 = null,
    cached_view_projection: ?Mat4 = null,

    pub fn init() Camera {
        return .{};
    }

    pub fn perspective(fov: f32, aspect: f32, near: f32, far: f32) Camera {
        return .{
            .projection_type = .perspective,
            .field_of_view = fov,
            .aspect_ratio = aspect,
            .near_clip = near,
            .far_clip = far,
        };
    }

    pub fn orthographic(size: f32, near: f32, far: f32) Camera {
        return .{
            .projection_type = .orthographic,
            .ortho_size = size,
            .near_clip = near,
            .far_clip = far,
        };
    }

    /// Invalidate cached matrices (call after transform changes)
    pub fn invalidateCache(self: *Camera) void {
        self.cached_view = null;
        self.cached_projection = null;
        self.cached_view_projection = null;
    }

    /// Get view matrix
    pub fn getViewMatrix(self: *Camera) Mat4 {
        if (self.cached_view) |v| return v;

        const view = Mat4.lookAt(
            self.transform.position,
            self.transform.position.add(self.transform.forward()),
            self.transform.up(),
        );
        self.cached_view = view;
        return view;
    }

    /// Get projection matrix
    pub fn getProjectionMatrix(self: *Camera) Mat4 {
        if (self.cached_projection) |p| return p;

        const projection = switch (self.projection_type) {
            .perspective => Mat4.perspective(
                self.field_of_view,
                self.aspect_ratio,
                self.near_clip,
                self.far_clip,
            ),
            .orthographic => blk: {
                const half_height = self.ortho_size;
                const half_width = half_height * self.aspect_ratio;
                break :blk Mat4.orthographic(
                    -half_width,
                    half_width,
                    -half_height,
                    half_height,
                    self.near_clip,
                    self.far_clip,
                );
            },
        };
        self.cached_projection = projection;
        return projection;
    }

    /// Get combined view-projection matrix
    pub fn getViewProjectionMatrix(self: *Camera) Mat4 {
        if (self.cached_view_projection) |vp| return vp;

        const vp = self.getProjectionMatrix().multiply(self.getViewMatrix());
        self.cached_view_projection = vp;
        return vp;
    }

    /// Get view frustum for culling
    pub fn getFrustum(self: *Camera) Frustum {
        return Frustum.fromMatrix(self.getViewProjectionMatrix());
    }

    /// Convert screen coordinates to world ray
    pub fn screenPointToRay(self: *Camera, screen_x: f32, screen_y: f32, screen_width: f32, screen_height: f32) Ray {
        // Normalize to -1..1 range
        const ndc_x = (2.0 * screen_x / screen_width) - 1.0;
        const ndc_y = 1.0 - (2.0 * screen_y / screen_height);

        // Near and far points in NDC
        const near_ndc = types.Vec4.init(ndc_x, ndc_y, -1.0, 1.0);
        const far_ndc = types.Vec4.init(ndc_x, ndc_y, 1.0, 1.0);

        // Get inverse view-projection matrix
        // Note: For a proper implementation, we'd need matrix inversion
        // For now, we use an approximation based on camera properties
        const origin = self.transform.position;

        // Calculate direction based on FOV and aspect ratio
        const tan_half_fov = @tan(self.field_of_view * 0.5);
        const right_vec = self.transform.right().scale(ndc_x * tan_half_fov * self.aspect_ratio);
        const up_vec = self.transform.up().scale(ndc_y * tan_half_fov);
        const direction = self.transform.forward().add(right_vec).add(up_vec).normalize();

        _ = near_ndc;
        _ = far_ndc;

        return Ray.init(origin, direction);
    }

    /// Convert world point to screen coordinates
    pub fn worldToScreenPoint(self: *Camera, world_point: Vec3, screen_width: f32, screen_height: f32) ?types.Vec2 {
        const vp = self.getViewProjectionMatrix();
        const clip = vp.transformVec4(types.Vec4.fromVec3(world_point, 1.0));

        // Check if point is behind camera
        if (clip.w <= 0) return null;

        // Perspective divide
        const ndc_x = clip.x / clip.w;
        const ndc_y = clip.y / clip.w;
        const ndc_z = clip.z / clip.w;

        // Check if point is outside frustum
        if (ndc_z < -1.0 or ndc_z > 1.0) return null;

        // Convert to screen coordinates
        return types.Vec2.init(
            (ndc_x + 1.0) * 0.5 * screen_width,
            (1.0 - ndc_y) * 0.5 * screen_height,
        );
    }

    /// Set position and look at target
    pub fn lookAt(self: *Camera, position: Vec3, target: Vec3, up: Vec3) void {
        self.transform.position = position;
        self.transform.lookAt(target, up);
        self.invalidateCache();
    }

    /// Set aspect ratio from viewport size
    pub fn setViewportSize(self: *Camera, width: f32, height: f32) void {
        if (height > 0) {
            self.aspect_ratio = width / height;
            self.invalidateCache();
        }
    }
};

// ============================================================================
// Camera Controllers
// ============================================================================

/// Orbit camera controller (rotate around target)
pub const OrbitController = struct {
    camera: *Camera,
    target: Vec3 = Vec3.zero(),
    distance: f32 = 10.0,
    azimuth: f32 = 0, // Horizontal angle
    elevation: f32 = std.math.pi / 4.0, // Vertical angle (45 degrees)

    min_distance: f32 = 1.0,
    max_distance: f32 = 100.0,
    min_elevation: f32 = -std.math.pi / 2.0 + 0.1,
    max_elevation: f32 = std.math.pi / 2.0 - 0.1,

    pub fn init(camera: *Camera) OrbitController {
        return .{ .camera = camera };
    }

    pub fn rotate(self: *OrbitController, delta_azimuth: f32, delta_elevation: f32) void {
        self.azimuth += delta_azimuth;
        self.elevation = std.math.clamp(
            self.elevation + delta_elevation,
            self.min_elevation,
            self.max_elevation,
        );
        self.updateCamera();
    }

    pub fn zoom(self: *OrbitController, delta: f32) void {
        self.distance = std.math.clamp(
            self.distance + delta,
            self.min_distance,
            self.max_distance,
        );
        self.updateCamera();
    }

    pub fn setTarget(self: *OrbitController, target: Vec3) void {
        self.target = target;
        self.updateCamera();
    }

    pub fn updateCamera(self: *OrbitController) void {
        const cos_elev = @cos(self.elevation);
        const sin_elev = @sin(self.elevation);
        const cos_azim = @cos(self.azimuth);
        const sin_azim = @sin(self.azimuth);

        const offset = Vec3.init(
            self.distance * cos_elev * sin_azim,
            self.distance * sin_elev,
            self.distance * cos_elev * cos_azim,
        );

        self.camera.transform.position = self.target.add(offset);
        self.camera.transform.lookAt(self.target, Vec3.up());
        self.camera.invalidateCache();
    }
};

/// First-person camera controller
pub const FirstPersonController = struct {
    camera: *Camera,
    yaw: f32 = 0, // Horizontal look angle
    pitch: f32 = 0, // Vertical look angle
    move_speed: f32 = 5.0,
    look_sensitivity: f32 = 0.002,

    min_pitch: f32 = -std.math.pi / 2.0 + 0.1,
    max_pitch: f32 = std.math.pi / 2.0 - 0.1,

    pub fn init(camera: *Camera) FirstPersonController {
        return .{ .camera = camera };
    }

    pub fn look(self: *FirstPersonController, delta_x: f32, delta_y: f32) void {
        self.yaw += delta_x * self.look_sensitivity;
        self.pitch = std.math.clamp(
            self.pitch - delta_y * self.look_sensitivity,
            self.min_pitch,
            self.max_pitch,
        );
        self.updateCamera();
    }

    pub fn move(self: *FirstPersonController, forward: f32, right: f32, up: f32, delta_time: f32) void {
        const speed = self.move_speed * delta_time;

        // Get movement vectors (ignore pitch for forward/right movement)
        const forward_vec = Vec3.init(@sin(self.yaw), 0, -@cos(self.yaw));
        const right_vec = Vec3.init(@cos(self.yaw), 0, @sin(self.yaw));
        const up_vec = Vec3.up();

        var movement = Vec3.zero();
        movement = movement.add(forward_vec.scale(forward * speed));
        movement = movement.add(right_vec.scale(right * speed));
        movement = movement.add(up_vec.scale(up * speed));

        self.camera.transform.position = self.camera.transform.position.add(movement);
        self.camera.invalidateCache();
    }

    pub fn updateCamera(self: *FirstPersonController) void {
        self.camera.transform.rotation = Quaternion.fromEuler(self.pitch, self.yaw, 0);
        self.camera.invalidateCache();
    }
};

/// Fly camera controller (six degrees of freedom)
pub const FlyController = struct {
    camera: *Camera,
    move_speed: f32 = 5.0,
    roll_speed: f32 = 1.0,
    look_sensitivity: f32 = 0.002,

    pub fn init(camera: *Camera) FlyController {
        return .{ .camera = camera };
    }

    pub fn look(self: *FlyController, delta_x: f32, delta_y: f32) void {
        // Rotate around local axes
        self.camera.transform.rotate(self.camera.transform.up(), -delta_x * self.look_sensitivity);
        self.camera.transform.rotate(self.camera.transform.right(), -delta_y * self.look_sensitivity);
        self.camera.invalidateCache();
    }

    pub fn roll(self: *FlyController, delta: f32, delta_time: f32) void {
        self.camera.transform.rotate(self.camera.transform.forward(), delta * self.roll_speed * delta_time);
        self.camera.invalidateCache();
    }

    pub fn move(self: *FlyController, forward: f32, right: f32, up: f32, delta_time: f32) void {
        const speed = self.move_speed * delta_time;

        var movement = Vec3.zero();
        movement = movement.add(self.camera.transform.forward().scale(forward * speed));
        movement = movement.add(self.camera.transform.right().scale(right * speed));
        movement = movement.add(self.camera.transform.up().scale(up * speed));

        self.camera.transform.position = self.camera.transform.position.add(movement);
        self.camera.invalidateCache();
    }
};

// ============================================================================
// Camera Manager
// ============================================================================

/// Manages multiple cameras in a scene
pub const CameraManager = struct {
    cameras: std.ArrayList(*Camera),
    main_camera: ?*Camera = null,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) CameraManager {
        return .{
            .cameras = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *CameraManager) void {
        self.cameras.deinit(self.allocator);
    }

    pub fn addCamera(self: *CameraManager, camera: *Camera) !void {
        try self.cameras.append(self.allocator, camera);
        if (self.main_camera == null) {
            self.main_camera = camera;
        }
    }

    pub fn removeCamera(self: *CameraManager, camera: *Camera) void {
        var i: usize = 0;
        while (i < self.cameras.items.len) : (i += 1) {
            if (self.cameras.items[i] == camera) {
                _ = self.cameras.orderedRemove(i);
                if (self.main_camera == camera) {
                    self.main_camera = if (self.cameras.items.len > 0) self.cameras.items[0] else null;
                }
                return;
            }
        }
    }

    pub fn setMainCamera(self: *CameraManager, camera: *Camera) void {
        self.main_camera = camera;
    }

    pub fn getMainCamera(self: *const CameraManager) ?*Camera {
        return self.main_camera;
    }

    /// Get cameras sorted by depth (for render order)
    pub fn getCamerasByDepth(self: *const CameraManager) []*Camera {
        // Sort cameras by depth
        const items = self.cameras.items;
        std.mem.sort(*Camera, items, {}, struct {
            fn lessThan(_: void, a: *Camera, b: *Camera) bool {
                return a.depth < b.depth;
            }
        }.lessThan);
        return items;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Camera perspective projection" {
    var camera = Camera.perspective(std.math.pi / 4.0, 16.0 / 9.0, 0.1, 100.0);
    camera.transform.position = Vec3.init(0, 0, 5);

    const view = camera.getViewMatrix();
    const proj = camera.getProjectionMatrix();
    _ = view;
    _ = proj;

    try std.testing.expect(camera.projection_type == .perspective);
}

test "Camera orthographic projection" {
    var camera = Camera.orthographic(5.0, 0.1, 100.0);

    const proj = camera.getProjectionMatrix();
    _ = proj;

    try std.testing.expect(camera.projection_type == .orthographic);
}

test "Camera lookAt" {
    var camera = Camera.init();
    camera.lookAt(Vec3.init(0, 5, 10), Vec3.zero(), Vec3.up());

    // Camera should be at (0, 5, 10) looking at origin
    try std.testing.expectApproxEqAbs(@as(f32, 0), camera.transform.position.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 5), camera.transform.position.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 10), camera.transform.position.z, 0.001);
}

test "OrbitController" {
    var camera = Camera.init();
    var orbit = OrbitController.init(&camera);

    orbit.setTarget(Vec3.init(0, 0, 0));
    orbit.distance = 10.0;
    orbit.azimuth = 0;
    orbit.elevation = 0;
    orbit.updateCamera();

    // Camera should be at (0, 0, 10) looking at origin
    try std.testing.expectApproxEqAbs(@as(f32, 0), camera.transform.position.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), camera.transform.position.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 10), camera.transform.position.z, 0.001);
}
