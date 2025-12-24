//! 3D Viewer - Application State

const std = @import("std");

pub const DemoScene = enum(u32) {
    primitives = 0,
    scene_graph = 1,
    materials = 2,
    lighting = 3,

    pub fn title(self: DemoScene) []const u8 {
        return switch (self) {
            .primitives => "Primitives",
            .scene_graph => "Scene Graph",
            .materials => "Materials",
            .lighting => "Lighting",
        };
    }

    pub fn description(self: DemoScene) []const u8 {
        return switch (self) {
            .primitives => "Basic 3D shapes: cube, sphere, cylinder",
            .scene_graph => "Parent-child transformations",
            .materials => "Different material properties",
            .lighting => "Light types and shadows",
        };
    }
};

pub const PrimitiveType = enum(u8) {
    cube,
    sphere,
    cylinder,
    plane,
    cone,
    torus,
};

pub const RenderMode = enum(u8) {
    solid,
    wireframe,
    points,
};

pub const CameraPreset = enum(u8) {
    perspective,
    front,
    top,
    right,
    isometric,
};

pub const Vec3 = struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,
};

pub const Color3 = struct {
    r: f32 = 1,
    g: f32 = 1,
    b: f32 = 1,

    pub const white = Color3{ .r = 1, .g = 1, .b = 1 };
    pub const red = Color3{ .r = 1, .g = 0.3, .b = 0.3 };
    pub const green = Color3{ .r = 0.3, .g = 1, .b = 0.3 };
    pub const blue = Color3{ .r = 0.3, .g = 0.5, .b = 1 };
    pub const yellow = Color3{ .r = 1, .g = 0.9, .b = 0.3 };
    pub const gray = Color3{ .r = 0.5, .g = 0.5, .b = 0.5 };
};

pub const SceneObject = struct {
    name: []const u8,
    primitive: PrimitiveType,
    position: Vec3,
    rotation: Vec3,
    scale: Vec3,
    color: Color3,
    visible: bool = true,
    selected: bool = false,
};

pub const Camera = struct {
    position: Vec3 = .{ .x = 5, .y = 5, .z = 5 },
    target: Vec3 = .{ .x = 0, .y = 0, .z = 0 },
    fov: f32 = 45.0,
    near: f32 = 0.1,
    far: f32 = 1000.0,
    orbit_theta: f32 = 0.785, // 45 degrees
    orbit_phi: f32 = 0.785,
    orbit_radius: f32 = 8.0,
};

pub const Light = struct {
    light_type: LightType,
    position: Vec3,
    color: Color3,
    intensity: f32,
    enabled: bool = true,
};

pub const LightType = enum(u8) {
    ambient,
    directional,
    point,
    spot,
};

pub const AppState = struct {
    initialized: bool = false,
    current_scene: DemoScene = .primitives,

    // Camera
    camera: Camera = .{},
    camera_preset: CameraPreset = .perspective,

    // Rendering
    render_mode: RenderMode = .solid,
    show_grid: bool = true,
    show_axes: bool = true,
    background_color: Color3 = .{ .r = 0.1, .g = 0.1, .b = 0.15 },

    // Scene objects (simplified - max 8 objects)
    objects: [8]SceneObject = undefined,
    object_count: usize = 0,
    selected_index: ?usize = null,

    // Lights
    lights: [4]Light = undefined,
    light_count: usize = 0,

    // UI state
    show_hierarchy: bool = true,
    show_properties: bool = true,
};

var app_state: AppState = .{};

pub fn init() void {
    app_state = .{ .initialized = true };
    setupDefaultScene();
}

pub fn deinit() void {
    app_state.initialized = false;
}

pub fn getState() *const AppState {
    return &app_state;
}

pub fn getStateMut() *AppState {
    return &app_state;
}

