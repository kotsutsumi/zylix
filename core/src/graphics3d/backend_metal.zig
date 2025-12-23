//! Zylix Metal Backend
//!
//! Apple Metal graphics backend for iOS/macOS platforms.
//! Provides low-level GPU access through Metal API.
//!
//! ## Features
//! - **Device Management**: Metal device initialization and capability detection
//! - **Command Submission**: Command buffers, queues, and encoders
//! - **Pipeline States**: Render and compute pipeline management
//! - **Resource Management**: Buffers, textures, and samplers
//! - **Shader Compilation**: MSL shader compilation and caching
//!
//! ## Platform Support
//! - macOS 10.13+ (High Sierra)
//! - iOS 11.0+
//! - tvOS 11.0+
//!
//! ## Example
//! ```zig
//! const metal = @import("backend_metal.zig");
//!
//! // Create Metal backend
//! var backend = try metal.MetalBackend.init(allocator);
//! defer backend.deinit();
//!
//! // Create render pipeline
//! const pipeline = try backend.createRenderPipeline(.{
//!     .vertex_function = "vertex_main",
//!     .fragment_function = "fragment_main",
//! });
//!
//! // Begin render pass
//! var encoder = try backend.beginRenderPass(&render_pass_desc);
//! encoder.setRenderPipeline(pipeline);
//! encoder.drawPrimitives(.triangle, 0, 36);
//! encoder.endEncoding();
//! ```

const std = @import("std");
const types = @import("types.zig");
const Vec2 = types.Vec2;
const Vec3 = types.Vec3;
const Vec4 = types.Vec4;
const Mat4 = types.Mat4;
const Color = types.Color;

// ============================================================================
// Metal API Types (Opaque handles for C interop)
// ============================================================================

/// Opaque Metal device handle
pub const MTLDevice = *opaque {};

/// Opaque Metal command queue handle
pub const MTLCommandQueue = *opaque {};

/// Opaque Metal command buffer handle
pub const MTLCommandBuffer = *opaque {};

/// Opaque Metal render command encoder handle
pub const MTLRenderCommandEncoder = *opaque {};

/// Opaque Metal compute command encoder handle
pub const MTLComputeCommandEncoder = *opaque {};

/// Opaque Metal blit command encoder handle
pub const MTLBlitCommandEncoder = *opaque {};

/// Opaque Metal render pipeline state handle
pub const MTLRenderPipelineState = *opaque {};

/// Opaque Metal compute pipeline state handle
pub const MTLComputePipelineState = *opaque {};

/// Opaque Metal depth stencil state handle
pub const MTLDepthStencilState = *opaque {};

/// Opaque Metal buffer handle
pub const MTLBuffer = *opaque {};

/// Opaque Metal texture handle
pub const MTLTexture = *opaque {};

/// Opaque Metal sampler state handle
pub const MTLSamplerState = *opaque {};

/// Opaque Metal library handle
pub const MTLLibrary = *opaque {};

/// Opaque Metal function handle
pub const MTLFunction = *opaque {};

// ============================================================================
// Enumerations
// ============================================================================

/// Metal pixel formats
pub const PixelFormat = enum(u32) {
    invalid = 0,

    // 8-bit formats
    r8_unorm = 10,
    r8_snorm = 12,
    r8_uint = 13,
    r8_sint = 14,

    // 16-bit formats
    r16_unorm = 20,
    r16_snorm = 22,
    r16_uint = 23,
    r16_sint = 24,
    r16_float = 25,

    rg8_unorm = 30,
    rg8_snorm = 32,
    rg8_uint = 33,
    rg8_sint = 34,

    // 32-bit formats
    r32_uint = 53,
    r32_sint = 54,
    r32_float = 55,

    rg16_unorm = 60,
    rg16_snorm = 62,
    rg16_uint = 63,
    rg16_sint = 64,
    rg16_float = 65,

    rgba8_unorm = 70,
    rgba8_unorm_srgb = 71,
    rgba8_snorm = 72,
    rgba8_uint = 73,
    rgba8_sint = 74,

    bgra8_unorm = 80,
    bgra8_unorm_srgb = 81,

    // 64-bit formats
    rg32_uint = 103,
    rg32_sint = 104,
    rg32_float = 105,

    rgba16_unorm = 110,
    rgba16_snorm = 112,
    rgba16_uint = 113,
    rgba16_sint = 114,
    rgba16_float = 115,

    // 128-bit formats
    rgba32_uint = 123,
    rgba32_sint = 124,
    rgba32_float = 125,

    // Depth/Stencil formats
    depth16_unorm = 250,
    depth32_float = 252,
    stencil8 = 253,
    depth24_unorm_stencil8 = 255,
    depth32_float_stencil8 = 260,

    pub fn isDepthFormat(self: PixelFormat) bool {
        return switch (self) {
            .depth16_unorm, .depth32_float, .depth24_unorm_stencil8, .depth32_float_stencil8 => true,
            else => false,
        };
    }

    pub fn isStencilFormat(self: PixelFormat) bool {
        return switch (self) {
            .stencil8, .depth24_unorm_stencil8, .depth32_float_stencil8 => true,
            else => false,
        };
    }

    pub fn bytesPerPixel(self: PixelFormat) u32 {
        return switch (self) {
            .r8_unorm, .r8_snorm, .r8_uint, .r8_sint, .stencil8 => 1,
            .r16_unorm, .r16_snorm, .r16_uint, .r16_sint, .r16_float, .rg8_unorm, .rg8_snorm, .rg8_uint, .rg8_sint, .depth16_unorm => 2,
            .r32_uint, .r32_sint, .r32_float, .rg16_unorm, .rg16_snorm, .rg16_uint, .rg16_sint, .rg16_float, .rgba8_unorm, .rgba8_unorm_srgb, .rgba8_snorm, .rgba8_uint, .rgba8_sint, .bgra8_unorm, .bgra8_unorm_srgb, .depth32_float, .depth24_unorm_stencil8 => 4,
            .rg32_uint, .rg32_sint, .rg32_float, .rgba16_unorm, .rgba16_snorm, .rgba16_uint, .rgba16_sint, .rgba16_float, .depth32_float_stencil8 => 8,
            .rgba32_uint, .rgba32_sint, .rgba32_float => 16,
            else => 0,
        };
    }
};

