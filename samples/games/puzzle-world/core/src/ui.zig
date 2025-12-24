//! Puzzle World - UI Components

const std = @import("std");
const app = @import("app.zig");

pub const Tag = enum { column, row, div, text, button, grid };

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
};

pub const Color = struct {
    pub const background: u32 = 0xFF2C3E50;
    pub const surface: u32 = 0xFF34495E;
    pub const text: u32 = 0xFFFFFFFF;
    pub const text_muted: u32 = 0xFFBDC3C7;
    pub const primary: u32 = 0xFF3498DB;
    pub const success: u32 = 0xFF2ECC71;
    pub const warning: u32 = 0xFFF39C12;
    pub const danger: u32 = 0xFFE74C3C;
};

pub const Props = struct {
    style: Style = .{},
    text: []const u8 = "",
};

pub const VNode = struct {
    tag: Tag,
    props: Props,
    children: []const VNode,
};

fn column(props: Props, children: []const VNode) VNode {
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

pub fn buildGame(state: *const app.GameData) VNode {
    const S = struct {
        var content: [1]VNode = undefined;
    };

    S.content[0] = buildContent(state);

    return column(.{
        .style = .{ .background = Color.background, .flex = 1 },
    }, &S.content);
}

fn buildContent(state: *const app.GameData) VNode {
    if (state.mode == .menu) {
        return buildMenuScreen(state);
    }

    return switch (state.state) {
        .selecting => buildModeSelectScreen(state),
        .playing => buildPlayingScreen(state),
        .paused => buildPausedScreen(state),
        .won => buildWonScreen(state),
        .lost => buildLostScreen(state),
    };
}

fn buildMenuScreen(state: *const app.GameData) VNode {
    const S = struct {
        var items: [5]VNode = undefined;
        var high_buf: [32]u8 = undefined;
    };

    const high_str = std.fmt.bufPrint(&S.high_buf, "High Score: {d}", .{state.high_score}) catch "High Score: 0";

    S.items[0] = text("Puzzle World", .{
        .style = .{ .font_size = 42, .font_weight = 700, .color = Color.text },
    });

    S.items[1] = text(high_str, .{
        .style = .{ .font_size = 16, .color = Color.text_muted },
    });

    S.items[2] = button("Match-3", .{
        .style = .{
            .background = app.GemType.red.color(),
            .color = Color.text,
            .padding = Spacing.symmetric(40, 16),
            .border_radius = 8,
            .font_size = 18,
        },
    });

    S.items[3] = button("Sliding Puzzle", .{
        .style = .{
            .background = app.GemType.blue.color(),
            .color = Color.text,
            .padding = Spacing.symmetric(40, 16),
            .border_radius = 8,
            .font_size = 18,
        },
    });

    S.items[4] = button("Memory Game", .{
        .style = .{
            .background = app.GemType.green.color(),
            .color = Color.text,
            .padding = Spacing.symmetric(40, 16),
            .border_radius = 8,
            .font_size = 18,
        },
    });

    return column(.{
        .style = .{ .flex = 1, .gap = 20, .padding = Spacing.all(40) },
    }, &S.items);
}

fn buildModeSelectScreen(state: *const app.GameData) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
    };

    S.items[0] = text(state.mode.name(), .{
        .style = .{ .font_size = 32, .font_weight = 700, .color = Color.text },
    });

    S.items[1] = button("Start", .{
        .style = .{
            .background = Color.success,
            .color = Color.text,
            .padding = Spacing.symmetric(32, 14),
            .border_radius = 8,
            .font_size = 18,
        },
    });

    S.items[2] = button("Back", .{
        .style = .{
            .background = Color.surface,
            .color = Color.text,
            .padding = Spacing.symmetric(24, 12),
            .border_radius = 8,
        },
    });

    return column(.{
        .style = .{ .flex = 1, .gap = 20, .padding = Spacing.all(40) },
    }, &S.items);
}

fn buildPlayingScreen(state: *const app.GameData) VNode {
    return switch (state.mode) {
        .match3 => buildMatch3Screen(state),
        .sliding => buildSlidingScreen(state),
        .memory => buildMemoryScreen(state),
        .menu => buildMenuScreen(state),
    };
}

