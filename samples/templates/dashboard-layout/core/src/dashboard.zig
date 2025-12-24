//! Dashboard Layout - UI Components

const std = @import("std");
const app = @import("app.zig");

pub const VNode = struct {
    tag: Tag,
    props: Props = .{},
    children: []const VNode = &.{},
    text: ?[]const u8 = null,
};

pub const Tag = enum { div, row, column, text, button, icon, spacer, grid, card, input };

pub const Props = struct {
    id: ?[]const u8 = null,
    style: ?Style = null,
    active: bool = false,
    collapsed: bool = false,
    span: u8 = 1,
};

pub const Style = struct {
    width: ?Size = null,
    height: ?Size = null,
    padding: ?Spacing = null,
    margin: ?Spacing = null,
    background: ?Color = null,
    color: ?Color = null,
    font_size: ?u32 = null,
    font_weight: ?FontWeight = null,
    alignment: ?Alignment = null,
    justify: ?Justify = null,
    border_radius: ?u32 = null,
    border_color: ?Color = null,
    gap: ?u32 = null,
    shadow: bool = false,
};

pub const Size = union(enum) { px: u32, percent: f32, fill, wrap };
pub const Spacing = struct {
    top: u32 = 0,
    right: u32 = 0,
    bottom: u32 = 0,
    left: u32 = 0,
    pub fn all(v: u32) Spacing {
        return .{ .top = v, .right = v, .bottom = v, .left = v };
    }
    pub fn horizontal(v: u32) Spacing {
        return .{ .left = v, .right = v };
    }
    pub fn vertical(v: u32) Spacing {
        return .{ .top = v, .bottom = v };
    }
};
pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,
    pub const white = Color{ .r = 255, .g = 255, .b = 255 };
    pub const black = Color{ .r = 0, .g = 0, .b = 0 };
    pub const primary = Color{ .r = 59, .g = 130, .b = 246 };
    pub const success = Color{ .r = 34, .g = 197, .b = 94 };
    pub const warning = Color{ .r = 234, .g = 179, .b = 8 };
    pub const danger = Color{ .r = 239, .g = 68, .b = 68 };
    pub const gray100 = Color{ .r = 243, .g = 244, .b = 246 };
    pub const gray200 = Color{ .r = 229, .g = 231, .b = 235 };
    pub const gray500 = Color{ .r = 107, .g = 114, .b = 128 };
    pub const gray700 = Color{ .r = 55, .g = 65, .b = 81 };
    pub const gray900 = Color{ .r = 17, .g = 24, .b = 39 };
};
pub const FontWeight = enum { normal, bold, light };
pub const Alignment = enum { start, center, end, stretch };
pub const Justify = enum { start, center, end, space_between };

// App Builder
pub fn buildApp(state: *const app.AppState) VNode {
    return row(.{ .style = .{ .height = .fill } }, &.{
        buildSidebar(state),
        column(.{ .style = .{ .width = .fill, .height = .fill, .background = Color.gray100 } }, &.{
            buildHeader(state),
            buildContent(state),
        }),
    });
}

fn buildSidebar(state: *const app.AppState) VNode {
    const width: Size = if (state.sidebar_collapsed) .{ .px = 64 } else .{ .px = 240 };
    return column(.{
        .style = .{
            .width = width,
            .height = .fill,
            .background = Color.gray900,
            .padding = Spacing.all(16),
            .gap = 24,
        },
        .collapsed = state.sidebar_collapsed,
    }, &.{
        buildLogo(state),
        buildNavigation(state),
        buildUserProfile(state),
    });
}

fn buildLogo(state: *const app.AppState) VNode {
    if (state.sidebar_collapsed) {
        return icon("square.grid.2x2", .{ .style = .{ .color = Color.white } });
    }
    return row(.{ .style = .{ .alignment = .center, .gap = 8 } }, &.{
        icon("square.grid.2x2", .{ .style = .{ .color = Color.primary } }),
        text("Dashboard", .{ .style = .{ .font_size = 20, .font_weight = .bold, .color = Color.white } }),
    });
}

