//! Tab Navigation - Application State
//!
//! Manages tab navigation state and per-tab data preservation.

const std = @import("std");
const router = @import("router.zig");

pub const Tab = router.Tab;

// ============================================================================
// Application State
// ============================================================================

/// Per-tab preserved state
pub const TabState = struct {
    scroll_position: f32 = 0,
    search_query: [256]u8 = [_]u8{0} ** 256,
    search_query_len: usize = 0,
    selected_item: ?usize = null,
};

/// Main application state
pub const AppState = struct {
    initialized: bool = false,
    current_tab: Tab = .home,
    previous_tab: ?Tab = null,

    // Per-tab state preservation
    tab_states: [4]TabState = [_]TabState{.{}} ** 4,

    // Badge counts for each tab
    badges: [4]u32 = [_]u32{0} ** 4,

    // User info (for profile tab)
    user_name: []const u8 = "Guest",
    user_avatar: ?[]const u8 = null,

    // Settings (for settings tab)
    dark_mode: bool = false,
    notifications_enabled: bool = true,

    /// Get state for a specific tab
    pub fn getTabState(self: *const AppState, tab: Tab) *const TabState {
        return &self.tab_states[@intFromEnum(tab)];
    }

    /// Get mutable state for a specific tab
    pub fn getTabStateMut(self: *AppState, tab: Tab) *TabState {
        return &self.tab_states[@intFromEnum(tab)];
    }

    /// Get badge count for a tab
    pub fn getBadge(self: *const AppState, tab: Tab) u32 {
        return self.badges[@intFromEnum(tab)];
    }
};

// Global state instance
var app_state: AppState = .{};

// ============================================================================
// Public API
// ============================================================================

pub fn init() void {
    app_state = .{
        .initialized = true,
    };
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

/// Navigate to a different tab
pub fn navigateTo(tab: Tab) void {
    if (app_state.current_tab != tab) {
        app_state.previous_tab = app_state.current_tab;
        app_state.current_tab = tab;
    }
}

/// Go back to previous tab
pub fn goBack() bool {
    if (app_state.previous_tab) |prev| {
        app_state.current_tab = prev;
        app_state.previous_tab = null;
        return true;
    }
    return false;
}

/// Set badge count for a tab
pub fn setBadge(tab: Tab, count: u32) void {
    app_state.badges[@intFromEnum(tab)] = count;
}

/// Clear badge for a tab
pub fn clearBadge(tab: Tab) void {
    app_state.badges[@intFromEnum(tab)] = 0;
}

/// Update scroll position for current tab
pub fn updateScrollPosition(position: f32) void {
    app_state.getTabStateMut(app_state.current_tab).scroll_position = position;
}

/// Set search query for search tab
pub fn setSearchQuery(query: []const u8) void {
    const tab_state = app_state.getTabStateMut(.search);
    const len = @min(query.len, tab_state.search_query.len);
    @memcpy(tab_state.search_query[0..len], query[0..len]);
    tab_state.search_query_len = len;
}

/// Toggle dark mode
pub fn toggleDarkMode() void {
    app_state.dark_mode = !app_state.dark_mode;
}

/// Toggle notifications
pub fn toggleNotifications() void {
    app_state.notifications_enabled = !app_state.notifications_enabled;
}

// ============================================================================
// Tests
// ============================================================================

test "state initialization" {
    init();
    defer deinit();

    try std.testing.expect(app_state.initialized);
    try std.testing.expectEqual(Tab.home, app_state.current_tab);
    try std.testing.expectEqual(@as(?Tab, null), app_state.previous_tab);
}

test "tab navigation with history" {
    init();
    defer deinit();

    navigateTo(.search);
    try std.testing.expectEqual(Tab.search, app_state.current_tab);
    try std.testing.expectEqual(@as(?Tab, Tab.home), app_state.previous_tab);

    navigateTo(.profile);
    try std.testing.expectEqual(Tab.profile, app_state.current_tab);
    try std.testing.expectEqual(@as(?Tab, Tab.search), app_state.previous_tab);

    const went_back = goBack();
    try std.testing.expect(went_back);
    try std.testing.expectEqual(Tab.search, app_state.current_tab);
}

test "badge management" {
    init();
    defer deinit();

    setBadge(.profile, 5);
    try std.testing.expectEqual(@as(u32, 5), app_state.getBadge(.profile));

    clearBadge(.profile);
    try std.testing.expectEqual(@as(u32, 0), app_state.getBadge(.profile));
}

test "tab state preservation" {
    init();
    defer deinit();

    navigateTo(.search);
    setSearchQuery("test query");
    updateScrollPosition(150.0);

    navigateTo(.home);
    navigateTo(.search);

    const search_state = app_state.getTabState(.search);
    try std.testing.expectEqual(@as(f32, 150.0), search_state.scroll_position);
    try std.testing.expectEqualStrings("test query", search_state.search_query[0..search_state.search_query_len]);
}

test "settings toggles" {
    init();
    defer deinit();

    try std.testing.expect(!app_state.dark_mode);
    toggleDarkMode();
    try std.testing.expect(app_state.dark_mode);

    try std.testing.expect(app_state.notifications_enabled);
    toggleNotifications();
    try std.testing.expect(!app_state.notifications_enabled);
}
