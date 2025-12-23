//! Zylix Post-Processing Pipeline
//!
//! Comprehensive post-processing effects system including HDR, bloom,
//! SSAO, motion blur, depth of field, and color grading.
//!
//! ## Features
//! - **HDR/Tone Mapping**: ACES, Reinhard, Uncharted2 tone mappers
//! - **Bloom**: Multi-pass gaussian bloom with threshold control
//! - **SSAO**: Screen-space ambient occlusion for contact shadows
//! - **Motion Blur**: Per-object and camera motion blur
//! - **Depth of Field**: Bokeh-style depth of field
//! - **Color Grading**: LUT-based color correction
//! - **Anti-Aliasing**: FXAA, TAA support
//! - **Additional Effects**: Vignette, film grain, chromatic aberration
//!
//! ## Example
//! ```zig
//! const pp = @import("postprocess.zig");
//!
//! // Create post-processing pipeline
//! var pipeline = pp.PostProcessPipeline.init(allocator, 1920, 1080);
//! defer pipeline.deinit();
//!
//! // Add effects
//! pipeline.addEffect(.bloom, .{ .threshold = 1.0, .intensity = 0.5 });
//! pipeline.addEffect(.tone_mapping, .{ .method = .aces });
//! pipeline.addEffect(.fxaa, .{});
//!
//! // Process frame
//! pipeline.process(&render_target);
//! ```

const std = @import("std");
const types = @import("types.zig");
const Vec2 = types.Vec2;
const Vec3 = types.Vec3;
const Vec4 = types.Vec4;
const Mat4 = types.Mat4;
const Color = types.Color;

// ============================================================================
// Effect Types
// ============================================================================

/// Available post-processing effects
pub const EffectType = enum {
    tone_mapping,
    bloom,
    ssao,
    motion_blur,
    depth_of_field,
    color_grading,
    fxaa,
    taa,
    vignette,
    film_grain,
    chromatic_aberration,
    sharpening,
    fog,
    outline,
};

/// Tone mapping algorithms
pub const ToneMapper = enum {
    none,
    reinhard,
    reinhard_extended,
    aces,
    aces_approx,
    uncharted2,
    neutral,
    agx,

    /// Apply tone mapping to HDR color
    pub fn apply(self: ToneMapper, hdr: Vec3, exposure: f32) Vec3 {
        const exposed = hdr.scale(exposure);

        return switch (self) {
            .none => exposed,
            .reinhard => reinhardToneMap(exposed),
            .reinhard_extended => reinhardExtendedToneMap(exposed, 4.0),
            .aces => acesToneMap(exposed),
            .aces_approx => acesApproxToneMap(exposed),
            .uncharted2 => uncharted2ToneMap(exposed),
            .neutral => neutralToneMap(exposed),
            .agx => agxToneMap(exposed),
        };
    }
};

/// Reinhard tone mapping
fn reinhardToneMap(hdr: Vec3) Vec3 {
    return Vec3.init(
        hdr.x / (1.0 + hdr.x),
        hdr.y / (1.0 + hdr.y),
        hdr.z / (1.0 + hdr.z),
    );
}

/// Reinhard extended tone mapping with white point
fn reinhardExtendedToneMap(hdr: Vec3, white_point: f32) Vec3 {
    const wp2 = white_point * white_point;
    return Vec3.init(
        hdr.x * (1.0 + hdr.x / wp2) / (1.0 + hdr.x),
        hdr.y * (1.0 + hdr.y / wp2) / (1.0 + hdr.y),
        hdr.z * (1.0 + hdr.z / wp2) / (1.0 + hdr.z),
    );
}

