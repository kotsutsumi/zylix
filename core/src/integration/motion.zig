//! Motion Frame Provider Module
//!
//! Low-resolution camera frames for motion tracking with:
//! - No preview required (background processing)
//! - Configurable frame rate and resolution
//! - Motion centroid detection support
//! - Multiple camera source support
//!
//! Platform implementations:
//! - iOS: AVFoundation
//! - Android: CameraX ImageAnalysis
//! - Web: getUserMedia
//! - Desktop: Platform cameras (via miniaudio or platform APIs)

const std = @import("std");

/// Motion error types
pub const MotionError = error{
    NotAvailable,
    NotInitialized,
    CameraNotFound,
    CameraPermissionDenied,
    CameraInUse,
    InvalidConfiguration,
    FrameProcessingError,
    OutOfMemory,
};

/// Frame resolution presets
pub const Resolution = enum(u8) {
    /// Very low (80x60) - minimal processing
    very_low = 0,
    /// Low (160x120) - basic motion detection
    low = 1,
    /// Medium (320x240) - detailed motion tracking
    medium = 2,
    /// High (640x480) - high precision
    high = 3,

    pub fn getWidth(self: Resolution) u16 {
        return switch (self) {
            .very_low => 80,
            .low => 160,
            .medium => 320,
            .high => 640,
        };
    }

    pub fn getHeight(self: Resolution) u16 {
        return switch (self) {
            .very_low => 60,
            .low => 120,
            .medium => 240,
            .high => 480,
        };
    }
};

/// Pixel format
pub const PixelFormat = enum(u8) {
    /// Single channel grayscale
    grayscale = 0,
    /// RGB 24-bit
    rgb = 1,
    /// RGBA 32-bit
    rgba = 2,
    /// YUV420 planar
    yuv420 = 3,
    /// NV12 (Y plane + interleaved UV)
    nv12 = 4,

    pub fn getBytesPerPixel(self: PixelFormat) u8 {
        return switch (self) {
            .grayscale => 1,
            .rgb => 3,
            .rgba => 4,
            .yuv420 => 1, // Per Y plane pixel
            .nv12 => 1, // Per Y plane pixel
        };
    }
};

/// Camera facing direction
pub const CameraFacing = enum(u8) {
    front = 0,
    back = 1,
    external = 2,
};

/// Motion frame configuration
pub const MotionFrameConfig = struct {
    /// Target frames per second (1-60)
    target_fps: u8 = 15,
    /// Frame resolution
    resolution: Resolution = .low,
    /// Pixel format
    pixel_format: PixelFormat = .grayscale,
    /// Preferred camera facing
    camera_facing: CameraFacing = .front,
    /// Enable automatic exposure
    auto_exposure: bool = true,
    /// Enable automatic white balance
    auto_white_balance: bool = true,
    /// Enable frame timestamp
    include_timestamp: bool = true,
    /// Enable motion detection in provider
    detect_motion: bool = false,
    /// Motion detection sensitivity (0.0-1.0)
    motion_sensitivity: f32 = 0.5,
    /// Enable debug logging
    debug: bool = false,
};

/// Motion frame data
pub const MotionFrame = struct {
    /// Frame width in pixels
    width: u16,
    /// Frame height in pixels
    height: u16,
    /// Pixel format
    format: PixelFormat,
    /// Raw pixel data
    data: []const u8,
    /// Bytes per row (stride)
    stride: u32,
    /// Frame timestamp in milliseconds
    timestamp: i64,
    /// Frame sequence number
    sequence: u64,
    /// Motion detected (if detect_motion enabled)
    motion_detected: bool = false,
    /// Motion centroid X (0.0-1.0, if motion detected)
    motion_x: f32 = 0.0,
    /// Motion centroid Y (0.0-1.0, if motion detected)
    motion_y: f32 = 0.0,
    /// Motion intensity (0.0-1.0)
    motion_intensity: f32 = 0.0,

    /// Get pixel at coordinates
    pub fn getPixel(self: *const MotionFrame, x: u16, y: u16) ?u8 {
        if (x >= self.width or y >= self.height) return null;
        if (self.format != .grayscale) return null;

        const index = @as(usize, y) * self.stride + @as(usize, x);
        if (index >= self.data.len) return null;
        return self.data[index];
    }

    /// Get average brightness
    pub fn getAverageBrightness(self: *const MotionFrame) f32 {
        if (self.format != .grayscale or self.data.len == 0) return 0.0;

        var sum: u64 = 0;
        for (self.data) |pixel| {
            sum += pixel;
        }
        return @as(f32, @floatFromInt(sum)) / @as(f32, @floatFromInt(self.data.len)) / 255.0;
    }
};

/// Frame callback type
pub const FrameCallback = *const fn (MotionFrame) void;

