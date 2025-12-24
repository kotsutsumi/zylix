//! Social Network - UI Components

const std = @import("std");
const app = @import("app.zig");

pub const Tag = enum { column, row, div, text, button, scroll, icon, avatar };

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
    pub const accent: u32 = 0xFF1DA1F2;
    pub const red: u32 = 0xFFFF3B30;
    pub const green: u32 = 0xFF34C759;
    pub const divider: u32 = 0xFF38383A;
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

    if (state.current_screen == .feed) {
        S.items[2] = iconView("plus.circle", .{ .style = .{ .color = Color.accent, .font_size = 24 } });
    } else {
        S.items[2] = iconView("magnifyingglass", .{ .style = .{ .color = Color.text, .font_size = 20 } });
    }

    return row(.{
        .style = .{ .padding = Spacing.symmetric(16, 12), .background = Color.background },
    }, &S.items);
}

fn buildContent(state: *const app.AppState) VNode {
    return switch (state.current_screen) {
        .feed => buildFeedScreen(state),
        .discover => buildDiscoverScreen(state),
        .notifications => buildNotificationsScreen(state),
        .profile => buildProfileScreen(state),
    };
}

fn buildFeedScreen(state: *const app.AppState) VNode {
    const max_display: usize = 5;
    const post_count: usize = state.post_count;
    const display_count: usize = @min(post_count, max_display);

    const S = struct {
        var items: [5]VNode = undefined;
    };

    for (0..display_count) |i| {
        const idx = post_count - 1 - i;
        S.items[i] = buildPostCard(&state.posts[idx], state);
    }

    const slice_end = display_count;
    return column(.{
        .style = .{ .gap = 1, .flex = 1, .background = Color.divider },
    }, S.items[0..slice_end]);
}

fn buildPostCard(post: *const app.Post, state: *const app.AppState) VNode {
    _ = state;
    const S = struct {
        var items: [3]VNode = undefined;
        var likes_buf: [16]u8 = undefined;
        var comments_buf: [16]u8 = undefined;
        var reposts_buf: [16]u8 = undefined;
    };

    const likes_str = std.fmt.bufPrint(&S.likes_buf, "{d}", .{post.likes}) catch "0";
    const comments_str = std.fmt.bufPrint(&S.comments_buf, "{d}", .{post.comments}) catch "0";
    const reposts_str = std.fmt.bufPrint(&S.reposts_buf, "{d}", .{post.reposts}) catch "0";

    // Header with avatar and username
    S.items[0] = row(.{ .style = .{ .gap = 12 } }, &.{
        div(.{ .style = .{ .background = Color.accent, .width = 48, .height = 48, .border_radius = 24 } }, &.{}),
        column(.{ .style = .{ .gap = 2, .flex = 1 } }, &.{
            text("User", .{ .style = .{ .font_size = 16, .font_weight = 600, .color = Color.text } }),
            text("@user", .{ .style = .{ .font_size = 14, .color = Color.text_secondary } }),
        }),
        iconView("ellipsis", .{ .style = .{ .color = Color.text_secondary, .font_size = 16 } }),
    });

    // Content
    S.items[1] = text(post.content, .{
        .style = .{ .font_size = 16, .color = Color.text },
    });

    // Action buttons
    S.items[2] = row(.{ .style = .{ .gap = 32, .padding = .{ .top = 8 } } }, &.{
        buildPostAction("bubble.left", comments_str, Color.text_secondary),
        buildPostAction("arrow.2.squarepath", reposts_str, if (post.is_reposted) Color.green else Color.text_secondary),
        buildPostAction("heart", likes_str, if (post.is_liked) Color.red else Color.text_secondary),
        iconView("square.and.arrow.up", .{ .style = .{ .color = Color.text_secondary, .font_size = 16 } }),
    });

    return div(.{
        .style = .{
            .background = Color.background,
            .padding = Spacing.all(16),
            .gap = 12,
        },
    }, &S.items);
}

fn buildPostAction(icon_name: []const u8, count: []const u8, color: u32) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = iconView(icon_name, .{ .style = .{ .color = color, .font_size = 16 } });
    S.items[1] = text(count, .{ .style = .{ .font_size = 14, .color = color } });

    return row(.{ .style = .{ .gap = 6 } }, &S.items);
}

