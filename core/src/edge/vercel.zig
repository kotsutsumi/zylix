//! Zylix Edge - Vercel Edge Functions Adapter
//!
//! Deploy Zylix applications to Vercel Edge Functions with access to:
//! - Vercel KV
//! - Vercel Postgres (Neon)
//! - Blob Storage
//! - Edge Config
//! - ISR (Incremental Static Regeneration)

const std = @import("std");
const types = @import("types.zig");
const server = @import("../server/server.zig");

const Platform = types.Platform;
const EdgeConfig = types.EdgeConfig;
const EdgeRequest = types.EdgeRequest;
const EdgeResponse = types.EdgeResponse;
const KVStore = types.KVStore;

/// Vercel Edge configuration
pub const VercelConfig = struct {
    /// Enable ISR
    isr_enabled: bool = false,

    /// ISR revalidation period in seconds
    isr_revalidate: ?u32 = null,

    /// Edge regions
    regions: []const Region = &.{.all},

    pub const Region = enum {
        all,
        iad1, // Washington, D.C.
        sfo1, // San Francisco
        cdg1, // Paris
        hnd1, // Tokyo
        sin1, // Singapore
        syd1, // Sydney
        gru1, // São Paulo
        // Add more as needed
    };
};

/// Vercel KV (Redis-compatible)
pub const VercelKV = struct {
    allocator: std.mem.Allocator,
    url: []const u8,
    token: []const u8,

    // Local storage for simulation
    storage: std.StringHashMapUnmanaged(KVEntry),

    const KVEntry = struct {
        value: []const u8,
        expiration: ?u64,
    };

    pub fn init(allocator: std.mem.Allocator, url: []const u8, token: []const u8) !*VercelKV {
        const kv = try allocator.create(VercelKV);
        kv.* = .{
            .allocator = allocator,
            .url = try allocator.dupe(u8, url),
            .token = try allocator.dupe(u8, token),
            .storage = .{},
        };
        return kv;
    }

    pub fn deinit(self: *VercelKV) void {
        var it = self.storage.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.value);
        }
        self.storage.deinit(self.allocator);
        self.allocator.free(self.url);
        self.allocator.free(self.token);
        self.allocator.destroy(self);
    }

    /// Get value
    pub fn get(self: *VercelKV, key: []const u8) !?[]const u8 {
        if (self.storage.get(key)) |entry| {
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

    /// Set value
    pub fn set(self: *VercelKV, key: []const u8, value: []const u8, options: ?SetOptions) !void {
        if (self.storage.fetchRemove(key)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value.value);
        }

        var expiration: ?u64 = null;
        if (options) |opts| {
            if (opts.ex) |ex| {
                expiration = @as(u64, @intCast(std.time.timestamp())) + ex;
            } else if (opts.px) |px| {
                expiration = @as(u64, @intCast(std.time.timestamp())) + px / 1000;
            }
        }

        const key_copy = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(key_copy);
        const value_copy = try self.allocator.dupe(u8, value);

        try self.storage.put(self.allocator, key_copy, .{
            .value = value_copy,
            .expiration = expiration,
        });
    }

    /// Delete value
    pub fn del(self: *VercelKV, key: []const u8) !void {
        if (self.storage.fetchRemove(key)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value.value);
        }
    }

    /// Hash set
    pub fn hset(self: *VercelKV, key: []const u8, field: []const u8, value: []const u8) !void {
        const hash_key = try std.fmt.allocPrint(self.allocator, "{s}:{s}", .{ key, field });
        defer self.allocator.free(hash_key);
        try self.set(hash_key, value, null);
    }

    /// Hash get
    pub fn hget(self: *VercelKV, key: []const u8, field: []const u8) !?[]const u8 {
        const hash_key = try std.fmt.allocPrint(self.allocator, "{s}:{s}", .{ key, field });
        defer self.allocator.free(hash_key);
        return self.get(hash_key);
    }

    pub const SetOptions = struct {
        ex: ?u64 = null, // Expiration in seconds
        px: ?u64 = null, // Expiration in milliseconds
        nx: bool = false, // Only set if not exists
        xx: bool = false, // Only set if exists
    };
};

