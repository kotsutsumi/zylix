//! Zylix Server Module
//!
//! High-performance HTTP server with routing, middleware, and RPC support.
//! Inspired by Hono.js with Zig-native implementation.
//!
//! Features:
//! - HTTP/1.1 request/response handling
//! - Flexible routing with path parameters
//! - Composable middleware chain
//! - Type-safe JSON-RPC 2.0 support
//! - Built-in middlewares (CORS, logging, security headers)
//!
//! Example usage:
//! ```zig
//! const server = @import("server");
//!
//! var app = try server.Zylix.init(allocator);
//! defer app.deinit();
//!
//! // Add middleware
//! _ = try app.use(server.middleware.logger);
//! _ = try app.use(server.middleware.cors);
//!
//! // Add routes
//! _ = try app.get("/", indexHandler);
//! _ = try app.get("/users/:id", userHandler);
//!
//! // Start server (would be platform-specific)
//! try app.listen(3000);
//! ```

const std = @import("std");

// Re-export submodules
pub const types = @import("types.zig");
pub const request = @import("request.zig");
pub const response = @import("response.zig");
pub const router = @import("router.zig");
pub const middleware = @import("middleware.zig");
pub const rpc = @import("rpc.zig");

// Re-export common types
pub const Method = types.Method;
pub const Status = types.Status;
pub const Headers = types.Headers;
pub const Cookie = types.Cookie;
pub const Url = types.Url;
pub const QueryParams = types.QueryParams;
pub const ContentType = types.ContentType;
pub const ServerConfig = types.ServerConfig;
pub const ServerError = types.ServerError;
pub const Error = types.Error;

pub const Request = request.Request;
pub const RequestBuilder = request.RequestBuilder;
pub const Response = response.Response;
pub const ResponseBuilder = response.ResponseBuilder;
pub const Router = router.Router;
pub const RouteGroup = router.RouteGroup;
pub const Context = router.Context;
pub const Handler = router.Handler;
pub const MiddlewareChain = middleware.MiddlewareChain;
pub const MiddlewareFn = middleware.MiddlewareFn;
pub const Next = middleware.Next;
pub const RpcServer = rpc.RpcServer;
pub const RpcClient = rpc.RpcClient;

/// Main Zylix server application
pub const Zylix = struct {
    allocator: std.mem.Allocator,
    router: Router,
    middleware_chain: MiddlewareChain,
    config: ServerConfig,

    /// Initialize a new Zylix server
    pub fn init(allocator: std.mem.Allocator) !Zylix {
        return initWithConfig(allocator, .{});
    }

    /// Initialize with custom configuration
    pub fn initWithConfig(allocator: std.mem.Allocator, config: ServerConfig) !Zylix {
        return .{
            .allocator = allocator,
            .router = Router.init(allocator),
            .middleware_chain = MiddlewareChain.init(allocator),
            .config = config,
        };
    }

    /// Clean up server resources
    pub fn deinit(self: *Zylix) void {
        self.router.deinit();
        self.middleware_chain.deinit();
    }

    // ========================================================================
    // Middleware API
    // ========================================================================

    /// Add middleware to the chain
    pub fn use(self: *Zylix, mw: MiddlewareFn) !*Zylix {
        _ = try self.middleware_chain.use(mw);
        return self;
    }

    // ========================================================================
    // Routing API
    // ========================================================================

    /// Add a route with any method
    pub fn route(self: *Zylix, method: ?Method, pattern: []const u8, handler: Handler) !*Zylix {
        _ = try self.router.route(method, pattern, handler);
        return self;
    }

    /// GET route
    pub fn get(self: *Zylix, pattern: []const u8, handler: Handler) !*Zylix {
        _ = try self.router.get(pattern, handler);
        return self;
    }

    /// POST route
    pub fn post(self: *Zylix, pattern: []const u8, handler: Handler) !*Zylix {
        _ = try self.router.post(pattern, handler);
        return self;
    }

    /// PUT route
    pub fn put(self: *Zylix, pattern: []const u8, handler: Handler) !*Zylix {
        _ = try self.router.put(pattern, handler);
        return self;
    }

    /// DELETE route
    pub fn delete(self: *Zylix, pattern: []const u8, handler: Handler) !*Zylix {
        _ = try self.router.delete(pattern, handler);
        return self;
    }

    /// PATCH route
    pub fn patch(self: *Zylix, pattern: []const u8, handler: Handler) !*Zylix {
        _ = try self.router.patch(pattern, handler);
        return self;
    }

    /// OPTIONS route
    pub fn options(self: *Zylix, pattern: []const u8, handler: Handler) !*Zylix {
        _ = try self.router.options(pattern, handler);
        return self;
    }

    /// HEAD route
    pub fn head(self: *Zylix, pattern: []const u8, handler: Handler) !*Zylix {
        _ = try self.router.head(pattern, handler);
        return self;
    }

    /// Match all HTTP methods
    pub fn all(self: *Zylix, pattern: []const u8, handler: Handler) !*Zylix {
        _ = try self.router.all(pattern, handler);
        return self;
    }

    /// Set custom 404 handler
    pub fn notFound(self: *Zylix, handler: Handler) *Zylix {
        _ = self.router.notFound(handler);
        return self;
    }

    /// Create a route group with shared prefix
    pub fn group(self: *Zylix, prefix: []const u8) RouteGroup {
        return RouteGroup.init(self.allocator, &self.router, prefix);
    }

    // ========================================================================
    // RPC API
    // ========================================================================

    /// Mount an RPC server
    pub fn rpcServer(self: *Zylix, path: []const u8) !RpcServer {
        var server = try RpcServer.init(self.allocator, path);
        try server.mount(&self.router);
        return server;
    }

    // ========================================================================
    // Request Handling
    // ========================================================================

    /// Handle an incoming request
    pub fn handleRequest(self: *Zylix, req: *Request) !Response {
        var res = Response.init(self.allocator);
        errdefer res.deinit();

        var ctx = Context{
            .allocator = self.allocator,
            .request = req,
            .response = &res,
        };

        // Store router reference in context to avoid static variable race condition
        try req.set("__zylix_router", @ptrCast(&self.router));

        // Set up middleware chain with router as final handler
        const RouterHandler = struct {
            fn handle(c: *Context) anyerror!void {
                if (c.request.get("__zylix_router")) |ptr| {
                    const router_ptr: *Router = @ptrCast(@alignCast(ptr));
                    try router_ptr.handle(c);
                }
            }
        };

        var chain = self.middleware_chain;
        _ = chain.setHandler(RouterHandler.handle);

        try chain.execute(&ctx);

        return res;
    }

    /// Handle raw HTTP data
    pub fn handleRaw(self: *Zylix, data: []const u8) ![]u8 {
        var req = try Request.parse(self.allocator, data);
        defer req.deinit();

        var res = try self.handleRequest(&req);
        defer res.deinit();

        return res.serialize();
    }

    // ========================================================================
    // Server Lifecycle (platform-specific implementations)
    // ========================================================================

    /// Start listening on a port (platform-specific)
    /// Note: Actual implementation would be platform-specific
    pub fn listen(self: *Zylix, port: u16) !void {
        _ = self;
        std.log.info("Server would listen on port {d}", .{port});
        // Platform-specific implementation would go here:
        // - Native: std.net.StreamServer
        // - WASM: Web Worker / Service Worker integration
        // - iOS/Android: Platform bridge integration
    }

    /// Stop the server
    pub fn close(self: *Zylix) void {
        _ = self;
        std.log.info("Server closed", .{});
    }
};

