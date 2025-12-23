//! Zylix Device - Unified Device Features Module
//!
//! Cross-platform device features including location, camera, sensors,
//! notifications, audio, background tasks, haptics, and permissions.
//!
//! ## Design Principles
//!
//! 1. **Unified API**: Same API across all platforms
//! 2. **Permission Aware**: Built-in permission handling
//! 3. **Battery Efficient**: Optimized for mobile devices
//! 4. **Platform Optimized**: Native implementations where beneficial
//!
//! ## Usage
//!
//! ```zig
//! const device = @import("device/device.zig");
//!
//! // Initialize
//! device.init();
//! defer device.deinit();
//!
//! // Location
//! const loc = device.location.getManager();
//! loc.requestPermission(false);
//! loc.startUpdates(.{ .accuracy = .high });
//!
//! // Camera
//! const cam = device.camera.getManager();
//! cam.requestPermission();
//! cam.startPreview();
//! cam.capturePhoto();
//!
//! // Haptics
//! device.haptics.mediumImpact();
//! ```

const std = @import("std");

// === Module Re-exports ===

/// Common types (Result, Permission, Coordinate, Vector3, etc.)
pub const types = @import("types.zig");
pub const Result = types.Result;
pub const Permission = types.Permission;
pub const PermissionStatus = types.PermissionStatus;
pub const Platform = types.Platform;
pub const Coordinate = types.Coordinate;
pub const Vector3 = types.Vector3;
pub const Quaternion = types.Quaternion;

/// Location services (GPS, geofencing, geocoding)
pub const location = @import("location.zig");
pub const LocationManager = location.LocationManager;
pub const LocationUpdate = location.LocationUpdate;
pub const LocationConfig = location.LocationConfig;
pub const Accuracy = location.Accuracy;
pub const GeofenceRegion = location.GeofenceRegion;
pub const Address = location.Address;

/// Camera (photo capture, video recording, preview)
pub const camera = @import("camera.zig");
pub const CameraManager = camera.CameraManager;
pub const CameraConfig = camera.CameraConfig;
pub const CameraFacing = camera.CameraFacing;
pub const PhotoQuality = camera.PhotoQuality;
pub const VideoQuality = camera.VideoQuality;
pub const FlashMode = camera.FlashMode;
pub const ImageData = camera.ImageData;
pub const CameraInfo = camera.CameraInfo;

/// Sensors (accelerometer, gyroscope, magnetometer, barometer, etc.)
pub const sensors = @import("sensors.zig");
pub const SensorManager = sensors.SensorManager;
pub const SensorType = sensors.SensorType;
pub const AccelerometerData = sensors.AccelerometerData;
pub const GyroscopeData = sensors.GyroscopeData;
pub const MagnetometerData = sensors.MagnetometerData;
pub const DeviceMotion = sensors.DeviceMotion;
pub const BarometerData = sensors.BarometerData;
pub const PedometerData = sensors.PedometerData;
pub const HeartRateData = sensors.HeartRateData;
pub const HeadingData = sensors.HeadingData;

/// Notifications (local and push)
pub const notifications = @import("notifications.zig");
pub const NotificationManager = notifications.NotificationManager;
pub const NotificationContent = notifications.Content;
pub const NotificationTrigger = notifications.Trigger;
pub const NotificationRequest = notifications.Request;
pub const NotificationPriority = notifications.Priority;
pub const PushToken = notifications.PushToken;

/// Audio (playback and recording)
pub const audio = @import("audio.zig");
pub const AudioSession = audio.AudioSession;
pub const AudioPlayer = audio.AudioPlayer;
pub const AudioRecorder = audio.AudioRecorder;
pub const PlayerState = audio.PlayerState;
pub const RecorderState = audio.RecorderState;
pub const SessionCategory = audio.SessionCategory;

/// Background tasks and processing
pub const background = @import("background.zig");
pub const BackgroundManager = background.BackgroundManager;
pub const TaskConfig = background.TaskConfig;
pub const TaskType = background.TaskType;
pub const TaskConstraints = background.TaskConstraints;
pub const TransferTask = background.TransferTask;

/// Haptic feedback
pub const haptics = @import("haptics.zig");
pub const HapticsEngine = haptics.HapticsEngine;
pub const HapticPattern = haptics.HapticPattern;
pub const ImpactStyle = haptics.ImpactStyle;
pub const NotificationType = haptics.NotificationType;

