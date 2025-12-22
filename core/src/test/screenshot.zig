// Zylix Test Framework - Screenshot API
// Provides screenshot capture, comparison, and visual regression testing

const std = @import("std");
const driver_mod = @import("driver.zig");

pub const Screenshot = driver_mod.Screenshot;
pub const CompareResult = driver_mod.CompareResult;
pub const DriverError = driver_mod.DriverError;

/// Screenshot comparison configuration
pub const CompareConfig = struct {
    /// Threshold for considering pixels different (0-255 per channel)
    color_threshold: u8 = 5,
    /// Percentage of different pixels to tolerate
    diff_threshold: f32 = 0.01,
    /// Ignore anti-aliasing differences
    ignore_antialiasing: bool = true,
    /// Ignore alpha channel
    ignore_alpha: bool = false,
    /// Region to compare (null = full image)
    region: ?Region = null,
    /// Generate diff image
    generate_diff: bool = true,
};

/// Region for partial comparison
pub const Region = struct {
    x: u32,
    y: u32,
    width: u32,
    height: u32,
};

/// Compare two screenshots pixel by pixel
pub fn compareImages(actual: Screenshot, baseline: Screenshot, config: CompareConfig) CompareResult {
    if (actual.width != baseline.width or actual.height != baseline.height) {
        return CompareResult{
            .matches = false,
            .diff_percentage = 1.0,
            .diff_pixels = actual.width * actual.height,
        };
    }

    const region = config.region orelse Region{
        .x = 0,
        .y = 0,
        .width = actual.width,
        .height = actual.height,
    };

    var diff_pixels: u32 = 0;
    const total_pixels = region.width * region.height;
    const bytes_per_pixel: u32 = switch (actual.format) {
        .rgba => 4,
        .rgb => 3,
        else => 4,
    };

    var y: u32 = region.y;
    while (y < region.y + region.height) : (y += 1) {
        var x: u32 = region.x;
        while (x < region.x + region.width) : (x += 1) {
            const idx = (y * actual.width + x) * bytes_per_pixel;
            if (idx + bytes_per_pixel > actual.pixels.len or idx + bytes_per_pixel > baseline.pixels.len) {
                diff_pixels += 1;
                continue;
            }

            const actual_pixel = actual.pixels[idx .. idx + bytes_per_pixel];
            const baseline_pixel = baseline.pixels[idx .. idx + bytes_per_pixel];

            if (!pixelsMatch(actual_pixel, baseline_pixel, config)) {
                if (config.ignore_antialiasing and isAntialiased(actual.pixels, x, y, actual.width, bytes_per_pixel)) {
                    continue;
                }
                diff_pixels += 1;
            }
        }
    }

    const diff_percentage = @as(f32, @floatFromInt(diff_pixels)) / @as(f32, @floatFromInt(total_pixels));
    const matches = diff_percentage <= config.diff_threshold;

    return CompareResult{
        .matches = matches,
        .diff_percentage = diff_percentage,
        .diff_pixels = diff_pixels,
        .diff_image = null, // TODO: Generate diff image if config.generate_diff
    };
}

/// Compare screenshot with baseline file
pub fn compare(actual: Screenshot, baseline_path: []const u8, allocator: std.mem.Allocator) DriverError!CompareResult {
    const baseline = loadImage(baseline_path, allocator) catch return DriverError.ScreenshotFailed;
    defer allocator.free(baseline.pixels);
    return compareImages(actual, baseline, .{});
}

/// Compare with custom configuration
pub fn compareWithConfig(actual: Screenshot, baseline_path: []const u8, config: CompareConfig, allocator: std.mem.Allocator) DriverError!CompareResult {
    const baseline = loadImage(baseline_path, allocator) catch return DriverError.ScreenshotFailed;
    defer allocator.free(baseline.pixels);
    return compareImages(actual, baseline, config);
}

/// Save screenshot to file
pub fn save(screenshot: Screenshot, path: []const u8) DriverError!void {
    const file = std.fs.cwd().createFile(path, .{}) catch return DriverError.ScreenshotFailed;
    defer file.close();

    // Write as raw RGBA or encode as PNG
    if (std.mem.endsWith(u8, path, ".raw")) {
        file.writeAll(screenshot.pixels) catch return DriverError.ScreenshotFailed;
    } else if (std.mem.endsWith(u8, path, ".png")) {
        writePng(file, screenshot) catch return DriverError.ScreenshotFailed;
    } else {
        // Default to raw format
        file.writeAll(screenshot.pixels) catch return DriverError.ScreenshotFailed;
    }
}