fn setupDefaultScene() void {
    // Add default objects
    app_state.objects[0] = .{
        .name = "Cube",
        .primitive = .cube,
        .position = .{ .x = 0, .y = 0, .z = 0 },
        .rotation = .{},
        .scale = .{ .x = 1, .y = 1, .z = 1 },
        .color = Color3.blue,
    };
    app_state.objects[1] = .{
        .name = "Sphere",
        .primitive = .sphere,
        .position = .{ .x = 2.5, .y = 0, .z = 0 },
        .rotation = .{},
        .scale = .{ .x = 1, .y = 1, .z = 1 },
        .color = Color3.red,
    };
    app_state.objects[2] = .{
        .name = "Cylinder",
        .primitive = .cylinder,
        .position = .{ .x = -2.5, .y = 0, .z = 0 },
        .rotation = .{},
        .scale = .{ .x = 1, .y = 1, .z = 1 },
        .color = Color3.green,
    };
    app_state.object_count = 3;

    // Add default light
    app_state.lights[0] = .{
        .light_type = .directional,
        .position = .{ .x = 5, .y = 10, .z = 5 },
        .color = Color3.white,
        .intensity = 1.0,
    };
    app_state.light_count = 1;
}

pub fn selectScene(scene: DemoScene) void {
    app_state.current_scene = scene;
    app_state.selected_index = null;
}

pub fn selectObject(index: ?usize) void {
    // Deselect previous
    if (app_state.selected_index) |prev| {
        if (prev < app_state.object_count) {
            app_state.objects[prev].selected = false;
        }
    }
    // Select new
    app_state.selected_index = index;
    if (index) |idx| {
        if (idx < app_state.object_count) {
            app_state.objects[idx].selected = true;
        }
    }
}

pub fn orbitCamera(delta_theta: f32, delta_phi: f32) void {
    app_state.camera.orbit_theta += delta_theta;
    app_state.camera.orbit_phi = @max(0.1, @min(app_state.camera.orbit_phi + delta_phi, 3.04));
    updateCameraPosition();
}

pub fn zoomCamera(delta: f32) void {
    app_state.camera.orbit_radius = @max(1.0, @min(app_state.camera.orbit_radius + delta, 50.0));
    updateCameraPosition();
}

fn updateCameraPosition() void {
    const theta = app_state.camera.orbit_theta;
    const phi = app_state.camera.orbit_phi;
    const r = app_state.camera.orbit_radius;

    app_state.camera.position.x = r * @sin(phi) * @cos(theta);
    app_state.camera.position.y = r * @cos(phi);
    app_state.camera.position.z = r * @sin(phi) * @sin(theta);
}

pub fn setCameraPreset(preset: CameraPreset) void {
    app_state.camera_preset = preset;
    switch (preset) {
        .perspective => {
            app_state.camera.orbit_theta = 0.785;
            app_state.camera.orbit_phi = 0.785;
        },
        .front => {
            app_state.camera.orbit_theta = 0;
            app_state.camera.orbit_phi = 1.57;
        },
        .top => {
            app_state.camera.orbit_theta = 0;
            app_state.camera.orbit_phi = 0.01;
        },
        .right => {
            app_state.camera.orbit_theta = 1.57;
            app_state.camera.orbit_phi = 1.57;
        },
        .isometric => {
            app_state.camera.orbit_theta = 0.785;
            app_state.camera.orbit_phi = 0.955;
        },
    }
    updateCameraPosition();
}

pub fn setRenderMode(mode: RenderMode) void {
    app_state.render_mode = mode;
}

pub fn toggleGrid() void {
    app_state.show_grid = !app_state.show_grid;
}

pub fn toggleAxes() void {
    app_state.show_axes = !app_state.show_axes;
}

// Tests
test "state init" {
    init();
    defer deinit();
    try std.testing.expect(app_state.initialized);
    try std.testing.expectEqual(@as(usize, 3), app_state.object_count);
}

test "camera orbit" {
    init();
    defer deinit();
    const initial_theta = app_state.camera.orbit_theta;
    orbitCamera(0.1, 0);
    try std.testing.expect(app_state.camera.orbit_theta != initial_theta);
}

test "object selection" {
    init();
    defer deinit();
    selectObject(1);
    try std.testing.expectEqual(@as(?usize, 1), app_state.selected_index);
    try std.testing.expect(app_state.objects[1].selected);
}

test "scene metadata" {
    try std.testing.expectEqualStrings("Primitives", DemoScene.primitives.title());
}
