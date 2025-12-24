//! watchOS Companion - Application State

const std = @import("std");

pub const Screen = enum(u8) {
    home = 0,
    workout = 1,
    health = 2,
    settings = 3,

    pub fn title(self: Screen) []const u8 {
        return switch (self) {
            .home => "Watch",
            .workout => "Workout",
            .health => "Health",
            .settings => "Settings",
        };
    }

    pub fn icon(self: Screen) []const u8 {
        return switch (self) {
            .home => "applewatch",
            .workout => "figure.run",
            .health => "heart.fill",
            .settings => "gear",
        };
    }
};

pub const WorkoutType = enum(u8) {
    running = 0,
    walking = 1,
    cycling = 2,
    swimming = 3,
    hiit = 4,

    pub fn name(self: WorkoutType) []const u8 {
        return switch (self) {
            .running => "Running",
            .walking => "Walking",
            .cycling => "Cycling",
            .swimming => "Swimming",
            .hiit => "HIIT",
        };
    }

    pub fn icon(self: WorkoutType) []const u8 {
        return switch (self) {
            .running => "figure.run",
            .walking => "figure.walk",
            .cycling => "bicycle",
            .swimming => "figure.pool.swim",
            .hiit => "bolt.heart.fill",
        };
    }

    pub fn color(self: WorkoutType) u32 {
        return switch (self) {
            .running => 0xFFFF3B30,
            .walking => 0xFF34C759,
            .cycling => 0xFFFF9500,
            .swimming => 0xFF007AFF,
            .hiit => 0xFFAF52DE,
        };
    }
};

pub const WorkoutState = enum(u8) {
    idle = 0,
    active = 1,
    paused = 2,

    pub fn label(self: WorkoutState) []const u8 {
        return switch (self) {
            .idle => "Ready",
            .active => "Active",
            .paused => "Paused",
        };
    }
};

pub const ComplicationFamily = enum(u8) {
    circular_small = 0,
    modular_small = 1,
    modular_large = 2,
    graphic_corner = 3,
    graphic_circular = 4,

    pub fn name(self: ComplicationFamily) []const u8 {
        return switch (self) {
            .circular_small => "Circular Small",
            .modular_small => "Modular Small",
            .modular_large => "Modular Large",
            .graphic_corner => "Graphic Corner",
            .graphic_circular => "Graphic Circular",
        };
    }
};

pub const AppState = struct {
    initialized: bool = false,
    current_screen: Screen = .home,

    // Workout
    workout_state: WorkoutState = .idle,
    current_workout_type: WorkoutType = .running,
    workout_duration: u32 = 0, // seconds
    workout_calories: u32 = 0,
    workout_distance: u32 = 0, // meters

    // Health metrics
    heart_rate: u32 = 0,
    steps_today: u32 = 0,
    calories_today: u32 = 0,
    active_minutes: u32 = 0,

    // Connectivity
    is_phone_connected: bool = false,
    last_sync_time: i64 = 0,
    pending_messages: u32 = 0,

    // Settings
    haptics_enabled: bool = true,
    always_on_display: bool = true,
    water_lock: bool = false,
};

var app_state: AppState = .{};

pub fn init() void {
    app_state = .{ .initialized = true };
    addSampleData();
}

pub fn deinit() void {
    app_state.initialized = false;
}

pub fn getState() *const AppState {
    return &app_state;
}

fn addSampleData() void {
    // Health data
    app_state.heart_rate = 72;
    app_state.steps_today = 5432;
    app_state.calories_today = 245;
    app_state.active_minutes = 32;

    // Connectivity
    app_state.is_phone_connected = true;
    app_state.last_sync_time = 1700000000;
    app_state.pending_messages = 2;
}

// Navigation
pub fn setScreen(screen: Screen) void {
    app_state.current_screen = screen;
}

// Workout
pub fn startWorkout(workout_type: WorkoutType) void {
    app_state.workout_state = .active;
    app_state.current_workout_type = workout_type;
    app_state.workout_duration = 0;
    app_state.workout_calories = 0;
    app_state.workout_distance = 0;
}

pub fn pauseWorkout() void {
    if (app_state.workout_state == .active) {
        app_state.workout_state = .paused;
    }
}

pub fn resumeWorkout() void {
    if (app_state.workout_state == .paused) {
        app_state.workout_state = .active;
    }
}

pub fn endWorkout() void {
    app_state.workout_state = .idle;
    // Add to today's totals
    app_state.calories_today += app_state.workout_calories;
    app_state.active_minutes += app_state.workout_duration / 60;
}

pub fn updateWorkout(duration: u32, calories: u32, distance: u32) void {
    app_state.workout_duration = duration;
    app_state.workout_calories = calories;
    app_state.workout_distance = distance;
}

// Health
pub fn updateHeartRate(rate: u32) void {
    app_state.heart_rate = rate;
}

pub fn addSteps(steps: u32) void {
    app_state.steps_today += steps;
}

// Connectivity
pub fn setPhoneConnected(connected: bool) void {
    app_state.is_phone_connected = connected;
}

pub fn syncWithPhone() void {
    app_state.last_sync_time = 1700000000;
    app_state.pending_messages = 0;
}

// Settings
pub fn setHapticsEnabled(enabled: bool) void {
    app_state.haptics_enabled = enabled;
}

pub fn setAlwaysOnDisplay(enabled: bool) void {
    app_state.always_on_display = enabled;
}

pub fn toggleWaterLock() void {
    app_state.water_lock = !app_state.water_lock;
}

// Tests
test "state init" {
    init();
    defer deinit();
    try std.testing.expect(app_state.initialized);
    try std.testing.expect(app_state.heart_rate > 0);
}

test "workout" {
    init();
    defer deinit();
    startWorkout(.running);
    try std.testing.expectEqual(WorkoutState.active, app_state.workout_state);
    pauseWorkout();
    try std.testing.expectEqual(WorkoutState.paused, app_state.workout_state);
    endWorkout();
    try std.testing.expectEqual(WorkoutState.idle, app_state.workout_state);
}

test "health" {
    init();
    defer deinit();
    const initial_steps = app_state.steps_today;
    addSteps(100);
    try std.testing.expectEqual(initial_steps + 100, app_state.steps_today);
}

test "connectivity" {
    init();
    defer deinit();
    try std.testing.expect(app_state.is_phone_connected);
    setPhoneConnected(false);
    try std.testing.expect(!app_state.is_phone_connected);
}

test "settings" {
    init();
    defer deinit();
    try std.testing.expect(app_state.haptics_enabled);
    setHapticsEnabled(false);
    try std.testing.expect(!app_state.haptics_enabled);
}
