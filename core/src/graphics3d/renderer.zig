//! Zylix 3D Graphics - Renderer
//!
//! Abstract rendering interface for platform backends.

const std = @import("std");
const types = @import("types.zig");
const camera_module = @import("camera.zig");
const lighting_module = @import("lighting.zig");
const mesh_module = @import("mesh.zig");
const material_module = @import("material.zig");
const scene_module = @import("scene.zig");

const Vec3 = types.Vec3;
const Vec4 = types.Vec4;
const Mat4 = types.Mat4;
const Color = types.Color;
const Camera = camera_module.Camera;
const Mesh = mesh_module.Mesh;
const Material = material_module.Material;
const Scene = scene_module.Scene;
const SceneNode = scene_module.SceneNode;

// ============================================================================
// Render Backend
// ============================================================================

/// Graphics API backend type
pub const BackendType = enum {
    metal, // iOS/macOS
    vulkan, // Android/Windows/Linux
    directx12, // Windows
    webgl2, // Web (fallback)
    webgpu, // Web (modern)
    opengl, // Desktop fallback
    software, // CPU rendering (testing)
};

/// Render capabilities
pub const RenderCapabilities = struct {
    backend: BackendType,
    max_texture_size: u32 = 4096,
    max_texture_units: u32 = 16,
    max_vertex_attributes: u32 = 16,
    max_uniform_buffer_size: u32 = 65536,
    supports_compute: bool = false,
    supports_tessellation: bool = false,
    supports_geometry_shaders: bool = false,
    supports_raytracing: bool = false,
    supports_mesh_shaders: bool = false,
    supports_variable_rate_shading: bool = false,
    max_msaa_samples: u8 = 4,
    anisotropic_filtering: bool = true,
    max_anisotropy: f32 = 16.0,
};

// ============================================================================
// Render State
// ============================================================================

/// Current render state
pub const RenderState = struct {
    // Viewport
    viewport_x: u32 = 0,
    viewport_y: u32 = 0,
    viewport_width: u32 = 1920,
    viewport_height: u32 = 1080,

    // Clear settings
    clear_color: Color = Color.rgb(0.1, 0.1, 0.15),
    clear_depth: f32 = 1.0,
    clear_stencil: u8 = 0,

    // Depth state
    depth_test: bool = true,
    depth_write: bool = true,
    depth_func: material_module.CompareFunc = .less,

    // Blend state
    blend_enabled: bool = false,
    blend_mode: material_module.BlendMode = .@"opaque",

    // Cull state
    cull_mode: material_module.CullMode = .back,
    front_face_ccw: bool = true,

    // Scissor
    scissor_enabled: bool = false,
    scissor_x: u32 = 0,
    scissor_y: u32 = 0,
    scissor_width: u32 = 0,
    scissor_height: u32 = 0,

    // Wireframe
    wireframe: bool = false,
};

// ============================================================================
// Render Command
// ============================================================================

/// Type of render command
pub const RenderCommandType = enum {
    clear,
    set_viewport,
    set_scissor,
    bind_material,
    bind_mesh,
    draw,
    draw_indexed,
    draw_instanced,
    dispatch_compute,
};

/// Render command for command buffer
pub const RenderCommand = struct {
    command_type: RenderCommandType,
    // Command-specific data would go here
    // Using a union or separate command structs for production
};

// ============================================================================
// Render Queue
// ============================================================================

/// Renderable item for sorting
pub const RenderItem = struct {
    node: *SceneNode,
    distance: f32 = 0, // Distance from camera
    sort_key: u64 = 0, // Combined sort key
};

