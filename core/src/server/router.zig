//! Zylix Server - Router
//!
//! URL routing with path parameters, inspired by Hono.js.

const std = @import("std");
const types = @import("types.zig");
const request_mod = @import("request.zig");
const response_mod = @import("response.zig");

const Method = types.Method;
const Request = request_mod.Request;
const Response = response_mod.Response;
const ServerError = types.ServerError;
const Error = types.Error;

/// Handler context passed to route handlers
pub const Context = struct {
    allocator: std.mem.Allocator,
    request: *Request,
    response: *Response,

    /// Get route parameter
    pub fn param(self: *const Context, key: []const u8) ?[]const u8 {
        return self.request.param(key);
    }

    /// Get query parameter
    pub fn query(self: *Context, key: []const u8) ?[]const u8 {
        return self.request.query(key);
    }

    /// Get header value
    pub fn header(self: *const Context, name: []const u8) ?[]const u8 {
        return self.request.header(name);
    }

    /// Get request body as text
    pub fn body(self: *const Context) ?[]const u8 {
        return self.request.text();
    }

    /// Parse request body as JSON
    pub fn json(self: *Context, comptime T: type) !T {
        return self.request.json(T);
    }

    /// Set context value
    pub fn set(self: *Context, key: []const u8, value: *anyopaque) !void {
        try self.request.set(key, value);
    }

    /// Get context value
    pub fn get(self: *const Context, key: []const u8) ?*anyopaque {
        return self.request.get(key);
    }

    /// Get typed context value
    pub fn getTyped(self: *const Context, comptime T: type, key: []const u8) ?*T {
        return self.request.getTyped(T, key);
    }

    // Response helpers

    /// Send text response
    pub fn text(self: *Context, content: []const u8) !void {
        _ = try self.response.text(content);
    }

    /// Send HTML response
    pub fn html(self: *Context, content: []const u8) !void {
        _ = try self.response.html(content);
    }

    /// Send JSON response
    pub fn jsonResponse(self: *Context, content: []const u8) !void {
        _ = try self.response.json(content);
    }

    /// Send JSON value response
    pub fn jsonValue(self: *Context, value: anytype) !void {
        _ = try self.response.jsonValue(value);
    }

    /// Redirect to URL
    pub fn redirect(self: *Context, location: []const u8) !void {
        _ = try self.response.redirect(location, false);
    }

    /// Set response status
    pub fn status(self: *Context, s: types.Status) *Context {
        _ = self.response.setStatus(s);
        return self;
    }

    /// Set response header
    pub fn setHeader(self: *Context, name: []const u8, value: []const u8) !void {
        _ = try self.response.setHeader(name, value);
    }
};

/// Handler function type
pub const Handler = *const fn (*Context) anyerror!void;

/// Route definition
const Route = struct {
    method: ?Method,
    pattern: []const u8,
    segments: []const PathSegment,
    handler: Handler,
    allocator: std.mem.Allocator,

    const PathSegment = union(enum) {
        literal: []const u8,
        param: []const u8,
        wildcard: void,
    };

    fn init(allocator: std.mem.Allocator, method: ?Method, pattern: []const u8, handler: Handler) !Route {
        var segments_list: std.ArrayListUnmanaged(PathSegment) = .{};

        // Parse pattern into segments
        var parts = std.mem.splitScalar(u8, pattern, '/');
        while (parts.next()) |part| {
            if (part.len == 0) continue;

            if (part[0] == ':') {
                // Parameter segment :name
                const param_name = try allocator.dupe(u8, part[1..]);
                try segments_list.append(allocator, .{ .param = param_name });
            } else if (std.mem.eql(u8, part, "*")) {
                // Wildcard segment
                try segments_list.append(allocator, .{ .wildcard = {} });
            } else {
                // Literal segment
                const literal = try allocator.dupe(u8, part);
                try segments_list.append(allocator, .{ .literal = literal });
            }
        }

        return .{
            .method = method,
            .pattern = try allocator.dupe(u8, pattern),
            .segments = try segments_list.toOwnedSlice(allocator),
            .handler = handler,
            .allocator = allocator,
        };
    }

    fn deinit(self: *Route) void {
        for (self.segments) |segment| {
            switch (segment) {
                .literal => |s| self.allocator.free(s),
                .param => |s| self.allocator.free(s),
                .wildcard => {},
            }
        }
        self.allocator.free(self.segments);
        self.allocator.free(self.pattern);
    }

    fn match(self: *const Route, method: Method, path: []const u8, request: *Request) bool {
        // Check method (null matches all)
        if (self.method) |m| {
            if (m != method) return false;
        }

        // Parse path segments
        var path_parts = std.mem.splitScalar(u8, path, '/');
        var segment_idx: usize = 0;

        while (path_parts.next()) |part| {
            if (part.len == 0) continue;

            if (segment_idx >= self.segments.len) {
                return false;
            }

            const segment = self.segments[segment_idx];
            switch (segment) {
                .literal => |lit| {
                    if (!std.mem.eql(u8, part, lit)) {
                        return false;
                    }
                },
                .param => |param_name| {
                    // Store parameter value
                    request.setParam(param_name, part) catch return false;
                },
                .wildcard => {
                    // Wildcard matches everything remaining
                    return true;
                },
            }
            segment_idx += 1;
        }

        // All segments must be matched
        return segment_idx == self.segments.len;
    }
};

