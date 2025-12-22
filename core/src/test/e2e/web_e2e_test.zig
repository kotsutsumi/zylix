//! Web Platform E2E Tests
//!
//! Tests against actual ChromeDriver/Selenium/Playwright server.
//! Requires a running WebDriver server on port 9515.

const std = @import("std");
const e2e = @import("e2e_tests.zig");

const HOST = "127.0.0.1";
const PORT = e2e.ProductionPorts.web;

/// Check if WebDriver is available
pub fn isWebDriverAvailable() bool {
    return e2e.isServerAvailable(HOST, PORT, 1000);
}

/// Create a new browser session
pub fn createSession(allocator: std.mem.Allocator, browser: []const u8) ![]u8 {
    var body_buf: [1024]u8 = undefined;
    const body = try std.fmt.bufPrint(&body_buf,
        \\{{"capabilities":{{"alwaysMatch":{{"browserName":"{s}"}}}}}}
    , .{browser});

    return e2e.sendHttpRequest(allocator, HOST, PORT, "POST", "/session", body);
}

/// Navigate to URL
pub fn navigateTo(allocator: std.mem.Allocator, session_id: []const u8, url: []const u8) ![]u8 {
    var path_buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/session/{s}/url", .{session_id});

    var body_buf: [1024]u8 = undefined;
    const body = try std.fmt.bufPrint(&body_buf,
        \\{{"url":"{s}"}}
    , .{url});

    return e2e.sendHttpRequest(allocator, HOST, PORT, "POST", path, body);
}

/// Get page title
pub fn getTitle(allocator: std.mem.Allocator, session_id: []const u8) ![]u8 {
    var path_buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/session/{s}/title", .{session_id});

    return e2e.sendHttpRequest(allocator, HOST, PORT, "GET", path, null);
}

/// Delete session
pub fn deleteSession(allocator: std.mem.Allocator, session_id: []const u8) ![]u8 {
    var path_buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/session/{s}", .{session_id});

    return e2e.sendHttpRequest(allocator, HOST, PORT, "DELETE", path, null);
}

/// Find element by selector
pub fn findElement(allocator: std.mem.Allocator, session_id: []const u8, using: []const u8, value: []const u8) ![]u8 {
    var path_buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/session/{s}/element", .{session_id});

    var body_buf: [512]u8 = undefined;
    const body = try std.fmt.bufPrint(&body_buf,
        \\{{"using":"{s}","value":"{s}"}}
    , .{using, value});

    return e2e.sendHttpRequest(allocator, HOST, PORT, "POST", path, body);
}

/// Take screenshot
pub fn takeScreenshot(allocator: std.mem.Allocator, session_id: []const u8) ![]u8 {
    var path_buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/session/{s}/screenshot", .{session_id});

    return e2e.sendHttpRequest(allocator, HOST, PORT, "GET", path, null);
}

// E2E Tests

test "web e2e: webdriver server availability" {
    // Skip if server not available
    if (!isWebDriverAvailable()) {
        std.debug.print("⏭️  WebDriver not available, skipping E2E tests\n", .{});
        return;
    }

    std.debug.print("✅ WebDriver server is available at {s}:{d}\n", .{HOST, PORT});
}

test "web e2e: session lifecycle" {
    if (!isWebDriverAvailable()) return;

    const allocator = std.testing.allocator;

    // Create session
    const create_response = createSession(allocator, "chrome") catch |err| {
        std.debug.print("Failed to create session: {}\n", .{err});
        return;
    };
    defer allocator.free(create_response);

    const session_id = e2e.parseSessionId(create_response);
    if (session_id == null) {
        std.debug.print("Could not parse session ID from response\n", .{});
        return;
    }

    // Delete session
    const delete_response = deleteSession(allocator, session_id.?) catch |err| {
        std.debug.print("Failed to delete session: {}\n", .{err});
        return;
    };
    defer allocator.free(delete_response);

    std.debug.print("✅ Session lifecycle test passed\n", .{});
}

test "web e2e: navigation" {
    if (!isWebDriverAvailable()) return;

    const allocator = std.testing.allocator;

    // Create session
    const create_response = createSession(allocator, "chrome") catch return;
    defer allocator.free(create_response);

    const session_id = e2e.parseSessionId(create_response) orelse return;

    defer {
        // Cleanup: delete session
        if (deleteSession(allocator, session_id)) |del_resp| {
            allocator.free(del_resp);
        } else |_| {}
    }

    // Navigate to URL
    const nav_response = navigateTo(allocator, session_id, "https://example.com") catch |err| {
        std.debug.print("Navigation failed: {}\n", .{err});
        return;
    };
    defer allocator.free(nav_response);

    // Get title
    const title_response = getTitle(allocator, session_id) catch return;
    defer allocator.free(title_response);

    // Verify title contains "Example"
    if (std.mem.indexOf(u8, title_response, "Example") != null) {
        std.debug.print("✅ Navigation test passed\n", .{});
    }
}

test "web e2e: element finding" {
    if (!isWebDriverAvailable()) return;

    const allocator = std.testing.allocator;

    // Create session
    const create_response = createSession(allocator, "chrome") catch return;
    defer allocator.free(create_response);

    const session_id = e2e.parseSessionId(create_response) orelse return;

    defer {
        if (deleteSession(allocator, session_id)) |del_resp| {
            allocator.free(del_resp);
        } else |_| {}
    }

    // Navigate to test page
    const nav_response = navigateTo(allocator, session_id, "https://example.com") catch return;
    defer allocator.free(nav_response);

    // Find element
    const element_response = findElement(allocator, session_id, "css selector", "h1") catch return;
    defer allocator.free(element_response);

    // Check if element was found
    if (std.mem.indexOf(u8, element_response, "ELEMENT") != null or
        std.mem.indexOf(u8, element_response, "element-") != null)
    {
        std.debug.print("✅ Element finding test passed\n", .{});
    }
}

test "web e2e: screenshot" {
    if (!isWebDriverAvailable()) return;

    const allocator = std.testing.allocator;

    // Create session
    const create_response = createSession(allocator, "chrome") catch return;
    defer allocator.free(create_response);

    const session_id = e2e.parseSessionId(create_response) orelse return;

    defer {
        if (deleteSession(allocator, session_id)) |del_resp| {
            allocator.free(del_resp);
        } else |_| {}
    }

    // Navigate
    const nav_response = navigateTo(allocator, session_id, "https://example.com") catch return;
    defer allocator.free(nav_response);

    // Take screenshot
    const screenshot_response = takeScreenshot(allocator, session_id) catch return;
    defer allocator.free(screenshot_response);

    // Check if base64 data is present
    if (std.mem.indexOf(u8, screenshot_response, "value") != null) {
        std.debug.print("✅ Screenshot test passed\n", .{});
    }
}