/// Render queue for sorted rendering
pub const RenderQueue = struct {
    opaque_items: std.ArrayList(RenderItem),
    transparent_items: std.ArrayList(RenderItem),
    overlay_items: std.ArrayList(RenderItem),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) RenderQueue {
        return .{
            .opaque_items = .{},
            .transparent_items = .{},
            .overlay_items = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *RenderQueue) void {
        self.opaque_items.deinit(self.allocator);
        self.transparent_items.deinit(self.allocator);
        self.overlay_items.deinit(self.allocator);
    }

    pub fn clear(self: *RenderQueue) void {
        self.opaque_items.clearRetainingCapacity();
        self.transparent_items.clearRetainingCapacity();
        self.overlay_items.clearRetainingCapacity();
    }

    pub fn addItem(self: *RenderQueue, node: *SceneNode, camera_pos: Vec3) !void {
        const mat = node.material_ref orelse return;

        const distance = node.getWorldPosition().sub(camera_pos).length();
        const item = RenderItem{
            .node = node,
            .distance = distance,
            .sort_key = @as(u64, @intCast(mat.render_queue)) << 32,
        };

        if (mat.render_queue >= 3000) {
            // Transparent - sort back to front
            try self.transparent_items.append(self.allocator, item);
        } else if (mat.render_queue >= 4000) {
            try self.overlay_items.append(self.allocator, item);
        } else {
            // Opaque - sort front to back
            try self.opaque_items.append(self.allocator, item);
        }
    }

    pub fn sort(self: *RenderQueue) void {
        // Opaque: front to back (minimize overdraw)
        std.mem.sort(RenderItem, self.opaque_items.items, {}, struct {
            fn lessThan(_: void, a: RenderItem, b: RenderItem) bool {
                return a.distance < b.distance;
            }
        }.lessThan);

        // Transparent: back to front (correct blending)
        std.mem.sort(RenderItem, self.transparent_items.items, {}, struct {
            fn lessThan(_: void, a: RenderItem, b: RenderItem) bool {
                return a.distance > b.distance;
            }
        }.lessThan);
    }
};

// ============================================================================
// Renderer
// ============================================================================

