// Zylix Test Framework - macOS Driver
// Accessibility API bridge for macOS platform E2E testing

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

/// macOS driver configuration
pub const MacOSDriverConfig = struct {
    /// Server host
    host: []const u8 = "127.0.0.1",
    /// Server port
    port: u16 = 8200,
    /// Wait for app launch timeout (ms)
    launch_timeout_ms: u32 = 30000,
    /// Default element timeout (ms)
    element_timeout_ms: u32 = 10000,
    /// Enable accessibility features
    enable_accessibility: bool = true,
};

/// macOS driver context
pub const MacOSDriverContext = struct {
    allocator: std.mem.Allocator,
    config: MacOSDriverConfig,
    session_id: ?[]const u8 = null,
    http_client: std.http.Client,
    elements: std.StringHashMap([]const u8),
    element_counter: u64 = 0,
    app_pid: ?i32 = null,

    pub fn init(allocator: std.mem.Allocator, config: MacOSDriverConfig) MacOSDriverContext {
        return .{
            .allocator = allocator,
            .config = config,
            .http_client = std.http.Client{ .allocator = allocator },
            .elements = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *MacOSDriverContext) void {
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

    fn storeElement(self: *MacOSDriverContext, ax_element_id: []const u8) ![]const u8 {
        self.element_counter += 1;
        const id = try std.fmt.allocPrint(self.allocator, "{d}", .{self.element_counter});
        const stored_ax_id = try self.allocator.dupe(u8, ax_element_id);
        try self.elements.put(id, stored_ax_id);
        return id;
    }

    fn getAXElementId(self: *MacOSDriverContext, element_id: []const u8) ?[]const u8 {
        return self.elements.get(element_id);
    }
};

/// Create macOS driver with configuration
pub fn createMacOSDriver(allocator: std.mem.Allocator, config: MacOSDriverConfig) !Driver {
    const ctx = try allocator.create(MacOSDriverContext);
    ctx.* = MacOSDriverContext.init(allocator, config);

    return Driver{
        .vtable = &macos_driver_vtable,
        .context = ctx,
        .allocator = allocator,
        .platform = .macos,
    };
}

// VTable implementation
pub const macos_driver_vtable = DriverVTable{
    .launch = macosLaunch,
    .terminate = macosTerminate,
    .findElement = macosFindElement,
    .findElements = macosFindElements,
    .tap = macosTap,
    .doubleTap = macosDoubleTap,
    .longPress = macosLongPress,
    .typeText = macosTypeText,
    .clearText = macosClearText,
    .swipe = macosSwipe,
    .scroll = macosScroll,
    .exists = macosExists,
    .isVisible = macosIsVisible,
    .isEnabled = macosIsEnabled,
    .getText = macosGetText,
    .getAttribute = macosGetAttribute,
    .getRect = macosGetRect,
    .takeScreenshot = macosTakeScreenshot,
    .takeElementScreenshot = macosTakeElementScreenshot,
    .waitForElement = macosWaitForElement,
    .waitForElementHidden = macosWaitForElementHidden,
    .deinit = macosDeinit,
};

fn macosLaunch(ctx: *anyopaque, config: AppConfig) DriverError!void {
    const self: *MacOSDriverContext = @ptrCast(@alignCast(ctx));

    var json_buf: [4096]u8 = undefined;
    const json = std.fmt.bufPrint(&json_buf,
        \\{{"bundleId": "{s}", "launchTimeout": {d}}}
    , .{
        config.app_id,
        self.config.launch_timeout_ms,
    }) catch return DriverError.ConnectionFailed;

    const response = self.sendRequest("/session/new/launch", json) catch return DriverError.ConnectionFailed;
    defer self.allocator.free(response);

    const session_id = parseSessionId(self.allocator, response) catch return DriverError.LaunchFailed;
    self.session_id = session_id;

    // Parse PID if available
    if (parseNumber(response, "\"pid\":")) |pid| {
        self.app_pid = @intFromFloat(pid);
    }
}

fn macosTerminate(ctx: *anyopaque) DriverError!void {
    const self: *MacOSDriverContext = @ptrCast(@alignCast(ctx));

    if (self.session_id) |sid| {
        var path_buf: [256]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "/session/{s}/close", .{sid}) catch return;
        _ = self.sendRequest(path, "{}") catch {};
        self.allocator.free(sid);
        self.session_id = null;
        self.app_pid = null;
    }
}

fn macosFindElement(ctx: *anyopaque, selector: Selector) DriverError!?ElementHandle {
    const self: *MacOSDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;

    const strategy_and_value = selectorToAXStrategy(selector) orelse return null;

    var json_buf: [1024]u8 = undefined;
    const json = std.fmt.bufPrint(&json_buf,
        \\{{"strategy": "{s}", "value": "{s}"}}
    , .{ strategy_and_value.strategy, strategy_and_value.value }) catch return DriverError.InvalidSelector;

    var path_buf: [256]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/findElement", .{sid}) catch return DriverError.InvalidSelector;

    const response = self.sendRequest(path, json) catch return null;
    defer self.allocator.free(response);

    const element_id = parseElementId(self.allocator, response) catch return null;
    defer self.allocator.free(element_id);

    const stored_id = self.storeElement(element_id) catch return DriverError.OutOfMemory;
    return ElementHandle{ .id = stored_id };
}

fn macosFindElements(ctx: *anyopaque, selector: Selector, out_handles: []ElementHandle) DriverError!usize {
    const self: *MacOSDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;

    const strategy_and_value = selectorToAXStrategy(selector) orelse return 0;

    var json_buf: [1024]u8 = undefined;
    const json = std.fmt.bufPrint(&json_buf,
        \\{{"strategy": "{s}", "value": "{s}"}}
    , .{ strategy_and_value.strategy, strategy_and_value.value }) catch return DriverError.InvalidSelector;

    var path_buf: [256]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/findElements", .{sid}) catch return DriverError.InvalidSelector;

    const response = self.sendRequest(path, json) catch return 0;
    defer self.allocator.free(response);

    return parseElementIds(self, response, out_handles) catch return 0;
}

fn macosTap(ctx: *anyopaque, handle: ElementHandle) DriverError!void {
    const self: *MacOSDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;
    const ax_id = self.getAXElementId(handle.id) orelse return DriverError.ElementNotFound;

    var json_buf: [256]u8 = undefined;
    const json = std.fmt.bufPrint(&json_buf,
        \\{{"elementId": "{s}"}}
    , .{ax_id}) catch return DriverError.ActionFailed;

    var path_buf: [256]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/click", .{sid}) catch return DriverError.InvalidSelector;

    _ = self.sendRequest(path, json) catch return DriverError.ActionFailed;
}

fn macosDoubleTap(ctx: *anyopaque, handle: ElementHandle) DriverError!void {
    const self: *MacOSDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;
    const ax_id = self.getAXElementId(handle.id) orelse return DriverError.ElementNotFound;

    var json_buf: [256]u8 = undefined;
    const json = std.fmt.bufPrint(&json_buf,
        \\{{"elementId": "{s}"}}
    , .{ax_id}) catch return DriverError.ActionFailed;

    var path_buf: [256]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/doubleClick", .{sid}) catch return DriverError.InvalidSelector;

    _ = self.sendRequest(path, json) catch return DriverError.ActionFailed;
}

fn macosLongPress(ctx: *anyopaque, handle: ElementHandle, duration_ms: u32) DriverError!void {
    const self: *MacOSDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;
    const ax_id = self.getAXElementId(handle.id) orelse return DriverError.ElementNotFound;

    var json_buf: [256]u8 = undefined;
    const json = std.fmt.bufPrint(&json_buf,
        \\{{"elementId": "{s}", "duration": {d}}}
    , .{ ax_id, duration_ms }) catch return DriverError.ActionFailed;

    var path_buf: [256]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/longPress", .{sid}) catch return DriverError.InvalidSelector;

    _ = self.sendRequest(path, json) catch return DriverError.ActionFailed;
}

fn macosTypeText(ctx: *anyopaque, handle: ElementHandle, text: []const u8) DriverError!void {
    const self: *MacOSDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;
    const ax_id = self.getAXElementId(handle.id) orelse return DriverError.ElementNotFound;

    var json_buf: [4096]u8 = undefined;
    const json = std.fmt.bufPrint(&json_buf,
        \\{{"elementId": "{s}", "text": "{s}"}}
    , .{ ax_id, text }) catch return DriverError.ActionFailed;

    var path_buf: [256]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/type", .{sid}) catch return DriverError.InvalidSelector;

    _ = self.sendRequest(path, json) catch return DriverError.ActionFailed;
}

fn macosClearText(ctx: *anyopaque, handle: ElementHandle) DriverError!void {
    const self: *MacOSDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;
    const ax_id = self.getAXElementId(handle.id) orelse return DriverError.ElementNotFound;

    var json_buf: [256]u8 = undefined;
    const json = std.fmt.bufPrint(&json_buf,
        \\{{"elementId": "{s}"}}
    , .{ax_id}) catch return DriverError.ActionFailed;

    var path_buf: [256]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/clear", .{sid}) catch return DriverError.InvalidSelector;

    _ = self.sendRequest(path, json) catch return DriverError.ActionFailed;
}

fn macosSwipe(ctx: *anyopaque, handle: ElementHandle, direction: SwipeDirection) DriverError!void {
    const self: *MacOSDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;
    const ax_id = self.getAXElementId(handle.id) orelse return DriverError.ElementNotFound;

    const dir_str = switch (direction) {
        .up => "up",
        .down => "down",
        .left => "left",
        .right => "right",
    };

    var json_buf: [256]u8 = undefined;
    const json = std.fmt.bufPrint(&json_buf,
        \\{{"elementId": "{s}", "direction": "{s}"}}
    , .{ ax_id, dir_str }) catch return DriverError.ActionFailed;

    var path_buf: [256]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/swipe", .{sid}) catch return DriverError.InvalidSelector;

    _ = self.sendRequest(path, json) catch return DriverError.ActionFailed;
}

fn macosScroll(ctx: *anyopaque, handle: ElementHandle, direction: ScrollDirection, amount: f32) DriverError!void {
    const self: *MacOSDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;
    const ax_id = self.getAXElementId(handle.id) orelse return DriverError.ElementNotFound;

    const dir_str = switch (direction) {
        .up => "up",
        .down => "down",
        .left => "left",
        .right => "right",
    };

    var json_buf: [256]u8 = undefined;
    const json = std.fmt.bufPrint(&json_buf,
        \\{{"elementId": "{s}", "direction": "{s}", "amount": {d:.2}}}
    , .{ ax_id, dir_str, amount }) catch return DriverError.ActionFailed;

    var path_buf: [256]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/scroll", .{sid}) catch return DriverError.InvalidSelector;

    _ = self.sendRequest(path, json) catch return DriverError.ActionFailed;
}

fn macosExists(ctx: *anyopaque, handle: ElementHandle) DriverError!bool {
    const self: *MacOSDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;
    const ax_id = self.getAXElementId(handle.id) orelse return false;

    var json_buf: [256]u8 = undefined;
    const json = std.fmt.bufPrint(&json_buf,
        \\{{"elementId": "{s}"}}
    , .{ax_id}) catch return false;

    var path_buf: [256]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/exists", .{sid}) catch return false;

    const response = self.sendRequest(path, json) catch return false;
    defer self.allocator.free(response);

    return parseBooleanValue(response);
}

fn macosIsVisible(ctx: *anyopaque, handle: ElementHandle) DriverError!bool {
    const self: *MacOSDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;
    const ax_id = self.getAXElementId(handle.id) orelse return false;

    var json_buf: [256]u8 = undefined;
    const json = std.fmt.bufPrint(&json_buf,
        \\{{"elementId": "{s}"}}
    , .{ax_id}) catch return false;

    var path_buf: [256]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/isVisible", .{sid}) catch return false;

    const response = self.sendRequest(path, json) catch return false;
    defer self.allocator.free(response);

    return parseBooleanValue(response);
}

fn macosIsEnabled(ctx: *anyopaque, handle: ElementHandle) DriverError!bool {
    const self: *MacOSDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;
    const ax_id = self.getAXElementId(handle.id) orelse return false;

    var json_buf: [256]u8 = undefined;
    const json = std.fmt.bufPrint(&json_buf,
        \\{{"elementId": "{s}"}}
    , .{ax_id}) catch return false;

    var path_buf: [256]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/isEnabled", .{sid}) catch return false;

    const response = self.sendRequest(path, json) catch return false;
    defer self.allocator.free(response);

    return parseBooleanValue(response);
}

fn macosGetText(ctx: *anyopaque, handle: ElementHandle, buf: []u8) DriverError![]const u8 {
    const self: *MacOSDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;
    const ax_id = self.getAXElementId(handle.id) orelse return DriverError.ElementNotFound;

    var json_buf: [256]u8 = undefined;
    const json = std.fmt.bufPrint(&json_buf,
        \\{{"elementId": "{s}"}}
    , .{ax_id}) catch return DriverError.InvalidSelector;

    var path_buf: [256]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/getText", .{sid}) catch return DriverError.InvalidSelector;

    const response = self.sendRequest(path, json) catch return DriverError.ActionFailed;
    defer self.allocator.free(response);

    return parseStringValue(response, buf);
}

fn macosGetAttribute(ctx: *anyopaque, handle: ElementHandle, name: []const u8, buf: []u8) DriverError![]const u8 {
    const self: *MacOSDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;
    const ax_id = self.getAXElementId(handle.id) orelse return DriverError.ElementNotFound;

    var json_buf: [512]u8 = undefined;
    const json = std.fmt.bufPrint(&json_buf,
        \\{{"elementId": "{s}", "name": "{s}"}}
    , .{ ax_id, name }) catch return DriverError.InvalidSelector;

    var path_buf: [256]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/getAttribute", .{sid}) catch return DriverError.InvalidSelector;

    const response = self.sendRequest(path, json) catch return DriverError.ActionFailed;
    defer self.allocator.free(response);

    return parseStringValue(response, buf);
}

fn macosGetRect(ctx: *anyopaque, handle: ElementHandle) DriverError!Rect {
    const self: *MacOSDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;
    const ax_id = self.getAXElementId(handle.id) orelse return DriverError.ElementNotFound;

    var json_buf: [256]u8 = undefined;
    const json = std.fmt.bufPrint(&json_buf,
        \\{{"elementId": "{s}"}}
    , .{ax_id}) catch return DriverError.InvalidSelector;

    var path_buf: [256]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/getRect", .{sid}) catch return DriverError.InvalidSelector;

    const response = self.sendRequest(path, json) catch return DriverError.ActionFailed;
    defer self.allocator.free(response);

    return parseRect(response);
}

fn macosTakeScreenshot(ctx: *anyopaque) DriverError!Screenshot {
    const self: *MacOSDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;

    var path_buf: [256]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/screenshot", .{sid}) catch return DriverError.ActionFailed;

    const response = self.sendRequest(path, "{}") catch return DriverError.ActionFailed;
    defer self.allocator.free(response);

    return parseScreenshot(self.allocator, response);
}

fn macosTakeElementScreenshot(ctx: *anyopaque, handle: ElementHandle) DriverError!Screenshot {
    const self: *MacOSDriverContext = @ptrCast(@alignCast(ctx));
    const sid = self.session_id orelse return DriverError.NotConnected;
    const ax_id = self.getAXElementId(handle.id) orelse return DriverError.ElementNotFound;

    var json_buf: [256]u8 = undefined;
    const json = std.fmt.bufPrint(&json_buf,
        \\{{"elementId": "{s}"}}
    , .{ax_id}) catch return DriverError.InvalidSelector;

    var path_buf: [256]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/session/{s}/elementScreenshot", .{sid}) catch return DriverError.InvalidSelector;

    const response = self.sendRequest(path, json) catch return DriverError.ActionFailed;
    defer self.allocator.free(response);

    return parseScreenshot(self.allocator, response);
}

fn macosWaitForElement(ctx: *anyopaque, selector: Selector, timeout_ms: u32) DriverError!?ElementHandle {
    const start = std.time.milliTimestamp();
    const timeout: i64 = @intCast(timeout_ms);

    while (std.time.milliTimestamp() - start < timeout) {
        if (try macosFindElement(ctx, selector)) |handle| {
            if (try macosIsVisible(ctx, handle)) {
                return handle;
            }
        }
        std.time.sleep(100 * std.time.ns_per_ms);
    }

    return null;
}

fn macosWaitForElementHidden(ctx: *anyopaque, selector: Selector, timeout_ms: u32) DriverError!bool {
    const start = std.time.milliTimestamp();
    const timeout: i64 = @intCast(timeout_ms);

    while (std.time.milliTimestamp() - start < timeout) {
        if (try macosFindElement(ctx, selector)) |handle| {
            if (!try macosIsVisible(ctx, handle)) {
                return true;
            }
        } else {
            return true;
        }
        std.time.sleep(100 * std.time.ns_per_ms);
    }

    return false;
}

fn macosDeinit(ctx: *anyopaque) void {
    const self: *MacOSDriverContext = @ptrCast(@alignCast(ctx));
    self.deinit();
    self.allocator.destroy(self);
}

// Helper functions

const StrategyAndValue = struct {
    strategy: []const u8,
    value: []const u8,
};

fn selectorToAXStrategy(selector: Selector) ?StrategyAndValue {
    if (selector.test_id) |id| {
        return .{ .strategy = "identifier", .value = id };
    }
    if (selector.accessibility_id) |id| {
        return .{ .strategy = "identifier", .value = id };
    }
    if (selector.text) |text| {
        return .{ .strategy = "title", .value = text };
    }
    if (selector.xpath) |xpath| {
        return .{ .strategy = "xpath", .value = xpath };
    }
    if (selector.predicate) |pred| {
        return .{ .strategy = "predicate", .value = pred };
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
    const key = "\"elementId\":\"";
    if (std.mem.indexOf(u8, response, key)) |start| {
        const value_start = start + key.len;
        if (std.mem.indexOfPos(u8, response, value_start, "\"")) |end| {
            return try allocator.dupe(u8, response[value_start..end]);
        }
    }
    return error.ParseError;
}

fn parseElementIds(ctx: *MacOSDriverContext, response: []const u8, out_handles: []ElementHandle) !usize {
    var count: usize = 0;
    var pos: usize = 0;
    const pattern = "\"elementId\":\"";

    while (count < out_handles.len) {
        if (std.mem.indexOfPos(u8, response, pos, pattern)) |start| {
            const value_start = start + pattern.len;
            if (std.mem.indexOfPos(u8, response, value_start, "\"")) |end| {
                const element_id = try ctx.allocator.dupe(u8, response[value_start..end]);
                defer ctx.allocator.free(element_id);
                const stored_id = try ctx.storeElement(element_id);
                out_handles[count] = ElementHandle{ .id = stored_id };
                count += 1;
                pos = end + 1;
            } else break;
        } else break;
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
    const key = "\"data\":\"";
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
fn sendRequest(self: *MacOSDriverContext, path: []const u8, body: []const u8) ![]const u8 {
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

// Tests
test "macos driver config" {
    const config = MacOSDriverConfig{};
    try std.testing.expectEqual(@as(u16, 8200), config.port);
    try std.testing.expectEqualStrings("127.0.0.1", config.host);
    try std.testing.expect(config.enable_accessibility);
}

test "selector to ax strategy - test id" {
    const selector = Selector{ .test_id = "login-button" };
    const result = selectorToAXStrategy(selector);
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("identifier", result.?.strategy);
    try std.testing.expectEqualStrings("login-button", result.?.value);
}

test "selector to ax strategy - text" {
    const selector = Selector{ .text = "Submit" };
    const result = selectorToAXStrategy(selector);
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("title", result.?.strategy);
}

test "selector to ax strategy - predicate" {
    const selector = Selector{ .predicate = "label BEGINSWITH 'Log'" };
    const result = selectorToAXStrategy(selector);
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("predicate", result.?.strategy);
}

test "parse boolean value" {
    try std.testing.expect(parseBooleanValue("{\"value\":true}"));
    try std.testing.expect(!parseBooleanValue("{\"value\":false}"));
}

test "parse number" {
    const response = "{\"x\":100,\"y\":200.5}";
    try std.testing.expectEqual(@as(f64, 100), parseNumber(response, "\"x\":").?);
    try std.testing.expectEqual(@as(f64, 200.5), parseNumber(response, "\"y\":").?);
}
