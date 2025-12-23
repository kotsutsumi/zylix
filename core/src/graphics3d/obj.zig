//! Zylix 3D Graphics - OBJ/MTL Loader
//!
//! Loader for Wavefront OBJ 3D models and MTL material files.
//! Simple, widely-supported text-based format.

const std = @import("std");
const types = @import("types.zig");
const mesh_module = @import("mesh.zig");
const material_module = @import("material.zig");

const Vec2 = types.Vec2;
const Vec3 = types.Vec3;
const Color = types.Color;

const Mesh = mesh_module.Mesh;
const Vertex = mesh_module.Vertex;
const Material = material_module.Material;

// ============================================================================
// OBJ Data Structures
// ============================================================================

/// Face vertex indices (position/texcoord/normal)
const FaceVertex = struct {
    position: u32 = 0,
    texcoord: ?u32 = null,
    normal: ?u32 = null,
};

/// OBJ mesh group
pub const ObjGroup = struct {
    name: []const u8 = "default",
    material_name: ?[]const u8 = null,
    face_start: usize = 0,
    face_count: usize = 0,
};

/// MTL material definition
pub const MtlMaterial = struct {
    name: []const u8 = "",

    // Ambient color
    ka: [3]f32 = .{ 0.2, 0.2, 0.2 },

    // Diffuse color (albedo)
    kd: [3]f32 = .{ 0.8, 0.8, 0.8 },

    // Specular color
    ks: [3]f32 = .{ 1.0, 1.0, 1.0 },

    // Emissive color
    ke: [3]f32 = .{ 0, 0, 0 },

    // Specular exponent (shininess)
    ns: f32 = 100.0,

    // Dissolve (opacity)
    d: f32 = 1.0,

    // Optical density (index of refraction)
    ni: f32 = 1.0,

    // Illumination model
    illum: u32 = 2,

    // Texture maps
    map_kd: ?[]const u8 = null, // Diffuse texture
    map_ks: ?[]const u8 = null, // Specular texture
    map_ka: ?[]const u8 = null, // Ambient texture
    map_bump: ?[]const u8 = null, // Bump/normal map
    map_d: ?[]const u8 = null, // Alpha texture
    map_ns: ?[]const u8 = null, // Specular highlight texture
};

/// Complete OBJ asset
pub const ObjAsset = struct {
    allocator: std.mem.Allocator,

    // Vertex data
    positions: std.ArrayListUnmanaged(Vec3) = .{},
    texcoords: std.ArrayListUnmanaged(Vec2) = .{},
    normals: std.ArrayListUnmanaged(Vec3) = .{},

    // Face data (triangulated)
    faces: std.ArrayListUnmanaged([3]FaceVertex) = .{},

    // Groups
    groups: std.ArrayListUnmanaged(ObjGroup) = .{},

    // Materials
    materials: std.StringHashMap(MtlMaterial),
    mtl_lib: ?[]const u8 = null,

    pub fn init(allocator: std.mem.Allocator) ObjAsset {
        return .{
            .allocator = allocator,
            .materials = std.StringHashMap(MtlMaterial).init(allocator),
        };
    }

    pub fn deinit(self: *ObjAsset) void {
        self.positions.deinit(self.allocator);
        self.texcoords.deinit(self.allocator);
        self.normals.deinit(self.allocator);
        self.faces.deinit(self.allocator);
        self.groups.deinit(self.allocator);
        self.materials.deinit();
    }
};

// ============================================================================
// OBJ Loader
// ============================================================================