/// ACES filmic tone mapping (full transform)
fn acesToneMap(hdr: Vec3) Vec3 {
    // ACES input transform matrix
    const aces_input = Mat4{ .data = .{
        0.59719, 0.35458, 0.04823, 0,
        0.07600, 0.90834, 0.01566, 0,
        0.02840, 0.13383, 0.83777, 0,
        0,       0,       0,       1,
    } };

    // ACES output transform matrix
    const aces_output = Mat4{ .data = .{
        1.60475,  -0.53108, -0.07367, 0,
        -0.10208, 1.10813,  -0.00605, 0,
        -0.00327, -0.07276, 1.07602,  0,
        0,        0,        0,        1,
    } };

    // Apply input transform
    var v = Vec4.init(hdr.x, hdr.y, hdr.z, 0);
    v = aces_input.transformVec4(v);

    // RRT and ODT fit
    const a = v.x * (v.x + 0.0245786) - 0.000090537;
    const b = v.x * (0.983729 * v.x + 0.4329510) + 0.238081;
    const rx = a / b;

    const a2 = v.y * (v.y + 0.0245786) - 0.000090537;
    const b2 = v.y * (0.983729 * v.y + 0.4329510) + 0.238081;
    const ry = a2 / b2;

    const a3 = v.z * (v.z + 0.0245786) - 0.000090537;
    const b3 = v.z * (0.983729 * v.z + 0.4329510) + 0.238081;
    const rz = a3 / b3;

    // Apply output transform
    var result = Vec4.init(rx, ry, rz, 0);
    result = aces_output.transformVec4(result);

    return Vec3.init(
        std.math.clamp(result.x, 0, 1),
        std.math.clamp(result.y, 0, 1),
        std.math.clamp(result.z, 0, 1),
    );
}

/// ACES approximation (faster)
fn acesApproxToneMap(hdr: Vec3) Vec3 {
    const a: f32 = 2.51;
    const b: f32 = 0.03;
    const c: f32 = 2.43;
    const d: f32 = 0.59;
    const e: f32 = 0.14;

    return Vec3.init(
        std.math.clamp((hdr.x * (a * hdr.x + b)) / (hdr.x * (c * hdr.x + d) + e), 0, 1),
        std.math.clamp((hdr.y * (a * hdr.y + b)) / (hdr.y * (c * hdr.y + d) + e), 0, 1),
        std.math.clamp((hdr.z * (a * hdr.z + b)) / (hdr.z * (c * hdr.z + d) + e), 0, 1),
    );
}

/// Uncharted 2 tone mapping
fn uncharted2ToneMap(hdr: Vec3) Vec3 {
    const A: f32 = 0.15; // Shoulder strength
    const B: f32 = 0.50; // Linear strength
    const C: f32 = 0.10; // Linear angle
    const D: f32 = 0.20; // Toe strength
    const E: f32 = 0.02; // Toe numerator
    const F: f32 = 0.30; // Toe denominator
    const W: f32 = 11.2; // White point

    const uc2 = struct {
        fn tonemap(x: f32) f32 {
            return ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F;
        }
    };

    const white_scale = 1.0 / uc2.tonemap(W);

    return Vec3.init(
        uc2.tonemap(hdr.x) * white_scale,
        uc2.tonemap(hdr.y) * white_scale,
        uc2.tonemap(hdr.z) * white_scale,
    );
}

/// Neutral tone mapping (balanced)
fn neutralToneMap(hdr: Vec3) Vec3 {
    const x = @max(hdr.x, 0.0);
    const y = @max(hdr.y, 0.0);
    const z = @max(hdr.z, 0.0);

    return Vec3.init(
        x / (x + 1.0),
        y / (y + 1.0),
        z / (z + 1.0),
    );
}

/// AgX tone mapping (modern approach)
fn agxToneMap(hdr: Vec3) Vec3 {
    // Simplified AgX approximation
    const agx_mat = Mat4{ .data = .{
        0.842479, 0.0784336, 0.0792237, 0,
        0.0423303, 0.878468, 0.0791916, 0,
        0.0423443, 0.0784336, 0.879142, 0,
        0,         0,         0,         1,
    } };

    var v = Vec4.init(hdr.x, hdr.y, hdr.z, 0);
    v = agx_mat.transformVec4(v);

    // Apply sigmoid
    const sigmoid = struct {
        fn apply(x: f32) f32 {
            return 1.0 / (1.0 + @exp(-x));
        }
    };

    return Vec3.init(
        sigmoid.apply(v.x),
        sigmoid.apply(v.y),
        sigmoid.apply(v.z),
    );
}

// ============================================================================
// Effect Settings
// ============================================================================

/// Tone mapping settings
pub const ToneMappingSettings = struct {
    method: ToneMapper = .aces_approx,
    exposure: f32 = 1.0,
    gamma: f32 = 2.2,
    enabled: bool = true,
};

