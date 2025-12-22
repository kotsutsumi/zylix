// Zylix Test Framework - iOS Driver
// XCUITest bridge for iOS platform E2E testing

const std = @import("std");
const driver = @import("driver.zig");
const Selector = @import("selector.zig").Selector;

const Driver = driver.Driver;
const DriverVTable = driver.DriverVTable;
const DriverError = driver.DriverError;
const Platform = driver.Platform;
const AppConfig = driver.AppConfig;
const ElementHandle = driver.ElementHandle;
const Rect = driver.Rect;
const SwipeDirection = driver.SwipeDirection;
const ScrollDirection = driver.ScrollDirection;
const Screenshot = driver.Screenshot;

/// iOS driver configuration
pub const IOSDriverConfig = struct {
    /// XCUITest server host
    host: []const u8 = "127.0.0.1",
    /// XCUITest server port
    port: u16 = 8100,
    /// Device UDID (null for simulator)
    device_udid: ?[]const u8 = null,
    /// Use simulator
    use_simulator: bool = true,
    /// Simulator type
    simulator_type: SimulatorType = .iphone_15,
    /// iOS version
    ios_version: []const u8 = "17.0",
    /// Wait for app launch timeout (ms)
    launch_timeout_ms: u32 = 30000,
    /// Default element timeout (ms)
    element_timeout_ms: u32 = 10000,

    pub const SimulatorType = enum {
        iphone_15,
        iphone_15_pro,
        iphone_15_pro_max,
        iphone_se,
        ipad_pro_11,
        ipad_pro_12_9,
        ipad_air,
    };

    pub fn simulatorName(self: *const IOSDriverConfig) []const u8 {
        return switch (self.simulator_type) {
            .iphone_15 => "iPhone 15",
            .iphone_15_pro => "iPhone 15 Pro",
            .iphone_15_pro_max => "iPhone 15 Pro Max",
            .iphone_se => "iPhone SE (3rd generation)",
            .ipad_pro_11 => "iPad Pro 11-inch (4th generation)",
            .ipad_pro_12_9 => "iPad Pro 12.9-inch (6th generation)",
            .ipad_air => "iPad Air (5th generation)",
        };
    }
};

