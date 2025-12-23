//! Zylix 3D Graphics - glTF 2.0 Loader
//!
//! Loader for glTF (GL Transmission Format) 3D models.
//! Supports both .gltf (JSON + binary) and .glb (binary) formats.
//!
//! Reference: https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html

const std = @import("std");
const types = @import("types.zig");
const mesh_module = @import("mesh.zig");
const material_module = @import("material.zig");
const scene_module = @import("scene.zig");

const Vec2 = types.Vec2;
const Vec3 = types.Vec3;
const Vec4 = types.Vec4;
const Quaternion = types.Quaternion;
const Mat4 = types.Mat4;
const Color = types.Color;
const Transform = types.Transform;

const Mesh = mesh_module.Mesh;
const Vertex = mesh_module.Vertex;
const Material = material_module.Material;
const Texture2D = material_module.Texture2D;

// ============================================================================
// glTF Data Structures
// ============================================================================

/// glTF component type
pub const ComponentType = enum(u32) {
    byte = 5120,
    unsigned_byte = 5121,
    short = 5122,
    unsigned_short = 5123,
    unsigned_int = 5125,
    float = 5126,

    pub fn size(self: ComponentType) usize {
        return switch (self) {
            .byte, .unsigned_byte => 1,
            .short, .unsigned_short => 2,
            .unsigned_int, .float => 4,
        };
    }
};

/// glTF accessor type
pub const AccessorType = enum {
    scalar,
    vec2,
    vec3,
    vec4,
    mat2,
    mat3,
    mat4,

    pub fn componentCount(self: AccessorType) usize {
        return switch (self) {
            .scalar => 1,
            .vec2 => 2,
            .vec3 => 3,
            .vec4 => 4,
            .mat2 => 4,
            .mat3 => 9,
            .mat4 => 16,
        };
    }

    pub fn fromString(str: []const u8) ?AccessorType {
        if (std.mem.eql(u8, str, "SCALAR")) return .scalar;
        if (std.mem.eql(u8, str, "VEC2")) return .vec2;
        if (std.mem.eql(u8, str, "VEC3")) return .vec3;
        if (std.mem.eql(u8, str, "VEC4")) return .vec4;
        if (std.mem.eql(u8, str, "MAT2")) return .mat2;
        if (std.mem.eql(u8, str, "MAT3")) return .mat3;
        if (std.mem.eql(u8, str, "MAT4")) return .mat4;
        return null;
    }
};

/// glTF primitive mode
pub const PrimitiveMode = enum(u32) {
    points = 0,
    lines = 1,
    line_loop = 2,
    line_strip = 3,
    triangles = 4,
    triangle_strip = 5,
    triangle_fan = 6,
};

/// glTF alpha mode
pub const AlphaMode = enum {
    @"opaque",
    mask,
    blend,
};

/// Buffer view target
pub const BufferTarget = enum(u32) {
    array_buffer = 34962,
    element_array_buffer = 34963,
};

// ============================================================================
// glTF Asset Structures
// ============================================================================

/// glTF buffer
pub const Buffer = struct {
    uri: ?[]const u8 = null,
    byte_length: usize = 0,
    data: ?[]u8 = null,
};

/// glTF buffer view
pub const BufferView = struct {
    buffer: u32 = 0,
    byte_offset: usize = 0,
    byte_length: usize = 0,
    byte_stride: ?usize = null,
    target: ?BufferTarget = null,
};

/// glTF accessor
pub const Accessor = struct {
    buffer_view: ?u32 = null,
    byte_offset: usize = 0,
    component_type: ComponentType = .float,
    normalized: bool = false,
    count: usize = 0,
    accessor_type: AccessorType = .scalar,
    min: ?[]f32 = null,
    max: ?[]f32 = null,
};

/// glTF texture sampler
pub const Sampler = struct {
    mag_filter: ?u32 = null,
    min_filter: ?u32 = null,
    wrap_s: u32 = 10497, // REPEAT
    wrap_t: u32 = 10497,
};

