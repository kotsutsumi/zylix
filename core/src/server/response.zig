//! Zylix Server - Response Handling
//!
//! HTTP response building and serialization.

const std = @import("std");
const types = @import("types.zig");

const Status = types.Status;
const Headers = types.Headers;
const ContentType = types.ContentType;
const Cookie = types.Cookie;
const ServerError = types.ServerError;
const Error = types.Error;

/// HTTP Response representation
pub const Response = struct {
    allocator: std.mem.Allocator,

    /// HTTP status code
    status: Status,

    /// Response headers
    headers: Headers,

    /// Cookies to set
    cookies: std.ArrayListUnmanaged(Cookie),

    /// Response body
    body: ?[]const u8,

    /// Body owned by response (should free on deinit)
    body_owned: bool,

    /// Initialize a new response
    pub fn init(allocator: std.mem.Allocator) Response {
        return .{
            .allocator = allocator,
            .status = .ok,
            .headers = Headers.init(allocator),
            .cookies = .{},
            .body = null,
            .body_owned = false,
        };
    }

    /// Clean up response resources
    pub fn deinit(self: *Response) void {
        self.headers.deinit();

        for (self.cookies.items) |*cookie| {
            cookie.deinit(self.allocator);
        }
        self.cookies.deinit(self.allocator);

        if (self.body_owned) {
            if (self.body) |b| {
                self.allocator.free(b);
            }
        }
    }

    /// Set response status
    pub fn setStatus(self: *Response, status: Status) *Response {
        self.status = status;
        return self;
    }

    /// Set a header
    pub fn setHeader(self: *Response, name: []const u8, value: []const u8) !*Response {
        try self.headers.set(name, value);
        return self;
    }

    /// Set content type
    pub fn setContentType(self: *Response, content_type: []const u8) !*Response {
        try self.headers.set("content-type", content_type);
        return self;
    }

    /// Add a cookie
    pub fn setCookie(self: *Response, cookie: Cookie) !*Response {
        try self.cookies.append(self.allocator, cookie);
        return self;
    }

    /// Set body (does not take ownership)
    pub fn setBody(self: *Response, body: []const u8) *Response {
        if (self.body_owned) {
            if (self.body) |b| {
                self.allocator.free(b);
            }
        }
        self.body = body;
        self.body_owned = false;
        return self;
    }

    /// Set body (takes ownership)
    pub fn setBodyOwned(self: *Response, body: []const u8) *Response {
        if (self.body_owned) {
            if (self.body) |b| {
                self.allocator.free(b);
            }
        }
        self.body = body;
        self.body_owned = true;
        return self;
    }

    /// Send plain text response
    pub fn text(self: *Response, content: []const u8) !*Response {
        _ = try self.setContentType(ContentType.text_plain);
        _ = self.setBody(content);
        return self;
    }

    /// Send HTML response
    pub fn html(self: *Response, content: []const u8) !*Response {
        _ = try self.setContentType(ContentType.text_html);
        _ = self.setBody(content);
        return self;
    }

    /// Send JSON response from raw string
    pub fn json(self: *Response, content: []const u8) !*Response {
        _ = try self.setContentType(ContentType.application_json);
        _ = self.setBody(content);
        return self;
    }

    /// Send JSON response from value (serializes)
    pub fn jsonValue(self: *Response, value: anytype) !*Response {
        const json_string = std.json.Stringify.valueAlloc(self.allocator, value, .{}) catch return error.OutOfMemory;
        _ = try self.setContentType(ContentType.application_json);
        _ = self.setBodyOwned(json_string);
        return self;
    }

    /// Send redirect response
    pub fn redirect(self: *Response, location: []const u8, permanent: bool) !*Response {
        self.status = if (permanent) .moved_permanently else .found;
        _ = try self.setHeader("location", location);
        return self;
    }

    /// Send 404 Not Found
    pub fn notFound(self: *Response) !*Response {
        self.status = .not_found;
        _ = try self.text("Not Found");
        return self;
    }

    /// Send 400 Bad Request
    pub fn badRequest(self: *Response, message: ?[]const u8) !*Response {
        self.status = .bad_request;
        _ = try self.text(message orelse "Bad Request");
        return self;
    }

    /// Send 401 Unauthorized
    pub fn unauthorized(self: *Response) !*Response {
        self.status = .unauthorized;
        _ = try self.text("Unauthorized");
        return self;
    }

    /// Send 403 Forbidden
    pub fn forbidden(self: *Response) !*Response {
        self.status = .forbidden;
        _ = try self.text("Forbidden");
        return self;
    }

    /// Send 500 Internal Server Error
    pub fn internalError(self: *Response, message: ?[]const u8) !*Response {
        self.status = .internal_server_error;
        _ = try self.text(message orelse "Internal Server Error");
        return self;
    }

    /// Serialize response to HTTP format
    pub fn serialize(self: *Response) ![]u8 {
        var buffer: std.ArrayListUnmanaged(u8) = .{};
        errdefer buffer.deinit(self.allocator);

        const writer = buffer.writer(self.allocator);

        // Status line
        try writer.print("HTTP/1.1 {d} {s}\r\n", .{
            @intFromEnum(self.status),
            self.status.phrase(),
        });

        // Add content-length if body exists
        if (self.body) |b| {
            if (self.headers.get("content-length") == null) {
                try writer.print("content-length: {d}\r\n", .{b.len});
            }
        }

        // Headers
        var header_it = self.headers.entries.iterator();
        while (header_it.next()) |entry| {
            try writer.print("{s}: {s}\r\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        }

        // Cookies
        for (self.cookies.items) |cookie| {
            const cookie_str = try cookie.format(self.allocator);
            defer self.allocator.free(cookie_str);
            try writer.print("set-cookie: {s}\r\n", .{cookie_str});
        }

        // End of headers
        try buffer.appendSlice(self.allocator, "\r\n");

        // Body
        if (self.body) |b| {
            try buffer.appendSlice(self.allocator, b);
        }

        return buffer.toOwnedSlice(self.allocator);
    }
};

/// Response builder with fluent API
pub const ResponseBuilder = struct {
    allocator: std.mem.Allocator,
    status_code: Status = .ok,
    headers: std.ArrayListUnmanaged(Header) = .{},
    cookies: std.ArrayListUnmanaged(Cookie) = .{},
    body_content: ?[]const u8 = null,
    body_owned: bool = false,

    const Header = struct {
        name: []const u8,
        value: []const u8,
    };

    pub fn init(allocator: std.mem.Allocator) ResponseBuilder {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *ResponseBuilder) void {
        self.headers.deinit(self.allocator);
        for (self.cookies.items) |*c| {
            c.deinit(self.allocator);
        }
        self.cookies.deinit(self.allocator);
        if (self.body_owned) {
            if (self.body_content) |b| {
                self.allocator.free(b);
            }
        }
    }

    pub fn status(self: *ResponseBuilder, s: Status) *ResponseBuilder {
        self.status_code = s;
        return self;
    }

    pub fn header(self: *ResponseBuilder, name: []const u8, value: []const u8) !*ResponseBuilder {
        try self.headers.append(self.allocator, .{ .name = name, .value = value });
        return self;
    }

    pub fn contentType(self: *ResponseBuilder, ct: []const u8) !*ResponseBuilder {
        return self.header("content-type", ct);
    }

    pub fn cookie(self: *ResponseBuilder, c: Cookie) !*ResponseBuilder {
        try self.cookies.append(self.allocator, c);
        return self;
    }

    pub fn body(self: *ResponseBuilder, b: []const u8) *ResponseBuilder {
        self.body_content = b;
        self.body_owned = false;
        return self;
    }

    pub fn bodyOwned(self: *ResponseBuilder, b: []const u8) *ResponseBuilder {
        self.body_content = b;
        self.body_owned = true;
        return self;
    }

    pub fn build(self: *ResponseBuilder) !Response {
        var res = Response.init(self.allocator);
        errdefer res.deinit();

        res.status = self.status_code;

        for (self.headers.items) |h| {
            try res.headers.set(h.name, h.value);
        }

        for (self.cookies.items) |c| {
            try res.cookies.append(self.allocator, c);
        }
        // Clear cookies from builder without deinit since ownership transferred
        self.cookies.items.len = 0;

        if (self.body_content) |b| {
            if (self.body_owned) {
                res.body = b;
                res.body_owned = true;
                self.body_content = null;
                self.body_owned = false;
            } else {
                res.body = b;
                res.body_owned = false;
            }
        }

        return res;
    }
};

// ============================================================================
// Unit Tests
// ============================================================================

test "Response init and deinit" {
    const allocator = std.testing.allocator;
    var response = Response.init(allocator);
    defer response.deinit();

    try std.testing.expectEqual(Status.ok, response.status);
    try std.testing.expect(response.body == null);
}

test "Response text" {
    const allocator = std.testing.allocator;
    var response = Response.init(allocator);
    defer response.deinit();

    _ = try response.text("Hello, World!");

    try std.testing.expectEqualStrings("text/plain", response.headers.get("content-type").?);
    try std.testing.expectEqualStrings("Hello, World!", response.body.?);
}

test "Response json" {
    const allocator = std.testing.allocator;
    var response = Response.init(allocator);
    defer response.deinit();

    _ = try response.json("{\"status\":\"ok\"}");

    try std.testing.expectEqualStrings("application/json", response.headers.get("content-type").?);
    try std.testing.expectEqualStrings("{\"status\":\"ok\"}", response.body.?);
}

test "Response redirect" {
    const allocator = std.testing.allocator;
    var response = Response.init(allocator);
    defer response.deinit();

    _ = try response.redirect("/new-location", false);

    try std.testing.expectEqual(Status.found, response.status);
    try std.testing.expectEqualStrings("/new-location", response.headers.get("location").?);
}

test "Response serialize" {
    const allocator = std.testing.allocator;
    var response = Response.init(allocator);
    defer response.deinit();

    _ = try response.text("Hello");
    const serialized = try response.serialize();
    defer allocator.free(serialized);

    try std.testing.expect(std.mem.indexOf(u8, serialized, "HTTP/1.1 200 OK") != null);
    try std.testing.expect(std.mem.indexOf(u8, serialized, "content-type: text/plain") != null);
    try std.testing.expect(std.mem.indexOf(u8, serialized, "Hello") != null);
}

test "ResponseBuilder" {
    const allocator = std.testing.allocator;
    var builder = ResponseBuilder.init(allocator);
    defer builder.deinit();

    _ = builder.status(.created);
    _ = try builder.contentType("application/json");
    _ = builder.body("{\"id\":1}");

    var res = try builder.build();
    defer res.deinit();

    try std.testing.expectEqual(Status.created, res.status);
    try std.testing.expectEqualStrings("application/json", res.headers.get("content-type").?);
    try std.testing.expectEqualStrings("{\"id\":1}", res.body.?);
}

test "Response error helpers" {
    const allocator = std.testing.allocator;

    {
        var res = Response.init(allocator);
        defer res.deinit();
        _ = try res.notFound();
        try std.testing.expectEqual(Status.not_found, res.status);
    }

    {
        var res = Response.init(allocator);
        defer res.deinit();
        _ = try res.badRequest("Invalid input");
        try std.testing.expectEqual(Status.bad_request, res.status);
        try std.testing.expectEqualStrings("Invalid input", res.body.?);
    }

    {
        var res = Response.init(allocator);
        defer res.deinit();
        _ = try res.unauthorized();
        try std.testing.expectEqual(Status.unauthorized, res.status);
    }
}
