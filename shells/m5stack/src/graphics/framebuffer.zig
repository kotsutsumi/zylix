//! Frame Buffer for M5Stack CoreS3
//!
//! RGB565 frame buffer management for ILI9342C display.
//! Supports full-frame and partial updates with DMA transfer.
//!
//! Memory Layout:
//! - Full frame: 320 x 240 x 2 = 153,600 bytes
//! - Double buffering: 307,200 bytes total
//! - Partial buffer option for memory-constrained scenarios

const std = @import("std");
const spi = @import("../hal/spi.zig");

/// Frame buffer error types
pub const FrameBufferError = error{
    OutOfMemory,
    InvalidDimensions,
    TransferFailed,
    NotInitialized,
};

/// Pixel format
pub const PixelFormat = enum {
    rgb565, // 16-bit RGB (5-6-5)
    rgb888, // 24-bit RGB (8-8-8)
    rgba8888, // 32-bit RGBA
};

/// Frame buffer configuration
pub const Config = struct {
    width: u16 = 320,
    height: u16 = 240,
    format: PixelFormat = .rgb565,
    double_buffer: bool = false,
    partial_height: ?u16 = null, // For memory-constrained mode
};

/// RGB565 Color type
pub const Color = u16;

/// RGB565 color utilities
pub const Colors = struct {
    pub const black: Color = 0x0000;
    pub const white: Color = 0xFFFF;
    pub const red: Color = 0xF800;
    pub const green: Color = 0x07E0;
    pub const blue: Color = 0x001F;
    pub const yellow: Color = 0xFFE0;
    pub const cyan: Color = 0x07FF;
    pub const magenta: Color = 0xF81F;
    pub const orange: Color = 0xFD20;
    pub const purple: Color = 0x8010;
    pub const gray: Color = 0x8410;
    pub const dark_gray: Color = 0x4208;
    pub const light_gray: Color = 0xC618;

    /// Convert RGB888 to RGB565
    pub fn fromRgb(r: u8, g: u8, b: u8) Color {
        const r5: u16 = @as(u16, r >> 3) << 11;
        const g6: u16 = @as(u16, g >> 2) << 5;
        const b5: u16 = @as(u16, b >> 3);
        return r5 | g6 | b5;
    }

    /// Convert RGB565 to RGB888 components
    pub fn toRgb(color: Color) struct { r: u8, g: u8, b: u8 } {
        return .{
            .r = @intCast((color >> 11) << 3),
            .g = @intCast(((color >> 5) & 0x3F) << 2),
            .b = @intCast((color & 0x1F) << 3),
        };
    }

    /// Convert RGBA to RGB565 with alpha blending against background
    pub fn fromRgba(r: u8, g: u8, b: u8, a: u8, background: Color) Color {
        if (a == 255) return fromRgb(r, g, b);
        if (a == 0) return background;

        const bg = toRgb(background);
        const alpha = @as(u16, a);
        const inv_alpha = 255 - alpha;

        const blended_r: u8 = @intCast((@as(u16, r) * alpha + @as(u16, bg.r) * inv_alpha) / 255);
        const blended_g: u8 = @intCast((@as(u16, g) * alpha + @as(u16, bg.g) * inv_alpha) / 255);
        const blended_b: u8 = @intCast((@as(u16, b) * alpha + @as(u16, bg.b) * inv_alpha) / 255);

        return fromRgb(blended_r, blended_g, blended_b);
    }

    /// Interpolate between two colors
    pub fn lerp(c1: Color, c2: Color, t: u8) Color {
        const rgb1 = toRgb(c1);
        const rgb2 = toRgb(c2);
        const t16 = @as(u16, t);
        const inv_t = 255 - t16;

        return fromRgb(
            @intCast((@as(u16, rgb1.r) * inv_t + @as(u16, rgb2.r) * t16) / 255),
            @intCast((@as(u16, rgb1.g) * inv_t + @as(u16, rgb2.g) * t16) / 255),
            @intCast((@as(u16, rgb1.b) * inv_t + @as(u16, rgb2.b) * t16) / 255),
        );
    }

    /// Swap bytes for big-endian display (ILI9342C expects big-endian)
    pub fn swapBytes(color: Color) Color {
        return @byteSwap(color);
    }
};

