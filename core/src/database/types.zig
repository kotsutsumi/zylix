//! Database Types - Common types for database operations
//!
//! Provides unified type definitions used across all database backends
//! including SQLite, MySQL, PostgreSQL, and Turso/libSQL.

const std = @import("std");

/// Database error types
pub const DatabaseError = error{
    ConnectionFailed,
    ConnectionClosed,
    ConnectionTimeout,
    AuthenticationFailed,
    DatabaseNotFound,
    TableNotFound,
    ColumnNotFound,
    DuplicateKey,
    ForeignKeyViolation,
    CheckConstraintViolation,
    NotNullViolation,
    UniqueViolation,
    QuerySyntaxError,
    QueryExecutionError,
    TransactionError,
    TransactionAborted,
    DeadlockDetected,
    LockTimeout,
    PrepareError,
    BindError,
    FetchError,
    TypeMismatch,
    Overflow,
    InvalidState,
    PoolExhausted,
    PoolTimeout,
    UnsupportedOperation,
    InvalidConfiguration,
    SslError,
    ProtocolError,
    OutOfMemory,
    IoError,
};

/// Combined error type
pub const Error = DatabaseError || std.mem.Allocator.Error;

/// Database backend type
pub const Backend = enum(u8) {
    sqlite = 0,
    mysql = 1,
    postgresql = 2,
    turso = 3,
};

/// Connection state
pub const ConnectionState = enum(u8) {
    disconnected = 0,
    connecting = 1,
    connected = 2,
    in_transaction = 3,
    error_state = 4,
};

/// Transaction isolation level
pub const IsolationLevel = enum(u8) {
    read_uncommitted = 0,
    read_committed = 1,
    repeatable_read = 2,
    serializable = 3,
    snapshot = 4, // PostgreSQL specific
};

/// SQL data types
pub const SqlType = enum(u8) {
    null = 0,
    boolean = 1,
    tinyint = 2,
    smallint = 3,
    integer = 4,
    bigint = 5,
    float = 6,
    double = 7,
    decimal = 8,
    text = 9,
    varchar = 10,
    char = 11,
    blob = 12,
    date = 13,
    time = 14,
    datetime = 15,
    timestamp = 16,
    interval = 17,
    uuid = 18,
    json = 19,
    jsonb = 20,
    array = 21,
    custom = 255,
};

/// SQL value - represents a database value
pub const Value = union(enum) {
    null: void,
    boolean: bool,
    integer: i64,
    float: f64,
    text: []const u8,
    blob: []const u8,
    timestamp: i64, // Unix timestamp in milliseconds
    json: []const u8, // JSON string

    pub fn isNull(self: Value) bool {
        return self == .null;
    }

    pub fn asInt(self: Value) ?i64 {
        return switch (self) {
            .integer => |v| v,
            .float => |v| @intFromFloat(v),
            .boolean => |v| if (v) @as(i64, 1) else 0,
            else => null,
        };
    }

    pub fn asFloat(self: Value) ?f64 {
        return switch (self) {
            .float => |v| v,
            .integer => |v| @floatFromInt(v),
            else => null,
        };
    }

    pub fn asBool(self: Value) ?bool {
        return switch (self) {
            .boolean => |v| v,
            .integer => |v| v != 0,
            else => null,
        };
    }

    pub fn asText(self: Value) ?[]const u8 {
        return switch (self) {
            .text => |v| v,
            .json => |v| v,
            else => null,
        };
    }

    pub fn asBlob(self: Value) ?[]const u8 {
        return switch (self) {
            .blob => |v| v,
            else => null,
        };
    }

    /// Clone value, duplicating any owned memory
    pub fn clone(self: Value, allocator: std.mem.Allocator) !Value {
        return switch (self) {
            .null => .null,
            .boolean => |v| .{ .boolean = v },
            .integer => |v| .{ .integer = v },
            .float => |v| .{ .float = v },
            .timestamp => |v| .{ .timestamp = v },
            .text => |v| .{ .text = try allocator.dupe(u8, v) },
            .blob => |v| .{ .blob = try allocator.dupe(u8, v) },
            .json => |v| .{ .json = try allocator.dupe(u8, v) },
        };
    }

    /// Free any allocated memory
    /// Note: Always frees regardless of length; Zig allocators handle zero-length frees correctly
    pub fn deinit(self: *Value, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .text => |v| allocator.free(v),
            .blob => |v| allocator.free(v),
            .json => |v| allocator.free(v),
            else => {},
        }
    }
};

/// Column metadata
pub const Column = struct {
    name: []const u8,
    sql_type: SqlType,
    nullable: bool = true,
    primary_key: bool = false,
    auto_increment: bool = false,
    default_value: ?Value = null,
    max_length: ?usize = null,
    precision: ?u8 = null,
    scale: ?u8 = null,
    table_name: ?[]const u8 = null,
};