/// Vercel Blob storage
pub const VercelBlob = struct {
    allocator: std.mem.Allocator,
    token: []const u8,

    // Local storage for simulation
    blobs: std.StringHashMapUnmanaged(BlobEntry),

    const BlobEntry = struct {
        data: []const u8,
        content_type: []const u8,
        url: []const u8,
    };

    pub fn init(allocator: std.mem.Allocator, token: []const u8) !*VercelBlob {
        const blob = try allocator.create(VercelBlob);
        blob.* = .{
            .allocator = allocator,
            .token = try allocator.dupe(u8, token),
            .blobs = .{},
        };
        return blob;
    }

    pub fn deinit(self: *VercelBlob) void {
        var it = self.blobs.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.data);
            self.allocator.free(entry.value_ptr.content_type);
            self.allocator.free(entry.value_ptr.url);
        }
        self.blobs.deinit(self.allocator);
        self.allocator.free(self.token);
        self.allocator.destroy(self);
    }

    /// Upload blob
    pub fn put(self: *VercelBlob, pathname: []const u8, data: []const u8, options: ?PutOptions) !BlobResult {
        if (self.blobs.fetchRemove(pathname)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value.data);
            self.allocator.free(old.value.content_type);
            self.allocator.free(old.value.url);
        }

        const content_type = if (options) |opts| opts.content_type orelse "application/octet-stream" else "application/octet-stream";

        const pathname_copy = try self.allocator.dupe(u8, pathname);
        errdefer self.allocator.free(pathname_copy);
        const data_copy = try self.allocator.dupe(u8, data);
        errdefer self.allocator.free(data_copy);
        const ct_copy = try self.allocator.dupe(u8, content_type);
        errdefer self.allocator.free(ct_copy);
        const url = try std.fmt.allocPrint(self.allocator, "https://blob.vercel-storage.com/{s}", .{pathname});

        try self.blobs.put(self.allocator, pathname_copy, .{
            .data = data_copy,
            .content_type = ct_copy,
            .url = url,
        });

        return .{
            .url = url,
            .pathname = pathname_copy,
            .content_type = ct_copy,
            .size = data.len,
        };
    }

    /// Delete blob
    pub fn del(self: *VercelBlob, url: []const u8) !void {
        // Extract pathname from URL
        const prefix = "https://blob.vercel-storage.com/";
        if (std.mem.startsWith(u8, url, prefix)) {
            const pathname = url[prefix.len..];
            if (self.blobs.fetchRemove(pathname)) |old| {
                self.allocator.free(old.key);
                self.allocator.free(old.value.data);
                self.allocator.free(old.value.content_type);
                self.allocator.free(old.value.url);
            }
        }
    }

    pub const PutOptions = struct {
        content_type: ?[]const u8 = null,
        access: Access = .public,
        add_random_suffix: bool = true,

        pub const Access = enum { public, private };
    };

    pub const BlobResult = struct {
        url: []const u8,
        pathname: []const u8,
        content_type: []const u8,
        size: usize,
    };
};

