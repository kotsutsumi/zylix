//! iOS Exclusive - UI Components

const std = @import("std");
const app = @import("app.zig");

pub const Tag = enum { column, row, div, text, button, scroll, icon, list };

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
    pub const blue: u32 = 0xFF007AFF;
    pub const green: u32 = 0xFF34C759;
    pub const red: u32 = 0xFFFF3B30;
    pub const orange: u32 = 0xFFFF9500;
    pub const purple: u32 = 0xFFAF52DE;
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
        var items: [2]VNode = undefined;
    };

    S.items[0] = text(state.current_screen.title(), .{
        .style = .{ .font_size = 28, .font_weight = 700, .color = Color.text },
    });
    S.items[1] = spacer();

    return row(.{
        .style = .{ .padding = Spacing.symmetric(16, 12) },
    }, &S.items);
}

fn buildContent(state: *const app.AppState) VNode {
    return switch (state.current_screen) {
        .home => buildHomeScreen(state),
        .biometrics => buildBiometricsScreen(state),
        .haptics => buildHapticsScreen(state),
        .health => buildHealthScreen(state),
        .siri => buildSiriScreen(state),
    };
}

fn buildHomeScreen(state: *const app.AppState) VNode {
    _ = state;
    const S = struct {
        var items: [5]VNode = undefined;
    };

    S.items[0] = buildFeatureCard("Face ID & Touch ID", "faceid", "Biometric authentication", Color.blue);
    S.items[1] = buildFeatureCard("Haptic Feedback", "hand.tap", "Tactile response system", Color.purple);
    S.items[2] = buildFeatureCard("HealthKit", "heart.fill", "Health data integration", Color.red);
    S.items[3] = buildFeatureCard("Siri Shortcuts", "waveform", "Voice command integration", Color.orange);
    S.items[4] = buildFeatureCard("Widgets", "square.grid.2x2", "Home screen widgets", Color.green);

    return column(.{
        .style = .{ .padding = Spacing.all(16), .gap = 12, .flex = 1 },
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
        text(title, .{ .style = .{ .font_size = 17, .font_weight = 600, .color = Color.text } }),
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

fn buildBiometricsScreen(state: *const app.AppState) VNode {
    const S = struct {
        var items: [4]VNode = undefined;
    };

    S.items[0] = div(.{
        .style = .{ .background = Color.surface, .width = 120, .height = 120, .border_radius = 60 },
    }, &.{
        iconView(state.biometric_type.icon(), .{ .style = .{ .color = Color.blue, .font_size = 48 } }),
    });

    S.items[1] = text(state.biometric_type.name(), .{
        .style = .{ .font_size = 24, .font_weight = 700, .color = Color.text },
    });

    S.items[2] = text(if (state.is_authenticated) "Authenticated" else "Not Authenticated", .{
        .style = .{
            .font_size = 16,
            .color = if (state.is_authenticated) Color.green else Color.text_secondary,
        },
    });

    S.items[3] = text("Authenticate", .{
        .style = .{
            .font_size = 17,
            .font_weight = 600,
            .color = Color.text,
            .background = Color.blue,
            .padding = Spacing.symmetric(32, 14),
            .border_radius = 12,
        },
    });

    return column(.{
        .style = .{ .padding = Spacing.all(16), .gap = 24, .flex = 1 },
    }, &S.items);
}

fn buildHapticsScreen(state: *const app.AppState) VNode {
    _ = state;
    const S = struct {
        var items: [6]VNode = undefined;
    };

    S.items[0] = text("Impact Styles", .{
        .style = .{ .font_size = 20, .font_weight = 600, .color = Color.text },
    });

    S.items[1] = buildHapticButton("Light", .light);
    S.items[2] = buildHapticButton("Medium", .medium);
    S.items[3] = buildHapticButton("Heavy", .heavy);

    S.items[4] = text("Notification Types", .{
        .style = .{ .font_size = 20, .font_weight = 600, .color = Color.text, .padding = .{ .top = 16 } },
    });

    S.items[5] = row(.{ .style = .{ .gap = 12 } }, &.{
        buildNotificationButton("Success", .success),
        buildNotificationButton("Warning", .warning),
        buildNotificationButton("Error", .error_type),
    });

    return column(.{
        .style = .{ .padding = Spacing.all(16), .gap = 12, .flex = 1 },
    }, &S.items);
}

fn buildHapticButton(label: []const u8, style: app.HapticStyle) VNode {
    _ = style;
    return text(label, .{
        .style = .{
            .font_size = 17,
            .color = Color.text,
            .background = Color.surface,
            .padding = Spacing.symmetric(16, 14),
            .border_radius = 10,
        },
    });
}

fn buildNotificationButton(label: []const u8, notification_type: app.NotificationType) VNode {
    return text(label, .{
        .style = .{
            .font_size = 15,
            .font_weight = 600,
            .color = Color.text,
            .background = notification_type.color(),
            .padding = Spacing.symmetric(16, 12),
            .border_radius = 8,
            .flex = 1,
        },
    });
}

fn buildHealthScreen(state: *const app.AppState) VNode {
    const S = struct {
        var items: [4]VNode = undefined;
    };

    S.items[0] = buildHealthCard(.steps, state.steps_today);
    S.items[1] = buildHealthCard(.heart_rate, state.heart_rate);
    S.items[2] = buildHealthCard(.calories, state.calories_burned);
    S.items[3] = buildHealthCard(.distance, @intFromFloat(state.distance_km * 10));

    return column(.{
        .style = .{ .padding = Spacing.all(16), .gap = 12, .flex = 1 },
    }, &S.items);
}

fn buildHealthCard(data_type: app.HealthDataType, value: u32) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
        var value_buf: [16]u8 = undefined;
    };

    const value_str = std.fmt.bufPrint(&S.value_buf, "{d}", .{value}) catch "0";

    S.items[0] = row(.{ .style = .{ .gap = 12 } }, &.{
        iconView(data_type.icon(), .{ .style = .{ .color = Color.red, .font_size = 24 } }),
        text(data_type.name(), .{ .style = .{ .font_size = 17, .color = Color.text, .flex = 1 } }),
    });

    S.items[1] = row(.{ .style = .{ .gap = 4 } }, &.{
        text(value_str, .{ .style = .{ .font_size = 34, .font_weight = 700, .color = Color.text } }),
        text(data_type.unit(), .{ .style = .{ .font_size = 17, .color = Color.text_secondary } }),
    });

    return div(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(16),
            .gap = 8,
        },
    }, &S.items);
}

