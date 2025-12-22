// Zylix Test Framework - Retry & Flaky Test Handling
// Intelligent retry strategies for unreliable tests

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Retry strategy
pub const RetryStrategy = enum {
    /// No retries
    none,
    /// Fixed delay between retries
    fixed,
    /// Exponential backoff
    exponential,
    /// Linear backoff
    linear,
    /// Immediate retry without delay
    immediate,
};

/// Retry configuration
pub const RetryConfig = struct {
    /// Maximum number of retry attempts
    max_retries: u32 = 3,
    /// Retry strategy
    strategy: RetryStrategy = .exponential,
    /// Initial delay in milliseconds
    initial_delay_ms: u64 = 100,
    /// Maximum delay in milliseconds
    max_delay_ms: u64 = 10000,
    /// Multiplier for exponential/linear backoff
    multiplier: f64 = 2.0,
    /// Jitter factor (0.0 - 1.0) to add randomness
    jitter: f64 = 0.1,
    /// Only retry on specific errors
    retry_on: []const anyerror = &.{},
    /// Never retry on specific errors
    no_retry_on: []const anyerror = &.{},
    /// Callback before each retry
    on_retry: ?*const fn (attempt: u32, err: anyerror, delay_ms: u64) void = null,
};

/// Retry executor
pub const RetryExecutor = struct {
    config: RetryConfig,
    attempt: u32,
    last_error: ?anyerror,
    total_delay_ms: u64,
    rng: std.Random,

    const Self = @This();

    pub fn init(config: RetryConfig) Self {
        var seed: u64 = undefined;
        std.posix.getrandom(std.mem.asBytes(&seed)) catch {
            seed = @intCast(std.time.milliTimestamp());
        };

        return .{
            .config = config,
            .attempt = 0,
            .last_error = null,
            .total_delay_ms = 0,
            .rng = std.Random.DefaultPrng.init(seed).random(),
        };
    }

    /// Execute a function with retry logic
    pub fn execute(self: *Self, comptime T: type, func: *const fn () anyerror!T) !T {
        while (true) {
            self.attempt += 1;

            if (func()) |result| {
                return result;
            } else |err| {
                self.last_error = err;

                if (!self.shouldRetry(err)) {
                    return err;
                }

                if (self.attempt > self.config.max_retries) {
                    return err;
                }

                const delay = self.calculateDelay();
                self.total_delay_ms += delay;

                if (self.config.on_retry) |callback| {
                    callback(self.attempt, err, delay);
                }

                std.time.sleep(delay * std.time.ns_per_ms);
            }
        }
    }

    /// Check if should retry for given error
    fn shouldRetry(self: *Self, err: anyerror) bool {
        // Check no_retry_on list
        for (self.config.no_retry_on) |no_retry_err| {
            if (err == no_retry_err) return false;
        }

        // If retry_on is specified, only retry on those errors
        if (self.config.retry_on.len > 0) {
            for (self.config.retry_on) |retry_err| {
                if (err == retry_err) return true;
            }
            return false;
        }

        return true;
    }

    /// Calculate delay for current attempt
    fn calculateDelay(self: *Self) u64 {
        var delay: u64 = switch (self.config.strategy) {
            .none => 0,
            .immediate => 0,
            .fixed => self.config.initial_delay_ms,
            .linear => self.config.initial_delay_ms * self.attempt,
            .exponential => blk: {
                const exp = std.math.pow(f64, self.config.multiplier, @as(f64, @floatFromInt(self.attempt - 1)));
                break :blk @intFromFloat(@as(f64, @floatFromInt(self.config.initial_delay_ms)) * exp);
            },
        };

        // Apply max delay cap
        delay = @min(delay, self.config.max_delay_ms);

        // Apply jitter
        if (self.config.jitter > 0) {
            const jitter_range = @as(f64, @floatFromInt(delay)) * self.config.jitter;
            const jitter_value = self.rng.float(f64) * jitter_range * 2 - jitter_range;
            delay = @intFromFloat(@max(0, @as(f64, @floatFromInt(delay)) + jitter_value));
        }

        return delay;
    }

    /// Get retry statistics
    pub fn getStats(self: Self) RetryStats {
        return .{
            .attempts = self.attempt,
            .retries = if (self.attempt > 0) self.attempt - 1 else 0,
            .total_delay_ms = self.total_delay_ms,
            .last_error = self.last_error,
            .success = self.last_error == null or self.attempt <= self.config.max_retries,
        };
    }
};