/// Row - a single database row
pub const Row = struct {
    allocator: std.mem.Allocator,
    columns: []const Column,
    values: []Value,

    pub fn init(allocator: std.mem.Allocator, columns: []const Column) !Row {
        const values = try allocator.alloc(Value, columns.len);
        for (values) |*v| {
            v.* = .null;
        }
        return .{
            .allocator = allocator,
            .columns = columns,
            .values = values,
        };
    }

    pub fn deinit(self: *Row) void {
        for (self.values) |*v| {
            v.deinit(self.allocator);
        }
        self.allocator.free(self.values);
    }

    /// Get value by column index
    pub fn get(self: *const Row, index: usize) ?Value {
        if (index >= self.values.len) return null;
        return self.values[index];
    }

    /// Get value by column name
    pub fn getByName(self: *const Row, name: []const u8) ?Value {
        for (self.columns, 0..) |col, i| {
            if (std.mem.eql(u8, col.name, name)) {
                return self.values[i];
            }
        }
        return null;
    }

    /// Get column index by name
    pub fn getColumnIndex(self: *const Row, name: []const u8) ?usize {
        for (self.columns, 0..) |col, i| {
            if (std.mem.eql(u8, col.name, name)) {
                return i;
            }
        }
        return null;
    }
};

/// Result set - collection of rows
pub const ResultSet = struct {
    allocator: std.mem.Allocator,
    columns: []Column,
    rows: std.ArrayListUnmanaged(Row) = .{},
    affected_rows: u64 = 0,
    last_insert_id: ?i64 = null,

    pub fn init(allocator: std.mem.Allocator) ResultSet {
        return .{
            .allocator = allocator,
            .columns = &.{},
        };
    }

    pub fn deinit(self: *ResultSet) void {
        for (self.rows.items) |*row| {
            row.deinit();
        }
        self.rows.deinit(self.allocator);
        if (self.columns.len > 0) {
            self.allocator.free(self.columns);
        }
    }

    pub fn rowCount(self: *const ResultSet) usize {
        return self.rows.items.len;
    }

    pub fn columnCount(self: *const ResultSet) usize {
        return self.columns.len;
    }

    pub fn getRow(self: *const ResultSet, index: usize) ?*const Row {
        if (index >= self.rows.items.len) return null;
        return &self.rows.items[index];
    }

    /// Iterator for rows
    pub fn iterator(self: *ResultSet) Iterator {
        return .{ .result_set = self, .index = 0 };
    }

    pub const Iterator = struct {
        result_set: *ResultSet,
        index: usize,

        pub fn next(self: *Iterator) ?*const Row {
            if (self.index >= self.result_set.rows.items.len) return null;
            const row = &self.result_set.rows.items[self.index];
            self.index += 1;
            return row;
        }

        pub fn reset(self: *Iterator) void {
            self.index = 0;
        }
    };
};

/// Prepared statement parameter
pub const Parameter = struct {
    index: usize,
    value: Value,
    name: ?[]const u8 = null, // For named parameters
};

/// Connection options
pub const ConnectionOptions = struct {
    host: []const u8 = "localhost",
    port: u16 = 0, // 0 = use default
    database: []const u8 = "",
    username: []const u8 = "",
    password: []const u8 = "",

    // Connection behavior
    connect_timeout_ms: u32 = 30000,
    read_timeout_ms: u32 = 30000,
    write_timeout_ms: u32 = 30000,
    max_retries: u8 = 3,
    retry_delay_ms: u32 = 1000,

    // SSL/TLS
    ssl_mode: SslMode = .prefer,
    ssl_ca: ?[]const u8 = null,
    ssl_cert: ?[]const u8 = null,
    ssl_key: ?[]const u8 = null,

    // Pool settings (when using pool)
    pool_min_size: u16 = 1,
    pool_max_size: u16 = 10,
    pool_idle_timeout_ms: u32 = 300000, // 5 minutes
    pool_max_lifetime_ms: u32 = 3600000, // 1 hour

    // Backend specific
    charset: []const u8 = "utf8mb4",
    timezone: []const u8 = "UTC",
    application_name: []const u8 = "zylix",

    pub fn defaultPort(backend: Backend) u16 {
        return switch (backend) {
            .sqlite => 0,
            .mysql => 3306,
            .postgresql => 5432,
            .turso => 443,
        };
    }
};

/// SSL mode
pub const SslMode = enum(u8) {
    disable = 0, // No SSL
    allow = 1, // Try SSL, fallback to non-SSL
    prefer = 2, // Try SSL first, fallback to non-SSL
    require = 3, // Require SSL
    verify_ca = 4, // Require SSL and verify CA
    verify_full = 5, // Require SSL and verify CA + hostname
};

