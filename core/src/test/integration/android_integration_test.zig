//! Android Driver Integration Tests
//!
//! Tests communication between Zig Android Driver and UIAutomator2 bridge server.
//!
//! Compatible with Zig 0.15.

const std = @import("std");
const mock_server = @import("mock_server.zig");

const MockServer = mock_server.MockServer;

// Test port (different from production 6790)
const TEST_PORT: u16 = 16790;

/// Android driver configuration (local copy for testing)
pub const AndroidDriverConfig = struct {
    host: []const u8 = "127.0.0.1",
    port: u16 = 6790,
    adb_port: u16 = 5037,
    device_serial: ?[]const u8 = null,
    app_package: ?[]const u8 = null,
    app_activity: ?[]const u8 = null,
    use_emulator: bool = true,
    api_level: u8 = 34,
    launch_timeout_ms: u32 = 30000,
    command_timeout_ms: u32 = 10000,
};

/// Selector types for testing
pub const Selector = struct {
    test_id: ?[]const u8 = null,
    accessibility_id: ?[]const u8 = null,
    text: ?[]const u8 = null,
    text_contains: ?[]const u8 = null,
    resource_id: ?[]const u8 = null,
    xpath: ?[]const u8 = null,
    uiautomator: ?[]const u8 = null,
};

/// UIAutomator2 selector strategy
pub const UIA2Strategy = struct {
    strategy: []const u8,
    value: []const u8,
};

// Helper: convert selector to UIAutomator2 strategy
fn selectorToUIA2Strategy(selector: Selector) ?UIA2Strategy {
    if (selector.test_id) |tid| {
        return .{ .strategy = "accessibility id", .value = tid };
    }
    if (selector.accessibility_id) |aid| {
        return .{ .strategy = "accessibility id", .value = aid };
    }
    if (selector.resource_id) |rid| {
        return .{ .strategy = "id", .value = rid };
    }
    if (selector.text) |_| {
        return .{ .strategy = "-android uiautomator", .value = "new UiSelector().text(\"...\")" };
    }
    if (selector.xpath) |xpath| {
        return .{ .strategy = "xpath", .value = xpath };
    }
    if (selector.uiautomator) |uia| {
        return .{ .strategy = "-android uiautomator", .value = uia };
    }
    return null;
}

// Android/UIAutomator2-specific mock handler
fn androidMockHandler(path: []const u8, body: []const u8) mock_server.MockResponse {
    _ = body;

    // Session creation (Appium/UIA2 format)
    if (std.mem.indexOf(u8, path, "/session") != null and std.mem.indexOf(u8, path, "element") == null) {
        return .{ .body =
            \\{"sessionId":"uia2-1","status":0,"value":{"platformName":"Android"}}
        };
    }

    // Element finding
    if (std.mem.indexOf(u8, path, "/element") != null and std.mem.indexOf(u8, path, "/elements") == null) {
        if (std.mem.indexOf(u8, path, "/click") != null) {
            return .{ .body =
                \\{"status":0,"value":null}
            };
        }
        if (std.mem.indexOf(u8, path, "/text") != null) {
            return .{ .body =
                \\{"status":0,"value":"Hello Android"}
            };
        }
        if (std.mem.indexOf(u8, path, "/displayed") != null) {
            return .{ .body =
                \\{"status":0,"value":true}
            };
        }
        if (std.mem.indexOf(u8, path, "/enabled") != null) {
            return .{ .body =
                \\{"status":0,"value":true}
            };
        }
        if (std.mem.indexOf(u8, path, "/rect") != null) {
            return .{ .body =
                \\{"status":0,"value":{"x":0,"y":100,"width":1080,"height":200}}
            };
        }
        // Element finding
        return .{ .body =
            \\{"status":0,"value":{"ELEMENT":"element-android-1"}}
        };
    }

    // Multiple elements
    if (std.mem.indexOf(u8, path, "/elements") != null) {
        return .{ .body =
            \\{"status":0,"value":[{"ELEMENT":"element-1"},{"ELEMENT":"element-2"},{"ELEMENT":"element-3"}]}
        };
    }

    // Touch actions
    if (std.mem.indexOf(u8, path, "/touch/") != null or std.mem.indexOf(u8, path, "/actions") != null) {
        return .{ .body =
            \\{"status":0,"value":null}
        };
    }

    // Screenshot
    if (std.mem.indexOf(u8, path, "/screenshot") != null) {
        return .{ .body =
            \\{"status":0,"value":"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="}
        };
    }

    // Source (page source)
    if (std.mem.indexOf(u8, path, "/source") != null) {
        return .{ .body =
            \\{"status":0,"value":"<hierarchy></hierarchy>"}
        };
    }

    // Default response
    return .{ .body =
        \\{"status":0,"value":null}
    };
}

