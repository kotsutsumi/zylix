//! 3D Viewer - UI Components

const std = @import("std");
const app = @import("app.zig");

pub const VNode = struct {
    tag: Tag,
    props: Props = .{},
    children: []const VNode = &.{},
    text: ?[]const u8 = null,
};

pub const Tag = enum { div, row, column, text, button, icon, canvas3d, spacer };

pub const Props = struct {
    id: ?[]const u8 = null,
    style: ?Style = null,
    active: bool = false,
    selected: bool = false,
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
    pub const primary = Color{ .r = 66, .g = 133, .b = 244 };
    pub const dark = Color{ .r = 30, .g = 30, .b = 40 };
    pub const darker = Color{ .r = 20, .g = 20, .b = 28 };
    pub const gray = Color{ .r = 128, .g = 128, .b = 128 };
    pub const light = Color{ .r = 200, .g = 200, .b = 200 };
};
pub const FontWeight = enum { normal, bold, light };
pub const Alignment = enum { start, center, end, stretch };
pub const Justify = enum { start, center, end, space_between };

// App Builder
pub fn buildApp(state: *const app.AppState) VNode {
    return column(.{ .style = .{ .height = .fill, .background = Color.darker } }, &.{
        buildToolbar(state),
        row(.{ .style = .{ .height = .fill } }, &.{
            buildHierarchyPanel(state),
            buildViewport(state),
            buildPropertiesPanel(state),
        }),
        buildStatusBar(state),
    });
}

fn buildToolbar(state: *const app.AppState) VNode {
    return row(.{
        .style = .{
            .height = .{ .px = 40 },
            .padding = Spacing.horizontal(12),
            .background = Color.dark,
            .alignment = .center,
            .gap = 16,
        },
    }, &.{
        buildSceneSelector(state),
        spacer(1),
        buildRenderModeButtons(state),
        spacer(1),
        buildViewButtons(state),
        spacer(1),
        buildCameraPresets(state),
    });
}

fn buildSceneSelector(state: *const app.AppState) VNode {
    const scenes = [_]app.DemoScene{ .primitives, .scene_graph, .materials, .lighting };
    const S = struct {
        var buttons: [4]VNode = undefined;
    };
    for (scenes, 0..) |scene, i| {
        S.buttons[i] = button(scene.title(), .{
            .id = @tagName(scene),
            .active = state.current_scene == scene,
            .style = .{
                .padding = Spacing.all(6),
                .background = if (state.current_scene == scene) Color.primary else Color.dark,
                .border_radius = 4,
            },
        });
    }
    return row(.{ .style = .{ .gap = 4 } }, &S.buttons);
}

fn buildRenderModeButtons(state: *const app.AppState) VNode {
    return row(.{ .style = .{ .gap = 4 } }, &.{
        button("solid", .{
            .id = "render-solid",
            .active = state.render_mode == .solid,
            .style = .{ .padding = Spacing.all(6), .background = if (state.render_mode == .solid) Color.primary else Color.dark, .border_radius = 4 },
        }),
        button("wireframe", .{
            .id = "render-wireframe",
            .active = state.render_mode == .wireframe,
            .style = .{ .padding = Spacing.all(6), .background = if (state.render_mode == .wireframe) Color.primary else Color.dark, .border_radius = 4 },
        }),
    });
}

fn buildViewButtons(state: *const app.AppState) VNode {
    return row(.{ .style = .{ .gap = 4 } }, &.{
        button("grid", .{
            .id = "toggle-grid",
            .active = state.show_grid,
            .style = .{ .padding = Spacing.all(6), .background = if (state.show_grid) Color.primary else Color.dark, .border_radius = 4 },
        }),
        button("axes", .{
            .id = "toggle-axes",
            .active = state.show_axes,
            .style = .{ .padding = Spacing.all(6), .background = if (state.show_axes) Color.primary else Color.dark, .border_radius = 4 },
        }),
    });
}

fn buildCameraPresets(state: *const app.AppState) VNode {
    const presets = [_]app.CameraPreset{ .perspective, .front, .top, .right };
    const labels = [_][]const u8{ "Persp", "Front", "Top", "Right" };
    const S = struct {
        var buttons: [4]VNode = undefined;
    };
    for (presets, 0..) |preset, i| {
        S.buttons[i] = button(labels[i], .{
            .id = @tagName(preset),
            .active = state.camera_preset == preset,
            .style = .{ .padding = Spacing.all(6), .background = if (state.camera_preset == preset) Color.primary else Color.dark, .border_radius = 4 },
        });
    }
    return row(.{ .style = .{ .gap = 4 } }, &S.buttons);
}

fn buildHierarchyPanel(state: *const app.AppState) VNode {
    if (!state.show_hierarchy) {
        return spacer(0);
    }

    const S = struct {
        var items: [8]VNode = undefined;
    };
    var count: usize = 0;
    for (0..state.object_count) |i| {
        S.items[count] = buildObjectItem(&state.objects[i], i, state.selected_index == i);
        count += 1;
    }

    return column(.{
        .style = .{
            .width = .{ .px = 180 },
            .height = .fill,
            .padding = Spacing.all(8),
            .background = Color.dark,
            .gap = 4,
        },
    }, &.{
        text("Hierarchy", .{ .style = .{ .font_size = 12, .font_weight = .bold, .color = Color.gray } }),
        column(.{ .style = .{ .gap = 2 } }, S.items[0..count]),
    });
}

