//! Zylix Performance & Optimization Module
//!
//! Comprehensive performance optimization toolkit for Zylix applications:
//! - Virtual DOM diff optimization
//! - Memory pool and allocation optimization
//! - Render batching and scheduling
//! - Error boundary components
//! - Analytics and crash reporting
//! - Bundle size optimization

const std = @import("std");

// Sub-modules
pub const vdom_opt = @import("vdom_opt.zig");
pub const memory = @import("memory.zig");
pub const batch = @import("batch.zig");
pub const error_boundary = @import("error_boundary.zig");
pub const analytics = @import("analytics.zig");
pub const bundle = @import("bundle.zig");

// Re-export primary types
pub const VDomOptimizer = vdom_opt.VDomOptimizer;
pub const DiffCache = vdom_opt.DiffCache;
pub const MemoryPool = memory.MemoryPool;
pub const ObjectPool = memory.ObjectPool;
pub const ArenaOptimizer = memory.ArenaOptimizer;
pub const RenderBatcher = batch.RenderBatcher;
pub const FrameScheduler = batch.FrameScheduler;
pub const PriorityQueue = batch.PriorityQueue;
pub const ErrorBoundary = error_boundary.ErrorBoundary;
pub const ErrorRecovery = error_boundary.ErrorRecovery;
pub const CrashReporter = analytics.CrashReporter;
pub const AnalyticsHook = analytics.AnalyticsHook;
pub const BundleAnalyzer = bundle.BundleAnalyzer;
pub const TreeShaker = bundle.TreeShaker;

/// Performance configuration
pub const PerfConfig = struct {
    /// Enable Virtual DOM diff caching
    enable_diff_cache: bool = true,

    /// Maximum diff cache size (entries)
    max_diff_cache_size: usize = 1000,

    /// Enable memory pooling
    enable_memory_pool: bool = true,

    /// Memory pool initial size (bytes)
    pool_initial_size: usize = 1024 * 1024, // 1MB

    /// Enable render batching
    enable_render_batching: bool = true,

    /// Target frame time (nanoseconds)
    target_frame_time_ns: u64 = 16_666_667, // ~60fps

    /// Enable error boundaries
    enable_error_boundaries: bool = true,

    /// Enable analytics
    enable_analytics: bool = false,

    /// Enable crash reporting
    enable_crash_reporting: bool = false,

    /// Bundle optimization level
    optimization_level: OptimizationLevel = .balanced,

    pub const OptimizationLevel = enum {
        /// Minimal optimization, fastest builds
        none,
        /// Balance between size and speed
        balanced,
        /// Aggressive size optimization
        size,
        /// Aggressive speed optimization
        speed,
    };
};

/// Performance metrics
pub const PerfMetrics = struct {
    /// Total render time (nanoseconds)
    total_render_time_ns: u64 = 0,

    /// Number of renders
    render_count: u64 = 0,

    /// Average render time (nanoseconds)
    avg_render_time_ns: u64 = 0,

    /// Maximum render time (nanoseconds)
    max_render_time_ns: u64 = 0,

    /// Minimum render time (nanoseconds)
    min_render_time_ns: u64 = std.math.maxInt(u64),

    /// Diff cache hit rate (0.0 - 1.0)
    diff_cache_hit_rate: f64 = 0.0,

    /// Memory pool utilization (0.0 - 1.0)
    pool_utilization: f64 = 0.0,

    /// Frames dropped
    frames_dropped: u64 = 0,

    /// Errors caught by boundaries
    errors_caught: u64 = 0,

    /// Update metrics with new render time
    pub fn recordRender(self: *PerfMetrics, render_time_ns: u64) void {
        self.total_render_time_ns += render_time_ns;
        self.render_count += 1;
        self.avg_render_time_ns = self.total_render_time_ns / self.render_count;
        self.max_render_time_ns = @max(self.max_render_time_ns, render_time_ns);
        self.min_render_time_ns = @min(self.min_render_time_ns, render_time_ns);
    }

    /// Check if performance is within target
    pub fn isWithinTarget(self: *const PerfMetrics, target_ns: u64) bool {
        return self.avg_render_time_ns <= target_ns;
    }

    /// Reset metrics
    pub fn reset(self: *PerfMetrics) void {
        self.* = .{};
    }

    /// Get metrics summary as string
    pub fn summary(self: *const PerfMetrics, allocator: std.mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(allocator,
            \\Performance Metrics:
            \\  Renders: {d}
            \\  Avg Time: {d:.2}ms
            \\  Max Time: {d:.2}ms
            \\  Min Time: {d:.2}ms
            \\  Cache Hit Rate: {d:.1}%
            \\  Pool Utilization: {d:.1}%
            \\  Frames Dropped: {d}
            \\  Errors Caught: {d}
        , .{
            self.render_count,
            @as(f64, @floatFromInt(self.avg_render_time_ns)) / 1_000_000.0,
            @as(f64, @floatFromInt(self.max_render_time_ns)) / 1_000_000.0,
            @as(f64, @floatFromInt(if (self.min_render_time_ns == std.math.maxInt(u64)) 0 else self.min_render_time_ns)) / 1_000_000.0,
            self.diff_cache_hit_rate * 100.0,
            self.pool_utilization * 100.0,
            self.frames_dropped,
            self.errors_caught,
        });
    }
};

