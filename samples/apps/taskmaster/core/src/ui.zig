//! Taskmaster - UI Components

const std = @import("std");
const app = @import("app.zig");

pub const Tag = enum {
    column,
    row,
    div,
    text,
    button,
    scroll,
    icon,
    checkbox,
    spacer,
};

pub const Alignment = enum { start, center, end, stretch };
pub const Justify = enum { start, center, end, space_between, space_around };

pub const Spacing = struct {
    top: f32 = 0,
    right: f32 = 0,
    bottom: f32 = 0,
    left: f32 = 0,

    pub fn all(v: f32) Spacing {
        return .{ .top = v, .right = v, .bottom = v, .left = v };
    }

    pub fn symmetric(h: f32, v: f32) Spacing {
        return .{ .top = v, .right = h, .bottom = v, .left = h };
    }
};

pub const Style = struct {
    padding: Spacing = .{},
    margin: Spacing = .{},
    background: u32 = 0,
    border_radius: f32 = 0,
    font_size: f32 = 14,
    font_weight: u16 = 400,
    color: u32 = Color.text,
    alignment: Alignment = .start,
    justify: Justify = .start,
    gap: f32 = 0,
    flex: f32 = 0,
    width: f32 = 0,
    height: f32 = 0,
};

pub const Color = struct {
    pub const background: u32 = 0xFF000000;
    pub const surface: u32 = 0xFF1C1C1E;
    pub const card: u32 = 0xFF2C2C2E;
    pub const text: u32 = 0xFFFFFFFF;
    pub const text_secondary: u32 = 0xFF8E8E93;
    pub const primary: u32 = 0xFF007AFF;
    pub const success: u32 = 0xFF34C759;
    pub const warning: u32 = 0xFFFF9500;
    pub const error_color: u32 = 0xFFFF3B30;
    pub const completed: u32 = 0xFF48484A;
};

pub const Props = struct {
    style: Style = .{},
    on_press: ?*const fn () void = null,
    text: []const u8 = "",
    icon: []const u8 = "",
    checked: bool = false,
};

pub const VNode = struct {
    tag: Tag,
    props: Props,
    children: []const VNode,
};

// Component constructors
fn column(props: Props, children: []const VNode) VNode {
    return .{ .tag = .column, .props = props, .children = children };
}

fn row(props: Props, children: []const VNode) VNode {
    return .{ .tag = .row, .props = props, .children = children };
}

fn div(props: Props, children: []const VNode) VNode {
    return .{ .tag = .div, .props = props, .children = children };
}

fn text(content: []const u8, props: Props) VNode {
    var p = props;
    p.text = content;
    return .{ .tag = .text, .props = p, .children = &.{} };
}

fn button(label: []const u8, props: Props) VNode {
    var p = props;
    p.text = label;
    return .{ .tag = .button, .props = p, .children = &.{} };
}

fn iconView(name: []const u8, props: Props) VNode {
    var p = props;
    p.icon = name;
    return .{ .tag = .icon, .props = p, .children = &.{} };
}

fn checkbox(checked: bool, props: Props) VNode {
    var p = props;
    p.checked = checked;
    return .{ .tag = .checkbox, .props = p, .children = &.{} };
}

fn scroll(props: Props, children: []const VNode) VNode {
    return .{ .tag = .scroll, .props = props, .children = children };
}

fn spacer() VNode {
    return .{ .tag = .spacer, .props = .{ .style = .{ .flex = 1 } }, .children = &.{} };
}

// Main app builder
pub fn buildApp(state: *const app.AppState) VNode {
    const S = struct {
        var content: [3]VNode = undefined;
    };

    S.content[0] = buildHeader(state);
    S.content[1] = buildViewTabs(state);
    S.content[2] = buildMainContent(state);

    return column(.{
        .style = .{
            .background = Color.background,
            .padding = Spacing.all(16),
            .gap = 16,
        },
    }, &S.content);
}