/// OBJ file loader
pub const ObjLoader = struct {
    allocator: std.mem.Allocator,
    base_path: []const u8 = "",

    pub fn init(allocator: std.mem.Allocator) ObjLoader {
        return .{ .allocator = allocator };
    }

    /// Load OBJ from text data
    pub fn load(self: *ObjLoader, data: []const u8) !ObjAsset {
        var asset = ObjAsset.init(self.allocator);
        errdefer asset.deinit();

        var current_group = ObjGroup{};
        var group_started = false;

        var lines = std.mem.splitScalar(u8, data, '\n');
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r");
            if (trimmed.len == 0 or trimmed[0] == '#') continue;

            var parts = std.mem.splitScalar(u8, trimmed, ' ');
            const cmd = parts.next() orelse continue;

            if (std.mem.eql(u8, cmd, "v")) {
                // Vertex position
                const x = parseFloat(parts.next());
                const y = parseFloat(parts.next());
                const z = parseFloat(parts.next());
                try asset.positions.append(self.allocator, Vec3.init(x, y, z));
            } else if (std.mem.eql(u8, cmd, "vt")) {
                // Texture coordinate
                const u = parseFloat(parts.next());
                const v = parseFloat(parts.next());
                try asset.texcoords.append(self.allocator, Vec2.init(u, v));
            } else if (std.mem.eql(u8, cmd, "vn")) {
                // Vertex normal
                const x = parseFloat(parts.next());
                const y = parseFloat(parts.next());
                const z = parseFloat(parts.next());
                try asset.normals.append(self.allocator, Vec3.init(x, y, z).normalize());
            } else if (std.mem.eql(u8, cmd, "f")) {
                // Face (triangulate if needed)
                var face_verts: [16]FaceVertex = undefined;
                var vert_count: usize = 0;

                while (parts.next()) |vert_str| {
                    if (vert_count >= 16) break;
                    face_verts[vert_count] = parseFaceVertex(vert_str);
                    vert_count += 1;
                }

                // Triangulate (fan triangulation)
                if (vert_count >= 3) {
                    if (!group_started) {
                        current_group.face_start = asset.faces.items.len;
                        group_started = true;
                    }

                    var i: usize = 1;
                    while (i + 1 < vert_count) : (i += 1) {
                        try asset.faces.append(self.allocator, .{
                            face_verts[0],
                            face_verts[i],
                            face_verts[i + 1],
                        });
                        current_group.face_count += 1;
                    }
                }
            } else if (std.mem.eql(u8, cmd, "g") or std.mem.eql(u8, cmd, "o")) {
                // Group or object
                if (group_started and current_group.face_count > 0) {
                    try asset.groups.append(self.allocator, current_group);
                }

                const name = parts.rest();
                current_group = ObjGroup{
                    .name = if (name.len > 0) name else "default",
                    .face_start = asset.faces.items.len,
                    .face_count = 0,
                };
                group_started = true;
            } else if (std.mem.eql(u8, cmd, "usemtl")) {
                // Use material
                if (group_started and current_group.face_count > 0) {
                    try asset.groups.append(self.allocator, current_group);
                }

                current_group.material_name = parts.rest();
                current_group.face_start = asset.faces.items.len;
                current_group.face_count = 0;
                group_started = true;
            } else if (std.mem.eql(u8, cmd, "mtllib")) {
                // Material library
                asset.mtl_lib = parts.rest();
            }
        }

        // Add final group
        if (group_started and current_group.face_count > 0) {
            try asset.groups.append(self.allocator, current_group);
        }

        // If no groups, create a default one
        if (asset.groups.items.len == 0 and asset.faces.items.len > 0) {
            try asset.groups.append(self.allocator, ObjGroup{
                .name = "default",
                .face_start = 0,
                .face_count = asset.faces.items.len,
            });
        }

        return asset;
    }

    /// Load MTL material file
    pub fn loadMtl(_: *ObjLoader, asset: *ObjAsset, data: []const u8) !void {
        var current_mat: ?MtlMaterial = null;

        var lines = std.mem.splitScalar(u8, data, '\n');
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r");
            if (trimmed.len == 0 or trimmed[0] == '#') continue;

            var parts = std.mem.splitScalar(u8, trimmed, ' ');
            const cmd = parts.next() orelse continue;

            if (std.mem.eql(u8, cmd, "newmtl")) {
                // Save previous material
                if (current_mat) |mat| {
                    try asset.materials.put(mat.name, mat);
                }

                current_mat = MtlMaterial{
                    .name = parts.rest(),
                };
            } else if (current_mat != null) {
                if (std.mem.eql(u8, cmd, "Ka")) {
                    current_mat.?.ka = .{
                        parseFloat(parts.next()),
                        parseFloat(parts.next()),
                        parseFloat(parts.next()),
                    };
                } else if (std.mem.eql(u8, cmd, "Kd")) {
                    current_mat.?.kd = .{
                        parseFloat(parts.next()),
                        parseFloat(parts.next()),
                        parseFloat(parts.next()),
                    };
                } else if (std.mem.eql(u8, cmd, "Ks")) {
                    current_mat.?.ks = .{
                        parseFloat(parts.next()),
                        parseFloat(parts.next()),
                        parseFloat(parts.next()),
                    };
                } else if (std.mem.eql(u8, cmd, "Ke")) {
                    current_mat.?.ke = .{
                        parseFloat(parts.next()),
                        parseFloat(parts.next()),
                        parseFloat(parts.next()),
                    };
                } else if (std.mem.eql(u8, cmd, "Ns")) {
                    current_mat.?.ns = parseFloat(parts.next());
                } else if (std.mem.eql(u8, cmd, "d")) {
                    current_mat.?.d = parseFloat(parts.next());
                } else if (std.mem.eql(u8, cmd, "Tr")) {
                    current_mat.?.d = 1.0 - parseFloat(parts.next());
                } else if (std.mem.eql(u8, cmd, "Ni")) {
                    current_mat.?.ni = parseFloat(parts.next());
                } else if (std.mem.eql(u8, cmd, "illum")) {
                    current_mat.?.illum = parseInt(parts.next());
                } else if (std.mem.eql(u8, cmd, "map_Kd")) {
                    current_mat.?.map_kd = parts.rest();
                } else if (std.mem.eql(u8, cmd, "map_Ks")) {
                    current_mat.?.map_ks = parts.rest();
                } else if (std.mem.eql(u8, cmd, "map_Ka")) {
                    current_mat.?.map_ka = parts.rest();
                } else if (std.mem.eql(u8, cmd, "map_Bump") or std.mem.eql(u8, cmd, "bump")) {
                    current_mat.?.map_bump = parts.rest();
                } else if (std.mem.eql(u8, cmd, "map_d")) {
                    current_mat.?.map_d = parts.rest();
                } else if (std.mem.eql(u8, cmd, "map_Ns")) {
                    current_mat.?.map_ns = parts.rest();
                }
            }
        }

        // Save last material
        if (current_mat) |mat| {
            try asset.materials.put(mat.name, mat);
        }
    }

    /// Convert OBJ asset to Zylix mesh
    pub fn toMesh(self: *ObjLoader, asset: *const ObjAsset) !Mesh {
        var mesh = Mesh.init(self.allocator);
        errdefer mesh.deinit();

        // Build unique vertices
        var vertex_map = std.AutoHashMap(u128, u32).init(self.allocator);
        defer vertex_map.deinit();

        for (asset.faces.items) |face| {
            for (face) |fv| {
                const key = makeVertexKey(fv);

                if (vertex_map.get(key)) |idx| {
                    try mesh.indices.append(self.allocator, idx);
                } else {
                    const new_idx: u32 = @intCast(mesh.vertices.items.len);

                    // Build vertex
                    const pos_idx = fv.position;
                    const pos = if (pos_idx > 0 and pos_idx <= asset.positions.items.len)
                        asset.positions.items[pos_idx - 1]
                    else
                        Vec3.zero();

                    const uv = if (fv.texcoord) |tc_idx| blk: {
                        break :blk if (tc_idx > 0 and tc_idx <= asset.texcoords.items.len)
                            asset.texcoords.items[tc_idx - 1]
                        else
                            Vec2.zero();
                    } else Vec2.zero();

                    const normal = if (fv.normal) |n_idx| blk: {
                        break :blk if (n_idx > 0 and n_idx <= asset.normals.items.len)
                            asset.normals.items[n_idx - 1]
                        else
                            Vec3.up();
                    } else Vec3.up();

                    const vertex = Vertex{
                        .position = pos,
                        .normal = normal,
                        .uv = uv,
                        .color = Color.white(),
                    };

                    try mesh.vertices.append(self.allocator, vertex);
                    try mesh.indices.append(self.allocator, new_idx);
                    try vertex_map.put(key, new_idx);
                }
            }
        }

        // Calculate normals if not provided
        if (asset.normals.items.len == 0) {
            mesh.calculateNormals();
        }

        mesh.calculateBounds();
        return mesh;
    }

    /// Convert OBJ group to Zylix mesh
    pub fn groupToMesh(self: *ObjLoader, asset: *const ObjAsset, group_index: usize) !Mesh {
        if (group_index >= asset.groups.items.len) return error.InvalidGroupIndex;

        const group = asset.groups.items[group_index];
        var mesh = Mesh.init(self.allocator);
        errdefer mesh.deinit();

        var vertex_map = std.AutoHashMap(u128, u32).init(self.allocator);
        defer vertex_map.deinit();

        const end = group.face_start + group.face_count;
        for (asset.faces.items[group.face_start..end]) |face| {
            for (face) |fv| {
                const key = makeVertexKey(fv);

                if (vertex_map.get(key)) |idx| {
                    try mesh.indices.append(self.allocator, idx);
                } else {
                    const new_idx: u32 = @intCast(mesh.vertices.items.len);

                    const pos_idx = fv.position;
                    const pos = if (pos_idx > 0 and pos_idx <= asset.positions.items.len)
                        asset.positions.items[pos_idx - 1]
                    else
                        Vec3.zero();

                    const uv = if (fv.texcoord) |tc_idx| blk: {
                        break :blk if (tc_idx > 0 and tc_idx <= asset.texcoords.items.len)
                            asset.texcoords.items[tc_idx - 1]
                        else
                            Vec2.zero();
                    } else Vec2.zero();

                    const normal = if (fv.normal) |n_idx| blk: {
                        break :blk if (n_idx > 0 and n_idx <= asset.normals.items.len)
                            asset.normals.items[n_idx - 1]
                        else
                            Vec3.up();
                    } else Vec3.up();

                    const vertex = Vertex{
                        .position = pos,
                        .normal = normal,
                        .uv = uv,
                        .color = Color.white(),
                    };

                    try mesh.vertices.append(self.allocator, vertex);
                    try mesh.indices.append(self.allocator, new_idx);
                    try vertex_map.put(key, new_idx);
                }
            }
        }

        if (asset.normals.items.len == 0) {
            mesh.calculateNormals();
        }

        mesh.calculateBounds();
        return mesh;
    }

    /// Convert MTL material to Zylix material
    pub fn toMaterial(_: *ObjLoader, mtl: *const MtlMaterial) Material {
        var mat = Material.init();

        mat.albedo = Color.rgb(mtl.kd[0], mtl.kd[1], mtl.kd[2]);
        mat.albedo.a = mtl.d;

        mat.emission = Color.rgb(mtl.ke[0], mtl.ke[1], mtl.ke[2]);

        // Estimate roughness from specular exponent
        mat.roughness = 1.0 - @min(1.0, mtl.ns / 1000.0);

        // Metallic estimation (simple heuristic)
        const avg_spec = (mtl.ks[0] + mtl.ks[1] + mtl.ks[2]) / 3.0;
        mat.metallic = if (avg_spec > 0.5) avg_spec else 0.0;

        // Transparency
        if (mtl.d < 1.0) {
            mat.blend_mode = .alpha_blend;
        }

        return mat;
    }
};