/// Primitive topology types
pub const PrimitiveType = enum(u32) {
    point = 0,
    line = 1,
    line_strip = 2,
    triangle = 3,
    triangle_strip = 4,
};

/// Index types for indexed drawing
pub const IndexType = enum(u32) {
    uint16 = 0,
    uint32 = 1,
};

/// Texture types
pub const TextureType = enum(u32) {
    type_1d = 0,
    type_1d_array = 1,
    type_2d = 2,
    type_2d_array = 3,
    type_2d_multisample = 4,
    type_cube = 5,
    type_cube_array = 6,
    type_3d = 7,
};

/// Texture usage flags
pub const TextureUsage = packed struct(u32) {
    unknown: bool = false,
    shader_read: bool = true,
    shader_write: bool = false,
    render_target: bool = false,
    pixel_format_view: bool = false,
    _padding: u27 = 0,

    pub const read_write = TextureUsage{ .shader_read = true, .shader_write = true };
    pub const render_target_usage = TextureUsage{ .shader_read = true, .render_target = true };
};

/// Buffer resource options
pub const ResourceOptions = packed struct(u32) {
    cpu_cache_mode: u2 = 0, // 0 = default, 1 = write combined
    storage_mode: u2 = 0, // 0 = shared, 1 = managed, 2 = private
    hazard_tracking: u2 = 0,
    _padding: u26 = 0,

    pub const cpu_cache_mode_default: u2 = 0;
    pub const cpu_cache_mode_write_combined: u2 = 1;

    pub const storage_shared: ResourceOptions = .{ .storage_mode = 0 };
    pub const storage_managed: ResourceOptions = .{ .storage_mode = 1 };
    pub const storage_private: ResourceOptions = .{ .storage_mode = 2 };
};

/// Load action for render pass attachments
pub const LoadAction = enum(u32) {
    dont_care = 0,
    load = 1,
    clear = 2,
};

/// Store action for render pass attachments
pub const StoreAction = enum(u32) {
    dont_care = 0,
    store = 1,
    multisample_resolve = 2,
    store_and_multisample_resolve = 3,
};

/// Comparison functions
pub const CompareFunction = enum(u32) {
    never = 0,
    less = 1,
    equal = 2,
    less_equal = 3,
    greater = 4,
    not_equal = 5,
    greater_equal = 6,
    always = 7,
};

/// Stencil operations
pub const StencilOperation = enum(u32) {
    keep = 0,
    zero = 1,
    replace = 2,
    increment_clamp = 3,
    decrement_clamp = 4,
    invert = 5,
    increment_wrap = 6,
    decrement_wrap = 7,
};

/// Blend factors
pub const BlendFactor = enum(u32) {
    zero = 0,
    one = 1,
    source_color = 2,
    one_minus_source_color = 3,
    source_alpha = 4,
    one_minus_source_alpha = 5,
    destination_color = 6,
    one_minus_destination_color = 7,
    destination_alpha = 8,
    one_minus_destination_alpha = 9,
    source_alpha_saturated = 10,
    blend_color = 11,
    one_minus_blend_color = 12,
    blend_alpha = 13,
    one_minus_blend_alpha = 14,
};

/// Blend operations
pub const BlendOperation = enum(u32) {
    add = 0,
    subtract = 1,
    reverse_subtract = 2,
    min = 3,
    max = 4,
};

/// Cull modes
pub const CullMode = enum(u32) {
    none = 0,
    front = 1,
    back = 2,
};

/// Winding order
pub const Winding = enum(u32) {
    clockwise = 0,
    counter_clockwise = 1,
};

/// Triangle fill mode
pub const TriangleFillMode = enum(u32) {
    fill = 0,
    lines = 1,
};

/// Sampler address modes
pub const SamplerAddressMode = enum(u32) {
    clamp_to_edge = 0,
    mirror_clamp_to_edge = 1,
    repeat = 2,
    mirror_repeat = 3,
    clamp_to_zero = 4,
    clamp_to_border_color = 5,
};

