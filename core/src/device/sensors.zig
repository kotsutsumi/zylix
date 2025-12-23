//! Zylix Device - Sensor Module
//!
//! Access to device sensors: accelerometer, gyroscope, magnetometer,
//! barometer, proximity, ambient light, and pedometer.

const std = @import("std");
const types = @import("types.zig");

pub const Result = types.Result;
pub const Vector3 = types.Vector3;
pub const Quaternion = types.Quaternion;
pub const Permission = types.Permission;
pub const PermissionStatus = types.PermissionStatus;

// === Sensor Types ===

/// Available sensor types
pub const SensorType = enum(u8) {
    accelerometer = 0, // Linear acceleration (m/s²)
    gyroscope = 1, // Rotation rate (rad/s)
    magnetometer = 2, // Magnetic field (μT)
    gravity = 3, // Gravity vector (m/s²)
    linear_acceleration = 4, // Acceleration without gravity
    rotation = 5, // Device rotation (quaternion)
    barometer = 6, // Atmospheric pressure (hPa)
    proximity = 7, // Proximity sensor (boolean or distance)
    ambient_light = 8, // Light level (lux)
    pedometer = 9, // Step counter
    heart_rate = 10, // Heart rate (BPM) - watchOS
    heading = 11, // Compass heading (degrees)
};

/// Sensor availability check
pub fn isSensorAvailable(sensor: SensorType) bool {
    _ = sensor;
    // Platform-specific implementation
    return false;
}

// === Sensor Data ===

/// Accelerometer data
pub const AccelerometerData = struct {
    acceleration: Vector3,

    /// Check if device is roughly stationary
    pub fn isStationary(self: AccelerometerData) bool {
        const magnitude = self.acceleration.magnitude();
        // Near 1g (gravity) means stationary
        return magnitude > 9.5 and magnitude < 10.1;
    }
};

/// Gyroscope data
pub const GyroscopeData = struct {
    rotation_rate: Vector3, // rad/s

    /// Check if device is rotating significantly
    pub fn isRotating(self: GyroscopeData) bool {
        return self.rotation_rate.magnitude() > 0.1;
    }
};

/// Magnetometer data
pub const MagnetometerData = struct {
    magnetic_field: Vector3, // μT (microtesla)

    /// Get magnetic field strength
    pub fn fieldStrength(self: MagnetometerData) f64 {
        return self.magnetic_field.magnitude();
    }
};

/// Device motion (combined sensors)
pub const DeviceMotion = struct {
    acceleration: Vector3, // User acceleration (without gravity)
    gravity: Vector3,
    rotation_rate: Vector3,
    attitude: Quaternion, // Device orientation
    heading: f64, // Compass heading (degrees, 0-360)
    timestamp: i64,

    /// Get pitch angle (radians)
    pub fn pitch(self: DeviceMotion) f64 {
        // Extract pitch from quaternion
        const q = self.attitude;
        return std.math.asin(2.0 * (q.w * q.y - q.z * q.x));
    }

    /// Get roll angle (radians)
    pub fn roll(self: DeviceMotion) f64 {
        const q = self.attitude;
        const sinr_cosp = 2.0 * (q.w * q.x + q.y * q.z);
        const cosr_cosp = 1.0 - 2.0 * (q.x * q.x + q.y * q.y);
        return std.math.atan2(sinr_cosp, cosr_cosp);
    }

    /// Get yaw angle (radians)
    pub fn yaw(self: DeviceMotion) f64 {
        const q = self.attitude;
        const siny_cosp = 2.0 * (q.w * q.z + q.x * q.y);
        const cosy_cosp = 1.0 - 2.0 * (q.y * q.y + q.z * q.z);
        return std.math.atan2(siny_cosp, cosy_cosp);
    }
};

/// Barometer data
pub const BarometerData = struct {
    pressure: f64, // hPa (hectopascals)
    relative_altitude: f64, // meters (relative to start)
    timestamp: i64,

    /// Estimate altitude from pressure (simplified)
    pub fn estimatedAltitude(self: BarometerData) f64 {
        // Using barometric formula (sea level = 1013.25 hPa)
        const sea_level_pressure: f64 = 1013.25;
        return 44330.0 * (1.0 - std.math.pow(self.pressure / sea_level_pressure, 0.1903));
    }
};

/// Proximity data
pub const ProximityData = struct {
    is_near: bool,
    distance: ?f64, // cm (if available)
    timestamp: i64,
};

