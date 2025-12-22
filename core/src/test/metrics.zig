// Zylix Test Framework - Performance Metrics
// Comprehensive test performance monitoring and analysis

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Metric data point
pub const DataPoint = struct {
    timestamp: i64,
    value: f64,
    labels: ?[]const Label = null,

    pub const Label = struct {
        key: []const u8,
        value: []const u8,
    };
};

/// Metric types
pub const MetricType = enum {
    counter,
    gauge,
    histogram,
    summary,
};

/// Histogram bucket configuration
pub const HistogramBuckets = struct {
    boundaries: []const f64 = &default_boundaries,
    counts: []u64 = &.{},

    const default_boundaries = [_]f64{ 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0 };
};

/// Performance metric
pub const Metric = struct {
    name: []const u8,
    description: []const u8,
    metric_type: MetricType,
    unit: []const u8,
    values: std.ArrayList(DataPoint),

    // Statistics
    count: u64,
    sum: f64,
    min: f64,
    max: f64,
    mean: f64,
    variance: f64,

    const Self = @This();

    pub fn init(allocator: Allocator, name: []const u8, description: []const u8, metric_type: MetricType, unit: []const u8) Self {
        return .{
            .name = name,
            .description = description,
            .metric_type = metric_type,
            .unit = unit,
            .values = std.ArrayList(DataPoint).init(allocator),
            .count = 0,
            .sum = 0,
            .min = std.math.inf(f64),
            .max = -std.math.inf(f64),
            .mean = 0,
            .variance = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.values.deinit();
    }

    /// Record a value
    pub fn record(self: *Self, value: f64) !void {
        const timestamp = std.time.timestamp();
        try self.values.append(.{ .timestamp = timestamp, .value = value });

        // Update statistics (Welford's online algorithm)
        self.count += 1;
        self.sum += value;

        if (value < self.min) self.min = value;
        if (value > self.max) self.max = value;

        const delta = value - self.mean;
        self.mean += delta / @as(f64, @floatFromInt(self.count));
        const delta2 = value - self.mean;
        self.variance += delta * delta2;
    }

    /// Get standard deviation
    pub fn stddev(self: Self) f64 {
        if (self.count < 2) return 0;
        return @sqrt(self.variance / @as(f64, @floatFromInt(self.count - 1)));
    }

    /// Get percentile (p50, p90, p95, p99)
    pub fn percentile(self: *Self, p: f64, allocator: Allocator) !f64 {
        if (self.values.items.len == 0) return 0;

        // Sort values
        var sorted = try allocator.alloc(f64, self.values.items.len);
        defer allocator.free(sorted);

        for (self.values.items, 0..) |dp, i| {
            sorted[i] = dp.value;
        }

        std.mem.sort(f64, sorted, {}, std.sort.asc(f64));

        const index = @as(usize, @intFromFloat(p / 100.0 * @as(f64, @floatFromInt(sorted.len - 1))));
        return sorted[@min(index, sorted.len - 1)];
    }
};

/// Metrics collector
pub const MetricsCollector = struct {
    allocator: Allocator,
    metrics: std.StringHashMap(Metric),
    start_time: i64,
    labels: std.ArrayList(DataPoint.Label),

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .metrics = std.StringHashMap(Metric).init(allocator),
            .start_time = std.time.timestamp(),
            .labels = std.ArrayList(DataPoint.Label).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.metrics.valueIterator();
        while (iter.next()) |metric| {
            metric.deinit();
        }
        self.metrics.deinit();
        self.labels.deinit();
    }

    /// Add a global label
    pub fn addLabel(self: *Self, key: []const u8, value: []const u8) !void {
        try self.labels.append(.{ .key = key, .value = value });
    }

    /// Register a new metric
    pub fn register(self: *Self, name: []const u8, description: []const u8, metric_type: MetricType, unit: []const u8) !*Metric {
        const result = try self.metrics.getOrPut(name);
        if (!result.found_existing) {
            result.value_ptr.* = Metric.init(self.allocator, name, description, metric_type, unit);
        }
        return result.value_ptr;
    }

    /// Record a value for a metric
    pub fn record(self: *Self, name: []const u8, value: f64) !void {
        if (self.metrics.getPtr(name)) |metric| {
            try metric.record(value);
        }
    }

    /// Increment a counter
    pub fn increment(self: *Self, name: []const u8) !void {
        try self.record(name, 1);
    }

    /// Record timing in milliseconds
    pub fn timing(self: *Self, name: []const u8, start_ns: i128) !void {
        const end_ns = std.time.nanoTimestamp();
        const duration_ms = @as(f64, @floatFromInt(end_ns - start_ns)) / 1_000_000.0;
        try self.record(name, duration_ms);
    }

    /// Get all metrics
    pub fn getAll(self: *Self) []Metric {
        var result = std.ArrayList(Metric).init(self.allocator);

        var iter = self.metrics.valueIterator();
        while (iter.next()) |metric| {
            result.append(metric.*) catch {};
        }

        return result.toOwnedSlice() catch &.{};
    }

    /// Export to Prometheus format
    pub fn exportPrometheus(self: *Self, allocator: Allocator) ![]const u8 {
        var buffer = std.ArrayList(u8).init(allocator);
        const writer = buffer.writer();

        var iter = self.metrics.iterator();
        while (iter.next()) |entry| {
            const metric = entry.value_ptr;

            try writer.print("# HELP {s} {s}\n", .{ metric.name, metric.description });
            try writer.print("# TYPE {s} {s}\n", .{ metric.name, @tagName(metric.metric_type) });

            switch (metric.metric_type) {
                .counter, .gauge => {
                    try writer.print("{s} {d}\n", .{ metric.name, metric.sum });
                },
                .histogram, .summary => {
                    try writer.print("{s}_count {d}\n", .{ metric.name, metric.count });
                    try writer.print("{s}_sum {d}\n", .{ metric.name, metric.sum });
                    try writer.print("{s}_min {d}\n", .{ metric.name, metric.min });
                    try writer.print("{s}_max {d}\n", .{ metric.name, metric.max });
                    try writer.print("{s}_avg {d}\n", .{ metric.name, metric.mean });
                },
            }
            try writer.writeAll("\n");
        }

        return buffer.toOwnedSlice();
    }

    /// Export to JSON format
    pub fn exportJSON(self: *Self, allocator: Allocator) ![]const u8 {
        var buffer = std.ArrayList(u8).init(allocator);
        const writer = buffer.writer();

        try writer.writeAll("{\n  \"metrics\": [\n");

        var first = true;
        var iter = self.metrics.iterator();
        while (iter.next()) |entry| {
            if (!first) try writer.writeAll(",\n");
            first = false;

            const metric = entry.value_ptr;

            try writer.writeAll("    {\n");
            try writer.print("      \"name\": \"{s}\",\n", .{metric.name});
            try writer.print("      \"type\": \"{s}\",\n", .{@tagName(metric.metric_type)});
            try writer.print("      \"unit\": \"{s}\",\n", .{metric.unit});
            try writer.print("      \"count\": {d},\n", .{metric.count});
            try writer.print("      \"sum\": {d},\n", .{metric.sum});
            try writer.print("      \"min\": {d},\n", .{if (metric.min == std.math.inf(f64)) @as(f64, 0) else metric.min});
            try writer.print("      \"max\": {d},\n", .{if (metric.max == -std.math.inf(f64)) @as(f64, 0) else metric.max});
            try writer.print("      \"mean\": {d},\n", .{metric.mean});
            try writer.print("      \"stddev\": {d}\n", .{metric.stddev()});
            try writer.writeAll("    }");
        }

        try writer.writeAll("\n  ],\n");
        try writer.print("  \"start_time\": {d},\n", .{self.start_time});
        try writer.print("  \"duration_s\": {d}\n", .{std.time.timestamp() - self.start_time});
        try writer.writeAll("}\n");

        return buffer.toOwnedSlice();
    }
};

