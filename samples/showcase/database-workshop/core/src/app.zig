//! Database Workshop - Application State

const std = @import("std");

pub const WorkshopMode = enum(u32) {
    crud = 0,
    query = 1,
    transaction = 2,
    keyvalue = 3,
    import_export = 4,

    pub fn title(self: WorkshopMode) []const u8 {
        return switch (self) {
            .crud => "CRUD Operations",
            .query => "Query Builder",
            .transaction => "Transactions",
            .keyvalue => "Key-Value Store",
            .import_export => "Import/Export",
        };
    }

    pub fn description(self: WorkshopMode) []const u8 {
        return switch (self) {
            .crud => "Create, Read, Update, Delete records",
            .query => "Build and execute queries",
            .transaction => "Atomic batch operations",
            .keyvalue => "Simple key-value storage",
            .import_export => "Data backup and restore",
        };
    }

    pub fn icon(self: WorkshopMode) []const u8 {
        return switch (self) {
            .crud => "plus.circle",
            .query => "magnifyingglass",
            .transaction => "arrow.triangle.2.circlepath",
            .keyvalue => "key",
            .import_export => "arrow.up.arrow.down",
        };
    }
};

pub const SortOrder = enum(u8) {
    ascending = 0,
    descending = 1,
};

pub const ExportFormat = enum(u8) {
    json = 0,
    csv = 1,
};

pub const OperationStatus = enum(u8) {
    idle = 0,
    pending = 1,
    success = 2,
    error_status = 3,
};

pub const Record = struct {
    id: u32 = 0,
    name: [64]u8 = [_]u8{0} ** 64,
    name_len: usize = 0,
    email: [128]u8 = [_]u8{0} ** 128,
    email_len: usize = 0,
    age: u8 = 0,
    active: bool = true,
    created_at: i64 = 0,
    updated_at: i64 = 0,
};

pub const KVEntry = struct {
    key: [64]u8 = [_]u8{0} ** 64,
    key_len: usize = 0,
    value: [256]u8 = [_]u8{0} ** 256,
    value_len: usize = 0,
    expires_at: i64 = 0,
};

pub const QueryFilter = struct {
    field: [32]u8 = [_]u8{0} ** 32,
    field_len: usize = 0,
    value: [64]u8 = [_]u8{0} ** 64,
    value_len: usize = 0,
    active: bool = false,
};

pub const max_records = 100;
pub const max_kv_entries = 50;

pub const AppState = struct {
    initialized: bool = false,
    current_mode: WorkshopMode = .crud,

    // CRUD state
    records: [max_records]Record = undefined,
    record_count: usize = 0,
    selected_record: ?u32 = null,
    next_id: u32 = 1,

    // Query state
    filter: QueryFilter = .{},
    sort_field: [32]u8 = [_]u8{0} ** 32,
    sort_field_len: usize = 0,
    sort_order: SortOrder = .ascending,
    query_result_count: usize = 0,
    query_executed: bool = false,

    // Transaction state
    in_transaction: bool = false,
    transaction_operations: u32 = 0,
    transaction_start_count: usize = 0,

    // Key-value state
    kv_entries: [max_kv_entries]KVEntry = undefined,
    kv_count: usize = 0,
    selected_key: [64]u8 = [_]u8{0} ** 64,
    selected_key_len: usize = 0,

    // Import/Export state
    export_format: ExportFormat = .json,
    last_export_size: usize = 0,
    last_import_count: u32 = 0,

    // Operation status
    status: OperationStatus = .idle,
    status_message: [128]u8 = [_]u8{0} ** 128,
    status_message_len: usize = 0,
};

var app_state: AppState = .{};

pub fn init() void {
    app_state = .{ .initialized = true };
    // Add sample records
    addSampleData();
}

pub fn deinit() void {
    app_state.initialized = false;
}

pub fn getState() *const AppState {
    return &app_state;
}

pub fn selectMode(mode: WorkshopMode) void {
    app_state.current_mode = mode;
    app_state.status = .idle;
}

