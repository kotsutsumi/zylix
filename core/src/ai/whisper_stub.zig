//! Whisper Stub Module
//!
//! Provides stub types for platforms without native C support.

const std = @import("std");
const types = @import("types.zig");

pub const MAX_AUDIO_DURATION: u32 = 30 * 60;
pub const SAMPLE_RATE: u32 = 16000;

pub const Language = enum(u8) {
    auto = 0,
    en = 1,
    zh = 2,
    de = 3,
    es = 4,
    ru = 5,
    ko = 6,
    fr = 7,
    ja = 8,
    pt = 9,
    tr = 10,
    pl = 11,
    it = 12,
    nl = 13,
    sv = 14,
};

pub const Audio = struct {
    samples: []const f32,
    sample_rate: u32,
    channels: u8,
    duration_ms: u32,
};

pub const WhisperConfig = struct {
    model: types.ModelConfig = .{},
    language: Language = .auto,
    translate: bool = false,
    timestamps: bool = true,
};

/// Stub Whisper model - always fails on unsupported platforms
pub const WhisperModel = struct {
    allocator: std.mem.Allocator,

    pub fn init(_: WhisperConfig, _: std.mem.Allocator) !*WhisperModel {
        return error.PlatformNotSupported;
    }

    pub fn deinit(_: *WhisperModel) void {}
};
