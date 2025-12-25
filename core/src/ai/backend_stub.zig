//! Backend Stub Module
//!
//! Provides stub types for platforms without native C support.
//! Used for WASM and cross-compilation builds.

const std = @import("std");
const types = @import("types.zig");
const Result = types.Result;

/// Supported backend types
pub const BackendType = enum(u8) {
    ggml = 0,
    onnx = 1,
    coreml = 2,
    tflite = 3,
    webgpu = 4,
    mock = 255,
};

/// Backend capabilities (stub - no real capabilities)
pub const BackendCapabilities = struct {
    gpu_acceleration: bool = false,
    batch_inference: bool = false,
    streaming: bool = false,
    quantization: bool = false,
    mmap: bool = false,
    max_context_length: u32 = 0,
    max_batch_size: u32 = 0,
};

/// Backend status
pub const BackendStatus = enum(u8) {
    uninitialized = 0,
    loading = 1,
    ready = 2,
    busy = 3,
    @"error" = 4,
    shutdown = 5,
};

/// Backend configuration
pub const BackendConfig = struct {
    backend_type: BackendType = .mock,
    model: types.ModelConfig = .{},
    num_threads: u8 = 4,
    use_gpu: bool = false,
    gpu_device: u8 = 0,
    memory_limit_mb: u32 = 0,
    verbose: bool = false,
};

/// Stub backend interface
pub const Backend = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        getType: *const fn (*anyopaque) BackendType,
        getCapabilities: *const fn (*anyopaque) BackendCapabilities,
        getStatus: *const fn (*anyopaque) BackendStatus,
        load: *const fn (*anyopaque, []const u8) Result,
        unload: *const fn (*anyopaque) void,
        isLoaded: *const fn (*anyopaque) bool,
        runEmbedding: *const fn (*anyopaque, []const u8, []f32) Result,
        runGenerate: *const fn (*anyopaque, []const u8, []u8) Result,
        deinit: *const fn (*anyopaque) void,
    };

    pub fn getType(self: Backend) BackendType {
        return self.vtable.getType(self.ptr);
    }

    pub fn getCapabilities(self: Backend) BackendCapabilities {
        return self.vtable.getCapabilities(self.ptr);
    }

    pub fn getStatus(self: Backend) BackendStatus {
        return self.vtable.getStatus(self.ptr);
    }

    pub fn load(self: Backend, path: []const u8) Result {
        return self.vtable.load(self.ptr, path);
    }

    pub fn unload(self: Backend) void {
        return self.vtable.unload(self.ptr);
    }

    pub fn isLoaded(self: Backend) bool {
        return self.vtable.isLoaded(self.ptr);
    }

    pub fn runEmbedding(self: Backend, text: []const u8, output: []f32) Result {
        return self.vtable.runEmbedding(self.ptr, text, output);
    }

    pub fn runGenerate(self: Backend, prompt: []const u8, output: []u8) Result {
        return self.vtable.runGenerate(self.ptr, prompt, output);
    }

    pub fn deinit(self: Backend) void {
        return self.vtable.deinit(self.ptr);
    }
};

/// Stub backend creation - always returns not available error
pub fn createBackend(_: BackendConfig, _: std.mem.Allocator) !Backend {
    return error.BackendNotAvailable;
}

/// Backend not available on this platform
pub fn isBackendAvailable(_: BackendType) bool {
    return false;
}

/// GPU not available on stub platform
pub fn hasGPUAcceleration() bool {
    return false;
}
