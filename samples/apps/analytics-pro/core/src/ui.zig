//! Analytics Pro - UI Components

const std = @import("std");
const app = @import("app.zig");

pub const Tag = enum { column, row, div, text, button, scroll, icon, chart, card };

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
    pub const background: u32 = 0xFFF2F2F7;
    pub const surface: u32 = 0xFFFFFFFF;
    pub const card: u32 = 0xFFFFFFFF;
    pub const text: u32 = 0xFF1C1C1E;
    pub const text_secondary: u32 = 0xFF8E8E93;
    pub const primary: u32 = 0xFF007AFF;
    pub const success: u32 = 0xFF34C759;
    pub const warning: u32 = 0xFFFF9500;
    pub const danger: u32 = 0xFFFF3B30;
    pub const purple: u32 = 0xFF5856D6;
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
        .style = .{ .font_size = 24, .font_weight = 700, .color = Color.text },
    });
    S.items[1] = spacer();
    S.items[2] = button(state.time_range.label(), .{
        .style = .{
            .background = Color.surface,
            .padding = Spacing.symmetric(12, 8),
            .border_radius = 8,
            .color = Color.primary,
        },
    });

    return row(.{
        .style = .{
            .background = Color.surface,
            .padding = Spacing.symmetric(16, 12),
        },
    }, &S.items);
}

fn buildContent(state: *const app.AppState) VNode {
    return switch (state.current_screen) {
        .dashboard => buildDashboardScreen(state),
        .analytics => buildAnalyticsScreen(state),
        .reports => buildReportsScreen(state),
        .settings => buildSettingsScreen(state),
    };
}

fn buildDashboardScreen(state: *const app.AppState) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
    };

    S.items[0] = buildMetricsRow(state);
    S.items[1] = buildChartCard(state);
    S.items[2] = buildActivityList(state);

    return column(.{
        .style = .{ .padding = Spacing.all(16), .gap = 16, .flex = 1 },
    }, &S.items);
}

fn buildMetricsRow(state: *const app.AppState) VNode {
    const max_display = 2;
    const display_count = @min(state.metric_count, max_display);

    const S = struct {
        var items: [max_display]VNode = undefined;
    };

    for (0..display_count) |i| {
        S.items[i] = buildMetricCard(&state.metrics[i]);
    }

    return row(.{ .style = .{ .gap = 12 } }, S.items[0..display_count]);
}

fn buildMetricCard(metric: *const app.Metric) VNode {
    const S = struct {
        var items: [4]VNode = undefined;
        var value_buf: [16]u8 = undefined;
        var change_buf: [16]u8 = undefined;
    };

    const value_str = std.fmt.bufPrint(&S.value_buf, "{d}", .{metric.value}) catch "0";
    const sign: []const u8 = if (metric.change_percent >= 0) "+" else "";
    const change_str = std.fmt.bufPrint(&S.change_buf, "{s}{d:.1}%", .{ sign, metric.change_percent }) catch "0%";

    S.items[0] = row(.{ .style = .{ .gap = 8 } }, &.{
        iconView(metric.icon[0..metric.icon_len], .{ .style = .{ .color = Color.primary, .font_size = 20 } }),
        text(metric.name[0..metric.name_len], .{ .style = .{ .font_size = 12, .color = Color.text_secondary } }),
    });
    S.items[1] = text(value_str, .{
        .style = .{ .font_size = 28, .font_weight = 700, .color = Color.text },
    });
    S.items[2] = row(.{ .style = .{ .gap = 4 } }, &.{
        iconView(metric.trend.icon(), .{ .style = .{ .color = metric.trend.color(), .font_size = 12 } }),
        text(change_str, .{ .style = .{ .font_size = 12, .color = metric.trend.color() } }),
    });
    S.items[3] = spacer();

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

fn buildChartCard(state: *const app.AppState) VNode {
    _ = state;
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = row(.{ .style = .{ .gap = 8 } }, &.{
        text("Revenue Trend", .{ .style = .{ .font_size = 16, .font_weight = 600, .color = Color.text } }),
        spacer(),
        iconView("ellipsis", .{ .style = .{ .color = Color.text_secondary } }),
    });
    S.items[1] = div(.{
        .style = .{ .background = Color.background, .height = 150, .border_radius = 8 },
    }, &.{
        // Chart placeholder
        text("Chart Area", .{ .style = .{ .color = Color.text_secondary, .padding = Spacing.all(60) } }),
    });

    return div(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(16),
            .gap = 12,
        },
    }, &S.items);
}

fn buildActivityList(state: *const app.AppState) VNode {
    const max_display = 4;
    const display_count = @min(state.activity_count, max_display);

    const S = struct {
        var items: [max_display + 1]VNode = undefined;
    };

    S.items[0] = text("Recent Activity", .{
        .style = .{ .font_size = 16, .font_weight = 600, .color = Color.text },
    });

    for (0..display_count) |i| {
        S.items[i + 1] = buildActivityItem(&state.activities[i]);
    }

    return div(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(16),
            .gap = 12,
        },
    }, S.items[0 .. display_count + 1]);
}

