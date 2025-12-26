//! SIMD Benchmark for VDOM Operations
//!
//! Compares SIMD vs scalar implementations for:
//! - Memory comparison (simdMemEql vs std.mem.eql)
//! - Key hashing (simdHashKey vs scalar DJB2)
//! - Props comparison (simdPropsEql vs field-by-field)

const std = @import("std");
const simd = @import("simd.zig");

// ============================================================================
// Benchmark Configuration
// ============================================================================

const ITERATIONS = 100_000;
const WARMUP_ITERATIONS = 1_000;

// ============================================================================
// Benchmark Results
// ============================================================================

pub const BenchmarkResult = struct {
    name: []const u8,
    simd_ns: u64,
    scalar_ns: u64,
    speedup: f64,

    pub fn print(self: *const BenchmarkResult) void {
        std.debug.print("  {s}:\n", .{self.name});
        std.debug.print("    SIMD:   {d:>10} ns ({d:.2} ns/op)\n", .{ self.simd_ns, @as(f64, @floatFromInt(self.simd_ns)) / ITERATIONS });
        std.debug.print("    Scalar: {d:>10} ns ({d:.2} ns/op)\n", .{ self.scalar_ns, @as(f64, @floatFromInt(self.scalar_ns)) / ITERATIONS });
        std.debug.print("    Speedup: {d:.2}x\n", .{self.speedup});
    }
};

pub const BenchmarkSuite = struct {
    results: [10]BenchmarkResult,
    count: usize,

    pub fn init() BenchmarkSuite {
        return .{
            .results = undefined,
            .count = 0,
        };
    }

    pub fn add(self: *BenchmarkSuite, result: BenchmarkResult) void {
        if (self.count < 10) {
            self.results[self.count] = result;
            self.count += 1;
        }
    }

    pub fn printAll(self: *const BenchmarkSuite) void {
        std.debug.print("\n========================================\n", .{});
        std.debug.print("       SIMD Benchmark Results\n", .{});
        std.debug.print("       ({d} iterations each)\n", .{ITERATIONS});
        std.debug.print("========================================\n\n", .{});

        for (self.results[0..self.count]) |*result| {
            result.print();
            std.debug.print("\n", .{});
        }

        // Summary
        var total_speedup: f64 = 0;
        for (self.results[0..self.count]) |result| {
            total_speedup += result.speedup;
        }
        const avg_speedup = total_speedup / @as(f64, @floatFromInt(self.count));
        std.debug.print("========================================\n", .{});
        std.debug.print("  Average Speedup: {d:.2}x\n", .{avg_speedup});
        std.debug.print("========================================\n", .{});
    }
};

// ============================================================================
// Scalar Implementations (for comparison)
// ============================================================================

fn scalarHashKey(key: []const u8) u32 {
    var hash: u32 = 5381;
    for (key) |c| {
        hash = ((hash << 5) +% hash) +% c;
    }
    return hash;
}

const TestProps = struct {
    class: [64]u8,
    class_len: u8,
    style_id: u32,
    on_click: u32,
    on_input: u32,
    on_change: u32,
    input_type: u8,
    disabled: bool,
    placeholder_len: u8,
    href_len: u8,
    src_len: u8,
    alt_len: u8,

    fn scalarEquals(self: *const TestProps, other: *const TestProps) bool {
        if (self.class_len != other.class_len) return false;
        if (!std.mem.eql(u8, self.class[0..self.class_len], other.class[0..other.class_len])) return false;
        if (self.style_id != other.style_id) return false;
        if (self.on_click != other.on_click) return false;
        if (self.on_input != other.on_input) return false;
        if (self.on_change != other.on_change) return false;
        if (self.input_type != other.input_type) return false;
        if (self.disabled != other.disabled) return false;
        if (self.placeholder_len != other.placeholder_len) return false;
        if (self.href_len != other.href_len) return false;
        if (self.src_len != other.src_len) return false;
        if (self.alt_len != other.alt_len) return false;
        return true;
    }
};