fn buildMatch3Screen(state: *const app.GameData) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
        var grid_rows: [8]VNode = undefined;
        var grid_cells: [8][8]VNode = undefined;
        var score_buf: [32]u8 = undefined;
        var moves_buf: [32]u8 = undefined;
    };

    const m3 = &state.match3;
    const score_str = std.fmt.bufPrint(&S.score_buf, "Score: {d} / {d}", .{ m3.score, m3.target_score }) catch "Score: 0";
    const moves_str = std.fmt.bufPrint(&S.moves_buf, "Moves: {d}", .{m3.moves}) catch "Moves: 0";

    // HUD
    S.items[0] = row(.{ .style = .{ .gap = 40, .padding = Spacing.all(10) } }, &.{
        text(score_str, .{ .style = .{ .font_size = 18, .font_weight = 600, .color = Color.text } }),
        text(moves_str, .{ .style = .{ .font_size = 18, .color = Color.text_muted } }),
    });

    // Grid
    for (0..8) |row_idx| {
        for (0..8) |col_idx| {
            const gem = m3.grid[row_idx][col_idx];
            const is_selected = m3.selected_row == row_idx and m3.selected_col == col_idx;

            S.grid_cells[row_idx][col_idx] = div(.{
                .style = .{
                    .background = gem.color(),
                    .width = 40,
                    .height = 40,
                    .border_radius = if (is_selected) 4 else 8,
                },
            }, &.{});
        }
        S.grid_rows[row_idx] = row(.{ .style = .{ .gap = 4 } }, &S.grid_cells[row_idx]);
    }

    S.items[1] = column(.{
        .style = .{ .gap = 4, .background = Color.surface, .padding = Spacing.all(8), .border_radius = 12 },
    }, &S.grid_rows);

    S.items[2] = button("Pause", .{
        .style = .{
            .background = Color.warning,
            .color = Color.text,
            .padding = Spacing.symmetric(20, 10),
            .border_radius = 6,
        },
    });

    return column(.{
        .style = .{ .flex = 1, .gap = 16, .padding = Spacing.all(20) },
    }, &S.items);
}

fn buildSlidingScreen(state: *const app.GameData) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
        var grid_rows: [4]VNode = undefined;
        var grid_cells: [4][4]VNode = undefined;
        var moves_buf: [32]u8 = undefined;
        var tile_bufs: [16][4]u8 = undefined;
    };

    const sl = &state.sliding;
    const moves_str = std.fmt.bufPrint(&S.moves_buf, "Moves: {d}", .{sl.moves}) catch "Moves: 0";

    // HUD
    S.items[0] = text(moves_str, .{
        .style = .{ .font_size = 20, .font_weight = 600, .color = Color.text },
    });

    // Grid
    for (0..4) |row_idx| {
        for (0..4) |col_idx| {
            const tile = sl.tiles[row_idx][col_idx];
            if (tile == 0) {
                S.grid_cells[row_idx][col_idx] = div(.{
                    .style = .{ .width = 60, .height = 60 },
                }, &.{});
            } else {
                const buf_idx = row_idx * 4 + col_idx;
                const tile_str = std.fmt.bufPrint(&S.tile_bufs[buf_idx], "{d}", .{tile}) catch "?";
                S.grid_cells[row_idx][col_idx] = div(.{
                    .style = .{
                        .background = Color.primary,
                        .width = 60,
                        .height = 60,
                        .border_radius = 8,
                    },
                }, &.{
                    text(tile_str, .{ .style = .{ .font_size = 24, .font_weight = 700, .color = Color.text } }),
                });
            }
        }
        S.grid_rows[row_idx] = row(.{ .style = .{ .gap = 4 } }, &S.grid_cells[row_idx]);
    }

    S.items[1] = column(.{
        .style = .{ .gap = 4, .background = Color.surface, .padding = Spacing.all(8), .border_radius = 12 },
    }, &S.grid_rows);

    S.items[2] = text("Use Arrow Keys to move tiles", .{
        .style = .{ .font_size = 14, .color = Color.text_muted },
    });

    return column(.{
        .style = .{ .flex = 1, .gap = 20, .padding = Spacing.all(20) },
    }, &S.items);
}

