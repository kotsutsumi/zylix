//! Zylix Edge - Cloudflare Workers Adapter
//!
//! Deploy Zylix applications to Cloudflare Workers with access to:
//! - KV Storage
//! - D1 Database
//! - Durable Objects
//! - R2 Storage
//! - Queues
//! - Workers AI

const std = @import("std");
const types = @import("types.zig");
const server = @import("../server/server.zig");

const Platform = types.Platform;
const EdgeConfig = types.EdgeConfig;
const EdgeRequest = types.EdgeRequest;
const EdgeResponse = types.EdgeResponse;
const EdgeAdapter = types.EdgeAdapter;
const KVStore = types.KVStore;
const EdgeError = types.EdgeError;

/// Cloudflare Workers environment bindings
pub const CloudflareEnv = struct {
    allocator: std.mem.Allocator,

    /// KV namespaces
    kv_namespaces: std.StringHashMapUnmanaged(*CloudflareKV),

    /// D1 databases
    d1_databases: std.StringHashMapUnmanaged(*D1Database),

    /// R2 buckets
    r2_buckets: std.StringHashMapUnmanaged(*R2Bucket),

    /// Environment variables
    vars: std.StringHashMapUnmanaged([]const u8),

    /// Secrets
    secrets: std.StringHashMapUnmanaged([]const u8),

    pub fn init(allocator: std.mem.Allocator) CloudflareEnv {
        return .{
            .allocator = allocator,
            .kv_namespaces = .{},
            .d1_databases = .{},
            .r2_buckets = .{},
            .vars = .{},
            .secrets = .{},
        };
    }

    pub fn deinit(self: *CloudflareEnv) void {
        // Clean up KV namespaces
        var kv_it = self.kv_namespaces.iterator();
        while (kv_it.next()) |entry| {
            entry.value_ptr.*.deinit();
        }
        self.kv_namespaces.deinit(self.allocator);

        // Clean up D1 databases
        var d1_it = self.d1_databases.iterator();
        while (d1_it.next()) |entry| {
            entry.value_ptr.*.deinit();
        }
        self.d1_databases.deinit(self.allocator);

        // Clean up R2 buckets
        var r2_it = self.r2_buckets.iterator();
        while (r2_it.next()) |entry| {
            entry.value_ptr.*.deinit();
        }
        self.r2_buckets.deinit(self.allocator);

        self.vars.deinit(self.allocator);
        self.secrets.deinit(self.allocator);
    }

    /// Get environment variable
    pub fn getVar(self: *CloudflareEnv, name: []const u8) ?[]const u8 {
        return self.vars.get(name);
    }

    /// Get secret
    pub fn getSecret(self: *CloudflareEnv, name: []const u8) ?[]const u8 {
        return self.secrets.get(name);
    }
};

