//! Android Exclusive - UI Components

const std = @import("std");
const app = @import("app.zig");

pub const Tag = enum { column, row, div, text, button, scroll, icon, card };

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
    pub const background: u32 = 0xFF1C1B1F;
    pub const surface: u32 = 0xFF2B2930;
    pub const surface_variant: u32 = 0xFF49454F;
    pub const text: u32 = 0xFFE6E1E5;
    pub const text_secondary: u32 = 0xFFCAC4D0;
    pub const primary: u32 = 0xFF6750A4;
    pub const secondary: u32 = 0xFF625B71;
    pub const tertiary: u32 = 0xFF7D5260;
    pub const error_color: u32 = 0xFFB3261E;
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
    S.content[2] = buildNavBar(state);

    return column(.{
        .style = .{ .background = Color.background },
    }, &S.content);
}

fn buildHeader(state: *const app.AppState) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = text(state.current_screen.title(), .{
        .style = .{ .font_size = 24, .font_weight = 500, .color = Color.text },
    });
    S.items[1] = spacer();

    return row(.{
        .style = .{ .padding = Spacing.symmetric(16, 16) },
    }, &S.items);
}

fn buildContent(state: *const app.AppState) VNode {
    return switch (state.current_screen) {
        .home => buildHomeScreen(state),
        .material_you => buildMaterialYouScreen(state),
        .widgets => buildWidgetsScreen(state),
        .notifications => buildNotificationsScreen(state),
        .shortcuts => buildShortcutsScreen(state),
    };
}

fn buildHomeScreen(state: *const app.AppState) VNode {
    _ = state;
    const S = struct {
        var items: [5]VNode = undefined;
    };

    S.items[0] = buildFeatureCard("Material You", "Dynamic theming", "palette", Color.primary);
    S.items[1] = buildFeatureCard("Widgets", "Home screen widgets", "widgets", Color.secondary);
    S.items[2] = buildFeatureCard("Notifications", "Rich notifications", "notifications", Color.tertiary);
    S.items[3] = buildFeatureCard("Shortcuts", "App shortcuts", "shortcut", Color.primary);
    S.items[4] = buildFeatureCard("Work Profile", "Enterprise features", "work", Color.secondary);

    return column(.{
        .style = .{ .padding = Spacing.all(16), .gap = 12, .flex = 1 },
    }, &S.items);
}

fn buildFeatureCard(title: []const u8, description: []const u8, icon_name: []const u8, color: u32) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = div(.{
        .style = .{ .background = color, .width = 48, .height = 48, .border_radius = 12 },
    }, &.{
        iconView(icon_name, .{ .style = .{ .color = Color.text, .font_size = 24 } }),
    });
    S.items[1] = column(.{ .style = .{ .flex = 1, .gap = 4 } }, &.{
        text(title, .{ .style = .{ .font_size = 16, .font_weight = 500, .color = Color.text } }),
        text(description, .{ .style = .{ .font_size = 14, .color = Color.text_secondary } }),
    });

    return row(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 16,
            .padding = Spacing.all(16),
            .gap = 16,
        },
    }, &S.items);
}

fn buildMaterialYouScreen(state: *const app.AppState) VNode {
    const S = struct {
        var items: [4]VNode = undefined;
    };

    S.items[0] = text("Dynamic Colors", .{
        .style = .{ .font_size = 20, .font_weight = 500, .color = Color.text },
    });

    S.items[1] = row(.{ .style = .{ .gap = 12, .padding = .{ .top = 16 } } }, &.{
        buildColorSwatch("Primary", state.color_scheme.primary),
        buildColorSwatch("Secondary", state.color_scheme.secondary),
    });

    S.items[2] = row(.{ .style = .{ .gap = 12 } }, &.{
        buildColorSwatch("Surface", state.color_scheme.surface),
        buildColorSwatch("Background", state.color_scheme.background),
    });

    S.items[3] = buildToggleRow("Dynamic Colors", state.dynamic_colors_enabled);

    return column(.{
        .style = .{ .padding = Spacing.all(16), .gap = 16, .flex = 1 },
    }, &S.items);
}

fn buildColorSwatch(label: []const u8, color: u32) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = div(.{
        .style = .{ .background = color, .width = 64, .height = 64, .border_radius = 16 },
    }, &.{});
    S.items[1] = text(label, .{ .style = .{ .font_size = 12, .color = Color.text_secondary } });

    return column(.{ .style = .{ .gap = 8, .flex = 1 } }, &S.items);
}

fn buildToggleRow(label: []const u8, is_enabled: bool) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = text(label, .{ .style = .{ .font_size = 16, .color = Color.text, .flex = 1 } });
    S.items[1] = div(.{
        .style = .{
            .background = if (is_enabled) Color.primary else Color.surface_variant,
            .width = 52,
            .height = 32,
            .border_radius = 16,
        },
    }, &.{});

    return row(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(16),
        },
    }, &S.items);
}

fn buildWidgetsScreen(state: *const app.AppState) VNode {
    const max_display: usize = 3;
    const widget_count: usize = state.widget_count;
    const display_count: usize = @min(widget_count, max_display);

    const S = struct {
        var items: [4]VNode = undefined;
    };

    S.items[0] = text("Available Widgets", .{
        .style = .{ .font_size = 20, .font_weight = 500, .color = Color.text },
    });

    for (0..display_count) |i| {
        S.items[i + 1] = buildWidgetCard(&state.widgets[i]);
    }

    const slice_end = display_count + 1;
    return column(.{
        .style = .{ .padding = Spacing.all(16), .gap = 12, .flex = 1 },
    }, S.items[0..slice_end]);
}