fn buildMemoryScreen(state: *const app.GameData) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
        var grid_rows: [4]VNode = undefined;
        var grid_cells: [4][4]VNode = undefined;
        var moves_buf: [32]u8 = undefined;
        var pairs_buf: [32]u8 = undefined;
    };

    const mem = &state.memory;
    const moves_str = std.fmt.bufPrint(&S.moves_buf, "Moves: {d}", .{mem.moves}) catch "Moves: 0";
    const pairs_str = std.fmt.bufPrint(&S.pairs_buf, "Pairs: {d}/8", .{mem.pairs_found}) catch "Pairs: 0/8";

    // HUD
    S.items[0] = row(.{ .style = .{ .gap = 40 } }, &.{
        text(moves_str, .{ .style = .{ .font_size = 18, .color = Color.text } }),
        text(pairs_str, .{ .style = .{ .font_size = 18, .color = Color.text } }),
    });

    // Grid (4x4)
    for (0..4) |row_idx| {
        for (0..4) |col_idx| {
            const idx = row_idx * 4 + col_idx;
            const card = mem.cards[idx];
            const is_revealed = mem.revealed[idx];
            const is_matched = mem.matched[idx];

            const bg_color: u32 = if (is_matched)
                Color.success
            else if (is_revealed)
                @as(u32, card) * 0x00222200 + 0xFF3498DB
            else
                Color.surface;

            S.grid_cells[row_idx][col_idx] = div(.{
                .style = .{
                    .background = bg_color,
                    .width = 50,
                    .height = 50,
                    .border_radius = 8,
                },
            }, &.{});
        }
        S.grid_rows[row_idx] = row(.{ .style = .{ .gap = 8 } }, &S.grid_cells[row_idx]);
    }

    S.items[1] = column(.{
        .style = .{ .gap = 8, .padding = Spacing.all(16) },
    }, &S.grid_rows);

    S.items[2] = text("Click cards to reveal and match pairs", .{
        .style = .{ .font_size = 14, .color = Color.text_muted },
    });

    return column(.{
        .style = .{ .flex = 1, .gap = 20, .padding = Spacing.all(20) },
    }, &S.items);
}

fn buildPausedScreen(state: *const app.GameData) VNode {
    _ = state;
    const S = struct {
        var items: [3]VNode = undefined;
    };

    S.items[0] = text("PAUSED", .{
        .style = .{ .font_size = 36, .font_weight = 700, .color = Color.text },
    });

    S.items[1] = button("Resume", .{
        .style = .{
            .background = Color.success,
            .color = Color.text,
            .padding = Spacing.symmetric(24, 12),
            .border_radius = 8,
        },
    });

    S.items[2] = button("Main Menu", .{
        .style = .{
            .background = Color.danger,
            .color = Color.text,
            .padding = Spacing.symmetric(24, 12),
            .border_radius = 8,
        },
    });

    return column(.{
        .style = .{ .flex = 1, .gap = 20, .background = 0xDD2C3E50 },
    }, &S.items);
}

fn buildWonScreen(state: *const app.GameData) VNode {
    const S = struct {
        var items: [4]VNode = undefined;
        var score_buf: [32]u8 = undefined;
    };

    const score_str = std.fmt.bufPrint(&S.score_buf, "Score: {d}", .{state.match3.score}) catch "Score: 0";

    S.items[0] = text("YOU WIN!", .{
        .style = .{ .font_size = 42, .font_weight = 700, .color = Color.success },
    });

    S.items[1] = text(score_str, .{
        .style = .{ .font_size = 24, .color = Color.text },
    });

    S.items[2] = button("Play Again", .{
        .style = .{
            .background = Color.success,
            .color = Color.text,
            .padding = Spacing.symmetric(24, 12),
            .border_radius = 8,
        },
    });

    S.items[3] = button("Main Menu", .{
        .style = .{
            .background = Color.surface,
            .color = Color.text,
            .padding = Spacing.symmetric(24, 12),
            .border_radius = 8,
        },
    });

    return column(.{
        .style = .{ .flex = 1, .gap = 20 },
    }, &S.items);
}

fn buildLostScreen(state: *const app.GameData) VNode {
    _ = state;
    const S = struct {
        var items: [3]VNode = undefined;
    };

    S.items[0] = text("GAME OVER", .{
        .style = .{ .font_size = 42, .font_weight = 700, .color = Color.danger },
    });

    S.items[1] = button("Try Again", .{
        .style = .{
            .background = Color.success,
            .color = Color.text,
            .padding = Spacing.symmetric(24, 12),
            .border_radius = 8,
        },
    });

    S.items[2] = button("Main Menu", .{
        .style = .{
            .background = Color.surface,
            .color = Color.text,
            .padding = Spacing.symmetric(24, 12),
            .border_radius = 8,
        },
    });

    return column(.{
        .style = .{ .flex = 1, .gap = 20 },
    }, &S.items);
}

// C ABI Export
pub fn render() [*]const VNode {
    const S = struct {
        var root: [1]VNode = undefined;
    };
    S.root[0] = buildGame(app.getState());
    return &S.root;
}

// Tests
test "build game" {
    app.init();
    defer app.deinit();
    const view = buildGame(app.getState());
    try std.testing.expectEqual(Tag.column, view.tag);
}

test "render" {
    app.init();
    defer app.deinit();
    const root = render();
    try std.testing.expectEqual(Tag.column, root[0].tag);
}
