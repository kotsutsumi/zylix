//! Zylix AI - Core Type Definitions
//!
//! Basic types for on-device AI inference.
//! These types are designed to be compatible with C ABI for cross-platform use.

const std = @import("std");

// === Model Types ===

/// AI model category
pub const ModelType = enum(u8) {
    /// Text embedding model (e.g., Qwen3-Embedding)
    embedding = 0,
    /// Large language model (e.g., Qwen3, Llama)
    llm = 1,
    /// Vision-language model (e.g., Qwen2-VL)
    vlm = 2,
    /// Speech recognition model (Whisper)
    whisper = 3,
    /// Text-to-speech model
    tts = 4,
};

/// Quantization level for model weights
pub const Quantization = enum(u8) {
    /// 16-bit float (high quality, large memory)
    f16 = 0,
    /// 8-bit quantization (balanced)
    q8_0 = 1,
    /// 4-bit quantization (lightweight, recommended)
    q4_0 = 2,
    /// 4-bit K-quant (optimal balance)
    q4_k_m = 3,
    /// 2-bit quantization (ultra-light, quality loss)
    q2_k = 4,
};

/// Model file format
pub const ModelFormat = enum(u8) {
    /// GGUF format (llama.cpp compatible)
    gguf = 0,
    /// ONNX format
    onnx = 1,
    /// Core ML format (Apple platforms)
    coreml = 2,
    /// TensorFlow Lite format (Android)
    tflite = 3,
    /// Unknown format
    unknown = 255,
};

// === Configuration ===

/// Maximum path length
pub const MAX_PATH_LEN: usize = 4096;

/// Maximum model name length
pub const MAX_NAME_LEN: usize = 256;

/// Model configuration
pub const ModelConfig = extern struct {
    /// Model type
    model_type: ModelType = .llm,

    /// Model file path (null-terminated)
    model_path: [MAX_PATH_LEN]u8 = [_]u8{0} ** MAX_PATH_LEN,
    model_path_len: u32 = 0,

    /// Quantization level
    quantization: Quantization = .q4_0,

    /// Maximum memory usage in MB
    max_memory_mb: u32 = 512,

    /// Use memory mapping for model loading
    use_mmap: bool = true,

    /// Context length (for LLM)
    context_length: u32 = 2048,

    /// Batch size for inference
    batch_size: u32 = 1,

    /// Number of CPU threads
    num_threads: u8 = 4,

    /// Use GPU acceleration
    use_gpu: bool = true,

    /// Number of layers to offload to GPU (0 = auto)
    gpu_layers: u32 = 0,

    _pad: [2]u8 = .{ 0, 0 },

    /// Set model path
    pub fn setPath(self: *ModelConfig, path: []const u8) void {
        const len = @min(path.len, MAX_PATH_LEN - 1);
        @memcpy(self.model_path[0..len], path[0..len]);
        self.model_path[len] = 0;
        self.model_path_len = @intCast(len);
    }

    /// Get model path as slice
    pub fn getPath(self: *const ModelConfig) []const u8 {
        return self.model_path[0..self.model_path_len];
    }

    /// Create default config for embedding model
    pub fn forEmbedding(path: []const u8) ModelConfig {
        var config = ModelConfig{
            .model_type = .embedding,
            .max_memory_mb = 256,
            .context_length = 512,
        };
        config.setPath(path);
        return config;
    }

    /// Create default config for LLM
    pub fn forLLM(path: []const u8) ModelConfig {
        var config = ModelConfig{
            .model_type = .llm,
            .max_memory_mb = 2048,
            .context_length = 4096,
        };
        config.setPath(path);
        return config;
    }

    /// Create default config for VLM
    pub fn forVLM(path: []const u8) ModelConfig {
        var config = ModelConfig{
            .model_type = .vlm,
            .max_memory_mb = 4096,
            .context_length = 2048,
        };
        config.setPath(path);
        return config;
    }

    /// Create default config for Whisper
    pub fn forWhisper(path: []const u8) ModelConfig {
        var config = ModelConfig{
            .model_type = .whisper,
            .max_memory_mb = 512,
            .context_length = 1500, // ~30 seconds of audio
        };
        config.setPath(path);
        return config;
    }
};

// === Generation Parameters ===

/// Parameters for text generation
pub const GenerateParams = extern struct {
    /// Maximum tokens to generate
    max_tokens: u32 = 256,

    /// Temperature (0.0 - 2.0, higher = more random)
    temperature: f32 = 0.7,

    /// Top-p sampling (0.0 - 1.0)
    top_p: f32 = 0.9,

    /// Top-k sampling (0 = disabled)
    top_k: u32 = 40,

    /// Repetition penalty (1.0 = no penalty)
    repeat_penalty: f32 = 1.1,

    /// Stop on end-of-sequence token
    stop_on_eos: bool = true,

    _pad: [3]u8 = .{ 0, 0, 0 },
};

// === Result Types ===

