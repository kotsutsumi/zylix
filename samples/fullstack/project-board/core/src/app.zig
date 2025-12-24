//! Project Board - Application State

const std = @import("std");

pub const Screen = enum(u8) {
    boards = 0,
    board = 1,
    card_detail = 2,
    settings = 3,

    pub fn title(self: Screen) []const u8 {
        return switch (self) {
            .boards => "All Boards",
            .board => "Board",
            .card_detail => "Card Details",
            .settings => "Settings",
        };
    }
};

pub const Priority = enum(u8) {
    none = 0,
    low = 1,
    medium = 2,
    high = 3,
    urgent = 4,

    pub fn label(self: Priority) []const u8 {
        return switch (self) {
            .none => "None",
            .low => "Low",
            .medium => "Medium",
            .high => "High",
            .urgent => "Urgent",
        };
    }

    pub fn color(self: Priority) u32 {
        return switch (self) {
            .none => 0xFF6B7280,
            .low => 0xFF10B981,
            .medium => 0xFF3B82F6,
            .high => 0xFFF59E0B,
            .urgent => 0xFFEF4444,
        };
    }
};

pub const Label = struct {
    id: u32 = 0,
    name: []const u8 = "",
    color: u32 = 0xFF3B82F6,
};

pub const Card = struct {
    id: u32 = 0,
    column_id: u32 = 0,
    title: []const u8 = "",
    description: []const u8 = "",
    priority: Priority = .none,
    assignee_id: u32 = 0,
    position: u32 = 0,
    label_ids: [4]u32 = .{ 0, 0, 0, 0 },
    label_count: u8 = 0,
    created_at: i64 = 0,
    due_date: i64 = 0,
};

pub const Column = struct {
    id: u32 = 0,
    board_id: u32 = 0,
    name: []const u8 = "",
    position: u32 = 0,
    wip_limit: u32 = 0, // 0 = no limit
    card_count: u32 = 0,
};

pub const Board = struct {
    id: u32 = 0,
    name: []const u8 = "",
    description: []const u8 = "",
    column_count: u32 = 0,
    card_count: u32 = 0,
};

pub const User = struct {
    id: u32 = 0,
    name: []const u8 = "",
    avatar: []const u8 = "",
};

const MAX_BOARDS: usize = 10;
const MAX_COLUMNS: usize = 20;
const MAX_CARDS: usize = 100;
const MAX_LABELS: usize = 20;
const MAX_USERS: usize = 10;

pub const AppState = struct {
    initialized: bool = false,
    current_screen: Screen = .boards,

    // Boards
    boards: [MAX_BOARDS]Board = undefined,
    board_count: usize = 0,
    current_board_id: u32 = 0,

    // Columns
    columns: [MAX_COLUMNS]Column = undefined,
    column_count: usize = 0,

    // Cards
    cards: [MAX_CARDS]Card = undefined,
    card_count: usize = 0,
    selected_card_id: u32 = 0,

    // Labels
    labels: [MAX_LABELS]Label = undefined,
    label_count: usize = 0,

    // Users
    users: [MAX_USERS]User = undefined,
    user_count: usize = 0,
    current_user_id: u32 = 0,

    // Drag state
    dragging_card_id: u32 = 0,
    drag_target_column: u32 = 0,
    drag_target_position: u32 = 0,
};

var app_state: AppState = .{};

pub fn init() void {
    app_state = .{ .initialized = true };
    loadSampleData();
}

pub fn deinit() void {
    app_state.initialized = false;
}

pub fn getState() *const AppState {
    return &app_state;
}

