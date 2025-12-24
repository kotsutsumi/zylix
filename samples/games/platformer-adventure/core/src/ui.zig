//! Platformer Adventure - UI Components

const std = @import("std");
const app = @import("app.zig");

pub const Tag = enum { column, row, div, text, button, canvas, sprite };

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
    x: f32 = 0,
    y: f32 = 0,
};

pub const Color = struct {
    pub const background: u32 = 0xFF87CEEB; // Sky blue
    pub const ground: u32 = 0xFF8B4513; // Brown
    pub const platform: u32 = 0xFF228B22; // Forest green
    pub const player: u32 = 0xFFFF6B6B; // Coral red
    pub const enemy: u32 = 0xFF9B59B6; // Purple
    pub const coin: u32 = 0xFFFFD700; // Gold
    pub const text: u32 = 0xFFFFFFFF;
    pub const text_dark: u32 = 0xFF2C3E50;
    pub const goal: u32 = 0xFF2ECC71; // Green
    pub const ui_bg: u32 = 0xAA000000;
};

pub const Props = struct {
    style: Style = .{},
    text: []const u8 = "",
    sprite: []const u8 = "",
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
        .style = .{ .background = Color.background, .width = 800, .height = 600 },
    }, &S.content);
}

fn buildContent(state: *const app.GameData) VNode {
    return switch (state.state) {
        .menu => buildMenuScreen(),
        .playing => buildPlayingScreen(state),
        .paused => buildPausedScreen(state),
        .game_over => buildGameOverScreen(state),
        .victory => buildVictoryScreen(state),
    };
}

fn buildMenuScreen() VNode {
    const S = struct {
        var items: [4]VNode = undefined;
    };

    S.items[0] = text("Platformer Adventure", .{
        .style = .{ .font_size = 48, .font_weight = 700, .color = Color.text_dark },
    });

    S.items[1] = div(.{ .style = .{ .height = 40 } }, &.{});

    S.items[2] = button("Start Game", .{
        .style = .{
            .background = Color.goal,
            .color = Color.text,
            .padding = Spacing.symmetric(32, 16),
            .border_radius = 8,
            .font_size = 20,
        },
    });

    S.items[3] = text("Use Arrow Keys to move, Space to jump", .{
        .style = .{ .font_size = 14, .color = Color.text_dark },
    });

    return column(.{
        .style = .{ .flex = 1, .gap = 20, .padding = Spacing.all(40) },
    }, &S.items);
}

fn buildPlayingScreen(state: *const app.GameData) VNode {
    const S = struct {
        var items: [4]VNode = undefined;
    };

    // HUD
    S.items[0] = buildHUD(state);

    // Game canvas with entities
    S.items[1] = buildGameCanvas(state);

    // Controls hint
    S.items[2] = text("Arrow Keys: Move | Space: Jump | P: Pause", .{
        .style = .{ .font_size = 12, .color = Color.text_dark },
    });

    S.items[3] = div(.{}, &.{});

    return column(.{
        .style = .{ .flex = 1 },
    }, &S.items);
}

fn buildHUD(state: *const app.GameData) VNode {
    const S = struct {
        var items: [3]VNode = undefined;
        var score_buf: [32]u8 = undefined;
        var lives_buf: [16]u8 = undefined;
        var level_buf: [16]u8 = undefined;
    };

    const score_str = std.fmt.bufPrint(&S.score_buf, "Score: {d}", .{state.score}) catch "Score: 0";
    const lives_str = std.fmt.bufPrint(&S.lives_buf, "Lives: {d}", .{state.lives}) catch "Lives: 0";
    const level_str = std.fmt.bufPrint(&S.level_buf, "Level {d}", .{state.current_level}) catch "Level 1";

    S.items[0] = text(score_str, .{ .style = .{ .font_size = 18, .font_weight = 600, .color = Color.text } });
    S.items[1] = text(level_str, .{ .style = .{ .font_size = 18, .font_weight = 600, .color = Color.text } });
    S.items[2] = text(lives_str, .{ .style = .{ .font_size = 18, .font_weight = 600, .color = Color.text } });

    return row(.{
        .style = .{
            .background = Color.ui_bg,
            .padding = Spacing.symmetric(20, 10),
            .gap = 40,
        },
    }, &S.items);
}