/// Motion detection result
pub const MotionResult = struct {
    /// Motion detected
    detected: bool,
    /// Motion centroid X (0.0-1.0, normalized)
    centroid_x: f32,
    /// Motion centroid Y (0.0-1.0, normalized)
    centroid_y: f32,
    /// Motion intensity (0.0-1.0)
    intensity: f32,
    /// Motion bounding box (normalized coordinates)
    bbox_x: f32 = 0.0,
    bbox_y: f32 = 0.0,
    bbox_width: f32 = 0.0,
    bbox_height: f32 = 0.0,
    /// Motion direction (radians, 0 = right, PI/2 = down)
    direction: f32 = 0.0,
    /// Motion velocity (pixels per second, normalized)
    velocity: f32 = 0.0,
};

/// Camera info
pub const CameraInfo = struct {
    id: []const u8,
    name: []const u8,
    facing: CameraFacing,
    max_width: u16,
    max_height: u16,
    max_fps: u8,
};

/// Motion Frame Provider
pub const MotionFrameProvider = struct {
    allocator: std.mem.Allocator,
    config: MotionFrameConfig,
    running: bool = false,
    frame_callback: ?FrameCallback = null,
    frame_count: u64 = 0,

    // Previous frame for motion detection
    prev_frame: ?[]u8 = null,
    prev_frame_time: i64 = 0,

    // Platform-specific handle
    platform_handle: ?*anyopaque = null,

    pub fn init(allocator: std.mem.Allocator, config: MotionFrameConfig) MotionFrameProvider {
        return .{
            .allocator = allocator,
            .config = config,
        };
    }

    pub fn deinit(self: *MotionFrameProvider) void {
        if (self.running) {
            self.stop();
        }
        if (self.prev_frame) |frame| {
            self.allocator.free(frame);
            self.prev_frame = null;
        }
    }

    /// Start capturing motion frames
    pub fn start(self: *MotionFrameProvider, on_frame: FrameCallback) MotionError!void {
        if (self.running) return;

        self.frame_callback = on_frame;
        self.frame_count = 0;

        // Allocate previous frame buffer for motion detection
        if (self.config.detect_motion) {
            const size = @as(usize, self.config.resolution.getWidth()) *
                @as(usize, self.config.resolution.getHeight());
            self.prev_frame = self.allocator.alloc(u8, size) catch return MotionError.OutOfMemory;
            @memset(self.prev_frame.?, 0);
        }

        // Platform-specific camera start would happen here
        self.running = true;
    }

    /// Stop capturing
    pub fn stop(self: *MotionFrameProvider) void {
        if (!self.running) return;

        // Platform-specific camera stop would happen here
        self.running = false;
        self.frame_callback = null;

        if (self.prev_frame) |frame| {
            self.allocator.free(frame);
            self.prev_frame = null;
        }
    }

    /// Check if currently running
    pub fn isRunning(self: *const MotionFrameProvider) bool {
        return self.running;
    }

    /// Get current configuration
    pub fn getConfig(self: *const MotionFrameProvider) MotionFrameConfig {
        return self.config;
    }

    /// Update configuration (must stop and restart to apply)
    pub fn setConfig(self: *MotionFrameProvider, config: MotionFrameConfig) void {
        self.config = config;
    }

    /// Get frame count since start
    pub fn getFrameCount(self: *const MotionFrameProvider) u64 {
        return self.frame_count;
    }

    /// Process a frame (called by platform layer)
    pub fn processFrame(self: *MotionFrameProvider, data: []const u8, width: u16, height: u16) void {
        if (!self.running) return;
        if (self.frame_callback == null) return;

        const now = std.time.milliTimestamp();
        self.frame_count += 1;

        var frame = MotionFrame{
            .width = width,
            .height = height,
            .format = self.config.pixel_format,
            .data = data,
            .stride = @as(u32, width) * self.config.pixel_format.getBytesPerPixel(),
            .timestamp = now,
            .sequence = self.frame_count,
        };

        // Motion detection if enabled
        if (self.config.detect_motion and self.prev_frame != null) {
            const result = self.detectMotion(data, width, height);
            frame.motion_detected = result.detected;
            frame.motion_x = result.centroid_x;
            frame.motion_y = result.centroid_y;
            frame.motion_intensity = result.intensity;

            // Store current frame for next comparison
            if (data.len <= self.prev_frame.?.len) {
                @memcpy(self.prev_frame.?[0..data.len], data);
            }
        }

        self.prev_frame_time = now;

        // Invoke callback
        self.frame_callback.?(frame);
    }

    /// Detect motion between current and previous frame
    fn detectMotion(self: *MotionFrameProvider, current: []const u8, width: u16, height: u16) MotionResult {
        const prev = self.prev_frame orelse return .{
            .detected = false,
            .centroid_x = 0.0,
            .centroid_y = 0.0,
            .intensity = 0.0,
        };

        const len = @min(current.len, prev.len);

        if (len == 0) return .{
            .detected = false,
            .centroid_x = 0.0,
            .centroid_y = 0.0,
            .intensity = 0.0,
        };

        // Calculate motion
        var diff_sum: u64 = 0;
        var motion_pixels: u32 = 0;
        var centroid_x_sum: u64 = 0;
        var centroid_y_sum: u64 = 0;

        const threshold: u8 = @intFromFloat(255.0 * (1.0 - self.config.motion_sensitivity));

        for (0..len) |i| {
            const diff = if (current[i] > prev[i])
                current[i] - prev[i]
            else
                prev[i] - current[i];

            if (diff > threshold) {
                motion_pixels += 1;
                const x = i % width;
                const y = i / width;
                centroid_x_sum += x;
                centroid_y_sum += y;
            }
            diff_sum += diff;
        }

        const intensity = @as(f32, @floatFromInt(diff_sum)) / @as(f32, @floatFromInt(len * 255));
        const detected = motion_pixels > len / 100; // More than 1% of pixels changed

        var centroid_x: f32 = 0.5;
        var centroid_y: f32 = 0.5;

        if (motion_pixels > 0) {
            centroid_x = @as(f32, @floatFromInt(centroid_x_sum)) / @as(f32, @floatFromInt(motion_pixels)) / @as(f32, @floatFromInt(width));
            centroid_y = @as(f32, @floatFromInt(centroid_y_sum)) / @as(f32, @floatFromInt(motion_pixels)) / @as(f32, @floatFromInt(height));
        }

        return .{
            .detected = detected,
            .centroid_x = centroid_x,
            .centroid_y = centroid_y,
            .intensity = intensity,
        };
    }

    /// Check if motion capture is available on this platform
    pub fn isAvailable() bool {
        // Platform detection would happen here
        return false;
    }

    /// Get list of available cameras
    pub fn getAvailableCameras(allocator: std.mem.Allocator) ![]CameraInfo {
        // Platform-specific camera enumeration
        _ = allocator;
        return &.{};
    }

    /// Request camera permission
    pub fn requestPermission() !bool {
        // Platform-specific permission request
        return false;
    }
};