/// Ambient light data
pub const AmbientLightData = struct {
    lux: f64, // Light level in lux
    timestamp: i64,

    pub const Level = enum {
        dark, // < 10 lux
        dim, // 10-50 lux
        indoor, // 50-500 lux
        outdoor, // 500-10000 lux
        bright, // > 10000 lux
    };

    /// Get light level category
    pub fn getLevel(self: AmbientLightData) Level {
        if (self.lux < 10) return .dark;
        if (self.lux < 50) return .dim;
        if (self.lux < 500) return .indoor;
        if (self.lux < 10000) return .outdoor;
        return .bright;
    }
};

/// Pedometer data
pub const PedometerData = struct {
    steps: u64,
    distance: f64, // meters
    floors_ascended: u32,
    floors_descended: u32,
    start_date: i64,
    end_date: i64,

    /// Calculate steps per minute (cadence)
    pub fn cadence(self: PedometerData) f64 {
        const duration_ms = self.end_date - self.start_date;
        if (duration_ms <= 0) return 0;
        const duration_min = @as(f64, @floatFromInt(duration_ms)) / 60000.0;
        return @as(f64, @floatFromInt(self.steps)) / duration_min;
    }
};

/// Heart rate data (watchOS)
pub const HeartRateData = struct {
    bpm: f64, // Beats per minute
    timestamp: i64,

    pub const Zone = enum {
        rest, // < 60% max
        fat_burn, // 60-70% max
        cardio, // 70-80% max
        peak, // > 80% max
    };

    /// Get heart rate zone (assumes max HR of 220 - age)
    pub fn getZone(self: HeartRateData, age: u8) Zone {
        const max_hr = 220 - @as(f64, @floatFromInt(age));
        const percentage = (self.bpm / max_hr) * 100;

        if (percentage < 60) return .rest;
        if (percentage < 70) return .fat_burn;
        if (percentage < 80) return .cardio;
        return .peak;
    }
};

/// Heading data (compass)
pub const HeadingData = struct {
    magnetic_heading: f64, // degrees (0-360, relative to magnetic north)
    true_heading: f64, // degrees (0-360, relative to true north)
    accuracy: f64, // degrees of uncertainty
    timestamp: i64,

    /// Get cardinal direction
    pub fn cardinalDirection(self: HeadingData) []const u8 {
        const heading = self.true_heading;
        if (heading >= 337.5 or heading < 22.5) return "N";
        if (heading < 67.5) return "NE";
        if (heading < 112.5) return "E";
        if (heading < 157.5) return "SE";
        if (heading < 202.5) return "S";
        if (heading < 247.5) return "SW";
        if (heading < 292.5) return "W";
        return "NW";
    }
};

// === Callbacks ===

pub const AccelerometerCallback = *const fn (data: *const AccelerometerData) void;
pub const GyroscopeCallback = *const fn (data: *const GyroscopeData) void;
pub const MagnetometerCallback = *const fn (data: *const MagnetometerData) void;
pub const DeviceMotionCallback = *const fn (data: *const DeviceMotion) void;
pub const BarometerCallback = *const fn (data: *const BarometerData) void;
pub const ProximityCallback = *const fn (data: *const ProximityData) void;
pub const AmbientLightCallback = *const fn (data: *const AmbientLightData) void;
pub const PedometerCallback = *const fn (data: *const PedometerData) void;
pub const HeartRateCallback = *const fn (data: *const HeartRateData) void;
pub const HeadingCallback = *const fn (data: *const HeadingData) void;

// === Sensor Manager ===

/// Update frequency
pub const UpdateFrequency = enum(u8) {
    low = 0, // ~10 Hz
    medium = 1, // ~30 Hz
    high = 2, // ~60 Hz
    max = 3, // Device maximum

    pub fn toHz(self: UpdateFrequency) u32 {
        return switch (self) {
            .low => 10,
            .medium => 30,
            .high => 60,
            .max => 100,
        };
    }

    pub fn toInterval(self: UpdateFrequency) f64 {
        return 1.0 / @as(f64, @floatFromInt(self.toHz()));
    }
};

