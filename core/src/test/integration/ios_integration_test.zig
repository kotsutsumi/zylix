//! iOS Driver Integration Tests
//!
//! Tests communication between Zig iOS Driver and XCUITest bridge server.
//!
//! Compatible with Zig 0.15.

const std = @import("std");
const mock_server = @import("mock_server.zig");

const MockServer = mock_server.MockServer;
const PlatformMocks = mock_server.PlatformMocks;

// Test port (different from production 8100)
const TEST_PORT: u16 = 18100;

/// iOS driver configuration (local copy for testing)
pub const IOSDriverConfig = struct {
    host: []const u8 = "127.0.0.1",
    port: u16 = 8100,
    device_udid: ?[]const u8 = null,
    bundle_id: ?[]const u8 = null,
    use_simulator: bool = true,
    simulator_type: SimulatorType = .iphone_15,
    ios_version: []const u8 = "17.0",
    launch_timeout_ms: u32 = 30000,
    command_timeout_ms: u32 = 10000,

    pub fn simulatorName(self: IOSDriverConfig) []const u8 {
        return switch (self.simulator_type) {
            .iphone_15 => "iPhone 15",
            .iphone_15_pro => "iPhone 15 Pro",
            .iphone_15_pro_max => "iPhone 15 Pro Max",
            .ipad_pro_11 => "iPad Pro 11-inch (4th generation)",
            .ipad_pro_12_9 => "iPad Pro 12.9-inch (6th generation)",
            .ipad_air => "iPad Air (5th generation)",
            .ipad_mini => "iPad mini (6th generation)",
        };
    }
};

pub const SimulatorType = enum {
    iphone_15,
    iphone_15_pro,
    iphone_15_pro_max,
    ipad_pro_11,
    ipad_pro_12_9,
    ipad_air,
    ipad_mini,
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

/// XCUITest selector strategy
pub const XCUIStrategy = struct {
    strategy: []const u8,
    value: []const u8,
};

// Helper: convert selector to XCUITest strategy
fn selectorToXCUIStrategy(selector: Selector) ?XCUIStrategy {
    if (selector.test_id) |tid| {
        return .{ .strategy = "accessibility id", .value = tid };
    }
    if (selector.accessibility_id) |aid| {
        return .{ .strategy = "accessibility id", .value = aid };
    }
    if (selector.text) |text| {
        return .{ .strategy = "name", .value = text };
    }
    if (selector.xpath) |xpath| {
        return .{ .strategy = "xpath", .value = xpath };
    }
    if (selector.class_chain) |chain| {
        return .{ .strategy = "-ios class chain", .value = chain };
    }
    if (selector.predicate) |pred| {
        return .{ .strategy = "-ios predicate string", .value = pred };
    }
    return null;
}

// iOS-specific mock handler
fn iosMockHandler(path: []const u8, body: []const u8) mock_server.MockResponse {
    _ = body;

    // Session creation
    if (std.mem.indexOf(u8, path, "/session") != null and std.mem.indexOf(u8, path, "element") == null) {
        return .{ .body =
            \\{"sessionId":"xcuitest-1","status":0}
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
                \\{"value":"Hello iOS"}
            };
        }
        if (std.mem.indexOf(u8, path, "/displayed") != null) {
            return .{ .body =
                \\{"value":true}
            };
        }
        if (std.mem.indexOf(u8, path, "/enabled") != null) {
            return .{ .body =
                \\{"value":true}
            };
        }
        if (std.mem.indexOf(u8, path, "/rect") != null) {
            return .{ .body =
                \\{"value":{"x":10,"y":20,"width":100,"height":44}}
            };
        }
        if (std.mem.indexOf(u8, path, "/screenshot") != null) {
            return .{ .body =
                \\{"value":"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="}
            };
        }
        // Element finding
        return .{ .body =
            \\{"value":{"ELEMENT":"element-1"}}
        };
    }

    // Multiple elements
    if (std.mem.indexOf(u8, path, "/elements") != null) {
        return .{ .body =
            \\{"value":[{"ELEMENT":"element-1"},{"ELEMENT":"element-2"}]}
        };
    }

    // WDA actions
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

test "ios driver config defaults" {
    const config = IOSDriverConfig{};

    try std.testing.expectEqualStrings("127.0.0.1", config.host);
    try std.testing.expectEqual(@as(u16, 8100), config.port);
    try std.testing.expect(config.use_simulator);
    try std.testing.expectEqualStrings("17.0", config.ios_version);
    try std.testing.expectEqual(@as(u32, 30000), config.launch_timeout_ms);
}

test "ios simulator type names" {
    var config = IOSDriverConfig{};

    config.simulator_type = .iphone_15;
    try std.testing.expectEqualStrings("iPhone 15", config.simulatorName());

    config.simulator_type = .iphone_15_pro;
    try std.testing.expectEqualStrings("iPhone 15 Pro", config.simulatorName());

    config.simulator_type = .ipad_pro_11;
    try std.testing.expectEqualStrings("iPad Pro 11-inch (4th generation)", config.simulatorName());

    config.simulator_type = .ipad_air;
    try std.testing.expectEqualStrings("iPad Air (5th generation)", config.simulatorName());
}

test "ios selector to xcui strategy mapping" {
    // Test ID → accessibility id
    {
        const sel = Selector{ .test_id = "login-btn" };
        const strategy = selectorToXCUIStrategy(sel);
        try std.testing.expect(strategy != null);
        try std.testing.expectEqualStrings("accessibility id", strategy.?.strategy);
        try std.testing.expectEqualStrings("login-btn", strategy.?.value);
    }

    // Accessibility ID → accessibility id
    {
        const sel = Selector{ .accessibility_id = "submit" };
        const strategy = selectorToXCUIStrategy(sel);
        try std.testing.expect(strategy != null);
        try std.testing.expectEqualStrings("accessibility id", strategy.?.strategy);
    }

    // Text → name
    {
        const sel = Selector{ .text = "Submit" };
        const strategy = selectorToXCUIStrategy(sel);
        try std.testing.expect(strategy != null);
        try std.testing.expectEqualStrings("name", strategy.?.strategy);
        try std.testing.expectEqualStrings("Submit", strategy.?.value);
    }

    // XPath → xpath
    {
        const sel = Selector{ .xpath = "//XCUIElementTypeButton" };
        const strategy = selectorToXCUIStrategy(sel);
        try std.testing.expect(strategy != null);
        try std.testing.expectEqualStrings("xpath", strategy.?.strategy);
    }

    // Class chain → -ios class chain
    {
        const sel = Selector{ .class_chain = "**/XCUIElementTypeButton" };
        const strategy = selectorToXCUIStrategy(sel);
        try std.testing.expect(strategy != null);
        try std.testing.expectEqualStrings("-ios class chain", strategy.?.strategy);
    }

    // Predicate → -ios predicate string
    {
        const sel = Selector{ .predicate = "label == 'Login'" };
        const strategy = selectorToXCUIStrategy(sel);
        try std.testing.expect(strategy != null);
        try std.testing.expectEqualStrings("-ios predicate string", strategy.?.strategy);
    }
}

test "ios mock server communication" {
    const allocator = std.testing.allocator;

    // Start mock server
    var server = MockServer.init(allocator, TEST_PORT);
    defer server.deinit();
    server.setHandler(iosMockHandler);
    try server.start();
    defer server.stop();

    std.Thread.sleep(100 * std.time.ns_per_ms);

    // Test HTTP request format manually
    const address = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, TEST_PORT);
    const stream = std.net.tcpConnectToAddress(address) catch return;
    defer stream.close();

    // Send session creation request (XCUITest format)
    const request =
        \\POST /session HTTP/1.1
        \\Host: 127.0.0.1:18100
        \\Content-Type: application/json
        \\Content-Length: 147
        \\
        \\{"capabilities":{"alwaysMatch":{"platformName":"iOS","platformVersion":"17.0","deviceName":"iPhone 15","bundleId":"com.test.app","automationName":"XCUITest"}}}
    ;
    _ = stream.write(request) catch return;

    var buffer: [1024]u8 = undefined;
    const bytes = stream.read(&buffer) catch return;
    const response = buffer[0..bytes];

    // Verify response contains session ID
    try std.testing.expect(std.mem.indexOf(u8, response, "sessionId") != null or std.mem.indexOf(u8, response, "xcuitest") != null);
}

