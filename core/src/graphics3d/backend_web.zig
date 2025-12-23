//! Zylix Web Graphics Backend
//!
//! Web graphics backend supporting WebGL2 and WebGPU APIs.
//! Provides cross-browser GPU access for web applications.
//!
//! ## Features
//! - **WebGL2**: Full WebGL 2.0 support for wide browser compatibility
//! - **WebGPU**: Modern WebGPU API for newer browsers
//! - **Automatic Detection**: Falls back to WebGL2 if WebGPU unavailable
//! - **Resource Management**: Buffers, textures, shaders, framebuffers
//! - **State Tracking**: Efficient state management to reduce API calls
//!
//! ## Browser Support
//! - WebGL2: Chrome 56+, Firefox 51+, Safari 15+, Edge 79+
//! - WebGPU: Chrome 113+, Firefox (Nightly), Safari 17+
//!
//! ## Example
//! ```zig
//! const web = @import("backend_web.zig");
//!
//! // Create web backend (auto-detects WebGPU/WebGL2)
//! var backend = try web.WebBackend.init(allocator, .auto);
//! defer backend.deinit();
//!
//! // Create shader program
//! const shader = try backend.createShaderProgram(vertex_src, fragment_src);
//!
//! // Create vertex buffer
//! const vbo = try backend.createBuffer(.vertex, &vertices);
//!
//! // Render
//! backend.useProgram(shader);
//! backend.bindVertexBuffer(vbo);
//! backend.drawArrays(.triangles, 0, 36);
//! ```

const std = @import("std");
const types = @import("types.zig");
const Vec2 = types.Vec2;
const Vec3 = types.Vec3;
const Vec4 = types.Vec4;
const Mat4 = types.Mat4;
const Color = types.Color;

// ============================================================================
// Web API Type Definitions
// ============================================================================

/// Backend API type
pub const BackendAPI = enum {
    auto,
    webgl2,
    webgpu,
};

/// WebGL constant type (GLEnum)
pub const GLenum = u32;

/// WebGL integer type
pub const GLint = i32;

/// WebGL unsigned integer type
pub const GLuint = u32;

/// WebGL float type
pub const GLfloat = f32;

/// WebGL size type
pub const GLsizei = i32;

/// WebGL boolean type
pub const GLboolean = u8;

// ============================================================================
// WebGL2 Constants
// ============================================================================

