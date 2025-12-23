//! Zylix AI - Whisper Speech-to-Text
//!
//! Speech recognition and transcription using Whisper models.
//! Supports multiple languages and provides word-level timestamps.
//!
//! ## Usage
//!
//! ```zig
//! const whisper = @import("ai/whisper.zig");
//!
//! // Load model
//! var model = try whisper.WhisperModel.init(config, allocator);
//! defer model.deinit();
//!
//! // Transcribe audio
//! const audio = whisper.Audio{ .samples = samples, .sample_rate = 16000 };
//! const result = try model.transcribe(audio);
//! defer allocator.free(result.text);
//! ```

const std = @import("std");
const types = @import("types.zig");
pub const whisper_backend = @import("whisper_backend.zig");
const ModelConfig = types.ModelConfig;
const ModelFormat = types.ModelFormat;
const Result = types.Result;

// Re-export backend types
pub const WhisperBackend = whisper_backend.WhisperBackend;
pub const TranscriptSegment = whisper_backend.TranscriptSegment;
pub const isWhisperAvailable = whisper_backend.isWhisperAvailable;
pub const getSampleRate = whisper_backend.getSampleRate;

// === Constants ===

/// Standard sample rate for Whisper (16kHz)
pub const WHISPER_SAMPLE_RATE: u32 = 16000;

/// Maximum audio duration in seconds
pub const MAX_AUDIO_DURATION: u32 = 30 * 60; // 30 minutes

/// Maximum samples (30 minutes at 16kHz)
pub const MAX_SAMPLES: usize = WHISPER_SAMPLE_RATE * MAX_AUDIO_DURATION;

/// Maximum output text length
pub const MAX_OUTPUT_LENGTH: usize = 32 * 1024; // 32KB

/// Number of mel bands
pub const N_MELS: u32 = 80;

// === Audio Types ===

/// Audio sample format
pub const SampleFormat = enum(u8) {
    /// 32-bit float (-1.0 to 1.0)
    f32 = 0,
    /// 16-bit signed integer
    i16 = 1,
    /// 8-bit unsigned integer
    u8 = 2,
};

/// Audio data structure
pub const Audio = struct {
    /// Raw audio samples (format depends on sample_format)
    samples: []const u8,
    /// Sample rate in Hz
    sample_rate: u32,
    /// Number of channels (1 = mono, 2 = stereo)
    channels: u8 = 1,
    /// Sample format
    sample_format: SampleFormat = .f32,

    /// Get number of samples
    pub fn getSampleCount(self: *const Audio) usize {
        const bytes_per_sample: usize = switch (self.sample_format) {
            .f32 => 4,
            .i16 => 2,
            .u8 => 1,
        };
        return self.samples.len / bytes_per_sample / @as(usize, self.channels);
    }

    /// Get duration in seconds
    pub fn getDuration(self: *const Audio) f32 {
        if (self.sample_rate == 0) return 0;
        return @as(f32, @floatFromInt(self.getSampleCount())) / @as(f32, @floatFromInt(self.sample_rate));
    }

    /// Validate audio data
    pub fn isValid(self: *const Audio) bool {
        if (self.samples.len == 0) return false;
        if (self.sample_rate == 0) return false;
        if (self.channels == 0 or self.channels > 2) return false;
        if (self.getDuration() > @as(f32, @floatFromInt(MAX_AUDIO_DURATION))) return false;
        return true;
    }
};

// === Whisper Configuration ===

/// Whisper language codes
pub const Language = enum(u8) {
    /// Auto-detect language
    auto = 0,
    /// English
    en = 1,
    /// Japanese
    ja = 2,
    /// Chinese
    zh = 3,
    /// Korean
    ko = 4,
    /// Spanish
    es = 5,
    /// French
    fr = 6,
    /// German
    de = 7,
    /// Italian
    it = 8,
    /// Portuguese
    pt = 9,
    /// Russian
    ru = 10,
    /// Other languages...
    other = 255,

    /// Get language code string
    pub fn getCode(self: Language) []const u8 {
        return switch (self) {
            .auto => "auto",
            .en => "en",
            .ja => "ja",
            .zh => "zh",
            .ko => "ko",
            .es => "es",
            .fr => "fr",
            .de => "de",
            .it => "it",
            .pt => "pt",
            .ru => "ru",
            .other => "other",
        };
    }
};