fn addSampleData() void {
    const names = [_][]const u8{ "Alice", "Bob", "Charlie", "Diana", "Eve" };
    const emails = [_][]const u8{ "alice@example.com", "bob@example.com", "charlie@example.com", "diana@example.com", "eve@example.com" };
    const ages = [_]u8{ 28, 34, 22, 45, 31 };

    for (names, emails, ages) |name, email, age| {
        _ = createRecord(name, email, age);
    }
}

// CRUD Operations
pub fn createRecord(name: []const u8, email: []const u8, age: u8) ?u32 {
    if (app_state.record_count >= max_records) {
        setStatus(.error_status, "Maximum records reached");
        return null;
    }

    var record = &app_state.records[app_state.record_count];
    record.id = app_state.next_id;

    const name_len = @min(name.len, record.name.len);
    @memcpy(record.name[0..name_len], name[0..name_len]);
    record.name_len = name_len;

    const email_len = @min(email.len, record.email.len);
    @memcpy(record.email[0..email_len], email[0..email_len]);
    record.email_len = email_len;

    record.age = age;
    record.active = true;
    record.created_at = 1700000000 + @as(i64, @intCast(app_state.record_count)) * 86400;
    record.updated_at = record.created_at;

    app_state.next_id += 1;
    app_state.record_count += 1;

    if (app_state.in_transaction) {
        app_state.transaction_operations += 1;
    }

    setStatus(.success, "Record created");
    return record.id;
}

pub fn readRecord(id: u32) ?*const Record {
    for (app_state.records[0..app_state.record_count]) |*record| {
        if (record.id == id) {
            app_state.selected_record = id;
            return record;
        }
    }
    setStatus(.error_status, "Record not found");
    return null;
}

pub fn updateRecord(id: u32, name: ?[]const u8, email: ?[]const u8, age: ?u8, active: ?bool) bool {
    for (app_state.records[0..app_state.record_count]) |*record| {
        if (record.id == id) {
            if (name) |n| {
                const len = @min(n.len, record.name.len);
                @memcpy(record.name[0..len], n[0..len]);
                record.name_len = len;
            }
            if (email) |e| {
                const len = @min(e.len, record.email.len);
                @memcpy(record.email[0..len], e[0..len]);
                record.email_len = len;
            }
            if (age) |a| record.age = a;
            if (active) |act| record.active = act;
            record.updated_at += 3600;

            if (app_state.in_transaction) {
                app_state.transaction_operations += 1;
            }

            setStatus(.success, "Record updated");
            return true;
        }
    }
    setStatus(.error_status, "Record not found");
    return false;
}

pub fn deleteRecord(id: u32) bool {
    for (app_state.records[0..app_state.record_count], 0..) |*record, i| {
        if (record.id == id) {
            // Shift remaining records
            if (i < app_state.record_count - 1) {
                var j = i;
                while (j < app_state.record_count - 1) : (j += 1) {
                    app_state.records[j] = app_state.records[j + 1];
                }
            }
            app_state.record_count -= 1;

            if (app_state.selected_record == id) {
                app_state.selected_record = null;
            }

            if (app_state.in_transaction) {
                app_state.transaction_operations += 1;
            }

            setStatus(.success, "Record deleted");
            return true;
        }
    }
    setStatus(.error_status, "Record not found");
    return false;
}

pub fn selectRecord(id: ?u32) void {
    app_state.selected_record = id;
}

// Query Operations
pub fn setFilter(field: []const u8, value: []const u8) void {
    const field_len = @min(field.len, app_state.filter.field.len);
    @memcpy(app_state.filter.field[0..field_len], field[0..field_len]);
    app_state.filter.field_len = field_len;

    const value_len = @min(value.len, app_state.filter.value.len);
    @memcpy(app_state.filter.value[0..value_len], value[0..value_len]);
    app_state.filter.value_len = value_len;

    app_state.filter.active = true;
}

