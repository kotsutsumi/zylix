//! Zylix AI - Whisper Backend
//!
//! Speech-to-text backend using whisper.cpp for audio transcription.
//! Supports multiple languages and translation to English.

const std = @import("std");
const builtin = @import("builtin");
const types = @import("types.zig");
const whisper = @import("whisper_cpp.zig");

// === Types ===

/// Transcription segment with timing information
pub const TranscriptSegment = struct {
    /// Segment text
    text: []const u8,
    /// Start time in milliseconds
    start_ms: i64,
    /// End time in milliseconds
    end_ms: i64,
};

/// Transcription result
pub const TranscriptResult = struct {
    /// Full transcribed text
    text: []u8,
    /// Number of bytes used in text buffer
    text_len: usize,
    /// Detected language code (e.g., "en", "ja", "es")
    language: [8]u8,
    /// Number of segments
    n_segments: usize,
};

/// Whisper configuration
pub const WhisperConfig = struct {
    /// Model file path
    model_path: []const u8 = "",
    /// Target language (empty = auto-detect)
    language: []const u8 = "",
    /// Translate to English
    translate: bool = false,
    /// Number of CPU threads
    n_threads: u8 = 4,
    /// Use GPU if available
    use_gpu: bool = true,
    /// Print progress during transcription
    print_progress: bool = false,
    /// Maximum segment length in tokens
    max_tokens_per_segment: u32 = 0,
};

/// Whisper backend status
pub const WhisperStatus = enum(u8) {
    uninitialized = 0,
    loading = 1,
    ready = 2,
    transcribing = 3,
    @"error" = 4,
    shutdown = 5,
};

// === Whisper Backend ===

/// Whisper speech-to-text backend
pub const WhisperBackend = struct {
    status: WhisperStatus,
    context: ?*whisper.whisper_context,
    model_path: [types.MAX_PATH_LEN]u8,
    model_path_len: usize,
    allocator: std.mem.Allocator,
    config: WhisperConfig,

    const Self = @This();

    /// Initialize Whisper backend
    pub fn init(allocator: std.mem.Allocator, config: WhisperConfig) !*Self {
        const self = try allocator.create(Self);
        self.* = Self{
            .status = .uninitialized,
            .context = null,
            .model_path = undefined,
            .model_path_len = 0,
            .allocator = allocator,
            .config = config,
        };
        self.status = .ready;
        return self;
    }

    /// Deinitialize backend
    pub fn deinit(self: *Self) void {
        self.unload();
        self.status = .shutdown;
        self.allocator.destroy(self);
    }

    /// Load Whisper model from file
    pub fn load(self: *Self, path: []const u8) types.Result {
        if (path.len == 0) {
            return .invalid_arg;
        }

        if (path.len >= types.MAX_PATH_LEN) {
            return .invalid_arg;
        }

        // Unload previous model if any
        if (self.context != null) {
            self.unload();
        }

        self.status = .loading;

        // Copy path and null-terminate
        @memcpy(self.model_path[0..path.len], path);
        self.model_path[path.len] = 0;
        self.model_path_len = path.len;

        // Initialize context parameters
        var ctx_params = whisper.contextDefaultParams();
        ctx_params.use_gpu = self.config.use_gpu;

        // Load the model
        const ctx = whisper.initFromFile(
            @ptrCast(self.model_path[0 .. path.len + 1]),
            ctx_params,
        );

        if (ctx == null) {
            self.status = .@"error";
            return .file_not_found;
        }

        self.context = ctx;
        self.status = .ready;
        return .ok;
    }

    /// Unload current model
    pub fn unload(self: *Self) void {
        if (self.context) |ctx| {
            whisper.free(ctx);
            self.context = null;
        }
        self.model_path_len = 0;
    }

    /// Check if model is loaded
    pub fn isLoaded(self: *const Self) bool {
        return self.context != null;
    }

    /// Get current status
    pub fn getStatus(self: *const Self) WhisperStatus {
        return self.status;
    }

    /// Transcribe audio samples
    /// Expects PCM f32 audio at 16kHz sample rate (mono)
    pub fn transcribe(
        self: *Self,
        samples: []const f32,
        output: []u8,
        result: *TranscriptResult,
    ) types.Result {
        if (self.context == null) {
            return .model_not_loaded;
        }

        if (samples.len == 0) {
            return .invalid_arg;
        }

        const ctx = self.context.?;
        self.status = .transcribing;

        // Set up transcription parameters
        var params = whisper.fullDefaultParams(.greedy);
        params.n_threads = self.config.n_threads;
        params.translate = self.config.translate;
        params.print_progress = self.config.print_progress;

        // Set language if specified
        if (self.config.language.len > 0 and self.config.language.len < 8) {
            var lang_buf: [8]u8 = .{0} ** 8;
            @memcpy(lang_buf[0..self.config.language.len], self.config.language);
            params.language = @ptrCast(&lang_buf);
        }

        if (self.config.max_tokens_per_segment > 0) {
            params.max_tokens = @intCast(self.config.max_tokens_per_segment);
        }

        // Run transcription
        const ret = whisper.full(
            ctx,
            params,
            samples.ptr,
            @intCast(samples.len),
        );

        if (ret != 0) {
            self.status = .@"error";
            return .inference_failed;
        }

        // Get number of segments
        const n_segments: usize = @intCast(@max(0, whisper.fullNSegments(ctx)));
        result.n_segments = n_segments;

        // Get detected language
        const lang_id = whisper.fullLangId(ctx);
        const lang_str = whisper.langStr(lang_id);
        const lang_span = std.mem.span(lang_str);
        const lang_len = @min(lang_span.len, result.language.len);
        @memcpy(result.language[0..lang_len], lang_span[0..lang_len]);
        if (lang_len < result.language.len) {
            result.language[lang_len] = 0;
        }

        // Collect all segment texts
        var text_pos: usize = 0;
        for (0..n_segments) |i| {
            const segment_text = whisper.fullGetSegmentText(ctx, @intCast(i));
            const segment_span = std.mem.span(segment_text);

            // Skip leading space on first segment
            var actual_span = segment_span;
            if (i == 0 and segment_span.len > 0 and segment_span[0] == ' ') {
                actual_span = segment_span[1..];
            }

            // Copy text to output
            if (text_pos + actual_span.len < output.len) {
                @memcpy(output[text_pos .. text_pos + actual_span.len], actual_span);
                text_pos += actual_span.len;
            } else {
                // Output buffer full
                break;
            }
        }

        result.text = output;
        result.text_len = text_pos;

        self.status = .ready;
        return .ok;
    }

    /// Get Whisper version string
    pub fn getVersion() []const u8 {
        return std.mem.span(whisper.version());
    }

    /// Check if model is multilingual
    pub fn isMultilingual(self: *const Self) bool {
        if (self.context) |ctx| {
            return whisper.isMultilingual(ctx);
        }
        return false;
    }

    /// Get supported language count
    pub fn getLanguageCount() usize {
        return @intCast(@max(0, whisper.langMaxId() + 1));
    }

    /// Get language name by ID
    pub fn getLanguageName(id: usize) []const u8 {
        if (id > @as(usize, @intCast(whisper.langMaxId()))) {
            return "";
        }
        return std.mem.span(whisper.langStrFull(@intCast(id)));
    }
};