/// Load image from file
pub fn loadImage(path: []const u8, allocator: std.mem.Allocator) !Screenshot {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    if (std.mem.endsWith(u8, path, ".png")) {
        return readPng(file, allocator);
    } else {
        // Assume raw format - need header or known dimensions
        const stat = try file.stat();
        const pixels = try allocator.alloc(u8, stat.size);
        const bytes_read = try file.readAll(pixels);
        if (bytes_read != stat.size) {
            allocator.free(pixels);
            return error.IncompleteRead;
        }

        // Assume square RGBA image
        const side = std.math.sqrt(stat.size / 4);
        return Screenshot{
            .width = @intCast(side),
            .height = @intCast(side),
            .pixels = pixels,
            .format = .rgba,
        };
    }
}

// Helper functions

fn pixelsMatch(a: []const u8, b: []const u8, config: CompareConfig) bool {
    const channels = if (config.ignore_alpha and a.len >= 4) 3 else a.len;

    var i: usize = 0;
    while (i < channels) : (i += 1) {
        const diff = if (a[i] > b[i]) a[i] - b[i] else b[i] - a[i];
        if (diff > config.color_threshold) {
            return false;
        }
    }
    return true;
}

fn isAntialiased(pixels: []const u8, x: u32, y: u32, width: u32, bpp: u32) bool {
    // Check if pixel is on an edge by comparing with neighbors
    const neighbors = [_][2]i32{
        .{ -1, 0 },
        .{ 1, 0 },
        .{ 0, -1 },
        .{ 0, 1 },
    };

    var similar_count: u32 = 0;
    const center_idx = (y * width + x) * bpp;

    for (neighbors) |offset| {
        const nx = @as(i64, @intCast(x)) + offset[0];
        const ny = @as(i64, @intCast(y)) + offset[1];

        if (nx < 0 or ny < 0 or nx >= width or ny >= width) continue;

        const neighbor_idx = (@as(u32, @intCast(ny)) * width + @as(u32, @intCast(nx))) * bpp;
        if (neighbor_idx + bpp > pixels.len or center_idx + bpp > pixels.len) continue;

        // Check if neighbor is similar
        var diff: u32 = 0;
        var i: usize = 0;
        while (i < bpp) : (i += 1) {
            const d = if (pixels[center_idx + i] > pixels[neighbor_idx + i])
                pixels[center_idx + i] - pixels[neighbor_idx + i]
            else
                pixels[neighbor_idx + i] - pixels[center_idx + i];
            diff += d;
        }

        if (diff < 30 * bpp) {
            similar_count += 1;
        }
    }

    // If surrounded by similar pixels, not anti-aliasing
    return similar_count < 3;
}

// PNG encoding (simplified - for production use a proper PNG library)
fn writePng(file: std.fs.File, screenshot: Screenshot) !void {
    // PNG signature
    try file.writeAll(&[_]u8{ 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A });

    // IHDR chunk
    var ihdr: [13]u8 = undefined;
    std.mem.writeInt(u32, ihdr[0..4], screenshot.width, .big);
    std.mem.writeInt(u32, ihdr[4..8], screenshot.height, .big);
    ihdr[8] = 8; // bit depth
    ihdr[9] = 6; // color type (RGBA)
    ihdr[10] = 0; // compression
    ihdr[11] = 0; // filter
    ihdr[12] = 0; // interlace

    try writeChunk(file, "IHDR", &ihdr);

    // IDAT chunk (uncompressed for simplicity)
    // In production, use zlib compression
    var raw_data = std.ArrayList(u8).init(std.heap.page_allocator);
    defer raw_data.deinit();

    const bpp: u32 = switch (screenshot.format) {
        .rgba => 4,
        .rgb => 3,
        else => 4,
    };

    var y: u32 = 0;
    while (y < screenshot.height) : (y += 1) {
        try raw_data.append(0); // filter byte
        const row_start = y * screenshot.width * bpp;
        const row_end = row_start + screenshot.width * bpp;
        if (row_end <= screenshot.pixels.len) {
            try raw_data.appendSlice(screenshot.pixels[row_start..row_end]);
        }
    }

    // For simplicity, write uncompressed IDAT
    // Real implementation should use zlib
    try writeChunk(file, "IDAT", raw_data.items);

    // IEND chunk
    try writeChunk(file, "IEND", &[_]u8{});
}

fn writeChunk(file: std.fs.File, chunk_type: *const [4]u8, data: []const u8) !void {
    var length: [4]u8 = undefined;
    std.mem.writeInt(u32, &length, @intCast(data.len), .big);
    try file.writeAll(&length);
    try file.writeAll(chunk_type);
    try file.writeAll(data);

    // CRC (simplified - should calculate proper CRC32)
    var crc: [4]u8 = undefined;
    std.mem.writeInt(u32, &crc, 0, .big);
    try file.writeAll(&crc);
}

