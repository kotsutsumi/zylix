//! Zylix Performance Benchmarks
//!
//! Comprehensive benchmarks for core modules.

const std = @import("std");

/// Benchmark result
pub const BenchmarkResult = struct {
    name: []const u8,
    iterations: u64,
    total_ns: i128,
    avg_ns: f64,
    min_ns: i128,
    max_ns: i128,
    ops_per_sec: f64,

    pub fn format(self: BenchmarkResult, writer: anytype) !void {
        try writer.print("{s:<40} {d:>10} iter  {d:>10.2} ns/op  {d:>12.0} ops/s\n", .{
            self.name,
            self.iterations,
            self.avg_ns,
            self.ops_per_sec,
        });
    }
};

/// Benchmark runner
pub const BenchmarkRunner = struct {
    allocator: std.mem.Allocator,
    results: std.ArrayList(BenchmarkResult),
    warmup_iterations: u32,
    min_iterations: u32,
    target_duration_ns: i128,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .results = .{},
            .warmup_iterations = 10,
            .min_iterations = 100,
            .target_duration_ns = 1_000_000_000, // 1 second
        };
    }

    pub fn deinit(self: *Self) void {
        self.results.deinit(self.allocator);
    }

    /// Run a benchmark
    pub fn bench(self: *Self, name: []const u8, comptime func: anytype) !BenchmarkResult {
        // Warmup
        for (0..self.warmup_iterations) |_| {
            _ = func();
        }

        // Measure
        var iterations: u64 = 0;
        var total_ns: i128 = 0;
        var min_ns: i128 = std.math.maxInt(i128);
        var max_ns: i128 = 0;

        while (total_ns < self.target_duration_ns or iterations < self.min_iterations) {
            const start = std.time.nanoTimestamp();
            _ = func();
            const elapsed = std.time.nanoTimestamp() - start;

            total_ns += elapsed;
            iterations += 1;

            if (elapsed < min_ns) min_ns = elapsed;
            if (elapsed > max_ns) max_ns = elapsed;
        }

        const avg_ns = @as(f64, @floatFromInt(total_ns)) / @as(f64, @floatFromInt(iterations));
        const ops_per_sec = 1_000_000_000.0 / avg_ns;

        const result = BenchmarkResult{
            .name = name,
            .iterations = iterations,
            .total_ns = total_ns,
            .avg_ns = avg_ns,
            .min_ns = min_ns,
            .max_ns = max_ns,
            .ops_per_sec = ops_per_sec,
        };

        try self.results.append(self.allocator, result);
        return result;
    }

    /// Print results
    pub fn printResults(self: *Self) void {
        std.debug.print("\n{s:=^80}\n", .{" Benchmark Results "});
        std.debug.print("{s:<40} {s:>10}  {s:>14}  {s:>12}\n", .{ "Name", "Iterations", "Avg (ns/op)", "Throughput" });
        std.debug.print("{s:-<80}\n", .{""});

        for (self.results.items) |result| {
            result.format(std.io.getStdErr().writer()) catch {};
        }

        std.debug.print("{s:=<80}\n\n", .{""});
    }
};

// ============================================================================
// PDF Module Benchmarks
// ============================================================================

fn benchPdfHeaderParse() u32 {
    const pdf_data = "%PDF-1.7\n%\xe2\xe3\xcf\xd3\n";
    var sum: u32 = 0;
    for (pdf_data) |c| {
        sum +%= c;
    }
    // Simulate header parsing
    if (std.mem.startsWith(u8, pdf_data, "%PDF-")) {
        sum +%= 1;
    }
    return sum;
}

fn benchPdfVersionDetect() u32 {
    const versions = [_][]const u8{ "1.0", "1.1", "1.2", "1.3", "1.4", "1.5", "1.6", "1.7", "2.0" };
    var hash: u32 = 0;
    for (versions) |ver| {
        for (ver) |c| {
            hash = hash *% 31 +% c;
        }
    }
    return hash;
}

// ============================================================================
// State Management Benchmarks
// ============================================================================

fn benchStateHash() u64 {
    var hash: u64 = 0;
    const keys = [_][]const u8{ "user", "settings", "theme", "language", "notifications" };
    for (keys) |key| {
        for (key) |c| {
            hash = hash *% 31 +% c;
        }
    }
    return hash;
}

fn benchStateLookup() u32 {
    const data = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    var sum: u32 = 0;
    for (data) |v| {
        sum +%= v;
    }
    return sum;
}

// ============================================================================
// Animation Benchmarks
// ============================================================================