// ============================================================================
// Benchmark Functions
// ============================================================================

fn benchmarkMemEql(suite: *BenchmarkSuite) void {
    // Test data - 128 bytes (typical text content size)
    const data_a = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.";
    const data_b = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.";

    // Warmup
    for (0..WARMUP_ITERATIONS) |_| {
        _ = simd.simdMemEql(data_a, data_b);
        _ = std.mem.eql(u8, data_a, data_b);
    }

    // SIMD benchmark
    var timer = std.time.Timer.start() catch return;
    for (0..ITERATIONS) |_| {
        _ = simd.simdMemEql(data_a, data_b);
    }
    const simd_time = timer.read();

    // Scalar benchmark
    timer.reset();
    for (0..ITERATIONS) |_| {
        _ = std.mem.eql(u8, data_a, data_b);
    }
    const scalar_time = timer.read();

    const speedup = if (simd_time > 0) @as(f64, @floatFromInt(scalar_time)) / @as(f64, @floatFromInt(simd_time)) else 1.0;

    suite.add(.{
        .name = "MemEql (128 bytes)",
        .simd_ns = simd_time,
        .scalar_ns = scalar_time,
        .speedup = speedup,
    });
}

fn benchmarkMemEqlShort(suite: *BenchmarkSuite) void {
    // Short strings (typical keys)
    const data_a = "item-123";
    const data_b = "item-123";

    // Warmup
    for (0..WARMUP_ITERATIONS) |_| {
        _ = simd.simdMemEql(data_a, data_b);
        _ = std.mem.eql(u8, data_a, data_b);
    }

    var timer = std.time.Timer.start() catch return;
    for (0..ITERATIONS) |_| {
        _ = simd.simdMemEql(data_a, data_b);
    }
    const simd_time = timer.read();

    timer.reset();
    for (0..ITERATIONS) |_| {
        _ = std.mem.eql(u8, data_a, data_b);
    }
    const scalar_time = timer.read();

    const speedup = if (simd_time > 0) @as(f64, @floatFromInt(scalar_time)) / @as(f64, @floatFromInt(simd_time)) else 1.0;

    suite.add(.{
        .name = "MemEql (8 bytes - keys)",
        .simd_ns = simd_time,
        .scalar_ns = scalar_time,
        .speedup = speedup,
    });
}

fn benchmarkHashKey(suite: *BenchmarkSuite) void {
    const keys = [_][]const u8{
        "item-1",
        "item-2",
        "user-profile",
        "list-item-42",
    };

    // Warmup
    for (0..WARMUP_ITERATIONS) |_| {
        for (keys) |key| {
            _ = simd.simdHashKey(key);
            _ = scalarHashKey(key);
        }
    }

    var timer = std.time.Timer.start() catch return;
    for (0..ITERATIONS) |_| {
        for (keys) |key| {
            _ = simd.simdHashKey(key);
        }
    }
    const simd_time = timer.read();

    timer.reset();
    for (0..ITERATIONS) |_| {
        for (keys) |key| {
            _ = scalarHashKey(key);
        }
    }
    const scalar_time = timer.read();

    const speedup = if (simd_time > 0) @as(f64, @floatFromInt(scalar_time)) / @as(f64, @floatFromInt(simd_time)) else 1.0;

    suite.add(.{
        .name = "HashKey (4 keys)",
        .simd_ns = simd_time,
        .scalar_ns = scalar_time,
        .speedup = speedup,
    });
}

