//! Database Module
//!
//! Comprehensive database connectivity layer supporting multiple backends:
//! - SQLite: Embedded database with WAL, FTS5, JSON1
//! - MySQL: Full protocol implementation with prepared statements
//! - PostgreSQL: All data types, LISTEN/NOTIFY, COPY, JSON/JSONB
//! - Turso/libSQL: Cloud and embedded modes with edge optimization
//!
//! Features:
//! - Connection pooling with health checks
//! - Type-safe query builder
//! - Prepared statements with parameter binding
//! - Transaction support with savepoints
//! - Cross-platform including WASM

const std = @import("std");

// Re-export submodules
pub const types = @import("types.zig");
pub const sqlite = @import("sqlite.zig");
pub const mysql = @import("mysql.zig");
pub const postgres = @import("postgres.zig");
pub const turso = @import("turso.zig");
pub const pool = @import("pool.zig");
pub const query = @import("query.zig");

// Re-export common types
pub const Value = types.Value;
pub const Column = types.Column;
pub const Row = types.Row;
pub const ResultSet = types.ResultSet;
pub const Parameter = types.Parameter;
pub const SqlType = types.SqlType;
pub const Backend = types.Backend;
pub const ConnectionState = types.ConnectionState;
pub const ConnectionOptions = types.ConnectionOptions;
pub const IsolationLevel = types.IsolationLevel;
pub const TransactionOptions = types.TransactionOptions;
pub const DatabaseError = types.DatabaseError;
pub const Error = types.Error;

// Re-export query builder types
pub const SelectBuilder = query.SelectBuilder;
pub const InsertBuilder = query.InsertBuilder;
pub const UpdateBuilder = query.UpdateBuilder;
pub const DeleteBuilder = query.DeleteBuilder;
pub const Operator = query.Operator;
pub const JoinType = query.JoinType;
pub const SortDirection = query.SortDirection;

// Re-export pool types
pub const PoolConfig = pool.PoolConfig;
pub const PoolStats = pool.PoolStats;
pub const ConnectionPool = pool.ConnectionPool;

/// Unified connection interface
pub const Connection = union(Backend) {
    sqlite: *sqlite.Connection,
    mysql: *mysql.Connection,
    postgresql: *postgres.Connection,
    turso: *turso.Connection,

    pub fn execute(self: Connection, sql: []const u8) !u64 {
        return switch (self) {
            .sqlite => |c| c.execute(sql),
            .mysql => |c| c.execute(sql),
            .postgresql => |c| c.execute(sql),
            .turso => |c| c.execute(sql),
        };
    }

    pub fn query(self: Connection, sql: []const u8) !ResultSet {
        return switch (self) {
            .sqlite => |c| c.query(sql),
            .mysql => |c| c.query(sql),
            .postgresql => |c| c.query(sql),
            .turso => |c| c.query(sql),
        };
    }

    pub fn beginTransaction(self: Connection, options: TransactionOptions) !void {
        switch (self) {
            .sqlite => |c| try c.beginTransaction(options),
            .mysql => |c| try c.beginTransaction(options),
            .postgresql => |c| try c.beginTransaction(options),
            .turso => |c| try c.beginTransaction(options),
        }
    }

    pub fn commit(self: Connection) !void {
        switch (self) {
            .sqlite => |c| try c.commit(),
            .mysql => |c| try c.commit(),
            .postgresql => |c| try c.commit(),
            .turso => |c| try c.commit(),
        }
    }

    pub fn rollback(self: Connection) !void {
        switch (self) {
            .sqlite => |c| try c.rollback(),
            .mysql => |c| try c.rollback(),
            .postgresql => |c| try c.rollback(),
            .turso => |c| try c.rollback(),
        }
    }

    pub fn close(self: Connection) void {
        switch (self) {
            .sqlite => |c| c.close(),
            .mysql => |c| c.close(),
            .postgresql => |c| c.close(),
            .turso => |c| c.close(),
        }
    }

    /// Properly close and deallocate the connection
    pub fn deinit(self: Connection, allocator: std.mem.Allocator) void {
        switch (self) {
            .sqlite => |c| {
                c.deinit();
                allocator.destroy(c);
            },
            .mysql => |c| {
                c.deinit();
                allocator.destroy(c);
            },
            .postgresql => |c| {
                c.deinit();
                allocator.destroy(c);
            },
            .turso => |c| {
                c.deinit();
                allocator.destroy(c);
            },
        }
    }
};

