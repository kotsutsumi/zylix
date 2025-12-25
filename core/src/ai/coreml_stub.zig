//! Core ML Stub Module
//!
//! Provides stub types for platforms without Core ML support.

const std = @import("std");

pub const ComputeUnits = enum(u8) {
    cpu_only = 0,
    cpu_and_gpu = 1,
    all = 2,
    cpu_and_ne = 3,
};

pub const Config = struct {
    compute_units: ComputeUnits = .all,
    allow_low_precision: bool = true,
};

/// Stub Core ML model - always fails on unsupported platforms
pub const Model = struct {
    allocator: std.mem.Allocator,

    pub fn load(_: std.mem.Allocator, _: []const u8, _: Config) !*Model {
        return error.CoreMLNotAvailable;
    }

    pub fn deinit(_: *Model) void {}

    pub fn generateEmbeddings(_: *Model, _: []const i32, _: []f32) !void {
        return error.CoreMLNotAvailable;
    }
};

/// Core ML not available on stub platform
pub fn isAvailable() bool {
    return false;
}

/// Get default config
pub fn getDefaultConfig() Config {
    return .{};
}
