//! Project Board - UI Components

const std = @import("std");
const app = @import("app.zig");

pub const Tag = enum { column, row, div, text, button, scroll, icon, avatar, card };

pub const Spacing = struct {
    top: f32 = 0,
    right: f32 = 0,
    bottom: f32 = 0,
    left: f32 = 0,
    pub fn all(v: f32) Spacing {
        return .{ .top = v, .right = v, .bottom = v, .left = v };
    }
    pub fn symmetric(h: f32, v: f32) Spacing {
        return .{ .top = v, .right = h, .bottom = v, .left = h };
    }
};

pub const Style = struct {
    padding: Spacing = .{},
    background: u32 = 0,
    border_radius: f32 = 0,
    font_size: f32 = 14,
    font_weight: u16 = 400,
    color: u32 = Color.text,
    gap: f32 = 0,
    flex: f32 = 0,
    width: f32 = 0,
    height: f32 = 0,
    border_color: u32 = 0,
    border_width: f32 = 0,
};

pub const Color = struct {
    pub const background: u32 = 0xFF0F172A;
    pub const surface: u32 = 0xFF1E293B;
    pub const surface_light: u32 = 0xFF334155;
    pub const primary: u32 = 0xFF3B82F6;
    pub const text: u32 = 0xFFFFFFFF;
    pub const text_muted: u32 = 0xFF94A3B8;
    pub const border: u32 = 0xFF475569;
    pub const success: u32 = 0xFF10B981;
    pub const warning: u32 = 0xFFF59E0B;
    pub const danger: u32 = 0xFFEF4444;
};

pub const Props = struct {
    style: Style = .{},
    text: []const u8 = "",
    icon: []const u8 = "",
};

pub const VNode = struct {
    tag: Tag,
    props: Props,
    children: []const VNode,
};

fn column_view(props: Props, children: []const VNode) VNode {
    return .{ .tag = .column, .props = props, .children = children };
}
fn row(props: Props, children: []const VNode) VNode {
    return .{ .tag = .row, .props = props, .children = children };
}
fn div(props: Props, children: []const VNode) VNode {
    return .{ .tag = .div, .props = props, .children = children };
}
fn text(content: []const u8, props: Props) VNode {
    var p = props;
    p.text = content;
    return .{ .tag = .text, .props = p, .children = &.{} };
}
fn button(label: []const u8, props: Props) VNode {
    var p = props;
    p.text = label;
    return .{ .tag = .button, .props = p, .children = &.{} };
}
fn iconView(name: []const u8, props: Props) VNode {
    var p = props;
    p.icon = name;
    return .{ .tag = .icon, .props = p, .children = &.{} };
}

pub fn buildApp(state: *const app.AppState) VNode {
    const S = struct {
        var content: [1]VNode = undefined;
    };

    S.content[0] = buildContent(state);

    return column_view(.{
        .style = .{ .background = Color.background, .flex = 1 },
    }, &S.content);
}

fn buildContent(state: *const app.AppState) VNode {
    return switch (state.current_screen) {
        .boards => buildBoardsScreen(state),
        .board => buildBoardScreen(state),
        .card_detail => buildCardDetailScreen(state),
        .settings => buildSettingsScreen(),
    };
}

fn buildBoardsScreen(state: *const app.AppState) VNode {
    const S = struct {
        var items: [12]VNode = undefined;
    };

    // Header
    S.items[0] = row(.{
        .style = .{
            .padding = Spacing.all(20),
            .gap = 16,
        },
    }, &.{
        text("My Boards", .{ .style = .{ .font_size = 24, .font_weight = 700, .color = Color.text } }),
    });

    // Boards grid
    const board_count = @min(state.board_count, 10);
    for (0..board_count) |i| {
        S.items[1 + i] = buildBoardCard(&state.boards[i]);
    }

    // Add board button
    S.items[1 + board_count] = button("+ Create Board", .{
        .style = .{
            .background = Color.primary,
            .color = Color.text,
            .padding = Spacing.symmetric(20, 12),
            .border_radius = 8,
        },
    });

    const total = 2 + board_count;
    return column_view(.{
        .style = .{ .flex = 1, .gap = 16, .padding = Spacing.all(20) },
    }, S.items[0..total]);
}

fn buildBoardCard(board: *const app.Board) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
        var card_buf: [16]u8 = undefined;
    };

    const card_str = std.fmt.bufPrint(&S.card_buf, "{d} cards", .{board.card_count}) catch "0 cards";

    S.items[0] = text(board.name, .{ .style = .{ .font_size = 16, .font_weight = 600, .color = Color.text } });
    S.items[1] = text(board.description, .{ .style = .{ .font_size = 13, .color = Color.text_muted } });
    S.items[2] = text(card_str, .{ .style = .{ .font_size = 12, .color = Color.text_muted } });

    return div(.{
        .style = .{
            .background = Color.surface,
            .padding = Spacing.all(16),
            .border_radius = 12,
            .gap = 8,
        },
    }, &S.items);
}