// === Utility Functions ===

/// Check if Whisper backend is available (native builds only)
pub fn isWhisperAvailable() bool {
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

/// Get expected sample rate for Whisper input
pub fn getSampleRate() u32 {
    return whisper.SAMPLE_RATE;
}

// === Tests ===

test "WhisperBackend initialization" {
    const allocator = std.testing.allocator;

    const config = WhisperConfig{};
    const backend = try WhisperBackend.init(allocator, config);
    defer backend.deinit();

    try std.testing.expectEqual(WhisperStatus.ready, backend.status);
    try std.testing.expect(!backend.isLoaded());
}

test "WhisperBackend getVersion" {
    const version = WhisperBackend.getVersion();
    try std.testing.expect(version.len > 0);
}

test "WhisperBackend load empty path error" {
    const allocator = std.testing.allocator;

    const config = WhisperConfig{};
    const backend = try WhisperBackend.init(allocator, config);
    defer backend.deinit();

    const result = backend.load("");
    try std.testing.expectEqual(types.Result.invalid_arg, result);
}

test "WhisperBackend transcribe without model" {
    const allocator = std.testing.allocator;

    const config = WhisperConfig{};
    const backend = try WhisperBackend.init(allocator, config);
    defer backend.deinit();

    var samples: [1600]f32 = .{0.0} ** 1600;
    var output: [1024]u8 = undefined;
    var result: TranscriptResult = undefined;

    const ret = backend.transcribe(&samples, &output, &result);
    try std.testing.expectEqual(types.Result.model_not_loaded, ret);
}

test "getSampleRate" {
    const rate = getSampleRate();
    try std.testing.expectEqual(@as(u32, 16000), rate);
}

test "isWhisperAvailable" {
    // On native desktop builds, this should be true
    const available = isWhisperAvailable();
    if (builtin.os.tag == .macos or builtin.os.tag == .linux) {
        try std.testing.expect(available);
    }
}

test "getLanguageCount" {
    const count = WhisperBackend.getLanguageCount();
    try std.testing.expect(count > 0);
}
