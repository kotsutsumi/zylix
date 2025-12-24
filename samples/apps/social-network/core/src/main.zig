//! Social Network - Entry Point and C ABI Exports

const std = @import("std");
pub const app = @import("app.zig");
pub const ui = @import("ui.zig");

// ============================================================================
// Initialization
// ============================================================================

pub fn init() void {
    app.init();
}

pub fn deinit() void {
    app.deinit();
}

// ============================================================================
// C ABI Exports
// ============================================================================

export fn app_init() void {
    init();
}

export fn app_deinit() void {
    deinit();
}

// Navigation
export fn app_set_screen(screen: u8) void {
    const screen_count = @typeInfo(app.Screen).@"enum".fields.len;
    if (screen < screen_count) {
        app.setScreen(@enumFromInt(screen));
    }
}

export fn app_get_screen() u8 {
    return @intFromEnum(app.getState().current_screen);
}

// Posts
export fn app_create_post(content_ptr: [*]const u8, content_len: u32) u32 {
    const content = content_ptr[0..content_len];
    return app.createPost(app.getState().current_user.id, content, "") orelse 0;
}

export fn app_get_post_count() u32 {
    return @intCast(app.getState().post_count);
}

export fn app_like_post(post_id: u32) void {
    app.likePost(post_id);
}

export fn app_unlike_post(post_id: u32) void {
    app.unlikePost(post_id);
}

export fn app_repost(post_id: u32) void {
    app.repostPost(post_id);
}

// Users
export fn app_get_user_count() u32 {
    return @intCast(app.getState().user_count);
}

export fn app_follow_user(user_id: u32) void {
    app.followUser(user_id);
}

export fn app_unfollow_user(user_id: u32) void {
    app.unfollowUser(user_id);
}

// Current user
export fn app_get_followers() u32 {
    return app.getState().current_user.followers;
}

export fn app_get_following() u32 {
    return app.getState().current_user.following;
}

// Notifications
export fn app_get_notification_count() u32 {
    return @intCast(app.getState().notification_count);
}

export fn app_get_unread_count() u32 {
    return app.getState().unread_count;
}

export fn app_mark_notifications_read() void {
    app.markNotificationsRead();
}

// UI rendering
export fn app_render() [*]const ui.VNode {
    return ui.render();
}

// ============================================================================
// Tests
// ============================================================================

test "initialization" {
    init();
    defer deinit();
    try std.testing.expect(app.getState().initialized);
}

test "create post" {
    init();
    defer deinit();

    const initial = app_get_post_count();
    const content = "Hello, world!";
    const id = app_create_post(content.ptr, content.len);
    try std.testing.expect(id > 0);
    try std.testing.expectEqual(initial + 1, app_get_post_count());
}

test "like post" {
    init();
    defer deinit();

    if (app.getState().post_count > 0) {
        const post = &app.getState().posts[0];
        const initial_liked = post.is_liked;
        const post_id = post.id;

        if (!initial_liked) {
            app_like_post(post_id);
            try std.testing.expect(app.getState().posts[0].is_liked);
        }
    }
}

test "follow user" {
    init();
    defer deinit();

    if (app.getState().user_count > 0) {
        const user_id = app.getState().users[0].id;
        const initial_following = app_get_following();

        if (!app.getState().users[0].is_following) {
            app_follow_user(user_id);
            try std.testing.expectEqual(initial_following + 1, app_get_following());
        }
    }
}

test "notifications" {
    init();
    defer deinit();

    try std.testing.expect(app_get_unread_count() > 0);
    app_mark_notifications_read();
    try std.testing.expectEqual(@as(u32, 0), app_get_unread_count());
}

test "navigation" {
    init();
    defer deinit();

    app_set_screen(1); // discover
    try std.testing.expectEqual(@as(u8, 1), app_get_screen());
}

test "ui render" {
    init();
    defer deinit();

    const root = app_render();
    try std.testing.expectEqual(ui.Tag.column, root[0].tag);
}
