//! Key-Value Store Module
//!
//! Persistent key-value storage with support for:
//! - Type-safe accessors (bool, int, float, string)
//! - Default value support
//! - Async batch operations
//!
//! Platform implementations:
//! - iOS: UserDefaults
//! - Android: SharedPreferences
//! - Web: localStorage
//! - Desktop: File-based (JSON/SQLite)

const std = @import("std");

/// KeyValueStore error types
pub const KvError = error{
    NotInitialized,
    KeyNotFound,
    TypeMismatch,
    StorageFull,
    IoError,
    SerializationError,
    EncryptionError,
    OutOfMemory,
};

/// Value type enum
pub const ValueType = enum(u8) {
    null = 0,
    boolean = 1,
    integer = 2,
    float = 3,
    string = 4,
    binary = 5,
    json = 6,
};

/// Stored value union
pub const StoredValue = union(ValueType) {
    null: void,
    boolean: bool,
    integer: i64,
    float: f64,
    string: []const u8,
    binary: []const u8,
    json: []const u8,

    pub fn getType(self: StoredValue) ValueType {
        return std.meta.activeTag(self);
    }
};

/// Storage configuration
pub const KvConfig = struct {
    /// Storage file path (for file-based backends)
    file_path: ?[]const u8 = null,
    /// Enable encryption for sensitive data
    encryption_enabled: bool = false,
    /// Encryption key (required if encryption_enabled)
    encryption_key: ?[]const u8 = null,
    /// Enable automatic persistence (vs manual flush)
    auto_persist: bool = true,
    /// Persistence interval in milliseconds (when auto_persist is true)
    persist_interval_ms: u32 = 1000,
    /// Maximum storage size in bytes (0 = unlimited)
    max_size: u64 = 0,
    /// Enable debug logging
    debug: bool = false,
};

/// Future result wrapper for async operations
pub fn Future(comptime T: type) type {
    return struct {
        const Self = @This();

        result: ?T = null,
        err: ?KvError = null,
        completed: bool = false,
        callback: ?*const fn (?T, ?KvError) void = null,

        pub fn init() Self {
            return .{};
        }

        pub fn complete(self: *Self, value: T) void {
            self.result = value;
            self.completed = true;
            if (self.callback) |cb| {
                cb(value, null);
            }
        }

        pub fn fail(self: *Self, err: KvError) void {
            self.err = err;
            self.completed = true;
            if (self.callback) |cb| {
                cb(null, err);
            }
        }

        pub fn isCompleted(self: *const Self) bool {
            return self.completed;
        }

        pub fn get(self: *const Self) KvError!T {
            if (self.err) |e| return e;
            if (self.result) |r| return r;
            return KvError.NotInitialized;
        }

        pub fn onComplete(self: *Self, callback: *const fn (?T, ?KvError) void) void {
            self.callback = callback;
            if (self.completed) {
                callback(self.result, self.err);
            }
        }
    };
}

