// Zylix Test Framework - Enhanced Visual Testing
// Advanced screenshot comparison, baseline management, and diff visualization

const std = @import("std");
const Allocator = std.mem.Allocator;
const screenshot_mod = @import("screenshot.zig");

pub const Screenshot = screenshot_mod.Screenshot;
pub const CompareConfig = screenshot_mod.CompareConfig;
pub const CompareResult = screenshot_mod.CompareResult;
pub const Region = screenshot_mod.Region;

/// Visual comparison algorithm
pub const CompareAlgorithm = enum {
    /// Pixel-by-pixel comparison
    pixel,
    /// Perceptual hash comparison (fast, tolerant)
    perceptual_hash,
    /// Structural similarity index (SSIM)
    ssim,
    /// Feature-based comparison
    feature,
    /// Histogram comparison
    histogram,
};

/// Enhanced comparison configuration
pub const VisualConfig = struct {
    /// Base comparison config
    base: CompareConfig = .{},
    /// Comparison algorithm
    algorithm: CompareAlgorithm = .pixel,
    /// Mask regions to ignore
    ignore_regions: []const Region = &.{},
    /// Focus only on specific regions
    focus_regions: []const Region = &.{},
    /// Highlight color for diff (RGBA)
    highlight_color: [4]u8 = .{ 255, 0, 255, 128 },
    /// Overlay original with diff
    overlay_diff: bool = true,
    /// Similarity threshold (0.0-1.0) for non-pixel algorithms
    similarity_threshold: f32 = 0.95,
    /// Scale images before comparison
    scale_factor: f32 = 1.0,
    /// Enable smart ignore (dynamic content detection)
    smart_ignore: bool = false,
};

/// Visual comparison result with enhanced details
pub const VisualResult = struct {
    matches: bool,
    similarity: f32,
    diff_percentage: f32,
    diff_pixels: u32,
    diff_regions: []const DiffRegion,
    diff_image: ?[]const u8,
    baseline_hash: u64,
    actual_hash: u64,
    comparison_time_ms: u64,

    pub const DiffRegion = struct {
        x: u32,
        y: u32,
        width: u32,
        height: u32,
        severity: Severity,
        category: Category,

        pub const Severity = enum { minor, moderate, major };
        pub const Category = enum { color, layout, missing, added, moved };
    };
};

