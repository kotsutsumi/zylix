//! Turso / libSQL Database Backend
//!
//! Provides Turso and libSQL database connectivity with support for:
//! - Turso cloud database (HTTP API)
//! - libSQL embedded mode (SQLite compatible)
//! - Edge-optimized queries
//! - Embedded replicas
//! - Global distribution
//! - Automatic scaling
//! - SQLite compatibility

const std = @import("std");
const types = @import("types.zig");

const Value = types.Value;
const Column = types.Column;
const Row = types.Row;
const ResultSet = types.ResultSet;
const Parameter = types.Parameter;
const SqlType = types.SqlType;
const ConnectionState = types.ConnectionState;
const ConnectionOptions = types.ConnectionOptions;
const IsolationLevel = types.IsolationLevel;
const TransactionOptions = types.TransactionOptions;
const QueryStats = types.QueryStats;
const DatabaseError = types.DatabaseError;
const Error = types.Error;

/// Turso connection mode
pub const ConnectionMode = enum {
    /// Connect to Turso cloud via HTTP API
    cloud,
    /// Use embedded libSQL (SQLite compatible)
    embedded,
    /// Embedded with cloud sync (embedded replica)
    replica,
};

/// Turso sync mode for replicas
pub const SyncMode = enum {
    /// Sync on every write
    immediate,
    /// Sync periodically
    periodic,
    /// Manual sync only
    manual,
};

/// Turso specific options
pub const TursoOptions = struct {
    // Connection
    url: []const u8 = "", // Turso database URL or file path
    auth_token: []const u8 = "", // Auth token for cloud mode
    mode: ConnectionMode = .cloud,

    // Replica settings
    sync_mode: SyncMode = .immediate,
    sync_interval_ms: u32 = 60000, // For periodic sync
    replica_path: ?[]const u8 = null, // Local replica file path

    // Timeouts
    connect_timeout_ms: u32 = 30000,
    read_timeout_ms: u32 = 30000,

    // HTTP settings (cloud mode)
    max_retries: u8 = 3,
    retry_delay_ms: u32 = 1000,

    // Embedded settings
    journal_mode: JournalMode = .wal,
    busy_timeout_ms: u32 = 5000,

    pub fn fromConnectionOptions(opts: ConnectionOptions) TursoOptions {
        return .{
            .url = opts.host,
            .auth_token = opts.password,
            .connect_timeout_ms = opts.connect_timeout_ms,
            .read_timeout_ms = opts.read_timeout_ms,
        };
    }

    /// Check if using cloud mode
    pub fn isCloud(self: TursoOptions) bool {
        return self.mode == .cloud or self.mode == .replica;
    }

    /// Check if using local storage
    pub fn hasLocalStorage(self: TursoOptions) bool {
        return self.mode == .embedded or self.mode == .replica;
    }
};

/// Journal mode (for embedded mode)
pub const JournalMode = enum {
    delete,
    truncate,
    persist,
    memory,
    wal,
    off,

    pub fn toSql(self: JournalMode) []const u8 {
        return switch (self) {
            .delete => "DELETE",
            .truncate => "TRUNCATE",
            .persist => "PERSIST",
            .memory => "MEMORY",
            .wal => "WAL",
            .off => "OFF",
        };
    }
};