/// Bloom settings
pub const BloomSettings = struct {
    enabled: bool = true,
    threshold: f32 = 1.0,
    soft_threshold: f32 = 0.5,
    intensity: f32 = 0.5,
    radius: f32 = 1.0,
    mip_levels: u32 = 5,
    dirt_intensity: f32 = 0.0,
};

/// SSAO settings
pub const SSAOSettings = struct {
    enabled: bool = true,
    radius: f32 = 0.5,
    bias: f32 = 0.025,
    intensity: f32 = 1.0,
    sample_count: u32 = 64,
    blur_passes: u32 = 2,
    power: f32 = 2.0,
};

/// Motion blur settings
pub const MotionBlurSettings = struct {
    enabled: bool = false,
    intensity: f32 = 1.0,
    sample_count: u32 = 8,
    max_blur: f32 = 0.05,
    velocity_scale: f32 = 1.0,
    camera_motion: bool = true,
    object_motion: bool = true,
};

/// Depth of field settings
pub const DepthOfFieldSettings = struct {
    enabled: bool = false,
    focus_distance: f32 = 10.0,
    focus_range: f32 = 5.0,
    bokeh_size: f32 = 4.0,
    aperture: f32 = 0.05,
    blade_count: u32 = 6,
    circular_bokeh: bool = true,
};

/// Color grading settings
pub const ColorGradingSettings = struct {
    enabled: bool = false,
    saturation: f32 = 1.0,
    contrast: f32 = 1.0,
    brightness: f32 = 0.0,
    temperature: f32 = 0.0, // -1 to 1 (cool to warm)
    tint: f32 = 0.0, // -1 to 1 (green to magenta)
    shadows: Color = Color.rgba(0, 0, 0, 1),
    midtones: Color = Color.rgba(0.5, 0.5, 0.5, 1),
    highlights: Color = Color.rgba(1, 1, 1, 1),
    lift: Vec3 = Vec3.zero(),
    gamma_adjust: Vec3 = Vec3.init(1, 1, 1),
    gain: Vec3 = Vec3.init(1, 1, 1),
};

/// FXAA settings
pub const FXAASettings = struct {
    enabled: bool = true,
    quality: FXAAQuality = .medium,
    subpixel: f32 = 0.75,
    edge_threshold: f32 = 0.166,
    edge_threshold_min: f32 = 0.0833,
};

/// FXAA quality presets
pub const FXAAQuality = enum {
    low,
    medium,
    high,
    ultra,

    pub fn getSearchSteps(self: FXAAQuality) u32 {
        return switch (self) {
            .low => 4,
            .medium => 8,
            .high => 12,
            .ultra => 16,
        };
    }
};

/// TAA settings
pub const TAASettings = struct {
    enabled: bool = false,
    feedback: f32 = 0.9,
    sharpness: f32 = 0.25,
    motion_weight: f32 = 0.5,
    velocity_weight: f32 = 0.5,
};

/// Vignette settings
pub const VignetteSettings = struct {
    enabled: bool = false,
    intensity: f32 = 0.3,
    smoothness: f32 = 0.3,
    roundness: f32 = 1.0,
    color: Color = Color.rgba(0, 0, 0, 1),
};

/// Film grain settings
pub const FilmGrainSettings = struct {
    enabled: bool = false,
    intensity: f32 = 0.1,
    response: f32 = 0.8,
    luminance_factor: f32 = 1.0,
};

/// Chromatic aberration settings
pub const ChromaticAberrationSettings = struct {
    enabled: bool = false,
    intensity: f32 = 1.0,
    samples: u32 = 3,
};

/// Sharpening settings
pub const SharpeningSettings = struct {
    enabled: bool = false,
    intensity: f32 = 0.5,
    threshold: f32 = 0.1,
};

/// Fog settings
pub const FogSettings = struct {
    enabled: bool = false,
    color: Color = Color.rgba(0.7, 0.7, 0.8, 1),
    density: f32 = 0.01,
    start: f32 = 0.0,
    end: f32 = 100.0,
    mode: FogMode = .exponential,
    height_falloff: f32 = 0.1,
};

/// Fog calculation modes
pub const FogMode = enum {
    linear,
    exponential,
    exponential_squared,
    height,
};

/// Outline settings
pub const OutlineSettings = struct {
    enabled: bool = false,
    color: Color = Color.rgba(0, 0, 0, 1),
    thickness: f32 = 1.0,
    depth_threshold: f32 = 0.1,
    normal_threshold: f32 = 0.5,
};

