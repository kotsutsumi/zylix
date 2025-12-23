//! Zylix 3D Graphics - Material System
//!
//! PBR materials, textures, and shaders.

const std = @import("std");
const types = @import("types.zig");

const Vec2 = types.Vec2;
const Vec3 = types.Vec3;
const Vec4 = types.Vec4;
const Color = types.Color;

// ============================================================================
// Texture Types
// ============================================================================

/// Texture wrap mode
pub const WrapMode = enum {
    repeat,
    clamp,
    mirror,
    border,
};

/// Texture filter mode
pub const FilterMode = enum {
    nearest,
    linear,
    nearest_mipmap_nearest,
    linear_mipmap_nearest,
    nearest_mipmap_linear,
    linear_mipmap_linear,
};

/// Texture format
pub const TextureFormat = enum {
    r8,
    rg8,
    rgb8,
    rgba8,
    r16f,
    rg16f,
    rgb16f,
    rgba16f,
    r32f,
    rg32f,
    rgb32f,
    rgba32f,
    depth16,
    depth24,
    depth32f,
    depth24_stencil8,
};

/// Texture type
pub const TextureType = enum {
    texture_2d,
    texture_3d,
    texture_cube,
    texture_2d_array,
};

// ============================================================================
// Texture
// ============================================================================

/// 2D texture
pub const Texture2D = struct {
    width: u32 = 0,
    height: u32 = 0,
    format: TextureFormat = .rgba8,

    wrap_u: WrapMode = .repeat,
    wrap_v: WrapMode = .repeat,
    filter_min: FilterMode = .linear_mipmap_linear,
    filter_mag: FilterMode = .linear,

    generate_mipmaps: bool = true,
    anisotropy: f32 = 1.0,

    // CPU data (for upload to GPU)
    data: ?[]u8 = null,
    allocator: ?std.mem.Allocator = null,

    // GPU state
    gpu_handle: u64 = 0,
    gpu_dirty: bool = true,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32, format: TextureFormat) !Texture2D {
        const bytes_per_pixel: usize = switch (format) {
            .r8 => 1,
            .rg8 => 2,
            .rgb8 => 3,
            .rgba8 => 4,
            .r16f => 2,
            .rg16f => 4,
            .rgb16f => 6,
            .rgba16f => 8,
            .r32f => 4,
            .rg32f => 8,
            .rgb32f => 12,
            .rgba32f => 16,
            else => 4,
        };

        const data_size = @as(usize, width) * @as(usize, height) * bytes_per_pixel;
        const data = try allocator.alloc(u8, data_size);

        return .{
            .width = width,
            .height = height,
            .format = format,
            .data = data,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Texture2D) void {
        if (self.data) |data| {
            if (self.allocator) |allocator| {
                allocator.free(data);
            }
        }
        self.data = null;
    }

    pub fn setPixel(self: *Texture2D, x: u32, y: u32, color: Color) void {
        if (self.data == null or x >= self.width or y >= self.height) return;

        const idx = (y * self.width + x) * 4;
        self.data.?[idx] = @intFromFloat(color.r * 255);
        self.data.?[idx + 1] = @intFromFloat(color.g * 255);
        self.data.?[idx + 2] = @intFromFloat(color.b * 255);
        self.data.?[idx + 3] = @intFromFloat(color.a * 255);
        self.gpu_dirty = true;
    }

    pub fn getPixel(self: *const Texture2D, x: u32, y: u32) Color {
        if (self.data == null or x >= self.width or y >= self.height) return Color.black();

        const idx = (y * self.width + x) * 4;
        return Color.rgba(
            @as(f32, @floatFromInt(self.data.?[idx])) / 255.0,
            @as(f32, @floatFromInt(self.data.?[idx + 1])) / 255.0,
            @as(f32, @floatFromInt(self.data.?[idx + 2])) / 255.0,
            @as(f32, @floatFromInt(self.data.?[idx + 3])) / 255.0,
        );
    }

    /// Create a solid color texture
    pub fn createSolid(allocator: std.mem.Allocator, color: Color) !Texture2D {
        var tex = try init(allocator, 1, 1, .rgba8);
        tex.setPixel(0, 0, color);
        return tex;
    }

    /// Create a checkerboard texture
    pub fn createCheckerboard(allocator: std.mem.Allocator, size: u32, color1: Color, color2: Color) !Texture2D {
        var tex = try init(allocator, size, size, .rgba8);

        var y: u32 = 0;
        while (y < size) : (y += 1) {
            var x: u32 = 0;
            while (x < size) : (x += 1) {
                const checker = ((x / 4) + (y / 4)) % 2 == 0;
                tex.setPixel(x, y, if (checker) color1 else color2);
            }
        }

        return tex;
    }
};