/// iOS driver context
pub const IOSDriverContext = struct {
    allocator: std.mem.Allocator,
    config: IOSDriverConfig,
    session_id: ?[]const u8 = null,
    http_client: std.http.Client,
    elements: std.StringHashMap([]const u8),
    element_counter: u64 = 0,

    pub fn init(allocator: std.mem.Allocator, config: IOSDriverConfig) IOSDriverContext {
        return .{
            .allocator = allocator,
            .config = config,
            .http_client = std.http.Client{ .allocator = allocator },
            .elements = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *IOSDriverContext) void {
        if (self.session_id) |sid| {
            self.allocator.free(sid);
        }
        var it = self.elements.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.elements.deinit();
        self.http_client.deinit();
    }

    fn storeElement(self: *IOSDriverContext, xcui_element_id: []const u8) ![]const u8 {
        self.element_counter += 1;
        const id = try std.fmt.allocPrint(self.allocator, "{d}", .{self.element_counter});
        const stored_xcui_id = try self.allocator.dupe(u8, xcui_element_id);
        try self.elements.put(id, stored_xcui_id);
        return id;
    }

    fn getXCUIElementId(self: *IOSDriverContext, element_id: []const u8) ?[]const u8 {
        return self.elements.get(element_id);
    }
};

/// Create iOS driver with configuration
pub fn createIOSDriver(allocator: std.mem.Allocator, config: IOSDriverConfig) !Driver {
    const ctx = try allocator.create(IOSDriverContext);
    ctx.* = IOSDriverContext.init(allocator, config);

    return Driver{
        .vtable = &ios_driver_vtable,
        .context = ctx,
        .allocator = allocator,
        .platform = .ios,
    };
}

// VTable implementation
pub const ios_driver_vtable = DriverVTable{
    .launch = iosLaunch,
    .terminate = iosTerminate,
    .findElement = iosFindElement,
    .findElements = iosFindElements,
    .tap = iosTap,
    .doubleTap = iosDoubleTap,
    .longPress = iosLongPress,
    .typeText = iosTypeText,
    .clearText = iosClearText,
    .swipe = iosSwipe,
    .scroll = iosScroll,
    .exists = iosExists,
    .isVisible = iosIsVisible,
    .isEnabled = iosIsEnabled,
    .getText = iosGetText,
    .getAttribute = iosGetAttribute,
    .getRect = iosGetRect,
    .takeScreenshot = iosTakeScreenshot,
    .takeElementScreenshot = iosTakeElementScreenshot,
    .waitForElement = iosWaitForElement,
    .waitForElementHidden = iosWaitForElementHidden,
    .deinit = iosDeinit,
};

fn iosLaunch(ctx: *anyopaque, config: AppConfig) DriverError!void {
    const self: *IOSDriverContext = @ptrCast(@alignCast(ctx));

    // Build WebDriverAgent session request
    var json_buf: [4096]u8 = undefined;
    const json = std.fmt.bufPrint(&json_buf,
        \\{{"capabilities": {{
        \\  "alwaysMatch": {{
        \\    "platformName": "iOS",
        \\    "platformVersion": "{s}",
        \\    "deviceName": "{s}",
        \\    "bundleId": "{s}",
        \\    "automationName": "XCUITest"
        \\  }}
        \\}}}}
    , .{
        self.config.ios_version,
        if (self.config.device_udid) |_| "Device" else self.config.simulatorName(),
        config.app_id,
    }) catch return DriverError.ConnectionFailed;

    const response = self.sendRequest("/session", json) catch return DriverError.ConnectionFailed;
    defer self.allocator.free(response);

    // Parse session ID from response
    const session_id = parseSessionId(self.allocator, response) catch return DriverError.LaunchFailed;
    self.session_id = session_id;
}

fn iosTerminate(ctx: *anyopaque) DriverError!void {
    const self: *IOSDriverContext = @ptrCast(@alignCast(ctx));

    if (self.session_id) |sid| {
        var path_buf: [256]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "/session/{s}", .{sid}) catch return;
        _ = self.sendDeleteRequest(path) catch {};
        self.allocator.free(sid);
        self.session_id = null;
    }
}

fn iosFindElement(ctx: *anyopaque, selector: Selector) DriverError!?ElementHandle {
    const self: *IOSDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;

    const strategy_and_value = selectorToXCUIStrategy(selector) orelse return null;

    var json_buf: [1024]u8 = undefined;
    const json = std.fmt.bufPrint(&json_buf,
        \\{{"using": "{s}", "value": "{s}"}}
    , .{ strategy_and_value.strategy, strategy_and_value.value }) catch return DriverError.InvalidSelector;

    var path_buf: [256]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/element", .{sid}) catch return DriverError.InvalidSelector;

    const response = self.sendRequest(path, json) catch return null;
    defer self.allocator.free(response);

    const element_id = parseElementId(self.allocator, response) catch return null;
    defer self.allocator.free(element_id);

    const stored_id = self.storeElement(element_id) catch return DriverError.OutOfMemory;
    return ElementHandle{ .id = stored_id };
}

fn iosFindElements(ctx: *anyopaque, selector: Selector, out_handles: []ElementHandle) DriverError!usize {
    const self: *IOSDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;

    const strategy_and_value = selectorToXCUIStrategy(selector) orelse return 0;

    var json_buf: [1024]u8 = undefined;
    const json = std.fmt.bufPrint(&json_buf,
        \\{{"using": "{s}", "value": "{s}"}}
    , .{ strategy_and_value.strategy, strategy_and_value.value }) catch return DriverError.InvalidSelector;

    var path_buf: [256]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/elements", .{sid}) catch return DriverError.InvalidSelector;

    const response = self.sendRequest(path, json) catch return 0;
    defer self.allocator.free(response);

    return parseElementIds(self, response, out_handles) catch return 0;
}