/// Router for handling HTTP routes
pub const Router = struct {
    allocator: std.mem.Allocator,
    routes: std.ArrayListUnmanaged(Route),
    not_found_handler: ?Handler,

    pub fn init(allocator: std.mem.Allocator) Router {
        return .{
            .allocator = allocator,
            .routes = .{},
            .not_found_handler = null,
        };
    }

    pub fn deinit(self: *Router) void {
        for (self.routes.items) |*r| {
            r.deinit();
        }
        self.routes.deinit(self.allocator);
    }

    /// Add a route
    pub fn route(self: *Router, method: ?Method, pattern: []const u8, handler: Handler) !*Router {
        const r = try Route.init(self.allocator, method, pattern, handler);
        try self.routes.append(self.allocator, r);
        return self;
    }

    /// GET route
    pub fn get(self: *Router, pattern: []const u8, handler: Handler) !*Router {
        return self.route(.GET, pattern, handler);
    }

    /// POST route
    pub fn post(self: *Router, pattern: []const u8, handler: Handler) !*Router {
        return self.route(.POST, pattern, handler);
    }

    /// PUT route
    pub fn put(self: *Router, pattern: []const u8, handler: Handler) !*Router {
        return self.route(.PUT, pattern, handler);
    }

    /// DELETE route
    pub fn delete(self: *Router, pattern: []const u8, handler: Handler) !*Router {
        return self.route(.DELETE, pattern, handler);
    }

    /// PATCH route
    pub fn patch(self: *Router, pattern: []const u8, handler: Handler) !*Router {
        return self.route(.PATCH, pattern, handler);
    }

    /// OPTIONS route
    pub fn options(self: *Router, pattern: []const u8, handler: Handler) !*Router {
        return self.route(.OPTIONS, pattern, handler);
    }

    /// HEAD route
    pub fn head(self: *Router, pattern: []const u8, handler: Handler) !*Router {
        return self.route(.HEAD, pattern, handler);
    }

    /// Match all methods
    pub fn all(self: *Router, pattern: []const u8, handler: Handler) !*Router {
        return self.route(null, pattern, handler);
    }

    /// Set custom 404 handler
    pub fn notFound(self: *Router, handler: Handler) *Router {
        self.not_found_handler = handler;
        return self;
    }

    /// Handle a request
    pub fn handle(self: *Router, ctx: *Context) !void {
        const path = ctx.request.url.path;
        const method = ctx.request.method;

        // Find matching route
        for (self.routes.items) |*r| {
            if (r.match(method, path, ctx.request)) {
                try r.handler(ctx);
                return;
            }
        }

        // No route found
        if (self.not_found_handler) |handler| {
            try handler(ctx);
        } else {
            _ = try ctx.response.notFound();
        }
    }
};

/// Route group for organizing routes with shared prefix
pub const RouteGroup = struct {
    router: *Router,
    prefix: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, router: *Router, prefix: []const u8) RouteGroup {
        return .{
            .router = router,
            .prefix = prefix,
            .allocator = allocator,
        };
    }

    fn buildPath(self: *const RouteGroup, pattern: []const u8) ![]u8 {
        return std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.prefix, pattern });
    }

    pub fn get(self: *RouteGroup, pattern: []const u8, handler: Handler) !*RouteGroup {
        const path = try self.buildPath(pattern);
        defer self.allocator.free(path);
        _ = try self.router.get(path, handler);
        return self;
    }

    pub fn post(self: *RouteGroup, pattern: []const u8, handler: Handler) !*RouteGroup {
        const path = try self.buildPath(pattern);
        defer self.allocator.free(path);
        _ = try self.router.post(path, handler);
        return self;
    }

    pub fn put(self: *RouteGroup, pattern: []const u8, handler: Handler) !*RouteGroup {
        const path = try self.buildPath(pattern);
        defer self.allocator.free(path);
        _ = try self.router.put(path, handler);
        return self;
    }

    pub fn delete(self: *RouteGroup, pattern: []const u8, handler: Handler) !*RouteGroup {
        const path = try self.buildPath(pattern);
        defer self.allocator.free(path);
        _ = try self.router.delete(path, handler);
        return self;
    }

    pub fn patch(self: *RouteGroup, pattern: []const u8, handler: Handler) !*RouteGroup {
        const path = try self.buildPath(pattern);
        defer self.allocator.free(path);
        _ = try self.router.patch(path, handler);
        return self;
    }
};

