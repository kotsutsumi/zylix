//! Zylix Device - Location Services
//!
//! GPS and location services for all platforms.
//! Provides unified API for location tracking, geocoding, and geofencing.

const std = @import("std");
const types = @import("types.zig");

pub const Result = types.Result;
pub const Coordinate = types.Coordinate;
pub const Permission = types.Permission;
pub const PermissionStatus = types.PermissionStatus;

// === Configuration ===

/// Location accuracy level
pub const Accuracy = enum(u8) {
    /// Best accuracy (uses GPS, consumes more power)
    best = 0,
    /// Within 10 meters
    navigation = 1,
    /// Within 100 meters (balanced)
    high = 2,
    /// Within 1000 meters (power saving)
    medium = 3,
    /// Within 3000 meters (minimal power)
    low = 4,
    /// Reduced accuracy (privacy mode, ~5km)
    reduced = 5,

    pub fn toMeters(self: Accuracy) f64 {
        return switch (self) {
            .best => 1,
            .navigation => 10,
            .high => 100,
            .medium => 1000,
            .low => 3000,
            .reduced => 5000,
        };
    }
};

/// Location request configuration
pub const LocationConfig = struct {
    accuracy: Accuracy = .high,
    distance_filter: f64 = 10, // Minimum distance in meters before update
    timeout_ms: u32 = 30000, // Request timeout
    max_age_ms: u32 = 60000, // Maximum age of cached location
    show_background_indicator: bool = false, // iOS: show blue bar when in background
    allow_background_updates: bool = false,
    pause_location_updates_automatically: bool = true,
};

// === Location Update ===

/// Location update data
pub const LocationUpdate = struct {
    coordinate: Coordinate,
    speed: ?f64 = null, // meters per second
    course: ?f64 = null, // heading in degrees (0-360)
    floor: ?i32 = null, // floor number (if available)
    source: LocationSource = .unknown,

    pub const LocationSource = enum(u8) {
        gps = 0,
        wifi = 1,
        cell = 2,
        ip = 3,
        cached = 4,
        unknown = 255,
    };
};

/// Location update callback
pub const LocationCallback = *const fn (update: *const LocationUpdate) void;

/// Location error callback
pub const LocationErrorCallback = *const fn (error_code: Result) void;

// === Geofence ===

/// Geofence region
pub const GeofenceRegion = struct {
    id: [64]u8 = undefined,
    id_len: usize = 0,
    center: Coordinate,
    radius: f64, // meters (max 100km on some platforms)
    notify_on_entry: bool = true,
    notify_on_exit: bool = true,
    notify_on_dwell: bool = false,
    dwell_time_ms: u32 = 30000, // Time to stay before triggering dwell

    pub fn setId(self: *GeofenceRegion, id: []const u8) void {
        const copy_len = @min(id.len, 64);
        @memcpy(self.id[0..copy_len], id[0..copy_len]);
        self.id_len = copy_len;
    }

    pub fn getId(self: *const GeofenceRegion) []const u8 {
        return self.id[0..self.id_len];
    }
};

/// Geofence event
pub const GeofenceEvent = struct {
    region_id: [64]u8 = undefined,
    region_id_len: usize = 0,
    event_type: EventType,
    timestamp: i64,

    pub const EventType = enum(u8) {
        enter = 0,
        exit = 1,
        dwell = 2,
    };

    pub fn getRegionId(self: *const GeofenceEvent) []const u8 {
        return self.region_id[0..self.region_id_len];
    }
};

/// Geofence callback
pub const GeofenceCallback = *const fn (event: *const GeofenceEvent) void;

// === Geocoding ===