// ============================================================================
// Helper Functions
// ============================================================================

fn parseFloat(str: ?[]const u8) f32 {
    const s = str orelse return 0;
    return std.fmt.parseFloat(f32, s) catch 0;
}

fn parseInt(str: ?[]const u8) u32 {
    const s = str orelse return 0;
    return std.fmt.parseInt(u32, s, 10) catch 0;
}

fn parseFaceVertex(str: []const u8) FaceVertex {
    var fv = FaceVertex{};
    var parts = std.mem.splitScalar(u8, str, '/');

    // Position index (required)
    if (parts.next()) |pos_str| {
        if (pos_str.len > 0) {
            fv.position = std.fmt.parseInt(u32, pos_str, 10) catch 0;
        }
    }

    // Texture coordinate index (optional)
    if (parts.next()) |tc_str| {
        if (tc_str.len > 0) {
            fv.texcoord = std.fmt.parseInt(u32, tc_str, 10) catch null;
        }
    }

    // Normal index (optional)
    if (parts.next()) |n_str| {
        if (n_str.len > 0) {
            fv.normal = std.fmt.parseInt(u32, n_str, 10) catch null;
        }
    }

    return fv;
}

fn makeVertexKey(fv: FaceVertex) u128 {
    const pos: u128 = fv.position;
    const tc: u128 = fv.texcoord orelse 0;
    const n: u128 = fv.normal orelse 0;
    return pos | (tc << 32) | (n << 64);
}