fn buildGameCanvas(state: *const app.GameData) VNode {
    const S = struct {
        var items: [30]VNode = undefined;
    };

    var idx: usize = 0;

    // Goal
    S.items[idx] = div(.{
        .style = .{
            .background = Color.goal,
            .x = state.level.goal_x,
            .y = state.level.goal_y,
            .width = state.level.goal_width,
            .height = state.level.goal_height,
            .border_radius = 4,
        },
    }, &.{});
    idx += 1;

    // Platforms
    const plat_count = @min(state.platform_count, 10);
    for (0..plat_count) |i| {
        const platform = state.platforms[i];
        const color: u32 = switch (platform.platform_type) {
            .static => Color.ground,
            .moving => Color.platform,
            .one_way => 0xFF90EE90,
        };
        S.items[idx] = div(.{
            .style = .{
                .background = color,
                .x = platform.x + platform.move_offset,
                .y = platform.y,
                .width = platform.width,
                .height = platform.height,
            },
        }, &.{});
        idx += 1;
    }

    // Collectibles
    const collect_count = @min(state.collectible_count, 10);
    for (0..collect_count) |i| {
        const collectible = state.collectibles[i];
        if (!collectible.collected) {
            const color: u32 = switch (collectible.collectible_type) {
                .coin => Color.coin,
                .speed_boost => 0xFF00CED1,
                .jump_boost => 0xFFFF69B4,
                .health => 0xFFFF0000,
            };
            S.items[idx] = div(.{
                .style = .{
                    .background = color,
                    .x = collectible.x,
                    .y = collectible.y,
                    .width = 24,
                    .height = 24,
                    .border_radius = 12,
                },
            }, &.{});
            idx += 1;
        }
    }

    // Enemies
    const enemy_count = @min(state.enemy_count, 5);
    for (0..enemy_count) |i| {
        const enemy = state.enemies[i];
        if (enemy.active) {
            S.items[idx] = div(.{
                .style = .{
                    .background = Color.enemy,
                    .x = enemy.x,
                    .y = enemy.y,
                    .width = enemy.width,
                    .height = enemy.height,
                    .border_radius = 4,
                },
            }, &.{});
            idx += 1;
        }
    }

    // Player
    S.items[idx] = div(.{
        .style = .{
            .background = Color.player,
            .x = state.player.position.x,
            .y = state.player.position.y,
            .width = state.player.width,
            .height = state.player.height,
            .border_radius = 4,
        },
    }, &.{});
    idx += 1;

    return div(.{
        .style = .{ .width = 800, .height = 500, .background = Color.background },
    }, S.items[0..idx]);
}

fn buildPausedScreen(state: *const app.GameData) VNode {
    const S = struct {
        var items: [4]VNode = undefined;
    };

    // Show game in background
    S.items[0] = buildGameCanvas(state);

    // Overlay
    S.items[1] = text("PAUSED", .{
        .style = .{ .font_size = 48, .font_weight = 700, .color = Color.text },
    });

    S.items[2] = button("Resume", .{
        .style = .{
            .background = Color.goal,
            .color = Color.text,
            .padding = Spacing.symmetric(24, 12),
            .border_radius = 8,
        },
    });

    S.items[3] = button("Main Menu", .{
        .style = .{
            .background = Color.enemy,
            .color = Color.text,
            .padding = Spacing.symmetric(24, 12),
            .border_radius = 8,
        },
    });

    return column(.{
        .style = .{ .flex = 1, .gap = 20, .background = 0xAA000000 },
    }, &S.items);
}

fn buildGameOverScreen(state: *const app.GameData) VNode {
    const S = struct {
        var items: [4]VNode = undefined;
        var score_buf: [32]u8 = undefined;
    };

    const score_str = std.fmt.bufPrint(&S.score_buf, "Final Score: {d}", .{state.score}) catch "Final Score: 0";

    S.items[0] = text("GAME OVER", .{
        .style = .{ .font_size = 48, .font_weight = 700, .color = Color.player },
    });

    S.items[1] = text(score_str, .{
        .style = .{ .font_size = 24, .color = Color.text },
    });

    S.items[2] = button("Try Again", .{
        .style = .{
            .background = Color.goal,
            .color = Color.text,
            .padding = Spacing.symmetric(24, 12),
            .border_radius = 8,
        },
    });

    S.items[3] = button("Main Menu", .{
        .style = .{
            .background = Color.platform,
            .color = Color.text,
            .padding = Spacing.symmetric(24, 12),
            .border_radius = 8,
        },
    });

    return column(.{
        .style = .{ .flex = 1, .gap = 20, .background = 0xDD2C3E50 },
    }, &S.items);
}

fn buildVictoryScreen(state: *const app.GameData) VNode {
    const S = struct {
        var items: [4]VNode = undefined;
        var score_buf: [32]u8 = undefined;
    };

    const score_str = std.fmt.bufPrint(&S.score_buf, "Score: {d}", .{state.score}) catch "Score: 0";

    S.items[0] = text("VICTORY!", .{
        .style = .{ .font_size = 48, .font_weight = 700, .color = Color.coin },
    });

    S.items[1] = text(score_str, .{
        .style = .{ .font_size = 24, .color = Color.text },
    });

    S.items[2] = button("Next Level", .{
        .style = .{
            .background = Color.goal,
            .color = Color.text,
            .padding = Spacing.symmetric(24, 12),
            .border_radius = 8,
        },
    });

    S.items[3] = button("Main Menu", .{
        .style = .{
            .background = Color.platform,
            .color = Color.text,
            .padding = Spacing.symmetric(24, 12),
            .border_radius = 8,
        },
    });

    return column(.{
        .style = .{ .flex = 1, .gap = 20, .background = 0xDD27AE60 },
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
