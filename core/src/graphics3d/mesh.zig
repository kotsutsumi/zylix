//! Zylix 3D Graphics - Mesh and Geometry
//!
//! Mesh data structures and primitive geometry generators.

const std = @import("std");
const types = @import("types.zig");

const Vec2 = types.Vec2;
const Vec3 = types.Vec3;
const Vec4 = types.Vec4;
const Color = types.Color;
const AABB = types.AABB;
const BoundingSphere = types.BoundingSphere;

// ============================================================================
// Vertex Formats
// ============================================================================

/// Basic vertex with position, normal, and UV
pub const Vertex = struct {
    position: Vec3 = Vec3.zero(),
    normal: Vec3 = Vec3.up(),
    uv: Vec2 = Vec2.zero(),
};

/// Extended vertex with tangent for normal mapping
pub const VertexTangent = struct {
    position: Vec3 = Vec3.zero(),
    normal: Vec3 = Vec3.up(),
    uv: Vec2 = Vec2.zero(),
    tangent: Vec4 = Vec4.init(1, 0, 0, 1), // w = handedness
};

/// Skinned vertex for skeletal animation
pub const VertexSkinned = struct {
    position: Vec3 = Vec3.zero(),
    normal: Vec3 = Vec3.up(),
    uv: Vec2 = Vec2.zero(),
    tangent: Vec4 = Vec4.init(1, 0, 0, 1),
    bone_indices: [4]u8 = [_]u8{0} ** 4,
    bone_weights: [4]f32 = [_]f32{ 1, 0, 0, 0 },
};

/// Vertex with color for debugging/simple rendering
pub const VertexColored = struct {
    position: Vec3 = Vec3.zero(),
    color: Color = Color.white(),
};

// ============================================================================
// Mesh Topology
// ============================================================================

/// Primitive topology for rendering
pub const PrimitiveTopology = enum {
    points,
    lines,
    line_strip,
    triangles,
    triangle_strip,
    triangle_fan,
};

/// Index format
pub const IndexFormat = enum {
    uint16,
    uint32,
};

// ============================================================================
// Mesh
// ============================================================================

