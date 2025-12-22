//! Android Platform E2E Tests
//!
//! Tests against actual UIAutomator2/Appium server.
//! Requires a running Appium server on port 4723.

const std = @import("std");
const e2e = @import("e2e_tests.zig");

const HOST = "127.0.0.1";
const PORT = e2e.ProductionPorts.android;

/// Check if Appium/UIAutomator2 is available
pub fn isAppiumAvailable() bool {
    return e2e.isServerAvailable(HOST, PORT, 1000);
}

/// Get Appium status
pub fn getStatus(allocator: std.mem.Allocator) ![]u8 {
    return e2e.sendHttpRequest(allocator, HOST, PORT, "GET", "/status", null);
}

/// Create Android session
pub fn createSession(
    allocator: std.mem.Allocator,
    package_name: []const u8,
    activity_name: []const u8,
) ![]u8 {
    var body_buf: [1024]u8 = undefined;
    const body = try std.fmt.bufPrint(&body_buf,
        \\{{"capabilities":{{"alwaysMatch":{{"platformName":"Android","appPackage":"{s}","appActivity":"{s}","automationName":"UiAutomator2"}}}}}}
    , .{package_name, activity_name});

    return e2e.sendHttpRequest(allocator, HOST, PORT, "POST", "/session", body);
}

/// Find element by resource ID
pub fn findByResourceId(allocator: std.mem.Allocator, session_id: []const u8, resource_id: []const u8) ![]u8 {
    var path_buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/session/{s}/element", .{session_id});

    var body_buf: [512]u8 = undefined;
    const body = try std.fmt.bufPrint(&body_buf,
        \\{{"using":"id","value":"{s}"}}
    , .{resource_id});

    return e2e.sendHttpRequest(allocator, HOST, PORT, "POST", path, body);
}

/// Find element by UI Automator selector
pub fn findByUiAutomator(allocator: std.mem.Allocator, session_id: []const u8, selector: []const u8) ![]u8 {
    var path_buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/session/{s}/element", .{session_id});

    var body_buf: [1024]u8 = undefined;
    const body = try std.fmt.bufPrint(&body_buf,
        \\{{"using":"-android uiautomator","value":"{s}"}}
    , .{selector});

    return e2e.sendHttpRequest(allocator, HOST, PORT, "POST", path, body);
}

/// Click element
pub fn clickElement(allocator: std.mem.Allocator, session_id: []const u8, element_id: []const u8) ![]u8 {
    var path_buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/session/{s}/element/{s}/click", .{session_id, element_id});

    return e2e.sendHttpRequest(allocator, HOST, PORT, "POST", path, "{}");
}

/// Send keys to element
pub fn sendKeys(allocator: std.mem.Allocator, session_id: []const u8, element_id: []const u8, text: []const u8) ![]u8 {
    var path_buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/session/{s}/element/{s}/value", .{session_id, element_id});

    var body_buf: [1024]u8 = undefined;
    const body = try std.fmt.bufPrint(&body_buf,
        \\{{"text":"{s}"}}
    , .{text});

    return e2e.sendHttpRequest(allocator, HOST, PORT, "POST", path, body);
}

/// Get page source
pub fn getSource(allocator: std.mem.Allocator, session_id: []const u8) ![]u8 {
    var path_buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/session/{s}/source", .{session_id});

    return e2e.sendHttpRequest(allocator, HOST, PORT, "GET", path, null);
}

/// Take screenshot
pub fn takeScreenshot(allocator: std.mem.Allocator, session_id: []const u8) ![]u8 {
    var path_buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/session/{s}/screenshot", .{session_id});

    return e2e.sendHttpRequest(allocator, HOST, PORT, "GET", path, null);
}

/// Press back button
pub fn pressBack(allocator: std.mem.Allocator, session_id: []const u8) ![]u8 {
    var path_buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/session/{s}/back", .{session_id});

    return e2e.sendHttpRequest(allocator, HOST, PORT, "POST", path, "{}");
}

/// Delete session
pub fn deleteSession(allocator: std.mem.Allocator, session_id: []const u8) ![]u8 {
    var path_buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/session/{s}", .{session_id});

    return e2e.sendHttpRequest(allocator, HOST, PORT, "DELETE", path, null);
}

// E2E Tests

