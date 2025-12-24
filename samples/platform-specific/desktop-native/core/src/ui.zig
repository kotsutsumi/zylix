//! Desktop Native - UI Components

const std = @import("std");
const app = @import("app.zig");

pub const Tag = enum { column, row, div, text, button, scroll, icon, menu };

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
    pub const background: u32 = 0xFF1E1E1E;
    pub const surface: u32 = 0xFF252526;
    pub const hover: u32 = 0xFF2A2D2E;
    pub const text: u32 = 0xFFCCCCCC;
    pub const text_secondary: u32 = 0xFF858585;
    pub const accent: u32 = 0xFF0078D4;
    pub const success: u32 = 0xFF4EC9B0;
    pub const warning: u32 = 0xFFDCDCAA;
    pub const border: u32 = 0xFF3C3C3C;
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
        var content: [2]VNode = undefined;
    };

    S.content[0] = buildSidebar(state);
    S.content[1] = buildMainContent(state);

    return row(.{
        .style = .{ .background = Color.background },
    }, &S.content);
}

fn buildSidebar(state: *const app.AppState) VNode {
    const S = struct {
        var items: [5]VNode = undefined;
    };

    S.items[0] = buildSidebarItem(.home, state.current_screen == .home);
    S.items[1] = buildSidebarItem(.tray, state.current_screen == .tray);
    S.items[2] = buildSidebarItem(.files, state.current_screen == .files);
    S.items[3] = buildSidebarItem(.shortcuts, state.current_screen == .shortcuts);
    S.items[4] = buildSidebarItem(.window, state.current_screen == .window);

    return column(.{
        .style = .{
            .background = Color.surface,
            .width = 56,
            .padding = Spacing.symmetric(0, 8),
            .gap = 4,
        },
    }, &S.items);
}

fn buildSidebarItem(screen: app.Screen, selected: bool) VNode {
    return div(.{
        .style = .{
            .background = if (selected) Color.accent else 0,
            .width = 40,
            .height = 40,
            .border_radius = 4,
        },
    }, &.{
        iconView(screen.icon(), .{
            .style = .{ .color = if (selected) Color.text else Color.text_secondary, .font_size = 20 },
        }),
    });
}

fn buildMainContent(state: *const app.AppState) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = buildHeader(state);
    S.items[1] = buildContent(state);

    return column(.{
        .style = .{ .flex = 1 },
    }, &S.items);
}

fn buildHeader(state: *const app.AppState) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = text(state.current_screen.title(), .{
        .style = .{ .font_size = 18, .font_weight = 600, .color = Color.text },
    });
    S.items[1] = spacer();

    return row(.{
        .style = .{
            .padding = Spacing.all(16),
            .background = Color.surface,
        },
    }, &S.items);
}

fn buildContent(state: *const app.AppState) VNode {
    return switch (state.current_screen) {
        .home => buildHomeScreen(state),
        .tray => buildTrayScreen(state),
        .files => buildFilesScreen(state),
        .shortcuts => buildShortcutsScreen(state),
        .window => buildWindowScreen(state),
    };
}

fn buildHomeScreen(state: *const app.AppState) VNode {
    _ = state;
    const S = struct {
        var items: [4]VNode = undefined;
    };

    S.items[0] = buildFeatureCard("System Tray", "menubar.rectangle", "Tray icon and menu");
    S.items[1] = buildFeatureCard("File System", "folder", "Open, save, and watch files");
    S.items[2] = buildFeatureCard("Keyboard Shortcuts", "command", "Global and local shortcuts");
    S.items[3] = buildFeatureCard("Window Management", "macwindow", "Fullscreen, always on top");

    return column(.{
        .style = .{ .padding = Spacing.all(16), .gap = 12, .flex = 1 },
    }, &S.items);
}

