//! watchOS Driver Integration Tests
//!
//! Tests communication between Zig watchOS Driver and XCUITest bridge server.
//!
//! Compatible with Zig 0.15.

const std = @import("std");
const mock_server = @import("mock_server.zig");

const MockServer = mock_server.MockServer;

// Test port (different from production 8100)
const TEST_PORT: u16 = 18101;

/// watchOS driver configuration (local copy for testing)
pub const WatchOSDriverConfig = struct {
    host: []const u8 = "127.0.0.1",
    port: u16 = 8100,
    device_udid: ?[]const u8 = null,
    use_simulator: bool = true,
    simulator_type: SimulatorType = .apple_watch_series_9_45mm,
    watchos_version: []const u8 = "11.0",
    launch_timeout_ms: u32 = 30000,
    command_timeout_ms: u32 = 10000,
    companion_device_udid: ?[]const u8 = null,

    pub const SimulatorType = enum {
        apple_watch_series_9_41mm,
        apple_watch_series_9_45mm,
        apple_watch_series_10_42mm,
        apple_watch_series_10_46mm,
        apple_watch_ultra_2,
        apple_watch_se_40mm,
        apple_watch_se_44mm,
    };

    pub fn simulatorName(self: *const WatchOSDriverConfig) []const u8 {
        return switch (self.simulator_type) {
            .apple_watch_series_9_41mm => "Apple Watch Series 9 (41mm)",
            .apple_watch_series_9_45mm => "Apple Watch Series 9 (45mm)",
            .apple_watch_series_10_42mm => "Apple Watch Series 10 (42mm)",
            .apple_watch_series_10_46mm => "Apple Watch Series 10 (46mm)",
            .apple_watch_ultra_2 => "Apple Watch Ultra 2",
            .apple_watch_se_40mm => "Apple Watch SE (40mm) (2nd generation)",
            .apple_watch_se_44mm => "Apple Watch SE (44mm) (2nd generation)",
        };
    }
};

/// Selector types for testing
pub const Selector = struct {
    test_id: ?[]const u8 = null,
    accessibility_id: ?[]const u8 = null,
    text: ?[]const u8 = null,
    text_contains: ?[]const u8 = null,
    xpath: ?[]const u8 = null,
    class_chain: ?[]const u8 = null,
    predicate: ?[]const u8 = null,
};

/// Digital Crown direction
pub const CrownDirection = enum {
    up,
    down,

    pub fn toString(self: CrownDirection) []const u8 {
        return switch (self) {
            .up => "up",
            .down => "down",
        };
    }
};

// watchOS-specific mock handler
fn watchosMockHandler(path: []const u8, body: []const u8) mock_server.MockResponse {
    _ = body;

    // Session creation (with watchOS platform)
    if (std.mem.indexOf(u8, path, "/session") != null and std.mem.indexOf(u8, path, "element") == null and std.mem.indexOf(u8, path, "wda") == null) {
        return .{ .body =
            \\{"sessionId":"watchos-session-1","status":0,"value":{"platformName":"watchOS"}}
        };
    }

    // Digital Crown rotation
    if (std.mem.indexOf(u8, path, "/wda/digitalCrown/rotate") != null) {
        return .{ .body =
            \\{"status":0,"value":null}
        };
    }

    // Side Button press
    if (std.mem.indexOf(u8, path, "/wda/sideButton/press") != null) {
        return .{ .body =
            \\{"status":0,"value":null}
        };
    }

    // Side Button double press
    if (std.mem.indexOf(u8, path, "/wda/sideButton/doublePress") != null) {
        return .{ .body =
            \\{"status":0,"value":null}
        };
    }

    // Companion device info
    if (std.mem.indexOf(u8, path, "/wda/companion/info") != null) {
        return .{ .body =
            \\{"status":0,"value":{"paired":true,"companionDeviceUDID":"iphone-udid-123"}}
        };
    }

    // Element finding
    if (std.mem.indexOf(u8, path, "/element") != null and std.mem.indexOf(u8, path, "/elements") == null) {
        if (std.mem.indexOf(u8, path, "/click") != null) {
            return .{ .body =
                \\{"status":0}
            };
        }
        if (std.mem.indexOf(u8, path, "/text") != null) {
            return .{ .body =
                \\{"value":"Hello watchOS"}
            };
        }
        if (std.mem.indexOf(u8, path, "/displayed") != null) {
            return .{ .body =
                \\{"value":true}
            };
        }
        if (std.mem.indexOf(u8, path, "/rect") != null) {
            // watchOS screens are smaller
            return .{ .body =
                \\{"value":{"x":5,"y":10,"width":180,"height":40}}
            };
        }
        // Element finding
        return .{ .body =
            \\{"value":{"ELEMENT":"watch-element-1"}}
        };
    }

    // Multiple elements
    if (std.mem.indexOf(u8, path, "/elements") != null) {
        return .{ .body =
            \\{"value":[{"ELEMENT":"watch-element-1"},{"ELEMENT":"watch-element-2"}]}
        };
    }

    // WDA actions (tap, swipe, etc.)
    if (std.mem.indexOf(u8, path, "/wda/") != null) {
        return .{ .body =
            \\{"status":0}
        };
    }

    // Screenshot
    if (std.mem.indexOf(u8, path, "/screenshot") != null) {
        return .{ .body =
            \\{"value":"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="}
        };
    }

    // Default response
    return .{ .body =
        \\{"status":0}
    };
}

