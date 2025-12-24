//! Analytics Pro - Entry Point and C ABI Exports

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

export fn app_set_time_range(range: u8) void {
    const range_count = @typeInfo(app.TimeRange).@"enum".fields.len;
    if (range < range_count) {
        app.setTimeRange(@enumFromInt(range));
    }
}

export fn app_get_time_range() u8 {
    return @intFromEnum(app.getState().time_range);
}

export fn app_set_chart_type(chart_type: u8) void {
    const type_count = @typeInfo(app.ChartType).@"enum".fields.len;
    if (chart_type < type_count) {
        app.setChartType(@enumFromInt(chart_type));
    }
}

// Queries
export fn app_get_metric_count() u32 {
    return @intCast(app.getState().metric_count);
}

export fn app_get_total_revenue() u32 {
    return app.getTotalRevenue();
}

export fn app_get_total_users() u32 {
    return app.getTotalUsers();
}

export fn app_get_chart_max() f32 {
    return app.getChartMax();
}

export fn app_get_chart_min() f32 {
    return app.getChartMin();
}

export fn app_get_data_point_count() u32 {
    return @intCast(app.getState().data_point_count);
}

export fn app_get_activity_count() u32 {
    return @intCast(app.getState().activity_count);
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

test "metrics queries" {
    init();
    defer deinit();

    try std.testing.expect(app_get_metric_count() > 0);
    try std.testing.expect(app_get_total_revenue() > 0);
    try std.testing.expect(app_get_total_users() > 0);
}

test "chart data" {
    init();
    defer deinit();

    try std.testing.expect(app_get_data_point_count() > 0);
    try std.testing.expect(app_get_chart_max() > app_get_chart_min());
}

test "time range" {
    init();
    defer deinit();

    app_set_time_range(2); // month
    try std.testing.expectEqual(@as(u8, 2), app_get_time_range());
}

test "navigation" {
    init();
    defer deinit();

    app_set_screen(1); // analytics
    try std.testing.expectEqual(@as(u8, 1), app_get_screen());
}

test "activity" {
    init();
    defer deinit();

    try std.testing.expect(app_get_activity_count() > 0);
}

test "ui render" {
    init();
    defer deinit();

    const root = app_render();
    try std.testing.expectEqual(ui.Tag.column, root[0].tag);
}