/// Dirty rectangle tracking for partial updates
pub const DirtyRect = struct {
    x: u16,
    y: u16,
    width: u16,
    height: u16,

    pub fn init() DirtyRect {
        return .{
            .x = 0xFFFF,
            .y = 0xFFFF,
            .width = 0,
            .height = 0,
        };
    }

    pub fn isEmpty(self: DirtyRect) bool {
        return self.width == 0 or self.height == 0;
    }

    pub fn reset(self: *DirtyRect) void {
        self.* = DirtyRect.init();
    }

    pub fn expand(self: *DirtyRect, x: u16, y: u16, w: u16, h: u16) void {
        if (w == 0 or h == 0) return;

        if (self.isEmpty()) {
            self.x = x;
            self.y = y;
            self.width = w;
            self.height = h;
            return;
        }

        const x2 = x + w;
        const y2 = y + h;
        const self_x2 = self.x + self.width;
        const self_y2 = self.y + self.height;

        const new_x = @min(self.x, x);
        const new_y = @min(self.y, y);
        const new_x2 = @max(self_x2, x2);
        const new_y2 = @max(self_y2, y2);

        self.x = new_x;
        self.y = new_y;
        self.width = new_x2 - new_x;
        self.height = new_y2 - new_y;
    }

    pub fn expandPoint(self: *DirtyRect, x: u16, y: u16) void {
        self.expand(x, y, 1, 1);
    }
};

/// Frame buffer
pub const FrameBuffer = struct {
    allocator: std.mem.Allocator,
    config: Config,
    buffer: []u8,
    back_buffer: ?[]u8 = null,
    front_is_first: bool = true,
    dirty: DirtyRect = DirtyRect.init(),
    stride: usize, // Bytes per row

    /// Initialize frame buffer
    pub fn init(allocator: std.mem.Allocator, config: Config) FrameBufferError!FrameBuffer {
        const height = config.partial_height orelse config.height;
        const bytes_per_pixel: usize = switch (config.format) {
            .rgb565 => 2,
            .rgb888 => 3,
            .rgba8888 => 4,
        };
        const stride = @as(usize, config.width) * bytes_per_pixel;
        const buffer_size = stride * height;

        const buffer = allocator.alloc(u8, buffer_size) catch {
            return FrameBufferError.OutOfMemory;
        };

        var back_buffer: ?[]u8 = null;
        if (config.double_buffer) {
            back_buffer = allocator.alloc(u8, buffer_size) catch {
                allocator.free(buffer);
                return FrameBufferError.OutOfMemory;
            };
        }

        var fb = FrameBuffer{
            .allocator = allocator,
            .config = config,
            .buffer = buffer,
            .back_buffer = back_buffer,
            .stride = stride,
        };

        fb.clear(Colors.black);
        return fb;
    }

    /// Deinitialize frame buffer
    pub fn deinit(self: *FrameBuffer) void {
        self.allocator.free(self.buffer);
        if (self.back_buffer) |bb| {
            self.allocator.free(bb);
        }
    }

    /// Get active buffer for drawing
    fn getDrawBuffer(self: *FrameBuffer) []u8 {
        if (self.back_buffer) |bb| {
            return if (self.front_is_first) bb else self.buffer;
        }
        return self.buffer;
    }

    /// Get buffer to display
    fn getDisplayBuffer(self: *FrameBuffer) []u8 {
        if (self.back_buffer != null) {
            return if (self.front_is_first) self.buffer else self.back_buffer.?;
        }
        return self.buffer;
    }

    /// Swap buffers (double buffering)
    pub fn swapBuffers(self: *FrameBuffer) void {
        if (self.back_buffer != null) {
            self.front_is_first = !self.front_is_first;
        }
    }

    /// Get pixel offset
    fn getOffset(self: *FrameBuffer, x: u16, y: u16) usize {
        return @as(usize, y) * self.stride + @as(usize, x) * 2; // RGB565 = 2 bytes
    }

    /// Set pixel at (x, y)
    pub fn setPixel(self: *FrameBuffer, x: u16, y: u16, color: Color) void {
        if (x >= self.config.width or y >= self.config.height) return;

        const offset = self.getOffset(x, y);
        const buf = self.getDrawBuffer();

        // Store as big-endian for ILI9342C
        const swapped = Colors.swapBytes(color);
        buf[offset] = @intCast(swapped >> 8);
        buf[offset + 1] = @intCast(swapped & 0xFF);

        self.dirty.expandPoint(x, y);
    }

    /// Get pixel at (x, y)
    pub fn getPixel(self: *FrameBuffer, x: u16, y: u16) Color {
        if (x >= self.config.width or y >= self.config.height) return 0;

        const offset = self.getOffset(x, y);
        const buf = self.getDrawBuffer();

        const hi = @as(u16, buf[offset]) << 8;
        const lo = @as(u16, buf[offset + 1]);
        return Colors.swapBytes(hi | lo);
    }

    /// Clear buffer with color
    pub fn clear(self: *FrameBuffer, color: Color) void {
        const buf = self.getDrawBuffer();
        const swapped = Colors.swapBytes(color);
        const hi: u8 = @intCast(swapped >> 8);
        const lo: u8 = @intCast(swapped & 0xFF);

        var i: usize = 0;
        while (i < buf.len) : (i += 2) {
            buf[i] = hi;
            buf[i + 1] = lo;
        }

        self.dirty.expand(0, 0, self.config.width, self.config.height);
    }

    /// Fill rectangle
    pub fn fillRect(self: *FrameBuffer, x: u16, y: u16, w: u16, h: u16, color: Color) void {
        const x2 = @min(x + w, self.config.width);
        const y2 = @min(y + h, self.config.height);

        if (x >= self.config.width or y >= self.config.height) return;

        const buf = self.getDrawBuffer();
        const swapped = Colors.swapBytes(color);
        const hi: u8 = @intCast(swapped >> 8);
        const lo: u8 = @intCast(swapped & 0xFF);

        var py = y;
        while (py < y2) : (py += 1) {
            var px = x;
            while (px < x2) : (px += 1) {
                const offset = self.getOffset(px, py);
                buf[offset] = hi;
                buf[offset + 1] = lo;
            }
        }

        self.dirty.expand(x, y, x2 - x, y2 - y);
    }

    /// Draw horizontal line
    pub fn hLine(self: *FrameBuffer, x: u16, y: u16, length: u16, color: Color) void {
        self.fillRect(x, y, length, 1, color);
    }

    /// Draw vertical line
    pub fn vLine(self: *FrameBuffer, x: u16, y: u16, length: u16, color: Color) void {
        self.fillRect(x, y, 1, length, color);
    }

    /// Get raw buffer for DMA transfer
    pub fn getRawBuffer(self: *FrameBuffer) []u8 {
        return self.getDisplayBuffer();
    }

    /// Get dirty region for partial update
    pub fn getDirtyRegion(self: *FrameBuffer) DirtyRect {
        return self.dirty;
    }

    /// Reset dirty tracking
    pub fn resetDirty(self: *FrameBuffer) void {
        self.dirty.reset();
    }

    /// Check if any region is dirty
    pub fn isDirty(self: *FrameBuffer) bool {
        return !self.dirty.isEmpty();
    }

    /// Copy region from source buffer
    pub fn blit(self: *FrameBuffer, src: []const u8, src_width: u16, dst_x: u16, dst_y: u16, w: u16, h: u16) void {
        const buf = self.getDrawBuffer();

        var sy: u16 = 0;
        while (sy < h and dst_y + sy < self.config.height) : (sy += 1) {
            var sx: u16 = 0;
            while (sx < w and dst_x + sx < self.config.width) : (sx += 1) {
                const src_offset = (@as(usize, sy) * @as(usize, src_width) + @as(usize, sx)) * 2;
                const dst_offset = self.getOffset(dst_x + sx, dst_y + sy);

                if (src_offset + 1 < src.len and dst_offset + 1 < buf.len) {
                    buf[dst_offset] = src[src_offset];
                    buf[dst_offset + 1] = src[src_offset + 1];
                }
            }
        }

        self.dirty.expand(dst_x, dst_y, w, h);
    }
};

