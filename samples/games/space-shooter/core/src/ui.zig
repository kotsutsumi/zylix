//! Space Shooter - UI Components

const std = @import("std");
const app = @import("app.zig");

pub const Tag = enum { column, row, div, text, button, canvas };

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
    pub const background: u32 = 0xFF0A0A1A; // Dark space
    pub const player: u32 = 0xFF3498DB; // Blue
    pub const bullet: u32 = 0xFF2ECC71; // Green
    pub const enemy_bullet: u32 = 0xFFFF6B6B; // Red
    pub const text: u32 = 0xFFFFFFFF;
    pub const text_muted: u32 = 0xFF7F8C8D;
    pub const hud_bg: u32 = 0x88000000;
    pub const shield: u32 = 0xFF00BFFF;
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
        .style = .{ .background = Color.background, .width = 800, .height = 600 },
    }, &S.content);
}

fn buildContent(state: *const app.GameData) VNode {
    return switch (state.state) {
        .menu => buildMenuScreen(state),
        .playing => buildPlayingScreen(state),
        .paused => buildPausedScreen(state),
        .game_over => buildGameOverScreen(state),
        .victory => buildVictoryScreen(state),
    };
}

fn buildMenuScreen(state: *const app.GameData) VNode {
    const S = struct {
        var items: [5]VNode = undefined;
        var high_buf: [32]u8 = undefined;
    };

    const high_str = std.fmt.bufPrint(&S.high_buf, "High Score: {d}", .{state.high_score}) catch "High Score: 0";

    S.items[0] = text("SPACE SHOOTER", .{
        .style = .{ .font_size = 48, .font_weight = 700, .color = Color.player },
    });

    S.items[1] = text(high_str, .{
        .style = .{ .font_size = 18, .color = Color.text_muted },
    });

    S.items[2] = div(.{ .style = .{ .height = 30 } }, &.{});

    S.items[3] = button("START GAME", .{
        .style = .{
            .background = Color.player,
            .color = Color.text,
            .padding = Spacing.symmetric(40, 16),
            .border_radius = 8,
            .font_size = 20,
            .font_weight = 600,
        },
    });

    S.items[4] = text("Arrow Keys: Move | Space: Fire | X: Special", .{
        .style = .{ .font_size = 14, .color = Color.text_muted },
    });

    return column(.{
        .style = .{ .flex = 1, .gap = 20, .padding = Spacing.all(40) },
    }, &S.items);
}

fn buildPlayingScreen(state: *const app.GameData) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = buildHUD(state);
    S.items[1] = buildGameCanvas(state);

    return column(.{
        .style = .{ .flex = 1 },
    }, &S.items);
}

fn buildHUD(state: *const app.GameData) VNode {
    const S = struct {
        var items: [5]VNode = undefined;
        var score_buf: [32]u8 = undefined;
        var wave_buf: [16]u8 = undefined;
        var lives_buf: [16]u8 = undefined;
        var combo_buf: [16]u8 = undefined;
        var special_buf: [16]u8 = undefined;
    };

    const score_str = std.fmt.bufPrint(&S.score_buf, "Score: {d}", .{state.score}) catch "Score: 0";
    const wave_str = std.fmt.bufPrint(&S.wave_buf, "Wave {d}", .{state.current_wave}) catch "Wave 1";
    const lives_str = std.fmt.bufPrint(&S.lives_buf, "Lives: {d}", .{state.lives}) catch "Lives: 0";
    const combo_str = std.fmt.bufPrint(&S.combo_buf, "x{d}", .{state.combo + 1}) catch "x1";
    const special_str = std.fmt.bufPrint(&S.special_buf, "Special: {d}", .{state.player.special_ammo}) catch "Special: 0";

    S.items[0] = text(score_str, .{ .style = .{ .font_size = 18, .font_weight = 600, .color = Color.text } });
    S.items[1] = text(wave_str, .{ .style = .{ .font_size = 16, .color = Color.text } });
    S.items[2] = text(if (state.combo > 0) combo_str else "", .{
        .style = .{ .font_size = 16, .font_weight = 700, .color = 0xFFFFD700 },
    });
    S.items[3] = text(special_str, .{ .style = .{ .font_size = 14, .color = Color.text_muted } });
    S.items[4] = text(lives_str, .{ .style = .{ .font_size = 16, .color = Color.text } });

    return row(.{
        .style = .{
            .background = Color.hud_bg,
            .padding = Spacing.symmetric(20, 10),
            .gap = 30,
        },
    }, &S.items);
}