/// AI operation result codes
pub const Result = enum(i32) {
    /// Success
    ok = 0,
    /// Invalid argument
    invalid_arg = 1,
    /// Out of memory
    out_of_memory = 2,
    /// Model not loaded
    model_not_loaded = 3,
    /// Model file not found
    file_not_found = 4,
    /// Invalid model format
    invalid_format = 5,
    /// Corrupted model file
    corrupted_file = 6,
    /// Unsupported model type
    unsupported_model = 7,
    /// GPU not available
    gpu_not_available = 8,
    /// Inference failed
    inference_failed = 9,
    /// Context length exceeded
    context_exceeded = 10,
    /// Operation cancelled
    cancelled = 11,
    /// Unknown error
    unknown = -1,
};

/// Model information (read from file)
pub const ModelInfo = extern struct {
    /// Model name (from metadata)
    name: [MAX_NAME_LEN]u8 = [_]u8{0} ** MAX_NAME_LEN,
    name_len: u32 = 0,

    /// Model type
    model_type: ModelType = .llm,

    /// File format
    format: ModelFormat = .unknown,

    /// File size in bytes
    file_size: u64 = 0,

    /// Parameter count (if available)
    param_count: u64 = 0,

    /// Context length (if available)
    context_length: u32 = 0,

    /// Vocabulary size (if available)
    vocab_size: u32 = 0,

    /// Embedding dimension (if available)
    embedding_dim: u32 = 0,

    /// Is quantized
    is_quantized: bool = false,

    /// Quantization type (if quantized)
    quantization: Quantization = .q4_0,

    _pad: [2]u8 = .{ 0, 0 },

    pub fn setName(self: *ModelInfo, name: []const u8) void {
        const len = @min(name.len, MAX_NAME_LEN - 1);
        @memcpy(self.name[0..len], name[0..len]);
        self.name[len] = 0;
        self.name_len = @intCast(len);
    }

    pub fn getName(self: *const ModelInfo) []const u8 {
        return self.name[0..self.name_len];
    }
};

// === Utility Functions ===

/// Detect model format from file extension
pub fn detectFormat(path: []const u8) ModelFormat {
    if (std.mem.endsWith(u8, path, ".gguf")) return .gguf;
    if (std.mem.endsWith(u8, path, ".onnx")) return .onnx;
    if (std.mem.endsWith(u8, path, ".mlmodel") or std.mem.endsWith(u8, path, ".mlpackage")) return .coreml;
    if (std.mem.endsWith(u8, path, ".tflite")) return .tflite;
    return .unknown;
}

/// Get file extension for format
pub fn formatExtension(format: ModelFormat) []const u8 {
    return switch (format) {
        .gguf => ".gguf",
        .onnx => ".onnx",
        .coreml => ".mlmodel",
        .tflite => ".tflite",
        .unknown => "",
    };
}

/// Estimate memory requirements for model
pub fn estimateMemory(file_size: u64, quantization: Quantization) u64 {
    // Rough estimation: model size + context buffers
    const base = file_size;
    const overhead: u64 = switch (quantization) {
        .f16 => file_size / 2, // 50% overhead
        .q8_0 => file_size / 3, // 33% overhead
        .q4_0, .q4_k_m => file_size / 4, // 25% overhead
        .q2_k => file_size / 5, // 20% overhead
    };
    return base + overhead;
}

// === Tests ===

test "ModelConfig creation" {
    const config = ModelConfig.forLLM("/path/to/model.gguf");
    try std.testing.expectEqual(ModelType.llm, config.model_type);
    try std.testing.expectEqual(@as(u32, 2048), config.max_memory_mb);
    try std.testing.expectEqual(@as(u32, 4096), config.context_length);
    try std.testing.expectEqualStrings("/path/to/model.gguf", config.getPath());
}

test "ModelConfig for different types" {
    const embedding = ModelConfig.forEmbedding("/model.gguf");
    try std.testing.expectEqual(ModelType.embedding, embedding.model_type);
    try std.testing.expectEqual(@as(u32, 256), embedding.max_memory_mb);

    const vlm = ModelConfig.forVLM("/vlm.gguf");
    try std.testing.expectEqual(ModelType.vlm, vlm.model_type);
    try std.testing.expectEqual(@as(u32, 4096), vlm.max_memory_mb);

    const whisper = ModelConfig.forWhisper("/whisper.bin");
    try std.testing.expectEqual(ModelType.whisper, whisper.model_type);
}

test "detectFormat" {
    try std.testing.expectEqual(ModelFormat.gguf, detectFormat("/path/model.gguf"));
    try std.testing.expectEqual(ModelFormat.onnx, detectFormat("model.onnx"));
    try std.testing.expectEqual(ModelFormat.coreml, detectFormat("model.mlmodel"));
    try std.testing.expectEqual(ModelFormat.tflite, detectFormat("model.tflite"));
    try std.testing.expectEqual(ModelFormat.unknown, detectFormat("model.bin"));
}

test "estimateMemory" {
    const file_size: u64 = 1024 * 1024 * 1024; // 1GB
    const mem_q4 = estimateMemory(file_size, .q4_0);
    try std.testing.expect(mem_q4 > file_size);
    try std.testing.expect(mem_q4 < file_size * 2);
}

test "GenerateParams defaults" {
    const params = GenerateParams{};
    try std.testing.expectEqual(@as(u32, 256), params.max_tokens);
    try std.testing.expectEqual(@as(f32, 0.7), params.temperature);
    try std.testing.expect(params.stop_on_eos);
}