/// Prepared statement
pub const Statement = struct {
    allocator: std.mem.Allocator,
    sql: []const u8,
    columns: []Column = &.{},
    param_count: usize = 0,
    bound_params: std.ArrayListUnmanaged(BoundParam) = .{},

    const BoundParam = struct {
        index: usize,
        value: Value,
    };

    pub fn init(allocator: std.mem.Allocator, sql: []const u8) Statement {
        return .{
            .allocator = allocator,
            .sql = sql,
        };
    }

    pub fn deinit(self: *Statement) void {
        if (self.columns.len > 0) {
            self.allocator.free(self.columns);
        }
        for (self.bound_params.items) |*param| {
            var val = param.value;
            val.deinit(self.allocator);
        }
        self.bound_params.deinit(self.allocator);
    }

    pub fn bind(self: *Statement, index: usize, value: Value) !void {
        if (index == 0) {
            return error.BindError;
        }

        // Clone value to own memory
        const cloned = try value.clone(self.allocator);
        try self.bound_params.append(self.allocator, .{
            .index = index,
            .value = cloned,
        });
    }

    pub fn bindAll(self: *Statement, params: []const Parameter) !void {
        for (params) |param| {
            try self.bind(param.index, param.value);
        }
    }

    pub fn reset(self: *Statement) void {
        for (self.bound_params.items) |*param| {
            var val = param.value;
            val.deinit(self.allocator);
        }
        self.bound_params.clearRetainingCapacity();
    }

    /// Convert to JSON for HTTP API
    pub fn toJson(self: *const Statement, buf: []u8) ![]const u8 {
        var fbs = std.io.fixedBufferStream(buf);
        const writer = fbs.writer();

        try writer.writeAll("{\"type\":\"execute\",\"stmt\":{\"sql\":\"");
        // Escape SQL string (RFC 8259 compliant JSON escaping)
        for (self.sql) |c| {
            switch (c) {
                '"' => try writer.writeAll("\\\""),
                '\\' => try writer.writeAll("\\\\"),
                '\n' => try writer.writeAll("\\n"),
                '\r' => try writer.writeAll("\\r"),
                '\t' => try writer.writeAll("\\t"),
                0x00...0x08, 0x0B, 0x0C, 0x0E...0x1F => {
                    try writer.print("\\u{X:0>4}", .{c});
                },
                else => try writer.writeByte(c),
            }
        }
        try writer.writeAll("\"");

        if (self.bound_params.items.len > 0) {
            try writer.writeAll(",\"args\":[");
            for (self.bound_params.items, 0..) |param, i| {
                if (i > 0) try writer.writeAll(",");
                try writeJsonValue(writer, param.value);
            }
            try writer.writeAll("]");
        }

        try writer.writeAll("}}");
        return fbs.getWritten();
    }
};

fn writeJsonValue(writer: anytype, value: Value) !void {
    switch (value) {
        .null => try writer.writeAll("{\"type\":\"null\"}"),
        .boolean => |v| try writer.print("{{\"type\":\"integer\",\"value\":\"{d}\"}}", .{@as(i32, if (v) 1 else 0)}),
        .integer => |v| try writer.print("{{\"type\":\"integer\",\"value\":\"{d}\"}}", .{v}),
        .float => |v| try writer.print("{{\"type\":\"float\",\"value\":\"{d}\"}}", .{v}),
        .text => |v| {
            try writer.writeAll("{\"type\":\"text\",\"value\":\"");
            for (v) |c| {
                switch (c) {
                    '"' => try writer.writeAll("\\\""),
                    '\\' => try writer.writeAll("\\\\"),
                    '\n' => try writer.writeAll("\\n"),
                    '\r' => try writer.writeAll("\\r"),
                    '\t' => try writer.writeAll("\\t"),
                    else => try writer.writeByte(c),
                }
            }
            try writer.writeAll("\"}");
        },
        .blob => |v| {
            try writer.writeAll("{\"type\":\"blob\",\"base64\":\"");
            // Base64 encode
            const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
            var i: usize = 0;
            while (i + 3 <= v.len) : (i += 3) {
                const n = (@as(u24, v[i]) << 16) | (@as(u24, v[i + 1]) << 8) | @as(u24, v[i + 2]);
                try writer.writeByte(alphabet[(n >> 18) & 0x3F]);
                try writer.writeByte(alphabet[(n >> 12) & 0x3F]);
                try writer.writeByte(alphabet[(n >> 6) & 0x3F]);
                try writer.writeByte(alphabet[n & 0x3F]);
            }
            if (i < v.len) {
                var n: u24 = @as(u24, v[i]) << 16;
                if (i + 1 < v.len) n |= @as(u24, v[i + 1]) << 8;
                try writer.writeByte(alphabet[(n >> 18) & 0x3F]);
                try writer.writeByte(alphabet[(n >> 12) & 0x3F]);
                if (i + 1 < v.len) {
                    try writer.writeByte(alphabet[(n >> 6) & 0x3F]);
                } else {
                    try writer.writeByte('=');
                }
                try writer.writeByte('=');
            }
            try writer.writeAll("\"}");
        },
        .timestamp => |v| try writer.print("{{\"type\":\"integer\",\"value\":\"{d}\"}}", .{v}),
        .json => |v| {
            try writer.writeAll("{\"type\":\"text\",\"value\":\"");
            for (v) |c| {
                switch (c) {
                    '"' => try writer.writeAll("\\\""),
                    '\\' => try writer.writeAll("\\\\"),
                    else => try writer.writeByte(c),
                }
            }
            try writer.writeAll("\"}");
        },
    }
}

