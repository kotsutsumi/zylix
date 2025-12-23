//! Zylix AI - Backend Abstraction Layer
//!
//! Provides a unified interface for different inference backends across platforms.
//! Each platform may use a different underlying engine:
//!
//! - **Desktop (macOS/Linux/Windows)**: GGML/llama.cpp
//! - **iOS/macOS**: Core ML + Metal
//! - **Android**: NNAPI/TensorFlow Lite
//! - **Web**: WebGPU/ONNX.js
//!
//! This abstraction allows the same API to work across all platforms.

const std = @import("std");
const types = @import("types.zig");
const ModelConfig = types.ModelConfig;
const ModelFormat = types.ModelFormat;
const ModelType = types.ModelType;
const Result = types.Result;

// === Backend Types ===

/// Supported backend types
pub const BackendType = enum(u8) {
    /// GGML/llama.cpp backend (desktop)
    ggml = 0,
    /// ONNX Runtime backend
    onnx = 1,
    /// Core ML backend (Apple platforms)
    coreml = 2,
    /// TensorFlow Lite backend (Android)
    tflite = 3,
    /// WebGPU backend (Web)
    webgpu = 4,
    /// Mock backend for testing
    mock = 255,
};

/// Backend capabilities
pub const BackendCapabilities = struct {
    /// Supports GPU acceleration
    gpu_acceleration: bool = false,
    /// Supports batched inference
    batch_inference: bool = false,
    /// Supports streaming output
    streaming: bool = false,
    /// Supports model quantization
    quantization: bool = false,
    /// Supports memory mapping
    mmap: bool = false,
    /// Maximum supported context length
    max_context_length: u32 = 2048,
    /// Maximum batch size
    max_batch_size: u32 = 1,
};

/// Backend status
pub const BackendStatus = enum(u8) {
    /// Not initialized
    uninitialized = 0,
    /// Loading model
    loading = 1,
    /// Ready for inference
    ready = 2,
    /// Running inference
    busy = 3,
    /// Error state
    @"error" = 4,
    /// Shutting down
    shutdown = 5,
};

// === Backend Configuration ===

/// Configuration for backend initialization
pub const BackendConfig = struct {
    /// Backend type to use
    backend_type: BackendType = .mock,

    /// Model configuration
    model: ModelConfig = .{},

    /// Number of CPU threads
    num_threads: u8 = 4,

    /// Use GPU if available
    use_gpu: bool = true,

    /// GPU device index (0 = default)
    gpu_device: u8 = 0,

    /// Memory limit in MB (0 = no limit)
    memory_limit_mb: u32 = 0,

    /// Enable verbose logging
    verbose: bool = false,
};

// === Backend Interface ===

/// Abstract backend interface
/// All backends must implement these methods
pub const Backend = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        /// Get backend type
        getType: *const fn (*anyopaque) BackendType,

        /// Get backend capabilities
        getCapabilities: *const fn (*anyopaque) BackendCapabilities,

        /// Get current status
        getStatus: *const fn (*anyopaque) BackendStatus,

        /// Load model
        load: *const fn (*anyopaque, []const u8) Result,

        /// Unload model
        unload: *const fn (*anyopaque) void,

        /// Check if model is loaded
        isLoaded: *const fn (*anyopaque) bool,

        /// Run embedding inference
        runEmbedding: *const fn (*anyopaque, []const u8, []f32) Result,

        /// Run text generation
        runGenerate: *const fn (*anyopaque, []const u8, []u8) Result,

        /// Deinitialize backend
        deinit: *const fn (*anyopaque) void,
    };

    /// Get backend type
    pub fn getType(self: Backend) BackendType {
        return self.vtable.getType(self.ptr);
    }

    /// Get backend capabilities
    pub fn getCapabilities(self: Backend) BackendCapabilities {
        return self.vtable.getCapabilities(self.ptr);
    }

    /// Get current status
    pub fn getStatus(self: Backend) BackendStatus {
        return self.vtable.getStatus(self.ptr);
    }

    /// Load model from path
    pub fn load(self: Backend, path: []const u8) Result {
        return self.vtable.load(self.ptr, path);
    }

    /// Unload current model
    pub fn unload(self: Backend) void {
        return self.vtable.unload(self.ptr);
    }

    /// Check if model is loaded
    pub fn isLoaded(self: Backend) bool {
        return self.vtable.isLoaded(self.ptr);
    }

    /// Run embedding inference
    pub fn runEmbedding(self: Backend, text: []const u8, output: []f32) Result {
        return self.vtable.runEmbedding(self.ptr, text, output);
    }

    /// Run text generation
    pub fn runGenerate(self: Backend, prompt: []const u8, output: []u8) Result {
        return self.vtable.runGenerate(self.ptr, prompt, output);
    }

    /// Deinitialize backend
    pub fn deinit(self: Backend) void {
        return self.vtable.deinit(self.ptr);
    }
};