/// Statement type
pub const StatementType = enum(u8) {
    select = 0,
    insert = 1,
    update = 2,
    delete = 3,
    create = 4,
    alter = 5,
    drop = 6,
    truncate = 7,
    begin = 8,
    commit = 9,
    rollback = 10,
    savepoint = 11,
    other = 255,

    pub fn fromSql(sql: []const u8) StatementType {
        const trimmed = std.mem.trim(u8, sql, " \t\n\r");
        if (trimmed.len == 0) return .other;

        const upper = blk: {
            var buf: [10]u8 = undefined;
            const len = @min(trimmed.len, 10);
            for (0..len) |i| {
                buf[i] = std.ascii.toUpper(trimmed[i]);
            }
            break :blk buf[0..len];
        };

        if (std.mem.startsWith(u8, upper, "SELECT")) return .select;
        if (std.mem.startsWith(u8, upper, "INSERT")) return .insert;
        if (std.mem.startsWith(u8, upper, "UPDATE")) return .update;
        if (std.mem.startsWith(u8, upper, "DELETE")) return .delete;
        if (std.mem.startsWith(u8, upper, "CREATE")) return .create;
        if (std.mem.startsWith(u8, upper, "ALTER")) return .alter;
        if (std.mem.startsWith(u8, upper, "DROP")) return .drop;
        if (std.mem.startsWith(u8, upper, "TRUNCATE")) return .truncate;
        if (std.mem.startsWith(u8, upper, "BEGIN")) return .begin;
        if (std.mem.startsWith(u8, upper, "COMMIT")) return .commit;
        if (std.mem.startsWith(u8, upper, "ROLLBACK")) return .rollback;
        if (std.mem.startsWith(u8, upper, "SAVEPOINT")) return .savepoint;

        return .other;
    }
};

/// Transaction options
pub const TransactionOptions = struct {
    isolation_level: IsolationLevel = .read_committed,
    read_only: bool = false,
    deferrable: bool = false, // PostgreSQL specific
};

/// Query statistics
pub const QueryStats = struct {
    execution_time_ns: u64 = 0,
    rows_examined: u64 = 0,
    rows_affected: u64 = 0,
    bytes_sent: u64 = 0,
    bytes_received: u64 = 0,
};

/// Database info
pub const DatabaseInfo = struct {
    backend: Backend,
    version: []const u8,
    server_info: []const u8,
    charset: []const u8,
    timezone: []const u8,
    max_connections: u32,
    current_database: []const u8,
};

// Tests
test "Value conversions" {
    const int_val = Value{ .integer = 42 };
    try std.testing.expectEqual(@as(i64, 42), int_val.asInt().?);
    try std.testing.expectEqual(@as(f64, 42.0), int_val.asFloat().?);

    const float_val = Value{ .float = 3.14 };
    try std.testing.expectEqual(@as(i64, 3), float_val.asInt().?);
    try std.testing.expectEqual(@as(f64, 3.14), float_val.asFloat().?);

    const bool_val = Value{ .boolean = true };
    try std.testing.expectEqual(@as(i64, 1), bool_val.asInt().?);
    try std.testing.expectEqual(true, bool_val.asBool().?);
}

test "StatementType detection" {
    try std.testing.expectEqual(StatementType.select, StatementType.fromSql("SELECT * FROM users"));
    try std.testing.expectEqual(StatementType.insert, StatementType.fromSql("INSERT INTO users VALUES (1)"));
    try std.testing.expectEqual(StatementType.update, StatementType.fromSql("  UPDATE users SET name = 'test'"));
    try std.testing.expectEqual(StatementType.delete, StatementType.fromSql("\nDELETE FROM users"));
    try std.testing.expectEqual(StatementType.begin, StatementType.fromSql("BEGIN TRANSACTION"));
}

test "Row operations" {
    const allocator = std.testing.allocator;

    var columns = [_]Column{
        .{ .name = "id", .sql_type = .integer },
        .{ .name = "name", .sql_type = .text },
    };

    var row = try Row.init(allocator, &columns);
    defer row.deinit();

    row.values[0] = .{ .integer = 1 };
    row.values[1] = .{ .text = "test" };

    try std.testing.expectEqual(@as(i64, 1), row.get(0).?.asInt().?);
    try std.testing.expect(std.mem.eql(u8, "test", row.getByName("name").?.asText().?));
    try std.testing.expectEqual(@as(?usize, 1), row.getColumnIndex("name"));
    try std.testing.expectEqual(@as(?usize, null), row.getColumnIndex("unknown"));
}
