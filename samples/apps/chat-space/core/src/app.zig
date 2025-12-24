//! Chat Space - Application State

const std = @import("std");

pub const Screen = enum(u8) {
    channels = 0,
    chat = 1,
    direct_messages = 2,
    settings = 3,

    pub fn title(self: Screen) []const u8 {
        return switch (self) {
            .channels => "Channels",
            .chat => "Chat",
            .direct_messages => "Messages",
            .settings => "Settings",
        };
    }
};

pub const UserStatus = enum(u8) {
    online = 0,
    away = 1,
    busy = 2,
    offline = 3,

    pub fn color(self: UserStatus) u32 {
        return switch (self) {
            .online => 0xFF34C759, // green
            .away => 0xFFFFCC00, // yellow
            .busy => 0xFFFF3B30, // red
            .offline => 0xFF8E8E93, // gray
        };
    }

    pub fn name(self: UserStatus) []const u8 {
        return switch (self) {
            .online => "Online",
            .away => "Away",
            .busy => "Busy",
            .offline => "Offline",
        };
    }
};

pub const User = struct {
    id: u32 = 0,
    name: [32]u8 = [_]u8{0} ** 32,
    name_len: usize = 0,
    avatar: [32]u8 = [_]u8{0} ** 32,
    avatar_len: usize = 0,
    status: UserStatus = .offline,
    last_seen: i64 = 0,
};

pub const Channel = struct {
    id: u32 = 0,
    name: [32]u8 = [_]u8{0} ** 32,
    name_len: usize = 0,
    is_private: bool = false,
    unread_count: u32 = 0,
    member_count: u32 = 0,
};

pub const Message = struct {
    id: u32 = 0,
    channel_id: u32 = 0,
    sender_id: u32 = 0,
    text: [256]u8 = [_]u8{0} ** 256,
    text_len: usize = 0,
    timestamp: i64 = 0,
};

pub const max_users = 20;
pub const max_channels = 10;
pub const max_messages = 100;
pub const max_input = 256;

pub const AppState = struct {
    initialized: bool = false,
    current_screen: Screen = .channels,

    // Current user
    current_user_id: u32 = 1,
    current_status: UserStatus = .online,

    // Users
    users: [max_users]User = undefined,
    user_count: usize = 0,

    // Channels
    channels: [max_channels]Channel = undefined,
    channel_count: usize = 0,
    selected_channel: ?u32 = null,

    // Direct messages
    selected_dm_user: ?u32 = null,

    // Messages
    messages: [max_messages]Message = undefined,
    message_count: usize = 0,
    next_message_id: u32 = 1,

    // Input
    input_text: [max_input]u8 = [_]u8{0} ** max_input,
    input_len: usize = 0,
    is_typing: bool = false,
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
    // Add users
    _ = addUser("You", "person.circle");
    _ = addUser("Alice", "person.circle.fill");
    _ = addUser("Bob", "person.circle.fill");
    _ = addUser("Charlie", "person.circle.fill");

    // Set some online
    if (app_state.user_count > 1) app_state.users[1].status = .online;
    if (app_state.user_count > 2) app_state.users[2].status = .away;
    if (app_state.user_count > 3) app_state.users[3].status = .offline;

    // Add channels
    _ = addChannel("general", false);
    _ = addChannel("random", false);
    _ = addChannel("announcements", false);
    _ = addChannel("private-team", true);

    // Add sample messages
    _ = addMessage(1, 2, "Hey everyone!");
    _ = addMessage(1, 3, "Hello! How's it going?");
    _ = addMessage(1, 2, "Working on the new feature");
    _ = addMessage(1, 1, "Sounds good!");
}

fn addUser(name: []const u8, avatar: []const u8) ?u32 {
    if (app_state.user_count >= max_users) return null;

    var user = &app_state.users[app_state.user_count];
    user.id = @intCast(app_state.user_count + 1);

    const name_len = @min(name.len, user.name.len);
    @memcpy(user.name[0..name_len], name[0..name_len]);
    user.name_len = name_len;

    const avatar_len = @min(avatar.len, user.avatar.len);
    @memcpy(user.avatar[0..avatar_len], avatar[0..avatar_len]);
    user.avatar_len = avatar_len;

    user.status = .offline;

    app_state.user_count += 1;
    return user.id;
}

fn addChannel(name: []const u8, is_private: bool) ?u32 {
    if (app_state.channel_count >= max_channels) return null;

    var channel = &app_state.channels[app_state.channel_count];
    channel.id = @intCast(app_state.channel_count + 1);

    const name_len = @min(name.len, channel.name.len);
    @memcpy(channel.name[0..name_len], name[0..name_len]);
    channel.name_len = name_len;

    channel.is_private = is_private;
    channel.member_count = @intCast(app_state.user_count);

    app_state.channel_count += 1;
    return channel.id;
}