// === Mock Backend for Testing ===

/// Mock backend for testing purposes
pub const MockBackend = struct {
    status: BackendStatus,
    model_loaded: bool,
    model_path: [types.MAX_PATH_LEN]u8,
    model_path_len: usize,
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Initialize mock backend
    pub fn init(allocator: std.mem.Allocator, _: BackendConfig) !*Self {
        const self = try allocator.create(Self);
        self.* = Self{
            .status = .uninitialized,
            .model_loaded = false,
            .model_path = undefined,
            .model_path_len = 0,
            .allocator = allocator,
        };
        self.status = .ready;
        return self;
    }

    /// Get as Backend interface
    pub fn backend(self: *Self) Backend {
        return .{
            .ptr = self,
            .vtable = &vtable,
        };
    }

    fn getTypeImpl(ptr: *anyopaque) BackendType {
        _ = ptr;
        return .mock;
    }

    fn getCapabilitiesImpl(ptr: *anyopaque) BackendCapabilities {
        _ = ptr;
        return .{
            .gpu_acceleration = false,
            .batch_inference = true,
            .streaming = false,
            .quantization = false,
            .mmap = false,
            .max_context_length = 2048,
            .max_batch_size = 32,
        };
    }

    fn getStatusImpl(ptr: *anyopaque) BackendStatus {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.status;
    }

    fn loadImpl(ptr: *anyopaque, path: []const u8) Result {
        const self: *Self = @ptrCast(@alignCast(ptr));

        if (path.len == 0) {
            return .invalid_arg;
        }

        if (path.len > types.MAX_PATH_LEN) {
            return .invalid_arg;
        }

        self.status = .loading;

        // Copy path
        @memcpy(self.model_path[0..path.len], path);
        self.model_path_len = path.len;
        self.model_loaded = true;

        self.status = .ready;
        return .ok;
    }

    fn unloadImpl(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.model_loaded = false;
        self.model_path_len = 0;
    }

    fn isLoadedImpl(ptr: *anyopaque) bool {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.model_loaded;
    }

    fn runEmbeddingImpl(ptr: *anyopaque, text: []const u8, output: []f32) Result {
        const self: *Self = @ptrCast(@alignCast(ptr));

        if (!self.model_loaded) {
            return .model_not_loaded;
        }

        if (text.len == 0) {
            return .invalid_arg;
        }

        // Generate mock embedding based on text hash
        var hasher = std.hash.Wyhash.init(0);
        hasher.update(text);
        var seed = hasher.final();

        for (output, 0..) |*val, i| {
            seed = seed *% 0x5851F42D4C957F2D +% @as(u64, @intCast(i));
            val.* = @as(f32, @floatFromInt(seed >> 40)) / 16777216.0 - 0.5;
        }

        return .ok;
    }

    fn runGenerateImpl(ptr: *anyopaque, prompt: []const u8, output: []u8) Result {
        const self: *Self = @ptrCast(@alignCast(ptr));

        if (!self.model_loaded) {
            return .model_not_loaded;
        }

        if (prompt.len == 0) {
            return .invalid_arg;
        }

        // Generate mock response
        const response = "This is a mock response from the test backend.";
        const copy_len = @min(response.len, output.len);
        @memcpy(output[0..copy_len], response[0..copy_len]);

        return .ok;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.status = .shutdown;
        self.allocator.destroy(self);
    }

    const vtable = Backend.VTable{
        .getType = getTypeImpl,
        .getCapabilities = getCapabilitiesImpl,
        .getStatus = getStatusImpl,
        .load = loadImpl,
        .unload = unloadImpl,
        .isLoaded = isLoadedImpl,
        .runEmbedding = runEmbeddingImpl,
        .runGenerate = runGenerateImpl,
        .deinit = deinitImpl,
    };
};

// === Backend Factory ===

/// Create a backend based on configuration
pub fn createBackend(config: BackendConfig, allocator: std.mem.Allocator) !Backend {
    return switch (config.backend_type) {
        .mock => blk: {
            const mock = try MockBackend.init(allocator, config);
            break :blk mock.backend();
        },
        // Other backends will be implemented as needed
        .ggml, .onnx, .coreml, .tflite, .webgpu => error.BackendNotImplemented,
    };
}

/// Get recommended backend for current platform and model format
pub fn getRecommendedBackend(format: ModelFormat) BackendType {
    // In a real implementation, this would check the platform
    // For now, return mock for testing
    return switch (format) {
        .gguf => .ggml,
        .onnx => .onnx,
        .coreml => .coreml,
        .tflite => .tflite,
        .unknown => .mock,
    };
}