pub const GL = struct {
    // Buffer targets
    pub const ARRAY_BUFFER: GLenum = 0x8892;
    pub const ELEMENT_ARRAY_BUFFER: GLenum = 0x8893;
    pub const UNIFORM_BUFFER: GLenum = 0x8A11;
    pub const TRANSFORM_FEEDBACK_BUFFER: GLenum = 0x8C8E;
    pub const COPY_READ_BUFFER: GLenum = 0x8F36;
    pub const COPY_WRITE_BUFFER: GLenum = 0x8F37;
    pub const PIXEL_PACK_BUFFER: GLenum = 0x88EB;
    pub const PIXEL_UNPACK_BUFFER: GLenum = 0x88EC;

    // Buffer usage
    pub const STATIC_DRAW: GLenum = 0x88E4;
    pub const DYNAMIC_DRAW: GLenum = 0x88E8;
    pub const STREAM_DRAW: GLenum = 0x88E0;
    pub const STATIC_READ: GLenum = 0x88E5;
    pub const DYNAMIC_READ: GLenum = 0x88E9;
    pub const STREAM_READ: GLenum = 0x88E1;
    pub const STATIC_COPY: GLenum = 0x88E6;
    pub const DYNAMIC_COPY: GLenum = 0x88EA;
    pub const STREAM_COPY: GLenum = 0x88E2;

    // Primitive types
    pub const POINTS: GLenum = 0x0000;
    pub const LINES: GLenum = 0x0001;
    pub const LINE_LOOP: GLenum = 0x0002;
    pub const LINE_STRIP: GLenum = 0x0003;
    pub const TRIANGLES: GLenum = 0x0004;
    pub const TRIANGLE_STRIP: GLenum = 0x0005;
    pub const TRIANGLE_FAN: GLenum = 0x0006;

    // Data types
    pub const BYTE: GLenum = 0x1400;
    pub const UNSIGNED_BYTE: GLenum = 0x1401;
    pub const SHORT: GLenum = 0x1402;
    pub const UNSIGNED_SHORT: GLenum = 0x1403;
    pub const INT: GLenum = 0x1404;
    pub const UNSIGNED_INT: GLenum = 0x1405;
    pub const FLOAT: GLenum = 0x1406;
    pub const HALF_FLOAT: GLenum = 0x140B;

    // Texture targets
    pub const TEXTURE_2D: GLenum = 0x0DE1;
    pub const TEXTURE_CUBE_MAP: GLenum = 0x8513;
    pub const TEXTURE_3D: GLenum = 0x806F;
    pub const TEXTURE_2D_ARRAY: GLenum = 0x8C1A;

    // Texture parameters
    pub const TEXTURE_MIN_FILTER: GLenum = 0x2801;
    pub const TEXTURE_MAG_FILTER: GLenum = 0x2800;
    pub const TEXTURE_WRAP_S: GLenum = 0x2802;
    pub const TEXTURE_WRAP_T: GLenum = 0x2803;
    pub const TEXTURE_WRAP_R: GLenum = 0x8072;
    pub const TEXTURE_MAX_ANISOTROPY: GLenum = 0x84FE;

    // Filter modes
    pub const NEAREST: GLenum = 0x2600;
    pub const LINEAR: GLenum = 0x2601;
    pub const NEAREST_MIPMAP_NEAREST: GLenum = 0x2700;
    pub const LINEAR_MIPMAP_NEAREST: GLenum = 0x2701;
    pub const NEAREST_MIPMAP_LINEAR: GLenum = 0x2702;
    pub const LINEAR_MIPMAP_LINEAR: GLenum = 0x2703;

    // Wrap modes
    pub const REPEAT: GLenum = 0x2901;
    pub const CLAMP_TO_EDGE: GLenum = 0x812F;
    pub const MIRRORED_REPEAT: GLenum = 0x8370;

    // Pixel formats
    pub const RED: GLenum = 0x1903;
    pub const RG: GLenum = 0x8227;
    pub const RGB: GLenum = 0x1907;
    pub const RGBA: GLenum = 0x1908;
    pub const DEPTH_COMPONENT: GLenum = 0x1902;
    pub const DEPTH_STENCIL: GLenum = 0x84F9;

    // Internal formats
    pub const R8: GLenum = 0x8229;
    pub const R16F: GLenum = 0x822D;
    pub const R32F: GLenum = 0x822E;
    pub const RG8: GLenum = 0x822B;
    pub const RG16F: GLenum = 0x822F;
    pub const RG32F: GLenum = 0x8230;
    pub const RGB8: GLenum = 0x8051;
    pub const RGB16F: GLenum = 0x881B;
    pub const RGB32F: GLenum = 0x8815;
    pub const RGBA8: GLenum = 0x8058;
    pub const RGBA16F: GLenum = 0x881A;
    pub const RGBA32F: GLenum = 0x8814;
    pub const SRGB8: GLenum = 0x8C41;
    pub const SRGB8_ALPHA8: GLenum = 0x8C43;
    pub const DEPTH_COMPONENT16: GLenum = 0x81A5;
    pub const DEPTH_COMPONENT24: GLenum = 0x81A6;
    pub const DEPTH_COMPONENT32F: GLenum = 0x8CAC;
    pub const DEPTH24_STENCIL8: GLenum = 0x88F0;
    pub const DEPTH32F_STENCIL8: GLenum = 0x8CAD;

    // Shader types
    pub const VERTEX_SHADER: GLenum = 0x8B31;
    pub const FRAGMENT_SHADER: GLenum = 0x8B30;

    // Shader parameters
    pub const COMPILE_STATUS: GLenum = 0x8B81;
    pub const LINK_STATUS: GLenum = 0x8B82;

    // Enable/Disable caps
    pub const BLEND: GLenum = 0x0BE2;
    pub const CULL_FACE: GLenum = 0x0B44;
    pub const DEPTH_TEST: GLenum = 0x0B71;
    pub const SCISSOR_TEST: GLenum = 0x0C11;
    pub const STENCIL_TEST: GLenum = 0x0B90;
    pub const DITHER: GLenum = 0x0BD0;
    pub const POLYGON_OFFSET_FILL: GLenum = 0x8037;
    pub const SAMPLE_COVERAGE: GLenum = 0x80A0;

    // Blend functions
    pub const ZERO: GLenum = 0;
    pub const ONE: GLenum = 1;
    pub const SRC_COLOR: GLenum = 0x0300;
    pub const ONE_MINUS_SRC_COLOR: GLenum = 0x0301;
    pub const DST_COLOR: GLenum = 0x0306;
    pub const ONE_MINUS_DST_COLOR: GLenum = 0x0307;
    pub const SRC_ALPHA: GLenum = 0x0302;
    pub const ONE_MINUS_SRC_ALPHA: GLenum = 0x0303;
    pub const DST_ALPHA: GLenum = 0x0304;
    pub const ONE_MINUS_DST_ALPHA: GLenum = 0x0305;
    pub const SRC_ALPHA_SATURATE: GLenum = 0x0308;

    // Blend equations
    pub const FUNC_ADD: GLenum = 0x8006;
    pub const FUNC_SUBTRACT: GLenum = 0x800A;
    pub const FUNC_REVERSE_SUBTRACT: GLenum = 0x800B;
    pub const MIN: GLenum = 0x8007;
    pub const MAX: GLenum = 0x8008;

    // Depth functions
    pub const NEVER: GLenum = 0x0200;
    pub const LESS: GLenum = 0x0201;
    pub const EQUAL: GLenum = 0x0202;
    pub const LEQUAL: GLenum = 0x0203;
    pub const GREATER: GLenum = 0x0204;
    pub const NOTEQUAL: GLenum = 0x0205;
    pub const GEQUAL: GLenum = 0x0206;
    pub const ALWAYS: GLenum = 0x0207;

    // Cull face modes
    pub const FRONT: GLenum = 0x0404;
    pub const BACK: GLenum = 0x0405;
    pub const FRONT_AND_BACK: GLenum = 0x0408;

    // Front face direction
    pub const CW: GLenum = 0x0900;
    pub const CCW: GLenum = 0x0901;

    // Clear buffer bits
    pub const COLOR_BUFFER_BIT: GLenum = 0x00004000;
    pub const DEPTH_BUFFER_BIT: GLenum = 0x00000100;
    pub const STENCIL_BUFFER_BIT: GLenum = 0x00000400;

    // Framebuffer targets
    pub const FRAMEBUFFER: GLenum = 0x8D40;
    pub const READ_FRAMEBUFFER: GLenum = 0x8CA8;
    pub const DRAW_FRAMEBUFFER: GLenum = 0x8CA9;

    // Framebuffer attachments
    pub const COLOR_ATTACHMENT0: GLenum = 0x8CE0;
    pub const DEPTH_ATTACHMENT: GLenum = 0x8D00;
    pub const STENCIL_ATTACHMENT: GLenum = 0x8D20;
    pub const DEPTH_STENCIL_ATTACHMENT: GLenum = 0x821A;

    // Framebuffer status
    pub const FRAMEBUFFER_COMPLETE: GLenum = 0x8CD5;

    // Renderbuffer
    pub const RENDERBUFFER: GLenum = 0x8D41;
};

