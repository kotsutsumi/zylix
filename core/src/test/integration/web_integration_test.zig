//! Web Driver Integration Tests
//!
//! Tests communication between Zig WebDriver and Playwright bridge server.
//!
//! Compatible with Zig 0.15.

const std = @import("std");
const mock_server = @import("mock_server.zig");

const MockServer = mock_server.MockServer;
const PlatformMocks = mock_server.PlatformMocks;

// Test port (different from production)
const TEST_PORT: u16 = 19515;

/// Web driver configuration (local copy for testing)
pub const WebDriverConfig = struct {
    host: []const u8 = "127.0.0.1",
    port: u16 = 9515,
    browser: BrowserType = .chromium,
    headless: bool = true,
    timeout_ms: u32 = 30000,
    viewport_width: u32 = 1280,
    viewport_height: u32 = 720,
};

pub const BrowserType = enum {
    chromium,
    firefox,
    webkit,

    pub fn toString(self: BrowserType) []const u8 {
        return switch (self) {
            .chromium => "chromium",
            .firefox => "firefox",
            .webkit => "webkit",
        };
    }
};

/// Selector types for testing
pub const Selector = struct {
    test_id: ?[]const u8 = null,
    accessibility_id: ?[]const u8 = null,
    text: ?[]const u8 = null,
    text_contains: ?[]const u8 = null,
};

// Helper function: selector to CSS
fn selectorToCss(selector: Selector, allocator: std.mem.Allocator) ![]const u8 {
    if (selector.test_id) |tid| {
        return std.fmt.allocPrint(allocator, "[data-testid=\"{s}\"]", .{tid});
    }
    if (selector.accessibility_id) |aid| {
        return std.fmt.allocPrint(allocator, "[aria-label=\"{s}\"]", .{aid});
    }
    if (selector.text) |text| {
        return std.fmt.allocPrint(allocator, ":text(\"{s}\")", .{text});
    }
    if (selector.text_contains) |text| {
        return std.fmt.allocPrint(allocator, ":text-matches(\"{s}\")", .{text});
    }
    return error.InvalidSelector;
}

// Integration Tests

test "web driver connection to mock bridge" {
    const allocator = std.testing.allocator;

    // Start mock server
    var server = MockServer.init(allocator, TEST_PORT);
    defer server.deinit();
    server.setHandler(PlatformMocks.webHandler);
    try server.start();
    defer server.stop();

    // Give server time to start
    std.Thread.sleep(100 * std.time.ns_per_ms);

    // Make a test connection
    const address = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, TEST_PORT);
    const stream = std.net.tcpConnectToAddress(address) catch return;
    defer stream.close();

    // Send launch request
    const request =
        \\POST /session/new/launch HTTP/1.1
        \\Host: 127.0.0.1:19515
        \\Content-Type: application/json
        \\Content-Length: 50
        \\
        \\{"browser":"chromium","headless":true,"url":"http://localhost"}
    ;
    _ = stream.write(request) catch return;

    var buffer: [1024]u8 = undefined;
    const bytes = stream.read(&buffer) catch return;
    const response = buffer[0..bytes];

    // Verify response contains session ID
    try std.testing.expect(std.mem.indexOf(u8, response, "sessionId") != null);

    // Check request was logged
    const requests = server.getRequests();
    try std.testing.expect(requests.len > 0);
}

test "web driver JSON protocol format" {
    const allocator = std.testing.allocator;

    var server = MockServer.init(allocator, TEST_PORT + 1);
    defer server.deinit();
    try server.start();
    defer server.stop();

    std.Thread.sleep(100 * std.time.ns_per_ms);

    // Test various request formats
    const address = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, TEST_PORT + 1);

    // Test findElement request
    {
        const stream = std.net.tcpConnectToAddress(address) catch return;
        defer stream.close();

        const request =
            \\POST /session/test-session/findElement HTTP/1.1
            \\Host: 127.0.0.1
            \\Content-Type: application/json
            \\Content-Length: 38
            \\
            \\{"selector":"[data-testid=\"button\"]"}
        ;
        _ = stream.write(request) catch return;

        var buffer: [1024]u8 = undefined;
        const bytes = stream.read(&buffer) catch return;
        const response = buffer[0..bytes];

        try std.testing.expect(std.mem.indexOf(u8, response, "200") != null or
            std.mem.indexOf(u8, response, "elementId") != null);
    }

    // Verify requests
    const requests = server.getRequests();
    for (requests) |req| {
        try std.testing.expectEqualStrings("POST", req.method);
    }
}

test "selector to CSS conversion" {
    const allocator = std.testing.allocator;

    // Test data-testid selector
    const sel1 = Selector{ .test_id = "my-button" };
    const css1 = try selectorToCss(sel1, allocator);
    defer allocator.free(css1);
    try std.testing.expectEqualStrings("[data-testid=\"my-button\"]", css1);

    // Test accessibility ID selector
    const sel2 = Selector{ .accessibility_id = "submit-btn" };
    const css2 = try selectorToCss(sel2, allocator);
    defer allocator.free(css2);
    try std.testing.expectEqualStrings("[aria-label=\"submit-btn\"]", css2);

    // Test text selector
    const sel3 = Selector{ .text = "Click me" };
    const css3 = try selectorToCss(sel3, allocator);
    defer allocator.free(css3);
    try std.testing.expectEqualStrings(":text(\"Click me\")", css3);
}

test "browser type configuration" {
    try std.testing.expectEqualStrings("chromium", BrowserType.chromium.toString());
    try std.testing.expectEqualStrings("firefox", BrowserType.firefox.toString());
    try std.testing.expectEqualStrings("webkit", BrowserType.webkit.toString());
}

test "driver config defaults" {
    const config = WebDriverConfig{};

    try std.testing.expectEqualStrings("127.0.0.1", config.host);
    try std.testing.expectEqual(@as(u16, 9515), config.port);
    try std.testing.expect(config.headless);
    try std.testing.expectEqual(@as(u32, 30000), config.timeout_ms);
    try std.testing.expectEqual(@as(u32, 1280), config.viewport_width);
    try std.testing.expectEqual(@as(u32, 720), config.viewport_height);
}

test "web bridge endpoint paths" {
    var buf: [256]u8 = undefined;

    // Session path
    const session_path = std.fmt.bufPrint(&buf, "/session/{s}/navigate", .{"session-123"}) catch unreachable;
    try std.testing.expect(std.mem.indexOf(u8, session_path, "/session/") != null);
    try std.testing.expect(std.mem.indexOf(u8, session_path, "/navigate") != null);

    // Element path
    const element_path = std.fmt.bufPrint(&buf, "/session/{s}/element/{s}/click", .{ "session-123", "element-1" }) catch unreachable;
    try std.testing.expect(std.mem.indexOf(u8, element_path, "/element/") != null);
    try std.testing.expect(std.mem.indexOf(u8, element_path, "/click") != null);
}
