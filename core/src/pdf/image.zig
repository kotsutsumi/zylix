//! Zylix PDF - Image Handling
//!
//! Image embedding and manipulation for PDF documents.

const std = @import("std");
const types = @import("types.zig");

const ImageFormat = types.ImageFormat;
const Compression = types.Compression;
const PdfError = types.PdfError;

/// Image color space
pub const ColorSpace = enum {
    grayscale,
    rgb,
    rgba,
    cmyk,
    indexed,
};

/// Image representation
pub const Image = struct {
    allocator: std.mem.Allocator,
    width: u32,
    height: u32,
    bits_per_component: u8,
    color_space: ColorSpace,
    data: []u8,
    format: ImageFormat,
    compression: Compression,

    /// Create image from raw pixel data
    pub fn create(
        allocator: std.mem.Allocator,
        width: u32,
        height: u32,
        color_space: ColorSpace,
        data: []const u8,
    ) !*Image {
        const img = try allocator.create(Image);
        const data_copy = try allocator.dupe(u8, data);

        img.* = .{
            .allocator = allocator,
            .width = width,
            .height = height,
            .bits_per_component = 8,
            .color_space = color_space,
            .data = data_copy,
            .format = .png,
            .compression = .flate,
        };

        return img;
    }

    /// Load image from file
    pub fn loadFromFile(allocator: std.mem.Allocator, path: []const u8) !*Image {
        const file = std.fs.cwd().openFile(path, .{}) catch {
            return PdfError.ImageDecodingFailed;
        };
        defer file.close();

        const stat = try file.stat();
        const data = try allocator.alloc(u8, stat.size);
        errdefer allocator.free(data);

        _ = try file.readAll(data);

        return loadFromMemory(allocator, data);
    }

    /// Load image from memory
    pub fn loadFromMemory(allocator: std.mem.Allocator, data: []const u8) !*Image {
        // Detect format and decode
        const format = detectFormat(data);

        return switch (format) {
            .jpeg => decodeJpeg(allocator, data),
            .png => decodePng(allocator, data),
            else => PdfError.ImageDecodingFailed,
        };
    }

    pub fn deinit(self: *Image) void {
        self.allocator.free(self.data);
    }

    /// Get number of components per pixel
    pub fn getComponentCount(self: *const Image) u8 {
        return switch (self.color_space) {
            .grayscale => 1,
            .rgb => 3,
            .rgba => 4,
            .cmyk => 4,
            .indexed => 1,
        };
    }

    /// Get bytes per row
    pub fn getStride(self: *const Image) u32 {
        return self.width * self.getComponentCount();
    }

    /// Get pixel at position
    pub fn getPixel(self: *const Image, x: u32, y: u32) ?[]const u8 {
        if (x >= self.width or y >= self.height) return null;

        const comp = self.getComponentCount();
        const offset = (y * self.width + x) * comp;

        if (offset + comp > self.data.len) return null;
        return self.data[offset .. offset + comp];
    }

    /// Scale image to new dimensions
    pub fn scale(self: *const Image, new_width: u32, new_height: u32) !*Image {
        const comp = self.getComponentCount();
        const new_data = try self.allocator.alloc(u8, new_width * new_height * comp);
        errdefer self.allocator.free(new_data);

        // Nearest-neighbor resampling
        const x_ratio: f32 = @as(f32, @floatFromInt(self.width - 1)) / @as(f32, @floatFromInt(new_width));
        const y_ratio: f32 = @as(f32, @floatFromInt(self.height - 1)) / @as(f32, @floatFromInt(new_height));

        var y: u32 = 0;
        while (y < new_height) : (y += 1) {
            var x: u32 = 0;
            while (x < new_width) : (x += 1) {
                const src_x = @as(f32, @floatFromInt(x)) * x_ratio;
                const src_y = @as(f32, @floatFromInt(y)) * y_ratio;

                const x0 = @as(u32, @intFromFloat(src_x));
                const y0 = @as(u32, @intFromFloat(src_y));

                const dst_offset = (y * new_width + x) * comp;
                const src_offset = (y0 * self.width + x0) * comp;

                // Simple nearest neighbor for now
                @memcpy(new_data[dst_offset .. dst_offset + comp], self.data[src_offset .. src_offset + comp]);
            }
        }

        const img = try self.allocator.create(Image);
        img.* = .{
            .allocator = self.allocator,
            .width = new_width,
            .height = new_height,
            .bits_per_component = self.bits_per_component,
            .color_space = self.color_space,
            .data = new_data,
            .format = self.format,
            .compression = self.compression,
        };

        return img;
    }

    /// Convert to grayscale
    pub fn toGrayscale(self: *const Image) !*Image {
        if (self.color_space == .grayscale) {
            // Already grayscale, just clone
            return self.clone();
        }

        const new_data = try self.allocator.alloc(u8, self.width * self.height);
        errdefer self.allocator.free(new_data);

        const comp = self.getComponentCount();
        var i: usize = 0;
        var j: usize = 0;

        while (i < self.data.len) : (i += comp) {
            const r = self.data[i];
            const g = if (comp > 1) self.data[i + 1] else r;
            const b = if (comp > 2) self.data[i + 2] else r;

            // Luminosity formula
            const gray = @as(u8, @intFromFloat(0.299 * @as(f32, @floatFromInt(r)) + 0.587 * @as(f32, @floatFromInt(g)) + 0.114 * @as(f32, @floatFromInt(b))));

            new_data[j] = gray;
            j += 1;
        }

        const img = try self.allocator.create(Image);
        img.* = .{
            .allocator = self.allocator,
            .width = self.width,
            .height = self.height,
            .bits_per_component = 8,
            .color_space = .grayscale,
            .data = new_data,
            .format = self.format,
            .compression = self.compression,
        };

        return img;
    }

    /// Clone the image
    pub fn clone(self: *const Image) !*Image {
        const data_copy = try self.allocator.dupe(u8, self.data);
        errdefer self.allocator.free(data_copy);

        const img = try self.allocator.create(Image);
        img.* = .{
            .allocator = self.allocator,
            .width = self.width,
            .height = self.height,
            .bits_per_component = self.bits_per_component,
            .color_space = self.color_space,
            .data = data_copy,
            .format = self.format,
            .compression = self.compression,
        };

        return img;
    }
};

