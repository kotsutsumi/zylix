//! Zylix Device - Notifications Module
//!
//! Local and push notification support for all platforms.
//! Supports scheduling, actions, categories, and rich content.

const std = @import("std");
const types = @import("types.zig");

pub const Result = types.Result;
pub const Permission = types.Permission;
pub const PermissionStatus = types.PermissionStatus;

// === Notification Content ===

/// Notification priority
pub const Priority = enum(u8) {
    min = 0, // Silent delivery
    low = 1, // No sound
    default = 2, // Standard
    high = 3, // Heads-up display
    critical = 4, // Critical alert (requires entitlement on iOS)
};

/// Notification category (for actions)
pub const Category = struct {
    id: types.StringBuffer(64) = types.StringBuffer(64).init(),
    actions: [4]?Action = [_]?Action{null} ** 4,
    action_count: usize = 0,
    options: CategoryOptions = .{},

    pub const CategoryOptions = struct {
        custom_dismiss_action: bool = false,
        allow_in_car_play: bool = false, // iOS
        hidden_preview_placeholder: ?[]const u8 = null,
    };

    pub fn addAction(self: *Category, action: Action) bool {
        if (self.action_count >= 4) return false;
        self.actions[self.action_count] = action;
        self.action_count += 1;
        return true;
    }
};

/// Notification action (button)
pub const Action = struct {
    id: types.StringBuffer(64) = types.StringBuffer(64).init(),
    title: types.StringBuffer(64) = types.StringBuffer(64).init(),
    options: ActionOptions = .{},

    pub const ActionOptions = struct {
        requires_foreground: bool = false, // Opens app when tapped
        destructive: bool = false, // Red text on iOS
        requires_authentication: bool = false, // Requires device unlock
    };
};

/// Notification sound
pub const Sound = union(enum) {
    default: void,
    none: void,
    named: types.StringBuffer(128),
    critical: struct {
        name: types.StringBuffer(128),
        volume: f32, // 0.0 - 1.0
    },

    pub fn defaultSound() Sound {
        return .{ .default = {} };
    }

    pub fn silent() Sound {
        return .{ .none = {} };
    }

    pub fn custom(name: []const u8) Sound {
        var s = Sound{ .named = types.StringBuffer(128).init() };
        s.named.set(name);
        return s;
    }
};

/// Notification content
pub const Content = struct {
    // Required
    title: types.StringBuffer(256) = types.StringBuffer(256).init(),
    body: types.StringBuffer(1024) = types.StringBuffer(1024).init(),

    // Optional
    subtitle: types.StringBuffer(256) = types.StringBuffer(256).init(),
    badge: ?u32 = null,
    sound: Sound = Sound.defaultSound(),
    priority: Priority = .default,

    // Grouping
    thread_id: types.StringBuffer(64) = types.StringBuffer(64).init(),
    category_id: types.StringBuffer(64) = types.StringBuffer(64).init(),

    // Rich content
    attachment_url: types.StringBuffer(512) = types.StringBuffer(512).init(),
    launch_image: types.StringBuffer(256) = types.StringBuffer(256).init(),

    // Custom data
    user_info: types.StringBuffer(2048) = types.StringBuffer(2048).init(), // JSON string

    // Presentation
    show_in_foreground: bool = true,
    interruption_level: InterruptionLevel = .active,

    pub const InterruptionLevel = enum(u8) {
        passive = 0, // Silently added to notification list
        active = 1, // Standard notification
        time_sensitive = 2, // Breaks through Focus/DND
        critical = 3, // Always shown (requires entitlement)
    };
};

// === Notification Trigger ===

/// Trigger type for scheduling
pub const Trigger = union(enum) {
    /// Fire immediately
    immediate: void,

    /// Fire after interval (seconds)
    interval: struct {
        seconds: f64,
        repeats: bool = false,
    },

    /// Fire at specific date/time
    calendar: struct {
        year: ?u16 = null,
        month: ?u8 = null, // 1-12
        day: ?u8 = null, // 1-31
        hour: ?u8 = null, // 0-23
        minute: ?u8 = null, // 0-59
        second: ?u8 = null, // 0-59
        weekday: ?u8 = null, // 1-7 (Sunday = 1)
        repeats: bool = false,
    },

    /// Fire when entering/exiting location (iOS)
    location: struct {
        latitude: f64,
        longitude: f64,
        radius: f64, // meters
        notify_on_entry: bool = true,
        notify_on_exit: bool = false,
        repeats: bool = false,
    },

    pub fn afterSeconds(seconds: f64) Trigger {
        return .{ .interval = .{ .seconds = seconds } };
    }

    pub fn afterMinutes(minutes: f64) Trigger {
        return .{ .interval = .{ .seconds = minutes * 60 } };
    }

    pub fn afterHours(hours: f64) Trigger {
        return .{ .interval = .{ .seconds = hours * 3600 } };
    }

    pub fn daily(hour: u8, minute: u8) Trigger {
        return .{ .calendar = .{
            .hour = hour,
            .minute = minute,
            .repeats = true,
        } };
    }

    pub fn weekly(weekday: u8, hour: u8, minute: u8) Trigger {
        return .{ .calendar = .{
            .weekday = weekday,
            .hour = hour,
            .minute = minute,
            .repeats = true,
        } };
    }
};

