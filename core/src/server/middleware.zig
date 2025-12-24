//! Zylix Server - Middleware System
//!
//! Composable middleware chain for request/response processing.

const std = @import("std");
const types = @import("types.zig");
const router_mod = @import("router.zig");

const Context = router_mod.Context;
const Handler = router_mod.Handler;
const Status = types.Status;

/// Middleware function type
/// Returns true to continue chain, false to stop
pub const MiddlewareFn = *const fn (*Context, Next) anyerror!void;

/// Next function to call the next middleware
pub const Next = struct {
    chain: *const MiddlewareChain,
    index: usize,
    ctx: *Context,

    pub fn call(self: Next) anyerror!void {
        if (self.index < self.chain.middlewares.items.len) {
            const middleware = self.chain.middlewares.items[self.index];
            try middleware(self.ctx, Next{
                .chain = self.chain,
                .index = self.index + 1,
                .ctx = self.ctx,
            });
        } else if (self.chain.handler) |handler| {
            try handler(self.ctx);
        }
    }
};

/// Middleware chain for composing multiple middlewares
pub const MiddlewareChain = struct {
    allocator: std.mem.Allocator,
    middlewares: std.ArrayListUnmanaged(MiddlewareFn),
    handler: ?Handler,

    pub fn init(allocator: std.mem.Allocator) MiddlewareChain {
        return .{
            .allocator = allocator,
            .middlewares = .{},
            .handler = null,
        };
    }

    pub fn deinit(self: *MiddlewareChain) void {
        self.middlewares.deinit(self.allocator);
    }

    /// Add middleware to chain
    pub fn use(self: *MiddlewareChain, middleware: MiddlewareFn) !*MiddlewareChain {
        try self.middlewares.append(self.allocator, middleware);
        return self;
    }

    /// Set final handler
    pub fn setHandler(self: *MiddlewareChain, handler: Handler) *MiddlewareChain {
        self.handler = handler;
        return self;
    }

    /// Execute middleware chain
    pub fn execute(self: *const MiddlewareChain, ctx: *Context) !void {
        const next = Next{
            .chain = self,
            .index = 0,
            .ctx = ctx,
        };
        try next.call();
    }
};

// ============================================================================
// Built-in Middlewares
// ============================================================================

/// Logger middleware - logs request info
pub fn logger(ctx: *Context, next: Next) anyerror!void {
    const start = std.time.milliTimestamp();

    // Call next middleware/handler
    try next.call();

    const end = std.time.milliTimestamp();
    const duration = end - start;

    // Log request (using debug log for now)
    std.log.debug("{s} {s} - {d}ms", .{
        @tagName(ctx.request.method),
        ctx.request.url.path,
        duration,
    });
}

/// CORS middleware configuration
pub const CorsConfig = struct {
    allow_origins: []const []const u8 = &.{"*"},
    allow_methods: []const []const u8 = &.{ "GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS" },
    allow_headers: []const []const u8 = &.{ "Content-Type", "Authorization" },
    expose_headers: []const []const u8 = &.{},
    allow_credentials: bool = false,
    max_age: ?u32 = 86400, // 24 hours
};

/// Create CORS middleware with default config
pub fn cors(ctx: *Context, next: Next) anyerror!void {
    return corsWithConfig(CorsConfig{})(ctx, next);
}

/// Create CORS middleware with custom config
pub fn corsWithConfig(config: CorsConfig) MiddlewareFn {
    _ = config; // TODO: Use config in actual implementation
    return struct {
        fn middleware(ctx: *Context, next: Next) anyerror!void {
            // Set CORS headers
            _ = try ctx.response.setHeader("access-control-allow-origin", "*");
            _ = try ctx.response.setHeader("access-control-allow-methods", "GET, POST, PUT, DELETE, PATCH, OPTIONS");
            _ = try ctx.response.setHeader("access-control-allow-headers", "Content-Type, Authorization");

            // Handle preflight request
            if (ctx.request.method == .OPTIONS) {
                _ = ctx.response.setStatus(.no_content);
                return;
            }

            try next.call();
        }
    }.middleware;
}

/// Compression config
pub const CompressionConfig = struct {
    level: enum { fast, default, best } = .default,
    min_size: usize = 1024, // Only compress if body > 1KB
};

/// Recovery middleware - catches panics and returns 500
pub fn recovery(ctx: *Context, next: Next) anyerror!void {
    next.call() catch |err| {
        std.log.err("Request handler error: {}", .{err});
        _ = try ctx.response.internalError("Internal Server Error");
    };
}

/// Request timeout middleware
pub const TimeoutConfig = struct {
    timeout_ms: u64 = 30000, // 30 seconds default
};

/// Rate limiter config
pub const RateLimitConfig = struct {
    requests_per_second: u32 = 100,
    burst_size: u32 = 10,
};

/// Basic auth config
pub const BasicAuthConfig = struct {
    realm: []const u8 = "Restricted",
    validator: *const fn (username: []const u8, password: []const u8) bool,
};

/// Create basic auth middleware
pub fn basicAuth(config: BasicAuthConfig) MiddlewareFn {
    _ = config; // Store in closure
    return struct {
        fn middleware(ctx: *Context, next: Next) anyerror!void {
            if (ctx.header("authorization")) |auth| {
                if (std.mem.startsWith(u8, auth, "Basic ")) {
                    // Decode and validate - simplified for now
                    // Full implementation would base64 decode and validate credentials
                    try next.call();
                    return;
                }
            }

            _ = try ctx.response.setHeader("www-authenticate", "Basic realm=\"Restricted\"");
            _ = try ctx.response.unauthorized();
        }
    }.middleware;
}

/// Request body size limit middleware
pub const BodyLimitConfig = struct {
    max_size: usize = 1024 * 1024, // 1MB default
};

