//! Taskmaster
//!
//! Advanced task management application with projects, priorities, and due dates.

const std = @import("std");
const app = @import("app.zig");
const ui = @import("ui.zig");

pub const AppState = app.AppState;
pub const ViewType = app.ViewType;
pub const Priority = app.Priority;
pub const FilterType = app.FilterType;
pub const SortType = app.SortType;
pub const Project = app.Project;
pub const Task = app.Task;
pub const VNode = ui.VNode;

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
    return ui.buildApp(app.getState());
}

// C ABI Exports
export fn app_init() void {
    init();
}

export fn app_deinit() void {
    deinit();
}

// View management
export fn app_set_view(view: u8) void {
    const max_view = @typeInfo(ViewType).@"enum".fields.len;
    if (view >= max_view) return;
    app.setView(@enumFromInt(view));
}

export fn app_get_view() u8 {
    return @intFromEnum(getState().current_view);
}

export fn app_set_filter(filter: u8) void {
    const max_filter = @typeInfo(FilterType).@"enum".fields.len;
    if (filter >= max_filter) return;
    app.setFilter(@enumFromInt(filter));
}

export fn app_set_sort(sort: u8) void {
    const max_sort = @typeInfo(SortType).@"enum".fields.len;
    if (sort >= max_sort) return;
    app.setSort(@enumFromInt(sort));
}

export fn app_toggle_show_completed() void {
    app.toggleShowCompleted();
}

// Project operations
export fn app_create_project() u32 {
    return app.createProject("New Project", 0xFF007AFF, "folder") orelse 0;
}

export fn app_select_project(id: u32) void {
    app.selectProject(if (id == 0) null else id);
}

export fn app_delete_project(id: u32) i32 {
    return if (app.deleteProject(id)) 1 else 0;
}

export fn app_archive_project(id: u32) i32 {
    return if (app.archiveProject(id)) 1 else 0;
}

export fn app_get_project_count() u32 {
    return @intCast(getState().project_count);
}

export fn app_get_selected_project() u32 {
    return getState().selected_project orelse 0;
}

// Task operations
export fn app_create_task(project_id: u32) u32 {
    return app.createTask(project_id, "New Task", .medium, 0) orelse 0;
}

export fn app_select_task(id: u32) void {
    app.selectTask(if (id == 0) null else id);
}

export fn app_toggle_task(id: u32) i32 {
    return if (app.toggleTask(id)) 1 else 0;
}

export fn app_set_task_priority(id: u32, priority: u8) i32 {
    const max_priority = @typeInfo(Priority).@"enum".fields.len;
    if (priority >= max_priority) return 0;
    return if (app.setTaskPriority(id, @enumFromInt(priority))) 1 else 0;
}

export fn app_set_task_due_date(id: u32, due_date: i64) i32 {
    return if (app.setTaskDueDate(id, due_date)) 1 else 0;
}

export fn app_delete_task(id: u32) i32 {
    return if (app.deleteTask(id)) 1 else 0;
}

export fn app_get_task_count() u32 {
    return @intCast(getState().task_count);
}

export fn app_get_selected_task() u32 {
    return getState().selected_task orelse 0;
}

// Stats
export fn app_get_total_tasks() u32 {
    return getState().total_tasks;
}

export fn app_get_completed_tasks() u32 {
    return getState().completed_tasks;
}

export fn app_get_overdue_tasks() u32 {
    return getState().overdue_tasks;
}

// Tests
test "initialization" {
    init();
    defer deinit();
    try std.testing.expect(getState().initialized);
    try std.testing.expect(getState().project_count > 0);
    try std.testing.expect(getState().task_count > 0);
}

test "view management" {
    init();
    defer deinit();
    app.setView(.board);
    try std.testing.expectEqual(ViewType.board, getState().current_view);
}

test "project operations" {
    init();
    defer deinit();
    const initial = getState().project_count;
    const id = app.createProject("Test", 0xFF0000, "star");
    try std.testing.expect(id != null);
    try std.testing.expectEqual(initial + 1, getState().project_count);
}

test "task operations" {
    init();
    defer deinit();
    const id = app.createTask(1, "Test Task", .urgent, 0);
    try std.testing.expect(id != null);
    try std.testing.expect(app.toggleTask(id.?));
}

test "render" {
    init();
    defer deinit();
    const view = render();
    try std.testing.expectEqual(ui.Tag.column, view.tag);
}