// === Notification Request ===

/// Notification request
pub const Request = struct {
    id: types.StringBuffer(64) = types.StringBuffer(64).init(),
    content: Content = .{},
    trigger: Trigger = .{ .immediate = {} },

    /// Set notification ID
    pub fn setId(self: *Request, id: []const u8) void {
        self.id.set(id);
    }

    /// Get notification ID
    pub fn getId(self: *const Request) []const u8 {
        return self.id.get();
    }
};

// === Notification Response ===

/// User response to notification
pub const Response = struct {
    notification_id: types.StringBuffer(64) = types.StringBuffer(64).init(),
    action_id: types.StringBuffer(64) = types.StringBuffer(64).init(), // "default" if tapped
    user_text: types.StringBuffer(1024) = types.StringBuffer(1024).init(), // For text input actions
    timestamp: i64 = 0,

    pub fn isDefaultAction(self: *const Response) bool {
        return std.mem.eql(u8, self.action_id.get(), "default");
    }
};

/// Notification received callback
pub const ReceivedCallback = *const fn (content: *const Content) void;

/// Notification response callback
pub const ResponseCallback = *const fn (response: *const Response) void;

/// Notification error callback
pub const ErrorCallback = *const fn (error_code: Result, notification_id: ?[*]const u8, id_len: usize) void;

// === Push Notification ===

/// Push notification token
pub const PushToken = struct {
    data: [256]u8 = undefined,
    len: usize = 0,
    type: TokenType = .apns,

    pub const TokenType = enum(u8) {
        apns = 0, // Apple Push Notification Service
        fcm = 1, // Firebase Cloud Messaging
        web_push = 2, // Web Push API
    };

    pub fn setToken(self: *PushToken, token: []const u8) void {
        const copy_len = @min(token.len, 256);
        @memcpy(self.data[0..copy_len], token[0..copy_len]);
        self.len = copy_len;
    }

    pub fn getToken(self: *const PushToken) []const u8 {
        return self.data[0..self.len];
    }

    /// Get hex string representation
    pub fn toHexString(self: *const PushToken, buffer: []u8) []const u8 {
        const token = self.getToken();
        var pos: usize = 0;
        for (token) |byte| {
            if (pos + 2 > buffer.len) break;
            const hex = "0123456789abcdef";
            buffer[pos] = hex[byte >> 4];
            buffer[pos + 1] = hex[byte & 0x0F];
            pos += 2;
        }
        return buffer[0..pos];
    }
};

/// Push token callback
pub const PushTokenCallback = *const fn (token: *const PushToken) void;

// === Notification Manager ===