/// Check if a backend type is available on the current platform
pub fn isBackendAvailable(backend_type: BackendType) bool {
    return switch (backend_type) {
        .mock => true, // Always available
        // Other backends depend on platform and build configuration
        .ggml, .onnx, .coreml, .tflite, .webgpu => false, // Not yet implemented
    };
}

// === Tests ===

test "MockBackend initialization" {
    const allocator = std.testing.allocator;

    const config = BackendConfig{
        .backend_type = .mock,
    };

    const mock = try MockBackend.init(allocator, config);
    defer mock.allocator.destroy(mock);

    try std.testing.expectEqual(BackendStatus.ready, mock.status);
    try std.testing.expect(!mock.model_loaded);
}

test "MockBackend via Backend interface" {
    const allocator = std.testing.allocator;

    const config = BackendConfig{
        .backend_type = .mock,
    };

    const mock = try MockBackend.init(allocator, config);
    const b = mock.backend();
    defer b.deinit();

    try std.testing.expectEqual(BackendType.mock, b.getType());
    try std.testing.expectEqual(BackendStatus.ready, b.getStatus());
    try std.testing.expect(!b.isLoaded());
}

test "MockBackend load and unload" {
    const allocator = std.testing.allocator;

    const config = BackendConfig{
        .backend_type = .mock,
    };

    const mock = try MockBackend.init(allocator, config);
    const b = mock.backend();
    defer b.deinit();

    // Load model
    const load_result = b.load("/path/to/model.gguf");
    try std.testing.expectEqual(Result.ok, load_result);
    try std.testing.expect(b.isLoaded());

    // Unload model
    b.unload();
    try std.testing.expect(!b.isLoaded());
}

test "MockBackend load empty path error" {
    const allocator = std.testing.allocator;

    const config = BackendConfig{
        .backend_type = .mock,
    };

    const mock = try MockBackend.init(allocator, config);
    const b = mock.backend();
    defer b.deinit();

    const result = b.load("");
    try std.testing.expectEqual(Result.invalid_arg, result);
}

test "MockBackend runEmbedding" {
    const allocator = std.testing.allocator;

    const config = BackendConfig{
        .backend_type = .mock,
    };

    const mock = try MockBackend.init(allocator, config);
    const b = mock.backend();
    defer b.deinit();

    // Load model first
    _ = b.load("/path/to/model.gguf");

    // Run embedding
    var output: [384]f32 = undefined;
    const result = b.runEmbedding("Hello, world!", &output);
    try std.testing.expectEqual(Result.ok, result);
}

test "MockBackend runEmbedding without model" {
    const allocator = std.testing.allocator;

    const config = BackendConfig{
        .backend_type = .mock,
    };

    const mock = try MockBackend.init(allocator, config);
    const b = mock.backend();
    defer b.deinit();

    // Try to run without loading model
    var output: [384]f32 = undefined;
    const result = b.runEmbedding("Hello, world!", &output);
    try std.testing.expectEqual(Result.model_not_loaded, result);
}

test "MockBackend runGenerate" {
    const allocator = std.testing.allocator;

    const config = BackendConfig{
        .backend_type = .mock,
    };

    const mock = try MockBackend.init(allocator, config);
    const b = mock.backend();
    defer b.deinit();

    // Load model first
    _ = b.load("/path/to/model.gguf");

    // Run generation
    var output: [256]u8 = undefined;
    const result = b.runGenerate("Hello", &output);
    try std.testing.expectEqual(Result.ok, result);
}

test "MockBackend capabilities" {
    const allocator = std.testing.allocator;

    const config = BackendConfig{
        .backend_type = .mock,
    };

    const mock = try MockBackend.init(allocator, config);
    const b = mock.backend();
    defer b.deinit();

    const caps = b.getCapabilities();
    try std.testing.expect(!caps.gpu_acceleration);
    try std.testing.expect(caps.batch_inference);
    try std.testing.expectEqual(@as(u32, 32), caps.max_batch_size);
}

test "createBackend mock" {
    const allocator = std.testing.allocator;

    const config = BackendConfig{
        .backend_type = .mock,
    };

    const b = try createBackend(config, allocator);
    defer b.deinit();

    try std.testing.expectEqual(BackendType.mock, b.getType());
}

test "getRecommendedBackend" {
    try std.testing.expectEqual(BackendType.ggml, getRecommendedBackend(.gguf));
    try std.testing.expectEqual(BackendType.onnx, getRecommendedBackend(.onnx));
    try std.testing.expectEqual(BackendType.coreml, getRecommendedBackend(.coreml));
    try std.testing.expectEqual(BackendType.tflite, getRecommendedBackend(.tflite));
    try std.testing.expectEqual(BackendType.mock, getRecommendedBackend(.unknown));
}

test "isBackendAvailable" {
    try std.testing.expect(isBackendAvailable(.mock));
    try std.testing.expect(!isBackendAvailable(.ggml)); // Not yet implemented
}
