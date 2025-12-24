//! Android Exclusive - Application State

const std = @import("std");

pub const Screen = enum(u8) {
    home = 0,
    material_you = 1,
    widgets = 2,
    notifications = 3,
    shortcuts = 4,

    pub fn title(self: Screen) []const u8 {
        return switch (self) {
            .home => "Android Features",
            .material_you => "Material You",
            .widgets => "Widgets",
            .notifications => "Notifications",
            .shortcuts => "Shortcuts",
        };
    }

    pub fn icon(self: Screen) []const u8 {
        return switch (self) {
            .home => "android",
            .material_you => "palette",
            .widgets => "widgets",
            .notifications => "notifications",
            .shortcuts => "shortcut",
        };
    }
};

pub const ColorScheme = struct {
    primary: u32 = 0xFF6750A4,
    on_primary: u32 = 0xFFFFFFFF,
    secondary: u32 = 0xFF625B71,
    on_secondary: u32 = 0xFFFFFFFF,
    surface: u32 = 0xFF1C1B1F,
    on_surface: u32 = 0xFFE6E1E5,
    background: u32 = 0xFF1C1B1F,
    error_color: u32 = 0xFFB3261E,
};

pub const NotificationChannel = enum(u8) {
    general = 0,
    messages = 1,
    updates = 2,
    alerts = 3,

    pub fn name(self: NotificationChannel) []const u8 {
        return switch (self) {
            .general => "General",
            .messages => "Messages",
            .updates => "Updates",
            .alerts => "Alerts",
        };
    }

    pub fn importance(self: NotificationChannel) []const u8 {
        return switch (self) {
            .general => "Default",
            .messages => "High",
            .updates => "Low",
            .alerts => "Urgent",
        };
    }
};

pub const AppShortcut = struct {
    id: u32 = 0,
    short_label: []const u8 = "",
    long_label: []const u8 = "",
    icon: []const u8 = "",
    is_pinned: bool = false,
    is_enabled: bool = true,
};

pub const Widget = struct {
    id: u32 = 0,
    name: []const u8 = "",
    description: []const u8 = "",
    min_width: u32 = 0,
    min_height: u32 = 0,
    is_placed: bool = false,
};

pub const max_shortcuts = 10;
pub const max_widgets = 5;
pub const max_notifications = 20;

pub const AppState = struct {
    initialized: bool = false,
    current_screen: Screen = .home,

    // Material You
    dynamic_colors_enabled: bool = true,
    color_scheme: ColorScheme = .{},
    wallpaper_seed: u32 = 0,

    // Widgets
    widgets: [max_widgets]Widget = undefined,
    widget_count: usize = 0,

    // Notifications
    notification_count: u32 = 0,
    channels_enabled: [4]bool = [_]bool{true} ** 4,

    // Shortcuts
    shortcuts: [max_shortcuts]AppShortcut = undefined,
    shortcut_count: usize = 0,

    // Work profile
    is_work_profile: bool = false,
    work_mode_enabled: bool = true,
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
    // Sample dynamic color from wallpaper
    app_state.wallpaper_seed = 0xFF4285F4;
    updateDynamicColors();

    // Sample widgets
    addWidget("Quick Actions", "Fast access to common actions", 2, 1);
    addWidget("Stats Overview", "View your daily statistics", 4, 2);
    addWidget("Recent Items", "Your recent activity", 4, 1);

    // Sample shortcuts
    addShortcut("compose", "Compose", "Write new message", "edit");
    addShortcut("search", "Search", "Search content", "search");
    addShortcut("settings", "Settings", "App settings", "settings");

    // Sample notifications
    app_state.notification_count = 3;
}

fn updateDynamicColors() void {
    // Simulate Material You color extraction
    const seed = app_state.wallpaper_seed;
    app_state.color_scheme.primary = seed;
    app_state.color_scheme.secondary = (seed & 0xFF00FFFF) | 0x00800000;
}

