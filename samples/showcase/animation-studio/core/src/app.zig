//! Animation Studio - Application State

const std = @import("std");

pub const DemoScene = enum(u32) {
    basic = 0,
    character = 1,
    lottie = 2,
    live2d = 3,

    pub fn title(self: DemoScene) []const u8 {
        return switch (self) {
            .basic => "Basic Animations",
            .character => "Character Controller",
            .lottie => "Lottie Player",
            .live2d => "Live2D Viewer",
        };
    }

    pub fn description(self: DemoScene) []const u8 {
        return switch (self) {
            .basic => "Transform, opacity, and color animations",
            .character => "State machine with idle/walk/run/jump",
            .lottie => "Playback of Lottie JSON animations",
            .live2d => "Interactive character with expressions",
        };
    }
};

pub const EasingType = enum(u8) {
    linear,
    ease_in,
    ease_out,
    ease_in_out,
    bounce,
    elastic,
    spring,
};

pub const LoopMode = enum(u8) {
    none,
    loop,
    pingpong,
};

pub const AnimationState = enum(u8) {
    idle,
    walking,
    running,
    jumping,
    falling,
};

pub const Expression = enum(u8) {
    neutral,
    happy,
    sad,
    angry,
    surprised,
};

pub const AppState = struct {
    initialized: bool = false,
    current_scene: DemoScene = .basic,

    // Playback state
    is_playing: bool = false,
    current_time: f32 = 0,
    playback_speed: f32 = 1.0,
    duration: f32 = 2.0,

    // Basic animation settings
    easing: EasingType = .ease_in_out,
    loop_mode: LoopMode = .loop,

    // Character controller state
    character_state: AnimationState = .idle,
    character_x: f32 = 0,
    character_y: f32 = 0,
    is_grounded: bool = true,

    // Live2D state
    current_expression: Expression = .neutral,
    head_angle_x: f32 = 0,
    head_angle_y: f32 = 0,
    body_angle: f32 = 0,

    // UI state
    show_timeline: bool = true,
    show_properties: bool = true,
    selected_keyframe: ?usize = null,
};

var app_state: AppState = .{};

pub fn init() void {
    app_state = .{ .initialized = true };
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

pub fn selectScene(scene: DemoScene) void {
    app_state.current_scene = scene;
    app_state.current_time = 0;
    app_state.is_playing = false;
}

pub fn play() void {
    app_state.is_playing = true;
}

pub fn pause() void {
    app_state.is_playing = false;
}

pub fn stop() void {
    app_state.is_playing = false;
    app_state.current_time = 0;
}

pub fn seek(time: f32) void {
    app_state.current_time = @max(0, @min(time, app_state.duration));
}

pub fn setSpeed(speed: f32) void {
    app_state.playback_speed = @max(0.1, @min(speed, 4.0));
}

pub fn setEasing(easing: EasingType) void {
    app_state.easing = easing;
}

pub fn setLoopMode(mode: LoopMode) void {
    app_state.loop_mode = mode;
}

pub fn setCharacterState(state: AnimationState) void {
    app_state.character_state = state;
}

pub fn setExpression(expr: Expression) void {
    app_state.current_expression = expr;
}

pub fn update(delta_time: f32) void {
    if (!app_state.is_playing) return;

    app_state.current_time += delta_time * app_state.playback_speed;

    switch (app_state.loop_mode) {
        .none => {
            if (app_state.current_time >= app_state.duration) {
                app_state.current_time = app_state.duration;
                app_state.is_playing = false;
            }
        },
        .loop => {
            if (app_state.current_time >= app_state.duration) {
                app_state.current_time = @mod(app_state.current_time, app_state.duration);
            }
        },
        .pingpong => {
            const cycle = @mod(app_state.current_time, app_state.duration * 2);
            if (cycle > app_state.duration) {
                app_state.current_time = app_state.duration * 2 - cycle;
            }
        },
    }
}

// Tests
test "state init" {
    init();
    defer deinit();
    try std.testing.expect(app_state.initialized);
    try std.testing.expectEqual(DemoScene.basic, app_state.current_scene);
}

test "playback controls" {
    init();
    defer deinit();
    try std.testing.expect(!app_state.is_playing);
    play();
    try std.testing.expect(app_state.is_playing);
    pause();
    try std.testing.expect(!app_state.is_playing);
}

test "seek bounds" {
    init();
    defer deinit();
    seek(5.0);
    try std.testing.expectEqual(@as(f32, 2.0), app_state.current_time);
    seek(-1.0);
    try std.testing.expectEqual(@as(f32, 0.0), app_state.current_time);
}

test "scene metadata" {
    try std.testing.expectEqualStrings("Basic Animations", DemoScene.basic.title());
}