/// Cubemap texture
pub const TextureCube = struct {
    size: u32 = 0,
    format: TextureFormat = .rgba8,

    filter_min: FilterMode = .linear,
    filter_mag: FilterMode = .linear,

    // Face data (6 faces: +X, -X, +Y, -Y, +Z, -Z)
    faces: [6]?[]u8 = [_]?[]u8{null} ** 6,
    allocator: ?std.mem.Allocator = null,

    gpu_handle: u64 = 0,
    gpu_dirty: bool = true,

    pub const Face = enum(usize) {
        positive_x = 0,
        negative_x = 1,
        positive_y = 2,
        negative_y = 3,
        positive_z = 4,
        negative_z = 5,
    };

    pub fn init(allocator: std.mem.Allocator, size: u32, format: TextureFormat) !TextureCube {
        var cube = TextureCube{
            .size = size,
            .format = format,
            .allocator = allocator,
        };

        const bytes_per_pixel: usize = 4; // Assuming RGBA8
        const face_size = @as(usize, size) * @as(usize, size) * bytes_per_pixel;

        for (&cube.faces) |*face| {
            face.* = try allocator.alloc(u8, face_size);
        }

        return cube;
    }

    pub fn deinit(self: *TextureCube) void {
        if (self.allocator) |allocator| {
            for (&self.faces) |*face| {
                if (face.*) |data| {
                    allocator.free(data);
                    face.* = null;
                }
            }
        }
    }
};

// ============================================================================
// Shader
// ============================================================================

/// Shader stage
pub const ShaderStage = enum {
    vertex,
    fragment,
    geometry,
    compute,
};

/// Shader uniform type
pub const UniformType = enum {
    float,
    vec2,
    vec3,
    vec4,
    mat3,
    mat4,
    int,
    ivec2,
    ivec3,
    ivec4,
    sampler2d,
    sampler_cube,
};

/// Shader uniform definition
pub const UniformDef = struct {
    name: []const u8,
    uniform_type: UniformType,
    array_size: u32 = 1,
};

