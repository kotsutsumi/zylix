//! Fit Track - UI Components

const std = @import("std");
const app = @import("app.zig");

pub const Tag = enum { column, row, div, text, button, scroll, icon, ring, chart };

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
    background: u32 = 0,
    border_radius: f32 = 0,
    font_size: f32 = 14,
    font_weight: u16 = 400,
    color: u32 = Color.text,
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
    pub const red: u32 = 0xFFFF3B30;
    pub const green: u32 = 0xFF34C759;
    pub const blue: u32 = 0xFF007AFF;
    pub const orange: u32 = 0xFFFF9500;
};

pub const Props = struct {
    style: Style = .{},
    text: []const u8 = "",
    icon: []const u8 = "",
};

pub const VNode = struct {
    tag: Tag,
    props: Props,
    children: []const VNode,
};

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
fn iconView(name: []const u8, props: Props) VNode {
    var p = props;
    p.icon = name;
    return .{ .tag = .icon, .props = p, .children = &.{} };
}
fn spacer() VNode {
    return .{ .tag = .div, .props = .{ .style = .{ .flex = 1 } }, .children = &.{} };
}

pub fn buildApp(state: *const app.AppState) VNode {
    const S = struct {
        var content: [3]VNode = undefined;
    };

    S.content[0] = buildHeader(state);
    S.content[1] = buildContent(state);
    S.content[2] = buildTabBar(state);

    return column(.{
        .style = .{ .background = Color.background },
    }, &S.content);
}

fn buildHeader(state: *const app.AppState) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
    };

    S.items[0] = text(state.current_screen.title(), .{
        .style = .{ .font_size = 28, .font_weight = 700, .color = Color.text },
    });
    S.items[1] = spacer();
    S.items[2] = iconView("person.circle", .{ .style = .{ .color = Color.text, .font_size = 28 } });

    return row(.{
        .style = .{ .padding = Spacing.symmetric(16, 12) },
    }, &S.items);
}

fn buildContent(state: *const app.AppState) VNode {
    return switch (state.current_screen) {
        .dashboard => buildDashboardScreen(state),
        .workouts => buildWorkoutsScreen(state),
        .progress => buildProgressScreen(state),
        .profile => buildProfileScreen(state),
    };
}

fn buildDashboardScreen(state: *const app.AppState) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
    };

    S.items[0] = buildActivityRings(state);
    S.items[1] = buildStatsGrid(state);
    S.items[2] = buildRecentWorkouts(state);

    return column(.{
        .style = .{ .padding = Spacing.all(16), .gap = 16, .flex = 1 },
    }, &S.items);
}

fn buildActivityRings(state: *const app.AppState) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
        var steps_buf: [16]u8 = undefined;
        var goal_buf: [16]u8 = undefined;
    };

    const steps_str = std.fmt.bufPrint(&S.steps_buf, "{d}", .{state.today.steps}) catch "0";
    const goal_str = std.fmt.bufPrint(&S.goal_buf, "/{d}", .{state.goal.steps}) catch "/10000";

    S.items[0] = div(.{
        .style = .{ .background = Color.surface, .width = 160, .height = 160, .border_radius = 80 },
    }, &.{
        column(.{ .style = .{ .padding = Spacing.all(40), .gap = 4 } }, &.{
            iconView("flame.fill", .{ .style = .{ .color = Color.red, .font_size = 24 } }),
            text(steps_str, .{ .style = .{ .font_size = 28, .font_weight = 700, .color = Color.text } }),
            text(goal_str, .{ .style = .{ .font_size = 14, .color = Color.text_secondary } }),
        }),
    });

    S.items[1] = column(.{ .style = .{ .gap = 8, .flex = 1 } }, &.{
        buildRingLegend("Move", Color.red, state.today.calories_burned, state.goal.calories),
        buildRingLegend("Exercise", Color.green, state.today.active_minutes, state.goal.active_minutes),
        buildRingLegend("Stand", Color.blue, 10, 12),
    });

    return row(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 16,
            .padding = Spacing.all(20),
            .gap = 24,
        },
    }, &S.items);
}

fn buildRingLegend(label: []const u8, color: u32, current: u32, goal: u32) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
        var value_buf: [16]u8 = undefined;
    };

    const value_str = std.fmt.bufPrint(&S.value_buf, "{d}/{d}", .{ current, goal }) catch "0/0";

    S.items[0] = div(.{ .style = .{ .background = color, .width = 12, .height = 12, .border_radius = 6 } }, &.{});
    S.items[1] = text(label, .{ .style = .{ .font_size = 14, .color = Color.text, .flex = 1 } });
    S.items[2] = text(value_str, .{ .style = .{ .font_size = 14, .color = Color.text_secondary } });

    return row(.{ .style = .{ .gap = 8 } }, &S.items);
}