/// Whisper task type
pub const TaskType = enum(u8) {
    /// Transcribe in original language
    transcribe = 0,
    /// Translate to English
    translate = 1,
};

/// Configuration for Whisper operations
pub const WhisperConfig = struct {
    /// Model configuration
    model: ModelConfig,

    /// Target language (auto = auto-detect)
    language: Language = .auto,

    /// Task type (transcribe or translate)
    task: TaskType = .transcribe,

    /// Enable word-level timestamps
    word_timestamps: bool = false,

    /// Number of threads for processing
    num_threads: u8 = 4,

    /// Enable beam search
    beam_size: u8 = 5,

    /// Temperature for sampling
    temperature: f32 = 0.0,
};

// === Transcription Result ===

/// Word with timestamp
pub const Word = struct {
    /// Word text
    text: []const u8,
    /// Start time in milliseconds
    start_ms: u64,
    /// End time in milliseconds
    end_ms: u64,
    /// Confidence score (0.0 - 1.0)
    confidence: f32,
};

/// Segment with timestamp
pub const Segment = struct {
    /// Segment text
    text: []const u8,
    /// Start time in milliseconds
    start_ms: u64,
    /// End time in milliseconds
    end_ms: u64,
};

/// Transcription result
pub const TranscriptionResult = struct {
    /// Full transcription text
    text: []u8,
    /// Detected language
    language: Language,
    /// Segments (if available)
    segments: ?[]Segment,
    /// Words with timestamps (if enabled)
    words: ?[]Word,
    /// Processing time in milliseconds
    processing_time_ms: u64,
};

// === Whisper Model ===

