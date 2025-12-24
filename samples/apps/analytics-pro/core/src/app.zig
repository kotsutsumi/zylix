//! Analytics Pro - Application State

const std = @import("std");

pub const Screen = enum(u8) {
    dashboard = 0,
    analytics = 1,
    reports = 2,
    settings = 3,

    pub fn title(self: Screen) []const u8 {
        return switch (self) {
            .dashboard => "Dashboard",
            .analytics => "Analytics",
            .reports => "Reports",
            .settings => "Settings",
        };
    }
};

pub const TimeRange = enum(u8) {
    today = 0,
    week = 1,
    month = 2,
    year = 3,

    pub fn label(self: TimeRange) []const u8 {
        return switch (self) {
            .today => "Today",
            .week => "This Week",
            .month => "This Month",
            .year => "This Year",
        };
    }
};

pub const Trend = enum(u8) {
    up = 0,
    down = 1,
    stable = 2,

    pub fn icon(self: Trend) []const u8 {
        return switch (self) {
            .up => "arrow.up.right",
            .down => "arrow.down.right",
            .stable => "arrow.right",
        };
    }

    pub fn color(self: Trend) u32 {
        return switch (self) {
            .up => 0xFF34C759,
            .down => 0xFFFF3B30,
            .stable => 0xFF8E8E93,
        };
    }
};

pub const Metric = struct {
    id: u32 = 0,
    name: [32]u8 = [_]u8{0} ** 32,
    name_len: usize = 0,
    value: u32 = 0,
    change_percent: f32 = 0,
    trend: Trend = .stable,
    icon: [32]u8 = [_]u8{0} ** 32,
    icon_len: usize = 0,
};

pub const DataPoint = struct {
    timestamp: i64 = 0,
    value: f32 = 0,
};

pub const ChartType = enum(u8) {
    line = 0,
    bar = 1,
    pie = 2,
    area = 3,
};

pub const max_metrics = 8;
pub const max_data_points = 30;
pub const max_activities = 10;

pub const Activity = struct {
    id: u32 = 0,
    description: [64]u8 = [_]u8{0} ** 64,
    description_len: usize = 0,
    timestamp: i64 = 0,
    icon: [32]u8 = [_]u8{0} ** 32,
    icon_len: usize = 0,
};

pub const AppState = struct {
    initialized: bool = false,
    current_screen: Screen = .dashboard,
    time_range: TimeRange = .week,
    selected_chart: ChartType = .line,

    // Metrics
    metrics: [max_metrics]Metric = undefined,
    metric_count: usize = 0,

    // Chart data
    chart_data: [max_data_points]DataPoint = undefined,
    data_point_count: usize = 0,

    // Recent activity
    activities: [max_activities]Activity = undefined,
    activity_count: usize = 0,
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
    // Add metrics
    _ = addMetric("Revenue", 125400, 12.5, .up, "dollarsign.circle");
    _ = addMetric("Users", 8432, 8.2, .up, "person.2");
    _ = addMetric("Orders", 1289, -3.1, .down, "cart");
    _ = addMetric("Conversion", 342, 0.5, .stable, "percent");

    // Add chart data points
    var i: usize = 0;
    while (i < 7) : (i += 1) {
        const value: f32 = 100.0 + @as(f32, @floatFromInt(i * 15)) + @as(f32, @floatFromInt(i % 3)) * 10.0;
        _ = addDataPoint(1700000000 + @as(i64, @intCast(i)) * 86400, value);
    }

    // Add activities
    _ = addActivity("New user registered", "person.badge.plus");
    _ = addActivity("Order #1234 completed", "cart.badge.checkmark");
    _ = addActivity("Revenue milestone reached", "star.fill");
    _ = addActivity("Daily report generated", "doc.text");
}

fn addMetric(name: []const u8, value: u32, change: f32, trend: Trend, icon: []const u8) ?u32 {
    if (app_state.metric_count >= max_metrics) return null;

    var m = &app_state.metrics[app_state.metric_count];
    m.id = @intCast(app_state.metric_count + 1);

    const name_len = @min(name.len, m.name.len);
    @memcpy(m.name[0..name_len], name[0..name_len]);
    m.name_len = name_len;

    const icon_len = @min(icon.len, m.icon.len);
    @memcpy(m.icon[0..icon_len], icon[0..icon_len]);
    m.icon_len = icon_len;

    m.value = value;
    m.change_percent = change;
    m.trend = trend;

    app_state.metric_count += 1;
    return m.id;
}

fn addDataPoint(timestamp: i64, value: f32) bool {
    if (app_state.data_point_count >= max_data_points) return false;

    app_state.chart_data[app_state.data_point_count] = .{
        .timestamp = timestamp,
        .value = value,
    };
    app_state.data_point_count += 1;
    return true;
}

fn addActivity(description: []const u8, icon: []const u8) ?u32 {
    if (app_state.activity_count >= max_activities) return null;

    var a = &app_state.activities[app_state.activity_count];
    a.id = @intCast(app_state.activity_count + 1);

    const desc_len = @min(description.len, a.description.len);
    @memcpy(a.description[0..desc_len], description[0..desc_len]);
    a.description_len = desc_len;

    const icon_len = @min(icon.len, a.icon.len);
    @memcpy(a.icon[0..icon_len], icon[0..icon_len]);
    a.icon_len = icon_len;

    a.timestamp = 1700000000 + @as(i64, @intCast(app_state.activity_count)) * 3600;

    app_state.activity_count += 1;
    return a.id;
}

// Navigation
pub fn setScreen(screen: Screen) void {
    app_state.current_screen = screen;
}

pub fn setTimeRange(range: TimeRange) void {
    app_state.time_range = range;
}

pub fn setChartType(chart_type: ChartType) void {
    app_state.selected_chart = chart_type;
}

// Queries
pub fn getMetric(id: u32) ?*const Metric {
    for (app_state.metrics[0..app_state.metric_count]) |*m| {
        if (m.id == id) return m;
    }
    return null;
}

pub fn getTotalRevenue() u32 {
    if (app_state.metric_count > 0) {
        return app_state.metrics[0].value;
    }
    return 0;
}

pub fn getTotalUsers() u32 {
    if (app_state.metric_count > 1) {
        return app_state.metrics[1].value;
    }
    return 0;
}

pub fn getChartMax() f32 {
    var max: f32 = 0;
    for (app_state.chart_data[0..app_state.data_point_count]) |dp| {
        if (dp.value > max) max = dp.value;
    }
    return max;
}

pub fn getChartMin() f32 {
    if (app_state.data_point_count == 0) return 0;
    var min: f32 = app_state.chart_data[0].value;
    for (app_state.chart_data[0..app_state.data_point_count]) |dp| {
        if (dp.value < min) min = dp.value;
    }
    return min;
}

// Tests
test "state init" {
    init();
    defer deinit();
    try std.testing.expect(app_state.initialized);
    try std.testing.expect(app_state.metric_count > 0);
    try std.testing.expect(app_state.data_point_count > 0);
}

test "metrics" {
    init();
    defer deinit();
    try std.testing.expect(getTotalRevenue() > 0);
    try std.testing.expect(getTotalUsers() > 0);
}

test "time range" {
    init();
    defer deinit();
    setTimeRange(.month);
    try std.testing.expectEqual(TimeRange.month, app_state.time_range);
}

test "chart data" {
    init();
    defer deinit();
    try std.testing.expect(getChartMax() > getChartMin());
}

test "navigation" {
    init();
    defer deinit();
    setScreen(.analytics);
    try std.testing.expectEqual(Screen.analytics, app_state.current_screen);
}
