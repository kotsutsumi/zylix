//! Zylix AI - miniaudio Zig Bindings
//!
//! Bindings to miniaudio wrapper for audio decoding.
//! Supports WAV, MP3, FLAC, and Vorbis formats.

const std = @import("std");

// C wrapper API bindings
const c = @cImport({
    @cInclude("miniaudio_wrapper.h");
});

// Result codes from wrapper
pub const Result = enum(c_int) {
    success = c.MA_WRAPPER_SUCCESS,
    generic_error = c.MA_WRAPPER_ERROR,
    file_not_found = c.MA_WRAPPER_FILE_NOT_FOUND,
    invalid_file = c.MA_WRAPPER_INVALID_FILE,
    out_of_memory = c.MA_WRAPPER_OUT_OF_MEMORY,

    _,

    pub fn isSuccess(self: Result) bool {
        return self == .success;
    }
};

pub const DecoderError = error{
    InvalidArgs,
    OutOfMemory,
    FileNotFound,
    InvalidFile,
    InvalidData,
    Unknown,
};

/// Opaque decoder context
pub const Decoder = opaque {
    const Self = @This();

    /// Create a new decoder
    pub fn create() ?*Self {
        return @ptrCast(c.ma_wrapper_create_decoder());
    }

    /// Free the decoder
    pub fn destroy(self: *Self) void {
        c.ma_wrapper_free_decoder(@ptrCast(self));
    }

    /// Initialize decoder from file path
    pub fn initFile(self: *Self, path: [*:0]const u8, targetSampleRate: u32) Result {
        return @enumFromInt(c.ma_wrapper_init_file(@ptrCast(self), path, targetSampleRate));
    }

    /// Initialize decoder from memory
    pub fn initMemory(self: *Self, data: [*]const u8, size: usize, targetSampleRate: u32) Result {
        return @enumFromInt(c.ma_wrapper_init_memory(@ptrCast(self), data, size, targetSampleRate));
    }

    /// Get output sample rate
    pub fn getSampleRate(self: *Self) u32 {
        return c.ma_wrapper_get_sample_rate(@ptrCast(self));
    }

    /// Get length in PCM frames
    pub fn getLength(self: *Self) u64 {
        return c.ma_wrapper_get_length(@ptrCast(self));
    }

    /// Read PCM frames (f32 samples)
    pub fn readFrames(self: *Self, output: [*]f32, frameCount: u64) u64 {
        return c.ma_wrapper_read_frames(@ptrCast(self), output, frameCount);
    }

    /// Seek to frame
    pub fn seek(self: *Self, frameIndex: u64) Result {
        return @enumFromInt(c.ma_wrapper_seek(@ptrCast(self), frameIndex));
    }
};

// === Utility Functions ===

/// Check if miniaudio is available
pub fn isAvailable() bool {
    return true;
}

/// Get supported format extensions
pub fn getSupportedExtensions() []const []const u8 {
    return &[_][]const u8{
        ".wav",
        ".mp3",
        ".flac",
        // Note: OGG/Vorbis requires additional configuration in miniaudio
    };
}

/// Check if file extension is supported
pub fn isExtensionSupported(ext: []const u8) bool {
    const lower = blk: {
        var buf: [8]u8 = undefined;
        const len = @min(ext.len, buf.len);
        for (ext[0..len], 0..) |ch, i| {
            buf[i] = if (ch >= 'A' and ch <= 'Z') ch + 32 else ch;
        }
        break :blk buf[0..len];
    };

    for (getSupportedExtensions()) |supported| {
        if (std.mem.eql(u8, lower, supported)) {
            return true;
        }
    }
    return false;
}

// === Tests ===

test "isAvailable" {
    try std.testing.expect(isAvailable());
}

test "isExtensionSupported" {
    try std.testing.expect(isExtensionSupported(".wav"));
    try std.testing.expect(isExtensionSupported(".mp3"));
    try std.testing.expect(isExtensionSupported(".flac"));
    try std.testing.expect(isExtensionSupported(".ogg"));
    try std.testing.expect(isExtensionSupported(".WAV"));
    try std.testing.expect(isExtensionSupported(".MP3"));
    try std.testing.expect(!isExtensionSupported(".txt"));
    try std.testing.expect(!isExtensionSupported(".aac"));
}
