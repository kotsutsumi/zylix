//! Zylix AI - On-Device AI Inference Module
//!
//! Provides on-device LLM, VLM, Embedding, and Whisper inference capabilities.
//! All processing is done locally - no external network calls.
//!
//! ## Design Principles
//!
//! 1. **Privacy First**: All data processed on-device, no external transmission
//! 2. **Offline Operation**: Full functionality without network
//! 3. **Resource Efficiency**: Optimized for mobile and edge devices
//! 4. **Platform Optimization**: Hardware acceleration on each platform
//! 5. **No Model Distribution**: Users obtain models themselves
//!
//! ## Supported Model Types
//!
//! - **Embedding**: Text to vector (semantic search, RAG)
//! - **LLM**: Text generation (chat, completion)
//! - **VLM**: Image understanding (OCR, analysis)
//! - **Whisper**: Speech to text
//!
//! ## Usage
//!
//! ```zig
//! const ai = @import("ai/ai.zig");
//!
//! // Initialize
//! ai.init();
//! defer ai.deinit();
//!
//! // Check if model exists
//! const path = "/path/to/model.gguf";
//! const validation = ai.validateModelPath(path);
//! if (validation.result != .ok) {
//!     // Model not found - user needs to download
//! }
//! ```

const std = @import("std");
const builtin = @import("builtin");

// === Platform Detection ===
// Native C imports are only available on native builds with libc support.
// For freestanding targets (WASM) or cross-compilation, we use stub implementations.

/// Check if native C imports are supported on this platform
pub const has_native_c_support = blk: {
    // Freestanding targets don't have libc
    if (builtin.os.tag == .freestanding) break :blk false;

    // WASM doesn't support native C imports
    if (builtin.cpu.arch == .wasm32 or builtin.cpu.arch == .wasm64) break :blk false;

    // Cross-compilation typically lacks proper sysroot for C headers
    // Native builds (host == target) have C support
    const native_endian = builtin.cpu.arch.endian();
    const target_endian = builtin.target.cpu.arch.endian();

    // Check if this is likely a native build by comparing architectures
    // In cross-compilation scenarios without proper sysroot, C imports fail
    if (builtin.target.os.tag == .linux and builtin.cpu.arch != .x86_64 and builtin.cpu.arch != .aarch64) {
        // Android cross-compile without NDK sysroot
        break :blk false;
    }

    // For now, enable C support on native desktop platforms
    break :blk switch (builtin.target.os.tag) {
        .macos, .linux, .windows => native_endian == target_endian,
        else => false,
    };
};

// Re-export types (always available - no C dependencies)
pub const types = @import("types.zig");
pub const ModelType = types.ModelType;
pub const ModelConfig = types.ModelConfig;
pub const ModelFormat = types.ModelFormat;
pub const ModelInfo = types.ModelInfo;
pub const Quantization = types.Quantization;
pub const GenerateParams = types.GenerateParams;
pub const Result = types.Result;

// Re-export embedding module (pure Zig - no C dependencies)
pub const embedding = @import("embedding.zig");
pub const EmbeddingModel = embedding.EmbeddingModel;
pub const EmbeddingConfig = embedding.EmbeddingConfig;
pub const cosineSimilarity = embedding.cosineSimilarity;

// === Conditionally import C-dependent modules ===

// Backend module (depends on llama_cpp, coreml, metal)
pub const backend = if (has_native_c_support) @import("backend.zig") else @import("backend_stub.zig");
pub const Backend = backend.Backend;
pub const BackendType = backend.BackendType;
pub const BackendConfig = backend.BackendConfig;
pub const createBackend = backend.createBackend;

// LLM module (depends on backend)
pub const llm = if (has_native_c_support) @import("llm.zig") else @import("llm_stub.zig");
pub const LLMModel = llm.LLMModel;
pub const LLMConfig = llm.LLMConfig;
pub const ChatMessage = llm.ChatMessage;
pub const ChatRole = llm.ChatRole;

// VLM module (depends on mtmd_cpp)
pub const vlm = if (has_native_c_support) @import("vlm.zig") else @import("vlm_stub.zig");
pub const vlm_backend = if (has_native_c_support) @import("vlm_backend.zig") else @import("vlm_backend_stub.zig");
pub const mtmd_cpp = if (has_native_c_support) @import("mtmd_cpp.zig") else @import("mtmd_cpp_stub.zig");
pub const VLMModel = vlm.VLMModel;
pub const VLMConfig = vlm.VLMConfig;
pub const Image = vlm.Image;
pub const ImageFormat = vlm.ImageFormat;
pub const VLMBackend = vlm_backend.VLMBackend;