fn buildNavigation(state: *const app.AppState) VNode {
    var items: [5]VNode = undefined;
    for (app.nav_items, 0..) |nav, i| {
        items[i] = buildNavItem(nav, i, state.current_nav == i, state.sidebar_collapsed);
    }
    return column(.{ .style = .{ .gap = 4 } }, &items);
}

fn buildNavItem(nav: app.NavItem, idx: usize, active: bool, collapsed: bool) VNode {
    const bg = if (active) Color.primary else Color.gray900;
    const txt_color = if (active) Color.white else Color.gray500;
    _ = idx;

    if (collapsed) {
        return div(.{
            .style = .{
                .padding = Spacing.all(12),
                .background = bg,
                .border_radius = 8,
                .alignment = .center,
            },
            .active = active,
        }, &.{
            icon(nav.icon, .{ .style = .{ .color = txt_color } }),
        });
    }

    var children: [3]VNode = undefined;
    var count: usize = 0;

    children[count] = icon(nav.icon, .{ .style = .{ .color = txt_color } });
    count += 1;
    children[count] = text(nav.title, .{ .style = .{ .font_size = 14, .color = txt_color } });
    count += 1;

    if (nav.badge) |badge| {
        const S = struct {
            var badge_text: [8]u8 = undefined;
        };
        const badge_len = std.fmt.formatIntBuf(&S.badge_text, badge, 10, .lower, .{});
        children[count] = div(.{
            .style = .{
                .padding = .{ .left = 8, .right = 8, .top = 2, .bottom = 2 },
                .background = Color.danger,
                .border_radius = 10,
            },
        }, &.{
            text(S.badge_text[0..badge_len], .{ .style = .{ .font_size = 12, .color = Color.white } }),
        });
        count += 1;
    }

    return row(.{
        .style = .{
            .padding = Spacing.all(12),
            .background = bg,
            .border_radius = 8,
            .gap = 12,
            .alignment = .center,
        },
        .active = active,
    }, children[0..count]);
}

fn buildUserProfile(state: *const app.AppState) VNode {
    if (state.sidebar_collapsed) {
        return div(.{
            .style = .{
                .width = .{ .px = 32 },
                .height = .{ .px = 32 },
                .background = Color.gray500,
                .border_radius = 16,
            },
        }, &.{});
    }

    return row(.{
        .style = .{
            .padding = Spacing.all(12),
            .background = Color.gray700,
            .border_radius = 8,
            .gap = 12,
            .alignment = .center,
        },
    }, &.{
        div(.{
            .style = .{
                .width = .{ .px = 40 },
                .height = .{ .px = 40 },
                .background = Color.gray500,
                .border_radius = 20,
            },
        }, &.{}),
        column(.{ .style = .{ .gap = 2 } }, &.{
            text(state.user_name, .{ .style = .{ .font_size = 14, .font_weight = .bold, .color = Color.white } }),
            text(state.user_role, .{ .style = .{ .font_size = 12, .color = Color.gray500 } }),
        }),
    });
}

fn buildHeader(state: *const app.AppState) VNode {
    return row(.{
        .style = .{
            .height = .{ .px = 64 },
            .padding = Spacing.horizontal(24),
            .background = Color.white,
            .alignment = .center,
            .justify = .space_between,
            .shadow = true,
        },
    }, &.{
        row(.{ .style = .{ .gap = 16, .alignment = .center } }, &.{
            button("menu", .{ .id = "toggle-sidebar" }),
            text("Dashboard Overview", .{ .style = .{ .font_size = 20, .font_weight = .bold } }),
        }),
        row(.{ .style = .{ .gap = 16, .alignment = .center } }, &.{
            buildSearchBox(state),
            buildNotificationBell(state),
            button("gear", .{ .id = "settings" }),
        }),
    });
}

