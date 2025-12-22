// Zylix Test Framework - Linux AT-SPI Driver
// Desktop automation using AT-SPI2 (Assistive Technology Service Provider Interface)
//
// Communication: HTTP bridge to Python/DBus AT-SPI server
// Port: 8300 (default)

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Linux driver configuration
pub const LinuxDriverConfig = struct {
    /// AT-SPI bridge host
    host: []const u8 = "127.0.0.1",
    /// AT-SPI bridge port
    port: u16 = 8300,
    /// App launch timeout in milliseconds
    launch_timeout_ms: u32 = 30000,
    /// Element find timeout in milliseconds
    element_timeout_ms: u32 = 10000,
    /// Display for X11/Wayland (e.g., ":0")
    display: ?[]const u8 = null,
    /// Enable accessibility features
    enable_accessibility: bool = true,
};

/// Linux AT-SPI driver for desktop automation
pub const LinuxDriver = struct {
    allocator: Allocator,
    config: LinuxDriverConfig,
    session_id: ?[]const u8,
    pid: ?i32,

    const Self = @This();

    /// Initialize the Linux driver
    pub fn init(allocator: Allocator, config: LinuxDriverConfig) !Self {
        return Self{
            .allocator = allocator,
            .config = config,
            .session_id = null,
            .pid = null,
        };
    }

    /// Clean up driver resources
    pub fn deinit(self: *Self) void {
        if (self.session_id) |sid| {
            self.allocator.free(sid);
            self.session_id = null;
        }
    }

    /// Launch an application
    pub fn launchApp(self: *Self, options: LaunchOptions) !void {
        var body = std.ArrayList(u8).init(self.allocator);
        defer body.deinit();

        const writer = body.writer();

        // Build JSON request
        try writer.writeAll("{");

        if (options.desktop_file) |df| {
            try writer.print("\"desktopFile\":\"{s}\"", .{df});
        } else if (options.executable) |exe| {
            try writer.print("\"executable\":\"{s}\"", .{exe});
            if (options.args) |args| {
                try writer.writeAll(",\"args\":[");
                for (args, 0..) |arg, i| {
                    if (i > 0) try writer.writeAll(",");
                    try writer.print("\"{s}\"", .{arg});
                }
                try writer.writeAll("]");
            }
        } else if (options.window_name) |wn| {
            try writer.print("\"windowName\":\"{s}\"", .{wn});
        } else {
            return error.MissingAppIdentifier;
        }

        if (options.working_dir) |wd| {
            try writer.print(",\"workingDir\":\"{s}\"", .{wd});
        }

        if (self.config.display) |display| {
            try writer.print(",\"display\":\"{s}\"", .{display});
        }

        try writer.writeAll("}");

        const response = try self.sendCommand("/session/new/launch", body.items);
        defer self.allocator.free(response);

        // Parse response for session ID
        if (try self.parseJsonString(response, "sessionId")) |sid| {
            self.session_id = sid;
        }

        if (try self.parseJsonInt(response, "pid")) |pid| {
            self.pid = @intCast(pid);
        }
    }

    /// Attach to a running application
    pub fn attachToApp(self: *Self, options: AttachOptions) !void {
        var body = std.ArrayList(u8).init(self.allocator);
        defer body.deinit();

        const writer = body.writer();
        try writer.writeAll("{");

        if (options.pid) |pid| {
            try writer.print("\"pid\":{d}", .{pid});
        } else if (options.window_name) |wn| {
            try writer.print("\"windowName\":\"{s}\"", .{wn});
        } else if (options.app_name) |an| {
            try writer.print("\"appName\":\"{s}\"", .{an});
        } else {
            return error.MissingAppIdentifier;
        }

        try writer.writeAll("}");

        const response = try self.sendCommand("/session/new/attach", body.items);
        defer self.allocator.free(response);

        if (try self.parseJsonString(response, "sessionId")) |sid| {
            self.session_id = sid;
        }

        if (try self.parseJsonInt(response, "pid")) |pid| {
            self.pid = @intCast(pid);
        }
    }

    /// Close the session
    pub fn close(self: *Self) !void {
        if (self.session_id) |sid| {
            const path = try std.fmt.allocPrint(self.allocator, "/session/{s}/close", .{sid});
            defer self.allocator.free(path);

            const response = try self.sendCommand(path, "{}");
            self.allocator.free(response);

            self.allocator.free(sid);
            self.session_id = null;
            self.pid = null;
        }
    }

    /// Find an element using AT-SPI selectors
    pub fn findElement(self: *Self, selector: ElementSelector) !?Element {
        const sid = self.session_id orelse return error.NoSession;

        var body = std.ArrayList(u8).init(self.allocator);
        defer body.deinit();

        const writer = body.writer();
        try writer.writeAll("{");
        try writer.print("\"strategy\":\"{s}\",\"value\":\"{s}\"", .{
            @tagName(selector.strategy),
            selector.value,
        });
        try writer.writeAll("}");

        const path = try std.fmt.allocPrint(self.allocator, "/session/{s}/findElement", .{sid});
        defer self.allocator.free(path);

        const response = try self.sendCommand(path, body.items);
        defer self.allocator.free(response);

        if (try self.parseJsonString(response, "elementId")) |eid| {
            return Element{
                .driver = self,
                .element_id = eid,
            };
        }

        return null;
    }

    /// Find multiple elements
    pub fn findElements(self: *Self, selector: ElementSelector) ![]Element {
        const sid = self.session_id orelse return error.NoSession;

        var body = std.ArrayList(u8).init(self.allocator);
        defer body.deinit();

        const writer = body.writer();
        try writer.writeAll("{");
        try writer.print("\"strategy\":\"{s}\",\"value\":\"{s}\"", .{
            @tagName(selector.strategy),
            selector.value,
        });
        try writer.writeAll("}");

        const path = try std.fmt.allocPrint(self.allocator, "/session/{s}/findElements", .{sid});
        defer self.allocator.free(path);

        const response = try self.sendCommand(path, body.items);
        defer self.allocator.free(response);

        // Parse element IDs from response
        var elements = std.ArrayList(Element).init(self.allocator);

        if (try self.parseJsonStringArray(response, "elements")) |ids| {
            defer {
                for (ids) |id| self.allocator.free(id);
                self.allocator.free(ids);
            }

            for (ids) |id| {
                const eid = try self.allocator.dupe(u8, id);
                try elements.append(Element{
                    .driver = self,
                    .element_id = eid,
                });
            }
        }

        return elements.toOwnedSlice();
    }

    /// Wait for an element to appear
    pub fn waitForElement(self: *Self, selector: ElementSelector, timeout_ms: ?u32) !?Element {
        const timeout = timeout_ms orelse self.config.element_timeout_ms;
        const start = std.time.milliTimestamp();

        while (std.time.milliTimestamp() - start < timeout) {
            if (try self.findElement(selector)) |element| {
                return element;
            }
            std.time.sleep(100 * std.time.ns_per_ms);
        }

        return null;
    }

    /// Take a screenshot of the application window
    pub fn takeScreenshot(self: *Self) ![]const u8 {
        const sid = self.session_id orelse return error.NoSession;

        const path = try std.fmt.allocPrint(self.allocator, "/session/{s}/screenshot", .{sid});
        defer self.allocator.free(path);

        const response = try self.sendCommand(path, "{}");
        defer self.allocator.free(response);

        if (try self.parseJsonString(response, "data")) |data| {
            return data;
        }

        return error.ScreenshotFailed;
    }

    /// Get window information
    pub fn getWindowInfo(self: *Self) !WindowInfo {
        const sid = self.session_id orelse return error.NoSession;

        const path = try std.fmt.allocPrint(self.allocator, "/session/{s}/window", .{sid});
        defer self.allocator.free(path);

        const response = try self.sendCommand(path, "{}");
        defer self.allocator.free(response);

        return WindowInfo{
            .title = try self.parseJsonString(response, "title"),
            .x = @intCast(try self.parseJsonInt(response, "x") orelse 0),
            .y = @intCast(try self.parseJsonInt(response, "y") orelse 0),
            .width = @intCast(try self.parseJsonInt(response, "width") orelse 0),
            .height = @intCast(try self.parseJsonInt(response, "height") orelse 0),
        };
    }

    /// Send keyboard input
    pub fn sendKeys(self: *Self, keys: []const u8) !void {
        const sid = self.session_id orelse return error.NoSession;

        var body = std.ArrayList(u8).init(self.allocator);
        defer body.deinit();

        try body.writer().print("{{\"keys\":\"{s}\"}}", .{keys});

        const path = try std.fmt.allocPrint(self.allocator, "/session/{s}/keys", .{sid});
        defer self.allocator.free(path);

        const response = try self.sendCommand(path, body.items);
        self.allocator.free(response);
    }

    /// Send command to AT-SPI bridge
    fn sendCommand(self: *Self, path: []const u8, body: []const u8) ![]const u8 {
        const address = std.net.Address.parseIp4(self.config.host, self.config.port) catch {
            return error.InvalidAddress;
        };

        const stream = std.net.tcpConnectToAddress(address) catch {
            return error.ConnectionFailed;
        };
        defer stream.close();

        // Build HTTP request
        var request = std.ArrayList(u8).init(self.allocator);
        defer request.deinit();

        const writer = request.writer();
        try writer.print("POST {s} HTTP/1.1\r\n", .{path});
        try writer.print("Host: {s}:{d}\r\n", .{ self.config.host, self.config.port });
        try writer.writeAll("Content-Type: application/json\r\n");
        try writer.print("Content-Length: {d}\r\n", .{body.len});
        try writer.writeAll("\r\n");
        try writer.writeAll(body);

        _ = stream.write(request.items) catch {
            return error.SendFailed;
        };

        // Read response
        var response_buf: [65536]u8 = undefined;
        const bytes_read = stream.read(&response_buf) catch {
            return error.ReadFailed;
        };

        if (bytes_read == 0) {
            return error.EmptyResponse;
        }

        const response = response_buf[0..bytes_read];

        // Find body start
        if (std.mem.indexOf(u8, response, "\r\n\r\n")) |body_start| {
            const json_body = response[body_start + 4 ..];
            return try self.allocator.dupe(u8, json_body);
        }

        return try self.allocator.dupe(u8, response);
    }

    /// Parse a string value from JSON
    fn parseJsonString(self: *Self, json: []const u8, key: []const u8) !?[]const u8 {
        const search_key = try std.fmt.allocPrint(self.allocator, "\"{s}\":\"", .{key});
        defer self.allocator.free(search_key);

        if (std.mem.indexOf(u8, json, search_key)) |start| {
            const value_start = start + search_key.len;
            if (std.mem.indexOfPos(u8, json, value_start, "\"")) |end| {
                return try self.allocator.dupe(u8, json[value_start..end]);
            }
        }
        return null;
    }

    /// Parse an integer value from JSON
    fn parseJsonInt(_: *Self, json: []const u8, key: []const u8) !?i64 {
        var search_buf: [128]u8 = undefined;
        const search_key = try std.fmt.bufPrint(&search_buf, "\"{s}\":", .{key});

        if (std.mem.indexOf(u8, json, search_key)) |start| {
            const value_start = start + search_key.len;
            var end = value_start;
            while (end < json.len and (json[end] == '-' or (json[end] >= '0' and json[end] <= '9'))) {
                end += 1;
            }
            if (end > value_start) {
                return std.fmt.parseInt(i64, json[value_start..end], 10) catch null;
            }
        }
        return null;
    }

    /// Parse string array from JSON
    fn parseJsonStringArray(self: *Self, json: []const u8, key: []const u8) !?[][]const u8 {
        const search_key = try std.fmt.allocPrint(self.allocator, "\"{s}\":[", .{key});
        defer self.allocator.free(search_key);

        if (std.mem.indexOf(u8, json, search_key)) |start| {
            const array_start = start + search_key.len;
            if (std.mem.indexOfPos(u8, json, array_start, "]")) |array_end| {
                const array_content = json[array_start..array_end];

                var items = std.ArrayList([]const u8).init(self.allocator);

                var iter = std.mem.splitSequence(u8, array_content, ",");
                while (iter.next()) |item| {
                    const trimmed = std.mem.trim(u8, item, " \t\n\r\"");
                    if (trimmed.len > 0) {
                        try items.append(try self.allocator.dupe(u8, trimmed));
                    }
                }

                return items.toOwnedSlice();
            }
        }
        return null;
    }

    /// Parse boolean from JSON
    fn parseJsonBool(_: *Self, json: []const u8, key: []const u8) !?bool {
        var search_buf: [128]u8 = undefined;
        const search_key = try std.fmt.bufPrint(&search_buf, "\"{s}\":", .{key});

        if (std.mem.indexOf(u8, json, search_key)) |start| {
            const value_start = start + search_key.len;
            const remaining = json[value_start..];
            if (std.mem.startsWith(u8, remaining, "true")) {
                return true;
            } else if (std.mem.startsWith(u8, remaining, "false")) {
                return false;
            }
        }
        return null;
    }
};

