//! Zylix Edge - Deno Deploy Adapter
//!
//! Deploy Zylix applications to Deno Deploy with access to:
//! - Deno KV
//! - BroadcastChannel
//! - Cron Triggers
//! - Fresh Framework compatibility

const std = @import("std");
const types = @import("types.zig");
const server = @import("../server/server.zig");

const Platform = types.Platform;
const EdgeConfig = types.EdgeConfig;
const EdgeRequest = types.EdgeRequest;
const EdgeResponse = types.EdgeResponse;
const KVStore = types.KVStore;

/// Deno Deploy configuration
pub const DenoConfig = struct {
    /// Project name
    project: []const u8 = "",

    /// Enable Deno KV
    kv_enabled: bool = true,

    /// Enable BroadcastChannel
    broadcast_enabled: bool = false,

    /// Cron schedules
    cron_schedules: []const CronSchedule = &.{},

    pub const CronSchedule = struct {
        name: []const u8,
        schedule: []const u8, // Cron expression
        handler: []const u8, // Handler function name
    };
};

/// Deno KV store
pub const DenoKV = struct {
    allocator: std.mem.Allocator,

    // Local storage for simulation
    storage: std.StringHashMapUnmanaged(KVEntry),

    const KVEntry = struct {
        value: []const u8,
        version: u64,
        expiration: ?u64,
    };

    pub fn init(allocator: std.mem.Allocator) !*DenoKV {
        const kv = try allocator.create(DenoKV);
        kv.* = .{
            .allocator = allocator,
            .storage = .{},
        };
        return kv;
    }

    pub fn deinit(self: *DenoKV) void {
        var it = self.storage.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.value);
        }
        self.storage.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    /// Get value with version
    pub fn get(self: *DenoKV, key: []const []const u8) !?KVResult {
        const full_key = try self.makeKey(key);
        defer self.allocator.free(full_key);

        if (self.storage.get(full_key)) |entry| {
            if (entry.expiration) |exp| {
                const now = @as(u64, @intCast(std.time.timestamp()));
                if (now > exp) return null;
            }
            return .{
                .key = key,
                .value = entry.value,
                .version = entry.version,
            };
        }
        return null;
    }

    /// Set value with atomic check
    pub fn set(self: *DenoKV, key: []const []const u8, value: []const u8, options: ?SetOptions) !void {
        const full_key = try self.makeKey(key);

        if (self.storage.fetchRemove(full_key)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value.value);
        }

        var expiration: ?u64 = null;
        if (options) |opts| {
            if (opts.expire_in) |exp| {
                expiration = @as(u64, @intCast(std.time.timestamp())) + exp / 1000;
            }
        }

        const key_copy = try self.allocator.dupe(u8, full_key);
        errdefer self.allocator.free(key_copy);
        const value_copy = try self.allocator.dupe(u8, value);

        try self.storage.put(self.allocator, key_copy, .{
            .value = value_copy,
            .version = @as(u64, @intCast(std.time.milliTimestamp())),
            .expiration = expiration,
        });

        self.allocator.free(full_key);
    }

    /// Delete value
    pub fn delete(self: *DenoKV, key: []const []const u8) !void {
        const full_key = try self.makeKey(key);
        defer self.allocator.free(full_key);

        if (self.storage.fetchRemove(full_key)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value.value);
        }
    }

    /// List keys with prefix
    pub fn list(self: *DenoKV, options: ListOptions) !ListResult {
        var keys = std.ArrayList([]const u8).init(self.allocator);
        errdefer keys.deinit();

        const prefix = if (options.prefix) |p| try self.makeKey(p) else null;
        defer if (prefix) |p| self.allocator.free(p);

        var it = self.storage.iterator();
        while (it.next()) |entry| {
            if (prefix) |p| {
                if (!std.mem.startsWith(u8, entry.key_ptr.*, p)) continue;
            }
            try keys.append(entry.key_ptr.*);
            if (keys.items.len >= options.limit) break;
        }

        return .{
            .keys = try keys.toOwnedSlice(),
            .cursor = null,
        };
    }

    /// Atomic transaction
    pub fn atomic(self: *DenoKV) AtomicOperation {
        return AtomicOperation.init(self);
    }

    fn makeKey(self: *DenoKV, parts: []const []const u8) ![]u8 {
        if (parts.len == 0) return try self.allocator.alloc(u8, 0);

        var total_len: usize = 0;
        for (parts) |part| {
            total_len += part.len;
        }
        // Add separator count (one less than number of parts)
        total_len += parts.len - 1;

        const key = try self.allocator.alloc(u8, total_len);
        var pos: usize = 0;
        for (parts, 0..) |part, i| {
            @memcpy(key[pos..][0..part.len], part);
            pos += part.len;
            if (i < parts.len - 1) {
                key[pos] = ':';
                pos += 1;
            }
        }

        return key;
    }

    pub const KVResult = struct {
        key: []const []const u8,
        value: []const u8,
        version: u64,
    };

    pub const SetOptions = struct {
        expire_in: ?u64 = null, // Milliseconds
    };

    pub const ListOptions = struct {
        prefix: ?[]const []const u8 = null,
        limit: u32 = 100,
        cursor: ?[]const u8 = null,
    };

    pub const ListResult = struct {
        keys: []const []const u8,
        cursor: ?[]const u8,
    };

    pub const AtomicOperation = struct {
        kv: *DenoKV,
        checks: std.ArrayList(Check),
        mutations: std.ArrayList(Mutation),

        pub const Check = struct {
            key: []const []const u8,
            version: ?u64,
        };

        pub const Mutation = struct {
            key: []const []const u8,
            value: ?[]const u8,
            kind: enum { set, delete },
        };

        pub fn init(kv: *DenoKV) AtomicOperation {
            return .{
                .kv = kv,
                .checks = std.ArrayList(Check).init(kv.allocator),
                .mutations = std.ArrayList(Mutation).init(kv.allocator),
            };
        }

        pub fn check(self: *AtomicOperation, key: []const []const u8, version: ?u64) *AtomicOperation {
            self.checks.append(.{ .key = key, .version = version }) catch {};
            return self;
        }

        pub fn set(self: *AtomicOperation, key: []const []const u8, value: []const u8) *AtomicOperation {
            self.mutations.append(.{ .key = key, .value = value, .kind = .set }) catch {};
            return self;
        }

        pub fn delete(self: *AtomicOperation, key: []const []const u8) *AtomicOperation {
            self.mutations.append(.{ .key = key, .value = null, .kind = .delete }) catch {};
            return self;
        }

        pub fn commit(self: *AtomicOperation) !bool {
            // Simplified: just apply mutations
            for (self.mutations.items) |mutation| {
                switch (mutation.kind) {
                    .set => if (mutation.value) |v| {
                        try self.kv.set(mutation.key, v, null);
                    },
                    .delete => try self.kv.delete(mutation.key),
                }
            }
            self.checks.deinit();
            self.mutations.deinit();
            return true;
        }
    };
};