// ============================================================================
// Enumerations
// ============================================================================

/// Primitive draw mode
pub const DrawMode = enum(u32) {
    points = GL.POINTS,
    lines = GL.LINES,
    line_loop = GL.LINE_LOOP,
    line_strip = GL.LINE_STRIP,
    triangles = GL.TRIANGLES,
    triangle_strip = GL.TRIANGLE_STRIP,
    triangle_fan = GL.TRIANGLE_FAN,
};

/// Buffer target type
pub const BufferTarget = enum(u32) {
    vertex = GL.ARRAY_BUFFER,
    index = GL.ELEMENT_ARRAY_BUFFER,
    uniform = GL.UNIFORM_BUFFER,
    transform_feedback = GL.TRANSFORM_FEEDBACK_BUFFER,
};

/// Buffer usage hint
pub const BufferUsage = enum(u32) {
    static_draw = GL.STATIC_DRAW,
    dynamic_draw = GL.DYNAMIC_DRAW,
    stream_draw = GL.STREAM_DRAW,
};

/// Texture target
pub const TextureTarget = enum(u32) {
    texture_2d = GL.TEXTURE_2D,
    texture_cube_map = GL.TEXTURE_CUBE_MAP,
    texture_3d = GL.TEXTURE_3D,
    texture_2d_array = GL.TEXTURE_2D_ARRAY,
};

/// Texture format
pub const TextureFormat = enum(u32) {
    r8 = GL.R8,
    r16f = GL.R16F,
    r32f = GL.R32F,
    rg8 = GL.RG8,
    rg16f = GL.RG16F,
    rg32f = GL.RG32F,
    rgb8 = GL.RGB8,
    rgb16f = GL.RGB16F,
    rgb32f = GL.RGB32F,
    rgba8 = GL.RGBA8,
    rgba16f = GL.RGBA16F,
    rgba32f = GL.RGBA32F,
    srgb8 = GL.SRGB8,
    srgb8_alpha8 = GL.SRGB8_ALPHA8,
    depth16 = GL.DEPTH_COMPONENT16,
    depth24 = GL.DEPTH_COMPONENT24,
    depth32f = GL.DEPTH_COMPONENT32F,
    depth24_stencil8 = GL.DEPTH24_STENCIL8,
    depth32f_stencil8 = GL.DEPTH32F_STENCIL8,

    pub fn isDepthFormat(self: TextureFormat) bool {
        return switch (self) {
            .depth16, .depth24, .depth32f, .depth24_stencil8, .depth32f_stencil8 => true,
            else => false,
        };
    }

    pub fn bytesPerPixel(self: TextureFormat) u32 {
        return switch (self) {
            .r8 => 1,
            .rg8, .r16f, .depth16 => 2,
            .rgb8, .srgb8 => 3,
            .rgba8, .srgb8_alpha8, .rg16f, .r32f, .depth24, .depth24_stencil8 => 4,
            .rgb16f => 6,
            .rgba16f, .rg32f, .depth32f, .depth32f_stencil8 => 8,
            .rgb32f => 12,
            .rgba32f => 16,
        };
    }
};

/// Filter mode
pub const FilterMode = enum(u32) {
    nearest = GL.NEAREST,
    linear = GL.LINEAR,
    nearest_mipmap_nearest = GL.NEAREST_MIPMAP_NEAREST,
    linear_mipmap_nearest = GL.LINEAR_MIPMAP_NEAREST,
    nearest_mipmap_linear = GL.NEAREST_MIPMAP_LINEAR,
    linear_mipmap_linear = GL.LINEAR_MIPMAP_LINEAR,
};

/// Wrap mode
pub const WrapMode = enum(u32) {
    repeat = GL.REPEAT,
    clamp_to_edge = GL.CLAMP_TO_EDGE,
    mirrored_repeat = GL.MIRRORED_REPEAT,
};