fn buildHeader(state: *const app.AppState) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
        var stats_buf: [64]u8 = undefined;
    };

    const stats_str = std.fmt.bufPrint(&S.stats_buf, "{d}/{d} completed", .{
        state.completed_tasks,
        state.total_tasks,
    }) catch "0/0 completed";

    S.items[0] = text("Taskmaster", .{
        .style = .{
            .font_size = 32,
            .font_weight = 700,
            .color = Color.text,
        },
    });
    S.items[1] = spacer();
    S.items[2] = text(stats_str, .{
        .style = .{
            .font_size = 14,
            .color = Color.text_secondary,
        },
    });

    return row(.{ .style = .{ .alignment = .center } }, &S.items);
}

fn buildViewTabs(state: *const app.AppState) VNode {
    const views = [_]app.ViewType{ .list, .board, .calendar };
    const S = struct {
        var items: [3]VNode = undefined;
    };

    for (views, 0..) |view, i| {
        S.items[i] = buildViewTab(view, state.current_view == view);
    }

    return row(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(4),
            .gap = 4,
        },
    }, &S.items);
}

fn buildViewTab(view: app.ViewType, selected: bool) VNode {
    const bg = if (selected) Color.primary else 0;
    const text_color = if (selected) Color.text else Color.text_secondary;

    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = iconView(view.icon(), .{
        .style = .{ .color = text_color, .font_size = 16 },
    });
    S.items[1] = text(view.title(), .{
        .style = .{ .font_size = 13, .color = text_color },
    });

    return row(.{
        .style = .{
            .padding = Spacing.symmetric(16, 10),
            .background = bg,
            .border_radius = 8,
            .gap = 6,
            .alignment = .center,
            .flex = 1,
            .justify = .center,
        },
    }, &S.items);
}

fn buildMainContent(state: *const app.AppState) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = buildSidebar(state);
    S.items[1] = buildTaskList(state);

    return row(.{ .style = .{ .gap = 16, .flex = 1 } }, &S.items);
}

fn buildSidebar(state: *const app.AppState) VNode {
    const max_display = 5;
    const display_count = @min(state.project_count, max_display);

    const S = struct {
        var items: [max_display + 2]VNode = undefined;
    };

    S.items[0] = text("Projects", .{
        .style = .{ .font_size = 14, .font_weight = 600, .color = Color.text_secondary },
    });

    for (0..display_count) |i| {
        const project = &state.projects[i];
        const selected = state.selected_project == project.id;
        S.items[i + 1] = buildProjectItem(project, selected);
    }

    S.items[display_count + 1] = button("+ New Project", .{
        .style = .{
            .background = Color.card,
            .padding = Spacing.symmetric(12, 10),
            .border_radius = 8,
            .color = Color.primary,
        },
    });

    return div(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(12),
            .gap = 8,
            .width = 180,
        },
    }, S.items[0 .. display_count + 2]);
}

fn buildProjectItem(project: *const app.Project, selected: bool) VNode {
    const bg = if (selected) Color.card else 0;

    const S = struct {
        var items: [3]VNode = undefined;
        var count_buf: [8]u8 = undefined;
    };

    const task_count = app.getProjectTaskCount(project.id);
    const count_str = std.fmt.bufPrint(&S.count_buf, "{d}", .{task_count}) catch "0";

    S.items[0] = div(.{
        .style = .{
            .background = project.color,
            .width = 8,
            .height = 8,
            .border_radius = 4,
        },
    }, &.{});
    S.items[1] = text(project.name[0..project.name_len], .{
        .style = .{ .font_size = 14, .color = Color.text, .flex = 1 },
    });
    S.items[2] = text(count_str, .{
        .style = .{ .font_size = 12, .color = Color.text_secondary },
    });

    return row(.{
        .style = .{
            .background = bg,
            .border_radius = 8,
            .padding = Spacing.symmetric(10, 8),
            .gap = 8,
            .alignment = .center,
        },
    }, &S.items);
}

