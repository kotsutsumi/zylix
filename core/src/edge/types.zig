//! Zylix Edge - Common Types and Interfaces
//!
//! Platform-agnostic types for edge computing adapters.

const std = @import("std");
const server = @import("../server/server.zig");

/// Supported edge platforms
pub const Platform = enum {
    cloudflare,
    vercel,
    aws_lambda,
    azure,
    deno,
    gcp,
    fastly,
    native, // Local/native execution
    unknown,

    /// Get platform name as string
    pub fn name(self: Platform) []const u8 {
        return switch (self) {
            .cloudflare => "Cloudflare Workers",
            .vercel => "Vercel Edge Functions",
            .aws_lambda => "AWS Lambda",
            .azure => "Azure Functions",
            .deno => "Deno Deploy",
            .gcp => "Google Cloud Run",
            .fastly => "Fastly Compute@Edge",
            .native => "Native",
            .unknown => "Unknown",
        };
    }
};

/// Edge environment configuration
pub const EdgeConfig = struct {
    /// Platform being used
    platform: Platform = .unknown,

    /// Enable cold start optimization
    cold_start_optimization: bool = true,

    /// Request timeout in milliseconds
    timeout_ms: u32 = 30000,

    /// Maximum request body size
    max_body_size: usize = 1024 * 1024, // 1MB

    /// Enable request/response streaming
    streaming: bool = false,

    /// Enable edge caching
    caching: bool = true,

    /// Cache TTL in seconds
    cache_ttl: u32 = 60,
};

/// Edge request abstraction
pub const EdgeRequest = struct {
    allocator: std.mem.Allocator,

    /// HTTP method
    method: server.Method,

    /// Request URL/path
    url: []const u8,

    /// Request headers
    headers: std.StringHashMapUnmanaged([]const u8),

    /// Request body (if any)
    body: ?[]const u8,

    /// Query parameters
    query: ?[]const u8,

    /// Client IP address
    client_ip: ?[]const u8,

    /// Geographic information (if available)
    geo: ?GeoInfo,

    /// Platform-specific context
    platform_context: ?*anyopaque,

    pub fn init(allocator: std.mem.Allocator) EdgeRequest {
        return .{
            .allocator = allocator,
            .method = .GET,
            .url = "/",
            .headers = .{},
            .body = null,
            .query = null,
            .client_ip = null,
            .geo = null,
            .platform_context = null,
        };
    }

    pub fn deinit(self: *EdgeRequest) void {
        self.headers.deinit(self.allocator);
    }

    /// Convert to server Request
    pub fn toServerRequest(self: *EdgeRequest) !server.Request {
        var req = server.Request.init(self.allocator);
        req.method = self.method;
        req.url = server.Url.parse(self.url);

        var it = self.headers.iterator();
        while (it.next()) |entry| {
            try req.headers.set(entry.key_ptr.*, entry.value_ptr.*);
        }

        if (self.body) |b| {
            req.body = try self.allocator.dupe(u8, b);
        }

        return req;
    }
};

/// Geographic information
pub const GeoInfo = struct {
    country: ?[]const u8 = null,
    region: ?[]const u8 = null,
    city: ?[]const u8 = null,
    latitude: ?f64 = null,
    longitude: ?f64 = null,
    timezone: ?[]const u8 = null,
};

/// Edge response abstraction
pub const EdgeResponse = struct {
    allocator: std.mem.Allocator,

    /// HTTP status code
    status: u16,

    /// Response headers
    headers: std.StringHashMapUnmanaged([]const u8),

    /// Response body
    body: ?[]const u8,

    /// Body is owned by response
    body_owned: bool,

    /// Enable streaming response
    streaming: bool,

    pub fn init(allocator: std.mem.Allocator) EdgeResponse {
        return .{
            .allocator = allocator,
            .status = 200,
            .headers = .{},
            .body = null,
            .body_owned = false,
            .streaming = false,
        };
    }

    pub fn deinit(self: *EdgeResponse) void {
        self.headers.deinit(self.allocator);
        if (self.body_owned) {
            if (self.body) |b| {
                self.allocator.free(b);
            }
        }
    }

    /// Set status code
    pub fn setStatus(self: *EdgeResponse, status: u16) *EdgeResponse {
        self.status = status;
        return self;
    }

    /// Set header
    pub fn setHeader(self: *EdgeResponse, name: []const u8, value: []const u8) !*EdgeResponse {
        try self.headers.put(self.allocator, name, value);
        return self;
    }

    /// Set body (not owned)
    pub fn setBody(self: *EdgeResponse, body: []const u8) *EdgeResponse {
        if (self.body_owned) {
            if (self.body) |b| {
                self.allocator.free(b);
            }
        }
        self.body = body;
        self.body_owned = false;
        return self;
    }

    /// Set body (owned)
    pub fn setBodyOwned(self: *EdgeResponse, body: []const u8) *EdgeResponse {
        if (self.body_owned) {
            if (self.body) |b| {
                self.allocator.free(b);
            }
        }
        self.body = body;
        self.body_owned = true;
        return self;
    }

    /// Create from server Response
    pub fn fromServerResponse(allocator: std.mem.Allocator, res: *server.Response) !EdgeResponse {
        var edge_res = EdgeResponse.init(allocator);
        edge_res.status = @intFromEnum(res.status);

        var it = res.headers.entries.iterator();
        while (it.next()) |entry| {
            try edge_res.headers.put(allocator, entry.key_ptr.*, entry.value_ptr.*);
        }

        if (res.body) |b| {
            edge_res.body = try allocator.dupe(u8, b);
            edge_res.body_owned = true;
        }

        return edge_res;
    }
};