/// Sampler min/mag filter
pub const SamplerMinMagFilter = enum(u32) {
    nearest = 0,
    linear = 1,
};

/// Sampler mip filter
pub const SamplerMipFilter = enum(u32) {
    not_mipmapped = 0,
    nearest = 1,
    linear = 2,
};

// ============================================================================
// Descriptor Structures
// ============================================================================

/// Clear color
pub const ClearColor = struct {
    r: f64 = 0,
    g: f64 = 0,
    b: f64 = 0,
    a: f64 = 1,

    pub fn fromColor(c: Color) ClearColor {
        return .{
            .r = @floatCast(c.r),
            .g = @floatCast(c.g),
            .b = @floatCast(c.b),
            .a = @floatCast(c.a),
        };
    }
};

/// Render pass color attachment descriptor
pub const ColorAttachmentDescriptor = struct {
    texture: ?MTLTexture = null,
    level: u32 = 0,
    slice: u32 = 0,
    depth_plane: u32 = 0,
    resolve_texture: ?MTLTexture = null,
    resolve_level: u32 = 0,
    resolve_slice: u32 = 0,
    resolve_depth_plane: u32 = 0,
    load_action: LoadAction = .clear,
    store_action: StoreAction = .store,
    clear_color: ClearColor = .{},
};

/// Render pass depth attachment descriptor
pub const DepthAttachmentDescriptor = struct {
    texture: ?MTLTexture = null,
    level: u32 = 0,
    slice: u32 = 0,
    depth_plane: u32 = 0,
    resolve_texture: ?MTLTexture = null,
    resolve_level: u32 = 0,
    resolve_slice: u32 = 0,
    resolve_depth_plane: u32 = 0,
    load_action: LoadAction = .clear,
    store_action: StoreAction = .store,
    clear_depth: f64 = 1.0,
};

/// Render pass stencil attachment descriptor
pub const StencilAttachmentDescriptor = struct {
    texture: ?MTLTexture = null,
    level: u32 = 0,
    slice: u32 = 0,
    depth_plane: u32 = 0,
    resolve_texture: ?MTLTexture = null,
    resolve_level: u32 = 0,
    resolve_slice: u32 = 0,
    resolve_depth_plane: u32 = 0,
    load_action: LoadAction = .clear,
    store_action: StoreAction = .store,
    clear_stencil: u32 = 0,
};

/// Render pass descriptor
pub const RenderPassDescriptor = struct {
    color_attachments: [8]ColorAttachmentDescriptor = [_]ColorAttachmentDescriptor{.{}} ** 8,
    depth_attachment: DepthAttachmentDescriptor = .{},
    stencil_attachment: StencilAttachmentDescriptor = .{},
    visibility_result_buffer: ?MTLBuffer = null,
    render_target_array_length: u32 = 0,
    render_target_width: u32 = 0,
    render_target_height: u32 = 0,
    default_raster_sample_count: u32 = 1,
};

/// Vertex attribute descriptor
pub const VertexAttributeDescriptor = struct {
    format: VertexFormat = .invalid,
    offset: u32 = 0,
    buffer_index: u32 = 0,
};

/// Vertex format
pub const VertexFormat = enum(u32) {
    invalid = 0,

    // 8-bit formats
    uchar2 = 1,
    uchar3 = 2,
    uchar4 = 3,
    char2 = 4,
    char3 = 5,
    char4 = 6,
    uchar2_normalized = 7,
    uchar3_normalized = 8,
    uchar4_normalized = 9,
    char2_normalized = 10,
    char3_normalized = 11,
    char4_normalized = 12,

    // 16-bit formats
    ushort2 = 13,
    ushort3 = 14,
    ushort4 = 15,
    short2 = 16,
    short3 = 17,
    short4 = 18,
    ushort2_normalized = 19,
    ushort3_normalized = 20,
    ushort4_normalized = 21,
    short2_normalized = 22,
    short3_normalized = 23,
    short4_normalized = 24,

    half2 = 25,
    half3 = 26,
    half4 = 27,

    // 32-bit formats
    float = 28,
    float2 = 29,
    float3 = 30,
    float4 = 31,

    int = 32,
    int2 = 33,
    int3 = 34,
    int4 = 35,

    uint = 36,
    uint2 = 37,
    uint3 = 38,
    uint4 = 39,

    // Special formats
    int_1010102_normalized = 40,
    uint_1010102_normalized = 41,

    pub fn size(self: VertexFormat) u32 {
        return switch (self) {
            .invalid => 0,
            .uchar2, .char2, .uchar2_normalized, .char2_normalized => 2,
            .uchar3, .char3, .uchar3_normalized, .char3_normalized => 3,
            .uchar4, .char4, .uchar4_normalized, .char4_normalized, .ushort2, .short2, .ushort2_normalized, .short2_normalized, .half2, .float, .int, .uint, .int_1010102_normalized, .uint_1010102_normalized => 4,
            .ushort3, .short3, .ushort3_normalized, .short3_normalized, .half3 => 6,
            .ushort4, .short4, .ushort4_normalized, .short4_normalized, .half4, .float2, .int2, .uint2 => 8,
            .float3, .int3, .uint3 => 12,
            .float4, .int4, .uint4 => 16,
        };
    }
};

