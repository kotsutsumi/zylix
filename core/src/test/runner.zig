// Zylix Test Framework - Test Runner
// Provides test execution, reporting, and parallel test running

const std = @import("std");
const driver_mod = @import("driver.zig");
const app_mod = @import("app.zig");

pub const Driver = driver_mod.Driver;
pub const Platform = driver_mod.Platform;
pub const App = app_mod.App;
pub const TestContext = app_mod.TestContext;
pub const TestFixture = app_mod.TestFixture;

/// Test result status
pub const TestStatus = enum {
    passed,
    failed,
    skipped,
    timeout,
    error_,
};

/// Single test result
pub const TestResult = struct {
    name: []const u8,
    status: TestStatus,
    duration_ms: u64,
    error_message: ?[]const u8 = null,
    stack_trace: ?[]const u8 = null,
    screenshots: std.ArrayListUnmanaged([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) TestResult {
        return .{
            .name = name,
            .status = .passed,
            .duration_ms = 0,
            .screenshots = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TestResult) void {
        self.screenshots.deinit(self.allocator);
    }

    pub fn fail(self: *TestResult, message: []const u8) void {
        self.status = .failed;
        self.error_message = message;
    }

    pub fn skip(self: *TestResult, reason: ?[]const u8) void {
        self.status = .skipped;
        self.error_message = reason;
    }

    pub fn addScreenshot(self: *TestResult, path: []const u8) !void {
        try self.screenshots.append(self.allocator, path);
    }
};

/// Test suite result
pub const SuiteResult = struct {
    name: []const u8,
    tests: std.ArrayListUnmanaged(TestResult),
    passed: u32 = 0,
    failed: u32 = 0,
    skipped: u32 = 0,
    duration_ms: u64 = 0,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) SuiteResult {
        return .{
            .name = name,
            .tests = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SuiteResult) void {
        for (self.tests.items) |*test_result| {
            test_result.deinit();
        }
        self.tests.deinit(self.allocator);
    }

    pub fn addResult(self: *SuiteResult, result: TestResult) !void {
        try self.tests.append(self.allocator, result);
        switch (result.status) {
            .passed => self.passed += 1,
            .failed, .error_, .timeout => self.failed += 1,
            .skipped => self.skipped += 1,
        }
        self.duration_ms += result.duration_ms;
    }

    pub fn isSuccess(self: *const SuiteResult) bool {
        return self.failed == 0;
    }
};

/// Test function signature
pub const TestFn = *const fn (*TestContext) anyerror!void;

/// Test case definition
pub const TestCase = struct {
    name: []const u8,
    func: TestFn,
    timeout_ms: u32 = 60000,
    retries: u32 = 0,
    skip: bool = false,
    skip_reason: ?[]const u8 = null,
    tags: []const []const u8 = &[_][]const u8{},
};

/// Test suite definition
pub const TestSuite = struct {
    name: []const u8,
    tests: std.ArrayListUnmanaged(TestCase),
    before_all: ?*const fn (*TestContext) anyerror!void = null,
    after_all: ?*const fn (*TestContext) anyerror!void = null,
    before_each: ?*const fn (*TestContext) anyerror!void = null,
    after_each: ?*const fn (*TestContext) anyerror!void = null,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) TestSuite {
        return .{
            .name = name,
            .tests = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TestSuite) void {
        self.tests.deinit(self.allocator);
    }

    pub fn addTest(self: *TestSuite, test_case: TestCase) !void {
        try self.tests.append(self.allocator, test_case);
    }

    pub fn test_(self: *TestSuite, name: []const u8, func: TestFn) !void {
        try self.addTest(.{ .name = name, .func = func });
    }

    pub fn skip(self: *TestSuite, name: []const u8, func: TestFn, reason: ?[]const u8) !void {
        try self.addTest(.{
            .name = name,
            .func = func,
            .skip = true,
            .skip_reason = reason,
        });
    }
};

/// Runner configuration
pub const RunnerConfig = struct {
    /// Run tests in parallel
    parallel: bool = false,
    /// Maximum parallel tests
    max_parallel: u32 = 4,
    /// Stop on first failure
    fail_fast: bool = false,
    /// Retry failed tests
    retries: u32 = 0,
    /// Default test timeout
    timeout_ms: u32 = 60000,
    /// Filter by tag
    tags: ?[]const []const u8 = null,
    /// Filter by test name pattern
    filter: ?[]const u8 = null,
    /// Output format
    output_format: OutputFormat = .console,
    /// Report output path
    report_path: ?[]const u8 = null,
    /// Screenshot on failure
    screenshot_on_failure: bool = true,
    /// Verbose output
    verbose: bool = false,
};

/// Output format
pub const OutputFormat = enum {
    console,
    json,
    junit,
    html,
};

/// Test runner
pub const TestRunner = struct {
    allocator: std.mem.Allocator,
    suites: std.ArrayListUnmanaged(TestSuite),
    config: RunnerConfig,
    context: TestContext,
    results: std.ArrayListUnmanaged(SuiteResult),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, config: RunnerConfig) Self {
        return .{
            .allocator = allocator,
            .suites = .{},
            .config = config,
            .context = TestContext.init(allocator),
            .results = .{},
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.suites.items) |*suite| {
            suite.deinit();
        }
        self.suites.deinit(self.allocator);

        for (self.results.items) |*result| {
            result.deinit();
        }
        self.results.deinit(self.allocator);

        self.context.deinit();
    }

    /// Add a test suite
    pub fn addSuite(self: *Self, suite: TestSuite) !void {
        try self.suites.append(self.allocator, suite);
    }

    /// Create and add a new suite
    pub fn describe(self: *Self, name: []const u8) !*TestSuite {
        try self.suites.append(self.allocator, TestSuite.init(self.allocator, name));
        return &self.suites.items[self.suites.items.len - 1];
    }

    /// Run all test suites
    pub fn run(self: *Self) !bool {
        var all_passed = true;

        for (self.suites.items) |*suite| {
            const result = try self.runSuite(suite);
            try self.results.append(self.allocator, result);

            if (!result.isSuccess()) {
                all_passed = false;
                if (self.config.fail_fast) {
                    break;
                }
            }
        }

        try self.generateReport();
        return all_passed;
    }

    /// Run a single test suite
    fn runSuite(self: *Self, suite: *TestSuite) !SuiteResult {
        var result = SuiteResult.init(self.allocator, suite.name);

        // Before all
        if (suite.before_all) |before_all| {
            before_all(&self.context) catch |err| {
                var test_result = TestResult.init(self.allocator, "before_all");
                test_result.status = .error_;
                test_result.error_message = @errorName(err);
                try result.addResult(test_result);
                return result;
            };
        }

        // Run tests
        for (suite.tests.items) |test_case| {
            if (!self.shouldRunTest(test_case)) {
                var test_result = TestResult.init(self.allocator, test_case.name);
                test_result.skip(test_case.skip_reason);
                try result.addResult(test_result);
                continue;
            }

            const test_result = try self.runTest(suite, test_case);
            try result.addResult(test_result);

            if (test_result.status == .failed and self.config.fail_fast) {
                break;
            }
        }

        // After all
        if (suite.after_all) |after_all| {
            after_all(&self.context) catch {};
        }

        return result;
    }

    /// Run a single test
    fn runTest(self: *Self, suite: *TestSuite, test_case: TestCase) !TestResult {
        var result = TestResult.init(self.allocator, test_case.name);
        const start_time = std.time.milliTimestamp();

        var retries: u32 = 0;
        const max_retries = if (test_case.retries > 0) test_case.retries else self.config.retries;

        while (retries <= max_retries) : (retries += 1) {
            // Before each
            if (suite.before_each) |before_each| {
                before_each(&self.context) catch |err| {
                    result.status = .error_;
                    result.error_message = @errorName(err);
                    break;
                };
            }

            // Run test
            const timeout = if (test_case.timeout_ms > 0) test_case.timeout_ms else self.config.timeout_ms;
            _ = timeout;

            test_case.func(&self.context) catch |err| {
                result.status = .failed;
                result.error_message = @errorName(err);

                if (self.config.screenshot_on_failure) {
                    // Take screenshot on failure
                    // Implementation depends on active app
                }

                if (retries < max_retries) {
                    continue; // Retry
                }
            };

            // After each
            if (suite.after_each) |after_each| {
                after_each(&self.context) catch {};
            }

            if (result.status == .passed) {
                break;
            }
        }

        result.duration_ms = @intCast(std.time.milliTimestamp() - start_time);
        return result;
    }

    /// Check if test should run based on filters
    fn shouldRunTest(self: *Self, test_case: TestCase) bool {
        if (test_case.skip) return false;

        // Filter by name
        if (self.config.filter) |filter| {
            if (std.mem.indexOf(u8, test_case.name, filter) == null) {
                return false;
            }
        }

        // Filter by tags
        if (self.config.tags) |required_tags| {
            var has_tag = false;
            for (required_tags) |required| {
                for (test_case.tags) |tag| {
                    if (std.mem.eql(u8, tag, required)) {
                        has_tag = true;
                        break;
                    }
                }
            }
            if (!has_tag) return false;
        }

        return true;
    }

    /// Generate test report
    fn generateReport(self: *Self) !void {
        switch (self.config.output_format) {
            .console => try self.printConsoleReport(),
            .json => try self.writeJsonReport(),
            .junit => try self.writeJunitReport(),
            .html => try self.writeHtmlReport(),
        }
    }

    fn printConsoleReport(self: *Self) !void {
        const stdout = std.io.getStdOut().writer();

        try stdout.print("\n========== Test Results ==========\n\n", .{});

        var total_passed: u32 = 0;
        var total_failed: u32 = 0;
        var total_skipped: u32 = 0;
        var total_duration: u64 = 0;

        for (self.results.items) |suite_result| {
            try stdout.print("Suite: {s}\n", .{suite_result.name});

            for (suite_result.tests.items) |test_result| {
                const status_str = switch (test_result.status) {
                    .passed => "✓",
                    .failed => "✗",
                    .skipped => "○",
                    .timeout => "⏱",
                    .error_ => "!",
                };

                try stdout.print("  {s} {s} ({d}ms)\n", .{
                    status_str,
                    test_result.name,
                    test_result.duration_ms,
                });

                if (test_result.error_message) |msg| {
                    try stdout.print("    Error: {s}\n", .{msg});
                }
            }

            total_passed += suite_result.passed;
            total_failed += suite_result.failed;
            total_skipped += suite_result.skipped;
            total_duration += suite_result.duration_ms;
        }

        try stdout.print("\n----------------------------------\n", .{});
        try stdout.print("Total: {d} passed, {d} failed, {d} skipped\n", .{
            total_passed,
            total_failed,
            total_skipped,
        });
        try stdout.print("Duration: {d}ms\n", .{total_duration});
        try stdout.print("==================================\n\n", .{});
    }

    fn writeJsonReport(self: *Self) !void {
        if (self.config.report_path) |path| {
            const file = try std.fs.cwd().createFile(path, .{});
            defer file.close();

            var writer = file.writer();
            try writer.writeAll("{\n  \"suites\": [\n");

            for (self.results.items, 0..) |suite_result, i| {
                if (i > 0) try writer.writeAll(",\n");
                try writer.print("    {{\n      \"name\": \"{s}\",\n      \"passed\": {d},\n      \"failed\": {d},\n      \"skipped\": {d}\n    }}", .{
                    suite_result.name,
                    suite_result.passed,
                    suite_result.failed,
                    suite_result.skipped,
                });
            }

            try writer.writeAll("\n  ]\n}\n");
        }
    }

    fn writeJunitReport(self: *Self) !void {
        if (self.config.report_path) |path| {
            const file = try std.fs.cwd().createFile(path, .{});
            defer file.close();

            var writer = file.writer();
            try writer.writeAll("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<testsuites>\n");

            for (self.results.items) |suite_result| {
                try writer.print("  <testsuite name=\"{s}\" tests=\"{d}\" failures=\"{d}\" skipped=\"{d}\">\n", .{
                    suite_result.name,
                    suite_result.tests.items.len,
                    suite_result.failed,
                    suite_result.skipped,
                });

                for (suite_result.tests.items) |test_result| {
                    try writer.print("    <testcase name=\"{s}\" time=\"{d}\"", .{
                        test_result.name,
                        @as(f64, @floatFromInt(test_result.duration_ms)) / 1000.0,
                    });

                    if (test_result.status == .failed) {
                        try writer.writeAll(">\n      <failure>");
                        if (test_result.error_message) |msg| {
                            try writer.writeAll(msg);
                        }
                        try writer.writeAll("</failure>\n    </testcase>\n");
                    } else if (test_result.status == .skipped) {
                        try writer.writeAll(">\n      <skipped/>\n    </testcase>\n");
                    } else {
                        try writer.writeAll("/>\n");
                    }
                }

                try writer.writeAll("  </testsuite>\n");
            }

            try writer.writeAll("</testsuites>\n");
        }
    }

    fn writeHtmlReport(self: *Self) !void {
        if (self.config.report_path) |path| {
            const file = try std.fs.cwd().createFile(path, .{});
            defer file.close();

            var writer = file.writer();
            try writer.writeAll(
                \\<!DOCTYPE html>
                \\<html>
                \\<head>
                \\  <title>Zylix Test Report</title>
                \\  <style>
                \\    body { font-family: system-ui, sans-serif; margin: 20px; }
                \\    .passed { color: green; }
                \\    .failed { color: red; }
                \\    .skipped { color: gray; }
                \\    .suite { margin: 20px 0; padding: 10px; border: 1px solid #ddd; }
                \\    .test { padding: 5px 10px; }
                \\  </style>
                \\</head>
                \\<body>
                \\  <h1>Zylix Test Report</h1>
                \\
            );

            for (self.results.items) |suite_result| {
                try writer.print("  <div class=\"suite\">\n    <h2>{s}</h2>\n", .{suite_result.name});

                for (suite_result.tests.items) |test_result| {
                    const class = switch (test_result.status) {
                        .passed => "passed",
                        .failed, .error_, .timeout => "failed",
                        .skipped => "skipped",
                    };

                    try writer.print("    <div class=\"test {s}\">{s} ({d}ms)</div>\n", .{
                        class,
                        test_result.name,
                        test_result.duration_ms,
                    });
                }

                try writer.writeAll("  </div>\n");
            }

            try writer.writeAll("</body>\n</html>\n");
        }
    }
};

// Tests
test "test runner creation" {
    var runner = TestRunner.init(std.testing.allocator, .{});
    defer runner.deinit();
    try std.testing.expect(runner.suites.items.len == 0);
}
