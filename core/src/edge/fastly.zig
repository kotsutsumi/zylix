//! Zylix Edge - Fastly Compute@Edge Adapter
//!
//! Deploy Zylix applications to Fastly Compute@Edge with access to:
//! - Config Store
//! - KV Store
//! - Secret Store
//! - Geolocation
//! - Request Collapsing
//! - Edge Dictionary

const std = @import("std");
const types = @import("types.zig");
const server = @import("../server/server.zig");

const Platform = types.Platform;
const EdgeConfig = types.EdgeConfig;
const EdgeRequest = types.EdgeRequest;
const EdgeResponse = types.EdgeResponse;
const GeoInfo = types.GeoInfo;

/// Fastly Compute configuration
pub const FastlyConfig = struct {
    /// Service ID
    service_id: []const u8 = "",

    /// Service version
    version: []const u8 = "",

    /// Backend name
    backend: []const u8 = "",

    /// Enable request collapsing
    request_collapsing: bool = false,

    /// Enable geolocation
    geolocation_enabled: bool = true,

    /// Cache TTL in seconds
    cache_ttl: u32 = 3600,
};

/// Fastly Config Store
pub const ConfigStore = struct {
    allocator: std.mem.Allocator,
    name: []const u8,

    // Local storage for simulation
    items: std.StringHashMapUnmanaged([]const u8),

    pub fn init(allocator: std.mem.Allocator, name: []const u8) !*ConfigStore {
        const store = try allocator.create(ConfigStore);
        store.* = .{
            .allocator = allocator,
            .name = try allocator.dupe(u8, name),
            .items = .{},
        };
        return store;
    }

    pub fn deinit(self: *ConfigStore) void {
        var it = self.items.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.items.deinit(self.allocator);
        self.allocator.free(self.name);
        self.allocator.destroy(self);
    }

    /// Get config value
    pub fn get(self: *ConfigStore, key: []const u8) ?[]const u8 {
        return self.items.get(key);
    }

    /// Set config value (for simulation)
    pub fn set(self: *ConfigStore, key: []const u8, value: []const u8) !void {
        if (self.items.fetchRemove(key)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }

        const key_copy = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(key_copy);
        const value_copy = try self.allocator.dupe(u8, value);

        try self.items.put(self.allocator, key_copy, value_copy);
    }
};

/// Fastly KV Store
pub const KVStore = struct {
    allocator: std.mem.Allocator,
    name: []const u8,

    // Local storage for simulation
    storage: std.StringHashMapUnmanaged(KVEntry),

    const KVEntry = struct {
        value: []const u8,
        metadata: ?[]const u8,
        generation: u64,
    };

    pub fn init(allocator: std.mem.Allocator, name: []const u8) !*KVStore {
        const store = try allocator.create(KVStore);
        store.* = .{
            .allocator = allocator,
            .name = try allocator.dupe(u8, name),
            .storage = .{},
        };
        return store;
    }

    pub fn deinit(self: *KVStore) void {
        var it = self.storage.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.value);
            if (entry.value_ptr.metadata) |m| self.allocator.free(m);
        }
        self.storage.deinit(self.allocator);
        self.allocator.free(self.name);
        self.allocator.destroy(self);
    }

    /// Lookup key
    pub fn lookup(self: *KVStore, key: []const u8) !?LookupResult {
        if (self.storage.get(key)) |entry| {
            return .{
                .value = entry.value,
                .metadata = entry.metadata,
                .generation = entry.generation,
            };
        }
        return null;
    }

    /// Insert key-value
    pub fn insert(self: *KVStore, key: []const u8, value: []const u8, options: ?InsertOptions) !void {
        if (self.storage.fetchRemove(key)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value.value);
            if (old.value.metadata) |m| self.allocator.free(m);
        }

        const key_copy = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(key_copy);
        const value_copy = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(value_copy);

        var metadata: ?[]const u8 = null;
        if (options) |opts| {
            if (opts.metadata) |m| {
                metadata = try self.allocator.dupe(u8, m);
            }
        }

        try self.storage.put(self.allocator, key_copy, .{
            .value = value_copy,
            .metadata = metadata,
            .generation = @as(u64, @intCast(std.time.milliTimestamp())),
        });
    }

    /// Delete key
    pub fn delete(self: *KVStore, key: []const u8) !void {
        if (self.storage.fetchRemove(key)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value.value);
            if (old.value.metadata) |m| self.allocator.free(m);
        }
    }

    pub const LookupResult = struct {
        value: []const u8,
        metadata: ?[]const u8,
        generation: u64,
    };

    pub const InsertOptions = struct {
        metadata: ?[]const u8 = null,
        mode: InsertMode = .overwrite,

        pub const InsertMode = enum {
            overwrite,
            add, // Only insert if not exists
            append,
            prepend,
        };
    };
};