fn buildStatsGrid(state: *const app.AppState) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = buildStatCard("Steps", state.today.steps, "figure.walk", Color.green);
    S.items[1] = buildStatCard("Calories", state.today.calories_burned, "flame.fill", Color.orange);

    return row(.{ .style = .{ .gap = 12 } }, &S.items);
}

fn buildStatCard(label: []const u8, value: u32, icon_name: []const u8, color: u32) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
        var value_buf: [16]u8 = undefined;
    };

    const value_str = std.fmt.bufPrint(&S.value_buf, "{d}", .{value}) catch "0";

    S.items[0] = iconView(icon_name, .{ .style = .{ .color = color, .font_size = 24 } });
    S.items[1] = text(value_str, .{ .style = .{ .font_size = 24, .font_weight = 700, .color = Color.text } });
    S.items[2] = text(label, .{ .style = .{ .font_size = 14, .color = Color.text_secondary } });

    return div(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(16),
            .gap = 8,
            .flex = 1,
        },
    }, &S.items);
}

fn buildRecentWorkouts(state: *const app.AppState) VNode {
    const max_display: usize = 3;
    const workout_count: usize = state.workout_count;
    const display_count: usize = @min(workout_count, max_display);

    const S = struct {
        var items: [4]VNode = undefined; // max_display + 1
    };

    S.items[0] = text("Recent Workouts", .{
        .style = .{ .font_size = 18, .font_weight = 600, .color = Color.text },
    });

    for (0..display_count) |i| {
        const idx = workout_count - 1 - i;
        S.items[i + 1] = buildWorkoutItem(&state.workouts[idx]);
    }

    const slice_end = display_count + 1;
    return div(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(16),
            .gap = 12,
        },
    }, S.items[0..slice_end]);
}

fn buildWorkoutItem(workout: *const app.Workout) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
        var dur_buf: [16]u8 = undefined;
        var cal_buf: [16]u8 = undefined;
    };

    const dur_str = std.fmt.bufPrint(&S.dur_buf, "{d} min", .{workout.duration}) catch "0 min";
    const cal_str = std.fmt.bufPrint(&S.cal_buf, "{d} kcal", .{workout.calories}) catch "0 kcal";

    S.items[0] = iconView(workout.workout_type.icon(), .{
        .style = .{ .color = workout.workout_type.color(), .font_size = 24 },
    });
    S.items[1] = column(.{ .style = .{ .flex = 1, .gap = 2 } }, &.{
        text(workout.workout_type.name(), .{ .style = .{ .font_size = 16, .color = Color.text } }),
        text(dur_str, .{ .style = .{ .font_size = 14, .color = Color.text_secondary } }),
    });
    S.items[2] = text(cal_str, .{ .style = .{ .font_size = 14, .color = Color.text_secondary } });

    return row(.{ .style = .{ .gap = 12 } }, &S.items);
}

fn buildWorkoutsScreen(state: *const app.AppState) VNode {
    _ = state;
    const S = struct {
        var items: [4]VNode = undefined;
    };

    S.items[0] = text("Quick Start", .{
        .style = .{ .font_size = 18, .font_weight = 600, .color = Color.text },
    });
    S.items[1] = buildWorkoutTypeButton(.running);
    S.items[2] = buildWorkoutTypeButton(.cycling);
    S.items[3] = buildWorkoutTypeButton(.strength);

    return column(.{
        .style = .{ .padding = Spacing.all(16), .gap = 12, .flex = 1 },
    }, &S.items);
}

fn buildWorkoutTypeButton(workout_type: app.WorkoutType) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = iconView(workout_type.icon(), .{ .style = .{ .color = workout_type.color(), .font_size = 32 } });
    S.items[1] = text(workout_type.name(), .{ .style = .{ .font_size = 16, .color = Color.text } });

    return row(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(16),
            .gap = 16,
        },
    }, &S.items);
}

