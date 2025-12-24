//! 3D Viewer Showcase
//!
//! Demonstration of Zylix 3D graphics rendering capabilities.

const std = @import("std");
const app = @import("app.zig");
const viewer = @import("viewer.zig");

pub const AppState = app.AppState;
pub const DemoScene = app.DemoScene;
pub const PrimitiveType = app.PrimitiveType;
pub const RenderMode = app.RenderMode;
pub const CameraPreset = app.CameraPreset;
pub const Vec3 = app.Vec3;
pub const VNode = viewer.VNode;

pub fn init() void {
    app.init();
}

pub fn deinit() void {
    app.deinit();
}

pub fn getState() *const AppState {
    return app.getState();
}

pub fn render() VNode {
    return viewer.buildApp(app.getState());
}

// C ABI Exports
export fn app_init() void {
    init();
}

export fn app_deinit() void {
    deinit();
}

export fn app_select_scene(scene: u32) void {
    const max_scene = @typeInfo(DemoScene).@"enum".fields.len;
    if (scene >= max_scene) return;
    app.selectScene(@enumFromInt(scene));
}

export fn app_select_object(index: i32) void {
    if (index < 0) {
        app.selectObject(null);
    } else {
        const idx: usize = @intCast(index);
        if (idx < app.getState().object_count) {
            app.selectObject(idx);
        }
    }
}

export fn app_orbit_camera(delta_theta: f32, delta_phi: f32) void {
    app.orbitCamera(delta_theta, delta_phi);
}

export fn app_zoom_camera(delta: f32) void {
    app.zoomCamera(delta);
}

export fn app_set_camera_preset(preset: u8) void {
    const max_preset = @typeInfo(CameraPreset).@"enum".fields.len;
    if (preset >= max_preset) return;
    app.setCameraPreset(@enumFromInt(preset));
}

export fn app_set_render_mode(mode: u8) void {
    const max_mode = @typeInfo(RenderMode).@"enum".fields.len;
    if (mode >= max_mode) return;
    app.setRenderMode(@enumFromInt(mode));
}

export fn app_toggle_grid() void {
    app.toggleGrid();
}

export fn app_toggle_axes() void {
    app.toggleAxes();
}

export fn app_get_camera_position_x() f32 {
    return app.getState().camera.position.x;
}

export fn app_get_camera_position_y() f32 {
    return app.getState().camera.position.y;
}

export fn app_get_camera_position_z() f32 {
    return app.getState().camera.position.z;
}

export fn app_get_object_count() u32 {
    return @intCast(app.getState().object_count);
}

// Tests
test "initialization" {
    init();
    defer deinit();
    try std.testing.expect(getState().initialized);
    try std.testing.expectEqual(@as(usize, 3), getState().object_count);
}

test "scene selection" {
    init();
    defer deinit();
    app.selectScene(.materials);
    try std.testing.expectEqual(DemoScene.materials, getState().current_scene);
}

test "camera controls" {
    init();
    defer deinit();
    const initial_x = getState().camera.position.x;
    app.orbitCamera(0.5, 0);
    try std.testing.expect(getState().camera.position.x != initial_x);
}

test "render" {
    init();
    defer deinit();
    const view = render();
    try std.testing.expectEqual(viewer.Tag.column, view.tag);
}
