//! SQLite Database Backend
//!
//! Provides SQLite database connectivity with support for:
//! - In-memory and file-based databases
//! - WAL (Write-Ahead Logging) mode
//! - User-defined functions
//! - Full-text search (FTS5)
//! - JSON1 extension
//! - Prepared statements with parameter binding

const std = @import("std");
const types = @import("types.zig");

const Value = types.Value;
const Column = types.Column;
const Row = types.Row;
const ResultSet = types.ResultSet;
const Parameter = types.Parameter;
const SqlType = types.SqlType;
const ConnectionState = types.ConnectionState;
const IsolationLevel = types.IsolationLevel;
const TransactionOptions = types.TransactionOptions;
const QueryStats = types.QueryStats;
const DatabaseError = types.DatabaseError;
const Error = types.Error;

/// SQLite open flags
pub const OpenFlags = packed struct(u32) {
    read_only: bool = false,
    read_write: bool = true,
    create: bool = true,
    uri: bool = false,
    memory: bool = false,
    no_mutex: bool = false,
    full_mutex: bool = false,
    shared_cache: bool = false,
    private_cache: bool = false,
    _padding: u23 = 0,

    pub fn toInt(self: OpenFlags) u32 {
        var flags: u32 = 0;
        if (self.read_only) flags |= 0x00000001;
        if (self.read_write) flags |= 0x00000002;
        if (self.create) flags |= 0x00000004;
        if (self.uri) flags |= 0x00000040;
        if (self.memory) flags |= 0x00000080;
        if (self.no_mutex) flags |= 0x00008000;
        if (self.full_mutex) flags |= 0x00010000;
        if (self.shared_cache) flags |= 0x00020000;
        if (self.private_cache) flags |= 0x00040000;
        return flags;
    }

    pub const default = OpenFlags{};
    pub const read_only_mode = OpenFlags{ .read_only = true, .read_write = false, .create = false };
    pub const memory_mode = OpenFlags{ .memory = true };
};

/// SQLite journal mode
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

/// SQLite synchronous mode
pub const SynchronousMode = enum {
    off,
    normal,
    full,
    extra,

    pub fn toSql(self: SynchronousMode) []const u8 {
        return switch (self) {
            .off => "OFF",
            .normal => "NORMAL",
            .full => "FULL",
            .extra => "EXTRA",
        };
    }
};

/// SQLite configuration options
pub const SqliteOptions = struct {
    path: []const u8 = ":memory:",
    flags: OpenFlags = .{},
    journal_mode: JournalMode = .wal,
    synchronous: SynchronousMode = .normal,
    busy_timeout_ms: u32 = 5000,
    cache_size: i32 = -2000, // Negative = KB, positive = pages
    page_size: u32 = 4096,
    mmap_size: u64 = 0, // 0 = disabled
    foreign_keys: bool = true,
    recursive_triggers: bool = false,
    secure_delete: bool = false,
};

/// SQLite prepared statement
pub const Statement = struct {
    allocator: std.mem.Allocator,
    sql: []const u8,
    handle: ?*anyopaque = null, // sqlite3_stmt*
    columns: []Column = &.{},
    param_count: usize = 0,
    state: StatementState = .prepared,

    const StatementState = enum {
        prepared,
        executing,
        done,
        error_state,
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
        // In real implementation, would call sqlite3_finalize
        self.handle = null;
    }

    /// Bind a value to a parameter by index (1-based)
    pub fn bind(self: *Statement, index: usize, value: Value) !void {
        if (index == 0 or index > self.param_count) {
            return error.BindError;
        }
        // In real implementation, would call sqlite3_bind_*
        _ = self;
        _ = value;
    }

    /// Bind a value to a named parameter
    pub fn bindNamed(self: *Statement, name: []const u8, value: Value) !void {
        // In real implementation, would call sqlite3_bind_parameter_index then bind
        _ = self;
        _ = name;
        _ = value;
    }

    /// Bind multiple parameters
    pub fn bindAll(self: *Statement, params: []const Parameter) !void {
        for (params) |param| {
            if (param.name) |name| {
                try self.bindNamed(name, param.value);
            } else {
                try self.bind(param.index, param.value);
            }
        }
    }

    /// Reset statement for re-execution
    pub fn reset(self: *Statement) !void {
        // In real implementation, would call sqlite3_reset
        self.state = .prepared;
    }

    /// Clear all bindings
    pub fn clearBindings(self: *Statement) !void {
        // In real implementation, would call sqlite3_clear_bindings
        _ = self;
    }
};