/// Timer for measuring durations
pub const Timer = struct {
    start: i128,
    collector: *MetricsCollector,
    metric_name: []const u8,

    const Self = @This();

    pub fn start(collector: *MetricsCollector, metric_name: []const u8) Self {
        return .{
            .start = std.time.nanoTimestamp(),
            .collector = collector,
            .metric_name = metric_name,
        };
    }

    pub fn stop(self: *Self) !void {
        try self.collector.timing(self.metric_name, self.start);
    }

    pub fn elapsedMs(self: Self) f64 {
        const now = std.time.nanoTimestamp();
        return @as(f64, @floatFromInt(now - self.start)) / 1_000_000.0;
    }
};

/// Test performance tracker
pub const PerformanceTracker = struct {
    collector: MetricsCollector,

    const Self = @This();

    pub fn init(allocator: Allocator) !Self {
        var tracker = Self{
            .collector = MetricsCollector.init(allocator),
        };

        // Register standard metrics
        _ = try tracker.collector.register("test_duration_ms", "Test execution duration", .histogram, "ms");
        _ = try tracker.collector.register("test_count", "Number of tests executed", .counter, "count");
        _ = try tracker.collector.register("test_passed", "Number of tests passed", .counter, "count");
        _ = try tracker.collector.register("test_failed", "Number of tests failed", .counter, "count");
        _ = try tracker.collector.register("test_skipped", "Number of tests skipped", .counter, "count");
        _ = try tracker.collector.register("memory_bytes", "Memory usage", .gauge, "bytes");
        _ = try tracker.collector.register("cpu_time_ms", "CPU time used", .histogram, "ms");

        return tracker;
    }

    pub fn deinit(self: *Self) void {
        self.collector.deinit();
    }

    /// Start timing a test
    pub fn startTest(self: *Self) Timer {
        return Timer.start(&self.collector, "test_duration_ms");
    }

    /// Record test completion
    pub fn recordTest(self: *Self, passed: bool, skipped: bool) !void {
        try self.collector.increment("test_count");
        if (skipped) {
            try self.collector.increment("test_skipped");
        } else if (passed) {
            try self.collector.increment("test_passed");
        } else {
            try self.collector.increment("test_failed");
        }
    }

    /// Record memory usage
    pub fn recordMemory(self: *Self, bytes: u64) !void {
        try self.collector.record("memory_bytes", @floatFromInt(bytes));
    }

    /// Get summary report
    pub fn getSummary(self: *Self) !PerformanceSummary {
        const allocator = self.collector.allocator;

        const duration_metric = self.collector.metrics.get("test_duration_ms");
        const count_metric = self.collector.metrics.get("test_count");
        const passed_metric = self.collector.metrics.get("test_passed");
        const failed_metric = self.collector.metrics.get("test_failed");

        return PerformanceSummary{
            .total_tests = if (count_metric) |m| @intFromFloat(m.sum) else 0,
            .passed_tests = if (passed_metric) |m| @intFromFloat(m.sum) else 0,
            .failed_tests = if (failed_metric) |m| @intFromFloat(m.sum) else 0,
            .total_duration_ms = if (duration_metric) |m| m.sum else 0,
            .avg_duration_ms = if (duration_metric) |m| m.mean else 0,
            .min_duration_ms = if (duration_metric) |m| (if (m.min == std.math.inf(f64)) 0 else m.min) else 0,
            .max_duration_ms = if (duration_metric) |m| (if (m.max == -std.math.inf(f64)) 0 else m.max) else 0,
            .p50_duration_ms = if (duration_metric) |*m| try m.percentile(50, allocator) else 0,
            .p95_duration_ms = if (duration_metric) |*m| try m.percentile(95, allocator) else 0,
            .p99_duration_ms = if (duration_metric) |*m| try m.percentile(99, allocator) else 0,
        };
    }
};

