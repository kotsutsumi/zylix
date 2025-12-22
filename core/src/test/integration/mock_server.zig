//! Mock HTTP Server for Integration Testing
//!
//! Provides a simple HTTP server that simulates bridge server responses
//! for testing Zig driver ↔ Bridge communication.
//!
//! Compatible with Zig 0.15.

const std = @import("std");

/// Mock server response
pub const MockResponse = struct {
    status_code: u16 = 200,
    body: []const u8 = "{}",
    content_type: []const u8 = "application/json",
};

/// Mock endpoint handler
pub const EndpointHandler = *const fn (path: []const u8, body: []const u8) MockResponse;

/// Mock HTTP Server for testing
pub const MockServer = struct {
    allocator: std.mem.Allocator,
    port: u16,
    listener: ?std.net.Server = null,
    thread: ?std.Thread = null,
    running: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    // Request logging
    requests: RequestLog,
    mutex: std.Thread.Mutex = .{},

    // Custom handler
    handler: ?EndpointHandler = null,

    const Self = @This();

    pub const RequestLog = struct {
        entries: std.ArrayListUnmanaged(Request) = .{},
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) RequestLog {
            return .{
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *RequestLog) void {
            for (self.entries.items) |entry| {
                self.allocator.free(entry.method);
                self.allocator.free(entry.path);
                self.allocator.free(entry.body);
            }
            self.entries.deinit(self.allocator);
        }

        pub fn add(self: *RequestLog, method: []const u8, path: []const u8, body: []const u8) !void {
            try self.entries.append(self.allocator, .{
                .method = try self.allocator.dupe(u8, method),
                .path = try self.allocator.dupe(u8, path),
                .body = try self.allocator.dupe(u8, body),
            });
        }
    };

    pub const Request = struct {
        method: []const u8,
        path: []const u8,
        body: []const u8,
    };

    pub fn init(allocator: std.mem.Allocator, port: u16) Self {
        return .{
            .allocator = allocator,
            .port = port,
            .requests = RequestLog.init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.stop();
        self.requests.deinit();
    }

    /// Set custom handler for requests
    pub fn setHandler(self: *Self, handler: EndpointHandler) void {
        self.handler = handler;
    }

    /// Start the mock server
    pub fn start(self: *Self) !void {
        const address = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, self.port);
        self.listener = try address.listen(.{
            .reuse_address = true,
        });
        self.running.store(true, .release);
        self.thread = try std.Thread.spawn(.{}, serverLoop, .{self});
    }

    /// Stop the mock server
    pub fn stop(self: *Self) void {
        self.running.store(false, .release);
        if (self.listener) |*listener| {
            listener.deinit();
            self.listener = null;
        }
        if (self.thread) |thread| {
            thread.join();
            self.thread = null;
        }
    }

    /// Get all logged requests
    pub fn getRequests(self: *Self) []const Request {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.requests.entries.items;
    }

    /// Clear request log
    pub fn clearRequests(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        for (self.requests.entries.items) |entry| {
            self.allocator.free(entry.method);
            self.allocator.free(entry.path);
            self.allocator.free(entry.body);
        }
        self.requests.entries.clearRetainingCapacity();
    }

    fn serverLoop(self: *Self) void {
        while (self.running.load(.acquire)) {
            if (self.listener) |*listener| {
                const conn = listener.accept() catch |err| {
                    if (err == error.ConnectionAborted) break;
                    continue;
                };
                self.handleConnection(conn.stream) catch {};
            } else {
                break;
            }
        }
    }

    fn handleConnection(self: *Self, stream: std.net.Stream) !void {
        defer stream.close();

        // Read request
        var buffer: [8192]u8 = undefined;
        const bytes_read = try stream.read(&buffer);
        if (bytes_read == 0) return;

        const request_data = buffer[0..bytes_read];

        // Parse request line
        var lines = std.mem.splitSequence(u8, request_data, "\r\n");
        const request_line = lines.first();

        var parts = std.mem.splitSequence(u8, request_line, " ");
        const method = parts.next() orelse "GET";
        const path = parts.next() orelse "/";

        // Find body (after empty line)
        var body: []const u8 = "";
        if (std.mem.indexOf(u8, request_data, "\r\n\r\n")) |body_start| {
            body = request_data[body_start + 4 ..];
        }

        // Log request
        {
            self.mutex.lock();
            defer self.mutex.unlock();
            self.requests.add(method, path, body) catch {};
        }

        // Generate response
        const response = if (self.handler) |handler| handler(path, body) else defaultHandler(path, body);

        // Send response
        var response_buf: [4096]u8 = undefined;
        const response_str = std.fmt.bufPrint(&response_buf,
            \\HTTP/1.1 {d} OK
            \\Content-Type: {s}
            \\Content-Length: {d}
            \\Connection: close
            \\
            \\{s}
        , .{
            response.status_code,
            response.content_type,
            response.body.len,
            response.body,
        }) catch return;

        _ = stream.write(response_str) catch {};
    }

    fn defaultHandler(path: []const u8, body: []const u8) MockResponse {
        _ = body;

        // Default mock responses based on path
        if (std.mem.indexOf(u8, path, "/launch") != null) {
            return .{ .body =
                \\{"sessionId":"mock-session-1","success":true}
            };
        }
        if (std.mem.indexOf(u8, path, "/findElement") != null) {
            return .{ .body =
                \\{"elementId":"1"}
            };
        }
        if (std.mem.indexOf(u8, path, "/findElements") != null) {
            return .{ .body =
                \\{"elements":["1","2","3"]}
            };
        }
        if (std.mem.indexOf(u8, path, "/click") != null or
            std.mem.indexOf(u8, path, "/type") != null or
            std.mem.indexOf(u8, path, "/clear") != null)
        {
            return .{ .body =
                \\{"success":true}
            };
        }
        if (std.mem.indexOf(u8, path, "/getText") != null) {
            return .{ .body =
                \\{"text":"Mock Text"}
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
        if (std.mem.indexOf(u8, path, "/exists") != null) {
            return .{ .body =
                \\{"exists":true}
            };
        }
        if (std.mem.indexOf(u8, path, "/getRect") != null) {
            return .{ .body =
                \\{"x":10,"y":20,"width":100,"height":50}
            };
        }
        if (std.mem.indexOf(u8, path, "/screenshot") != null) {
            return .{ .body =
                \\{"data":"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==","width":1,"height":1}
            };
        }
        if (std.mem.indexOf(u8, path, "/close") != null) {
            return .{ .body =
                \\{"success":true}
            };
        }
        if (std.mem.indexOf(u8, path, "/waitForSelector") != null) {
            return .{ .body =
                \\{"elementId":"1"}
            };
        }
        if (std.mem.indexOf(u8, path, "/navigate") != null) {
            return .{ .body =
                \\{"success":true}
            };
        }

        // Default response
        return .{ .body =
            \\{"error":"Unknown endpoint"}
        , .status_code = 404 };
    }
};

/// Platform-specific mock responses
pub const PlatformMocks = struct {
    /// Web/Playwright mock responses
    pub fn webHandler(path: []const u8, body: []const u8) MockResponse {
        if (std.mem.indexOf(u8, path, "/launch") != null) {
            return .{ .body =
                \\{"sessionId":"playwright-session-1","success":true,"browser":"chromium"}
            };
        }
        return defaultHandler(path, body);
    }

    /// iOS/XCUITest mock responses
    pub fn iosHandler(path: []const u8, body: []const u8) MockResponse {
        if (std.mem.indexOf(u8, path, "/session/new") != null) {
            return .{ .body =
                \\{"sessionId":"xcuitest-session-1","success":true}
            };
        }
        if (std.mem.indexOf(u8, path, "/element") != null and std.mem.indexOf(u8, path, "/click") != null) {
            return .{ .body =
                \\{"success":true}
            };
        }
        return defaultHandler(path, body);
    }

    /// Android/UIAutomator2 mock responses
    pub fn androidHandler(path: []const u8, body: []const u8) MockResponse {
        if (std.mem.indexOf(u8, path, "/session/new") != null) {
            return .{ .body =
                \\{"sessionId":"uia2-session-1","success":true}
            };
        }
        return defaultHandler(path, body);
    }

    /// macOS/Accessibility mock responses
    pub fn macosHandler(path: []const u8, body: []const u8) MockResponse {
        if (std.mem.indexOf(u8, path, "/launch") != null or std.mem.indexOf(u8, path, "/attach") != null) {
            return .{ .body =
                \\{"sessionId":"ax-session-1","pid":12345,"success":true}
            };
        }
        return defaultHandler(path, body);
    }

    /// Linux/AT-SPI mock responses
    pub fn linuxHandler(path: []const u8, body: []const u8) MockResponse {
        if (std.mem.indexOf(u8, path, "/launch") != null or std.mem.indexOf(u8, path, "/attach") != null) {
            return .{ .body =
                \\{"sessionId":"atspi-session-1","pid":12345,"success":true}
            };
        }
        return defaultHandler(path, body);
    }

    fn defaultHandler(path: []const u8, body: []const u8) MockResponse {
        return MockServer.defaultHandler(path, body);
    }
};

// Tests
test "mock server starts and stops" {
    var server = MockServer.init(std.testing.allocator, 19515);
    defer server.deinit();

    try server.start();
    std.Thread.sleep(100 * std.time.ns_per_ms);
    server.stop();
}

test "mock server handles requests" {
    var server = MockServer.init(std.testing.allocator, 19516);
    defer server.deinit();

    try server.start();
    defer server.stop();

    // Give server time to start
    std.Thread.sleep(100 * std.time.ns_per_ms);

    // Make a test request
    const address = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 19516);
    const stream = std.net.tcpConnectToAddress(address) catch return;
    defer stream.close();

    const request =
        \\POST /session/new/launch HTTP/1.1
        \\Host: 127.0.0.1:19516
        \\Content-Type: application/json
        \\Content-Length: 2
        \\
        \\{}
    ;
    _ = stream.write(request) catch return;

    var buffer: [1024]u8 = undefined;
    const bytes = stream.read(&buffer) catch return;

    // Check response contains session ID
    const response = buffer[0..bytes];
    try std.testing.expect(std.mem.indexOf(u8, response, "sessionId") != null);
}
