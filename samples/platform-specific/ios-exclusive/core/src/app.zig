//! iOS Exclusive - Application State

const std = @import("std");

pub const Screen = enum(u8) {
    home = 0,
    biometrics = 1,
    haptics = 2,
    health = 3,
    siri = 4,

    pub fn title(self: Screen) []const u8 {
        return switch (self) {
            .home => "iOS Features",
            .biometrics => "Biometrics",
            .haptics => "Haptics",
            .health => "HealthKit",
            .siri => "Siri",
        };
    }

    pub fn icon(self: Screen) []const u8 {
        return switch (self) {
            .home => "apple.logo",
            .biometrics => "faceid",
            .haptics => "hand.tap",
            .health => "heart.fill",
            .siri => "waveform",
        };
    }
};

pub const BiometricType = enum(u8) {
    none = 0,
    touch_id = 1,
    face_id = 2,

    pub fn name(self: BiometricType) []const u8 {
        return switch (self) {
            .none => "Not Available",
            .touch_id => "Touch ID",
            .face_id => "Face ID",
        };
    }

    pub fn icon(self: BiometricType) []const u8 {
        return switch (self) {
            .none => "xmark.circle",
            .touch_id => "touchid",
            .face_id => "faceid",
        };
    }
};

pub const HapticStyle = enum(u8) {
    light = 0,
    medium = 1,
    heavy = 2,
    rigid = 3,
    soft = 4,

    pub fn name(self: HapticStyle) []const u8 {
        return switch (self) {
            .light => "Light",
            .medium => "Medium",
            .heavy => "Heavy",
            .rigid => "Rigid",
            .soft => "Soft",
        };
    }
};

pub const NotificationType = enum(u8) {
    success = 0,
    warning = 1,
    error_type = 2,

    pub fn name(self: NotificationType) []const u8 {
        return switch (self) {
            .success => "Success",
            .warning => "Warning",
            .error_type => "Error",
        };
    }

    pub fn color(self: NotificationType) u32 {
        return switch (self) {
            .success => 0xFF34C759,
            .warning => 0xFFFF9500,
            .error_type => 0xFFFF3B30,
        };
    }
};

pub const HealthDataType = enum(u8) {
    steps = 0,
    heart_rate = 1,
    calories = 2,
    distance = 3,

    pub fn name(self: HealthDataType) []const u8 {
        return switch (self) {
            .steps => "Steps",
            .heart_rate => "Heart Rate",
            .calories => "Calories",
            .distance => "Distance",
        };
    }

    pub fn unit(self: HealthDataType) []const u8 {
        return switch (self) {
            .steps => "steps",
            .heart_rate => "BPM",
            .calories => "kcal",
            .distance => "km",
        };
    }

    pub fn icon(self: HealthDataType) []const u8 {
        return switch (self) {
            .steps => "figure.walk",
            .heart_rate => "heart.fill",
            .calories => "flame.fill",
            .distance => "map",
        };
    }
};

pub const SiriShortcut = struct {
    id: u32 = 0,
    phrase: []const u8 = "",
    action: []const u8 = "",
    icon: []const u8 = "",
    is_enabled: bool = false,
};

pub const max_shortcuts = 10;

pub const AppState = struct {
    initialized: bool = false,
    current_screen: Screen = .home,

    // Biometrics
    biometric_type: BiometricType = .face_id,
    is_authenticated: bool = false,
    auth_attempts: u32 = 0,

    // Haptics
    haptics_enabled: bool = true,
    last_haptic: HapticStyle = .medium,

    // HealthKit
    health_authorized: bool = false,
    steps_today: u32 = 0,
    heart_rate: u32 = 0,
    calories_burned: u32 = 0,
    distance_km: f32 = 0,

    // Siri shortcuts
    shortcuts: [max_shortcuts]SiriShortcut = undefined,
    shortcut_count: usize = 0,
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
    // Simulate health data
    app_state.steps_today = 8432;
    app_state.heart_rate = 72;
    app_state.calories_burned = 420;
    app_state.distance_km = 6.2;
    app_state.health_authorized = true;

    // Sample Siri shortcuts
    addShortcut("Open Dashboard", "open_dashboard", "square.grid.2x2");
    addShortcut("Start Workout", "start_workout", "figure.run");
    addShortcut("Check Steps", "check_steps", "figure.walk");
}

fn addShortcut(phrase: []const u8, action: []const u8, icon: []const u8) void {
    if (app_state.shortcut_count >= max_shortcuts) return;
    app_state.shortcuts[app_state.shortcut_count] = .{
        .id = @intCast(app_state.shortcut_count + 1),
        .phrase = phrase,
        .action = action,
        .icon = icon,
        .is_enabled = true,
    };
    app_state.shortcut_count += 1;
}

// Navigation
pub fn setScreen(screen: Screen) void {
    app_state.current_screen = screen;
}

// Biometrics
pub fn isBiometricAvailable() bool {
    return app_state.biometric_type != .none;
}

pub fn authenticate() bool {
    app_state.auth_attempts += 1;
    // Simulate successful authentication
    app_state.is_authenticated = true;
    return true;
}

pub fn logout() void {
    app_state.is_authenticated = false;
}

// Haptics
pub fn setHapticsEnabled(enabled: bool) void {
    app_state.haptics_enabled = enabled;
}

pub fn triggerHaptic(style: HapticStyle) void {
    if (app_state.haptics_enabled) {
        app_state.last_haptic = style;
    }
}

pub fn triggerNotification(notification_type: NotificationType) void {
    _ = notification_type;
    // Platform shell handles actual haptic
}

// HealthKit
pub fn requestHealthAuthorization() void {
    app_state.health_authorized = true;
}

pub fn getHealthValue(data_type: HealthDataType) u32 {
    return switch (data_type) {
        .steps => app_state.steps_today,
        .heart_rate => app_state.heart_rate,
        .calories => app_state.calories_burned,
        .distance => @intFromFloat(app_state.distance_km * 1000),
    };
}

// Siri shortcuts
pub fn toggleShortcut(shortcut_id: u32) void {
    for (0..app_state.shortcut_count) |i| {
        if (app_state.shortcuts[i].id == shortcut_id) {
            app_state.shortcuts[i].is_enabled = !app_state.shortcuts[i].is_enabled;
            break;
        }
    }
}

// Tests
test "state init" {
    init();
    defer deinit();
    try std.testing.expect(app_state.initialized);
    try std.testing.expect(app_state.steps_today > 0);
}

test "biometric authentication" {
    init();
    defer deinit();
    try std.testing.expect(isBiometricAvailable());
    try std.testing.expect(authenticate());
    try std.testing.expect(app_state.is_authenticated);
}

test "haptics" {
    init();
    defer deinit();
    triggerHaptic(.heavy);
    try std.testing.expectEqual(HapticStyle.heavy, app_state.last_haptic);
}

test "health data" {
    init();
    defer deinit();
    try std.testing.expect(app_state.health_authorized);
    try std.testing.expect(getHealthValue(.steps) > 0);
}

test "siri shortcuts" {
    init();
    defer deinit();
    try std.testing.expect(app_state.shortcut_count > 0);
    const first_id = app_state.shortcuts[0].id;
    toggleShortcut(first_id);
    try std.testing.expect(!app_state.shortcuts[0].is_enabled);
}