fn iosTap(ctx: *anyopaque, handle: ElementHandle) DriverError!void {
    const self: *IOSDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;
    const xcui_id = self.getXCUIElementId(handle.id) orelse return DriverError.ElementNotFound;

    var path_buf: [512]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/element/{s}/click", .{ sid, xcui_id }) catch return DriverError.InvalidSelector;

    _ = self.sendRequest(path, "{}") catch return DriverError.ActionFailed;
}

fn iosDoubleTap(ctx: *anyopaque, handle: ElementHandle) DriverError!void {
    const self: *IOSDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;
    const xcui_id = self.getXCUIElementId(handle.id) orelse return DriverError.ElementNotFound;

    var path_buf: [512]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/wda/element/{s}/doubleTap", .{ sid, xcui_id }) catch return DriverError.InvalidSelector;

    _ = self.sendRequest(path, "{}") catch return DriverError.ActionFailed;
}

fn iosLongPress(ctx: *anyopaque, handle: ElementHandle, duration_ms: u32) DriverError!void {
    const self: *IOSDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;
    const xcui_id = self.getXCUIElementId(handle.id) orelse return DriverError.ElementNotFound;

    var json_buf: [256]u8 = undefined;
    const duration_sec: f64 = @as(f64, @floatFromInt(duration_ms)) / 1000.0;
    const json = std.fmt.bufPrint(&json_buf,
        \\{{"duration": {d:.3}}}
    , .{duration_sec}) catch return DriverError.ActionFailed;

    var path_buf: [512]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/wda/element/{s}/touchAndHold", .{ sid, xcui_id }) catch return DriverError.InvalidSelector;

    _ = self.sendRequest(path, json) catch return DriverError.ActionFailed;
}

fn iosTypeText(ctx: *anyopaque, handle: ElementHandle, text: []const u8) DriverError!void {
    const self: *IOSDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;
    const xcui_id = self.getXCUIElementId(handle.id) orelse return DriverError.ElementNotFound;

    var json_buf: [4096]u8 = undefined;
    const json = std.fmt.bufPrint(&json_buf,
        \\{{"value": ["{s}"]}}
    , .{text}) catch return DriverError.ActionFailed;

    var path_buf: [512]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/element/{s}/value", .{ sid, xcui_id }) catch return DriverError.InvalidSelector;

    _ = self.sendRequest(path, json) catch return DriverError.ActionFailed;
}

fn iosClearText(ctx: *anyopaque, handle: ElementHandle) DriverError!void {
    const self: *IOSDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;
    const xcui_id = self.getXCUIElementId(handle.id) orelse return DriverError.ElementNotFound;

    var path_buf: [512]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/element/{s}/clear", .{ sid, xcui_id }) catch return DriverError.InvalidSelector;

    _ = self.sendRequest(path, "{}") catch return DriverError.ActionFailed;
}

fn iosSwipe(ctx: *anyopaque, handle: ElementHandle, direction: SwipeDirection) DriverError!void {
    const self: *IOSDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;
    const xcui_id = self.getXCUIElementId(handle.id) orelse return DriverError.ElementNotFound;

    const dir_str = switch (direction) {
        .up => "up",
        .down => "down",
        .left => "left",
        .right => "right",
    };

    var json_buf: [256]u8 = undefined;
    const json = std.fmt.bufPrint(&json_buf,
        \\{{"direction": "{s}"}}
    , .{dir_str}) catch return DriverError.ActionFailed;

    var path_buf: [512]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/wda/element/{s}/swipe", .{ sid, xcui_id }) catch return DriverError.InvalidSelector;

    _ = self.sendRequest(path, json) catch return DriverError.ActionFailed;
}