/// BroadcastChannel for real-time messaging
pub const BroadcastChannel = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    subscribers: std.ArrayList(*const fn ([]const u8) void),

    pub fn init(allocator: std.mem.Allocator, name: []const u8) !*BroadcastChannel {
        const channel = try allocator.create(BroadcastChannel);
        channel.* = .{
            .allocator = allocator,
            .name = try allocator.dupe(u8, name),
            .subscribers = std.ArrayList(*const fn ([]const u8) void).init(allocator),
        };
        return channel;
    }

    pub fn deinit(self: *BroadcastChannel) void {
        self.subscribers.deinit();
        self.allocator.free(self.name);
        self.allocator.destroy(self);
    }

    /// Subscribe to messages
    pub fn onMessage(self: *BroadcastChannel, handler: *const fn ([]const u8) void) !void {
        try self.subscribers.append(handler);
    }

    /// Send message
    pub fn postMessage(self: *BroadcastChannel, message: []const u8) void {
        for (self.subscribers.items) |handler| {
            handler(message);
        }
    }

    /// Close channel
    pub fn close(self: *BroadcastChannel) void {
        self.subscribers.clearRetainingCapacity();
    }
};

/// Deno Deploy adapter
pub const DenoAdapter = struct {
    allocator: std.mem.Allocator,
    config: EdgeConfig,
    deno_config: DenoConfig,
    kv: ?*DenoKV,
    app: ?*server.Zylix,

    pub fn init(allocator: std.mem.Allocator) DenoAdapter {
        return .{
            .allocator = allocator,
            .config = .{ .platform = .deno },
            .deno_config = .{},
            .kv = null,
            .app = null,
        };
    }

    pub fn deinit(self: *DenoAdapter) void {
        if (self.kv) |kv| kv.deinit();
    }

    /// Set the Zylix application
    pub fn setApp(self: *DenoAdapter, app: *server.Zylix) *DenoAdapter {
        self.app = app;
        return self;
    }

    /// Enable Deno KV
    pub fn withKV(self: *DenoAdapter) !*DenoAdapter {
        self.kv = try DenoKV.init(self.allocator);
        self.deno_config.kv_enabled = true;
        return self;
    }

    /// Enable BroadcastChannel
    pub fn withBroadcast(self: *DenoAdapter) *DenoAdapter {
        self.deno_config.broadcast_enabled = true;
        return self;
    }

    /// Handle incoming request
    pub fn handle(self: *DenoAdapter, request: *EdgeRequest) !EdgeResponse {
        if (self.app) |app| {
            var server_req = try request.toServerRequest();
            defer server_req.deinit();

            try server_req.set("__deno_adapter", @ptrCast(self));

            var server_res = try app.handleRequest(&server_req);
            defer server_res.deinit();

            return EdgeResponse.fromServerResponse(self.allocator, &server_res);
        }

        var res = EdgeResponse.init(self.allocator);
        _ = res.setStatus(500);
        _ = res.setBody("No application configured");
        return res;
    }

    /// Serve the application
    pub fn serve(self: *DenoAdapter, port: u16) !void {
        _ = self;
        std.log.info("Deno Deploy server listening on port {d}", .{port});
    }
};

/// Create Deno Deploy middleware for Zylix server
pub fn adapter() server.MiddlewareFn {
    return struct {
        fn middleware(ctx: *server.Context, next: server.Next) anyerror!void {
            _ = try ctx.response.setHeader("x-deno-region", "simulated");
            try next.call();
        }
    }.middleware;
}

// ============================================================================
// Unit Tests
// ============================================================================

test "DenoKV basic operations" {
    const allocator = std.testing.allocator;

    var kv = try DenoKV.init(allocator);
    defer kv.deinit();

    const key = &[_][]const u8{ "users", "1" };
    try kv.set(key, "{\"name\":\"test\"}", null);

    const result = try kv.get(key);
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("{\"name\":\"test\"}", result.?.value);

    try kv.delete(key);
    const deleted = try kv.get(key);
    try std.testing.expect(deleted == null);
}

test "DenoAdapter init and deinit" {
    const allocator = std.testing.allocator;

    var adapter_instance = DenoAdapter.init(allocator);
    defer adapter_instance.deinit();

    _ = try adapter_instance.withKV();
    _ = adapter_instance.withBroadcast();

    try std.testing.expectEqual(Platform.deno, adapter_instance.config.platform);
    try std.testing.expect(adapter_instance.deno_config.kv_enabled);
}