fn addMessage(channel_id: u32, sender_id: u32, text: []const u8) ?u32 {
    if (app_state.message_count >= max_messages) return null;

    var msg = &app_state.messages[app_state.message_count];
    msg.id = app_state.next_message_id;
    msg.channel_id = channel_id;
    msg.sender_id = sender_id;

    const text_len = @min(text.len, msg.text.len);
    @memcpy(msg.text[0..text_len], text[0..text_len]);
    msg.text_len = text_len;

    msg.timestamp = 1700000000 + @as(i64, @intCast(app_state.message_count * 60));

    app_state.next_message_id += 1;
    app_state.message_count += 1;
    return msg.id;
}

// Navigation
pub fn setScreen(screen: Screen) void {
    app_state.current_screen = screen;
}

pub fn selectChannel(id: ?u32) void {
    app_state.selected_channel = id;
    if (id != null) {
        app_state.current_screen = .chat;
        // Clear unread
        for (app_state.channels[0..app_state.channel_count]) |*ch| {
            if (ch.id == id) {
                ch.unread_count = 0;
                break;
            }
        }
    }
}

pub fn selectDMUser(id: ?u32) void {
    app_state.selected_dm_user = id;
    if (id != null) {
        app_state.current_screen = .chat;
    }
}

// Messaging
pub fn sendMessage(text: []const u8) bool {
    if (text.len == 0) return false;

    const channel_id = app_state.selected_channel orelse return false;
    const result = addMessage(channel_id, app_state.current_user_id, text);

    if (result != null) {
        clearInput();
        return true;
    }
    return false;
}

pub fn setInputText(text: []const u8) void {
    const len = @min(text.len, app_state.input_text.len);
    @memcpy(app_state.input_text[0..len], text[0..len]);
    app_state.input_len = len;
}

pub fn clearInput() void {
    app_state.input_len = 0;
    app_state.is_typing = false;
}

pub fn setTyping(is_typing: bool) void {
    app_state.is_typing = is_typing;
}

// User status
pub fn setStatus(status: UserStatus) void {
    app_state.current_status = status;
    if (app_state.user_count > 0) {
        app_state.users[0].status = status;
    }
}

// Queries
pub fn getUser(id: u32) ?*const User {
    for (app_state.users[0..app_state.user_count]) |*user| {
        if (user.id == id) return user;
    }
    return null;
}

pub fn getChannel(id: u32) ?*const Channel {
    for (app_state.channels[0..app_state.channel_count]) |*ch| {
        if (ch.id == id) return ch;
    }
    return null;
}

pub fn getChannelMessages(channel_id: u32) []const Message {
    // Return all messages for simplicity
    // In real app, would filter by channel_id
    _ = channel_id;
    return app_state.messages[0..app_state.message_count];
}

pub fn getUnreadTotal() u32 {
    var total: u32 = 0;
    for (app_state.channels[0..app_state.channel_count]) |ch| {
        total += ch.unread_count;
    }
    return total;
}

pub fn getOnlineCount() u32 {
    var count: u32 = 0;
    for (app_state.users[0..app_state.user_count]) |user| {
        if (user.status == .online or user.status == .away) {
            count += 1;
        }
    }
    return count;
}

// Tests
test "state init" {
    init();
    defer deinit();
    try std.testing.expect(app_state.initialized);
    try std.testing.expect(app_state.user_count > 0);
    try std.testing.expect(app_state.channel_count > 0);
}

test "channel selection" {
    init();
    defer deinit();
    selectChannel(1);
    try std.testing.expectEqual(@as(?u32, 1), app_state.selected_channel);
    try std.testing.expectEqual(Screen.chat, app_state.current_screen);
}

test "send message" {
    init();
    defer deinit();
    const initial_count = app_state.message_count;
    selectChannel(1);
    try std.testing.expect(sendMessage("Hello world!"));
    try std.testing.expectEqual(initial_count + 1, app_state.message_count);
}

test "user status" {
    init();
    defer deinit();
    setStatus(.busy);
    try std.testing.expectEqual(UserStatus.busy, app_state.current_status);
}

test "unread count" {
    init();
    defer deinit();
    // Set unread on a channel
    if (app_state.channel_count > 0) {
        app_state.channels[0].unread_count = 5;
    }
    try std.testing.expect(getUnreadTotal() >= 5);
}
