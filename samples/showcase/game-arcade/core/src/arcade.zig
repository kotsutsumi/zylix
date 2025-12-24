//! Game Arcade - UI Components

const std = @import("std");
const app = @import("app.zig");

pub const VNode = struct {
    tag: Tag,
    props: Props = .{},
    children: []const VNode = &.{},
    text: ?[]const u8 = null,
};

pub const Tag = enum { div, row, column, text, button, icon, canvas, spacer };

pub const Props = struct {
    id: ?[]const u8 = null,
    style: ?Style = null,
    active: bool = false,
};

pub const Style = struct {
    width: ?Size = null,
    height: ?Size = null,
    padding: ?Spacing = null,
    background: ?Color = null,
    color: ?Color = null,
    font_size: ?u32 = null,
    font_weight: ?FontWeight = null,
    alignment: ?Alignment = null,
    justify: ?Justify = null,
    border_radius: ?u32 = null,
    gap: ?u32 = null,
};

pub const Size = union(enum) { px: u32, percent: f32, fill, wrap };
pub const Spacing = struct {
    top: u32 = 0,
    right: u32 = 0,
    bottom: u32 = 0,
    left: u32 = 0,
    pub fn all(v: u32) Spacing {
        return .{ .top = v, .right = v, .bottom = v, .left = v };
    }
};
pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,
    pub const white = Color{ .r = 255, .g = 255, .b = 255 };
    pub const black = Color{ .r = 0, .g = 0, .b = 0 };
    pub const primary = Color{ .r = 255, .g = 107, .b = 107 };
    pub const secondary = Color{ .r = 78, .g = 205, .b = 196 };
    pub const accent = Color{ .r = 255, .g = 230, .b = 109 };
    pub const dark = Color{ .r = 25, .g = 25, .b = 35 };
    pub const darker = Color{ .r = 15, .g = 15, .b = 22 };
    pub const gray = Color{ .r = 128, .g = 128, .b = 128 };
};
pub const FontWeight = enum { normal, bold, light };
pub const Alignment = enum { start, center, end, stretch };
pub const Justify = enum { start, center, end, space_between };

// App Builder
pub fn buildApp(state: *const app.AppState) VNode {
    return column(.{ .style = .{ .height = .fill, .background = Color.darker } }, &.{
        buildHeader(state),
        row(.{ .style = .{ .height = .fill } }, &.{
            buildGameSelector(state),
            buildGameArea(state),
            buildScorePanel(state),
        }),
    });
}

fn buildHeader(state: *const app.AppState) VNode {
    return row(.{
        .style = .{
            .height = .{ .px = 50 },
            .padding = Spacing.all(12),
            .background = Color.dark,
            .alignment = .center,
            .justify = .space_between,
        },
    }, &.{
        row(.{ .style = .{ .gap = 12, .alignment = .center } }, &.{
            icon("gamecontroller", .{ .style = .{ .color = Color.primary } }),
            text("Game Arcade", .{ .style = .{ .font_size = 18, .font_weight = .bold, .color = Color.white } }),
        }),
        text(state.current_game.title(), .{ .style = .{ .font_size = 14, .color = Color.accent } }),
        buildGameStateIndicator(state),
    });
}

fn buildGameStateIndicator(state: *const app.AppState) VNode {
    const state_text = switch (state.game_state) {
        .menu => "Press Start",
        .playing => "Playing",
        .paused => "Paused",
        .game_over => "Game Over",
        .victory => "Victory!",
    };
    const state_color = switch (state.game_state) {
        .menu => Color.gray,
        .playing => Color.secondary,
        .paused => Color.accent,
        .game_over => Color.primary,
        .victory => Color.secondary,
    };
    return text(state_text, .{ .style = .{ .font_size = 12, .color = state_color } });
}

fn buildGameSelector(state: *const app.AppState) VNode {
    const games = [_]app.Game{ .breakout, .snake, .pong, .memory };
    const S = struct {
        var items: [4]VNode = undefined;
    };
    for (games, 0..) |game, i| {
        S.items[i] = buildGameItem(game, state.current_game == game);
    }
    return column(.{
        .style = .{
            .width = .{ .px = 140 },
            .height = .fill,
            .padding = Spacing.all(8),
            .background = Color.dark,
            .gap = 8,
        },
    }, &.{
        text("Games", .{ .style = .{ .font_size = 11, .font_weight = .bold, .color = Color.gray } }),
        column(.{ .style = .{ .gap = 4 } }, &S.items),
    });
}

fn buildGameItem(game: app.Game, active: bool) VNode {
    return column(.{
        .id = @tagName(game),
        .active = active,
        .style = .{
            .padding = Spacing.all(10),
            .background = if (active) Color.primary else Color.dark,
            .border_radius = 8,
            .gap = 4,
        },
    }, &.{
        text(game.title(), .{ .style = .{ .font_size = 13, .font_weight = .bold, .color = if (active) Color.white else Color.gray } }),
        text(game.description(), .{ .style = .{ .font_size = 10, .color = if (active) Color.white else Color.gray } }),
    });
}

