// Zylix Test Framework - Web Driver
// Playwright-based driver for web platform testing

const std = @import("std");
const driver_mod = @import("driver.zig");
const json = std.json;

pub const Driver = driver_mod.Driver;
pub const DriverVTable = driver_mod.DriverVTable;
pub const DriverError = driver_mod.DriverError;
pub const Selector = driver_mod.Selector;
pub const ElementHandle = driver_mod.ElementHandle;
pub const Rect = driver_mod.Rect;
pub const SwipeDirection = driver_mod.SwipeDirection;
pub const ScrollDirection = driver_mod.ScrollDirection;
pub const AppConfig = driver_mod.AppConfig;
pub const Screenshot = driver_mod.Screenshot;
pub const Platform = driver_mod.Platform;

/// Web driver configuration
pub const WebDriverConfig = struct {
    /// Playwright server host
    host: []const u8 = "127.0.0.1",
    /// Playwright server port
    port: u16 = 9515,
    /// Browser type
    browser: BrowserType = .chromium,
    /// Headless mode
    headless: bool = true,
    /// Connection timeout in ms
    timeout_ms: u32 = 30000,
    /// Viewport width
    viewport_width: u32 = 1280,
    /// Viewport height
    viewport_height: u32 = 720,
};

/// Supported browser types
pub const BrowserType = enum {
    chromium,
    firefox,
    webkit,

    pub fn toString(self: BrowserType) []const u8 {
        return switch (self) {
            .chromium => "chromium",
            .firefox => "firefox",
            .webkit => "webkit",
        };
    }
};

/// Web driver context
pub const WebDriverContext = struct {
    allocator: std.mem.Allocator,
    config: WebDriverConfig,
    session_id: ?[]const u8 = null,
    base_url: ?[]const u8 = null,
    next_element_id: u64 = 1,
    is_running: bool = false,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, config: WebDriverConfig) Self {
        return .{
            .allocator = allocator,
            .config = config,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.session_id) |sid| {
            self.allocator.free(sid);
        }
        if (self.base_url) |url| {
            self.allocator.free(url);
        }
    }

    /// Send command to Playwright server
    pub fn sendCommand(self: *Self, method: []const u8, params: anytype) DriverError![]const u8 {
        const uri = std.fmt.allocPrint(self.allocator, "http://{s}:{d}/session/{s}/{s}", .{
            self.config.host,
            self.config.port,
            self.session_id orelse "new",
            method,
        }) catch return DriverError.OutOfMemory;
        defer self.allocator.free(uri);

        // Serialize params to JSON
        const body = json.stringifyAlloc(self.allocator, params, .{}) catch return DriverError.OutOfMemory;
        defer self.allocator.free(body);

        // Make HTTP request
        return self.httpPost(uri, body);
    }

    /// HTTP POST request
    fn httpPost(self: *Self, uri: []const u8, body: []const u8) DriverError![]const u8 {
        const parsed_uri = std.Uri.parse(uri) catch return DriverError.ConnectionFailed;

        const stream = std.net.tcpConnectToHost(
            self.allocator,
            parsed_uri.host orelse return DriverError.ConnectionFailed,
            parsed_uri.port orelse 80,
        ) catch return DriverError.ConnectionFailed;
        defer stream.close();

        // Build HTTP request
        const request = std.fmt.allocPrint(self.allocator,
            \\POST {s} HTTP/1.1
            \\Host: {s}:{d}
            \\Content-Type: application/json
            \\Content-Length: {d}
            \\Connection: close
            \\
            \\{s}
        , .{
            parsed_uri.path,
            parsed_uri.host orelse "",
            parsed_uri.port orelse 80,
            body.len,
            body,
        }) catch return DriverError.OutOfMemory;
        defer self.allocator.free(request);

        // Send request
        stream.writeAll(request) catch return DriverError.ConnectionFailed;

        // Read response
        var response_buffer: [65536]u8 = undefined;
        const bytes_read = stream.read(&response_buffer) catch return DriverError.ConnectionFailed;

        // Parse response (skip headers, get body)
        const response = response_buffer[0..bytes_read];
        if (std.mem.indexOf(u8, response, "\r\n\r\n")) |header_end| {
            const response_body = response[header_end + 4 ..];
            return self.allocator.dupe(u8, response_body) catch return DriverError.OutOfMemory;
        }

        return DriverError.ConnectionFailed;
    }

    /// Generate next element ID
    pub fn nextElementId(self: *Self) u64 {
        const id = self.next_element_id;
        self.next_element_id += 1;
        return id;
    }
};

