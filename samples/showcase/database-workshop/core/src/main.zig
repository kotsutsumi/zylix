//! Database Workshop Showcase
//!
//! Demonstration of Zylix database and persistence capabilities.

const std = @import("std");
const app = @import("app.zig");
const workshop = @import("workshop.zig");

pub const AppState = app.AppState;
pub const WorkshopMode = app.WorkshopMode;
pub const Record = app.Record;
pub const KVEntry = app.KVEntry;
pub const SortOrder = app.SortOrder;
pub const ExportFormat = app.ExportFormat;
pub const OperationStatus = app.OperationStatus;
pub const VNode = workshop.VNode;

pub fn init() void {
    app.init();
}

pub fn deinit() void {
    app.deinit();
}

pub fn getState() *const AppState {
    return app.getState();
}

pub fn render() VNode {
    return workshop.buildApp(app.getState());
}

// C ABI Exports
export fn app_init() void {
    init();
}

export fn app_deinit() void {
    deinit();
}

export fn app_select_mode(mode: u32) void {
    const max_mode = @typeInfo(WorkshopMode).@"enum".fields.len;
    if (mode >= max_mode) return;
    app.selectMode(@enumFromInt(mode));
}

// CRUD exports
export fn app_create_record() u32 {
    const id = app.createRecord("New Record", "new@example.com", 25);
    return id orelse 0;
}

export fn app_select_record(id: u32) void {
    app.selectRecord(if (id == 0) null else id);
}

export fn app_update_record_active(id: u32, active: u8) i32 {
    return if (app.updateRecord(id, null, null, null, active != 0)) 1 else 0;
}

export fn app_delete_record(id: u32) i32 {
    return if (app.deleteRecord(id)) 1 else 0;
}

export fn app_get_record_count() u32 {
    return @intCast(getState().record_count);
}

export fn app_get_selected_record() u32 {
    return getState().selected_record orelse 0;
}

// Query exports
export fn app_execute_query() void {
    app.executeQuery();
}

export fn app_clear_query() void {
    app.clearQuery();
}

export fn app_get_query_result_count() u32 {
    return @intCast(getState().query_result_count);
}

export fn app_is_query_executed() i32 {
    return if (getState().query_executed) 1 else 0;
}

// Transaction exports
export fn app_begin_transaction() void {
    app.beginTransaction();
}

export fn app_commit_transaction() void {
    app.commitTransaction();
}

export fn app_rollback_transaction() void {
    app.rollbackTransaction();
}

export fn app_is_in_transaction() i32 {
    return if (getState().in_transaction) 1 else 0;
}

export fn app_get_transaction_operations() u32 {
    return getState().transaction_operations;
}

// Key-value exports
export fn app_kv_set_demo() i32 {
    return if (app.kvSet("demo_key", "demo_value")) 1 else 0;
}

export fn app_kv_delete_demo() i32 {
    return if (app.kvDelete("demo_key")) 1 else 0;
}

export fn app_kv_get_count() u32 {
    return @intCast(getState().kv_count);
}

// Import/Export exports
export fn app_set_export_format(format: u8) void {
    const max_format = @typeInfo(ExportFormat).@"enum".fields.len;
    if (format >= max_format) return;
    app.setExportFormat(@enumFromInt(format));
}

export fn app_export_data() void {
    app.exportData();
}

export fn app_import_data(count: u32) void {
    app.importData(count);
}

export fn app_get_last_export_size() u32 {
    return @intCast(getState().last_export_size);
}

export fn app_get_status() u8 {
    return @intFromEnum(getState().status);
}

// Tests
test "initialization" {
    init();
    defer deinit();
    try std.testing.expect(getState().initialized);
    try std.testing.expectEqual(WorkshopMode.crud, getState().current_mode);
    try std.testing.expect(getState().record_count > 0);
}

test "mode selection" {
    init();
    defer deinit();
    app.selectMode(.transaction);
    try std.testing.expectEqual(WorkshopMode.transaction, getState().current_mode);
}

test "crud operations" {
    init();
    defer deinit();
    const initial = getState().record_count;
    const id = app.createRecord("Test", "test@test.com", 30);
    try std.testing.expect(id != null);
    try std.testing.expectEqual(initial + 1, getState().record_count);
    try std.testing.expect(app.deleteRecord(id.?));
    try std.testing.expectEqual(initial, getState().record_count);
}

test "transaction workflow" {
    init();
    defer deinit();
    app.beginTransaction();
    try std.testing.expect(getState().in_transaction);
    _ = app.createRecord("TxRecord", "tx@test.com", 25);
    app.commitTransaction();
    try std.testing.expect(!getState().in_transaction);
}

test "kv operations" {
    init();
    defer deinit();
    try std.testing.expect(app.kvSet("key1", "value1"));
    try std.testing.expect(app.kvGet("key1") != null);
    try std.testing.expect(app.kvDelete("key1"));
}

test "render" {
    init();
    defer deinit();
    const view = render();
    try std.testing.expectEqual(workshop.Tag.column, view.tag);
}