/// Address components
pub const Address = struct {
    street: types.StringBuffer(256) = types.StringBuffer(256).init(),
    city: types.StringBuffer(128) = types.StringBuffer(128).init(),
    state: types.StringBuffer(128) = types.StringBuffer(128).init(),
    postal_code: types.StringBuffer(32) = types.StringBuffer(32).init(),
    country: types.StringBuffer(128) = types.StringBuffer(128).init(),
    country_code: types.StringBuffer(4) = types.StringBuffer(4).init(), // ISO 3166-1 alpha-2

    pub fn formatted(self: *const Address, buffer: []u8) []const u8 {
        var pos: usize = 0;

        if (self.street.len > 0) {
            const street = self.street.get();
            if (pos + street.len + 2 < buffer.len) {
                @memcpy(buffer[pos .. pos + street.len], street);
                pos += street.len;
                buffer[pos] = ',';
                buffer[pos + 1] = ' ';
                pos += 2;
            }
        }

        if (self.city.len > 0) {
            const city = self.city.get();
            if (pos + city.len + 2 < buffer.len) {
                @memcpy(buffer[pos .. pos + city.len], city);
                pos += city.len;
                buffer[pos] = ',';
                buffer[pos + 1] = ' ';
                pos += 2;
            }
        }

        if (self.country.len > 0) {
            const country = self.country.get();
            if (pos + country.len < buffer.len) {
                @memcpy(buffer[pos .. pos + country.len], country);
                pos += country.len;
            }
        }

        return buffer[0..pos];
    }
};

/// Geocode result callback
pub const GeocodeCallback = *const fn (coordinate: *const Coordinate, address: *const Address) void;

// === Location Manager ===

/// Location manager state
pub const LocationManager = struct {
    config: LocationConfig = .{},
    is_updating: bool = false,
    last_location: ?LocationUpdate = null,
    permission_status: PermissionStatus = .not_determined,

    // Callbacks
    location_callback: ?LocationCallback = null,
    error_callback: ?LocationErrorCallback = null,
    geofence_callback: ?GeofenceCallback = null,

    // Platform handle (opaque pointer)
    platform_handle: ?*anyopaque = null,

    // Registered geofences
    geofences: [20]?GeofenceRegion = [_]?GeofenceRegion{null} ** 20,
    geofence_count: usize = 0,

    const Self = @This();

    /// Initialize location manager
    pub fn init() Self {
        return .{};
    }

    /// Deinitialize and cleanup
    pub fn deinit(self: *Self) void {
        self.stopUpdates();
        self.clearAllGeofences();
        self.platform_handle = null;
    }

    /// Request location permission
    pub fn requestPermission(self: *Self, always: bool) Result {
        _ = self;
        _ = always;
        // Platform-specific implementation via C ABI
        return .not_available;
    }

    /// Check current permission status
    pub fn checkPermission(self: *Self) PermissionStatus {
        return self.permission_status;
    }

    /// Start location updates
    pub fn startUpdates(self: *Self, config: LocationConfig) Result {
        if (!self.permission_status.isAuthorized()) {
            return .permission_denied;
        }

        self.config = config;
        self.is_updating = true;
        // Platform-specific implementation
        return .ok;
    }

    /// Stop location updates
    pub fn stopUpdates(self: *Self) void {
        self.is_updating = false;
        // Platform-specific implementation
    }

    /// Request single location update
    pub fn requestLocation(self: *Self, config: LocationConfig) Result {
        if (!self.permission_status.isAuthorized()) {
            return .permission_denied;
        }

        self.config = config;
        // Platform-specific implementation
        return .ok;
    }

    /// Get last known location (may be cached)
    pub fn getLastLocation(self: *const Self) ?LocationUpdate {
        return self.last_location;
    }

    /// Set location update callback
    pub fn setLocationCallback(self: *Self, callback: ?LocationCallback) void {
        self.location_callback = callback;
    }

    /// Set error callback
    pub fn setErrorCallback(self: *Self, callback: ?LocationErrorCallback) void {
        self.error_callback = callback;
    }

    // === Geofencing ===

    /// Add geofence region
    pub fn addGeofence(self: *Self, region: GeofenceRegion) Result {
        if (self.geofence_count >= 20) {
            return .not_available; // Max geofences reached
        }

        // Find empty slot
        for (&self.geofences) |*slot| {
            if (slot.* == null) {
                slot.* = region;
                self.geofence_count += 1;
                return .ok;
            }
        }

        return .not_available;
    }

    /// Remove geofence by ID
    pub fn removeGeofence(self: *Self, id: []const u8) Result {
        for (&self.geofences) |*slot| {
            if (slot.*) |*region| {
                if (std.mem.eql(u8, region.getId(), id)) {
                    slot.* = null;
                    self.geofence_count -= 1;
                    return .ok;
                }
            }
        }
        return .invalid_arg;
    }

    /// Clear all geofences
    pub fn clearAllGeofences(self: *Self) void {
        for (&self.geofences) |*slot| {
            slot.* = null;
        }
        self.geofence_count = 0;
    }

    /// Set geofence callback
    pub fn setGeofenceCallback(self: *Self, callback: ?GeofenceCallback) void {
        self.geofence_callback = callback;
    }

    // === Geocoding ===

    /// Forward geocode (address to coordinate)
    pub fn geocode(_: *Self, address: []const u8, callback: GeocodeCallback) Result {
        _ = address;
        _ = callback;
        // Platform-specific implementation
        return .not_available;
    }

    /// Reverse geocode (coordinate to address)
    pub fn reverseGeocode(_: *Self, coordinate: Coordinate, callback: GeocodeCallback) Result {
        _ = coordinate;
        _ = callback;
        // Platform-specific implementation
        return .not_available;
    }

    // === Internal callbacks (called by platform code) ===

    /// Called by platform when location is updated
    pub fn onLocationUpdate(self: *Self, update: LocationUpdate) void {
        self.last_location = update;
        if (self.location_callback) |cb| {
            cb(&update);
        }
    }

    /// Called by platform on error
    pub fn onError(self: *Self, error_code: Result) void {
        if (self.error_callback) |cb| {
            cb(error_code);
        }
    }

    /// Called by platform on geofence event
    pub fn onGeofenceEvent(self: *Self, event: GeofenceEvent) void {
        if (self.geofence_callback) |cb| {
            cb(&event);
        }
    }
};