/// KV Store interface for edge platforms
pub const KVStore = struct {
    allocator: std.mem.Allocator,
    platform: Platform,
    namespace: []const u8,
    impl: *anyopaque,

    // Function pointers for platform-specific operations
    get_fn: *const fn (*anyopaque, []const u8) anyerror!?[]const u8,
    put_fn: *const fn (*anyopaque, []const u8, []const u8, ?KVOptions) anyerror!void,
    delete_fn: *const fn (*anyopaque, []const u8) anyerror!void,
    list_fn: *const fn (*anyopaque, ?KVListOptions) anyerror!KVListResult,

    pub const KVOptions = struct {
        expiration: ?u64 = null, // Unix timestamp
        expiration_ttl: ?u32 = null, // Seconds
        metadata: ?[]const u8 = null,
    };

    pub const KVListOptions = struct {
        prefix: ?[]const u8 = null,
        limit: u32 = 1000,
        cursor: ?[]const u8 = null,
    };

    pub const KVListResult = struct {
        keys: []const []const u8,
        cursor: ?[]const u8,
        complete: bool,
    };

    pub fn get(self: *KVStore, key: []const u8) anyerror!?[]const u8 {
        return self.get_fn(self.impl, key);
    }

    pub fn put(self: *KVStore, key: []const u8, value: []const u8, options: ?KVOptions) anyerror!void {
        return self.put_fn(self.impl, key, value, options);
    }

    pub fn delete(self: *KVStore, key: []const u8) anyerror!void {
        return self.delete_fn(self.impl, key);
    }

    pub fn list(self: *KVStore, options: ?KVListOptions) anyerror!KVListResult {
        return self.list_fn(self.impl, options);
    }
};

/// Edge adapter interface
pub const EdgeAdapter = struct {
    platform: Platform,
    config: EdgeConfig,

    // Function pointers for platform operations
    handle_fn: *const fn (*EdgeAdapter, *EdgeRequest) anyerror!EdgeResponse,
    get_kv_fn: ?*const fn (*EdgeAdapter, []const u8) anyerror!KVStore,

    /// Handle incoming request
    pub fn handle(self: *EdgeAdapter, request: *EdgeRequest) anyerror!EdgeResponse {
        return self.handle_fn(self, request);
    }

    /// Get KV store by namespace
    pub fn getKV(self: *EdgeAdapter, namespace: []const u8) anyerror!KVStore {
        if (self.get_kv_fn) |get_fn| {
            return get_fn(self, namespace);
        }
        return error.KVNotSupported;
    }
};

/// Edge middleware function type
pub const EdgeMiddlewareFn = *const fn (*EdgeRequest, *EdgeResponse, EdgeNext) anyerror!void;

/// Edge middleware next function
pub const EdgeNext = struct {
    chain: []const EdgeMiddlewareFn,
    index: usize,
    request: *EdgeRequest,
    response: *EdgeResponse,

    pub fn call(self: EdgeNext) anyerror!void {
        if (self.index < self.chain.len) {
            const middleware = self.chain[self.index];
            try middleware(self.request, self.response, EdgeNext{
                .chain = self.chain,
                .index = self.index + 1,
                .request = self.request,
                .response = self.response,
            });
        }
    }
};

/// Edge cache control
pub const CacheControl = struct {
    /// Cache directive
    directive: Directive,

    /// Max age in seconds
    max_age: ?u32 = null,

    /// Stale-while-revalidate in seconds
    stale_while_revalidate: ?u32 = null,

    /// Stale-if-error in seconds
    stale_if_error: ?u32 = null,

    pub const Directive = enum {
        public,
        private,
        no_cache,
        no_store,
        must_revalidate,
    };

    pub fn format(self: CacheControl, buffer: []u8) ![]const u8 {
        var writer = std.io.fixedBufferStream(buffer);
        const w = writer.writer();

        try w.print("{s}", .{switch (self.directive) {
            .public => "public",
            .private => "private",
            .no_cache => "no-cache",
            .no_store => "no-store",
            .must_revalidate => "must-revalidate",
        }});

        if (self.max_age) |age| {
            try w.print(", max-age={d}", .{age});
        }

        if (self.stale_while_revalidate) |swr| {
            try w.print(", stale-while-revalidate={d}", .{swr});
        }

        if (self.stale_if_error) |sie| {
            try w.print(", stale-if-error={d}", .{sie});
        }

        return buffer[0..writer.pos];
    }
};

/// Edge error types
pub const EdgeError = error{
    PlatformNotSupported,
    RequestTimeout,
    BodyTooLarge,
    InvalidRequest,
    KVNotSupported,
    StorageError,
    NetworkError,
    AuthenticationError,
    RateLimited,
    InternalError,
};

// ============================================================================
// Unit Tests
// ============================================================================

test "Platform name" {
    try std.testing.expectEqualStrings("Cloudflare Workers", Platform.cloudflare.name());
    try std.testing.expectEqualStrings("AWS Lambda", Platform.aws_lambda.name());
}

test "EdgeRequest init and deinit" {
    const allocator = std.testing.allocator;
    var req = EdgeRequest.init(allocator);
    defer req.deinit();

    try std.testing.expectEqual(server.Method.GET, req.method);
    try std.testing.expectEqualStrings("/", req.url);
}

test "EdgeResponse init and deinit" {
    const allocator = std.testing.allocator;
    var res = EdgeResponse.init(allocator);
    defer res.deinit();

    _ = res.setStatus(201);
    try std.testing.expectEqual(@as(u16, 201), res.status);
}

test "CacheControl format" {
    var buffer: [128]u8 = undefined;

    const cc = CacheControl{
        .directive = .public,
        .max_age = 3600,
        .stale_while_revalidate = 60,
    };

    const result = try cc.format(&buffer);
    try std.testing.expect(std.mem.indexOf(u8, result, "public") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "max-age=3600") != null);
}