/// Performance summary
pub const PerformanceSummary = struct {
    total_tests: u64,
    passed_tests: u64,
    failed_tests: u64,
    total_duration_ms: f64,
    avg_duration_ms: f64,
    min_duration_ms: f64,
    max_duration_ms: f64,
    p50_duration_ms: f64,
    p95_duration_ms: f64,
    p99_duration_ms: f64,
};

// Tests
test "Metric recording" {
    const allocator = std.testing.allocator;

    var metric = Metric.init(allocator, "test_metric", "Test metric", .histogram, "ms");
    defer metric.deinit();

    try metric.record(10);
    try metric.record(20);
    try metric.record(30);

    try std.testing.expectEqual(@as(u64, 3), metric.count);
    try std.testing.expectApproxEqAbs(@as(f64, 60), metric.sum, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 20), metric.mean, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 10), metric.min, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 30), metric.max, 0.001);
}

test "MetricsCollector" {
    const allocator = std.testing.allocator;

    var collector = MetricsCollector.init(allocator);
    defer collector.deinit();

    _ = try collector.register("requests", "HTTP requests", .counter, "count");
    _ = try collector.register("latency", "Request latency", .histogram, "ms");

    try collector.increment("requests");
    try collector.increment("requests");
    try collector.record("latency", 100);
    try collector.record("latency", 150);

    const requests = collector.metrics.get("requests").?;
    try std.testing.expectApproxEqAbs(@as(f64, 2), requests.sum, 0.001);

    const latency = collector.metrics.get("latency").?;
    try std.testing.expectApproxEqAbs(@as(f64, 125), latency.mean, 0.001);
}

test "PerformanceTracker" {
    const allocator = std.testing.allocator;

    var tracker = try PerformanceTracker.init(allocator);
    defer tracker.deinit();

    try tracker.recordTest(true, false);
    try tracker.recordTest(true, false);
    try tracker.recordTest(false, false);

    const summary = try tracker.getSummary();
    try std.testing.expectEqual(@as(u64, 3), summary.total_tests);
    try std.testing.expectEqual(@as(u64, 2), summary.passed_tests);
    try std.testing.expectEqual(@as(u64, 1), summary.failed_tests);
}
