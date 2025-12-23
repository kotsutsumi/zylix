//! Zylix Device - Common Types
//!
//! Shared types for device features module.

const std = @import("std");

// === Result Types ===

/// Common result type for device operations
pub const Result = enum(u8) {
    ok = 0,
    not_available = 1,
    permission_denied = 2,
    not_initialized = 3,
    invalid_arg = 4,
    timeout = 5,
    cancelled = 6,
    hardware_error = 7,
    not_supported = 8,
    busy = 9,
    unknown = 255,

    pub fn isOk(self: Result) bool {
        return self == .ok;
    }

    pub fn isError(self: Result) bool {
        return self != .ok;
    }
};

// === Permission Types ===

/// Permission types for device features
pub const Permission = enum(u8) {
    camera = 0,
    microphone = 1,
    location = 2,
    location_always = 3,
    photos = 4,
    contacts = 5,
    calendar = 6,
    reminders = 7,
    bluetooth = 8,
    motion = 9,
    notifications = 10,
    background_refresh = 11,

    pub fn toString(self: Permission) []const u8 {
        return switch (self) {
            .camera => "camera",
            .microphone => "microphone",
            .location => "location",
            .location_always => "location_always",
            .photos => "photos",
            .contacts => "contacts",
            .calendar => "calendar",
            .reminders => "reminders",
            .bluetooth => "bluetooth",
            .motion => "motion",
            .notifications => "notifications",
            .background_refresh => "background_refresh",
        };
    }
};

/// Permission status
pub const PermissionStatus = enum(u8) {
    not_determined = 0,
    restricted = 1,
    denied = 2,
    authorized = 3,
    authorized_when_in_use = 4, // For location
    provisional = 5, // For notifications (iOS)

    pub fn isAuthorized(self: PermissionStatus) bool {
        return self == .authorized or self == .authorized_when_in_use or self == .provisional;
    }
};

// === Platform Detection ===

/// Target platform
pub const Platform = enum(u8) {
    ios = 0,
    android = 1,
    macos = 2,
    windows = 3,
    linux = 4,
    web = 5,
    watchos = 6,
    tvos = 7,
    unknown = 255,
};

/// Get current platform at comptime
pub fn getPlatform() Platform {
    const builtin = @import("builtin");
    return switch (builtin.os.tag) {
        .ios => .ios,
        .macos => .macos,
        .windows => .windows,
        .linux => .linux,
        .freestanding => .web, // WASM target
        else => .unknown,
    };
}

// === Coordinate Types ===

/// Geographic coordinate
pub const Coordinate = struct {
    latitude: f64,
    longitude: f64,
    altitude: ?f64 = null,
    accuracy: ?f64 = null, // Horizontal accuracy in meters
    altitude_accuracy: ?f64 = null, // Vertical accuracy in meters
    timestamp: i64 = 0, // Unix timestamp in milliseconds

    pub fn isValid(self: Coordinate) bool {
        return self.latitude >= -90 and self.latitude <= 90 and
            self.longitude >= -180 and self.longitude <= 180;
    }

    /// Calculate distance to another coordinate in meters (Haversine formula)
    pub fn distanceTo(self: Coordinate, other: Coordinate) f64 {
        const earth_radius: f64 = 6371000; // meters
        const lat1_rad = self.latitude * std.math.pi / 180.0;
        const lat2_rad = other.latitude * std.math.pi / 180.0;
        const delta_lat = (other.latitude - self.latitude) * std.math.pi / 180.0;
        const delta_lon = (other.longitude - self.longitude) * std.math.pi / 180.0;

        const a = @sin(delta_lat / 2) * @sin(delta_lat / 2) +
            @cos(lat1_rad) * @cos(lat2_rad) *
            @sin(delta_lon / 2) * @sin(delta_lon / 2);
        const c = 2 * std.math.atan2(@sqrt(a), @sqrt(1 - a));

        return earth_radius * c;
    }
};

// === Vector Types ===

/// 3D vector for sensor data
pub const Vector3 = struct {
    x: f64 = 0,
    y: f64 = 0,
    z: f64 = 0,
    timestamp: i64 = 0,

    pub fn magnitude(self: Vector3) f64 {
        return @sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
    }

    pub fn normalized(self: Vector3) Vector3 {
        const mag = self.magnitude();
        if (mag == 0) return self;
        return .{
            .x = self.x / mag,
            .y = self.y / mag,
            .z = self.z / mag,
            .timestamp = self.timestamp,
        };
    }
};

/// Quaternion for rotation data
pub const Quaternion = struct {
    x: f64 = 0,
    y: f64 = 0,
    z: f64 = 0,
    w: f64 = 1,
    timestamp: i64 = 0,
};

// === Callback Types ===

/// Generic callback function type
pub const Callback = *const fn (data: ?*anyopaque, len: usize) void;

/// Error callback function type
pub const ErrorCallback = *const fn (error_code: Result, message: ?[*]const u8, message_len: usize) void;

// === Buffer Types ===

/// Fixed-size string buffer
pub fn StringBuffer(comptime size: usize) type {
    return struct {
        const Self = @This();
        data: [size]u8 = undefined,
        len: usize = 0,

        pub fn init() Self {
            return .{};
        }

        pub fn set(self: *Self, str: []const u8) void {
            const copy_len = @min(str.len, size);
            @memcpy(self.data[0..copy_len], str[0..copy_len]);
            self.len = copy_len;
        }

        pub fn get(self: *const Self) []const u8 {
            return self.data[0..self.len];
        }

        pub fn clear(self: *Self) void {
            self.len = 0;
        }
    };
}

// === Tests ===

test "Coordinate distance calculation" {
    // Tokyo to Osaka (approximately 400km)
    const tokyo = Coordinate{ .latitude = 35.6762, .longitude = 139.6503 };
    const osaka = Coordinate{ .latitude = 34.6937, .longitude = 135.5023 };

    const distance = tokyo.distanceTo(osaka);
    // Should be around 400km
    try std.testing.expect(distance > 390000 and distance < 410000);
}

test "Vector3 magnitude" {
    const v = Vector3{ .x = 3, .y = 4, .z = 0 };
    try std.testing.expectApproxEqAbs(@as(f64, 5.0), v.magnitude(), 0.001);
}

test "Permission status check" {
    try std.testing.expect(PermissionStatus.authorized.isAuthorized());
    try std.testing.expect(PermissionStatus.authorized_when_in_use.isAuthorized());
    try std.testing.expect(!PermissionStatus.denied.isAuthorized());
}

test "StringBuffer operations" {
    var buf = StringBuffer(32).init();
    buf.set("Hello");
    try std.testing.expectEqualStrings("Hello", buf.get());
    buf.clear();
    try std.testing.expectEqual(@as(usize, 0), buf.len);
}