fn buildProgressScreen(state: *const app.AppState) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
        var streak_buf: [16]u8 = undefined;
        var avg_buf: [16]u8 = undefined;
    };

    const streak_str = std.fmt.bufPrint(&S.streak_buf, "{d} days", .{state.current_streak}) catch "0 days";
    const avg_str = std.fmt.bufPrint(&S.avg_buf, "{d} avg", .{app.getWeeklyAverage()}) catch "0 avg";

    S.items[0] = text("This Week", .{
        .style = .{ .font_size = 18, .font_weight = 600, .color = Color.text },
    });
    S.items[1] = div(.{
        .style = .{ .background = Color.surface, .border_radius = 12, .padding = Spacing.all(16), .height = 150 },
    }, &.{
        text("Weekly chart", .{ .style = .{ .color = Color.text_secondary } }),
    });
    S.items[2] = row(.{ .style = .{ .gap = 12 } }, &.{
        buildProgressStat("Streak", streak_str, Color.orange),
        buildProgressStat("Steps", avg_str, Color.green),
    });

    return column(.{
        .style = .{ .padding = Spacing.all(16), .gap = 16, .flex = 1 },
    }, &S.items);
}

fn buildProgressStat(label: []const u8, value: []const u8, color: u32) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = text(value, .{ .style = .{ .font_size = 24, .font_weight = 700, .color = color } });
    S.items[1] = text(label, .{ .style = .{ .font_size = 14, .color = Color.text_secondary } });

    return div(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(16),
            .flex = 1,
        },
    }, &S.items);
}

fn buildProfileScreen(state: *const app.AppState) VNode {
    const S = struct {
        var items: [4]VNode = undefined;
        var weight_buf: [16]u8 = undefined;
    };

    const weight_str = std.fmt.bufPrint(&S.weight_buf, "{d:.1} kg", .{state.weight}) catch "0 kg";

    S.items[0] = row(.{ .style = .{ .gap = 16 } }, &.{
        iconView("person.circle.fill", .{ .style = .{ .color = Color.blue, .font_size = 64 } }),
        column(.{ .style = .{ .gap = 4 } }, &.{
            text("Athlete", .{ .style = .{ .font_size = 24, .font_weight = 700, .color = Color.text } }),
            text(weight_str, .{ .style = .{ .font_size = 16, .color = Color.text_secondary } }),
        }),
    });
    S.items[1] = buildProfileItem("Goals", "gear");
    S.items[2] = buildProfileItem("Health Data", "heart");
    S.items[3] = buildProfileItem("Settings", "gearshape");

    return column(.{
        .style = .{ .padding = Spacing.all(16), .gap = 16, .flex = 1 },
    }, &S.items);
}

fn buildProfileItem(label: []const u8, icon_name: []const u8) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
    };

    S.items[0] = iconView(icon_name, .{ .style = .{ .color = Color.text_secondary, .font_size = 20 } });
    S.items[1] = text(label, .{ .style = .{ .font_size = 16, .color = Color.text, .flex = 1 } });
    S.items[2] = iconView("chevron.right", .{ .style = .{ .color = Color.text_secondary, .font_size = 14 } });

    return row(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(16),
            .gap = 12,
        },
    }, &S.items);
}

fn buildTabBar(state: *const app.AppState) VNode {
    const S = struct {
        var items: [4]VNode = undefined;
    };

    S.items[0] = buildTabItem("flame", "Today", state.current_screen == .dashboard);
    S.items[1] = buildTabItem("figure.run", "Workouts", state.current_screen == .workouts);
    S.items[2] = buildTabItem("chart.line.uptrend.xyaxis", "Progress", state.current_screen == .progress);
    S.items[3] = buildTabItem("person", "Profile", state.current_screen == .profile);

    return row(.{
        .style = .{
            .background = Color.surface,
            .padding = Spacing.symmetric(0, 8),
        },
    }, &S.items);
}

fn buildTabItem(icon_name: []const u8, label: []const u8, selected: bool) VNode {
    const color = if (selected) Color.red else Color.text_secondary;

    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = iconView(icon_name, .{ .style = .{ .color = color, .font_size = 20 } });
    S.items[1] = text(label, .{ .style = .{ .font_size = 10, .color = color } });

    return column(.{ .style = .{ .flex = 1, .gap = 4, .padding = Spacing.symmetric(0, 8) } }, &S.items);
}

// ============================================================================
// C ABI Export
// ============================================================================

pub fn render() [*]const VNode {
    const S = struct {
        var root: [1]VNode = undefined;
    };
    S.root[0] = buildApp(app.getState());
    return &S.root;
}

// ============================================================================
// Tests
// ============================================================================

test "build app" {
    app.init();
    defer app.deinit();
    const view = buildApp(app.getState());
    try std.testing.expectEqual(Tag.column, view.tag);
}

test "render" {
    app.init();
    defer app.deinit();
    const root = render();
    try std.testing.expectEqual(Tag.column, root[0].tag);
}