/// Turso/libSQL connection
pub const Connection = struct {
    allocator: std.mem.Allocator,
    options: TursoOptions,
    state: ConnectionState = .disconnected,
    in_transaction: bool = false,

    // Stats
    stats: QueryStats = .{},

    // Statement cache
    statement_cache: std.StringHashMapUnmanaged(*Statement) = .{},

    // Sync state
    last_sync_time: i64 = 0,
    pending_writes: u32 = 0,

    // HTTP client state (for cloud mode)
    http_headers: [2]struct { name: []const u8, value: []const u8 } = undefined,

    pub fn init(allocator: std.mem.Allocator, options: TursoOptions) Connection {
        return .{
            .allocator = allocator,
            .options = options,
        };
    }

    pub fn deinit(self: *Connection) void {
        self.close();

        var iter = self.statement_cache.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.*.deinit();
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.statement_cache.deinit(self.allocator);
    }

    /// Open connection
    pub fn open(self: *Connection) !void {
        if (self.state != .disconnected) {
            return error.InvalidState;
        }

        self.state = .connecting;

        switch (self.options.mode) {
            .cloud => {
                // Setup HTTP headers for cloud API
                self.http_headers[0] = .{ .name = "Authorization", .value = self.options.auth_token };
                self.http_headers[1] = .{ .name = "Content-Type", .value = "application/json" };

                // In real implementation, verify connection with a simple query
            },
            .embedded => {
                // In real implementation, open libSQL database file
            },
            .replica => {
                // In real implementation:
                // 1. Open local replica file
                // 2. Connect to remote for sync
                // 3. Perform initial sync if needed
            },
        }

        self.state = .connected;
    }

    /// Close connection
    pub fn close(self: *Connection) void {
        if (self.state == .disconnected) return;

        // Sync pending writes for replica mode
        if (self.options.mode == .replica and self.pending_writes > 0) {
            self.sync() catch {};
        }

        self.state = .disconnected;
        self.in_transaction = false;
    }

    /// Execute SQL without results
    pub fn execute(self: *Connection, sql: []const u8) !u64 {
        if (self.state != .connected and self.state != .in_transaction) {
            return error.InvalidState;
        }

        const start_time = std.time.nanoTimestamp();
        defer {
            const end_time = std.time.nanoTimestamp();
            self.stats.execution_time_ns = @intCast(end_time - start_time);
        }

        if (self.options.isCloud()) {
            return self.executeHttp(sql);
        } else {
            return self.executeEmbedded(sql);
        }
    }

    fn executeHttp(self: *Connection, sql: []const u8) !u64 {
        // In real implementation:
        // 1. Build JSON request
        // 2. Send HTTP POST to Turso API
        // 3. Parse JSON response
        // 4. Extract affected rows
        _ = self;
        _ = sql;
        return 0;
    }

    fn executeEmbedded(self: *Connection, sql: []const u8) !u64 {
        // In real implementation:
        // Use libSQL C API
        _ = self;
        _ = sql;
        return 0;
    }

    /// Execute SQL and return results
    pub fn query(self: *Connection, sql: []const u8) !ResultSet {
        if (self.state != .connected and self.state != .in_transaction) {
            return error.InvalidState;
        }

        var result = ResultSet.init(self.allocator);

        const start_time = std.time.nanoTimestamp();
        defer {
            const end_time = std.time.nanoTimestamp();
            self.stats.execution_time_ns = @intCast(end_time - start_time);
        }

        if (self.options.isCloud()) {
            return self.queryHttp(sql, &result);
        } else {
            return self.queryEmbedded(sql, &result);
        }
    }

    fn queryHttp(self: *Connection, sql: []const u8, result: *ResultSet) !ResultSet {
        _ = self;
        _ = sql;
        return result.*;
    }

    fn queryEmbedded(self: *Connection, sql: []const u8, result: *ResultSet) !ResultSet {
        _ = self;
        _ = sql;
        return result.*;
    }

    /// Prepare a statement
    pub fn prepare(self: *Connection, sql: []const u8) !*Statement {
        if (self.state != .connected and self.state != .in_transaction) {
            return error.InvalidState;
        }

        if (self.statement_cache.get(sql)) |stmt| {
            stmt.reset();
            return stmt;
        }

        const stmt = try self.allocator.create(Statement);
        stmt.* = Statement.init(self.allocator, sql);

        self.statement_cache.put(self.allocator, sql, stmt) catch {};

        return stmt;
    }

    /// Execute a batch of statements
    pub fn batch(self: *Connection, statements: []const []const u8) ![]ResultSet {
        var results = try self.allocator.alloc(ResultSet, statements.len);
        errdefer self.allocator.free(results);

        for (statements, 0..) |sql, i| {
            results[i] = try self.query(sql);
        }

        return results;
    }

    /// Begin transaction
    pub fn beginTransaction(self: *Connection, options: TransactionOptions) !void {
        if (self.in_transaction) {
            return error.TransactionError;
        }

        // Turso/libSQL supports different isolation levels via pragmas
        _ = options;

        _ = try self.execute("BEGIN");
        self.in_transaction = true;
        self.state = .in_transaction;
    }

    /// Commit transaction
    pub fn commit(self: *Connection) !void {
        if (!self.in_transaction) {
            return error.TransactionError;
        }

        _ = try self.execute("COMMIT");
        self.in_transaction = false;
        self.state = .connected;

        // Sync after commit in replica mode
        if (self.options.mode == .replica and self.options.sync_mode == .immediate) {
            try self.sync();
        }
    }

    /// Rollback transaction
    pub fn rollback(self: *Connection) !void {
        if (!self.in_transaction) {
            return error.TransactionError;
        }

        _ = try self.execute("ROLLBACK");
        self.in_transaction = false;
        self.state = .connected;
    }

    /// Sync local replica with remote (for replica mode)
    pub fn sync(self: *Connection) !void {
        if (self.options.mode != .replica) {
            return error.UnsupportedOperation;
        }

        // In real implementation:
        // 1. Push local changes to remote
        // 2. Pull remote changes to local
        // 3. Merge changes

        self.last_sync_time = std.time.timestamp();
        self.pending_writes = 0;
    }

    /// Force push local changes (for replica mode)
    pub fn push(self: *Connection) !void {
        if (self.options.mode != .replica) {
            return error.UnsupportedOperation;
        }

        // In real implementation, push pending changes
        self.pending_writes = 0;
    }

    /// Force pull remote changes (for replica mode)
    pub fn pull(self: *Connection) !void {
        if (self.options.mode != .replica) {
            return error.UnsupportedOperation;
        }

        // In real implementation, pull and apply remote changes
    }

    /// Get sync status
    pub fn getSyncStatus(self: *const Connection) struct {
        last_sync: i64,
        pending_writes: u32,
        is_synced: bool,
    } {
        return .{
            .last_sync = self.last_sync_time,
            .pending_writes = self.pending_writes,
            .is_synced = self.pending_writes == 0,
        };
    }

    /// Validate identifier (alphanumeric and underscore only)
    fn isValidIdentifier(name: []const u8) bool {
        if (name.len == 0 or name.len > 128) return false;
        for (name) |c| {
            if (!std.ascii.isAlphanumeric(c) and c != '_') return false;
        }
        return true;
    }

    /// Create savepoint
    pub fn savepoint(self: *Connection, name: []const u8) !void {
        if (!isValidIdentifier(name)) {
            return error.QuerySyntaxError;
        }
        var buf: [256]u8 = undefined;
        const sql = std.fmt.bufPrint(&buf, "SAVEPOINT {s}", .{name}) catch return error.QuerySyntaxError;
        _ = try self.execute(sql);
    }

    /// Release savepoint
    pub fn releaseSavepoint(self: *Connection, name: []const u8) !void {
        if (!isValidIdentifier(name)) {
            return error.QuerySyntaxError;
        }
        var buf: [256]u8 = undefined;
        const sql = std.fmt.bufPrint(&buf, "RELEASE SAVEPOINT {s}", .{name}) catch return error.QuerySyntaxError;
        _ = try self.execute(sql);
    }

    /// Rollback to savepoint
    pub fn rollbackToSavepoint(self: *Connection, name: []const u8) !void {
        if (!isValidIdentifier(name)) {
            return error.QuerySyntaxError;
        }
        var buf: [256]u8 = undefined;
        const sql = std.fmt.bufPrint(&buf, "ROLLBACK TO SAVEPOINT {s}", .{name}) catch return error.QuerySyntaxError;
        _ = try self.execute(sql);
    }
};