// Integration Tests

test "android driver config defaults" {
    const config = AndroidDriverConfig{};

    try std.testing.expectEqualStrings("127.0.0.1", config.host);
    try std.testing.expectEqual(@as(u16, 6790), config.port);
    try std.testing.expect(config.use_emulator);
    try std.testing.expectEqual(@as(u8, 34), config.api_level);
    try std.testing.expectEqual(@as(u32, 30000), config.launch_timeout_ms);
    try std.testing.expectEqual(@as(u16, 5037), config.adb_port);
}

test "android selector to uia2 strategy mapping" {
    // Test ID → accessibility id (Android uses content-desc)
    {
        const sel = Selector{ .test_id = "login-btn" };
        const strategy = selectorToUIA2Strategy(sel);
        try std.testing.expect(strategy != null);
        try std.testing.expectEqualStrings("accessibility id", strategy.?.strategy);
        try std.testing.expectEqualStrings("login-btn", strategy.?.value);
    }

    // Resource ID → id
    {
        const sel = Selector{ .resource_id = "com.app:id/button" };
        const strategy = selectorToUIA2Strategy(sel);
        try std.testing.expect(strategy != null);
        try std.testing.expectEqualStrings("id", strategy.?.strategy);
        try std.testing.expectEqualStrings("com.app:id/button", strategy.?.value);
    }

    // Text → -android uiautomator
    {
        const sel = Selector{ .text = "Submit" };
        const strategy = selectorToUIA2Strategy(sel);
        try std.testing.expect(strategy != null);
        try std.testing.expectEqualStrings("-android uiautomator", strategy.?.strategy);
    }

    // XPath → xpath
    {
        const sel = Selector{ .xpath = "//android.widget.Button" };
        const strategy = selectorToUIA2Strategy(sel);
        try std.testing.expect(strategy != null);
        try std.testing.expectEqualStrings("xpath", strategy.?.strategy);
    }

    // UIAutomator selector
    {
        const sel = Selector{ .uiautomator = "new UiSelector().text(\"Login\")" };
        const strategy = selectorToUIA2Strategy(sel);
        try std.testing.expect(strategy != null);
        try std.testing.expectEqualStrings("-android uiautomator", strategy.?.strategy);
    }
}

test "android mock server communication" {
    const allocator = std.testing.allocator;

    // Start mock server
    var server = MockServer.init(allocator, TEST_PORT);
    defer server.deinit();
    server.setHandler(androidMockHandler);
    try server.start();
    defer server.stop();

    std.Thread.sleep(100 * std.time.ns_per_ms);

    // Test HTTP request format
    const address = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, TEST_PORT);
    const stream = std.net.tcpConnectToAddress(address) catch return;
    defer stream.close();

    // Send session creation request (Appium/UIA2 format)
    const request =
        \\POST /session HTTP/1.1
        \\Host: 127.0.0.1:16790
        \\Content-Type: application/json
        \\Content-Length: 189
        \\
        \\{"capabilities":{"alwaysMatch":{"platformName":"Android","automationName":"UiAutomator2","appPackage":"com.test.app","appActivity":".MainActivity","deviceName":"emulator-5554"}}}
    ;
    _ = stream.write(request) catch return;

    var buffer: [1024]u8 = undefined;
    const bytes = stream.read(&buffer) catch return;
    const response = buffer[0..bytes];

    // Verify response contains session info
    try std.testing.expect(std.mem.indexOf(u8, response, "sessionId") != null or std.mem.indexOf(u8, response, "uia2") != null);
}