// ============================================================================
// Render Target
// ============================================================================

/// Render target format
pub const RenderTargetFormat = enum {
    rgba8,
    rgba16f,
    rgba32f,
    r11g11b10f,
    rg16f,
    r32f,
    depth24_stencil8,
    depth32f,
};

/// Render target for post-processing
pub const RenderTarget = struct {
    width: u32,
    height: u32,
    format: RenderTargetFormat,
    handle: u64 = 0,
    data: ?[]u8 = null,
    mip_levels: u32 = 1,

    pub fn init(width: u32, height: u32, format: RenderTargetFormat) RenderTarget {
        return .{
            .width = width,
            .height = height,
            .format = format,
        };
    }

    pub fn initWithMips(width: u32, height: u32, format: RenderTargetFormat, mip_levels: u32) RenderTarget {
        return .{
            .width = width,
            .height = height,
            .format = format,
            .mip_levels = mip_levels,
        };
    }

    pub fn getByteSize(self: RenderTarget) usize {
        const pixel_size: usize = switch (self.format) {
            .rgba8 => 4,
            .rgba16f => 8,
            .rgba32f => 16,
            .r11g11b10f => 4,
            .rg16f => 4,
            .r32f => 4,
            .depth24_stencil8 => 4,
            .depth32f => 4,
        };

        var total: usize = 0;
        var w = self.width;
        var h = self.height;
        var level: u32 = 0;
        while (level < self.mip_levels) : (level += 1) {
            total += @as(usize, w) * @as(usize, h) * pixel_size;
            w = @max(1, w / 2);
            h = @max(1, h / 2);
        }

        return total;
    }
};

// ============================================================================
// Post-Process Pass
// ============================================================================

/// Single post-processing pass
pub const PostProcessPass = struct {
    effect_type: EffectType,
    enabled: bool = true,
    input_targets: [4]?*RenderTarget = .{ null, null, null, null },
    output_target: ?*RenderTarget = null,
    settings: PassSettings,

    pub const PassSettings = union(EffectType) {
        tone_mapping: ToneMappingSettings,
        bloom: BloomSettings,
        ssao: SSAOSettings,
        motion_blur: MotionBlurSettings,
        depth_of_field: DepthOfFieldSettings,
        color_grading: ColorGradingSettings,
        fxaa: FXAASettings,
        taa: TAASettings,
        vignette: VignetteSettings,
        film_grain: FilmGrainSettings,
        chromatic_aberration: ChromaticAberrationSettings,
        sharpening: SharpeningSettings,
        fog: FogSettings,
        outline: OutlineSettings,
    };
};

// ============================================================================
// Post-Process Pipeline
// ============================================================================

