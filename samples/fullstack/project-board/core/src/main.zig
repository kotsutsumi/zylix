//! Project Board - Entry Point and C ABI Exports

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

export fn board_init() void {
    init();
}

export fn board_deinit() void {
    deinit();
}

// Navigation
export fn board_set_screen(screen: u8) void {
    const screen_count = @typeInfo(app.Screen).@"enum".fields.len;
    if (screen < screen_count) {
        app.setScreen(@enumFromInt(screen));
    }
}

export fn board_get_screen() u8 {
    return @intFromEnum(app.getState().current_screen);
}

export fn board_select(board_id: u32) void {
    app.selectBoard(board_id);
}

export fn board_get_current() u32 {
    return app.getState().current_board_id;
}

// Cards
export fn card_select(card_id: u32) void {
    app.selectCard(card_id);
}

export fn card_create(column_id: u32) void {
    app.createCard(column_id, "New Task");
}

export fn card_move(card_id: u32, to_column: u32, position: u32) void {
    app.moveCard(card_id, to_column, position);
}

export fn card_set_priority(card_id: u32, priority: u8) void {
    const priority_count = @typeInfo(app.Priority).@"enum".fields.len;
    if (priority < priority_count) {
        app.updateCardPriority(card_id, @enumFromInt(priority));
    }
}

export fn card_assign(card_id: u32, user_id: u32) void {
    app.assignCard(card_id, user_id);
}

export fn card_add_label(card_id: u32, label_id: u32) void {
    app.addLabelToCard(card_id, label_id);
}

export fn card_get_count() u32 {
    return @as(u32, @intCast(app.getState().card_count));
}

// Columns
export fn column_create() void {
    app.createColumn("New Column");
}

export fn column_get_count() u32 {
    return @as(u32, @intCast(app.getState().column_count));
}

// Drag and drop
export fn drag_start(card_id: u32) void {
    app.startDrag(card_id);
}

export fn drag_update(column_id: u32, position: u32) void {
    app.updateDragTarget(column_id, position);
}

export fn drag_end() void {
    app.endDrag();
}

export fn drag_cancel() void {
    app.cancelDrag();
}

export fn drag_get_card() u32 {
    return app.getState().dragging_card_id;
}

// UI rendering
export fn board_render() [*]const ui.VNode {
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

test "navigation" {
    init();
    defer deinit();

    board_set_screen(0); // boards
    try std.testing.expectEqual(@as(u8, 0), board_get_screen());

    board_set_screen(1); // board
    try std.testing.expectEqual(@as(u8, 1), board_get_screen());
}

test "card operations" {
    init();
    defer deinit();

    const initial_count = card_get_count();
    card_create(1);
    try std.testing.expectEqual(initial_count + 1, card_get_count());
}

test "card priority" {
    init();
    defer deinit();

    card_set_priority(1, 4); // urgent
    try std.testing.expectEqual(app.Priority.urgent, app.getState().cards[0].priority);
}

test "drag and drop" {
    init();
    defer deinit();

    drag_start(1);
    try std.testing.expectEqual(@as(u32, 1), drag_get_card());

    drag_update(3, 0);
    drag_end();

    try std.testing.expectEqual(@as(u32, 0), drag_get_card());
}

test "ui render" {
    init();
    defer deinit();
    const root = board_render();
    try std.testing.expectEqual(ui.Tag.column, root[0].tag);
}
