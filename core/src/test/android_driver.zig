// Zylix Test Framework - Android Driver
// UIAutomator2/Espresso bridge for Android platform E2E testing

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

/// Android driver configuration
pub const AndroidDriverConfig = struct {
    /// UIAutomator2 server host
    host: []const u8 = "127.0.0.1",
    /// UIAutomator2 server port
    port: u16 = 6790,
    /// Device serial (from adb devices)
    device_serial: ?[]const u8 = null,
    /// Use emulator
    use_emulator: bool = true,
    /// Android API level
    api_level: u8 = 34,
    /// Wait for app launch timeout (ms)
    launch_timeout_ms: u32 = 30000,
    /// Default element timeout (ms)
    element_timeout_ms: u32 = 10000,
    /// ADB forward port
    adb_port: u16 = 5037,
};

/// Android driver context
pub const AndroidDriverContext = struct {
    allocator: std.mem.Allocator,
    config: AndroidDriverConfig,
    session_id: ?[]const u8 = null,
    http_client: std.http.Client,
    elements: std.StringHashMap([]const u8),
    element_counter: u64 = 0,

    pub fn init(allocator: std.mem.Allocator, config: AndroidDriverConfig) AndroidDriverContext {
        return .{
            .allocator = allocator,
            .config = config,
            .http_client = std.http.Client{ .allocator = allocator },
            .elements = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *AndroidDriverContext) void {
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

    fn storeElement(self: *AndroidDriverContext, uia_element_id: []const u8) ![]const u8 {
        self.element_counter += 1;
        const id = try std.fmt.allocPrint(self.allocator, "{d}", .{self.element_counter});
        const stored_uia_id = try self.allocator.dupe(u8, uia_element_id);
        try self.elements.put(id, stored_uia_id);
        return id;
    }

    fn getUIAElementId(self: *AndroidDriverContext, element_id: []const u8) ?[]const u8 {
        return self.elements.get(element_id);
    }
};

/// Create Android driver with configuration
pub fn createAndroidDriver(allocator: std.mem.Allocator, config: AndroidDriverConfig) !Driver {
    const ctx = try allocator.create(AndroidDriverContext);
    ctx.* = AndroidDriverContext.init(allocator, config);

    return Driver{
        .vtable = &android_driver_vtable,
        .context = ctx,
        .allocator = allocator,
        .platform = .android,
    };
}

// VTable implementation
pub const android_driver_vtable = DriverVTable{
    .launch = androidLaunch,
    .terminate = androidTerminate,
    .findElement = androidFindElement,
    .findElements = androidFindElements,
    .tap = androidTap,
    .doubleTap = androidDoubleTap,
    .longPress = androidLongPress,
    .typeText = androidTypeText,
    .clearText = androidClearText,
    .swipe = androidSwipe,
    .scroll = androidScroll,
    .exists = androidExists,
    .isVisible = androidIsVisible,
    .isEnabled = androidIsEnabled,
    .getText = androidGetText,
    .getAttribute = androidGetAttribute,
    .getRect = androidGetRect,
    .takeScreenshot = androidTakeScreenshot,
    .takeElementScreenshot = androidTakeElementScreenshot,
    .waitForElement = androidWaitForElement,
    .waitForElementHidden = androidWaitForElementHidden,
    .deinit = androidDeinit,
};

fn androidLaunch(ctx: *anyopaque, config: AppConfig) DriverError!void {
    const self: *AndroidDriverContext = @ptrCast(@alignCast(ctx));

    // Build UIAutomator2 session request
    var json_buf: [4096]u8 = undefined;
    const json = std.fmt.bufPrint(&json_buf,
        \\{{"capabilities": {{
        \\  "alwaysMatch": {{
        \\    "platformName": "Android",
        \\    "appPackage": "{s}",
        \\    "automationName": "UiAutomator2",
        \\    "deviceName": "{s}"
        \\  }}
        \\}}}}
    , .{
        config.app_id,
        if (self.config.device_serial) |serial| serial else "emulator-5554",
    }) catch return DriverError.ConnectionFailed;

    const response = self.sendRequest("/session", json) catch return DriverError.ConnectionFailed;
    defer self.allocator.free(response);

    // Parse session ID from response
    const session_id = parseSessionId(self.allocator, response) catch return DriverError.LaunchFailed;
    self.session_id = session_id;
}

fn androidTerminate(ctx: *anyopaque) DriverError!void {
    const self: *AndroidDriverContext = @ptrCast(@alignCast(ctx));

    if (self.session_id) |sid| {
        var path_buf: [256]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "/session/{s}", .{sid}) catch return;
        _ = self.sendDeleteRequest(path) catch {};
        self.allocator.free(sid);
        self.session_id = null;
    }
}

fn androidFindElement(ctx: *anyopaque, selector: Selector) DriverError!?ElementHandle {
    const self: *AndroidDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;

    const strategy_and_value = selectorToUIAStrategy(selector) orelse return null;

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

fn androidFindElements(ctx: *anyopaque, selector: Selector, out_handles: []ElementHandle) DriverError!usize {
    const self: *AndroidDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;

    const strategy_and_value = selectorToUIAStrategy(selector) orelse return 0;

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

fn androidTap(ctx: *anyopaque, handle: ElementHandle) DriverError!void {
    const self: *AndroidDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;
    const uia_id = self.getUIAElementId(handle.id) orelse return DriverError.ElementNotFound;

    var path_buf: [512]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/element/{s}/click", .{ sid, uia_id }) catch return DriverError.InvalidSelector;

    _ = self.sendRequest(path, "{}") catch return DriverError.ActionFailed;
}

fn androidDoubleTap(ctx: *anyopaque, handle: ElementHandle) DriverError!void {
    const self: *AndroidDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;

    // Get element center coordinates
    const rect = try androidGetRect(ctx, handle);
    const center_x = rect.x + @divFloor(rect.width, 2);
    const center_y = rect.y + @divFloor(rect.height, 2);

    // Perform double tap via touch actions
    var json_buf: [512]u8 = undefined;
    const json = std.fmt.bufPrint(&json_buf,
        \\{{"actions": [{{"type": "pointer", "id": "finger1", "actions": [
        \\  {{"type": "pointerMove", "x": {d}, "y": {d}}},
        \\  {{"type": "pointerDown"}},
        \\  {{"type": "pointerUp"}},
        \\  {{"type": "pause", "duration": 50}},
        \\  {{"type": "pointerDown"}},
        \\  {{"type": "pointerUp"}}
        \\]}}]}}
    , .{ center_x, center_y }) catch return DriverError.ActionFailed;

    var path_buf: [256]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/actions", .{sid}) catch return DriverError.InvalidSelector;

    _ = self.sendRequest(path, json) catch return DriverError.ActionFailed;
}

fn androidLongPress(ctx: *anyopaque, handle: ElementHandle, duration_ms: u32) DriverError!void {
    const self: *AndroidDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;

    // Get element center coordinates
    const rect = try androidGetRect(ctx, handle);
    const center_x = rect.x + @divFloor(rect.width, 2);
    const center_y = rect.y + @divFloor(rect.height, 2);

    // Perform long press via touch actions
    var json_buf: [512]u8 = undefined;
    const json = std.fmt.bufPrint(&json_buf,
        \\{{"actions": [{{"type": "pointer", "id": "finger1", "actions": [
        \\  {{"type": "pointerMove", "x": {d}, "y": {d}}},
        \\  {{"type": "pointerDown"}},
        \\  {{"type": "pause", "duration": {d}}},
        \\  {{"type": "pointerUp"}}
        \\]}}]}}
    , .{ center_x, center_y, duration_ms }) catch return DriverError.ActionFailed;

    var path_buf: [256]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/actions", .{sid}) catch return DriverError.InvalidSelector;

    _ = self.sendRequest(path, json) catch return DriverError.ActionFailed;
}

fn androidTypeText(ctx: *anyopaque, handle: ElementHandle, text: []const u8) DriverError!void {
    const self: *AndroidDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;
    const uia_id = self.getUIAElementId(handle.id) orelse return DriverError.ElementNotFound;

    // First tap to focus
    try androidTap(ctx, handle);

    var json_buf: [4096]u8 = undefined;
    const json = std.fmt.bufPrint(&json_buf,
        \\{{"text": "{s}"}}
    , .{text}) catch return DriverError.ActionFailed;

    var path_buf: [512]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/element/{s}/value", .{ sid, uia_id }) catch return DriverError.InvalidSelector;

    _ = self.sendRequest(path, json) catch return DriverError.ActionFailed;
}

fn androidClearText(ctx: *anyopaque, handle: ElementHandle) DriverError!void {
    const self: *AndroidDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;
    const uia_id = self.getUIAElementId(handle.id) orelse return DriverError.ElementNotFound;

    var path_buf: [512]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/element/{s}/clear", .{ sid, uia_id }) catch return DriverError.InvalidSelector;

    _ = self.sendRequest(path, "{}") catch return DriverError.ActionFailed;
}

fn androidSwipe(ctx: *anyopaque, handle: ElementHandle, direction: SwipeDirection) DriverError!void {
    const self: *AndroidDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;

    // Get element bounds
    const rect = try androidGetRect(ctx, handle);
    const center_x = rect.x + @divFloor(rect.width, 2);
    const center_y = rect.y + @divFloor(rect.height, 2);
    const distance: i32 = 300;

    var end_x = center_x;
    var end_y = center_y;
    switch (direction) {
        .up => end_y -= distance,
        .down => end_y += distance,
        .left => end_x -= distance,
        .right => end_x += distance,
    }

    var json_buf: [512]u8 = undefined;
    const json = std.fmt.bufPrint(&json_buf,
        \\{{"actions": [{{"type": "pointer", "id": "finger1", "actions": [
        \\  {{"type": "pointerMove", "x": {d}, "y": {d}}},
        \\  {{"type": "pointerDown"}},
        \\  {{"type": "pointerMove", "x": {d}, "y": {d}, "duration": 200}},
        \\  {{"type": "pointerUp"}}
        \\]}}]}}
    , .{ center_x, center_y, end_x, end_y }) catch return DriverError.ActionFailed;

    var path_buf: [256]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/actions", .{sid}) catch return DriverError.InvalidSelector;

    _ = self.sendRequest(path, json) catch return DriverError.ActionFailed;
}

fn androidScroll(ctx: *anyopaque, handle: ElementHandle, direction: ScrollDirection, amount: f32) DriverError!void {
    const self: *AndroidDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;

    // Get element bounds
    const rect = try androidGetRect(ctx, handle);
    const center_x = rect.x + @divFloor(rect.width, 2);
    const center_y = rect.y + @divFloor(rect.height, 2);
    const distance: i32 = @intFromFloat(@as(f32, @floatFromInt(rect.height)) * amount);

    var end_x = center_x;
    var end_y = center_y;
    switch (direction) {
        .up => end_y -= distance,
        .down => end_y += distance,
        .left => end_x -= distance,
        .right => end_x += distance,
    }

    var json_buf: [512]u8 = undefined;
    const json = std.fmt.bufPrint(&json_buf,
        \\{{"actions": [{{"type": "pointer", "id": "finger1", "actions": [
        \\  {{"type": "pointerMove", "x": {d}, "y": {d}}},
        \\  {{"type": "pointerDown"}},
        \\  {{"type": "pointerMove", "x": {d}, "y": {d}, "duration": 300}},
        \\  {{"type": "pointerUp"}}
        \\]}}]}}
    , .{ center_x, center_y, end_x, end_y }) catch return DriverError.ActionFailed;

    var path_buf: [256]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/actions", .{sid}) catch return DriverError.InvalidSelector;

    _ = self.sendRequest(path, json) catch return DriverError.ActionFailed;
}

fn androidExists(ctx: *anyopaque, handle: ElementHandle) DriverError!bool {
    const self: *AndroidDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;
    const uia_id = self.getUIAElementId(handle.id) orelse return false;

    var path_buf: [512]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/element/{s}/displayed", .{ sid, uia_id }) catch return false;

    const response = self.sendGetRequest(path) catch return false;
    defer self.allocator.free(response);

    // Element exists if we got a response (even if not displayed)
    return true;
}

fn androidIsVisible(ctx: *anyopaque, handle: ElementHandle) DriverError!bool {
    const self: *AndroidDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;
    const uia_id = self.getUIAElementId(handle.id) orelse return false;

    var path_buf: [512]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/element/{s}/displayed", .{ sid, uia_id }) catch return false;

    const response = self.sendGetRequest(path) catch return false;
    defer self.allocator.free(response);

    return parseBooleanValue(response);
}

fn androidIsEnabled(ctx: *anyopaque, handle: ElementHandle) DriverError!bool {
    const self: *AndroidDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;
    const uia_id = self.getUIAElementId(handle.id) orelse return false;

    var path_buf: [512]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/element/{s}/enabled", .{ sid, uia_id }) catch return false;

    const response = self.sendGetRequest(path) catch return false;
    defer self.allocator.free(response);

    return parseBooleanValue(response);
}

fn androidGetText(ctx: *anyopaque, handle: ElementHandle, buf: []u8) DriverError![]const u8 {
    const self: *AndroidDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;
    const uia_id = self.getUIAElementId(handle.id) orelse return DriverError.ElementNotFound;

    var path_buf: [512]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/element/{s}/text", .{ sid, uia_id }) catch return DriverError.InvalidSelector;

    const response = self.sendGetRequest(path) catch return DriverError.ActionFailed;
    defer self.allocator.free(response);

    return parseStringValue(response, buf);
}

fn androidGetAttribute(ctx: *anyopaque, handle: ElementHandle, name: []const u8, buf: []u8) DriverError![]const u8 {
    const self: *AndroidDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;
    const uia_id = self.getUIAElementId(handle.id) orelse return DriverError.ElementNotFound;

    var path_buf: [512]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/element/{s}/attribute/{s}", .{ sid, uia_id, name }) catch return DriverError.InvalidSelector;

    const response = self.sendGetRequest(path) catch return DriverError.ActionFailed;
    defer self.allocator.free(response);

    return parseStringValue(response, buf);
}

fn androidGetRect(ctx: *anyopaque, handle: ElementHandle) DriverError!Rect {
    const self: *AndroidDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;
    const uia_id = self.getUIAElementId(handle.id) orelse return DriverError.ElementNotFound;

    var path_buf: [512]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/element/{s}/rect", .{ sid, uia_id }) catch return DriverError.InvalidSelector;

    const response = self.sendGetRequest(path) catch return DriverError.ActionFailed;
    defer self.allocator.free(response);

    return parseRect(response);
}

fn androidTakeScreenshot(ctx: *anyopaque) DriverError!Screenshot {
    const self: *AndroidDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;

    var path_buf: [256]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/screenshot", .{sid}) catch return DriverError.ActionFailed;

    const response = self.sendGetRequest(path) catch return DriverError.ActionFailed;
    defer self.allocator.free(response);

    return parseScreenshot(self.allocator, response);
}

fn androidTakeElementScreenshot(ctx: *anyopaque, handle: ElementHandle) DriverError!Screenshot {
    const self: *AndroidDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;
    const uia_id = self.getUIAElementId(handle.id) orelse return DriverError.ElementNotFound;

    var path_buf: [512]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/element/{s}/screenshot", .{ sid, uia_id }) catch return DriverError.InvalidSelector;

    const response = self.sendGetRequest(path) catch return DriverError.ActionFailed;
    defer self.allocator.free(response);

    return parseScreenshot(self.allocator, response);
}

fn androidWaitForElement(ctx: *anyopaque, selector: Selector, timeout_ms: u32) DriverError!?ElementHandle {
    const self: *AndroidDriverContext = @ptrCast(@alignCast(ctx));
    const start = std.time.milliTimestamp();
    const timeout: i64 = @intCast(timeout_ms);

    while (std.time.milliTimestamp() - start < timeout) {
        if (try androidFindElement(ctx, selector)) |handle| {
            if (try androidIsVisible(ctx, handle)) {
                return handle;
            }
        }
        std.time.sleep(100 * std.time.ns_per_ms);
    }

    _ = self;
    return null;
}

fn androidWaitForElementHidden(ctx: *anyopaque, selector: Selector, timeout_ms: u32) DriverError!bool {
    const self: *AndroidDriverContext = @ptrCast(@alignCast(ctx));
    const start = std.time.milliTimestamp();
    const timeout: i64 = @intCast(timeout_ms);

    while (std.time.milliTimestamp() - start < timeout) {
        if (try androidFindElement(ctx, selector)) |handle| {
            if (!try androidIsVisible(ctx, handle)) {
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

fn androidDeinit(ctx: *anyopaque) void {
    const self: *AndroidDriverContext = @ptrCast(@alignCast(ctx));
    self.deinit();
    self.allocator.destroy(self);
}

// Helper functions

const StrategyAndValue = struct {
    strategy: []const u8,
    value: []const u8,
};

fn selectorToUIAStrategy(selector: Selector) ?StrategyAndValue {
    if (selector.test_id) |id| {
        // Android uses resource-id or content-desc for test IDs
        return .{ .strategy = "accessibility id", .value = id };
    }
    if (selector.accessibility_id) |id| {
        return .{ .strategy = "accessibility id", .value = id };
    }
    if (selector.text) |text| {
        // Use UiSelector for text matching
        var buf: [256]u8 = undefined;
        const value = std.fmt.bufPrint(&buf, "new UiSelector().text(\"{s}\")", .{text}) catch return null;
        return .{ .strategy = "-android uiautomator", .value = value };
    }
    if (selector.xpath) |xpath| {
        return .{ .strategy = "xpath", .value = xpath };
    }
    if (selector.resource_id) |rid| {
        var buf: [256]u8 = undefined;
        const value = std.fmt.bufPrint(&buf, "new UiSelector().resourceId(\"{s}\")", .{rid}) catch return null;
        return .{ .strategy = "-android uiautomator", .value = value };
    }
    if (selector.class_name) |class| {
        return .{ .strategy = "class name", .value = class };
    }
    return null;
}

fn parseSessionId(allocator: std.mem.Allocator, response: []const u8) ![]const u8 {
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

fn parseElementIds(ctx: *AndroidDriverContext, response: []const u8, out_handles: []ElementHandle) !usize {
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
                .width = 0,
                .height = 0,
                .format = .png,
            };
        }
    }
    return DriverError.ActionFailed;
}

// HTTP client helpers
fn sendRequest(self: *AndroidDriverContext, path: []const u8, body: []const u8) ![]const u8 {
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

fn sendGetRequest(self: *AndroidDriverContext, path: []const u8) ![]const u8 {
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

fn sendDeleteRequest(self: *AndroidDriverContext, path: []const u8) ![]const u8 {
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
test "android driver config" {
    const config = AndroidDriverConfig{};
    try std.testing.expectEqual(@as(u16, 6790), config.port);
    try std.testing.expectEqualStrings("127.0.0.1", config.host);
    try std.testing.expect(config.use_emulator);
    try std.testing.expectEqual(@as(u8, 34), config.api_level);
}

test "selector to uia strategy - test id" {
    const selector = Selector{ .test_id = "login-button" };
    const result = selectorToUIAStrategy(selector);
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("accessibility id", result.?.strategy);
    try std.testing.expectEqualStrings("login-button", result.?.value);
}

test "selector to uia strategy - accessibility id" {
    const selector = Selector{ .accessibility_id = "submit" };
    const result = selectorToUIAStrategy(selector);
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("accessibility id", result.?.strategy);
}

test "selector to uia strategy - xpath" {
    const selector = Selector{ .xpath = "//android.widget.Button[@text='Login']" };
    const result = selectorToUIAStrategy(selector);
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("xpath", result.?.strategy);
}

test "selector to uia strategy - class name" {
    const selector = Selector{ .class_name = "android.widget.Button" };
    const result = selectorToUIAStrategy(selector);
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("class name", result.?.strategy);
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
