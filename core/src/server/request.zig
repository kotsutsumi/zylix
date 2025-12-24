//! Zylix Server - Request Handling
//!
//! HTTP request parsing and representation.

const std = @import("std");
const types = @import("types.zig");

const Method = types.Method;
const Headers = types.Headers;
const Url = types.Url;
const QueryParams = types.QueryParams;
const ServerError = types.ServerError;
const Error = types.Error;

/// HTTP Request representation
pub const Request = struct {
    allocator: std.mem.Allocator,

    /// HTTP method
    method: Method,

    /// Request URL
    url: Url,

    /// HTTP version (e.g., "HTTP/1.1")
    version: []const u8,

    /// Request headers
    headers: Headers,

    /// Query parameters (parsed lazily)
    query_params: ?QueryParams,

    /// Route parameters (set by router)
    route_params: std.StringHashMapUnmanaged([]const u8),

    /// Request body (raw bytes)
    body: ?[]const u8,

    /// Parsed JSON body (cached)
    json_cache: ?std.json.Value,

    /// Remote address
    remote_addr: ?[]const u8,

    /// Request context for middleware data
    context: std.StringHashMapUnmanaged(*anyopaque),

    /// Initialize a new request
    pub fn init(allocator: std.mem.Allocator) Request {
        return .{
            .allocator = allocator,
            .method = .GET,
            .url = Url.parse("/"),
            .version = "HTTP/1.1",
            .headers = Headers.init(allocator),
            .query_params = null,
            .route_params = .{},
            .body = null,
            .json_cache = null,
            .remote_addr = null,
            .context = .{},
        };
    }

    /// Clean up request resources
    pub fn deinit(self: *Request) void {
        self.headers.deinit();

        if (self.query_params) |*qp| {
            qp.deinit();
        }

        var route_it = self.route_params.iterator();
        while (route_it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.route_params.deinit(self.allocator);

        if (self.body) |b| {
            self.allocator.free(b);
        }

        // Free context keys (values are not owned by context)
        var ctx_it = self.context.iterator();
        while (ctx_it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.context.deinit(self.allocator);
    }

    /// Parse HTTP request from raw bytes
    pub fn parse(allocator: std.mem.Allocator, data: []const u8) Error!Request {
        var request = Request.init(allocator);
        errdefer request.deinit();

        // Find end of headers
        const header_end = std.mem.indexOf(u8, data, "\r\n\r\n") orelse
            return ServerError.ParseError;

        const header_data = data[0..header_end];
        const body_start = header_end + 4;

        // Parse request line
        var lines = std.mem.splitSequence(u8, header_data, "\r\n");
        const request_line = lines.first();

        var parts = std.mem.splitScalar(u8, request_line, ' ');
        const method_str = parts.next() orelse return ServerError.ParseError;
        const path_str = parts.next() orelse return ServerError.ParseError;
        const version_str = parts.next() orelse return ServerError.ParseError;

        request.method = Method.fromString(method_str) orelse return ServerError.ParseError;
        request.url = Url.parse(path_str);
        request.version = version_str;

        // Parse headers
        while (lines.next()) |line| {
            if (line.len == 0) break;
            if (std.mem.indexOf(u8, line, ": ")) |colon_pos| {
                const name = line[0..colon_pos];
                const value = line[colon_pos + 2 ..];
                try request.headers.set(name, value);
            }
        }

        // Parse body if present
        if (body_start < data.len) {
            request.body = try allocator.dupe(u8, data[body_start..]);
        }

        return request;
    }

    /// Get a header value
    pub fn header(self: *const Request, name: []const u8) ?[]const u8 {
        return self.headers.get(name);
    }

    /// Get content type
    pub fn contentType(self: *const Request) ?[]const u8 {
        return self.header("content-type");
    }

    /// Get content length
    pub fn contentLength(self: *const Request) ?usize {
        if (self.header("content-length")) |len_str| {
            return std.fmt.parseInt(usize, len_str, 10) catch null;
        }
        return null;
    }

    /// Check if request accepts JSON
    pub fn acceptsJson(self: *const Request) bool {
        if (self.header("accept")) |accept| {
            return std.mem.indexOf(u8, accept, "application/json") != null or
                std.mem.indexOf(u8, accept, "*/*") != null;
        }
        return false;
    }

    /// Get query parameter
    pub fn query(self: *Request, key: []const u8) ?[]const u8 {
        // Lazy parse query params
        if (self.query_params == null) {
            if (self.url.query) |q| {
                self.query_params = QueryParams.parse(self.allocator, q) catch null;
            }
        }

        if (self.query_params) |*qp| {
            return qp.get(key);
        }
        return null;
    }

    /// Get route parameter (set by router)
    pub fn param(self: *const Request, key: []const u8) ?[]const u8 {
        return self.route_params.get(key);
    }

    /// Set route parameter
    pub fn setParam(self: *Request, key: []const u8, value: []const u8) !void {
        // Remove old entry if exists to prevent memory leak
        if (self.route_params.fetchRemove(key)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }
        const key_copy = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(key_copy);
        const value_copy = try self.allocator.dupe(u8, value);
        try self.route_params.put(self.allocator, key_copy, value_copy);
    }

    /// Parse body as JSON
    pub fn json(self: *Request, comptime T: type) !T {
        if (self.body) |body_data| {
            return std.json.parseFromSlice(T, self.allocator, body_data, .{});
        }
        return ServerError.ParseError;
    }

    /// Get raw body as string
    pub fn text(self: *const Request) ?[]const u8 {
        return self.body;
    }

    /// Check if request is AJAX/XHR
    pub fn isXhr(self: *const Request) bool {
        if (self.header("x-requested-with")) |xhr| {
            return std.ascii.eqlIgnoreCase(xhr, "xmlhttprequest");
        }
        return false;
    }

    /// Check if request is secure (HTTPS)
    pub fn isSecure(self: *const Request) bool {
        // Check X-Forwarded-Proto header (for reverse proxies)
        if (self.header("x-forwarded-proto")) |proto| {
            return std.ascii.eqlIgnoreCase(proto, "https");
        }
        return false;
    }

    /// Get host from request
    pub fn host(self: *const Request) ?[]const u8 {
        return self.header("host");
    }

    /// Get user agent
    pub fn userAgent(self: *const Request) ?[]const u8 {
        return self.header("user-agent");
    }

    /// Store context value (for middleware)
    pub fn set(self: *Request, key: []const u8, value: *anyopaque) !void {
        // Remove old entry if exists to prevent memory leak
        if (self.context.fetchRemove(key)) |old| {
            self.allocator.free(old.key);
            // Note: values are not owned by context, so don't free
        }
        const key_copy = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(key_copy);
        try self.context.put(self.allocator, key_copy, value);
    }

    /// Get context value
    pub fn get(self: *const Request, key: []const u8) ?*anyopaque {
        return self.context.get(key);
    }

    /// Get typed context value
    pub fn getTyped(self: *const Request, comptime T: type, key: []const u8) ?*T {
        if (self.context.get(key)) |ptr| {
            return @ptrCast(@alignCast(ptr));
        }
        return null;
    }
};

/// Request builder for testing
pub const RequestBuilder = struct {
    allocator: std.mem.Allocator,
    method: Method = .GET,
    path: []const u8 = "/",
    headers: std.ArrayListUnmanaged(Header) = .{},
    body: ?[]const u8 = null,

    const Header = struct {
        name: []const u8,
        value: []const u8,
    };

    pub fn init(allocator: std.mem.Allocator) RequestBuilder {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *RequestBuilder) void {
        self.headers.deinit(self.allocator);
    }

    pub fn setMethod(self: *RequestBuilder, method: Method) *RequestBuilder {
        self.method = method;
        return self;
    }

    pub fn setPath(self: *RequestBuilder, path: []const u8) *RequestBuilder {
        self.path = path;
        return self;
    }

    pub fn addHeader(self: *RequestBuilder, name: []const u8, value: []const u8) !*RequestBuilder {
        try self.headers.append(self.allocator, .{ .name = name, .value = value });
        return self;
    }

    pub fn setBody(self: *RequestBuilder, body: []const u8) *RequestBuilder {
        self.body = body;
        return self;
    }

    pub fn setJson(self: *RequestBuilder, body: []const u8) !*RequestBuilder {
        _ = try self.addHeader("Content-Type", "application/json");
        self.body = body;
        return self;
    }

    pub fn build(self: *RequestBuilder) !Request {
        var request = Request.init(self.allocator);
        errdefer request.deinit();

        request.method = self.method;
        request.url = Url.parse(self.path);

        for (self.headers.items) |h| {
            try request.headers.set(h.name, h.value);
        }

        if (self.body) |b| {
            request.body = try self.allocator.dupe(u8, b);
        }

        return request;
    }
};

// ============================================================================
// Unit Tests
// ============================================================================

test "Request init and deinit" {
    const allocator = std.testing.allocator;
    var request = Request.init(allocator);
    defer request.deinit();

    try std.testing.expectEqual(Method.GET, request.method);
    try std.testing.expectEqualStrings("/", request.url.path);
}

test "Request parse" {
    const allocator = std.testing.allocator;
    const raw_request =
        "GET /api/users?page=1 HTTP/1.1\r\n" ++
        "Host: example.com\r\n" ++
        "Content-Type: application/json\r\n" ++
        "\r\n";

    var request = try Request.parse(allocator, raw_request);
    defer request.deinit();

    try std.testing.expectEqual(Method.GET, request.method);
    try std.testing.expectEqualStrings("/api/users", request.url.path);
    try std.testing.expectEqualStrings("page=1", request.url.query.?);
    try std.testing.expectEqualStrings("example.com", request.header("host").?);
}

test "Request query params" {
    const allocator = std.testing.allocator;
    var request = Request.init(allocator);
    defer request.deinit();

    request.url = Url.parse("/search?q=hello&page=2");

    try std.testing.expectEqualStrings("hello", request.query("q").?);
    try std.testing.expectEqualStrings("2", request.query("page").?);
}

test "Request route params" {
    const allocator = std.testing.allocator;
    var request = Request.init(allocator);
    defer request.deinit();

    try request.setParam("id", "123");
    try request.setParam("name", "test");

    try std.testing.expectEqualStrings("123", request.param("id").?);
    try std.testing.expectEqualStrings("test", request.param("name").?);
}

test "RequestBuilder" {
    const allocator = std.testing.allocator;
    var builder = RequestBuilder.init(allocator);
    defer builder.deinit();

    _ = builder.setMethod(.POST).setPath("/api/users");
    _ = try builder.addHeader("Authorization", "Bearer token123");
    _ = try builder.setJson("{\"name\":\"John\"}");

    var request = try builder.build();
    defer request.deinit();

    try std.testing.expectEqual(Method.POST, request.method);
    try std.testing.expectEqualStrings("/api/users", request.url.path);
    try std.testing.expectEqualStrings("application/json", request.header("content-type").?);
}