// Tests
test "Colors.fromRgb" {
    try std.testing.expectEqual(Colors.white, Colors.fromRgb(255, 255, 255));
    try std.testing.expectEqual(Colors.black, Colors.fromRgb(0, 0, 0));
    try std.testing.expectEqual(Colors.red, Colors.fromRgb(255, 0, 0));
    try std.testing.expectEqual(Colors.green, Colors.fromRgb(0, 255, 0));
    try std.testing.expectEqual(Colors.blue, Colors.fromRgb(0, 0, 255));
}

test "Colors.swapBytes" {
    try std.testing.expectEqual(@as(Color, 0x0102), Colors.swapBytes(0x0201));
    try std.testing.expectEqual(@as(Color, 0xFFFF), Colors.swapBytes(0xFFFF));
}

test "DirtyRect operations" {
    var dirty = DirtyRect.init();
    try std.testing.expect(dirty.isEmpty());

    dirty.expand(10, 20, 30, 40);
    try std.testing.expect(!dirty.isEmpty());
    try std.testing.expectEqual(@as(u16, 10), dirty.x);
    try std.testing.expectEqual(@as(u16, 20), dirty.y);

    dirty.expand(5, 15, 50, 60);
    try std.testing.expectEqual(@as(u16, 5), dirty.x);
    try std.testing.expectEqual(@as(u16, 15), dirty.y);
}

test "FrameBuffer initialization" {
    const allocator = std.testing.allocator;
    var fb = try FrameBuffer.init(allocator, .{});
    defer fb.deinit();

    try std.testing.expectEqual(@as(u16, 320), fb.config.width);
    try std.testing.expectEqual(@as(u16, 240), fb.config.height);
    try std.testing.expectEqual(@as(usize, 640), fb.stride);
}