/// Complete post-processing pipeline
pub const PostProcessPipeline = struct {
    allocator: std.mem.Allocator,
    width: u32,
    height: u32,
    passes: std.ArrayListUnmanaged(PostProcessPass) = .{},

    // Internal render targets
    hdr_buffer: RenderTarget,
    bloom_buffers: [8]RenderTarget,
    ssao_buffer: RenderTarget,
    temp_buffers: [2]RenderTarget,
    depth_buffer: RenderTarget,
    velocity_buffer: RenderTarget,
    history_buffer: RenderTarget,

    // Global settings
    enabled: bool = true,
    hdr_enabled: bool = true,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) PostProcessPipeline {
        var bloom_buffers: [8]RenderTarget = undefined;
        var w = width;
        var h = height;
        for (0..8) |i| {
            bloom_buffers[i] = RenderTarget.init(w, h, .rgba16f);
            w = @max(1, w / 2);
            h = @max(1, h / 2);
        }

        return .{
            .allocator = allocator,
            .width = width,
            .height = height,
            .hdr_buffer = RenderTarget.init(width, height, .rgba16f),
            .bloom_buffers = bloom_buffers,
            .ssao_buffer = RenderTarget.init(width, height, .r32f),
            .temp_buffers = .{
                RenderTarget.init(width, height, .rgba16f),
                RenderTarget.init(width, height, .rgba16f),
            },
            .depth_buffer = RenderTarget.init(width, height, .depth32f),
            .velocity_buffer = RenderTarget.init(width, height, .rg16f),
            .history_buffer = RenderTarget.init(width, height, .rgba16f),
        };
    }

    pub fn deinit(self: *PostProcessPipeline) void {
        self.passes.deinit(self.allocator);
    }

    /// Add a post-processing pass
    pub fn addPass(self: *PostProcessPipeline, pass: PostProcessPass) !void {
        try self.passes.append(self.allocator, pass);
    }

    /// Add effect with settings
    pub fn addEffect(self: *PostProcessPipeline, effect_type: EffectType, settings: PostProcessPass.PassSettings) !void {
        try self.passes.append(self.allocator, .{
            .effect_type = effect_type,
            .settings = settings,
        });
    }

    /// Remove effect by type
    pub fn removeEffect(self: *PostProcessPipeline, effect_type: EffectType) void {
        var i: usize = 0;
        while (i < self.passes.items.len) {
            if (self.passes.items[i].effect_type == effect_type) {
                _ = self.passes.orderedRemove(i);
            } else {
                i += 1;
            }
        }
    }

    /// Get effect settings
    pub fn getEffectSettings(self: *PostProcessPipeline, effect_type: EffectType) ?*PostProcessPass.PassSettings {
        for (self.passes.items) |*pass| {
            if (pass.effect_type == effect_type) {
                return &pass.settings;
            }
        }
        return null;
    }

    /// Toggle effect
    pub fn toggleEffect(self: *PostProcessPipeline, effect_type: EffectType, enabled: bool) void {
        for (self.passes.items) |*pass| {
            if (pass.effect_type == effect_type) {
                pass.enabled = enabled;
            }
        }
    }

    /// Resize pipeline
    pub fn resize(self: *PostProcessPipeline, width: u32, height: u32) void {
        self.width = width;
        self.height = height;

        self.hdr_buffer = RenderTarget.init(width, height, .rgba16f);
        self.ssao_buffer = RenderTarget.init(width, height, .r32f);
        self.temp_buffers[0] = RenderTarget.init(width, height, .rgba16f);
        self.temp_buffers[1] = RenderTarget.init(width, height, .rgba16f);
        self.depth_buffer = RenderTarget.init(width, height, .depth32f);
        self.velocity_buffer = RenderTarget.init(width, height, .rg16f);
        self.history_buffer = RenderTarget.init(width, height, .rgba16f);

        var w = width;
        var h = height;
        for (0..8) |i| {
            self.bloom_buffers[i] = RenderTarget.init(w, h, .rgba16f);
            w = @max(1, w / 2);
            h = @max(1, h / 2);
        }
    }

    /// Process frame (CPU reference implementation)
    pub fn process(self: *PostProcessPipeline, input: *RenderTarget) *RenderTarget {
        if (!self.enabled) return input;

        var current = input;

        for (self.passes.items) |*pass| {
            if (!pass.enabled) continue;

            current = self.executePass(pass, current);
        }

        return current;
    }

    fn executePass(self: *PostProcessPipeline, pass: *PostProcessPass, input: *RenderTarget) *RenderTarget {
        _ = self;
        // In actual implementation, this would dispatch to GPU shaders
        // Here we just return input as placeholder
        pass.input_targets[0] = input;
        return pass.output_target orelse input;
    }

    /// Get pass count
    pub fn getPassCount(self: PostProcessPipeline) usize {
        return self.passes.items.len;
    }

    /// Get enabled pass count
    pub fn getEnabledPassCount(self: PostProcessPipeline) usize {
        var count: usize = 0;
        for (self.passes.items) |pass| {
            if (pass.enabled) count += 1;
        }
        return count;
    }
};

// ============================================================================
// Preset Configurations
// ============================================================================

