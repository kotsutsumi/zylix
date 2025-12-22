//! Zylix Test Framework - End-to-End Tests
//!
//! Tests communication with actual bridge servers (not mock).
//! These tests require running bridge servers and are skipped when unavailable.
//!
//! Compatible with Zig 0.15.
//!
//! ## Running E2E Tests
//! ```bash
//! # Start bridge servers first, then:
//! cd core
//! zig build test-e2e
//! ```

const std = @import("std");

// Import E2E test modules
pub const web = @import("web_e2e_test.zig");
pub const ios = @import("ios_e2e_test.zig");
pub const android = @import("android_e2e_test.zig");
pub const desktop = @import("desktop_e2e_test.zig");

/// E2E test configuration
pub const E2EConfig = struct {
    /// Skip tests when server is unavailable
    skip_unavailable: bool = true,
    /// Connection timeout (ms)
    connection_timeout_ms: u32 = 5000,
    /// Command timeout (ms)
    command_timeout_ms: u32 = 30000,
    /// Retry count for flaky operations
    retry_count: u8 = 3,
    /// Verbose logging
    verbose: bool = false,
};

/// Production port configuration for E2E tests
pub const ProductionPorts = struct {
    pub const web: u16 = 9515; // ChromeDriver/Playwright
    pub const ios: u16 = 8100; // WebDriverAgent
    pub const android: u16 = 4723; // Appium/UIAutomator2
    pub const macos: u16 = 8200; // Accessibility bridge
    pub const linux: u16 = 8300; // AT-SPI bridge
    pub const windows: u16 = 4723; // WinAppDriver
};

/// Check if a server is available at the given address
pub fn isServerAvailable(host: []const u8, port: u16, timeout_ms: u32) bool {
    _ = timeout_ms; // timeout not directly supported in Zig 0.15 std.net
    const address = std.net.Address.parseIp4(host, port) catch return false;

    const stream = std.net.tcpConnectToAddress(address) catch return false;
    stream.close();

    return true;
}

/// Send HTTP request and get response
pub fn sendHttpRequest(
    allocator: std.mem.Allocator,
    host: []const u8,
    port: u16,
    method: []const u8,
    path: []const u8,
    body: ?[]const u8,
) ![]u8 {
    const address = std.net.Address.parseIp4(host, port) catch return error.InvalidAddress;
    const stream = try std.net.tcpConnectToAddress(address);
    defer stream.close();

    // Build request
    var request_buf: [4096]u8 = undefined;
    const content_length = if (body) |b| b.len else 0;

    const request = try std.fmt.bufPrint(&request_buf,
        "{s} {s} HTTP/1.1\r\n" ++
        "Host: {s}:{d}\r\n" ++
        "Content-Type: application/json\r\n" ++
        "Content-Length: {d}\r\n" ++
        "Connection: close\r\n" ++
        "\r\n",
        .{ method, path, host, port, content_length }
    );

    _ = try stream.write(request);
    if (body) |b| {
        _ = try stream.write(b);
    }

    // Read response
    var response_buf: std.ArrayListUnmanaged(u8) = .{};
    defer response_buf.deinit(allocator);

    var buf: [4096]u8 = undefined;
    while (true) {
        const bytes = stream.read(&buf) catch |err| {
            if (err == error.WouldBlock) break;
            return err;
        };
        if (bytes == 0) break;
        try response_buf.appendSlice(allocator, buf[0..bytes]);
    }

    return response_buf.toOwnedSlice(allocator);
}

/// Parse JSON response for session ID
pub fn parseSessionId(response: []const u8) ?[]const u8 {
    // Simple parser for {"sessionId":"xxx"} or {"value":{"sessionId":"xxx"}}
    const session_key = "\"sessionId\":\"";
    if (std.mem.indexOf(u8, response, session_key)) |start| {
        const id_start = start + session_key.len;
        if (std.mem.indexOfPos(u8, response, id_start, "\"")) |end| {
            return response[id_start..end];
        }
    }
    return null;
}

/// Parse JSON response for status code
pub fn parseStatus(response: []const u8) ?i32 {
    const status_key = "\"status\":";
    if (std.mem.indexOf(u8, response, status_key)) |start| {
        const val_start = start + status_key.len;
        // Skip whitespace
        var i = val_start;
        while (i < response.len and (response[i] == ' ' or response[i] == '\t')) : (i += 1) {}
        // Parse number
        var end = i;
        while (end < response.len and (response[end] >= '0' and response[end] <= '9')) : (end += 1) {}
        if (end > i) {
            return std.fmt.parseInt(i32, response[i..end], 10) catch null;
        }
    }
    return null;
}

/// Test result structure
pub const TestResult = struct {
    name: []const u8,
    passed: bool,
    skipped: bool,
    duration_ms: u64,
    error_message: ?[]const u8,
};

/// E2E test runner
pub const E2ERunner = struct {
    allocator: std.mem.Allocator,
    config: E2EConfig,
    results: std.ArrayList(TestResult),

    pub fn init(allocator: std.mem.Allocator, config: E2EConfig) E2ERunner {
        return .{
            .allocator = allocator,
            .config = config,
            .results = std.ArrayList(TestResult).init(allocator),
        };
    }

    pub fn deinit(self: *E2ERunner) void {
        self.results.deinit();
    }

    pub fn addResult(self: *E2ERunner, result: TestResult) !void {
        try self.results.append(result);
    }

    pub fn printSummary(self: *E2ERunner) void {
        var passed: usize = 0;
        var failed: usize = 0;
        var skipped: usize = 0;

        std.debug.print("\n=== E2E Test Summary ===\n", .{});

        for (self.results.items) |result| {
            if (result.skipped) {
                skipped += 1;
                std.debug.print("⏭️  SKIP: {s}\n", .{result.name});
            } else if (result.passed) {
                passed += 1;
                std.debug.print("✅ PASS: {s} ({d}ms)\n", .{result.name, result.duration_ms});
            } else {
                failed += 1;
                std.debug.print("❌ FAIL: {s} - {s}\n", .{result.name, result.error_message orelse "unknown error"});
            }
        }

        std.debug.print("\nTotal: {d} | Passed: {d} | Failed: {d} | Skipped: {d}\n", .{
            self.results.items.len, passed, failed, skipped
        });
    }
};

// Compile-time test aggregation
comptime {
    _ = web;
    _ = ios;
    _ = android;
    _ = desktop;
}

test "e2e test module loads" {
    try std.testing.expect(@TypeOf(E2EConfig) != void);
    try std.testing.expect(@TypeOf(E2ERunner) != void);
}

test "production ports are correct" {
    try std.testing.expectEqual(@as(u16, 9515), ProductionPorts.web);
    try std.testing.expectEqual(@as(u16, 8100), ProductionPorts.ios);
    try std.testing.expectEqual(@as(u16, 4723), ProductionPorts.android);
}

test "server availability check" {
    // This should return false for a non-existent server
    const available = isServerAvailable("127.0.0.1", 59999, 100);
    try std.testing.expect(!available);
}
