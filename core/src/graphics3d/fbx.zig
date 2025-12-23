// ============================================================================
// Zylix Game Engine - FBX Model Loader
// ============================================================================
// FBX (Filmbox) format loader supporting both ASCII and Binary formats
// Developed by Autodesk, commonly used for 3D model exchange
// ============================================================================

const std = @import("std");
const Mesh = @import("mesh.zig").Mesh;
const Material = @import("material.zig").Material;
const types = @import("types.zig");
const Vec2 = types.Vec2;
const Vec3 = types.Vec3;
const Vec4 = types.Vec4;
const Color = types.Color;

// ============================================================================
// FBX Data Structures
// ============================================================================

/// FBX file header (binary format)
pub const FbxHeader = struct {
    magic: [21]u8, // "Kaydara FBX Binary  \x00"
    unknown: [2]u8, // Usually 0x1A, 0x00
    version: u32, // FBX version (e.g., 7400 = 7.4)
};

/// FBX property types
pub const PropertyType = enum(u8) {
    // Primitive types
    bool_type = 'C', // 1 byte boolean
    int16_type = 'Y', // 2 byte signed integer
    int32_type = 'I', // 4 byte signed integer
    int64_type = 'L', // 8 byte signed integer
    float_type = 'F', // 4 byte IEEE float
    double_type = 'D', // 8 byte IEEE float
    // Array types
    bool_array = 'b', // array of booleans
    int32_array = 'i', // array of int32
    int64_array = 'l', // array of int64
    float_array = 'f', // array of float
    double_array = 'd', // array of double
    // Special types
    string_type = 'S', // string
    raw_type = 'R', // raw binary data
    _,
};

/// FBX property value
pub const PropertyValue = union(enum) {
    bool_val: bool,
    int16_val: i16,
    int32_val: i32,
    int64_val: i64,
    float_val: f32,
    double_val: f64,
    bool_array: []const bool,
    int32_array: []const i32,
    int64_array: []const i64,
    float_array: []const f32,
    double_array: []const f64,
    string_val: []const u8,
    raw_val: []const u8,
};

/// FBX node property
pub const FbxProperty = struct {
    type_code: PropertyType,
    value: PropertyValue,
};

/// FBX node in the document tree
pub const FbxNode = struct {
    name: []const u8 = "",
    properties: std.ArrayListUnmanaged(FbxProperty) = .{},
    children: std.ArrayListUnmanaged(*FbxNode) = .{},
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) FbxNode {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *FbxNode) void {
        // Free array properties data
        for (self.properties.items) |prop| {
            switch (prop.value) {
                .bool_array => |arr| self.allocator.free(arr),
                .int32_array => |arr| self.allocator.free(arr),
                .int64_array => |arr| self.allocator.free(arr),
                .float_array => |arr| self.allocator.free(arr),
                .double_array => |arr| self.allocator.free(arr),
                else => {},
            }
        }
        for (self.children.items) |child| {
            child.deinit();
            self.allocator.destroy(child);
        }
        self.children.deinit(self.allocator);
        self.properties.deinit(self.allocator);
    }

    /// Find child node by name
    pub fn findChild(self: *const FbxNode, name: []const u8) ?*FbxNode {
        for (self.children.items) |child| {
            if (std.mem.eql(u8, child.name, name)) {
                return child;
            }
        }
        return null;
    }

    /// Find all children with given name
    pub fn findChildren(self: *const FbxNode, name: []const u8, allocator: std.mem.Allocator) !std.ArrayListUnmanaged(*FbxNode) {
        var result: std.ArrayListUnmanaged(*FbxNode) = .{};
        for (self.children.items) |child| {
            if (std.mem.eql(u8, child.name, name)) {
                try result.append(allocator, child);
            }
        }
        return result;
    }

    /// Get property as int64
    pub fn getPropertyInt64(self: *const FbxNode, index: usize) ?i64 {
        if (index >= self.properties.items.len) return null;
        const prop = self.properties.items[index];
        return switch (prop.value) {
            .int64_val => |v| v,
            .int32_val => |v| @as(i64, v),
            .int16_val => |v| @as(i64, v),
            else => null,
        };
    }

    /// Get property as string
    pub fn getPropertyString(self: *const FbxNode, index: usize) ?[]const u8 {
        if (index >= self.properties.items.len) return null;
        const prop = self.properties.items[index];
        return switch (prop.value) {
            .string_val => |v| v,
            else => null,
        };
    }

    /// Get property as double array
    pub fn getPropertyDoubleArray(self: *const FbxNode, index: usize) ?[]const f64 {
        if (index >= self.properties.items.len) return null;
        const prop = self.properties.items[index];
        return switch (prop.value) {
            .double_array => |v| v,
            else => null,
        };
    }

    /// Get property as int32 array
    pub fn getPropertyInt32Array(self: *const FbxNode, index: usize) ?[]const i32 {
        if (index >= self.properties.items.len) return null;
        const prop = self.properties.items[index];
        return switch (prop.value) {
            .int32_array => |v| v,
            else => null,
        };
    }
};