/// Shader program
pub const Shader = struct {
    name: []const u8 = "Unnamed",

    vertex_source: ?[]const u8 = null,
    fragment_source: ?[]const u8 = null,

    uniforms: std.ArrayList(UniformDef),
    allocator: std.mem.Allocator,

    gpu_handle: u64 = 0,
    gpu_dirty: bool = true,

    pub fn init(allocator: std.mem.Allocator) Shader {
        return .{
            .uniforms = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Shader) void {
        self.uniforms.deinit(self.allocator);
    }

    pub fn addUniform(self: *Shader, name: []const u8, uniform_type: UniformType) !void {
        try self.uniforms.append(self.allocator, .{
            .name = name,
            .uniform_type = uniform_type,
        });
    }
};

// ============================================================================
// Material
// ============================================================================

/// Blend mode for rendering
pub const BlendMode = enum {
    @"opaque",
    alpha_blend,
    additive,
    multiply,
    premultiplied,
};

/// Cull mode
pub const CullMode = enum {
    none,
    front,
    back,
};

/// Compare function for depth/stencil
pub const CompareFunc = enum {
    never,
    less,
    equal,
    less_equal,
    greater,
    not_equal,
    greater_equal,
    always,
};

/// PBR Material
pub const Material = struct {
    name: []const u8 = "Unnamed",

    // Base color
    albedo: Color = Color.white(),
    albedo_texture: ?*Texture2D = null,

    // PBR properties
    metallic: f32 = 0.0,
    metallic_texture: ?*Texture2D = null,

    roughness: f32 = 0.5,
    roughness_texture: ?*Texture2D = null,

    // Normal mapping
    normal_texture: ?*Texture2D = null,
    normal_scale: f32 = 1.0,

    // Ambient occlusion
    ao_texture: ?*Texture2D = null,
    ao_strength: f32 = 1.0,

    // Emission
    emission: Color = Color.black(),
    emission_texture: ?*Texture2D = null,
    emission_strength: f32 = 1.0,

    // Height/parallax mapping
    height_texture: ?*Texture2D = null,
    height_scale: f32 = 0.05,

    // Render settings
    blend_mode: BlendMode = .@"opaque",
    cull_mode: CullMode = .back,
    depth_write: bool = true,
    depth_test: bool = true,
    depth_func: CompareFunc = .less,

    // Custom shader (null = use default PBR)
    shader: ?*Shader = null,

    // Render queue priority
    render_queue: i32 = 2000, // 1000=Background, 2000=Geometry, 3000=Transparent, 4000=Overlay

    // UV tiling/offset
    uv_tiling: Vec2 = Vec2.init(1, 1),
    uv_offset: Vec2 = Vec2.zero(),

    pub fn init() Material {
        return .{};
    }

    /// Create a basic unlit material
    pub fn unlit(color: Color) Material {
        return .{
            .albedo = color,
            .metallic = 0,
            .roughness = 1,
            .emission = color,
        };
    }

    /// Create a standard PBR material
    pub fn pbr(albedo: Color, metallic: f32, roughness: f32) Material {
        return .{
            .albedo = albedo,
            .metallic = metallic,
            .roughness = roughness,
        };
    }

    /// Check if material is transparent
    pub fn isTransparent(self: *const Material) bool {
        return self.blend_mode != .@"opaque" or self.albedo.a < 1.0;
    }
};

// ============================================================================
// Material Library
// ============================================================================

/// Pre-defined materials
pub const MaterialLibrary = struct {

    /// Default white material
    pub fn defaultWhite() Material {
        return Material.pbr(Color.white(), 0.0, 0.5);
    }

    /// Default material for missing textures
    pub fn defaultError() Material {
        return Material.pbr(Color.magenta(), 0.0, 1.0);
    }

    /// Metallic material (chrome-like)
    pub fn metal() Material {
        return Material.pbr(Color.rgb(0.9, 0.9, 0.9), 1.0, 0.2);
    }

    /// Plastic material
    pub fn plastic(color: Color) Material {
        return Material.pbr(color, 0.0, 0.4);
    }

    /// Rubber material
    pub fn rubber(color: Color) Material {
        return Material.pbr(color, 0.0, 0.9);
    }

    /// Glass material
    pub fn glass() Material {
        var mat = Material.pbr(Color.rgba(1, 1, 1, 0.1), 0.0, 0.0);
        mat.blend_mode = .alpha_blend;
        mat.render_queue = 3000;
        return mat;
    }

    /// Wood material
    pub fn wood() Material {
        return Material.pbr(Color.fromHex(0x8B4513), 0.0, 0.6);
    }

    /// Concrete material
    pub fn concrete() Material {
        return Material.pbr(Color.rgb(0.5, 0.5, 0.5), 0.0, 0.9);
    }

    /// Gold material
    pub fn gold() Material {
        return Material.pbr(Color.fromHex(0xFFD700), 1.0, 0.3);
    }

    /// Silver material
    pub fn silver() Material {
        return Material.pbr(Color.rgb(0.95, 0.93, 0.88), 1.0, 0.2);
    }

    /// Copper material
    pub fn copper() Material {
        return Material.pbr(Color.fromHex(0xB87333), 1.0, 0.4);
    }

    /// Wireframe material for debugging
    pub fn wireframe(color: Color) Material {
        var mat = Material.unlit(color);
        mat.cull_mode = .none;
        return mat;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Texture2D creation" {
    const allocator = std.testing.allocator;

    var tex = try Texture2D.init(allocator, 64, 64, .rgba8);
    defer tex.deinit();

    try std.testing.expect(tex.width == 64);
    try std.testing.expect(tex.height == 64);
    try std.testing.expect(tex.data != null);
}

test "Texture2D pixel operations" {
    const allocator = std.testing.allocator;

    var tex = try Texture2D.init(allocator, 2, 2, .rgba8);
    defer tex.deinit();

    tex.setPixel(0, 0, Color.red());
    tex.setPixel(1, 0, Color.green());
    tex.setPixel(0, 1, Color.blue());
    tex.setPixel(1, 1, Color.white());

    const pixel = tex.getPixel(0, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 1), pixel.r, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0), pixel.g, 0.01);
}

test "Material creation" {
    const mat = Material.pbr(Color.red(), 0.5, 0.3);

    try std.testing.expect(mat.metallic == 0.5);
    try std.testing.expect(mat.roughness == 0.3);
    try std.testing.expect(!mat.isTransparent());
}

test "Material library" {
    const gold = MaterialLibrary.gold();
    try std.testing.expect(gold.metallic == 1.0);

    const glass = MaterialLibrary.glass();
    try std.testing.expect(glass.isTransparent());
}