// Whisper module (depends on whisper_cpp)
pub const whisper = if (has_native_c_support) @import("whisper.zig") else @import("whisper_stub.zig");
pub const whisper_backend = if (has_native_c_support) @import("whisper_backend.zig") else @import("whisper_backend_stub.zig");
pub const WhisperModel = whisper.WhisperModel;
pub const WhisperConfig = whisper.WhisperConfig;
pub const Audio = whisper.Audio;
pub const Language = whisper.Language;

// Audio Decoder module (depends on miniaudio)
pub const audio_decoder = if (has_native_c_support) @import("audio_decoder.zig") else @import("audio_decoder_stub.zig");
pub const miniaudio = if (has_native_c_support) @import("miniaudio.zig") else @import("miniaudio_stub.zig");
pub const AudioFormat = audio_decoder.AudioFormat;
pub const AudioInfo = audio_decoder.AudioInfo;
pub const DecodeResult = audio_decoder.DecodeResult;

// Whisper Streaming module (depends on whisper_backend)
pub const whisper_stream = if (has_native_c_support) @import("whisper_stream.zig") else @import("whisper_stream_stub.zig");
pub const StreamingContext = whisper_stream.StreamingContext;
pub const StreamConfig = whisper_stream.StreamConfig;
pub const StreamSegment = whisper_stream.StreamSegment;
pub const StreamState = whisper_stream.StreamState;

// Metal/GPU module (Apple platform only, uses Objective-C runtime)
pub const metal = if (has_native_c_support) @import("metal.zig") else @import("metal_stub.zig");
pub const MetalConfig = metal.MetalConfig;
pub const MetalStatus = metal.MetalStatus;
pub const DeviceInfo = metal.DeviceInfo;
pub const DeviceCapabilities = metal.DeviceCapabilities;

// Core ML module (Apple platform only)
pub const coreml = if (has_native_c_support) @import("coreml.zig") else @import("coreml_stub.zig");
pub const CoreMLModel = coreml.Model;
pub const CoreMLConfig = coreml.Config;
pub const CoreMLComputeUnits = coreml.ComputeUnits;

// === Constants ===

/// Zylix AI version
pub const VERSION: u32 = 0x00_09_00; // v0.9.0

/// Version string
pub const VERSION_STRING = "0.9.0";

/// Default models directory (relative to user home)
pub const DEFAULT_MODELS_DIR = ".zylix/models";

// === Global State ===

var initialized: bool = false;
var allocator: ?std.mem.Allocator = null;

// === Initialization ===

/// Initialize AI module
pub fn init() Result {
    return initWithAllocator(std.heap.page_allocator);
}

/// Initialize AI module with custom allocator
pub fn initWithAllocator(alloc: std.mem.Allocator) Result {
    if (initialized) {
        return .ok; // Already initialized
    }

    allocator = alloc;
    initialized = true;

    return .ok;
}

/// Deinitialize AI module
pub fn deinit() void {
    if (!initialized) return;

    allocator = null;
    initialized = false;
}

/// Check if AI module is initialized
pub fn isInitialized() bool {
    return initialized;
}

/// Get AI module version
pub fn getVersion() u32 {
    return VERSION;
}

/// Get version string
pub fn getVersionString() []const u8 {
    return VERSION_STRING;
}

// === Model Path Validation ===

/// Validation result for model path
pub const PathValidation = struct {
    result: Result,
    format: ModelFormat,
    file_size: u64,

    pub fn isValid(self: PathValidation) bool {
        return self.result == .ok;
    }
};

/// Validate a model file path
/// Returns detailed information about the file
pub fn validateModelPath(path: []const u8) PathValidation {
    // Check format from extension
    const format = types.detectFormat(path);
    if (format == .unknown) {
        return .{
            .result = .invalid_format,
            .format = .unknown,
            .file_size = 0,
        };
    }

    // Try to get file info
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        return .{
            .result = switch (err) {
                error.FileNotFound => .file_not_found,
                error.AccessDenied => .invalid_arg,
                else => .unknown,
            },
            .format = format,
            .file_size = 0,
        };
    };
    defer file.close();

    const stat = file.stat() catch {
        return .{
            .result = .unknown,
            .format = format,
            .file_size = 0,
        };
    };

    // Check if file is too small (likely corrupted)
    if (stat.size < 1024) {
        return .{
            .result = .corrupted_file,
            .format = format,
            .file_size = stat.size,
        };
    }

    return .{
        .result = .ok,
        .format = format,
        .file_size = stat.size,
    };
}

