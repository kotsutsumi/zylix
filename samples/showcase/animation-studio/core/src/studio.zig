//! Animation Studio - UI Components

const std = @import("std");
const app = @import("app.zig");

pub const VNode = struct {
    tag: Tag,
    props: Props = .{},
    children: []const VNode = &.{},
    text: ?[]const u8 = null,
};

pub const Tag = enum { div, row, column, text, button, icon, slider, canvas, spacer };

pub const Props = struct {
    id: ?[]const u8 = null,
    style: ?Style = null,
    active: bool = false,
    disabled: bool = false,
    value: f32 = 0,
};

pub const Style = struct {
    width: ?Size = null,
    height: ?Size = null,
    padding: ?Spacing = null,
    margin: ?Spacing = null,
    background: ?Color = null,
    color: ?Color = null,
    font_size: ?u32 = null,
    font_weight: ?FontWeight = null,
    alignment: ?Alignment = null,
    justify: ?Justify = null,
    border_radius: ?u32 = null,
    border_color: ?Color = null,
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
    pub fn horizontal(v: u32) Spacing {
        return .{ .left = v, .right = v };
    }
};
pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,
    pub const white = Color{ .r = 255, .g = 255, .b = 255 };
    pub const black = Color{ .r = 0, .g = 0, .b = 0 };
    pub const primary = Color{ .r = 99, .g = 102, .b = 241 };
    pub const secondary = Color{ .r = 139, .g = 92, .b = 246 };
    pub const success = Color{ .r = 34, .g = 197, .b = 94 };
    pub const dark = Color{ .r = 30, .g = 30, .b = 46 };
    pub const darker = Color{ .r = 17, .g = 17, .b = 27 };
    pub const gray = Color{ .r = 107, .g = 114, .b = 128 };
    pub const light = Color{ .r = 243, .g = 244, .b = 246 };
};
pub const FontWeight = enum { normal, bold, light };
pub const Alignment = enum { start, center, end, stretch };
pub const Justify = enum { start, center, end, space_between };

// App Builder
pub fn buildApp(state: *const app.AppState) VNode {
    return column(.{ .style = .{ .height = .fill, .background = Color.darker } }, &.{
        buildHeader(state),
        row(.{ .style = .{ .height = .fill } }, &.{
            buildSidebar(state),
            buildMainArea(state),
            buildPropertiesPanel(state),
        }),
        buildTimeline(state),
    });
}

fn buildHeader(state: *const app.AppState) VNode {
    return row(.{
        .style = .{
            .height = .{ .px = 48 },
            .padding = Spacing.horizontal(16),
            .background = Color.dark,
            .alignment = .center,
            .justify = .space_between,
        },
    }, &.{
        row(.{ .style = .{ .gap = 16, .alignment = .center } }, &.{
            icon("film", .{ .style = .{ .color = Color.primary } }),
            text("Animation Studio", .{ .style = .{ .font_size = 16, .font_weight = .bold, .color = Color.white } }),
        }),
        buildPlaybackControls(state),
        row(.{ .style = .{ .gap = 8 } }, &.{
            button("timeline", .{ .id = "toggle-timeline", .active = state.show_timeline }),
            button("properties", .{ .id = "toggle-properties", .active = state.show_properties }),
        }),
    });
}

fn buildPlaybackControls(state: *const app.AppState) VNode {
    const play_icon = if (state.is_playing) "pause.fill" else "play.fill";
    return row(.{ .style = .{ .gap = 8, .alignment = .center } }, &.{
        button("backward.fill", .{ .id = "rewind" }),
        button(play_icon, .{ .id = "play-pause" }),
        button("stop.fill", .{ .id = "stop" }),
        button("forward.fill", .{ .id = "forward" }),
        buildTimeDisplay(state),
        buildSpeedSelector(state),
    });
}

fn buildTimeDisplay(state: *const app.AppState) VNode {
    const S = struct {
        var time_text: [32]u8 = undefined;
    };
    const current_secs = @as(u32, @intFromFloat(state.current_time));
    const total_secs = @as(u32, @intFromFloat(state.duration));
    const len = std.fmt.bufPrint(&S.time_text, "{d:0>2}:{d:0>2} / {d:0>2}:{d:0>2}", .{
        current_secs / 60,
        current_secs % 60,
        total_secs / 60,
        total_secs % 60,
    }) catch &S.time_text;
    return text(len, .{ .style = .{ .font_size = 12, .color = Color.gray } });
}