/// Abstract renderer interface
pub const Renderer = struct {
    // Backend info
    backend: BackendType,
    capabilities: RenderCapabilities,

    // State
    current_state: RenderState = .{},
    render_queue: RenderQueue,

    // Statistics
    stats: RenderStats = .{},

    // Memory
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, backend: BackendType) Renderer {
        return .{
            .backend = backend,
            .capabilities = getDefaultCapabilities(backend),
            .render_queue = RenderQueue.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Renderer) void {
        self.render_queue.deinit();
    }

    /// Get default capabilities for backend
    fn getDefaultCapabilities(backend: BackendType) RenderCapabilities {
        return switch (backend) {
            .metal => .{
                .backend = backend,
                .max_texture_size = 16384,
                .supports_compute = true,
                .supports_tessellation = true,
                .max_msaa_samples = 8,
            },
            .vulkan => .{
                .backend = backend,
                .max_texture_size = 16384,
                .supports_compute = true,
                .supports_tessellation = true,
                .supports_geometry_shaders = true,
                .max_msaa_samples = 8,
            },
            .directx12 => .{
                .backend = backend,
                .max_texture_size = 16384,
                .supports_compute = true,
                .supports_tessellation = true,
                .supports_mesh_shaders = true,
                .supports_raytracing = true,
                .max_msaa_samples = 8,
            },
            .webgpu => .{
                .backend = backend,
                .max_texture_size = 8192,
                .supports_compute = true,
                .max_msaa_samples = 4,
            },
            .webgl2 => .{
                .backend = backend,
                .max_texture_size = 4096,
                .max_msaa_samples = 4,
            },
            .opengl => .{
                .backend = backend,
                .max_texture_size = 8192,
                .supports_tessellation = true,
                .supports_geometry_shaders = true,
                .max_msaa_samples = 8,
            },
            .software => .{
                .backend = backend,
                .max_texture_size = 2048,
                .max_msaa_samples = 1,
            },
        };
    }

    /// Begin frame
    pub fn beginFrame(self: *Renderer) void {
        self.stats.draw_calls = 0;
        self.stats.triangles = 0;
        self.stats.vertices = 0;
        self.render_queue.clear();
    }

    /// End frame
    pub fn endFrame(_: *Renderer) void {
        // Frame timing would be calculated here
    }

    /// Set viewport
    pub fn setViewport(self: *Renderer, x: u32, y: u32, width: u32, height: u32) void {
        self.current_state.viewport_x = x;
        self.current_state.viewport_y = y;
        self.current_state.viewport_width = width;
        self.current_state.viewport_height = height;
    }

    /// Clear render targets
    pub fn clear(self: *Renderer, color: bool, depth: bool, stencil: bool) void {
        _ = self;
        _ = color;
        _ = depth;
        _ = stencil;
        // Backend-specific implementation
    }

    /// Render a scene
    pub fn renderScene(self: *Renderer, scene: *Scene, cam: *Camera) !void {
        self.beginFrame();

        // Update scene transforms
        scene.updateTransforms();

        // Cull scene
        var visible_nodes: std.ArrayList(*SceneNode) = .{};
        defer visible_nodes.deinit(self.allocator);
        try scene.cullScene(cam, &visible_nodes);

        // Build render queue
        const camera_pos = cam.transform.position;
        for (visible_nodes.items) |node| {
            try self.render_queue.addItem(node, camera_pos);
        }

        // Sort render queue
        self.render_queue.sort();

        // Set camera matrices
        _ = cam.getViewProjectionMatrix();

        // Render opaque objects
        for (self.render_queue.opaque_items.items) |item| {
            self.renderNode(item.node, cam);
        }

        // Render transparent objects
        for (self.render_queue.transparent_items.items) |item| {
            self.renderNode(item.node, cam);
        }

        // Render overlay objects
        for (self.render_queue.overlay_items.items) |item| {
            self.renderNode(item.node, cam);
        }

        // Update statistics
        scene.stats.draw_calls = self.stats.draw_calls;

        self.endFrame();
    }

    /// Render a single node
    fn renderNode(self: *Renderer, node: *SceneNode, cam: *Camera) void {
        _ = cam;
        const m = node.mesh_ref orelse return;

        // Update stats
        self.stats.draw_calls += 1;
        self.stats.triangles += m.getTriangleCount();
        self.stats.vertices += m.getVertexCount();
    }

    /// Draw a mesh with material
    pub fn drawMesh(self: *Renderer, m: *Mesh, mat: *Material, model_matrix: Mat4, view_proj: Mat4) void {
        _ = self;
        _ = m;
        _ = mat;
        _ = model_matrix;
        _ = view_proj;
        // Backend-specific implementation
    }

    /// Draw a debug line
    pub fn drawLine(self: *Renderer, start: Vec3, end: Vec3, color: Color) void {
        _ = self;
        _ = start;
        _ = end;
        _ = color;
        // Debug drawing implementation
    }

    /// Draw a debug box
    pub fn drawBox(self: *Renderer, center: Vec3, size: Vec3, color: Color) void {
        const half = size.scale(0.5);
        const corners = [8]Vec3{
            center.add(Vec3.init(-half.x, -half.y, -half.z)),
            center.add(Vec3.init(half.x, -half.y, -half.z)),
            center.add(Vec3.init(half.x, half.y, -half.z)),
            center.add(Vec3.init(-half.x, half.y, -half.z)),
            center.add(Vec3.init(-half.x, -half.y, half.z)),
            center.add(Vec3.init(half.x, -half.y, half.z)),
            center.add(Vec3.init(half.x, half.y, half.z)),
            center.add(Vec3.init(-half.x, half.y, half.z)),
        };

        // Bottom
        self.drawLine(corners[0], corners[1], color);
        self.drawLine(corners[1], corners[2], color);
        self.drawLine(corners[2], corners[3], color);
        self.drawLine(corners[3], corners[0], color);

        // Top
        self.drawLine(corners[4], corners[5], color);
        self.drawLine(corners[5], corners[6], color);
        self.drawLine(corners[6], corners[7], color);
        self.drawLine(corners[7], corners[4], color);

        // Verticals
        self.drawLine(corners[0], corners[4], color);
        self.drawLine(corners[1], corners[5], color);
        self.drawLine(corners[2], corners[6], color);
        self.drawLine(corners[3], corners[7], color);
    }

    /// Draw a debug sphere (wireframe)
    pub fn drawSphere(self: *Renderer, center: Vec3, radius: f32, color: Color, segments: u32) void {
        const seg_f: f32 = @floatFromInt(segments);

        // Draw three circles
        var i: u32 = 0;
        while (i < segments) : (i += 1) {
            const i_f: f32 = @floatFromInt(i);
            const i1_f: f32 = @floatFromInt(i + 1);

            const a0 = i_f * 2.0 * std.math.pi / seg_f;
            const a1 = i1_f * 2.0 * std.math.pi / seg_f;

            // XY circle
            self.drawLine(
                center.add(Vec3.init(@cos(a0) * radius, @sin(a0) * radius, 0)),
                center.add(Vec3.init(@cos(a1) * radius, @sin(a1) * radius, 0)),
                color,
            );

            // XZ circle
            self.drawLine(
                center.add(Vec3.init(@cos(a0) * radius, 0, @sin(a0) * radius)),
                center.add(Vec3.init(@cos(a1) * radius, 0, @sin(a1) * radius)),
                color,
            );

            // YZ circle
            self.drawLine(
                center.add(Vec3.init(0, @cos(a0) * radius, @sin(a0) * radius)),
                center.add(Vec3.init(0, @cos(a1) * radius, @sin(a1) * radius)),
                color,
            );
        }
    }
};

