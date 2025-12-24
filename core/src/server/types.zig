//! Zylix Server - Common Types
//!
//! Core types for the Zylix HTTP server including methods, status codes,
//! headers, and common data structures.

const std = @import("std");

/// HTTP Methods
pub const Method = enum {
    GET,
    POST,
    PUT,
    DELETE,
    PATCH,
    HEAD,
    OPTIONS,
    CONNECT,
    TRACE,

    pub fn fromString(str: []const u8) ?Method {
        const methods = std.StaticStringMap(Method).initComptime(.{
            .{ "GET", .GET },
            .{ "POST", .POST },
            .{ "PUT", .PUT },
            .{ "DELETE", .DELETE },
            .{ "PATCH", .PATCH },
            .{ "HEAD", .HEAD },
            .{ "OPTIONS", .OPTIONS },
            .{ "CONNECT", .CONNECT },
            .{ "TRACE", .TRACE },
        });
        return methods.get(str);
    }

    pub fn toString(self: Method) []const u8 {
        return switch (self) {
            .GET => "GET",
            .POST => "POST",
            .PUT => "PUT",
            .DELETE => "DELETE",
            .PATCH => "PATCH",
            .HEAD => "HEAD",
            .OPTIONS => "OPTIONS",
            .CONNECT => "CONNECT",
            .TRACE => "TRACE",
        };
    }
};

/// HTTP Status Codes
pub const Status = enum(u16) {
    // 1xx Informational
    @"continue" = 100,
    switching_protocols = 101,
    processing = 102,
    early_hints = 103,

    // 2xx Success
    ok = 200,
    created = 201,
    accepted = 202,
    non_authoritative_information = 203,
    no_content = 204,
    reset_content = 205,
    partial_content = 206,
    multi_status = 207,

    // 3xx Redirection
    multiple_choices = 300,
    moved_permanently = 301,
    found = 302,
    see_other = 303,
    not_modified = 304,
    temporary_redirect = 307,
    permanent_redirect = 308,

    // 4xx Client Errors
    bad_request = 400,
    unauthorized = 401,
    payment_required = 402,
    forbidden = 403,
    not_found = 404,
    method_not_allowed = 405,
    not_acceptable = 406,
    proxy_authentication_required = 407,
    request_timeout = 408,
    conflict = 409,
    gone = 410,
    length_required = 411,
    precondition_failed = 412,
    payload_too_large = 413,
    uri_too_long = 414,
    unsupported_media_type = 415,
    range_not_satisfiable = 416,
    expectation_failed = 417,
    im_a_teapot = 418,
    misdirected_request = 421,
    unprocessable_entity = 422,
    locked = 423,
    failed_dependency = 424,
    too_early = 425,
    upgrade_required = 426,
    precondition_required = 428,
    too_many_requests = 429,
    request_header_fields_too_large = 431,
    unavailable_for_legal_reasons = 451,

    // 5xx Server Errors
    internal_server_error = 500,
    not_implemented = 501,
    bad_gateway = 502,
    service_unavailable = 503,
    gateway_timeout = 504,
    http_version_not_supported = 505,
    variant_also_negotiates = 506,
    insufficient_storage = 507,
    loop_detected = 508,
    not_extended = 510,
    network_authentication_required = 511,

    pub fn code(self: Status) u16 {
        return @intFromEnum(self);
    }

    pub fn phrase(self: Status) []const u8 {
        return switch (self) {
            .@"continue" => "Continue",
            .switching_protocols => "Switching Protocols",
            .processing => "Processing",
            .early_hints => "Early Hints",
            .ok => "OK",
            .created => "Created",
            .accepted => "Accepted",
            .non_authoritative_information => "Non-Authoritative Information",
            .no_content => "No Content",
            .reset_content => "Reset Content",
            .partial_content => "Partial Content",
            .multi_status => "Multi-Status",
            .multiple_choices => "Multiple Choices",
            .moved_permanently => "Moved Permanently",
            .found => "Found",
            .see_other => "See Other",
            .not_modified => "Not Modified",
            .temporary_redirect => "Temporary Redirect",
            .permanent_redirect => "Permanent Redirect",
            .bad_request => "Bad Request",
            .unauthorized => "Unauthorized",
            .payment_required => "Payment Required",
            .forbidden => "Forbidden",
            .not_found => "Not Found",
            .method_not_allowed => "Method Not Allowed",
            .not_acceptable => "Not Acceptable",
            .proxy_authentication_required => "Proxy Authentication Required",
            .request_timeout => "Request Timeout",
            .conflict => "Conflict",
            .gone => "Gone",
            .length_required => "Length Required",
            .precondition_failed => "Precondition Failed",
            .payload_too_large => "Payload Too Large",
            .uri_too_long => "URI Too Long",
            .unsupported_media_type => "Unsupported Media Type",
            .range_not_satisfiable => "Range Not Satisfiable",
            .expectation_failed => "Expectation Failed",
            .im_a_teapot => "I'm a teapot",
            .misdirected_request => "Misdirected Request",
            .unprocessable_entity => "Unprocessable Entity",
            .locked => "Locked",
            .failed_dependency => "Failed Dependency",
            .too_early => "Too Early",
            .upgrade_required => "Upgrade Required",
            .precondition_required => "Precondition Required",
            .too_many_requests => "Too Many Requests",
            .request_header_fields_too_large => "Request Header Fields Too Large",
            .unavailable_for_legal_reasons => "Unavailable For Legal Reasons",
            .internal_server_error => "Internal Server Error",
            .not_implemented => "Not Implemented",
            .bad_gateway => "Bad Gateway",
            .service_unavailable => "Service Unavailable",
            .gateway_timeout => "Gateway Timeout",
            .http_version_not_supported => "HTTP Version Not Supported",
            .variant_also_negotiates => "Variant Also Negotiates",
            .insufficient_storage => "Insufficient Storage",
            .loop_detected => "Loop Detected",
            .not_extended => "Not Extended",
            .network_authentication_required => "Network Authentication Required",
        };
    }

    pub fn isSuccess(self: Status) bool {
        const code_val = self.code();
        return code_val >= 200 and code_val < 300;
    }

    pub fn isRedirect(self: Status) bool {
        const code_val = self.code();
        return code_val >= 300 and code_val < 400;
    }

    pub fn isClientError(self: Status) bool {
        const code_val = self.code();
        return code_val >= 400 and code_val < 500;
    }

    pub fn isServerError(self: Status) bool {
        const code_val = self.code();
        return code_val >= 500 and code_val < 600;
    }
};

