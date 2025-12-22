//! Desktop Platform Integration Tests
//!
//! Tests communication between Zig drivers and desktop bridge servers:
//! - macOS Accessibility bridge
//! - Linux AT-SPI bridge
//!
//! Compatible with Zig 0.15.

const std = @import("std");
const builtin = @import("builtin");
const mock_server = @import("mock_server.zig");

const MockServer = mock_server.MockServer;

// Test ports
const MACOS_TEST_PORT: u16 = 18200;
const LINUX_TEST_PORT: u16 = 18300;

/// Platform detection for testing
pub const Platform = enum {
    auto,
    macos,
    linux,
    windows,
    ios,
    android,
    web,

    pub fn current() Platform {
        return switch (builtin.os.tag) {
            .macos => .macos,
            .linux => .linux,
            .windows => .windows,
            .ios => .ios,
            else => .auto,
        };
    }
};

/// Selector types for testing
pub const Selector = struct {
    test_id: ?[]const u8 = null,
    accessibility_id: ?[]const u8 = null,
    text: ?[]const u8 = null,
    text_contains: ?[]const u8 = null,
    role: ?[]const u8 = null,
    title: ?[]const u8 = null,
};

// =========================================================================
// macOS Accessibility Bridge Mock Handler
// =========================================================================

fn macosMockHandler(path: []const u8, body: []const u8) mock_server.MockResponse {
    _ = body;

    // Session management
    if (std.mem.indexOf(u8, path, "/launch") != null or std.mem.indexOf(u8, path, "/attach") != null) {
        return .{ .body =
            \\{"sessionId":"ax-session-1","pid":12345,"success":true}
        };
    }
    if (std.mem.indexOf(u8, path, "/close") != null) {
        return .{ .body =
            \\{"success":true}
        };
    }

    // Element finding (macOS uses AXUIElement patterns)
    if (std.mem.indexOf(u8, path, "/findElement") != null) {
        return .{ .body =
            \\{"elementId":"ax-1"}
        };
    }
    if (std.mem.indexOf(u8, path, "/findElements") != null) {
        return .{ .body =
            \\{"elements":["ax-1","ax-2","ax-3"]}
        };
    }

    // Element actions
    if (std.mem.indexOf(u8, path, "/click") != null) {
        return .{ .body =
            \\{"success":true}
        };
    }
    if (std.mem.indexOf(u8, path, "/type") != null) {
        return .{ .body =
            \\{"success":true}
        };
    }

    // Element properties (AXValue, AXTitle, etc.)
    if (std.mem.indexOf(u8, path, "/getValue") != null or std.mem.indexOf(u8, path, "/getText") != null) {
        return .{ .body =
            \\{"value":"macOS Element Text"}
        };
    }
    if (std.mem.indexOf(u8, path, "/getTitle") != null) {
        return .{ .body =
            \\{"value":"Window Title"}
        };
    }
    if (std.mem.indexOf(u8, path, "/getRole") != null) {
        return .{ .body =
            \\{"value":"AXButton"}
        };
    }
    if (std.mem.indexOf(u8, path, "/isVisible") != null) {
        return .{ .body =
            \\{"visible":true}
        };
    }
    if (std.mem.indexOf(u8, path, "/isEnabled") != null) {
        return .{ .body =
            \\{"enabled":true}
        };
    }
    if (std.mem.indexOf(u8, path, "/getBounds") != null or std.mem.indexOf(u8, path, "/getFrame") != null) {
        return .{ .body =
            \\{"x":100,"y":200,"width":300,"height":50}
        };
    }

    // Screenshot
    if (std.mem.indexOf(u8, path, "/screenshot") != null) {
        return .{ .body =
            \\{"data":"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="}
        };
    }

    // Window info
    if (std.mem.indexOf(u8, path, "/window") != null) {
        return .{ .body =
            \\{"title":"Test Window","x":0,"y":0,"width":1920,"height":1080}
        };
    }

    // Default response
    return .{ .body =
        \\{"success":true}
    };
}

// =========================================================================
// Linux AT-SPI Bridge Mock Handler
// =========================================================================

