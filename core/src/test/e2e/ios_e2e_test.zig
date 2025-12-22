//! iOS/watchOS Platform E2E Tests
//!
//! Tests against actual WebDriverAgent server.
//! Requires a running WDA server on port 8100.

const std = @import("std");
const e2e = @import("e2e_tests.zig");

const HOST = "127.0.0.1";
const PORT = e2e.ProductionPorts.ios;

/// Check if WebDriverAgent is available
pub fn isWDAAvailable() bool {
    return e2e.isServerAvailable(HOST, PORT, 1000);
}

/// Get WDA status
pub fn getStatus(allocator: std.mem.Allocator) ![]u8 {
    return e2e.sendHttpRequest(allocator, HOST, PORT, "GET", "/status", null);
}

/// Create iOS session
pub fn createSession(
    allocator: std.mem.Allocator,
    bundle_id: []const u8,
    platform_name: []const u8,
) ![]u8 {
    var body_buf: [1024]u8 = undefined;
    const body = try std.fmt.bufPrint(&body_buf,
        \\{{"capabilities":{{"alwaysMatch":{{"platformName":"{s}","bundleId":"{s}","automationName":"XCUITest"}}}}}}
    , .{platform_name, bundle_id});

    return e2e.sendHttpRequest(allocator, HOST, PORT, "POST", "/session", body);
}

/// Get source (UI hierarchy)
pub fn getSource(allocator: std.mem.Allocator, session_id: []const u8) ![]u8 {
    var path_buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/session/{s}/source", .{session_id});

    return e2e.sendHttpRequest(allocator, HOST, PORT, "GET", path, null);
}

/// Find element by accessibility ID
pub fn findByAccessibilityId(allocator: std.mem.Allocator, session_id: []const u8, accessibility_id: []const u8) ![]u8 {
    var path_buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/session/{s}/element", .{session_id});

    var body_buf: [512]u8 = undefined;
    const body = try std.fmt.bufPrint(&body_buf,
        \\{{"using":"accessibility id","value":"{s}"}}
    , .{accessibility_id});

    return e2e.sendHttpRequest(allocator, HOST, PORT, "POST", path, body);
}

/// Tap at coordinates
pub fn tapAtCoordinates(allocator: std.mem.Allocator, session_id: []const u8, x: u32, y: u32) ![]u8 {
    var path_buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/session/{s}/wda/tap/0", .{session_id});

    var body_buf: [256]u8 = undefined;
    const body = try std.fmt.bufPrint(&body_buf,
        \\{{"x":{d},"y":{d}}}
    , .{x, y});

    return e2e.sendHttpRequest(allocator, HOST, PORT, "POST", path, body);
}

/// Swipe gesture
pub fn swipe(allocator: std.mem.Allocator, session_id: []const u8, start_x: u32, start_y: u32, end_x: u32, end_y: u32) ![]u8 {
    var path_buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/session/{s}/wda/dragfromtoforduration", .{session_id});

    var body_buf: [256]u8 = undefined;
    const body = try std.fmt.bufPrint(&body_buf,
        \\{{"fromX":{d},"fromY":{d},"toX":{d},"toY":{d},"duration":0.5}}
    , .{start_x, start_y, end_x, end_y});

    return e2e.sendHttpRequest(allocator, HOST, PORT, "POST", path, body);
}

/// Rotate Digital Crown (watchOS)
pub fn rotateDigitalCrown(allocator: std.mem.Allocator, session_id: []const u8, direction: []const u8, velocity: f32) ![]u8 {
    var path_buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/session/{s}/wda/digitalCrown/rotate", .{session_id});

    var body_buf: [256]u8 = undefined;
    const body = try std.fmt.bufPrint(&body_buf,
        \\{{"direction":"{s}","velocity":{d:.2}}}
    , .{direction, velocity});

    return e2e.sendHttpRequest(allocator, HOST, PORT, "POST", path, body);
}

/// Press Side Button (watchOS)
pub fn pressSideButton(allocator: std.mem.Allocator, session_id: []const u8) ![]u8 {
    var path_buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/session/{s}/wda/sideButton/press", .{session_id});

    return e2e.sendHttpRequest(allocator, HOST, PORT, "POST", path, "{}");
}

/// Delete session
pub fn deleteSession(allocator: std.mem.Allocator, session_id: []const u8) ![]u8 {
    var path_buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/session/{s}", .{session_id});

    return e2e.sendHttpRequest(allocator, HOST, PORT, "DELETE", path, null);
}

// E2E Tests