/// Performance profiler for measuring and optimizing performance
pub const Profiler = struct {
    allocator: std.mem.Allocator,
    config: PerfConfig,
    metrics: PerfMetrics,
    vdom_optimizer: ?*VDomOptimizer,
    memory_pool: ?*MemoryPool,
    render_batcher: ?*RenderBatcher,
    frame_scheduler: ?*FrameScheduler,
    start_time: i128,

    pub fn init(allocator: std.mem.Allocator, config: PerfConfig) !*Profiler {
        const profiler = try allocator.create(Profiler);
        profiler.* = .{
            .allocator = allocator,
            .config = config,
            .metrics = .{},
            .vdom_optimizer = null,
            .memory_pool = null,
            .render_batcher = null,
            .frame_scheduler = null,
            .start_time = std.time.nanoTimestamp(),
        };

        // Initialize sub-systems based on config
        if (config.enable_diff_cache) {
            profiler.vdom_optimizer = try VDomOptimizer.init(allocator, config.max_diff_cache_size);
        }

        if (config.enable_memory_pool) {
            profiler.memory_pool = try MemoryPool.init(allocator, config.pool_initial_size);
        }

        if (config.enable_render_batching) {
            profiler.render_batcher = try RenderBatcher.init(allocator);
            profiler.frame_scheduler = try FrameScheduler.init(allocator, config.target_frame_time_ns);
        }

        return profiler;
    }

    pub fn deinit(self: *Profiler) void {
        if (self.vdom_optimizer) |opt| opt.deinit();
        if (self.memory_pool) |pool| pool.deinit();
        if (self.render_batcher) |batcher| batcher.deinit();
        if (self.frame_scheduler) |scheduler| scheduler.deinit();
        self.allocator.destroy(self);
    }

    /// Start a profiling section
    pub fn beginSection(self: *Profiler, name: []const u8) Section {
        _ = self;
        return Section{
            .name = name,
            .start_time = std.time.nanoTimestamp(),
        };
    }

    /// End a profiling section
    pub fn endSection(self: *Profiler, section: *Section) u64 {
        const end_time = std.time.nanoTimestamp();
        const duration = @as(u64, @intCast(end_time - section.start_time));
        self.metrics.recordRender(duration);
        return duration;
    }

    /// Get current metrics
    pub fn getMetrics(self: *const Profiler) PerfMetrics {
        return self.metrics;
    }

    /// Get uptime in nanoseconds
    pub fn getUptime(self: *const Profiler) u64 {
        const now = std.time.nanoTimestamp();
        return @intCast(now - self.start_time);
    }

    pub const Section = struct {
        name: []const u8,
        start_time: i128,
    };
};

/// Quick performance check macro-like function
pub fn measureTime(comptime func: anytype, args: anytype) struct { result: @typeInfo(@TypeOf(func)).@"fn".return_type.?, time_ns: u64 } {
    const start = std.time.nanoTimestamp();
    const result = @call(.auto, func, args);
    const end = std.time.nanoTimestamp();
    return .{
        .result = result,
        .time_ns = @intCast(end - start),
    };
}

// ============================================================================
// Unit Tests
// ============================================================================

test "PerfConfig defaults" {
    const config = PerfConfig{};
    try std.testing.expect(config.enable_diff_cache);
    try std.testing.expect(config.enable_memory_pool);
    try std.testing.expect(config.enable_render_batching);
    try std.testing.expectEqual(@as(u64, 16_666_667), config.target_frame_time_ns);
}

test "PerfMetrics recording" {
    var metrics = PerfMetrics{};

    metrics.recordRender(10_000_000); // 10ms
    try std.testing.expectEqual(@as(u64, 1), metrics.render_count);
    try std.testing.expectEqual(@as(u64, 10_000_000), metrics.avg_render_time_ns);

    metrics.recordRender(20_000_000); // 20ms
    try std.testing.expectEqual(@as(u64, 2), metrics.render_count);
    try std.testing.expectEqual(@as(u64, 15_000_000), metrics.avg_render_time_ns);
    try std.testing.expectEqual(@as(u64, 20_000_000), metrics.max_render_time_ns);
    try std.testing.expectEqual(@as(u64, 10_000_000), metrics.min_render_time_ns);
}

test "PerfMetrics within target" {
    var metrics = PerfMetrics{};
    metrics.recordRender(10_000_000); // 10ms

    try std.testing.expect(metrics.isWithinTarget(16_666_667)); // 60fps target
    try std.testing.expect(!metrics.isWithinTarget(5_000_000)); // 5ms target
}

test "Profiler init and deinit" {
    const allocator = std.testing.allocator;

    var profiler = try Profiler.init(allocator, .{});
    defer profiler.deinit();

    try std.testing.expect(profiler.vdom_optimizer != null);
    try std.testing.expect(profiler.memory_pool != null);
    try std.testing.expect(profiler.render_batcher != null);
}

test "Profiler section timing" {
    const allocator = std.testing.allocator;

    var profiler = try Profiler.init(allocator, .{});
    defer profiler.deinit();

    var section = profiler.beginSection("test");
    std.Thread.sleep(1_000_000); // 1ms
    const duration = profiler.endSection(&section);

    try std.testing.expect(duration >= 1_000_000);
    try std.testing.expectEqual(@as(u64, 1), profiler.metrics.render_count);
}
