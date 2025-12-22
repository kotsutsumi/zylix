// Zylix Test Framework - Test Reporter System
// Unified reporting for multiple output formats

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Test result status
pub const TestStatus = enum {
    passed,
    failed,
    skipped,
    error_,

    pub fn toString(self: TestStatus) []const u8 {
        return switch (self) {
            .passed => "passed",
            .failed => "failed",
            .skipped => "skipped",
            .error_ => "error",
        };
    }
};

/// Individual test result
pub const TestResult = struct {
    name: []const u8,
    suite: []const u8,
    status: TestStatus,
    duration_ms: u64,
    message: ?[]const u8 = null,
    stack_trace: ?[]const u8 = null,
    stdout: ?[]const u8 = null,
    stderr: ?[]const u8 = null,
    screenshot_path: ?[]const u8 = null,
    timestamp: i64,

    pub fn init(name: []const u8, suite: []const u8) TestResult {
        return .{
            .name = name,
            .suite = suite,
            .status = .passed,
            .duration_ms = 0,
            .timestamp = std.time.timestamp(),
        };
    }
};

/// Test suite summary
pub const SuiteSummary = struct {
    name: []const u8,
    total: u32,
    passed: u32,
    failed: u32,
    skipped: u32,
    errors: u32,
    duration_ms: u64,
    timestamp: i64,

    pub fn init(name: []const u8) SuiteSummary {
        return .{
            .name = name,
            .total = 0,
            .passed = 0,
            .failed = 0,
            .skipped = 0,
            .errors = 0,
            .duration_ms = 0,
            .timestamp = std.time.timestamp(),
        };
    }

    pub fn addResult(self: *SuiteSummary, result: TestResult) void {
        self.total += 1;
        self.duration_ms += result.duration_ms;
        switch (result.status) {
            .passed => self.passed += 1,
            .failed => self.failed += 1,
            .skipped => self.skipped += 1,
            .error_ => self.errors += 1,
        }
    }

    pub fn successRate(self: SuiteSummary) f64 {
        if (self.total == 0) return 0;
        return @as(f64, @floatFromInt(self.passed)) / @as(f64, @floatFromInt(self.total)) * 100.0;
    }
};

/// Report format
pub const ReportFormat = enum {
    junit,
    html,
    json,
    markdown,
    console,
};

/// Reporter configuration
pub const ReporterConfig = struct {
    output_dir: []const u8 = "test-results",
    formats: []const ReportFormat = &[_]ReportFormat{ .junit, .html, .json },
    include_stdout: bool = true,
    include_screenshots: bool = true,
    timestamp_format: []const u8 = "%Y-%m-%d_%H-%M-%S",
};