fn buildSpeedSelector(state: *const app.AppState) VNode {
    const S = struct {
        var speed_text: [8]u8 = undefined;
    };
    const len = std.fmt.bufPrint(&S.speed_text, "{d:.1}x", .{state.playback_speed}) catch &S.speed_text;
    return row(.{
        .style = .{
            .padding = .{ .left = 8, .right = 8, .top = 4, .bottom = 4 },
            .background = Color.dark,
            .border_radius = 4,
        },
    }, &.{
        text(len, .{ .style = .{ .font_size = 12, .color = Color.white } }),
    });
}

fn buildSidebar(state: *const app.AppState) VNode {
    const scenes = [_]app.DemoScene{ .basic, .character, .lottie, .live2d };
    var items: [4]VNode = undefined;
    for (scenes, 0..) |scene, i| {
        items[i] = buildSceneItem(scene, state.current_scene == scene);
    }
    return column(.{
        .style = .{
            .width = .{ .px = 200 },
            .height = .fill,
            .padding = Spacing.all(12),
            .background = Color.dark,
            .gap = 8,
        },
    }, &.{
        text("Demo Scenes", .{ .style = .{ .font_size = 12, .font_weight = .bold, .color = Color.gray } }),
        column(.{ .style = .{ .gap = 4 } }, &items),
    });
}

fn buildSceneItem(scene: app.DemoScene, active: bool) VNode {
    const bg = if (active) Color.primary else Color.dark;
    const txt_color = if (active) Color.white else Color.gray;

    return column(.{
        .id = @tagName(scene),
        .active = active,
        .style = .{
            .padding = Spacing.all(12),
            .background = bg,
            .border_radius = 8,
            .gap = 4,
        },
    }, &.{
        text(scene.title(), .{ .style = .{ .font_size = 14, .font_weight = .bold, .color = txt_color } }),
        text(scene.description(), .{ .style = .{ .font_size = 11, .color = if (active) Color.light else Color.gray } }),
    });
}

fn buildMainArea(state: *const app.AppState) VNode {
    return column(.{
        .style = .{
            .width = .fill,
            .height = .fill,
            .padding = Spacing.all(16),
        },
    }, &.{
        buildCanvas(state),
    });
}

fn buildCanvas(state: *const app.AppState) VNode {
    return switch (state.current_scene) {
        .basic => buildBasicDemo(state),
        .character => buildCharacterDemo(state),
        .lottie => buildLottieDemo(state),
        .live2d => buildLive2DDemo(state),
    };
}

fn buildBasicDemo(state: *const app.AppState) VNode {
    const progress = state.current_time / state.duration;
    return column(.{
        .style = .{
            .width = .fill,
            .height = .fill,
            .background = Color.darker,
            .border_radius = 8,
            .alignment = .center,
            .justify = .center,
            .gap = 24,
        },
    }, &.{
        div(.{
            .style = .{
                .width = .{ .px = 100 },
                .height = .{ .px = 100 },
                .background = Color.primary,
                .border_radius = 16,
            },
            .value = progress,
        }, &.{}),
        text("Basic Transform Animation", .{ .style = .{ .color = Color.gray } }),
    });
}

fn buildCharacterDemo(state: *const app.AppState) VNode {
    return column(.{
        .style = .{
            .width = .fill,
            .height = .fill,
            .background = Color.darker,
            .border_radius = 8,
            .alignment = .center,
            .justify = .center,
            .gap = 16,
        },
    }, &.{
        div(.{
            .style = .{
                .width = .{ .px = 80 },
                .height = .{ .px = 120 },
                .background = Color.secondary,
                .border_radius = 8,
            },
        }, &.{}),
        text(@tagName(state.character_state), .{
            .style = .{ .font_size = 14, .font_weight = .bold, .color = Color.white },
        }),
        row(.{ .style = .{ .gap = 8 } }, &.{
            buildStateButton(.idle, state.character_state == .idle),
            buildStateButton(.walking, state.character_state == .walking),
            buildStateButton(.running, state.character_state == .running),
            buildStateButton(.jumping, state.character_state == .jumping),
        }),
    });
}

fn buildStateButton(state_type: app.AnimationState, active: bool) VNode {
    return button(@tagName(state_type), .{
        .id = @tagName(state_type),
        .active = active,
        .style = .{
            .padding = Spacing.all(8),
            .background = if (active) Color.primary else Color.dark,
            .border_radius = 4,
        },
    });
}