/// Connect to a database using a connection string
pub fn connect(allocator: std.mem.Allocator, connection_string: []const u8) !Connection {
    const parsed = try parseConnectionString(connection_string);

    switch (parsed.backend) {
        .sqlite => {
            const conn = try allocator.create(sqlite.Connection);
            errdefer allocator.destroy(conn);
            conn.* = sqlite.Connection.init(allocator, .{
                .path = parsed.database,
            });
            try conn.open();
            return .{ .sqlite = conn };
        },
        .mysql => {
            const conn = try allocator.create(mysql.Connection);
            errdefer allocator.destroy(conn);
            conn.* = mysql.Connection.init(allocator, .{
                .host = parsed.host,
                .port = parsed.port,
                .database = parsed.database,
                .username = parsed.username,
                .password = parsed.password,
            });
            try conn.open();
            return .{ .mysql = conn };
        },
        .postgresql => {
            const conn = try allocator.create(postgres.Connection);
            errdefer allocator.destroy(conn);
            conn.* = postgres.Connection.init(allocator, .{
                .host = parsed.host,
                .port = parsed.port,
                .database = parsed.database,
                .username = parsed.username,
                .password = parsed.password,
            });
            try conn.open();
            return .{ .postgresql = conn };
        },
        .turso => {
            const conn = try allocator.create(turso.Connection);
            errdefer allocator.destroy(conn);
            conn.* = turso.Connection.init(allocator, .{
                .url = parsed.host,
                .auth_token = parsed.password,
                .mode = .cloud,
            });
            try conn.open();
            return .{ .turso = conn };
        },
    }
}

/// Parsed connection string
const ParsedConnection = struct {
    backend: Backend,
    host: []const u8 = "localhost",
    port: u16 = 0,
    database: []const u8 = "",
    username: []const u8 = "",
    password: []const u8 = "",
};

/// Parse a connection string
/// Formats supported:
/// - sqlite:path/to/db.sqlite
/// - sqlite::memory:
/// - mysql://user:pass@host:port/database
/// - postgresql://user:pass@host:port/database
/// - libsql://database.turso.io?authToken=xxx
fn parseConnectionString(conn_str: []const u8) !ParsedConnection {
    var result = ParsedConnection{ .backend = .sqlite };

    // Check for protocol prefix
    if (std.mem.startsWith(u8, conn_str, "sqlite:")) {
        result.backend = .sqlite;
        result.database = conn_str[7..];
        return result;
    }

    if (std.mem.startsWith(u8, conn_str, "mysql://")) {
        result.backend = .mysql;
        result.port = 3306;
        try parseUrlConnectionString(conn_str[8..], &result);
        return result;
    }

    if (std.mem.startsWith(u8, conn_str, "postgresql://") or
        std.mem.startsWith(u8, conn_str, "postgres://"))
    {
        result.backend = .postgresql;
        result.port = 5432;
        const offset: usize = if (std.mem.startsWith(u8, conn_str, "postgresql://")) 13 else 11;
        try parseUrlConnectionString(conn_str[offset..], &result);
        return result;
    }

    if (std.mem.startsWith(u8, conn_str, "libsql://") or
        std.mem.startsWith(u8, conn_str, "turso://"))
    {
        result.backend = .turso;
        const offset: usize = if (std.mem.startsWith(u8, conn_str, "libsql://")) 9 else 8;
        result.host = conn_str[offset..];
        // Parse authToken from query string
        if (std.mem.indexOf(u8, result.host, "?authToken=")) |pos| {
            result.password = result.host[pos + 11 ..];
            result.host = result.host[0..pos];
        }
        return result;
    }

    // Default to SQLite with path
    result.database = conn_str;
    return result;
}

fn parseUrlConnectionString(url: []const u8, result: *ParsedConnection) !void {
    var remaining = url;

    // Parse user:pass@
    if (std.mem.indexOf(u8, remaining, "@")) |at_pos| {
        const user_pass = remaining[0..at_pos];
        remaining = remaining[at_pos + 1 ..];

        if (std.mem.indexOf(u8, user_pass, ":")) |colon_pos| {
            result.username = user_pass[0..colon_pos];
            result.password = user_pass[colon_pos + 1 ..];
        } else {
            result.username = user_pass;
        }
    }

    // Parse host:port/database
    if (std.mem.indexOf(u8, remaining, "/")) |slash_pos| {
        const host_port = remaining[0..slash_pos];
        result.database = remaining[slash_pos + 1 ..];

        // Remove query string from database
        if (std.mem.indexOf(u8, result.database, "?")) |q_pos| {
            result.database = result.database[0..q_pos];
        }

        if (std.mem.indexOf(u8, host_port, ":")) |colon_pos| {
            result.host = host_port[0..colon_pos];
            result.port = std.fmt.parseInt(u16, host_port[colon_pos + 1 ..], 10) catch result.port;
        } else {
            result.host = host_port;
        }
    } else {
        result.host = remaining;
    }
}