/// Fastly Secret Store
pub const SecretStore = struct {
    allocator: std.mem.Allocator,
    name: []const u8,

    // Local storage for simulation (in production, secrets are encrypted)
    secrets: std.StringHashMapUnmanaged([]const u8),

    pub fn init(allocator: std.mem.Allocator, name: []const u8) !*SecretStore {
        const store = try allocator.create(SecretStore);
        store.* = .{
            .allocator = allocator,
            .name = try allocator.dupe(u8, name),
            .secrets = .{},
        };
        return store;
    }

    pub fn deinit(self: *SecretStore) void {
        var it = self.secrets.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            // Zero out secret before freeing
            @memset(@constCast(entry.value_ptr.*), 0);
            self.allocator.free(entry.value_ptr.*);
        }
        self.secrets.deinit(self.allocator);
        self.allocator.free(self.name);
        self.allocator.destroy(self);
    }

    /// Get secret
    pub fn get(self: *SecretStore, name: []const u8) ?Secret {
        if (self.secrets.get(name)) |value| {
            return .{ .plaintext = value };
        }
        return null;
    }

    /// Set secret (for simulation)
    pub fn set(self: *SecretStore, name: []const u8, value: []const u8) !void {
        if (self.secrets.fetchRemove(name)) |old| {
            self.allocator.free(old.key);
            @memset(@constCast(old.value), 0);
            self.allocator.free(old.value);
        }

        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);
        const value_copy = try self.allocator.dupe(u8, value);

        try self.secrets.put(self.allocator, name_copy, value_copy);
    }

    pub const Secret = struct {
        plaintext: []const u8,
    };
};

/// Edge Dictionary (legacy, read-only)
pub const EdgeDictionary = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    items: std.StringHashMapUnmanaged([]const u8),

    pub fn init(allocator: std.mem.Allocator, name: []const u8) !*EdgeDictionary {
        const dict = try allocator.create(EdgeDictionary);
        dict.* = .{
            .allocator = allocator,
            .name = try allocator.dupe(u8, name),
            .items = .{},
        };
        return dict;
    }

    pub fn deinit(self: *EdgeDictionary) void {
        var it = self.items.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.items.deinit(self.allocator);
        self.allocator.free(self.name);
        self.allocator.destroy(self);
    }

    /// Get dictionary value
    pub fn get(self: *EdgeDictionary, key: []const u8) ?[]const u8 {
        return self.items.get(key);
    }

    /// Set value (for simulation)
    pub fn set(self: *EdgeDictionary, key: []const u8, value: []const u8) !void {
        if (self.items.fetchRemove(key)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }

        const key_copy = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(key_copy);
        const value_copy = try self.allocator.dupe(u8, value);

        try self.items.put(self.allocator, key_copy, value_copy);
    }
};

/// Fastly geolocation info
pub const FastlyGeo = struct {
    /// Get geolocation from request
    pub fn fromRequest(request: *EdgeRequest) GeoInfo {
        // In production, this would use Fastly's geo database
        _ = request;
        return .{
            .country = "US",
            .region = "CA",
            .city = "San Francisco",
            .latitude = 37.7749,
            .longitude = -122.4194,
            .timezone = "America/Los_Angeles",
        };
    }
};

