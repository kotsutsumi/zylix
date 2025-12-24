//! Drawer Navigation - Application State

const std = @import("std");

pub const Screen = enum(u32) {
    home = 0,
    dashboard = 1,
    profile = 2,
    settings = 3,
    help = 4,

    pub fn title(self: Screen) []const u8 {
        return switch (self) {
            .home => "Home",
            .dashboard => "Dashboard",
            .profile => "Profile",
            .settings => "Settings",
            .help => "Help",
        };
    }

    pub fn icon(self: Screen) []const u8 {
        return switch (self) {
            .home => "house",
            .dashboard => "chart.bar",
            .profile => "person",
            .settings => "gear",
            .help => "questionmark.circle",
        };
    }
};

pub const MenuSection = struct {
    title: []const u8,
    items: []const Screen,
};

pub const menu_sections = [_]MenuSection{
    .{ .title = "Main", .items = &[_]Screen{ .home, .dashboard } },
    .{ .title = "Account", .items = &[_]Screen{ .profile, .settings } },
    .{ .title = "Support", .items = &[_]Screen{.help} },
};

pub const AppState = struct {
    initialized: bool = false,
    current_screen: Screen = .home,
    drawer_open: bool = false,
    user_name: []const u8 = "Guest User",
    user_email: []const u8 = "guest@example.com",
    notification_count: u32 = 0,
};

/// Global app state. Note: This template assumes single-threaded usage.
/// For multi-threaded contexts, add synchronization or use thread-local storage.
var app_state: AppState = .{};

/// Initialize app state. Resets all fields to defaults.
/// Call this once at app startup. To preserve user data across reinit,
/// save relevant fields before calling init() and restore after.
pub fn init() void {
    app_state = .{ .initialized = true };
}

pub fn deinit() void {
    app_state.initialized = false;
}

pub fn getState() *const AppState {
    return &app_state;
}

pub fn getStateMut() *AppState {
    return &app_state;
}

pub fn navigateTo(screen: Screen) void {
    app_state.current_screen = screen;
    app_state.drawer_open = false;
}

pub fn toggleDrawer() void {
    app_state.drawer_open = !app_state.drawer_open;
}

pub fn openDrawer() void {
    app_state.drawer_open = true;
}

pub fn closeDrawer() void {
    app_state.drawer_open = false;
}

// Tests
test "state init" {
    init();
    defer deinit();
    try std.testing.expect(app_state.initialized);
}

test "navigation closes drawer" {
    init();
    defer deinit();
    openDrawer();
    try std.testing.expect(app_state.drawer_open);
    navigateTo(.settings);
    try std.testing.expect(!app_state.drawer_open);
    try std.testing.expectEqual(Screen.settings, app_state.current_screen);
}

test "screen metadata" {
    try std.testing.expectEqualStrings("Home", Screen.home.title());
    try std.testing.expectEqualStrings("house", Screen.home.icon());
}