/// Launch options for Linux apps
pub const LaunchOptions = struct {
    /// Desktop file name (e.g., "org.gnome.Calculator.desktop")
    desktop_file: ?[]const u8 = null,
    /// Executable path
    executable: ?[]const u8 = null,
    /// Command line arguments
    args: ?[]const []const u8 = null,
    /// Working directory
    working_dir: ?[]const u8 = null,
    /// Window name pattern to attach to
    window_name: ?[]const u8 = null,
};

/// Options for attaching to existing apps
pub const AttachOptions = struct {
    /// Process ID
    pid: ?i32 = null,
    /// Window name pattern
    window_name: ?[]const u8 = null,
    /// Application name
    app_name: ?[]const u8 = null,
};

/// Element selector for AT-SPI
pub const ElementSelector = struct {
    strategy: SelectorStrategy,
    value: []const u8,

    pub const SelectorStrategy = enum {
        /// AT-SPI role name (e.g., "push button", "text")
        role,
        /// Accessible name/label
        name,
        /// Accessible description
        description,
        /// Application name
        application,
        /// State-based selector (e.g., "focusable", "visible")
        state,
        /// Hierarchical path selector
        path,
        /// Predicate expression
        predicate,
    };
};

/// Window information
pub const WindowInfo = struct {
    title: ?[]const u8,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
};