/// Whisper speech-to-text model
pub const WhisperModel = struct {
    config: WhisperConfig,
    allocator: std.mem.Allocator,
    initialized: bool,
    backend: ?*WhisperBackend,

    const Self = @This();

    /// Initialize Whisper model
    pub fn init(config: WhisperConfig, allocator: std.mem.Allocator) !Self {
        // Validate model path
        const path = config.model.getPath();
        if (path.len == 0) {
            return error.InvalidModelPath;
        }

        // Check model format
        const format = types.detectFormat(path);
        if (format == .unknown) {
            return error.UnsupportedFormat;
        }

        // Try to create backend if available
        var backend: ?*WhisperBackend = null;
        if (isWhisperAvailable()) {
            const backend_config = whisper_backend.WhisperConfig{
                .model_path = path,
                .language = config.language.getCode(),
                .translate = config.task == .translate,
                .n_threads = config.num_threads,
                .use_gpu = true,
            };
            backend = WhisperBackend.init(allocator, backend_config) catch null;

            // Load the model
            if (backend) |b| {
                const load_result = b.load(path);
                if (load_result != .ok) {
                    b.deinit();
                    backend = null;
                }
            }
        }

        return Self{
            .config = config,
            .allocator = allocator,
            .initialized = true,
            .backend = backend,
        };
    }

    /// Check if model is ready
    pub fn isReady(self: *const Self) bool {
        return self.initialized;
    }

    /// Check if using real backend (not placeholder)
    pub fn hasBackend(self: *const Self) bool {
        return self.backend != null and self.backend.?.isLoaded();
    }

    /// Transcribe audio
    /// Caller owns the returned text and must free it
    pub fn transcribe(self: *Self, audio: Audio) !TranscriptionResult {
        if (!self.initialized) {
            return error.ModelNotInitialized;
        }

        if (!audio.isValid()) {
            return error.InvalidAudio;
        }

        const start_time = std.time.milliTimestamp();

        // Try to use real backend
        if (self.backend) |backend| {
            if (backend.isLoaded()) {
                // Convert audio to f32 samples at 16kHz mono
                const prepared = try self.prepareAudioForWhisper(audio);
                defer if (prepared.needs_free) self.allocator.free(prepared.samples);

                // Allocate output buffer
                var output_buffer: [MAX_OUTPUT_LENGTH]u8 = undefined;
                var backend_result: whisper_backend.TranscriptResult = undefined;

                const result = backend.transcribe(prepared.samples, &output_buffer, &backend_result);
                if (result == .ok) {
                    // Copy result to allocated memory
                    const text = try self.allocator.alloc(u8, backend_result.text_len);
                    @memcpy(text, output_buffer[0..backend_result.text_len]);

                    // Parse detected language
                    const detected_lang = self.parseLanguageCode(&backend_result.language);

                    const end_time = std.time.milliTimestamp();

                    return TranscriptionResult{
                        .text = text,
                        .language = detected_lang,
                        .segments = null,
                        .words = null,
                        .processing_time_ms = @intCast(@max(0, end_time - start_time)),
                    };
                }
            }
        }

        // Fallback to placeholder
        var temp_buffer: [MAX_OUTPUT_LENGTH]u8 = undefined;
        const response_len = self.generatePlaceholderResponse(audio, &temp_buffer);

        // Allocate exact size for result
        const text = try self.allocator.alloc(u8, response_len);
        @memcpy(text, temp_buffer[0..response_len]);

        return TranscriptionResult{
            .text = text,
            .language = self.config.language,
            .segments = null,
            .words = null,
            .processing_time_ms = 0,
        };
    }

    /// Prepare audio for Whisper (convert to f32 mono 16kHz)
    fn prepareAudioForWhisper(self: *Self, audio: Audio) !struct { samples: []const f32, needs_free: bool } {
        _ = self;

        // Check if already in correct format
        if (audio.sample_format == .f32 and audio.channels == 1 and audio.sample_rate == WHISPER_SAMPLE_RATE) {
            // Reinterpret bytes as f32 slice
            const f32_ptr: [*]const f32 = @ptrCast(@alignCast(audio.samples.ptr));
            const sample_count = audio.samples.len / 4;
            return .{ .samples = f32_ptr[0..sample_count], .needs_free = false };
        }

        // For now, just return the raw samples reinterpreted
        // TODO: Implement proper audio conversion
        const f32_ptr: [*]const f32 = @ptrCast(@alignCast(audio.samples.ptr));
        const sample_count = audio.samples.len / 4;
        return .{ .samples = f32_ptr[0..sample_count], .needs_free = false };
    }

    /// Parse language code to Language enum
    fn parseLanguageCode(self: *const Self, code: *const [8]u8) Language {
        _ = self;
        const span = std.mem.sliceTo(code, 0);
        if (std.mem.eql(u8, span, "en")) return .en;
        if (std.mem.eql(u8, span, "ja")) return .ja;
        if (std.mem.eql(u8, span, "zh")) return .zh;
        if (std.mem.eql(u8, span, "ko")) return .ko;
        if (std.mem.eql(u8, span, "es")) return .es;
        if (std.mem.eql(u8, span, "fr")) return .fr;
        if (std.mem.eql(u8, span, "de")) return .de;
        if (std.mem.eql(u8, span, "it")) return .it;
        if (std.mem.eql(u8, span, "pt")) return .pt;
        if (std.mem.eql(u8, span, "ru")) return .ru;
        return .other;
    }

    /// Transcribe with language detection
    /// Returns detected language along with transcription
    pub fn transcribeWithDetection(self: *Self, audio: Audio) !struct { result: TranscriptionResult, detected_language: Language } {
        const result = try self.transcribe(audio);
        return .{
            .result = result,
            .detected_language = result.language,
        };
    }

    /// Translate audio to English
    /// Caller owns the returned text and must free it
    pub fn translate(self: *Self, audio: Audio) !TranscriptionResult {
        // Temporarily override config
        const original_task = self.config.task;
        self.config.task = .translate;
        defer self.config.task = original_task;

        // Update backend config if available
        if (self.backend) |backend| {
            backend.config.translate = true;
            defer backend.config.translate = false;
        }

        return self.transcribe(audio);
    }

    /// Generate placeholder response (for testing before backend integration)
    fn generatePlaceholderResponse(self: *const Self, audio: Audio, output: []u8) usize {
        const duration = audio.getDuration();
        const lang_code = self.config.language.getCode();
        const task_name = if (self.config.task == .translate) "translation" else "transcription";

        var writer = std.io.fixedBufferStream(output);
        writer.writer().print(
            "Whisper {s}: Audio {d:.1}s @ {d}Hz ({s}). Language: {s}",
            .{
                task_name,
                duration,
                audio.sample_rate,
                @tagName(audio.sample_format),
                lang_code,
            },
        ) catch {};

        return writer.pos;
    }

    /// Deinitialize model
    pub fn deinit(self: *Self) void {
        if (self.backend) |backend| {
            backend.deinit();
            self.backend = null;
        }
        self.initialized = false;
    }
};

