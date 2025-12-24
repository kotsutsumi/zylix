//! Taskmaster - Application State

const std = @import("std");

pub const ViewType = enum(u8) {
    list = 0,
    board = 1,
    calendar = 2,

    pub fn title(self: ViewType) []const u8 {
        return switch (self) {
            .list => "List",
            .board => "Board",
            .calendar => "Calendar",
        };
    }

    pub fn icon(self: ViewType) []const u8 {
        return switch (self) {
            .list => "list.bullet",
            .board => "rectangle.split.3x1",
            .calendar => "calendar",
        };
    }
};

pub const Priority = enum(u8) {
    low = 0,
    medium = 1,
    high = 2,
    urgent = 3,

    pub fn name(self: Priority) []const u8 {
        return switch (self) {
            .low => "Low",
            .medium => "Medium",
            .high => "High",
            .urgent => "Urgent",
        };
    }

    pub fn color(self: Priority) u32 {
        return switch (self) {
            .low => 0xFF8E8E93,
            .medium => 0xFF007AFF,
            .high => 0xFFFF9500,
            .urgent => 0xFFFF3B30,
        };
    }
};

pub const FilterType = enum(u8) {
    all = 0,
    today = 1,
    upcoming = 2,
    completed = 3,
    priority_high = 4,

    pub fn name(self: FilterType) []const u8 {
        return switch (self) {
            .all => "All Tasks",
            .today => "Today",
            .upcoming => "Upcoming",
            .completed => "Completed",
            .priority_high => "High Priority",
        };
    }
};

pub const SortType = enum(u8) {
    created = 0,
    due_date = 1,
    priority = 2,
    alphabetical = 3,

    pub fn name(self: SortType) []const u8 {
        return switch (self) {
            .created => "Created",
            .due_date => "Due Date",
            .priority => "Priority",
            .alphabetical => "A-Z",
        };
    }
};

pub const Project = struct {
    id: u32 = 0,
    name: [64]u8 = [_]u8{0} ** 64,
    name_len: usize = 0,
    color: u32 = 0xFF007AFF,
    icon: [32]u8 = [_]u8{0} ** 32,
    icon_len: usize = 0,
    archived: bool = false,
};

pub const Task = struct {
    id: u32 = 0,
    project_id: u32 = 0,
    title: [128]u8 = [_]u8{0} ** 128,
    title_len: usize = 0,
    description: [256]u8 = [_]u8{0} ** 256,
    description_len: usize = 0,
    priority: Priority = .medium,
    due_date: i64 = 0,
    completed: bool = false,
    created_at: i64 = 0,
};

pub const max_projects = 20;
pub const max_tasks = 100;

pub const AppState = struct {
    initialized: bool = false,
    current_view: ViewType = .list,
    current_filter: FilterType = .all,
    current_sort: SortType = .created,

    // Projects
    projects: [max_projects]Project = undefined,
    project_count: usize = 0,
    selected_project: ?u32 = null,
    next_project_id: u32 = 1,

    // Tasks
    tasks: [max_tasks]Task = undefined,
    task_count: usize = 0,
    selected_task: ?u32 = null,
    next_task_id: u32 = 1,

    // Stats
    total_tasks: u32 = 0,
    completed_tasks: u32 = 0,
    overdue_tasks: u32 = 0,

    // UI state
    show_completed: bool = true,
    search_query: [64]u8 = [_]u8{0} ** 64,
    search_query_len: usize = 0,
};

var app_state: AppState = .{};

pub fn init() void {
    app_state = .{ .initialized = true };
    addSampleData();
    updateStats();
}

pub fn deinit() void {
    app_state.initialized = false;
}

pub fn getState() *const AppState {
    return &app_state;
}