/// Vertex buffer layout descriptor
pub const VertexBufferLayoutDescriptor = struct {
    stride: u32 = 0,
    step_function: VertexStepFunction = .per_vertex,
    step_rate: u32 = 1,
};

/// Vertex step function
pub const VertexStepFunction = enum(u32) {
    constant = 0,
    per_vertex = 1,
    per_instance = 2,
    per_patch = 3,
    per_patch_control_point = 4,
};

/// Vertex descriptor
pub const VertexDescriptor = struct {
    attributes: [31]VertexAttributeDescriptor = [_]VertexAttributeDescriptor{.{}} ** 31,
    layouts: [31]VertexBufferLayoutDescriptor = [_]VertexBufferLayoutDescriptor{.{}} ** 31,
};

/// Render pipeline color attachment descriptor
pub const RenderPipelineColorAttachmentDescriptor = struct {
    pixel_format: PixelFormat = .bgra8_unorm,
    blending_enabled: bool = false,
    source_rgb_blend_factor: BlendFactor = .one,
    destination_rgb_blend_factor: BlendFactor = .zero,
    rgb_blend_operation: BlendOperation = .add,
    source_alpha_blend_factor: BlendFactor = .one,
    destination_alpha_blend_factor: BlendFactor = .zero,
    alpha_blend_operation: BlendOperation = .add,
    write_mask: ColorWriteMask = .all,
};

/// Color write mask
pub const ColorWriteMask = packed struct(u8) {
    alpha: bool = true,
    blue: bool = true,
    green: bool = true,
    red: bool = true,
    _padding: u4 = 0,

    pub const none = ColorWriteMask{ .alpha = false, .blue = false, .green = false, .red = false };
    pub const all = ColorWriteMask{};
};

/// Render pipeline descriptor
pub const RenderPipelineDescriptor = struct {
    label: ?[]const u8 = null,
    vertex_function: ?MTLFunction = null,
    fragment_function: ?MTLFunction = null,
    vertex_descriptor: ?VertexDescriptor = null,
    color_attachments: [8]RenderPipelineColorAttachmentDescriptor = [_]RenderPipelineColorAttachmentDescriptor{.{}} ** 8,
    depth_attachment_pixel_format: PixelFormat = .invalid,
    stencil_attachment_pixel_format: PixelFormat = .invalid,
    sample_count: u32 = 1,
    alpha_to_coverage_enabled: bool = false,
    alpha_to_one_enabled: bool = false,
    rasterization_enabled: bool = true,
    input_primitive_topology: PrimitiveTopologyClass = .unspecified,
    max_vertex_amplification_count: u32 = 1,
};

/// Primitive topology class
pub const PrimitiveTopologyClass = enum(u32) {
    unspecified = 0,
    point = 1,
    line = 2,
    triangle = 3,
};

/// Depth stencil descriptor
pub const DepthStencilDescriptor = struct {
    depth_compare_function: CompareFunction = .always,
    depth_write_enabled: bool = false,
    front_face_stencil: ?StencilDescriptor = null,
    back_face_stencil: ?StencilDescriptor = null,
    label: ?[]const u8 = null,
};

/// Stencil descriptor
pub const StencilDescriptor = struct {
    stencil_compare_function: CompareFunction = .always,
    stencil_failure_operation: StencilOperation = .keep,
    depth_failure_operation: StencilOperation = .keep,
    depth_stencil_pass_operation: StencilOperation = .keep,
    read_mask: u32 = 0xFFFFFFFF,
    write_mask: u32 = 0xFFFFFFFF,
};

/// Texture descriptor
pub const TextureDescriptor = struct {
    texture_type: TextureType = .type_2d,
    pixel_format: PixelFormat = .rgba8_unorm,
    width: u32 = 1,
    height: u32 = 1,
    depth: u32 = 1,
    mipmap_level_count: u32 = 1,
    sample_count: u32 = 1,
    array_length: u32 = 1,
    resource_options: ResourceOptions = .{},
    cpu_cache_mode: u32 = 0,
    storage_mode: u32 = 0,
    usage: TextureUsage = .{},
    allow_gpu_optimized_contents: bool = true,
};

/// Sampler descriptor
pub const SamplerDescriptor = struct {
    min_filter: SamplerMinMagFilter = .nearest,
    mag_filter: SamplerMinMagFilter = .nearest,
    mip_filter: SamplerMipFilter = .not_mipmapped,
    max_anisotropy: u32 = 1,
    s_address_mode: SamplerAddressMode = .clamp_to_edge,
    t_address_mode: SamplerAddressMode = .clamp_to_edge,
    r_address_mode: SamplerAddressMode = .clamp_to_edge,
    normalized_coordinates: bool = true,
    lod_min_clamp: f32 = 0.0,
    lod_max_clamp: f32 = std.math.floatMax(f32),
    compare_function: CompareFunction = .never,
    label: ?[]const u8 = null,
};

// ============================================================================
// Device Capabilities
// ============================================================================