// === Audio Processing Utilities ===

/// Resample audio to target sample rate
/// Caller owns the returned data and must free it
pub fn resampleAudio(audio: Audio, target_rate: u32, allocator: std.mem.Allocator) !Audio {
    if (audio.sample_rate == target_rate) {
        // No resampling needed, copy the data
        const data_copy = try allocator.alloc(u8, audio.samples.len);
        @memcpy(data_copy, audio.samples);
        return Audio{
            .samples = data_copy,
            .sample_rate = target_rate,
            .channels = audio.channels,
            .sample_format = audio.sample_format,
        };
    }

    // Calculate new sample count
    const original_samples = audio.getSampleCount();
    const ratio = @as(f64, @floatFromInt(target_rate)) / @as(f64, @floatFromInt(audio.sample_rate));
    const new_sample_count: usize = @intFromFloat(@as(f64, @floatFromInt(original_samples)) * ratio);

    const bytes_per_sample: usize = switch (audio.sample_format) {
        .f32 => 4,
        .i16 => 2,
        .u8 => 1,
    };
    const new_size = new_sample_count * bytes_per_sample * @as(usize, audio.channels);
    const new_data = try allocator.alloc(u8, new_size);

    // TODO: Implement actual resampling (linear interpolation for now - placeholder)
    @memset(new_data, 0);

    return Audio{
        .samples = new_data,
        .sample_rate = target_rate,
        .channels = audio.channels,
        .sample_format = audio.sample_format,
    };
}

/// Convert stereo audio to mono
/// Caller owns the returned data and must free it
pub fn convertToMono(audio: Audio, allocator: std.mem.Allocator) !Audio {
    if (audio.channels == 1) {
        // Already mono, copy the data
        const data_copy = try allocator.alloc(u8, audio.samples.len);
        @memcpy(data_copy, audio.samples);
        return Audio{
            .samples = data_copy,
            .sample_rate = audio.sample_rate,
            .channels = 1,
            .sample_format = audio.sample_format,
        };
    }

    const bytes_per_sample: usize = switch (audio.sample_format) {
        .f32 => 4,
        .i16 => 2,
        .u8 => 1,
    };

    const stereo_sample_count = audio.getSampleCount();
    const new_size = stereo_sample_count * bytes_per_sample;
    const new_data = try allocator.alloc(u8, new_size);

    // TODO: Implement actual stereo-to-mono conversion
    // For now, just copy left channel (placeholder)
    @memset(new_data, 0);

    return Audio{
        .samples = new_data,
        .sample_rate = audio.sample_rate,
        .channels = 1,
        .sample_format = audio.sample_format,
    };
}

/// Convert sample format to f32
/// Caller owns the returned data and must free it
pub fn convertToF32(audio: Audio, allocator: std.mem.Allocator) !Audio {
    if (audio.sample_format == .f32) {
        // Already f32, copy the data
        const data_copy = try allocator.alloc(u8, audio.samples.len);
        @memcpy(data_copy, audio.samples);
        return Audio{
            .samples = data_copy,
            .sample_rate = audio.sample_rate,
            .channels = audio.channels,
            .sample_format = .f32,
        };
    }

    const sample_count = audio.getSampleCount() * @as(usize, audio.channels);
    const new_size = sample_count * 4; // 4 bytes per f32
    const new_data = try allocator.alloc(u8, new_size);

    // Convert to f32 based on source format
    switch (audio.sample_format) {
        .i16 => {
            // Read i16 samples byte-by-byte to avoid alignment issues
            var src_idx: usize = 0;
            for (0..sample_count) |i| {
                // Read little-endian i16
                const low: u16 = audio.samples[src_idx];
                const high: u16 = audio.samples[src_idx + 1];
                const value: i16 = @bitCast(low | (high << 8));
                src_idx += 2;

                // Write f32 (use std.mem to handle alignment)
                const f32_value = @as(f32, @floatFromInt(value)) / 32768.0;
                std.mem.writeInt(u32, new_data[i * 4 ..][0..4], @bitCast(f32_value), .little);
            }
        },
        .u8 => {
            for (0..sample_count) |i| {
                const f32_value = (@as(f32, @floatFromInt(audio.samples[i])) - 128.0) / 128.0;
                std.mem.writeInt(u32, new_data[i * 4 ..][0..4], @bitCast(f32_value), .little);
            }
        },
        .f32 => unreachable, // Handled above
    }

    return Audio{
        .samples = new_data,
        .sample_rate = audio.sample_rate,
        .channels = audio.channels,
        .sample_format = .f32,
    };
}

