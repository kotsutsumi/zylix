//! Whisper Backend Stub Module
//!
//! Provides stub types for platforms without native C support.

const std = @import("std");

/// Whisper configuration (stub)
pub const WhisperConfig = struct {
    model_path: []const u8 = "",
    language: []const u8 = "",
    translate: bool = false,
    n_threads: u8 = 4,
    use_gpu: bool = true,
    print_progress: bool = false,
    max_tokens_per_segment: u32 = 0,
};

/// Whisper backend status (stub)
pub const WhisperStatus = enum(u8) {
    uninitialized = 0,
    loading = 1,
    ready = 2,
    transcribing = 3,
    @"error" = 4,
    shutdown = 5,
};

/// Transcription result (stub)
pub const TranscriptResult = struct {
    text: []u8 = &.{},
    text_len: usize = 0,
    language: [8]u8 = [_]u8{0} ** 8,
    n_segments: usize = 0,
};

/// Whisper backend stub for platforms without native C support
pub const WhisperBackend = struct {
    status: WhisperStatus = .uninitialized,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, _: WhisperConfig) !*Self {
        _ = allocator;
        return error.PlatformNotSupported;
    }

    pub fn deinit(_: *Self) void {}

    pub fn isLoaded(_: *const Self) bool {
        return false;
    }

    pub fn getStatus(_: *const Self) WhisperStatus {
        return .uninitialized;
    }

    pub fn getVersion() []const u8 {
        return "stub";
    }

    pub fn getLanguageCount() usize {
        return 0;
    }
};

/// Check if Whisper backend is available (stub - always false)
pub fn isWhisperAvailable() bool {
    return false;
}

/// Get expected sample rate for Whisper input (stub)
pub fn getSampleRate() u32 {
    return 16000;
}
