//! VLM Stub Module
//!
//! Provides stub types for platforms without native C support.

const std = @import("std");
const types = @import("types.zig");

pub const MAX_IMAGE_SIZE: usize = 16 * 1024 * 1024;
pub const MAX_OUTPUT_LENGTH: usize = 4096;

pub const ImageFormat = enum(u8) {
    unknown = 0,
    jpeg = 1,
    png = 2,
    webp = 3,
    bmp = 4,
};

pub const Image = struct {
    data: []const u8,
    width: u32,
    height: u32,
    format: ImageFormat,
};

pub const VLMConfig = struct {
    model: types.ModelConfig = .{},
    max_image_size: u32 = 1024,
    detail_level: u8 = 1,
};

/// Stub VLM model - always fails on unsupported platforms
pub const VLMModel = struct {
    allocator: std.mem.Allocator,

    pub fn init(_: VLMConfig, _: std.mem.Allocator) !*VLMModel {
        return error.PlatformNotSupported;
    }

    pub fn deinit(_: *VLMModel) void {}
};