fn buildFeatureCard(title: []const u8, icon_name: []const u8, description: []const u8) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = iconView(icon_name, .{ .style = .{ .color = Color.accent, .font_size = 24 } });
    S.items[1] = column(.{ .style = .{ .flex = 1, .gap = 4 } }, &.{
        text(title, .{ .style = .{ .font_size = 14, .font_weight = 600, .color = Color.text } }),
        text(description, .{ .style = .{ .font_size = 12, .color = Color.text_secondary } }),
    });

    return row(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 4,
            .padding = Spacing.all(12),
            .gap = 12,
        },
    }, &S.items);
}

fn buildTrayScreen(state: *const app.AppState) VNode {
    const max_display: usize = 4;
    const item_count: usize = state.tray_item_count;
    const display_count: usize = @min(item_count, max_display);

    const S = struct {
        var items: [6]VNode = undefined;
        var badge_buf: [16]u8 = undefined;
    };

    const badge_str = std.fmt.bufPrint(&S.badge_buf, "{d}", .{state.badge_count}) catch "0";

    S.items[0] = text("Tray Menu Items", .{
        .style = .{ .font_size = 14, .font_weight = 600, .color = Color.text },
    });

    for (0..display_count) |i| {
        S.items[i + 1] = buildTrayMenuItem(&state.tray_menu_items[i]);
    }

    S.items[display_count + 1] = row(.{ .style = .{ .gap = 8, .padding = .{ .top = 16 } } }, &.{
        text("Badge Count:", .{ .style = .{ .font_size = 13, .color = Color.text_secondary } }),
        text(badge_str, .{ .style = .{ .font_size = 13, .font_weight = 600, .color = Color.accent } }),
    });

    const slice_end = display_count + 2;
    return column(.{
        .style = .{ .padding = Spacing.all(16), .gap = 8, .flex = 1 },
    }, S.items[0..slice_end]);
}

fn buildTrayMenuItem(item: *const app.TrayMenuItem) VNode {
    if (item.is_separator) {
        return div(.{
            .style = .{ .background = Color.border, .height = 1 },
        }, &.{});
    }

    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = iconView(item.icon, .{ .style = .{ .color = Color.text_secondary, .font_size = 16 } });
    S.items[1] = text(item.label, .{ .style = .{ .font_size = 13, .color = Color.text } });

    return row(.{
        .style = .{
            .background = Color.hover,
            .padding = Spacing.symmetric(12, 8),
            .gap = 8,
            .border_radius = 4,
        },
    }, &S.items);
}

fn buildFilesScreen(state: *const app.AppState) VNode {
    const max_display: usize = 3;
    const file_count: usize = state.recent_file_count;
    const display_count: usize = @min(file_count, max_display);

    const S = struct {
        var items: [5]VNode = undefined;
        var watch_buf: [24]u8 = undefined;
    };

    const watch_str = std.fmt.bufPrint(&S.watch_buf, "{d} paths watched", .{state.watching_paths}) catch "0";

    S.items[0] = text("Recent Files", .{
        .style = .{ .font_size = 14, .font_weight = 600, .color = Color.text },
    });

    for (0..display_count) |i| {
        S.items[i + 1] = buildRecentFileRow(&state.recent_files[i]);
    }

    S.items[display_count + 1] = text(watch_str, .{
        .style = .{ .font_size = 12, .color = Color.text_secondary, .padding = .{ .top = 16 } },
    });

    const slice_end = display_count + 2;
    return column(.{
        .style = .{ .padding = Spacing.all(16), .gap = 8, .flex = 1 },
    }, S.items[0..slice_end]);
}