/// Post-processing quality preset
pub const PostProcessPreset = enum {
    minimal,
    low,
    medium,
    high,
    ultra,
    cinematic,

    /// Create pipeline with preset
    pub fn createPipeline(self: PostProcessPreset, allocator: std.mem.Allocator, width: u32, height: u32) !PostProcessPipeline {
        var pipeline = PostProcessPipeline.init(allocator, width, height);

        switch (self) {
            .minimal => {
                try pipeline.addEffect(.tone_mapping, .{ .tone_mapping = .{
                    .method = .aces_approx,
                    .exposure = 1.0,
                } });
            },
            .low => {
                try pipeline.addEffect(.tone_mapping, .{ .tone_mapping = .{
                    .method = .aces_approx,
                } });
                try pipeline.addEffect(.fxaa, .{ .fxaa = .{
                    .quality = .low,
                } });
            },
            .medium => {
                try pipeline.addEffect(.bloom, .{ .bloom = .{
                    .intensity = 0.3,
                    .mip_levels = 4,
                } });
                try pipeline.addEffect(.tone_mapping, .{ .tone_mapping = .{
                    .method = .aces,
                } });
                try pipeline.addEffect(.fxaa, .{ .fxaa = .{
                    .quality = .medium,
                } });
            },
            .high => {
                try pipeline.addEffect(.ssao, .{ .ssao = .{
                    .sample_count = 32,
                } });
                try pipeline.addEffect(.bloom, .{ .bloom = .{
                    .intensity = 0.4,
                    .mip_levels = 5,
                } });
                try pipeline.addEffect(.tone_mapping, .{ .tone_mapping = .{
                    .method = .aces,
                } });
                try pipeline.addEffect(.fxaa, .{ .fxaa = .{
                    .quality = .high,
                } });
                try pipeline.addEffect(.vignette, .{ .vignette = .{
                    .intensity = 0.2,
                    .enabled = true,
                } });
            },
            .ultra => {
                try pipeline.addEffect(.ssao, .{ .ssao = .{
                    .sample_count = 64,
                    .radius = 0.6,
                } });
                try pipeline.addEffect(.bloom, .{ .bloom = .{
                    .intensity = 0.5,
                    .mip_levels = 6,
                } });
                try pipeline.addEffect(.depth_of_field, .{ .depth_of_field = .{
                    .enabled = true,
                } });
                try pipeline.addEffect(.color_grading, .{ .color_grading = .{
                    .enabled = true,
                    .contrast = 1.1,
                } });
                try pipeline.addEffect(.tone_mapping, .{ .tone_mapping = .{
                    .method = .aces,
                } });
                try pipeline.addEffect(.fxaa, .{ .fxaa = .{
                    .quality = .ultra,
                } });
                try pipeline.addEffect(.sharpening, .{ .sharpening = .{
                    .enabled = true,
                    .intensity = 0.3,
                } });
            },
            .cinematic => {
                try pipeline.addEffect(.ssao, .{ .ssao = .{
                    .sample_count = 64,
                } });
                try pipeline.addEffect(.motion_blur, .{ .motion_blur = .{
                    .enabled = true,
                    .intensity = 0.5,
                } });
                try pipeline.addEffect(.bloom, .{ .bloom = .{
                    .intensity = 0.6,
                    .mip_levels = 6,
                } });
                try pipeline.addEffect(.depth_of_field, .{ .depth_of_field = .{
                    .enabled = true,
                    .bokeh_size = 6.0,
                } });
                try pipeline.addEffect(.color_grading, .{ .color_grading = .{
                    .enabled = true,
                    .contrast = 1.15,
                    .saturation = 0.9,
                } });
                try pipeline.addEffect(.tone_mapping, .{ .tone_mapping = .{
                    .method = .aces,
                    .exposure = 1.1,
                } });
                try pipeline.addEffect(.chromatic_aberration, .{ .chromatic_aberration = .{
                    .enabled = true,
                    .intensity = 0.5,
                } });
                try pipeline.addEffect(.film_grain, .{ .film_grain = .{
                    .enabled = true,
                    .intensity = 0.05,
                } });
                try pipeline.addEffect(.vignette, .{ .vignette = .{
                    .enabled = true,
                    .intensity = 0.35,
                } });
            },
        }

        return pipeline;
    }
};

// ============================================================================
// Utility Functions
// ============================================================================

/// Apply gamma correction
pub fn gammaCorrect(color: Vec3, gamma: f32) Vec3 {
    const inv_gamma = 1.0 / gamma;
    return Vec3.init(
        std.math.pow(color.x, inv_gamma),
        std.math.pow(color.y, inv_gamma),
        std.math.pow(color.z, inv_gamma),
    );
}

