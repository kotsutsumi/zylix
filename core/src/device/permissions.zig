//! Zylix Device - Permissions Module
//!
//! Unified permission handling for all device features.
//! Provides a single API for checking and requesting permissions.

const std = @import("std");
const types = @import("types.zig");

pub const Permission = types.Permission;
pub const PermissionStatus = types.PermissionStatus;
pub const Result = types.Result;

// === Permission Request ===

/// Permission request callback
pub const PermissionCallback = *const fn (permission: Permission, status: PermissionStatus) void;

/// Permission request configuration
pub const RequestConfig = struct {
    /// Show rationale before requesting (Android)
    show_rationale: bool = true,

    /// Rationale message to show user
    rationale_title: types.StringBuffer(128) = types.StringBuffer(128).init(),
    rationale_message: types.StringBuffer(512) = types.StringBuffer(512).init(),

    /// Open settings if permanently denied
    open_settings_if_denied: bool = false,
};

// === Permission Manager ===

/// Permission manager for unified permission handling
pub const PermissionManager = struct {
    // Cached permission statuses
    statuses: [12]PermissionStatus = [_]PermissionStatus{.not_determined} ** 12,

    // Callback
    callback: ?PermissionCallback = null,

    // Platform handle
    platform_handle: ?*anyopaque = null,

    const Self = @This();

    pub fn init() Self {
        return .{};
    }

    pub fn deinit(self: *Self) void {
        self.platform_handle = null;
    }

    /// Check permission status (cached, use refresh() to update)
    pub fn check(self: *Self, permission: Permission) PermissionStatus {
        return self.statuses[@intFromEnum(permission)];
    }

    /// Refresh permission status from system
    pub fn refresh(self: *Self, permission: Permission) PermissionStatus {
        // Platform-specific implementation
        // For now, return cached value
        return self.statuses[@intFromEnum(permission)];
    }

    /// Refresh all permission statuses
    pub fn refreshAll(self: *Self) void {
        for (0..12) |i| {
            _ = self.refresh(@enumFromInt(i));
        }
    }

    /// Request a single permission
    pub fn request(self: *Self, permission: Permission, config: ?RequestConfig) Result {
        const current = self.check(permission);

        // Already authorized
        if (current.isAuthorized()) {
            if (self.callback) |cb| cb(permission, current);
            return .ok;
        }

        // Check if permanently denied (would need settings)
        if (current == .denied) {
            if (config) |c| {
                if (c.open_settings_if_denied) {
                    return self.openSettings();
                }
            }
        }

        // Platform-specific implementation
        return .ok;
    }

    /// Request multiple permissions
    pub fn requestMultiple(self: *Self, permissions: []const Permission) Result {
        for (permissions) |p| {
            const result = self.request(p, null);
            if (result != .ok) return result;
        }
        return .ok;
    }

    /// Check if should show rationale (Android)
    pub fn shouldShowRationale(_: *Self, permission: Permission) bool {
        _ = permission;
        // Platform-specific implementation (Android only)
        return false;
    }

    /// Open app settings
    pub fn openSettings(_: *Self) Result {
        // Platform-specific implementation
        return .ok;
    }

    /// Set permission callback
    pub fn setCallback(self: *Self, callback: ?PermissionCallback) void {
        self.callback = callback;
    }

    // === Convenience methods ===

    /// Check if camera is authorized
    pub fn isCameraAuthorized(self: *Self) bool {
        return self.check(.camera).isAuthorized();
    }

    /// Check if microphone is authorized
    pub fn isMicrophoneAuthorized(self: *Self) bool {
        return self.check(.microphone).isAuthorized();
    }

    /// Check if location is authorized
    pub fn isLocationAuthorized(self: *Self) bool {
        return self.check(.location).isAuthorized() or
            self.check(.location_always).isAuthorized();
    }

    /// Check if notifications are authorized
    pub fn isNotificationsAuthorized(self: *Self) bool {
        return self.check(.notifications).isAuthorized();
    }

    /// Request camera and microphone (for video recording)
    pub fn requestCameraAndMicrophone(self: *Self) Result {
        return self.requestMultiple(&[_]Permission{ .camera, .microphone });
    }

    // === Internal callbacks ===

    /// Called by platform when permission status changes
    pub fn onPermissionChanged(self: *Self, permission: Permission, status: PermissionStatus) void {
        self.statuses[@intFromEnum(permission)] = status;
        if (self.callback) |cb| cb(permission, status);
    }
};

// === Global Instance ===

var global_manager: ?PermissionManager = null;

pub fn getManager() *PermissionManager {
    if (global_manager == null) {
        global_manager = PermissionManager.init();
    }
    return &global_manager.?;
}

pub fn init() Result {
    if (global_manager != null) return .ok;
    global_manager = PermissionManager.init();
    return .ok;
}

pub fn deinit() void {
    if (global_manager) |*m| m.deinit();
    global_manager = null;
}

// === Convenience Functions ===

/// Check permission status
pub fn check(permission: Permission) PermissionStatus {
    return getManager().check(permission);
}

/// Request permission
pub fn request(permission: Permission) Result {
    return getManager().request(permission, null);
}

/// Request permission with config
pub fn requestWithConfig(permission: Permission, config: RequestConfig) Result {
    return getManager().request(permission, config);
}

/// Open app settings
pub fn openSettings() Result {
    return getManager().openSettings();
}

// === Permission Group Helpers ===

/// Permissions required for camera features
pub const CameraPermissions = [_]Permission{ .camera, .microphone };

/// Permissions required for location features
pub const LocationPermissions = [_]Permission{ .location, .location_always };

/// Permissions required for media library
pub const MediaPermissions = [_]Permission{.photos};

/// Permissions required for health/fitness
pub const HealthPermissions = [_]Permission{ .motion, .bluetooth };

// === Tests ===

test "PermissionManager initialization" {
    var manager = PermissionManager.init();
    defer manager.deinit();

    try std.testing.expectEqual(PermissionStatus.not_determined, manager.check(.camera));
    try std.testing.expectEqual(PermissionStatus.not_determined, manager.check(.location));
}

test "Permission status check" {
    var manager = PermissionManager.init();
    defer manager.deinit();

    // Simulate authorized camera
    manager.statuses[@intFromEnum(Permission.camera)] = .authorized;
    try std.testing.expect(manager.isCameraAuthorized());

    // Simulate denied microphone
    manager.statuses[@intFromEnum(Permission.microphone)] = .denied;
    try std.testing.expect(!manager.isMicrophoneAuthorized());
}

test "PermissionStatus isAuthorized" {
    try std.testing.expect(PermissionStatus.authorized.isAuthorized());
    try std.testing.expect(PermissionStatus.authorized_when_in_use.isAuthorized());
    try std.testing.expect(PermissionStatus.provisional.isAuthorized());
    try std.testing.expect(!PermissionStatus.denied.isAuthorized());
    try std.testing.expect(!PermissionStatus.not_determined.isAuthorized());
}

test "Permission toString" {
    try std.testing.expectEqualStrings("camera", Permission.camera.toString());
    try std.testing.expectEqualStrings("location", Permission.location.toString());
    try std.testing.expectEqualStrings("notifications", Permission.notifications.toString());
}