/// Notification manager
pub const NotificationManager = struct {
    permission_status: PermissionStatus = .not_determined,
    push_token: ?PushToken = null,

    // Categories
    categories: [16]?Category = [_]?Category{null} ** 16,
    category_count: usize = 0,

    // Callbacks
    received_callback: ?ReceivedCallback = null,
    response_callback: ?ResponseCallback = null,
    error_callback: ?ErrorCallback = null,
    push_token_callback: ?PushTokenCallback = null,

    // Platform handle
    platform_handle: ?*anyopaque = null,

    const Self = @This();

    pub fn init() Self {
        return .{};
    }

    pub fn deinit(self: *Self) void {
        self.removeAllPendingNotifications();
        self.platform_handle = null;
    }

    /// Request notification permission
    pub fn requestPermission(self: *Self, options: PermissionOptions) Result {
        _ = self;
        _ = options;
        // Platform-specific implementation
        return .not_available;
    }

    pub const PermissionOptions = struct {
        alert: bool = true,
        badge: bool = true,
        sound: bool = true,
        provisional: bool = false, // iOS: deliver quietly
        critical_alert: bool = false, // Requires entitlement
        car_play: bool = false,
    };

    /// Check permission status
    pub fn checkPermission(self: *Self) PermissionStatus {
        return self.permission_status;
    }

    /// Register notification category
    pub fn registerCategory(self: *Self, category: Category) Result {
        if (self.category_count >= 16) {
            return .not_available;
        }

        for (&self.categories) |*slot| {
            if (slot.* == null) {
                slot.* = category;
                self.category_count += 1;
                return .ok;
            }
        }
        return .not_available;
    }

    /// Schedule a notification
    pub fn schedule(self: *Self, request: Request) Result {
        if (!self.permission_status.isAuthorized()) {
            return .permission_denied;
        }
        _ = request;
        // Platform-specific implementation
        return .ok;
    }

    /// Cancel a scheduled notification
    pub fn cancel(_: *Self, notification_id: []const u8) Result {
        _ = notification_id;
        // Platform-specific implementation
        return .ok;
    }

    /// Cancel multiple notifications
    pub fn cancelMultiple(_: *Self, ids: []const []const u8) Result {
        _ = ids;
        // Platform-specific implementation
        return .ok;
    }

    /// Remove all pending notifications
    pub fn removeAllPendingNotifications(_: *Self) void {
        // Platform-specific implementation
    }

    /// Remove all delivered notifications
    pub fn removeAllDeliveredNotifications(_: *Self) void {
        // Platform-specific implementation
    }

    /// Get pending notification IDs
    pub fn getPendingNotifications(_: *Self, buffer: []types.StringBuffer(64)) usize {
        _ = buffer;
        // Platform-specific implementation
        return 0;
    }

    /// Set badge count
    pub fn setBadgeCount(_: *Self, count: u32) Result {
        _ = count;
        // Platform-specific implementation
        return .ok;
    }

    /// Clear badge
    pub fn clearBadge(self: *Self) Result {
        return self.setBadgeCount(0);
    }

    // === Push Notifications ===

    /// Register for push notifications
    pub fn registerForPushNotifications(self: *Self) Result {
        if (!self.permission_status.isAuthorized()) {
            return .permission_denied;
        }
        // Platform-specific implementation
        return .ok;
    }

    /// Unregister from push notifications
    pub fn unregisterFromPushNotifications(_: *Self) Result {
        // Platform-specific implementation
        return .ok;
    }

    /// Get push token
    pub fn getPushToken(self: *const Self) ?PushToken {
        return self.push_token;
    }

    // === Callbacks ===

    pub fn setReceivedCallback(self: *Self, callback: ?ReceivedCallback) void {
        self.received_callback = callback;
    }

    pub fn setResponseCallback(self: *Self, callback: ?ResponseCallback) void {
        self.response_callback = callback;
    }

    pub fn setErrorCallback(self: *Self, callback: ?ErrorCallback) void {
        self.error_callback = callback;
    }

    pub fn setPushTokenCallback(self: *Self, callback: ?PushTokenCallback) void {
        self.push_token_callback = callback;
    }

    // === Internal callbacks ===

    pub fn onNotificationReceived(self: *Self, content: Content) void {
        if (self.received_callback) |cb| cb(&content);
    }

    pub fn onNotificationResponse(self: *Self, response: Response) void {
        if (self.response_callback) |cb| cb(&response);
    }

    pub fn onPushTokenReceived(self: *Self, token: PushToken) void {
        self.push_token = token;
        if (self.push_token_callback) |cb| cb(&token);
    }

    pub fn onError(self: *Self, error_code: Result, notification_id: ?[]const u8) void {
        if (self.error_callback) |cb| {
            if (notification_id) |id| {
                cb(error_code, id.ptr, id.len);
            } else {
                cb(error_code, null, 0);
            }
        }
    }
};

// === Global Instance ===

var global_manager: ?NotificationManager = null;

pub fn getManager() *NotificationManager {
    if (global_manager == null) {
        global_manager = NotificationManager.init();
    }
    return &global_manager.?;
}

pub fn init() Result {
    if (global_manager != null) return .ok;
    global_manager = NotificationManager.init();
    return .ok;
}

pub fn deinit() void {
    if (global_manager) |*m| m.deinit();
    global_manager = null;
}

// === Convenience Functions ===

/// Schedule a simple notification
pub fn scheduleSimple(id: []const u8, title: []const u8, body: []const u8, trigger: Trigger) Result {
    var request = Request{};
    request.setId(id);
    request.content.title.set(title);
    request.content.body.set(body);
    request.trigger = trigger;
    return getManager().schedule(request);
}

/// Schedule a notification after delay
pub fn scheduleAfterDelay(id: []const u8, title: []const u8, body: []const u8, seconds: f64) Result {
    return scheduleSimple(id, title, body, Trigger.afterSeconds(seconds));
}

// === Tests ===

test "NotificationManager initialization" {
    var manager = NotificationManager.init();
    defer manager.deinit();

    try std.testing.expect(manager.push_token == null);
    try std.testing.expectEqual(@as(usize, 0), manager.category_count);
}

test "Trigger creation" {
    const interval = Trigger.afterMinutes(5);
    switch (interval) {
        .interval => |i| try std.testing.expectApproxEqAbs(@as(f64, 300), i.seconds, 0.1),
        else => unreachable,
    }

    const daily = Trigger.daily(9, 30);
    switch (daily) {
        .calendar => |c| {
            try std.testing.expectEqual(@as(u8, 9), c.hour.?);
            try std.testing.expectEqual(@as(u8, 30), c.minute.?);
            try std.testing.expect(c.repeats);
        },
        else => unreachable,
    }
}

test "PushToken hex conversion" {
    var token = PushToken{};
    token.setToken(&[_]u8{ 0xDE, 0xAD, 0xBE, 0xEF });

    var buffer: [64]u8 = undefined;
    const hex = token.toHexString(&buffer);
    try std.testing.expectEqualStrings("deadbeef", hex);
}

test "Category with actions" {
    var category = Category{};
    category.id.set("message");

    var action1 = Action{};
    action1.id.set("reply");
    action1.title.set("Reply");

    try std.testing.expect(category.addAction(action1));
    try std.testing.expectEqual(@as(usize, 1), category.action_count);
}