/// VTable implementation for web driver
pub const web_driver_vtable = DriverVTable{
    .launch = webLaunch,
    .terminate = webTerminate,
    .reset = webReset,
    .isRunning = webIsRunning,
    .findElement = webFindElement,
    .findElements = webFindElements,
    .waitForElement = webWaitForElement,
    .waitForElementGone = webWaitForElementGone,
    .tap = webTap,
    .doubleTap = webDoubleTap,
    .longPress = webLongPress,
    .typeText = webTypeText,
    .clearText = webClearText,
    .swipe = webSwipe,
    .scroll = webScroll,
    .exists = webExists,
    .isVisible = webIsVisible,
    .isEnabled = webIsEnabled,
    .getText = webGetText,
    .getAttribute = webGetAttribute,
    .getRect = webGetRect,
    .takeScreenshot = webTakeScreenshot,
    .takeElementScreenshot = webTakeElementScreenshot,
    .getState = null,
    .dispatch = null,
    .deinit = webDeinit,
};

// Driver implementation functions

fn webLaunch(ctx: *anyopaque, config: AppConfig) DriverError!void {
    const self: *WebDriverContext = @ptrCast(@alignCast(ctx));

    // Create new browser session
    const params = .{
        .browser = self.config.browser.toString(),
        .headless = self.config.headless,
        .viewport = .{
            .width = self.config.viewport_width,
            .height = self.config.viewport_height,
        },
        .url = config.base_url orelse "about:blank",
    };

    const response = self.sendCommand("launch", params) catch |err| {
        return err;
    };
    defer self.allocator.free(response);

    // Parse session ID from response
    const parsed = json.parseFromSlice(json.Value, self.allocator, response, .{}) catch {
        return DriverError.AppLaunchFailed;
    };
    defer parsed.deinit();

    if (parsed.value.object.get("sessionId")) |sid| {
        if (sid == .string) {
            self.session_id = self.allocator.dupe(u8, sid.string) catch return DriverError.OutOfMemory;
        }
    }

    if (config.base_url) |url| {
        self.base_url = self.allocator.dupe(u8, url) catch return DriverError.OutOfMemory;
    }

    self.is_running = true;
}

fn webTerminate(ctx: *anyopaque) DriverError!void {
    const self: *WebDriverContext = @ptrCast(@alignCast(ctx));

    if (self.session_id) |_| {
        _ = self.sendCommand("close", .{}) catch {};
    }

    self.is_running = false;
}

fn webReset(ctx: *anyopaque) DriverError!void {
    const self: *WebDriverContext = @ptrCast(@alignCast(ctx));

    if (self.base_url) |url| {
        _ = try self.sendCommand("navigate", .{ .url = url });
    }
}

fn webIsRunning(ctx: *anyopaque) bool {
    const self: *WebDriverContext = @ptrCast(@alignCast(ctx));
    return self.is_running;
}

fn webFindElement(ctx: *anyopaque, selector: Selector) DriverError!?ElementHandle {
    const self: *WebDriverContext = @ptrCast(@alignCast(ctx));

    const css_selector = selectorToCss(selector, self.allocator) catch return DriverError.InvalidSelector;
    defer self.allocator.free(css_selector);

    const response = try self.sendCommand("findElement", .{ .selector = css_selector });
    defer self.allocator.free(response);

    const parsed = json.parseFromSlice(json.Value, self.allocator, response, .{}) catch {
        return null;
    };
    defer parsed.deinit();

    if (parsed.value.object.get("elementId")) |eid| {
        if (eid == .string) {
            // Parse element ID string to u64
            const id = std.fmt.parseInt(u64, eid.string, 10) catch self.nextElementId();
            return ElementHandle{ .id = id };
        }
    }

    return null;
}

fn webFindElements(ctx: *anyopaque, selector: Selector, allocator: std.mem.Allocator) DriverError![]ElementHandle {
    const self: *WebDriverContext = @ptrCast(@alignCast(ctx));

    const css_selector = selectorToCss(selector, self.allocator) catch return DriverError.InvalidSelector;
    defer self.allocator.free(css_selector);

    const response = try self.sendCommand("findElements", .{ .selector = css_selector });
    defer self.allocator.free(response);

    const parsed = json.parseFromSlice(json.Value, self.allocator, response, .{}) catch {
        return allocator.alloc(ElementHandle, 0) catch return DriverError.OutOfMemory;
    };
    defer parsed.deinit();

    if (parsed.value.object.get("elements")) |elements| {
        if (elements == .array) {
            var handles = allocator.alloc(ElementHandle, elements.array.items.len) catch return DriverError.OutOfMemory;
            for (elements.array.items, 0..) |elem, i| {
                if (elem == .string) {
                    handles[i] = ElementHandle{
                        .id = std.fmt.parseInt(u64, elem.string, 10) catch self.nextElementId(),
                    };
                } else {
                    handles[i] = ElementHandle{ .id = self.nextElementId() };
                }
            }
            return handles;
        }
    }

    return allocator.alloc(ElementHandle, 0) catch return DriverError.OutOfMemory;
}