// === Global Instance ===

var global_manager: ?LocationManager = null;

/// Get global location manager instance
pub fn getManager() *LocationManager {
    if (global_manager == null) {
        global_manager = LocationManager.init();
    }
    return &global_manager.?;
}

/// Initialize location module
pub fn init() Result {
    if (global_manager != null) {
        return .ok;
    }
    global_manager = LocationManager.init();
    return .ok;
}

/// Deinitialize location module
pub fn deinit() void {
    if (global_manager) |*manager| {
        manager.deinit();
    }
    global_manager = null;
}

// === Tests ===

test "LocationManager basic operations" {
    var manager = LocationManager.init();
    defer manager.deinit();

    try std.testing.expect(!manager.is_updating);
    try std.testing.expect(manager.last_location == null);
}

test "Geofence management" {
    var manager = LocationManager.init();
    defer manager.deinit();

    var region = GeofenceRegion{
        .center = .{ .latitude = 35.6762, .longitude = 139.6503 },
        .radius = 100,
    };
    region.setId("test-region");

    // Set permission to authorized for testing
    manager.permission_status = .authorized;

    const result = manager.addGeofence(region);
    try std.testing.expectEqual(Result.ok, result);
    try std.testing.expectEqual(@as(usize, 1), manager.geofence_count);

    const remove_result = manager.removeGeofence("test-region");
    try std.testing.expectEqual(Result.ok, remove_result);
    try std.testing.expectEqual(@as(usize, 0), manager.geofence_count);
}

test "Accuracy to meters" {
    try std.testing.expectEqual(@as(f64, 10), Accuracy.navigation.toMeters());
    try std.testing.expectEqual(@as(f64, 100), Accuracy.high.toMeters());
    try std.testing.expectEqual(@as(f64, 1000), Accuracy.medium.toMeters());
}
