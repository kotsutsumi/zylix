//! Social Network - Application State

const std = @import("std");

pub const Screen = enum(u8) {
    feed = 0,
    discover = 1,
    notifications = 2,
    profile = 3,

    pub fn title(self: Screen) []const u8 {
        return switch (self) {
            .feed => "Home",
            .discover => "Discover",
            .notifications => "Notifications",
            .profile => "Profile",
        };
    }
};

pub const User = struct {
    id: u32 = 0,
    username: []const u8 = "",
    display_name: []const u8 = "",
    avatar: []const u8 = "",
    bio: []const u8 = "",
    followers: u32 = 0,
    following: u32 = 0,
    posts_count: u32 = 0,
    is_following: bool = false,
};

pub const Post = struct {
    id: u32 = 0,
    author_id: u32 = 0,
    content: []const u8 = "",
    image: []const u8 = "",
    likes: u32 = 0,
    comments: u32 = 0,
    reposts: u32 = 0,
    created_at: i64 = 0,
    is_liked: bool = false,
    is_reposted: bool = false,
};

pub const NotificationType = enum(u8) {
    like = 0,
    comment = 1,
    follow = 2,
    mention = 3,
    repost = 4,

    pub fn icon(self: NotificationType) []const u8 {
        return switch (self) {
            .like => "heart.fill",
            .comment => "bubble.left.fill",
            .follow => "person.badge.plus",
            .mention => "at",
            .repost => "arrow.2.squarepath",
        };
    }

    pub fn color(self: NotificationType) u32 {
        return switch (self) {
            .like => 0xFFFF3B30,
            .comment => 0xFF007AFF,
            .follow => 0xFF5856D6,
            .mention => 0xFFFF9500,
            .repost => 0xFF34C759,
        };
    }
};

pub const Notification = struct {
    id: u32 = 0,
    notification_type: NotificationType = .like,
    user_id: u32 = 0,
    post_id: u32 = 0,
    created_at: i64 = 0,
    is_read: bool = false,
};

pub const max_posts = 50;
pub const max_users = 20;
pub const max_notifications = 30;

pub const AppState = struct {
    initialized: bool = false,
    current_screen: Screen = .feed,

    // Current user
    current_user: User = .{},

    // Feed posts
    posts: [max_posts]Post = undefined,
    post_count: usize = 0,
    next_post_id: u32 = 1,

    // Users
    users: [max_users]User = undefined,
    user_count: usize = 0,

    // Notifications
    notifications: [max_notifications]Notification = undefined,
    notification_count: usize = 0,
    unread_count: u32 = 0,
};

var app_state: AppState = .{};

pub fn init() void {
    app_state = .{ .initialized = true };
    addSampleData();
}

pub fn deinit() void {
    app_state.initialized = false;
}

pub fn getState() *const AppState {
    return &app_state;
}

fn addSampleData() void {
    // Current user
    app_state.current_user = .{
        .id = 1,
        .username = "user",
        .display_name = "Current User",
        .avatar = "person.circle.fill",
        .bio = "Building awesome apps",
        .followers = 1234,
        .following = 567,
        .posts_count = 42,
    };

    // Sample users
    addUser(2, "alice", "Alice", "A", "Designer", 5678, 234);
    addUser(3, "bob", "Bob Smith", "B", "Developer", 8901, 456);
    addUser(4, "charlie", "Charlie", "C", "Creator", 2345, 789);

    // Sample posts
    _ = createPost(2, "Just shipped a new feature!", "");
    _ = createPost(3, "Working on something exciting", "");
    _ = createPost(4, "Beautiful day for coding", "");
    _ = createPost(2, "Check out my latest project", "");

    // Mark some as liked
    if (app_state.post_count > 0) {
        app_state.posts[0].is_liked = true;
        app_state.posts[0].likes = 42;
    }
    if (app_state.post_count > 1) {
        app_state.posts[1].likes = 128;
        app_state.posts[1].comments = 15;
    }

    // Sample notifications
    addNotification(.like, 2, 1);
    addNotification(.follow, 3, 0);
    addNotification(.comment, 4, 1);

    app_state.unread_count = 3;
}

fn addUser(id: u32, username: []const u8, display_name: []const u8, avatar: []const u8, bio: []const u8, followers: u32, following: u32) void {
    if (app_state.user_count >= max_users) return;
    app_state.users[app_state.user_count] = .{
        .id = id,
        .username = username,
        .display_name = display_name,
        .avatar = avatar,
        .bio = bio,
        .followers = followers,
        .following = following,
    };
    app_state.user_count += 1;
}