/// Blend factor
pub const BlendFactor = enum(u32) {
    zero = GL.ZERO,
    one = GL.ONE,
    src_color = GL.SRC_COLOR,
    one_minus_src_color = GL.ONE_MINUS_SRC_COLOR,
    dst_color = GL.DST_COLOR,
    one_minus_dst_color = GL.ONE_MINUS_DST_COLOR,
    src_alpha = GL.SRC_ALPHA,
    one_minus_src_alpha = GL.ONE_MINUS_SRC_ALPHA,
    dst_alpha = GL.DST_ALPHA,
    one_minus_dst_alpha = GL.ONE_MINUS_DST_ALPHA,
    src_alpha_saturate = GL.SRC_ALPHA_SATURATE,
};

/// Blend equation
pub const BlendEquation = enum(u32) {
    add = GL.FUNC_ADD,
    subtract = GL.FUNC_SUBTRACT,
    reverse_subtract = GL.FUNC_REVERSE_SUBTRACT,
    min = GL.MIN,
    max = GL.MAX,
};

/// Depth function
pub const DepthFunc = enum(u32) {
    never = GL.NEVER,
    less = GL.LESS,
    equal = GL.EQUAL,
    lequal = GL.LEQUAL,
    greater = GL.GREATER,
    notequal = GL.NOTEQUAL,
    gequal = GL.GEQUAL,
    always = GL.ALWAYS,
};

/// Cull mode
pub const CullMode = enum(u32) {
    none = 0,
    front = GL.FRONT,
    back = GL.BACK,
    front_and_back = GL.FRONT_AND_BACK,
};

/// Front face winding
pub const FrontFace = enum(u32) {
    clockwise = GL.CW,
    counter_clockwise = GL.CCW,
};

// ============================================================================
// Resource Handles
// ============================================================================

/// Buffer handle
pub const BufferHandle = struct {
    id: u32 = 0,
    target: BufferTarget = .vertex,
    size: usize = 0,

    pub fn isValid(self: BufferHandle) bool {
        return self.id != 0;
    }
};

/// Texture handle
pub const TextureHandle = struct {
    id: u32 = 0,
    target: TextureTarget = .texture_2d,
    width: u32 = 0,
    height: u32 = 0,
    depth: u32 = 1,
    format: TextureFormat = .rgba8,
    mip_levels: u32 = 1,

    pub fn isValid(self: TextureHandle) bool {
        return self.id != 0;
    }
};

/// Shader handle
pub const ShaderHandle = struct {
    id: u32 = 0,

    pub fn isValid(self: ShaderHandle) bool {
        return self.id != 0;
    }
};

/// Program handle
pub const ProgramHandle = struct {
    id: u32 = 0,

    pub fn isValid(self: ProgramHandle) bool {
        return self.id != 0;
    }
};

/// Framebuffer handle
pub const FramebufferHandle = struct {
    id: u32 = 0,
    width: u32 = 0,
    height: u32 = 0,
    color_attachments: u32 = 0,
    has_depth: bool = false,
    has_stencil: bool = false,

    pub fn isValid(self: FramebufferHandle) bool {
        return self.id != 0;
    }
};

/// Renderbuffer handle
pub const RenderbufferHandle = struct {
    id: u32 = 0,
    width: u32 = 0,
    height: u32 = 0,
    format: TextureFormat = .rgba8,

    pub fn isValid(self: RenderbufferHandle) bool {
        return self.id != 0;
    }
};

/// Vertex array object handle
pub const VAOHandle = struct {
    id: u32 = 0,

    pub fn isValid(self: VAOHandle) bool {
        return self.id != 0;
    }
};

/// Sampler handle
pub const SamplerHandle = struct {
    id: u32 = 0,

    pub fn isValid(self: SamplerHandle) bool {
        return self.id != 0;
    }
};

// ============================================================================
// Descriptors
// ============================================================================

/// Texture descriptor
pub const TextureDescriptor = struct {
    target: TextureTarget = .texture_2d,
    format: TextureFormat = .rgba8,
    width: u32 = 1,
    height: u32 = 1,
    depth: u32 = 1,
    mip_levels: u32 = 1,
    samples: u32 = 1,
};

/// Sampler descriptor
pub const SamplerDescriptor = struct {
    min_filter: FilterMode = .linear_mipmap_linear,
    mag_filter: FilterMode = .linear,
    wrap_s: WrapMode = .repeat,
    wrap_t: WrapMode = .repeat,
    wrap_r: WrapMode = .repeat,
    max_anisotropy: f32 = 1.0,
    compare_func: ?DepthFunc = null,
    lod_min: f32 = -1000.0,
    lod_max: f32 = 1000.0,
};

/// Framebuffer descriptor
pub const FramebufferDescriptor = struct {
    width: u32 = 0,
    height: u32 = 0,
    color_format: TextureFormat = .rgba8,
    depth_format: ?TextureFormat = null,
    color_attachment_count: u32 = 1,
    samples: u32 = 1,
};

/// Vertex attribute descriptor
pub const VertexAttribute = struct {
    location: u32 = 0,
    size: u32 = 4,
    data_type: GLenum = GL.FLOAT,
    normalized: bool = false,
    stride: u32 = 0,
    offset: u32 = 0,
};

/// Blend state descriptor
pub const BlendState = struct {
    enabled: bool = false,
    src_rgb: BlendFactor = .one,
    dst_rgb: BlendFactor = .zero,
    src_alpha: BlendFactor = .one,
    dst_alpha: BlendFactor = .zero,
    equation_rgb: BlendEquation = .add,
    equation_alpha: BlendEquation = .add,
    color: [4]f32 = .{ 0, 0, 0, 0 },
};

