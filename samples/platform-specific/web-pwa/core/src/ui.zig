//! Web PWA - UI Components

const std = @import("std");
const app = @import("app.zig");

pub const Tag = enum { column, row, div, text, button, scroll, icon, progress };

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
    pub const background: u32 = 0xFF121212;
    pub const surface: u32 = 0xFF1E1E1E;
    pub const card: u32 = 0xFF2D2D2D;
    pub const text: u32 = 0xFFFFFFFF;
    pub const text_secondary: u32 = 0xFFB3B3B3;
    pub const primary: u32 = 0xFF6200EE;
    pub const secondary: u32 = 0xFF03DAC6;
    pub const success: u32 = 0xFF4CAF50;
    pub const warning: u32 = 0xFFFF9800;
    pub const error_color: u32 = 0xFFF44336;
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
        .style = .{ .font_size = 24, .font_weight = 700, .color = Color.text },
    });
    S.items[1] = spacer();
    S.items[2] = buildOnlineIndicator(state.is_online);

    return row(.{
        .style = .{ .padding = Spacing.symmetric(16, 12) },
    }, &S.items);
}

fn buildOnlineIndicator(is_online: bool) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = div(.{
        .style = .{
            .background = if (is_online) Color.success else Color.error_color,
            .width = 8,
            .height = 8,
            .border_radius = 4,
        },
    }, &.{});
    S.items[1] = text(if (is_online) "Online" else "Offline", .{
        .style = .{ .font_size = 12, .color = Color.text_secondary },
    });

    return row(.{ .style = .{ .gap = 6 } }, &S.items);
}

fn buildContent(state: *const app.AppState) VNode {
    return switch (state.current_screen) {
        .home => buildHomeScreen(state),
        .cache => buildCacheScreen(state),
        .push => buildPushScreen(state),
        .install => buildInstallScreen(state),
    };
}

fn buildHomeScreen(state: *const app.AppState) VNode {
    const S = struct {
        var items: [4]VNode = undefined;
    };

    S.items[0] = buildStatusCard("Service Worker", state.sw_registered, state.sw_version);
    S.items[1] = buildFeatureCard("Caching", "folder", "Cache resources for offline use", Color.primary);
    S.items[2] = buildFeatureCard("Push Notifications", "bell", "Receive updates in background", Color.secondary);
    S.items[3] = buildFeatureCard("Install App", "download", "Add to home screen", Color.success);

    return column(.{
        .style = .{ .padding = Spacing.all(16), .gap = 12, .flex = 1 },
    }, &S.items);
}

fn buildStatusCard(label: []const u8, is_active: bool, version: []const u8) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
    };

    S.items[0] = column(.{ .style = .{ .flex = 1, .gap = 4 } }, &.{
        text(label, .{ .style = .{ .font_size = 16, .font_weight = 600, .color = Color.text } }),
        text(version, .{ .style = .{ .font_size = 14, .color = Color.text_secondary } }),
    });
    S.items[1] = spacer();
    S.items[2] = div(.{
        .style = .{
            .background = if (is_active) Color.success else Color.error_color,
            .width = 12,
            .height = 12,
            .border_radius = 6,
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

fn buildFeatureCard(title: []const u8, icon_name: []const u8, description: []const u8, color: u32) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = div(.{
        .style = .{ .background = color, .width = 44, .height = 44, .border_radius = 10 },
    }, &.{
        iconView(icon_name, .{ .style = .{ .color = Color.text, .font_size = 22 } }),
    });
    S.items[1] = column(.{ .style = .{ .flex = 1, .gap = 2 } }, &.{
        text(title, .{ .style = .{ .font_size = 16, .font_weight = 600, .color = Color.text } }),
        text(description, .{ .style = .{ .font_size = 14, .color = Color.text_secondary } }),
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

fn buildCacheScreen(state: *const app.AppState) VNode {
    const S = struct {
        var items: [4]VNode = undefined;
        var size_buf: [24]u8 = undefined;
        var count_buf: [16]u8 = undefined;
    };

    const size_kb = state.cache_size_bytes / 1024;
    const size_str = std.fmt.bufPrint(&S.size_buf, "{d} KB cached", .{size_kb}) catch "0 KB";
    const count_str = std.fmt.bufPrint(&S.count_buf, "{d} resources", .{state.cached_count}) catch "0";

    S.items[0] = text("Cache Strategy", .{
        .style = .{ .font_size = 18, .font_weight = 600, .color = Color.text },
    });

    S.items[1] = buildStrategyOption(state.cache_strategy);

    S.items[2] = column(.{ .style = .{ .gap = 4, .padding = .{ .top = 16 } } }, &.{
        text(size_str, .{ .style = .{ .font_size = 24, .font_weight = 700, .color = Color.primary } }),
        text(count_str, .{ .style = .{ .font_size = 14, .color = Color.text_secondary } }),
    });

    S.items[3] = text("Clear Cache", .{
        .style = .{
            .font_size = 16,
            .font_weight = 600,
            .color = Color.error_color,
            .padding = Spacing.symmetric(0, 12),
        },
    });

    return column(.{
        .style = .{ .padding = Spacing.all(16), .gap = 12, .flex = 1 },
    }, &S.items);
}

fn buildStrategyOption(strategy: app.CacheStrategy) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = text(strategy.name(), .{ .style = .{ .font_size = 16, .color = Color.text } });
    S.items[1] = text(strategy.description(), .{ .style = .{ .font_size = 14, .color = Color.text_secondary } });

    return div(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(16),
            .gap = 4,
        },
    }, &S.items);
}

fn buildPushScreen(state: *const app.AppState) VNode {
    const S = struct {
        var items: [4]VNode = undefined;
        var pending_buf: [24]u8 = undefined;
    };

    const pending_str = std.fmt.bufPrint(&S.pending_buf, "{d} pending", .{state.pending_notifications}) catch "0";

    S.items[0] = text("Push Notifications", .{
        .style = .{ .font_size = 18, .font_weight = 600, .color = Color.text },
    });

    S.items[1] = buildPermissionStatus(state.push_permission);

    S.items[2] = buildToggleRow("Enable Push", state.push_enabled);

    S.items[3] = row(.{ .style = .{ .gap = 8, .padding = .{ .top = 16 } } }, &.{
        iconView("bell", .{ .style = .{ .color = Color.warning, .font_size = 20 } }),
        text(pending_str, .{ .style = .{ .font_size = 16, .color = Color.text } }),
    });

    return column(.{
        .style = .{ .padding = Spacing.all(16), .gap = 12, .flex = 1 },
    }, &S.items);
}

fn buildPermissionStatus(permission: app.PushPermission) VNode {
    const color = switch (permission) {
        .default => Color.warning,
        .granted => Color.success,
        .denied => Color.error_color,
    };

    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = text("Permission", .{ .style = .{ .font_size = 14, .color = Color.text_secondary } });
    S.items[1] = text(permission.name(), .{ .style = .{ .font_size = 16, .font_weight = 600, .color = color } });

    return div(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(16),
            .gap = 4,
        },
    }, &S.items);
}

