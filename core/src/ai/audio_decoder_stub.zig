//! Audio Decoder Stub Module
//!
//! Provides stub types for platforms without native C support.

const std = @import("std");

pub const AudioFormat = enum(u8) {
    unknown = 0,
    wav = 1,
    mp3 = 2,
    flac = 3,
    ogg = 4,
    opus = 5,
};

pub const AudioInfo = struct {
    format: AudioFormat = .unknown,
    sample_rate: u32 = 0,
    channels: u8 = 0,
    duration_ms: u32 = 0,
    bit_depth: u8 = 0,
};

pub const DecodeResult = struct {
    samples: []f32 = &.{},
    info: AudioInfo = .{},
};

/// Stub - decode not available on this platform
pub fn decode(_: std.mem.Allocator, _: []const u8) !DecodeResult {
    return error.PlatformNotSupported;
}

/// Stub - format detection
pub fn detectFormat(_: []const u8) AudioFormat {
    return .unknown;
}