fn buildSiriScreen(state: *const app.AppState) VNode {
    const max_display: usize = 3;
    const shortcut_count: usize = state.shortcut_count;
    const display_count: usize = @min(shortcut_count, max_display);

    const S = struct {
        var items: [4]VNode = undefined;
    };

    S.items[0] = text("Siri Shortcuts", .{
        .style = .{ .font_size = 20, .font_weight = 600, .color = Color.text },
    });

    for (0..display_count) |i| {
        S.items[i + 1] = buildShortcutItem(&state.shortcuts[i]);
    }

    const slice_end = display_count + 1;
    return column(.{
        .style = .{ .padding = Spacing.all(16), .gap = 12, .flex = 1 },
    }, S.items[0..slice_end]);
}

fn buildShortcutItem(shortcut: *const app.SiriShortcut) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
    };

    S.items[0] = iconView(shortcut.icon, .{ .style = .{ .color = Color.orange, .font_size = 24 } });
    S.items[1] = column(.{ .style = .{ .flex = 1, .gap = 2 } }, &.{
        text(shortcut.phrase, .{ .style = .{ .font_size = 17, .color = Color.text } }),
        text(shortcut.action, .{ .style = .{ .font_size = 14, .color = Color.text_secondary } }),
    });
    S.items[2] = iconView(if (shortcut.is_enabled) "checkmark.circle.fill" else "circle", .{
        .style = .{ .color = if (shortcut.is_enabled) Color.green else Color.text_secondary, .font_size = 22 },
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

fn buildTabBar(state: *const app.AppState) VNode {
    const S = struct {
        var items: [5]VNode = undefined;
    };

    S.items[0] = buildTabItem(.home, state.current_screen == .home);
    S.items[1] = buildTabItem(.biometrics, state.current_screen == .biometrics);
    S.items[2] = buildTabItem(.haptics, state.current_screen == .haptics);
    S.items[3] = buildTabItem(.health, state.current_screen == .health);
    S.items[4] = buildTabItem(.siri, state.current_screen == .siri);

    return row(.{
        .style = .{
            .background = Color.surface,
            .padding = Spacing.symmetric(0, 8),
        },
    }, &S.items);
}

fn buildTabItem(screen: app.Screen, selected: bool) VNode {
    const color = if (selected) Color.blue else Color.text_secondary;

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
