//! Social Network Stack - Application State

const std = @import("std");

pub const Screen = enum(u8) {
    login = 0,
    feed = 1,
    profile = 2,
    notifications = 3,
    search = 4,
    settings = 5,

    pub fn title(self: Screen) []const u8 {
        return switch (self) {
            .login => "Login",
            .feed => "Feed",
            .profile => "Profile",
            .notifications => "Notifications",
            .search => "Search",
            .settings => "Settings",
        };
    }

    pub fn icon(self: Screen) []const u8 {
        return switch (self) {
            .login => "person",
            .feed => "home",
            .profile => "person.circle",
            .notifications => "bell",
            .search => "magnifyingglass",
            .settings => "gear",
        };
    }
};

pub const PostType = enum(u8) {
    text = 0,
    image = 1,
    video = 2,
    link = 3,
};

pub const Post = struct {
    id: u32 = 0,
    author_id: u32 = 0,
    author_name: []const u8 = "",
    author_avatar: []const u8 = "",
    content: []const u8 = "",
    post_type: PostType = .text,
    likes: u32 = 0,
    comments: u32 = 0,
    reposts: u32 = 0,
    is_liked: bool = false,
    is_reposted: bool = false,
    created_at: i64 = 0,
};

pub const User = struct {
    id: u32 = 0,
    name: []const u8 = "",
    username: []const u8 = "",
    avatar: []const u8 = "",
    bio: []const u8 = "",
    followers: u32 = 0,
    following: u32 = 0,
    posts_count: u32 = 0,
    is_following: bool = false,
};

pub const Notification = struct {
    id: u32 = 0,
    notification_type: NotificationType = .like,
    actor_name: []const u8 = "",
    content: []const u8 = "",
    is_read: bool = false,
    created_at: i64 = 0,
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
            .like => 0xFFE74C3C,
            .comment => 0xFF3498DB,
            .follow => 0xFF2ECC71,
            .mention => 0xFF9B59B6,
            .repost => 0xFF1ABC9C,
        };
    }
};

const MAX_POSTS: usize = 20;
const MAX_NOTIFICATIONS: usize = 15;
const MAX_USERS: usize = 10;

pub const AppState = struct {
    initialized: bool = false,
    current_screen: Screen = .login,
    is_logged_in: bool = false,
    is_loading: bool = false,

    // Current user
    current_user: User = .{},

    // Feed
    posts: [MAX_POSTS]Post = undefined,
    post_count: usize = 0,
    feed_page: u32 = 1,

    // Notifications
    notifications: [MAX_NOTIFICATIONS]Notification = undefined,
    notification_count: usize = 0,
    unread_count: u32 = 0,

    // Search
    search_query: []const u8 = "",
    search_results: [MAX_USERS]User = undefined,
    search_result_count: usize = 0,

    // Profile viewing
    viewed_user: User = .{},

    // Compose
    compose_text: []const u8 = "",
    is_composing: bool = false,
};

var app_state: AppState = .{};

pub fn init() void {
    app_state = .{ .initialized = true };
}

pub fn deinit() void {
    app_state.initialized = false;
}

pub fn getState() *const AppState {
    return &app_state;
}

// Navigation
pub fn setScreen(screen: Screen) void {
    if (!app_state.is_logged_in and screen != .login) return;
    app_state.current_screen = screen;
}

// Authentication
pub fn login(email: []const u8, password: []const u8) bool {
    _ = email;
    _ = password;

    // Simulate login
    app_state.is_logged_in = true;
    app_state.current_user = .{
        .id = 1,
        .name = "Demo User",
        .username = "@demo",
        .avatar = "avatar1",
        .bio = "Welcome to the social network!",
        .followers = 142,
        .following = 89,
        .posts_count = 37,
    };
    app_state.current_screen = .feed;

    // Load initial data
    loadFeed();
    loadNotifications();

    return true;
}

pub fn logout() void {
    app_state.is_logged_in = false;
    app_state.current_user = .{};
    app_state.current_screen = .login;
    app_state.post_count = 0;
    app_state.notification_count = 0;
}

pub fn isLoggedIn() bool {
    return app_state.is_logged_in;
}

// Feed
fn loadFeed() void {
    // Sample posts
    app_state.posts[0] = .{
        .id = 1,
        .author_id = 2,
        .author_name = "Jane Smith",
        .author_avatar = "avatar2",
        .content = "Just shipped a new feature! 🚀",
        .likes = 42,
        .comments = 8,
        .reposts = 3,
    };
    app_state.posts[1] = .{
        .id = 2,
        .author_id = 3,
        .author_name = "Bob Johnson",
        .author_avatar = "avatar3",
        .content = "Beautiful sunset today",
        .post_type = .image,
        .likes = 156,
        .comments = 23,
    };
    app_state.posts[2] = .{
        .id = 3,
        .author_id = 4,
        .author_name = "Alice Brown",
        .author_avatar = "avatar4",
        .content = "Working on something exciting...",
        .likes = 28,
        .comments = 5,
    };
    app_state.post_count = 3;
}

