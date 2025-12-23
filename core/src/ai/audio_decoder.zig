//! Zylix AI - Audio Decoder Module
//!
//! High-level audio decoding interface using miniaudio.
//! Converts various audio formats to f32 PCM for Whisper processing.

const std = @import("std");
const miniaudio = @import("miniaudio.zig");

/// Supported audio formats
pub const AudioFormat = enum {
    wav,
    mp3,
    flac,
    ogg,
    unknown,

    pub fn fromExtension(ext: []const u8) AudioFormat {
        const lower = blk: {
            var buf: [8]u8 = undefined;
            const len = @min(ext.len, buf.len);
            for (ext[0..len], 0..) |ch, i| {
                buf[i] = if (ch >= 'A' and ch <= 'Z') ch + 32 else ch;
            }
            break :blk buf[0..len];
        };

        if (std.mem.eql(u8, lower, ".wav")) return .wav;
        if (std.mem.eql(u8, lower, ".mp3")) return .mp3;
        if (std.mem.eql(u8, lower, ".flac")) return .flac;
        if (std.mem.eql(u8, lower, ".ogg")) return .ogg;
        return .unknown;
    }

    pub fn toString(self: AudioFormat) []const u8 {
        return switch (self) {
            .wav => "WAV",
            .mp3 => "MP3",
            .flac => "FLAC",
            .ogg => "OGG/Vorbis",
            .unknown => "Unknown",
        };
    }
};

/// Audio metadata
pub const AudioInfo = struct {
    format: AudioFormat,
    channels: u32,
    sample_rate: u32,
    total_frames: u64,
    duration_seconds: f64,

    pub fn durationString(self: AudioInfo, buffer: []u8) []const u8 {
        const minutes = @as(u32, @intFromFloat(self.duration_seconds)) / 60;
        const seconds = @as(u32, @intFromFloat(self.duration_seconds)) % 60;
        return std.fmt.bufPrint(buffer, "{d}:{d:0>2}", .{ minutes, seconds }) catch "?:??";
    }
};

/// Audio decoder result
pub const DecodeResult = struct {
    /// Decoded audio samples in f32 format [-1.0, 1.0]
    samples: []f32,
    /// Audio metadata
    info: AudioInfo,
    /// Allocator used for samples
    allocator: std.mem.Allocator,

    pub fn deinit(self: *DecodeResult) void {
        self.allocator.free(self.samples);
    }
};

pub const DecodeError = error{
    FileNotFound,
    InvalidFile,
    InvalidFormat,
    UnsupportedFormat,
    OutOfMemory,
    DecodeFailed,
    NoData,
};

/// Decode audio file to f32 PCM samples
/// Automatically detects format from file extension
/// Returns mono audio at the file's native sample rate
pub fn decodeFile(allocator: std.mem.Allocator, path: []const u8) DecodeError!DecodeResult {
    return decodeFileWithSampleRate(allocator, path, 0);
}

