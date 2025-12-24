//! Dashboard Layout - Application State

const std = @import("std");

pub const Widget = enum(u32) {
    stats = 0,
    chart = 1,
    activity = 2,
    actions = 3,
    calendar = 4,
    tasks = 5,

    pub fn title(self: Widget) []const u8 {
        return switch (self) {
            .stats => "Statistics",
            .chart => "Analytics Chart",
            .activity => "Recent Activity",
            .actions => "Quick Actions",
            .calendar => "Calendar",
            .tasks => "Tasks",
        };
    }

    pub fn icon(self: Widget) []const u8 {
        return switch (self) {
            .stats => "chart.pie",
            .chart => "chart.bar",
            .activity => "clock",
            .actions => "bolt",
            .calendar => "calendar",
            .tasks => "checklist",
        };
    }

    pub fn cols(self: Widget) u8 {
        return switch (self) {
            .stats => 2,
            .chart => 2,
            .activity => 1,
            .actions => 1,
            .calendar => 1,
            .tasks => 1,
        };
    }
};

pub const NavItem = struct {
    title: []const u8,
    icon: []const u8,
    badge: ?u32 = null,
};

pub const nav_items = [_]NavItem{
    .{ .title = "Dashboard", .icon = "house" },
    .{ .title = "Analytics", .icon = "chart.bar" },
    .{ .title = "Reports", .icon = "doc.text", .badge = 3 },
    .{ .title = "Users", .icon = "person.2" },
    .{ .title = "Settings", .icon = "gear" },
};

pub const StatCard = struct {
    label: []const u8,
    value: []const u8,
    trend: i8,
    trend_label: []const u8,
};

pub const default_stats = [_]StatCard{
    .{ .label = "Total Revenue", .value = "$45,231", .trend = 12, .trend_label = "+12% from last month" },
    .{ .label = "Active Users", .value = "2,345", .trend = 8, .trend_label = "+8% from last week" },
    .{ .label = "Conversion", .value = "3.2%", .trend = -2, .trend_label = "-2% from last month" },
    .{ .label = "Avg. Session", .value = "4m 32s", .trend = 5, .trend_label = "+5% engagement" },
};

pub const AppState = struct {
    initialized: bool = false,
    sidebar_collapsed: bool = false,
    current_nav: usize = 0,
    theme: Theme = .light,
    user_name: []const u8 = "John Doe",
    user_role: []const u8 = "Administrator",
    notification_count: u32 = 5,
    search_query: [256]u8 = [_]u8{0} ** 256,
    search_query_len: usize = 0,
    visible_widgets: [6]bool = [_]bool{true} ** 6,
};

pub const Theme = enum { light, dark };

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

pub fn getStateMut() *AppState {
    return &app_state;
}

pub fn navigateTo(index: usize) void {
    if (index < nav_items.len) {
        app_state.current_nav = index;
    }
}

pub fn toggleSidebar() void {
    app_state.sidebar_collapsed = !app_state.sidebar_collapsed;
}

pub fn toggleTheme() void {
    app_state.theme = if (app_state.theme == .light) .dark else .light;
}

pub fn toggleWidget(widget: Widget) void {
    const idx = @intFromEnum(widget);
    if (idx < app_state.visible_widgets.len) {
        app_state.visible_widgets[idx] = !app_state.visible_widgets[idx];
    }
}

pub fn setSearchQuery(query: []const u8) void {
    const len = @min(query.len, app_state.search_query.len);
    @memcpy(app_state.search_query[0..len], query[0..len]);
    app_state.search_query_len = len;
}

// Tests
test "state init" {
    init();
    defer deinit();
    try std.testing.expect(app_state.initialized);
    try std.testing.expect(!app_state.sidebar_collapsed);
}

test "navigation" {
    init();
    defer deinit();
    navigateTo(2);
    try std.testing.expectEqual(@as(usize, 2), app_state.current_nav);
}

test "sidebar toggle" {
    init();
    defer deinit();
    try std.testing.expect(!app_state.sidebar_collapsed);
    toggleSidebar();
    try std.testing.expect(app_state.sidebar_collapsed);
}

test "theme toggle" {
    init();
    defer deinit();
    try std.testing.expectEqual(Theme.light, app_state.theme);
    toggleTheme();
    try std.testing.expectEqual(Theme.dark, app_state.theme);
}

test "widget metadata" {
    try std.testing.expectEqualStrings("Statistics", Widget.stats.title());
    try std.testing.expectEqual(@as(u8, 2), Widget.chart.cols());
}