fn webWaitForElement(ctx: *anyopaque, selector: Selector, timeout_ms: u32) DriverError!ElementHandle {
    const self: *WebDriverContext = @ptrCast(@alignCast(ctx));

    const css_selector = selectorToCss(selector, self.allocator) catch return DriverError.InvalidSelector;
    defer self.allocator.free(css_selector);

    const response = try self.sendCommand("waitForSelector", .{
        .selector = css_selector,
        .timeout = timeout_ms,
    });
    defer self.allocator.free(response);

    const parsed = json.parseFromSlice(json.Value, self.allocator, response, .{}) catch {
        return DriverError.Timeout;
    };
    defer parsed.deinit();

    if (parsed.value.object.get("elementId")) |eid| {
        if (eid == .string) {
            const id = std.fmt.parseInt(u64, eid.string, 10) catch self.nextElementId();
            return ElementHandle{ .id = id };
        }
    }

    return DriverError.Timeout;
}

fn webWaitForElementGone(ctx: *anyopaque, selector: Selector, timeout_ms: u32) DriverError!void {
    const self: *WebDriverContext = @ptrCast(@alignCast(ctx));

    const css_selector = selectorToCss(selector, self.allocator) catch return DriverError.InvalidSelector;
    defer self.allocator.free(css_selector);

    _ = try self.sendCommand("waitForSelectorHidden", .{
        .selector = css_selector,
        .timeout = timeout_ms,
    });
}

fn webTap(ctx: *anyopaque, handle: ElementHandle) DriverError!void {
    const self: *WebDriverContext = @ptrCast(@alignCast(ctx));
    _ = try self.sendCommand("click", .{ .elementId = handle.id });
}

fn webDoubleTap(ctx: *anyopaque, handle: ElementHandle) DriverError!void {
    const self: *WebDriverContext = @ptrCast(@alignCast(ctx));
    _ = try self.sendCommand("dblclick", .{ .elementId = handle.id });
}

fn webLongPress(ctx: *anyopaque, handle: ElementHandle, duration_ms: u32) DriverError!void {
    const self: *WebDriverContext = @ptrCast(@alignCast(ctx));
    _ = try self.sendCommand("longPress", .{
        .elementId = handle.id,
        .duration = duration_ms,
    });
}

fn webTypeText(ctx: *anyopaque, handle: ElementHandle, text: []const u8) DriverError!void {
    const self: *WebDriverContext = @ptrCast(@alignCast(ctx));
    _ = try self.sendCommand("type", .{
        .elementId = handle.id,
        .text = text,
    });
}

fn webClearText(ctx: *anyopaque, handle: ElementHandle) DriverError!void {
    const self: *WebDriverContext = @ptrCast(@alignCast(ctx));
    _ = try self.sendCommand("clear", .{ .elementId = handle.id });
}

fn webSwipe(ctx: *anyopaque, handle: ElementHandle, direction: SwipeDirection) DriverError!void {
    const self: *WebDriverContext = @ptrCast(@alignCast(ctx));
    const dir_str: []const u8 = switch (direction) {
        .up => "up",
        .down => "down",
        .left => "left",
        .right => "right",
    };
    _ = try self.sendCommand("swipe", .{
        .elementId = handle.id,
        .direction = dir_str,
    });
}

fn webScroll(ctx: *anyopaque, handle: ElementHandle, direction: ScrollDirection, amount: f32) DriverError!void {
    const self: *WebDriverContext = @ptrCast(@alignCast(ctx));
    const dir_str: []const u8 = switch (direction) {
        .up => "up",
        .down => "down",
        .left => "left",
        .right => "right",
    };
    _ = try self.sendCommand("scroll", .{
        .elementId = handle.id,
        .direction = dir_str,
        .amount = amount,
    });
}