fn readPng(file: std.fs.File, allocator: std.mem.Allocator) !Screenshot {
    // Read PNG signature
    var sig: [8]u8 = undefined;
    _ = try file.readAll(&sig);

    if (!std.mem.eql(u8, &sig, &[_]u8{ 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A })) {
        return error.InvalidPng;
    }

    var width: u32 = 0;
    var height: u32 = 0;
    var pixels: []u8 = &[_]u8{};

    // Read chunks
    while (true) {
        var length_buf: [4]u8 = undefined;
        const read = try file.readAll(&length_buf);
        if (read < 4) break;

        const length = std.mem.readInt(u32, &length_buf, .big);

        var chunk_type: [4]u8 = undefined;
        _ = try file.readAll(&chunk_type);

        if (std.mem.eql(u8, &chunk_type, "IHDR")) {
            var ihdr: [13]u8 = undefined;
            _ = try file.readAll(&ihdr);
            width = std.mem.readInt(u32, ihdr[0..4], .big);
            height = std.mem.readInt(u32, ihdr[4..8], .big);

            pixels = try allocator.alloc(u8, width * height * 4);

            // Skip CRC
            try file.seekBy(4);
        } else if (std.mem.eql(u8, &chunk_type, "IDAT")) {
            // Read compressed data (simplified - assumes uncompressed)
            const data = try allocator.alloc(u8, length);
            defer allocator.free(data);
            _ = try file.readAll(data);

            // Copy pixels (skip filter bytes)
            var y: u32 = 0;
            var src: usize = 0;
            while (y < height and src < data.len) : (y += 1) {
                src += 1; // Skip filter byte
                const dst_start = y * width * 4;
                const copy_len = @min(width * 4, data.len - src);
                if (dst_start + copy_len <= pixels.len) {
                    @memcpy(pixels[dst_start .. dst_start + copy_len], data[src .. src + copy_len]);
                }
                src += width * 4;
            }

            try file.seekBy(4); // CRC
        } else if (std.mem.eql(u8, &chunk_type, "IEND")) {
            break;
        } else {
            // Skip unknown chunk
            try file.seekBy(@intCast(length + 4));
        }
    }

    return Screenshot{
        .width = width,
        .height = height,
        .pixels = pixels,
        .format = .rgba,
    };
}

/// Visual regression test helper
pub const VisualTest = struct {
    baseline_dir: []const u8,
    diff_dir: []const u8,
    config: CompareConfig,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(baseline_dir: []const u8, diff_dir: []const u8, allocator: std.mem.Allocator) Self {
        return .{
            .baseline_dir = baseline_dir,
            .diff_dir = diff_dir,
            .config = .{},
            .allocator = allocator,
        };
    }

    pub fn withConfig(self: *Self, config: CompareConfig) *Self {
        self.config = config;
        return self;
    }

    /// Compare screenshot against baseline with name
    pub fn check(self: *Self, name: []const u8, screenshot: Screenshot) !CompareResult {
        const baseline_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}.png", .{ self.baseline_dir, name });
        defer self.allocator.free(baseline_path);

        // Check if baseline exists
        if (std.fs.cwd().access(baseline_path, .{})) |_| {
            const result = try compareWithConfig(screenshot, baseline_path, self.config, self.allocator);

            if (!result.matches and self.config.generate_diff) {
                const diff_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}-diff.png", .{ self.diff_dir, name });
                defer self.allocator.free(diff_path);
                try save(screenshot, diff_path);
            }

            return result;
        } else |_| {
            // No baseline exists, save current as baseline
            try save(screenshot, baseline_path);
            return CompareResult{
                .matches = true,
                .diff_percentage = 0,
                .diff_pixels = 0,
            };
        }
    }

    /// Update baseline with current screenshot
    pub fn updateBaseline(self: *Self, name: []const u8, screenshot: Screenshot) !void {
        const baseline_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}.png", .{ self.baseline_dir, name });
        defer self.allocator.free(baseline_path);
        try save(screenshot, baseline_path);
    }
};

// Tests
test "pixel comparison" {
    const a = [_]u8{ 100, 100, 100, 255 };
    const b = [_]u8{ 102, 98, 100, 255 };

    try std.testing.expect(pixelsMatch(&a, &b, .{ .color_threshold = 5 }));
    try std.testing.expect(!pixelsMatch(&a, &b, .{ .color_threshold = 1 }));
}
