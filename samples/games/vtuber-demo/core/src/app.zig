//! VTuber Demo - Character State

const std = @import("std");

pub const Expression = enum(u8) {
    neutral = 0,
    happy = 1,
    surprised = 2,
    sad = 3,
    angry = 4,
    wink = 5,

    pub fn name(self: Expression) []const u8 {
        return switch (self) {
            .neutral => "Neutral",
            .happy => "Happy",
            .surprised => "Surprised",
            .sad => "Sad",
            .angry => "Angry",
            .wink => "Wink",
        };
    }

    pub fn eyeScale(self: Expression) f32 {
        return switch (self) {
            .neutral => 1.0,
            .happy => 0.6,
            .surprised => 1.4,
            .sad => 0.8,
            .angry => 0.7,
            .wink => 1.0,
        };
    }
};

pub const Motion = enum(u8) {
    idle = 0,
    wave = 1,
    nod = 2,
    shake = 3,
    excited = 4,

    pub fn name(self: Motion) []const u8 {
        return switch (self) {
            .idle => "Idle",
            .wave => "Wave",
            .nod => "Nod",
            .shake => "Shake Head",
            .excited => "Excited",
        };
    }

    pub fn duration(self: Motion) f32 {
        return switch (self) {
            .idle => 0,
            .wave => 1.5,
            .nod => 1.0,
            .shake => 1.2,
            .excited => 2.0,
        };
    }
};

pub const Accessory = enum(u8) {
    glasses = 0,
    cat_ears = 1,
    ribbon = 2,
    headphones = 3,

    pub fn name(self: Accessory) []const u8 {
        return switch (self) {
            .glasses => "Glasses",
            .cat_ears => "Cat Ears",
            .ribbon => "Ribbon",
            .headphones => "Headphones",
        };
    }
};

pub const Background = enum(u8) {
    studio = 0,
    room = 1,
    outdoor = 2,
    space = 3,

    pub fn name(self: Background) []const u8 {
        return switch (self) {
            .studio => "Studio",
            .room => "Room",
            .outdoor => "Outdoor",
            .space => "Space",
        };
    }

    pub fn color(self: Background) u32 {
        return switch (self) {
            .studio => 0xFF1A1A2E,
            .room => 0xFF2D3436,
            .outdoor => 0xFF74B9FF,
            .space => 0xFF0C0C1E,
        };
    }
};

pub const Vec2 = struct {
    x: f32 = 0,
    y: f32 = 0,

    pub fn lerp(self: Vec2, target: Vec2, t: f32) Vec2 {
        return .{
            .x = self.x + (target.x - self.x) * t,
            .y = self.y + (target.y - self.y) * t,
        };
    }
};

pub const CharacterState = struct {
    // Position and rotation
    head_position: Vec2 = .{},
    head_rotation: Vec2 = .{}, // tilt x, turn y
    body_sway: f32 = 0,

    // Eyes
    eye_position: Vec2 = .{}, // -1 to 1 for look direction
    eye_target: Vec2 = .{},
    blink_timer: f32 = 0,
    is_blinking: bool = false,

    // Mouth
    mouth_open: f32 = 0, // 0 = closed, 1 = open
    mouth_target: f32 = 0,

    // Expression and motion
    expression: Expression = .neutral,
    current_motion: Motion = .idle,
    motion_timer: f32 = 0,
    motion_progress: f32 = 0,

    // Accessories
    accessories: [4]bool = [_]bool{ false, false, false, false },

    // Physics
    hair_offset: f32 = 0,
    hair_velocity: f32 = 0,

    // Blush
    blush_amount: f32 = 0,
};