/// Check if a model file exists at the given path
pub fn modelExists(path: []const u8) bool {
    return validateModelPath(path).isValid();
}

// === Model Info ===

/// Read basic model information from file
/// Note: Full metadata parsing requires format-specific implementation
pub fn getModelInfo(path: []const u8) !ModelInfo {
    const validation = validateModelPath(path);
    if (!validation.isValid()) {
        return error.InvalidModel;
    }

    var info = ModelInfo{
        .format = validation.format,
        .file_size = validation.file_size,
    };

    // Extract name from filename
    const basename = std.fs.path.basename(path);
    if (std.mem.lastIndexOfScalar(u8, basename, '.')) |dot_idx| {
        info.setName(basename[0..dot_idx]);
    } else {
        info.setName(basename);
    }

    // TODO: Parse GGUF/ONNX headers for detailed metadata

    return info;
}

// === Utility ===

/// Get recommended models directory path
/// Returns null if home directory cannot be determined
pub fn getModelsDir(buffer: []u8) ?[]const u8 {
    const alloc = allocator orelse return null;

    // Try to get home directory from environment
    const home = std.process.getEnvVarOwned(alloc, "HOME") catch return null;
    defer alloc.free(home);

    // Construct path
    const path = std.fmt.bufPrint(buffer, "{s}/{s}", .{ home, DEFAULT_MODELS_DIR }) catch return null;

    return path;
}

/// Format file size for display
pub fn formatFileSize(size: u64, buffer: []u8) []const u8 {
    if (size >= 1024 * 1024 * 1024) {
        return std.fmt.bufPrint(buffer, "{d:.1} GB", .{@as(f64, @floatFromInt(size)) / (1024 * 1024 * 1024)}) catch "? GB";
    } else if (size >= 1024 * 1024) {
        return std.fmt.bufPrint(buffer, "{d:.1} MB", .{@as(f64, @floatFromInt(size)) / (1024 * 1024)}) catch "? MB";
    } else if (size >= 1024) {
        return std.fmt.bufPrint(buffer, "{d:.1} KB", .{@as(f64, @floatFromInt(size)) / 1024}) catch "? KB";
    } else {
        return std.fmt.bufPrint(buffer, "{d} B", .{size}) catch "? B";
    }
}

// === Tests ===

test "initialization" {
    try std.testing.expectEqual(false, isInitialized());

    const result = init();
    try std.testing.expectEqual(Result.ok, result);
    try std.testing.expectEqual(true, isInitialized());

    // Double init should be ok
    const result2 = init();
    try std.testing.expectEqual(Result.ok, result2);

    deinit();
    try std.testing.expectEqual(false, isInitialized());
}

test "version" {
    try std.testing.expectEqual(@as(u32, 0x00_09_00), getVersion());
    try std.testing.expectEqualStrings("0.9.0", getVersionString());
}

test "validateModelPath with non-existent file" {
    const validation = validateModelPath("/non/existent/path.gguf");
    try std.testing.expectEqual(Result.file_not_found, validation.result);
    try std.testing.expectEqual(ModelFormat.gguf, validation.format);
}

test "validateModelPath with unknown format" {
    const validation = validateModelPath("/some/path.xyz");
    try std.testing.expectEqual(Result.invalid_format, validation.result);
    try std.testing.expectEqual(ModelFormat.unknown, validation.format);
}

test "formatFileSize" {
    var buffer: [32]u8 = undefined;

    const size_b = formatFileSize(512, &buffer);
    try std.testing.expectEqualStrings("512 B", size_b);

    const size_kb = formatFileSize(2048, &buffer);
    try std.testing.expectEqualStrings("2.0 KB", size_kb);

    const size_mb = formatFileSize(1024 * 1024 * 5, &buffer);
    try std.testing.expectEqualStrings("5.0 MB", size_mb);

    const size_gb = formatFileSize(1024 * 1024 * 1024 * 2, &buffer);
    try std.testing.expectEqualStrings("2.0 GB", size_gb);
}

// Include submodule tests
test {
    // Always test pure Zig modules
    _ = types;
    _ = embedding;

    // Conditionally test C-dependent modules
    if (has_native_c_support) {
        _ = backend;
        _ = llm;
        _ = vlm;
        _ = whisper;
        _ = whisper_stream;
        _ = audio_decoder;
        _ = metal;
        _ = coreml;
    }
}