/// HTTP Headers
pub const Headers = struct {
    allocator: std.mem.Allocator,
    entries: std.StringHashMapUnmanaged([]const u8),

    pub fn init(allocator: std.mem.Allocator) Headers {
        return .{
            .allocator = allocator,
            .entries = .{},
        };
    }

    pub fn deinit(self: *Headers) void {
        var it = self.entries.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.entries.deinit(self.allocator);
    }

    pub fn set(self: *Headers, name: []const u8, value: []const u8) !void {
        const name_lower = try self.allocator.alloc(u8, name.len);
        for (name, 0..) |c, i| {
            name_lower[i] = std.ascii.toLower(c);
        }

        // Remove old value if exists
        if (self.entries.fetchRemove(name_lower)) |kv| {
            self.allocator.free(kv.key);
            self.allocator.free(kv.value);
            self.allocator.free(name_lower);
            // Re-add with new value
            const new_name = try self.allocator.dupe(u8, name);
            for (new_name, 0..) |c, i| {
                new_name[i] = std.ascii.toLower(c);
            }
            const new_value = try self.allocator.dupe(u8, value);
            try self.entries.put(self.allocator, new_name, new_value);
        } else {
            const value_copy = try self.allocator.dupe(u8, value);
            try self.entries.put(self.allocator, name_lower, value_copy);
        }
    }

    pub fn get(self: *const Headers, name: []const u8) ?[]const u8 {
        var name_lower: [256]u8 = undefined;
        if (name.len > 256) return null;
        for (name, 0..) |c, i| {
            name_lower[i] = std.ascii.toLower(c);
        }
        return self.entries.get(name_lower[0..name.len]);
    }

    pub fn remove(self: *Headers, name: []const u8) void {
        var name_lower: [256]u8 = undefined;
        if (name.len > 256) return;
        for (name, 0..) |c, i| {
            name_lower[i] = std.ascii.toLower(c);
        }
        if (self.entries.fetchRemove(name_lower[0..name.len])) |kv| {
            self.allocator.free(kv.key);
            self.allocator.free(kv.value);
        }
    }

    pub fn contains(self: *const Headers, name: []const u8) bool {
        return self.get(name) != null;
    }
};

