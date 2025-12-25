//! VLM Backend Stub Module
//!
//! Provides stub types for platforms without native C support.

const std = @import("std");

/// Stub VLM backend
pub const VLMBackend = struct {
    pub fn init(_: std.mem.Allocator) !*VLMBackend {
        return error.PlatformNotSupported;
    }

    pub fn deinit(_: *VLMBackend) void {}

    pub fn isAvailable() bool {
        return false;
    }
};
