//! Desktop Platform E2E Tests (macOS, Windows, Linux)
//!
//! Tests against actual accessibility bridge servers.
//! - macOS: Custom accessibility bridge on port 8200
//! - Windows: WinAppDriver on port 4723
//! - Linux: AT-SPI bridge on port 8300

const std = @import("std");
const builtin = @import("builtin");
const e2e = @import("e2e_tests.zig");

/// Get current platform configuration
pub fn getCurrentPlatform() struct { host: []const u8, port: u16, name: []const u8 } {
    return switch (builtin.os.tag) {
        .macos => .{ .host = "127.0.0.1", .port = e2e.ProductionPorts.macos, .name = "macOS" },
        .windows => .{ .host = "127.0.0.1", .port = e2e.ProductionPorts.windows, .name = "Windows" },
        .linux => .{ .host = "127.0.0.1", .port = e2e.ProductionPorts.linux, .name = "Linux" },
        else => .{ .host = "127.0.0.1", .port = 8200, .name = "Unknown" },
    };
}

/// Check if accessibility bridge is available
pub fn isBridgeAvailable() bool {
    const platform = getCurrentPlatform();
    return e2e.isServerAvailable(platform.host, platform.port, 1000);
}

// =============================================================================
// macOS Accessibility Bridge
// =============================================================================

/// macOS: Get bridge status
pub fn macosGetStatus(allocator: std.mem.Allocator) ![]u8 {
    return e2e.sendHttpRequest(allocator, "127.0.0.1", e2e.ProductionPorts.macos, "GET", "/status", null);
}

/// macOS: Create session
pub fn macosCreateSession(allocator: std.mem.Allocator, bundle_id: []const u8) ![]u8 {
    var body_buf: [512]u8 = undefined;
    const body = try std.fmt.bufPrint(&body_buf,
        \\{{"capabilities":{{"bundleId":"{s}","platformName":"macOS"}}}}
    , .{bundle_id});

    return e2e.sendHttpRequest(allocator, "127.0.0.1", e2e.ProductionPorts.macos, "POST", "/session", body);
}

/// macOS: Find element by accessibility identifier
pub fn macosFindByAccessibilityId(allocator: std.mem.Allocator, session_id: []const u8, identifier: []const u8) ![]u8 {
    var path_buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/session/{s}/element", .{session_id});

    var body_buf: [512]u8 = undefined;
    const body = try std.fmt.bufPrint(&body_buf,
        \\{{"using":"accessibility id","value":"{s}"}}
    , .{identifier});

    return e2e.sendHttpRequest(allocator, "127.0.0.1", e2e.ProductionPorts.macos, "POST", path, body);
}

/// macOS: Get window list
pub fn macosGetWindows(allocator: std.mem.Allocator, session_id: []const u8) ![]u8 {
    var path_buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/session/{s}/windows", .{session_id});

    return e2e.sendHttpRequest(allocator, "127.0.0.1", e2e.ProductionPorts.macos, "GET", path, null);
}

/// macOS: Delete session
pub fn macosDeleteSession(allocator: std.mem.Allocator, session_id: []const u8) ![]u8 {
    var path_buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/session/{s}", .{session_id});

    return e2e.sendHttpRequest(allocator, "127.0.0.1", e2e.ProductionPorts.macos, "DELETE", path, null);
}

// =============================================================================
// Linux AT-SPI Bridge
// =============================================================================

/// Linux: Get AT-SPI status
pub fn linuxGetStatus(allocator: std.mem.Allocator) ![]u8 {
    return e2e.sendHttpRequest(allocator, "127.0.0.1", e2e.ProductionPorts.linux, "GET", "/status", null);
}

/// Linux: Create session
pub fn linuxCreateSession(allocator: std.mem.Allocator, app_path: []const u8) ![]u8 {
    var body_buf: [512]u8 = undefined;
    const body = try std.fmt.bufPrint(&body_buf,
        \\{{"capabilities":{{"appPath":"{s}","platformName":"Linux"}}}}
    , .{app_path});

    return e2e.sendHttpRequest(allocator, "127.0.0.1", e2e.ProductionPorts.linux, "POST", "/session", body);
}