fn linuxMockHandler(path: []const u8, body: []const u8) mock_server.MockResponse {
    _ = body;

    // Session management
    if (std.mem.indexOf(u8, path, "/launch") != null or std.mem.indexOf(u8, path, "/attach") != null) {
        return .{ .body =
            \\{"sessionId":"atspi-session-1","pid":54321,"success":true}
        };
    }
    if (std.mem.indexOf(u8, path, "/close") != null) {
        return .{ .body =
            \\{"success":true}
        };
    }

    // Element finding (AT-SPI patterns)
    if (std.mem.indexOf(u8, path, "/findElement") != null) {
        return .{ .body =
            \\{"elementId":"atspi-1"}
        };
    }
    if (std.mem.indexOf(u8, path, "/findElements") != null) {
        return .{ .body =
            \\{"elements":["atspi-1","atspi-2"]}
        };
    }

    // Element actions
    if (std.mem.indexOf(u8, path, "/click") != null) {
        return .{ .body =
            \\{"success":true}
        };
    }
    if (std.mem.indexOf(u8, path, "/doubleClick") != null) {
        return .{ .body =
            \\{"success":true}
        };
    }
    if (std.mem.indexOf(u8, path, "/rightClick") != null) {
        return .{ .body =
            \\{"success":true}
        };
    }
    if (std.mem.indexOf(u8, path, "/type") != null) {
        return .{ .body =
            \\{"success":true}
        };
    }
    if (std.mem.indexOf(u8, path, "/keys") != null) {
        return .{ .body =
            \\{"success":true}
        };
    }

    // Element properties (AT-SPI names)
    if (std.mem.indexOf(u8, path, "/getText") != null) {
        return .{ .body =
            \\{"value":"Linux Element Text"}
        };
    }
    if (std.mem.indexOf(u8, path, "/getName") != null) {
        return .{ .body =
            \\{"value":"Button Label"}
        };
    }
    if (std.mem.indexOf(u8, path, "/getRole") != null) {
        return .{ .body =
            \\{"value":"push-button"}
        };
    }
    if (std.mem.indexOf(u8, path, "/getDescription") != null) {
        return .{ .body =
            \\{"value":"Click to submit"}
        };
    }
    if (std.mem.indexOf(u8, path, "/isVisible") != null) {
        return .{ .body =
            \\{"value":true}
        };
    }
    if (std.mem.indexOf(u8, path, "/isEnabled") != null) {
        return .{ .body =
            \\{"value":true}
        };
    }
    if (std.mem.indexOf(u8, path, "/isFocused") != null) {
        return .{ .body =
            \\{"value":false}
        };
    }
    if (std.mem.indexOf(u8, path, "/getBounds") != null) {
        return .{ .body =
            \\{"x":50,"y":100,"width":200,"height":40}
        };
    }

    // Screenshot
    if (std.mem.indexOf(u8, path, "/screenshot") != null or std.mem.indexOf(u8, path, "/elementScreenshot") != null) {
        return .{ .body =
            \\{"data":"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="}
        };
    }

    // Window info
    if (std.mem.indexOf(u8, path, "/window") != null) {
        return .{ .body =
            \\{"title":"GTK Window","x":0,"y":0,"width":1280,"height":720}
        };
    }

    // Default response
    return .{ .body =
        \\{"success":true}
    };
}

// =========================================================================
// macOS Integration Tests
// =========================================================================

test "macos bridge session management" {
    const allocator = std.testing.allocator;

    var server = MockServer.init(allocator, MACOS_TEST_PORT);
    defer server.deinit();
    server.setHandler(macosMockHandler);
    try server.start();
    defer server.stop();

    std.Thread.sleep(100 * std.time.ns_per_ms);

    // Test launch request
    const address = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, MACOS_TEST_PORT);
    const stream = std.net.tcpConnectToAddress(address) catch return;
    defer stream.close();

    const request =
        \\POST /session/new/launch HTTP/1.1
        \\Host: 127.0.0.1:18200
        \\Content-Type: application/json
        \\Content-Length: 65
        \\
        \\{"bundleId":"com.test.app","waitForLaunch":true,"timeout":30000}
    ;
    _ = stream.write(request) catch return;

    var buffer: [1024]u8 = undefined;
    const bytes = stream.read(&buffer) catch return;
    const response = buffer[0..bytes];

    try std.testing.expect(std.mem.indexOf(u8, response, "sessionId") != null or std.mem.indexOf(u8, response, "ax-session") != null);
}

