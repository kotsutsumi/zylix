//! Type-safe Query Builder
//!
//! Provides a fluent API for building SQL queries with:
//! - Type-safe column and table references
//! - Support for all database backends
//! - Parameterized queries to prevent SQL injection
//! - JOIN, WHERE, GROUP BY, ORDER BY, LIMIT support
//! - Subqueries and CTEs
//! - Insert, Update, Delete builders

const std = @import("std");
const types = @import("types.zig");

const Value = types.Value;
const Parameter = types.Parameter;
const Backend = types.Backend;

/// Comparison operators
pub const Operator = enum {
    eq, // =
    ne, // != or <>
    lt, // <
    le, // <=
    gt, // >
    ge, // >=
    like,
    not_like,
    in,
    not_in,
    is_null,
    is_not_null,
    between,
    not_between,

    pub fn toSql(self: Operator) []const u8 {
        return switch (self) {
            .eq => "=",
            .ne => "<>",
            .lt => "<",
            .le => "<=",
            .gt => ">",
            .ge => ">=",
            .like => "LIKE",
            .not_like => "NOT LIKE",
            .in => "IN",
            .not_in => "NOT IN",
            .is_null => "IS NULL",
            .is_not_null => "IS NOT NULL",
            .between => "BETWEEN",
            .not_between => "NOT BETWEEN",
        };
    }
};

/// Logical operators for combining conditions
pub const LogicalOp = enum {
    @"and",
    @"or",

    pub fn toSql(self: LogicalOp) []const u8 {
        return switch (self) {
            .@"and" => "AND",
            .@"or" => "OR",
        };
    }
};

/// Sort direction
pub const SortDirection = enum {
    asc,
    desc,

    pub fn toSql(self: SortDirection) []const u8 {
        return switch (self) {
            .asc => "ASC",
            .desc => "DESC",
        };
    }
};

/// Join type
pub const JoinType = enum {
    inner,
    left,
    right,
    full,
    cross,

    pub fn toSql(self: JoinType) []const u8 {
        return switch (self) {
            .inner => "INNER JOIN",
            .left => "LEFT JOIN",
            .right => "RIGHT JOIN",
            .full => "FULL OUTER JOIN",
            .cross => "CROSS JOIN",
        };
    }
};

/// WHERE condition
pub const Condition = struct {
    column: []const u8,
    operator: Operator,
    value: ?Value = null,
    values: ?[]const Value = null, // For IN, NOT IN
    value2: ?Value = null, // For BETWEEN
    logical_op: LogicalOp = .@"and",
    is_raw: bool = false,
    raw_sql: ?[]const u8 = null,
};

/// ORDER BY clause
pub const OrderBy = struct {
    column: []const u8,
    direction: SortDirection = .asc,
    nulls: NullsOrder = .default,

    pub const NullsOrder = enum {
        default,
        first,
        last,

        pub fn toSql(self: NullsOrder) ?[]const u8 {
            return switch (self) {
                .default => null,
                .first => "NULLS FIRST",
                .last => "NULLS LAST",
            };
        }
    };
};

/// JOIN clause
pub const Join = struct {
    join_type: JoinType,
    table: []const u8,
    alias: ?[]const u8 = null,
    on_left: []const u8,
    on_right: []const u8,
};