/// Sensor manager
pub const SensorManager = struct {
    // Active sensors
    accelerometer_active: bool = false,
    gyroscope_active: bool = false,
    magnetometer_active: bool = false,
    device_motion_active: bool = false,
    barometer_active: bool = false,
    proximity_active: bool = false,
    ambient_light_active: bool = false,
    pedometer_active: bool = false,
    heart_rate_active: bool = false,
    heading_active: bool = false,

    // Update frequency
    frequency: UpdateFrequency = .medium,

    // Callbacks
    accelerometer_callback: ?AccelerometerCallback = null,
    gyroscope_callback: ?GyroscopeCallback = null,
    magnetometer_callback: ?MagnetometerCallback = null,
    device_motion_callback: ?DeviceMotionCallback = null,
    barometer_callback: ?BarometerCallback = null,
    proximity_callback: ?ProximityCallback = null,
    ambient_light_callback: ?AmbientLightCallback = null,
    pedometer_callback: ?PedometerCallback = null,
    heart_rate_callback: ?HeartRateCallback = null,
    heading_callback: ?HeadingCallback = null,

    // Permission
    motion_permission: PermissionStatus = .not_determined,

    // Platform handle
    platform_handle: ?*anyopaque = null,

    const Self = @This();

    pub fn init() Self {
        return .{};
    }

    pub fn deinit(self: *Self) void {
        self.stopAll();
        self.platform_handle = null;
    }

    /// Request motion permission (required on iOS 13+)
    pub fn requestMotionPermission(self: *Self) Result {
        _ = self;
        // Platform-specific implementation
        return .not_available;
    }

    /// Start accelerometer updates
    pub fn startAccelerometer(self: *Self, callback: AccelerometerCallback) Result {
        self.accelerometer_callback = callback;
        self.accelerometer_active = true;
        // Platform-specific implementation
        return .ok;
    }

    /// Stop accelerometer updates
    pub fn stopAccelerometer(self: *Self) void {
        self.accelerometer_active = false;
        self.accelerometer_callback = null;
    }

    /// Start gyroscope updates
    pub fn startGyroscope(self: *Self, callback: GyroscopeCallback) Result {
        self.gyroscope_callback = callback;
        self.gyroscope_active = true;
        return .ok;
    }

    /// Stop gyroscope updates
    pub fn stopGyroscope(self: *Self) void {
        self.gyroscope_active = false;
        self.gyroscope_callback = null;
    }

    /// Start magnetometer updates
    pub fn startMagnetometer(self: *Self, callback: MagnetometerCallback) Result {
        self.magnetometer_callback = callback;
        self.magnetometer_active = true;
        return .ok;
    }

    /// Stop magnetometer updates
    pub fn stopMagnetometer(self: *Self) void {
        self.magnetometer_active = false;
        self.magnetometer_callback = null;
    }

    /// Start combined device motion updates
    pub fn startDeviceMotion(self: *Self, callback: DeviceMotionCallback) Result {
        self.device_motion_callback = callback;
        self.device_motion_active = true;
        return .ok;
    }

    /// Stop device motion updates
    pub fn stopDeviceMotion(self: *Self) void {
        self.device_motion_active = false;
        self.device_motion_callback = null;
    }

    /// Start barometer updates
    pub fn startBarometer(self: *Self, callback: BarometerCallback) Result {
        self.barometer_callback = callback;
        self.barometer_active = true;
        return .ok;
    }

    /// Stop barometer updates
    pub fn stopBarometer(self: *Self) void {
        self.barometer_active = false;
        self.barometer_callback = null;
    }

    /// Start proximity sensor
    pub fn startProximity(self: *Self, callback: ProximityCallback) Result {
        self.proximity_callback = callback;
        self.proximity_active = true;
        return .ok;
    }

    /// Stop proximity sensor
    pub fn stopProximity(self: *Self) void {
        self.proximity_active = false;
        self.proximity_callback = null;
    }

    /// Start ambient light sensor
    pub fn startAmbientLight(self: *Self, callback: AmbientLightCallback) Result {
        self.ambient_light_callback = callback;
        self.ambient_light_active = true;
        return .ok;
    }

    /// Stop ambient light sensor
    pub fn stopAmbientLight(self: *Self) void {
        self.ambient_light_active = false;
        self.ambient_light_callback = null;
    }

    /// Start pedometer
    pub fn startPedometer(self: *Self, callback: PedometerCallback) Result {
        self.pedometer_callback = callback;
        self.pedometer_active = true;
        return .ok;
    }

    /// Stop pedometer
    pub fn stopPedometer(self: *Self) void {
        self.pedometer_active = false;
        self.pedometer_callback = null;
    }

    /// Start heart rate monitoring (watchOS)
    pub fn startHeartRate(self: *Self, callback: HeartRateCallback) Result {
        self.heart_rate_callback = callback;
        self.heart_rate_active = true;
        return .ok;
    }

    /// Stop heart rate monitoring
    pub fn stopHeartRate(self: *Self) void {
        self.heart_rate_active = false;
        self.heart_rate_callback = null;
    }

    /// Start heading updates
    pub fn startHeading(self: *Self, callback: HeadingCallback) Result {
        self.heading_callback = callback;
        self.heading_active = true;
        return .ok;
    }

    /// Stop heading updates
    pub fn stopHeading(self: *Self) void {
        self.heading_active = false;
        self.heading_callback = null;
    }

    /// Set update frequency for all sensors
    pub fn setFrequency(self: *Self, freq: UpdateFrequency) void {
        self.frequency = freq;
    }

    /// Stop all sensors
    pub fn stopAll(self: *Self) void {
        self.stopAccelerometer();
        self.stopGyroscope();
        self.stopMagnetometer();
        self.stopDeviceMotion();
        self.stopBarometer();
        self.stopProximity();
        self.stopAmbientLight();
        self.stopPedometer();
        self.stopHeartRate();
        self.stopHeading();
    }

    // === Internal callbacks ===

    pub fn onAccelerometerUpdate(self: *Self, data: AccelerometerData) void {
        if (self.accelerometer_callback) |cb| cb(&data);
    }

    pub fn onGyroscopeUpdate(self: *Self, data: GyroscopeData) void {
        if (self.gyroscope_callback) |cb| cb(&data);
    }

    pub fn onMagnetometerUpdate(self: *Self, data: MagnetometerData) void {
        if (self.magnetometer_callback) |cb| cb(&data);
    }

    pub fn onDeviceMotionUpdate(self: *Self, data: DeviceMotion) void {
        if (self.device_motion_callback) |cb| cb(&data);
    }

    pub fn onBarometerUpdate(self: *Self, data: BarometerData) void {
        if (self.barometer_callback) |cb| cb(&data);
    }

    pub fn onProximityUpdate(self: *Self, data: ProximityData) void {
        if (self.proximity_callback) |cb| cb(&data);
    }

    pub fn onAmbientLightUpdate(self: *Self, data: AmbientLightData) void {
        if (self.ambient_light_callback) |cb| cb(&data);
    }

    pub fn onPedometerUpdate(self: *Self, data: PedometerData) void {
        if (self.pedometer_callback) |cb| cb(&data);
    }

    pub fn onHeartRateUpdate(self: *Self, data: HeartRateData) void {
        if (self.heart_rate_callback) |cb| cb(&data);
    }

    pub fn onHeadingUpdate(self: *Self, data: HeadingData) void {
        if (self.heading_callback) |cb| cb(&data);
    }
};

