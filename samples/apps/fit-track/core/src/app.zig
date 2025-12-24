//! Fit Track - Application State

const std = @import("std");

pub const Screen = enum(u8) {
    dashboard = 0,
    workouts = 1,
    progress = 2,
    profile = 3,

    pub fn title(self: Screen) []const u8 {
        return switch (self) {
            .dashboard => "Today",
            .workouts => "Workouts",
            .progress => "Progress",
            .profile => "Profile",
        };
    }
};

pub const WorkoutType = enum(u8) {
    running = 0,
    walking = 1,
    cycling = 2,
    strength = 3,
    yoga = 4,
    swimming = 5,

    pub fn name(self: WorkoutType) []const u8 {
        return switch (self) {
            .running => "Running",
            .walking => "Walking",
            .cycling => "Cycling",
            .strength => "Strength",
            .yoga => "Yoga",
            .swimming => "Swimming",
        };
    }

    pub fn icon(self: WorkoutType) []const u8 {
        return switch (self) {
            .running => "figure.run",
            .walking => "figure.walk",
            .cycling => "bicycle",
            .strength => "dumbbell",
            .yoga => "figure.yoga",
            .swimming => "figure.pool.swim",
        };
    }

    pub fn color(self: WorkoutType) u32 {
        return switch (self) {
            .running => 0xFFFF3B30,
            .walking => 0xFF34C759,
            .cycling => 0xFFFF9500,
            .strength => 0xFF5856D6,
            .yoga => 0xFFAF52DE,
            .swimming => 0xFF007AFF,
        };
    }
};

pub const Workout = struct {
    id: u32 = 0,
    workout_type: WorkoutType = .running,
    duration: u32 = 0, // minutes
    calories: u32 = 0,
    distance: u32 = 0, // meters
    completed_at: i64 = 0,
};

pub const DailyStats = struct {
    steps: u32 = 0,
    calories_burned: u32 = 0,
    active_minutes: u32 = 0,
    distance: u32 = 0, // meters
    workouts_completed: u32 = 0,
};

pub const Goal = struct {
    steps: u32 = 10000,
    calories: u32 = 500,
    active_minutes: u32 = 30,
};

pub const max_workouts = 50;
pub const max_weekly_data = 7;

pub const AppState = struct {
    initialized: bool = false,
    current_screen: Screen = .dashboard,

    // Today's stats
    today: DailyStats = .{},

    // Goals
    goal: Goal = .{},

    // Workout history
    workouts: [max_workouts]Workout = undefined,
    workout_count: usize = 0,
    next_workout_id: u32 = 1,

    // Weekly data
    weekly_steps: [max_weekly_data]u32 = [_]u32{0} ** max_weekly_data,
    current_streak: u32 = 0,

    // Profile
    weight: f32 = 70.0, // kg
    height: u32 = 175, // cm
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
    // Today's progress
    app_state.today.steps = 6543;
    app_state.today.calories_burned = 324;
    app_state.today.active_minutes = 45;
    app_state.today.distance = 4800;

    // Weekly data
    app_state.weekly_steps = .{ 8234, 10521, 7845, 9123, 11234, 6543, 0 };
    app_state.current_streak = 5;

    // Add workouts
    _ = logWorkout(.running, 30, 280, 5000);
    _ = logWorkout(.strength, 45, 220, 0);
    _ = logWorkout(.yoga, 20, 80, 0);
}

// Navigation
pub fn setScreen(screen: Screen) void {
    app_state.current_screen = screen;
}

// Workout operations
pub fn logWorkout(workout_type: WorkoutType, duration: u32, calories: u32, distance: u32) ?u32 {
    if (app_state.workout_count >= max_workouts) return null;

    var w = &app_state.workouts[app_state.workout_count];
    w.id = app_state.next_workout_id;
    w.workout_type = workout_type;
    w.duration = duration;
    w.calories = calories;
    w.distance = distance;
    w.completed_at = 1700000000 + @as(i64, @intCast(app_state.workout_count)) * 3600;

    app_state.next_workout_id += 1;
    app_state.workout_count += 1;

    // Update today's stats
    app_state.today.active_minutes += duration;
    app_state.today.calories_burned += calories;
    app_state.today.distance += distance;
    app_state.today.workouts_completed += 1;

    return w.id;
}

// Daily tracking
pub fn addSteps(steps: u32) void {
    app_state.today.steps += steps;
}

pub fn setStepGoal(steps: u32) void {
    app_state.goal.steps = steps;
}

pub fn setCalorieGoal(calories: u32) void {
    app_state.goal.calories = calories;
}

pub fn setActiveMinutesGoal(minutes: u32) void {
    app_state.goal.active_minutes = minutes;
}

// Progress calculations
pub fn getStepProgress() f32 {
    if (app_state.goal.steps == 0) return 0;
    const progress = @as(f32, @floatFromInt(app_state.today.steps)) / @as(f32, @floatFromInt(app_state.goal.steps));
    return @min(1.0, progress);
}

pub fn getCalorieProgress() f32 {
    if (app_state.goal.calories == 0) return 0;
    const progress = @as(f32, @floatFromInt(app_state.today.calories_burned)) / @as(f32, @floatFromInt(app_state.goal.calories));
    return @min(1.0, progress);
}

pub fn getActiveMinutesProgress() f32 {
    if (app_state.goal.active_minutes == 0) return 0;
    const progress = @as(f32, @floatFromInt(app_state.today.active_minutes)) / @as(f32, @floatFromInt(app_state.goal.active_minutes));
    return @min(1.0, progress);
}

pub fn getWeeklyAverage() u32 {
    var sum: u32 = 0;
    var days: u32 = 0;
    for (app_state.weekly_steps) |steps| {
        if (steps > 0) {
            sum += steps;
            days += 1;
        }
    }
    if (days == 0) return 0;
    return sum / days;
}

// Tests
test "state init" {
    init();
    defer deinit();
    try std.testing.expect(app_state.initialized);
    try std.testing.expect(app_state.today.steps > 0);
}

test "log workout" {
    init();
    defer deinit();
    const initial = app_state.workout_count;
    const id = logWorkout(.running, 30, 300, 5000);
    try std.testing.expect(id != null);
    try std.testing.expectEqual(initial + 1, app_state.workout_count);
}

test "add steps" {
    init();
    defer deinit();
    const initial = app_state.today.steps;
    addSteps(1000);
    try std.testing.expectEqual(initial + 1000, app_state.today.steps);
}

test "step progress" {
    init();
    defer deinit();
    app_state.goal.steps = 10000;
    app_state.today.steps = 5000;
    try std.testing.expectEqual(@as(f32, 0.5), getStepProgress());
}

test "weekly average" {
    init();
    defer deinit();
    const avg = getWeeklyAverage();
    try std.testing.expect(avg > 0);
}