/// Fastly Compute@Edge adapter
pub const FastlyAdapter = struct {
    allocator: std.mem.Allocator,
    config: EdgeConfig,
    fastly_config: FastlyConfig,
    config_store: ?*ConfigStore,
    kv_store: ?*KVStore,
    secret_store: ?*SecretStore,
    edge_dict: ?*EdgeDictionary,
    app: ?*server.Zylix,

    pub fn init(allocator: std.mem.Allocator) FastlyAdapter {
        return .{
            .allocator = allocator,
            .config = .{ .platform = .fastly },
            .fastly_config = .{},
            .config_store = null,
            .kv_store = null,
            .secret_store = null,
            .edge_dict = null,
            .app = null,
        };
    }

    pub fn deinit(self: *FastlyAdapter) void {
        if (self.config_store) |cs| cs.deinit();
        if (self.kv_store) |kv| kv.deinit();
        if (self.secret_store) |ss| ss.deinit();
        if (self.edge_dict) |ed| ed.deinit();
    }

    /// Set the Zylix application
    pub fn setApp(self: *FastlyAdapter, app: *server.Zylix) *FastlyAdapter {
        self.app = app;
        return self;
    }

    /// Set service ID
    pub fn withServiceId(self: *FastlyAdapter, service_id: []const u8) *FastlyAdapter {
        self.fastly_config.service_id = service_id;
        return self;
    }

    /// Set backend
    pub fn withBackend(self: *FastlyAdapter, backend: []const u8) *FastlyAdapter {
        self.fastly_config.backend = backend;
        return self;
    }

    /// Configure Config Store
    pub fn withConfigStore(self: *FastlyAdapter, name: []const u8) !*FastlyAdapter {
        self.config_store = try ConfigStore.init(self.allocator, name);
        return self;
    }

    /// Configure KV Store
    pub fn withKVStore(self: *FastlyAdapter, name: []const u8) !*FastlyAdapter {
        self.kv_store = try KVStore.init(self.allocator, name);
        return self;
    }

    /// Configure Secret Store
    pub fn withSecretStore(self: *FastlyAdapter, name: []const u8) !*FastlyAdapter {
        self.secret_store = try SecretStore.init(self.allocator, name);
        return self;
    }

    /// Configure Edge Dictionary
    pub fn withEdgeDictionary(self: *FastlyAdapter, name: []const u8) !*FastlyAdapter {
        self.edge_dict = try EdgeDictionary.init(self.allocator, name);
        return self;
    }

    /// Enable request collapsing
    pub fn withRequestCollapsing(self: *FastlyAdapter) *FastlyAdapter {
        self.fastly_config.request_collapsing = true;
        return self;
    }

    /// Set cache TTL
    pub fn withCacheTTL(self: *FastlyAdapter, ttl: u32) *FastlyAdapter {
        self.fastly_config.cache_ttl = ttl;
        return self;
    }

    /// Handle incoming request
    pub fn handle(self: *FastlyAdapter, request: *EdgeRequest) !EdgeResponse {
        // Add geolocation info
        request.geo = FastlyGeo.fromRequest(request);

        if (self.app) |app| {
            var server_req = try request.toServerRequest();
            defer server_req.deinit();

            try server_req.set("__fastly_adapter", @ptrCast(self));

            var server_res = try app.handleRequest(&server_req);
            defer server_res.deinit();

            var edge_res = try EdgeResponse.fromServerResponse(self.allocator, &server_res);

            // Add cache headers
            if (self.fastly_config.cache_ttl > 0) {
                var buf: [64]u8 = undefined;
                const value = try std.fmt.bufPrint(&buf, "public, max-age={d}", .{self.fastly_config.cache_ttl});
                _ = try edge_res.setHeader("cache-control", value);
            }

            return edge_res;
        }

        var res = EdgeResponse.init(self.allocator);
        _ = res.setStatus(500);
        _ = res.setBody("No application configured");
        return res;
    }

    /// Send request to backend
    pub fn fetch(self: *FastlyAdapter, backend: []const u8, request: *EdgeRequest) !EdgeResponse {
        _ = self;
        _ = backend;

        // In production, this would make an actual request to the backend
        var res = EdgeResponse.init(request.allocator);
        _ = res.setStatus(200);
        _ = res.setBody("Backend response (simulated)");
        return res;
    }
};

/// Create Fastly middleware for Zylix server
pub fn adapter() server.MiddlewareFn {
    return struct {
        fn middleware(ctx: *server.Context, next: server.Next) anyerror!void {
            _ = try ctx.response.setHeader("x-fastly-pop", "simulated");
            try next.call();
        }
    }.middleware;
}

// ============================================================================
// Unit Tests
// ============================================================================

test "ConfigStore basic operations" {
    const allocator = std.testing.allocator;

    var store = try ConfigStore.init(allocator, "config");
    defer store.deinit();

    try store.set("key1", "value1");
    const value = store.get("key1");
    try std.testing.expect(value != null);
    try std.testing.expectEqualStrings("value1", value.?);
}

test "KVStore basic operations" {
    const allocator = std.testing.allocator;

    var store = try KVStore.init(allocator, "data");
    defer store.deinit();

    try store.insert("key1", "value1", null);
    const result = try store.lookup("key1");
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("value1", result.?.value);

    try store.delete("key1");
    const deleted = try store.lookup("key1");
    try std.testing.expect(deleted == null);
}

test "SecretStore basic operations" {
    const allocator = std.testing.allocator;

    var store = try SecretStore.init(allocator, "secrets");
    defer store.deinit();

    try store.set("api_key", "secret123");
    const secret = store.get("api_key");
    try std.testing.expect(secret != null);
    try std.testing.expectEqualStrings("secret123", secret.?.plaintext);
}

test "FastlyAdapter init and deinit" {
    const allocator = std.testing.allocator;

    var adapter_instance = FastlyAdapter.init(allocator);
    defer adapter_instance.deinit();

    _ = adapter_instance.withServiceId("svc-123").withBackend("origin");
    _ = adapter_instance.withRequestCollapsing().withCacheTTL(7200);

    try std.testing.expectEqual(Platform.fastly, adapter_instance.config.platform);
    try std.testing.expect(adapter_instance.fastly_config.request_collapsing);
    try std.testing.expectEqual(@as(u32, 7200), adapter_instance.fastly_config.cache_ttl);
}
