//! Desktop Native - Application State

const std = @import("std");

pub const Screen = enum(u8) {
    home = 0,
    tray = 1,
    files = 2,
    shortcuts = 3,
    window = 4,

    pub fn title(self: Screen) []const u8 {
        return switch (self) {
            .home => "Desktop Features",
            .tray => "System Tray",
            .files => "File System",
            .shortcuts => "Shortcuts",
            .window => "Window",
        };
    }

    pub fn icon(self: Screen) []const u8 {
        return switch (self) {
            .home => "desktopcomputer",
            .tray => "menubar.rectangle",
            .files => "folder",
            .shortcuts => "command",
            .window => "macwindow",
        };
    }
};

pub const RecentFile = struct {
    path: []const u8 = "",
    name: []const u8 = "",
    size: u32 = 0,
    modified_at: i64 = 0,
    is_pinned: bool = false,
};

pub const Shortcut = struct {
    id: u32 = 0,
    keys: []const u8 = "",
    action: []const u8 = "",
    is_global: bool = false,
    is_enabled: bool = true,
};

pub const TrayMenuItem = struct {
    id: u32 = 0,
    label: []const u8 = "",
    icon: []const u8 = "",
    is_separator: bool = false,
};

pub const max_recent_files = 10;
pub const max_shortcuts = 15;
pub const max_tray_items = 8;

pub const AppState = struct {
    initialized: bool = false,
    current_screen: Screen = .home,

    // System Tray
    tray_visible: bool = true,
    tray_tooltip: []const u8 = "Desktop App",
    tray_menu_items: [max_tray_items]TrayMenuItem = undefined,
    tray_item_count: usize = 0,
    badge_count: u32 = 0,

    // Files
    recent_files: [max_recent_files]RecentFile = undefined,
    recent_file_count: usize = 0,
    current_directory: []const u8 = "/home/user",
    watching_paths: u32 = 0,

    // Shortcuts
    shortcuts: [max_shortcuts]Shortcut = undefined,
    shortcut_count: usize = 0,

    // Window
    is_fullscreen: bool = false,
    is_always_on_top: bool = false,
    is_maximized: bool = false,
    window_width: u32 = 1200,
    window_height: u32 = 800,

    // Notifications
    notifications_enabled: bool = true,
    notification_sound: bool = true,
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
    // Tray menu items
    addTrayItem("Open", "folder");
    addTrayItem("Settings", "gear");
    addTrayItemSeparator();
    addTrayItem("Quit", "power");

    // Recent files
    addRecentFile("/home/user/document.txt", "document.txt", 4096);
    addRecentFile("/home/user/project/main.zig", "main.zig", 8192);
    addRecentFile("/home/user/data.json", "data.json", 2048);

    // Shortcuts
    addShortcut("Cmd+N", "New File", false);
    addShortcut("Cmd+O", "Open File", false);
    addShortcut("Cmd+S", "Save", false);
    addShortcut("Cmd+Shift+S", "Save As", false);
    addShortcut("Cmd+Q", "Quit", true);

    app_state.badge_count = 3;
    app_state.watching_paths = 2;
}

fn addTrayItem(label: []const u8, icon: []const u8) void {
    if (app_state.tray_item_count >= max_tray_items) return;
    app_state.tray_menu_items[app_state.tray_item_count] = .{
        .id = @intCast(app_state.tray_item_count + 1),
        .label = label,
        .icon = icon,
    };
    app_state.tray_item_count += 1;
}

fn addTrayItemSeparator() void {
    if (app_state.tray_item_count >= max_tray_items) return;
    app_state.tray_menu_items[app_state.tray_item_count] = .{
        .id = @intCast(app_state.tray_item_count + 1),
        .is_separator = true,
    };
    app_state.tray_item_count += 1;
}

fn addRecentFile(path: []const u8, name: []const u8, size: u32) void {
    if (app_state.recent_file_count >= max_recent_files) return;
    app_state.recent_files[app_state.recent_file_count] = .{
        .path = path,
        .name = name,
        .size = size,
        .modified_at = 1700000000,
    };
    app_state.recent_file_count += 1;
}

fn addShortcut(keys: []const u8, action: []const u8, is_global: bool) void {
    if (app_state.shortcut_count >= max_shortcuts) return;
    app_state.shortcuts[app_state.shortcut_count] = .{
        .id = @intCast(app_state.shortcut_count + 1),
        .keys = keys,
        .action = action,
        .is_global = is_global,
    };
    app_state.shortcut_count += 1;
}

// Navigation
pub fn setScreen(screen: Screen) void {
    app_state.current_screen = screen;
}

// System Tray
pub fn setTrayVisible(visible: bool) void {
    app_state.tray_visible = visible;
}

pub fn setBadgeCount(count: u32) void {
    app_state.badge_count = count;
}

pub fn clearBadge() void {
    app_state.badge_count = 0;
}

// Files
pub fn clearRecentFiles() void {
    app_state.recent_file_count = 0;
}

pub fn pinRecentFile(index: usize) void {
    if (index < app_state.recent_file_count) {
        app_state.recent_files[index].is_pinned = !app_state.recent_files[index].is_pinned;
    }
}

pub fn addWatchPath() void {
    app_state.watching_paths += 1;
}

pub fn removeWatchPath() void {
    if (app_state.watching_paths > 0) {
        app_state.watching_paths -= 1;
    }
}

// Shortcuts
pub fn toggleShortcut(shortcut_id: u32) void {
    for (0..app_state.shortcut_count) |i| {
        if (app_state.shortcuts[i].id == shortcut_id) {
            app_state.shortcuts[i].is_enabled = !app_state.shortcuts[i].is_enabled;
            break;
        }
    }
}

// Window
pub fn setFullscreen(fullscreen: bool) void {
    app_state.is_fullscreen = fullscreen;
}

pub fn toggleFullscreen() void {
    app_state.is_fullscreen = !app_state.is_fullscreen;
}

pub fn setAlwaysOnTop(enabled: bool) void {
    app_state.is_always_on_top = enabled;
}

pub fn setMaximized(maximized: bool) void {
    app_state.is_maximized = maximized;
}

// Notifications
pub fn setNotificationsEnabled(enabled: bool) void {
    app_state.notifications_enabled = enabled;
}

// Tests
test "state init" {
    init();
    defer deinit();
    try std.testing.expect(app_state.initialized);
    try std.testing.expect(app_state.tray_item_count > 0);
}

test "tray" {
    init();
    defer deinit();
    try std.testing.expect(app_state.tray_visible);
    setBadgeCount(5);
    try std.testing.expectEqual(@as(u32, 5), app_state.badge_count);
}

test "files" {
    init();
    defer deinit();
    try std.testing.expect(app_state.recent_file_count > 0);
    pinRecentFile(0);
    try std.testing.expect(app_state.recent_files[0].is_pinned);
}

test "shortcuts" {
    init();
    defer deinit();
    try std.testing.expect(app_state.shortcut_count > 0);
    const first_id = app_state.shortcuts[0].id;
    toggleShortcut(first_id);
    try std.testing.expect(!app_state.shortcuts[0].is_enabled);
}

test "window" {
    init();
    defer deinit();
    try std.testing.expect(!app_state.is_fullscreen);
    toggleFullscreen();
    try std.testing.expect(app_state.is_fullscreen);
}
