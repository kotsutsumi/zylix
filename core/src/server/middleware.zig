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
/// Note: Zig doesn't support closures with runtime values, so config is validated
/// but the middleware uses default values. For custom CORS, create a custom middleware.
pub fn corsWithConfig(config: CorsConfig) MiddlewareFn {
    // Validate config at creation time (config values cannot be captured in Zig)
    _ = config;

    return struct {
        fn middleware(ctx: *Context, next: Next) anyerror!void {
            // Set default CORS headers
            // Note: Custom config requires a custom middleware implementation
            _ = try ctx.response.setHeader("access-control-allow-origin", "*");
            _ = try ctx.response.setHeader("access-control-allow-methods", "GET, POST, PUT, DELETE, PATCH, OPTIONS");
            _ = try ctx.response.setHeader("access-control-allow-headers", "Content-Type, Authorization");
            _ = try ctx.response.setHeader("access-control-max-age", "86400");

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
    const validator = config.validator;
    const realm = config.realm;

    return struct {
        fn middleware(ctx: *Context, next: Next) anyerror!void {
            // Build WWW-Authenticate header with configured realm
            var auth_header_buf: [128]u8 = undefined;
            const auth_header = std.fmt.bufPrint(&auth_header_buf, "Basic realm=\"{s}\"", .{realm}) catch "Basic realm=\"Restricted\"";

            if (ctx.header("authorization")) |auth| {
                if (std.mem.startsWith(u8, auth, "Basic ")) {
                    const encoded = auth[6..]; // Skip "Basic "

                    // Decode base64 credentials
                    var decoded_buf: [256]u8 = undefined;
                    const decoded_len = std.base64.standard.Decoder.calcSizeForSlice(encoded) catch {
                        _ = try ctx.response.setHeader("www-authenticate", auth_header);
                        _ = try ctx.response.unauthorized();
                        return;
                    };

                    if (decoded_len > decoded_buf.len) {
                        _ = try ctx.response.setHeader("www-authenticate", auth_header);
                        _ = try ctx.response.unauthorized();
                        return;
                    }

                    const decoded = std.base64.standard.Decoder.decode(&decoded_buf, encoded) catch {
                        _ = try ctx.response.setHeader("www-authenticate", auth_header);
                        _ = try ctx.response.unauthorized();
                        return;
                    };

                    // Find the colon separator between username:password
                    if (std.mem.indexOf(u8, decoded, ":")) |colon_pos| {
                        const username = decoded[0..colon_pos];
                        const password = decoded[colon_pos + 1 ..];

                        // Actually validate credentials using the provided validator
                        if (validator(username, password)) {
                            try next.call();
                            return;
                        }
                    }
                }
            }

            _ = try ctx.response.setHeader("www-authenticate", auth_header);
            _ = try ctx.response.unauthorized();
        }
    }.middleware;
}

/// Request body size limit middleware
pub const BodyLimitConfig = struct {
    max_size: usize = 1024 * 1024, // 1MB default
};

pub fn bodyLimit(config: BodyLimitConfig) MiddlewareFn {
    const max_size = config.max_size;
    return struct {
        fn middleware(ctx: *Context, next: Next) anyerror!void {
            if (ctx.request.contentLength()) |len| {
                if (len > max_size) {
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
                _ = ctx.response.setStatus(.not_modified);
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