pub const AppState = struct {
    initialized: bool = false,
    character: CharacterState = .{},
    background: Background = .studio,
    time_elapsed: f32 = 0,
    breathing_phase: f32 = 0,
    touch_reaction_timer: f32 = 0,
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

pub fn update(delta: f32) void {
    app_state.time_elapsed += delta;

    updateBreathing(delta);
    updateEyes(delta);
    updateMouth(delta);
    updateMotion(delta);
    updatePhysics(delta);
    updateTouchReaction(delta);
}

fn updateBreathing(delta: f32) void {
    app_state.breathing_phase += delta * 0.8;
    if (app_state.breathing_phase > std.math.tau) {
        app_state.breathing_phase -= std.math.tau;
    }

    // Subtle body sway
    app_state.character.body_sway = @sin(app_state.breathing_phase) * 2.0;
}

fn updateEyes(delta: f32) void {
    var char = &app_state.character;

    // Smooth eye movement
    char.eye_position = char.eye_position.lerp(char.eye_target, delta * 8.0);

    // Blinking
    char.blink_timer -= delta;
    if (char.blink_timer <= 0) {
        if (char.is_blinking) {
            char.is_blinking = false;
            char.blink_timer = 2.0 + @as(f32, @floatFromInt(@as(u32, @intFromFloat(app_state.time_elapsed)) % 3)) * 1.5;
        } else {
            char.is_blinking = true;
            char.blink_timer = 0.15;
        }
    }
}

fn updateMouth(delta: f32) void {
    var char = &app_state.character;

    // Smooth mouth movement
    const diff = char.mouth_target - char.mouth_open;
    char.mouth_open += diff * delta * 12.0;
}

fn updateMotion(delta: f32) void {
    var char = &app_state.character;

    if (char.current_motion == .idle) return;

    char.motion_timer += delta;
    const duration = char.current_motion.duration();

    if (char.motion_timer >= duration) {
        char.current_motion = .idle;
        char.motion_timer = 0;
        char.motion_progress = 0;
        return;
    }

    char.motion_progress = char.motion_timer / duration;

    // Apply motion effects
    const progress = char.motion_progress;
    const wave = @sin(progress * std.math.pi);

    switch (char.current_motion) {
        .wave => {
            char.head_rotation.y = wave * 10;
        },
        .nod => {
            char.head_rotation.x = wave * 15;
        },
        .shake => {
            char.head_rotation.y = @sin(progress * std.math.pi * 4) * 12;
        },
        .excited => {
            char.head_position.y = @abs(@sin(progress * std.math.pi * 6)) * 10;
            char.blush_amount = wave * 0.5;
        },
        .idle => {},
    }
}

fn updatePhysics(delta: f32) void {
    var char = &app_state.character;

    // Hair physics (simple spring)
    const target = char.head_rotation.y * 0.5 + char.body_sway * 0.3;
    const spring_force = (target - char.hair_offset) * 50;
    const damping = char.hair_velocity * 5;

    char.hair_velocity += (spring_force - damping) * delta;
    char.hair_offset += char.hair_velocity * delta;
}

fn updateTouchReaction(delta: f32) void {
    if (app_state.touch_reaction_timer > 0) {
        app_state.touch_reaction_timer -= delta;

        if (app_state.touch_reaction_timer <= 0) {
            app_state.character.expression = .neutral;
            app_state.character.blush_amount = 0;
        }
    }
}

// Expression
pub fn setExpression(expr: Expression) void {
    app_state.character.expression = expr;
}

// Eyes
pub fn setEyePosition(x: f32, y: f32) void {
    app_state.character.eye_target = .{
        .x = std.math.clamp(x, -1.0, 1.0),
        .y = std.math.clamp(y, -1.0, 1.0),
    };
}

// Mouth
pub fn setMouthOpen(amount: f32) void {
    app_state.character.mouth_target = std.math.clamp(amount, 0.0, 1.0);
}

// Head
pub fn setHeadRotation(x: f32, y: f32) void {
    app_state.character.head_rotation = .{
        .x = std.math.clamp(x, -30.0, 30.0),
        .y = std.math.clamp(y, -30.0, 30.0),
    };
}

// Motion
pub fn playMotion(motion: Motion) void {
    if (app_state.character.current_motion != .idle) return;

    app_state.character.current_motion = motion;
    app_state.character.motion_timer = 0;
    app_state.character.motion_progress = 0;
}

// Accessories
pub fn toggleAccessory(id: usize) void {
    if (id < 4) {
        app_state.character.accessories[id] = !app_state.character.accessories[id];
    }
}

pub fn setAccessory(id: usize, enabled: bool) void {
    if (id < 4) {
        app_state.character.accessories[id] = enabled;
    }
}

// Background
pub fn setBackground(bg: Background) void {
    app_state.background = bg;
}

// Interaction
pub fn onTouch(x: f32, y: f32) void {
    _ = x;
    _ = y;

    // React to touch
    app_state.character.expression = .surprised;
    app_state.character.blush_amount = 0.7;
    app_state.touch_reaction_timer = 1.5;

    // Play reaction motion
    if (app_state.character.current_motion == .idle) {
        playMotion(.excited);
    }
}

// Tests
test "app init" {
    init();
    defer deinit();
    try std.testing.expect(app_state.initialized);
}

test "expression change" {
    init();
    defer deinit();
    setExpression(.happy);
    try std.testing.expectEqual(Expression.happy, app_state.character.expression);
}

test "eye tracking" {
    init();
    defer deinit();
    setEyePosition(0.5, -0.3);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), app_state.character.eye_target.x, 0.01);
}

test "motion playback" {
    init();
    defer deinit();
    playMotion(.wave);
    try std.testing.expectEqual(Motion.wave, app_state.character.current_motion);
}

test "accessory toggle" {
    init();
    defer deinit();
    try std.testing.expect(!app_state.character.accessories[0]);
    toggleAccessory(0);
    try std.testing.expect(app_state.character.accessories[0]);
}

test "background change" {
    init();
    defer deinit();
    setBackground(.room);
    try std.testing.expectEqual(Background.room, app_state.background);
}

test "update" {
    init();
    defer deinit();
    update(0.016);
    try std.testing.expect(app_state.time_elapsed > 0);
}