/// Decode audio file to f32 PCM samples at specified sample rate
/// Automatically detects format from file extension
/// Use targetSampleRate = 0 to preserve the file's native sample rate
pub fn decodeFileWithSampleRate(allocator: std.mem.Allocator, path: []const u8, targetSampleRate: u32) DecodeError!DecodeResult {
    // Detect format from extension
    const ext = std.fs.path.extension(path);
    const format = AudioFormat.fromExtension(ext);

    if (format == .unknown) {
        return DecodeError.UnsupportedFormat;
    }

    // Create null-terminated path
    const path_z = allocator.allocSentinel(u8, path.len, 0) catch return DecodeError.OutOfMemory;
    defer allocator.free(path_z);
    @memcpy(path_z, path);

    // Create decoder
    const decoder = miniaudio.Decoder.create() orelse return DecodeError.OutOfMemory;
    defer decoder.destroy();

    // Initialize from file
    const init_result = decoder.initFile(path_z.ptr, targetSampleRate);
    if (!init_result.isSuccess()) {
        return switch (init_result) {
            .file_not_found => DecodeError.FileNotFound,
            .invalid_file => DecodeError.InvalidFile,
            .out_of_memory => DecodeError.OutOfMemory,
            else => DecodeError.DecodeFailed,
        };
    }

    // Get audio info
    const sample_rate = if (targetSampleRate > 0) targetSampleRate else decoder.getSampleRate();
    var total_frames = decoder.getLength();

    // Estimate if length unknown (streaming formats)
    if (total_frames == 0) {
        total_frames = 1024 * 1024; // 1M frames initial estimate
    }

    // Allocate buffer for decoded samples
    const buffer_size = @min(total_frames, 1024 * 1024 * 60); // Max 60M frames (~20 min at 48kHz)
    var samples = allocator.alloc(f32, buffer_size) catch return DecodeError.OutOfMemory;
    errdefer allocator.free(samples);

    // Read all frames
    var total_read: usize = 0;
    const chunk_size: u64 = 4096;

    while (total_read < samples.len) {
        const remaining = samples.len - total_read;
        const to_read = @min(chunk_size, remaining);

        const frames_read = decoder.readFrames(samples[total_read..].ptr, to_read);
        if (frames_read == 0) break;
        total_read += @intCast(frames_read);
    }

    if (total_read == 0) {
        allocator.free(samples);
        return DecodeError.NoData;
    }

    // Resize to actual read size
    if (total_read < samples.len) {
        samples = allocator.realloc(samples, total_read) catch samples;
    }

    const duration = @as(f64, @floatFromInt(total_read)) / @as(f64, @floatFromInt(sample_rate));

    return DecodeResult{
        .samples = samples[0..total_read],
        .info = AudioInfo{
            .format = format,
            .channels = 1, // Always mono output
            .sample_rate = sample_rate,
            .total_frames = total_read,
            .duration_seconds = duration,
        },
        .allocator = allocator,
    };
}

/// Decode audio file for Whisper (16kHz mono f32)
/// Supports WAV, MP3, FLAC, and OGG formats
pub fn decodeFileForWhisper(allocator: std.mem.Allocator, path: []const u8) DecodeError!DecodeResult {
    return decodeFileWithSampleRate(allocator, path, 16000);
}

/// Decode audio from memory buffer
pub fn decodeMemory(allocator: std.mem.Allocator, data: []const u8, format: AudioFormat) DecodeError!DecodeResult {
    return decodeMemoryWithSampleRate(allocator, data, format, 0);
}

/// Decode audio from memory buffer at specified sample rate
pub fn decodeMemoryWithSampleRate(allocator: std.mem.Allocator, data: []const u8, format: AudioFormat, targetSampleRate: u32) DecodeError!DecodeResult {
    if (format == .unknown) {
        return DecodeError.UnsupportedFormat;
    }

    // Create decoder
    const decoder = miniaudio.Decoder.create() orelse return DecodeError.OutOfMemory;
    defer decoder.destroy();

    // Initialize from memory
    const init_result = decoder.initMemory(data.ptr, data.len, targetSampleRate);
    if (!init_result.isSuccess()) {
        return switch (init_result) {
            .invalid_file => DecodeError.InvalidFile,
            .out_of_memory => DecodeError.OutOfMemory,
            else => DecodeError.DecodeFailed,
        };
    }

    // Get audio info
    const sample_rate = if (targetSampleRate > 0) targetSampleRate else decoder.getSampleRate();
    var total_frames = decoder.getLength();

    if (total_frames == 0) {
        total_frames = 1024 * 1024;
    }

    const buffer_size = @min(total_frames, 1024 * 1024 * 60);
    var samples = allocator.alloc(f32, buffer_size) catch return DecodeError.OutOfMemory;
    errdefer allocator.free(samples);

    var total_read: usize = 0;
    const chunk_size: u64 = 4096;

    while (total_read < samples.len) {
        const remaining = samples.len - total_read;
        const to_read = @min(chunk_size, remaining);

        const frames_read = decoder.readFrames(samples[total_read..].ptr, to_read);
        if (frames_read == 0) break;
        total_read += @intCast(frames_read);
    }

    if (total_read == 0) {
        allocator.free(samples);
        return DecodeError.NoData;
    }

    if (total_read < samples.len) {
        samples = allocator.realloc(samples, total_read) catch samples;
    }

    const duration = @as(f64, @floatFromInt(total_read)) / @as(f64, @floatFromInt(sample_rate));

    return DecodeResult{
        .samples = samples[0..total_read],
        .info = AudioInfo{
            .format = format,
            .channels = 1,
            .sample_rate = sample_rate,
            .total_frames = total_read,
            .duration_seconds = duration,
        },
        .allocator = allocator,
    };
}