/// Linear to sRGB
pub fn linearToSRGB(color: Vec3) Vec3 {
    const srgb = struct {
        fn convert(c: f32) f32 {
            if (c <= 0.0031308) {
                return c * 12.92;
            } else {
                return 1.055 * std.math.pow(c, 1.0 / 2.4) - 0.055;
            }
        }
    };

    return Vec3.init(
        srgb.convert(color.x),
        srgb.convert(color.y),
        srgb.convert(color.z),
    );
}

/// sRGB to Linear
pub fn sRGBToLinear(color: Vec3) Vec3 {
    const linear = struct {
        fn convert(c: f32) f32 {
            if (c <= 0.04045) {
                return c / 12.92;
            } else {
                return std.math.pow((c + 0.055) / 1.055, 2.4);
            }
        }
    };

    return Vec3.init(
        linear.convert(color.x),
        linear.convert(color.y),
        linear.convert(color.z),
    );
}

/// Calculate luminance
pub fn luminance(color: Vec3) f32 {
    return color.x * 0.2126 + color.y * 0.7152 + color.z * 0.0722;
}

/// Apply saturation adjustment
pub fn adjustSaturation(color: Vec3, saturation: f32) Vec3 {
    const lum = luminance(color);
    return Vec3.init(
        lum + (color.x - lum) * saturation,
        lum + (color.y - lum) * saturation,
        lum + (color.z - lum) * saturation,
    );
}

/// Apply contrast adjustment
pub fn adjustContrast(color: Vec3, contrast: f32) Vec3 {
    return Vec3.init(
        (color.x - 0.5) * contrast + 0.5,
        (color.y - 0.5) * contrast + 0.5,
        (color.z - 0.5) * contrast + 0.5,
    );
}

/// Apply brightness adjustment
pub fn adjustBrightness(color: Vec3, brightness: f32) Vec3 {
    return Vec3.init(
        color.x + brightness,
        color.y + brightness,
        color.z + brightness,
    );
}

/// Apply vignette
pub fn applyVignette(color: Vec3, uv: Vec2, settings: VignetteSettings) Vec3 {
    const center = Vec2.init(0.5, 0.5);
    const dist = uv.sub(center).length() * 2.0;
    const vignette = std.math.clamp(
        1.0 - std.math.pow(dist * settings.intensity, 1.0 / settings.smoothness),
        0,
        1,
    );
    return color.scale(vignette);
}

/// Generate film grain
pub fn generateFilmGrain(uv: Vec2, time: f32, intensity: f32) f32 {
    // Simple pseudo-random noise
    const noise = struct {
        fn hash(p: Vec2) f32 {
            const h = p.dot(Vec2.init(127.1, 311.7));
            return @mod(h, 1.0);
        }
    };

    const n = noise.hash(Vec2.init(uv.x + time, uv.y + time * 1.3));
    return (n - 0.5) * intensity;
}

// ============================================================================
// SSAO Kernel Generation
// ============================================================================

/// SSAO sample kernel
pub const SSAOKernel = struct {
    samples: [64]Vec3,
    sample_count: u32,

    pub fn init(count: u32) SSAOKernel {
        var kernel = SSAOKernel{
            .samples = undefined,
            .sample_count = @min(count, 64),
        };

        // Generate hemisphere samples
        var prng = std.Random.DefaultPrng.init(0);
        const random = prng.random();

        for (0..kernel.sample_count) |i| {
            // Random point on hemisphere
            var sample = Vec3.init(
                random.float(f32) * 2.0 - 1.0,
                random.float(f32) * 2.0 - 1.0,
                random.float(f32),
            );
            sample = sample.normalize();

            // Scale by random length
            var scale: f32 = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(kernel.sample_count));
            scale = lerp(0.1, 1.0, scale * scale);
            sample = sample.scale(scale);

            kernel.samples[i] = sample;
        }

        return kernel;
    }
};

fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * t;
}

// ============================================================================
// Gaussian Blur
// ============================================================================

/// Gaussian blur weights
pub const GaussianKernel = struct {
    weights: [32]f32,
    offsets: [32]f32,
    size: u32,

    pub fn init(radius: f32, sample_count: u32) GaussianKernel {
        var kernel = GaussianKernel{
            .weights = undefined,
            .offsets = undefined,
            .size = @min(sample_count, 32),
        };

        const sigma = radius / 3.0;
        var total: f32 = 0;

        for (0..kernel.size) |i| {
            const x = @as(f32, @floatFromInt(i));
            const weight = gaussian(x, sigma);
            kernel.weights[i] = weight;
            kernel.offsets[i] = x;
            total += if (i == 0) weight else weight * 2;
        }

        // Normalize
        for (0..kernel.size) |i| {
            kernel.weights[i] /= total;
        }

        return kernel;
    }

    fn gaussian(x: f32, sigma: f32) f32 {
        return @exp(-(x * x) / (2.0 * sigma * sigma));
    }
};