/// Baseline management
pub const BaselineManager = struct {
    allocator: Allocator,
    baseline_dir: []const u8,
    branch: ?[]const u8,
    versioning: bool,
    history: std.StringHashMap(BaselineHistory),

    const BaselineHistory = struct {
        versions: std.ArrayList(BaselineVersion),
        current_version: u32,
    };

    const BaselineVersion = struct {
        version: u32,
        hash: u64,
        created_at: i64,
        created_by: []const u8,
        commit: ?[]const u8,
    };

    const Self = @This();

    pub fn init(allocator: Allocator, baseline_dir: []const u8) Self {
        return .{
            .allocator = allocator,
            .baseline_dir = baseline_dir,
            .branch = null,
            .versioning = true,
            .history = std.StringHashMap(BaselineHistory).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.history.valueIterator();
        while (iter.next()) |hist| {
            hist.versions.deinit();
        }
        self.history.deinit();
    }

    /// Get baseline path for a test
    pub fn getBaselinePath(self: *Self, test_name: []const u8) ![]const u8 {
        if (self.branch) |branch| {
            return try std.fmt.allocPrint(self.allocator, "{s}/{s}/{s}.png", .{ self.baseline_dir, branch, test_name });
        }
        return try std.fmt.allocPrint(self.allocator, "{s}/{s}.png", .{ self.baseline_dir, test_name });
    }

    /// Check if baseline exists
    pub fn hasBaseline(self: *Self, test_name: []const u8) bool {
        const path = self.getBaselinePath(test_name) catch return false;
        defer self.allocator.free(path);

        return std.fs.cwd().access(path, .{}) != error.FileNotFound;
    }

    /// Load baseline image
    pub fn loadBaseline(self: *Self, test_name: []const u8) !Screenshot {
        const path = try self.getBaselinePath(test_name);
        defer self.allocator.free(path);

        return screenshot_mod.loadImage(path, self.allocator);
    }

    /// Save new baseline
    pub fn saveBaseline(self: *Self, test_name: []const u8, image: Screenshot) !void {
        const path = try self.getBaselinePath(test_name);
        defer self.allocator.free(path);

        // Ensure directory exists
        if (std.fs.path.dirname(path)) |dir| {
            std.fs.cwd().makePath(dir) catch {};
        }

        try screenshot_mod.save(image, path);

        // Update history
        if (self.versioning) {
            try self.recordVersion(test_name, image);
        }
    }

    /// Record version in history
    fn recordVersion(self: *Self, test_name: []const u8, image: Screenshot) !void {
        const entry = try self.history.getOrPut(test_name);
        if (!entry.found_existing) {
            entry.value_ptr.* = .{
                .versions = std.ArrayList(BaselineVersion).init(self.allocator),
                .current_version = 0,
            };
        }

        const hist = entry.value_ptr;
        hist.current_version += 1;

        try hist.versions.append(.{
            .version = hist.current_version,
            .hash = computeImageHash(image),
            .created_at = std.time.timestamp(),
            .created_by = "zylix-test",
            .commit = null,
        });
    }

    /// Get baseline history
    pub fn getHistory(self: *Self, test_name: []const u8) ?[]const BaselineVersion {
        const hist = self.history.get(test_name) orelse return null;
        return hist.versions.items;
    }

    /// Rollback to previous version
    pub fn rollback(self: *Self, test_name: []const u8, version: u32) !void {
        const hist = self.history.getPtr(test_name) orelse return error.NotFound;
        if (version > hist.current_version or version == 0) return error.InvalidVersion;

        // Load versioned baseline and restore
        const versioned_path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/.versions/{s}-v{d}.png",
            .{ self.baseline_dir, test_name, version },
        );
        defer self.allocator.free(versioned_path);

        const current_path = try self.getBaselinePath(test_name);
        defer self.allocator.free(current_path);

        try std.fs.cwd().copyFile(versioned_path, std.fs.cwd(), current_path, .{});
        hist.current_version = version;
    }
};