fn buildGameCanvas(state: *const app.GameData) VNode {
    const S = struct {
        var items: [130]VNode = undefined; // player + bullets + enemies + enemy_bullets + powerups
    };

    var idx: usize = 0;

    // Player bullets
    for (state.bullets) |b| {
        if (b.active) {
            S.items[idx] = div(.{
                .style = .{
                    .background = Color.bullet,
                    .x = b.x - 3,
                    .y = b.y - 8,
                    .width = 6,
                    .height = 16,
                    .border_radius = 3,
                },
            }, &.{});
            idx += 1;
            if (idx >= S.items.len - 5) break;
        }
    }

    // Enemy bullets
    for (state.enemy_bullets) |b| {
        if (b.active) {
            S.items[idx] = div(.{
                .style = .{
                    .background = Color.enemy_bullet,
                    .x = b.x - 4,
                    .y = b.y - 4,
                    .width = 8,
                    .height = 8,
                    .border_radius = 4,
                },
            }, &.{});
            idx += 1;
            if (idx >= S.items.len - 5) break;
        }
    }

    // Enemies
    for (state.enemies) |e| {
        if (e.active) {
            S.items[idx] = div(.{
                .style = .{
                    .background = e.enemy_type.color(),
                    .x = e.x,
                    .y = e.y,
                    .width = 30,
                    .height = 30,
                    .border_radius = if (e.enemy_type == .boss) 4 else 15,
                },
            }, &.{});
            idx += 1;
            if (idx >= S.items.len - 5) break;
        }
    }

    // Powerups
    for (state.powerups) |p| {
        if (p.active) {
            S.items[idx] = div(.{
                .style = .{
                    .background = p.power_type.color(),
                    .x = p.x,
                    .y = p.y,
                    .width = 20,
                    .height = 20,
                    .border_radius = 4,
                },
            }, &.{});
            idx += 1;
            if (idx >= S.items.len - 2) break;
        }
    }

    // Player ship
    const p = &state.player;
    const blink = p.invincible_timer > 0 and @as(u32, @intFromFloat(p.invincible_timer * 10)) % 2 == 0;

    if (!blink) {
        S.items[idx] = div(.{
            .style = .{
                .background = Color.player,
                .x = p.x,
                .y = p.y,
                .width = p.width,
                .height = p.height,
                .border_radius = 4,
            },
        }, &.{});
        idx += 1;
    }

    // Shield indicator
    if (p.shield > 0) {
        S.items[idx] = div(.{
            .style = .{
                .background = 0x443498DB,
                .x = p.x - 5,
                .y = p.y - 5,
                .width = p.width + 10,
                .height = p.height + 10,
                .border_radius = 25,
            },
        }, &.{});
        idx += 1;
    }

    return div(.{
        .style = .{ .flex = 1, .background = Color.background },
    }, S.items[0..idx]);
}

fn buildPausedScreen(state: *const app.GameData) VNode {
    _ = state;
    const S = struct {
        var items: [3]VNode = undefined;
    };

    S.items[0] = text("PAUSED", .{
        .style = .{ .font_size = 48, .font_weight = 700, .color = Color.text },
    });

    S.items[1] = button("Resume", .{
        .style = .{
            .background = Color.player,
            .color = Color.text,
            .padding = Spacing.symmetric(32, 14),
            .border_radius = 8,
        },
    });

    S.items[2] = button("Main Menu", .{
        .style = .{
            .background = 0xFF7F8C8D,
            .color = Color.text,
            .padding = Spacing.symmetric(24, 12),
            .border_radius = 8,
        },
    });

    return column(.{
        .style = .{ .flex = 1, .gap = 20, .background = 0xDD0A0A1A },
    }, &S.items);
}

fn buildGameOverScreen(state: *const app.GameData) VNode {
    const S = struct {
        var items: [5]VNode = undefined;
        var score_buf: [32]u8 = undefined;
        var wave_buf: [32]u8 = undefined;
    };

    const score_str = std.fmt.bufPrint(&S.score_buf, "Final Score: {d}", .{state.score}) catch "Final Score: 0";
    const wave_str = std.fmt.bufPrint(&S.wave_buf, "Reached Wave {d}", .{state.current_wave}) catch "Wave 1";

    S.items[0] = text("GAME OVER", .{
        .style = .{ .font_size = 48, .font_weight = 700, .color = Color.enemy_bullet },
    });

    S.items[1] = text(score_str, .{
        .style = .{ .font_size = 24, .color = Color.text },
    });

    S.items[2] = text(wave_str, .{
        .style = .{ .font_size = 18, .color = Color.text_muted },
    });

    S.items[3] = button("Try Again", .{
        .style = .{
            .background = Color.player,
            .color = Color.text,
            .padding = Spacing.symmetric(32, 14),
            .border_radius = 8,
        },
    });

    S.items[4] = button("Main Menu", .{
        .style = .{
            .background = 0xFF7F8C8D,
            .color = Color.text,
            .padding = Spacing.symmetric(24, 12),
            .border_radius = 8,
        },
    });

    return column(.{
        .style = .{ .flex = 1, .gap = 20, .background = 0xDD0A0A1A },
    }, &S.items);
}

fn buildVictoryScreen(state: *const app.GameData) VNode {
    const S = struct {
        var items: [4]VNode = undefined;
        var score_buf: [32]u8 = undefined;
    };

    const score_str = std.fmt.bufPrint(&S.score_buf, "Final Score: {d}", .{state.score}) catch "Final Score: 0";

    S.items[0] = text("VICTORY!", .{
        .style = .{ .font_size = 48, .font_weight = 700, .color = 0xFFFFD700 },
    });

    S.items[1] = text(score_str, .{
        .style = .{ .font_size = 24, .color = Color.text },
    });

    S.items[2] = button("Play Again", .{
        .style = .{
            .background = Color.player,
            .color = Color.text,
            .padding = Spacing.symmetric(32, 14),
            .border_radius = 8,
        },
    });

    S.items[3] = button("Main Menu", .{
        .style = .{
            .background = 0xFF7F8C8D,
            .color = Color.text,
            .padding = Spacing.symmetric(24, 12),
            .border_radius = 8,
        },
    });

    return column(.{
        .style = .{ .flex = 1, .gap = 20, .background = 0xDD0A1A0A },
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