/// Retry statistics
pub const RetryStats = struct {
    attempts: u32,
    retries: u32,
    total_delay_ms: u64,
    last_error: ?anyerror,
    success: bool,
};

/// Flaky test handler
pub const FlakyHandler = struct {
    allocator: Allocator,
    quarantine: std.StringHashMap(QuarantineInfo),
    history: std.StringHashMap(TestHistory),
    config: FlakyConfig,

    const QuarantineInfo = struct {
        reason: []const u8,
        quarantined_at: i64,
        failure_count: u32,
        auto_quarantine: bool,
    };

    const TestHistory = struct {
        runs: u32,
        passes: u32,
        consecutive_failures: u32,
        consecutive_passes: u32,
        last_failure_time: i64,
        last_pass_time: i64,
    };

    const Self = @This();

    pub fn init(allocator: Allocator, config: FlakyConfig) Self {
        return .{
            .allocator = allocator,
            .quarantine = std.StringHashMap(QuarantineInfo).init(allocator),
            .history = std.StringHashMap(TestHistory).init(allocator),
            .config = config,
        };
    }

    pub fn deinit(self: *Self) void {
        self.quarantine.deinit();
        self.history.deinit();
    }

    /// Record a test result
    pub fn recordResult(self: *Self, test_name: []const u8, passed: bool) !void {
        const entry = try self.history.getOrPut(test_name);
        if (!entry.found_existing) {
            entry.value_ptr.* = .{
                .runs = 0,
                .passes = 0,
                .consecutive_failures = 0,
                .consecutive_passes = 0,
                .last_failure_time = 0,
                .last_pass_time = 0,
            };
        }

        const hist = entry.value_ptr;
        hist.runs += 1;

        if (passed) {
            hist.passes += 1;
            hist.consecutive_passes += 1;
            hist.consecutive_failures = 0;
            hist.last_pass_time = std.time.timestamp();

            // Check if test should be removed from quarantine
            if (self.config.auto_unquarantine and hist.consecutive_passes >= self.config.unquarantine_threshold) {
                _ = self.quarantine.remove(test_name);
            }
        } else {
            hist.consecutive_failures += 1;
            hist.consecutive_passes = 0;
            hist.last_failure_time = std.time.timestamp();

            // Check if test should be auto-quarantined
            if (self.config.auto_quarantine and hist.consecutive_failures >= self.config.quarantine_threshold) {
                try self.quarantine.put(test_name, .{
                    .reason = "Auto-quarantined due to consecutive failures",
                    .quarantined_at = std.time.timestamp(),
                    .failure_count = hist.consecutive_failures,
                    .auto_quarantine = true,
                });
            }
        }
    }

    /// Check if test is quarantined
    pub fn isQuarantined(self: *Self, test_name: []const u8) bool {
        return self.quarantine.contains(test_name);
    }

    /// Manually quarantine a test
    pub fn quarantineTest(self: *Self, test_name: []const u8, reason: []const u8) !void {
        try self.quarantine.put(test_name, .{
            .reason = reason,
            .quarantined_at = std.time.timestamp(),
            .failure_count = 0,
            .auto_quarantine = false,
        });
    }

    /// Get flakiness score (0.0 = stable, 1.0 = very flaky)
    pub fn getFlakinessScore(self: *Self, test_name: []const u8) f64 {
        const hist = self.history.get(test_name) orelse return 0;

        if (hist.runs < 5) return 0; // Not enough data

        const pass_rate = @as(f64, @floatFromInt(hist.passes)) / @as(f64, @floatFromInt(hist.runs));

        // A test is flaky if it has a mixed pass/fail ratio
        // 0.0 or 1.0 pass rate = not flaky
        // 0.5 pass rate = maximally flaky
        return 1.0 - @abs(pass_rate - 0.5) * 2.0;
    }

    /// Get all flaky tests
    pub fn getFlakyTests(self: *Self, threshold: f64, allocator: Allocator) ![]const []const u8 {
        var flaky = std.ArrayList([]const u8).init(allocator);

        var iter = self.history.iterator();
        while (iter.next()) |entry| {
            if (self.getFlakinessScore(entry.key_ptr.*) >= threshold) {
                try flaky.append(entry.key_ptr.*);
            }
        }

        return flaky.toOwnedSlice();
    }

    /// Get quarantine report
    pub fn getQuarantineReport(self: *Self, allocator: Allocator) ![]const u8 {
        var buffer = std.ArrayList(u8).init(allocator);
        const writer = buffer.writer();

        try writer.writeAll("# Quarantined Tests Report\n\n");

        var iter = self.quarantine.iterator();
        while (iter.next()) |entry| {
            const info = entry.value_ptr;
            try writer.print("## {s}\n", .{entry.key_ptr.*});
            try writer.print("- Reason: {s}\n", .{info.reason});
            try writer.print("- Quarantined at: {d}\n", .{info.quarantined_at});
            try writer.print("- Failure count: {d}\n", .{info.failure_count});
            try writer.print("- Auto-quarantine: {}\n\n", .{info.auto_quarantine});
        }

        return buffer.toOwnedSlice();
    }
};