fn iosScroll(ctx: *anyopaque, handle: ElementHandle, direction: ScrollDirection, amount: f32) DriverError!void {
    const self: *IOSDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;
    const xcui_id = self.getXCUIElementId(handle.id) orelse return DriverError.ElementNotFound;

    const dir_str = switch (direction) {
        .up => "up",
        .down => "down",
        .left => "left",
        .right => "right",
    };

    var json_buf: [256]u8 = undefined;
    const json = std.fmt.bufPrint(&json_buf,
        \\{{"direction": "{s}", "distance": {d:.2}}}
    , .{ dir_str, amount }) catch return DriverError.ActionFailed;

    var path_buf: [512]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/wda/element/{s}/scroll", .{ sid, xcui_id }) catch return DriverError.InvalidSelector;

    _ = self.sendRequest(path, json) catch return DriverError.ActionFailed;
}

fn iosExists(ctx: *anyopaque, handle: ElementHandle) DriverError!bool {
    const self: *IOSDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;
    const xcui_id = self.getXCUIElementId(handle.id) orelse return false;

    var path_buf: [512]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/element/{s}/displayed", .{ sid, xcui_id }) catch return false;

    const response = self.sendGetRequest(path) catch return false;
    defer self.allocator.free(response);

    return parseBooleanValue(response);
}

fn iosIsVisible(ctx: *anyopaque, handle: ElementHandle) DriverError!bool {
    const self: *IOSDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;
    const xcui_id = self.getXCUIElementId(handle.id) orelse return false;

    var path_buf: [512]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/element/{s}/displayed", .{ sid, xcui_id }) catch return false;

    const response = self.sendGetRequest(path) catch return false;
    defer self.allocator.free(response);

    return parseBooleanValue(response);
}

fn iosIsEnabled(ctx: *anyopaque, handle: ElementHandle) DriverError!bool {
    const self: *IOSDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;
    const xcui_id = self.getXCUIElementId(handle.id) orelse return false;

    var path_buf: [512]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/element/{s}/enabled", .{ sid, xcui_id }) catch return false;

    const response = self.sendGetRequest(path) catch return false;
    defer self.allocator.free(response);

    return parseBooleanValue(response);
}

fn iosGetText(ctx: *anyopaque, handle: ElementHandle, buf: []u8) DriverError![]const u8 {
    const self: *IOSDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;
    const xcui_id = self.getXCUIElementId(handle.id) orelse return DriverError.ElementNotFound;

    var path_buf: [512]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/element/{s}/text", .{ sid, xcui_id }) catch return DriverError.InvalidSelector;

    const response = self.sendGetRequest(path) catch return DriverError.ActionFailed;
    defer self.allocator.free(response);

    return parseStringValue(response, buf);
}

fn iosGetAttribute(ctx: *anyopaque, handle: ElementHandle, name: []const u8, buf: []u8) DriverError![]const u8 {
    const self: *IOSDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;
    const xcui_id = self.getXCUIElementId(handle.id) orelse return DriverError.ElementNotFound;

    var path_buf: [512]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/element/{s}/attribute/{s}", .{ sid, xcui_id, name }) catch return DriverError.InvalidSelector;

    const response = self.sendGetRequest(path) catch return DriverError.ActionFailed;
    defer self.allocator.free(response);

    return parseStringValue(response, buf);
}

fn iosGetRect(ctx: *anyopaque, handle: ElementHandle) DriverError!Rect {
    const self: *IOSDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;
    const xcui_id = self.getXCUIElementId(handle.id) orelse return DriverError.ElementNotFound;

    var path_buf: [512]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/element/{s}/rect", .{ sid, xcui_id }) catch return DriverError.InvalidSelector;

    const response = self.sendGetRequest(path) catch return DriverError.ActionFailed;
    defer self.allocator.free(response);

    return parseRect(response);
}

fn iosTakeScreenshot(ctx: *anyopaque) DriverError!Screenshot {
    const self: *IOSDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;

    var path_buf: [256]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/screenshot", .{sid}) catch return DriverError.ActionFailed;

    const response = self.sendGetRequest(path) catch return DriverError.ActionFailed;
    defer self.allocator.free(response);

    return parseScreenshot(self.allocator, response);
}