fn buildDiscoverScreen(state: *const app.AppState) VNode {
    const max_display: usize = 3;
    const user_count: usize = state.user_count;
    const display_count: usize = @min(user_count, max_display);

    const S = struct {
        var items: [4]VNode = undefined;
    };

    S.items[0] = text("Suggested for you", .{
        .style = .{ .font_size = 18, .font_weight = 600, .color = Color.text },
    });

    for (0..display_count) |i| {
        S.items[i + 1] = buildUserCard(&state.users[i]);
    }

    const slice_end = display_count + 1;
    return column(.{
        .style = .{ .padding = Spacing.all(16), .gap = 16, .flex = 1 },
    }, S.items[0..slice_end]);
}

fn buildUserCard(user: *const app.User) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
        var followers_buf: [24]u8 = undefined;
    };

    const followers_str = std.fmt.bufPrint(&S.followers_buf, "{d} followers", .{user.followers}) catch "0 followers";

    S.items[0] = div(.{ .style = .{ .background = Color.accent, .width = 56, .height = 56, .border_radius = 28 } }, &.{});
    S.items[1] = column(.{ .style = .{ .flex = 1, .gap = 2 } }, &.{
        text(user.display_name, .{ .style = .{ .font_size = 16, .font_weight = 600, .color = Color.text } }),
        text(user.bio, .{ .style = .{ .font_size = 14, .color = Color.text_secondary } }),
        text(followers_str, .{ .style = .{ .font_size = 14, .color = Color.text_secondary } }),
    });
    S.items[2] = buildFollowButton(user.is_following);

    return row(.{
        .style = .{
            .background = Color.surface,
            .border_radius = 12,
            .padding = Spacing.all(16),
            .gap = 12,
        },
    }, &S.items);
}

fn buildFollowButton(is_following: bool) VNode {
    return text(if (is_following) "Following" else "Follow", .{
        .style = .{
            .font_size = 14,
            .font_weight = 600,
            .color = if (is_following) Color.text else Color.background,
            .background = if (is_following) Color.card else Color.text,
            .padding = Spacing.symmetric(16, 8),
            .border_radius = 20,
        },
    });
}

fn buildNotificationsScreen(state: *const app.AppState) VNode {
    const max_display: usize = 5;
    const notif_count: usize = state.notification_count;
    const display_count: usize = @min(notif_count, max_display);

    const S = struct {
        var items: [5]VNode = undefined;
    };

    if (display_count == 0) {
        S.items[0] = text("No notifications yet", .{
            .style = .{ .font_size = 16, .color = Color.text_secondary },
        });
        return column(.{
            .style = .{ .padding = Spacing.all(16), .flex = 1 },
        }, S.items[0..1]);
    }

    for (0..display_count) |i| {
        const idx = notif_count - 1 - i;
        S.items[i] = buildNotificationItem(&state.notifications[idx]);
    }

    return column(.{
        .style = .{ .gap = 1, .flex = 1, .background = Color.divider },
    }, S.items[0..display_count]);
}

fn buildNotificationItem(notification: *const app.Notification) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
    };

    const message = switch (notification.notification_type) {
        .like => "liked your post",
        .comment => "commented on your post",
        .follow => "started following you",
        .mention => "mentioned you",
        .repost => "reposted your post",
    };

    S.items[0] = div(.{
        .style = .{
            .background = notification.notification_type.color(),
            .width = 32,
            .height = 32,
            .border_radius = 16,
        },
    }, &.{
        iconView(notification.notification_type.icon(), .{
            .style = .{ .color = Color.text, .font_size = 16 },
        }),
    });
    S.items[1] = column(.{ .style = .{ .flex = 1, .gap = 2 } }, &.{
        text("User", .{ .style = .{ .font_size = 16, .font_weight = 600, .color = Color.text } }),
        text(message, .{ .style = .{ .font_size = 14, .color = Color.text_secondary } }),
    });
    S.items[2] = text("1h", .{ .style = .{ .font_size = 14, .color = Color.text_secondary } });

    return row(.{
        .style = .{
            .background = if (notification.is_read) Color.background else Color.surface,
            .padding = Spacing.all(16),
            .gap = 12,
        },
    }, &S.items);
}