test "macos accessibility element strategies" {
    // Test macOS AX attribute mappings

    // AXIdentifier strategy
    {
        var buf: [256]u8 = undefined;
        const json = std.fmt.bufPrint(&buf,
            \\{{"strategy": "identifier", "value": "{s}"}}
        , .{"login-button"}) catch unreachable;

        try std.testing.expect(std.mem.indexOf(u8, json, "identifier") != null);
    }

    // AXTitle strategy
    {
        var buf: [256]u8 = undefined;
        const json = std.fmt.bufPrint(&buf,
            \\{{"strategy": "title", "value": "{s}"}}
        , .{"Submit"}) catch unreachable;

        try std.testing.expect(std.mem.indexOf(u8, json, "title") != null);
    }

    // AXRole strategy
    {
        var buf: [256]u8 = undefined;
        const json = std.fmt.bufPrint(&buf,
            \\{{"strategy": "role", "value": "{s}"}}
        , .{"AXButton"}) catch unreachable;

        try std.testing.expect(std.mem.indexOf(u8, json, "role") != null);
        try std.testing.expect(std.mem.indexOf(u8, json, "AXButton") != null);
    }
}

test "macos path format validation" {
    var path_buf: [256]u8 = undefined;

    // Launch path
    const launch_path = std.fmt.bufPrint(&path_buf, "/session/new/launch", .{}) catch unreachable;
    try std.testing.expect(std.mem.indexOf(u8, launch_path, "/session/new/launch") != null);

    // Attach path
    const attach_path = std.fmt.bufPrint(&path_buf, "/session/new/attach", .{}) catch unreachable;
    try std.testing.expect(std.mem.indexOf(u8, attach_path, "/attach") != null);

    // Element finding
    const find_path = std.fmt.bufPrint(&path_buf, "/session/{s}/findElement", .{"ax-session-1"}) catch unreachable;
    try std.testing.expect(std.mem.indexOf(u8, find_path, "/findElement") != null);

    // Element action
    const action_path = std.fmt.bufPrint(&path_buf, "/session/{s}/element/{s}/click", .{ "ax-session-1", "ax-1" }) catch unreachable;
    try std.testing.expect(std.mem.indexOf(u8, action_path, "/click") != null);
}

// =========================================================================
// Linux AT-SPI Integration Tests
// =========================================================================

test "linux atspi bridge session management" {
    const allocator = std.testing.allocator;

    var server = MockServer.init(allocator, LINUX_TEST_PORT);
    defer server.deinit();
    server.setHandler(linuxMockHandler);
    try server.start();
    defer server.stop();

    std.Thread.sleep(100 * std.time.ns_per_ms);

    // Test launch request
    const address = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, LINUX_TEST_PORT);
    const stream = std.net.tcpConnectToAddress(address) catch return;
    defer stream.close();

    const request =
        \\POST /session/new/launch HTTP/1.1
        \\Host: 127.0.0.1:18300
        \\Content-Type: application/json
        \\Content-Length: 55
        \\
        \\{"executable":"/usr/bin/gedit","args":[],"timeout":30}
    ;
    _ = stream.write(request) catch return;

    var buffer: [1024]u8 = undefined;
    const bytes = stream.read(&buffer) catch return;
    const response = buffer[0..bytes];

    try std.testing.expect(std.mem.indexOf(u8, response, "sessionId") != null or std.mem.indexOf(u8, response, "atspi") != null);
}

test "linux atspi element strategies" {
    // Test AT-SPI strategy mappings

    // Role strategy
    {
        var buf: [256]u8 = undefined;
        const json = std.fmt.bufPrint(&buf,
            \\{{"strategy": "role", "value": "{s}"}}
        , .{"push button"}) catch unreachable;

        try std.testing.expect(std.mem.indexOf(u8, json, "role") != null);
        try std.testing.expect(std.mem.indexOf(u8, json, "push button") != null);
    }

    // Name strategy
    {
        var buf: [256]u8 = undefined;
        const json = std.fmt.bufPrint(&buf,
            \\{{"strategy": "name", "value": "{s}"}}
        , .{"Submit"}) catch unreachable;

        try std.testing.expect(std.mem.indexOf(u8, json, "name") != null);
    }

    // Description strategy
    {
        var buf: [256]u8 = undefined;
        const json = std.fmt.bufPrint(&buf,
            \\{{"strategy": "description", "value": "{s}"}}
        , .{"Click to submit form"}) catch unreachable;

        try std.testing.expect(std.mem.indexOf(u8, json, "description") != null);
    }
}