fn buildWidgetCard(widget: *const app.Widget) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
        var size_buf: [16]u8 = undefined;
    };

    const size_str = std.fmt.bufPrint(&S.size_buf, "{d}x{d}", .{ widget.min_width, widget.min_height }) catch "0x0";

    S.items[0] = column(.{ .style = .{ .flex = 1, .gap = 4 } }, &.{
        text(widget.name, .{ .style = .{ .font_size = 16, .font_weight = 500, .color = Color.text } }),
        text(widget.description, .{ .style = .{ .font_size = 14, .color = Color.text_secondary } }),
        text(size_str, .{ .style = .{ .font_size = 12, .color = Color.text_secondary } }),
    });
    S.items[1] = text(if (widget.is_placed) "Placed" else "Add", .{
        .style = .{
            .font_size = 14,
            .font_weight = 500,
            .color = if (widget.is_placed) Color.text_secondary else Color.primary,
        },
    });

    return row(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 16,
            .padding = Spacing.all(16),
            .gap = 12,
        },
    }, &S.items);
}

fn buildNotificationsScreen(state: *const app.AppState) VNode {
    const S = struct {
        var items: [5]VNode = undefined;
        var count_buf: [16]u8 = undefined;
    };

    const count_str = std.fmt.bufPrint(&S.count_buf, "{d} notifications", .{state.notification_count}) catch "0";

    S.items[0] = text("Notification Channels", .{
        .style = .{ .font_size = 20, .font_weight = 500, .color = Color.text },
    });

    S.items[1] = buildChannelRow(.general, state.channels_enabled[0]);
    S.items[2] = buildChannelRow(.messages, state.channels_enabled[1]);
    S.items[3] = buildChannelRow(.updates, state.channels_enabled[2]);
    S.items[4] = text(count_str, .{
        .style = .{ .font_size = 14, .color = Color.text_secondary, .padding = .{ .top = 16 } },
    });

    return column(.{
        .style = .{ .padding = Spacing.all(16), .gap = 12, .flex = 1 },
    }, &S.items);
}

fn buildChannelRow(channel: app.NotificationChannel, is_enabled: bool) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
    };

    S.items[0] = column(.{ .style = .{ .flex = 1, .gap = 2 } }, &.{
        text(channel.name(), .{ .style = .{ .font_size = 16, .color = Color.text } }),
        text(channel.importance(), .{ .style = .{ .font_size = 14, .color = Color.text_secondary } }),
    });
    S.items[1] = spacer();
    S.items[2] = div(.{
        .style = .{
            .background = if (is_enabled) Color.primary else Color.surface_variant,
            .width = 52,
            .height = 32,
            .border_radius = 16,
        },
    }, &.{});

    return row(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(16),
        },
    }, &S.items);
}

fn buildShortcutsScreen(state: *const app.AppState) VNode {
    const max_display: usize = 3;
    const shortcut_count: usize = state.shortcut_count;
    const display_count: usize = @min(shortcut_count, max_display);

    const S = struct {
        var items: [4]VNode = undefined;
    };

    S.items[0] = text("App Shortcuts", .{
        .style = .{ .font_size = 20, .font_weight = 500, .color = Color.text },
    });

    for (0..display_count) |i| {
        S.items[i + 1] = buildShortcutRow(&state.shortcuts[i]);
    }

    const slice_end = display_count + 1;
    return column(.{
        .style = .{ .padding = Spacing.all(16), .gap = 12, .flex = 1 },
    }, S.items[0..slice_end]);
}

fn buildShortcutRow(shortcut: *const app.AppShortcut) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
    };

    S.items[0] = iconView(shortcut.icon, .{ .style = .{ .color = Color.primary, .font_size = 24 } });
    S.items[1] = column(.{ .style = .{ .flex = 1, .gap = 2 } }, &.{
        text(shortcut.short_label, .{ .style = .{ .font_size = 16, .color = Color.text } }),
        text(shortcut.long_label, .{ .style = .{ .font_size = 14, .color = Color.text_secondary } }),
    });
    S.items[2] = iconView(if (shortcut.is_pinned) "push_pin" else "push_pin_outlined", .{
        .style = .{ .color = if (shortcut.is_pinned) Color.primary else Color.text_secondary, .font_size = 20 },
    });

    return row(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(16),
            .gap = 12,
        },
    }, &S.items);
}

fn buildNavBar(state: *const app.AppState) VNode {
    const S = struct {
        var items: [5]VNode = undefined;
    };

    S.items[0] = buildNavItem(.home, state.current_screen == .home);
    S.items[1] = buildNavItem(.material_you, state.current_screen == .material_you);
    S.items[2] = buildNavItem(.widgets, state.current_screen == .widgets);
    S.items[3] = buildNavItem(.notifications, state.current_screen == .notifications);
    S.items[4] = buildNavItem(.shortcuts, state.current_screen == .shortcuts);

    return row(.{
        .style = .{
            .background = Color.surface,
            .padding = Spacing.symmetric(0, 12),
        },
    }, &S.items);
}

fn buildNavItem(screen: app.Screen, selected: bool) VNode {
    const color = if (selected) Color.primary else Color.text_secondary;

    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = iconView(screen.icon(), .{ .style = .{ .color = color, .font_size = 24 } });
    S.items[1] = text(screen.title(), .{ .style = .{ .font_size = 12, .color = color } });

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