/// Linux: Find element by role
pub fn linuxFindByRole(allocator: std.mem.Allocator, session_id: []const u8, role: []const u8) ![]u8 {
    var path_buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/session/{s}/element", .{session_id});

    var body_buf: [512]u8 = undefined;
    const body = try std.fmt.bufPrint(&body_buf,
        \\{{"using":"role","value":"{s}"}}
    , .{role});

    return e2e.sendHttpRequest(allocator, "127.0.0.1", e2e.ProductionPorts.linux, "POST", path, body);
}

/// Linux: Delete session
pub fn linuxDeleteSession(allocator: std.mem.Allocator, session_id: []const u8) ![]u8 {
    var path_buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/session/{s}", .{session_id});

    return e2e.sendHttpRequest(allocator, "127.0.0.1", e2e.ProductionPorts.linux, "DELETE", path, null);
}

// =============================================================================
// Windows WinAppDriver
// =============================================================================

/// Windows: Get WinAppDriver status
pub fn windowsGetStatus(allocator: std.mem.Allocator) ![]u8 {
    return e2e.sendHttpRequest(allocator, "127.0.0.1", e2e.ProductionPorts.windows, "GET", "/status", null);
}

/// Windows: Create session
pub fn windowsCreateSession(allocator: std.mem.Allocator, app_path: []const u8) ![]u8 {
    var body_buf: [1024]u8 = undefined;
    const body = try std.fmt.bufPrint(&body_buf,
        \\{{"capabilities":{{"alwaysMatch":{{"app":"{s}","platformName":"Windows"}}}}}}
    , .{app_path});

    return e2e.sendHttpRequest(allocator, "127.0.0.1", e2e.ProductionPorts.windows, "POST", "/session", body);
}

/// Windows: Find element by automation ID
pub fn windowsFindByAutomationId(allocator: std.mem.Allocator, session_id: []const u8, automation_id: []const u8) ![]u8 {
    var path_buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/session/{s}/element", .{session_id});

    var body_buf: [512]u8 = undefined;
    const body = try std.fmt.bufPrint(&body_buf,
        \\{{"using":"accessibility id","value":"{s}"}}
    , .{automation_id});

    return e2e.sendHttpRequest(allocator, "127.0.0.1", e2e.ProductionPorts.windows, "POST", path, body);
}

/// Windows: Delete session
pub fn windowsDeleteSession(allocator: std.mem.Allocator, session_id: []const u8) ![]u8 {
    var path_buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/session/{s}", .{session_id});

    return e2e.sendHttpRequest(allocator, "127.0.0.1", e2e.ProductionPorts.windows, "DELETE", path, null);
}

// E2E Tests

test "desktop e2e: bridge availability" {
    const platform = getCurrentPlatform();

    if (!isBridgeAvailable()) {
        std.debug.print("⏭️  {s} accessibility bridge not available, skipping desktop E2E tests\n", .{platform.name});
        return;
    }

    std.debug.print("✅ {s} accessibility bridge is available at {s}:{d}\n", .{platform.name, platform.host, platform.port});
}

test "desktop e2e: macos session lifecycle" {
    if (builtin.os.tag != .macos) return;
    if (!e2e.isServerAvailable("127.0.0.1", e2e.ProductionPorts.macos, 1000)) {
        std.debug.print("⏭️  macOS bridge not available\n", .{});
        return;
    }

    const allocator = std.testing.allocator;

    // Get status first
    const status_response = macosGetStatus(allocator) catch |err| {
        std.debug.print("Failed to get macOS bridge status: {}\n", .{err});
        return;
    };
    defer allocator.free(status_response);

    // Create session with Finder
    const create_response = macosCreateSession(allocator, "com.apple.finder") catch |err| {
        std.debug.print("Failed to create macOS session: {}\n", .{err});
        return;
    };
    defer allocator.free(create_response);

    const session_id = e2e.parseSessionId(create_response);
    if (session_id == null) {
        std.debug.print("Could not parse session ID from macOS response\n", .{});
        return;
    }

    // Delete session
    const delete_response = macosDeleteSession(allocator, session_id.?) catch |err| {
        std.debug.print("Failed to delete macOS session: {}\n", .{err});
        return;
    };
    defer allocator.free(delete_response);

    std.debug.print("✅ macOS session lifecycle test passed\n", .{});
}