/// Depth state descriptor
pub const DepthState = struct {
    test_enabled: bool = true,
    write_enabled: bool = true,
    func: DepthFunc = .less,
    range_near: f32 = 0.0,
    range_far: f32 = 1.0,
};

/// Stencil state descriptor
pub const StencilState = struct {
    enabled: bool = false,
    read_mask: u32 = 0xFF,
    write_mask: u32 = 0xFF,
    reference: i32 = 0,
    func_front: DepthFunc = .always,
    func_back: DepthFunc = .always,
};

/// Rasterizer state descriptor
pub const RasterizerState = struct {
    cull_mode: CullMode = .back,
    front_face: FrontFace = .counter_clockwise,
    polygon_offset_enabled: bool = false,
    polygon_offset_factor: f32 = 0.0,
    polygon_offset_units: f32 = 0.0,
    scissor_enabled: bool = false,
};

// ============================================================================
// Device Capabilities
// ============================================================================

/// WebGL2/WebGPU capabilities
pub const DeviceCapabilities = struct {
    /// Active API
    api: BackendAPI = .webgl2,

    /// Renderer string
    renderer: []const u8 = "Unknown",

    /// Vendor string
    vendor: []const u8 = "Unknown",

    /// Maximum texture dimensions
    max_texture_size: u32 = 4096,
    max_texture_size_3d: u32 = 256,
    max_texture_size_cube: u32 = 4096,
    max_array_texture_layers: u32 = 256,

    /// Maximum render targets
    max_color_attachments: u32 = 4,
    max_draw_buffers: u32 = 4,

    /// Maximum samples for MSAA
    max_samples: u32 = 4,

    /// Maximum anisotropic filtering
    max_anisotropy: f32 = 1.0,

    /// Maximum uniform buffer size
    max_uniform_buffer_bindings: u32 = 24,
    max_uniform_block_size: u32 = 16384,

    /// Maximum vertex attributes
    max_vertex_attribs: u32 = 16,

    /// Maximum texture units
    max_texture_image_units: u32 = 16,
    max_combined_texture_image_units: u32 = 32,

    /// Extension support
    supports_anisotropic_filtering: bool = false,
    supports_float_textures: bool = true,
    supports_depth_textures: bool = true,
    supports_instancing: bool = true,
    supports_vao: bool = true,
    supports_transform_feedback: bool = true,
    supports_compute_shaders: bool = false, // WebGL2 doesn't support compute
    supports_storage_buffers: bool = false,

    pub fn default() DeviceCapabilities {
        return .{};
    }
};

// ============================================================================
// Web Backend
// ============================================================================