fn webExists(ctx: *anyopaque, handle: ElementHandle) bool {
    const self: *WebDriverContext = @ptrCast(@alignCast(ctx));
    const response = self.sendCommand("exists", .{ .elementId = handle.id }) catch return false;
    defer self.allocator.free(response);

    const parsed = json.parseFromSlice(json.Value, self.allocator, response, .{}) catch return false;
    defer parsed.deinit();

    if (parsed.value.object.get("exists")) |exists| {
        return exists == .bool and exists.bool;
    }
    return false;
}

fn webIsVisible(ctx: *anyopaque, handle: ElementHandle) bool {
    const self: *WebDriverContext = @ptrCast(@alignCast(ctx));
    const response = self.sendCommand("isVisible", .{ .elementId = handle.id }) catch return false;
    defer self.allocator.free(response);

    const parsed = json.parseFromSlice(json.Value, self.allocator, response, .{}) catch return false;
    defer parsed.deinit();

    if (parsed.value.object.get("visible")) |visible| {
        return visible == .bool and visible.bool;
    }
    return false;
}

fn webIsEnabled(ctx: *anyopaque, handle: ElementHandle) bool {
    const self: *WebDriverContext = @ptrCast(@alignCast(ctx));
    const response = self.sendCommand("isEnabled", .{ .elementId = handle.id }) catch return false;
    defer self.allocator.free(response);

    const parsed = json.parseFromSlice(json.Value, self.allocator, response, .{}) catch return false;
    defer parsed.deinit();

    if (parsed.value.object.get("enabled")) |enabled| {
        return enabled == .bool and enabled.bool;
    }
    return false;
}

fn webGetText(ctx: *anyopaque, handle: ElementHandle, allocator: std.mem.Allocator) DriverError![]const u8 {
    const self: *WebDriverContext = @ptrCast(@alignCast(ctx));
    const response = try self.sendCommand("getText", .{ .elementId = handle.id });
    defer self.allocator.free(response);

    const parsed = json.parseFromSlice(json.Value, self.allocator, response, .{}) catch {
        return allocator.dupe(u8, "") catch return DriverError.OutOfMemory;
    };
    defer parsed.deinit();

    if (parsed.value.object.get("text")) |text| {
        if (text == .string) {
            return allocator.dupe(u8, text.string) catch return DriverError.OutOfMemory;
        }
    }
    return allocator.dupe(u8, "") catch return DriverError.OutOfMemory;
}

fn webGetAttribute(ctx: *anyopaque, handle: ElementHandle, name: []const u8, allocator: std.mem.Allocator) DriverError!?[]const u8 {
    const self: *WebDriverContext = @ptrCast(@alignCast(ctx));
    const response = try self.sendCommand("getAttribute", .{
        .elementId = handle.id,
        .name = name,
    });
    defer self.allocator.free(response);

    const parsed = json.parseFromSlice(json.Value, self.allocator, response, .{}) catch {
        return null;
    };
    defer parsed.deinit();

    if (parsed.value.object.get("value")) |value| {
        if (value == .string) {
            return allocator.dupe(u8, value.string) catch return DriverError.OutOfMemory;
        }
    }
    return null;
}

fn webGetRect(ctx: *anyopaque, handle: ElementHandle) DriverError!Rect {
    const self: *WebDriverContext = @ptrCast(@alignCast(ctx));
    const response = try self.sendCommand("getRect", .{ .elementId = handle.id });
    defer self.allocator.free(response);

    const parsed = json.parseFromSlice(json.Value, self.allocator, response, .{}) catch {
        return Rect{ .x = 0, .y = 0, .width = 0, .height = 0 };
    };
    defer parsed.deinit();

    var rect = Rect{ .x = 0, .y = 0, .width = 0, .height = 0 };

    if (parsed.value.object.get("x")) |x| {
        if (x == .float) rect.x = @floatCast(x.float);
        if (x == .integer) rect.x = @floatFromInt(x.integer);
    }
    if (parsed.value.object.get("y")) |y| {
        if (y == .float) rect.y = @floatCast(y.float);
        if (y == .integer) rect.y = @floatFromInt(y.integer);
    }
    if (parsed.value.object.get("width")) |w| {
        if (w == .float) rect.width = @floatCast(w.float);
        if (w == .integer) rect.width = @floatFromInt(w.integer);
    }
    if (parsed.value.object.get("height")) |h| {
        if (h == .float) rect.height = @floatCast(h.float);
        if (h == .integer) rect.height = @floatFromInt(h.integer);
    }

    return rect;
}