fn buildProfileScreen(state: *const app.AppState) VNode {
    const S = struct {
        var items: [4]VNode = undefined;
        var followers_buf: [16]u8 = undefined;
        var following_buf: [16]u8 = undefined;
        var posts_buf: [16]u8 = undefined;
    };

    const followers_str = std.fmt.bufPrint(&S.followers_buf, "{d}", .{state.current_user.followers}) catch "0";
    const following_str = std.fmt.bufPrint(&S.following_buf, "{d}", .{state.current_user.following}) catch "0";
    const posts_str = std.fmt.bufPrint(&S.posts_buf, "{d}", .{state.current_user.posts_count}) catch "0";

    // Profile header
    S.items[0] = column(.{ .style = .{ .gap = 12 } }, &.{
        div(.{ .style = .{ .background = Color.accent, .width = 80, .height = 80, .border_radius = 40 } }, &.{}),
        text(state.current_user.display_name, .{
            .style = .{ .font_size = 24, .font_weight = 700, .color = Color.text },
        }),
        text(state.current_user.bio, .{
            .style = .{ .font_size = 16, .color = Color.text_secondary },
        }),
    });

    // Stats
    S.items[1] = row(.{ .style = .{ .gap = 24, .padding = .{ .top = 16, .bottom = 16 } } }, &.{
        buildProfileStat(posts_str, "Posts"),
        buildProfileStat(followers_str, "Followers"),
        buildProfileStat(following_str, "Following"),
    });

    // Edit profile button
    S.items[2] = text("Edit Profile", .{
        .style = .{
            .font_size = 16,
            .font_weight = 600,
            .color = Color.text,
            .background = Color.surface,
            .padding = Spacing.symmetric(0, 12),
            .border_radius = 8,
            .width = 200,
        },
    });

    // Menu items
    S.items[3] = column(.{ .style = .{ .gap = 12, .padding = .{ .top = 24 } } }, &.{
        buildProfileMenuItem("bookmark", "Bookmarks"),
        buildProfileMenuItem("heart", "Likes"),
        buildProfileMenuItem("gearshape", "Settings"),
    });

    return column(.{
        .style = .{ .padding = Spacing.all(16), .gap = 8, .flex = 1 },
    }, &S.items);
}

fn buildProfileStat(value: []const u8, label: []const u8) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = text(value, .{ .style = .{ .font_size = 20, .font_weight = 700, .color = Color.text } });
    S.items[1] = text(label, .{ .style = .{ .font_size = 14, .color = Color.text_secondary } });

    return column(.{ .style = .{ .gap = 4 } }, &S.items);
}

fn buildProfileMenuItem(icon_name: []const u8, label: []const u8) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
    };

    S.items[0] = iconView(icon_name, .{ .style = .{ .color = Color.text, .font_size = 20 } });
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

    S.items[0] = buildTabItem("house", state.current_screen == .feed);
    S.items[1] = buildTabItem("magnifyingglass", state.current_screen == .discover);
    S.items[2] = buildTabItemWithBadge("bell", state.current_screen == .notifications, state.unread_count);
    S.items[3] = buildTabItem("person", state.current_screen == .profile);

    return row(.{
        .style = .{
            .background = Color.surface,
            .padding = Spacing.symmetric(0, 12),
        },
    }, &S.items);
}

fn buildTabItem(icon_name: []const u8, selected: bool) VNode {
    const color = if (selected) Color.accent else Color.text_secondary;

    return div(.{
        .style = .{ .flex = 1, .padding = Spacing.symmetric(0, 8) },
    }, &.{
        iconView(icon_name, .{ .style = .{ .color = color, .font_size = 24 } }),
    });
}

fn buildTabItemWithBadge(icon_name: []const u8, selected: bool, badge_count: u32) VNode {
    _ = badge_count;
    const color = if (selected) Color.accent else Color.text_secondary;

    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = iconView(icon_name, .{ .style = .{ .color = color, .font_size = 24 } });
    S.items[1] = div(.{
        .style = .{ .background = Color.red, .width = 8, .height = 8, .border_radius = 4 },
    }, &.{});

    return row(.{
        .style = .{ .flex = 1, .padding = Spacing.symmetric(0, 8) },
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
    try std.testing.expectEqual(Tag.column, view.tag);
}

test "render" {
    app.init();
    defer app.deinit();
    const root = render();
    try std.testing.expectEqual(Tag.column, root[0].tag);
}