fn iosTakeElementScreenshot(ctx: *anyopaque, handle: ElementHandle) DriverError!Screenshot {
    const self: *IOSDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;
    const xcui_id = self.getXCUIElementId(handle.id) orelse return DriverError.ElementNotFound;

    var path_buf: [512]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/element/{s}/screenshot", .{ sid, xcui_id }) catch return DriverError.InvalidSelector;

    const response = self.sendGetRequest(path) catch return DriverError.ActionFailed;
    defer self.allocator.free(response);

    return parseScreenshot(self.allocator, response);
}

fn iosWaitForElement(ctx: *anyopaque, selector: Selector, timeout_ms: u32) DriverError!?ElementHandle {
    const self: *IOSDriverContext = @ptrCast(@alignCast(ctx));
    const start = std.time.milliTimestamp();
    const timeout: i64 = @intCast(timeout_ms);

    while (std.time.milliTimestamp() - start < timeout) {
        if (try iosFindElement(ctx, selector)) |handle| {
            if (try iosIsVisible(ctx, handle)) {
                return handle;
            }
        }
        std.time.sleep(100 * std.time.ns_per_ms);
    }

    _ = self;
    return null;
}

fn iosWaitForElementHidden(ctx: *anyopaque, selector: Selector, timeout_ms: u32) DriverError!bool {
    const self: *IOSDriverContext = @ptrCast(@alignCast(ctx));
    const start = std.time.milliTimestamp();
    const timeout: i64 = @intCast(timeout_ms);

    while (std.time.milliTimestamp() - start < timeout) {
        if (try iosFindElement(ctx, selector)) |handle| {
            if (!try iosIsVisible(ctx, handle)) {
                return true;
            }
        } else {
            return true;
        }
        std.time.sleep(100 * std.time.ns_per_ms);
    }

    _ = self;
    return false;
}

fn iosDeinit(ctx: *anyopaque) void {
    const self: *IOSDriverContext = @ptrCast(@alignCast(ctx));
    self.deinit();
    self.allocator.destroy(self);
}

// Helper functions

const StrategyAndValue = struct {
    strategy: []const u8,
    value: []const u8,
};