/// Cloudflare KV namespace
pub const CloudflareKV = struct {
    allocator: std.mem.Allocator,
    namespace: []const u8,

    // Simulated storage for native execution
    storage: std.StringHashMapUnmanaged(KVEntry),

    const KVEntry = struct {
        value: []const u8,
        metadata: ?[]const u8,
        expiration: ?u64,
    };

    pub fn init(allocator: std.mem.Allocator, namespace: []const u8) !*CloudflareKV {
        const kv = try allocator.create(CloudflareKV);
        kv.* = .{
            .allocator = allocator,
            .namespace = try allocator.dupe(u8, namespace),
            .storage = .{},
        };
        return kv;
    }

    pub fn deinit(self: *CloudflareKV) void {
        var it = self.storage.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.value);
            if (entry.value_ptr.metadata) |m| {
                self.allocator.free(m);
            }
        }
        self.storage.deinit(self.allocator);
        self.allocator.free(self.namespace);
        self.allocator.destroy(self);
    }

    /// Get value from KV
    pub fn get(self: *CloudflareKV, key: []const u8) !?[]const u8 {
        if (self.storage.get(key)) |entry| {
            // Check expiration
            if (entry.expiration) |exp| {
                const now = @as(u64, @intCast(std.time.timestamp()));
                if (now > exp) {
                    return null;
                }
            }
            return entry.value;
        }
        return null;
    }

    /// Get value with metadata
    pub fn getWithMetadata(self: *CloudflareKV, key: []const u8) !?struct { value: []const u8, metadata: ?[]const u8 } {
        if (self.storage.get(key)) |entry| {
            if (entry.expiration) |exp| {
                const now = @as(u64, @intCast(std.time.timestamp()));
                if (now > exp) {
                    return null;
                }
            }
            return .{ .value = entry.value, .metadata = entry.metadata };
        }
        return null;
    }

    /// Put value into KV
    pub fn put(self: *CloudflareKV, key: []const u8, value: []const u8, options: ?KVStore.KVOptions) !void {
        // Remove old entry if exists
        if (self.storage.fetchRemove(key)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value.value);
            if (old.value.metadata) |m| {
                self.allocator.free(m);
            }
        }

        var expiration: ?u64 = null;
        var metadata: ?[]const u8 = null;

        if (options) |opts| {
            if (opts.expiration) |exp| {
                expiration = exp;
            } else if (opts.expiration_ttl) |ttl| {
                expiration = @as(u64, @intCast(std.time.timestamp())) + ttl;
            }
            if (opts.metadata) |m| {
                metadata = try self.allocator.dupe(u8, m);
            }
        }

        const key_copy = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(key_copy);

        const value_copy = try self.allocator.dupe(u8, value);

        try self.storage.put(self.allocator, key_copy, .{
            .value = value_copy,
            .metadata = metadata,
            .expiration = expiration,
        });
    }

    /// Delete value from KV
    pub fn delete(self: *CloudflareKV, key: []const u8) !void {
        if (self.storage.fetchRemove(key)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value.value);
            if (old.value.metadata) |m| {
                self.allocator.free(m);
            }
        }
    }

    /// List keys
    pub fn list(self: *CloudflareKV, options: ?KVStore.KVListOptions) !KVStore.KVListResult {
        var keys = std.ArrayList([]const u8).init(self.allocator);
        errdefer keys.deinit();

        const limit: u32 = if (options) |opts| opts.limit else 1000;
        const prefix: ?[]const u8 = if (options) |opts| opts.prefix else null;

        var count: u32 = 0;
        var it = self.storage.iterator();
        while (it.next()) |entry| {
            if (count >= limit) break;

            if (prefix) |p| {
                if (!std.mem.startsWith(u8, entry.key_ptr.*, p)) {
                    continue;
                }
            }

            try keys.append(entry.key_ptr.*);
            count += 1;
        }

        return .{
            .keys = try keys.toOwnedSlice(),
            .cursor = null,
            .complete = true,
        };
    }

    /// Convert to generic KVStore interface
    pub fn toKVStore(self: *CloudflareKV) KVStore {
        return .{
            .allocator = self.allocator,
            .platform = .cloudflare,
            .namespace = self.namespace,
            .impl = @ptrCast(self),
            .get_fn = kvGet,
            .put_fn = kvPut,
            .delete_fn = kvDelete,
            .list_fn = kvList,
        };
    }

    fn kvGet(impl: *anyopaque, key: []const u8) anyerror!?[]const u8 {
        const self: *CloudflareKV = @ptrCast(@alignCast(impl));
        return self.get(key);
    }

    fn kvPut(impl: *anyopaque, key: []const u8, value: []const u8, options: ?KVStore.KVOptions) anyerror!void {
        const self: *CloudflareKV = @ptrCast(@alignCast(impl));
        return self.put(key, value, options);
    }

    fn kvDelete(impl: *anyopaque, key: []const u8) anyerror!void {
        const self: *CloudflareKV = @ptrCast(@alignCast(impl));
        return self.delete(key);
    }

    fn kvList(impl: *anyopaque, options: ?KVStore.KVListOptions) anyerror!KVStore.KVListResult {
        const self: *CloudflareKV = @ptrCast(@alignCast(impl));
        return self.list(options);
    }
};

/// D1 Database (SQLite at the edge)
pub const D1Database = struct {
    allocator: std.mem.Allocator,
    name: []const u8,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) !*D1Database {
        const db = try allocator.create(D1Database);
        db.* = .{
            .allocator = allocator,
            .name = try allocator.dupe(u8, name),
        };
        return db;
    }

    pub fn deinit(self: *D1Database) void {
        self.allocator.free(self.name);
        self.allocator.destroy(self);
    }

    /// Execute a query
    pub fn exec(self: *D1Database, query: []const u8) !D1Result {
        _ = self;
        _ = query;
        // Would use WASM bindings in actual Workers environment
        return .{ .success = true, .changes = 0 };
    }

    /// Prepare and execute with bindings
    pub fn prepare(self: *D1Database, query: []const u8) !D1Statement {
        return D1Statement{
            .db = self,
            .query = query,
        };
    }

    pub const D1Result = struct {
        success: bool,
        changes: u64,
    };

    pub const D1Statement = struct {
        db: *D1Database,
        query: []const u8,

        pub fn bind(self: *D1Statement, values: anytype) *D1Statement {
            _ = values;
            return self;
        }

        pub fn run(self: *D1Statement) !D1Result {
            _ = self;
            return .{ .success = true, .changes = 0 };
        }

        pub fn first(self: *D1Statement) !?std.json.Value {
            _ = self;
            return null;
        }

        pub fn all(self: *D1Statement) ![]std.json.Value {
            _ = self;
            return &[_]std.json.Value{};
        }
    };
};