/// Metal GPU family
pub const GPUFamily = enum {
    apple1,
    apple2,
    apple3,
    apple4,
    apple5,
    apple6,
    apple7,
    apple8,
    mac1,
    mac2,
    common1,
    common2,
    common3,
};

/// Device capabilities and limits
pub const DeviceCapabilities = struct {
    /// Device name
    name: []const u8 = "Unknown",

    /// GPU family
    gpu_family: GPUFamily = .common1,

    /// Maximum texture dimensions
    max_texture_size_1d: u32 = 16384,
    max_texture_size_2d: u32 = 16384,
    max_texture_size_3d: u32 = 2048,
    max_texture_size_cube: u32 = 16384,

    /// Maximum buffer size
    max_buffer_length: u64 = 256 * 1024 * 1024,

    /// Maximum threads per threadgroup
    max_threads_per_threadgroup: u32 = 1024,

    /// Maximum threadgroup memory
    max_threadgroup_memory_length: u32 = 32 * 1024,

    /// Feature support flags
    supports_ray_tracing: bool = false,
    supports_32bit_float_filtering: bool = true,
    supports_32bit_msaa: bool = true,
    supports_bc_texture_compression: bool = false,
    supports_pull_model_interpolation: bool = false,
    supports_shader_barycentric_coordinates: bool = false,

    /// Recommended limits
    recommended_max_working_set_size: u64 = 0,

    pub fn default() DeviceCapabilities {
        return .{};
    }
};

// ============================================================================
// Metal Backend
// ============================================================================

/// Metal graphics backend
pub const MetalBackend = struct {
    allocator: std.mem.Allocator,

    // Metal objects (null in simulation mode)
    device: ?MTLDevice = null,
    command_queue: ?MTLCommandQueue = null,
    default_library: ?MTLLibrary = null,

    // Capabilities
    capabilities: DeviceCapabilities,

    // State tracking
    current_render_encoder: ?MTLRenderCommandEncoder = null,
    current_compute_encoder: ?MTLComputeCommandEncoder = null,
    current_command_buffer: ?MTLCommandBuffer = null,

    // Resource caches
    pipeline_cache: std.StringHashMap(MTLRenderPipelineState),
    sampler_cache: std.ArrayListUnmanaged(MTLSamplerState) = .{},
    depth_stencil_cache: std.ArrayListUnmanaged(MTLDepthStencilState) = .{},

    // Statistics
    stats: BackendStats,

    pub fn init(allocator: std.mem.Allocator) MetalBackend {
        return .{
            .allocator = allocator,
            .capabilities = DeviceCapabilities.default(),
            .pipeline_cache = std.StringHashMap(MTLRenderPipelineState).init(allocator),
            .stats = .{},
        };
    }

    pub fn deinit(self: *MetalBackend) void {
        self.pipeline_cache.deinit();
        self.sampler_cache.deinit(self.allocator);
        self.depth_stencil_cache.deinit(self.allocator);
    }

    /// Get device capabilities
    pub fn getCapabilities(self: *const MetalBackend) DeviceCapabilities {
        return self.capabilities;
    }

    /// Check if device supports a GPU family
    pub fn supportsFamily(self: *const MetalBackend, family: GPUFamily) bool {
        return @intFromEnum(self.capabilities.gpu_family) >= @intFromEnum(family);
    }

    /// Begin a new frame
    pub fn beginFrame(self: *MetalBackend) void {
        self.stats.frame_count += 1;
        self.stats.draw_calls = 0;
        self.stats.triangles = 0;
        self.stats.vertices = 0;
    }

    /// End the current frame
    pub fn endFrame(self: *MetalBackend) void {
        // Submit command buffer if active
        if (self.current_command_buffer != null) {
            self.current_command_buffer = null;
        }
    }

    /// Create a buffer
    pub fn createBuffer(self: *MetalBackend, size: usize, options: ResourceOptions) !BufferHandle {
        _ = options;
        self.stats.buffers_created += 1;
        self.stats.buffer_memory += size;
        return BufferHandle{
            .id = self.stats.buffers_created,
            .size = size,
        };
    }

    /// Create a texture
    pub fn createTexture(self: *MetalBackend, desc: TextureDescriptor) !TextureHandle {
        self.stats.textures_created += 1;
        const size = @as(usize, desc.width) * @as(usize, desc.height) * desc.pixel_format.bytesPerPixel();
        self.stats.texture_memory += size;
        return TextureHandle{
            .id = self.stats.textures_created,
            .width = desc.width,
            .height = desc.height,
            .format = desc.pixel_format,
        };
    }

    /// Create a sampler
    pub fn createSampler(self: *MetalBackend, desc: SamplerDescriptor) !SamplerHandle {
        _ = desc;
        self.stats.samplers_created += 1;
        return SamplerHandle{
            .id = self.stats.samplers_created,
        };
    }

    /// Create a render pipeline
    pub fn createRenderPipeline(self: *MetalBackend, desc: RenderPipelineDescriptor) !PipelineHandle {
        _ = desc;
        self.stats.pipelines_created += 1;
        return PipelineHandle{
            .id = self.stats.pipelines_created,
            .pipeline_type = .render,
        };
    }

    /// Create a compute pipeline
    pub fn createComputePipeline(self: *MetalBackend, function_name: []const u8) !PipelineHandle {
        _ = function_name;
        self.stats.pipelines_created += 1;
        return PipelineHandle{
            .id = self.stats.pipelines_created,
            .pipeline_type = .compute,
        };
    }

    /// Create a depth stencil state
    pub fn createDepthStencilState(self: *MetalBackend, desc: DepthStencilDescriptor) !DepthStencilHandle {
        _ = desc;
        self.stats.depth_stencil_states_created += 1;
        return DepthStencilHandle{
            .id = self.stats.depth_stencil_states_created,
        };
    }

    /// Begin a render pass
    pub fn beginRenderPass(self: *MetalBackend, desc: RenderPassDescriptor) !RenderEncoder {
        _ = desc;
        return RenderEncoder{
            .backend = self,
        };
    }

    /// Begin a compute pass
    pub fn beginComputePass(self: *MetalBackend) !ComputeEncoder {
        return ComputeEncoder{
            .backend = self,
        };
    }

    /// Begin a blit pass
    pub fn beginBlitPass(self: *MetalBackend) !BlitEncoder {
        return BlitEncoder{
            .backend = self,
        };
    }

    /// Get current statistics
    pub fn getStats(self: *const MetalBackend) BackendStats {
        return self.stats;
    }

    /// Reset statistics
    pub fn resetStats(self: *MetalBackend) void {
        self.stats.draw_calls = 0;
        self.stats.triangles = 0;
        self.stats.vertices = 0;
    }
};