// === Tests ===

test "Audio validation" {
    // Valid audio
    var samples = [_]u8{0} ** (16000 * 4); // 1 second of f32 samples
    const valid_audio = Audio{
        .samples = &samples,
        .sample_rate = 16000,
        .channels = 1,
        .sample_format = .f32,
    };
    try std.testing.expect(valid_audio.isValid());

    // Invalid: empty samples
    const empty_audio = Audio{
        .samples = &.{},
        .sample_rate = 16000,
        .channels = 1,
        .sample_format = .f32,
    };
    try std.testing.expect(!empty_audio.isValid());

    // Invalid: zero sample rate
    const zero_rate = Audio{
        .samples = &samples,
        .sample_rate = 0,
        .channels = 1,
        .sample_format = .f32,
    };
    try std.testing.expect(!zero_rate.isValid());

    // Invalid: zero channels
    const zero_channels = Audio{
        .samples = &samples,
        .sample_rate = 16000,
        .channels = 0,
        .sample_format = .f32,
    };
    try std.testing.expect(!zero_channels.isValid());
}

test "Audio getSampleCount" {
    // f32 format: 4 bytes per sample
    const f32_samples = [_]u8{0} ** 16;
    const f32_audio = Audio{
        .samples = &f32_samples,
        .sample_rate = 16000,
        .channels = 1,
        .sample_format = .f32,
    };
    try std.testing.expectEqual(@as(usize, 4), f32_audio.getSampleCount());

    // i16 format: 2 bytes per sample
    const i16_samples = [_]u8{0} ** 16;
    const i16_audio = Audio{
        .samples = &i16_samples,
        .sample_rate = 16000,
        .channels = 1,
        .sample_format = .i16,
    };
    try std.testing.expectEqual(@as(usize, 8), i16_audio.getSampleCount());

    // Stereo: divide by channels
    const stereo_audio = Audio{
        .samples = &f32_samples,
        .sample_rate = 16000,
        .channels = 2,
        .sample_format = .f32,
    };
    try std.testing.expectEqual(@as(usize, 2), stereo_audio.getSampleCount());
}

test "Audio getDuration" {
    const samples = [_]u8{0} ** (16000 * 4); // 1 second at 16kHz
    const audio = Audio{
        .samples = &samples,
        .sample_rate = 16000,
        .channels = 1,
        .sample_format = .f32,
    };
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), audio.getDuration(), 0.001);
}

test "Language getCode" {
    try std.testing.expectEqualStrings("en", Language.en.getCode());
    try std.testing.expectEqualStrings("ja", Language.ja.getCode());
    try std.testing.expectEqualStrings("auto", Language.auto.getCode());
}

test "WhisperModel initialization" {
    const allocator = std.testing.allocator;

    const model_config = ModelConfig.forWhisper("/path/to/whisper.gguf");

    const config = WhisperConfig{
        .model = model_config,
    };

    var model = try WhisperModel.init(config, allocator);
    defer model.deinit();

    try std.testing.expect(model.isReady());
}

test "WhisperModel transcribe" {
    const allocator = std.testing.allocator;

    const model_config = ModelConfig.forWhisper("/path/to/whisper.gguf");

    const config = WhisperConfig{
        .model = model_config,
        .language = .en,
    };

    var model = try WhisperModel.init(config, allocator);
    defer model.deinit();

    // Create test audio (1 second at 16kHz)
    var audio_samples = [_]u8{0} ** (16000 * 4);
    const audio = Audio{
        .samples = &audio_samples,
        .sample_rate = 16000,
        .channels = 1,
        .sample_format = .f32,
    };

    const result = try model.transcribe(audio);
    defer allocator.free(result.text);

    try std.testing.expect(result.text.len > 0);
}

test "WhisperModel translate" {
    const allocator = std.testing.allocator;

    const model_config = ModelConfig.forWhisper("/path/to/whisper.gguf");

    const config = WhisperConfig{
        .model = model_config,
        .language = .ja,
    };

    var model = try WhisperModel.init(config, allocator);
    defer model.deinit();

    var audio_samples = [_]u8{0} ** (8000 * 4); // 0.5 second
    const audio = Audio{
        .samples = &audio_samples,
        .sample_rate = 16000,
        .channels = 1,
        .sample_format = .f32,
    };

    const result = try model.translate(audio);
    defer allocator.free(result.text);

    try std.testing.expect(result.text.len > 0);
}