/// SELECT query builder
pub const SelectBuilder = struct {
    allocator: std.mem.Allocator,
    backend: Backend = .sqlite,

    // Query parts
    distinct: bool = false,
    columns: std.ArrayListUnmanaged([]const u8) = .{},
    from_table: ?[]const u8 = null,
    table_alias: ?[]const u8 = null,
    joins: std.ArrayListUnmanaged(Join) = .{},
    conditions: std.ArrayListUnmanaged(Condition) = .{},
    group_by: std.ArrayListUnmanaged([]const u8) = .{},
    having: std.ArrayListUnmanaged(Condition) = .{},
    order_by: std.ArrayListUnmanaged(OrderBy) = .{},
    limit_value: ?u64 = null,
    offset_value: ?u64 = null,

    // Parameters
    params: std.ArrayListUnmanaged(Parameter) = .{},
    param_index: usize = 1,

    // Error tracking for allocation failures
    has_error: bool = false,

    // PostgreSQL placeholder buffer
    pg_placeholder_buf: [16]u8 = undefined,

    pub fn init(allocator: std.mem.Allocator) SelectBuilder {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *SelectBuilder) void {
        self.columns.deinit(self.allocator);
        self.joins.deinit(self.allocator);
        self.conditions.deinit(self.allocator);
        self.group_by.deinit(self.allocator);
        self.having.deinit(self.allocator);
        self.order_by.deinit(self.allocator);
        self.params.deinit(self.allocator);
    }

    /// Set backend for SQL generation
    pub fn forBackend(self: *SelectBuilder, backend: Backend) *SelectBuilder {
        self.backend = backend;
        return self;
    }

    /// Add DISTINCT
    pub fn setDistinct(self: *SelectBuilder, value: bool) *SelectBuilder {
        self.distinct = value;
        return self;
    }

    /// Add columns to select
    pub fn select(self: *SelectBuilder, cols: []const []const u8) *SelectBuilder {
        for (cols) |col| {
            self.columns.append(self.allocator, col) catch {
                self.has_error = true;
            };
        }
        return self;
    }

    /// Select single column
    pub fn selectOne(self: *SelectBuilder, col: []const u8) *SelectBuilder {
        self.columns.append(self.allocator, col) catch {
            self.has_error = true;
        };
        return self;
    }

    /// Select all columns
    pub fn selectAll(self: *SelectBuilder) *SelectBuilder {
        self.columns.append(self.allocator, "*") catch {
            self.has_error = true;
        };
        return self;
    }

    /// Set FROM table
    pub fn from(self: *SelectBuilder, table: []const u8) *SelectBuilder {
        self.from_table = table;
        return self;
    }

    /// Set FROM table with alias
    pub fn fromAs(self: *SelectBuilder, table: []const u8, alias: []const u8) *SelectBuilder {
        self.from_table = table;
        self.table_alias = alias;
        return self;
    }

    /// Add JOIN
    pub fn join(self: *SelectBuilder, join_type: JoinType, table: []const u8, on_left: []const u8, on_right: []const u8) *SelectBuilder {
        self.joins.append(self.allocator, .{
            .join_type = join_type,
            .table = table,
            .on_left = on_left,
            .on_right = on_right,
        }) catch {
            self.has_error = true;
        };
        return self;
    }

    /// Add INNER JOIN
    pub fn innerJoin(self: *SelectBuilder, table: []const u8, on_left: []const u8, on_right: []const u8) *SelectBuilder {
        return self.join(.inner, table, on_left, on_right);
    }

    /// Add LEFT JOIN
    pub fn leftJoin(self: *SelectBuilder, table: []const u8, on_left: []const u8, on_right: []const u8) *SelectBuilder {
        return self.join(.left, table, on_left, on_right);
    }

    /// Add WHERE condition
    pub fn where(self: *SelectBuilder, column: []const u8, op: Operator, value: Value) *SelectBuilder {
        self.conditions.append(self.allocator, .{
            .column = column,
            .operator = op,
            .value = value,
            .logical_op = .@"and",
        }) catch {};
        self.addParam(value);
        return self;
    }

    /// Add OR WHERE condition
    pub fn orWhere(self: *SelectBuilder, column: []const u8, op: Operator, value: Value) *SelectBuilder {
        self.conditions.append(self.allocator, .{
            .column = column,
            .operator = op,
            .value = value,
            .logical_op = .@"or",
        }) catch {};
        self.addParam(value);
        return self;
    }

    /// Add WHERE ... IS NULL
    pub fn whereNull(self: *SelectBuilder, column: []const u8) *SelectBuilder {
        self.conditions.append(self.allocator, .{
            .column = column,
            .operator = .is_null,
        }) catch {};
        return self;
    }

    /// Add WHERE ... IS NOT NULL
    pub fn whereNotNull(self: *SelectBuilder, column: []const u8) *SelectBuilder {
        self.conditions.append(self.allocator, .{
            .column = column,
            .operator = .is_not_null,
        }) catch {};
        return self;
    }

    /// Add WHERE ... IN (...)
    pub fn whereIn(self: *SelectBuilder, column: []const u8, values: []const Value) *SelectBuilder {
        self.conditions.append(self.allocator, .{
            .column = column,
            .operator = .in,
            .values = values,
        }) catch {};
        for (values) |v| {
            self.addParam(v);
        }
        return self;
    }

    /// Add WHERE ... BETWEEN ... AND ...
    pub fn whereBetween(self: *SelectBuilder, column: []const u8, low: Value, high: Value) *SelectBuilder {
        self.conditions.append(self.allocator, .{
            .column = column,
            .operator = .between,
            .value = low,
            .value2 = high,
        }) catch {};
        self.addParam(low);
        self.addParam(high);
        return self;
    }

    /// Add raw WHERE clause
    pub fn whereRaw(self: *SelectBuilder, sql: []const u8) *SelectBuilder {
        self.conditions.append(self.allocator, .{
            .column = "",
            .operator = .eq,
            .is_raw = true,
            .raw_sql = sql,
        }) catch {};
        return self;
    }

    /// Add GROUP BY
    pub fn groupBy(self: *SelectBuilder, cols: []const []const u8) *SelectBuilder {
        for (cols) |col| {
            self.group_by.append(self.allocator, col) catch {};
        }
        return self;
    }

    /// Add HAVING condition
    pub fn havingCond(self: *SelectBuilder, column: []const u8, op: Operator, value: Value) *SelectBuilder {
        self.having.append(self.allocator, .{
            .column = column,
            .operator = op,
            .value = value,
        }) catch {};
        self.addParam(value);
        return self;
    }

    /// Add ORDER BY
    pub fn orderBy(self: *SelectBuilder, column: []const u8, direction: SortDirection) *SelectBuilder {
        self.order_by.append(self.allocator, .{
            .column = column,
            .direction = direction,
        }) catch {};
        return self;
    }

    /// Set LIMIT
    pub fn limit(self: *SelectBuilder, value: u64) *SelectBuilder {
        self.limit_value = value;
        return self;
    }

    /// Set OFFSET
    pub fn offset(self: *SelectBuilder, value: u64) *SelectBuilder {
        self.offset_value = value;
        return self;
    }

    fn addParam(self: *SelectBuilder, value: Value) void {
        self.params.append(self.allocator, .{
            .index = self.param_index,
            .value = value,
        }) catch {};
        self.param_index += 1;
    }

    /// Get placeholder for current backend
    fn placeholder(self: *SelectBuilder, index: usize) []const u8 {
        return switch (self.backend) {
            .sqlite, .turso => "?",
            .mysql => "?",
            .postgresql => blk: {
                // Format PostgreSQL placeholder ($1, $2, etc.)
                const len = std.fmt.bufPrint(&self.pg_placeholder_buf, "${d}", .{index}) catch break :blk "?";
                break :blk len;
            },
        };
    }

    /// Build the SQL query
    pub fn build(self: *const SelectBuilder, buf: []u8) ![]const u8 {
        // Check for allocation failures during builder construction
        if (self.has_error) return error.OutOfMemory;

        var fbs = std.io.fixedBufferStream(buf);
        const writer = fbs.writer();

        // SELECT
        try writer.writeAll("SELECT ");
        if (self.distinct) try writer.writeAll("DISTINCT ");

        // Columns
        if (self.columns.items.len == 0) {
            try writer.writeAll("*");
        } else {
            for (self.columns.items, 0..) |col, i| {
                if (i > 0) try writer.writeAll(", ");
                try writer.writeAll(col);
            }
        }

        // FROM
        if (self.from_table) |table| {
            try writer.writeAll(" FROM ");
            try writer.writeAll(table);
            if (self.table_alias) |alias| {
                try writer.writeAll(" AS ");
                try writer.writeAll(alias);
            }
        }

        // JOINs
        for (self.joins.items) |j| {
            try writer.writeAll(" ");
            try writer.writeAll(j.join_type.toSql());
            try writer.writeAll(" ");
            try writer.writeAll(j.table);
            if (j.alias) |alias| {
                try writer.writeAll(" AS ");
                try writer.writeAll(alias);
            }
            try writer.writeAll(" ON ");
            try writer.writeAll(j.on_left);
            try writer.writeAll(" = ");
            try writer.writeAll(j.on_right);
        }

        // WHERE
        if (self.conditions.items.len > 0) {
            try writer.writeAll(" WHERE ");
            for (self.conditions.items, 0..) |cond, i| {
                if (i > 0) {
                    try writer.writeAll(" ");
                    try writer.writeAll(cond.logical_op.toSql());
                    try writer.writeAll(" ");
                }

                if (cond.is_raw) {
                    if (cond.raw_sql) |sql| {
                        try writer.writeAll(sql);
                    }
                } else {
                    try writer.writeAll(cond.column);
                    try writer.writeAll(" ");
                    try writer.writeAll(cond.operator.toSql());

                    switch (cond.operator) {
                        .is_null, .is_not_null => {},
                        .in, .not_in => {
                            try writer.writeAll(" (");
                            if (cond.values) |values| {
                                for (values, 0..) |_, vi| {
                                    if (vi > 0) try writer.writeAll(", ");
                                    try writer.writeAll("?");
                                }
                            }
                            try writer.writeAll(")");
                        },
                        .between, .not_between => {
                            try writer.writeAll(" ? AND ?");
                        },
                        else => {
                            try writer.writeAll(" ?");
                        },
                    }
                }
            }
        }

        // GROUP BY
        if (self.group_by.items.len > 0) {
            try writer.writeAll(" GROUP BY ");
            for (self.group_by.items, 0..) |col, i| {
                if (i > 0) try writer.writeAll(", ");
                try writer.writeAll(col);
            }
        }

        // HAVING
        if (self.having.items.len > 0) {
            try writer.writeAll(" HAVING ");
            for (self.having.items, 0..) |cond, i| {
                if (i > 0) {
                    try writer.writeAll(" ");
                    try writer.writeAll(cond.logical_op.toSql());
                    try writer.writeAll(" ");
                }
                try writer.writeAll(cond.column);
                try writer.writeAll(" ");
                try writer.writeAll(cond.operator.toSql());
                try writer.writeAll(" ?");
            }
        }

        // ORDER BY
        if (self.order_by.items.len > 0) {
            try writer.writeAll(" ORDER BY ");
            for (self.order_by.items, 0..) |ob, i| {
                if (i > 0) try writer.writeAll(", ");
                try writer.writeAll(ob.column);
                try writer.writeAll(" ");
                try writer.writeAll(ob.direction.toSql());
                if (ob.nulls.toSql()) |nulls| {
                    try writer.writeAll(" ");
                    try writer.writeAll(nulls);
                }
            }
        }

        // LIMIT
        if (self.limit_value) |lim| {
            try writer.print(" LIMIT {d}", .{lim});
        }

        // OFFSET
        if (self.offset_value) |off| {
            try writer.print(" OFFSET {d}", .{off});
        }

        return fbs.getWritten();
    }

    /// Get parameters for binding
    pub fn getParams(self: *const SelectBuilder) []const Parameter {
        return self.params.items;
    }
};