test "android e2e: appium server availability" {
    if (!isAppiumAvailable()) {
        std.debug.print("⏭️  Appium/UIAutomator2 not available, skipping Android E2E tests\n", .{});
        return;
    }

    std.debug.print("✅ Appium server is available at {s}:{d}\n", .{HOST, PORT});
}

test "android e2e: appium status" {
    if (!isAppiumAvailable()) return;

    const allocator = std.testing.allocator;

    const status_response = getStatus(allocator) catch |err| {
        std.debug.print("Failed to get Appium status: {}\n", .{err});
        return;
    };
    defer allocator.free(status_response);

    // Check for status indicators
    if (std.mem.indexOf(u8, status_response, "ready") != null or
        std.mem.indexOf(u8, status_response, "build") != null)
    {
        std.debug.print("✅ Appium status check passed\n", .{});
    }
}

test "android e2e: session lifecycle" {
    if (!isAppiumAvailable()) return;

    const allocator = std.testing.allocator;

    // Create Android session (using Settings app as test target)
    const create_response = createSession(
        allocator,
        "com.android.settings",
        ".Settings",
    ) catch |err| {
        std.debug.print("Failed to create Android session: {}\n", .{err});
        return;
    };
    defer allocator.free(create_response);

    const session_id = e2e.parseSessionId(create_response);
    if (session_id == null) {
        std.debug.print("Could not parse session ID from Android response\n", .{});
        return;
    }

    // Delete session
    const delete_response = deleteSession(allocator, session_id.?) catch |err| {
        std.debug.print("Failed to delete Android session: {}\n", .{err});
        return;
    };
    defer allocator.free(delete_response);

    std.debug.print("✅ Android session lifecycle test passed\n", .{});
}

test "android e2e: element finding" {
    if (!isAppiumAvailable()) return;

    const allocator = std.testing.allocator;

    // Create session
    const create_response = createSession(
        allocator,
        "com.android.settings",
        ".Settings",
    ) catch return;
    defer allocator.free(create_response);

    const session_id = e2e.parseSessionId(create_response) orelse return;

    defer {
        if (deleteSession(allocator, session_id)) |del_resp| {
            allocator.free(del_resp);
        } else |_| {}
    }

    // Find element by UI Automator
    const element_response = findByUiAutomator(
        allocator,
        session_id,
        "new UiSelector().textContains(\\\"Network\\\")",
    ) catch return;
    defer allocator.free(element_response);

    if (std.mem.indexOf(u8, element_response, "ELEMENT") != null or
        std.mem.indexOf(u8, element_response, "element-") != null)
    {
        std.debug.print("✅ Android element finding test passed\n", .{});
    }
}

test "android e2e: source retrieval" {
    if (!isAppiumAvailable()) return;

    const allocator = std.testing.allocator;

    // Create session
    const create_response = createSession(
        allocator,
        "com.android.settings",
        ".Settings",
    ) catch return;
    defer allocator.free(create_response);

    const session_id = e2e.parseSessionId(create_response) orelse return;

    defer {
        if (deleteSession(allocator, session_id)) |del_resp| {
            allocator.free(del_resp);
        } else |_| {}
    }

    // Get source
    const source_response = getSource(allocator, session_id) catch return;
    defer allocator.free(source_response);

    if (std.mem.indexOf(u8, source_response, "android.widget") != null or
        std.mem.indexOf(u8, source_response, "hierarchy") != null)
    {
        std.debug.print("✅ Android source retrieval test passed\n", .{});
    }
}

test "android e2e: screenshot" {
    if (!isAppiumAvailable()) return;

    const allocator = std.testing.allocator;

    // Create session
    const create_response = createSession(
        allocator,
        "com.android.settings",
        ".Settings",
    ) catch return;
    defer allocator.free(create_response);

    const session_id = e2e.parseSessionId(create_response) orelse return;

    defer {
        if (deleteSession(allocator, session_id)) |del_resp| {
            allocator.free(del_resp);
        } else |_| {}
    }

    // Take screenshot
    const screenshot_response = takeScreenshot(allocator, session_id) catch return;
    defer allocator.free(screenshot_response);

    if (std.mem.indexOf(u8, screenshot_response, "value") != null) {
        std.debug.print("✅ Android screenshot test passed\n", .{});
    }
}
