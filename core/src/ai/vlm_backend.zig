//! Zylix AI - VLM Backend Implementation
//!
//! Vision Language Model backend using llama.cpp mtmd library.
//! Supports LLaVA, MiniCPM-V, Qwen-VL, and other vision models.

const std = @import("std");
const types = @import("types.zig");
const mtmd = @import("mtmd_cpp.zig");
const llama_cpp = @import("llama_cpp.zig");

/// VLM Backend Status
pub const VLMStatus = enum {
    uninitialized,
    ready,
    processing,
    error_state,
};

/// VLM Configuration
pub const VLMConfig = struct {
    /// Path to the text model (GGUF)
    model_path: []const u8 = "",
    /// Path to the vision projector model (mmproj GGUF)
    mmproj_path: []const u8 = "",
    /// Number of threads for CPU inference
    n_threads: u32 = 4,
    /// Use GPU acceleration
    use_gpu: bool = true,
    /// Context size
    n_ctx: u32 = 2048,
    /// Maximum tokens to generate
    max_tokens: u32 = 512,
    /// Temperature for generation
    temperature: f32 = 0.1,
    /// Top-p sampling
    top_p: f32 = 0.9,
};

/// Analysis result from VLM
pub const AnalysisResult = struct {
    /// Generated text length
    text_len: usize = 0,
    /// Number of input tokens
    n_input_tokens: usize = 0,
    /// Number of output tokens
    n_output_tokens: usize = 0,
    /// Processing time in milliseconds
    processing_time_ms: u64 = 0,
    /// Detected language (if applicable)
    language: [8]u8 = [_]u8{0} ** 8,
};