/// Web graphics backend
pub const WebBackend = struct {
    allocator: std.mem.Allocator,

    /// Active API type
    api: BackendAPI,

    /// Device capabilities
    capabilities: DeviceCapabilities,

    /// Resource ID counters
    next_buffer_id: u32 = 1,
    next_texture_id: u32 = 1,
    next_shader_id: u32 = 1,
    next_program_id: u32 = 1,
    next_framebuffer_id: u32 = 1,
    next_renderbuffer_id: u32 = 1,
    next_vao_id: u32 = 1,
    next_sampler_id: u32 = 1,

    /// Current state
    current_program: ProgramHandle = .{},
    current_vao: VAOHandle = .{},
    current_framebuffer: FramebufferHandle = .{},

    /// Viewport
    viewport: struct {
        x: i32 = 0,
        y: i32 = 0,
        width: i32 = 0,
        height: i32 = 0,
    } = .{},

    /// Statistics
    stats: BackendStats,

    pub fn init(allocator: std.mem.Allocator, preferred_api: BackendAPI) WebBackend {
        const api: BackendAPI = if (preferred_api == .auto) .webgl2 else preferred_api;

        return .{
            .allocator = allocator,
            .api = api,
            .capabilities = DeviceCapabilities.default(),
            .stats = .{},
        };
    }

    pub fn deinit(self: *WebBackend) void {
        _ = self;
    }

    /// Get device capabilities
    pub fn getCapabilities(self: *const WebBackend) DeviceCapabilities {
        return self.capabilities;
    }

    /// Get current API
    pub fn getAPI(self: *const WebBackend) BackendAPI {
        return self.api;
    }

    /// Begin a new frame
    pub fn beginFrame(self: *WebBackend) void {
        self.stats.frame_count += 1;
        self.stats.draw_calls = 0;
        self.stats.triangles = 0;
        self.stats.vertices = 0;
    }

    /// End the current frame
    pub fn endFrame(self: *WebBackend) void {
        _ = self;
    }

    // ========================================================================
    // Buffer Operations
    // ========================================================================

    /// Create a buffer
    pub fn createBuffer(self: *WebBackend, target: BufferTarget, size: usize, usage: BufferUsage) BufferHandle {
        _ = usage;
        const id = self.next_buffer_id;
        self.next_buffer_id += 1;
        self.stats.buffers_created += 1;
        self.stats.buffer_memory += size;

        return .{
            .id = id,
            .target = target,
            .size = size,
        };
    }

    /// Create a buffer with initial data
    pub fn createBufferWithData(self: *WebBackend, target: BufferTarget, data: []const u8, usage: BufferUsage) BufferHandle {
        return self.createBuffer(target, data.len, usage);
    }

    /// Delete a buffer
    pub fn deleteBuffer(self: *WebBackend, buffer: *BufferHandle) void {
        if (buffer.isValid()) {
            self.stats.buffer_memory -= buffer.size;
            buffer.* = .{};
        }
    }

    /// Update buffer data
    pub fn updateBuffer(self: *WebBackend, buffer: BufferHandle, offset: usize, data: []const u8) void {
        _ = self;
        _ = buffer;
        _ = offset;
        _ = data;
    }

    // ========================================================================
    // Texture Operations
    // ========================================================================

    /// Create a texture
    pub fn createTexture(self: *WebBackend, desc: TextureDescriptor) TextureHandle {
        const id = self.next_texture_id;
        self.next_texture_id += 1;
        self.stats.textures_created += 1;

        const size = @as(usize, desc.width) * @as(usize, desc.height) * desc.format.bytesPerPixel();
        self.stats.texture_memory += size;

        return .{
            .id = id,
            .target = desc.target,
            .width = desc.width,
            .height = desc.height,
            .depth = desc.depth,
            .format = desc.format,
            .mip_levels = desc.mip_levels,
        };
    }

    /// Delete a texture
    pub fn deleteTexture(self: *WebBackend, texture: *TextureHandle) void {
        if (texture.isValid()) {
            const size = @as(usize, texture.width) * @as(usize, texture.height) * texture.format.bytesPerPixel();
            self.stats.texture_memory -= size;
            texture.* = .{};
        }
    }

    /// Update texture data
    pub fn updateTexture(self: *WebBackend, texture: TextureHandle, level: u32, x: u32, y: u32, width: u32, height: u32, data: []const u8) void {
        _ = self;
        _ = texture;
        _ = level;
        _ = x;
        _ = y;
        _ = width;
        _ = height;
        _ = data;
    }

    /// Generate mipmaps
    pub fn generateMipmaps(self: *WebBackend, texture: TextureHandle) void {
        _ = self;
        _ = texture;
    }

    // ========================================================================
    // Shader Operations
    // ========================================================================

    /// Create a shader
    pub fn createShader(self: *WebBackend, shader_type: GLenum, source: []const u8) !ShaderHandle {
        _ = shader_type;
        _ = source;
        const id = self.next_shader_id;
        self.next_shader_id += 1;
        self.stats.shaders_created += 1;

        return .{ .id = id };
    }

    /// Delete a shader
    pub fn deleteShader(self: *WebBackend, shader: *ShaderHandle) void {
        _ = self;
        if (shader.isValid()) {
            shader.* = .{};
        }
    }

    /// Create a shader program
    pub fn createProgram(self: *WebBackend, vertex_source: []const u8, fragment_source: []const u8) !ProgramHandle {
        _ = vertex_source;
        _ = fragment_source;
        const id = self.next_program_id;
        self.next_program_id += 1;
        self.stats.programs_created += 1;

        return .{ .id = id };
    }

    /// Delete a program
    pub fn deleteProgram(self: *WebBackend, program: *ProgramHandle) void {
        _ = self;
        if (program.isValid()) {
            program.* = .{};
        }
    }

    /// Use a program
    pub fn useProgram(self: *WebBackend, program: ProgramHandle) void {
        self.current_program = program;
    }

    // ========================================================================
    // Framebuffer Operations
    // ========================================================================

    /// Create a framebuffer
    pub fn createFramebuffer(self: *WebBackend, desc: FramebufferDescriptor) FramebufferHandle {
        const id = self.next_framebuffer_id;
        self.next_framebuffer_id += 1;
        self.stats.framebuffers_created += 1;

        return .{
            .id = id,
            .width = desc.width,
            .height = desc.height,
            .color_attachments = desc.color_attachment_count,
            .has_depth = desc.depth_format != null,
            .has_stencil = if (desc.depth_format) |fmt|
                (fmt == .depth24_stencil8 or fmt == .depth32f_stencil8)
            else
                false,
        };
    }

    /// Delete a framebuffer
    pub fn deleteFramebuffer(self: *WebBackend, framebuffer: *FramebufferHandle) void {
        _ = self;
        if (framebuffer.isValid()) {
            framebuffer.* = .{};
        }
    }

    /// Bind a framebuffer
    pub fn bindFramebuffer(self: *WebBackend, framebuffer: ?FramebufferHandle) void {
        self.current_framebuffer = framebuffer orelse .{};
    }

    // ========================================================================
    // VAO Operations
    // ========================================================================

    /// Create a vertex array object
    pub fn createVAO(self: *WebBackend) VAOHandle {
        const id = self.next_vao_id;
        self.next_vao_id += 1;
        self.stats.vaos_created += 1;

        return .{ .id = id };
    }

    /// Delete a VAO
    pub fn deleteVAO(self: *WebBackend, vao: *VAOHandle) void {
        _ = self;
        if (vao.isValid()) {
            vao.* = .{};
        }
    }

    /// Bind a VAO
    pub fn bindVAO(self: *WebBackend, vao: VAOHandle) void {
        self.current_vao = vao;
    }

    // ========================================================================
    // Sampler Operations
    // ========================================================================

    /// Create a sampler
    pub fn createSampler(self: *WebBackend, desc: SamplerDescriptor) SamplerHandle {
        _ = desc;
        const id = self.next_sampler_id;
        self.next_sampler_id += 1;
        self.stats.samplers_created += 1;

        return .{ .id = id };
    }

    /// Delete a sampler
    pub fn deleteSampler(self: *WebBackend, sampler: *SamplerHandle) void {
        _ = self;
        if (sampler.isValid()) {
            sampler.* = .{};
        }
    }

    // ========================================================================
    // State Operations
    // ========================================================================

    /// Set viewport
    pub fn setViewport(self: *WebBackend, x: i32, y: i32, width: i32, height: i32) void {
        self.viewport = .{ .x = x, .y = y, .width = width, .height = height };
    }

    /// Set scissor rect
    pub fn setScissor(self: *WebBackend, x: i32, y: i32, width: i32, height: i32) void {
        _ = self;
        _ = x;
        _ = y;
        _ = width;
        _ = height;
    }

    /// Set blend state
    pub fn setBlendState(self: *WebBackend, state: BlendState) void {
        _ = self;
        _ = state;
    }

    /// Set depth state
    pub fn setDepthState(self: *WebBackend, state: DepthState) void {
        _ = self;
        _ = state;
    }

    /// Set stencil state
    pub fn setStencilState(self: *WebBackend, state: StencilState) void {
        _ = self;
        _ = state;
    }

    /// Set rasterizer state
    pub fn setRasterizerState(self: *WebBackend, state: RasterizerState) void {
        _ = self;
        _ = state;
    }

    // ========================================================================
    // Clear Operations
    // ========================================================================

    /// Clear color buffer
    pub fn clearColor(self: *WebBackend, r: f32, g: f32, b: f32, a: f32) void {
        _ = self;
        _ = r;
        _ = g;
        _ = b;
        _ = a;
    }

    /// Clear depth buffer
    pub fn clearDepth(self: *WebBackend, depth: f32) void {
        _ = self;
        _ = depth;
    }

    /// Clear stencil buffer
    pub fn clearStencil(self: *WebBackend, stencil: i32) void {
        _ = self;
        _ = stencil;
    }

    /// Clear specified buffers
    pub fn clear(self: *WebBackend, color: bool, depth: bool, stencil: bool) void {
        _ = self;
        _ = color;
        _ = depth;
        _ = stencil;
    }

    // ========================================================================
    // Draw Operations
    // ========================================================================

    /// Draw arrays
    pub fn drawArrays(self: *WebBackend, mode: DrawMode, first: u32, count: u32) void {
        _ = first;
        self.stats.draw_calls += 1;
        self.stats.vertices += count;
        if (mode == .triangles) {
            self.stats.triangles += count / 3;
        }
    }

    /// Draw indexed
    pub fn drawElements(self: *WebBackend, mode: DrawMode, count: u32, index_type: GLenum, offset: usize) void {
        _ = index_type;
        _ = offset;
        self.stats.draw_calls += 1;
        self.stats.vertices += count;
        if (mode == .triangles) {
            self.stats.triangles += count / 3;
        }
    }

    /// Draw arrays instanced
    pub fn drawArraysInstanced(self: *WebBackend, mode: DrawMode, first: u32, count: u32, instance_count: u32) void {
        _ = first;
        self.stats.draw_calls += 1;
        self.stats.vertices += count * instance_count;
        if (mode == .triangles) {
            self.stats.triangles += (count / 3) * instance_count;
        }
    }

    /// Draw indexed instanced
    pub fn drawElementsInstanced(self: *WebBackend, mode: DrawMode, count: u32, index_type: GLenum, offset: usize, instance_count: u32) void {
        _ = index_type;
        _ = offset;
        self.stats.draw_calls += 1;
        self.stats.vertices += count * instance_count;
        if (mode == .triangles) {
            self.stats.triangles += (count / 3) * instance_count;
        }
    }

    // ========================================================================
    // Uniform Operations
    // ========================================================================

    /// Set uniform int
    pub fn setUniformInt(self: *WebBackend, location: i32, value: i32) void {
        _ = self;
        _ = location;
        _ = value;
    }

    /// Set uniform float
    pub fn setUniformFloat(self: *WebBackend, location: i32, value: f32) void {
        _ = self;
        _ = location;
        _ = value;
    }

    /// Set uniform vec2
    pub fn setUniformVec2(self: *WebBackend, location: i32, v: Vec2) void {
        _ = self;
        _ = location;
        _ = v;
    }

    /// Set uniform vec3
    pub fn setUniformVec3(self: *WebBackend, location: i32, v: Vec3) void {
        _ = self;
        _ = location;
        _ = v;
    }

    /// Set uniform vec4
    pub fn setUniformVec4(self: *WebBackend, location: i32, v: Vec4) void {
        _ = self;
        _ = location;
        _ = v;
    }

    /// Set uniform mat4
    pub fn setUniformMat4(self: *WebBackend, location: i32, m: Mat4) void {
        _ = self;
        _ = location;
        _ = m;
    }

    // ========================================================================
    // Statistics
    // ========================================================================

    /// Get current statistics
    pub fn getStats(self: *const WebBackend) BackendStats {
        return self.stats;
    }

    /// Reset statistics
    pub fn resetStats(self: *WebBackend) void {
        self.stats.draw_calls = 0;
        self.stats.triangles = 0;
        self.stats.vertices = 0;
    }
};