pub fn refreshFeed() void {
    app_state.is_loading = true;
    loadFeed();
    app_state.is_loading = false;
}

pub fn loadMorePosts() void {
    app_state.feed_page += 1;
    // Would load more posts here
}

// Posts
pub fn createPost(content: []const u8) void {
    if (app_state.post_count >= MAX_POSTS) return;

    // Shift posts down
    var i = app_state.post_count;
    while (i > 0) : (i -= 1) {
        app_state.posts[i] = app_state.posts[i - 1];
    }

    app_state.posts[0] = .{
        .id = @as(u32, @intCast(app_state.post_count)) + 100,
        .author_id = app_state.current_user.id,
        .author_name = app_state.current_user.name,
        .author_avatar = app_state.current_user.avatar,
        .content = content,
    };
    app_state.post_count += 1;
    app_state.current_user.posts_count += 1;
}

pub fn likePost(post_id: u32) void {
    for (app_state.posts[0..app_state.post_count]) |*post| {
        if (post.id == post_id) {
            post.is_liked = !post.is_liked;
            if (post.is_liked) {
                post.likes += 1;
            } else {
                post.likes -|= 1;
            }
            break;
        }
    }
}

pub fn repostPost(post_id: u32) void {
    for (app_state.posts[0..app_state.post_count]) |*post| {
        if (post.id == post_id) {
            post.is_reposted = !post.is_reposted;
            if (post.is_reposted) {
                post.reposts += 1;
            } else {
                post.reposts -|= 1;
            }
            break;
        }
    }
}

// Notifications
fn loadNotifications() void {
    app_state.notifications[0] = .{
        .id = 1,
        .notification_type = .like,
        .actor_name = "Jane Smith",
        .content = "liked your post",
    };
    app_state.notifications[1] = .{
        .id = 2,
        .notification_type = .follow,
        .actor_name = "Bob Johnson",
        .content = "started following you",
    };
    app_state.notifications[2] = .{
        .id = 3,
        .notification_type = .comment,
        .actor_name = "Alice Brown",
        .content = "commented on your post",
    };
    app_state.notification_count = 3;
    app_state.unread_count = 3;
}

pub fn markNotificationRead(id: u32) void {
    for (app_state.notifications[0..app_state.notification_count]) |*notif| {
        if (notif.id == id and !notif.is_read) {
            notif.is_read = true;
            app_state.unread_count -|= 1;
            break;
        }
    }
}

pub fn markAllNotificationsRead() void {
    for (app_state.notifications[0..app_state.notification_count]) |*notif| {
        notif.is_read = true;
    }
    app_state.unread_count = 0;
}

// Social
pub fn followUser(user_id: u32) void {
    if (app_state.viewed_user.id == user_id) {
        app_state.viewed_user.is_following = true;
        app_state.viewed_user.followers += 1;
        app_state.current_user.following += 1;
    }
}

pub fn unfollowUser(user_id: u32) void {
    if (app_state.viewed_user.id == user_id) {
        app_state.viewed_user.is_following = false;
        app_state.viewed_user.followers -|= 1;
        app_state.current_user.following -|= 1;
    }
}

// Compose
pub fn startCompose() void {
    app_state.is_composing = true;
}

pub fn cancelCompose() void {
    app_state.is_composing = false;
    app_state.compose_text = "";
}

// Tests
test "app init" {
    init();
    defer deinit();
    try std.testing.expect(app_state.initialized);
}

test "login logout" {
    init();
    defer deinit();

    try std.testing.expect(!isLoggedIn());
    _ = login("test@example.com", "password");
    try std.testing.expect(isLoggedIn());
    logout();
    try std.testing.expect(!isLoggedIn());
}

test "navigation" {
    init();
    defer deinit();
    _ = login("test@example.com", "password");

    setScreen(.profile);
    try std.testing.expectEqual(Screen.profile, app_state.current_screen);
}

test "posts" {
    init();
    defer deinit();
    _ = login("test@example.com", "password");

    const initial_count = app_state.post_count;
    createPost("Hello world!");
    try std.testing.expectEqual(initial_count + 1, app_state.post_count);
}

test "like post" {
    init();
    defer deinit();
    _ = login("test@example.com", "password");

    const initial_likes = app_state.posts[0].likes;
    likePost(1);
    try std.testing.expect(app_state.posts[0].is_liked);
    try std.testing.expectEqual(initial_likes + 1, app_state.posts[0].likes);
}

test "notifications" {
    init();
    defer deinit();
    _ = login("test@example.com", "password");

    try std.testing.expect(app_state.notification_count > 0);
    try std.testing.expect(app_state.unread_count > 0);

    markAllNotificationsRead();
    try std.testing.expectEqual(@as(u32, 0), app_state.unread_count);
}