/// SQLite connection
pub const Connection = struct {
    allocator: std.mem.Allocator,
    handle: ?*anyopaque = null, // sqlite3*
    options: SqliteOptions,
    state: ConnectionState = .disconnected,
    in_transaction: bool = false,
    last_error: ?[]const u8 = null,
    stats: QueryStats = .{},

    // Statement cache
    statement_cache: std.StringHashMapUnmanaged(*Statement) = .{},
    cache_enabled: bool = true,
    max_cached_statements: usize = 100,

    pub fn init(allocator: std.mem.Allocator, options: SqliteOptions) Connection {
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

    /// Open database connection
    pub fn open(self: *Connection) !void {
        if (self.state != .disconnected) {
            return error.InvalidState;
        }

        self.state = .connecting;

        // In real implementation, would call sqlite3_open_v2
        // For now, simulate successful connection
        self.state = .connected;

        // Apply configuration
        try self.configure();
    }

    /// Close database connection
    pub fn close(self: *Connection) void {
        if (self.state == .disconnected) return;

        // In real implementation, would call sqlite3_close_v2
        self.handle = null;
        self.state = .disconnected;
        self.in_transaction = false;
    }

    /// Configure database after opening
    fn configure(self: *Connection) !void {
        // Set pragmas
        const pragmas = [_]struct { name: []const u8, value: []const u8 }{
            .{ .name = "journal_mode", .value = self.options.journal_mode.toSql() },
            .{ .name = "synchronous", .value = self.options.synchronous.toSql() },
            .{ .name = "foreign_keys", .value = if (self.options.foreign_keys) "ON" else "OFF" },
            .{ .name = "recursive_triggers", .value = if (self.options.recursive_triggers) "ON" else "OFF" },
            .{ .name = "secure_delete", .value = if (self.options.secure_delete) "ON" else "OFF" },
        };

        for (pragmas) |pragma| {
            var buf: [256]u8 = undefined;
            const sql = std.fmt.bufPrint(&buf, "PRAGMA {s} = {s}", .{ pragma.name, pragma.value }) catch continue;
            _ = try self.execute(sql);
        }
    }

    /// Execute a SQL statement without returning results
    pub fn execute(self: *Connection, sql: []const u8) !u64 {
        if (self.state != .connected and self.state != .in_transaction) {
            return error.InvalidState;
        }

        const start_time = std.time.nanoTimestamp();
        defer {
            const end_time = std.time.nanoTimestamp();
            const elapsed = end_time - start_time;
            self.stats.execution_time_ns = if (elapsed > 0) @intCast(elapsed) else 0;
        }

        // In real implementation, would call sqlite3_exec
        _ = sql;

        return 0; // affected rows
    }

    /// Execute a SQL query and return results
    pub fn query(self: *Connection, sql: []const u8) !ResultSet {
        if (self.state != .connected and self.state != .in_transaction) {
            return error.InvalidState;
        }

        var result = ResultSet.init(self.allocator);

        const start_time = std.time.nanoTimestamp();
        defer {
            const end_time = std.time.nanoTimestamp();
            const elapsed = end_time - start_time;
            self.stats.execution_time_ns = if (elapsed > 0) @intCast(elapsed) else 0;
        }

        // In real implementation, would prepare, step, and fetch results
        _ = sql;

        return result;
    }

    /// Prepare a statement for later execution
    pub fn prepare(self: *Connection, sql: []const u8) !*Statement {
        if (self.state != .connected and self.state != .in_transaction) {
            return error.InvalidState;
        }

        // Check cache first
        if (self.cache_enabled) {
            if (self.statement_cache.get(sql)) |stmt| {
                try stmt.reset();
                return stmt;
            }
        }

        // Create new statement
        const stmt = try self.allocator.create(Statement);
        stmt.* = Statement.init(self.allocator, sql);

        // In real implementation, would call sqlite3_prepare_v2

        // Cache statement
        if (self.cache_enabled and self.statement_cache.count() < self.max_cached_statements) {
            self.statement_cache.put(self.allocator, sql, stmt) catch {};
        }

        return stmt;
    }

    /// Execute a prepared statement
    pub fn executeStatement(self: *Connection, stmt: *Statement, params: []const Parameter) !u64 {
        if (self.state != .connected and self.state != .in_transaction) {
            return error.InvalidState;
        }

        try stmt.reset();
        try stmt.bindAll(params);

        // In real implementation, would call sqlite3_step
        return 0;
    }

    /// Query with a prepared statement
    pub fn queryStatement(self: *Connection, stmt: *Statement, params: []const Parameter) !ResultSet {
        if (self.state != .connected and self.state != .in_transaction) {
            return error.InvalidState;
        }

        try stmt.reset();
        try stmt.bindAll(params);

        var result = ResultSet.init(self.allocator);

        // In real implementation, would call sqlite3_step and fetch rows
        return result;
    }

    /// Begin a transaction
    pub fn beginTransaction(self: *Connection, options: TransactionOptions) !void {
        if (self.in_transaction) {
            return error.TransactionError;
        }

        const sql = switch (options.isolation_level) {
            .read_uncommitted => "BEGIN",
            .read_committed => "BEGIN",
            .repeatable_read => "BEGIN IMMEDIATE",
            .serializable => "BEGIN EXCLUSIVE",
            .snapshot => "BEGIN",
        };

        _ = try self.execute(sql);
        self.in_transaction = true;
        self.state = .in_transaction;
    }

    /// Commit the current transaction
    pub fn commit(self: *Connection) !void {
        if (!self.in_transaction) {
            return error.TransactionError;
        }

        _ = try self.execute("COMMIT");
        self.in_transaction = false;
        self.state = .connected;
    }

    /// Rollback the current transaction
    pub fn rollback(self: *Connection) !void {
        if (!self.in_transaction) {
            return error.TransactionError;
        }

        _ = try self.execute("ROLLBACK");
        self.in_transaction = false;
        self.state = .connected;
    }

    /// Validate identifier (alphanumeric and underscore only)
    fn isValidIdentifier(name: []const u8) bool {
        if (name.len == 0 or name.len > 128) return false;
        for (name) |c| {
            if (!std.ascii.isAlphanumeric(c) and c != '_') return false;
        }
        return true;
    }

    /// Create a savepoint
    pub fn savepoint(self: *Connection, name: []const u8) !void {
        if (!self.in_transaction) {
            return error.TransactionError;
        }
        if (!isValidIdentifier(name)) {
            return error.QuerySyntaxError;
        }

        var buf: [256]u8 = undefined;
        const sql = std.fmt.bufPrint(&buf, "SAVEPOINT {s}", .{name}) catch return error.QuerySyntaxError;
        _ = try self.execute(sql);
    }

    /// Release a savepoint
    pub fn releaseSavepoint(self: *Connection, name: []const u8) !void {
        if (!isValidIdentifier(name)) {
            return error.QuerySyntaxError;
        }

        var buf: [256]u8 = undefined;
        const sql = std.fmt.bufPrint(&buf, "RELEASE SAVEPOINT {s}", .{name}) catch return error.QuerySyntaxError;
        _ = try self.execute(sql);
    }

    /// Rollback to a savepoint
    pub fn rollbackToSavepoint(self: *Connection, name: []const u8) !void {
        if (!isValidIdentifier(name)) {
            return error.QuerySyntaxError;
        }

        var buf: [256]u8 = undefined;
        const sql = std.fmt.bufPrint(&buf, "ROLLBACK TO SAVEPOINT {s}", .{name}) catch return error.QuerySyntaxError;
        _ = try self.execute(sql);
    }

    /// Get last insert rowid
    pub fn lastInsertRowId(self: *const Connection) i64 {
        // In real implementation, would call sqlite3_last_insert_rowid
        _ = self;
        return 0;
    }

    /// Get number of changes from last statement
    pub fn changes(self: *const Connection) u64 {
        // In real implementation, would call sqlite3_changes
        _ = self;
        return 0;
    }

    /// Get total number of changes since connection opened
    pub fn totalChanges(self: *const Connection) u64 {
        // In real implementation, would call sqlite3_total_changes
        _ = self;
        return 0;
    }

    /// Check if database is in autocommit mode
    pub fn isAutocommit(self: *const Connection) bool {
        return !self.in_transaction;
    }

    /// Vacuum the database
    pub fn vacuum(self: *Connection) !void {
        _ = try self.execute("VACUUM");
    }

    /// Analyze the database for query optimization
    pub fn analyze(self: *Connection) !void {
        _ = try self.execute("ANALYZE");
    }

    /// Get database file path
    pub fn getDatabasePath(self: *const Connection) []const u8 {
        return self.options.path;
    }

    /// Check database integrity
    pub fn integrityCheck(self: *Connection) !bool {
        var result = try self.query("PRAGMA integrity_check");
        defer result.deinit();

        if (result.rowCount() > 0) {
            if (result.getRow(0)) |row| {
                if (row.get(0)) |val| {
                    if (val.asText()) |text| {
                        return std.mem.eql(u8, text, "ok");
                    }
                }
            }
        }
        return false;
    }

    /// Get SQLite version
    pub fn getVersion() []const u8 {
        // In real implementation, would call sqlite3_libversion
        return "3.45.0";
    }

    /// Get SQLite version number
    pub fn getVersionNumber() u32 {
        // In real implementation, would call sqlite3_libversion_number
        return 3045000;
    }

    /// Register a user-defined scalar function
    pub fn createFunction(
        self: *Connection,
        name: []const u8,
        arg_count: i32,
        func: *const fn ([]const Value) Value,
    ) !void {
        // In real implementation, would call sqlite3_create_function_v2
        _ = self;
        _ = name;
        _ = arg_count;
        _ = func;
    }

    /// Create a virtual table
    pub fn createVirtualTable(
        self: *Connection,
        name: []const u8,
        module: []const u8,
        args: []const []const u8,
    ) !void {
        var buf: [4096]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buf);
        const writer = fbs.writer();

        writer.print("CREATE VIRTUAL TABLE IF NOT EXISTS {s} USING {s}", .{ name, module }) catch return error.QuerySyntaxError;

        if (args.len > 0) {
            writer.writeAll("(") catch return error.QuerySyntaxError;
            for (args, 0..) |arg, i| {
                if (i > 0) writer.writeAll(", ") catch return error.QuerySyntaxError;
                writer.writeAll(arg) catch return error.QuerySyntaxError;
            }
            writer.writeAll(")") catch return error.QuerySyntaxError;
        }

        _ = try self.execute(fbs.getWritten());
    }

    /// Enable full-text search (FTS5)
    pub fn createFtsTable(
        self: *Connection,
        name: []const u8,
        columns: []const []const u8,
        options: struct {
            tokenizer: []const u8 = "unicode61",
            content: ?[]const u8 = null,
            content_rowid: ?[]const u8 = null,
        },
    ) !void {
        var buf: [4096]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buf);
        const writer = fbs.writer();

        writer.print("CREATE VIRTUAL TABLE IF NOT EXISTS {s} USING fts5(", .{name}) catch return error.QuerySyntaxError;

        for (columns, 0..) |col, i| {
            if (i > 0) writer.writeAll(", ") catch return error.QuerySyntaxError;
            writer.writeAll(col) catch return error.QuerySyntaxError;
        }

        writer.print(", tokenize='{s}'", .{options.tokenizer}) catch return error.QuerySyntaxError;

        if (options.content) |content| {
            writer.print(", content='{s}'", .{content}) catch return error.QuerySyntaxError;
        }
        if (options.content_rowid) |rowid| {
            writer.print(", content_rowid='{s}'", .{rowid}) catch return error.QuerySyntaxError;
        }

        writer.writeAll(")") catch return error.QuerySyntaxError;

        _ = try self.execute(fbs.getWritten());
    }

    /// Backup database to file
    pub fn backup(self: *Connection, dest_path: []const u8) !void {
        // In real implementation, would use sqlite3_backup_* API
        // Validate path doesn't contain SQL injection characters
        for (dest_path) |c| {
            if (c == '\'' or c == ';' or c == 0) return error.QuerySyntaxError;
        }
        var buf: [512]u8 = undefined;
        const sql = std.fmt.bufPrint(&buf, "VACUUM INTO '{s}'", .{dest_path}) catch return error.QuerySyntaxError;
        _ = try self.execute(sql);
    }
};

