//! Zylix AI - Core ML Zig Bindings
//!
//! High-level Zig interface for Core ML operations on Apple platforms.
//! Provides type-safe wrappers around the C API.
//!
//! ## Usage
//!
//! ```zig
//! const coreml = @import("ai/coreml.zig");
//!
//! if (coreml.isAvailable()) {
//!     var model = try coreml.Model.load(allocator, "model.mlpackage", .{});
//!     defer model.deinit();
//!
//!     const output = try model.predict(input);
//! }
//! ```

const std = @import("std");
const builtin = @import("builtin");
const types = @import("types.zig");

// C API bindings
const c = @cImport({
    @cInclude("coreml_wrapper.h");
});

// === Types ===

/// Core ML result codes
pub const Result = enum(i32) {
    success = c.COREML_SUCCESS,
    invalid_arg = c.COREML_ERROR_INVALID_ARG,
    model_not_found = c.COREML_ERROR_MODEL_NOT_FOUND,
    model_compile = c.COREML_ERROR_MODEL_COMPILE,
    model_load = c.COREML_ERROR_MODEL_LOAD,
    inference = c.COREML_ERROR_INFERENCE,
    memory = c.COREML_ERROR_MEMORY,
    not_available = c.COREML_ERROR_NOT_AVAILABLE,
    unsupported = c.COREML_ERROR_UNSUPPORTED,
    unknown = c.COREML_ERROR_UNKNOWN,

    pub fn isSuccess(self: Result) bool {
        return self == .success;
    }

    pub fn toString(self: Result) []const u8 {
        return std.mem.span(c.coreml_error_string(@intFromEnum(self)));
    }
};

/// Compute unit options
pub const ComputeUnits = enum(c_uint) {
    /// Use all available compute units
    all = c.COREML_COMPUTE_ALL,
    /// CPU only
    cpu_only = c.COREML_COMPUTE_CPU_ONLY,
    /// CPU and GPU
    cpu_and_gpu = c.COREML_COMPUTE_CPU_AND_GPU,
    /// CPU and Neural Engine
    cpu_and_neural_engine = c.COREML_COMPUTE_CPU_AND_NE,
};

/// Core ML configuration
pub const Config = struct {
    /// Compute units to use
    compute_units: ComputeUnits = .all,
    /// Allow low precision for better performance
    allow_low_precision: bool = true,
    /// Fall back to CPU if GPU/NE fails
    use_cpu_fallback: bool = true,
    /// Maximum batch size
    max_batch_size: u32 = 1,
    /// Optimize for Neural Engine
    optimize_for_neural_engine: bool = true,

    /// Convert to C config struct
    fn toC(self: Config) c.CoreMLConfig {
        return .{
            .compute_units = @intFromEnum(self.compute_units),
            .allow_low_precision = self.allow_low_precision,
            .use_cpu_fallback = self.use_cpu_fallback,
            .max_batch_size = self.max_batch_size,
            .optimize_for_neural_engine = self.optimize_for_neural_engine,
        };
    }
};

/// Model information
pub const ModelInfo = struct {
    name: [256]u8 = [_]u8{0} ** 256,
    name_len: usize = 0,
    description: [512]u8 = [_]u8{0} ** 512,
    description_len: usize = 0,
    author: [128]u8 = [_]u8{0} ** 128,
    author_len: usize = 0,
    version: [32]u8 = [_]u8{0} ** 32,
    version_len: usize = 0,
    input_count: u32 = 0,
    output_count: u32 = 0,
    is_compiled: bool = false,
    model_size: u64 = 0,

    pub fn getName(self: *const ModelInfo) []const u8 {
        return self.name[0..self.name_len];
    }

    pub fn getAuthor(self: *const ModelInfo) []const u8 {
        return self.author[0..self.author_len];
    }

    pub fn getVersion(self: *const ModelInfo) []const u8 {
        return self.version[0..self.version_len];
    }
};

// === Platform Detection ===

/// Check if Core ML is available on this platform
pub fn isAvailable() bool {
    return c.coreml_is_available();
}

/// Get Core ML version string
pub fn getVersion() []const u8 {
    return std.mem.span(c.coreml_version());
}

/// Check if Neural Engine is available
pub fn hasNeuralEngine() bool {
    return c.coreml_has_neural_engine();
}

/// Get default configuration
pub fn getDefaultConfig() Config {
    const cc = c.coreml_default_config();
    return .{
        .compute_units = @enumFromInt(cc.compute_units),
        .allow_low_precision = cc.allow_low_precision,
        .use_cpu_fallback = cc.use_cpu_fallback,
        .max_batch_size = cc.max_batch_size,
        .optimize_for_neural_engine = cc.optimize_for_neural_engine,
    };
}

// === Model ===