fn buildToggleRow(label: []const u8, is_enabled: bool) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = text(label, .{ .style = .{ .font_size = 16, .color = Color.text, .flex = 1 } });
    S.items[1] = div(.{
        .style = .{
            .background = if (is_enabled) Color.primary else Color.card,
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

fn buildInstallScreen(state: *const app.AppState) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
    };

    S.items[0] = div(.{
        .style = .{ .background = Color.surface, .width = 96, .height = 96, .border_radius = 24 },
    }, &.{
        iconView("download", .{ .style = .{ .color = Color.primary, .font_size = 48 } }),
    });

    if (state.is_installed) {
        S.items[1] = text("App Installed", .{
            .style = .{ .font_size = 24, .font_weight = 700, .color = Color.success },
        });
        S.items[2] = text("Running as standalone app", .{
            .style = .{ .font_size = 16, .color = Color.text_secondary },
        });
    } else if (state.can_install) {
        S.items[1] = text("Install App", .{
            .style = .{ .font_size = 24, .font_weight = 700, .color = Color.text },
        });
        S.items[2] = text("Add to Home Screen", .{
            .style = .{
                .font_size = 16,
                .font_weight = 600,
                .color = Color.text,
                .background = Color.primary,
                .padding = Spacing.symmetric(32, 14),
                .border_radius = 12,
            },
        });
    } else {
        S.items[1] = text("Not Available", .{
            .style = .{ .font_size = 24, .font_weight = 700, .color = Color.text_secondary },
        });
        S.items[2] = text("Install not supported", .{
            .style = .{ .font_size = 16, .color = Color.text_secondary },
        });
    }

    return column(.{
        .style = .{ .padding = Spacing.all(16), .gap = 16, .flex = 1 },
    }, &S.items);
}

fn buildTabBar(state: *const app.AppState) VNode {
    const S = struct {
        var items: [4]VNode = undefined;
    };

    S.items[0] = buildTabItem(.home, state.current_screen == .home);
    S.items[1] = buildTabItem(.cache, state.current_screen == .cache);
    S.items[2] = buildTabItem(.push, state.current_screen == .push);
    S.items[3] = buildTabItem(.install, state.current_screen == .install);

    return row(.{
        .style = .{
            .background = Color.surface,
            .padding = Spacing.symmetric(0, 8),
        },
    }, &S.items);
}

fn buildTabItem(screen: app.Screen, selected: bool) VNode {
    const color = if (selected) Color.primary else Color.text_secondary;

    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = iconView(screen.icon(), .{ .style = .{ .color = color, .font_size = 20 } });
    S.items[1] = text(screen.title(), .{ .style = .{ .font_size = 10, .color = color } });

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