// ============================================================================
// Statistics
// ============================================================================

/// Backend statistics
pub const BackendStats = struct {
    frame_count: u64 = 0,
    draw_calls: u32 = 0,
    triangles: u32 = 0,
    vertices: u32 = 0,

    buffers_created: u64 = 0,
    textures_created: u64 = 0,
    shaders_created: u64 = 0,
    programs_created: u64 = 0,
    framebuffers_created: u64 = 0,
    vaos_created: u64 = 0,
    samplers_created: u64 = 0,

    buffer_memory: usize = 0,
    texture_memory: usize = 0,

    pub fn getTotalMemory(self: BackendStats) usize {
        return self.buffer_memory + self.texture_memory;
    }
};

// ============================================================================
// Utility Functions
// ============================================================================

/// Create standard PBR vertex attributes
pub fn createPBRVertexAttributes() [5]VertexAttribute {
    return .{
        // Position
        .{ .location = 0, .size = 3, .data_type = GL.FLOAT, .stride = 48, .offset = 0 },
        // Normal
        .{ .location = 1, .size = 3, .data_type = GL.FLOAT, .stride = 48, .offset = 12 },
        // UV
        .{ .location = 2, .size = 2, .data_type = GL.FLOAT, .stride = 48, .offset = 24 },
        // Tangent
        .{ .location = 3, .size = 4, .data_type = GL.FLOAT, .stride = 48, .offset = 32 },
        // Unused (padding for alignment)
        .{ .location = 4, .size = 0, .data_type = GL.FLOAT, .stride = 0, .offset = 0 },
    };
}