/// Render statistics
pub const RenderStats = struct {
    draw_calls: u32 = 0,
    triangles: usize = 0,
    vertices: usize = 0,
    texture_binds: u32 = 0,
    shader_switches: u32 = 0,
    frame_time_ms: f32 = 0,
    gpu_time_ms: f32 = 0,
};

// ============================================================================
// Render Pass
// ============================================================================

/// Type of render pass
pub const RenderPassType = enum {
    shadow,
    depth_prepass,
    gbuffer,
    lighting,
    forward,
    transparent,
    post_process,
    ui,
};

/// Render pass definition
pub const RenderPass = struct {
    name: []const u8 = "Pass",
    pass_type: RenderPassType,
    enabled: bool = true,

    // Clear settings
    clear_color: bool = true,
    clear_depth: bool = true,
    clear_stencil: bool = false,
    clear_color_value: Color = Color.black(),

    // Render target
    // target: ?*RenderTarget = null, // Would be implemented for actual rendering

    pub fn init(name: []const u8, pass_type: RenderPassType) RenderPass {
        return .{
            .name = name,
            .pass_type = pass_type,
        };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Renderer creation" {
    const allocator = std.testing.allocator;

    var renderer = Renderer.init(allocator, .webgl2);
    defer renderer.deinit();

    try std.testing.expect(renderer.backend == .webgl2);
    try std.testing.expect(renderer.capabilities.max_texture_size == 4096);
}

test "RenderQueue sorting" {
    const allocator = std.testing.allocator;

    var queue = RenderQueue.init(allocator);
    defer queue.deinit();

    // Would need actual scene nodes to test properly
    queue.sort();
}

test "Renderer capabilities" {
    const allocator = std.testing.allocator;

    var metal_renderer = Renderer.init(allocator, .metal);
    defer metal_renderer.deinit();

    try std.testing.expect(metal_renderer.capabilities.supports_compute);
    try std.testing.expect(metal_renderer.capabilities.max_texture_size == 16384);

    var webgl_renderer = Renderer.init(allocator, .webgl2);
    defer webgl_renderer.deinit();

    try std.testing.expect(!webgl_renderer.capabilities.supports_compute);
}