/// Content types
pub const ContentType = struct {
    pub const text_plain = "text/plain";
    pub const text_html = "text/html";
    pub const text_css = "text/css";
    pub const text_javascript = "text/javascript";
    pub const application_json = "application/json";
    pub const application_xml = "application/xml";
    pub const application_form_urlencoded = "application/x-www-form-urlencoded";
    pub const multipart_form_data = "multipart/form-data";
    pub const application_octet_stream = "application/octet-stream";
    pub const image_png = "image/png";
    pub const image_jpeg = "image/jpeg";
    pub const image_gif = "image/gif";
    pub const image_svg = "image/svg+xml";
    pub const image_webp = "image/webp";

    pub fn fromExtension(ext: []const u8) []const u8 {
        const types = std.StaticStringMap([]const u8).initComptime(.{
            .{ ".html", text_html },
            .{ ".htm", text_html },
            .{ ".css", text_css },
            .{ ".js", text_javascript },
            .{ ".mjs", text_javascript },
            .{ ".json", application_json },
            .{ ".xml", application_xml },
            .{ ".txt", text_plain },
            .{ ".png", image_png },
            .{ ".jpg", image_jpeg },
            .{ ".jpeg", image_jpeg },
            .{ ".gif", image_gif },
            .{ ".svg", image_svg },
            .{ ".webp", image_webp },
        });
        return types.get(ext) orelse application_octet_stream;
    }
};

/// Cookie representation
pub const Cookie = struct {
    name: []const u8,
    value: []const u8,
    domain: ?[]const u8 = null,
    path: ?[]const u8 = null,
    expires: ?i64 = null,
    max_age: ?i64 = null,
    secure: bool = false,
    http_only: bool = false,
    same_site: SameSite = .lax,

    pub const SameSite = enum {
        strict,
        lax,
        none,
    };

    pub fn deinit(self: *Cookie, allocator: std.mem.Allocator) void {
        // Cookie typically doesn't own its strings (they're slices from request)
        // But if needed, this provides the interface
        _ = self;
        _ = allocator;
    }

    pub fn format(self: *const Cookie, allocator: std.mem.Allocator) ![]u8 {
        var buf: std.ArrayListUnmanaged(u8) = .{};
        errdefer buf.deinit(allocator);

        try buf.writer(allocator).print("{s}={s}", .{ self.name, self.value });

        if (self.domain) |domain| {
            try buf.writer(allocator).print("; Domain={s}", .{domain});
        }
        if (self.path) |path| {
            try buf.writer(allocator).print("; Path={s}", .{path});
        }
        if (self.max_age) |max_age| {
            try buf.writer(allocator).print("; Max-Age={d}", .{max_age});
        }
        if (self.secure) {
            try buf.appendSlice(allocator, "; Secure");
        }
        if (self.http_only) {
            try buf.appendSlice(allocator, "; HttpOnly");
        }
        switch (self.same_site) {
            .strict => try buf.appendSlice(allocator, "; SameSite=Strict"),
            .lax => try buf.appendSlice(allocator, "; SameSite=Lax"),
            .none => try buf.appendSlice(allocator, "; SameSite=None"),
        }

        return buf.toOwnedSlice(allocator);
    }
};

/// URL components
pub const Url = struct {
    raw: []const u8,
    path: []const u8,
    query: ?[]const u8,
    fragment: ?[]const u8,

    pub fn parse(raw: []const u8) Url {
        var path = raw;
        var query: ?[]const u8 = null;
        var fragment: ?[]const u8 = null;

        // Extract fragment
        if (std.mem.indexOf(u8, path, "#")) |frag_pos| {
            fragment = path[frag_pos + 1 ..];
            path = path[0..frag_pos];
        }

        // Extract query
        if (std.mem.indexOf(u8, path, "?")) |query_pos| {
            query = path[query_pos + 1 ..];
            path = path[0..query_pos];
        }

        return .{
            .raw = raw,
            .path = path,
            .query = query,
            .fragment = fragment,
        };
    }
};

