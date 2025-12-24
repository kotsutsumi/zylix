//! Device Lab Showcase
//!
//! Demonstration of Zylix platform-specific device feature integration.

const std = @import("std");
const app = @import("app.zig");
const lab = @import("lab.zig");

pub const AppState = app.AppState;
pub const Feature = app.Feature;
pub const HapticType = app.HapticType;
pub const PermissionState = app.PermissionState;
pub const BiometricType = app.BiometricType;
pub const NetworkStatus = app.NetworkStatus;
pub const VNode = lab.VNode;

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
    return lab.buildApp(app.getState());
}

// C ABI Exports
export fn app_init() void {
    init();
}

export fn app_deinit() void {
    deinit();
}

export fn app_select_feature(feature: u32) void {
    const max_feature = @typeInfo(Feature).@"enum".fields.len;
    if (feature >= max_feature) return;
    app.selectFeature(@enumFromInt(feature));
}

// Motion exports
export fn app_update_accelerometer(x: f32, y: f32, z: f32) void {
    app.updateAccelerometer(x, y, z);
}

export fn app_update_gyroscope(x: f32, y: f32, z: f32) void {
    app.updateGyroscope(x, y, z);
}

export fn app_update_compass(heading: f32) void {
    app.updateCompass(heading);
}

export fn app_clear_shake() void {
    app.clearShake();
}

export fn app_is_shake_detected() i32 {
    return if (getState().shake_detected) 1 else 0;
}

// Location exports
export fn app_update_location(lat: f64, lon: f64, accuracy: f32) void {
    app.updateLocation(lat, lon, accuracy);
}

export fn app_set_location_permission(granted: u8) void {
    app.setLocationPermission(granted != 0);
}

export fn app_start_location_tracking() void {
    app.startLocationTracking();
}

export fn app_stop_location_tracking() void {
    app.stopLocationTracking();
}

export fn app_get_distance_traveled() f32 {
    return getState().distance_traveled;
}

// Camera exports
export fn app_set_camera_permission(granted: u8) void {
    app.setCameraPermission(granted != 0);
}

export fn app_photo_captured() void {
    app.photoCaptured();
}

export fn app_start_video_recording() void {
    app.startVideoRecording();
}

export fn app_stop_video_recording() void {
    app.stopVideoRecording();
}

export fn app_is_video_recording() i32 {
    return if (getState().video_recording) 1 else 0;
}

export fn app_get_photo_count() u32 {
    return getState().photo_count;
}

// Biometric exports
export fn app_set_biometric_type(biometric_type: u8) void {
    const max_type = @typeInfo(BiometricType).@"enum".fields.len;
    if (biometric_type >= max_type) return;
    app.setBiometricType(@enumFromInt(biometric_type));
}

export fn app_request_biometric_auth() void {
    app.requestBiometricAuth();
}

export fn app_biometric_result(success: u8) void {
    app.biometricResult(success != 0);
}

export fn app_is_biometric_available() i32 {
    return if (getState().biometric_available) 1 else 0;
}

export fn app_is_biometric_authenticated() i32 {
    return if (getState().biometric_authenticated) 1 else 0;
}

// Haptic exports
export fn app_trigger_haptic(haptic_type: u8) void {
    const max_type = @typeInfo(HapticType).@"enum".fields.len;
    if (haptic_type >= max_type) return;
    app.triggerHaptic(@enumFromInt(haptic_type));
}

export fn app_set_haptic_available(available: u8) void {
    app.setHapticAvailable(available != 0);
}

// Notification exports
export fn app_set_notification_permission(granted: u8) void {
    app.setNotificationPermission(granted != 0);
}

export fn app_schedule_notification() void {
    app.scheduleNotification();
}

export fn app_set_badge_count(count: u32) void {
    app.setBadgeCount(count);
}

export fn app_clear_badge() void {
    app.clearBadge();
}

export fn app_get_scheduled_count() u32 {
    return getState().scheduled_count;
}

// Device info exports
export fn app_set_battery_level(level: f32) void {
    app.setBatteryLevel(level);
}

export fn app_set_battery_charging(charging: u8) void {
    app.setBatteryCharging(charging != 0);
}

export fn app_set_network_status(status: u8) void {
    const max_status = @typeInfo(NetworkStatus).@"enum".fields.len;
    if (status >= max_status) return;
    app.setNetworkStatus(@enumFromInt(status));
}

export fn app_set_screen_size(width: u32, height: u32) void {
    app.setScreenSize(width, height);
}

// Tests
test "initialization" {
    init();
    defer deinit();
    try std.testing.expect(getState().initialized);
    try std.testing.expectEqual(Feature.motion, getState().current_feature);
}

test "feature selection" {
    init();
    defer deinit();
    app.selectFeature(.camera);
    try std.testing.expectEqual(Feature.camera, getState().current_feature);
}

test "motion sensors" {
    init();
    defer deinit();
    app.updateAccelerometer(0.5, -0.3, 9.8);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), getState().accelerometer.x, 0.001);
    try std.testing.expect(getState().motion_enabled);
}

test "biometric flow" {
    init();
    defer deinit();
    app.setBiometricType(.face_id);
    try std.testing.expect(getState().biometric_available);
    app.requestBiometricAuth();
    try std.testing.expect(getState().auth_in_progress);
    app.biometricResult(true);
    try std.testing.expect(getState().biometric_authenticated);
}

test "render" {
    init();
    defer deinit();
    const view = render();
    try std.testing.expectEqual(lab.Tag.column, view.tag);
}