/// INSERT query builder
pub const InsertBuilder = struct {
    allocator: std.mem.Allocator,
    backend: Backend = .sqlite,

    table: ?[]const u8 = null,
    columns: std.ArrayListUnmanaged([]const u8) = .{},
    values: std.ArrayListUnmanaged(Value) = .{},
    returning: ?[]const u8 = null,
    on_conflict: OnConflict = .none,

    params: std.ArrayListUnmanaged(Parameter) = .{},
    param_index: usize = 1,

    pub const OnConflict = enum {
        none,
        ignore,
        replace,
        update,
    };

    pub fn init(allocator: std.mem.Allocator) InsertBuilder {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *InsertBuilder) void {
        self.columns.deinit(self.allocator);
        self.values.deinit(self.allocator);
        self.params.deinit(self.allocator);
    }

    pub fn into(self: *InsertBuilder, table: []const u8) *InsertBuilder {
        self.table = table;
        return self;
    }

    pub fn column(self: *InsertBuilder, col: []const u8, value: Value) *InsertBuilder {
        self.columns.append(self.allocator, col) catch {};
        self.values.append(self.allocator, value) catch {};
        self.params.append(self.allocator, .{
            .index = self.param_index,
            .value = value,
        }) catch {};
        self.param_index += 1;
        return self;
    }

    pub fn setReturning(self: *InsertBuilder, cols: []const u8) *InsertBuilder {
        self.returning = cols;
        return self;
    }

    pub fn setOnConflict(self: *InsertBuilder, action: OnConflict) *InsertBuilder {
        self.on_conflict = action;
        return self;
    }

    pub fn build(self: *const InsertBuilder, buf: []u8) ![]const u8 {
        var fbs = std.io.fixedBufferStream(buf);
        const writer = fbs.writer();

        // INSERT INTO
        switch (self.on_conflict) {
            .replace => try writer.writeAll("INSERT OR REPLACE INTO "),
            .ignore => try writer.writeAll("INSERT OR IGNORE INTO "),
            else => try writer.writeAll("INSERT INTO "),
        }

        if (self.table) |table| {
            try writer.writeAll(table);
        }

        // Columns
        if (self.columns.items.len > 0) {
            try writer.writeAll(" (");
            for (self.columns.items, 0..) |col, i| {
                if (i > 0) try writer.writeAll(", ");
                try writer.writeAll(col);
            }
            try writer.writeAll(")");
        }

        // VALUES
        try writer.writeAll(" VALUES (");
        for (self.values.items, 0..) |_, i| {
            if (i > 0) try writer.writeAll(", ");
            try writer.writeAll("?");
        }
        try writer.writeAll(")");

        // RETURNING
        if (self.returning) |ret| {
            try writer.writeAll(" RETURNING ");
            try writer.writeAll(ret);
        }

        return fbs.getWritten();
    }

    pub fn getParams(self: *const InsertBuilder) []const Parameter {
        return self.params.items;
    }
};