fn addSampleData() void {
    // Create sample projects
    _ = createProject("Work", 0xFF007AFF, "briefcase");
    _ = createProject("Personal", 0xFF34C759, "person");
    _ = createProject("Shopping", 0xFFFF9500, "cart");

    // Create sample tasks
    _ = createTask(1, "Finish quarterly report", .high, 1700000000);
    _ = createTask(1, "Review team proposals", .medium, 1700086400);
    _ = createTask(1, "Schedule meeting with client", .urgent, 1699913600);
    _ = createTask(2, "Go to the gym", .medium, 0);
    _ = createTask(2, "Read a book", .low, 0);
    _ = createTask(3, "Buy groceries", .medium, 1700000000);
}

// View management
pub fn setView(view: ViewType) void {
    app_state.current_view = view;
}

pub fn setFilter(filter: FilterType) void {
    app_state.current_filter = filter;
}

pub fn setSort(sort: SortType) void {
    app_state.current_sort = sort;
}

pub fn toggleShowCompleted() void {
    app_state.show_completed = !app_state.show_completed;
}

// Project operations
pub fn createProject(name: []const u8, color: u32, icon: []const u8) ?u32 {
    if (app_state.project_count >= max_projects) return null;

    var project = &app_state.projects[app_state.project_count];
    project.id = app_state.next_project_id;

    const name_len = @min(name.len, project.name.len);
    @memcpy(project.name[0..name_len], name[0..name_len]);
    project.name_len = name_len;

    project.color = color;

    const icon_len = @min(icon.len, project.icon.len);
    @memcpy(project.icon[0..icon_len], icon[0..icon_len]);
    project.icon_len = icon_len;

    app_state.next_project_id += 1;
    app_state.project_count += 1;

    return project.id;
}

pub fn selectProject(id: ?u32) void {
    app_state.selected_project = id;
}

pub fn deleteProject(id: u32) bool {
    for (app_state.projects[0..app_state.project_count], 0..) |*project, i| {
        if (project.id == id) {
            // Delete all tasks in project
            deleteTasksInProject(id);

            // Shift remaining projects
            if (i < app_state.project_count - 1) {
                var j = i;
                while (j < app_state.project_count - 1) : (j += 1) {
                    app_state.projects[j] = app_state.projects[j + 1];
                }
            }
            app_state.project_count -= 1;

            if (app_state.selected_project == id) {
                app_state.selected_project = null;
            }
            updateStats();
            return true;
        }
    }
    return false;
}

pub fn archiveProject(id: u32) bool {
    for (app_state.projects[0..app_state.project_count]) |*project| {
        if (project.id == id) {
            project.archived = !project.archived;
            return true;
        }
    }
    return false;
}

fn deleteTasksInProject(project_id: u32) void {
    var i: usize = 0;
    while (i < app_state.task_count) {
        if (app_state.tasks[i].project_id == project_id) {
            // Shift remaining tasks
            var j = i;
            while (j < app_state.task_count - 1) : (j += 1) {
                app_state.tasks[j] = app_state.tasks[j + 1];
            }
            app_state.task_count -= 1;
        } else {
            i += 1;
        }
    }
}

// Task operations
pub fn createTask(project_id: u32, title: []const u8, priority: Priority, due_date: i64) ?u32 {
    if (app_state.task_count >= max_tasks) return null;

    var task = &app_state.tasks[app_state.task_count];
    task.id = app_state.next_task_id;
    task.project_id = project_id;

    const title_len = @min(title.len, task.title.len);
    @memcpy(task.title[0..title_len], title[0..title_len]);
    task.title_len = title_len;

    task.priority = priority;
    task.due_date = due_date;
    task.completed = false;
    task.created_at = 1700000000 + @as(i64, @intCast(app_state.task_count)) * 3600;

    app_state.next_task_id += 1;
    app_state.task_count += 1;

    updateStats();
    return task.id;
}

pub fn selectTask(id: ?u32) void {
    app_state.selected_task = id;
}

pub fn toggleTask(id: u32) bool {
    for (app_state.tasks[0..app_state.task_count]) |*task| {
        if (task.id == id) {
            task.completed = !task.completed;
            updateStats();
            return true;
        }
    }
    return false;
}

pub fn setTaskPriority(id: u32, priority: Priority) bool {
    for (app_state.tasks[0..app_state.task_count]) |*task| {
        if (task.id == id) {
            task.priority = priority;
            return true;
        }
    }
    return false;
}

