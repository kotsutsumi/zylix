//! Tab Navigation - Router and UI
//!
//! Tab routing logic and screen builders.

const std = @import("std");
const app = @import("app.zig");

// ============================================================================
// Types
// ============================================================================

/// Available tabs
pub const Tab = enum(u32) {
    home = 0,
    search = 1,
    profile = 2,
    settings = 3,

    pub fn label(self: Tab) []const u8 {
        return switch (self) {
            .home => "Home",
            .search => "Search",
            .profile => "Profile",
            .settings => "Settings",
        };
    }

    pub fn icon(self: Tab) []const u8 {
        return switch (self) {
            .home => "house",
            .search => "magnifyingglass",
            .profile => "person",
            .settings => "gear",
        };
    }
};

/// Virtual DOM node
pub const VNode = struct {
    tag: Tag,
    props: Props = .{},
    children: []const VNode = &.{},
    text: ?[]const u8 = null,
};

pub const Tag = enum {
    div,
    row,
    column,
    text,
    button,
    icon,
    spacer,
    scroll,
    input,
    image,
    tab_bar,
    tab_item,
    card,
    list,
    list_item,
    toggle,
    badge,
};

pub const Props = struct {
    id: ?[]const u8 = null,
    class: ?[]const u8 = null,
    style: ?Style = null,
    on_click: ?*const fn () void = null,
    disabled: bool = false,
    visible: bool = true,
    active: bool = false,
    placeholder: ?[]const u8 = null,
    value: ?[]const u8 = null,
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
    pub fn symmetric(v: u32, h: u32) Spacing {
        return .{ .top = v, .right = h, .bottom = v, .left = h };
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
    pub const gray = Color{ .r = 156, .g = 163, .b = 175 };
    pub const light_gray = Color{ .r = 243, .g = 244, .b = 246 };
    pub const red = Color{ .r = 239, .g = 68, .b = 68 };
};
pub const FontWeight = enum { normal, bold, light };
pub const Alignment = enum { start, center, end, stretch };
pub const Justify = enum { start, center, end, space_between, space_around, space_evenly };

// ============================================================================
// App Builder
// ============================================================================

/// Build the complete app UI
pub fn buildApp(state: *const app.AppState) VNode {
    return column(.{
        .style = .{ .height = .fill },
    }, &.{
        // Content area (screen)
        div(.{
            .style = .{ .height = .fill },
        }, &.{
            buildScreen(state),
        }),

        // Tab bar at bottom
        buildTabBar(state),
    });
}

/// Build the tab bar
fn buildTabBar(state: *const app.AppState) VNode {
    const tabs = [_]Tab{ .home, .search, .profile, .settings };

    var items: [4]VNode = undefined;
    for (tabs, 0..) |tab, i| {
        items[i] = buildTabItem(tab, state.current_tab == tab, state.getBadge(tab));
    }

    return row(.{
        .style = .{
            .height = .{ .px = 56 },
            .background = Color.white,
            .justify = .space_evenly,
            .alignment = .center,
            .padding = .{ .top = 8, .bottom = 8, .left = 0, .right = 0 },
        },
    }, &items);
}

/// Build a single tab item
fn buildTabItem(tab: Tab, active: bool, badge_count: u32) VNode {
    const txt_color = if (active) Color.primary else Color.gray;

    var children: [3]VNode = undefined;
    var child_count: usize = 0;

    // Icon
    children[child_count] = icon(tab.icon(), .{
        .style = .{ .color = txt_color },
    });
    child_count += 1;

    // Badge (if any)
    if (badge_count > 0) {
        children[child_count] = buildBadge(badge_count);
        child_count += 1;
    }

    // Label
    children[child_count] = text(tab.label(), .{
        .style = .{
            .font_size = 10,
            .color = txt_color,
        },
    });
    child_count += 1;

    return column(.{
        .id = @tagName(tab),
        .style = .{
            .alignment = .center,
            .gap = 4,
        },
        .active = active,
    }, children[0..child_count]);
}

/// Build a badge indicator
fn buildBadge(count: u32) VNode {
    const S = struct {
        var badge_text: [8]u8 = undefined;
    };
    const badge_str = if (count > 99)
        "99+"
    else
        std.fmt.bufPrint(&S.badge_text, "{d}", .{count}) catch "?";

    return div(.{
        .style = .{
            .background = Color.red,
            .border_radius = 8,
            .padding = Spacing.symmetric(2, 6),
        },
    }, &.{
        text(badge_str, .{
            .style = .{
                .font_size = 10,
                .color = Color.white,
                .font_weight = .bold,
            },
        }),
    });
}

/// Build the current screen based on active tab
fn buildScreen(state: *const app.AppState) VNode {
    return switch (state.current_tab) {
        .home => buildHomeScreen(state),
        .search => buildSearchScreen(state),
        .profile => buildProfileScreen(state),
        .settings => buildSettingsScreen(state),
    };
}

// ============================================================================
// Screen Builders
// ============================================================================

fn buildHomeScreen(state: *const app.AppState) VNode {
    _ = state;
    return column(.{
        .style = .{
            .padding = Spacing.all(16),
            .gap = 16,
        },
    }, &.{
        text("Welcome Home", .{
            .style = .{
                .font_size = 24,
                .font_weight = .bold,
            },
        }),
        text("Your personalized dashboard", .{
            .style = .{
                .font_size = 14,
                .color = Color.gray,
            },
        }),
        spacer(16),
        buildQuickActions(),
        spacer(16),
        text("Recent Activity", .{
            .style = .{
                .font_size = 18,
                .font_weight = .bold,
            },
        }),
        buildActivityList(),
    });
}

fn buildSearchScreen(state: *const app.AppState) VNode {
    const tab_state = state.getTabState(.search);
    const query = if (tab_state.search_query_len > 0)
        tab_state.search_query[0..tab_state.search_query_len]
    else
        "";

    return column(.{
        .style = .{
            .padding = Spacing.all(16),
            .gap = 16,
        },
    }, &.{
        text("Search", .{
            .style = .{
                .font_size = 24,
                .font_weight = .bold,
            },
        }),
        input(.{
            .placeholder = "Search...",
            .value = query,
            .style = .{
                .padding = Spacing.all(12),
                .background = Color.light_gray,
                .border_radius = 8,
            },
        }),
        spacer(8),
        text("Popular Searches", .{
            .style = .{
                .font_size = 16,
                .font_weight = .bold,
            },
        }),
        buildSearchSuggestions(),
    });
}

fn buildProfileScreen(state: *const app.AppState) VNode {
    return column(.{
        .style = .{
            .padding = Spacing.all(16),
            .gap = 16,
            .alignment = .center,
        },
    }, &.{
        spacer(32),
        // Avatar placeholder
        div(.{
            .style = .{
                .width = .{ .px = 80 },
                .height = .{ .px = 80 },
                .background = Color.light_gray,
                .border_radius = 40,
            },
        }, &.{}),
        text(state.user_name, .{
            .style = .{
                .font_size = 20,
                .font_weight = .bold,
            },
        }),
        spacer(16),
        buildProfileStats(),
        spacer(24),
        button("Edit Profile", .{
            .style = .{
                .padding = Spacing.symmetric(12, 24),
                .background = Color.primary,
                .color = Color.white,
                .border_radius = 8,
            },
        }),
    });
}

fn buildSettingsScreen(state: *const app.AppState) VNode {
    return column(.{
        .style = .{
            .padding = Spacing.all(16),
            .gap = 16,
        },
    }, &.{
        text("Settings", .{
            .style = .{
                .font_size = 24,
                .font_weight = .bold,
            },
        }),
        spacer(8),
        buildSettingRow("Dark Mode", state.dark_mode),
        buildSettingRow("Notifications", state.notifications_enabled),
        buildSettingRow("Auto-sync", true),
        spacer(16),
        text("About", .{
            .style = .{
                .font_size = 16,
                .font_weight = .bold,
            },
        }),
        buildInfoRow("Version", "1.0.0"),
        buildInfoRow("Build", "2025.12.24"),
    });
}

// ============================================================================
// Component Builders
// ============================================================================

fn buildQuickActions() VNode {
    return row(.{
        .style = .{
            .justify = .space_between,
            .gap = 12,
        },
    }, &.{
        buildActionCard("New", "plus"),
        buildActionCard("Scan", "qrcode"),
        buildActionCard("Share", "share"),
        buildActionCard("More", "ellipsis"),
    });
}

fn buildActionCard(label_text: []const u8, icon_name: []const u8) VNode {
    return column(.{
        .style = .{
            .padding = Spacing.all(16),
            .background = Color.light_gray,
            .border_radius = 12,
            .alignment = .center,
            .gap = 8,
        },
    }, &.{
        icon(icon_name, .{
            .style = .{ .color = Color.primary },
        }),
        text(label_text, .{
            .style = .{
                .font_size = 12,
                .color = Color.gray,
            },
        }),
    });
}

fn buildActivityList() VNode {
    return column(.{
        .style = .{ .gap = 8 },
    }, &.{
        buildActivityItem("Updated profile picture", "2 hours ago"),
        buildActivityItem("Completed task: Review PRs", "5 hours ago"),
        buildActivityItem("New follower: @dev_user", "Yesterday"),
    });
}

fn buildActivityItem(title: []const u8, time: []const u8) VNode {
    return row(.{
        .style = .{
            .padding = Spacing.all(12),
            .background = Color.light_gray,
            .border_radius = 8,
            .justify = .space_between,
        },
    }, &.{
        text(title, .{
            .style = .{ .font_size = 14 },
        }),
        text(time, .{
            .style = .{
                .font_size = 12,
                .color = Color.gray,
            },
        }),
    });
}

fn buildSearchSuggestions() VNode {
    return column(.{
        .style = .{ .gap = 8 },
    }, &.{
        buildSuggestionChip("zylix tutorial"),
        buildSuggestionChip("cross-platform"),
        buildSuggestionChip("animation"),
    });
}

fn buildSuggestionChip(suggestion: []const u8) VNode {
    return div(.{
        .style = .{
            .padding = Spacing.symmetric(8, 12),
            .background = Color.light_gray,
            .border_radius = 16,
        },
    }, &.{
        text(suggestion, .{
            .style = .{
                .font_size = 14,
                .color = Color.gray,
            },
        }),
    });
}

fn buildProfileStats() VNode {
    return row(.{
        .style = .{
            .justify = .space_evenly,
            .gap = 24,
        },
    }, &.{
        buildStatItem("128", "Posts"),
        buildStatItem("1.2K", "Followers"),
        buildStatItem("456", "Following"),
    });
}

fn buildStatItem(value: []const u8, label_text: []const u8) VNode {
    return column(.{
        .style = .{
            .alignment = .center,
            .gap = 4,
        },
    }, &.{
        text(value, .{
            .style = .{
                .font_size = 18,
                .font_weight = .bold,
            },
        }),
        text(label_text, .{
            .style = .{
                .font_size = 12,
                .color = Color.gray,
            },
        }),
    });
}

fn buildSettingRow(label_text: []const u8, enabled: bool) VNode {
    return row(.{
        .style = .{
            .padding = Spacing.all(12),
            .background = Color.light_gray,
            .border_radius = 8,
            .justify = .space_between,
            .alignment = .center,
        },
    }, &.{
        text(label_text, .{
            .style = .{ .font_size = 16 },
        }),
        toggle(.{ .active = enabled }),
    });
}

fn buildInfoRow(label_text: []const u8, value: []const u8) VNode {
    return row(.{
        .style = .{
            .padding = Spacing.all(12),
            .justify = .space_between,
        },
    }, &.{
        text(label_text, .{
            .style = .{
                .font_size = 14,
                .color = Color.gray,
            },
        }),
        text(value, .{
            .style = .{ .font_size = 14 },
        }),
    });
}

// ============================================================================
// Element Constructors
// ============================================================================

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

pub fn input(props: Props) VNode {
    return .{ .tag = .input, .props = props };
}

pub fn toggle(props: Props) VNode {
    return .{ .tag = .toggle, .props = props };
}

pub fn spacer(size: u32) VNode {
    return .{
        .tag = .spacer,
        .props = .{
            .style = .{ .height = .{ .px = size }, .width = .{ .px = size } },
        },
    };
}

// ============================================================================
// Tests
// ============================================================================

test "build app" {
    const state = app.AppState{ .initialized = true };
    const view = buildApp(&state);
    try std.testing.expectEqual(Tag.column, view.tag);
}

test "tab labels and icons" {
    try std.testing.expectEqualStrings("Home", Tab.home.label());
    try std.testing.expectEqualStrings("house", Tab.home.icon());
    try std.testing.expectEqualStrings("Search", Tab.search.label());
    try std.testing.expectEqualStrings("magnifyingglass", Tab.search.icon());
}

test "screen builders" {
    const state = app.AppState{ .initialized = true };

    const home = buildHomeScreen(&state);
    try std.testing.expectEqual(Tag.column, home.tag);

    const search = buildSearchScreen(&state);
    try std.testing.expectEqual(Tag.column, search.tag);

    const profile = buildProfileScreen(&state);
    try std.testing.expectEqual(Tag.column, profile.tag);

    const settings = buildSettingsScreen(&state);
    try std.testing.expectEqual(Tag.column, settings.tag);
}