fn selectorToXCUIStrategy(selector: Selector) ?StrategyAndValue {
    if (selector.test_id) |id| {
        return .{ .strategy = "accessibility id", .value = id };
    }
    if (selector.accessibility_id) |id| {
        return .{ .strategy = "accessibility id", .value = id };
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

fn parseSessionId(allocator: std.mem.Allocator, response: []const u8) ![]const u8 {
    // Simple JSON parsing for session ID
    const key = "\"sessionId\":\"";
    if (std.mem.indexOf(u8, response, key)) |start| {
        const value_start = start + key.len;
        if (std.mem.indexOfPos(u8, response, value_start, "\"")) |end| {
            return try allocator.dupe(u8, response[value_start..end]);
        }
    }
    return error.ParseError;
}

fn parseElementId(allocator: std.mem.Allocator, response: []const u8) ![]const u8 {
    // Look for element-xxx or ELEMENT pattern
    const patterns = [_][]const u8{ "\"element-", "\"ELEMENT\":\"" };
    for (patterns) |pattern| {
        if (std.mem.indexOf(u8, response, pattern)) |start| {
            const value_start = start + pattern.len;
            if (std.mem.indexOfPos(u8, response, value_start, "\"")) |end| {
                return try allocator.dupe(u8, response[value_start..end]);
            }
        }
    }
    return error.ParseError;
}

fn parseElementIds(ctx: *IOSDriverContext, response: []const u8, out_handles: []ElementHandle) !usize {
    var count: usize = 0;
    var pos: usize = 0;

    while (count < out_handles.len) {
        const patterns = [_][]const u8{ "\"element-", "\"ELEMENT\":\"" };
        var found = false;
        for (patterns) |pattern| {
            if (std.mem.indexOfPos(u8, response, pos, pattern)) |start| {
                const value_start = start + pattern.len;
                if (std.mem.indexOfPos(u8, response, value_start, "\"")) |end| {
                    const element_id = try ctx.allocator.dupe(u8, response[value_start..end]);
                    defer ctx.allocator.free(element_id);
                    const stored_id = try ctx.storeElement(element_id);
                    out_handles[count] = ElementHandle{ .id = stored_id };
                    count += 1;
                    pos = end + 1;
                    found = true;
                    break;
                }
            }
        }
        if (!found) break;
    }

    return count;
}

fn parseBooleanValue(response: []const u8) bool {
    if (std.mem.indexOf(u8, response, "\"value\":true")) |_| {
        return true;
    }
    if (std.mem.indexOf(u8, response, "\"value\": true")) |_| {
        return true;
    }
    return false;
}

fn parseStringValue(response: []const u8, buf: []u8) DriverError![]const u8 {
    const key = "\"value\":\"";
    if (std.mem.indexOf(u8, response, key)) |start| {
        const value_start = start + key.len;
        if (std.mem.indexOfPos(u8, response, value_start, "\"")) |end| {
            const value = response[value_start..end];
            if (value.len > buf.len) return DriverError.BufferTooSmall;
            @memcpy(buf[0..value.len], value);
            return buf[0..value.len];
        }
    }
    return "";
}

fn parseRect(response: []const u8) DriverError!Rect {
    var rect = Rect{ .x = 0, .y = 0, .width = 0, .height = 0 };

    // Parse x, y, width, height from JSON
    if (parseNumber(response, "\"x\":")) |x| rect.x = @intFromFloat(x);
    if (parseNumber(response, "\"y\":")) |y| rect.y = @intFromFloat(y);
    if (parseNumber(response, "\"width\":")) |w| rect.width = @intFromFloat(w);
    if (parseNumber(response, "\"height\":")) |h| rect.height = @intFromFloat(h);

    return rect;
}

fn parseNumber(response: []const u8, key: []const u8) ?f64 {
    if (std.mem.indexOf(u8, response, key)) |start| {
        const value_start = start + key.len;
        var end = value_start;
        while (end < response.len and (response[end] == '-' or response[end] == '.' or (response[end] >= '0' and response[end] <= '9'))) {
            end += 1;
        }
        if (end > value_start) {
            return std.fmt.parseFloat(f64, response[value_start..end]) catch null;
        }
    }
    return null;
}

fn parseScreenshot(allocator: std.mem.Allocator, response: []const u8) DriverError!Screenshot {
    const key = "\"value\":\"";
    if (std.mem.indexOf(u8, response, key)) |start| {
        const value_start = start + key.len;
        if (std.mem.indexOfPos(u8, response, value_start, "\"")) |end| {
            const base64_data = response[value_start..end];
            const decoded = std.base64.standard.Decoder.calcSizeForSlice(base64_data) catch return DriverError.ActionFailed;
            const data = allocator.alloc(u8, decoded) catch return DriverError.OutOfMemory;
            _ = std.base64.standard.Decoder.decode(data, base64_data) catch {
                allocator.free(data);
                return DriverError.ActionFailed;
            };
            return Screenshot{
                .data = data,
                .width = 0, // Would need to parse from image
                .height = 0,
                .format = .png,
            };
        }
    }
    return DriverError.ActionFailed;
}

// HTTP client helpers
fn sendRequest(self: *IOSDriverContext, path: []const u8, body: []const u8) ![]const u8 {
    var uri_buf: [512]u8 = undefined;
    const uri_str = std.fmt.bufPrint(&uri_buf, "http://{s}:{d}{s}", .{
        self.config.host,
        self.config.port,
        path,
    }) catch return error.UriTooLong;

    const uri = std.Uri.parse(uri_str) catch return error.InvalidUri;

    var header_buf: [4096]u8 = undefined;
    var req = self.http_client.open(.POST, uri, .{
        .server_header_buffer = &header_buf,
    }) catch return error.ConnectionFailed;
    defer req.deinit();

    req.transfer_encoding = .{ .content_length = body.len };
    req.send() catch return error.SendFailed;
    req.writer().writeAll(body) catch return error.WriteFailed;
    req.finish() catch return error.FinishFailed;
    req.wait() catch return error.WaitFailed;

    const response = req.reader().readAllAlloc(self.allocator, 1024 * 1024) catch return error.ReadFailed;
    return response;
}

fn sendGetRequest(self: *IOSDriverContext, path: []const u8) ![]const u8 {
    var uri_buf: [512]u8 = undefined;
    const uri_str = std.fmt.bufPrint(&uri_buf, "http://{s}:{d}{s}", .{
        self.config.host,
        self.config.port,
        path,
    }) catch return error.UriTooLong;

    const uri = std.Uri.parse(uri_str) catch return error.InvalidUri;

    var header_buf: [4096]u8 = undefined;
    var req = self.http_client.open(.GET, uri, .{
        .server_header_buffer = &header_buf,
    }) catch return error.ConnectionFailed;
    defer req.deinit();

    req.send() catch return error.SendFailed;
    req.finish() catch return error.FinishFailed;
    req.wait() catch return error.WaitFailed;

    const response = req.reader().readAllAlloc(self.allocator, 1024 * 1024) catch return error.ReadFailed;
    return response;
}

fn sendDeleteRequest(self: *IOSDriverContext, path: []const u8) ![]const u8 {
    var uri_buf: [512]u8 = undefined;
    const uri_str = std.fmt.bufPrint(&uri_buf, "http://{s}:{d}{s}", .{
        self.config.host,
        self.config.port,
        path,
    }) catch return error.UriTooLong;

    const uri = std.Uri.parse(uri_str) catch return error.InvalidUri;

    var header_buf: [4096]u8 = undefined;
    var req = self.http_client.open(.DELETE, uri, .{
        .server_header_buffer = &header_buf,
    }) catch return error.ConnectionFailed;
    defer req.deinit();

    req.send() catch return error.SendFailed;
    req.finish() catch return error.FinishFailed;
    req.wait() catch return error.WaitFailed;

    const response = req.reader().readAllAlloc(self.allocator, 1024 * 1024) catch return error.ReadFailed;
    return response;
}

// Tests
test "ios driver config" {
    const config = IOSDriverConfig{};
    try std.testing.expectEqual(@as(u16, 8100), config.port);
    try std.testing.expectEqualStrings("127.0.0.1", config.host);
    try std.testing.expect(config.use_simulator);
}

test "ios driver config simulator name" {
    var config = IOSDriverConfig{};
    try std.testing.expectEqualStrings("iPhone 15", config.simulatorName());

    config.simulator_type = .ipad_pro_11;
    try std.testing.expectEqualStrings("iPad Pro 11-inch (4th generation)", config.simulatorName());
}

test "selector to xcui strategy - test id" {
    const selector = Selector{ .test_id = "login-button" };
    const result = selectorToXCUIStrategy(selector);
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("accessibility id", result.?.strategy);
    try std.testing.expectEqualStrings("login-button", result.?.value);
}

test "selector to xcui strategy - accessibility id" {
    const selector = Selector{ .accessibility_id = "submit" };
    const result = selectorToXCUIStrategy(selector);
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("accessibility id", result.?.strategy);
}

test "selector to xcui strategy - text" {
    const selector = Selector{ .text = "Submit" };
    const result = selectorToXCUIStrategy(selector);
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("name", result.?.strategy);
    try std.testing.expectEqualStrings("Submit", result.?.value);
}

test "parse boolean value" {
    try std.testing.expect(parseBooleanValue("{\"value\":true}"));
    try std.testing.expect(parseBooleanValue("{\"value\": true}"));
    try std.testing.expect(!parseBooleanValue("{\"value\":false}"));
    try std.testing.expect(!parseBooleanValue("{}"));
}

test "parse number" {
    const response = "{\"x\":100,\"y\":200.5}";
    try std.testing.expectEqual(@as(f64, 100), parseNumber(response, "\"x\":").?);
    try std.testing.expectEqual(@as(f64, 200.5), parseNumber(response, "\"y\":").?);
    try std.testing.expect(parseNumber(response, "\"z\":") == null);
}