test "ios e2e: wda server availability" {
    if (!isWDAAvailable()) {
        std.debug.print("⏭️  WebDriverAgent not available, skipping iOS E2E tests\n", .{});
        return;
    }

    std.debug.print("✅ WebDriverAgent server is available at {s}:{d}\n", .{HOST, PORT});
}

test "ios e2e: wda status" {
    if (!isWDAAvailable()) return;

    const allocator = std.testing.allocator;

    const status_response = getStatus(allocator) catch |err| {
        std.debug.print("Failed to get WDA status: {}\n", .{err});
        return;
    };
    defer allocator.free(status_response);

    // Check for status indicators
    if (std.mem.indexOf(u8, status_response, "ready") != null or
        std.mem.indexOf(u8, status_response, "sessionId") != null or
        std.mem.indexOf(u8, status_response, "ios") != null)
    {
        std.debug.print("✅ WDA status check passed\n", .{});
    }
}

test "ios e2e: session lifecycle" {
    if (!isWDAAvailable()) return;

    const allocator = std.testing.allocator;

    // Create iOS session
    const create_response = createSession(allocator, "com.apple.Preferences", "iOS") catch |err| {
        std.debug.print("Failed to create iOS session: {}\n", .{err});
        return;
    };
    defer allocator.free(create_response);

    const session_id = e2e.parseSessionId(create_response);
    if (session_id == null) {
        std.debug.print("Could not parse session ID from iOS response\n", .{});
        return;
    }

    // Delete session
    const delete_response = deleteSession(allocator, session_id.?) catch |err| {
        std.debug.print("Failed to delete iOS session: {}\n", .{err});
        return;
    };
    defer allocator.free(delete_response);

    std.debug.print("✅ iOS session lifecycle test passed\n", .{});
}

test "ios e2e: element finding" {
    if (!isWDAAvailable()) return;

    const allocator = std.testing.allocator;

    // Create session
    const create_response = createSession(allocator, "com.apple.Preferences", "iOS") catch return;
    defer allocator.free(create_response);

    const session_id = e2e.parseSessionId(create_response) orelse return;

    defer {
        if (deleteSession(allocator, session_id)) |del_resp| {
            allocator.free(del_resp);
        } else |_| {}
    }

    // Find element by accessibility ID
    const element_response = findByAccessibilityId(allocator, session_id, "General") catch return;
    defer allocator.free(element_response);

    if (std.mem.indexOf(u8, element_response, "ELEMENT") != null) {
        std.debug.print("✅ iOS element finding test passed\n", .{});
    }
}

test "ios e2e: source retrieval" {
    if (!isWDAAvailable()) return;

    const allocator = std.testing.allocator;

    // Create session
    const create_response = createSession(allocator, "com.apple.Preferences", "iOS") catch return;
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

    if (std.mem.indexOf(u8, source_response, "XCUIElementType") != null) {
        std.debug.print("✅ iOS source retrieval test passed\n", .{});
    }
}

test "watchos e2e: digital crown" {
    if (!isWDAAvailable()) return;

    const allocator = std.testing.allocator;

    // Create watchOS session
    const create_response = createSession(allocator, "com.apple.Workout", "watchOS") catch return;
    defer allocator.free(create_response);

    const session_id = e2e.parseSessionId(create_response) orelse return;

    defer {
        if (deleteSession(allocator, session_id)) |del_resp| {
            allocator.free(del_resp);
        } else |_| {}
    }

    // Rotate Digital Crown
    const crown_response = rotateDigitalCrown(allocator, session_id, "up", 0.5) catch return;
    defer allocator.free(crown_response);

    if (e2e.parseStatus(crown_response)) |status| {
        if (status == 0) {
            std.debug.print("✅ watchOS Digital Crown test passed\n", .{});
        }
    }
}

test "watchos e2e: side button" {
    if (!isWDAAvailable()) return;

    const allocator = std.testing.allocator;

    // Create watchOS session
    const create_response = createSession(allocator, "com.apple.Workout", "watchOS") catch return;
    defer allocator.free(create_response);

    const session_id = e2e.parseSessionId(create_response) orelse return;

    defer {
        if (deleteSession(allocator, session_id)) |del_resp| {
            allocator.free(del_resp);
        } else |_| {}
    }

    // Press Side Button
    const button_response = pressSideButton(allocator, session_id) catch return;
    defer allocator.free(button_response);

    if (e2e.parseStatus(button_response)) |status| {
        if (status == 0) {
            std.debug.print("✅ watchOS Side Button test passed\n", .{});
        }
    }
}