/// glTF image
pub const Image = struct {
    uri: ?[]const u8 = null,
    mime_type: ?[]const u8 = null,
    buffer_view: ?u32 = null,
    data: ?[]u8 = null,
};

/// glTF texture
pub const GltfTexture = struct {
    sampler: ?u32 = null,
    source: ?u32 = null,
};

/// glTF texture info
pub const TextureInfo = struct {
    index: u32 = 0,
    tex_coord: u32 = 0,
};

/// glTF normal texture info
pub const NormalTextureInfo = struct {
    index: u32 = 0,
    tex_coord: u32 = 0,
    scale: f32 = 1.0,
};

/// glTF occlusion texture info
pub const OcclusionTextureInfo = struct {
    index: u32 = 0,
    tex_coord: u32 = 0,
    strength: f32 = 1.0,
};

/// glTF PBR metallic roughness
pub const PbrMetallicRoughness = struct {
    base_color_factor: [4]f32 = .{ 1, 1, 1, 1 },
    base_color_texture: ?TextureInfo = null,
    metallic_factor: f32 = 1.0,
    roughness_factor: f32 = 1.0,
    metallic_roughness_texture: ?TextureInfo = null,
};

/// glTF material
pub const GltfMaterial = struct {
    name: ?[]const u8 = null,
    pbr_metallic_roughness: PbrMetallicRoughness = .{},
    normal_texture: ?NormalTextureInfo = null,
    occlusion_texture: ?OcclusionTextureInfo = null,
    emissive_texture: ?TextureInfo = null,
    emissive_factor: [3]f32 = .{ 0, 0, 0 },
    alpha_mode: AlphaMode = .@"opaque",
    alpha_cutoff: f32 = 0.5,
    double_sided: bool = false,
};

/// glTF mesh primitive
pub const Primitive = struct {
    attributes: std.StringHashMap(u32),
    indices: ?u32 = null,
    material: ?u32 = null,
    mode: PrimitiveMode = .triangles,

    pub fn init(allocator: std.mem.Allocator) Primitive {
        return .{
            .attributes = std.StringHashMap(u32).init(allocator),
        };
    }

    pub fn deinit(self: *Primitive) void {
        self.attributes.deinit();
    }
};

/// glTF mesh
pub const GltfMesh = struct {
    name: ?[]const u8 = null,
    primitives: std.ArrayListUnmanaged(Primitive) = .{},
    weights: ?[]f32 = null,

    pub fn init() GltfMesh {
        return .{};
    }

    pub fn deinit(self: *GltfMesh, allocator: std.mem.Allocator) void {
        for (self.primitives.items) |*p| {
            p.deinit();
        }
        self.primitives.deinit(allocator);
    }
};

/// glTF node
pub const GltfNode = struct {
    name: ?[]const u8 = null,
    children: ?[]u32 = null,
    mesh: ?u32 = null,
    camera: ?u32 = null,
    skin: ?u32 = null,
    matrix: ?[16]f32 = null,
    translation: [3]f32 = .{ 0, 0, 0 },
    rotation: [4]f32 = .{ 0, 0, 0, 1 },
    scale: [3]f32 = .{ 1, 1, 1 },
    weights: ?[]f32 = null,
};

/// glTF scene
pub const GltfScene = struct {
    name: ?[]const u8 = null,
    nodes: ?[]u32 = null,
};

/// glTF animation channel target
pub const AnimationTarget = struct {
    node: ?u32 = null,
    path: []const u8 = "",
};

/// glTF animation channel
pub const AnimationChannel = struct {
    sampler: u32 = 0,
    target: AnimationTarget = .{},
};

/// glTF animation sampler
pub const AnimationSampler = struct {
    input: u32 = 0,
    output: u32 = 0,
    interpolation: []const u8 = "LINEAR",
};

/// glTF animation
pub const GltfAnimation = struct {
    name: ?[]const u8 = null,
    channels: []AnimationChannel = &.{},
    samplers: []AnimationSampler = &.{},
};

/// glTF skin
pub const Skin = struct {
    name: ?[]const u8 = null,
    inverse_bind_matrices: ?u32 = null,
    skeleton: ?u32 = null,
    joints: []u32 = &.{},
};

