//! Social Network Stack - Entry Point and C ABI Exports

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

export fn social_init() void {
    init();
}

export fn social_deinit() void {
    deinit();
}

// Navigation
export fn social_set_screen(screen: u8) void {
    const screen_count = @typeInfo(app.Screen).@"enum".fields.len;
    if (screen < screen_count) {
        app.setScreen(@enumFromInt(screen));
    }
}

export fn social_get_screen() u8 {
    return @intFromEnum(app.getState().current_screen);
}

// Authentication
export fn auth_login() bool {
    return app.login("demo@example.com", "password");
}

export fn auth_logout() void {
    app.logout();
}

export fn auth_is_logged_in() bool {
    return app.isLoggedIn();
}

// Feed
export fn feed_refresh() void {
    app.refreshFeed();
}

export fn feed_load_more() void {
    app.loadMorePosts();
}

export fn feed_get_post_count() u32 {
    return @as(u32, @intCast(app.getState().post_count));
}

// Posts
export fn post_like(post_id: u32) void {
    app.likePost(post_id);
}

export fn post_repost(post_id: u32) void {
    app.repostPost(post_id);
}

// Notifications
export fn notif_mark_read(id: u32) void {
    app.markNotificationRead(id);
}

export fn notif_mark_all_read() void {
    app.markAllNotificationsRead();
}

export fn notif_get_unread_count() u32 {
    return app.getState().unread_count;
}

// Social
export fn user_follow(user_id: u32) void {
    app.followUser(user_id);
}

export fn user_unfollow(user_id: u32) void {
    app.unfollowUser(user_id);
}

// Compose
export fn compose_start() void {
    app.startCompose();
}

export fn compose_cancel() void {
    app.cancelCompose();
}

export fn compose_is_active() bool {
    return app.getState().is_composing;
}

// UI rendering
export fn social_render() [*]const ui.VNode {
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

test "login logout" {
    init();
    defer deinit();

    try std.testing.expect(!auth_is_logged_in());
    _ = auth_login();
    try std.testing.expect(auth_is_logged_in());
    auth_logout();
    try std.testing.expect(!auth_is_logged_in());
}

test "navigation" {
    init();
    defer deinit();
    _ = auth_login();

    social_set_screen(2); // profile
    try std.testing.expectEqual(@as(u8, 2), social_get_screen());
}

test "notifications" {
    init();
    defer deinit();
    _ = auth_login();

    try std.testing.expect(notif_get_unread_count() > 0);
    notif_mark_all_read();
    try std.testing.expectEqual(@as(u32, 0), notif_get_unread_count());
}

test "post interactions" {
    init();
    defer deinit();
    _ = auth_login();

    const initial_likes = app.getState().posts[0].likes;
    post_like(1);
    try std.testing.expectEqual(initial_likes + 1, app.getState().posts[0].likes);
}

test "ui render" {
    init();
    defer deinit();
    const root = social_render();
    try std.testing.expectEqual(ui.Tag.column, root[0].tag);
}