fn buildRecentFileRow(file: *const app.RecentFile) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
        var size_buf: [16]u8 = undefined;
    };

    const size_str = std.fmt.bufPrint(&S.size_buf, "{d} B", .{file.size}) catch "0 B";

    S.items[0] = iconView("doc", .{ .style = .{ .color = Color.text_secondary, .font_size = 16 } });
    S.items[1] = column(.{ .style = .{ .flex = 1, .gap = 2 } }, &.{
        text(file.name, .{ .style = .{ .font_size = 13, .color = Color.text } }),
        text(file.path, .{ .style = .{ .font_size = 11, .color = Color.text_secondary } }),
    });
    S.items[2] = text(size_str, .{ .style = .{ .font_size = 11, .color = Color.text_secondary } });

    return row(.{
        .style = .{
            .background = Color.surface,
            .padding = Spacing.all(8),
            .gap = 8,
            .border_radius = 4,
        },
    }, &S.items);
}

fn buildShortcutsScreen(state: *const app.AppState) VNode {
    const max_display: usize = 5;
    const shortcut_count: usize = state.shortcut_count;
    const display_count: usize = @min(shortcut_count, max_display);

    const S = struct {
        var items: [6]VNode = undefined;
    };

    S.items[0] = text("Keyboard Shortcuts", .{
        .style = .{ .font_size = 14, .font_weight = 600, .color = Color.text },
    });

    for (0..display_count) |i| {
        S.items[i + 1] = buildShortcutRow(&state.shortcuts[i]);
    }

    const slice_end = display_count + 1;
    return column(.{
        .style = .{ .padding = Spacing.all(16), .gap = 8, .flex = 1 },
    }, S.items[0..slice_end]);
}

fn buildShortcutRow(shortcut: *const app.Shortcut) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
    };

    S.items[0] = text(shortcut.keys, .{
        .style = .{
            .font_size = 12,
            .color = Color.text,
            .background = Color.hover,
            .padding = Spacing.symmetric(8, 4),
            .border_radius = 4,
        },
    });
    S.items[1] = text(shortcut.action, .{
        .style = .{ .font_size = 13, .color = Color.text, .flex = 1 },
    });
    S.items[2] = text(if (shortcut.is_global) "Global" else "Local", .{
        .style = .{ .font_size = 11, .color = Color.text_secondary },
    });

    return row(.{
        .style = .{
            .background = Color.surface,
            .padding = Spacing.all(8),
            .gap = 12,
            .border_radius = 4,
        },
    }, &S.items);
}

fn buildWindowScreen(state: *const app.AppState) VNode {
    const S = struct {
        var items: [4]VNode = undefined;
        var size_buf: [24]u8 = undefined;
    };

    const size_str = std.fmt.bufPrint(&S.size_buf, "{d} x {d}", .{ state.window_width, state.window_height }) catch "0x0";

    S.items[0] = text("Window Settings", .{
        .style = .{ .font_size = 14, .font_weight = 600, .color = Color.text },
    });

    S.items[1] = buildToggleRow("Fullscreen", state.is_fullscreen);
    S.items[2] = buildToggleRow("Always on Top", state.is_always_on_top);
    S.items[3] = row(.{ .style = .{ .gap = 8, .padding = .{ .top = 8 } } }, &.{
        text("Window Size:", .{ .style = .{ .font_size = 13, .color = Color.text_secondary } }),
        text(size_str, .{ .style = .{ .font_size = 13, .color = Color.text } }),
    });

    return column(.{
        .style = .{ .padding = Spacing.all(16), .gap = 12, .flex = 1 },
    }, &S.items);
}

fn buildToggleRow(label: []const u8, is_enabled: bool) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = text(label, .{ .style = .{ .font_size = 13, .color = Color.text, .flex = 1 } });
    S.items[1] = div(.{
        .style = .{
            .background = if (is_enabled) Color.accent else Color.hover,
            .width = 40,
            .height = 20,
            .border_radius = 10,
        },
    }, &.{});

    return row(.{
        .style = .{
            .background = Color.surface,
            .padding = Spacing.symmetric(12, 8),
            .border_radius = 4,
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
    try std.testing.expectEqual(Tag.row, view.tag);
}

test "render" {
    app.init();
    defer app.deinit();
    const root = render();
    try std.testing.expectEqual(Tag.row, root[0].tag);
}