// ============================================================================
// Tests
// ============================================================================

test "ObjLoader init" {
    const allocator = std.testing.allocator;
    const loader = ObjLoader.init(allocator);
    _ = loader;
}

test "ObjAsset init/deinit" {
    const allocator = std.testing.allocator;
    var asset = ObjAsset.init(allocator);
    defer asset.deinit();

    try std.testing.expect(asset.positions.items.len == 0);
    try std.testing.expect(asset.faces.items.len == 0);
}

test "parseFloat" {
    try std.testing.expectApproxEqAbs(@as(f32, 1.5), parseFloat("1.5"), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -2.0), parseFloat("-2.0"), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), parseFloat(null), 0.001);
}

test "parseFaceVertex" {
    const fv1 = parseFaceVertex("1/2/3");
    try std.testing.expect(fv1.position == 1);
    try std.testing.expect(fv1.texcoord.? == 2);
    try std.testing.expect(fv1.normal.? == 3);

    const fv2 = parseFaceVertex("1//3");
    try std.testing.expect(fv2.position == 1);
    try std.testing.expect(fv2.texcoord == null);
    try std.testing.expect(fv2.normal.? == 3);

    const fv3 = parseFaceVertex("1");
    try std.testing.expect(fv3.position == 1);
    try std.testing.expect(fv3.texcoord == null);
    try std.testing.expect(fv3.normal == null);
}

test "ObjLoader parse simple cube" {
    const allocator = std.testing.allocator;
    var loader = ObjLoader.init(allocator);

    const obj_data =
        \\# Simple cube
        \\v -1 -1 1
        \\v 1 -1 1
        \\v 1 1 1
        \\v -1 1 1
        \\f 1 2 3 4
    ;

    var asset = try loader.load(obj_data);
    defer asset.deinit();

    try std.testing.expect(asset.positions.items.len == 4);
    try std.testing.expect(asset.faces.items.len == 2); // Quad triangulated to 2 triangles
}
