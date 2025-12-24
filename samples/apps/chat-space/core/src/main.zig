//! Chat Space - Entry Point and C ABI Exports

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

export fn app_select_channel(id: u32) void {
    if (id == 0) {
        app.selectChannel(null);
    } else {
        app.selectChannel(id);
    }
}

export fn app_select_dm_user(id: u32) void {
    if (id == 0) {
        app.selectDMUser(null);
    } else {
        app.selectDMUser(id);
    }
}

// Messaging
export fn app_send_message(ptr: [*]const u8, len: usize) i32 {
    if (len == 0) return 0;
    return if (app.sendMessage(ptr[0..len])) 1 else 0;
}

export fn app_set_input_text(ptr: [*]const u8, len: usize) void {
    if (len > 0) {
        app.setInputText(ptr[0..len]);
    } else {
        app.clearInput();
    }
}

export fn app_clear_input() void {
    app.clearInput();
}

export fn app_set_typing(is_typing: i32) void {
    app.setTyping(is_typing != 0);
}

// User status
export fn app_set_status(status: u8) void {
    const status_count = @typeInfo(app.UserStatus).@"enum".fields.len;
    if (status < status_count) {
        app.setStatus(@enumFromInt(status));
    }
}

export fn app_get_status() u8 {
    return @intFromEnum(app.getState().current_status);
}

// Queries
export fn app_get_channel_count() u32 {
    return @intCast(app.getState().channel_count);
}

export fn app_get_user_count() u32 {
    return @intCast(app.getState().user_count);
}

export fn app_get_message_count() u32 {
    return @intCast(app.getState().message_count);
}

export fn app_get_unread_total() u32 {
    return app.getUnreadTotal();
}

export fn app_get_online_count() u32 {
    return app.getOnlineCount();
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

test "channel workflow" {
    init();
    defer deinit();

    try std.testing.expect(app_get_channel_count() > 0);

    app_select_channel(1);
    try std.testing.expectEqual(@as(u8, @intFromEnum(app.Screen.chat)), app_get_screen());
}

test "messaging" {
    init();
    defer deinit();

    app_select_channel(1);
    const initial_count = app_get_message_count();

    const msg = "Hello test!";
    try std.testing.expectEqual(@as(i32, 1), app_send_message(msg.ptr, msg.len));
    try std.testing.expectEqual(initial_count + 1, app_get_message_count());
}

test "user status" {
    init();
    defer deinit();

    app_set_status(2); // busy
    try std.testing.expectEqual(@as(u8, 2), app_get_status());
}

test "typing indicator" {
    init();
    defer deinit();

    app_set_typing(1);
    try std.testing.expect(app.getState().is_typing);
    app_set_typing(0);
    try std.testing.expect(!app.getState().is_typing);
}

test "navigation" {
    init();
    defer deinit();

    app_set_screen(3); // settings
    try std.testing.expectEqual(@as(u8, 3), app_get_screen());
}

test "online count" {
    init();
    defer deinit();

    const count = app_get_online_count();
    try std.testing.expect(count > 0);
}

test "ui render" {
    init();
    defer deinit();

    const root = app_render();
    try std.testing.expectEqual(ui.Tag.column, root[0].tag);
}