// === Global Instance ===

var global_manager: ?SensorManager = null;

pub fn getManager() *SensorManager {
    if (global_manager == null) {
        global_manager = SensorManager.init();
    }
    return &global_manager.?;
}

pub fn init() Result {
    if (global_manager != null) return .ok;
    global_manager = SensorManager.init();
    return .ok;
}

pub fn deinit() void {
    if (global_manager) |*m| m.deinit();
    global_manager = null;
}

// === Tests ===

test "SensorManager initialization" {
    var manager = SensorManager.init();
    defer manager.deinit();

    try std.testing.expect(!manager.accelerometer_active);
    try std.testing.expect(!manager.gyroscope_active);
}

test "UpdateFrequency conversion" {
    try std.testing.expectEqual(@as(u32, 60), UpdateFrequency.high.toHz());
    try std.testing.expectApproxEqAbs(@as(f64, 0.0166), UpdateFrequency.high.toInterval(), 0.001);
}

test "HeadingData cardinal direction" {
    const north = HeadingData{ .magnetic_heading = 0, .true_heading = 0, .accuracy = 5, .timestamp = 0 };
    try std.testing.expectEqualStrings("N", north.cardinalDirection());

    const east = HeadingData{ .magnetic_heading = 90, .true_heading = 90, .accuracy = 5, .timestamp = 0 };
    try std.testing.expectEqualStrings("E", east.cardinalDirection());
}

test "AmbientLightData level" {
    const dark = AmbientLightData{ .lux = 5, .timestamp = 0 };
    try std.testing.expectEqual(AmbientLightData.Level.dark, dark.getLevel());

    const outdoor = AmbientLightData{ .lux = 5000, .timestamp = 0 };
    try std.testing.expectEqual(AmbientLightData.Level.outdoor, outdoor.getLevel());
}

test "PedometerData cadence" {
    const data = PedometerData{
        .steps = 120,
        .distance = 100,
        .floors_ascended = 0,
        .floors_descended = 0,
        .start_date = 0,
        .end_date = 60000, // 1 minute
    };
    try std.testing.expectApproxEqAbs(@as(f64, 120.0), data.cadence(), 0.1);
}