fn buildActivityItem(activity: *const app.Activity) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = iconView(activity.icon[0..activity.icon_len], .{
        .style = .{ .color = Color.primary, .font_size = 16 },
    });
    S.items[1] = text(activity.description[0..activity.description_len], .{
        .style = .{ .font_size = 14, .color = Color.text, .flex = 1 },
    });

    return row(.{ .style = .{ .gap = 12, .padding = Spacing.symmetric(0, 4) } }, &S.items);
}

fn buildAnalyticsScreen(state: *const app.AppState) VNode {
    const max_display = 4;
    const display_count = @min(state.metric_count, max_display);

    const S = struct {
        var items: [max_display + 1]VNode = undefined;
    };

    S.items[0] = text("All Metrics", .{
        .style = .{ .font_size = 18, .font_weight = 600, .color = Color.text },
    });

    for (0..display_count) |i| {
        S.items[i + 1] = buildMetricRow(&state.metrics[i]);
    }

    return column(.{
        .style = .{ .padding = Spacing.all(16), .gap = 12, .flex = 1 },
    }, S.items[0 .. display_count + 1]);
}

fn buildMetricRow(metric: *const app.Metric) VNode {
    const S = struct {
        var items: [4]VNode = undefined;
        var value_buf: [16]u8 = undefined;
    };

    const value_str = std.fmt.bufPrint(&S.value_buf, "{d}", .{metric.value}) catch "0";

    S.items[0] = iconView(metric.icon[0..metric.icon_len], .{ .style = .{ .color = Color.primary, .font_size = 24 } });
    S.items[1] = text(metric.name[0..metric.name_len], .{
        .style = .{ .font_size = 16, .color = Color.text, .flex = 1 },
    });
    S.items[2] = text(value_str, .{ .style = .{ .font_size = 18, .font_weight = 700, .color = Color.text } });
    S.items[3] = iconView(metric.trend.icon(), .{ .style = .{ .color = metric.trend.color(), .font_size = 16 } });

    return row(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(16),
            .gap = 12,
        },
    }, &S.items);
}

fn buildReportsScreen(state: *const app.AppState) VNode {
    _ = state;
    const S = struct {
        var items: [4]VNode = undefined;
    };

    S.items[0] = text("Reports", .{
        .style = .{ .font_size = 18, .font_weight = 600, .color = Color.text },
    });
    S.items[1] = buildReportItem("Weekly Summary", "doc.text", Color.primary);
    S.items[2] = buildReportItem("Monthly Revenue", "chart.bar", Color.success);
    S.items[3] = buildReportItem("User Analytics", "person.2", Color.purple);

    return column(.{
        .style = .{ .padding = Spacing.all(16), .gap = 12, .flex = 1 },
    }, &S.items);
}

fn buildReportItem(name: []const u8, icon_name: []const u8, color: u32) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
    };

    S.items[0] = iconView(icon_name, .{ .style = .{ .color = color, .font_size = 24 } });
    S.items[1] = text(name, .{ .style = .{ .font_size = 16, .color = Color.text, .flex = 1 } });
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

fn buildSettingsScreen(state: *const app.AppState) VNode {
    _ = state;
    const S = struct {
        var items: [4]VNode = undefined;
    };

    S.items[0] = text("Settings", .{
        .style = .{ .font_size = 18, .font_weight = 600, .color = Color.text },
    });
    S.items[1] = buildSettingItem("Notifications", "bell");
    S.items[2] = buildSettingItem("Data Refresh", "arrow.clockwise");
    S.items[3] = buildSettingItem("Export Data", "square.and.arrow.up");

    return column(.{
        .style = .{ .padding = Spacing.all(16), .gap = 12, .flex = 1 },
    }, &S.items);
}

fn buildSettingItem(name: []const u8, icon_name: []const u8) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
    };

    S.items[0] = iconView(icon_name, .{ .style = .{ .color = Color.text_secondary, .font_size = 20 } });
    S.items[1] = text(name, .{ .style = .{ .font_size = 16, .color = Color.text, .flex = 1 } });
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

    S.items[0] = buildTabItem("square.grid.2x2", "Dashboard", state.current_screen == .dashboard);
    S.items[1] = buildTabItem("chart.bar", "Analytics", state.current_screen == .analytics);
    S.items[2] = buildTabItem("doc.text", "Reports", state.current_screen == .reports);
    S.items[3] = buildTabItem("gear", "Settings", state.current_screen == .settings);

    return row(.{
        .style = .{
            .background = Color.surface,
            .padding = Spacing.symmetric(0, 8),
        },
    }, &S.items);
}

fn buildTabItem(icon_name: []const u8, label: []const u8, selected: bool) VNode {
    const color = if (selected) Color.primary else Color.text_secondary;

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