fn loadSampleData() void {
    // Create sample users
    app_state.users[0] = .{ .id = 1, .name = "Alice", .avatar = "avatar1" };
    app_state.users[1] = .{ .id = 2, .name = "Bob", .avatar = "avatar2" };
    app_state.users[2] = .{ .id = 3, .name = "Carol", .avatar = "avatar3" };
    app_state.user_count = 3;
    app_state.current_user_id = 1;

    // Create sample labels
    app_state.labels[0] = .{ .id = 1, .name = "Bug", .color = 0xFFEF4444 };
    app_state.labels[1] = .{ .id = 2, .name = "Feature", .color = 0xFF10B981 };
    app_state.labels[2] = .{ .id = 3, .name = "Enhancement", .color = 0xFF3B82F6 };
    app_state.labels[3] = .{ .id = 4, .name = "Documentation", .color = 0xFF8B5CF6 };
    app_state.label_count = 4;

    // Create sample board
    app_state.boards[0] = .{
        .id = 1,
        .name = "Project Alpha",
        .description = "Main development board",
        .column_count = 3,
        .card_count = 5,
    };
    app_state.board_count = 1;
    app_state.current_board_id = 1;

    // Create columns
    app_state.columns[0] = .{ .id = 1, .board_id = 1, .name = "To Do", .position = 0, .card_count = 2 };
    app_state.columns[1] = .{ .id = 2, .board_id = 1, .name = "In Progress", .position = 1, .wip_limit = 3, .card_count = 2 };
    app_state.columns[2] = .{ .id = 3, .board_id = 1, .name = "Done", .position = 2, .card_count = 1 };
    app_state.column_count = 3;

    // Create cards
    app_state.cards[0] = .{
        .id = 1,
        .column_id = 1,
        .title = "Setup project structure",
        .description = "Initialize the project with proper folder structure",
        .priority = .high,
        .assignee_id = 1,
        .position = 0,
    };
    app_state.cards[1] = .{
        .id = 2,
        .column_id = 1,
        .title = "Design database schema",
        .description = "Create ERD and define tables",
        .priority = .medium,
        .position = 1,
    };
    app_state.cards[2] = .{
        .id = 3,
        .column_id = 2,
        .title = "Implement authentication",
        .description = "Add login and signup flows",
        .priority = .high,
        .assignee_id = 2,
        .position = 0,
    };
    app_state.cards[3] = .{
        .id = 4,
        .column_id = 2,
        .title = "Create API endpoints",
        .description = "REST API for CRUD operations",
        .priority = .medium,
        .assignee_id = 1,
        .position = 1,
    };
    app_state.cards[4] = .{
        .id = 5,
        .column_id = 3,
        .title = "Project kickoff",
        .description = "Initial meeting completed",
        .priority = .none,
        .assignee_id = 3,
        .position = 0,
    };
    app_state.card_count = 5;

    app_state.current_screen = .board;
}

// Navigation
pub fn setScreen(screen: Screen) void {
    app_state.current_screen = screen;
}

pub fn selectBoard(board_id: u32) void {
    for (app_state.boards[0..app_state.board_count]) |board| {
        if (board.id == board_id) {
            app_state.current_board_id = board_id;
            app_state.current_screen = .board;
            break;
        }
    }
}

pub fn selectCard(card_id: u32) void {
    for (app_state.cards[0..app_state.card_count]) |card| {
        if (card.id == card_id) {
            app_state.selected_card_id = card_id;
            app_state.current_screen = .card_detail;
            break;
        }
    }
}

// Card operations
pub fn createCard(column_id: u32, title: []const u8) void {
    if (app_state.card_count >= MAX_CARDS) return;

    // Find column and check WIP limit
    for (app_state.columns[0..app_state.column_count]) |*col| {
        if (col.id == column_id) {
            if (col.wip_limit > 0 and col.card_count >= col.wip_limit) return;

            app_state.cards[app_state.card_count] = .{
                .id = @as(u32, @intCast(app_state.card_count)) + 100,
                .column_id = column_id,
                .title = title,
                .position = col.card_count,
            };
            app_state.card_count += 1;
            col.card_count += 1;
            break;
        }
    }
}

pub fn moveCard(card_id: u32, to_column_id: u32, to_position: u32) void {
    var card_ptr: ?*Card = null;
    var from_column_id: u32 = 0;

    // Find the card
    for (app_state.cards[0..app_state.card_count]) |*card| {
        if (card.id == card_id) {
            card_ptr = card;
            from_column_id = card.column_id;
            break;
        }
    }

    if (card_ptr == null) return;
    const card = card_ptr.?;

    // Check target column WIP limit
    for (app_state.columns[0..app_state.column_count]) |*col| {
        if (col.id == to_column_id) {
            if (from_column_id != to_column_id) {
                if (col.wip_limit > 0 and col.card_count >= col.wip_limit) return;
            }
            break;
        }
    }

    // Update column counts if moving between columns
    if (from_column_id != to_column_id) {
        for (app_state.columns[0..app_state.column_count]) |*col| {
            if (col.id == from_column_id) col.card_count -|= 1;
            if (col.id == to_column_id) col.card_count += 1;
        }
    }

    // Update card
    card.column_id = to_column_id;
    card.position = to_position;

    // Reorder other cards in target column
    for (app_state.cards[0..app_state.card_count]) |*c| {
        if (c.id != card_id and c.column_id == to_column_id and c.position >= to_position) {
            c.position += 1;
        }
    }
}

