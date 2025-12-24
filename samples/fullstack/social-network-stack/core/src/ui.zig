//! Social Network Stack - UI Components

const std = @import("std");
const app = @import("app.zig");

pub const Tag = enum { column, row, div, text, button, input, scroll, icon, avatar };

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
    pub const background: u32 = 0xFF15202B;
    pub const surface: u32 = 0xFF192734;
    pub const primary: u32 = 0xFF1DA1F2;
    pub const text: u32 = 0xFFFFFFFF;
    pub const text_muted: u32 = 0xFF8899A6;
    pub const border: u32 = 0xFF38444D;
    pub const like: u32 = 0xFFE0245E;
    pub const repost: u32 = 0xFF17BF63;
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

pub fn buildApp(state: *const app.AppState) VNode {
    const S = struct {
        var content: [1]VNode = undefined;
    };

    S.content[0] = buildContent(state);

    return column(.{
        .style = .{ .background = Color.background, .flex = 1 },
    }, &S.content);
}

fn buildContent(state: *const app.AppState) VNode {
    if (!state.is_logged_in) {
        return buildLoginScreen();
    }

    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = buildMainContent(state);
    S.items[1] = buildBottomNav(state);

    return column(.{ .style = .{ .flex = 1 } }, &S.items);
}

fn buildLoginScreen() VNode {
    const S = struct {
        var items: [5]VNode = undefined;
    };

    S.items[0] = text("Social Network", .{
        .style = .{ .font_size = 32, .font_weight = 700, .color = Color.primary },
    });

    S.items[1] = div(.{ .style = .{ .height = 40 } }, &.{});

    S.items[2] = div(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 8,
            .padding = Spacing.all(16),
            .width = 300,
        },
    }, &.{
        text("Email", .{ .style = .{ .font_size = 12, .color = Color.text_muted } }),
    });

    S.items[3] = div(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 8,
            .padding = Spacing.all(16),
            .width = 300,
        },
    }, &.{
        text("Password", .{ .style = .{ .font_size = 12, .color = Color.text_muted } }),
    });

    S.items[4] = button("Sign In", .{
        .style = .{
            .background = Color.primary,
            .color = Color.text,
            .padding = Spacing.symmetric(40, 14),
            .border_radius = 25,
            .font_size = 16,
            .font_weight = 600,
        },
    });

    return column(.{
        .style = .{ .flex = 1, .gap = 16, .padding = Spacing.all(40) },
    }, &S.items);
}

fn buildMainContent(state: *const app.AppState) VNode {
    return switch (state.current_screen) {
        .feed => buildFeedScreen(state),
        .profile => buildProfileScreen(state),
        .notifications => buildNotificationsScreen(state),
        .search => buildSearchScreen(),
        .settings => buildSettingsScreen(),
        .login => buildLoginScreen(),
    };
}

fn buildFeedScreen(state: *const app.AppState) VNode {
    const S = struct {
        var items: [6]VNode = undefined;
    };

    // Header
    S.items[0] = row(.{
        .style = .{
            .padding = Spacing.symmetric(16, 12),
            .gap = 16,
        },
    }, &.{
        text("Home", .{ .style = .{ .font_size = 20, .font_weight = 700, .color = Color.text } }),
    });

    // Compose button
    S.items[1] = button("What's happening?", .{
        .style = .{
            .background = Color.surface,
            .color = Color.text_muted,
            .padding = Spacing.all(16),
            .border_radius = 8,
        },
    });

    // Posts
    const post_count = @min(state.post_count, 3);
    for (0..post_count) |i| {
        S.items[2 + i] = buildPostCard(&state.posts[i]);
    }

    const total = 2 + post_count;
    return column(.{
        .style = .{ .flex = 1, .gap = 1 },
    }, S.items[0..total]);
}