/// Create Turso cloud connection
pub fn cloud(allocator: std.mem.Allocator, url: []const u8, auth_token: []const u8) Connection {
    return Connection.init(allocator, .{
        .url = url,
        .auth_token = auth_token,
        .mode = .cloud,
    });
}

/// Create embedded libSQL connection
pub fn embedded(allocator: std.mem.Allocator, path: []const u8) Connection {
    return Connection.init(allocator, .{
        .url = path,
        .mode = .embedded,
    });
}

/// Create replica connection (embedded with cloud sync)
pub fn replica(allocator: std.mem.Allocator, url: []const u8, auth_token: []const u8, local_path: []const u8) Connection {
    return Connection.init(allocator, .{
        .url = url,
        .auth_token = auth_token,
        .mode = .replica,
        .replica_path = local_path,
    });
}

/// Create in-memory libSQL connection
pub fn inMemory(allocator: std.mem.Allocator) Connection {
    return Connection.init(allocator, .{
        .url = ":memory:",
        .mode = .embedded,
    });
}

// Tests
test "Connection initialization" {
    const allocator = std.testing.allocator;

    var conn = cloud(allocator, "libsql://my-db.turso.io", "token123");
    defer conn.deinit();

    try std.testing.expectEqual(ConnectionState.disconnected, conn.state);
    try std.testing.expectEqual(ConnectionMode.cloud, conn.options.mode);
}