/// Edge Config (global configuration)
pub const EdgeConfigClient = struct {
    allocator: std.mem.Allocator,
    config: std.StringHashMapUnmanaged(std.json.Value),

    pub fn init(allocator: std.mem.Allocator) !*EdgeConfigClient {
        const client = try allocator.create(EdgeConfigClient);
        client.* = .{
            .allocator = allocator,
            .config = .{},
        };
        return client;
    }

    pub fn deinit(self: *EdgeConfigClient) void {
        self.config.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    /// Get config value
    pub fn get(self: *EdgeConfigClient, key: []const u8) ?std.json.Value {
        return self.config.get(key);
    }

    /// Get all config
    pub fn getAll(self: *EdgeConfigClient) std.StringHashMapUnmanaged(std.json.Value) {
        return self.config;
    }

    /// Check if key exists
    pub fn has(self: *EdgeConfigClient, key: []const u8) bool {
        return self.config.get(key) != null;
    }
};

/// Vercel Edge Functions adapter
pub const VercelAdapter = struct {
    allocator: std.mem.Allocator,
    config: EdgeConfig,
    vercel_config: VercelConfig,
    kv: ?*VercelKV,
    blob: ?*VercelBlob,
    edge_config: ?*EdgeConfigClient,
    app: ?*server.Zylix,

    pub fn init(allocator: std.mem.Allocator) VercelAdapter {
        return .{
            .allocator = allocator,
            .config = .{ .platform = .vercel },
            .vercel_config = .{},
            .kv = null,
            .blob = null,
            .edge_config = null,
            .app = null,
        };
    }

    pub fn deinit(self: *VercelAdapter) void {
        if (self.kv) |kv| kv.deinit();
        if (self.blob) |blob| blob.deinit();
        if (self.edge_config) |ec| ec.deinit();
    }

    /// Set the Zylix application
    pub fn setApp(self: *VercelAdapter, app: *server.Zylix) *VercelAdapter {
        self.app = app;
        return self;
    }

    /// Configure Vercel KV
    pub fn withKV(self: *VercelAdapter, url: []const u8, token: []const u8) !*VercelAdapter {
        self.kv = try VercelKV.init(self.allocator, url, token);
        return self;
    }

    /// Configure Vercel Blob
    pub fn withBlob(self: *VercelAdapter, token: []const u8) !*VercelAdapter {
        self.blob = try VercelBlob.init(self.allocator, token);
        return self;
    }

    /// Configure Edge Config
    pub fn withEdgeConfig(self: *VercelAdapter) !*VercelAdapter {
        self.edge_config = try EdgeConfigClient.init(self.allocator);
        return self;
    }

    /// Enable ISR
    pub fn withISR(self: *VercelAdapter, revalidate: u32) *VercelAdapter {
        self.vercel_config.isr_enabled = true;
        self.vercel_config.isr_revalidate = revalidate;
        return self;
    }

    /// Handle incoming request
    pub fn handle(self: *VercelAdapter, request: *EdgeRequest) !EdgeResponse {
        if (self.app) |app| {
            var server_req = try request.toServerRequest();
            defer server_req.deinit();

            try server_req.set("__vercel_adapter", @ptrCast(self));

            var server_res = try app.handleRequest(&server_req);
            defer server_res.deinit();

            var edge_res = try EdgeResponse.fromServerResponse(self.allocator, &server_res);

            // Add ISR headers if enabled
            if (self.vercel_config.isr_enabled) {
                if (self.vercel_config.isr_revalidate) |revalidate| {
                    var buf: [32]u8 = undefined;
                    const value = try std.fmt.bufPrint(&buf, "s-maxage={d}, stale-while-revalidate", .{revalidate});
                    _ = try edge_res.setHeader("cache-control", value);
                }
            }

            return edge_res;
        }

        var res = EdgeResponse.init(self.allocator);
        _ = res.setStatus(500);
        _ = res.setBody("No application configured");
        return res;
    }
};

/// Create Vercel Edge middleware for Zylix server
pub fn adapter() server.MiddlewareFn {
    return struct {
        fn middleware(ctx: *server.Context, next: server.Next) anyerror!void {
            // Add Vercel-specific headers
            _ = try ctx.response.setHeader("x-vercel-id", "simulated");

            try next.call();
        }
    }.middleware;
}

// ============================================================================
// Unit Tests
// ============================================================================

test "VercelKV basic operations" {
    const allocator = std.testing.allocator;

    var kv = try VercelKV.init(allocator, "redis://localhost", "token");
    defer kv.deinit();

    try kv.set("key1", "value1", null);
    const value = try kv.get("key1");
    try std.testing.expectEqualStrings("value1", value.?);

    try kv.del("key1");
    const deleted = try kv.get("key1");
    try std.testing.expect(deleted == null);
}

test "VercelBlob basic operations" {
    const allocator = std.testing.allocator;

    var blob = try VercelBlob.init(allocator, "token");
    defer blob.deinit();

    const result = try blob.put("test.txt", "Hello, World!", .{ .content_type = "text/plain" });
    try std.testing.expect(std.mem.indexOf(u8, result.url, "test.txt") != null);
}

test "VercelAdapter init and deinit" {
    const allocator = std.testing.allocator;

    var adapter_instance = VercelAdapter.init(allocator);
    defer adapter_instance.deinit();

    _ = try adapter_instance.withKV("redis://localhost", "token");
    _ = adapter_instance.withISR(60);

    try std.testing.expectEqual(Platform.vercel, adapter_instance.config.platform);
    try std.testing.expect(adapter_instance.vercel_config.isr_enabled);
}