/// UPDATE query builder
pub const UpdateBuilder = struct {
    allocator: std.mem.Allocator,
    backend: Backend = .sqlite,

    table: ?[]const u8 = null,
    sets: std.ArrayListUnmanaged(struct { column: []const u8, value: Value }) = .{},
    conditions: std.ArrayListUnmanaged(Condition) = .{},
    returning: ?[]const u8 = null,

    params: std.ArrayListUnmanaged(Parameter) = .{},
    param_index: usize = 1,

    pub fn init(allocator: std.mem.Allocator) UpdateBuilder {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *UpdateBuilder) void {
        self.sets.deinit(self.allocator);
        self.conditions.deinit(self.allocator);
        self.params.deinit(self.allocator);
    }

    pub fn update(self: *UpdateBuilder, table: []const u8) *UpdateBuilder {
        self.table = table;
        return self;
    }

    pub fn set(self: *UpdateBuilder, column: []const u8, value: Value) *UpdateBuilder {
        self.sets.append(self.allocator, .{ .column = column, .value = value }) catch {};
        self.params.append(self.allocator, .{
            .index = self.param_index,
            .value = value,
        }) catch {};
        self.param_index += 1;
        return self;
    }

    pub fn where(self: *UpdateBuilder, column: []const u8, op: Operator, value: Value) *UpdateBuilder {
        self.conditions.append(self.allocator, .{
            .column = column,
            .operator = op,
            .value = value,
        }) catch {};
        self.params.append(self.allocator, .{
            .index = self.param_index,
            .value = value,
        }) catch {};
        self.param_index += 1;
        return self;
    }

    pub fn setReturning(self: *UpdateBuilder, cols: []const u8) *UpdateBuilder {
        self.returning = cols;
        return self;
    }

    pub fn build(self: *const UpdateBuilder, buf: []u8) ![]const u8 {
        var fbs = std.io.fixedBufferStream(buf);
        const writer = fbs.writer();

        try writer.writeAll("UPDATE ");
        if (self.table) |table| {
            try writer.writeAll(table);
        }

        // SET
        if (self.sets.items.len > 0) {
            try writer.writeAll(" SET ");
            for (self.sets.items, 0..) |s, i| {
                if (i > 0) try writer.writeAll(", ");
                try writer.writeAll(s.column);
                try writer.writeAll(" = ?");
            }
        }

        // WHERE
        if (self.conditions.items.len > 0) {
            try writer.writeAll(" WHERE ");
            for (self.conditions.items, 0..) |cond, i| {
                if (i > 0) {
                    try writer.writeAll(" ");
                    try writer.writeAll(cond.logical_op.toSql());
                    try writer.writeAll(" ");
                }
                try writer.writeAll(cond.column);
                try writer.writeAll(" ");
                try writer.writeAll(cond.operator.toSql());
                try writer.writeAll(" ?");
            }
        }

        // RETURNING
        if (self.returning) |ret| {
            try writer.writeAll(" RETURNING ");
            try writer.writeAll(ret);
        }

        return fbs.getWritten();
    }

    pub fn getParams(self: *const UpdateBuilder) []const Parameter {
        return self.params.items;
    }
};