/// Detect image format from magic bytes
fn detectFormat(data: []const u8) ImageFormat {
    if (data.len < 8) return .png;

    // JPEG: FF D8 FF
    if (data[0] == 0xFF and data[1] == 0xD8 and data[2] == 0xFF) {
        return .jpeg;
    }

    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (data[0] == 0x89 and data[1] == 0x50 and data[2] == 0x4E and data[3] == 0x47) {
        return .png;
    }

    // GIF: 47 49 46 38
    if (data[0] == 0x47 and data[1] == 0x49 and data[2] == 0x46) {
        return .gif;
    }

    // BMP: 42 4D
    if (data[0] == 0x42 and data[1] == 0x4D) {
        return .bmp;
    }

    // TIFF: 49 49 or 4D 4D
    if ((data[0] == 0x49 and data[1] == 0x49) or (data[0] == 0x4D and data[1] == 0x4D)) {
        return .tiff;
    }

    return .png;
}

/// Decode JPEG image (placeholder - would need full JPEG decoder)
fn decodeJpeg(allocator: std.mem.Allocator, data: []const u8) !*Image {
    // For JPEG in PDF, we can embed the raw data directly
    // PDF readers handle JPEG decompression
    const img = try allocator.create(Image);
    const data_copy = try allocator.dupe(u8, data);

    // Try to parse JPEG header for dimensions
    var width: u32 = 0;
    var height: u32 = 0;

    if (data.len > 10) {
        var i: usize = 2;
        while (i < data.len - 8) {
            if (data[i] == 0xFF) {
                const marker = data[i + 1];
                // SOF0, SOF1, SOF2 markers contain dimensions
                if (marker >= 0xC0 and marker <= 0xC2) {
                    height = (@as(u32, data[i + 5]) << 8) | @as(u32, data[i + 6]);
                    width = (@as(u32, data[i + 7]) << 8) | @as(u32, data[i + 8]);
                    break;
                }
                if (marker == 0xD9) break; // EOI
                if (i + 3 < data.len) {
                    const len = (@as(usize, data[i + 2]) << 8) | @as(usize, data[i + 3]);
                    i += len + 2;
                } else {
                    break;
                }
            } else {
                i += 1;
            }
        }
    }

    if (width == 0) width = 100;
    if (height == 0) height = 100;

    img.* = .{
        .allocator = allocator,
        .width = width,
        .height = height,
        .bits_per_component = 8,
        .color_space = .rgb,
        .data = data_copy,
        .format = .jpeg,
        .compression = .jpeg,
    };

    return img;
}