fn buildObjectItem(obj: *const app.SceneObject, idx: usize, selected: bool) VNode {
    _ = idx;
    return row(.{
        .id = obj.name,
        .selected = selected,
        .style = .{
            .padding = Spacing.all(8),
            .background = if (selected) Color.primary else Color.dark,
            .border_radius = 4,
            .gap = 8,
            .alignment = .center,
        },
    }, &.{
        icon(@tagName(obj.primitive), .{ .style = .{ .color = if (selected) Color.white else Color.gray } }),
        text(obj.name, .{ .style = .{ .font_size = 12, .color = if (selected) Color.white else Color.light } }),
    });
}

fn buildViewport(state: *const app.AppState) VNode {
    _ = state;
    return column(.{
        .style = .{
            .width = .fill,
            .height = .fill,
        },
    }, &.{
        canvas3d(.{ .id = "main-viewport" }),
    });
}

fn buildPropertiesPanel(state: *const app.AppState) VNode {
    if (!state.show_properties) {
        return spacer(0);
    }

    return column(.{
        .style = .{
            .width = .{ .px = 200 },
            .height = .fill,
            .padding = Spacing.all(8),
            .background = Color.dark,
            .gap = 12,
        },
    }, &.{
        text("Properties", .{ .style = .{ .font_size = 12, .font_weight = .bold, .color = Color.gray } }),
        if (state.selected_index) |idx| buildObjectProperties(&state.objects[idx]) else buildNoSelection(),
    });
}

fn buildNoSelection() VNode {
    return text("No object selected", .{ .style = .{ .font_size = 11, .color = Color.gray } });
}

fn buildObjectProperties(obj: *const app.SceneObject) VNode {
    return column(.{ .style = .{ .gap = 12 } }, &.{
        buildPropertySection("Transform", &.{
            buildVec3Property("Position", obj.position),
            buildVec3Property("Rotation", obj.rotation),
            buildVec3Property("Scale", obj.scale),
        }),
        buildPropertySection("Appearance", &.{
            buildProperty("Type", @tagName(obj.primitive)),
            buildProperty("Visible", if (obj.visible) "Yes" else "No"),
        }),
    });
}

fn buildPropertySection(title_text: []const u8, content: []const VNode) VNode {
    return column(.{ .style = .{ .gap = 6 } }, &.{
        text(title_text, .{ .style = .{ .font_size = 11, .font_weight = .bold, .color = Color.gray } }),
        column(.{ .style = .{ .gap = 4 } }, content),
    });
}

fn buildProperty(label: []const u8, value: []const u8) VNode {
    return row(.{ .style = .{ .justify = .space_between } }, &.{
        text(label, .{ .style = .{ .font_size = 11, .color = Color.gray } }),
        text(value, .{ .style = .{ .font_size = 11, .color = Color.white } }),
    });
}

fn buildVec3Property(label: []const u8, vec: app.Vec3) VNode {
    const S = struct {
        var x_buf: [16]u8 = undefined;
        var y_buf: [16]u8 = undefined;
        var z_buf: [16]u8 = undefined;
    };
    const x_str = std.fmt.bufPrint(&S.x_buf, "{d:.1}", .{vec.x}) catch "0";
    const y_str = std.fmt.bufPrint(&S.y_buf, "{d:.1}", .{vec.y}) catch "0";
    const z_str = std.fmt.bufPrint(&S.z_buf, "{d:.1}", .{vec.z}) catch "0";

    return column(.{ .style = .{ .gap = 2 } }, &.{
        text(label, .{ .style = .{ .font_size = 10, .color = Color.gray } }),
        row(.{ .style = .{ .gap = 4 } }, &.{
            text(x_str, .{ .style = .{ .font_size = 11, .color = Color.light } }),
            text(y_str, .{ .style = .{ .font_size = 11, .color = Color.light } }),
            text(z_str, .{ .style = .{ .font_size = 11, .color = Color.light } }),
        }),
    });
}

fn buildStatusBar(state: *const app.AppState) VNode {
    const S = struct {
        var obj_text: [32]u8 = undefined;
    };
    const obj_str = std.fmt.bufPrint(&S.obj_text, "Objects: {d}", .{state.object_count}) catch "Objects: 0";

    return row(.{
        .style = .{
            .height = .{ .px = 24 },
            .padding = Spacing.horizontal(12),
            .background = Color.darker,
            .alignment = .center,
            .justify = .space_between,
        },
    }, &.{
        text(obj_str, .{ .style = .{ .font_size = 11, .color = Color.gray } }),
        text(state.current_scene.description(), .{ .style = .{ .font_size = 11, .color = Color.gray } }),
        text(@tagName(state.render_mode), .{ .style = .{ .font_size = 11, .color = Color.gray } }),
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

pub fn canvas3d(props: Props) VNode {
    return .{ .tag = .canvas3d, .props = props };
}

pub fn spacer(size: u32) VNode {
    return .{ .tag = .spacer, .props = .{ .style = .{ .width = if (size > 0) .{ .px = size } else .fill } } };
}

// Tests
test "build app" {
    const state = app.AppState{ .initialized = true };
    const view = buildApp(&state);
    try std.testing.expectEqual(Tag.column, view.tag);
}

test "toolbar builds" {
    const state = app.AppState{ .initialized = true };
    const toolbar = buildToolbar(&state);
    try std.testing.expectEqual(Tag.row, toolbar.tag);
}