fn buildSearchBox(state: *const app.AppState) VNode {
    _ = state;
    return row(.{
        .style = .{
            .width = .{ .px = 240 },
            .padding = .{ .left = 12, .right = 12, .top = 8, .bottom = 8 },
            .background = Color.gray100,
            .border_radius = 8,
            .gap = 8,
            .alignment = .center,
        },
    }, &.{
        icon("magnifyingglass", .{ .style = .{ .color = Color.gray500 } }),
        input("Search...", .{ .id = "search" }),
    });
}

fn buildNotificationBell(state: *const app.AppState) VNode {
    if (state.notification_count > 0) {
        const S = struct {
            var count_text: [8]u8 = undefined;
        };
        const len = std.fmt.formatIntBuf(&S.count_text, state.notification_count, 10, .lower, .{});
        return div(.{ .style = .{ .width = .wrap, .height = .wrap } }, &.{
            button("bell", .{ .id = "notifications" }),
            div(.{
                .style = .{
                    .padding = .{ .left = 6, .right = 6, .top = 2, .bottom = 2 },
                    .background = Color.danger,
                    .border_radius = 10,
                },
            }, &.{
                text(S.count_text[0..len], .{ .style = .{ .font_size = 10, .color = Color.white } }),
            }),
        });
    }
    return button("bell", .{ .id = "notifications" });
}

fn buildContent(state: *const app.AppState) VNode {
    return column(.{
        .style = .{
            .padding = Spacing.all(24),
            .gap = 24,
        },
    }, &.{
        buildStatsRow(),
        buildWidgetGrid(state),
    });
}

fn buildStatsRow() VNode {
    var cards: [4]VNode = undefined;
    for (app.default_stats, 0..) |stat, i| {
        cards[i] = buildStatCard(stat);
    }
    return row(.{ .style = .{ .gap = 16 } }, &cards);
}

fn buildStatCard(stat: app.StatCard) VNode {
    const trend_color = if (stat.trend >= 0) Color.success else Color.danger;
    const trend_icon = if (stat.trend >= 0) "arrow.up" else "arrow.down";

    return card(.{
        .style = .{
            .width = .fill,
            .padding = Spacing.all(16),
            .background = Color.white,
            .border_radius = 8,
            .shadow = true,
        },
    }, &.{
        column(.{ .style = .{ .gap = 8 } }, &.{
            text(stat.label, .{ .style = .{ .font_size = 14, .color = Color.gray500 } }),
            text(stat.value, .{ .style = .{ .font_size = 24, .font_weight = .bold } }),
            row(.{ .style = .{ .gap = 4, .alignment = .center } }, &.{
                icon(trend_icon, .{ .style = .{ .color = trend_color } }),
                text(stat.trend_label, .{ .style = .{ .font_size = 12, .color = trend_color } }),
            }),
        }),
    });
}

fn buildWidgetGrid(state: *const app.AppState) VNode {
    _ = state;
    return grid(.{ .style = .{ .gap = 16 } }, &.{
        buildChartWidget(),
        buildActivityWidget(),
        buildActionsWidget(),
    });
}

fn buildChartWidget() VNode {
    return card(.{
        .span = 2,
        .style = .{
            .padding = Spacing.all(16),
            .background = Color.white,
            .border_radius = 8,
            .shadow = true,
        },
    }, &.{
        column(.{ .style = .{ .gap = 16 } }, &.{
            row(.{ .style = .{ .justify = .space_between, .alignment = .center } }, &.{
                text("Analytics Overview", .{ .style = .{ .font_size = 16, .font_weight = .bold } }),
                button("ellipsis", .{ .id = "chart-menu" }),
            }),
            div(.{
                .style = .{ .height = .{ .px = 200 }, .background = Color.gray100, .border_radius = 8 },
            }, &.{
                text("Chart Placeholder", .{ .style = .{ .color = Color.gray500 } }),
            }),
        }),
    });
}