fn addWidget(name: []const u8, description: []const u8, width: u32, height: u32) void {
    if (app_state.widget_count >= max_widgets) return;
    app_state.widgets[app_state.widget_count] = .{
        .id = @intCast(app_state.widget_count + 1),
        .name = name,
        .description = description,
        .min_width = width,
        .min_height = height,
    };
    app_state.widget_count += 1;
}

fn addShortcut(id: []const u8, short_label: []const u8, long_label: []const u8, icon: []const u8) void {
    _ = id;
    if (app_state.shortcut_count >= max_shortcuts) return;
    app_state.shortcuts[app_state.shortcut_count] = .{
        .id = @intCast(app_state.shortcut_count + 1),
        .short_label = short_label,
        .long_label = long_label,
        .icon = icon,
    };
    app_state.shortcut_count += 1;
}

// Navigation
pub fn setScreen(screen: Screen) void {
    app_state.current_screen = screen;
}

// Material You
pub fn setDynamicColorsEnabled(enabled: bool) void {
    app_state.dynamic_colors_enabled = enabled;
}

pub fn getPrimaryColor() u32 {
    return app_state.color_scheme.primary;
}

pub fn getSecondaryColor() u32 {
    return app_state.color_scheme.secondary;
}

// Widgets
pub fn placeWidget(widget_id: u32) void {
    for (0..app_state.widget_count) |i| {
        if (app_state.widgets[i].id == widget_id) {
            app_state.widgets[i].is_placed = true;
            break;
        }
    }
}

pub fn removeWidget(widget_id: u32) void {
    for (0..app_state.widget_count) |i| {
        if (app_state.widgets[i].id == widget_id) {
            app_state.widgets[i].is_placed = false;
            break;
        }
    }
}

// Notifications
pub fn setChannelEnabled(channel: NotificationChannel, enabled: bool) void {
    app_state.channels_enabled[@intFromEnum(channel)] = enabled;
}

pub fn isChannelEnabled(channel: NotificationChannel) bool {
    return app_state.channels_enabled[@intFromEnum(channel)];
}

pub fn clearNotifications() void {
    app_state.notification_count = 0;
}

// Shortcuts
pub fn pinShortcut(shortcut_id: u32) void {
    for (0..app_state.shortcut_count) |i| {
        if (app_state.shortcuts[i].id == shortcut_id) {
            app_state.shortcuts[i].is_pinned = true;
            break;
        }
    }
}

pub fn toggleShortcut(shortcut_id: u32) void {
    for (0..app_state.shortcut_count) |i| {
        if (app_state.shortcuts[i].id == shortcut_id) {
            app_state.shortcuts[i].is_enabled = !app_state.shortcuts[i].is_enabled;
            break;
        }
    }
}

// Work profile
pub fn setWorkModeEnabled(enabled: bool) void {
    app_state.work_mode_enabled = enabled;
}

// Tests
test "state init" {
    init();
    defer deinit();
    try std.testing.expect(app_state.initialized);
    try std.testing.expect(app_state.widget_count > 0);
}

test "dynamic colors" {
    init();
    defer deinit();
    try std.testing.expect(app_state.dynamic_colors_enabled);
    try std.testing.expect(getPrimaryColor() != 0);
}

test "widgets" {
    init();
    defer deinit();
    try std.testing.expect(app_state.widget_count > 0);
    const widget_id = app_state.widgets[0].id;
    placeWidget(widget_id);
    try std.testing.expect(app_state.widgets[0].is_placed);
}

test "notifications" {
    init();
    defer deinit();
    try std.testing.expect(isChannelEnabled(.general));
    setChannelEnabled(.general, false);
    try std.testing.expect(!isChannelEnabled(.general));
}

test "shortcuts" {
    init();
    defer deinit();
    try std.testing.expect(app_state.shortcut_count > 0);
    const shortcut_id = app_state.shortcuts[0].id;
    pinShortcut(shortcut_id);
    try std.testing.expect(app_state.shortcuts[0].is_pinned);
}
