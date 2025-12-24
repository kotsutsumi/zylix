//! Device Lab - Application State

const std = @import("std");

pub const Feature = enum(u32) {
    motion = 0,
    location = 1,
    camera = 2,
    biometric = 3,
    haptic = 4,
    notification = 5,
    device_info = 6,

    pub fn title(self: Feature) []const u8 {
        return switch (self) {
            .motion => "Motion Sensors",
            .location => "Location",
            .camera => "Camera",
            .biometric => "Biometrics",
            .haptic => "Haptics",
            .notification => "Notifications",
            .device_info => "Device Info",
        };
    }

    pub fn description(self: Feature) []const u8 {
        return switch (self) {
            .motion => "Accelerometer, gyroscope, orientation",
            .location => "GPS, compass, distance tracking",
            .camera => "Photo, video, QR scanning",
            .biometric => "Face ID, Touch ID, fingerprint",
            .haptic => "Vibration patterns and feedback",
            .notification => "Local and push notifications",
            .device_info => "Platform, battery, network",
        };
    }

    pub fn icon(self: Feature) []const u8 {
        return switch (self) {
            .motion => "gyroscope",
            .location => "location.fill",
            .camera => "camera.fill",
            .biometric => "faceid",
            .haptic => "waveform",
            .notification => "bell.fill",
            .device_info => "iphone",
        };
    }
};

pub const HapticType = enum(u8) {
    light = 0,
    medium = 1,
    heavy = 2,
    selection = 3,
    success = 4,
    warning = 5,
    error_feedback = 6,

    pub fn name(self: HapticType) []const u8 {
        return switch (self) {
            .light => "Light",
            .medium => "Medium",
            .heavy => "Heavy",
            .selection => "Selection",
            .success => "Success",
            .warning => "Warning",
            .error_feedback => "Error",
        };
    }
};

pub const PermissionState = enum(u8) {
    unknown = 0,
    granted = 1,
    denied = 2,
    restricted = 3,
};

pub const BiometricType = enum(u8) {
    none = 0,
    touch_id = 1,
    face_id = 2,
    fingerprint = 3,
    face_unlock = 4,
};

pub const NetworkStatus = enum(u8) {
    unknown = 0,
    disconnected = 1,
    wifi = 2,
    cellular = 3,
};

pub const Vec3 = struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,
};

pub const Location = struct {
    latitude: f64 = 0,
    longitude: f64 = 0,
    accuracy: f32 = 0,
    heading: f32 = 0,
    speed: f32 = 0,
};