// ============================================================================
// glTF Asset
// ============================================================================

/// Complete glTF asset
pub const GltfAsset = struct {
    allocator: std.mem.Allocator,

    // Asset info
    version: []const u8 = "2.0",
    generator: ?[]const u8 = null,
    copyright: ?[]const u8 = null,

    // Data arrays
    buffers: std.ArrayListUnmanaged(Buffer) = .{},
    buffer_views: std.ArrayListUnmanaged(BufferView) = .{},
    accessors: std.ArrayListUnmanaged(Accessor) = .{},
    images: std.ArrayListUnmanaged(Image) = .{},
    samplers: std.ArrayListUnmanaged(Sampler) = .{},
    textures: std.ArrayListUnmanaged(GltfTexture) = .{},
    materials: std.ArrayListUnmanaged(GltfMaterial) = .{},
    meshes: std.ArrayListUnmanaged(GltfMesh) = .{},
    nodes: std.ArrayListUnmanaged(GltfNode) = .{},
    scenes: std.ArrayListUnmanaged(GltfScene) = .{},
    animations: std.ArrayListUnmanaged(GltfAnimation) = .{},
    skins: std.ArrayListUnmanaged(Skin) = .{},

    // Default scene
    scene: ?u32 = null,

    // Binary data (for .glb)
    binary_chunk: ?[]u8 = null,

    pub fn init(allocator: std.mem.Allocator) GltfAsset {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *GltfAsset) void {
        // Free buffer data
        for (self.buffers.items) |*buf| {
            if (buf.data) |data| {
                self.allocator.free(data);
            }
        }
        self.buffers.deinit(self.allocator);

        self.buffer_views.deinit(self.allocator);
        self.accessors.deinit(self.allocator);
        self.images.deinit(self.allocator);
        self.samplers.deinit(self.allocator);
        self.textures.deinit(self.allocator);
        self.materials.deinit(self.allocator);

        for (self.meshes.items) |*m| {
            m.deinit(self.allocator);
        }
        self.meshes.deinit(self.allocator);

        self.nodes.deinit(self.allocator);
        self.scenes.deinit(self.allocator);
        self.animations.deinit(self.allocator);
        self.skins.deinit(self.allocator);

        if (self.binary_chunk) |chunk| {
            self.allocator.free(chunk);
        }
    }
};

// ============================================================================
// glTF Loader
// ============================================================================