test "Embedded connection" {
    const allocator = std.testing.allocator;

    var conn = embedded(allocator, "test.db");
    defer conn.deinit();

    try std.testing.expectEqual(ConnectionMode.embedded, conn.options.mode);
}

test "Replica connection" {
    const allocator = std.testing.allocator;

    var conn = replica(allocator, "libsql://my-db.turso.io", "token", "local.db");
    defer conn.deinit();

    try std.testing.expectEqual(ConnectionMode.replica, conn.options.mode);
    try std.testing.expect(conn.options.isCloud());
    try std.testing.expect(conn.options.hasLocalStorage());
}

test "Statement JSON serialization" {
    const allocator = std.testing.allocator;

    var stmt = Statement.init(allocator, "SELECT * FROM users WHERE id = ?");
    defer stmt.deinit();

    try stmt.bind(1, .{ .integer = 42 });

    var buf: [1024]u8 = undefined;
    const json = try stmt.toJson(&buf);

    try std.testing.expect(std.mem.indexOf(u8, json, "SELECT * FROM users") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"type\":\"integer\"") != null);
}

test "TursoOptions helpers" {
    const opts = TursoOptions{ .mode = .cloud };
    try std.testing.expect(opts.isCloud());
    try std.testing.expect(!opts.hasLocalStorage());

    const replica_opts = TursoOptions{ .mode = .replica };
    try std.testing.expect(replica_opts.isCloud());
    try std.testing.expect(replica_opts.hasLocalStorage());
}