pub fn setSort(field: []const u8, order: SortOrder) void {
    const len = @min(field.len, app_state.sort_field.len);
    @memcpy(app_state.sort_field[0..len], field[0..len]);
    app_state.sort_field_len = len;
    app_state.sort_order = order;
}

pub fn executeQuery() void {
    // In a real implementation, this would filter and sort records
    // For demo purposes, we just count matching records
    var count: usize = 0;
    const filter_value = app_state.filter.value[0..app_state.filter.value_len];

    for (app_state.records[0..app_state.record_count]) |record| {
        if (!app_state.filter.active) {
            count += 1;
            continue;
        }

        // Simple name filter
        const name = record.name[0..record.name_len];
        if (std.mem.indexOf(u8, name, filter_value) != null) {
            count += 1;
        }
    }

    app_state.query_result_count = count;
    app_state.query_executed = true;
    setStatus(.success, "Query executed");
}

pub fn clearQuery() void {
    app_state.filter = .{};
    app_state.sort_field_len = 0;
    app_state.query_executed = false;
    app_state.query_result_count = 0;
}

// Transaction Operations
// NOTE: This is a simplified demo implementation. Rollback only prevents
// new record creation by restoring record_count. A production implementation
// would require snapshotting the full records array at transaction start
// to properly revert updates and deletions.
pub fn beginTransaction() void {
    if (app_state.in_transaction) {
        setStatus(.error_status, "Already in transaction");
        return;
    }
    app_state.in_transaction = true;
    app_state.transaction_operations = 0;
    app_state.transaction_start_count = app_state.record_count;
    setStatus(.pending, "Transaction started");
}

pub fn commitTransaction() void {
    if (!app_state.in_transaction) {
        setStatus(.error_status, "No active transaction");
        return;
    }
    app_state.in_transaction = false;
    setStatus(.success, "Transaction committed");
}

pub fn rollbackTransaction() void {
    if (!app_state.in_transaction) {
        setStatus(.error_status, "No active transaction");
        return;
    }
    // Restore to transaction start state
    app_state.record_count = app_state.transaction_start_count;
    app_state.in_transaction = false;
    app_state.transaction_operations = 0;
    setStatus(.success, "Transaction rolled back");
}

// Key-Value Operations
pub fn kvSet(key: []const u8, value: []const u8) bool {
    // Check if key exists
    for (app_state.kv_entries[0..app_state.kv_count]) |*entry| {
        if (std.mem.eql(u8, entry.key[0..entry.key_len], key)) {
            const value_len = @min(value.len, entry.value.len);
            @memcpy(entry.value[0..value_len], value[0..value_len]);
            entry.value_len = value_len;
            setStatus(.success, "Value updated");
            return true;
        }
    }

    // Add new entry
    if (app_state.kv_count >= max_kv_entries) {
        setStatus(.error_status, "KV store full");
        return false;
    }

    var entry = &app_state.kv_entries[app_state.kv_count];
    const key_len = @min(key.len, entry.key.len);
    @memcpy(entry.key[0..key_len], key[0..key_len]);
    entry.key_len = key_len;

    const value_len = @min(value.len, entry.value.len);
    @memcpy(entry.value[0..value_len], value[0..value_len]);
    entry.value_len = value_len;

    app_state.kv_count += 1;
    setStatus(.success, "Value set");
    return true;
}

pub fn kvGet(key: []const u8) ?[]const u8 {
    for (app_state.kv_entries[0..app_state.kv_count]) |*entry| {
        if (std.mem.eql(u8, entry.key[0..entry.key_len], key)) {
            return entry.value[0..entry.value_len];
        }
    }
    return null;
}

pub fn kvDelete(key: []const u8) bool {
    for (app_state.kv_entries[0..app_state.kv_count], 0..) |*entry, i| {
        if (std.mem.eql(u8, entry.key[0..entry.key_len], key)) {
            if (i < app_state.kv_count - 1) {
                var j = i;
                while (j < app_state.kv_count - 1) : (j += 1) {
                    app_state.kv_entries[j] = app_state.kv_entries[j + 1];
                }
            }
            app_state.kv_count -= 1;
            setStatus(.success, "Key deleted");
            return true;
        }
    }
    setStatus(.error_status, "Key not found");
    return false;
}