// ============================================================================
// Resource Handles
// ============================================================================

/// Buffer handle
pub const BufferHandle = struct {
    id: u64 = 0,
    size: usize = 0,
    native: ?MTLBuffer = null,

    pub fn isValid(self: BufferHandle) bool {
        return self.id != 0;
    }
};

/// Texture handle
pub const TextureHandle = struct {
    id: u64 = 0,
    width: u32 = 0,
    height: u32 = 0,
    format: PixelFormat = .invalid,
    native: ?MTLTexture = null,

    pub fn isValid(self: TextureHandle) bool {
        return self.id != 0;
    }
};

/// Sampler handle
pub const SamplerHandle = struct {
    id: u64 = 0,
    native: ?MTLSamplerState = null,

    pub fn isValid(self: SamplerHandle) bool {
        return self.id != 0;
    }
};

/// Pipeline handle
pub const PipelineHandle = struct {
    id: u64 = 0,
    pipeline_type: PipelineType = .render,
    native_render: ?MTLRenderPipelineState = null,
    native_compute: ?MTLComputePipelineState = null,

    pub const PipelineType = enum {
        render,
        compute,
    };

    pub fn isValid(self: PipelineHandle) bool {
        return self.id != 0;
    }
};

/// Depth stencil handle
pub const DepthStencilHandle = struct {
    id: u64 = 0,
    native: ?MTLDepthStencilState = null,

    pub fn isValid(self: DepthStencilHandle) bool {
        return self.id != 0;
    }
};

// ============================================================================
// Command Encoders
// ============================================================================

/// Render command encoder wrapper
pub const RenderEncoder = struct {
    backend: *MetalBackend,

    pub fn setRenderPipeline(self: *RenderEncoder, pipeline: PipelineHandle) void {
        _ = pipeline;
        _ = self;
    }

    pub fn setVertexBuffer(self: *RenderEncoder, buffer: BufferHandle, offset: u32, index: u32) void {
        _ = buffer;
        _ = offset;
        _ = index;
        _ = self;
    }

    pub fn setFragmentBuffer(self: *RenderEncoder, buffer: BufferHandle, offset: u32, index: u32) void {
        _ = buffer;
        _ = offset;
        _ = index;
        _ = self;
    }

    pub fn setVertexTexture(self: *RenderEncoder, texture: TextureHandle, index: u32) void {
        _ = texture;
        _ = index;
        _ = self;
    }

    pub fn setFragmentTexture(self: *RenderEncoder, texture: TextureHandle, index: u32) void {
        _ = texture;
        _ = index;
        _ = self;
    }

    pub fn setVertexSampler(self: *RenderEncoder, sampler: SamplerHandle, index: u32) void {
        _ = sampler;
        _ = index;
        _ = self;
    }

    pub fn setFragmentSampler(self: *RenderEncoder, sampler: SamplerHandle, index: u32) void {
        _ = sampler;
        _ = index;
        _ = self;
    }

    pub fn setDepthStencilState(self: *RenderEncoder, state: DepthStencilHandle) void {
        _ = state;
        _ = self;
    }

    pub fn setCullMode(self: *RenderEncoder, mode: CullMode) void {
        _ = mode;
        _ = self;
    }

    pub fn setFrontFacing(self: *RenderEncoder, winding: Winding) void {
        _ = winding;
        _ = self;
    }

    pub fn setTriangleFillMode(self: *RenderEncoder, mode: TriangleFillMode) void {
        _ = mode;
        _ = self;
    }

    pub fn setViewport(self: *RenderEncoder, x: f64, y: f64, width: f64, height: f64, near: f64, far: f64) void {
        _ = x;
        _ = y;
        _ = width;
        _ = height;
        _ = near;
        _ = far;
        _ = self;
    }

    pub fn setScissorRect(self: *RenderEncoder, x: u32, y: u32, width: u32, height: u32) void {
        _ = x;
        _ = y;
        _ = width;
        _ = height;
        _ = self;
    }

    pub fn setBlendColor(self: *RenderEncoder, r: f32, g: f32, b: f32, a: f32) void {
        _ = r;
        _ = g;
        _ = b;
        _ = a;
        _ = self;
    }

    pub fn setStencilReferenceValue(self: *RenderEncoder, value: u32) void {
        _ = value;
        _ = self;
    }

    pub fn drawPrimitives(self: *RenderEncoder, primitive_type: PrimitiveType, vertex_start: u32, vertex_count: u32) void {
        _ = vertex_start;
        self.backend.stats.draw_calls += 1;
        self.backend.stats.vertices += vertex_count;
        if (primitive_type == .triangle) {
            self.backend.stats.triangles += vertex_count / 3;
        }
    }

    pub fn drawIndexedPrimitives(self: *RenderEncoder, primitive_type: PrimitiveType, index_count: u32, index_type: IndexType, index_buffer: BufferHandle, index_buffer_offset: u32) void {
        _ = index_type;
        _ = index_buffer;
        _ = index_buffer_offset;
        self.backend.stats.draw_calls += 1;
        self.backend.stats.vertices += index_count;
        if (primitive_type == .triangle) {
            self.backend.stats.triangles += index_count / 3;
        }
    }

    pub fn drawPrimitivesInstanced(self: *RenderEncoder, primitive_type: PrimitiveType, vertex_start: u32, vertex_count: u32, instance_count: u32) void {
        _ = vertex_start;
        self.backend.stats.draw_calls += 1;
        self.backend.stats.vertices += vertex_count * instance_count;
        if (primitive_type == .triangle) {
            self.backend.stats.triangles += (vertex_count / 3) * instance_count;
        }
    }

    pub fn endEncoding(self: *RenderEncoder) void {
        self.backend.current_render_encoder = null;
    }
};