/// Permission handling
pub const permissions = @import("permissions.zig");
pub const PermissionManager = permissions.PermissionManager;

// === Constants ===

/// Zylix Device module version
pub const VERSION: u32 = 0x00_0A_00; // v0.10.0

/// Version string
pub const VERSION_STRING = "0.10.0";

// === Global State ===

var initialized: bool = false;

// === Initialization ===

/// Initialize all device modules
pub fn init() Result {
    if (initialized) {
        return .ok;
    }

    // Initialize all submodules
    _ = types.getPlatform(); // Ensure platform detection
    _ = location.init();
    _ = camera.init();
    _ = sensors.init();
    _ = notifications.init();
    _ = audio.init();
    _ = background.init();
    _ = haptics.init();
    _ = permissions.init();

    initialized = true;
    return .ok;
}

/// Deinitialize all device modules
pub fn deinit() void {
    if (!initialized) return;

    permissions.deinit();
    haptics.deinit();
    background.deinit();
    audio.deinit();
    notifications.deinit();
    sensors.deinit();
    camera.deinit();
    location.deinit();

    initialized = false;
}

/// Check if device module is initialized
pub fn isInitialized() bool {
    return initialized;
}

/// Get version
pub fn getVersion() u32 {
    return VERSION;
}

/// Get version string
pub fn getVersionString() []const u8 {
    return VERSION_STRING;
}

// === Quick Access Functions ===

/// Get location manager
pub fn getLocationManager() *LocationManager {
    return location.getManager();
}

/// Get camera manager
pub fn getCameraManager() *CameraManager {
    return camera.getManager();
}

/// Get sensor manager
pub fn getSensorManager() *SensorManager {
    return sensors.getManager();
}

/// Get notification manager
pub fn getNotificationManager() *NotificationManager {
    return notifications.getManager();
}

/// Get audio player
pub fn getAudioPlayer() *AudioPlayer {
    return audio.getPlayer();
}

/// Get audio recorder
pub fn getAudioRecorder() *AudioRecorder {
    return audio.getRecorder();
}

/// Get background manager
pub fn getBackgroundManager() *BackgroundManager {
    return background.getManager();
}

/// Get haptics engine
pub fn getHapticsEngine() *HapticsEngine {
    return haptics.getEngine();
}

/// Get permission manager
pub fn getPermissionManager() *PermissionManager {
    return permissions.getManager();
}

// === Device Info ===

/// Device capabilities
pub const DeviceCapabilities = struct {
    has_camera: bool = false,
    has_front_camera: bool = false,
    has_flash: bool = false,
    has_gps: bool = false,
    has_accelerometer: bool = false,
    has_gyroscope: bool = false,
    has_magnetometer: bool = false,
    has_barometer: bool = false,
    has_haptics: bool = false,
    has_heart_rate: bool = false,
    supports_background_fetch: bool = false,
    supports_push_notifications: bool = false,
};

/// Query device capabilities
pub fn getCapabilities() DeviceCapabilities {
    // Platform-specific implementation
    return DeviceCapabilities{
        .has_camera = true,
        .has_front_camera = true,
        .has_flash = true,
        .has_gps = true,
        .has_accelerometer = true,
        .has_gyroscope = true,
        .has_magnetometer = true,
        .has_barometer = true,
        .has_haptics = true,
        .has_heart_rate = types.getPlatform() == .watchos,
        .supports_background_fetch = true,
        .supports_push_notifications = true,
    };
}

/// Get current platform
pub fn getPlatform() Platform {
    return types.getPlatform();
}

// === Tests ===

test "device module initialization" {
    const result = init();
    try std.testing.expectEqual(Result.ok, result);
    try std.testing.expect(isInitialized());

    // Double init should be ok
    const result2 = init();
    try std.testing.expectEqual(Result.ok, result2);

    deinit();
    try std.testing.expect(!isInitialized());
}

test "version" {
    try std.testing.expectEqual(@as(u32, 0x00_0A_00), getVersion());
    try std.testing.expectEqualStrings("0.10.0", getVersionString());
}

test "device capabilities" {
    const caps = getCapabilities();
    try std.testing.expect(caps.has_camera);
    try std.testing.expect(caps.has_gps);
}

// Include submodule tests
test {
    _ = types;
    _ = location;
    _ = camera;
    _ = sensors;
    _ = notifications;
    _ = audio;
    _ = background;
    _ = haptics;
    _ = permissions;
}