fn buildPostCard(post: *const app.Post) VNode {
    const S = struct {
        var items: [4]VNode = undefined;
        var likes_buf: [16]u8 = undefined;
        var comments_buf: [16]u8 = undefined;
        var reposts_buf: [16]u8 = undefined;
    };

    const likes_str = std.fmt.bufPrint(&S.likes_buf, "{d}", .{post.likes}) catch "0";
    const comments_str = std.fmt.bufPrint(&S.comments_buf, "{d}", .{post.comments}) catch "0";
    const reposts_str = std.fmt.bufPrint(&S.reposts_buf, "{d}", .{post.reposts}) catch "0";

    // Author info
    S.items[0] = row(.{ .style = .{ .gap = 8 } }, &.{
        div(.{
            .style = .{ .width = 40, .height = 40, .border_radius = 20, .background = Color.primary },
        }, &.{}),
        column(.{ .style = .{ .gap = 2 } }, &.{
            text(post.author_name, .{ .style = .{ .font_weight = 600, .color = Color.text } }),
            text("@user", .{ .style = .{ .font_size = 12, .color = Color.text_muted } }),
        }),
    });

    // Content
    S.items[1] = text(post.content, .{
        .style = .{ .font_size = 15, .color = Color.text },
    });

    // Actions
    S.items[2] = row(.{ .style = .{ .gap = 40 } }, &.{
        row(.{ .style = .{ .gap = 4 } }, &.{
            iconView("bubble.left", .{ .style = .{ .color = Color.text_muted, .font_size = 16 } }),
            text(comments_str, .{ .style = .{ .font_size = 12, .color = Color.text_muted } }),
        }),
        row(.{ .style = .{ .gap = 4 } }, &.{
            iconView("arrow.2.squarepath", .{
                .style = .{ .color = if (post.is_reposted) Color.repost else Color.text_muted, .font_size = 16 },
            }),
            text(reposts_str, .{ .style = .{ .font_size = 12, .color = Color.text_muted } }),
        }),
        row(.{ .style = .{ .gap = 4 } }, &.{
            iconView(if (post.is_liked) "heart.fill" else "heart", .{
                .style = .{ .color = if (post.is_liked) Color.like else Color.text_muted, .font_size = 16 },
            }),
            text(likes_str, .{ .style = .{ .font_size = 12, .color = Color.text_muted } }),
        }),
    });

    S.items[3] = div(.{}, &.{});

    return div(.{
        .style = .{
            .background = Color.surface,
            .padding = Spacing.all(16),
            .gap = 12,
        },
    }, &S.items);
}

fn buildProfileScreen(state: *const app.AppState) VNode {
    const S = struct {
        var items: [4]VNode = undefined;
        var followers_buf: [32]u8 = undefined;
        var following_buf: [32]u8 = undefined;
    };

    const user = &state.current_user;
    const followers_str = std.fmt.bufPrint(&S.followers_buf, "{d} Followers", .{user.followers}) catch "0";
    const following_str = std.fmt.bufPrint(&S.following_buf, "{d} Following", .{user.following}) catch "0";

    // Avatar
    S.items[0] = div(.{
        .style = .{ .width = 80, .height = 80, .border_radius = 40, .background = Color.primary },
    }, &.{});

    // Name
    S.items[1] = column(.{ .style = .{ .gap = 4 } }, &.{
        text(user.name, .{ .style = .{ .font_size = 20, .font_weight = 700, .color = Color.text } }),
        text(user.username, .{ .style = .{ .font_size = 14, .color = Color.text_muted } }),
    });

    // Bio
    S.items[2] = text(user.bio, .{
        .style = .{ .font_size = 14, .color = Color.text },
    });

    // Stats
    S.items[3] = row(.{ .style = .{ .gap = 20 } }, &.{
        text(followers_str, .{ .style = .{ .font_size = 14, .color = Color.text_muted } }),
        text(following_str, .{ .style = .{ .font_size = 14, .color = Color.text_muted } }),
    });

    return column(.{
        .style = .{ .flex = 1, .gap = 16, .padding = Spacing.all(20) },
    }, &S.items);
}