// ============================================================================
// Unit Tests
// ============================================================================

fn testIndexHandler(ctx: *Context) anyerror!void {
    try ctx.text("Welcome to Zylix!");
}

fn testApiHandler(ctx: *Context) anyerror!void {
    try ctx.jsonResponse("{\"status\":\"ok\"}");
}

fn testUserHandler(ctx: *Context) anyerror!void {
    if (ctx.param("id")) |id| {
        const json = try std.fmt.allocPrint(ctx.allocator, "{{\"id\":\"{s}\"}}", .{id});
        _ = ctx.response.setBodyOwned(json);
        _ = try ctx.response.setContentType(ContentType.application_json);
    }
}

test "Zylix init and deinit" {
    const allocator = std.testing.allocator;
    var app = try Zylix.init(allocator);
    defer app.deinit();

    try std.testing.expect(app.router.routes.items.len == 0);
}

test "Zylix routing" {
    const allocator = std.testing.allocator;
    var app = try Zylix.init(allocator);
    defer app.deinit();

    _ = try app.get("/", testIndexHandler);
    _ = try app.get("/api", testApiHandler);
    _ = try app.get("/users/:id", testUserHandler);
    _ = try app.post("/users", testApiHandler);

    try std.testing.expectEqual(@as(usize, 4), app.router.routes.items.len);
}

test "Zylix middleware" {
    const allocator = std.testing.allocator;
    var app = try Zylix.init(allocator);
    defer app.deinit();

    _ = try app.use(middleware.logger);
    _ = try app.use(middleware.secureHeaders);

    try std.testing.expectEqual(@as(usize, 2), app.middleware_chain.middlewares.items.len);
}

test "Zylix handle request" {
    const allocator = std.testing.allocator;
    var app = try Zylix.init(allocator);
    defer app.deinit();

    _ = try app.get("/", testIndexHandler);

    var req = Request.init(allocator);
    defer req.deinit();
    req.method = .GET;
    req.url = Url.parse("/");

    var res = try app.handleRequest(&req);
    defer res.deinit();

    try std.testing.expectEqual(Status.ok, res.status);
    try std.testing.expectEqualStrings("Welcome to Zylix!", res.body.?);
}

test "Zylix handle raw HTTP" {
    const allocator = std.testing.allocator;
    var app = try Zylix.init(allocator);
    defer app.deinit();

    _ = try app.get("/api", testApiHandler);

    const raw_request = "GET /api HTTP/1.1\r\nHost: localhost\r\n\r\n";
    const raw_response = try app.handleRaw(raw_request);
    defer allocator.free(raw_response);

    try std.testing.expect(std.mem.indexOf(u8, raw_response, "HTTP/1.1 200 OK") != null);
    try std.testing.expect(std.mem.indexOf(u8, raw_response, "{\"status\":\"ok\"}") != null);
}

test "Zylix route groups" {
    const allocator = std.testing.allocator;
    var app = try Zylix.init(allocator);
    defer app.deinit();

    var api = app.group("/api/v1");
    _ = try api.get("/users", testApiHandler);
    _ = try api.post("/users", testApiHandler);
    _ = try api.get("/users/:id", testUserHandler);

    try std.testing.expectEqual(@as(usize, 3), app.router.routes.items.len);
}

test "Zylix with config" {
    const allocator = std.testing.allocator;
    var app = try Zylix.initWithConfig(allocator, .{
        .port = 8080,
        .host = "0.0.0.0",
        .max_connections = 1000,
    });
    defer app.deinit();

    try std.testing.expectEqual(@as(u16, 8080), app.config.port);
    try std.testing.expectEqualStrings("0.0.0.0", app.config.host);
}