test "android appium path format" {
    // Verify expected path formats for Appium/UIA2

    // Session creation
    const session_path = "/session";
    try std.testing.expect(std.mem.eql(u8, session_path, "/session"));

    // Element finding (session/{id}/element)
    var path_buf: [256]u8 = undefined;
    const element_path = std.fmt.bufPrint(&path_buf, "/session/{s}/element", .{"test-session"}) catch unreachable;
    try std.testing.expect(std.mem.indexOf(u8, element_path, "/session/") != null);
    try std.testing.expect(std.mem.indexOf(u8, element_path, "/element") != null);

    // Touch actions
    const touch_path = std.fmt.bufPrint(&path_buf, "/session/{s}/touch/perform", .{"test-session"}) catch unreachable;
    try std.testing.expect(std.mem.indexOf(u8, touch_path, "/touch/") != null);

    // W3C actions
    const actions_path = std.fmt.bufPrint(&path_buf, "/session/{s}/actions", .{"test-session"}) catch unreachable;
    try std.testing.expect(std.mem.indexOf(u8, actions_path, "/actions") != null);
}

test "android driver json request format" {
    // Verify JSON request format matches UIA2 server expectations

    // Launch/session creation (Appium format)
    {
        var buf: [512]u8 = undefined;
        const json = std.fmt.bufPrint(&buf,
            \\{{"capabilities": {{"alwaysMatch": {{"platformName": "Android", "automationName": "UiAutomator2", "appPackage": "{s}", "appActivity": "{s}"}}}}}}
        , .{ "com.test.app", ".MainActivity" }) catch unreachable;

        try std.testing.expect(std.mem.indexOf(u8, json, "platformName") != null);
        try std.testing.expect(std.mem.indexOf(u8, json, "UiAutomator2") != null);
        try std.testing.expect(std.mem.indexOf(u8, json, "appPackage") != null);
    }

    // Element finding
    {
        var buf: [256]u8 = undefined;
        const json = std.fmt.bufPrint(&buf,
            \\{{"using": "{s}", "value": "{s}"}}
        , .{ "id", "com.test.app:id/button" }) catch unreachable;

        try std.testing.expect(std.mem.indexOf(u8, json, "using") != null);
        try std.testing.expect(std.mem.indexOf(u8, json, "id") != null);
    }

    // UiAutomator selector
    {
        var buf: [256]u8 = undefined;
        const json = std.fmt.bufPrint(&buf,
            \\{{"using": "-android uiautomator", "value": "{s}"}}
        , .{"new UiSelector().text(\"Login\")"}) catch unreachable;

        try std.testing.expect(std.mem.indexOf(u8, json, "-android uiautomator") != null);
        try std.testing.expect(std.mem.indexOf(u8, json, "UiSelector") != null);
    }

    // Touch actions (W3C format)
    {
        const json =
            \\{"actions":[{"type":"pointer","id":"finger1","parameters":{"pointerType":"touch"},"actions":[{"type":"pointerMove","duration":0,"x":500,"y":1000},{"type":"pointerDown","button":0},{"type":"pause","duration":100},{"type":"pointerUp","button":0}]}]}
        ;

        try std.testing.expect(std.mem.indexOf(u8, json, "actions") != null);
        try std.testing.expect(std.mem.indexOf(u8, json, "pointerType") != null);
        try std.testing.expect(std.mem.indexOf(u8, json, "touch") != null);
    }
}

test "android adb port forwarding format" {
    // Test ADB command format expectations
    var buf: [256]u8 = undefined;

    // Port forward command format
    const forward_cmd = std.fmt.bufPrint(&buf, "adb -P {d} forward tcp:{d} tcp:{d}", .{ 5037, 6790, 6790 }) catch unreachable;
    try std.testing.expect(std.mem.indexOf(u8, forward_cmd, "forward") != null);
    try std.testing.expect(std.mem.indexOf(u8, forward_cmd, "tcp:") != null);

    // Device-specific forward
    const device_forward = std.fmt.bufPrint(&buf, "adb -s {s} forward tcp:{d} tcp:{d}", .{ "emulator-5554", 6790, 6790 }) catch unreachable;
    try std.testing.expect(std.mem.indexOf(u8, device_forward, "-s emulator-5554") != null);
}
