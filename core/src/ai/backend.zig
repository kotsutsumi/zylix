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
const builtin = @import("builtin");
const types = @import("types.zig");
const llama = @import("llama_cpp.zig");
const coreml = @import("coreml.zig");
const metal = @import("metal.zig");
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

// === GGML Backend (llama.cpp) ===

/// GGML backend using llama.cpp for actual inference
pub const GGMLBackend = struct {
    status: BackendStatus,
    model: ?*llama.llama_model,
    context: ?*llama.llama_context,
    model_path: [types.MAX_PATH_LEN]u8,
    model_path_len: usize,
    allocator: std.mem.Allocator,
    config: BackendConfig,
    embedding_dim: i32,
    vocab: ?*const llama.c.llama_vocab,

    const Self = @This();

    /// Initialize GGML backend
    pub fn init(allocator: std.mem.Allocator, config: BackendConfig) !*Self {
        const self = try allocator.create(Self);
        self.* = Self{
            .status = .uninitialized,
            .model = null,
            .context = null,
            .model_path = undefined,
            .model_path_len = 0,
            .allocator = allocator,
            .config = config,
            .embedding_dim = 0,
            .vocab = null,
        };

        // Initialize llama.cpp backend
        llama.backendInit();

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
        return .ggml;
    }

    fn getCapabilitiesImpl(ptr: *anyopaque) BackendCapabilities {
        _ = ptr;
        return .{
            .gpu_acceleration = llama.supportsGpuOffload(),
            .batch_inference = true,
            .streaming = true,
            .quantization = true,
            .mmap = llama.supportsMmap(),
            .max_context_length = 8192,
            .max_batch_size = 512,
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

        // Unload previous model if any
        if (self.model != null) {
            self.unloadInternal();
        }

        self.status = .loading;

        // Copy path and ensure null termination
        @memcpy(self.model_path[0..path.len], path);
        self.model_path[path.len] = 0;
        self.model_path_len = path.len;

        // Set up model parameters
        var model_params = llama.modelDefaultParams();
        model_params.n_gpu_layers = if (self.config.use_gpu) 99 else 0;

        // Load the model
        const model = llama.modelLoadFromFile(
            @ptrCast(self.model_path[0 .. path.len + 1]),
            model_params,
        );

        if (model == null) {
            self.status = .@"error";
            return .file_not_found;
        }

        self.model = model;

        // Get model info
        self.embedding_dim = llama.modelNEmbd(model.?);
        self.vocab = llama.modelGetVocab(model.?) orelse {
            llama.modelFree(model.?);
            self.model = null;
            self.status = .@"error";
            return .init_failed;
        };

        // Create context
        var ctx_params = llama.contextDefaultParams();
        ctx_params.n_ctx = self.config.model.context_length;
        ctx_params.n_batch = @intCast(self.config.model.batch_size);
        ctx_params.n_threads = self.config.num_threads;
        ctx_params.embeddings = true; // Enable embeddings mode

        const context = llama.initFromModel(model.?, ctx_params);
        if (context == null) {
            llama.modelFree(model.?);
            self.model = null;
            self.status = .@"error";
            return .init_failed;
        }

        self.context = context;
        self.status = .ready;
        return .ok;
    }

    fn unloadInternal(self: *Self) void {
        if (self.context) |ctx| {
            llama.free(ctx);
            self.context = null;
        }
        if (self.model) |model| {
            llama.modelFree(model);
            self.model = null;
        }
        self.vocab = null;
        self.embedding_dim = 0;
        self.model_path_len = 0;
    }

    fn unloadImpl(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.unloadInternal();
    }

    fn isLoadedImpl(ptr: *anyopaque) bool {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.model != null and self.context != null;
    }

    fn runEmbeddingImpl(ptr: *anyopaque, text: []const u8, output: []f32) Result {
        const self: *Self = @ptrCast(@alignCast(ptr));

        if (self.model == null or self.context == null) {
            return .model_not_loaded;
        }

        if (text.len == 0) {
            return .invalid_arg;
        }

        const ctx = self.context.?;
        const vocab = self.vocab.?;

        // Allocate token buffer
        const max_tokens: usize = 512;
        var tokens: [512]llama.llama_token = undefined;

        // Tokenize input text
        const n_tokens = llama.tokenize(
            vocab,
            text.ptr,
            @intCast(text.len),
            &tokens,
            @intCast(max_tokens),
            true, // add_special (BOS)
            false, // parse_special
        );

        if (n_tokens < 0) {
            return .tokenize_failed;
        }

        // Clear memory
        const mem = llama.getMemory(ctx);
        llama.memoryClear(mem, true);

        // Enable embeddings mode
        llama.setEmbeddings(ctx, true);

        // Create batch
        const batch = llama.batchGetOne(&tokens, n_tokens);

        // Run inference (encode for embeddings)
        const decode_result = llama.decode(ctx, batch);
        if (decode_result != 0) {
            return .inference_failed;
        }

        // Get embeddings
        const embd_dim: usize = @intCast(self.embedding_dim);
        const embeddings = llama.getEmbeddingsSeq(ctx, 0);

        if (embeddings == null) {
            return .inference_failed;
        }

        // Copy embeddings to output
        const copy_len = @min(embd_dim, output.len);
        @memcpy(output[0..copy_len], embeddings.?[0..copy_len]);

        // Normalize embeddings (L2 normalization)
        var norm: f32 = 0.0;
        for (output[0..copy_len]) |v| {
            norm += v * v;
        }
        norm = @sqrt(norm);
        if (norm > 0.0) {
            for (output[0..copy_len]) |*v| {
                v.* /= norm;
            }
        }

        return .ok;
    }

    fn runGenerateImpl(ptr: *anyopaque, prompt: []const u8, output: []u8) Result {
        const self: *Self = @ptrCast(@alignCast(ptr));

        if (self.model == null or self.context == null) {
            return .model_not_loaded;
        }

        if (prompt.len == 0) {
            return .invalid_arg;
        }

        const ctx = self.context.?;
        const vocab = self.vocab.?;
        _ = self.model; // Model is used indirectly through context

        // Tokenize prompt
        const max_tokens: usize = 512;
        var tokens: [512]llama.llama_token = undefined;

        const n_prompt_tokens = llama.tokenize(
            vocab,
            prompt.ptr,
            @intCast(prompt.len),
            &tokens,
            @intCast(max_tokens),
            true,
            false,
        );

        if (n_prompt_tokens < 0) {
            return .tokenize_failed;
        }

        // Disable embeddings mode for generation
        llama.setEmbeddings(ctx, false);

        // Clear memory
        const mem = llama.getMemory(ctx);
        llama.memoryClear(mem, true);

        // Process prompt tokens
        const batch = llama.batchGetOne(&tokens, n_prompt_tokens);
        if (llama.decode(ctx, batch) != 0) {
            return .inference_failed;
        }

        // Create sampler chain
        const sampler_params = llama.samplerChainDefaultParams();
        const sampler = llama.samplerChainInit(sampler_params) orelse return .init_failed;
        defer llama.samplerFree(sampler);

        // Add temperature and greedy samplers
        if (llama.samplerInitTemp(0.8)) |temp| {
            llama.samplerChainAdd(sampler, temp);
        }
        if (llama.samplerInitGreedy()) |greedy| {
            llama.samplerChainAdd(sampler, greedy);
        }

        // Get special tokens
        const eos_token = llama.vocabEos(vocab);
        const eot_token = llama.vocabEot(vocab);

        // Generate tokens
        var output_pos: usize = 0;
        var n_cur: i32 = n_prompt_tokens;
        const n_ctx = llama.nCtx(ctx);
        const max_gen_tokens: usize = @min(256, output.len);

        while (output_pos < max_gen_tokens) {
            // Sample next token
            const new_token = llama.samplerSample(sampler, ctx, -1);

            // Check for end tokens
            if (new_token == eos_token or new_token == eot_token) {
                break;
            }

            // Check context limit
            if (n_cur >= @as(i32, @intCast(n_ctx))) {
                break;
            }

            // Convert token to text
            var piece: [64]u8 = undefined;
            const piece_len = llama.tokenToPiece(vocab, new_token, &piece, 64, 0, false);

            if (piece_len > 0) {
                const copy_len = @min(@as(usize, @intCast(piece_len)), max_gen_tokens - output_pos);
                @memcpy(output[output_pos .. output_pos + copy_len], piece[0..copy_len]);
                output_pos += copy_len;
            }

            // Prepare next batch with the new token
            var next_tokens: [1]llama.llama_token = .{new_token};
            const next_batch = llama.batchGetOne(&next_tokens, 1);

            if (llama.decode(ctx, next_batch) != 0) {
                break;
            }

            n_cur += 1;
        }

        return .ok;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.unloadInternal();
        self.status = .shutdown;

        // Free llama.cpp backend
        llama.backendFree();

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

// === Core ML Backend ===

/// Core ML backend for Apple platforms
pub const CoreMLBackend = struct {
    status: BackendStatus,
    model: ?*coreml.Model,
    model_path: [types.MAX_PATH_LEN]u8,
    model_path_len: usize,
    allocator: std.mem.Allocator,
    config: BackendConfig,
    embedding_dim: i32,

    const Self = @This();

    /// Initialize Core ML backend
    pub fn init(allocator: std.mem.Allocator, config: BackendConfig) !*Self {
        const self = try allocator.create(Self);
        self.* = Self{
            .status = .uninitialized,
            .model = null,
            .model_path = undefined,
            .model_path_len = 0,
            .allocator = allocator,
            .config = config,
            .embedding_dim = 0,
        };

        if (coreml.isAvailable()) {
            self.status = .ready;
        } else {
            self.status = .@"error";
            allocator.destroy(self);
            return error.BackendNotAvailable;
        }

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
        return .coreml;
    }

    fn getCapabilitiesImpl(ptr: *anyopaque) BackendCapabilities {
        _ = ptr;
        return .{
            .gpu_acceleration = metal.isAvailable(),
            .batch_inference = true,
            .streaming = false, // Core ML doesn't support streaming
            .quantization = false, // Core ML uses its own quantization
            .mmap = false,
            .max_context_length = 4096,
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

        // Unload previous model if any
        if (self.model != null) {
            self.unloadInternal();
        }

        self.status = .loading;

        // Copy path
        @memcpy(self.model_path[0..path.len], path);
        self.model_path[path.len] = 0;
        self.model_path_len = path.len;

        // Configure Core ML
        var coreml_config = coreml.getDefaultConfig();
        if (self.config.use_gpu) {
            coreml_config.compute_units = .all;
        } else {
            coreml_config.compute_units = .cpu_only;
        }

        // Load the model
        const model = coreml.Model.load(
            self.allocator,
            path,
            coreml_config,
        ) catch |err| {
            self.status = .@"error";
            return switch (err) {
                error.ModelNotFound => .file_not_found,
                error.CoreMLNotAvailable => .gpu_not_available,
                error.OutOfMemory => .out_of_memory,
                else => .init_failed,
            };
        };

        self.model = model;
        self.status = .ready;
        return .ok;
    }

    fn unloadInternal(self: *Self) void {
        if (self.model) |model| {
            model.deinit();
            self.model = null;
        }
        self.embedding_dim = 0;
        self.model_path_len = 0;
    }

    fn unloadImpl(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.unloadInternal();
    }

    fn isLoadedImpl(ptr: *anyopaque) bool {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.model != null;
    }

    fn runEmbeddingImpl(ptr: *anyopaque, text: []const u8, output: []f32) Result {
        const self: *Self = @ptrCast(@alignCast(ptr));

        if (self.model == null) {
            return .model_not_loaded;
        }

        if (text.len == 0) {
            return .invalid_arg;
        }

        // For Core ML embedding models, we need to tokenize first
        // This is a simplified implementation - real usage would need proper tokenization
        var tokens: [512]i32 = undefined;
        const token_count = @min(text.len, 512);

        // Simple byte-level tokenization (real implementation would use proper tokenizer)
        for (0..token_count) |i| {
            tokens[i] = @intCast(text[i]);
        }

        self.model.?.generateEmbeddings(
            tokens[0..token_count],
            output,
        ) catch {
            return .inference_failed;
        };

        return .ok;
    }

    fn runGenerateImpl(ptr: *anyopaque, prompt: []const u8, output: []u8) Result {
        _ = ptr;
        _ = prompt;
        _ = output;
        // Core ML backend doesn't support text generation directly
        // Text generation models should use GGML backend
        return .unsupported_model;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.unloadInternal();
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

/// Check if Core ML backend is available
fn isCoreMLAvailable() bool {
    return coreml.isAvailable();
}

/// Check if GGML backend is available (native builds with llama.cpp)
fn isGGMLAvailable() bool {
    // GGML is only available for native desktop builds
    const target_os = builtin.os.tag;
    const target_arch = builtin.cpu.arch;

    return switch (target_os) {
        .macos, .linux, .windows => switch (target_arch) {
            .x86_64, .aarch64 => true,
            else => false,
        },
        else => false,
    };
}

/// Create a backend based on configuration
pub fn createBackend(config: BackendConfig, allocator: std.mem.Allocator) !Backend {
    return switch (config.backend_type) {
        .mock => blk: {
            const mock = try MockBackend.init(allocator, config);
            break :blk mock.backend();
        },
        .ggml => blk: {
            if (!isGGMLAvailable()) {
                return error.BackendNotAvailable;
            }
            const ggml = try GGMLBackend.init(allocator, config);
            break :blk ggml.backend();
        },
        .coreml => blk: {
            if (!isCoreMLAvailable()) {
                return error.BackendNotAvailable;
            }
            const coreml_backend = try CoreMLBackend.init(allocator, config);
            break :blk coreml_backend.backend();
        },
        // Other backends will be implemented as needed
        .onnx, .tflite, .webgpu => error.BackendNotImplemented,
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
        .ggml => isGGMLAvailable(), // GGML via llama.cpp
        .coreml => isCoreMLAvailable(), // Core ML on Apple platforms
        // Other backends depend on platform and build configuration
        .onnx, .tflite, .webgpu => false, // Not yet implemented
    };
}

/// Get GPU/Metal information
pub fn getGPUInfo() metal.DeviceInfo {
    return metal.getDefaultDeviceInfo();
}

/// Check if GPU acceleration is available
pub fn hasGPUAcceleration() bool {
    return metal.isAvailable();
}

/// Get recommended Metal configuration
pub fn getMetalConfig() metal.MetalConfig {
    return metal.getDefaultConfig();
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
    // GGML is now available on supported platforms
    try std.testing.expectEqual(isGGMLAvailable(), isBackendAvailable(.ggml));
}
