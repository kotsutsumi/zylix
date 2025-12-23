//! Zylix Device - Camera Module
//!
//! Camera access and image capture for all platforms.
//! Supports photo capture, video recording, and camera preview.

const std = @import("std");
const types = @import("types.zig");

pub const Result = types.Result;
pub const Permission = types.Permission;
pub const PermissionStatus = types.PermissionStatus;

// === Camera Configuration ===

/// Camera facing direction
pub const CameraFacing = enum(u8) {
    back = 0,
    front = 1,
    external = 2, // USB/external camera
};

/// Photo quality preset
pub const PhotoQuality = enum(u8) {
    low = 0, // ~480p, smaller file
    medium = 1, // ~720p
    high = 2, // ~1080p
    max = 3, // Maximum resolution

    pub fn toJpegQuality(self: PhotoQuality) u8 {
        return switch (self) {
            .low => 50,
            .medium => 70,
            .high => 85,
            .max => 95,
        };
    }
};

/// Video quality preset
pub const VideoQuality = enum(u8) {
    low = 0, // 480p, 30fps
    medium = 1, // 720p, 30fps
    high = 2, // 1080p, 30fps
    ultra = 3, // 4K, 30fps (if available)

    pub fn toResolution(self: VideoQuality) struct { width: u32, height: u32 } {
        return switch (self) {
            .low => .{ .width = 640, .height = 480 },
            .medium => .{ .width = 1280, .height = 720 },
            .high => .{ .width = 1920, .height = 1080 },
            .ultra => .{ .width = 3840, .height = 2160 },
        };
    }
};

/// Flash mode
pub const FlashMode = enum(u8) {
    off = 0,
    on = 1,
    auto = 2,
    torch = 3, // Continuous light
};

/// Focus mode
pub const FocusMode = enum(u8) {
    auto = 0,
    continuous = 1,
    manual = 2,
    locked = 3,
};

/// Camera configuration
pub const CameraConfig = struct {
    facing: CameraFacing = .back,
    photo_quality: PhotoQuality = .high,
    video_quality: VideoQuality = .high,
    flash_mode: FlashMode = .auto,
    focus_mode: FocusMode = .continuous,
    enable_stabilization: bool = true,
    enable_hdr: bool = false,
    mirror_front_camera: bool = true,
};

// === Image Data ===

/// Image format
pub const ImageFormat = enum(u8) {
    jpeg = 0,
    png = 1,
    heic = 2, // iOS/macOS
    webp = 3,
    raw = 4, // Platform-specific raw format
};

/// Image data structure
pub const ImageData = struct {
    data: ?[*]u8 = null,
    size: usize = 0,
    width: u32 = 0,
    height: u32 = 0,
    format: ImageFormat = .jpeg,
    orientation: Orientation = .up,
    timestamp: i64 = 0,

    pub const Orientation = enum(u8) {
        up = 0,
        down = 1,
        left = 2,
        right = 3,
        up_mirrored = 4,
        down_mirrored = 5,
        left_mirrored = 6,
        right_mirrored = 7,
    };

    /// Check if image data is valid
    pub fn isValid(self: ImageData) bool {
        return self.data != null and self.size > 0 and self.width > 0 and self.height > 0;
    }

    /// Get data as slice
    pub fn getData(self: ImageData) ?[]u8 {
        if (self.data) |d| {
            return d[0..self.size];
        }
        return null;
    }
};

/// Photo capture callback
pub const PhotoCallback = *const fn (image: *const ImageData, error_code: Result) void;

/// Video recording callback
pub const VideoCallback = *const fn (path: ?[*]const u8, path_len: usize, error_code: Result) void;

/// Preview frame callback (for real-time processing)
pub const PreviewCallback = *const fn (frame: *const ImageData) void;

// === Camera Capabilities ===

/// Camera device information
pub const CameraInfo = struct {
    device_id: types.StringBuffer(64) = types.StringBuffer(64).init(),
    name: types.StringBuffer(128) = types.StringBuffer(128).init(),
    facing: CameraFacing = .back,
    has_flash: bool = false,
    has_torch: bool = false,
    supports_hdr: bool = false,
    supports_stabilization: bool = false,
    supports_raw: bool = false,
    max_zoom: f32 = 1.0,
    sensor_orientation: u16 = 0, // degrees

    // Supported resolutions (simplified)
    max_photo_width: u32 = 0,
    max_photo_height: u32 = 0,
    max_video_width: u32 = 0,
    max_video_height: u32 = 0,
};

// === Camera Manager ===