fn buildActivityWidget() VNode {
    return card(.{
        .style = .{
            .padding = Spacing.all(16),
            .background = Color.white,
            .border_radius = 8,
            .shadow = true,
        },
    }, &.{
        column(.{ .style = .{ .gap = 12 } }, &.{
            text("Recent Activity", .{ .style = .{ .font_size = 16, .font_weight = .bold } }),
            buildActivityItem("New user registered", "2 min ago"),
            buildActivityItem("Order #1234 completed", "15 min ago"),
            buildActivityItem("Report generated", "1 hour ago"),
        }),
    });
}

fn buildActivityItem(title: []const u8, time: []const u8) VNode {
    return row(.{ .style = .{ .gap = 12, .alignment = .center } }, &.{
        div(.{
            .style = .{ .width = .{ .px = 8 }, .height = .{ .px = 8 }, .background = Color.primary, .border_radius = 4 },
        }, &.{}),
        column(.{ .style = .{ .gap = 2 } }, &.{
            text(title, .{ .style = .{ .font_size = 14 } }),
            text(time, .{ .style = .{ .font_size = 12, .color = Color.gray500 } }),
        }),
    });
}

fn buildActionsWidget() VNode {
    return card(.{
        .style = .{
            .padding = Spacing.all(16),
            .background = Color.white,
            .border_radius = 8,
            .shadow = true,
        },
    }, &.{
        column(.{ .style = .{ .gap = 12 } }, &.{
            text("Quick Actions", .{ .style = .{ .font_size = 16, .font_weight = .bold } }),
            buildActionButton("Create Report", "doc.badge.plus", Color.primary),
            buildActionButton("Add User", "person.badge.plus", Color.success),
            buildActionButton("Export Data", "square.and.arrow.up", Color.gray700),
        }),
    });
}

fn buildActionButton(label: []const u8, ic: []const u8, bg: Color) VNode {
    return row(.{
        .style = .{
            .padding = Spacing.all(12),
            .background = bg,
            .border_radius = 8,
            .gap = 8,
            .alignment = .center,
        },
    }, &.{
        icon(ic, .{ .style = .{ .color = Color.white } }),
        text(label, .{ .style = .{ .font_size = 14, .color = Color.white } }),
    });
}

// Element constructors
pub fn div(props: Props, children: []const VNode) VNode {
    return .{ .tag = .div, .props = props, .children = children };
}

pub fn row(props: Props, children: []const VNode) VNode {
    return .{ .tag = .row, .props = props, .children = children };
}

pub fn column(props: Props, children: []const VNode) VNode {
    return .{ .tag = .column, .props = props, .children = children };
}

pub fn text(content: []const u8, props: Props) VNode {
    return .{ .tag = .text, .props = props, .text = content };
}

pub fn button(label: []const u8, props: Props) VNode {
    return .{ .tag = .button, .props = props, .text = label };
}

pub fn icon(name: []const u8, props: Props) VNode {
    return .{ .tag = .icon, .props = props, .text = name };
}

pub fn card(props: Props, children: []const VNode) VNode {
    return .{ .tag = .card, .props = props, .children = children };
}

pub fn grid(props: Props, children: []const VNode) VNode {
    return .{ .tag = .grid, .props = props, .children = children };
}

pub fn input(placeholder: []const u8, props: Props) VNode {
    return .{ .tag = .input, .props = props, .text = placeholder };
}

// Tests
test "build app" {
    const state = app.AppState{ .initialized = true };
    const view = buildApp(&state);
    try std.testing.expectEqual(Tag.row, view.tag);
}

test "sidebar collapsed" {
    var state = app.AppState{ .initialized = true };
    state.sidebar_collapsed = true;
    const view = buildApp(&state);
    try std.testing.expect(view.children.len > 0);
}