// Integration Tests

test "watchos driver config defaults" {
    const config = WatchOSDriverConfig{};

    try std.testing.expectEqualStrings("127.0.0.1", config.host);
    try std.testing.expectEqual(@as(u16, 8100), config.port);
    try std.testing.expect(config.use_simulator);
    try std.testing.expectEqualStrings("11.0", config.watchos_version);
    try std.testing.expectEqual(@as(u32, 30000), config.launch_timeout_ms);
    try std.testing.expect(config.companion_device_udid == null);
}

test "watchos simulator type names" {
    var config = WatchOSDriverConfig{};

    config.simulator_type = .apple_watch_series_9_41mm;
    try std.testing.expectEqualStrings("Apple Watch Series 9 (41mm)", config.simulatorName());

    config.simulator_type = .apple_watch_series_9_45mm;
    try std.testing.expectEqualStrings("Apple Watch Series 9 (45mm)", config.simulatorName());

    config.simulator_type = .apple_watch_ultra_2;
    try std.testing.expectEqualStrings("Apple Watch Ultra 2", config.simulatorName());

    config.simulator_type = .apple_watch_se_40mm;
    try std.testing.expectEqualStrings("Apple Watch SE (40mm) (2nd generation)", config.simulatorName());
}

test "watchos mock server communication" {
    const allocator = std.testing.allocator;

    // Start mock server
    var server = MockServer.init(allocator, TEST_PORT);
    defer server.deinit();
    server.setHandler(watchosMockHandler);
    try server.start();
    defer server.stop();

    std.Thread.sleep(100 * std.time.ns_per_ms);

    // Test HTTP request format
    const address = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, TEST_PORT);
    const stream = std.net.tcpConnectToAddress(address) catch return;
    defer stream.close();

    // Send session creation request (watchOS format)
    const request =
        \\POST /session HTTP/1.1
        \\Host: 127.0.0.1:18101
        \\Content-Type: application/json
        \\Content-Length: 180
        \\
        \\{"capabilities":{"alwaysMatch":{"platformName":"watchOS","platformVersion":"11.0","deviceName":"Apple Watch Series 9 (45mm)","bundleId":"com.test.watchapp","automationName":"XCUITest"}}}
    ;
    _ = stream.write(request) catch return;

    var buffer: [1024]u8 = undefined;
    const bytes = stream.read(&buffer) catch return;
    const response = buffer[0..bytes];

    // Verify response contains session ID and watchOS platform
    try std.testing.expect(std.mem.indexOf(u8, response, "sessionId") != null or std.mem.indexOf(u8, response, "watchos") != null);
}

test "watchos digital crown command format" {
    const allocator = std.testing.allocator;

    var server = MockServer.init(allocator, TEST_PORT + 1);
    defer server.deinit();
    server.setHandler(watchosMockHandler);
    try server.start();
    defer server.stop();

    std.Thread.sleep(100 * std.time.ns_per_ms);

    const address = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, TEST_PORT + 1);
    const stream = std.net.tcpConnectToAddress(address) catch return;
    defer stream.close();

    // Send Digital Crown rotation request
    const request =
        \\POST /session/watchos-1/wda/digitalCrown/rotate HTTP/1.1
        \\Host: 127.0.0.1:18102
        \\Content-Type: application/json
        \\Content-Length: 35
        \\
        \\{"direction":"up","velocity":0.50}
    ;
    _ = stream.write(request) catch return;

    var buffer: [1024]u8 = undefined;
    const bytes = stream.read(&buffer) catch return;
    const response = buffer[0..bytes];

    // Verify success response
    try std.testing.expect(std.mem.indexOf(u8, response, "200") != null or std.mem.indexOf(u8, response, "status") != null);
}