/// glTF loader
pub const GltfLoader = struct {
    allocator: std.mem.Allocator,
    base_path: []const u8 = "",

    pub fn init(allocator: std.mem.Allocator) GltfLoader {
        return .{ .allocator = allocator };
    }

    /// Load glTF from file data
    pub fn load(self: *GltfLoader, data: []const u8) !GltfAsset {
        // Check for GLB magic number
        if (data.len >= 4 and std.mem.eql(u8, data[0..4], "glTF")) {
            return self.loadGlb(data);
        }

        // Parse as JSON
        return self.loadGltf(data);
    }

    /// Load .gltf (JSON) format
    fn loadGltf(self: *GltfLoader, data: []const u8) !GltfAsset {
        var asset = GltfAsset.init(self.allocator);
        errdefer asset.deinit();

        // Parse JSON
        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, data, .{}) catch {
            return error.InvalidJson;
        };
        defer parsed.deinit();

        const root = parsed.value;
        if (root != .object) return error.InvalidGltf;

        // Parse asset info
        if (root.object.get("asset")) |asset_obj| {
            if (asset_obj == .object) {
                if (asset_obj.object.get("version")) |v| {
                    if (v == .string) asset.version = v.string;
                }
            }
        }

        // Parse buffers
        if (root.object.get("buffers")) |buffers_arr| {
            if (buffers_arr == .array) {
                for (buffers_arr.array.items) |buf_obj| {
                    if (buf_obj == .object) {
                        var buf = Buffer{};
                        if (buf_obj.object.get("byteLength")) |bl| {
                            if (bl == .integer) buf.byte_length = @intCast(bl.integer);
                        }
                        if (buf_obj.object.get("uri")) |uri| {
                            if (uri == .string) buf.uri = uri.string;
                        }
                        try asset.buffers.append(self.allocator, buf);
                    }
                }
            }
        }

        // Parse buffer views
        if (root.object.get("bufferViews")) |bv_arr| {
            if (bv_arr == .array) {
                for (bv_arr.array.items) |bv_obj| {
                    if (bv_obj == .object) {
                        var bv = BufferView{};
                        if (bv_obj.object.get("buffer")) |b| {
                            if (b == .integer) bv.buffer = @intCast(b.integer);
                        }
                        if (bv_obj.object.get("byteOffset")) |bo| {
                            if (bo == .integer) bv.byte_offset = @intCast(bo.integer);
                        }
                        if (bv_obj.object.get("byteLength")) |bl| {
                            if (bl == .integer) bv.byte_length = @intCast(bl.integer);
                        }
                        if (bv_obj.object.get("byteStride")) |bs| {
                            if (bs == .integer) bv.byte_stride = @intCast(bs.integer);
                        }
                        try asset.buffer_views.append(self.allocator, bv);
                    }
                }
            }
        }

        // Parse accessors
        if (root.object.get("accessors")) |acc_arr| {
            if (acc_arr == .array) {
                for (acc_arr.array.items) |acc_obj| {
                    if (acc_obj == .object) {
                        var acc = Accessor{};
                        if (acc_obj.object.get("bufferView")) |bv| {
                            if (bv == .integer) acc.buffer_view = @intCast(bv.integer);
                        }
                        if (acc_obj.object.get("byteOffset")) |bo| {
                            if (bo == .integer) acc.byte_offset = @intCast(bo.integer);
                        }
                        if (acc_obj.object.get("componentType")) |ct| {
                            if (ct == .integer) acc.component_type = @enumFromInt(@as(u32, @intCast(ct.integer)));
                        }
                        if (acc_obj.object.get("count")) |c| {
                            if (c == .integer) acc.count = @intCast(c.integer);
                        }
                        if (acc_obj.object.get("type")) |t| {
                            if (t == .string) {
                                acc.accessor_type = AccessorType.fromString(t.string) orelse .scalar;
                            }
                        }
                        try asset.accessors.append(self.allocator, acc);
                    }
                }
            }
        }

        // Parse meshes
        if (root.object.get("meshes")) |meshes_arr| {
            if (meshes_arr == .array) {
                for (meshes_arr.array.items) |mesh_obj| {
                    if (mesh_obj == .object) {
                        var gltf_mesh = GltfMesh.init();

                        if (mesh_obj.object.get("name")) |n| {
                            if (n == .string) gltf_mesh.name = n.string;
                        }

                        if (mesh_obj.object.get("primitives")) |prims_arr| {
                            if (prims_arr == .array) {
                                for (prims_arr.array.items) |prim_obj| {
                                    if (prim_obj == .object) {
                                        var prim = Primitive.init(self.allocator);

                                        if (prim_obj.object.get("attributes")) |attrs| {
                                            if (attrs == .object) {
                                                var iter = attrs.object.iterator();
                                                while (iter.next()) |entry| {
                                                    if (entry.value_ptr.* == .integer) {
                                                        try prim.attributes.put(entry.key_ptr.*, @intCast(entry.value_ptr.integer));
                                                    }
                                                }
                                            }
                                        }

                                        if (prim_obj.object.get("indices")) |idx| {
                                            if (idx == .integer) prim.indices = @intCast(idx.integer);
                                        }

                                        if (prim_obj.object.get("material")) |mat| {
                                            if (mat == .integer) prim.material = @intCast(mat.integer);
                                        }

                                        if (prim_obj.object.get("mode")) |m| {
                                            if (m == .integer) prim.mode = @enumFromInt(@as(u32, @intCast(m.integer)));
                                        }

                                        try gltf_mesh.primitives.append(self.allocator, prim);
                                    }
                                }
                            }
                        }

                        try asset.meshes.append(self.allocator, gltf_mesh);
                    }
                }
            }
        }

        // Parse nodes
        if (root.object.get("nodes")) |nodes_arr| {
            if (nodes_arr == .array) {
                for (nodes_arr.array.items) |node_obj| {
                    if (node_obj == .object) {
                        var node = GltfNode{};

                        if (node_obj.object.get("name")) |n| {
                            if (n == .string) node.name = n.string;
                        }

                        if (node_obj.object.get("mesh")) |m| {
                            if (m == .integer) node.mesh = @intCast(m.integer);
                        }

                        if (node_obj.object.get("translation")) |t| {
                            if (t == .array and t.array.items.len == 3) {
                                for (0..3) |i| {
                                    node.translation[i] = getFloat(t.array.items[i]);
                                }
                            }
                        }

                        if (node_obj.object.get("rotation")) |r| {
                            if (r == .array and r.array.items.len == 4) {
                                for (0..4) |i| {
                                    node.rotation[i] = getFloat(r.array.items[i]);
                                }
                            }
                        }

                        if (node_obj.object.get("scale")) |s| {
                            if (s == .array and s.array.items.len == 3) {
                                for (0..3) |i| {
                                    node.scale[i] = getFloat(s.array.items[i]);
                                }
                            }
                        }

                        try asset.nodes.append(self.allocator, node);
                    }
                }
            }
        }

        // Parse scenes
        if (root.object.get("scenes")) |scenes_arr| {
            if (scenes_arr == .array) {
                for (scenes_arr.array.items) |scene_obj| {
                    if (scene_obj == .object) {
                        var gltf_scene = GltfScene{};

                        if (scene_obj.object.get("name")) |n| {
                            if (n == .string) gltf_scene.name = n.string;
                        }

                        try asset.scenes.append(self.allocator, gltf_scene);
                    }
                }
            }
        }

        // Parse default scene
        if (root.object.get("scene")) |s| {
            if (s == .integer) asset.scene = @intCast(s.integer);
        }

        return asset;
    }

    /// Load .glb (binary) format
    fn loadGlb(self: *GltfLoader, data: []const u8) !GltfAsset {
        if (data.len < 12) return error.InvalidGlb;

        // GLB Header
        const magic = std.mem.readInt(u32, data[0..4], .little);
        if (magic != 0x46546C67) return error.InvalidGlb; // "glTF"

        const version = std.mem.readInt(u32, data[4..8], .little);
        if (version != 2) return error.UnsupportedVersion;

        const length = std.mem.readInt(u32, data[8..12], .little);
        if (length > data.len) return error.InvalidGlb;

        // Parse chunks
        var offset: usize = 12;
        var json_chunk: ?[]const u8 = null;
        var binary_chunk: ?[]const u8 = null;

        while (offset + 8 <= data.len) {
            const chunk_length = std.mem.readInt(u32, data[offset..][0..4], .little);
            const chunk_type = std.mem.readInt(u32, data[offset + 4 ..][0..4], .little);
            offset += 8;

            if (offset + chunk_length > data.len) break;

            const chunk_data = data[offset .. offset + chunk_length];
            offset += chunk_length;

            switch (chunk_type) {
                0x4E4F534A => json_chunk = chunk_data, // "JSON"
                0x004E4942 => binary_chunk = chunk_data, // "BIN\0"
                else => {},
            }
        }

        if (json_chunk == null) return error.MissingJsonChunk;

        // Parse JSON chunk
        var asset = try self.loadGltf(json_chunk.?);

        // Store binary chunk
        if (binary_chunk) |bin| {
            asset.binary_chunk = try self.allocator.dupe(u8, bin);

            // Set buffer data for buffer 0 (usually the embedded binary)
            if (asset.buffers.items.len > 0) {
                asset.buffers.items[0].data = asset.binary_chunk;
            }
        }

        return asset;
    }

    /// Convert glTF asset to Zylix mesh
    pub fn toMesh(self: *GltfLoader, asset: *const GltfAsset, mesh_index: u32) !Mesh {
        if (mesh_index >= asset.meshes.items.len) return error.InvalidMeshIndex;

        const gltf_mesh = asset.meshes.items[mesh_index];
        var mesh = Mesh.init(self.allocator);
        errdefer mesh.deinit();

        // Process each primitive
        for (gltf_mesh.primitives.items) |prim| {
            // Get position accessor
            const pos_accessor_idx = prim.attributes.get("POSITION") orelse continue;
            const pos_accessor = asset.accessors.items[pos_accessor_idx];

            // Get other accessors
            const normal_accessor = if (prim.attributes.get("NORMAL")) |idx|
                &asset.accessors.items[idx]
            else
                null;

            const uv_accessor = if (prim.attributes.get("TEXCOORD_0")) |idx|
                &asset.accessors.items[idx]
            else
                null;

            // Read vertex data
            const vertex_count = pos_accessor.count;
            const positions = try self.readAccessorVec3(asset, &pos_accessor);
            defer self.allocator.free(positions);

            const normals = if (normal_accessor) |acc|
                try self.readAccessorVec3(asset, acc)
            else
                null;
            defer if (normals) |n| self.allocator.free(n);

            const uvs = if (uv_accessor) |acc|
                try self.readAccessorVec2(asset, acc)
            else
                null;
            defer if (uvs) |u| self.allocator.free(u);

            // Build vertices
            for (0..vertex_count) |i| {
                const vertex = Vertex{
                    .position = positions[i],
                    .normal = if (normals) |n| n[i] else Vec3.up(),
                    .uv = if (uvs) |u| u[i] else Vec2.zero(),
                    .color = Color.white(),
                };
                try mesh.vertices.append(self.allocator, vertex);
            }

            // Read indices
            if (prim.indices) |idx_accessor_idx| {
                const idx_accessor = asset.accessors.items[idx_accessor_idx];
                const indices = try self.readAccessorIndices(asset, &idx_accessor);
                defer self.allocator.free(indices);

                for (indices) |idx| {
                    try mesh.indices.append(self.allocator, idx);
                }
            }
        }

        mesh.calculateBounds();
        return mesh;
    }

    /// Read Vec3 data from accessor
    fn readAccessorVec3(self: *GltfLoader, asset: *const GltfAsset, accessor: *const Accessor) ![]Vec3 {
        const buffer_view_idx = accessor.buffer_view orelse return error.MissingBufferView;
        const buffer_view = asset.buffer_views.items[buffer_view_idx];
        const buffer = asset.buffers.items[buffer_view.buffer];

        const data = buffer.data orelse return error.MissingBufferData;
        const offset = buffer_view.byte_offset + accessor.byte_offset;
        const stride = buffer_view.byte_stride orelse (accessor.component_type.size() * accessor.accessor_type.componentCount());

        var result = try self.allocator.alloc(Vec3, accessor.count);
        errdefer self.allocator.free(result);

        for (0..accessor.count) |i| {
            const base = offset + i * stride;
            if (base + 12 > data.len) return error.BufferOverflow;

            result[i] = Vec3.init(
                @bitCast(std.mem.readInt(u32, data[base..][0..4], .little)),
                @bitCast(std.mem.readInt(u32, data[base + 4 ..][0..4], .little)),
                @bitCast(std.mem.readInt(u32, data[base + 8 ..][0..4], .little)),
            );
        }

        return result;
    }

    /// Read Vec2 data from accessor
    fn readAccessorVec2(self: *GltfLoader, asset: *const GltfAsset, accessor: *const Accessor) ![]Vec2 {
        const buffer_view_idx = accessor.buffer_view orelse return error.MissingBufferView;
        const buffer_view = asset.buffer_views.items[buffer_view_idx];
        const buffer = asset.buffers.items[buffer_view.buffer];

        const data = buffer.data orelse return error.MissingBufferData;
        const offset = buffer_view.byte_offset + accessor.byte_offset;
        const stride = buffer_view.byte_stride orelse (accessor.component_type.size() * accessor.accessor_type.componentCount());

        var result = try self.allocator.alloc(Vec2, accessor.count);
        errdefer self.allocator.free(result);

        for (0..accessor.count) |i| {
            const base = offset + i * stride;
            if (base + 8 > data.len) return error.BufferOverflow;

            result[i] = Vec2.init(
                @bitCast(std.mem.readInt(u32, data[base..][0..4], .little)),
                @bitCast(std.mem.readInt(u32, data[base + 4 ..][0..4], .little)),
            );
        }

        return result;
    }

    /// Read index data from accessor
    fn readAccessorIndices(self: *GltfLoader, asset: *const GltfAsset, accessor: *const Accessor) ![]u32 {
        const buffer_view_idx = accessor.buffer_view orelse return error.MissingBufferView;
        const buffer_view = asset.buffer_views.items[buffer_view_idx];
        const buffer = asset.buffers.items[buffer_view.buffer];

        const data = buffer.data orelse return error.MissingBufferData;
        const offset = buffer_view.byte_offset + accessor.byte_offset;

        var result = try self.allocator.alloc(u32, accessor.count);
        errdefer self.allocator.free(result);

        for (0..accessor.count) |i| {
            const base = offset + i * accessor.component_type.size();
            result[i] = switch (accessor.component_type) {
                .unsigned_byte => data[base],
                .unsigned_short => std.mem.readInt(u16, data[base..][0..2], .little),
                .unsigned_int => std.mem.readInt(u32, data[base..][0..4], .little),
                else => return error.InvalidIndexType,
            };
        }

        return result;
    }

    /// Convert glTF material to Zylix material
    pub fn toMaterial(_: *GltfLoader, asset: *const GltfAsset, material_index: u32) Material {
        if (material_index >= asset.materials.items.len) {
            return Material.init();
        }

        const gltf_mat = asset.materials.items[material_index];
        const pbr = gltf_mat.pbr_metallic_roughness;

        var mat = Material.init();
        mat.albedo = Color.rgba(
            pbr.base_color_factor[0],
            pbr.base_color_factor[1],
            pbr.base_color_factor[2],
            pbr.base_color_factor[3],
        );
        mat.metallic = pbr.metallic_factor;
        mat.roughness = pbr.roughness_factor;

        // Emissive
        mat.emission = Color.rgb(
            gltf_mat.emissive_factor[0],
            gltf_mat.emissive_factor[1],
            gltf_mat.emissive_factor[2],
        );

        // Alpha mode
        mat.blend_mode = switch (gltf_mat.alpha_mode) {
            .@"opaque" => .@"opaque",
            .blend => .alpha_blend,
            .mask => .@"opaque", // TODO: Implement alpha cutoff
        };

        // Double-sided
        if (gltf_mat.double_sided) {
            mat.cull_mode = .none;
        }

        return mat;
    }
};

