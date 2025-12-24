//! Chat Space - UI Components

const std = @import("std");
const app = @import("app.zig");

pub const Tag = enum { column, row, div, text, button, scroll, icon, input, avatar };

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
    pub const background: u32 = 0xFF1C1C1E;
    pub const surface: u32 = 0xFF2C2C2E;
    pub const card: u32 = 0xFF3A3A3C;
    pub const text: u32 = 0xFFFFFFFF;
    pub const text_secondary: u32 = 0xFF8E8E93;
    pub const primary: u32 = 0xFF007AFF;
    pub const accent: u32 = 0xFF5856D6;
    pub const online: u32 = 0xFF34C759;
    pub const mention: u32 = 0xFFFF9500;
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
fn avatarView(name: []const u8, status_color: u32) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };
    S.items[0] = iconView(name, .{ .style = .{ .color = Color.text, .font_size = 32 } });
    S.items[1] = div(.{ .style = .{
        .background = status_color,
        .width = 10,
        .height = 10,
        .border_radius = 5,
    } }, &.{});
    return row(.{ .style = .{ .gap = -8 } }, &S.items);
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

    const title = if (state.current_screen == .chat) blk: {
        if (state.selected_channel) |ch_id| {
            if (app.getChannel(ch_id)) |ch| {
                break :blk ch.name[0..ch.name_len];
            }
        }
        break :blk state.current_screen.title();
    } else state.current_screen.title();

    S.items[0] = text(title, .{
        .style = .{ .font_size = 20, .font_weight = 700, .color = Color.text },
    });
    S.items[1] = spacer();
    S.items[2] = iconView("plus.circle", .{ .style = .{ .color = Color.primary, .font_size = 24 } });

    return row(.{
        .style = .{
            .background = Color.surface,
            .padding = Spacing.symmetric(16, 12),
        },
    }, &S.items);
}

fn buildContent(state: *const app.AppState) VNode {
    return switch (state.current_screen) {
        .channels => buildChannelsScreen(state),
        .chat => buildChatScreen(state),
        .direct_messages => buildDMScreen(state),
        .settings => buildSettingsScreen(state),
    };
}

fn buildChannelsScreen(state: *const app.AppState) VNode {
    const max_display = 6;
    const display_count = @min(state.channel_count, max_display);

    const S = struct {
        var items: [max_display + 1]VNode = undefined;
    };

    S.items[0] = text("Channels", .{
        .style = .{ .font_size = 12, .font_weight = 600, .color = Color.text_secondary, .padding = Spacing.all(16) },
    });

    for (0..display_count) |i| {
        S.items[i + 1] = buildChannelItem(&state.channels[i]);
    }

    return column(.{ .style = .{ .flex = 1 } }, S.items[0 .. display_count + 1]);
}

fn buildChannelItem(channel: *const app.Channel) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
        var unread_buf: [8]u8 = undefined;
    };

    const prefix: []const u8 = if (channel.is_private) "lock" else "number";
    S.items[0] = iconView(prefix, .{ .style = .{ .color = Color.text_secondary, .font_size = 16 } });
    S.items[1] = text(channel.name[0..channel.name_len], .{
        .style = .{ .font_size = 16, .color = Color.text, .flex = 1 },
    });

    if (channel.unread_count > 0) {
        const unread_str = std.fmt.bufPrint(&S.unread_buf, "{d}", .{channel.unread_count}) catch "0";
        S.items[2] = text(unread_str, .{
            .style = .{
                .font_size = 12,
                .color = Color.text,
                .background = Color.primary,
                .padding = Spacing.symmetric(6, 2),
                .border_radius = 10,
            },
        });
    } else {
        S.items[2] = div(.{}, &.{});
    }

    return row(.{
        .style = .{
            .padding = Spacing.symmetric(16, 12),
            .gap = 12,
        },
    }, &S.items);
}

fn buildChatScreen(state: *const app.AppState) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = buildMessageList(state);
    S.items[1] = buildInputBar(state);

    return column(.{ .style = .{ .flex = 1 } }, &S.items);
}

fn buildMessageList(state: *const app.AppState) VNode {
    const max_display = 8;
    const display_count = @min(state.message_count, max_display);

    const S = struct {
        var items: [max_display]VNode = undefined;
    };

    for (0..display_count) |i| {
        S.items[i] = buildMessageItem(&state.messages[i]);
    }

    return column(.{
        .style = .{ .padding = Spacing.all(16), .gap = 12, .flex = 1 },
    }, S.items[0..display_count]);
}