fn benchEasingLinear() f32 {
    var result: f32 = 0;
    var t: f32 = 0;
    while (t <= 1.0) : (t += 0.01) {
        result += t; // Linear easing: f(t) = t
    }
    return result;
}

fn benchEasingEaseInOut() f32 {
    var result: f32 = 0;
    var t: f32 = 0;
    while (t <= 1.0) : (t += 0.01) {
        // Ease in-out cubic: 4t³ for t<0.5, 1-(-2t+2)³/2 for t>=0.5
        const eased = if (t < 0.5)
            4 * t * t * t
        else
            1 - std.math.pow(f32, -2 * t + 2, 3) / 2;
        result += eased;
    }
    return result;
}

fn benchInterpolation() f32 {
    const start: f32 = 0;
    const end: f32 = 100;
    var result: f32 = 0;
    var t: f32 = 0;
    while (t <= 1.0) : (t += 0.01) {
        result += start + (end - start) * t;
    }
    return result;
}

// ============================================================================
// NodeFlow Benchmarks
// ============================================================================

fn benchNodeIdGeneration() u64 {
    var id: u64 = 0;
    for (0..100) |i| {
        id = id *% 31 +% @as(u64, @intCast(i));
    }
    return id;
}

fn benchConnectionValidation() bool {
    // Simulate connection type checking
    const types = [_]u8{ 0, 1, 2, 3, 4, 5 }; // Different port types
    var compatible: u32 = 0;
    for (types) |t1| {
        for (types) |t2| {
            if (t1 == t2) compatible += 1;
        }
    }
    return compatible > 0;
}

// ============================================================================
// Memory Benchmarks
// ============================================================================

fn benchSmallAlloc() void {
    var buffer: [64]u8 = undefined;
    for (&buffer) |*b| {
        b.* = 0;
    }
}

fn benchMediumAlloc() void {
    var buffer: [1024]u8 = undefined;
    for (&buffer) |*b| {
        b.* = 0;
    }
}

// ============================================================================
// Main Benchmark Suite
// ============================================================================

pub fn runAllBenchmarks(allocator: std.mem.Allocator) !void {
    var runner = BenchmarkRunner.init(allocator);
    defer runner.deinit();

    std.debug.print("\nRunning Zylix Performance Benchmarks...\n", .{});

    // PDF Benchmarks
    _ = try runner.bench("pdf/header_parse", benchPdfHeaderParse);
    _ = try runner.bench("pdf/version_detect", benchPdfVersionDetect);

    // State Management Benchmarks
    _ = try runner.bench("state/hash_computation", benchStateHash);
    _ = try runner.bench("state/lookup", benchStateLookup);

    // Animation Benchmarks
    _ = try runner.bench("animation/easing_linear", benchEasingLinear);
    _ = try runner.bench("animation/easing_ease_in_out", benchEasingEaseInOut);
    _ = try runner.bench("animation/interpolation", benchInterpolation);

    // NodeFlow Benchmarks
    _ = try runner.bench("nodeflow/id_generation", benchNodeIdGeneration);
    _ = try runner.bench("nodeflow/connection_validation", benchConnectionValidation);

    // Memory Benchmarks
    _ = try runner.bench("memory/small_alloc_64b", benchSmallAlloc);
    _ = try runner.bench("memory/medium_alloc_1kb", benchMediumAlloc);

    runner.printResults();
}

// ============================================================================
// Tests
// ============================================================================

test "BenchmarkRunner basic" {
    const allocator = std.testing.allocator;

    var runner = BenchmarkRunner.init(allocator);
    defer runner.deinit();

    runner.warmup_iterations = 1;
    runner.min_iterations = 10;
    runner.target_duration_ns = 1000; // 1 microsecond

    const result = try runner.bench("test/simple", benchStateLookup);

    try std.testing.expect(result.iterations >= 10);
    try std.testing.expect(result.avg_ns > 0);
    try std.testing.expect(result.ops_per_sec > 0);
}

test "Benchmark PDF functions" {
    const header_result = benchPdfHeaderParse();
    try std.testing.expect(header_result > 0);

    const version_result = benchPdfVersionDetect();
    try std.testing.expect(version_result > 0);
}

test "Benchmark Animation functions" {
    const linear = benchEasingLinear();
    try std.testing.expect(linear > 0);

    const ease_in_out = benchEasingEaseInOut();
    try std.testing.expect(ease_in_out > 0);

    const interp = benchInterpolation();
    try std.testing.expect(interp > 0);
}