/// DELETE query builder
pub const DeleteBuilder = struct {
    allocator: std.mem.Allocator,
    backend: Backend = .sqlite,

    table: ?[]const u8 = null,
    conditions: std.ArrayListUnmanaged(Condition) = .{},
    returning: ?[]const u8 = null,

    params: std.ArrayListUnmanaged(Parameter) = .{},
    param_index: usize = 1,

    pub fn init(allocator: std.mem.Allocator) DeleteBuilder {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *DeleteBuilder) void {
        self.conditions.deinit(self.allocator);
        self.params.deinit(self.allocator);
    }

    pub fn from(self: *DeleteBuilder, table: []const u8) *DeleteBuilder {
        self.table = table;
        return self;
    }

    pub fn where(self: *DeleteBuilder, column: []const u8, op: Operator, value: Value) *DeleteBuilder {
        self.conditions.append(self.allocator, .{
            .column = column,
            .operator = op,
            .value = value,
        }) catch {};
        self.params.append(self.allocator, .{
            .index = self.param_index,
            .value = value,
        }) catch {};
        self.param_index += 1;
        return self;
    }

    pub fn setReturning(self: *DeleteBuilder, cols: []const u8) *DeleteBuilder {
        self.returning = cols;
        return self;
    }

    pub fn build(self: *const DeleteBuilder, buf: []u8) ![]const u8 {
        var fbs = std.io.fixedBufferStream(buf);
        const writer = fbs.writer();

        try writer.writeAll("DELETE FROM ");
        if (self.table) |table| {
            try writer.writeAll(table);
        }

        // WHERE
        if (self.conditions.items.len > 0) {
            try writer.writeAll(" WHERE ");
            for (self.conditions.items, 0..) |cond, i| {
                if (i > 0) {
                    try writer.writeAll(" ");
                    try writer.writeAll(cond.logical_op.toSql());
                    try writer.writeAll(" ");
                }
                try writer.writeAll(cond.column);
                try writer.writeAll(" ");
                try writer.writeAll(cond.operator.toSql());
                try writer.writeAll(" ?");
            }
        }

        // RETURNING
        if (self.returning) |ret| {
            try writer.writeAll(" RETURNING ");
            try writer.writeAll(ret);
        }

        return fbs.getWritten();
    }

    pub fn getParams(self: *const DeleteBuilder) []const Parameter {
        return self.params.items;
    }
};