/// 3D mesh containing vertex and index data
pub const Mesh = struct {
    // Vertex data
    vertices: std.ArrayList(Vertex),

    // Index data
    indices: std.ArrayList(u32),

    // Topology
    topology: PrimitiveTopology = .triangles,

    // Bounds
    bounds_aabb: AABB = AABB.empty(),
    bounds_sphere: BoundingSphere = .{},

    // Submeshes for multi-material rendering
    submeshes: std.ArrayList(SubMesh),

    // Memory
    allocator: std.mem.Allocator,

    // GPU state (set by renderer)
    gpu_dirty: bool = true,

    pub fn init(allocator: std.mem.Allocator) Mesh {
        return .{
            .vertices = .{},
            .indices = .{},
            .submeshes = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Mesh) void {
        self.vertices.deinit(self.allocator);
        self.indices.deinit(self.allocator);
        self.submeshes.deinit(self.allocator);
    }

    /// Set vertex data
    pub fn setVertices(self: *Mesh, vertices: []const Vertex) !void {
        self.vertices.clearRetainingCapacity();
        try self.vertices.appendSlice(self.allocator, vertices);
        self.gpu_dirty = true;
    }

    /// Set index data
    pub fn setIndices(self: *Mesh, indices: []const u32) !void {
        self.indices.clearRetainingCapacity();
        try self.indices.appendSlice(self.allocator, indices);
        self.gpu_dirty = true;
    }

    /// Add a submesh
    pub fn addSubMesh(self: *Mesh, start_index: u32, index_count: u32, material_index: u32) !void {
        try self.submeshes.append(self.allocator, .{
            .start_index = start_index,
            .index_count = index_count,
            .material_index = material_index,
        });
    }

    /// Recalculate bounds from vertex data
    pub fn recalculateBounds(self: *Mesh) void {
        if (self.vertices.items.len == 0) return;

        var positions: []Vec3 = self.allocator.alloc(Vec3, self.vertices.items.len) catch return;
        defer self.allocator.free(positions);

        for (self.vertices.items, 0..) |v, i| {
            positions[i] = v.position;
        }

        self.bounds_aabb = AABB.fromPoints(positions);
        self.bounds_sphere = BoundingSphere.fromPoints(positions);
    }

    /// Recalculate normals from triangle faces
    pub fn recalculateNormals(self: *Mesh) void {
        if (self.vertices.items.len == 0 or self.indices.items.len < 3) return;

        // Reset normals
        for (self.vertices.items) |*v| {
            v.normal = Vec3.zero();
        }

        // Accumulate face normals
        var i: usize = 0;
        while (i + 2 < self.indices.items.len) : (i += 3) {
            const idx0 = self.indices.items[i];
            const idx1 = self.indices.items[i + 1];
            const idx2 = self.indices.items[i + 2];

            const v0 = self.vertices.items[idx0].position;
            const v1 = self.vertices.items[idx1].position;
            const v2 = self.vertices.items[idx2].position;

            const edge1 = v1.sub(v0);
            const edge2 = v2.sub(v0);
            const face_normal = edge1.cross(edge2);

            self.vertices.items[idx0].normal = self.vertices.items[idx0].normal.add(face_normal);
            self.vertices.items[idx1].normal = self.vertices.items[idx1].normal.add(face_normal);
            self.vertices.items[idx2].normal = self.vertices.items[idx2].normal.add(face_normal);
        }

        // Normalize
        for (self.vertices.items) |*v| {
            v.normal = v.normal.normalize();
        }
    }

    /// Get vertex count
    pub fn getVertexCount(self: *const Mesh) usize {
        return self.vertices.items.len;
    }

    /// Get index count
    pub fn getIndexCount(self: *const Mesh) usize {
        return self.indices.items.len;
    }

    /// Get triangle count
    pub fn getTriangleCount(self: *const Mesh) usize {
        return self.indices.items.len / 3;
    }
};

/// Submesh defines a portion of a mesh with its own material
pub const SubMesh = struct {
    start_index: u32,
    index_count: u32,
    material_index: u32,
    bounds_aabb: ?AABB = null,
};

// ============================================================================
// Geometry Generators
// ============================================================================

/// Primitive geometry generators
pub const Geometry = struct {

    /// Create a unit cube (1x1x1)
    pub fn createCube(allocator: std.mem.Allocator) !Mesh {
        var mesh = Mesh.init(allocator);

        const vertices = [_]Vertex{
            // Front face
            .{ .position = Vec3.init(-0.5, -0.5, 0.5), .normal = Vec3.init(0, 0, 1), .uv = Vec2.init(0, 1) },
            .{ .position = Vec3.init(0.5, -0.5, 0.5), .normal = Vec3.init(0, 0, 1), .uv = Vec2.init(1, 1) },
            .{ .position = Vec3.init(0.5, 0.5, 0.5), .normal = Vec3.init(0, 0, 1), .uv = Vec2.init(1, 0) },
            .{ .position = Vec3.init(-0.5, 0.5, 0.5), .normal = Vec3.init(0, 0, 1), .uv = Vec2.init(0, 0) },
            // Back face
            .{ .position = Vec3.init(0.5, -0.5, -0.5), .normal = Vec3.init(0, 0, -1), .uv = Vec2.init(0, 1) },
            .{ .position = Vec3.init(-0.5, -0.5, -0.5), .normal = Vec3.init(0, 0, -1), .uv = Vec2.init(1, 1) },
            .{ .position = Vec3.init(-0.5, 0.5, -0.5), .normal = Vec3.init(0, 0, -1), .uv = Vec2.init(1, 0) },
            .{ .position = Vec3.init(0.5, 0.5, -0.5), .normal = Vec3.init(0, 0, -1), .uv = Vec2.init(0, 0) },
            // Top face
            .{ .position = Vec3.init(-0.5, 0.5, 0.5), .normal = Vec3.init(0, 1, 0), .uv = Vec2.init(0, 1) },
            .{ .position = Vec3.init(0.5, 0.5, 0.5), .normal = Vec3.init(0, 1, 0), .uv = Vec2.init(1, 1) },
            .{ .position = Vec3.init(0.5, 0.5, -0.5), .normal = Vec3.init(0, 1, 0), .uv = Vec2.init(1, 0) },
            .{ .position = Vec3.init(-0.5, 0.5, -0.5), .normal = Vec3.init(0, 1, 0), .uv = Vec2.init(0, 0) },
            // Bottom face
            .{ .position = Vec3.init(-0.5, -0.5, -0.5), .normal = Vec3.init(0, -1, 0), .uv = Vec2.init(0, 1) },
            .{ .position = Vec3.init(0.5, -0.5, -0.5), .normal = Vec3.init(0, -1, 0), .uv = Vec2.init(1, 1) },
            .{ .position = Vec3.init(0.5, -0.5, 0.5), .normal = Vec3.init(0, -1, 0), .uv = Vec2.init(1, 0) },
            .{ .position = Vec3.init(-0.5, -0.5, 0.5), .normal = Vec3.init(0, -1, 0), .uv = Vec2.init(0, 0) },
            // Right face
            .{ .position = Vec3.init(0.5, -0.5, 0.5), .normal = Vec3.init(1, 0, 0), .uv = Vec2.init(0, 1) },
            .{ .position = Vec3.init(0.5, -0.5, -0.5), .normal = Vec3.init(1, 0, 0), .uv = Vec2.init(1, 1) },
            .{ .position = Vec3.init(0.5, 0.5, -0.5), .normal = Vec3.init(1, 0, 0), .uv = Vec2.init(1, 0) },
            .{ .position = Vec3.init(0.5, 0.5, 0.5), .normal = Vec3.init(1, 0, 0), .uv = Vec2.init(0, 0) },
            // Left face
            .{ .position = Vec3.init(-0.5, -0.5, -0.5), .normal = Vec3.init(-1, 0, 0), .uv = Vec2.init(0, 1) },
            .{ .position = Vec3.init(-0.5, -0.5, 0.5), .normal = Vec3.init(-1, 0, 0), .uv = Vec2.init(1, 1) },
            .{ .position = Vec3.init(-0.5, 0.5, 0.5), .normal = Vec3.init(-1, 0, 0), .uv = Vec2.init(1, 0) },
            .{ .position = Vec3.init(-0.5, 0.5, -0.5), .normal = Vec3.init(-1, 0, 0), .uv = Vec2.init(0, 0) },
        };

        const indices = [_]u32{
            0,  1,  2,  0,  2,  3, // Front
            4,  5,  6,  4,  6,  7, // Back
            8,  9,  10, 8,  10, 11, // Top
            12, 13, 14, 12, 14, 15, // Bottom
            16, 17, 18, 16, 18, 19, // Right
            20, 21, 22, 20, 22, 23, // Left
        };

        try mesh.setVertices(&vertices);
        try mesh.setIndices(&indices);
        mesh.recalculateBounds();

        return mesh;
    }

    /// Create a UV sphere
    pub fn createSphere(allocator: std.mem.Allocator, radius: f32, segments: u32, rings: u32) !Mesh {
        var mesh = Mesh.init(allocator);

        const seg_f: f32 = @floatFromInt(segments);
        const ring_f: f32 = @floatFromInt(rings);

        // Generate vertices
        var j: u32 = 0;
        while (j <= rings) : (j += 1) {
            const j_f: f32 = @floatFromInt(j);
            const theta = j_f * std.math.pi / ring_f;
            const sin_theta = @sin(theta);
            const cos_theta = @cos(theta);

            var i: u32 = 0;
            while (i <= segments) : (i += 1) {
                const i_f: f32 = @floatFromInt(i);
                const phi = i_f * 2.0 * std.math.pi / seg_f;
                const sin_phi = @sin(phi);
                const cos_phi = @cos(phi);

                const x = cos_phi * sin_theta;
                const y = cos_theta;
                const z = sin_phi * sin_theta;

                try mesh.vertices.append(allocator, .{
                    .position = Vec3.init(x * radius, y * radius, z * radius),
                    .normal = Vec3.init(x, y, z),
                    .uv = Vec2.init(i_f / seg_f, j_f / ring_f),
                });
            }
        }

        // Generate indices
        j = 0;
        while (j < rings) : (j += 1) {
            var i: u32 = 0;
            while (i < segments) : (i += 1) {
                const first = j * (segments + 1) + i;
                const second = first + segments + 1;

                try mesh.indices.append(allocator, first);
                try mesh.indices.append(allocator, second);
                try mesh.indices.append(allocator, first + 1);

                try mesh.indices.append(allocator, second);
                try mesh.indices.append(allocator, second + 1);
                try mesh.indices.append(allocator, first + 1);
            }
        }

        mesh.recalculateBounds();
        return mesh;
    }

    /// Create a cylinder
    pub fn createCylinder(allocator: std.mem.Allocator, radius: f32, height: f32, segments: u32) !Mesh {
        var mesh = Mesh.init(allocator);

        const half_height = height * 0.5;
        const seg_f: f32 = @floatFromInt(segments);

        // Side vertices
        var i: u32 = 0;
        while (i <= segments) : (i += 1) {
            const i_f: f32 = @floatFromInt(i);
            const angle = i_f * 2.0 * std.math.pi / seg_f;
            const x = @cos(angle);
            const z = @sin(angle);

            // Bottom vertex
            try mesh.vertices.append(allocator, .{
                .position = Vec3.init(x * radius, -half_height, z * radius),
                .normal = Vec3.init(x, 0, z),
                .uv = Vec2.init(i_f / seg_f, 1),
            });

            // Top vertex
            try mesh.vertices.append(allocator, .{
                .position = Vec3.init(x * radius, half_height, z * radius),
                .normal = Vec3.init(x, 0, z),
                .uv = Vec2.init(i_f / seg_f, 0),
            });
        }

        // Side indices
        i = 0;
        while (i < segments) : (i += 1) {
            const base = i * 2;
            try mesh.indices.append(allocator, base);
            try mesh.indices.append(allocator, base + 2);
            try mesh.indices.append(allocator, base + 1);
            try mesh.indices.append(allocator, base + 1);
            try mesh.indices.append(allocator, base + 2);
            try mesh.indices.append(allocator, base + 3);
        }

        // Top cap center
        const top_center_idx: u32 = @intCast(mesh.vertices.items.len);
        try mesh.vertices.append(allocator, .{
            .position = Vec3.init(0, half_height, 0),
            .normal = Vec3.up(),
            .uv = Vec2.init(0.5, 0.5),
        });

        // Top cap vertices
        i = 0;
        while (i <= segments) : (i += 1) {
            const i_f: f32 = @floatFromInt(i);
            const angle = i_f * 2.0 * std.math.pi / seg_f;
            const x = @cos(angle);
            const z = @sin(angle);

            try mesh.vertices.append(allocator, .{
                .position = Vec3.init(x * radius, half_height, z * radius),
                .normal = Vec3.up(),
                .uv = Vec2.init(x * 0.5 + 0.5, z * 0.5 + 0.5),
            });
        }

        // Top cap indices
        i = 0;
        while (i < segments) : (i += 1) {
            try mesh.indices.append(allocator, top_center_idx);
            try mesh.indices.append(allocator, top_center_idx + 1 + i);
            try mesh.indices.append(allocator, top_center_idx + 2 + i);
        }

        // Bottom cap center
        const bottom_center_idx: u32 = @intCast(mesh.vertices.items.len);
        try mesh.vertices.append(allocator, .{
            .position = Vec3.init(0, -half_height, 0),
            .normal = Vec3.down(),
            .uv = Vec2.init(0.5, 0.5),
        });

        // Bottom cap vertices
        i = 0;
        while (i <= segments) : (i += 1) {
            const i_f: f32 = @floatFromInt(i);
            const angle = i_f * 2.0 * std.math.pi / seg_f;
            const x = @cos(angle);
            const z = @sin(angle);

            try mesh.vertices.append(allocator, .{
                .position = Vec3.init(x * radius, -half_height, z * radius),
                .normal = Vec3.down(),
                .uv = Vec2.init(x * 0.5 + 0.5, z * 0.5 + 0.5),
            });
        }

        // Bottom cap indices
        i = 0;
        while (i < segments) : (i += 1) {
            try mesh.indices.append(allocator, bottom_center_idx);
            try mesh.indices.append(allocator, bottom_center_idx + 2 + i);
            try mesh.indices.append(allocator, bottom_center_idx + 1 + i);
        }

        mesh.recalculateBounds();
        return mesh;
    }

    /// Create a plane
    pub fn createPlane(allocator: std.mem.Allocator, width: f32, height: f32, segments_x: u32, segments_z: u32) !Mesh {
        var mesh = Mesh.init(allocator);

        const half_w = width * 0.5;
        const half_h = height * 0.5;
        const seg_x_f: f32 = @floatFromInt(segments_x);
        const seg_z_f: f32 = @floatFromInt(segments_z);

        // Generate vertices
        var z: u32 = 0;
        while (z <= segments_z) : (z += 1) {
            const z_f: f32 = @floatFromInt(z);
            var x: u32 = 0;
            while (x <= segments_x) : (x += 1) {
                const x_f: f32 = @floatFromInt(x);

                try mesh.vertices.append(allocator, .{
                    .position = Vec3.init(
                        (x_f / seg_x_f - 0.5) * width,
                        0,
                        (z_f / seg_z_f - 0.5) * height,
                    ),
                    .normal = Vec3.up(),
                    .uv = Vec2.init(x_f / seg_x_f, z_f / seg_z_f),
                });
            }
        }

        _ = half_w;
        _ = half_h;

        // Generate indices
        z = 0;
        while (z < segments_z) : (z += 1) {
            var x: u32 = 0;
            while (x < segments_x) : (x += 1) {
                const base = z * (segments_x + 1) + x;
                try mesh.indices.append(allocator, base);
                try mesh.indices.append(allocator, base + segments_x + 1);
                try mesh.indices.append(allocator, base + 1);
                try mesh.indices.append(allocator, base + 1);
                try mesh.indices.append(allocator, base + segments_x + 1);
                try mesh.indices.append(allocator, base + segments_x + 2);
            }
        }

        mesh.recalculateBounds();
        return mesh;
    }

    /// Create a cone
    pub fn createCone(allocator: std.mem.Allocator, radius: f32, height: f32, segments: u32) !Mesh {
        var mesh = Mesh.init(allocator);

        const half_height = height * 0.5;
        const seg_f: f32 = @floatFromInt(segments);

        // Apex vertex
        const apex_idx: u32 = 0;
        try mesh.vertices.append(allocator, .{
            .position = Vec3.init(0, half_height, 0),
            .normal = Vec3.up(),
            .uv = Vec2.init(0.5, 0),
        });

        // Side vertices
        var i: u32 = 0;
        while (i <= segments) : (i += 1) {
            const i_f: f32 = @floatFromInt(i);
            const angle = i_f * 2.0 * std.math.pi / seg_f;
            const x = @cos(angle);
            const z = @sin(angle);

            // Calculate normal for cone surface
            const slope = radius / height;
            const normal = Vec3.init(x, slope, z).normalize();

            try mesh.vertices.append(allocator, .{
                .position = Vec3.init(x * radius, -half_height, z * radius),
                .normal = normal,
                .uv = Vec2.init(i_f / seg_f, 1),
            });
        }

        // Side indices
        i = 0;
        while (i < segments) : (i += 1) {
            try mesh.indices.append(allocator, apex_idx);
            try mesh.indices.append(allocator, 1 + i);
            try mesh.indices.append(allocator, 2 + i);
        }

        // Bottom cap center
        const bottom_center_idx: u32 = @intCast(mesh.vertices.items.len);
        try mesh.vertices.append(allocator, .{
            .position = Vec3.init(0, -half_height, 0),
            .normal = Vec3.down(),
            .uv = Vec2.init(0.5, 0.5),
        });

        // Bottom cap vertices
        i = 0;
        while (i <= segments) : (i += 1) {
            const i_f: f32 = @floatFromInt(i);
            const angle = i_f * 2.0 * std.math.pi / seg_f;
            const x = @cos(angle);
            const z = @sin(angle);

            try mesh.vertices.append(allocator, .{
                .position = Vec3.init(x * radius, -half_height, z * radius),
                .normal = Vec3.down(),
                .uv = Vec2.init(x * 0.5 + 0.5, z * 0.5 + 0.5),
            });
        }

        // Bottom cap indices
        i = 0;
        while (i < segments) : (i += 1) {
            try mesh.indices.append(allocator, bottom_center_idx);
            try mesh.indices.append(allocator, bottom_center_idx + 2 + i);
            try mesh.indices.append(allocator, bottom_center_idx + 1 + i);
        }

        mesh.recalculateBounds();
        return mesh;
    }

    /// Create a torus
    pub fn createTorus(allocator: std.mem.Allocator, major_radius: f32, minor_radius: f32, major_segments: u32, minor_segments: u32) !Mesh {
        var mesh = Mesh.init(allocator);

        const major_seg_f: f32 = @floatFromInt(major_segments);
        const minor_seg_f: f32 = @floatFromInt(minor_segments);

        // Generate vertices
        var i: u32 = 0;
        while (i <= major_segments) : (i += 1) {
            const i_f: f32 = @floatFromInt(i);
            const u = i_f * 2.0 * std.math.pi / major_seg_f;
            const cos_u = @cos(u);
            const sin_u = @sin(u);

            var j: u32 = 0;
            while (j <= minor_segments) : (j += 1) {
                const j_f: f32 = @floatFromInt(j);
                const v = j_f * 2.0 * std.math.pi / minor_seg_f;
                const cos_v = @cos(v);
                const sin_v = @sin(v);

                const x = (major_radius + minor_radius * cos_v) * cos_u;
                const y = minor_radius * sin_v;
                const z = (major_radius + minor_radius * cos_v) * sin_u;

                // Normal points from center of tube to vertex
                const nx = cos_v * cos_u;
                const ny = sin_v;
                const nz = cos_v * sin_u;

                try mesh.vertices.append(allocator, .{
                    .position = Vec3.init(x, y, z),
                    .normal = Vec3.init(nx, ny, nz),
                    .uv = Vec2.init(i_f / major_seg_f, j_f / minor_seg_f),
                });
            }
        }

        // Generate indices
        i = 0;
        while (i < major_segments) : (i += 1) {
            var j: u32 = 0;
            while (j < minor_segments) : (j += 1) {
                const first = i * (minor_segments + 1) + j;
                const second = first + minor_segments + 1;

                try mesh.indices.append(allocator, first);
                try mesh.indices.append(allocator, second);
                try mesh.indices.append(allocator, first + 1);

                try mesh.indices.append(allocator, second);
                try mesh.indices.append(allocator, second + 1);
                try mesh.indices.append(allocator, first + 1);
            }
        }

        mesh.recalculateBounds();
        return mesh;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Mesh creation" {
    const allocator = std.testing.allocator;

    var mesh = Mesh.init(allocator);
    defer mesh.deinit();

    const vertices = [_]Vertex{
        .{ .position = Vec3.init(0, 0, 0) },
        .{ .position = Vec3.init(1, 0, 0) },
        .{ .position = Vec3.init(0, 1, 0) },
    };
    const indices = [_]u32{ 0, 1, 2 };

    try mesh.setVertices(&vertices);
    try mesh.setIndices(&indices);

    try std.testing.expect(mesh.getVertexCount() == 3);
    try std.testing.expect(mesh.getIndexCount() == 3);
    try std.testing.expect(mesh.getTriangleCount() == 1);
}

test "Geometry cube" {
    const allocator = std.testing.allocator;

    var cube = try Geometry.createCube(allocator);
    defer cube.deinit();

    try std.testing.expect(cube.getVertexCount() == 24);
    try std.testing.expect(cube.getIndexCount() == 36);
    try std.testing.expect(cube.getTriangleCount() == 12);
}

test "Geometry sphere" {
    const allocator = std.testing.allocator;

    var sphere = try Geometry.createSphere(allocator, 1.0, 16, 8);
    defer sphere.deinit();

    try std.testing.expect(sphere.getVertexCount() > 0);
    try std.testing.expect(sphere.getIndexCount() > 0);
}

test "Geometry plane" {
    const allocator = std.testing.allocator;

    var plane = try Geometry.createPlane(allocator, 10.0, 10.0, 4, 4);
    defer plane.deinit();

    try std.testing.expect(plane.getVertexCount() == 25); // 5x5 grid
    try std.testing.expect(plane.getTriangleCount() == 32); // 4x4 quads = 32 triangles
}