fn webTakeScreenshot(ctx: *anyopaque, allocator: std.mem.Allocator) DriverError!Screenshot {
    const self: *WebDriverContext = @ptrCast(@alignCast(ctx));
    const response = try self.sendCommand("screenshot", .{});
    defer self.allocator.free(response);

    const parsed = json.parseFromSlice(json.Value, self.allocator, response, .{}) catch {
        return DriverError.ScreenshotFailed;
    };
    defer parsed.deinit();

    // Response contains base64 encoded PNG
    if (parsed.value.object.get("data")) |data| {
        if (data == .string) {
            // Decode base64
            const decoded = decodeBase64(data.string, allocator) catch return DriverError.ScreenshotFailed;
            return Screenshot{
                .width = self.config.viewport_width,
                .height = self.config.viewport_height,
                .pixels = decoded,
                .format = .png,
            };
        }
    }

    return DriverError.ScreenshotFailed;
}

fn webTakeElementScreenshot(ctx: *anyopaque, handle: ElementHandle, allocator: std.mem.Allocator) DriverError!Screenshot {
    const self: *WebDriverContext = @ptrCast(@alignCast(ctx));
    const response = try self.sendCommand("elementScreenshot", .{ .elementId = handle.id });
    defer self.allocator.free(response);

    const parsed = json.parseFromSlice(json.Value, self.allocator, response, .{}) catch {
        return DriverError.ScreenshotFailed;
    };
    defer parsed.deinit();

    if (parsed.value.object.get("data")) |data| {
        if (data == .string) {
            const decoded = decodeBase64(data.string, allocator) catch return DriverError.ScreenshotFailed;

            var width: u32 = 100;
            var height: u32 = 100;

            if (parsed.value.object.get("width")) |w| {
                if (w == .integer) width = @intCast(w.integer);
            }
            if (parsed.value.object.get("height")) |h| {
                if (h == .integer) height = @intCast(h.integer);
            }

            return Screenshot{
                .width = width,
                .height = height,
                .pixels = decoded,
                .format = .png,
            };
        }
    }

    return DriverError.ScreenshotFailed;
}

fn webDeinit(ctx: *anyopaque) void {
    const self: *WebDriverContext = @ptrCast(@alignCast(ctx));
    self.deinit();
}

// Helper functions

fn selectorToCss(selector: Selector, allocator: std.mem.Allocator) ![]const u8 {
    if (selector.test_id) |tid| {
        return std.fmt.allocPrint(allocator, "[data-testid=\"{s}\"]", .{tid});
    }
    if (selector.accessibility_id) |aid| {
        return std.fmt.allocPrint(allocator, "[aria-label=\"{s}\"]", .{aid});
    }
    if (selector.text) |text| {
        // Use XPath-like text selector via attribute
        return std.fmt.allocPrint(allocator, ":text(\"{s}\")", .{text});
    }
    if (selector.text_contains) |text| {
        return std.fmt.allocPrint(allocator, ":text-matches(\"{s}\")", .{text});
    }

    return error.InvalidSelector;
}

fn decodeBase64(input: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    const decoder = std.base64.standard.Decoder;
    const decoded_len = decoder.calcSizeForSlice(input) catch return error.InvalidBase64;
    const buffer = try allocator.alloc(u8, decoded_len);
    decoder.decode(buffer, input) catch {
        allocator.free(buffer);
        return error.InvalidBase64;
    };
    return buffer;
}

/// Create a new web driver
pub fn createWebDriver(allocator: std.mem.Allocator, config: WebDriverConfig) !Driver {
    const context = try allocator.create(WebDriverContext);
    context.* = WebDriverContext.init(allocator, config);

    return Driver.init(
        &web_driver_vtable,
        context,
        allocator,
        .web,
    );
}

// Tests
test "web driver config" {
    const config = WebDriverConfig{
        .browser = .chromium,
        .headless = true,
    };
    try std.testing.expectEqualStrings("chromium", config.browser.toString());
}

test "selector to css" {
    const allocator = std.testing.allocator;

    const sel1 = Selector{ .test_id = "my-button" };
    const css1 = try selectorToCss(sel1, allocator);
    defer allocator.free(css1);
    try std.testing.expectEqualStrings("[data-testid=\"my-button\"]", css1);

    const sel2 = Selector{ .accessibility_id = "submit" };
    const css2 = try selectorToCss(sel2, allocator);
    defer allocator.free(css2);
    try std.testing.expectEqualStrings("[aria-label=\"submit\"]", css2);
}