fn buildGameArea(state: *const app.AppState) VNode {
    return column(.{
        .style = .{
            .width = .fill,
            .height = .fill,
            .padding = Spacing.all(16),
            .alignment = .center,
            .justify = .center,
        },
    }, &.{
        buildGameCanvas(state),
        buildGameControls(state),
    });
}

fn buildGameCanvas(state: *const app.AppState) VNode {
    return div(.{
        .style = .{
            .width = .{ .px = 320 },
            .height = .{ .px = 240 },
            .background = Color.black,
            .border_radius = 8,
        },
    }, &.{
        canvas(.{ .id = switch (state.current_game) {
            .breakout => "breakout-canvas",
            .snake => "snake-canvas",
            .pong => "pong-canvas",
            .memory => "memory-canvas",
        } }),
    });
}

fn buildGameControls(state: *const app.AppState) VNode {
    return row(.{
        .style = .{
            .padding = Spacing.all(12),
            .gap = 12,
        },
    }, &.{
        if (state.game_state == .menu or state.game_state == .game_over or state.game_state == .victory)
            button("Start", .{ .id = "start", .style = .{ .padding = Spacing.all(12), .background = Color.secondary, .border_radius = 8 } })
        else
            button("Pause", .{ .id = "pause", .style = .{ .padding = Spacing.all(12), .background = Color.accent, .border_radius = 8 } }),
        button("Reset", .{ .id = "reset", .style = .{ .padding = Spacing.all(12), .background = Color.gray, .border_radius = 8 } }),
    });
}

fn buildScorePanel(state: *const app.AppState) VNode {
    return column(.{
        .style = .{
            .width = .{ .px = 120 },
            .height = .fill,
            .padding = Spacing.all(12),
            .background = Color.dark,
            .gap = 16,
        },
    }, &.{
        buildScoreItem("Score", state.score),
        buildScoreItem("High", state.high_score),
        buildLivesDisplay(state),
    });
}

fn buildScoreItem(label: []const u8, value: u32) VNode {
    const S = struct {
        var score_text: [16]u8 = undefined;
    };
    const score_str = std.fmt.bufPrint(&S.score_text, "{d}", .{value}) catch "0";
    return column(.{ .style = .{ .gap = 4 } }, &.{
        text(label, .{ .style = .{ .font_size = 10, .color = Color.gray } }),
        text(score_str, .{ .style = .{ .font_size = 20, .font_weight = .bold, .color = Color.accent } }),
    });
}

fn buildLivesDisplay(state: *const app.AppState) VNode {
    const S = struct {
        var lives_text: [8]u8 = undefined;
    };
    const lives_str = std.fmt.bufPrint(&S.lives_text, "{d}", .{state.lives}) catch "0";
    return column(.{ .style = .{ .gap = 4 } }, &.{
        text("Lives", .{ .style = .{ .font_size = 10, .color = Color.gray } }),
        row(.{ .style = .{ .gap = 4 } }, &.{
            icon("heart.fill", .{ .style = .{ .color = Color.primary } }),
            text(lives_str, .{ .style = .{ .font_size = 16, .font_weight = .bold, .color = Color.primary } }),
        }),
    });
}

// Element constructors
pub fn div(props: Props, children: []const VNode) VNode {
    return .{ .tag = .div, .props = props, .children = children };
}

pub fn row(props: Props, children: []const VNode) VNode {
    return .{ .tag = .row, .props = props, .children = children };
}

pub fn column(props: Props, children: []const VNode) VNode {
    return .{ .tag = .column, .props = props, .children = children };
}

pub fn text(content: []const u8, props: Props) VNode {
    return .{ .tag = .text, .props = props, .text = content };
}

pub fn button(label: []const u8, props: Props) VNode {
    return .{ .tag = .button, .props = props, .text = label };
}

pub fn icon(name: []const u8, props: Props) VNode {
    return .{ .tag = .icon, .props = props, .text = name };
}

pub fn canvas(props: Props) VNode {
    return .{ .tag = .canvas, .props = props };
}

pub fn spacer(size: u32) VNode {
    return .{ .tag = .spacer, .props = .{ .style = .{ .width = .{ .px = size } } } };
}

// Tests
test "build app" {
    const state = app.AppState{ .initialized = true };
    const view = buildApp(&state);
    try std.testing.expectEqual(Tag.column, view.tag);
}

test "game selector" {
    const state = app.AppState{ .initialized = true, .current_game = .snake };
    const selector = buildGameSelector(&state);
    try std.testing.expectEqual(Tag.column, selector.tag);
}