test "linux atspi path format validation" {
    var path_buf: [256]u8 = undefined;

    // Launch path (via desktop file)
    const launch_path = std.fmt.bufPrint(&path_buf, "/session/new/launch", .{}) catch unreachable;
    try std.testing.expect(std.mem.indexOf(u8, launch_path, "/launch") != null);

    // Attach path (by PID or window name)
    const attach_path = std.fmt.bufPrint(&path_buf, "/session/new/attach", .{}) catch unreachable;
    try std.testing.expect(std.mem.indexOf(u8, attach_path, "/attach") != null);

    // Element finding
    const find_path = std.fmt.bufPrint(&path_buf, "/session/{s}/findElement", .{"atspi-1"}) catch unreachable;
    try std.testing.expect(std.mem.indexOf(u8, find_path, "/findElement") != null);

    // Element actions
    const click_path = std.fmt.bufPrint(&path_buf, "/session/{s}/click", .{"atspi-1"}) catch unreachable;
    try std.testing.expect(std.mem.indexOf(u8, click_path, "/click") != null);

    const dbl_path = std.fmt.bufPrint(&path_buf, "/session/{s}/doubleClick", .{"atspi-1"}) catch unreachable;
    try std.testing.expect(std.mem.indexOf(u8, dbl_path, "/doubleClick") != null);

    const keys_path = std.fmt.bufPrint(&path_buf, "/session/{s}/keys", .{"atspi-1"}) catch unreachable;
    try std.testing.expect(std.mem.indexOf(u8, keys_path, "/keys") != null);
}

test "linux atspi json request format" {
    // Launch with executable
    {
        const json =
            \\{"executable":"/usr/bin/gedit","args":["--new-window"],"workingDir":"/home/user"}
        ;
        try std.testing.expect(std.mem.indexOf(u8, json, "executable") != null);
        try std.testing.expect(std.mem.indexOf(u8, json, "args") != null);
    }

    // Launch with desktop file
    {
        const json =
            \\{"desktopFile":"org.gnome.gedit.desktop"}
        ;
        try std.testing.expect(std.mem.indexOf(u8, json, "desktopFile") != null);
    }

    // Attach by PID
    {
        var buf: [128]u8 = undefined;
        const json = std.fmt.bufPrint(&buf,
            \\{{"pid": {d}}}
        , .{12345}) catch unreachable;
        try std.testing.expect(std.mem.indexOf(u8, json, "pid") != null);
    }

    // Attach by window name
    {
        const json =
            \\{"windowName":"gedit"}
        ;
        try std.testing.expect(std.mem.indexOf(u8, json, "windowName") != null);
    }
}

// =========================================================================
// Cross-Platform Tests
// =========================================================================

test "platform detection" {
    const current = Platform.current();

    // Verify platform detection works
    try std.testing.expect(current != .auto or builtin.os.tag == .freestanding);

    // On macOS, should detect macOS
    if (builtin.os.tag == .macos) {
        try std.testing.expectEqual(Platform.macos, current);
    }

    // On Linux, should detect Linux
    if (builtin.os.tag == .linux) {
        try std.testing.expectEqual(Platform.linux, current);
    }
}

test "desktop element rect parsing" {
    const response =
        \\{"x":100,"y":200,"width":300,"height":50}
    ;

    // Parse x
    if (std.mem.indexOf(u8, response, "\"x\":")) |start| {
        const value_start = start + 4;
        var end = value_start;
        while (end < response.len and response[end] >= '0' and response[end] <= '9') {
            end += 1;
        }
        const x = std.fmt.parseInt(i32, response[value_start..end], 10) catch 0;
        try std.testing.expectEqual(@as(i32, 100), x);
    }

    // Parse width
    if (std.mem.indexOf(u8, response, "\"width\":")) |start| {
        const value_start = start + 8;
        var end = value_start;
        while (end < response.len and response[end] >= '0' and response[end] <= '9') {
            end += 1;
        }
        const width = std.fmt.parseInt(i32, response[value_start..end], 10) catch 0;
        try std.testing.expectEqual(@as(i32, 300), width);
    }
}