pub fn bodyLimit(config: BodyLimitConfig) MiddlewareFn {
    _ = config; // Store in closure
    return struct {
        fn middleware(ctx: *Context, next: Next) anyerror!void {
            if (ctx.request.contentLength()) |len| {
                if (len > 1024 * 1024) { // 1MB
                    _ = ctx.response.setStatus(.payload_too_large);
                    _ = try ctx.response.text("Request body too large");
                    return;
                }
            }
            try next.call();
        }
    }.middleware;
}

/// Security headers middleware
pub fn secureHeaders(ctx: *Context, next: Next) anyerror!void {
    _ = try ctx.response.setHeader("x-content-type-options", "nosniff");
    _ = try ctx.response.setHeader("x-frame-options", "DENY");
    _ = try ctx.response.setHeader("x-xss-protection", "1; mode=block");
    _ = try ctx.response.setHeader("referrer-policy", "strict-origin-when-cross-origin");

    try next.call();
}

/// ETag middleware for caching
pub fn etag(ctx: *Context, next: Next) anyerror!void {
    try next.call();

    // Generate ETag from response body
    if (ctx.response.body) |body| {
        var hash: [16]u8 = undefined;
        std.crypto.hash.Md5.hash(body, &hash, .{});

        var etag_buf: [36]u8 = undefined;
        const etag_str = std.fmt.bufPrint(&etag_buf, "\"{s}\"", .{
            std.fmt.fmtSliceHexLower(&hash),
        }) catch return;

        // Check If-None-Match header
        if (ctx.header("if-none-match")) |client_etag| {
            if (std.mem.eql(u8, client_etag, etag_str)) {
                _ = ctx.response.setStatus(.NotModified);
                ctx.response.body = null;
                return;
            }
        }

        _ = try ctx.response.setHeader("etag", etag_str);
    }
}

// ============================================================================
// Unit Tests
// ============================================================================

fn testHandler(ctx: *Context) anyerror!void {
    try ctx.text("OK");
}

fn countingMiddleware(ctx: *Context, next: Next) anyerror!void {
    // Increment counter stored in context
    if (ctx.get("count")) |ptr| {
        const count: *usize = @ptrCast(@alignCast(ptr));
        count.* += 1;
    }
    try next.call();
}

test "MiddlewareChain init and deinit" {
    const allocator = std.testing.allocator;
    var chain = MiddlewareChain.init(allocator);
    defer chain.deinit();

    _ = try chain.use(logger);
    _ = try chain.use(secureHeaders);
    _ = chain.setHandler(testHandler);

    try std.testing.expectEqual(@as(usize, 2), chain.middlewares.items.len);
}

test "MiddlewareChain execute" {
    const allocator = std.testing.allocator;
    var chain = MiddlewareChain.init(allocator);
    defer chain.deinit();

    _ = chain.setHandler(testHandler);

    var request = @import("request.zig").Request.init(allocator);
    defer request.deinit();

    var response = @import("response.zig").Response.init(allocator);
    defer response.deinit();

    var ctx = Context{
        .allocator = allocator,
        .request = &request,
        .response = &response,
    };

    try chain.execute(&ctx);

    try std.testing.expectEqualStrings("OK", response.body.?);
}

test "MiddlewareChain with multiple middlewares" {
    const allocator = std.testing.allocator;
    var chain = MiddlewareChain.init(allocator);
    defer chain.deinit();

    var count: usize = 0;

    _ = try chain.use(countingMiddleware);
    _ = try chain.use(countingMiddleware);
    _ = try chain.use(countingMiddleware);
    _ = chain.setHandler(testHandler);

    var request = @import("request.zig").Request.init(allocator);
    defer request.deinit();
    try request.set("count", &count);

    var response = @import("response.zig").Response.init(allocator);
    defer response.deinit();

    var ctx = Context{
        .allocator = allocator,
        .request = &request,
        .response = &response,
    };

    try chain.execute(&ctx);

    try std.testing.expectEqual(@as(usize, 3), count);
}

test "CORS middleware" {
    const allocator = std.testing.allocator;

    var req = @import("request.zig").Request.init(allocator);
    defer req.deinit();
    req.method = .OPTIONS;

    var res = @import("response.zig").Response.init(allocator);
    defer res.deinit();

    var ctx = Context{
        .allocator = allocator,
        .request = &req,
        .response = &res,
    };

    // Create a simple next function for testing
    const EmptyChain = struct {
        fn emptyHandler(_: *Context) anyerror!void {}
    };

    var chain = MiddlewareChain.init(allocator);
    defer chain.deinit();
    _ = chain.setHandler(EmptyChain.emptyHandler);

    try cors(&ctx, Next{
        .chain = &chain,
        .index = 0,
        .ctx = &ctx,
    });

    try std.testing.expect(res.headers.get("access-control-allow-origin") != null);
    try std.testing.expectEqual(Status.no_content, res.status);
}

test "Security headers middleware" {
    const allocator = std.testing.allocator;

    var request = @import("request.zig").Request.init(allocator);
    defer request.deinit();

    var response = @import("response.zig").Response.init(allocator);
    defer response.deinit();

    var ctx = Context{
        .allocator = allocator,
        .request = &request,
        .response = &response,
    };

    var chain = MiddlewareChain.init(allocator);
    defer chain.deinit();
    _ = chain.setHandler(testHandler);

    try secureHeaders(&ctx, Next{
        .chain = &chain,
        .index = 0,
        .ctx = &ctx,
    });

    try std.testing.expectEqualStrings("nosniff", response.headers.get("x-content-type-options").?);
    try std.testing.expectEqualStrings("DENY", response.headers.get("x-frame-options").?);
}