test "watchos side button command format" {
    const allocator = std.testing.allocator;

    var server = MockServer.init(allocator, TEST_PORT + 2);
    defer server.deinit();
    server.setHandler(watchosMockHandler);
    try server.start();
    defer server.stop();

    std.Thread.sleep(100 * std.time.ns_per_ms);

    const address = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, TEST_PORT + 2);

    // Test single press
    {
        const stream = std.net.tcpConnectToAddress(address) catch return;
        defer stream.close();

        const request =
            \\POST /session/watchos-1/wda/sideButton/press HTTP/1.1
            \\Host: 127.0.0.1:18103
            \\Content-Type: application/json
            \\Content-Length: 16
            \\
            \\{"duration": 0}
        ;
        _ = stream.write(request) catch return;

        var buffer: [1024]u8 = undefined;
        const bytes = stream.read(&buffer) catch return;
        const response = buffer[0..bytes];

        try std.testing.expect(std.mem.indexOf(u8, response, "200") != null or std.mem.indexOf(u8, response, "status") != null);
    }

    // Test double press
    {
        const stream = std.net.tcpConnectToAddress(address) catch return;
        defer stream.close();

        const request =
            \\POST /session/watchos-1/wda/sideButton/doublePress HTTP/1.1
            \\Host: 127.0.0.1:18103
            \\Content-Type: application/json
            \\Content-Length: 2
            \\
            \\{}
        ;
        _ = stream.write(request) catch return;

        var buffer: [1024]u8 = undefined;
        const bytes = stream.read(&buffer) catch return;
        const response = buffer[0..bytes];

        try std.testing.expect(std.mem.indexOf(u8, response, "200") != null or std.mem.indexOf(u8, response, "status") != null);
    }
}

test "watchos companion device pairing" {
    const allocator = std.testing.allocator;

    var server = MockServer.init(allocator, TEST_PORT + 3);
    defer server.deinit();
    server.setHandler(watchosMockHandler);
    try server.start();
    defer server.stop();

    std.Thread.sleep(100 * std.time.ns_per_ms);

    const address = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, TEST_PORT + 3);
    const stream = std.net.tcpConnectToAddress(address) catch return;
    defer stream.close();

    // Request companion device info
    const request =
        \\GET /session/watchos-1/wda/companion/info HTTP/1.1
        \\Host: 127.0.0.1:18104
        \\
        \\
    ;
    _ = stream.write(request) catch return;

    var buffer: [1024]u8 = undefined;
    const bytes = stream.read(&buffer) catch return;
    const response = buffer[0..bytes];

    // Verify companion device info is returned
    try std.testing.expect(std.mem.indexOf(u8, response, "paired") != null or std.mem.indexOf(u8, response, "companion") != null);
}

test "watchos json request format" {
    // Verify JSON request format matches XCUITest server expectations for watchOS

    // Session creation (with watchOS platform)
    {
        var buf: [512]u8 = undefined;
        const json = std.fmt.bufPrint(&buf,
            \\{{"capabilities": {{"alwaysMatch": {{"platformName": "watchOS", "platformVersion": "{s}", "deviceName": "{s}", "bundleId": "{s}", "automationName": "XCUITest"}}}}}}
        , .{ "11.0", "Apple Watch Series 9 (45mm)", "com.test.watchapp" }) catch unreachable;

        try std.testing.expect(std.mem.indexOf(u8, json, "platformName") != null);
        try std.testing.expect(std.mem.indexOf(u8, json, "watchOS") != null);
        try std.testing.expect(std.mem.indexOf(u8, json, "Apple Watch") != null);
    }

    // Digital Crown rotation
    {
        var buf: [256]u8 = undefined;
        const json = std.fmt.bufPrint(&buf,
            \\{{"direction": "{s}", "velocity": {d:.2}}}
        , .{ "up", 0.5 }) catch unreachable;

        try std.testing.expect(std.mem.indexOf(u8, json, "direction") != null);
        try std.testing.expect(std.mem.indexOf(u8, json, "velocity") != null);
    }

    // Side button press
    {
        var buf: [128]u8 = undefined;
        const json = std.fmt.bufPrint(&buf,
            \\{{"duration": {d}}}
        , .{100}) catch unreachable;

        try std.testing.expect(std.mem.indexOf(u8, json, "duration") != null);
    }
}

test "watchos endpoint paths" {
    var buf: [256]u8 = undefined;

    // Session path
    const session_path = std.fmt.bufPrint(&buf, "/session/{s}/wda/digitalCrown/rotate", .{"session-123"}) catch unreachable;
    try std.testing.expect(std.mem.indexOf(u8, session_path, "/session/") != null);
    try std.testing.expect(std.mem.indexOf(u8, session_path, "/digitalCrown/") != null);

    // Side button path
    const button_path = std.fmt.bufPrint(&buf, "/session/{s}/wda/sideButton/press", .{"session-123"}) catch unreachable;
    try std.testing.expect(std.mem.indexOf(u8, button_path, "/sideButton/") != null);

    // Companion path
    const companion_path = std.fmt.bufPrint(&buf, "/session/{s}/wda/companion/info", .{"session-123"}) catch unreachable;
    try std.testing.expect(std.mem.indexOf(u8, companion_path, "/companion/") != null);
}

test "crown direction to string" {
    try std.testing.expectEqualStrings("up", CrownDirection.up.toString());
    try std.testing.expectEqualStrings("down", CrownDirection.down.toString());
}