fn buildTaskList(state: *const app.AppState) VNode {
    const max_display = 8;
    var display_count: usize = 0;

    const S = struct {
        var items: [max_display + 1]VNode = undefined;
    };

    S.items[0] = buildFilterBar(state);

    // Filter tasks based on selected project
    for (state.tasks[0..state.task_count]) |*task| {
        if (display_count >= max_display) break;

        // Filter by project if one is selected
        if (state.selected_project) |project_id| {
            if (task.project_id != project_id) continue;
        }

        // Filter by completion state
        if (!state.show_completed and task.completed) continue;

        S.items[display_count + 1] = buildTaskItem(task);
        display_count += 1;
    }

    return div(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(12),
            .gap = 8,
            .flex = 1,
        },
    }, S.items[0 .. display_count + 1]);
}

fn buildFilterBar(state: *const app.AppState) VNode {
    const S = struct {
        var items: [4]VNode = undefined;
    };

    S.items[0] = text(state.current_filter.name(), .{
        .style = .{ .font_size = 16, .font_weight = 600, .color = Color.text },
    });
    S.items[1] = spacer();
    S.items[2] = button(state.current_sort.name(), .{
        .style = .{
            .background = Color.card,
            .padding = Spacing.symmetric(12, 6),
            .border_radius = 6,
            .font_size = 12,
        },
    });
    S.items[3] = button("+ Task", .{
        .style = .{
            .background = Color.primary,
            .padding = Spacing.symmetric(12, 6),
            .border_radius = 6,
            .font_size = 12,
        },
    });

    return row(.{ .style = .{ .gap = 8, .alignment = .center } }, &S.items);
}

fn buildTaskItem(task: *const app.Task) VNode {
    const bg = if (task.completed) Color.completed else Color.card;
    const text_color = if (task.completed) Color.text_secondary else Color.text;

    const S = struct {
        var items: [4]VNode = undefined;
    };

    S.items[0] = checkbox(task.completed, .{
        .style = .{ .color = Color.primary },
    });
    S.items[1] = text(task.title[0..task.title_len], .{
        .style = .{ .font_size = 14, .color = text_color, .flex = 1 },
    });
    S.items[2] = buildPriorityBadge(task.priority);
    S.items[3] = buildDueDateBadge(task.due_date, task.completed);

    return row(.{
        .style = .{
            .background = bg,
            .border_radius = 10,
            .padding = Spacing.symmetric(12, 10),
            .gap = 10,
            .alignment = .center,
        },
    }, &S.items);
}

fn buildPriorityBadge(priority: app.Priority) VNode {
    if (priority == .low) {
        return div(.{}, &.{});
    }

    return div(.{
        .style = .{
            .background = priority.color(),
            .padding = Spacing.symmetric(8, 4),
            .border_radius = 4,
        },
    }, &.{
        text(priority.name(), .{
            .style = .{ .font_size = 10, .color = Color.text },
        }),
    });
}

fn buildDueDateBadge(due_date: i64, completed: bool) VNode {
    if (due_date == 0 or completed) {
        return div(.{}, &.{});
    }

    const S = struct {
        var items: [2]VNode = undefined;
    };

    const now: i64 = 1700000000;
    const is_overdue = due_date < now;
    const badge_color = if (is_overdue) Color.error_color else Color.text_secondary;

    S.items[0] = iconView("calendar", .{
        .style = .{ .color = badge_color, .font_size = 12 },
    });
    S.items[1] = text(if (is_overdue) "Overdue" else "Due", .{
        .style = .{ .font_size = 11, .color = badge_color },
    });

    return row(.{ .style = .{ .gap = 4, .alignment = .center } }, &S.items);
}

// Tests
test "build app" {
    app.init();
    defer app.deinit();
    const view = buildApp(app.getState());
    try std.testing.expectEqual(Tag.column, view.tag);
}