pub const AppState = struct {
    initialized: bool = false,
    current_feature: Feature = .motion,

    // Motion state
    accelerometer: Vec3 = .{},
    gyroscope: Vec3 = .{},
    compass_heading: f32 = 0,
    shake_detected: bool = false,
    motion_enabled: bool = false,

    // Location state
    location: Location = .{},
    location_permission: PermissionState = .unknown,
    location_tracking: bool = false,
    distance_traveled: f32 = 0,

    // Camera state
    camera_permission: PermissionState = .unknown,
    photo_count: u32 = 0,
    video_recording: bool = false,
    qr_result: [128]u8 = [_]u8{0} ** 128,
    qr_result_len: usize = 0,

    // Biometric state
    biometric_type: BiometricType = .none,
    biometric_available: bool = false,
    biometric_authenticated: bool = false,
    auth_in_progress: bool = false,

    // Haptic state
    last_haptic: HapticType = .light,
    haptic_available: bool = true,

    // Notification state
    notification_permission: PermissionState = .unknown,
    scheduled_count: u32 = 0,
    badge_count: u32 = 0,

    // Device info
    platform: [32]u8 = [_]u8{0} ** 32,
    platform_len: usize = 0,
    os_version: [16]u8 = [_]u8{0} ** 16,
    os_version_len: usize = 0,
    device_model: [32]u8 = [_]u8{0} ** 32,
    device_model_len: usize = 0,
    screen_width: u32 = 0,
    screen_height: u32 = 0,
    battery_level: f32 = 1.0,
    battery_charging: bool = false,
    network_status: NetworkStatus = .unknown,
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

pub fn selectFeature(feature: Feature) void {
    app_state.current_feature = feature;
}

// Motion functions
pub fn updateAccelerometer(x: f32, y: f32, z: f32) void {
    app_state.accelerometer = .{ .x = x, .y = y, .z = z };
    app_state.motion_enabled = true;

    // Simple shake detection
    const magnitude = @sqrt(x * x + y * y + z * z);
    app_state.shake_detected = magnitude > 2.5;
}

pub fn updateGyroscope(x: f32, y: f32, z: f32) void {
    app_state.gyroscope = .{ .x = x, .y = y, .z = z };
}

pub fn updateCompass(heading: f32) void {
    app_state.compass_heading = heading;
}

pub fn clearShake() void {
    app_state.shake_detected = false;
}

// Location functions
pub fn updateLocation(lat: f64, lon: f64, accuracy: f32) void {
    // Calculate distance if tracking
    if (app_state.location_tracking and app_state.location.latitude != 0) {
        const dist = calculateDistance(
            app_state.location.latitude,
            app_state.location.longitude,
            lat,
            lon,
        );
        app_state.distance_traveled += dist;
    }

    app_state.location.latitude = lat;
    app_state.location.longitude = lon;
    app_state.location.accuracy = accuracy;
}

pub fn setLocationPermission(granted: bool) void {
    app_state.location_permission = if (granted) .granted else .denied;
}

pub fn startLocationTracking() void {
    if (app_state.location_permission == .granted) {
        app_state.location_tracking = true;
        app_state.distance_traveled = 0;
    }
}

pub fn stopLocationTracking() void {
    app_state.location_tracking = false;
}

fn calculateDistance(lat1: f64, lon1: f64, lat2: f64, lon2: f64) f32 {
    // Haversine formula (simplified)
    const r = 6371000.0; // Earth radius in meters
    const dlat = (lat2 - lat1) * std.math.pi / 180.0;
    const dlon = (lon2 - lon1) * std.math.pi / 180.0;
    const a = @sin(dlat / 2) * @sin(dlat / 2) +
        @cos(lat1 * std.math.pi / 180.0) * @cos(lat2 * std.math.pi / 180.0) *
        @sin(dlon / 2) * @sin(dlon / 2);
    const c = 2 * std.math.atan2(@sqrt(a), @sqrt(1 - a));
    return @floatCast(r * c);
}

// Camera functions
pub fn setCameraPermission(granted: bool) void {
    app_state.camera_permission = if (granted) .granted else .denied;
}

pub fn photoCaptured() void {
    app_state.photo_count += 1;
}

pub fn startVideoRecording() void {
    if (app_state.camera_permission == .granted) {
        app_state.video_recording = true;
    }
}

pub fn stopVideoRecording() void {
    app_state.video_recording = false;
}

pub fn setQRResult(result: []const u8) void {
    const len = @min(result.len, app_state.qr_result.len);
    @memcpy(app_state.qr_result[0..len], result[0..len]);
    app_state.qr_result_len = len;
}

// Biometric functions
pub fn setBiometricType(biometric_type: BiometricType) void {
    app_state.biometric_type = biometric_type;
    app_state.biometric_available = biometric_type != .none;
}

pub fn requestBiometricAuth() void {
    if (app_state.biometric_available) {
        app_state.auth_in_progress = true;
        app_state.biometric_authenticated = false;
    }
}

pub fn biometricResult(success: bool) void {
    app_state.auth_in_progress = false;
    app_state.biometric_authenticated = success;
}

// Haptic functions
pub fn triggerHaptic(haptic_type: HapticType) void {
    app_state.last_haptic = haptic_type;
}

pub fn setHapticAvailable(available: bool) void {
    app_state.haptic_available = available;
}

// Notification functions
pub fn setNotificationPermission(granted: bool) void {
    app_state.notification_permission = if (granted) .granted else .denied;
}

pub fn scheduleNotification() void {
    if (app_state.notification_permission == .granted) {
        app_state.scheduled_count += 1;
    }
}

pub fn setBadgeCount(count: u32) void {
    app_state.badge_count = count;
}

pub fn clearBadge() void {
    app_state.badge_count = 0;
}

// Device info functions
pub fn setPlatform(platform: []const u8) void {
    const len = @min(platform.len, app_state.platform.len);
    @memcpy(app_state.platform[0..len], platform[0..len]);
    app_state.platform_len = len;
}

pub fn setOSVersion(version: []const u8) void {
    const len = @min(version.len, app_state.os_version.len);
    @memcpy(app_state.os_version[0..len], version[0..len]);
    app_state.os_version_len = len;
}

pub fn setDeviceModel(model: []const u8) void {
    const len = @min(model.len, app_state.device_model.len);
    @memcpy(app_state.device_model[0..len], model[0..len]);
    app_state.device_model_len = len;
}

pub fn setScreenSize(width: u32, height: u32) void {
    app_state.screen_width = width;
    app_state.screen_height = height;
}

pub fn setBatteryLevel(level: f32) void {
    app_state.battery_level = @max(0, @min(level, 1.0));
}

pub fn setBatteryCharging(charging: bool) void {
    app_state.battery_charging = charging;
}

pub fn setNetworkStatus(status: NetworkStatus) void {
    app_state.network_status = status;
}

// Tests
test "state init" {
    init();
    defer deinit();
    try std.testing.expect(app_state.initialized);
    try std.testing.expectEqual(Feature.motion, app_state.current_feature);
}

test "feature selection" {
    init();
    defer deinit();
    selectFeature(.biometric);
    try std.testing.expectEqual(Feature.biometric, app_state.current_feature);
}

test "accelerometer update" {
    init();
    defer deinit();
    updateAccelerometer(0.1, 0.2, 9.8);
    try std.testing.expectApproxEqAbs(@as(f32, 0.1), app_state.accelerometer.x, 0.001);
    try std.testing.expect(app_state.motion_enabled);
}

test "shake detection" {
    init();
    defer deinit();
    updateAccelerometer(3.0, 3.0, 3.0);
    try std.testing.expect(app_state.shake_detected);
    clearShake();
    try std.testing.expect(!app_state.shake_detected);
}

test "location permission" {
    init();
    defer deinit();
    try std.testing.expectEqual(PermissionState.unknown, app_state.location_permission);
    setLocationPermission(true);
    try std.testing.expectEqual(PermissionState.granted, app_state.location_permission);
}

test "biometric flow" {
    init();
    defer deinit();
    setBiometricType(.face_id);
    try std.testing.expect(app_state.biometric_available);
    requestBiometricAuth();
    try std.testing.expect(app_state.auth_in_progress);
    biometricResult(true);
    try std.testing.expect(app_state.biometric_authenticated);
    try std.testing.expect(!app_state.auth_in_progress);
}

test "haptic trigger" {
    init();
    defer deinit();
    triggerHaptic(.heavy);
    try std.testing.expectEqual(HapticType.heavy, app_state.last_haptic);
}

test "notification scheduling" {
    init();
    defer deinit();
    setNotificationPermission(true);
    scheduleNotification();
    scheduleNotification();
    try std.testing.expectEqual(@as(u32, 2), app_state.scheduled_count);
}

test "battery level" {
    init();
    defer deinit();
    setBatteryLevel(0.75);
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), app_state.battery_level, 0.001);
    setBatteryLevel(1.5); // Should clamp
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), app_state.battery_level, 0.001);
}

test "feature metadata" {
    try std.testing.expectEqualStrings("Motion Sensors", Feature.motion.title());
    try std.testing.expectEqualStrings("gyroscope", Feature.motion.icon());
    try std.testing.expectEqualStrings("Face ID, Touch ID, fingerprint", Feature.biometric.description());
}

test "haptic type names" {
    try std.testing.expectEqualStrings("Light", HapticType.light.name());
    try std.testing.expectEqualStrings("Success", HapticType.success.name());
}