// Helper function
fn getFloat(value: std.json.Value) f32 {
    return switch (value) {
        .float => @floatCast(value.float),
        .integer => @floatFromInt(value.integer),
        else => 0,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "GltfLoader init" {
    const allocator = std.testing.allocator;
    const loader = GltfLoader.init(allocator);
    _ = loader;
}

test "ComponentType size" {
    try std.testing.expect(ComponentType.byte.size() == 1);
    try std.testing.expect(ComponentType.unsigned_short.size() == 2);
    try std.testing.expect(ComponentType.float.size() == 4);
}

test "AccessorType componentCount" {
    try std.testing.expect(AccessorType.scalar.componentCount() == 1);
    try std.testing.expect(AccessorType.vec3.componentCount() == 3);
    try std.testing.expect(AccessorType.mat4.componentCount() == 16);
}

test "AccessorType fromString" {
    try std.testing.expect(AccessorType.fromString("VEC3") == .vec3);
    try std.testing.expect(AccessorType.fromString("MAT4") == .mat4);
    try std.testing.expect(AccessorType.fromString("INVALID") == null);
}

test "GltfAsset init/deinit" {
    const allocator = std.testing.allocator;
    var asset = GltfAsset.init(allocator);
    defer asset.deinit();

    try std.testing.expect(asset.buffers.items.len == 0);
    try std.testing.expect(asset.meshes.items.len == 0);
}