pub fn selectKey(key: []const u8) void {
    const len = @min(key.len, app_state.selected_key.len);
    @memcpy(app_state.selected_key[0..len], key[0..len]);
    app_state.selected_key_len = len;
}

// Import/Export Operations
pub fn setExportFormat(format: ExportFormat) void {
    app_state.export_format = format;
}

pub fn exportData() void {
    // Simulate export size calculation
    const base_size: usize = switch (app_state.export_format) {
        .json => 50, // JSON overhead per record
        .csv => 30, // CSV overhead per record
    };
    app_state.last_export_size = app_state.record_count * base_size;
    setStatus(.success, "Data exported");
}

pub fn importData(count: u32) void {
    app_state.last_import_count = count;
    setStatus(.success, "Data imported");
}

// Status helpers
fn setStatus(status: OperationStatus, message: []const u8) void {
    app_state.status = status;
    const len = @min(message.len, app_state.status_message.len);
    @memcpy(app_state.status_message[0..len], message[0..len]);
    app_state.status_message_len = len;
}

// Tests
test "state init" {
    init();
    defer deinit();
    try std.testing.expect(app_state.initialized);
    try std.testing.expectEqual(WorkshopMode.crud, app_state.current_mode);
    try std.testing.expect(app_state.record_count > 0); // Sample data
}

test "create record" {
    init();
    defer deinit();
    const initial_count = app_state.record_count;
    const id = createRecord("Test", "test@example.com", 25);
    try std.testing.expect(id != null);
    try std.testing.expectEqual(initial_count + 1, app_state.record_count);
}

test "read record" {
    init();
    defer deinit();
    const record = readRecord(1);
    try std.testing.expect(record != null);
    try std.testing.expectEqual(@as(u32, 1), record.?.id);
}

test "update record" {
    init();
    defer deinit();
    const success = updateRecord(1, "Updated", null, null, null);
    try std.testing.expect(success);
    const record = readRecord(1);
    try std.testing.expectEqualStrings("Updated", record.?.name[0..record.?.name_len]);
}

test "delete record" {
    init();
    defer deinit();
    const initial_count = app_state.record_count;
    const success = deleteRecord(1);
    try std.testing.expect(success);
    try std.testing.expectEqual(initial_count - 1, app_state.record_count);
}

test "transaction flow" {
    init();
    defer deinit();
    beginTransaction();
    try std.testing.expect(app_state.in_transaction);
    _ = createRecord("TxTest", "tx@test.com", 30);
    commitTransaction();
    try std.testing.expect(!app_state.in_transaction);
}

test "transaction rollback" {
    init();
    defer deinit();
    const initial_count = app_state.record_count;
    beginTransaction();
    _ = createRecord("RollbackTest", "rollback@test.com", 30);
    rollbackTransaction();
    try std.testing.expectEqual(initial_count, app_state.record_count);
}

test "kv operations" {
    init();
    defer deinit();
    try std.testing.expect(kvSet("testkey", "testvalue"));
    const value = kvGet("testkey");
    try std.testing.expect(value != null);
    try std.testing.expectEqualStrings("testvalue", value.?);
    try std.testing.expect(kvDelete("testkey"));
    try std.testing.expect(kvGet("testkey") == null);
}

test "query execution" {
    init();
    defer deinit();
    setFilter("name", "Alice");
    executeQuery();
    try std.testing.expect(app_state.query_executed);
    try std.testing.expect(app_state.query_result_count > 0);
}

test "mode metadata" {
    try std.testing.expectEqualStrings("CRUD Operations", WorkshopMode.crud.title());
    try std.testing.expectEqualStrings("plus.circle", WorkshopMode.crud.icon());
}