// ============================================================================
// Tests
// ============================================================================

test "ToneMapper operations" {
    const hdr = Vec3.init(2.0, 1.5, 0.8);

    // Test Reinhard
    const reinhard = ToneMapper.reinhard.apply(hdr, 1.0);
    try std.testing.expect(reinhard.x < 1.0);
    try std.testing.expect(reinhard.y < 1.0);

    // Test ACES
    const aces = ToneMapper.aces_approx.apply(hdr, 1.0);
    try std.testing.expect(aces.x >= 0 and aces.x <= 1.0);
    try std.testing.expect(aces.y >= 0 and aces.y <= 1.0);
    try std.testing.expect(aces.z >= 0 and aces.z <= 1.0);
}

test "PostProcessPipeline initialization" {
    const allocator = std.testing.allocator;
    var pipeline = PostProcessPipeline.init(allocator, 1920, 1080);
    defer pipeline.deinit();

    try std.testing.expect(pipeline.width == 1920);
    try std.testing.expect(pipeline.height == 1080);
    try std.testing.expect(pipeline.getPassCount() == 0);
}

test "PostProcessPipeline add effects" {
    const allocator = std.testing.allocator;
    var pipeline = PostProcessPipeline.init(allocator, 1920, 1080);
    defer pipeline.deinit();

    try pipeline.addEffect(.bloom, .{ .bloom = .{
        .intensity = 0.5,
    } });
    try pipeline.addEffect(.tone_mapping, .{ .tone_mapping = .{
        .method = .aces,
    } });

    try std.testing.expect(pipeline.getPassCount() == 2);
}

test "PostProcessPreset creation" {
    const allocator = std.testing.allocator;

    // Test minimal preset
    var minimal = try PostProcessPreset.minimal.createPipeline(allocator, 1280, 720);
    defer minimal.deinit();
    try std.testing.expect(minimal.getPassCount() >= 1);

    // Test high preset
    var high = try PostProcessPreset.high.createPipeline(allocator, 1920, 1080);
    defer high.deinit();
    try std.testing.expect(high.getPassCount() > minimal.getPassCount());
}

test "color utility functions" {
    // Test luminance
    const white = Vec3.init(1, 1, 1);
    try std.testing.expect(@abs(luminance(white) - 1.0) < 0.01);

    const black = Vec3.init(0, 0, 0);
    try std.testing.expect(luminance(black) == 0);

    // Test saturation
    const gray = adjustSaturation(Vec3.init(1, 0.5, 0.5), 0);
    const lum = luminance(Vec3.init(1, 0.5, 0.5));
    try std.testing.expect(@abs(gray.x - lum) < 0.01);
    try std.testing.expect(@abs(gray.y - lum) < 0.01);
    try std.testing.expect(@abs(gray.z - lum) < 0.01);
}

test "RenderTarget byte size calculation" {
    const rt = RenderTarget.init(1024, 1024, .rgba8);
    try std.testing.expect(rt.getByteSize() == 1024 * 1024 * 4);

    const rt_hdr = RenderTarget.init(1024, 1024, .rgba16f);
    try std.testing.expect(rt_hdr.getByteSize() == 1024 * 1024 * 8);
}

test "GaussianKernel generation" {
    const kernel = GaussianKernel.init(5.0, 16);
    try std.testing.expect(kernel.size == 16);

    // Weights should sum to approximately 1
    var total: f32 = kernel.weights[0];
    for (1..kernel.size) |i| {
        total += kernel.weights[i] * 2;
    }
    try std.testing.expect(@abs(total - 1.0) < 0.1);
}

test "SSAOKernel generation" {
    const kernel = SSAOKernel.init(32);
    try std.testing.expect(kernel.sample_count == 32);

    // Samples should be in hemisphere (z >= 0)
    for (0..kernel.sample_count) |i| {
        try std.testing.expect(kernel.samples[i].z >= 0);
    }
}