/// Key-Value Store
pub const KeyValueStore = struct {
    allocator: std.mem.Allocator,
    config: KvConfig,
    initialized: bool = false,
    data: std.StringHashMapUnmanaged(StoredValue) = .{},
    dirty: bool = false,

    // Owned strings for storage
    owned_strings: std.ArrayListUnmanaged([]const u8) = .{},

    // Platform-specific handle
    platform_handle: ?*anyopaque = null,

    pub fn init(allocator: std.mem.Allocator, config: KvConfig) KeyValueStore {
        return .{
            .allocator = allocator,
            .config = config,
        };
    }

    pub fn deinit(self: *KeyValueStore) void {
        // Free owned strings
        for (self.owned_strings.items) |s| {
            self.allocator.free(s);
        }
        self.owned_strings.deinit(self.allocator);
        self.data.deinit(self.allocator);
        self.initialized = false;
    }

    /// Initialize and load stored data
    pub fn open(self: *KeyValueStore) *Future(void) {
        const future = self.allocator.create(Future(void)) catch {
            const err_future = self.allocator.create(Future(void)) catch unreachable;
            err_future.* = Future(void).init();
            err_future.fail(KvError.OutOfMemory);
            return err_future;
        };
        future.* = Future(void).init();

        // Platform-specific load would happen here
        self.initialized = true;
        future.complete({});

        return future;
    }

    /// Close and persist data
    pub fn close(self: *KeyValueStore) void {
        if (self.dirty) {
            _ = self.flush();
        }
        self.initialized = false;
    }

    /// Flush changes to persistent storage
    pub fn flush(self: *KeyValueStore) *Future(void) {
        const future = self.allocator.create(Future(void)) catch {
            const err_future = self.allocator.create(Future(void)) catch unreachable;
            err_future.* = Future(void).init();
            err_future.fail(KvError.OutOfMemory);
            return err_future;
        };
        future.* = Future(void).init();

        if (!self.initialized) {
            future.fail(KvError.NotInitialized);
            return future;
        }

        // Platform-specific persist would happen here
        self.dirty = false;
        future.complete({});

        return future;
    }

    /// Get a boolean value
    pub fn getBool(self: *const KeyValueStore, key: []const u8, default: bool) bool {
        if (self.data.get(key)) |value| {
            return switch (value) {
                .boolean => |v| v,
                .integer => |v| v != 0,
                else => default,
            };
        }
        return default;
    }

    /// Get an integer value
    pub fn getInt(self: *const KeyValueStore, key: []const u8, default: i64) i64 {
        if (self.data.get(key)) |value| {
            return switch (value) {
                .integer => |v| v,
                .boolean => |v| if (v) @as(i64, 1) else 0,
                .float => |v| @intFromFloat(v),
                else => default,
            };
        }
        return default;
    }

    /// Get a float value
    pub fn getFloat(self: *const KeyValueStore, key: []const u8, default: f32) f32 {
        if (self.data.get(key)) |value| {
            return switch (value) {
                .float => |v| @floatCast(v),
                .integer => |v| @floatFromInt(v),
                else => default,
            };
        }
        return default;
    }

    /// Get a double value
    pub fn getDouble(self: *const KeyValueStore, key: []const u8, default: f64) f64 {
        if (self.data.get(key)) |value| {
            return switch (value) {
                .float => |v| v,
                .integer => |v| @floatFromInt(v),
                else => default,
            };
        }
        return default;
    }

    /// Get a string value
    pub fn getString(self: *const KeyValueStore, key: []const u8, default: []const u8) []const u8 {
        if (self.data.get(key)) |value| {
            return switch (value) {
                .string => |v| v,
                .json => |v| v,
                else => default,
            };
        }
        return default;
    }

    /// Get binary data
    pub fn getBinary(self: *const KeyValueStore, key: []const u8) ?[]const u8 {
        if (self.data.get(key)) |value| {
            return switch (value) {
                .binary => |v| v,
                else => null,
            };
        }
        return null;
    }

    /// Check if a key exists
    pub fn contains(self: *const KeyValueStore, key: []const u8) bool {
        return self.data.contains(key);
    }

    /// Get the type of a stored value
    pub fn getValueType(self: *const KeyValueStore, key: []const u8) ?ValueType {
        if (self.data.get(key)) |value| {
            return value.getType();
        }
        return null;
    }

    /// Put a boolean value
    pub fn putBool(self: *KeyValueStore, key: []const u8, value: bool) void {
        self.data.put(self.allocator, key, .{ .boolean = value }) catch return;
        self.markDirty();
    }

    /// Put an integer value
    pub fn putInt(self: *KeyValueStore, key: []const u8, value: i64) void {
        self.data.put(self.allocator, key, .{ .integer = value }) catch return;
        self.markDirty();
    }

    /// Put a float value
    pub fn putFloat(self: *KeyValueStore, key: []const u8, value: f32) void {
        self.data.put(self.allocator, key, .{ .float = @floatCast(value) }) catch return;
        self.markDirty();
    }

    /// Put a double value
    pub fn putDouble(self: *KeyValueStore, key: []const u8, value: f64) void {
        self.data.put(self.allocator, key, .{ .float = value }) catch return;
        self.markDirty();
    }

    /// Free old owned string value for a key if exists
    fn freeOldValue(self: *KeyValueStore, key: []const u8) void {
        if (self.data.get(key)) |old_value| {
            const old_str: ?[]const u8 = switch (old_value) {
                .string => |s| s,
                .binary => |s| s,
                .json => |s| s,
                else => null,
            };
            if (old_str) |str| {
                // Find and remove from owned_strings
                for (self.owned_strings.items, 0..) |s, i| {
                    if (s.ptr == str.ptr and s.len == str.len) {
                        self.allocator.free(s);
                        _ = self.owned_strings.swapRemove(i);
                        break;
                    }
                }
            }
        }
    }

    /// Put a string value (copies the string)
    pub fn putString(self: *KeyValueStore, key: []const u8, value: []const u8) void {
        // Free old value if exists
        self.freeOldValue(key);

        const owned = self.allocator.dupe(u8, value) catch return;
        self.owned_strings.append(self.allocator, owned) catch {
            self.allocator.free(owned);
            return;
        };
        self.data.put(self.allocator, key, .{ .string = owned }) catch return;
        self.markDirty();
    }

    /// Put binary data (copies the data)
    pub fn putBinary(self: *KeyValueStore, key: []const u8, value: []const u8) void {
        // Free old value if exists
        self.freeOldValue(key);

        const owned = self.allocator.dupe(u8, value) catch return;
        self.owned_strings.append(self.allocator, owned) catch {
            self.allocator.free(owned);
            return;
        };
        self.data.put(self.allocator, key, .{ .binary = owned }) catch return;
        self.markDirty();
    }

    /// Remove a key
    pub fn remove(self: *KeyValueStore, key: []const u8) bool {
        // Free owned string if exists
        self.freeOldValue(key);

        if (self.data.remove(key)) {
            self.markDirty();
            return true;
        }
        return false;
    }

    /// Clear all data
    pub fn clear(self: *KeyValueStore) void {
        for (self.owned_strings.items) |s| {
            self.allocator.free(s);
        }
        self.owned_strings.clearRetainingCapacity();
        self.data.clearRetainingCapacity();
        self.markDirty();
    }

    /// Get all keys
    pub fn keys(self: *const KeyValueStore, allocator: std.mem.Allocator) ![]const []const u8 {
        var list = std.ArrayList([]const u8).init(allocator);
        errdefer list.deinit();

        var iter = self.data.keyIterator();
        while (iter.next()) |key| {
            try list.append(key.*);
        }

        return list.toOwnedSlice();
    }

    /// Get the number of stored items
    pub fn count(self: *const KeyValueStore) usize {
        return self.data.count();
    }

    fn markDirty(self: *KeyValueStore) void {
        self.dirty = true;
        if (self.config.auto_persist) {
            // In a real implementation, this would schedule a flush
        }
    }
};

