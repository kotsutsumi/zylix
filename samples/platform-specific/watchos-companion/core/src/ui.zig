//! watchOS Companion - UI Components

const std = @import("std");
const app = @import("app.zig");

pub const Tag = enum { column, row, div, text, button, scroll, icon, ring };

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

pub fn buildApp(state: *const app.AppState) VNode {
    const S = struct {
        var content: [1]VNode = undefined;
    };

    S.content[0] = buildContent(state);

    return column(.{
        .style = .{ .background = Color.background },
    }, &S.content);
}

fn buildContent(state: *const app.AppState) VNode {
    return switch (state.current_screen) {
        .home => buildHomeScreen(state),
        .workout => buildWorkoutScreen(state),
        .health => buildHealthScreen(state),
        .settings => buildSettingsScreen(state),
    };
}

fn buildHomeScreen(state: *const app.AppState) VNode {
    const S = struct {
        var items: [4]VNode = undefined;
        var steps_buf: [16]u8 = undefined;
        var hr_buf: [16]u8 = undefined;
    };

    const steps_str = std.fmt.bufPrint(&S.steps_buf, "{d}", .{state.steps_today}) catch "0";
    const hr_str = std.fmt.bufPrint(&S.hr_buf, "{d}", .{state.heart_rate}) catch "0";

    // Time display (simulated)
    S.items[0] = text("10:42", .{
        .style = .{ .font_size = 48, .font_weight = 700, .color = Color.text },
    });

    // Activity rings area
    S.items[1] = div(.{
        .style = .{ .background = Color.surface, .height = 60, .border_radius = 12, .padding = Spacing.all(8) },
    }, &.{
        row(.{ .style = .{ .gap = 16 } }, &.{
            buildMetricSmall("figure.walk", steps_str, Color.green),
            buildMetricSmall("heart.fill", hr_str, Color.red),
        }),
    });

    // Quick actions
    S.items[2] = buildQuickAction("Start Workout", "figure.run", Color.green);
    S.items[3] = buildQuickAction("Check Health", "heart.fill", Color.red);

    return column(.{
        .style = .{ .padding = Spacing.all(8), .gap = 8, .flex = 1 },
    }, &S.items);
}

fn buildMetricSmall(icon_name: []const u8, value: []const u8, color: u32) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = iconView(icon_name, .{ .style = .{ .color = color, .font_size = 16 } });
    S.items[1] = text(value, .{ .style = .{ .font_size = 16, .font_weight = 600, .color = Color.text } });

    return row(.{ .style = .{ .gap = 4 } }, &S.items);
}

fn buildQuickAction(label: []const u8, icon_name: []const u8, color: u32) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = iconView(icon_name, .{ .style = .{ .color = color, .font_size = 20 } });
    S.items[1] = text(label, .{ .style = .{ .font_size = 14, .color = Color.text } });

    return row(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.symmetric(12, 10),
            .gap = 8,
        },
    }, &S.items);
}

fn buildWorkoutScreen(state: *const app.AppState) VNode {
    const S = struct {
        var items: [4]VNode = undefined;
        var duration_buf: [16]u8 = undefined;
        var calories_buf: [16]u8 = undefined;
        var hr_buf: [16]u8 = undefined;
    };

    const mins = state.workout_duration / 60;
    const secs = state.workout_duration % 60;
    const duration_str = std.fmt.bufPrint(&S.duration_buf, "{d:0>2}:{d:0>2}", .{ mins, secs }) catch "00:00";
    const calories_str = std.fmt.bufPrint(&S.calories_buf, "{d}", .{state.workout_calories}) catch "0";
    const hr_str = std.fmt.bufPrint(&S.hr_buf, "{d}", .{state.heart_rate}) catch "0";

    // Workout type and status
    S.items[0] = column(.{ .style = .{ .gap = 4 } }, &.{
        text(state.current_workout_type.name(), .{
            .style = .{ .font_size = 14, .color = state.current_workout_type.color() },
        }),
        text(state.workout_state.label(), .{
            .style = .{ .font_size = 12, .color = Color.text_secondary },
        }),
    });

    // Duration (main display)
    S.items[1] = text(duration_str, .{
        .style = .{ .font_size = 48, .font_weight = 700, .color = Color.text },
    });

    // Metrics
    S.items[2] = row(.{ .style = .{ .gap = 16 } }, &.{
        buildWorkoutMetric("flame.fill", calories_str, "CAL", Color.orange),
        buildWorkoutMetric("heart.fill", hr_str, "BPM", Color.red),
    });

    // Control button
    S.items[3] = buildWorkoutControl(state.workout_state);

    return column(.{
        .style = .{ .padding = Spacing.all(8), .gap = 12, .flex = 1 },
    }, &S.items);
}