/// Convenience function to create a motion provider
pub fn createProvider(allocator: std.mem.Allocator, config: MotionFrameConfig) MotionFrameProvider {
    return MotionFrameProvider.init(allocator, config);
}

/// Convenience function with default config
pub fn createDefaultProvider(allocator: std.mem.Allocator) MotionFrameProvider {
    return MotionFrameProvider.init(allocator, .{});
}

// Tests
test "MotionFrameProvider initialization" {
    const allocator = std.testing.allocator;
    var provider = createDefaultProvider(allocator);
    defer provider.deinit();

    try std.testing.expect(!provider.isRunning());
    try std.testing.expectEqual(@as(u64, 0), provider.getFrameCount());
}

test "Resolution dimensions" {
    try std.testing.expectEqual(@as(u16, 80), Resolution.very_low.getWidth());
    try std.testing.expectEqual(@as(u16, 60), Resolution.very_low.getHeight());

    try std.testing.expectEqual(@as(u16, 160), Resolution.low.getWidth());
    try std.testing.expectEqual(@as(u16, 120), Resolution.low.getHeight());

    try std.testing.expectEqual(@as(u16, 320), Resolution.medium.getWidth());
    try std.testing.expectEqual(@as(u16, 240), Resolution.medium.getHeight());

    try std.testing.expectEqual(@as(u16, 640), Resolution.high.getWidth());
    try std.testing.expectEqual(@as(u16, 480), Resolution.high.getHeight());
}

test "PixelFormat bytes per pixel" {
    try std.testing.expectEqual(@as(u8, 1), PixelFormat.grayscale.getBytesPerPixel());
    try std.testing.expectEqual(@as(u8, 3), PixelFormat.rgb.getBytesPerPixel());
    try std.testing.expectEqual(@as(u8, 4), PixelFormat.rgba.getBytesPerPixel());
}

test "MotionFrame pixel access" {
    const data = [_]u8{ 10, 20, 30, 40, 50, 60 };
    const frame = MotionFrame{
        .width = 3,
        .height = 2,
        .format = .grayscale,
        .data = &data,
        .stride = 3,
        .timestamp = 0,
        .sequence = 0,
    };

    try std.testing.expectEqual(@as(u8, 10), frame.getPixel(0, 0).?);
    try std.testing.expectEqual(@as(u8, 30), frame.getPixel(2, 0).?);
    try std.testing.expectEqual(@as(u8, 40), frame.getPixel(0, 1).?);
    try std.testing.expect(frame.getPixel(3, 0) == null); // Out of bounds
}

test "MotionFrame average brightness" {
    const data = [_]u8{ 0, 128, 255 };
    const frame = MotionFrame{
        .width = 3,
        .height = 1,
        .format = .grayscale,
        .data = &data,
        .stride = 3,
        .timestamp = 0,
        .sequence = 0,
    };

    const avg = frame.getAverageBrightness();
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), avg, 0.01);
}

test "Configuration update" {
    const allocator = std.testing.allocator;
    var provider = createDefaultProvider(allocator);
    defer provider.deinit();

    try std.testing.expectEqual(Resolution.low, provider.getConfig().resolution);

    provider.setConfig(.{ .resolution = .high, .target_fps = 30 });
    try std.testing.expectEqual(Resolution.high, provider.getConfig().resolution);
    try std.testing.expectEqual(@as(u8, 30), provider.getConfig().target_fps);
}

test "Availability check" {
    try std.testing.expect(!MotionFrameProvider.isAvailable());
}