/// Batch operation for efficient multiple writes
pub const BatchOperation = struct {
    store: *KeyValueStore,
    operations: std.ArrayListUnmanaged(Op) = .{},

    pub const Op = union(enum) {
        put_bool: struct { key: []const u8, value: bool },
        put_int: struct { key: []const u8, value: i64 },
        put_float: struct { key: []const u8, value: f64 },
        put_string: struct { key: []const u8, value: []const u8 },
        remove: []const u8,
    };

    pub fn init(store: *KeyValueStore) BatchOperation {
        return .{ .store = store };
    }

    pub fn deinit(self: *BatchOperation) void {
        self.operations.deinit(self.store.allocator);
    }

    pub fn putBool(self: *BatchOperation, key: []const u8, value: bool) !void {
        try self.operations.append(self.store.allocator, .{ .put_bool = .{ .key = key, .value = value } });
    }

    pub fn putInt(self: *BatchOperation, key: []const u8, value: i64) !void {
        try self.operations.append(self.store.allocator, .{ .put_int = .{ .key = key, .value = value } });
    }

    pub fn putFloat(self: *BatchOperation, key: []const u8, value: f64) !void {
        try self.operations.append(self.store.allocator, .{ .put_float = .{ .key = key, .value = value } });
    }

    pub fn putString(self: *BatchOperation, key: []const u8, value: []const u8) !void {
        try self.operations.append(self.store.allocator, .{ .put_string = .{ .key = key, .value = value } });
    }

    pub fn remove(self: *BatchOperation, key: []const u8) !void {
        try self.operations.append(self.store.allocator, .{ .remove = key });
    }

    pub fn apply(self: *BatchOperation) void {
        for (self.operations.items) |op| {
            switch (op) {
                .put_bool => |o| self.store.putBool(o.key, o.value),
                .put_int => |o| self.store.putInt(o.key, o.value),
                .put_float => |o| self.store.putFloat(o.key, o.value),
                .put_string => |o| self.store.putString(o.key, o.value),
                .remove => |key| _ = self.store.remove(key),
            }
        }
        self.operations.clearRetainingCapacity();
    }
};

/// Convenience function to create a store
pub fn createStore(allocator: std.mem.Allocator, config: KvConfig) KeyValueStore {
    return KeyValueStore.init(allocator, config);
}