fn buildWorkoutMetric(icon_name: []const u8, value: []const u8, unit: []const u8, color: u32) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
    };

    S.items[0] = iconView(icon_name, .{ .style = .{ .color = color, .font_size = 14 } });
    S.items[1] = text(value, .{ .style = .{ .font_size = 20, .font_weight = 600, .color = Color.text } });
    S.items[2] = text(unit, .{ .style = .{ .font_size = 10, .color = Color.text_secondary } });

    return column(.{ .style = .{ .gap = 2 } }, &S.items);
}

fn buildWorkoutControl(workout_state: app.WorkoutState) VNode {
    const label = switch (workout_state) {
        .idle => "Start",
        .active => "Pause",
        .paused => "Resume",
    };
    const color = switch (workout_state) {
        .idle => Color.green,
        .active => Color.orange,
        .paused => Color.green,
    };

    return text(label, .{
        .style = .{
            .font_size = 16,
            .font_weight = 600,
            .color = Color.text,
            .background = color,
            .padding = Spacing.symmetric(24, 12),
            .border_radius = 20,
        },
    });
}

fn buildHealthScreen(state: *const app.AppState) VNode {
    const S = struct {
        var items: [4]VNode = undefined;
    };

    S.items[0] = buildHealthCard("Heart Rate", state.heart_rate, "BPM", "heart.fill", Color.red);
    S.items[1] = buildHealthCard("Steps", state.steps_today, "steps", "figure.walk", Color.green);
    S.items[2] = buildHealthCard("Calories", state.calories_today, "kcal", "flame.fill", Color.orange);
    S.items[3] = buildHealthCard("Active", state.active_minutes, "min", "clock", Color.blue);

    return column(.{
        .style = .{ .padding = Spacing.all(8), .gap = 8, .flex = 1 },
    }, &S.items);
}

fn buildHealthCard(label: []const u8, value: u32, unit: []const u8, icon_name: []const u8, color: u32) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
        var value_buf: [16]u8 = undefined;
    };

    const value_str = std.fmt.bufPrint(&S.value_buf, "{d}", .{value}) catch "0";

    S.items[0] = row(.{ .style = .{ .gap = 6 } }, &.{
        iconView(icon_name, .{ .style = .{ .color = color, .font_size = 14 } }),
        text(label, .{ .style = .{ .font_size = 12, .color = Color.text_secondary } }),
    });
    S.items[1] = row(.{ .style = .{ .gap = 4 } }, &.{
        text(value_str, .{ .style = .{ .font_size = 20, .font_weight = 600, .color = Color.text } }),
        text(unit, .{ .style = .{ .font_size = 12, .color = Color.text_secondary } }),
    });

    return div(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(10),
            .gap = 4,
        },
    }, &S.items);
}

fn buildSettingsScreen(state: *const app.AppState) VNode {
    const S = struct {
        var items: [4]VNode = undefined;
    };

    S.items[0] = buildSettingRow("Haptics", state.haptics_enabled);
    S.items[1] = buildSettingRow("Always On", state.always_on_display);
    S.items[2] = buildSettingRow("Water Lock", state.water_lock);
    S.items[3] = buildConnectionStatus(state.is_phone_connected);

    return column(.{
        .style = .{ .padding = Spacing.all(8), .gap = 8, .flex = 1 },
    }, &S.items);
}

fn buildSettingRow(label: []const u8, is_enabled: bool) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = text(label, .{ .style = .{ .font_size = 14, .color = Color.text, .flex = 1 } });
    S.items[1] = div(.{
        .style = .{
            .background = if (is_enabled) Color.green else Color.surface,
            .width = 36,
            .height = 20,
            .border_radius = 10,
        },
    }, &.{});

    return row(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 10,
            .padding = Spacing.symmetric(10, 8),
        },
    }, &S.items);
}

fn buildConnectionStatus(is_connected: bool) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = iconView("iphone", .{
        .style = .{ .color = if (is_connected) Color.green else Color.text_secondary, .font_size = 16 },
    });
    S.items[1] = text(if (is_connected) "iPhone Connected" else "Not Connected", .{
        .style = .{ .font_size = 12, .color = if (is_connected) Color.text else Color.text_secondary },
    });

    return row(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 10,
            .padding = Spacing.all(10),
            .gap = 8,
        },
    }, &S.items);
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