/// Query string parser
pub const QueryParams = struct {
    allocator: std.mem.Allocator,
    params: std.StringHashMapUnmanaged([]const u8),

    pub fn init(allocator: std.mem.Allocator) QueryParams {
        return .{
            .allocator = allocator,
            .params = .{},
        };
    }

    pub fn deinit(self: *QueryParams) void {
        var it = self.params.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.params.deinit(self.allocator);
    }

    pub fn parse(allocator: std.mem.Allocator, query: []const u8) !QueryParams {
        var params = QueryParams.init(allocator);
        errdefer params.deinit();

        var iter = std.mem.splitScalar(u8, query, '&');
        while (iter.next()) |pair| {
            if (pair.len == 0) continue;

            if (std.mem.indexOf(u8, pair, "=")) |eq_pos| {
                const key = try allocator.dupe(u8, pair[0..eq_pos]);
                const value = try allocator.dupe(u8, pair[eq_pos + 1 ..]);
                try params.params.put(allocator, key, value);
            } else {
                const key = try allocator.dupe(u8, pair);
                const value = try allocator.dupe(u8, "");
                try params.params.put(allocator, key, value);
            }
        }

        return params;
    }

    pub fn get(self: *const QueryParams, key: []const u8) ?[]const u8 {
        return self.params.get(key);
    }
};

/// Server configuration
pub const ServerConfig = struct {
    host: []const u8 = "127.0.0.1",
    port: u16 = 3000,
    max_connections: u32 = 1024,
    read_timeout_ms: u32 = 30000,
    write_timeout_ms: u32 = 30000,
    max_request_size: usize = 10 * 1024 * 1024, // 10MB
    keep_alive: bool = true,
    tcp_nodelay: bool = true,
};

/// Server error types
pub const ServerError = error{
    BindFailed,
    AcceptFailed,
    ReadFailed,
    WriteFailed,
    ConnectionClosed,
    RequestTooLarge,
    InvalidRequest,
    ParseError,
    Timeout,
    OutOfMemory,
    HandlerError,
    MiddlewareError,
    RouteNotFound,
    MethodNotAllowed,
    InternalError,
};

/// Combined error type
pub const Error = ServerError || std.mem.Allocator.Error;

// ============================================================================
// Unit Tests
// ============================================================================

test "Method fromString and toString" {
    try std.testing.expectEqual(Method.GET, Method.fromString("GET").?);
    try std.testing.expectEqual(Method.POST, Method.fromString("POST").?);
    try std.testing.expect(Method.fromString("INVALID") == null);
    try std.testing.expectEqualStrings("GET", Method.GET.toString());
}

test "Status code and phrase" {
    try std.testing.expectEqual(@as(u16, 200), Status.ok.code());
    try std.testing.expectEqualStrings("OK", Status.ok.phrase());
    try std.testing.expect(Status.ok.isSuccess());
    try std.testing.expect(!Status.ok.isClientError());
    try std.testing.expect(Status.not_found.isClientError());
    try std.testing.expect(Status.internal_server_error.isServerError());
}

test "Headers set and get" {
    const allocator = std.testing.allocator;
    var headers = Headers.init(allocator);
    defer headers.deinit();

    try headers.set("Content-Type", "application/json");
    try std.testing.expectEqualStrings("application/json", headers.get("content-type").?);
    try std.testing.expectEqualStrings("application/json", headers.get("Content-Type").?);
}

test "Url parse" {
    const url = Url.parse("/api/users?page=1&limit=10#section");
    try std.testing.expectEqualStrings("/api/users", url.path);
    try std.testing.expectEqualStrings("page=1&limit=10", url.query.?);
    try std.testing.expectEqualStrings("section", url.fragment.?);
}

test "QueryParams parse" {
    const allocator = std.testing.allocator;
    var params = try QueryParams.parse(allocator, "name=john&age=30");
    defer params.deinit();

    try std.testing.expectEqualStrings("john", params.get("name").?);
    try std.testing.expectEqualStrings("30", params.get("age").?);
}

test "ContentType fromExtension" {
    try std.testing.expectEqualStrings("text/html", ContentType.fromExtension(".html"));
    try std.testing.expectEqualStrings("application/json", ContentType.fromExtension(".json"));
    try std.testing.expectEqualStrings("application/octet-stream", ContentType.fromExtension(".unknown"));
}