fn addNotification(notification_type: NotificationType, user_id: u32, post_id: u32) void {
    if (app_state.notification_count >= max_notifications) return;
    app_state.notifications[app_state.notification_count] = .{
        .id = @intCast(app_state.notification_count + 1),
        .notification_type = notification_type,
        .user_id = user_id,
        .post_id = post_id,
        .created_at = 1700000000,
    };
    app_state.notification_count += 1;
}

// Navigation
pub fn setScreen(screen: Screen) void {
    app_state.current_screen = screen;
}

// Post operations
pub fn createPost(author_id: u32, content: []const u8, image: []const u8) ?u32 {
    if (app_state.post_count >= max_posts) return null;

    app_state.posts[app_state.post_count] = .{
        .id = app_state.next_post_id,
        .author_id = author_id,
        .content = content,
        .image = image,
        .created_at = 1700000000 + @as(i64, @intCast(app_state.post_count)) * 3600,
    };

    app_state.next_post_id += 1;
    app_state.post_count += 1;

    return app_state.posts[app_state.post_count - 1].id;
}

pub fn likePost(post_id: u32) void {
    for (0..app_state.post_count) |i| {
        if (app_state.posts[i].id == post_id and !app_state.posts[i].is_liked) {
            app_state.posts[i].is_liked = true;
            app_state.posts[i].likes += 1;
            break;
        }
    }
}

pub fn unlikePost(post_id: u32) void {
    for (0..app_state.post_count) |i| {
        if (app_state.posts[i].id == post_id and app_state.posts[i].is_liked) {
            app_state.posts[i].is_liked = false;
            if (app_state.posts[i].likes > 0) {
                app_state.posts[i].likes -= 1;
            }
            break;
        }
    }
}

pub fn repostPost(post_id: u32) void {
    for (0..app_state.post_count) |i| {
        if (app_state.posts[i].id == post_id and !app_state.posts[i].is_reposted) {
            app_state.posts[i].is_reposted = true;
            app_state.posts[i].reposts += 1;
            break;
        }
    }
}

// User operations
pub fn followUser(user_id: u32) void {
    for (0..app_state.user_count) |i| {
        if (app_state.users[i].id == user_id and !app_state.users[i].is_following) {
            app_state.users[i].is_following = true;
            app_state.users[i].followers += 1;
            app_state.current_user.following += 1;
            break;
        }
    }
}

pub fn unfollowUser(user_id: u32) void {
    for (0..app_state.user_count) |i| {
        if (app_state.users[i].id == user_id and app_state.users[i].is_following) {
            app_state.users[i].is_following = false;
            if (app_state.users[i].followers > 0) {
                app_state.users[i].followers -= 1;
            }
            if (app_state.current_user.following > 0) {
                app_state.current_user.following -= 1;
            }
            break;
        }
    }
}

// Notification operations
pub fn markNotificationsRead() void {
    for (0..app_state.notification_count) |i| {
        app_state.notifications[i].is_read = true;
    }
    app_state.unread_count = 0;
}

pub fn getUser(user_id: u32) ?*const User {
    for (0..app_state.user_count) |i| {
        if (app_state.users[i].id == user_id) {
            return &app_state.users[i];
        }
    }
    return null;
}

// Tests
test "state init" {
    init();
    defer deinit();
    try std.testing.expect(app_state.initialized);
    try std.testing.expect(app_state.post_count > 0);
    try std.testing.expect(app_state.user_count > 0);
}

test "create post" {
    init();
    defer deinit();
    const initial = app_state.post_count;
    const id = createPost(1, "Test post", "");
    try std.testing.expect(id != null);
    try std.testing.expectEqual(initial + 1, app_state.post_count);
}

test "like post" {
    init();
    defer deinit();
    if (app_state.post_count > 0) {
        const post_id = app_state.posts[0].id;
        const initial_liked = app_state.posts[0].is_liked;

        if (!initial_liked) {
            likePost(post_id);
            try std.testing.expect(app_state.posts[0].is_liked);
        }
    }
}

test "follow user" {
    init();
    defer deinit();
    if (app_state.user_count > 0) {
        const user_id = app_state.users[0].id;
        const initial_following = app_state.current_user.following;

        if (!app_state.users[0].is_following) {
            followUser(user_id);
            try std.testing.expect(app_state.users[0].is_following);
            try std.testing.expectEqual(initial_following + 1, app_state.current_user.following);
        }
    }
}

test "notifications" {
    init();
    defer deinit();
    try std.testing.expect(app_state.notification_count > 0);
    try std.testing.expect(app_state.unread_count > 0);

    markNotificationsRead();
    try std.testing.expectEqual(@as(u32, 0), app_state.unread_count);
}