fn buildNotificationsScreen(state: *const app.AppState) VNode {
    const S = struct {
        var items: [5]VNode = undefined;
    };

    // Header
    S.items[0] = text("Notifications", .{
        .style = .{ .font_size = 20, .font_weight = 700, .color = Color.text, .padding = Spacing.all(16) },
    });

    // Notifications
    const notif_count = @min(state.notification_count, 4);
    for (0..notif_count) |i| {
        S.items[1 + i] = buildNotificationRow(&state.notifications[i]);
    }

    const total = 1 + notif_count;
    return column(.{
        .style = .{ .flex = 1, .gap = 1 },
    }, S.items[0..total]);
}

fn buildNotificationRow(notif: *const app.Notification) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = iconView(notif.notification_type.icon(), .{
        .style = .{ .color = notif.notification_type.color(), .font_size = 20 },
    });

    S.items[1] = column(.{ .style = .{ .gap = 2 } }, &.{
        text(notif.actor_name, .{ .style = .{ .font_weight = 600, .color = Color.text } }),
        text(notif.content, .{ .style = .{ .font_size = 13, .color = Color.text_muted } }),
    });

    return row(.{
        .style = .{
            .background = if (notif.is_read) Color.surface else 0xFF1C2938,
            .padding = Spacing.all(16),
            .gap = 12,
        },
    }, &S.items);
}

fn buildSearchScreen() VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = div(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 20,
            .padding = Spacing.symmetric(16, 12),
        },
    }, &.{
        text("Search", .{ .style = .{ .color = Color.text_muted } }),
    });

    S.items[1] = text("Search for users, posts, or topics", .{
        .style = .{ .font_size = 14, .color = Color.text_muted },
    });

    return column(.{
        .style = .{ .flex = 1, .gap = 20, .padding = Spacing.all(16) },
    }, &S.items);
}

fn buildSettingsScreen() VNode {
    const S = struct {
        var items: [4]VNode = undefined;
    };

    S.items[0] = text("Settings", .{
        .style = .{ .font_size = 20, .font_weight = 700, .color = Color.text },
    });

    S.items[1] = buildSettingRow("Account");
    S.items[2] = buildSettingRow("Privacy");
    S.items[3] = button("Logout", .{
        .style = .{
            .background = Color.like,
            .color = Color.text,
            .padding = Spacing.symmetric(20, 12),
            .border_radius = 8,
        },
    });

    return column(.{
        .style = .{ .flex = 1, .gap = 16, .padding = Spacing.all(20) },
    }, &S.items);
}

fn buildSettingRow(label: []const u8) VNode {
    return row(.{
        .style = .{
            .background = Color.surface,
            .padding = Spacing.all(16),
            .border_radius = 8,
        },
    }, &.{
        text(label, .{ .style = .{ .color = Color.text } }),
    });
}

fn buildBottomNav(state: *const app.AppState) VNode {
    const S = struct {
        var items: [5]VNode = undefined;
    };

    const tabs = [_]app.Screen{ .feed, .search, .notifications, .profile, .settings };

    for (tabs, 0..) |tab, i| {
        const is_active = state.current_screen == tab;
        S.items[i] = column(.{
            .style = .{ .flex = 1, .padding = Spacing.symmetric(0, 12) },
        }, &.{
            iconView(tab.icon(), .{
                .style = .{ .color = if (is_active) Color.primary else Color.text_muted, .font_size = 24 },
            }),
        });
    }

    return row(.{
        .style = .{
            .background = Color.surface,
            .padding = Spacing.symmetric(0, 8),
        },
    }, &S.items);
}

// C ABI Export
pub fn render() [*]const VNode {
    const S = struct {
        var root: [1]VNode = undefined;
    };
    S.root[0] = buildApp(app.getState());
    return &S.root;
}

// Tests
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