/// Compute command encoder wrapper
pub const ComputeEncoder = struct {
    backend: *MetalBackend,

    pub fn setComputePipeline(self: *ComputeEncoder, pipeline: PipelineHandle) void {
        _ = pipeline;
        _ = self;
    }

    pub fn setBuffer(self: *ComputeEncoder, buffer: BufferHandle, offset: u32, index: u32) void {
        _ = buffer;
        _ = offset;
        _ = index;
        _ = self;
    }

    pub fn setTexture(self: *ComputeEncoder, texture: TextureHandle, index: u32) void {
        _ = texture;
        _ = index;
        _ = self;
    }

    pub fn setSampler(self: *ComputeEncoder, sampler: SamplerHandle, index: u32) void {
        _ = sampler;
        _ = index;
        _ = self;
    }

    pub fn setThreadgroupMemoryLength(self: *ComputeEncoder, length: u32, index: u32) void {
        _ = length;
        _ = index;
        _ = self;
    }

    pub fn dispatchThreadgroups(self: *ComputeEncoder, threadgroups_per_grid: [3]u32, threads_per_threadgroup: [3]u32) void {
        _ = threadgroups_per_grid;
        _ = threads_per_threadgroup;
        self.backend.stats.compute_dispatches += 1;
    }

    pub fn dispatchThreads(self: *ComputeEncoder, threads_per_grid: [3]u32, threads_per_threadgroup: [3]u32) void {
        _ = threads_per_grid;
        _ = threads_per_threadgroup;
        self.backend.stats.compute_dispatches += 1;
    }

    pub fn endEncoding(self: *ComputeEncoder) void {
        self.backend.current_compute_encoder = null;
    }
};