/// Create a new query builder for SELECT
pub fn select(allocator: std.mem.Allocator) SelectBuilder {
    return SelectBuilder.init(allocator);
}

/// Create a new query builder for INSERT
pub fn insert(allocator: std.mem.Allocator) InsertBuilder {
    return InsertBuilder.init(allocator);
}

/// Create a new query builder for UPDATE
pub fn update(allocator: std.mem.Allocator) UpdateBuilder {
    return UpdateBuilder.init(allocator);
}

/// Create a new query builder for DELETE
pub fn delete(allocator: std.mem.Allocator) DeleteBuilder {
    return DeleteBuilder.init(allocator);
}

// Convenience functions for specific backends

/// Create an in-memory SQLite connection
pub fn inMemory(allocator: std.mem.Allocator) sqlite.Connection {
    return sqlite.inMemory(allocator);
}

/// Create a SQLite connection to a file
pub fn sqliteFile(allocator: std.mem.Allocator, path: []const u8) sqlite.Connection {
    return sqlite.file(allocator, path);
}

/// Create a MySQL connection
pub fn mysqlConnect(allocator: std.mem.Allocator, options: mysql.MysqlOptions) mysql.Connection {
    return mysql.connect(allocator, options);
}

/// Create a PostgreSQL connection
pub fn postgresConnect(allocator: std.mem.Allocator, options: postgres.PostgresOptions) postgres.Connection {
    return postgres.connect(allocator, options);
}

/// Create a Turso cloud connection
pub fn tursoCloud(allocator: std.mem.Allocator, url: []const u8, auth_token: []const u8) turso.Connection {
    return turso.cloud(allocator, url, auth_token);
}

/// Create a Turso embedded connection
pub fn tursoEmbedded(allocator: std.mem.Allocator, path: []const u8) turso.Connection {
    return turso.embedded(allocator, path);
}

/// Create a Turso replica connection (local + cloud sync)
pub fn tursoReplica(allocator: std.mem.Allocator, url: []const u8, auth_token: []const u8, local_path: []const u8) turso.Connection {
    return turso.replica(allocator, url, auth_token, local_path);
}

// Tests
test "parse sqlite connection string" {
    const result = try parseConnectionString("sqlite:test.db");
    try std.testing.expectEqual(Backend.sqlite, result.backend);
    try std.testing.expect(std.mem.eql(u8, "test.db", result.database));
}

test "parse sqlite memory connection string" {
    const result = try parseConnectionString("sqlite::memory:");
    try std.testing.expectEqual(Backend.sqlite, result.backend);
    try std.testing.expect(std.mem.eql(u8, ":memory:", result.database));
}

test "parse mysql connection string" {
    const result = try parseConnectionString("mysql://user:pass@localhost:3306/mydb");
    try std.testing.expectEqual(Backend.mysql, result.backend);
    try std.testing.expect(std.mem.eql(u8, "localhost", result.host));
    try std.testing.expectEqual(@as(u16, 3306), result.port);
    try std.testing.expect(std.mem.eql(u8, "mydb", result.database));
    try std.testing.expect(std.mem.eql(u8, "user", result.username));
    try std.testing.expect(std.mem.eql(u8, "pass", result.password));
}

test "parse postgresql connection string" {
    const result = try parseConnectionString("postgresql://admin@db.example.com/production");
    try std.testing.expectEqual(Backend.postgresql, result.backend);
    try std.testing.expect(std.mem.eql(u8, "db.example.com", result.host));
    try std.testing.expect(std.mem.eql(u8, "production", result.database));
    try std.testing.expect(std.mem.eql(u8, "admin", result.username));
}

test "parse libsql connection string" {
    const result = try parseConnectionString("libsql://my-db.turso.io?authToken=secret");
    try std.testing.expectEqual(Backend.turso, result.backend);
    try std.testing.expect(std.mem.eql(u8, "my-db.turso.io", result.host));
    try std.testing.expect(std.mem.eql(u8, "secret", result.password));
}

test "query builder helpers" {
    const allocator = std.testing.allocator;

    var sel = select(allocator);
    defer sel.deinit();
    _ = sel.selectAll().from("users");

    var ins = insert(allocator);
    defer ins.deinit();
    _ = ins.into("users");

    var upd = update(allocator);
    defer upd.deinit();
    _ = upd.update("users");

    var del = delete(allocator);
    defer del.deinit();
    _ = del.from("users");
}