fn benchmarkPropsEql(suite: *BenchmarkSuite) void {
    var props1 = TestProps{
        .class = undefined,
        .class_len = 16,
        .style_id = 42,
        .on_click = 1,
        .on_input = 2,
        .on_change = 3,
        .input_type = 0,
        .disabled = false,
        .placeholder_len = 0,
        .href_len = 0,
        .src_len = 0,
        .alt_len = 0,
    };
    @memcpy(props1.class[0..16], "container-class-");

    var props2 = props1;

    // Warmup
    for (0..WARMUP_ITERATIONS) |_| {
        _ = simd.simdPropsEql(TestProps, &props1, &props2);
        _ = props1.scalarEquals(&props2);
    }

    var timer = std.time.Timer.start() catch return;
    for (0..ITERATIONS) |_| {
        _ = simd.simdPropsEql(TestProps, &props1, &props2);
    }
    const simd_time = timer.read();

    timer.reset();
    for (0..ITERATIONS) |_| {
        _ = props1.scalarEquals(&props2);
    }
    const scalar_time = timer.read();

    const speedup = if (simd_time > 0) @as(f64, @floatFromInt(scalar_time)) / @as(f64, @floatFromInt(simd_time)) else 1.0;

    suite.add(.{
        .name = "PropsEql (struct compare)",
        .simd_ns = simd_time,
        .scalar_ns = scalar_time,
        .speedup = speedup,
    });
}

fn benchmarkFindDiffPos(suite: *BenchmarkSuite) void {
    const str_a = "The quick brown fox jumps over the lazy dog. And then some more text to make it longer.";
    const str_b = "The quick brown fox jumps over the lazy cat. And then some more text to make it longer.";

    // Warmup
    for (0..WARMUP_ITERATIONS) |_| {
        _ = simd.simdFindDiffPos(str_a, str_b);
    }

    var timer = std.time.Timer.start() catch return;
    for (0..ITERATIONS) |_| {
        _ = simd.simdFindDiffPos(str_a, str_b);
    }
    const simd_time = timer.read();

    // Scalar version
    timer.reset();
    for (0..ITERATIONS) |_| {
        const min_len = @min(str_a.len, str_b.len);
        var i: usize = 0;
        while (i < min_len) : (i += 1) {
            if (str_a[i] != str_b[i]) break;
        }
    }
    const scalar_time = timer.read();

    const speedup = if (simd_time > 0) @as(f64, @floatFromInt(scalar_time)) / @as(f64, @floatFromInt(simd_time)) else 1.0;

    suite.add(.{
        .name = "FindDiffPos (87 bytes)",
        .simd_ns = simd_time,
        .scalar_ns = scalar_time,
        .speedup = speedup,
    });
}

fn benchmarkLargeMemEql(suite: *BenchmarkSuite) void {
    // Large data - 1KB
    const data_a = "A" ** 1024;
    const data_b = "A" ** 1024;

    // Warmup
    for (0..WARMUP_ITERATIONS) |_| {
        _ = simd.simdMemEql(data_a, data_b);
        _ = std.mem.eql(u8, data_a, data_b);
    }

    var timer = std.time.Timer.start() catch return;
    for (0..ITERATIONS) |_| {
        _ = simd.simdMemEql(data_a, data_b);
    }
    const simd_time = timer.read();

    timer.reset();
    for (0..ITERATIONS) |_| {
        _ = std.mem.eql(u8, data_a, data_b);
    }
    const scalar_time = timer.read();

    const speedup = if (simd_time > 0) @as(f64, @floatFromInt(scalar_time)) / @as(f64, @floatFromInt(simd_time)) else 1.0;

    suite.add(.{
        .name = "MemEql (1KB)",
        .simd_ns = simd_time,
        .scalar_ns = scalar_time,
        .speedup = speedup,
    });
}

// ============================================================================
// Main Benchmark Runner
// ============================================================================

pub fn runBenchmarks() void {
    var suite = BenchmarkSuite.init();

    benchmarkMemEqlShort(&suite);
    benchmarkMemEql(&suite);
    benchmarkLargeMemEql(&suite);
    benchmarkHashKey(&suite);
    benchmarkPropsEql(&suite);
    benchmarkFindDiffPos(&suite);

    suite.printAll();
}

pub fn main() void {
    runBenchmarks();
}

// ============================================================================
// Tests
// ============================================================================

test "benchmark runs without error" {
    // Just verify the benchmark code compiles and runs
    var suite = BenchmarkSuite.init();
    benchmarkMemEqlShort(&suite);
    try std.testing.expect(suite.count == 1);
}