// Tests
test "SelectBuilder basic" {
    const allocator = std.testing.allocator;
    var builder = SelectBuilder.init(allocator);
    defer builder.deinit();

    _ = builder.selectAll().from("users");

    var buf: [1024]u8 = undefined;
    const sql = try builder.build(&buf);

    try std.testing.expect(std.mem.eql(u8, "SELECT * FROM users", sql));
}

test "SelectBuilder with WHERE" {
    const allocator = std.testing.allocator;
    var builder = SelectBuilder.init(allocator);
    defer builder.deinit();

    _ = builder.select(&.{ "id", "name" })
        .from("users")
        .where("id", .eq, .{ .integer = 1 });

    var buf: [1024]u8 = undefined;
    const sql = try builder.build(&buf);

    try std.testing.expect(std.mem.indexOf(u8, sql, "WHERE id = ?") != null);
}

test "SelectBuilder with JOIN" {
    const allocator = std.testing.allocator;
    var builder = SelectBuilder.init(allocator);
    defer builder.deinit();

    _ = builder.selectAll()
        .from("users")
        .innerJoin("orders", "users.id", "orders.user_id");

    var buf: [1024]u8 = undefined;
    const sql = try builder.build(&buf);

    try std.testing.expect(std.mem.indexOf(u8, sql, "INNER JOIN orders") != null);
}