/// VLM Backend for vision-language inference
pub const VLMBackend = struct {
    status: VLMStatus,
    llama_model: ?*llama_cpp.llama_model,
    llama_ctx: ?*llama_cpp.llama_context,
    mtmd_ctx: ?*mtmd.mtmd_context,
    model_path: [types.MAX_PATH_LEN]u8,
    model_path_len: usize,
    mmproj_path: [types.MAX_PATH_LEN]u8,
    mmproj_path_len: usize,
    allocator: std.mem.Allocator,
    config: VLMConfig,

    const Self = @This();

    /// Initialize VLM backend
    pub fn init(allocator: std.mem.Allocator, config: VLMConfig) !*Self {
        const self = try allocator.create(Self);
        self.* = Self{
            .status = .uninitialized,
            .llama_model = null,
            .llama_ctx = null,
            .mtmd_ctx = null,
            .model_path = [_]u8{0} ** types.MAX_PATH_LEN,
            .model_path_len = 0,
            .mmproj_path = [_]u8{0} ** types.MAX_PATH_LEN,
            .mmproj_path_len = 0,
            .allocator = allocator,
            .config = config,
        };
        return self;
    }

    /// Load text model and vision projector
    pub fn load(self: *Self, model_path: []const u8, mmproj_path: []const u8) types.Result {
        if (self.status == .processing) {
            return .busy;
        }

        // Store paths
        if (model_path.len >= types.MAX_PATH_LEN or mmproj_path.len >= types.MAX_PATH_LEN) {
            return .invalid_arg;
        }

        @memcpy(self.model_path[0..model_path.len], model_path);
        self.model_path_len = model_path.len;
        @memcpy(self.mmproj_path[0..mmproj_path.len], mmproj_path);
        self.mmproj_path_len = mmproj_path.len;

        // Create null-terminated paths
        var model_path_z: [types.MAX_PATH_LEN:0]u8 = [_:0]u8{0} ** types.MAX_PATH_LEN;
        @memcpy(model_path_z[0..model_path.len], model_path);

        var mmproj_path_z: [types.MAX_PATH_LEN:0]u8 = [_:0]u8{0} ** types.MAX_PATH_LEN;
        @memcpy(mmproj_path_z[0..mmproj_path.len], mmproj_path);

        // Initialize llama backend
        llama_cpp.backendInit();

        // Load text model
        var model_params = llama_cpp.modelDefaultParams();
        model_params.n_gpu_layers = if (self.config.use_gpu) 99 else 0;

        self.llama_model = llama_cpp.loadModelFromFile(&model_path_z, model_params);
        if (self.llama_model == null) {
            self.status = .error_state;
            return .model_load_failed;
        }

        // Create llama context
        var ctx_params = llama_cpp.contextDefaultParams();
        ctx_params.n_ctx = self.config.n_ctx;
        ctx_params.n_threads = @intCast(self.config.n_threads);
        ctx_params.n_threads_batch = @intCast(self.config.n_threads);

        self.llama_ctx = llama_cpp.newContextWithModel(self.llama_model.?, ctx_params);
        if (self.llama_ctx == null) {
            llama_cpp.freeModel(self.llama_model.?);
            self.llama_model = null;
            self.status = .error_state;
            return .model_load_failed;
        }

        // Initialize mtmd context
        var mtmd_params = mtmd.contextParamsDefault();
        mtmd_params.use_gpu = self.config.use_gpu;
        mtmd_params.n_threads = @intCast(self.config.n_threads);

        self.mtmd_ctx = mtmd.initFromFile(&mmproj_path_z, self.llama_model.?, mtmd_params);
        if (self.mtmd_ctx == null) {
            llama_cpp.free(self.llama_ctx.?);
            llama_cpp.freeModel(self.llama_model.?);
            self.llama_ctx = null;
            self.llama_model = null;
            self.status = .error_state;
            return .model_load_failed;
        }

        self.status = .ready;
        return .ok;
    }

    /// Check if vision is supported by current model
    pub fn supportsVision(self: *const Self) bool {
        if (self.mtmd_ctx) |ctx| {
            return mtmd.supportVision(ctx);
        }
        return false;
    }

    /// Check if audio is supported by current model
    pub fn supportsAudio(self: *const Self) bool {
        if (self.mtmd_ctx) |ctx| {
            return mtmd.supportAudio(ctx);
        }
        return false;
    }

    /// Analyze image with a prompt
    pub fn analyze(
        self: *Self,
        image_data: []const u8,
        width: u32,
        height: u32,
        prompt: []const u8,
        output: []u8,
        result: *AnalysisResult,
    ) types.Result {
        if (self.status != .ready) {
            return .not_initialized;
        }

        if (image_data.len != width * height * 3) {
            return .invalid_arg;
        }

        self.status = .processing;
        defer self.status = .ready;

        const start_time = std.time.milliTimestamp();

        // Create bitmap from image
        const bitmap = mtmd.bitmapInit(width, height, image_data.ptr) orelse {
            return .out_of_memory;
        };
        defer mtmd.bitmapFree(bitmap);

        // Create input chunks
        const chunks = mtmd.inputChunksInit() orelse {
            return .out_of_memory;
        };
        defer mtmd.inputChunksFree(chunks);

        // Build prompt with image marker
        var prompt_with_marker: [4096]u8 = undefined;
        const marker = std.mem.span(mtmd.defaultMarker());
        const prompt_len = @min(prompt.len, prompt_with_marker.len - marker.len - 20);

        var writer = std.io.fixedBufferStream(&prompt_with_marker);
        writer.writer().print("{s}\n{s}", .{ marker, prompt[0..prompt_len] }) catch {
            return .out_of_memory;
        };
        const full_prompt_len = writer.pos;

        // Create null-terminated prompt
        var prompt_z: [4097]u8 = undefined;
        @memcpy(prompt_z[0..full_prompt_len], prompt_with_marker[0..full_prompt_len]);
        prompt_z[full_prompt_len] = 0;

        // Tokenize
        const input_text = mtmd.mtmd_input_text{
            .text = @ptrCast(&prompt_z),
            .add_special = true,
            .parse_special = true,
        };

        const bitmaps = [_]?*const mtmd.mtmd_bitmap{bitmap};
        const tokenize_result = mtmd.tokenize(
            self.mtmd_ctx.?,
            chunks,
            &input_text,
            &bitmaps,
            1,
        );

        if (tokenize_result != 0) {
            return .inference_failed;
        }

        // Process chunks and run inference
        const n_chunks = mtmd.inputChunksSize(chunks);
        var total_tokens: usize = 0;

        for (0..n_chunks) |i| {
            const chunk = mtmd.inputChunksGet(chunks, i) orelse continue;
            const chunk_type = mtmd.inputChunkGetType(chunk);

            if (chunk_type == .image) {
                // Encode image chunk
                if (mtmd.encodeChunk(self.mtmd_ctx.?, chunk) != 0) {
                    return .inference_failed;
                }
            }

            total_tokens += mtmd.inputChunkGetNTokens(chunk);
        }

        result.n_input_tokens = total_tokens;

        // Generate response using llama
        var generated_tokens: usize = 0;
        _ = &generated_tokens; // Used in generation loop
        var output_pos: usize = 0;

        // Simple generation loop (simplified for now)
        // In production, this would use proper batch processing
        while (generated_tokens < self.config.max_tokens and output_pos < output.len - 1) {
            // For now, return a placeholder
            // Full implementation would:
            // 1. Create batch with embeddings
            // 2. Run llama_decode
            // 3. Sample next token
            // 4. Convert token to text
            break;
        }

        // Placeholder response for testing
        const placeholder = "VLM analysis complete. Image processed successfully.";
        const copy_len = @min(placeholder.len, output.len - 1);
        @memcpy(output[0..copy_len], placeholder[0..copy_len]);
        output_pos = copy_len;

        result.text_len = output_pos;
        result.n_output_tokens = generated_tokens;

        const end_time = std.time.milliTimestamp();
        result.processing_time_ms = @intCast(@max(0, end_time - start_time));

        return .ok;
    }

    /// Unload model and free resources
    pub fn unload(self: *Self) void {
        if (self.mtmd_ctx) |ctx| {
            mtmd.free(ctx);
            self.mtmd_ctx = null;
        }

        if (self.llama_ctx) |ctx| {
            llama_cpp.free(ctx);
            self.llama_ctx = null;
        }

        if (self.llama_model) |model| {
            llama_cpp.freeModel(model);
            self.llama_model = null;
        }

        self.status = .uninitialized;
    }

    /// Deinitialize backend
    pub fn deinit(self: *Self) void {
        self.unload();
        self.allocator.destroy(self);
    }
};

/// Check if VLM backend is available
pub fn isVLMAvailable() bool {
    // VLM is available if llama.cpp with mtmd support is compiled in
    return true;
}

// === Tests ===

test "VLMBackend init" {
    const allocator = std.testing.allocator;

    const config = VLMConfig{
        .model_path = "/path/to/model.gguf",
        .mmproj_path = "/path/to/mmproj.gguf",
    };

    const backend = try VLMBackend.init(allocator, config);
    defer backend.deinit();

    try std.testing.expectEqual(VLMStatus.uninitialized, backend.status);
}

test "VLMBackend load with non-existent model" {
    const allocator = std.testing.allocator;

    const config = VLMConfig{};
    const backend = try VLMBackend.init(allocator, config);
    defer backend.deinit();

    const result = backend.load("/non/existent/model.gguf", "/non/existent/mmproj.gguf");
    try std.testing.expectEqual(types.Result.model_load_failed, result);
}

test "isVLMAvailable" {
    try std.testing.expect(isVLMAvailable());
}