fn buildLottieDemo(state: *const app.AppState) VNode {
    _ = state;
    return column(.{
        .style = .{
            .width = .fill,
            .height = .fill,
            .background = Color.darker,
            .border_radius = 8,
            .alignment = .center,
            .justify = .center,
            .gap = 16,
        },
    }, &.{
        div(.{
            .style = .{
                .width = .{ .px = 200 },
                .height = .{ .px = 200 },
                .background = Color.dark,
                .border_radius = 16,
            },
        }, &.{
            text("Lottie", .{ .style = .{ .font_size = 24, .color = Color.gray } }),
        }),
        text("Lottie Animation Player", .{ .style = .{ .color = Color.gray } }),
    });
}

fn buildLive2DDemo(state: *const app.AppState) VNode {
    const expressions = [_]app.Expression{ .neutral, .happy, .sad, .angry, .surprised };
    var expr_buttons: [5]VNode = undefined;
    for (expressions, 0..) |expr, i| {
        expr_buttons[i] = buildExpressionButton(expr, state.current_expression == expr);
    }

    return column(.{
        .style = .{
            .width = .fill,
            .height = .fill,
            .background = Color.darker,
            .border_radius = 8,
            .alignment = .center,
            .justify = .center,
            .gap = 16,
        },
    }, &.{
        div(.{
            .style = .{
                .width = .{ .px = 200 },
                .height = .{ .px = 280 },
                .background = Color.dark,
                .border_radius = 16,
            },
        }, &.{
            text("Live2D", .{ .style = .{ .font_size = 24, .color = Color.gray } }),
        }),
        row(.{ .style = .{ .gap = 8 } }, &expr_buttons),
    });
}

fn buildExpressionButton(expr: app.Expression, active: bool) VNode {
    return button(@tagName(expr), .{
        .id = @tagName(expr),
        .active = active,
        .style = .{
            .padding = Spacing.all(8),
            .background = if (active) Color.secondary else Color.dark,
            .border_radius = 4,
        },
    });
}

fn buildPropertiesPanel(state: *const app.AppState) VNode {
    if (!state.show_properties) {
        return spacer(0);
    }

    return column(.{
        .style = .{
            .width = .{ .px = 240 },
            .height = .fill,
            .padding = Spacing.all(12),
            .background = Color.dark,
            .gap = 16,
        },
    }, &.{
        text("Properties", .{ .style = .{ .font_size = 12, .font_weight = .bold, .color = Color.gray } }),
        buildEasingSelector(state),
        buildLoopModeSelector(state),
    });
}

fn buildEasingSelector(state: *const app.AppState) VNode {
    return column(.{ .style = .{ .gap = 8 } }, &.{
        text("Easing", .{ .style = .{ .font_size = 11, .color = Color.gray } }),
        text(@tagName(state.easing), .{ .style = .{ .font_size = 14, .color = Color.white } }),
    });
}

fn buildLoopModeSelector(state: *const app.AppState) VNode {
    return column(.{ .style = .{ .gap = 8 } }, &.{
        text("Loop Mode", .{ .style = .{ .font_size = 11, .color = Color.gray } }),
        text(@tagName(state.loop_mode), .{ .style = .{ .font_size = 14, .color = Color.white } }),
    });
}

fn buildTimeline(state: *const app.AppState) VNode {
    if (!state.show_timeline) {
        return spacer(0);
    }

    const progress = state.current_time / state.duration;

    return column(.{
        .style = .{
            .height = .{ .px = 120 },
            .padding = Spacing.all(12),
            .background = Color.dark,
            .gap = 8,
        },
    }, &.{
        text("Timeline", .{ .style = .{ .font_size = 12, .font_weight = .bold, .color = Color.gray } }),
        row(.{ .style = .{ .height = .{ .px = 24 }, .background = Color.darker, .border_radius = 4 } }, &.{
            div(.{
                .style = .{
                    .width = .{ .percent = progress },
                    .height = .fill,
                    .background = Color.primary,
                    .border_radius = 4,
                },
            }, &.{}),
        }),
        row(.{ .style = .{ .height = .{ .px = 40 }, .background = Color.darker, .border_radius = 4 } }, &.{
            text("Keyframes", .{ .style = .{ .font_size = 11, .color = Color.gray } }),
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

pub fn slider(props: Props) VNode {
    return .{ .tag = .slider, .props = props };
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

test "canvas renders demo" {
    const state = app.AppState{ .initialized = true, .current_scene = .character };
    const canvas_view = buildCanvas(&state);
    try std.testing.expectEqual(Tag.column, canvas_view.tag);
}
