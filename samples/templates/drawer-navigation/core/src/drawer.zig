//! Drawer Navigation - UI Components

const std = @import("std");
const app = @import("app.zig");

pub const VNode = struct {
    tag: Tag,
    props: Props = .{},
    children: []const VNode = &.{},
    text: ?[]const u8 = null,
};

pub const Tag = enum { div, row, column, text, button, icon, spacer, overlay };

pub const Props = struct {
    id: ?[]const u8 = null,
    style: ?Style = null,
    active: bool = false,
    visible: bool = true,
};

pub const Style = struct {
    width: ?Size = null,
    height: ?Size = null,
    padding: ?Spacing = null,
    background: ?Color = null,
    color: ?Color = null,
    font_size: ?u32 = null,
    font_weight: ?FontWeight = null,
    alignment: ?Alignment = null,
    justify: ?Justify = null,
    border_radius: ?u32 = null,
    gap: ?u32 = null,
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
};
pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,
    pub const white = Color{ .r = 255, .g = 255, .b = 255 };
    pub const black = Color{ .r = 0, .g = 0, .b = 0 };
    pub const primary = Color{ .r = 59, .g = 130, .b = 246 };
    pub const gray = Color{ .r = 107, .g = 114, .b = 128 };
    pub const light = Color{ .r = 243, .g = 244, .b = 246 };
    pub const overlay = Color{ .r = 0, .g = 0, .b = 0, .a = 128 };
};
pub const FontWeight = enum { normal, bold, light };
pub const Alignment = enum { start, center, end, stretch };
pub const Justify = enum { start, center, end, space_between };

// App Builder
pub fn buildApp(state: *const app.AppState) VNode {
    return row(.{ .style = .{ .height = .fill } }, &.{
        if (state.drawer_open) buildOverlay() else spacer(0),
        if (state.drawer_open) buildDrawer(state) else spacer(0),
        column(.{ .style = .{ .width = .fill, .height = .fill } }, &.{
            buildHeader(state),
            buildContent(state),
        }),
    });
}

fn buildOverlay() VNode {
    return div(.{
        .id = "overlay",
        .style = .{
            .width = .fill,
            .height = .fill,
            .background = Color.overlay,
        },
    }, &.{});
}

fn buildDrawer(state: *const app.AppState) VNode {
    return column(.{
        .style = .{
            .width = .{ .px = 280 },
            .height = .fill,
            .background = Color.white,
        },
    }, &.{
        buildUserSection(state),
        buildMenuSections(state),
    });
}

fn buildUserSection(state: *const app.AppState) VNode {
    return column(.{
        .style = .{
            .padding = Spacing.all(16),
            .background = Color.primary,
            .gap = 8,
        },
    }, &.{
        div(.{
            .style = .{
                .width = .{ .px = 64 },
                .height = .{ .px = 64 },
                .background = Color.white,
                .border_radius = 32,
            },
        }, &.{}),
        text(state.user_name, .{
            .style = .{
                .font_size = 16,
                .font_weight = .bold,
                .color = Color.white,
            },
        }),
        text(state.user_email, .{
            .style = .{
                .font_size = 12,
                .color = Color.light,
            },
        }),
    });
}

fn buildMenuSections(state: *const app.AppState) VNode {
    const S = struct {
        var sections: [app.menu_sections.len]VNode = undefined;
    };
    for (app.menu_sections, 0..) |section, i| {
        S.sections[i] = buildSection(section, state.current_screen);
    }
    return column(.{ .style = .{ .padding = Spacing.all(8), .gap = 16 } }, &S.sections);
}

fn maxSectionItems() comptime_int {
    var max: comptime_int = 0;
    for (app.menu_sections) |section| {
        if (section.items.len > max) max = section.items.len;
    }
    return max + 1; // +1 for section header
}

fn buildSection(section: app.MenuSection, current: app.Screen) VNode {
    const S = struct {
        var items: [maxSectionItems()]VNode = undefined;
    };
    var count: usize = 0;

    // Section header
    S.items[count] = text(section.title, .{
        .style = .{
            .font_size = 12,
            .font_weight = .bold,
            .color = Color.gray,
            .padding = .{ .left = 12, .top = 0, .right = 0, .bottom = 0 },
        },
    });
    count += 1;

    // Menu items
    for (section.items) |screen| {
        S.items[count] = buildMenuItem(screen, current == screen);
        count += 1;
    }

    return column(.{ .style = .{ .gap = 4 } }, S.items[0..count]);
}