/// AT-SPI element wrapper
pub const Element = struct {
    driver: *LinuxDriver,
    element_id: []const u8,

    const Self = @This();

    /// Clean up element
    pub fn deinit(self: *Self) void {
        self.driver.allocator.free(self.element_id);
    }

    /// Click on the element
    pub fn click(self: *Self) !void {
        try self.performAction("click", "{}");
    }

    /// Double-click on the element
    pub fn doubleClick(self: *Self) !void {
        try self.performAction("doubleClick", "{}");
    }

    /// Right-click on the element
    pub fn rightClick(self: *Self) !void {
        try self.performAction("rightClick", "{}");
    }

    /// Type text into the element
    pub fn typeText(self: *Self, text: []const u8) !void {
        var body = std.ArrayList(u8).init(self.driver.allocator);
        defer body.deinit();

        try body.writer().print("{{\"text\":\"{s}\"}}", .{text});
        try self.performAction("type", body.items);
    }

    /// Clear the element's text
    pub fn clear(self: *Self) !void {
        try self.performAction("clear", "{}");
    }

    /// Get element text
    pub fn getText(self: *Self) !?[]const u8 {
        return try self.getProperty("getText");
    }

    /// Get element name
    pub fn getName(self: *Self) !?[]const u8 {
        return try self.getProperty("getName");
    }

    /// Get element role
    pub fn getRole(self: *Self) !?[]const u8 {
        return try self.getProperty("getRole");
    }

    /// Get element description
    pub fn getDescription(self: *Self) !?[]const u8 {
        return try self.getProperty("getDescription");
    }

    /// Check if element is visible
    pub fn isVisible(self: *Self) !bool {
        const response = try self.getPropertyRaw("isVisible");
        defer self.driver.allocator.free(response);
        return (try self.driver.parseJsonBool(response, "value")) orelse false;
    }

    /// Check if element is enabled
    pub fn isEnabled(self: *Self) !bool {
        const response = try self.getPropertyRaw("isEnabled");
        defer self.driver.allocator.free(response);
        return (try self.driver.parseJsonBool(response, "value")) orelse false;
    }

    /// Check if element is focused
    pub fn isFocused(self: *Self) !bool {
        const response = try self.getPropertyRaw("isFocused");
        defer self.driver.allocator.free(response);
        return (try self.driver.parseJsonBool(response, "value")) orelse false;
    }

    /// Focus the element
    pub fn focus(self: *Self) !void {
        try self.performAction("focus", "{}");
    }

    /// Get element bounds
    pub fn getBounds(self: *Self) !ElementBounds {
        const response = try self.getPropertyRaw("getBounds");
        defer self.driver.allocator.free(response);

        return ElementBounds{
            .x = @intCast((try self.driver.parseJsonInt(response, "x")) orelse 0),
            .y = @intCast((try self.driver.parseJsonInt(response, "y")) orelse 0),
            .width = @intCast((try self.driver.parseJsonInt(response, "width")) orelse 0),
            .height = @intCast((try self.driver.parseJsonInt(response, "height")) orelse 0),
        };
    }

    /// Get element attribute
    pub fn getAttribute(self: *Self, name: []const u8) !?[]const u8 {
        var body = std.ArrayList(u8).init(self.driver.allocator);
        defer body.deinit();

        try body.writer().print("{{\"name\":\"{s}\"}}", .{name});

        const sid = self.driver.session_id orelse return error.NoSession;
        const path = try std.fmt.allocPrint(
            self.driver.allocator,
            "/session/{s}/getAttribute",
            .{sid},
        );
        defer self.driver.allocator.free(path);

        var full_body = std.ArrayList(u8).init(self.driver.allocator);
        defer full_body.deinit();
        try full_body.writer().print("{{\"elementId\":\"{s}\",\"name\":\"{s}\"}}", .{ self.element_id, name });

        const response = try self.driver.sendCommand(path, full_body.items);
        defer self.driver.allocator.free(response);

        return try self.driver.parseJsonString(response, "value");
    }

    /// Take element screenshot
    pub fn takeScreenshot(self: *Self) ![]const u8 {
        const sid = self.driver.session_id orelse return error.NoSession;

        var body = std.ArrayList(u8).init(self.driver.allocator);
        defer body.deinit();

        try body.writer().print("{{\"elementId\":\"{s}\"}}", .{self.element_id});

        const path = try std.fmt.allocPrint(
            self.driver.allocator,
            "/session/{s}/elementScreenshot",
            .{sid},
        );
        defer self.driver.allocator.free(path);

        const response = try self.driver.sendCommand(path, body.items);
        defer self.driver.allocator.free(response);

        if (try self.driver.parseJsonString(response, "data")) |data| {
            return data;
        }

        return error.ScreenshotFailed;
    }

    /// Find child element
    pub fn findElement(self: *Self, selector: ElementSelector) !?Element {
        const sid = self.driver.session_id orelse return error.NoSession;

        var body = std.ArrayList(u8).init(self.driver.allocator);
        defer body.deinit();

        try body.writer().print(
            "{{\"parentId\":\"{s}\",\"strategy\":\"{s}\",\"value\":\"{s}\"}}",
            .{ self.element_id, @tagName(selector.strategy), selector.value },
        );

        const path = try std.fmt.allocPrint(
            self.driver.allocator,
            "/session/{s}/findElement",
            .{sid},
        );
        defer self.driver.allocator.free(path);

        const response = try self.driver.sendCommand(path, body.items);
        defer self.driver.allocator.free(response);

        if (try self.driver.parseJsonString(response, "elementId")) |eid| {
            return Element{
                .driver = self.driver,
                .element_id = eid,
            };
        }

        return null;
    }

    /// Perform an action on the element
    fn performAction(self: *Self, action: []const u8, extra_body: []const u8) !void {
        const sid = self.driver.session_id orelse return error.NoSession;

        var body = std.ArrayList(u8).init(self.driver.allocator);
        defer body.deinit();

        const writer = body.writer();
        try writer.print("{{\"elementId\":\"{s}\"", .{self.element_id});

        // Merge extra body
        if (extra_body.len > 2) {
            try writer.writeAll(",");
            // Skip opening brace
            try writer.writeAll(extra_body[1..]);
        } else {
            try writer.writeAll("}");
        }

        const path = try std.fmt.allocPrint(
            self.driver.allocator,
            "/session/{s}/{s}",
            .{ sid, action },
        );
        defer self.driver.allocator.free(path);

        const response = try self.driver.sendCommand(path, body.items);
        self.driver.allocator.free(response);
    }

    /// Get a property
    fn getProperty(self: *Self, property: []const u8) !?[]const u8 {
        const response = try self.getPropertyRaw(property);
        defer self.driver.allocator.free(response);
        return try self.driver.parseJsonString(response, "value");
    }

    /// Get raw property response
    fn getPropertyRaw(self: *Self, property: []const u8) ![]const u8 {
        const sid = self.driver.session_id orelse return error.NoSession;

        var body = std.ArrayList(u8).init(self.driver.allocator);
        defer body.deinit();

        try body.writer().print("{{\"elementId\":\"{s}\"}}", .{self.element_id});

        const path = try std.fmt.allocPrint(
            self.driver.allocator,
            "/session/{s}/{s}",
            .{ sid, property },
        );
        defer self.driver.allocator.free(path);

        return try self.driver.sendCommand(path, body.items);
    }
};