/// Visual test runner
pub const VisualTestRunner = struct {
    allocator: Allocator,
    baselines: BaselineManager,
    config: VisualConfig,
    results: std.ArrayList(TestRun),
    diff_dir: []const u8,

    const TestRun = struct {
        name: []const u8,
        result: VisualResult,
        timestamp: i64,
    };

    const Self = @This();

    pub fn init(allocator: Allocator, baseline_dir: []const u8, diff_dir: []const u8) Self {
        return .{
            .allocator = allocator,
            .baselines = BaselineManager.init(allocator, baseline_dir),
            .config = .{},
            .results = std.ArrayList(TestRun).init(allocator),
            .diff_dir = diff_dir,
        };
    }

    pub fn deinit(self: *Self) void {
        self.baselines.deinit();
        self.results.deinit();
    }

    /// Set configuration
    pub fn withConfig(self: *Self, config: VisualConfig) *Self {
        self.config = config;
        return self;
    }

    /// Compare screenshot against baseline
    pub fn compare(self: *Self, test_name: []const u8, actual: Screenshot) !VisualResult {
        const start = std.time.nanoTimestamp();

        // Check for baseline
        if (!self.baselines.hasBaseline(test_name)) {
            // No baseline - save current as baseline
            try self.baselines.saveBaseline(test_name, actual);
            return VisualResult{
                .matches = true,
                .similarity = 1.0,
                .diff_percentage = 0,
                .diff_pixels = 0,
                .diff_regions = &.{},
                .diff_image = null,
                .baseline_hash = computeImageHash(actual),
                .actual_hash = computeImageHash(actual),
                .comparison_time_ms = 0,
            };
        }

        // Load baseline
        const baseline = try self.baselines.loadBaseline(test_name);
        defer self.allocator.free(baseline.pixels);

        // Perform comparison based on algorithm
        const result = switch (self.config.algorithm) {
            .pixel => try self.pixelCompare(actual, baseline),
            .perceptual_hash => try self.perceptualHashCompare(actual, baseline),
            .ssim => try self.ssimCompare(actual, baseline),
            .histogram => try self.histogramCompare(actual, baseline),
            .feature => try self.pixelCompare(actual, baseline), // Fallback to pixel
        };

        const end = std.time.nanoTimestamp();
        var final_result = result;
        final_result.comparison_time_ms = @intCast(@divFloor(end - start, std.time.ns_per_ms));

        // Save diff if not matching
        if (!result.matches and self.config.base.generate_diff) {
            try self.saveDiff(test_name, actual, baseline);
        }

        // Record result
        try self.results.append(.{
            .name = test_name,
            .result = final_result,
            .timestamp = std.time.timestamp(),
        });

        return final_result;
    }

    /// Pixel-by-pixel comparison
    fn pixelCompare(self: *Self, actual: Screenshot, baseline: Screenshot) !VisualResult {
        const compare_result = screenshot_mod.compareImages(actual, baseline, self.config.base);

        return VisualResult{
            .matches = compare_result.matches,
            .similarity = 1.0 - compare_result.diff_percentage,
            .diff_percentage = compare_result.diff_percentage,
            .diff_pixels = compare_result.diff_pixels,
            .diff_regions = &.{},
            .diff_image = null,
            .baseline_hash = computeImageHash(baseline),
            .actual_hash = computeImageHash(actual),
            .comparison_time_ms = 0,
        };
    }

    /// Perceptual hash comparison (fast similarity check)
    fn perceptualHashCompare(self: *Self, actual: Screenshot, baseline: Screenshot) !VisualResult {
        const actual_hash = computePerceptualHash(actual);
        const baseline_hash = computePerceptualHash(baseline);

        // Hamming distance between hashes
        const xor_result = actual_hash ^ baseline_hash;
        const diff_bits = @popCount(xor_result);
        const similarity = 1.0 - @as(f32, @floatFromInt(diff_bits)) / 64.0;

        return VisualResult{
            .matches = similarity >= self.config.similarity_threshold,
            .similarity = similarity,
            .diff_percentage = 1.0 - similarity,
            .diff_pixels = 0,
            .diff_regions = &.{},
            .diff_image = null,
            .baseline_hash = baseline_hash,
            .actual_hash = actual_hash,
            .comparison_time_ms = 0,
        };
    }

    /// SSIM-like comparison
    fn ssimCompare(self: *Self, actual: Screenshot, baseline: Screenshot) !VisualResult {
        _ = self;

        if (actual.width != baseline.width or actual.height != baseline.height) {
            return VisualResult{
                .matches = false,
                .similarity = 0,
                .diff_percentage = 1.0,
                .diff_pixels = actual.width * actual.height,
                .diff_regions = &.{},
                .diff_image = null,
                .baseline_hash = 0,
                .actual_hash = 0,
                .comparison_time_ms = 0,
            };
        }

        // Simplified SSIM calculation
        var sum_actual: f64 = 0;
        var sum_baseline: f64 = 0;
        var sum_actual_sq: f64 = 0;
        var sum_baseline_sq: f64 = 0;
        var sum_product: f64 = 0;

        const n = actual.width * actual.height;
        const bpp: u32 = 4;

        var i: usize = 0;
        while (i < n) : (i += 1) {
            const idx = i * bpp;
            if (idx + bpp > actual.pixels.len or idx + bpp > baseline.pixels.len) break;

            // Use luminance
            const a_lum = @as(f64, @floatFromInt(actual.pixels[idx])) * 0.299 +
                @as(f64, @floatFromInt(actual.pixels[idx + 1])) * 0.587 +
                @as(f64, @floatFromInt(actual.pixels[idx + 2])) * 0.114;
            const b_lum = @as(f64, @floatFromInt(baseline.pixels[idx])) * 0.299 +
                @as(f64, @floatFromInt(baseline.pixels[idx + 1])) * 0.587 +
                @as(f64, @floatFromInt(baseline.pixels[idx + 2])) * 0.114;

            sum_actual += a_lum;
            sum_baseline += b_lum;
            sum_actual_sq += a_lum * a_lum;
            sum_baseline_sq += b_lum * b_lum;
            sum_product += a_lum * b_lum;
        }

        const n_f = @as(f64, @floatFromInt(n));
        const mean_a = sum_actual / n_f;
        const mean_b = sum_baseline / n_f;
        const var_a = (sum_actual_sq / n_f) - (mean_a * mean_a);
        const var_b = (sum_baseline_sq / n_f) - (mean_b * mean_b);
        const covar = (sum_product / n_f) - (mean_a * mean_b);

        // SSIM constants
        const c1 = 6.5025; // (0.01 * 255)^2
        const c2 = 58.5225; // (0.03 * 255)^2

        const ssim = ((2 * mean_a * mean_b + c1) * (2 * covar + c2)) /
            ((mean_a * mean_a + mean_b * mean_b + c1) * (var_a + var_b + c2));

        const similarity: f32 = @floatCast(@max(0, @min(1, ssim)));

        return VisualResult{
            .matches = similarity >= 0.95,
            .similarity = similarity,
            .diff_percentage = 1.0 - similarity,
            .diff_pixels = 0,
            .diff_regions = &.{},
            .diff_image = null,
            .baseline_hash = computeImageHash(baseline),
            .actual_hash = computeImageHash(actual),
            .comparison_time_ms = 0,
        };
    }

    /// Histogram comparison
    fn histogramCompare(self: *Self, actual: Screenshot, baseline: Screenshot) !VisualResult {
        _ = self;

        var actual_hist: [256]u32 = [_]u32{0} ** 256;
        var baseline_hist: [256]u32 = [_]u32{0} ** 256;

        // Build histograms (grayscale)
        const bpp: u32 = 4;
        var i: usize = 0;
        while (i < actual.pixels.len / bpp) : (i += 1) {
            const idx = i * bpp;
            if (idx + 2 >= actual.pixels.len) break;

            const a_gray = (@as(u32, actual.pixels[idx]) + actual.pixels[idx + 1] + actual.pixels[idx + 2]) / 3;
            actual_hist[a_gray] += 1;
        }

        i = 0;
        while (i < baseline.pixels.len / bpp) : (i += 1) {
            const idx = i * bpp;
            if (idx + 2 >= baseline.pixels.len) break;

            const b_gray = (@as(u32, baseline.pixels[idx]) + baseline.pixels[idx + 1] + baseline.pixels[idx + 2]) / 3;
            baseline_hist[b_gray] += 1;
        }

        // Calculate correlation
        var sum_a: f64 = 0;
        var sum_b: f64 = 0;
        var sum_ab: f64 = 0;
        var sum_a2: f64 = 0;
        var sum_b2: f64 = 0;

        for (actual_hist, baseline_hist) |a, b| {
            const af: f64 = @floatFromInt(a);
            const bf: f64 = @floatFromInt(b);
            sum_a += af;
            sum_b += bf;
            sum_ab += af * bf;
            sum_a2 += af * af;
            sum_b2 += bf * bf;
        }

        const n: f64 = 256;
        const correlation = (n * sum_ab - sum_a * sum_b) /
            @sqrt((n * sum_a2 - sum_a * sum_a) * (n * sum_b2 - sum_b * sum_b) + 0.0001);

        const similarity: f32 = @floatCast(@max(0, @min(1, (correlation + 1) / 2)));

        return VisualResult{
            .matches = similarity >= 0.95,
            .similarity = similarity,
            .diff_percentage = 1.0 - similarity,
            .diff_pixels = 0,
            .diff_regions = &.{},
            .diff_image = null,
            .baseline_hash = computeImageHash(baseline),
            .actual_hash = computeImageHash(actual),
            .comparison_time_ms = 0,
        };
    }

    /// Save diff image
    fn saveDiff(self: *Self, test_name: []const u8, actual: Screenshot, baseline: Screenshot) !void {
        _ = baseline;

        std.fs.cwd().makePath(self.diff_dir) catch {};

        const path = try std.fmt.allocPrint(self.allocator, "{s}/{s}-diff.png", .{ self.diff_dir, test_name });
        defer self.allocator.free(path);

        try screenshot_mod.save(actual, path);
    }

    /// Generate HTML report
    pub fn generateReport(self: *Self) ![]const u8 {
        var buffer = std.ArrayList(u8).init(self.allocator);
        const writer = buffer.writer();

        try writer.writeAll(
            \\<!DOCTYPE html>
            \\<html>
            \\<head>
            \\  <title>Visual Test Report</title>
            \\  <style>
            \\    body { font-family: system-ui; padding: 20px; background: #f5f5f5; }
            \\    .test { background: white; margin: 10px 0; padding: 15px; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
            \\    .pass { border-left: 4px solid #22c55e; }
            \\    .fail { border-left: 4px solid #ef4444; }
            \\    .name { font-weight: 600; margin-bottom: 5px; }
            \\    .stats { color: #666; font-size: 0.9em; }
            \\  </style>
            \\</head>
            \\<body>
            \\  <h1>Visual Test Report</h1>
            \\
        );

        for (self.results.items) |run| {
            const class = if (run.result.matches) "pass" else "fail";
            try writer.print(
                \\  <div class="test {s}">
                \\    <div class="name">{s}</div>
                \\    <div class="stats">Similarity: {d:.1}% | Time: {d}ms</div>
                \\  </div>
                \\
            ,
                .{ class, run.name, run.result.similarity * 100, run.result.comparison_time_ms },
            );
        }

        try writer.writeAll("</body></html>\n");

        return buffer.toOwnedSlice();
    }
};

/// Compute simple image hash
fn computeImageHash(image: Screenshot) u64 {
    var hash: u64 = 0;
    const step = @max(1, image.pixels.len / 64);

    var i: usize = 0;
    var bit: u6 = 0;
    while (i < image.pixels.len and bit < 64) : (i += step) {
        if (image.pixels[i] > 127) {
            hash |= (@as(u64, 1) << bit);
        }
        bit +%= 1;
    }

    return hash;
}

/// Compute perceptual hash (average hash)
fn computePerceptualHash(image: Screenshot) u64 {
    // Simplified: sample 8x8 grid and compare to average
    var samples: [64]u8 = undefined;
    var total: u32 = 0;

    const step_x = @max(1, image.width / 8);
    const step_y = @max(1, image.height / 8);
    const bpp: u32 = 4;

    var idx: usize = 0;
    var y: u32 = 0;
    while (y < 8) : (y += 1) {
        var x: u32 = 0;
        while (x < 8) : (x += 1) {
            const px = x * step_x;
            const py = y * step_y;
            const pixel_idx = (py * image.width + px) * bpp;

            if (pixel_idx + 2 < image.pixels.len) {
                const gray: u8 = @intCast((@as(u32, image.pixels[pixel_idx]) +
                    image.pixels[pixel_idx + 1] +
                    image.pixels[pixel_idx + 2]) / 3);
                samples[idx] = gray;
                total += gray;
            } else {
                samples[idx] = 0;
            }
            idx += 1;
        }
    }

    const avg: u8 = @intCast(total / 64);

    var hash: u64 = 0;
    for (samples, 0..) |sample, i| {
        if (sample > avg) {
            hash |= (@as(u64, 1) << @as(u6, @intCast(i)));
        }
    }

    return hash;
}

// Tests
test "VisualConfig defaults" {
    const config = VisualConfig{};
    try std.testing.expectEqual(CompareAlgorithm.pixel, config.algorithm);
    try std.testing.expectApproxEqAbs(@as(f32, 0.95), config.similarity_threshold, 0.001);
}

test "computeImageHash" {
    const image = Screenshot{
        .width = 2,
        .height = 2,
        .pixels = &[_]u8{ 255, 255, 255, 255, 0, 0, 0, 255, 128, 128, 128, 255, 200, 200, 200, 255 },
        .format = .rgba,
    };

    const hash = computeImageHash(image);
    try std.testing.expect(hash != 0);
}

test "computePerceptualHash" {
    const image = Screenshot{
        .width = 8,
        .height = 8,
        .pixels = &([_]u8{128} ** (8 * 8 * 4)),
        .format = .rgba,
    };

    const hash = computePerceptualHash(image);
    // All same value should give 0 hash (all below average)
    try std.testing.expectEqual(@as(u64, 0), hash);
}

test "BaselineManager" {
    const allocator = std.testing.allocator;

    var manager = BaselineManager.init(allocator, "/tmp/baselines");
    defer manager.deinit();

    const path = try manager.getBaselinePath("test_screenshot");
    defer allocator.free(path);

    try std.testing.expect(std.mem.endsWith(u8, path, "test_screenshot.png"));
}