pub fn setTaskDueDate(id: u32, due_date: i64) bool {
    for (app_state.tasks[0..app_state.task_count]) |*task| {
        if (task.id == id) {
            task.due_date = due_date;
            updateStats();
            return true;
        }
    }
    return false;
}

pub fn deleteTask(id: u32) bool {
    for (app_state.tasks[0..app_state.task_count], 0..) |*task, i| {
        if (task.id == id) {
            if (i < app_state.task_count - 1) {
                var j = i;
                while (j < app_state.task_count - 1) : (j += 1) {
                    app_state.tasks[j] = app_state.tasks[j + 1];
                }
            }
            app_state.task_count -= 1;

            if (app_state.selected_task == id) {
                app_state.selected_task = null;
            }
            updateStats();
            return true;
        }
    }
    return false;
}

// Stats
fn updateStats() void {
    app_state.total_tasks = @intCast(app_state.task_count);
    app_state.completed_tasks = 0;
    app_state.overdue_tasks = 0;

    const now: i64 = 1700000000; // Demo timestamp
    for (app_state.tasks[0..app_state.task_count]) |task| {
        if (task.completed) {
            app_state.completed_tasks += 1;
        } else if (task.due_date > 0 and task.due_date < now) {
            app_state.overdue_tasks += 1;
        }
    }
}

pub fn getProjectTaskCount(project_id: u32) u32 {
    var count: u32 = 0;
    for (app_state.tasks[0..app_state.task_count]) |task| {
        if (task.project_id == project_id) {
            count += 1;
        }
    }
    return count;
}

pub fn getProjectCompletedCount(project_id: u32) u32 {
    var count: u32 = 0;
    for (app_state.tasks[0..app_state.task_count]) |task| {
        if (task.project_id == project_id and task.completed) {
            count += 1;
        }
    }
    return count;
}

// Search
pub fn setSearchQuery(query: []const u8) void {
    const len = @min(query.len, app_state.search_query.len);
    @memcpy(app_state.search_query[0..len], query[0..len]);
    app_state.search_query_len = len;
}

pub fn clearSearch() void {
    app_state.search_query_len = 0;
}

// Tests
test "state init" {
    init();
    defer deinit();
    try std.testing.expect(app_state.initialized);
    try std.testing.expectEqual(ViewType.list, app_state.current_view);
    try std.testing.expect(app_state.project_count > 0);
    try std.testing.expect(app_state.task_count > 0);
}

test "create project" {
    init();
    defer deinit();
    const initial = app_state.project_count;
    const id = createProject("Test Project", 0xFF0000, "folder");
    try std.testing.expect(id != null);
    try std.testing.expectEqual(initial + 1, app_state.project_count);
}

test "create task" {
    init();
    defer deinit();
    const initial = app_state.task_count;
    const id = createTask(1, "Test Task", .high, 0);
    try std.testing.expect(id != null);
    try std.testing.expectEqual(initial + 1, app_state.task_count);
}

test "toggle task" {
    init();
    defer deinit();
    const task = &app_state.tasks[0];
    const initial_state = task.completed;
    try std.testing.expect(toggleTask(task.id));
    try std.testing.expectEqual(!initial_state, task.completed);
}

test "delete task" {
    init();
    defer deinit();
    const initial = app_state.task_count;
    const task_id = app_state.tasks[0].id;
    try std.testing.expect(deleteTask(task_id));
    try std.testing.expectEqual(initial - 1, app_state.task_count);
}

test "project task count" {
    init();
    defer deinit();
    const count = getProjectTaskCount(1);
    try std.testing.expect(count > 0);
}

test "view metadata" {
    try std.testing.expectEqualStrings("List", ViewType.list.title());
    try std.testing.expectEqualStrings("list.bullet", ViewType.list.icon());
}

test "priority metadata" {
    try std.testing.expectEqualStrings("High", Priority.high.name());
    try std.testing.expectEqual(@as(u32, 0xFFFF9500), Priority.high.color());
}