/// Flaky test configuration
pub const FlakyConfig = struct {
    /// Enable auto-quarantine for repeatedly failing tests
    auto_quarantine: bool = true,
    /// Number of consecutive failures before quarantine
    quarantine_threshold: u32 = 3,
    /// Enable auto-unquarantine for recovering tests
    auto_unquarantine: bool = true,
    /// Number of consecutive passes to remove from quarantine
    unquarantine_threshold: u32 = 5,
    /// Flakiness threshold for reporting
    flakiness_threshold: f64 = 0.3,
};

/// Retry helper function
pub fn withRetry(comptime T: type, config: RetryConfig, func: *const fn () anyerror!T) !T {
    var executor = RetryExecutor.init(config);
    return executor.execute(T, func);
}

/// Simple retry with defaults
pub fn retry(comptime T: type, max_attempts: u32, func: *const fn () anyerror!T) !T {
    return withRetry(T, .{ .max_retries = max_attempts }, func);
}

// Tests
test "RetryExecutor exponential backoff" {
    var executor = RetryExecutor.init(.{
        .max_retries = 3,
        .strategy = .exponential,
        .initial_delay_ms = 100,
        .multiplier = 2.0,
        .jitter = 0,
    });

    // First attempt: 100ms
    try std.testing.expectEqual(@as(u64, 100), executor.calculateDelay());
    executor.attempt = 1;

    // Second attempt: 200ms
    try std.testing.expectEqual(@as(u64, 200), executor.calculateDelay());
    executor.attempt = 2;

    // Third attempt: 400ms
    try std.testing.expectEqual(@as(u64, 400), executor.calculateDelay());
}

test "RetryExecutor max delay cap" {
    var executor = RetryExecutor.init(.{
        .max_retries = 10,
        .strategy = .exponential,
        .initial_delay_ms = 1000,
        .max_delay_ms = 5000,
        .multiplier = 2.0,
        .jitter = 0,
    });

    executor.attempt = 5;
    const delay = executor.calculateDelay();
    try std.testing.expect(delay <= 5000);
}

test "FlakyHandler auto-quarantine" {
    const allocator = std.testing.allocator;

    var handler = FlakyHandler.init(allocator, .{
        .quarantine_threshold = 3,
    });
    defer handler.deinit();

    // Record 3 consecutive failures
    try handler.recordResult("flaky_test", false);
    try handler.recordResult("flaky_test", false);
    try std.testing.expect(!handler.isQuarantined("flaky_test"));

    try handler.recordResult("flaky_test", false);
    try std.testing.expect(handler.isQuarantined("flaky_test"));
}

test "FlakyHandler flakiness score" {
    const allocator = std.testing.allocator;

    var handler = FlakyHandler.init(allocator, .{});
    defer handler.deinit();

    // Record mixed results
    try handler.recordResult("mixed_test", true);
    try handler.recordResult("mixed_test", false);
    try handler.recordResult("mixed_test", true);
    try handler.recordResult("mixed_test", false);
    try handler.recordResult("mixed_test", true);

    const score = handler.getFlakinessScore("mixed_test");
    try std.testing.expect(score > 0.5); // High flakiness

    // Record stable results
    try handler.recordResult("stable_test", true);
    try handler.recordResult("stable_test", true);
    try handler.recordResult("stable_test", true);
    try handler.recordResult("stable_test", true);
    try handler.recordResult("stable_test", true);

    const stable_score = handler.getFlakinessScore("stable_test");
    try std.testing.expect(stable_score < 0.1); // Low flakiness
}

test "RetryConfig defaults" {
    const config = RetryConfig{};
    try std.testing.expectEqual(@as(u32, 3), config.max_retries);
    try std.testing.expectEqual(RetryStrategy.exponential, config.strategy);
}