/// Test reporter manager
pub const Reporter = struct {
    allocator: Allocator,
    config: ReporterConfig,
    results: std.ArrayList(TestResult),
    suites: std.StringHashMap(SuiteSummary),
    start_time: i64,

    const Self = @This();

    pub fn init(allocator: Allocator, config: ReporterConfig) Self {
        return .{
            .allocator = allocator,
            .config = config,
            .results = std.ArrayList(TestResult).init(allocator),
            .suites = std.StringHashMap(SuiteSummary).init(allocator),
            .start_time = std.time.timestamp(),
        };
    }

    pub fn deinit(self: *Self) void {
        self.results.deinit();
        self.suites.deinit();
    }

    /// Add a test result
    pub fn addResult(self: *Self, result: TestResult) !void {
        try self.results.append(result);

        // Update suite summary
        const entry = try self.suites.getOrPut(result.suite);
        if (!entry.found_existing) {
            entry.value_ptr.* = SuiteSummary.init(result.suite);
        }
        entry.value_ptr.addResult(result);
    }

    /// Get overall summary
    pub fn getSummary(self: *Self) SuiteSummary {
        var summary = SuiteSummary.init("All Tests");
        summary.timestamp = self.start_time;

        for (self.results.items) |result| {
            summary.addResult(result);
        }

        return summary;
    }

    /// Generate all configured reports
    pub fn generateReports(self: *Self) !void {
        // Create output directory
        std.fs.cwd().makePath(self.config.output_dir) catch {};

        for (self.config.formats) |format| {
            switch (format) {
                .junit => try self.generateJUnit(),
                .html => try self.generateHTML(),
                .json => try self.generateJSON(),
                .markdown => try self.generateMarkdown(),
                .console => self.printConsole(),
            }
        }
    }

    /// Generate JUnit XML report
    pub fn generateJUnit(self: *Self) !void {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/junit-report.xml",
            .{self.config.output_dir},
        );
        defer self.allocator.free(path);

        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        const writer = file.writer();

        try writer.writeAll("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");

        const summary = self.getSummary();
        try writer.print(
            "<testsuites tests=\"{d}\" failures=\"{d}\" errors=\"{d}\" skipped=\"{d}\" time=\"{d:.3}\">\n",
            .{
                summary.total,
                summary.failed,
                summary.errors,
                summary.skipped,
                @as(f64, @floatFromInt(summary.duration_ms)) / 1000.0,
            },
        );

        // Group by suite
        var suite_iter = self.suites.iterator();
        while (suite_iter.next()) |entry| {
            const suite = entry.value_ptr.*;
            try writer.print(
                "  <testsuite name=\"{s}\" tests=\"{d}\" failures=\"{d}\" errors=\"{d}\" skipped=\"{d}\" time=\"{d:.3}\">\n",
                .{
                    suite.name,
                    suite.total,
                    suite.failed,
                    suite.errors,
                    suite.skipped,
                    @as(f64, @floatFromInt(suite.duration_ms)) / 1000.0,
                },
            );

            // Write test cases for this suite
            for (self.results.items) |result| {
                if (!std.mem.eql(u8, result.suite, suite.name)) continue;

                try writer.print(
                    "    <testcase name=\"{s}\" classname=\"{s}\" time=\"{d:.3}\"",
                    .{
                        result.name,
                        result.suite,
                        @as(f64, @floatFromInt(result.duration_ms)) / 1000.0,
                    },
                );

                switch (result.status) {
                    .passed => try writer.writeAll(" />\n"),
                    .failed => {
                        try writer.writeAll(">\n");
                        try writer.print("      <failure message=\"{s}\"", .{result.message orelse "Test failed"});
                        if (result.stack_trace) |trace| {
                            try writer.print(">{s}</failure>\n", .{trace});
                        } else {
                            try writer.writeAll(" />\n");
                        }
                        try writer.writeAll("    </testcase>\n");
                    },
                    .skipped => {
                        try writer.writeAll(">\n      <skipped />\n    </testcase>\n");
                    },
                    .error_ => {
                        try writer.writeAll(">\n");
                        try writer.print("      <error message=\"{s}\"", .{result.message orelse "Test error"});
                        if (result.stack_trace) |trace| {
                            try writer.print(">{s}</error>\n", .{trace});
                        } else {
                            try writer.writeAll(" />\n");
                        }
                        try writer.writeAll("    </testcase>\n");
                    },
                }
            }

            try writer.writeAll("  </testsuite>\n");
        }

        try writer.writeAll("</testsuites>\n");
    }

    /// Generate HTML report
    pub fn generateHTML(self: *Self) !void {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/report.html",
            .{self.config.output_dir},
        );
        defer self.allocator.free(path);

        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        const writer = file.writer();
        const summary = self.getSummary();

        try writer.writeAll(
            \\<!DOCTYPE html>
            \\<html lang="en">
            \\<head>
            \\  <meta charset="UTF-8">
            \\  <meta name="viewport" content="width=device-width, initial-scale=1.0">
            \\  <title>Zylix Test Report</title>
            \\  <style>
            \\    * { box-sizing: border-box; margin: 0; padding: 0; }
            \\    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f5f5f5; padding: 20px; }
            \\    .container { max-width: 1200px; margin: 0 auto; }
            \\    .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 10px; margin-bottom: 20px; }
            \\    .header h1 { font-size: 2em; margin-bottom: 10px; }
            \\    .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 15px; margin-bottom: 20px; }
            \\    .stat { background: white; padding: 20px; border-radius: 8px; text-align: center; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
            \\    .stat-value { font-size: 2em; font-weight: bold; }
            \\    .stat-label { color: #666; font-size: 0.9em; }
            \\    .passed { color: #22c55e; }
            \\    .failed { color: #ef4444; }
            \\    .skipped { color: #f59e0b; }
            \\    .error { color: #dc2626; }
            \\    .suite { background: white; border-radius: 8px; margin-bottom: 15px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
            \\    .suite-header { padding: 15px 20px; background: #f8f9fa; border-bottom: 1px solid #eee; font-weight: 600; display: flex; justify-content: space-between; }
            \\    .test { padding: 12px 20px; border-bottom: 1px solid #f0f0f0; display: flex; align-items: center; gap: 10px; }
            \\    .test:last-child { border-bottom: none; }
            \\    .test-status { width: 10px; height: 10px; border-radius: 50%; }
            \\    .test-status.passed { background: #22c55e; }
            \\    .test-status.failed { background: #ef4444; }
            \\    .test-status.skipped { background: #f59e0b; }
            \\    .test-status.error { background: #dc2626; }
            \\    .test-name { flex: 1; }
            \\    .test-duration { color: #999; font-size: 0.9em; }
            \\    .progress-bar { height: 8px; background: #e5e7eb; border-radius: 4px; overflow: hidden; margin-top: 10px; }
            \\    .progress-fill { height: 100%; background: #22c55e; }
            \\  </style>
            \\</head>
            \\<body>
            \\  <div class="container">
            \\    <div class="header">
            \\      <h1>Zylix Test Report</h1>
            \\
        );

        try writer.print(
            \\      <p>Generated: {d} | Duration: {d:.2}s</p>
        ,
            .{ summary.timestamp, @as(f64, @floatFromInt(summary.duration_ms)) / 1000.0 },
        );

        try writer.print(
            \\      <div class="progress-bar"><div class="progress-fill" style="width: {d:.1}%"></div></div>
            \\    </div>
            \\    <div class="summary">
            \\      <div class="stat"><div class="stat-value">{d}</div><div class="stat-label">Total</div></div>
            \\      <div class="stat"><div class="stat-value passed">{d}</div><div class="stat-label">Passed</div></div>
            \\      <div class="stat"><div class="stat-value failed">{d}</div><div class="stat-label">Failed</div></div>
            \\      <div class="stat"><div class="stat-value skipped">{d}</div><div class="stat-label">Skipped</div></div>
            \\      <div class="stat"><div class="stat-value">{d:.1}%</div><div class="stat-label">Success Rate</div></div>
            \\    </div>
            \\
        ,
            .{
                summary.successRate(),
                summary.total,
                summary.passed,
                summary.failed,
                summary.skipped,
                summary.successRate(),
            },
        );

        // Suites
        var suite_iter = self.suites.iterator();
        while (suite_iter.next()) |entry| {
            const suite = entry.value_ptr.*;
            try writer.print(
                \\    <div class="suite">
                \\      <div class="suite-header">
                \\        <span>{s}</span>
                \\        <span>{d}/{d} passed</span>
                \\      </div>
                \\
            ,
                .{ suite.name, suite.passed, suite.total },
            );

            for (self.results.items) |result| {
                if (!std.mem.eql(u8, result.suite, suite.name)) continue;

                try writer.print(
                    \\      <div class="test">
                    \\        <div class="test-status {s}"></div>
                    \\        <div class="test-name">{s}</div>
                    \\        <div class="test-duration">{d}ms</div>
                    \\      </div>
                    \\
                ,
                    .{ result.status.toString(), result.name, result.duration_ms },
                );
            }

            try writer.writeAll("    </div>\n");
        }

        try writer.writeAll(
            \\  </div>
            \\</body>
            \\</html>
            \\
        );
    }

    /// Generate JSON report
    pub fn generateJSON(self: *Self) !void {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/report.json",
            .{self.config.output_dir},
        );
        defer self.allocator.free(path);

        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        const writer = file.writer();
        const summary = self.getSummary();

        try writer.writeAll("{\n");
        try writer.print("  \"timestamp\": {d},\n", .{summary.timestamp});
        try writer.print("  \"duration_ms\": {d},\n", .{summary.duration_ms});
        try writer.writeAll("  \"summary\": {\n");
        try writer.print("    \"total\": {d},\n", .{summary.total});
        try writer.print("    \"passed\": {d},\n", .{summary.passed});
        try writer.print("    \"failed\": {d},\n", .{summary.failed});
        try writer.print("    \"skipped\": {d},\n", .{summary.skipped});
        try writer.print("    \"errors\": {d},\n", .{summary.errors});
        try writer.print("    \"success_rate\": {d:.2}\n", .{summary.successRate()});
        try writer.writeAll("  },\n");

        try writer.writeAll("  \"suites\": [\n");

        var suite_iter = self.suites.iterator();
        var first_suite = true;
        while (suite_iter.next()) |entry| {
            if (!first_suite) try writer.writeAll(",\n");
            first_suite = false;

            const suite = entry.value_ptr.*;
            try writer.writeAll("    {\n");
            try writer.print("      \"name\": \"{s}\",\n", .{suite.name});
            try writer.print("      \"total\": {d},\n", .{suite.total});
            try writer.print("      \"passed\": {d},\n", .{suite.passed});
            try writer.print("      \"failed\": {d},\n", .{suite.failed});
            try writer.writeAll("      \"tests\": [\n");

            var first_test = true;
            for (self.results.items) |result| {
                if (!std.mem.eql(u8, result.suite, suite.name)) continue;

                if (!first_test) try writer.writeAll(",\n");
                first_test = false;

                try writer.writeAll("        {\n");
                try writer.print("          \"name\": \"{s}\",\n", .{result.name});
                try writer.print("          \"status\": \"{s}\",\n", .{result.status.toString()});
                try writer.print("          \"duration_ms\": {d}", .{result.duration_ms});

                if (result.message) |msg| {
                    try writer.print(",\n          \"message\": \"{s}\"", .{msg});
                }

                try writer.writeAll("\n        }");
            }

            try writer.writeAll("\n      ]\n    }");
        }

        try writer.writeAll("\n  ],\n");
        try writer.writeAll("  \"results\": [\n");

        for (self.results.items, 0..) |result, i| {
            if (i > 0) try writer.writeAll(",\n");
            try writer.writeAll("    {\n");
            try writer.print("      \"name\": \"{s}\",\n", .{result.name});
            try writer.print("      \"suite\": \"{s}\",\n", .{result.suite});
            try writer.print("      \"status\": \"{s}\",\n", .{result.status.toString()});
            try writer.print("      \"duration_ms\": {d},\n", .{result.duration_ms});
            try writer.print("      \"timestamp\": {d}", .{result.timestamp});
            if (result.message) |msg| {
                try writer.print(",\n      \"message\": \"{s}\"", .{msg});
            }
            try writer.writeAll("\n    }");
        }

        try writer.writeAll("\n  ]\n}\n");
    }

    /// Generate Markdown report
    pub fn generateMarkdown(self: *Self) !void {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/report.md",
            .{self.config.output_dir},
        );
        defer self.allocator.free(path);

        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        const writer = file.writer();
        const summary = self.getSummary();

        try writer.writeAll("# Zylix Test Report\n\n");
        try writer.writeAll("## Summary\n\n");
        try writer.writeAll("| Metric | Value |\n");
        try writer.writeAll("|--------|-------|\n");
        try writer.print("| Total Tests | {d} |\n", .{summary.total});
        try writer.print("| Passed | {d} |\n", .{summary.passed});
        try writer.print("| Failed | {d} |\n", .{summary.failed});
        try writer.print("| Skipped | {d} |\n", .{summary.skipped});
        try writer.print("| Success Rate | {d:.1}% |\n", .{summary.successRate()});
        try writer.print("| Duration | {d:.2}s |\n\n", .{@as(f64, @floatFromInt(summary.duration_ms)) / 1000.0});

        try writer.writeAll("## Test Results\n\n");

        var suite_iter = self.suites.iterator();
        while (suite_iter.next()) |entry| {
            const suite = entry.value_ptr.*;
            try writer.print("### {s}\n\n", .{suite.name});
            try writer.writeAll("| Test | Status | Duration |\n");
            try writer.writeAll("|------|--------|----------|\n");

            for (self.results.items) |result| {
                if (!std.mem.eql(u8, result.suite, suite.name)) continue;

                const status_emoji = switch (result.status) {
                    .passed => "✅",
                    .failed => "❌",
                    .skipped => "⏭️",
                    .error_ => "💥",
                };

                try writer.print("| {s} | {s} {s} | {d}ms |\n", .{
                    result.name,
                    status_emoji,
                    result.status.toString(),
                    result.duration_ms,
                });
            }
            try writer.writeAll("\n");
        }
    }

    /// Print console report
    pub fn printConsole(self: *Self) void {
        const summary = self.getSummary();

        std.debug.print("\n", .{});
        std.debug.print("╔════════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║                     Zylix Test Report                          ║\n", .{});
        std.debug.print("╠════════════════════════════════════════════════════════════════╣\n", .{});
        std.debug.print("║  Total: {d:<6}  Passed: {d:<6}  Failed: {d:<6}  Skipped: {d:<6} ║\n", .{
            summary.total,
            summary.passed,
            summary.failed,
            summary.skipped,
        });
        std.debug.print("║  Success Rate: {d:.1}%                Duration: {d:.2}s            ║\n", .{
            summary.successRate(),
            @as(f64, @floatFromInt(summary.duration_ms)) / 1000.0,
        });
        std.debug.print("╚════════════════════════════════════════════════════════════════╝\n", .{});
        std.debug.print("\n", .{});

        for (self.results.items) |result| {
            const status_icon = switch (result.status) {
                .passed => "✓",
                .failed => "✗",
                .skipped => "○",
                .error_ => "!",
            };
            std.debug.print("  {s} {s}::{s} ({d}ms)\n", .{
                status_icon,
                result.suite,
                result.name,
                result.duration_ms,
            });

            if (result.message) |msg| {
                std.debug.print("    └─ {s}\n", .{msg});
            }
        }
        std.debug.print("\n", .{});
    }
};

// Tests
test "Reporter initialization" {
    const allocator = std.testing.allocator;
    var reporter = Reporter.init(allocator, .{});
    defer reporter.deinit();

    try std.testing.expectEqual(@as(usize, 0), reporter.results.items.len);
}

test "Reporter add results" {
    const allocator = std.testing.allocator;
    var reporter = Reporter.init(allocator, .{});
    defer reporter.deinit();

    try reporter.addResult(.{
        .name = "test1",
        .suite = "suite1",
        .status = .passed,
        .duration_ms = 100,
        .timestamp = 0,
    });

    try reporter.addResult(.{
        .name = "test2",
        .suite = "suite1",
        .status = .failed,
        .duration_ms = 200,
        .message = "assertion failed",
        .timestamp = 0,
    });

    const summary = reporter.getSummary();
    try std.testing.expectEqual(@as(u32, 2), summary.total);
    try std.testing.expectEqual(@as(u32, 1), summary.passed);
    try std.testing.expectEqual(@as(u32, 1), summary.failed);
}

test "SuiteSummary success rate" {
    var summary = SuiteSummary.init("test");
    summary.total = 10;
    summary.passed = 8;
    summary.failed = 2;

    try std.testing.expectApproxEqAbs(@as(f64, 80.0), summary.successRate(), 0.01);
}

test "TestStatus toString" {
    try std.testing.expectEqualStrings("passed", TestStatus.passed.toString());
    try std.testing.expectEqualStrings("failed", TestStatus.failed.toString());
    try std.testing.expectEqualStrings("skipped", TestStatus.skipped.toString());
}