/// Camera manager state
pub const CameraManager = struct {
    config: CameraConfig = .{},
    is_previewing: bool = false,
    is_recording: bool = false,
    permission_status: PermissionStatus = .not_determined,
    current_camera: ?CameraInfo = null,
    current_zoom: f32 = 1.0,

    // Callbacks
    photo_callback: ?PhotoCallback = null,
    video_callback: ?VideoCallback = null,
    preview_callback: ?PreviewCallback = null,

    // Platform handle
    platform_handle: ?*anyopaque = null,

    const Self = @This();

    /// Initialize camera manager
    pub fn init() Self {
        return .{};
    }

    /// Deinitialize and cleanup
    pub fn deinit(self: *Self) void {
        self.stopPreview();
        self.stopRecording();
        self.platform_handle = null;
    }

    /// Request camera permission
    pub fn requestPermission(self: *Self) Result {
        _ = self;
        // Platform-specific implementation
        return .not_available;
    }

    /// Check current permission status
    pub fn checkPermission(self: *Self) PermissionStatus {
        return self.permission_status;
    }

    /// Get available cameras
    pub fn getAvailableCameras(_: *Self, buffer: []CameraInfo) usize {
        // Platform-specific implementation
        _ = buffer;
        return 0;
    }

    /// Select camera by facing direction
    pub fn selectCamera(self: *Self, facing: CameraFacing) Result {
        self.config.facing = facing;
        // Platform-specific implementation
        return .not_available;
    }

    /// Start camera preview
    pub fn startPreview(self: *Self) Result {
        if (!self.permission_status.isAuthorized()) {
            return .permission_denied;
        }

        self.is_previewing = true;
        // Platform-specific implementation
        return .ok;
    }

    /// Stop camera preview
    pub fn stopPreview(self: *Self) void {
        self.is_previewing = false;
        // Platform-specific implementation
    }

    /// Capture photo
    pub fn capturePhoto(self: *Self) Result {
        if (!self.is_previewing) {
            return .not_initialized;
        }

        // Platform-specific implementation
        return .ok;
    }

    /// Start video recording
    pub fn startRecording(self: *Self) Result {
        if (!self.is_previewing) {
            return .not_initialized;
        }
        if (self.is_recording) {
            return .busy;
        }

        self.is_recording = true;
        // Platform-specific implementation
        return .ok;
    }

    /// Stop video recording
    pub fn stopRecording(self: *Self) Result {
        if (!self.is_recording) {
            return .not_initialized;
        }

        self.is_recording = false;
        // Platform-specific implementation
        return .ok;
    }

    /// Set flash mode
    pub fn setFlashMode(self: *Self, mode: FlashMode) Result {
        self.config.flash_mode = mode;
        // Platform-specific implementation
        return .ok;
    }

    /// Set zoom level (1.0 = no zoom)
    pub fn setZoom(self: *Self, zoom: f32) Result {
        if (self.current_camera) |camera| {
            if (zoom < 1.0 or zoom > camera.max_zoom) {
                return .invalid_arg;
            }
        } else {
            if (zoom < 1.0) return .invalid_arg;
        }

        self.current_zoom = zoom;
        // Platform-specific implementation
        return .ok;
    }

    /// Focus at point (normalized 0-1 coordinates)
    pub fn focusAtPoint(self: *Self, x: f32, y: f32) Result {
        if (x < 0 or x > 1 or y < 0 or y > 1) {
            return .invalid_arg;
        }
        _ = self;
        // Platform-specific implementation
        return .ok;
    }

    /// Set photo callback
    pub fn setPhotoCallback(self: *Self, callback: ?PhotoCallback) void {
        self.photo_callback = callback;
    }

    /// Set video callback
    pub fn setVideoCallback(self: *Self, callback: ?VideoCallback) void {
        self.video_callback = callback;
    }

    /// Set preview frame callback
    pub fn setPreviewCallback(self: *Self, callback: ?PreviewCallback) void {
        self.preview_callback = callback;
    }

    // === Internal callbacks ===

    /// Called by platform when photo is captured
    pub fn onPhotoCaptured(self: *Self, image: ImageData, error_code: Result) void {
        if (self.photo_callback) |cb| {
            cb(&image, error_code);
        }
    }

    /// Called by platform when video recording completes
    pub fn onVideoRecorded(self: *Self, path: ?[]const u8, error_code: Result) void {
        if (self.video_callback) |cb| {
            if (path) |p| {
                cb(p.ptr, p.len, error_code);
            } else {
                cb(null, 0, error_code);
            }
        }
    }

    /// Called by platform for each preview frame
    pub fn onPreviewFrame(self: *Self, frame: ImageData) void {
        if (self.preview_callback) |cb| {
            cb(&frame);
        }
    }
};

// === Global Instance ===

var global_manager: ?CameraManager = null;

/// Get global camera manager instance
pub fn getManager() *CameraManager {
    if (global_manager == null) {
        global_manager = CameraManager.init();
    }
    return &global_manager.?;
}

/// Initialize camera module
pub fn init() Result {
    if (global_manager != null) {
        return .ok;
    }
    global_manager = CameraManager.init();
    return .ok;
}

/// Deinitialize camera module
pub fn deinit() void {
    if (global_manager) |*manager| {
        manager.deinit();
    }
    global_manager = null;
}

// === Convenience Functions ===

/// Quick photo capture with callback
pub fn takePhoto(callback: PhotoCallback) Result {
    const manager = getManager();
    manager.setPhotoCallback(callback);
    return manager.capturePhoto();
}

// === Tests ===

test "CameraManager initialization" {
    var manager = CameraManager.init();
    defer manager.deinit();

    try std.testing.expect(!manager.is_previewing);
    try std.testing.expect(!manager.is_recording);
    try std.testing.expectEqual(@as(f32, 1.0), manager.current_zoom);
}

test "VideoQuality resolution" {
    const hd = VideoQuality.high.toResolution();
    try std.testing.expectEqual(@as(u32, 1920), hd.width);
    try std.testing.expectEqual(@as(u32, 1080), hd.height);
}

test "PhotoQuality to JPEG quality" {
    try std.testing.expectEqual(@as(u8, 85), PhotoQuality.high.toJpegQuality());
    try std.testing.expectEqual(@as(u8, 95), PhotoQuality.max.toJpegQuality());
}

test "ImageData validation" {
    var image = ImageData{};
    try std.testing.expect(!image.isValid());

    var buffer: [100]u8 = undefined;
    image.data = &buffer;
    image.size = 100;
    image.width = 10;
    image.height = 10;
    try std.testing.expect(image.isValid());
}