/// FBX mesh geometry data
pub const FbxGeometry = struct {
    id: i64,
    name: []const u8,
    vertices: []const f64, // Flat array of vertex positions (x, y, z, x, y, z, ...)
    polygon_vertex_index: []const i32, // Polygon indices (negative = end of polygon)
    normals: ?[]const f64,
    uvs: ?[]const f64,
    uv_indices: ?[]const i32,
    material_ids: ?[]const i32,
};

/// FBX material data
pub const FbxMaterial = struct {
    id: i64,
    name: []const u8,
    diffuse_color: Color,
    specular_color: Color,
    ambient_color: Color,
    emissive_color: Color,
    shininess: f32,
    opacity: f32,
    diffuse_texture: ?[]const u8,
    normal_texture: ?[]const u8,
};

/// FBX model (mesh instance)
pub const FbxModel = struct {
    id: i64 = 0,
    name: []const u8 = "",
    model_type: []const u8 = "Null", // "Mesh", "Null", "LimbNode", etc.
    translation: Vec3 = Vec3.zero(),
    rotation: Vec3 = Vec3.zero(), // Euler angles in degrees
    scaling: Vec3 = Vec3.init(1, 1, 1),
    geometry_id: ?i64 = null,
    material_ids: std.ArrayListUnmanaged(i64) = .{},
};

/// FBX document asset
pub const FbxAsset = struct {
    allocator: std.mem.Allocator,
    version: u32 = 0,
    root: *FbxNode = undefined,
    geometries: std.ArrayListUnmanaged(FbxGeometry) = .{},
    materials: std.ArrayListUnmanaged(FbxMaterial) = .{},
    models: std.ArrayListUnmanaged(FbxModel) = .{},
    connections: std.ArrayListUnmanaged(FbxConnection) = .{},

    pub fn deinit(self: *FbxAsset) void {
        self.root.deinit();
        self.allocator.destroy(self.root);

        for (self.models.items) |*model| {
            model.material_ids.deinit(self.allocator);
        }

        self.geometries.deinit(self.allocator);
        self.materials.deinit(self.allocator);
        self.models.deinit(self.allocator);
        self.connections.deinit(self.allocator);
    }
};

/// FBX connection types
pub const ConnectionType = enum {
    object_object, // OO - Object to Object
    object_property, // OP - Object to Property
};

/// FBX connection between objects
pub const FbxConnection = struct {
    connection_type: ConnectionType,
    child_id: i64,
    parent_id: i64,
    property_name: ?[]const u8,
};

// ============================================================================
// FBX Binary Format Constants
// ============================================================================

const FBX_MAGIC = "Kaydara FBX Binary  \x00";
const FBX_HEADER_SIZE = 27;
const NULL_RECORD_SIZE_V7500 = 25;
const NULL_RECORD_SIZE_V7400 = 13;

// ============================================================================
// FBX Loader
// ============================================================================