/// Core ML Model wrapper
pub const Model = struct {
    handle: c.CoreMLModelHandle,
    allocator: std.mem.Allocator,
    config: Config,
    model_path: []const u8,

    const Self = @This();

    /// Load a Core ML model from path
    pub fn load(allocator: std.mem.Allocator, path: []const u8, config: Config) !*Self {
        if (!isAvailable()) {
            return error.CoreMLNotAvailable;
        }

        if (path.len == 0 or path.len >= types.MAX_PATH_LEN) {
            return error.InvalidPath;
        }

        // Create null-terminated path
        var path_buf: [types.MAX_PATH_LEN]u8 = undefined;
        @memcpy(path_buf[0..path.len], path);
        path_buf[path.len] = 0;

        var result: c.CoreMLResult = c.COREML_ERROR_UNKNOWN;
        const handle = c.coreml_load_model(
            @ptrCast(path_buf[0 .. path.len + 1]),
            config.toC(),
            &result,
        );

        if (handle == null or result != c.COREML_SUCCESS) {
            return switch (@as(Result, @enumFromInt(result))) {
                .model_not_found => error.ModelNotFound,
                .model_compile => error.ModelCompileFailed,
                .model_load => error.ModelLoadFailed,
                .memory => error.OutOfMemory,
                .not_available => error.CoreMLNotAvailable,
                else => error.Unknown,
            };
        }

        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        // Copy path
        const path_copy = try allocator.dupe(u8, path);
        errdefer allocator.free(path_copy);

        self.* = .{
            .handle = handle,
            .allocator = allocator,
            .config = config,
            .model_path = path_copy,
        };

        return self;
    }

    /// Free the model
    pub fn deinit(self: *Self) void {
        if (self.handle != null) {
            c.coreml_free_model(self.handle);
            self.handle = null;
        }
        self.allocator.free(self.model_path);
        self.allocator.destroy(self);
    }

    /// Check if model is ready
    pub fn isReady(self: *const Self) bool {
        return c.coreml_is_model_ready(self.handle);
    }

    /// Get model information
    pub fn getInfo(self: *const Self) !ModelInfo {
        var c_info: c.CoreMLModelInfo = undefined;
        const result = c.coreml_get_model_info(self.handle, &c_info);

        if (result != c.COREML_SUCCESS) {
            return error.InfoFailed;
        }

        var info = ModelInfo{
            .input_count = c_info.input_count,
            .output_count = c_info.output_count,
            .is_compiled = c_info.is_compiled,
            .model_size = c_info.model_size,
        };

        // Copy strings
        const name_len = std.mem.indexOfScalar(u8, &c_info.name, 0) orelse c_info.name.len;
        @memcpy(info.name[0..name_len], c_info.name[0..name_len]);
        info.name_len = name_len;

        const author_len = std.mem.indexOfScalar(u8, &c_info.author, 0) orelse c_info.author.len;
        @memcpy(info.author[0..author_len], c_info.author[0..author_len]);
        info.author_len = author_len;

        const version_len = std.mem.indexOfScalar(u8, &c_info.version, 0) orelse c_info.version.len;
        @memcpy(info.version[0..version_len], c_info.version[0..version_len]);
        info.version_len = version_len;

        return info;
    }

    /// Run inference with float input/output
    pub fn predict(self: *Self, input: []const f32, output: []f32) !void {
        const result = c.coreml_predict_float(
            self.handle,
            input.ptr,
            input.len,
            output.ptr,
            output.len,
        );

        if (result != c.COREML_SUCCESS) {
            return switch (@as(Result, @enumFromInt(result))) {
                .invalid_arg => error.InvalidArgument,
                .inference => error.InferenceFailed,
                .memory => error.OutOfMemory,
                else => error.Unknown,
            };
        }
    }

    /// Generate embeddings from tokens
    pub fn generateEmbeddings(
        self: *Self,
        tokens: []const i32,
        embeddings: []f32,
    ) !void {
        const result = c.coreml_generate_embeddings(
            self.handle,
            tokens.ptr,
            tokens.len,
            embeddings.ptr,
            embeddings.len,
        );

        if (result != c.COREML_SUCCESS) {
            return switch (@as(Result, @enumFromInt(result))) {
                .invalid_arg => error.InvalidArgument,
                .inference => error.InferenceFailed,
                .memory => error.OutOfMemory,
                else => error.Unknown,
            };
        }
    }

    /// Warm up the model (run dummy inference)
    pub fn warmup(self: *Self) !void {
        const result = c.coreml_warmup(self.handle);
        if (result != c.COREML_SUCCESS) {
            return error.WarmupFailed;
        }
    }

    /// Get last inference time in milliseconds
    pub fn getLastInferenceTime(self: *const Self) f64 {
        return c.coreml_get_last_inference_time(self.handle);
    }
};

// === Utility ===

/// Clear Core ML model cache
pub fn clearCache() void {
    c.coreml_clear_cache();
}

/// Check if a file is a Core ML model
pub fn isCoreMLModel(path: []const u8) bool {
    return std.mem.endsWith(u8, path, ".mlmodel") or
        std.mem.endsWith(u8, path, ".mlmodelc") or
        std.mem.endsWith(u8, path, ".mlpackage");
}

// === Tests ===

test "isAvailable" {
    const available = isAvailable();
    // On Apple platforms, should be available
    if (builtin.os.tag == .macos or builtin.os.tag == .ios) {
        try std.testing.expect(available);
    }
}

test "getVersion" {
    const version = getVersion();
    try std.testing.expect(version.len > 0);
}

test "getDefaultConfig" {
    const config = getDefaultConfig();
    try std.testing.expect(config.max_batch_size >= 1);
}

test "isCoreMLModel" {
    try std.testing.expect(isCoreMLModel("model.mlmodel"));
    try std.testing.expect(isCoreMLModel("model.mlmodelc"));
    try std.testing.expect(isCoreMLModel("model.mlpackage"));
    try std.testing.expect(!isCoreMLModel("model.gguf"));
    try std.testing.expect(!isCoreMLModel("model.onnx"));
}
