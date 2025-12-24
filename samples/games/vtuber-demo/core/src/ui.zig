//! VTuber Demo - UI Components

const std = @import("std");
const app = @import("app.zig");

pub const Tag = enum { column, row, div, text, button, canvas, circle, ellipse };

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
    rotation: f32 = 0,
    scale: f32 = 1,
    opacity: f32 = 1,
};

pub const Color = struct {
    pub const text: u32 = 0xFFFFFFFF;
    pub const text_muted: u32 = 0xFFB0B0B0;
    pub const skin: u32 = 0xFFFAD4C0;
    pub const hair: u32 = 0xFF2D2D44;
    pub const eye_white: u32 = 0xFFFFFFFF;
    pub const eye_iris: u32 = 0xFF6B5B95;
    pub const eye_pupil: u32 = 0xFF2D2D44;
    pub const blush: u32 = 0x66FF6B6B;
    pub const mouth: u32 = 0xFFE56B6B;
    pub const clothes: u32 = 0xFF4A90D9;
    pub const button_bg: u32 = 0xFF3D3D5C;
    pub const button_active: u32 = 0xFF5B5B8A;
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
fn circle(props: Props) VNode {
    return .{ .tag = .circle, .props = props, .children = &.{} };
}

pub fn buildApp(state: *const app.AppState) VNode {
    const S = struct {
        var content: [1]VNode = undefined;
    };

    S.content[0] = buildContent(state);

    return column(.{
        .style = .{ .background = state.background.color(), .width = 800, .height = 600 },
    }, &S.content);
}

fn buildContent(state: *const app.AppState) VNode {
    const S = struct {
        var items: [2]VNode = undefined;
    };

    S.items[0] = buildCharacter(state);
    S.items[1] = buildControls(state);

    return row(.{
        .style = .{ .flex = 1 },
    }, &S.items);
}

fn buildCharacter(state: *const app.AppState) VNode {
    const S = struct {
        var parts: [12]VNode = undefined;
    };

    const char = &state.character;
    const center_x: f32 = 300;
    const center_y: f32 = 280;
    const body_y = center_y + char.body_sway;

    var idx: usize = 0;

    // Body
    S.parts[idx] = div(.{
        .style = .{
            .background = Color.clothes,
            .x = center_x - 60,
            .y = body_y + 80,
            .width = 120,
            .height = 200,
            .border_radius = 30,
        },
    }, &.{});
    idx += 1;

    // Neck
    S.parts[idx] = div(.{
        .style = .{
            .background = Color.skin,
            .x = center_x - 20,
            .y = body_y + 50,
            .width = 40,
            .height = 50,
        },
    }, &.{});
    idx += 1;

    // Head
    const head_x = center_x + char.head_rotation.y * 0.5;
    const head_y = body_y + char.head_position.y;

    S.parts[idx] = div(.{
        .style = .{
            .background = Color.skin,
            .x = head_x - 70,
            .y = head_y - 60,
            .width = 140,
            .height = 150,
            .border_radius = 70,
        },
    }, &.{});
    idx += 1;

    // Hair back
    S.parts[idx] = div(.{
        .style = .{
            .background = Color.hair,
            .x = head_x - 80 + char.hair_offset * 0.3,
            .y = head_y - 70,
            .width = 160,
            .height = 200,
            .border_radius = 60,
            .opacity = 0.9,
        },
    }, &.{});
    idx += 1;

    // Hair front
    S.parts[idx] = div(.{
        .style = .{
            .background = Color.hair,
            .x = head_x - 75 + char.hair_offset * 0.2,
            .y = head_y - 75,
            .width = 150,
            .height = 60,
            .border_radius = 30,
        },
    }, &.{});
    idx += 1;

    // Eyes
    const eye_y = head_y + 10 + char.head_rotation.x * 0.3;
    const eye_scale = char.expression.eyeScale();
    const blink_scale: f32 = if (char.is_blinking) 0.1 else 1.0;

    // Left eye
    S.parts[idx] = buildEye(head_x - 30 + char.eye_position.x * 5, eye_y + char.eye_position.y * 3, eye_scale * blink_scale, char.expression == .wink);
    idx += 1;

    // Right eye
    S.parts[idx] = buildEye(head_x + 30 + char.eye_position.x * 5, eye_y + char.eye_position.y * 3, eye_scale * blink_scale, false);
    idx += 1;

    // Mouth
    const mouth_height: f32 = 5 + char.mouth_open * 15;
    S.parts[idx] = div(.{
        .style = .{
            .background = Color.mouth,
            .x = head_x - 10,
            .y = head_y + 50,
            .width = 20,
            .height = mouth_height,
            .border_radius = 10,
        },
    }, &.{});
    idx += 1;

    // Blush
    if (char.blush_amount > 0) {
        S.parts[idx] = circle(.{
            .style = .{
                .background = Color.blush,
                .x = head_x - 50,
                .y = head_y + 30,
                .width = 25,
                .height = 15,
                .opacity = char.blush_amount,
            },
        });
        idx += 1;

        S.parts[idx] = circle(.{
            .style = .{
                .background = Color.blush,
                .x = head_x + 25,
                .y = head_y + 30,
                .width = 25,
                .height = 15,
                .opacity = char.blush_amount,
            },
        });
        idx += 1;
    }

    // Accessories
    if (char.accessories[0]) { // Glasses
        S.parts[idx] = div(.{
            .style = .{
                .background = 0xFF333333,
                .x = head_x - 55,
                .y = eye_y - 10,
                .width = 110,
                .height = 30,
                .border_radius = 15,
                .opacity = 0.8,
            },
        }, &.{});
        idx += 1;
    }

    if (char.accessories[1]) { // Cat ears
        S.parts[idx] = buildCatEars(head_x, head_y - 80);
        idx += 1;
    }

    return div(.{
        .style = .{ .flex = 1 },
    }, S.parts[0..idx]);
}

fn buildEye(x: f32, y: f32, scale: f32, is_wink: bool) VNode {
    const S = struct {
        var parts: [3]VNode = undefined;
    };

    if (is_wink) {
        // Closed eye line
        S.parts[0] = div(.{
            .style = .{
                .background = Color.eye_pupil,
                .x = x - 15,
                .y = y,
                .width = 30,
                .height = 3,
                .border_radius = 2,
            },
        }, &.{});
        return S.parts[0];
    }

    const eye_height = 20 * scale;

    // White
    S.parts[0] = div(.{
        .style = .{
            .background = Color.eye_white,
            .x = x - 15,
            .y = y - eye_height / 2,
            .width = 30,
            .height = eye_height,
            .border_radius = 15,
        },
    }, &.{});

    // Iris
    S.parts[1] = circle(.{
        .style = .{
            .background = Color.eye_iris,
            .x = x - 8,
            .y = y - 8 * scale,
            .width = 16,
            .height = 16 * scale,
        },
    });

    // Pupil
    S.parts[2] = circle(.{
        .style = .{
            .background = Color.eye_pupil,
            .x = x - 4,
            .y = y - 4 * scale,
            .width = 8,
            .height = 8 * scale,
        },
    });

    return div(.{}, &S.parts);
}

fn buildCatEars(x: f32, y: f32) VNode {
    const S = struct {
        var ears: [2]VNode = undefined;
    };

    S.ears[0] = div(.{
        .style = .{
            .background = Color.hair,
            .x = x - 60,
            .y = y,
            .width = 40,
            .height = 50,
            .border_radius = 5,
            .rotation = -20,
        },
    }, &.{});

    S.ears[1] = div(.{
        .style = .{
            .background = Color.hair,
            .x = x + 20,
            .y = y,
            .width = 40,
            .height = 50,
            .border_radius = 5,
            .rotation = 20,
        },
    }, &.{});

    return div(.{}, &S.ears);
}

fn buildControls(state: *const app.AppState) VNode {
    const S = struct {
        var items: [5]VNode = undefined;
    };

    // Expression buttons
    S.items[0] = column(.{ .style = .{ .gap = 8 } }, &.{
        text("Expression", .{ .style = .{ .font_size = 14, .font_weight = 600, .color = Color.text } }),
        row(.{ .style = .{ .gap = 4 } }, &.{
            buildExpressionButton(.neutral, state.character.expression),
            buildExpressionButton(.happy, state.character.expression),
            buildExpressionButton(.surprised, state.character.expression),
        }),
        row(.{ .style = .{ .gap = 4 } }, &.{
            buildExpressionButton(.sad, state.character.expression),
            buildExpressionButton(.angry, state.character.expression),
            buildExpressionButton(.wink, state.character.expression),
        }),
    });

    // Motion buttons
    S.items[1] = column(.{ .style = .{ .gap = 8 } }, &.{
        text("Motion", .{ .style = .{ .font_size = 14, .font_weight = 600, .color = Color.text } }),
        row(.{ .style = .{ .gap = 4 } }, &.{
            buildMotionButton(.wave),
            buildMotionButton(.nod),
        }),
        row(.{ .style = .{ .gap = 4 } }, &.{
            buildMotionButton(.shake),
            buildMotionButton(.excited),
        }),
    });

    // Accessories
    S.items[2] = column(.{ .style = .{ .gap = 8 } }, &.{
        text("Accessories", .{ .style = .{ .font_size = 14, .font_weight = 600, .color = Color.text } }),
        row(.{ .style = .{ .gap = 4 } }, &.{
            buildAccessoryButton(.glasses, state.character.accessories[0]),
            buildAccessoryButton(.cat_ears, state.character.accessories[1]),
        }),
        row(.{ .style = .{ .gap = 4 } }, &.{
            buildAccessoryButton(.ribbon, state.character.accessories[2]),
            buildAccessoryButton(.headphones, state.character.accessories[3]),
        }),
    });

    // Background
    S.items[3] = column(.{ .style = .{ .gap = 8 } }, &.{
        text("Background", .{ .style = .{ .font_size = 14, .font_weight = 600, .color = Color.text } }),
        row(.{ .style = .{ .gap = 4 } }, &.{
            buildBackgroundButton(.studio, state.background),
            buildBackgroundButton(.room, state.background),
        }),
        row(.{ .style = .{ .gap = 4 } }, &.{
            buildBackgroundButton(.outdoor, state.background),
            buildBackgroundButton(.space, state.background),
        }),
    });

    // Instructions
    S.items[4] = text("Click character to interact!", .{
        .style = .{ .font_size = 12, .color = Color.text_muted },
    });

    return column(.{
        .style = .{
            .width = 180,
            .padding = Spacing.all(16),
            .gap = 20,
            .background = 0x44000000,
        },
    }, &S.items);
}

fn buildExpressionButton(expr: app.Expression, current: app.Expression) VNode {
    const is_active = expr == current;
    return button(expr.name(), .{
        .style = .{
            .background = if (is_active) Color.button_active else Color.button_bg,
            .color = Color.text,
            .padding = Spacing.symmetric(8, 6),
            .border_radius = 4,
            .font_size = 11,
        },
    });
}

fn buildMotionButton(motion: app.Motion) VNode {
    return button(motion.name(), .{
        .style = .{
            .background = Color.button_bg,
            .color = Color.text,
            .padding = Spacing.symmetric(8, 6),
            .border_radius = 4,
            .font_size = 11,
        },
    });
}

fn buildAccessoryButton(acc: app.Accessory, is_active: bool) VNode {
    return button(acc.name(), .{
        .style = .{
            .background = if (is_active) Color.button_active else Color.button_bg,
            .color = Color.text,
            .padding = Spacing.symmetric(8, 6),
            .border_radius = 4,
            .font_size = 11,
        },
    });
}

fn buildBackgroundButton(bg: app.Background, current: app.Background) VNode {
    const is_active = bg == current;
    return button(bg.name(), .{
        .style = .{
            .background = if (is_active) Color.button_active else Color.button_bg,
            .color = Color.text,
            .padding = Spacing.symmetric(8, 6),
            .border_radius = 4,
            .font_size = 11,
        },
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