/// Get audio file info without decoding
pub fn getFileInfo(allocator: std.mem.Allocator, path: []const u8) DecodeError!AudioInfo {
    // Detect format from extension
    const ext = std.fs.path.extension(path);
    const format = AudioFormat.fromExtension(ext);

    if (format == .unknown) {
        return DecodeError.UnsupportedFormat;
    }

    // Create null-terminated path
    const path_z = allocator.allocSentinel(u8, path.len, 0) catch return DecodeError.OutOfMemory;
    defer allocator.free(path_z);
    @memcpy(path_z, path);

    // Create decoder
    const decoder = miniaudio.Decoder.create() orelse return DecodeError.OutOfMemory;
    defer decoder.destroy();

    const init_result = decoder.initFile(path_z.ptr, 0);
    if (!init_result.isSuccess()) {
        return DecodeError.FileNotFound;
    }

    const sample_rate = decoder.getSampleRate();
    const total_frames = decoder.getLength();

    const duration = if (sample_rate > 0)
        @as(f64, @floatFromInt(total_frames)) / @as(f64, @floatFromInt(sample_rate))
    else
        0.0;

    return AudioInfo{
        .format = format,
        .channels = 1,
        .sample_rate = sample_rate,
        .total_frames = total_frames,
        .duration_seconds = duration,
    };
}

/// Check if audio decoding is available
pub fn isAvailable() bool {
    return miniaudio.isAvailable();
}

/// Get list of supported file extensions
pub fn getSupportedExtensions() []const []const u8 {
    return miniaudio.getSupportedExtensions();
}

/// Check if file format is supported
pub fn isFormatSupported(path: []const u8) bool {
    const ext = std.fs.path.extension(path);
    return AudioFormat.fromExtension(ext) != .unknown;
}

// === Tests ===

test "AudioFormat from extension" {
    try std.testing.expectEqual(AudioFormat.wav, AudioFormat.fromExtension(".wav"));
    try std.testing.expectEqual(AudioFormat.mp3, AudioFormat.fromExtension(".mp3"));
    try std.testing.expectEqual(AudioFormat.flac, AudioFormat.fromExtension(".flac"));
    try std.testing.expectEqual(AudioFormat.ogg, AudioFormat.fromExtension(".ogg"));
    try std.testing.expectEqual(AudioFormat.wav, AudioFormat.fromExtension(".WAV"));
    try std.testing.expectEqual(AudioFormat.mp3, AudioFormat.fromExtension(".MP3"));
    try std.testing.expectEqual(AudioFormat.unknown, AudioFormat.fromExtension(".txt"));
}

test "isAvailable" {
    try std.testing.expect(isAvailable());
}

test "isFormatSupported" {
    try std.testing.expect(isFormatSupported("audio.wav"));
    try std.testing.expect(isFormatSupported("audio.mp3"));
    try std.testing.expect(isFormatSupported("audio.flac"));
    try std.testing.expect(!isFormatSupported("audio.txt"));
}