// ============================================================================
// Unit Tests
// ============================================================================

fn testHandler(_: *Context) anyerror!void {}

fn testHelloHandler(ctx: *Context) anyerror!void {
    try ctx.text("Hello!");
}

fn testParamHandler(ctx: *Context) anyerror!void {
    if (ctx.param("id")) |id| {
        const msg = try std.fmt.allocPrint(ctx.allocator, "ID: {s}", .{id});
        defer ctx.allocator.free(msg);
        _ = try ctx.response.text(msg);
        // Don't use setBodyOwned since we're freeing msg
        ctx.response.body = try ctx.allocator.dupe(u8, msg);
        ctx.response.body_owned = true;
    }
}

test "Router init and deinit" {
    const allocator = std.testing.allocator;
    var router = Router.init(allocator);
    defer router.deinit();

    _ = try router.get("/", testHandler);
    _ = try router.post("/api/users", testHandler);

    try std.testing.expectEqual(@as(usize, 2), router.routes.items.len);
}

test "Router route matching" {
    const allocator = std.testing.allocator;
    var router = Router.init(allocator);
    defer router.deinit();

    _ = try router.get("/hello", testHelloHandler);

    var request = Request.init(allocator);
    defer request.deinit();
    request.method = .GET;
    request.url = types.Url.parse("/hello");

    var response = Response.init(allocator);
    defer response.deinit();

    var ctx = Context{
        .allocator = allocator,
        .request = &request,
        .response = &response,
    };

    try router.handle(&ctx);

    try std.testing.expectEqualStrings("Hello!", response.body.?);
}

test "Router path parameters" {
    const allocator = std.testing.allocator;
    var router = Router.init(allocator);
    defer router.deinit();

    _ = try router.get("/users/:id", testParamHandler);

    var request = Request.init(allocator);
    defer request.deinit();
    request.method = .GET;
    request.url = types.Url.parse("/users/123");

    var response = Response.init(allocator);
    defer response.deinit();

    var ctx = Context{
        .allocator = allocator,
        .request = &request,
        .response = &response,
    };

    try router.handle(&ctx);

    try std.testing.expectEqualStrings("123", request.param("id").?);
}

test "Router 404 not found" {
    const allocator = std.testing.allocator;
    var router = Router.init(allocator);
    defer router.deinit();

    _ = try router.get("/exists", testHandler);

    var request = Request.init(allocator);
    defer request.deinit();
    request.method = .GET;
    request.url = types.Url.parse("/not-exists");

    var response = Response.init(allocator);
    defer response.deinit();

    var ctx = Context{
        .allocator = allocator,
        .request = &request,
        .response = &response,
    };

    try router.handle(&ctx);

    try std.testing.expectEqual(types.Status.not_found, response.status);
}

test "RouteGroup" {
    const allocator = std.testing.allocator;
    var router = Router.init(allocator);
    defer router.deinit();

    var api = RouteGroup.init(allocator, &router, "/api/v1");
    _ = try api.get("/users", testHandler);
    _ = try api.post("/users", testHandler);

    try std.testing.expectEqual(@as(usize, 2), router.routes.items.len);
    try std.testing.expectEqualStrings("/api/v1/users", router.routes.items[0].pattern);
}

test "Route all methods" {
    const allocator = std.testing.allocator;
    var router = Router.init(allocator);
    defer router.deinit();

    _ = try router.all("/health", testHandler);

    // Should match GET
    {
        var request = Request.init(allocator);
        defer request.deinit();
        request.method = .GET;
        request.url = types.Url.parse("/health");

        var response = Response.init(allocator);
        defer response.deinit();

        var ctx = Context{
            .allocator = allocator,
            .request = &request,
            .response = &response,
        };

        try router.handle(&ctx);
        try std.testing.expect(response.status != .not_found);
    }

    // Should match POST
    {
        var request = Request.init(allocator);
        defer request.deinit();
        request.method = .POST;
        request.url = types.Url.parse("/health");

        var response = Response.init(allocator);
        defer response.deinit();

        var ctx = Context{
            .allocator = allocator,
            .request = &request,
            .response = &response,
        };

        try router.handle(&ctx);
        try std.testing.expect(response.status != .not_found);
    }
}