/// Decode PNG image (placeholder - would need full PNG decoder)
fn decodePng(allocator: std.mem.Allocator, data: []const u8) !*Image {
    // For PNG, we need to decode it to raw pixels for PDF
    const img = try allocator.create(Image);

    // Parse PNG header for dimensions
    var width: u32 = 100;
    var height: u32 = 100;
    var color_type: u8 = 2;

    if (data.len > 24 and data[0] == 0x89 and data[1] == 0x50) {
        // IHDR chunk should be at offset 8
        width = (@as(u32, data[16]) << 24) | (@as(u32, data[17]) << 16) | (@as(u32, data[18]) << 8) | @as(u32, data[19]);
        height = (@as(u32, data[20]) << 24) | (@as(u32, data[21]) << 16) | (@as(u32, data[22]) << 8) | @as(u32, data[23]);
        color_type = data[25];
    }

    const color_space: ColorSpace = switch (color_type) {
        0 => .grayscale,
        2 => .rgb,
        4 => .grayscale, // Grayscale + alpha
        6 => .rgba,
        else => .rgb,
    };

    // For now, store raw PNG data
    // Full implementation would decompress and decode
    const data_copy = try allocator.dupe(u8, data);

    img.* = .{
        .allocator = allocator,
        .width = width,
        .height = height,
        .bits_per_component = 8,
        .color_space = color_space,
        .data = data_copy,
        .format = .png,
        .compression = .flate,
    };

    return img;
}

/// Image placement options
pub const ImageOptions = struct {
    x: f32 = 0,
    y: f32 = 0,
    width: ?f32 = null,
    height: ?f32 = null,
    rotation: f32 = 0, // radians
    opacity: f32 = 1.0,
    fit: FitMode = .none,

    pub const FitMode = enum {
        none, // Use specified or original dimensions
        contain, // Fit within bounds, maintain aspect ratio
        cover, // Cover bounds, maintain aspect ratio
        fill, // Fill bounds, may distort
    };
};

// Unit tests
test "Image creation" {
    const allocator = std.testing.allocator;

    const data = [_]u8{ 255, 0, 0, 0, 255, 0, 0, 0, 255 }; // 3 RGB pixels
    const img = try Image.create(allocator, 3, 1, .rgb, &data);
    defer {
        img.deinit();
        allocator.destroy(img);
    }

    try std.testing.expectEqual(img.width, 3);
    try std.testing.expectEqual(img.height, 1);
    try std.testing.expectEqual(img.getComponentCount(), 3);
}

test "Format detection" {
    const jpeg_header = [_]u8{ 0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0 };
    try std.testing.expectEqual(detectFormat(&jpeg_header), .jpeg);

    const png_header = [_]u8{ 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A };
    try std.testing.expectEqual(detectFormat(&png_header), .png);
}

test "Image clone" {
    const allocator = std.testing.allocator;

    const data = [_]u8{ 100, 150, 200 };
    const img = try Image.create(allocator, 1, 1, .rgb, &data);
    defer {
        img.deinit();
        allocator.destroy(img);
    }

    const cloned = try img.clone();
    defer {
        cloned.deinit();
        allocator.destroy(cloned);
    }

    try std.testing.expectEqual(cloned.width, img.width);
    try std.testing.expectEqualSlices(u8, cloned.data, img.data);
}
