//! VLM Backend Stub Module
//!
//! Provides stub types for platforms without native C support.

const std = @import("std");

/// VLM Backend Status (stub)
pub const VLMStatus = enum {
    uninitialized,
    ready,
    processing,
    error_state,
};

/// VLM Configuration (stub)
pub const VLMConfig = struct {
    model_path: []const u8 = "",
    mmproj_path: []const u8 = "",
    n_threads: u32 = 4,
    use_gpu: bool = true,
    n_ctx: u32 = 2048,
    max_tokens: u32 = 512,
    temperature: f32 = 0.1,
    top_p: f32 = 0.9,
};

/// Analysis result (stub)
pub const AnalysisResult = struct {
    text_len: usize = 0,
    n_input_tokens: usize = 0,
    n_output_tokens: usize = 0,
    processing_time_ms: u64 = 0,
    language: [8]u8 = [_]u8{0} ** 8,
};

/// Stub VLM backend
pub const VLMBackend = struct {
    status: VLMStatus = .uninitialized,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, _: VLMConfig) !*Self {
        _ = allocator;
        return error.PlatformNotSupported;
    }

    pub fn deinit(_: *Self) void {}

    pub fn supportsVision(_: *const Self) bool {
        return false;
    }

    pub fn supportsAudio(_: *const Self) bool {
        return false;
    }
};

/// Check if VLM backend is available (stub - always false)
pub fn isVLMAvailable() bool {
    return false;
}