pub const FbxLoader = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) FbxLoader {
        return .{
            .allocator = allocator,
        };
    }

    /// Load FBX from binary data
    pub fn load(self: *FbxLoader, data: []const u8) !FbxAsset {
        if (data.len < FBX_HEADER_SIZE) {
            return error.InvalidFbxFile;
        }

        // Check if binary format
        if (std.mem.startsWith(u8, data, FBX_MAGIC)) {
            return self.loadBinary(data);
        }

        // Try ASCII format
        return self.loadAscii(data);
    }

    /// Load FBX binary format
    fn loadBinary(self: *FbxLoader, data: []const u8) !FbxAsset {
        var offset: usize = 0;

        // Parse header
        const header = try self.parseHeader(data, &offset);

        // Determine null record size based on version
        const null_record_size: usize = if (header.version >= 7500)
            NULL_RECORD_SIZE_V7500
        else
            NULL_RECORD_SIZE_V7400;

        // Create root node
        const root = try self.allocator.create(FbxNode);
        root.* = FbxNode.init(self.allocator);
        root.name = "Root";

        // Parse all top-level nodes
        while (offset + null_record_size < data.len) {
            const node = try self.parseNode(data, &offset, header.version);
            if (node) |n| {
                try root.children.append(self.allocator, n);
            } else {
                break; // Null record indicates end
            }
        }

        // Build asset from parsed nodes
        var asset = FbxAsset{
            .allocator = self.allocator,
            .version = header.version,
            .root = root,
            .geometries = .{},
            .materials = .{},
            .models = .{},
            .connections = .{},
        };

        // Extract data from nodes
        try self.extractObjects(&asset);
        try self.extractConnections(&asset);

        return asset;
    }

    /// Parse FBX header
    fn parseHeader(self: *FbxLoader, data: []const u8, offset: *usize) !FbxHeader {
        _ = self;

        if (data.len < FBX_HEADER_SIZE) {
            return error.InvalidFbxFile;
        }

        var header: FbxHeader = undefined;

        @memcpy(&header.magic, data[0..21]);
        @memcpy(&header.unknown, data[21..23]);
        header.version = std.mem.readInt(u32, data[23..27], .little);

        offset.* = FBX_HEADER_SIZE;

        return header;
    }

    /// Parse a single FBX node
    fn parseNode(self: *FbxLoader, data: []const u8, offset: *usize, version: u32) !?*FbxNode {
        const start_offset = offset.*;

        // Read node record header
        var end_offset: u64 = undefined;
        var num_properties: u64 = undefined;
        var property_list_len: u64 = undefined;
        var name_len: u8 = undefined;

        if (version >= 7500) {
            // 64-bit offsets for FBX 7.5+
            if (data.len < offset.* + 25) return error.UnexpectedEndOfData;

            end_offset = std.mem.readInt(u64, data[offset.*..][0..8], .little);
            num_properties = std.mem.readInt(u64, data[offset.* + 8 ..][0..8], .little);
            property_list_len = std.mem.readInt(u64, data[offset.* + 16 ..][0..8], .little);
            name_len = data[offset.* + 24];
            offset.* += 25;
        } else {
            // 32-bit offsets for FBX 7.4 and earlier
            if (data.len < offset.* + 13) return error.UnexpectedEndOfData;

            end_offset = std.mem.readInt(u32, data[offset.*..][0..4], .little);
            num_properties = std.mem.readInt(u32, data[offset.* + 4 ..][0..4], .little);
            property_list_len = std.mem.readInt(u32, data[offset.* + 8 ..][0..4], .little);
            name_len = data[offset.* + 12];
            offset.* += 13;
        }

        // Null record check
        if (end_offset == 0) {
            return null;
        }

        // Read node name
        if (data.len < offset.* + name_len) return error.UnexpectedEndOfData;
        const name = data[offset.* .. offset.* + name_len];
        offset.* += name_len;

        // Create node
        const node = try self.allocator.create(FbxNode);
        node.* = FbxNode.init(self.allocator);
        node.name = name;

        // Parse properties
        const property_end = offset.* + @as(usize, @intCast(property_list_len));
        var prop_count: u64 = 0;
        while (offset.* < property_end and prop_count < num_properties) {
            const prop = try self.parseProperty(data, offset);
            try node.properties.append(node.allocator, prop);
            prop_count += 1;
        }

        // Skip any remaining property data
        offset.* = property_end;

        // Parse child nodes
        while (offset.* < @as(usize, @intCast(end_offset))) {
            // Check for null record
            const remaining = @as(usize, @intCast(end_offset)) - offset.*;
            const null_size: usize = if (version >= 7500) NULL_RECORD_SIZE_V7500 else NULL_RECORD_SIZE_V7400;

            if (remaining < null_size) break;

            // Check if it's a null record (all zeros)
            var is_null = true;
            for (data[offset.* .. offset.* + null_size]) |b| {
                if (b != 0) {
                    is_null = false;
                    break;
                }
            }

            if (is_null) {
                offset.* += null_size;
                break;
            }

            const child = try self.parseNode(data, offset, version);
            if (child) |c| {
                try node.children.append(node.allocator, c);
            } else {
                break;
            }
        }

        // Ensure offset is at end_offset
        offset.* = @max(offset.*, @as(usize, @intCast(end_offset)));
        _ = start_offset;

        return node;
    }

    /// Parse a single property
    fn parseProperty(self: *FbxLoader, data: []const u8, offset: *usize) !FbxProperty {
        if (data.len < offset.* + 1) return error.UnexpectedEndOfData;

        const type_code: PropertyType = @enumFromInt(data[offset.*]);
        offset.* += 1;

        var prop = FbxProperty{
            .type_code = type_code,
            .value = undefined,
        };

        switch (type_code) {
            .bool_type => {
                if (data.len < offset.* + 1) return error.UnexpectedEndOfData;
                prop.value = .{ .bool_val = data[offset.*] != 0 };
                offset.* += 1;
            },
            .int16_type => {
                if (data.len < offset.* + 2) return error.UnexpectedEndOfData;
                prop.value = .{ .int16_val = std.mem.readInt(i16, data[offset.*..][0..2], .little) };
                offset.* += 2;
            },
            .int32_type => {
                if (data.len < offset.* + 4) return error.UnexpectedEndOfData;
                prop.value = .{ .int32_val = std.mem.readInt(i32, data[offset.*..][0..4], .little) };
                offset.* += 4;
            },
            .int64_type => {
                if (data.len < offset.* + 8) return error.UnexpectedEndOfData;
                prop.value = .{ .int64_val = std.mem.readInt(i64, data[offset.*..][0..8], .little) };
                offset.* += 8;
            },
            .float_type => {
                if (data.len < offset.* + 4) return error.UnexpectedEndOfData;
                const bits = std.mem.readInt(u32, data[offset.*..][0..4], .little);
                prop.value = .{ .float_val = @bitCast(bits) };
                offset.* += 4;
            },
            .double_type => {
                if (data.len < offset.* + 8) return error.UnexpectedEndOfData;
                const bits = std.mem.readInt(u64, data[offset.*..][0..8], .little);
                prop.value = .{ .double_val = @bitCast(bits) };
                offset.* += 8;
            },
            .string_type, .raw_type => {
                if (data.len < offset.* + 4) return error.UnexpectedEndOfData;
                const len = std.mem.readInt(u32, data[offset.*..][0..4], .little);
                offset.* += 4;
                if (data.len < offset.* + len) return error.UnexpectedEndOfData;
                const str = data[offset.* .. offset.* + len];
                offset.* += len;
                if (type_code == .string_type) {
                    prop.value = .{ .string_val = str };
                } else {
                    prop.value = .{ .raw_val = str };
                }
            },
            .bool_array => {
                const array = try self.parseArrayHeader(data, offset);
                const arr_data = try self.allocator.alloc(bool, array.count);
                for (0..array.count) |i| {
                    arr_data[i] = array.data[i] != 0;
                }
                prop.value = .{ .bool_array = arr_data };
            },
            .int32_array => {
                const array = try self.parseArrayHeader(data, offset);
                const count = array.count;
                const arr_data = try self.allocator.alloc(i32, count);
                for (0..count) |i| {
                    arr_data[i] = std.mem.readInt(i32, array.data[i * 4 ..][0..4], .little);
                }
                prop.value = .{ .int32_array = arr_data };
            },
            .int64_array => {
                const array = try self.parseArrayHeader(data, offset);
                const count = array.count;
                const arr_data = try self.allocator.alloc(i64, count);
                for (0..count) |i| {
                    arr_data[i] = std.mem.readInt(i64, array.data[i * 8 ..][0..8], .little);
                }
                prop.value = .{ .int64_array = arr_data };
            },
            .float_array => {
                const array = try self.parseArrayHeader(data, offset);
                const count = array.count;
                const arr_data = try self.allocator.alloc(f32, count);
                for (0..count) |i| {
                    const bits = std.mem.readInt(u32, array.data[i * 4 ..][0..4], .little);
                    arr_data[i] = @bitCast(bits);
                }
                prop.value = .{ .float_array = arr_data };
            },
            .double_array => {
                const array = try self.parseArrayHeader(data, offset);
                const count = array.count;
                const arr_data = try self.allocator.alloc(f64, count);
                for (0..count) |i| {
                    const bits = std.mem.readInt(u64, array.data[i * 8 ..][0..8], .little);
                    arr_data[i] = @bitCast(bits);
                }
                prop.value = .{ .double_array = arr_data };
            },
            _ => {
                return error.UnknownPropertyType;
            },
        }

        return prop;
    }

    /// Array header parsing result
    const ArrayData = struct {
        count: usize,
        data: []const u8,
    };

    /// Parse array property header
    fn parseArrayHeader(self: *FbxLoader, data: []const u8, offset: *usize) !ArrayData {
        if (data.len < offset.* + 12) return error.UnexpectedEndOfData;

        const count = std.mem.readInt(u32, data[offset.*..][0..4], .little);
        const encoding = std.mem.readInt(u32, data[offset.* + 4 ..][0..4], .little);
        const compressed_len = std.mem.readInt(u32, data[offset.* + 8 ..][0..4], .little);
        offset.* += 12;

        if (data.len < offset.* + compressed_len) return error.UnexpectedEndOfData;

        const array_data = data[offset.* .. offset.* + compressed_len];
        offset.* += compressed_len;

        if (encoding == 1) {
            // Zlib compressed - decompress
            return self.decompressArray(array_data, count);
        }

        return .{
            .count = count,
            .data = array_data,
        };
    }

    /// Decompress zlib-compressed array data
    fn decompressArray(self: *FbxLoader, compressed: []const u8, count: usize) !ArrayData {
        // For now, return error for compressed data
        // Full implementation would use zlib decompression
        _ = self;
        _ = compressed;
        _ = count;
        return error.CompressedDataNotSupported;
    }

    /// Load FBX ASCII format
    fn loadAscii(self: *FbxLoader, data: []const u8) !FbxAsset {
        // Create root node
        const root = try self.allocator.create(FbxNode);
        root.* = FbxNode.init(self.allocator);
        root.name = "Root";

        // Parse ASCII content
        var line_iter = std.mem.splitScalar(u8, data, '\n');
        var node_stack: std.ArrayListUnmanaged(*FbxNode) = .{};
        defer node_stack.deinit(self.allocator);
        try node_stack.append(self.allocator, root);

        while (line_iter.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r");
            if (trimmed.len == 0) continue;
            if (trimmed[0] == ';') continue; // Comment

            // Check for opening brace
            if (std.mem.indexOf(u8, trimmed, "{")) |_| {
                // New node - extract name
                const name_end = std.mem.indexOf(u8, trimmed, ":") orelse
                    std.mem.indexOf(u8, trimmed, " ") orelse
                    std.mem.indexOf(u8, trimmed, "{") orelse
                    trimmed.len;

                const node = try self.allocator.create(FbxNode);
                node.* = FbxNode.init(self.allocator);
                node.name = trimmed[0..name_end];

                if (node_stack.items.len > 0) {
                    const parent = node_stack.items[node_stack.items.len - 1];
                    try parent.children.append(parent.allocator, node);
                }
                try node_stack.append(self.allocator, node);
            } else if (trimmed[0] == '}') {
                // Close node
                if (node_stack.items.len > 1) {
                    _ = node_stack.pop();
                }
            }
        }

        var asset = FbxAsset{
            .allocator = self.allocator,
            .version = 0, // ASCII format doesn't have explicit version
            .root = root,
            .geometries = .{},
            .materials = .{},
            .models = .{},
            .connections = .{},
        };

        try self.extractObjects(&asset);
        try self.extractConnections(&asset);

        return asset;
    }

    /// Extract objects from parsed FBX nodes
    fn extractObjects(self: *FbxLoader, asset: *FbxAsset) !void {
        const objects_node = asset.root.findChild("Objects") orelse return;

        for (objects_node.children.items) |child| {
            if (std.mem.eql(u8, child.name, "Geometry")) {
                try self.extractGeometry(asset, child);
            } else if (std.mem.eql(u8, child.name, "Material")) {
                try self.extractMaterial(asset, child);
            } else if (std.mem.eql(u8, child.name, "Model")) {
                try self.extractModel(asset, child);
            }
        }
    }

    /// Extract geometry from Geometry node
    fn extractGeometry(self: *FbxLoader, asset: *FbxAsset, node: *FbxNode) !void {
        const id = node.getPropertyInt64(0) orelse return;
        const name = node.getPropertyString(1) orelse "";

        var geometry = FbxGeometry{
            .id = id,
            .name = name,
            .vertices = &[_]f64{},
            .polygon_vertex_index = &[_]i32{},
            .normals = null,
            .uvs = null,
            .uv_indices = null,
            .material_ids = null,
        };

        // Find Vertices
        if (node.findChild("Vertices")) |vertices_node| {
            if (vertices_node.getPropertyDoubleArray(0)) |arr| {
                geometry.vertices = arr;
            }
        }

        // Find PolygonVertexIndex
        if (node.findChild("PolygonVertexIndex")) |indices_node| {
            if (indices_node.getPropertyInt32Array(0)) |arr| {
                geometry.polygon_vertex_index = arr;
            }
        }

        // Find normals in LayerElementNormal
        if (node.findChild("LayerElementNormal")) |normal_layer| {
            if (normal_layer.findChild("Normals")) |normals_node| {
                if (normals_node.getPropertyDoubleArray(0)) |arr| {
                    geometry.normals = arr;
                }
            }
        }

        // Find UVs in LayerElementUV
        if (node.findChild("LayerElementUV")) |uv_layer| {
            if (uv_layer.findChild("UV")) |uv_node| {
                if (uv_node.getPropertyDoubleArray(0)) |arr| {
                    geometry.uvs = arr;
                }
            }
            if (uv_layer.findChild("UVIndex")) |uv_index_node| {
                if (uv_index_node.getPropertyInt32Array(0)) |arr| {
                    geometry.uv_indices = arr;
                }
            }
        }

        // Find material IDs in LayerElementMaterial
        if (node.findChild("LayerElementMaterial")) |mat_layer| {
            if (mat_layer.findChild("Materials")) |mat_node| {
                if (mat_node.getPropertyInt32Array(0)) |arr| {
                    geometry.material_ids = arr;
                }
            }
        }

        try asset.geometries.append(asset.allocator, geometry);
        _ = self;
    }

    /// Extract material from Material node
    fn extractMaterial(self: *FbxLoader, asset: *FbxAsset, node: *FbxNode) !void {
        const id = node.getPropertyInt64(0) orelse return;
        const name = node.getPropertyString(1) orelse "";

        var material = FbxMaterial{
            .id = id,
            .name = name,
            .diffuse_color = Color.white(),
            .specular_color = Color.white(),
            .ambient_color = Color.init(0.2, 0.2, 0.2, 1.0),
            .emissive_color = Color.black(),
            .shininess = 32.0,
            .opacity = 1.0,
            .diffuse_texture = null,
            .normal_texture = null,
        };

        // Extract properties from Properties70 node
        if (node.findChild("Properties70")) |props| {
            for (props.children.items) |prop_node| {
                if (std.mem.eql(u8, prop_node.name, "P")) {
                    const prop_name = prop_node.getPropertyString(0) orelse continue;

                    if (std.mem.eql(u8, prop_name, "DiffuseColor")) {
                        if (prop_node.properties.items.len >= 7) {
                            material.diffuse_color = self.extractColor(prop_node, 4);
                        }
                    } else if (std.mem.eql(u8, prop_name, "SpecularColor")) {
                        if (prop_node.properties.items.len >= 7) {
                            material.specular_color = self.extractColor(prop_node, 4);
                        }
                    } else if (std.mem.eql(u8, prop_name, "AmbientColor")) {
                        if (prop_node.properties.items.len >= 7) {
                            material.ambient_color = self.extractColor(prop_node, 4);
                        }
                    } else if (std.mem.eql(u8, prop_name, "EmissiveColor")) {
                        if (prop_node.properties.items.len >= 7) {
                            material.emissive_color = self.extractColor(prop_node, 4);
                        }
                    } else if (std.mem.eql(u8, prop_name, "Shininess")) {
                        if (prop_node.properties.items.len >= 5) {
                            material.shininess = self.extractFloat(prop_node, 4);
                        }
                    } else if (std.mem.eql(u8, prop_name, "Opacity")) {
                        if (prop_node.properties.items.len >= 5) {
                            material.opacity = self.extractFloat(prop_node, 4);
                        }
                    }
                }
            }
        }

        try asset.materials.append(asset.allocator, material);
    }

    /// Extract color from property node
    fn extractColor(self: *FbxLoader, node: *FbxNode, start_index: usize) Color {
        _ = self;
        var r: f32 = 1.0;
        var g: f32 = 1.0;
        var b: f32 = 1.0;

        if (node.properties.items.len > start_index) {
            switch (node.properties.items[start_index].value) {
                .double_val => |v| r = @floatCast(v),
                .float_val => |v| r = v,
                else => {},
            }
        }
        if (node.properties.items.len > start_index + 1) {
            switch (node.properties.items[start_index + 1].value) {
                .double_val => |v| g = @floatCast(v),
                .float_val => |v| g = v,
                else => {},
            }
        }
        if (node.properties.items.len > start_index + 2) {
            switch (node.properties.items[start_index + 2].value) {
                .double_val => |v| b = @floatCast(v),
                .float_val => |v| b = v,
                else => {},
            }
        }

        return Color.init(r, g, b, 1.0);
    }

    /// Extract float from property node
    fn extractFloat(self: *FbxLoader, node: *FbxNode, index: usize) f32 {
        _ = self;
        if (node.properties.items.len > index) {
            switch (node.properties.items[index].value) {
                .double_val => |v| return @floatCast(v),
                .float_val => |v| return v,
                else => {},
            }
        }
        return 0.0;
    }

    /// Extract model from Model node
    fn extractModel(self: *FbxLoader, asset: *FbxAsset, node: *FbxNode) !void {
        const id = node.getPropertyInt64(0) orelse return;
        const name = node.getPropertyString(1) orelse "";
        const model_type = node.getPropertyString(2) orelse "Null";

        var model = FbxModel{
            .id = id,
            .name = name,
            .model_type = model_type,
        };

        // Extract transform from Properties70
        if (node.findChild("Properties70")) |props| {
            for (props.children.items) |prop_node| {
                if (std.mem.eql(u8, prop_node.name, "P")) {
                    const prop_name = prop_node.getPropertyString(0) orelse continue;

                    if (std.mem.eql(u8, prop_name, "Lcl Translation")) {
                        model.translation = self.extractVec3(prop_node, 4);
                    } else if (std.mem.eql(u8, prop_name, "Lcl Rotation")) {
                        model.rotation = self.extractVec3(prop_node, 4);
                    } else if (std.mem.eql(u8, prop_name, "Lcl Scaling")) {
                        model.scaling = self.extractVec3(prop_node, 4);
                    }
                }
            }
        }

        try asset.models.append(asset.allocator, model);
    }

    /// Extract Vec3 from property node
    fn extractVec3(self: *FbxLoader, node: *FbxNode, start_index: usize) Vec3 {
        _ = self;
        var x: f32 = 0.0;
        var y: f32 = 0.0;
        var z: f32 = 0.0;

        if (node.properties.items.len > start_index) {
            switch (node.properties.items[start_index].value) {
                .double_val => |v| x = @floatCast(v),
                .float_val => |v| x = v,
                else => {},
            }
        }
        if (node.properties.items.len > start_index + 1) {
            switch (node.properties.items[start_index + 1].value) {
                .double_val => |v| y = @floatCast(v),
                .float_val => |v| y = v,
                else => {},
            }
        }
        if (node.properties.items.len > start_index + 2) {
            switch (node.properties.items[start_index + 2].value) {
                .double_val => |v| z = @floatCast(v),
                .float_val => |v| z = v,
                else => {},
            }
        }

        return Vec3.init(x, y, z);
    }

    /// Extract connections from Connections section
    fn extractConnections(self: *FbxLoader, asset: *FbxAsset) !void {
        const connections_node = asset.root.findChild("Connections") orelse return;

        for (connections_node.children.items) |child| {
            if (std.mem.eql(u8, child.name, "C")) {
                const conn_type_str = child.getPropertyString(0) orelse continue;
                const child_id = child.getPropertyInt64(1) orelse continue;
                const parent_id = child.getPropertyInt64(2) orelse continue;

                var conn = FbxConnection{
                    .connection_type = .object_object,
                    .child_id = child_id,
                    .parent_id = parent_id,
                    .property_name = null,
                };

                if (std.mem.eql(u8, conn_type_str, "OP")) {
                    conn.connection_type = .object_property;
                    conn.property_name = child.getPropertyString(3);
                }

                try asset.connections.append(asset.allocator, conn);

                // Update model connections
                for (asset.models.items) |*model| {
                    if (model.id == parent_id) {
                        // Check if child is geometry
                        for (asset.geometries.items) |geom| {
                            if (geom.id == child_id) {
                                model.geometry_id = child_id;
                                break;
                            }
                        }
                        // Check if child is material
                        for (asset.materials.items) |mat| {
                            if (mat.id == child_id) {
                                try model.material_ids.append(asset.allocator, child_id);
                                break;
                            }
                        }
                    }
                }
            }
        }
        _ = self;
    }

    /// Convert FBX geometry to Zylix Mesh
    pub fn toMesh(self: *FbxLoader, asset: *const FbxAsset, geometry_index: usize) !Mesh {
        if (geometry_index >= asset.geometries.items.len) {
            return error.InvalidGeometryIndex;
        }

        const geom = asset.geometries.items[geometry_index];

        var mesh = Mesh.init(self.allocator);
        errdefer mesh.deinit();

        // Convert polygon indices to triangles
        var poly_start: usize = 0;
        var vertex_idx: usize = 0;

        for (geom.polygon_vertex_index) |idx| {
            const is_last = idx < 0;
            const actual_idx: usize = if (is_last)
                @intCast(~idx)
            else
                @intCast(idx);

            // Get vertex position
            const vx: f32 = @floatCast(geom.vertices[actual_idx * 3]);
            const vy: f32 = @floatCast(geom.vertices[actual_idx * 3 + 1]);
            const vz: f32 = @floatCast(geom.vertices[actual_idx * 3 + 2]);

            // Get normal if available
            var nx: f32 = 0.0;
            var ny: f32 = 1.0;
            var nz: f32 = 0.0;
            if (geom.normals) |normals| {
                if (vertex_idx * 3 + 2 < normals.len) {
                    nx = @floatCast(normals[vertex_idx * 3]);
                    ny = @floatCast(normals[vertex_idx * 3 + 1]);
                    nz = @floatCast(normals[vertex_idx * 3 + 2]);
                }
            }

            // Get UV if available
            var u: f32 = 0.0;
            var v: f32 = 0.0;
            if (geom.uvs) |uvs| {
                if (geom.uv_indices) |uv_indices| {
                    if (vertex_idx < uv_indices.len) {
                        const uv_idx: usize = @intCast(uv_indices[vertex_idx]);
                        if (uv_idx * 2 + 1 < uvs.len) {
                            u = @floatCast(uvs[uv_idx * 2]);
                            v = @floatCast(uvs[uv_idx * 2 + 1]);
                        }
                    }
                } else if (vertex_idx * 2 + 1 < uvs.len) {
                    u = @floatCast(uvs[vertex_idx * 2]);
                    v = @floatCast(uvs[vertex_idx * 2 + 1]);
                }
            }

            try mesh.addVertex(vx, vy, vz, nx, ny, nz, u, v);
            vertex_idx += 1;

            if (is_last) {
                // Triangulate polygon
                const poly_size = vertex_idx - poly_start;
                if (poly_size >= 3) {
                    // Fan triangulation
                    for (1..poly_size - 1) |i| {
                        try mesh.addIndex(@intCast(poly_start));
                        try mesh.addIndex(@intCast(poly_start + i));
                        try mesh.addIndex(@intCast(poly_start + i + 1));
                    }
                }
                poly_start = vertex_idx;
            }
        }

        try mesh.calculateBounds();

        return mesh;
    }

    /// Convert FBX material to Zylix Material
    pub fn toMaterial(self: *FbxLoader, asset: *const FbxAsset, material_index: usize) !Material {
        if (material_index >= asset.materials.items.len) {
            return error.InvalidMaterialIndex;
        }

        const fbx_mat = asset.materials.items[material_index];

        var mat = Material.init(self.allocator);
        mat.name = fbx_mat.name;
        mat.base_color = fbx_mat.diffuse_color;

        // Convert shininess to roughness (inverse relationship)
        mat.roughness = 1.0 - @min(fbx_mat.shininess / 100.0, 1.0);

        // Use specular intensity for metallic approximation
        const spec_intensity = (fbx_mat.specular_color.r + fbx_mat.specular_color.g + fbx_mat.specular_color.b) / 3.0;
        mat.metallic = spec_intensity;

        mat.emission_color = fbx_mat.emissive_color;

        return mat;
    }

    /// Find geometry by ID
    pub fn findGeometry(self: *FbxLoader, asset: *const FbxAsset, id: i64) ?usize {
        _ = self;
        for (asset.geometries.items, 0..) |geom, i| {
            if (geom.id == id) return i;
        }
        return null;
    }

    /// Find material by ID
    pub fn findMaterial(self: *FbxLoader, asset: *const FbxAsset, id: i64) ?usize {
        _ = self;
        for (asset.materials.items, 0..) |mat, i| {
            if (mat.id == id) return i;
        }
        return null;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "FbxLoader initialization" {
    const allocator = std.testing.allocator;
    const loader = FbxLoader.init(allocator);
    _ = loader;
}

test "FbxNode operations" {
    const allocator = std.testing.allocator;

    var node = FbxNode.init(allocator);
    defer node.deinit();

    node.name = "TestNode";

    // Add child node
    const child = try allocator.create(FbxNode);
    child.* = FbxNode.init(allocator);
    child.name = "ChildNode";
    try node.children.append(allocator, child);

    // Find child
    const found = node.findChild("ChildNode");
    try std.testing.expect(found != null);
    try std.testing.expectEqualStrings("ChildNode", found.?.name);

    // Find non-existent
    const not_found = node.findChild("NonExistent");
    try std.testing.expect(not_found == null);
}

test "PropertyType enum" {
    try std.testing.expectEqual(@as(u8, 'C'), @intFromEnum(PropertyType.bool_type));
    try std.testing.expectEqual(@as(u8, 'I'), @intFromEnum(PropertyType.int32_type));
    try std.testing.expectEqual(@as(u8, 'L'), @intFromEnum(PropertyType.int64_type));
    try std.testing.expectEqual(@as(u8, 'F'), @intFromEnum(PropertyType.float_type));
    try std.testing.expectEqual(@as(u8, 'D'), @intFromEnum(PropertyType.double_type));
    try std.testing.expectEqual(@as(u8, 'S'), @intFromEnum(PropertyType.string_type));
}