fn buildMenuItem(screen: app.Screen, active: bool) VNode {
    const bg = if (active) Color.light else Color.white;
    const txt_color = if (active) Color.primary else Color.black;

    return row(.{
        .id = @tagName(screen),
        .active = active,
        .style = .{
            .padding = Spacing.all(12),
            .background = bg,
            .border_radius = 8,
            .gap = 12,
            .alignment = .center,
        },
    }, &.{
        icon(screen.icon(), .{ .style = .{ .color = txt_color } }),
        text(screen.title(), .{
            .style = .{ .font_size = 14, .color = txt_color },
        }),
    });
}

fn buildHeader(state: *const app.AppState) VNode {
    return row(.{
        .style = .{
            .height = .{ .px = 56 },
            .padding = .{ .left = 16, .right = 16, .top = 0, .bottom = 0 },
            .background = Color.white,
            .alignment = .center,
            .justify = .space_between,
        },
    }, &.{
        button("menu", .{ .id = "hamburger" }),
        text(state.current_screen.title(), .{
            .style = .{ .font_size = 18, .font_weight = .bold },
        }),
        button("bell", .{ .id = "notifications" }),
    });
}

fn buildContent(state: *const app.AppState) VNode {
    return switch (state.current_screen) {
        .home => buildHomeContent(),
        .dashboard => buildDashboardContent(),
        .profile => buildProfileContent(state),
        .settings => buildSettingsContent(),
        .help => buildHelpContent(),
    };
}

fn buildHomeContent() VNode {
    return column(.{ .style = .{ .padding = Spacing.all(16), .gap = 16 } }, &.{
        text("Welcome Home", .{ .style = .{ .font_size = 24, .font_weight = .bold } }),
        text("Your personalized start page", .{ .style = .{ .color = Color.gray } }),
    });
}

fn buildDashboardContent() VNode {
    return column(.{ .style = .{ .padding = Spacing.all(16), .gap = 16 } }, &.{
        text("Dashboard", .{ .style = .{ .font_size = 24, .font_weight = .bold } }),
        text("Analytics and metrics", .{ .style = .{ .color = Color.gray } }),
    });
}

fn buildProfileContent(state: *const app.AppState) VNode {
    return column(.{
        .style = .{ .padding = Spacing.all(16), .gap = 16, .alignment = .center },
    }, &.{
        div(.{
            .style = .{
                .width = .{ .px = 80 },
                .height = .{ .px = 80 },
                .background = Color.light,
                .border_radius = 40,
            },
        }, &.{}),
        text(state.user_name, .{ .style = .{ .font_size = 20, .font_weight = .bold } }),
        text(state.user_email, .{ .style = .{ .color = Color.gray } }),
    });
}

fn buildSettingsContent() VNode {
    return column(.{ .style = .{ .padding = Spacing.all(16), .gap = 16 } }, &.{
        text("Settings", .{ .style = .{ .font_size = 24, .font_weight = .bold } }),
        text("App preferences and configuration", .{ .style = .{ .color = Color.gray } }),
    });
}

fn buildHelpContent() VNode {
    return column(.{ .style = .{ .padding = Spacing.all(16), .gap = 16 } }, &.{
        text("Help & Support", .{ .style = .{ .font_size = 24, .font_weight = .bold } }),
        text("Documentation and FAQs", .{ .style = .{ .color = Color.gray } }),
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

pub fn spacer(size: u32) VNode {
    return .{ .tag = .spacer, .props = .{ .style = .{ .width = .{ .px = size } } } };
}

// Tests
test "build app" {
    const state = app.AppState{ .initialized = true };
    const view = buildApp(&state);
    try std.testing.expectEqual(Tag.row, view.tag);
}

test "drawer visible when open" {
    var state = app.AppState{ .initialized = true };
    state.drawer_open = true;
    const view = buildApp(&state);
    try std.testing.expect(view.children.len > 0);
}