/// Create an in-memory SQLite connection
pub fn inMemory(allocator: std.mem.Allocator) Connection {
    return Connection.init(allocator, .{ .path = ":memory:" });
}

/// Create a file-based SQLite connection
pub fn file(allocator: std.mem.Allocator, path: []const u8) Connection {
    return Connection.init(allocator, .{ .path = path });
}

/// Create a temporary SQLite connection (deleted on close)
pub fn temporary(allocator: std.mem.Allocator) Connection {
    return Connection.init(allocator, .{ .path = "" });
}

// Tests
test "Connection initialization" {
    const allocator = std.testing.allocator;
    var conn = inMemory(allocator);
    defer conn.deinit();

    try std.testing.expectEqual(ConnectionState.disconnected, conn.state);
    try std.testing.expect(std.mem.eql(u8, ":memory:", conn.options.path));
}

test "OpenFlags conversion" {
    const default_flags = OpenFlags.default;
    try std.testing.expect(default_flags.read_write);
    try std.testing.expect(default_flags.create);
    try std.testing.expect(!default_flags.read_only);

    const flags_int = default_flags.toInt();
    try std.testing.expectEqual(@as(u32, 0x00000006), flags_int); // READ_WRITE | CREATE
}

test "JournalMode to SQL" {
    try std.testing.expect(std.mem.eql(u8, "WAL", JournalMode.wal.toSql()));
    try std.testing.expect(std.mem.eql(u8, "DELETE", JournalMode.delete.toSql()));
}

test "Statement initialization" {
    const allocator = std.testing.allocator;
    var stmt = Statement.init(allocator, "SELECT * FROM users WHERE id = ?");
    defer stmt.deinit();

    try std.testing.expect(std.mem.eql(u8, "SELECT * FROM users WHERE id = ?", stmt.sql));
}