/// R2 Object Storage
pub const R2Bucket = struct {
    allocator: std.mem.Allocator,
    name: []const u8,

    // Simulated storage
    objects: std.StringHashMapUnmanaged(R2Object),

    pub const R2Object = struct {
        key: []const u8,
        body: []const u8,
        content_type: ?[]const u8,
        etag: []const u8,
        size: usize,
        uploaded: u64,
    };

    pub fn init(allocator: std.mem.Allocator, name: []const u8) !*R2Bucket {
        const bucket = try allocator.create(R2Bucket);
        bucket.* = .{
            .allocator = allocator,
            .name = try allocator.dupe(u8, name),
            .objects = .{},
        };
        return bucket;
    }

    pub fn deinit(self: *R2Bucket) void {
        var it = self.objects.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.body);
            if (entry.value_ptr.content_type) |ct| {
                self.allocator.free(ct);
            }
            self.allocator.free(entry.value_ptr.etag);
        }
        self.objects.deinit(self.allocator);
        self.allocator.free(self.name);
        self.allocator.destroy(self);
    }

    /// Get object
    pub fn get(self: *R2Bucket, key: []const u8) !?R2Object {
        return self.objects.get(key);
    }

    /// Put object
    pub fn put(self: *R2Bucket, key: []const u8, body: []const u8, content_type: ?[]const u8) !void {
        // Remove old if exists
        if (self.objects.fetchRemove(key)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value.body);
            if (old.value.content_type) |ct| {
                self.allocator.free(ct);
            }
            self.allocator.free(old.value.etag);
        }

        const key_copy = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(key_copy);

        const body_copy = try self.allocator.dupe(u8, body);
        errdefer self.allocator.free(body_copy);

        var ct_copy: ?[]const u8 = null;
        if (content_type) |ct| {
            ct_copy = try self.allocator.dupe(u8, ct);
        }

        // Generate simple ETag
        var etag_buf: [32]u8 = undefined;
        const etag = try std.fmt.bufPrint(&etag_buf, "\"{x}\"", .{std.hash.Wyhash.hash(0, body)});
        const etag_copy = try self.allocator.dupe(u8, etag);

        try self.objects.put(self.allocator, key_copy, .{
            .key = key_copy,
            .body = body_copy,
            .content_type = ct_copy,
            .etag = etag_copy,
            .size = body.len,
            .uploaded = @as(u64, @intCast(std.time.timestamp())),
        });
    }

    /// Delete object
    pub fn delete(self: *R2Bucket, key: []const u8) !void {
        if (self.objects.fetchRemove(key)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value.body);
            if (old.value.content_type) |ct| {
                self.allocator.free(ct);
            }
            self.allocator.free(old.value.etag);
        }
    }
};