fn buildBoardScreen(state: *const app.AppState) VNode {
    const S = struct {
        var items: [5]VNode = undefined;
        var columns: [4]VNode = undefined;
    };

    // Find current board name
    var board_name: []const u8 = "Board";
    for (state.boards[0..state.board_count]) |board| {
        if (board.id == state.current_board_id) {
            board_name = board.name;
            break;
        }
    }

    // Header
    S.items[0] = row(.{
        .style = .{
            .padding = Spacing.symmetric(20, 16),
            .gap = 16,
            .background = Color.surface,
        },
    }, &.{
        iconView("arrow.left", .{ .style = .{ .color = Color.text_muted, .font_size = 20 } }),
        text(board_name, .{ .style = .{ .font_size = 20, .font_weight = 700, .color = Color.text } }),
    });

    // Build columns
    var col_idx: usize = 0;
    for (state.columns[0..state.column_count]) |*col| {
        if (col.board_id == state.current_board_id and col_idx < 4) {
            S.columns[col_idx] = buildColumn(col, state);
            col_idx += 1;
        }
    }

    // Columns container
    S.items[1] = row(.{
        .style = .{ .flex = 1, .gap = 16, .padding = Spacing.all(16) },
    }, S.columns[0..col_idx]);

    return column_view(.{
        .style = .{ .flex = 1 },
    }, S.items[0..2]);
}

fn buildColumn(col: *const app.Column, state: *const app.AppState) VNode {
    const S = struct {
        var items: [12]VNode = undefined;
        var count_buf: [16]u8 = undefined;
    };

    var count_str: []const u8 = "";
    if (col.wip_limit > 0) {
        count_str = std.fmt.bufPrint(&S.count_buf, "{d}/{d}", .{ col.card_count, col.wip_limit }) catch "";
    } else {
        count_str = std.fmt.bufPrint(&S.count_buf, "{d}", .{col.card_count}) catch "";
    }

    // Column header
    S.items[0] = row(.{
        .style = .{ .gap = 8, .padding = Spacing.symmetric(0, 8) },
    }, &.{
        text(col.name, .{ .style = .{ .font_size = 14, .font_weight = 600, .color = Color.text } }),
        text(count_str, .{ .style = .{ .font_size = 12, .color = Color.text_muted } }),
    });

    // Cards
    var card_idx: usize = 1;
    for (state.cards[0..state.card_count]) |*card| {
        if (card.column_id == col.id and card_idx < 11) {
            S.items[card_idx] = buildCard(card, state);
            card_idx += 1;
        }
    }

    // Add card button
    S.items[card_idx] = button("+ Add Card", .{
        .style = .{
            .color = Color.text_muted,
            .font_size = 13,
            .padding = Spacing.symmetric(0, 8),
        },
    });

    return column_view(.{
        .style = .{
            .background = Color.surface,
            .padding = Spacing.all(12),
            .border_radius = 12,
            .gap = 8,
            .width = 280,
        },
    }, S.items[0 .. card_idx + 1]);
}

fn buildCard(card_data: *const app.Card, state: *const app.AppState) VNode {
    const S = struct {
        var items: [4]VNode = undefined;
    };

    // Title
    S.items[0] = text(card_data.title, .{
        .style = .{ .font_size = 14, .font_weight = 500, .color = Color.text },
    });

    // Priority badge (if set)
    var item_count: usize = 1;
    if (card_data.priority != .none) {
        S.items[item_count] = div(.{
            .style = .{
                .background = card_data.priority.color(),
                .padding = Spacing.symmetric(8, 4),
                .border_radius = 4,
            },
        }, &.{
            text(card_data.priority.label(), .{
                .style = .{ .font_size = 11, .font_weight = 500, .color = Color.text },
            }),
        });
        item_count += 1;
    }

    // Footer with assignee
    if (card_data.assignee_id > 0) {
        if (app.getUserById(card_data.assignee_id)) |user| {
            S.items[item_count] = row(.{
                .style = .{ .gap = 8 },
            }, &.{
                div(.{
                    .style = .{ .width = 24, .height = 24, .border_radius = 12, .background = Color.primary },
                }, &.{}),
                text(user.name, .{ .style = .{ .font_size = 12, .color = Color.text_muted } }),
            });
            item_count += 1;
        }
    }

    _ = state;

    return div(.{
        .style = .{
            .background = Color.surface_light,
            .padding = Spacing.all(12),
            .border_radius = 8,
            .gap = 8,
            .border_color = if (card_data.priority == .urgent) Color.danger else 0,
            .border_width = if (card_data.priority == .urgent) 2 else 0,
        },
    }, S.items[0..item_count]);
}