test "WhisperModel invalid audio error" {
    const allocator = std.testing.allocator;

    const model_config = ModelConfig.forWhisper("/path/to/whisper.gguf");

    const config = WhisperConfig{
        .model = model_config,
    };

    var model = try WhisperModel.init(config, allocator);
    defer model.deinit();

    // Invalid audio (empty samples)
    const invalid_audio = Audio{
        .samples = &.{},
        .sample_rate = 16000,
        .channels = 1,
        .sample_format = .f32,
    };

    const result = model.transcribe(invalid_audio);
    try std.testing.expectError(error.InvalidAudio, result);
}

test "WhisperModel invalid path error" {
    const allocator = std.testing.allocator;

    var model_config = ModelConfig{};
    model_config.model_type = .whisper;

    const config = WhisperConfig{
        .model = model_config,
    };

    const result = WhisperModel.init(config, allocator);
    try std.testing.expectError(error.InvalidModelPath, result);
}

test "resampleAudio no resample needed" {
    const allocator = std.testing.allocator;

    var samples = [_]u8{128} ** 64;
    const audio = Audio{
        .samples = &samples,
        .sample_rate = 16000,
        .channels = 1,
        .sample_format = .f32,
    };

    const resampled = try resampleAudio(audio, 16000, allocator);
    defer allocator.free(@constCast(resampled.samples));

    try std.testing.expectEqual(@as(u32, 16000), resampled.sample_rate);
    try std.testing.expectEqual(@as(usize, 64), resampled.samples.len);
}

test "convertToMono already mono" {
    const allocator = std.testing.allocator;

    var samples = [_]u8{100} ** 32;
    const audio = Audio{
        .samples = &samples,
        .sample_rate = 16000,
        .channels = 1,
        .sample_format = .f32,
    };

    const mono = try convertToMono(audio, allocator);
    defer allocator.free(@constCast(mono.samples));

    try std.testing.expectEqual(@as(u8, 1), mono.channels);
    try std.testing.expectEqual(@as(usize, 32), mono.samples.len);
}

test "convertToF32 from i16" {
    const allocator = std.testing.allocator;

    // Create i16 samples (little-endian): 16384, -16384
    const i16_samples = [_]u8{ 0x00, 0x40, 0x00, 0xC0 };
    const audio = Audio{
        .samples = &i16_samples,
        .sample_rate = 16000,
        .channels = 1,
        .sample_format = .i16,
    };

    const f32_audio = try convertToF32(audio, allocator);
    defer allocator.free(@constCast(f32_audio.samples));

    try std.testing.expectEqual(SampleFormat.f32, f32_audio.sample_format);
    try std.testing.expectEqual(@as(usize, 8), f32_audio.samples.len); // 2 samples * 4 bytes

    // Read f32 values safely using std.mem
    const value0: f32 = @bitCast(std.mem.readInt(u32, f32_audio.samples[0..4], .little));
    const value1: f32 = @bitCast(std.mem.readInt(u32, f32_audio.samples[4..8], .little));

    try std.testing.expectApproxEqAbs(@as(f32, 0.5), value0, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -0.5), value1, 0.001);
}

test "convertToF32 already f32" {
    const allocator = std.testing.allocator;

    var samples = [_]u8{0} ** 16;
    const audio = Audio{
        .samples = &samples,
        .sample_rate = 16000,
        .channels = 1,
        .sample_format = .f32,
    };

    const result = try convertToF32(audio, allocator);
    defer allocator.free(@constCast(result.samples));

    try std.testing.expectEqual(SampleFormat.f32, result.sample_format);
}

test "isWhisperAvailable" {
    // On native desktop builds, this should be true
    const available = isWhisperAvailable();
    if (@import("builtin").os.tag == .macos or @import("builtin").os.tag == .linux) {
        try std.testing.expect(available);
    }
}

test "getSampleRate" {
    const rate = getSampleRate();
    try std.testing.expectEqual(@as(u32, 16000), rate);
}

// Include submodule tests
test {
    _ = whisper_backend;
}