/// Convenience function with default config
pub fn createDefaultStore(allocator: std.mem.Allocator) KeyValueStore {
    return KeyValueStore.init(allocator, .{});
}

// Tests
test "KeyValueStore initialization" {
    const allocator = std.testing.allocator;
    var store = createDefaultStore(allocator);
    defer store.deinit();

    const future = store.open();
    try std.testing.expect(future.isCompleted());
    try std.testing.expect(store.initialized);
}

test "Boolean storage" {
    const allocator = std.testing.allocator;
    var store = createDefaultStore(allocator);
    defer store.deinit();

    _ = store.open();

    store.putBool("enabled", true);
    try std.testing.expect(store.getBool("enabled", false));

    store.putBool("enabled", false);
    try std.testing.expect(!store.getBool("enabled", true));

    // Default value for non-existent key
    try std.testing.expect(!store.getBool("non_existent", false));
}

test "Integer storage" {
    const allocator = std.testing.allocator;
    var store = createDefaultStore(allocator);
    defer store.deinit();

    _ = store.open();

    store.putInt("score", 100);
    try std.testing.expectEqual(@as(i64, 100), store.getInt("score", 0));

    store.putInt("negative", -50);
    try std.testing.expectEqual(@as(i64, -50), store.getInt("negative", 0));

    // Default value
    try std.testing.expectEqual(@as(i64, 42), store.getInt("non_existent", 42));
}

test "Float storage" {
    const allocator = std.testing.allocator;
    var store = createDefaultStore(allocator);
    defer store.deinit();

    _ = store.open();

    store.putFloat("pi", 3.14);
    try std.testing.expectApproxEqAbs(@as(f32, 3.14), store.getFloat("pi", 0.0), 0.01);

    store.putDouble("e", 2.71828);
    try std.testing.expectApproxEqAbs(@as(f64, 2.71828), store.getDouble("e", 0.0), 0.00001);
}

test "String storage" {
    const allocator = std.testing.allocator;
    var store = createDefaultStore(allocator);
    defer store.deinit();

    _ = store.open();

    store.putString("name", "Alice");
    try std.testing.expect(std.mem.eql(u8, "Alice", store.getString("name", "")));

    // Default value
    try std.testing.expect(std.mem.eql(u8, "default", store.getString("non_existent", "default")));
}

test "Contains and remove" {
    const allocator = std.testing.allocator;
    var store = createDefaultStore(allocator);
    defer store.deinit();

    _ = store.open();

    store.putInt("key", 42);
    try std.testing.expect(store.contains("key"));
    try std.testing.expect(!store.contains("other"));

    try std.testing.expect(store.remove("key"));
    try std.testing.expect(!store.contains("key"));
    try std.testing.expect(!store.remove("key")); // Already removed
}

test "Clear and count" {
    const allocator = std.testing.allocator;
    var store = createDefaultStore(allocator);
    defer store.deinit();

    _ = store.open();

    store.putInt("a", 1);
    store.putInt("b", 2);
    store.putInt("c", 3);
    try std.testing.expectEqual(@as(usize, 3), store.count());

    store.clear();
    try std.testing.expectEqual(@as(usize, 0), store.count());
}

test "Value type detection" {
    const allocator = std.testing.allocator;
    var store = createDefaultStore(allocator);
    defer store.deinit();

    _ = store.open();

    store.putBool("b", true);
    store.putInt("i", 42);
    store.putFloat("f", 3.14);
    store.putString("s", "hello");

    try std.testing.expectEqual(ValueType.boolean, store.getValueType("b").?);
    try std.testing.expectEqual(ValueType.integer, store.getValueType("i").?);
    try std.testing.expectEqual(ValueType.float, store.getValueType("f").?);
    try std.testing.expectEqual(ValueType.string, store.getValueType("s").?);
    try std.testing.expect(store.getValueType("none") == null);
}

test "Batch operations" {
    const allocator = std.testing.allocator;
    var store = createDefaultStore(allocator);
    defer store.deinit();

    _ = store.open();

    var batch = BatchOperation.init(&store);
    defer batch.deinit();

    try batch.putBool("enabled", true);
    try batch.putInt("count", 10);
    try batch.putString("name", "Test");

    batch.apply();

    try std.testing.expect(store.getBool("enabled", false));
    try std.testing.expectEqual(@as(i64, 10), store.getInt("count", 0));
    try std.testing.expect(std.mem.eql(u8, "Test", store.getString("name", "")));
}