pub fn updateCardPriority(card_id: u32, priority: Priority) void {
    for (app_state.cards[0..app_state.card_count]) |*card| {
        if (card.id == card_id) {
            card.priority = priority;
            break;
        }
    }
}

pub fn assignCard(card_id: u32, user_id: u32) void {
    for (app_state.cards[0..app_state.card_count]) |*card| {
        if (card.id == card_id) {
            card.assignee_id = user_id;
            break;
        }
    }
}

pub fn addLabelToCard(card_id: u32, label_id: u32) void {
    for (app_state.cards[0..app_state.card_count]) |*card| {
        if (card.id == card_id) {
            if (card.label_count < 4) {
                card.label_ids[card.label_count] = label_id;
                card.label_count += 1;
            }
            break;
        }
    }
}

// Column operations
pub fn createColumn(name: []const u8) void {
    if (app_state.column_count >= MAX_COLUMNS) return;

    app_state.columns[app_state.column_count] = .{
        .id = @as(u32, @intCast(app_state.column_count)) + 100,
        .board_id = app_state.current_board_id,
        .name = name,
        .position = @as(u32, @intCast(app_state.column_count)),
    };
    app_state.column_count += 1;

    // Update board column count
    for (app_state.boards[0..app_state.board_count]) |*board| {
        if (board.id == app_state.current_board_id) {
            board.column_count += 1;
            break;
        }
    }
}

// Drag and drop
pub fn startDrag(card_id: u32) void {
    app_state.dragging_card_id = card_id;
}

pub fn updateDragTarget(column_id: u32, position: u32) void {
    app_state.drag_target_column = column_id;
    app_state.drag_target_position = position;
}

pub fn endDrag() void {
    if (app_state.dragging_card_id > 0) {
        moveCard(app_state.dragging_card_id, app_state.drag_target_column, app_state.drag_target_position);
    }
    app_state.dragging_card_id = 0;
    app_state.drag_target_column = 0;
    app_state.drag_target_position = 0;
}

pub fn cancelDrag() void {
    app_state.dragging_card_id = 0;
    app_state.drag_target_column = 0;
    app_state.drag_target_position = 0;
}

// Helper functions
pub fn getCardsInColumn(column_id: u32) []const Card {
    // Return slice of cards in this column
    // In real app, this would be filtered and sorted
    _ = column_id;
    return app_state.cards[0..app_state.card_count];
}

pub fn getColumnsForBoard(board_id: u32) []const Column {
    _ = board_id;
    return app_state.columns[0..app_state.column_count];
}

pub fn getUserById(user_id: u32) ?*const User {
    for (app_state.users[0..app_state.user_count]) |*user| {
        if (user.id == user_id) return user;
    }
    return null;
}

// Tests
test "app init" {
    init();
    defer deinit();
    try std.testing.expect(app_state.initialized);
    try std.testing.expect(app_state.board_count > 0);
}

test "create card" {
    init();
    defer deinit();

    const initial_count = app_state.card_count;
    createCard(1, "New task");
    try std.testing.expectEqual(initial_count + 1, app_state.card_count);
}

test "move card" {
    init();
    defer deinit();

    // Card 1 is in column 1
    try std.testing.expectEqual(@as(u32, 1), app_state.cards[0].column_id);

    // Move to column 2
    moveCard(1, 2, 0);
    try std.testing.expectEqual(@as(u32, 2), app_state.cards[0].column_id);
}

test "update priority" {
    init();
    defer deinit();

    updateCardPriority(1, .urgent);
    try std.testing.expectEqual(Priority.urgent, app_state.cards[0].priority);
}

test "assign card" {
    init();
    defer deinit();

    assignCard(2, 3);
    try std.testing.expectEqual(@as(u32, 3), app_state.cards[1].assignee_id);
}

test "drag and drop" {
    init();
    defer deinit();

    startDrag(1);
    try std.testing.expectEqual(@as(u32, 1), app_state.dragging_card_id);

    updateDragTarget(3, 0);
    endDrag();

    try std.testing.expectEqual(@as(u32, 0), app_state.dragging_card_id);
    try std.testing.expectEqual(@as(u32, 3), app_state.cards[0].column_id);
}