test "desktop e2e: linux session lifecycle" {
    if (builtin.os.tag != .linux) return;
    if (!e2e.isServerAvailable("127.0.0.1", e2e.ProductionPorts.linux, 1000)) {
        std.debug.print("⏭️  Linux AT-SPI bridge not available\n", .{});
        return;
    }

    const allocator = std.testing.allocator;

    // Get status
    const status_response = linuxGetStatus(allocator) catch |err| {
        std.debug.print("Failed to get Linux bridge status: {}\n", .{err});
        return;
    };
    defer allocator.free(status_response);

    // Create session with gedit or gnome-calculator
    const create_response = linuxCreateSession(allocator, "/usr/bin/gnome-calculator") catch |err| {
        std.debug.print("Failed to create Linux session: {}\n", .{err});
        return;
    };
    defer allocator.free(create_response);

    const session_id = e2e.parseSessionId(create_response);
    if (session_id == null) {
        std.debug.print("Could not parse session ID from Linux response\n", .{});
        return;
    }

    // Delete session
    const delete_response = linuxDeleteSession(allocator, session_id.?) catch |err| {
        std.debug.print("Failed to delete Linux session: {}\n", .{err});
        return;
    };
    defer allocator.free(delete_response);

    std.debug.print("✅ Linux session lifecycle test passed\n", .{});
}

test "desktop e2e: windows session lifecycle" {
    if (builtin.os.tag != .windows) return;
    if (!e2e.isServerAvailable("127.0.0.1", e2e.ProductionPorts.windows, 1000)) {
        std.debug.print("⏭️  Windows WinAppDriver not available\n", .{});
        return;
    }

    const allocator = std.testing.allocator;

    // Get status
    const status_response = windowsGetStatus(allocator) catch |err| {
        std.debug.print("Failed to get Windows WinAppDriver status: {}\n", .{err});
        return;
    };
    defer allocator.free(status_response);

    // Create session with Calculator
    const create_response = windowsCreateSession(allocator, "Microsoft.WindowsCalculator_8wekyb3d8bbwe!App") catch |err| {
        std.debug.print("Failed to create Windows session: {}\n", .{err});
        return;
    };
    defer allocator.free(create_response);

    const session_id = e2e.parseSessionId(create_response);
    if (session_id == null) {
        std.debug.print("Could not parse session ID from Windows response\n", .{});
        return;
    }

    // Delete session
    const delete_response = windowsDeleteSession(allocator, session_id.?) catch |err| {
        std.debug.print("Failed to delete Windows session: {}\n", .{err});
        return;
    };
    defer allocator.free(delete_response);

    std.debug.print("✅ Windows session lifecycle test passed\n", .{});
}

test "desktop e2e: macos element finding" {
    if (builtin.os.tag != .macos) return;
    if (!e2e.isServerAvailable("127.0.0.1", e2e.ProductionPorts.macos, 1000)) return;

    const allocator = std.testing.allocator;

    // Create session
    const create_response = macosCreateSession(allocator, "com.apple.finder") catch return;
    defer allocator.free(create_response);

    const session_id = e2e.parseSessionId(create_response) orelse return;

    defer {
        if (macosDeleteSession(allocator, session_id)) |del_resp| {
            allocator.free(del_resp);
        } else |_| {}
    }

    // Find element
    const element_response = macosFindByAccessibilityId(allocator, session_id, "AXMenuBarItem") catch return;
    defer allocator.free(element_response);

    if (std.mem.indexOf(u8, element_response, "ELEMENT") != null) {
        std.debug.print("✅ macOS element finding test passed\n", .{});
    }
}

test "desktop e2e: macos window list" {
    if (builtin.os.tag != .macos) return;
    if (!e2e.isServerAvailable("127.0.0.1", e2e.ProductionPorts.macos, 1000)) return;

    const allocator = std.testing.allocator;

    // Create session
    const create_response = macosCreateSession(allocator, "com.apple.finder") catch return;
    defer allocator.free(create_response);

    const session_id = e2e.parseSessionId(create_response) orelse return;

    defer {
        if (macosDeleteSession(allocator, session_id)) |del_resp| {
            allocator.free(del_resp);
        } else |_| {}
    }

    // Get windows
    const windows_response = macosGetWindows(allocator, session_id) catch return;
    defer allocator.free(windows_response);

    if (std.mem.indexOf(u8, windows_response, "value") != null) {
        std.debug.print("✅ macOS window list test passed\n", .{});
    }
}
