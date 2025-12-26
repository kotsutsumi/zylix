//! Zylix 3D Graphics - Scene Graph
//!
//! Hierarchical scene management with transform propagation.

const std = @import("std");
const types = @import("types.zig");
const camera = @import("camera.zig");
const lighting = @import("lighting.zig");
const mesh_module = @import("mesh.zig");
const material = @import("material.zig");

const Vec3 = types.Vec3;
const Mat4 = types.Mat4;
const Transform = types.Transform;
const AABB = types.AABB;
const BoundingSphere = types.BoundingSphere;
const Frustum = types.Frustum;

const Camera = camera.Camera;
const CameraManager = camera.CameraManager;
const LightManager = lighting.LightManager;
const Mesh = mesh_module.Mesh;
const Material = material.Material;

// ============================================================================
// Scene Node
// ============================================================================

/// Type of scene node
pub const NodeType = enum {
    empty,
    mesh,
    camera,
    light,
    group,
};

/// Scene node in the hierarchy
pub const SceneNode = struct {
    // Identity
    name: []const u8 = "Node",
    id: u64 = 0,
    enabled: bool = true,

    // Transform
    local_transform: Transform = Transform.identity(),
    world_transform: Transform = Transform.identity(),
    world_matrix: Mat4 = Mat4.identity(),
    transform_dirty: bool = true,

    // Hierarchy
    parent: ?*SceneNode = null,
    children: std.ArrayList(*SceneNode),

    // Components
    node_type: NodeType = .empty,
    mesh_ref: ?*Mesh = null,
    material_ref: ?*Material = null,
    camera_ref: ?*Camera = null,
    light_type: ?lighting.LightType = null,

    // Culling
    layer: u32 = 0, // Layer mask bit
    bounds_aabb: AABB = AABB.empty(),
    bounds_sphere: BoundingSphere = .{},
    visible: bool = true,
    cull_mode: CullMode = .frustum,

    // Memory
    allocator: std.mem.Allocator,

    pub const CullMode = enum {
        none, // Never cull
        frustum, // Frustum culling
        distance, // Distance-based culling
        both, // Both frustum and distance
    };

    pub fn init(allocator: std.mem.Allocator, name: []const u8) SceneNode {
        return .{
            .name = name,
            .children = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SceneNode) void {
        // Recursively deinit children
        for (self.children.items) |child| {
            child.deinit();
            self.allocator.destroy(child);
        }
        self.children.deinit(self.allocator);
    }

    /// Add a child node
    pub fn addChild(self: *SceneNode, child: *SceneNode) !void {
        // Remove from previous parent if any
        if (child.parent) |old_parent| {
            old_parent.removeChild(child);
        }

        child.parent = self;
        try self.children.append(self.allocator, child);
        child.markTransformDirty();
    }

    /// Remove a child node
    pub fn removeChild(self: *SceneNode, child: *SceneNode) void {
        for (self.children.items, 0..) |c, i| {
            if (c == child) {
                _ = self.children.orderedRemove(i);
                child.parent = null;
                child.markTransformDirty();
                return;
            }
        }
    }

    /// Create a child node
    pub fn createChild(self: *SceneNode, name: []const u8) !*SceneNode {
        const child = try self.allocator.create(SceneNode);
        child.* = SceneNode.init(self.allocator, name);
        try self.addChild(child);
        return child;
    }

    /// Mark transform as needing update
    pub fn markTransformDirty(self: *SceneNode) void {
        self.transform_dirty = true;
        for (self.children.items) |child| {
            child.markTransformDirty();
        }
    }

    /// Update world transform
    pub fn updateTransform(self: *SceneNode) void {
        if (!self.transform_dirty) return;

        if (self.parent) |p| {
            // Combine with parent transform
            self.world_matrix = p.world_matrix.multiply(self.local_transform.toMatrix());

            // Extract world transform components (simplified - full decomposition is complex)
            self.world_transform.position = Vec3.init(
                self.world_matrix.get(0, 3),
                self.world_matrix.get(1, 3),
                self.world_matrix.get(2, 3),
            );
        } else {
            self.world_matrix = self.local_transform.toMatrix();
            self.world_transform = self.local_transform;
        }

        self.transform_dirty = false;

        // Update children
        for (self.children.items) |child| {
            child.updateTransform();
        }
    }

    /// Set local position
    pub fn setPosition(self: *SceneNode, position: Vec3) void {
        self.local_transform.position = position;
        self.markTransformDirty();
    }

    /// Set local rotation
    pub fn setRotation(self: *SceneNode, rotation: types.Quaternion) void {
        self.local_transform.rotation = rotation;
        self.markTransformDirty();
    }

    /// Set local scale
    pub fn setScale(self: *SceneNode, scale: Vec3) void {
        self.local_transform.scale = scale;
        self.markTransformDirty();
    }

    /// Translate locally
    pub fn translate(self: *SceneNode, delta: Vec3) void {
        self.local_transform.position = self.local_transform.position.add(delta);
        self.markTransformDirty();
    }

    /// Rotate around axis
    pub fn rotate(self: *SceneNode, axis: Vec3, angle: f32) void {
        self.local_transform.rotate(axis, angle);
        self.markTransformDirty();
    }

    /// Look at target
    pub fn lookAt(self: *SceneNode, target: Vec3, up: Vec3) void {
        self.local_transform.lookAt(target, up);
        self.markTransformDirty();
    }

    /// Get world position
    pub fn getWorldPosition(self: *SceneNode) Vec3 {
        self.updateTransform();
        return self.world_transform.position;
    }

    /// Get world forward direction
    pub fn getWorldForward(self: *SceneNode) Vec3 {
        self.updateTransform();
        return self.world_transform.forward();
    }

    /// Update bounds from mesh
    pub fn updateBounds(self: *SceneNode) void {
        if (self.mesh_ref) |m| {
            self.bounds_aabb = m.bounds_aabb;
            self.bounds_sphere = m.bounds_sphere;
        }
    }

    /// Check if node is visible in frustum
    pub fn isInFrustum(self: *const SceneNode, frustum: Frustum) bool {
        if (self.cull_mode == .none) return true;

        // Transform bounds to world space (simplified - uses sphere center)
        const world_center = self.world_transform.position.add(self.bounds_sphere.center);
        const world_sphere = BoundingSphere{ .center = world_center, .radius = self.bounds_sphere.radius * self.world_transform.scale.x };

        return frustum.intersectsSphere(world_sphere);
    }

    /// Find child by name
    pub fn findChild(self: *const SceneNode, name: []const u8) ?*SceneNode {
        for (self.children.items) |child| {
            if (std.mem.eql(u8, child.name, name)) return child;

            if (child.findChild(name)) |found| return found;
        }
        return null;
    }

    /// Find children by layer
    pub fn findByLayer(self: *const SceneNode, layer_mask: u32, result: *std.ArrayList(*SceneNode)) void {
        if (self.layer & layer_mask != 0) {
            result.append(self.allocator, @constCast(self)) catch {
                std.log.warn("SceneNode.findByLayer: Failed to append result for node '{s}'", .{self.name});
            };
        }
        for (self.children.items) |child| {
            child.findByLayer(layer_mask, result);
        }
    }
};

// ============================================================================
// Scene
// ============================================================================

/// 3D scene containing nodes, cameras, and lights
pub const Scene = struct {
    name: []const u8 = "Scene",

    // Root node
    root: SceneNode,

    // Managers
    camera_manager: CameraManager,
    light_manager: LightManager,

    // Environment
    ambient_color: types.Color = types.Color.rgb(0.1, 0.1, 0.1),
    fog_enabled: bool = false,
    fog_color: types.Color = types.Color.rgb(0.5, 0.5, 0.5),
    fog_density: f32 = 0.01,
    fog_start: f32 = 10.0,
    fog_end: f32 = 100.0,

    // Skybox
    skybox: ?*material.TextureCube = null,

    // Statistics
    stats: SceneStats = .{},

    // Memory
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) Scene {
        return .{
            .name = name,
            .root = SceneNode.init(allocator, "Root"),
            .camera_manager = CameraManager.init(allocator),
            .light_manager = LightManager.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Scene) void {
        self.root.deinit();
        self.camera_manager.deinit();
        self.light_manager.deinit();
    }

    /// Create a new node in the scene
    pub fn createNode(self: *Scene, name: []const u8) !*SceneNode {
        return self.root.createChild(name);
    }

    /// Create a mesh node
    pub fn createMeshNode(self: *Scene, name: []const u8, m: *Mesh, mat: ?*Material) !*SceneNode {
        const node = try self.createNode(name);
        node.node_type = .mesh;
        node.mesh_ref = m;
        node.material_ref = mat;
        node.updateBounds();
        return node;
    }

    /// Create a camera node
    pub fn createCameraNode(self: *Scene, name: []const u8, cam: *Camera) !*SceneNode {
        const node = try self.createNode(name);
        node.node_type = .camera;
        node.camera_ref = cam;
        try self.camera_manager.addCamera(cam);
        return node;
    }

    /// Update all transforms in the scene
    pub fn updateTransforms(self: *Scene) void {
        self.root.updateTransform();
    }

    /// Perform frustum culling and populate visible list
    pub fn cullScene(self: *Scene, cam: *Camera, visible_nodes: *std.ArrayList(*SceneNode)) !void {
        visible_nodes.clearRetainingCapacity();
        const frustum = cam.getFrustum();
        try self.cullNode(&self.root, frustum, visible_nodes);
    }

    fn cullNode(self: *Scene, node: *SceneNode, frustum: Frustum, visible_nodes: *std.ArrayList(*SceneNode)) !void {
        if (!node.enabled) return;

        // Check visibility
        node.visible = node.isInFrustum(frustum);

        if (node.visible and node.node_type == .mesh) {
            try visible_nodes.append(self.allocator, node);
        }

        // Recurse to children
        for (node.children.items) |child| {
            try self.cullNode(child, frustum, visible_nodes);
        }
    }

    /// Update scene statistics
    pub fn updateStats(self: *Scene) void {
        self.stats.total_nodes = 0;
        self.stats.mesh_nodes = 0;
        self.stats.visible_nodes = 0;
        self.stats.total_triangles = 0;
        self.countNodes(&self.root);
    }

    fn countNodes(self: *Scene, node: *const SceneNode) void {
        self.stats.total_nodes += 1;

        if (node.node_type == .mesh) {
            self.stats.mesh_nodes += 1;
            if (node.visible) {
                self.stats.visible_nodes += 1;
                if (node.mesh_ref) |m| {
                    self.stats.total_triangles += m.getTriangleCount();
                }
            }
        }

        for (node.children.items) |child| {
            self.countNodes(child);
        }
    }

    /// Get all mesh nodes
    pub fn getMeshNodes(self: *Scene, result: *std.ArrayList(*SceneNode)) void {
        self.collectMeshNodes(&self.root, result);
    }

    fn collectMeshNodes(self: *Scene, node: *SceneNode, result: *std.ArrayList(*SceneNode)) void {
        if (node.node_type == .mesh) {
            result.append(self.allocator, node) catch {
                std.log.warn("Scene.collectMeshNodes: Failed to append result for node '{s}'", .{node.name});
            };
        }
        for (node.children.items) |child| {
            self.collectMeshNodes(child, result);
        }
    }
};

/// Scene statistics
pub const SceneStats = struct {
    total_nodes: u32 = 0,
    mesh_nodes: u32 = 0,
    visible_nodes: u32 = 0,
    total_triangles: usize = 0,
    draw_calls: u32 = 0,
    frame_time_ms: f32 = 0,
};

// ============================================================================
// Tests
// ============================================================================

test "SceneNode hierarchy" {
    const allocator = std.testing.allocator;

    var parent = SceneNode.init(allocator, "Parent");
    defer parent.deinit();

    const child = try parent.createChild("Child");
    try std.testing.expect(child.parent == &parent);
    try std.testing.expect(parent.children.items.len == 1);

    const grandchild = try child.createChild("Grandchild");
    try std.testing.expect(grandchild.parent == child);
}

test "SceneNode transform propagation" {
    const allocator = std.testing.allocator;

    var parent = SceneNode.init(allocator, "Parent");
    defer parent.deinit();

    parent.setPosition(Vec3.init(10, 0, 0));

    const child = try parent.createChild("Child");
    child.setPosition(Vec3.init(5, 0, 0));

    parent.updateTransform();

    // Child world position should be parent position + local position
    const world_pos = child.getWorldPosition();
    try std.testing.expectApproxEqAbs(@as(f32, 15), world_pos.x, 0.01);
}

test "Scene creation" {
    const allocator = std.testing.allocator;

    var scene = Scene.init(allocator, "TestScene");
    defer scene.deinit();

    _ = try scene.createNode("Node1");
    _ = try scene.createNode("Node2");

    scene.updateStats();
    try std.testing.expect(scene.stats.total_nodes == 3); // Root + 2 children
}

test "Scene find by name" {
    const allocator = std.testing.allocator;

    var scene = Scene.init(allocator, "TestScene");
    defer scene.deinit();

    _ = try scene.createNode("A");
    const b = try scene.createNode("B");
    _ = try b.createChild("C");

    const found = scene.root.findChild("C");
    try std.testing.expect(found != null);
    try std.testing.expect(std.mem.eql(u8, found.?.name, "C"));
}
