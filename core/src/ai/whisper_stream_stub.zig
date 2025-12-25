//! Whisper Stream Stub Module
//!
//! Provides stub types for platforms without native C support.

const std = @import("std");

pub const StreamState = enum(u8) {
    idle = 0,
    listening = 1,
    processing = 2,
    paused = 3,
};

pub const StreamConfig = struct {
    language: u8 = 0,
    translate: bool = false,
    vad_enabled: bool = true,
    silence_threshold: f32 = 0.01,
};

pub const StreamSegment = struct {
    text: []const u8 = "",
    start_ms: u32 = 0,
    end_ms: u32 = 0,
    is_final: bool = false,
};

/// Stub streaming context - always fails on unsupported platforms
pub const StreamingContext = struct {
    pub fn init(_: StreamConfig, _: std.mem.Allocator) !*StreamingContext {
        return error.PlatformNotSupported;
    }

    pub fn deinit(_: *StreamingContext) void {}
};