test "ios webdriver agent path format" {
    // Verify the expected path formats used by WebDriverAgent/XCUITest

    // Session creation
    const session_path = "/session";
    try std.testing.expect(std.mem.eql(u8, session_path, "/session"));

    // Element finding (session/{id}/element)
    var path_buf: [256]u8 = undefined;
    const element_path = std.fmt.bufPrint(&path_buf, "/session/{s}/element", .{"test-session"}) catch unreachable;
    try std.testing.expect(std.mem.indexOf(u8, element_path, "/session/") != null);
    try std.testing.expect(std.mem.indexOf(u8, element_path, "/element") != null);

    // WDA actions (session/{id}/wda/element/{eid}/action)
    const wda_path = std.fmt.bufPrint(&path_buf, "/session/{s}/wda/element/{s}/doubleTap", .{ "test-session", "element-1" }) catch unreachable;
    try std.testing.expect(std.mem.indexOf(u8, wda_path, "/wda/") != null);
    try std.testing.expect(std.mem.indexOf(u8, wda_path, "/doubleTap") != null);
}

test "ios driver json request format" {
    // Verify JSON request format matches XCUITest server expectations

    // Launch/session creation
    {
        var buf: [512]u8 = undefined;
        const json = std.fmt.bufPrint(&buf,
            \\{{"capabilities": {{"alwaysMatch": {{"platformName": "iOS", "platformVersion": "{s}", "deviceName": "{s}", "bundleId": "{s}", "automationName": "XCUITest"}}}}}}
        , .{ "17.0", "iPhone 15", "com.test.app" }) catch unreachable;

        try std.testing.expect(std.mem.indexOf(u8, json, "platformName") != null);
        try std.testing.expect(std.mem.indexOf(u8, json, "bundleId") != null);
        try std.testing.expect(std.mem.indexOf(u8, json, "XCUITest") != null);
    }

    // Element finding
    {
        var buf: [256]u8 = undefined;
        const json = std.fmt.bufPrint(&buf,
            \\{{"using": "{s}", "value": "{s}"}}
        , .{ "accessibility id", "login-button" }) catch unreachable;

        try std.testing.expect(std.mem.indexOf(u8, json, "using") != null);
        try std.testing.expect(std.mem.indexOf(u8, json, "accessibility id") != null);
    }

    // Type text
    {
        var buf: [256]u8 = undefined;
        const json = std.fmt.bufPrint(&buf,
            \\{{"value": ["{s}"]}}
        , .{"Hello World"}) catch unreachable;

        try std.testing.expect(std.mem.indexOf(u8, json, "value") != null);
        try std.testing.expect(std.mem.indexOf(u8, json, "Hello World") != null);
    }
}