fn buildCardDetailScreen(state: *const app.AppState) VNode {
    const S = struct {
        var items: [8]VNode = undefined;
    };

    // Find selected card
    var selected_card: ?*const app.Card = null;
    for (state.cards[0..state.card_count]) |*card| {
        if (card.id == state.selected_card_id) {
            selected_card = card;
            break;
        }
    }

    if (selected_card == null) {
        return text("Card not found", .{ .style = .{ .color = Color.text } });
    }

    const card_data = selected_card.?;

    // Header
    S.items[0] = row(.{
        .style = .{
            .padding = Spacing.all(20),
            .gap = 16,
            .background = Color.surface,
        },
    }, &.{
        iconView("xmark", .{ .style = .{ .color = Color.text_muted, .font_size = 20 } }),
        text("Card Details", .{ .style = .{ .font_size = 18, .font_weight = 600, .color = Color.text } }),
    });

    // Title
    S.items[1] = text(card_data.title, .{
        .style = .{ .font_size = 20, .font_weight = 700, .color = Color.text },
    });

    // Description
    S.items[2] = column_view(.{ .style = .{ .gap = 8 } }, &.{
        text("Description", .{ .style = .{ .font_size = 12, .font_weight = 600, .color = Color.text_muted } }),
        text(if (card_data.description.len > 0) card_data.description else "No description", .{
            .style = .{ .font_size = 14, .color = Color.text },
        }),
    });

    // Priority
    S.items[3] = column_view(.{ .style = .{ .gap = 8 } }, &.{
        text("Priority", .{ .style = .{ .font_size = 12, .font_weight = 600, .color = Color.text_muted } }),
        row(.{ .style = .{ .gap = 8 } }, &.{
            div(.{
                .style = .{
                    .background = card_data.priority.color(),
                    .padding = Spacing.symmetric(12, 6),
                    .border_radius = 4,
                },
            }, &.{
                text(card_data.priority.label(), .{ .style = .{ .font_size = 13, .color = Color.text } }),
            }),
        }),
    });

    // Assignee
    S.items[4] = column_view(.{ .style = .{ .gap = 8 } }, &.{
        text("Assignee", .{ .style = .{ .font_size = 12, .font_weight = 600, .color = Color.text_muted } }),
        if (card_data.assignee_id > 0)
            if (app.getUserById(card_data.assignee_id)) |user|
                row(.{ .style = .{ .gap = 8 } }, &.{
                    div(.{
                        .style = .{ .width = 32, .height = 32, .border_radius = 16, .background = Color.primary },
                    }, &.{}),
                    text(user.name, .{ .style = .{ .font_size = 14, .color = Color.text } }),
                })
            else
                text("Unassigned", .{ .style = .{ .color = Color.text_muted } })
        else
            text("Unassigned", .{ .style = .{ .color = Color.text_muted } }),
    });

    // Actions
    S.items[5] = row(.{ .style = .{ .gap = 12 } }, &.{
        button("Edit", .{
            .style = .{
                .background = Color.primary,
                .color = Color.text,
                .padding = Spacing.symmetric(20, 10),
                .border_radius = 6,
            },
        }),
        button("Delete", .{
            .style = .{
                .background = Color.danger,
                .color = Color.text,
                .padding = Spacing.symmetric(20, 10),
                .border_radius = 6,
            },
        }),
    });

    return column_view(.{
        .style = .{ .flex = 1, .gap = 24, .padding = Spacing.all(20) },
    }, S.items[0..6]);
}

fn buildSettingsScreen() VNode {
    const S = struct {
        var items: [4]VNode = undefined;
    };

    S.items[0] = text("Settings", .{
        .style = .{ .font_size = 24, .font_weight = 700, .color = Color.text },
    });

    S.items[1] = buildSettingRow("Board Settings");
    S.items[2] = buildSettingRow("Labels");
    S.items[3] = buildSettingRow("Team Members");

    return column_view(.{
        .style = .{ .flex = 1, .gap = 16, .padding = Spacing.all(20) },
    }, &S.items);
}

fn buildSettingRow(label: []const u8) VNode {
    return row(.{
        .style = .{
            .background = Color.surface,
            .padding = Spacing.all(16),
            .border_radius = 8,
        },
    }, &.{
        text(label, .{ .style = .{ .color = Color.text } }),
        iconView("chevron.right", .{ .style = .{ .color = Color.text_muted, .font_size = 16 } }),
    });
}

// C ABI Export
pub fn render() [*]const VNode {
    const S = struct {
        var root: [1]VNode = undefined;
    };
    S.root[0] = buildApp(app.getState());
    return &S.root;
}

// Tests
test "build app" {
    app.init();
    defer app.deinit();
    const view = buildApp(app.getState());
    try std.testing.expectEqual(Tag.column, view.tag);
}

test "render" {
    app.init();
    defer app.deinit();
    const root = render();
    try std.testing.expectEqual(Tag.column, root[0].tag);
}