/// Element bounds
pub const ElementBounds = struct {
    x: i32,
    y: i32,
    width: i32,
    height: i32,
};

// Tests
test "LinuxDriver initialization" {
    const allocator = std.testing.allocator;

    var driver = try LinuxDriver.init(allocator, .{});
    defer driver.deinit();

    try std.testing.expectEqual(@as(u16, 8300), driver.config.port);
    try std.testing.expectEqualStrings("127.0.0.1", driver.config.host);
    try std.testing.expect(driver.config.enable_accessibility);
}

test "LinuxDriver custom config" {
    const allocator = std.testing.allocator;

    var driver = try LinuxDriver.init(allocator, .{
        .host = "192.168.1.100",
        .port = 9300,
        .display = ":1",
        .launch_timeout_ms = 60000,
    });
    defer driver.deinit();

    try std.testing.expectEqual(@as(u16, 9300), driver.config.port);
    try std.testing.expectEqualStrings("192.168.1.100", driver.config.host);
    try std.testing.expectEqualStrings(":1", driver.config.display.?);
}

test "ElementSelector strategies" {
    const role_selector = ElementSelector{
        .strategy = .role,
        .value = "push button",
    };
    try std.testing.expectEqual(ElementSelector.SelectorStrategy.role, role_selector.strategy);

    const name_selector = ElementSelector{
        .strategy = .name,
        .value = "Submit",
    };
    try std.testing.expectEqual(ElementSelector.SelectorStrategy.name, name_selector.strategy);
}