test "InsertBuilder" {
    const allocator = std.testing.allocator;
    var builder = InsertBuilder.init(allocator);
    defer builder.deinit();

    _ = builder.into("users")
        .column("name", .{ .text = "John" })
        .column("email", .{ .text = "john@example.com" });

    var buf: [1024]u8 = undefined;
    const sql = try builder.build(&buf);

    try std.testing.expect(std.mem.indexOf(u8, sql, "INSERT INTO users") != null);
    try std.testing.expect(std.mem.indexOf(u8, sql, "(name, email)") != null);
}

test "UpdateBuilder" {
    const allocator = std.testing.allocator;
    var builder = UpdateBuilder.init(allocator);
    defer builder.deinit();

    _ = builder.update("users")
        .set("name", .{ .text = "Jane" })
        .where("id", .eq, .{ .integer = 1 });

    var buf: [1024]u8 = undefined;
    const sql = try builder.build(&buf);

    try std.testing.expect(std.mem.indexOf(u8, sql, "UPDATE users SET") != null);
}

test "DeleteBuilder" {
    const allocator = std.testing.allocator;
    var builder = DeleteBuilder.init(allocator);
    defer builder.deinit();

    _ = builder.from("users")
        .where("id", .eq, .{ .integer = 1 });

    var buf: [1024]u8 = undefined;
    const sql = try builder.build(&buf);

    try std.testing.expect(std.mem.indexOf(u8, sql, "DELETE FROM users") != null);
}

test "Operator toSql" {
    try std.testing.expect(std.mem.eql(u8, "=", Operator.eq.toSql()));
    try std.testing.expect(std.mem.eql(u8, "LIKE", Operator.like.toSql()));
    try std.testing.expect(std.mem.eql(u8, "IS NULL", Operator.is_null.toSql()));
}