/// Create simple vertex attributes (position + color)
pub fn createSimpleVertexAttributes() [2]VertexAttribute {
    return .{
        // Position
        .{ .location = 0, .size = 3, .data_type = GL.FLOAT, .stride = 28, .offset = 0 },
        // Color
        .{ .location = 1, .size = 4, .data_type = GL.FLOAT, .stride = 28, .offset = 12 },
    };
}

/// Create default sampler descriptor
pub fn createDefaultSamplerDescriptor() SamplerDescriptor {
    return .{
        .min_filter = .linear_mipmap_linear,
        .mag_filter = .linear,
        .wrap_s = .repeat,
        .wrap_t = .repeat,
        .max_anisotropy = 16.0,
    };
}

/// Create shadow map sampler descriptor
pub fn createShadowSamplerDescriptor() SamplerDescriptor {
    return .{
        .min_filter = .linear,
        .mag_filter = .linear,
        .wrap_s = .clamp_to_edge,
        .wrap_t = .clamp_to_edge,
        .compare_func = .lequal,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "WebBackend initialization" {
    const allocator = std.testing.allocator;
    var backend = WebBackend.init(allocator, .auto);
    defer backend.deinit();

    try std.testing.expect(backend.getAPI() == .webgl2);
    const caps = backend.getCapabilities();
    try std.testing.expect(caps.max_texture_size > 0);
}

test "WebBackend buffer creation" {
    const allocator = std.testing.allocator;
    var backend = WebBackend.init(allocator, .webgl2);
    defer backend.deinit();

    const buffer = backend.createBuffer(.vertex, 1024, .static_draw);
    try std.testing.expect(buffer.isValid());
    try std.testing.expect(buffer.size == 1024);
}

test "WebBackend texture creation" {
    const allocator = std.testing.allocator;
    var backend = WebBackend.init(allocator, .webgl2);
    defer backend.deinit();

    const texture = backend.createTexture(.{
        .width = 512,
        .height = 512,
        .format = .rgba8,
    });
    try std.testing.expect(texture.isValid());
    try std.testing.expect(texture.width == 512);
    try std.testing.expect(texture.height == 512);
}

test "WebBackend statistics" {
    const allocator = std.testing.allocator;
    var backend = WebBackend.init(allocator, .webgl2);
    defer backend.deinit();

    backend.beginFrame();
    backend.drawArrays(.triangles, 0, 36);
    backend.drawArrays(.triangles, 0, 24);
    backend.endFrame();

    const stats = backend.getStats();
    try std.testing.expect(stats.draw_calls == 2);
    try std.testing.expect(stats.vertices == 60);
    try std.testing.expect(stats.triangles == 20);
}

test "TextureFormat byte sizes" {
    try std.testing.expect(TextureFormat.r8.bytesPerPixel() == 1);
    try std.testing.expect(TextureFormat.rg8.bytesPerPixel() == 2);
    try std.testing.expect(TextureFormat.rgba8.bytesPerPixel() == 4);
    try std.testing.expect(TextureFormat.rgba16f.bytesPerPixel() == 8);
    try std.testing.expect(TextureFormat.rgba32f.bytesPerPixel() == 16);
}

test "PBR vertex attributes" {
    const attrs = createPBRVertexAttributes();
    try std.testing.expect(attrs[0].location == 0);
    try std.testing.expect(attrs[0].size == 3);
    try std.testing.expect(attrs[0].stride == 48);
}