/// Cloudflare Workers adapter
pub const CloudflareAdapter = struct {
    allocator: std.mem.Allocator,
    config: EdgeConfig,
    env: CloudflareEnv,
    app: ?*server.Zylix,

    pub fn init(allocator: std.mem.Allocator) CloudflareAdapter {
        return .{
            .allocator = allocator,
            .config = .{ .platform = .cloudflare },
            .env = CloudflareEnv.init(allocator),
            .app = null,
        };
    }

    pub fn deinit(self: *CloudflareAdapter) void {
        self.env.deinit();
    }

    /// Set the Zylix application
    pub fn setApp(self: *CloudflareAdapter, app: *server.Zylix) *CloudflareAdapter {
        self.app = app;
        return self;
    }

    /// Add KV namespace binding
    pub fn bindKV(self: *CloudflareAdapter, name: []const u8) !*CloudflareAdapter {
        const kv = try CloudflareKV.init(self.allocator, name);
        try self.env.kv_namespaces.put(self.allocator, name, kv);
        return self;
    }

    /// Add D1 database binding
    pub fn bindD1(self: *CloudflareAdapter, name: []const u8) !*CloudflareAdapter {
        const db = try D1Database.init(self.allocator, name);
        try self.env.d1_databases.put(self.allocator, name, db);
        return self;
    }

    /// Add R2 bucket binding
    pub fn bindR2(self: *CloudflareAdapter, name: []const u8) !*CloudflareAdapter {
        const bucket = try R2Bucket.init(self.allocator, name);
        try self.env.r2_buckets.put(self.allocator, name, bucket);
        return self;
    }

    /// Handle incoming request (entry point for Workers)
    pub fn fetch(self: *CloudflareAdapter, request: *EdgeRequest) !EdgeResponse {
        if (self.app) |app| {
            // Convert to server request
            var server_req = try request.toServerRequest();
            defer server_req.deinit();

            // Store adapter reference in context
            try server_req.set("__cloudflare_adapter", @ptrCast(self));

            // Handle request
            var server_res = try app.handleRequest(&server_req);
            defer server_res.deinit();

            // Convert to edge response
            return EdgeResponse.fromServerResponse(self.allocator, &server_res);
        }

        // No app configured, return 500
        var res = EdgeResponse.init(self.allocator);
        _ = res.setStatus(500);
        _ = res.setBody("No application configured");
        return res;
    }

    /// Convert to generic EdgeAdapter interface
    pub fn toEdgeAdapter(self: *CloudflareAdapter) EdgeAdapter {
        return .{
            .platform = .cloudflare,
            .config = self.config,
            .handle_fn = handleEdgeRequest,
            .get_kv_fn = getKVStore,
        };
    }

    fn handleEdgeRequest(edge_adapter: *EdgeAdapter, request: *EdgeRequest) anyerror!EdgeResponse {
        _ = edge_adapter;
        _ = request;
        // Would delegate to self.fetch
        return EdgeResponse.init(std.heap.page_allocator);
    }

    fn getKVStore(edge_adapter: *EdgeAdapter, namespace: []const u8) anyerror!KVStore {
        _ = edge_adapter;
        _ = namespace;
        return EdgeError.KVNotSupported;
    }
};

/// Create Cloudflare Workers middleware for Zylix server
pub fn adapter(env: *CloudflareEnv) server.MiddlewareFn {
    _ = env;
    return struct {
        fn middleware(ctx: *server.Context, next: server.Next) anyerror!void {
            // Add Cloudflare-specific headers
            _ = try ctx.response.setHeader("cf-ray", "simulated");

            try next.call();
        }
    }.middleware;
}

// ============================================================================
// Unit Tests
// ============================================================================

test "CloudflareKV basic operations" {
    const allocator = std.testing.allocator;

    var kv = try CloudflareKV.init(allocator, "TEST_KV");
    defer kv.deinit();

    // Put and get
    try kv.put("key1", "value1", null);
    const value = try kv.get("key1");
    try std.testing.expectEqualStrings("value1", value.?);

    // Delete
    try kv.delete("key1");
    const deleted = try kv.get("key1");
    try std.testing.expect(deleted == null);
}

test "CloudflareKV with TTL" {
    const allocator = std.testing.allocator;

    var kv = try CloudflareKV.init(allocator, "TEST_KV");
    defer kv.deinit();

    // Put with TTL (very short for testing - but won't actually expire in test)
    try kv.put("key1", "value1", .{ .expiration_ttl = 3600 });
    const value = try kv.get("key1");
    try std.testing.expectEqualStrings("value1", value.?);
}

test "R2Bucket basic operations" {
    const allocator = std.testing.allocator;

    var bucket = try R2Bucket.init(allocator, "TEST_BUCKET");
    defer bucket.deinit();

    // Put object
    try bucket.put("file.txt", "Hello, World!", "text/plain");

    // Get object
    const obj = try bucket.get("file.txt");
    try std.testing.expect(obj != null);
    try std.testing.expectEqualStrings("Hello, World!", obj.?.body);
    try std.testing.expectEqualStrings("text/plain", obj.?.content_type.?);

    // Delete object
    try bucket.delete("file.txt");
    const deleted = try bucket.get("file.txt");
    try std.testing.expect(deleted == null);
}

test "CloudflareAdapter init and deinit" {
    const allocator = std.testing.allocator;

    var adapter_instance = CloudflareAdapter.init(allocator);
    defer adapter_instance.deinit();

    _ = try adapter_instance.bindKV("MY_KV");
    _ = try adapter_instance.bindR2("MY_BUCKET");

    try std.testing.expectEqual(Platform.cloudflare, adapter_instance.config.platform);
}