/// Blit command encoder wrapper
pub const BlitEncoder = struct {
    backend: *MetalBackend,

    pub fn copyFromBuffer(self: *BlitEncoder, source: BufferHandle, source_offset: u32, dest: BufferHandle, dest_offset: u32, size: u32) void {
        _ = source;
        _ = source_offset;
        _ = dest;
        _ = dest_offset;
        _ = size;
        _ = self;
    }

    pub fn copyFromTexture(self: *BlitEncoder, source: TextureHandle, dest: TextureHandle) void {
        _ = source;
        _ = dest;
        _ = self;
    }

    pub fn generateMipmaps(self: *BlitEncoder, texture: TextureHandle) void {
        _ = texture;
        _ = self;
    }

    pub fn synchronizeResource(self: *BlitEncoder, buffer: BufferHandle) void {
        _ = buffer;
        _ = self;
    }

    pub fn synchronizeTexture(self: *BlitEncoder, texture: TextureHandle, slice: u32, level: u32) void {
        _ = texture;
        _ = slice;
        _ = level;
        _ = self;
    }

    pub fn endEncoding(self: *BlitEncoder) void {
        _ = self;
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
    compute_dispatches: u32 = 0,

    buffers_created: u64 = 0,
    textures_created: u64 = 0,
    samplers_created: u64 = 0,
    pipelines_created: u64 = 0,
    depth_stencil_states_created: u64 = 0,

    buffer_memory: usize = 0,
    texture_memory: usize = 0,

    pub fn getTotalMemory(self: BackendStats) usize {
        return self.buffer_memory + self.texture_memory;
    }
};

// ============================================================================
// Utility Functions
// ============================================================================

/// Create a vertex descriptor for standard PBR vertex
pub fn createPBRVertexDescriptor() VertexDescriptor {
    var desc = VertexDescriptor{};

    // Position (float3)
    desc.attributes[0] = .{ .format = .float3, .offset = 0, .buffer_index = 0 };
    // Normal (float3)
    desc.attributes[1] = .{ .format = .float3, .offset = 12, .buffer_index = 0 };
    // UV (float2)
    desc.attributes[2] = .{ .format = .float2, .offset = 24, .buffer_index = 0 };
    // Tangent (float4)
    desc.attributes[3] = .{ .format = .float4, .offset = 32, .buffer_index = 0 };

    desc.layouts[0] = .{ .stride = 48, .step_function = .per_vertex };

    return desc;
}

/// Create a simple unlit vertex descriptor
pub fn createSimpleVertexDescriptor() VertexDescriptor {
    var desc = VertexDescriptor{};

    // Position (float3)
    desc.attributes[0] = .{ .format = .float3, .offset = 0, .buffer_index = 0 };
    // Color (float4)
    desc.attributes[1] = .{ .format = .float4, .offset = 12, .buffer_index = 0 };

    desc.layouts[0] = .{ .stride = 28, .step_function = .per_vertex };

    return desc;
}

/// Create default sampler descriptor
pub fn createDefaultSamplerDescriptor() SamplerDescriptor {
    return .{
        .min_filter = .linear,
        .mag_filter = .linear,
        .mip_filter = .linear,
        .s_address_mode = .repeat,
        .t_address_mode = .repeat,
        .max_anisotropy = 16,
    };
}

/// Create shadow map sampler descriptor
pub fn createShadowSamplerDescriptor() SamplerDescriptor {
    return .{
        .min_filter = .linear,
        .mag_filter = .linear,
        .mip_filter = .not_mipmapped,
        .s_address_mode = .clamp_to_edge,
        .t_address_mode = .clamp_to_edge,
        .compare_function = .less_equal,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "MetalBackend initialization" {
    const allocator = std.testing.allocator;
    var backend = MetalBackend.init(allocator);
    defer backend.deinit();

    const caps = backend.getCapabilities();
    try std.testing.expect(caps.max_texture_size_2d > 0);
}

test "MetalBackend buffer creation" {
    const allocator = std.testing.allocator;
    var backend = MetalBackend.init(allocator);
    defer backend.deinit();

    const buffer = try backend.createBuffer(1024, .{});
    try std.testing.expect(buffer.isValid());
    try std.testing.expect(buffer.size == 1024);
}

test "MetalBackend texture creation" {
    const allocator = std.testing.allocator;
    var backend = MetalBackend.init(allocator);
    defer backend.deinit();

    const texture = try backend.createTexture(.{
        .width = 512,
        .height = 512,
        .pixel_format = .rgba8_unorm,
    });
    try std.testing.expect(texture.isValid());
    try std.testing.expect(texture.width == 512);
    try std.testing.expect(texture.height == 512);
}

test "MetalBackend statistics" {
    const allocator = std.testing.allocator;
    var backend = MetalBackend.init(allocator);
    defer backend.deinit();

    backend.beginFrame();

    var encoder = try backend.beginRenderPass(.{});
    encoder.drawPrimitives(.triangle, 0, 36);
    encoder.drawPrimitives(.triangle, 0, 24);
    encoder.endEncoding();

    backend.endFrame();

    const stats = backend.getStats();
    try std.testing.expect(stats.draw_calls == 2);
    try std.testing.expect(stats.vertices == 60);
    try std.testing.expect(stats.triangles == 20);
}

test "PixelFormat byte sizes" {
    try std.testing.expect(PixelFormat.r8_unorm.bytesPerPixel() == 1);
    try std.testing.expect(PixelFormat.rg8_unorm.bytesPerPixel() == 2);
    try std.testing.expect(PixelFormat.rgba8_unorm.bytesPerPixel() == 4);
    try std.testing.expect(PixelFormat.rgba16_float.bytesPerPixel() == 8);
    try std.testing.expect(PixelFormat.rgba32_float.bytesPerPixel() == 16);
}

test "VertexFormat sizes" {
    try std.testing.expect(VertexFormat.float.size() == 4);
    try std.testing.expect(VertexFormat.float2.size() == 8);
    try std.testing.expect(VertexFormat.float3.size() == 12);
    try std.testing.expect(VertexFormat.float4.size() == 16);
}

test "PBR vertex descriptor" {
    const desc = createPBRVertexDescriptor();
    try std.testing.expect(desc.layouts[0].stride == 48);
    try std.testing.expect(desc.attributes[0].format == .float3);
    try std.testing.expect(desc.attributes[1].format == .float3);
    try std.testing.expect(desc.attributes[2].format == .float2);
    try std.testing.expect(desc.attributes[3].format == .float4);
}