fn buildMessageItem(message: *const app.Message) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
        var name_items: [2]VNode = undefined;
    };

    const sender = app.getUser(message.sender_id);
    const sender_name = if (sender) |s| s.name[0..s.name_len] else "Unknown";
    const sender_avatar = if (sender) |s| s.avatar[0..s.avatar_len] else "person.circle";

    S.items[0] = iconView(sender_avatar, .{ .style = .{ .color = Color.text_secondary, .font_size = 32 } });

    S.name_items[0] = text(sender_name, .{
        .style = .{ .font_size = 14, .font_weight = 600, .color = Color.text },
    });
    S.name_items[1] = text(message.text[0..message.text_len], .{
        .style = .{ .font_size = 14, .color = Color.text },
    });

    S.items[1] = column(.{ .style = .{ .gap = 4, .flex = 1 } }, &S.name_items);

    return row(.{
        .style = .{
            .gap = 12,
            .padding = Spacing.symmetric(0, 4),
        },
    }, &S.items);
}

fn buildInputBar(state: *const app.AppState) VNode {
    _ = state;
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = div(.{
        .style = .{
            .background = Color.card,
            .border_radius = 20,
            .padding = Spacing.symmetric(16, 10),
            .flex = 1,
        },
    }, &.{
        text("Message...", .{ .style = .{ .color = Color.text_secondary } }),
    });
    S.items[1] = button("Send", .{
        .style = .{
            .background = Color.primary,
            .padding = Spacing.symmetric(16, 10),
            .border_radius = 20,
            .color = Color.text,
        },
    });

    return row(.{
        .style = .{
            .background = Color.surface,
            .padding = Spacing.all(12),
            .gap = 8,
        },
    }, &S.items);
}

fn buildDMScreen(state: *const app.AppState) VNode {
    const max_display = 6;
    // Skip first user (self)
    const start: usize = 1;
    const available = if (state.user_count > start) state.user_count - start else 0;
    const display_count = @min(available, max_display);

    const S = struct {
        var items: [max_display + 1]VNode = undefined;
    };

    S.items[0] = text("Direct Messages", .{
        .style = .{ .font_size = 12, .font_weight = 600, .color = Color.text_secondary, .padding = Spacing.all(16) },
    });

    for (0..display_count) |i| {
        S.items[i + 1] = buildDMItem(&state.users[start + i]);
    }

    return column(.{ .style = .{ .flex = 1 } }, S.items[0 .. display_count + 1]);
}

fn buildDMItem(user: *const app.User) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
    };

    S.items[0] = avatarView(user.avatar[0..user.avatar_len], user.status.color());
    S.items[1] = column(.{ .style = .{ .flex = 1, .gap = 2 } }, &.{
        text(user.name[0..user.name_len], .{
            .style = .{ .font_size = 16, .color = Color.text },
        }),
        text(user.status.name(), .{
            .style = .{ .font_size = 12, .color = Color.text_secondary },
        }),
    });
    S.items[2] = div(.{}, &.{});

    return row(.{
        .style = .{
            .padding = Spacing.symmetric(16, 12),
            .gap = 12,
        },
    }, &S.items);
}

fn buildSettingsScreen(state: *const app.AppState) VNode {
    const S = struct {
        var items: [4]VNode = undefined;
    };

    const current_user = app.getUser(state.current_user_id);
    const user_name = if (current_user) |u| u.name[0..u.name_len] else "User";

    S.items[0] = div(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(16),
        },
    }, &.{
        row(.{ .style = .{ .gap = 12 } }, &.{
            iconView("person.circle.fill", .{ .style = .{ .color = Color.primary, .font_size = 48 } }),
            column(.{ .style = .{ .gap = 4 } }, &.{
                text(user_name, .{ .style = .{ .font_size = 18, .font_weight = 600, .color = Color.text } }),
                text(state.current_status.name(), .{ .style = .{ .font_size = 14, .color = state.current_status.color() } }),
            }),
        }),
    });
    S.items[1] = buildSettingItem("bell", "Notifications");
    S.items[2] = buildSettingItem("moon", "Appearance");
    S.items[3] = buildSettingItem("shield", "Privacy");

    return column(.{
        .style = .{ .padding = Spacing.all(16), .gap = 12, .flex = 1 },
    }, &S.items);
}

fn buildSettingItem(icon_name: []const u8, label: []const u8) VNode {
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

    S.items[0] = buildTabItem("number", "Channels", state.current_screen == .channels);
    S.items[1] = buildTabItem("bubble.left.and.bubble.right", "DMs", state.current_screen == .direct_messages);
    S.items[2] = buildTabItem("bell", "Activity", false);
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
