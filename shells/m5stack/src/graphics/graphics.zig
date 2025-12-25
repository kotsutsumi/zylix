//! Graphics Primitives for M5Stack CoreS3
//!
//! 2D graphics rendering primitives including lines, circles,
//! arcs, polygons, and text rendering support.
//!
//! All drawing operations work with the frame buffer and support
//! anti-aliasing options where applicable.

const std = @import("std");
const fb = @import("framebuffer.zig");
const Color = fb.Color;
const Colors = fb.Colors;
const FrameBuffer = fb.FrameBuffer;

/// Graphics error types
pub const GraphicsError = error{
    InvalidParameter,
    OutOfBounds,
    FontNotLoaded,
};

/// Point structure
pub const Point = struct {
    x: i32,
    y: i32,

    pub fn init(x: i32, y: i32) Point {
        return .{ .x = x, .y = y };
    }

    pub fn add(self: Point, other: Point) Point {
        return .{ .x = self.x + other.x, .y = self.y + other.y };
    }

    pub fn sub(self: Point, other: Point) Point {
        return .{ .x = self.x - other.x, .y = self.y - other.y };
    }
};

/// Rectangle structure
pub const Rect = struct {
    x: i32,
    y: i32,
    width: u16,
    height: u16,

    pub fn init(x: i32, y: i32, width: u16, height: u16) Rect {
        return .{ .x = x, .y = y, .width = width, .height = height };
    }

    pub fn contains(self: Rect, p: Point) bool {
        return p.x >= self.x and p.x < self.x + @as(i32, self.width) and
            p.y >= self.y and p.y < self.y + @as(i32, self.height);
    }

    pub fn intersects(self: Rect, other: Rect) bool {
        return self.x < other.x + @as(i32, other.width) and
            self.x + @as(i32, self.width) > other.x and
            self.y < other.y + @as(i32, other.height) and
            self.y + @as(i32, self.height) > other.y;
    }
};

/// Line style
pub const LineStyle = enum {
    solid,
    dashed,
    dotted,
};

/// Draw options
pub const DrawOptions = struct {
    line_style: LineStyle = .solid,
    line_width: u8 = 1,
    anti_alias: bool = false,
    dash_length: u8 = 4,
    gap_length: u8 = 2,
};

/// Graphics context for drawing operations
pub const Graphics = struct {
    frame_buffer: *FrameBuffer,
    clip_rect: ?Rect = null,
    options: DrawOptions = .{},

    /// Create graphics context from frame buffer
    pub fn init(frame_buffer: *FrameBuffer) Graphics {
        return .{
            .frame_buffer = frame_buffer,
        };
    }

    /// Set clipping rectangle
    pub fn setClipRect(self: *Graphics, rect: ?Rect) void {
        self.clip_rect = rect;
    }

    /// Set draw options
    pub fn setOptions(self: *Graphics, options: DrawOptions) void {
        self.options = options;
    }

    /// Check if point is within bounds and clip rect
    fn isVisible(self: *Graphics, x: i32, y: i32) bool {
        if (x < 0 or y < 0) return false;
        if (x >= self.frame_buffer.config.width or y >= self.frame_buffer.config.height) return false;

        if (self.clip_rect) |clip| {
            return clip.contains(Point.init(x, y));
        }
        return true;
    }

    /// Draw a single pixel with bounds checking
    pub fn drawPixel(self: *Graphics, x: i32, y: i32, color: Color) void {
        if (self.isVisible(x, y)) {
            self.frame_buffer.setPixel(@intCast(x), @intCast(y), color);
        }
    }

    /// Draw a line using Bresenham's algorithm
    pub fn drawLine(self: *Graphics, x0: i32, y0: i32, x1: i32, y1: i32, color: Color) void {
        if (self.options.line_width > 1) {
            self.drawThickLine(x0, y0, x1, y1, color);
            return;
        }

        var px0 = x0;
        var py0 = y0;
        const px1 = x1;
        const py1 = y1;

        const dx = @abs(px1 - px0);
        const dy = @abs(py1 - py0);
        const sx: i32 = if (px0 < px1) 1 else -1;
        const sy: i32 = if (py0 < py1) 1 else -1;
        var err = @as(i32, @intCast(dx)) - @as(i32, @intCast(dy));

        var step: u32 = 0;
        const dash_cycle = @as(u32, self.options.dash_length) + @as(u32, self.options.gap_length);

        while (true) {
            const should_draw = switch (self.options.line_style) {
                .solid => true,
                .dashed => (step % dash_cycle) < self.options.dash_length,
                .dotted => (step % 2) == 0,
            };

            if (should_draw) {
                self.drawPixel(px0, py0, color);
            }

            if (px0 == px1 and py0 == py1) break;

            const e2 = err * 2;
            if (e2 > -@as(i32, @intCast(dy))) {
                err -= @as(i32, @intCast(dy));
                px0 += sx;
            }
            if (e2 < @as(i32, @intCast(dx))) {
                err += @as(i32, @intCast(dx));
                py0 += sy;
            }
            step += 1;
        }
    }

    /// Draw a thick line
    fn drawThickLine(self: *Graphics, x0: i32, y0: i32, x1: i32, y1: i32, color: Color) void {
        const width = self.options.line_width;
        const half_width = @as(i32, width / 2);

        // Calculate line direction
        const dx = x1 - x0;
        const dy = y1 - y0;
        const length = @sqrt(@as(f32, @floatFromInt(dx * dx + dy * dy)));

        if (length < 0.001) {
            // Point-like line, draw a filled circle
            self.fillCircle(x0, y0, half_width, color);
            return;
        }

        // Perpendicular direction
        const px = @as(f32, @floatFromInt(-dy)) / length;
        const py = @as(f32, @floatFromInt(dx)) / length;

        // Draw parallel lines
        var offset: i32 = -half_width;
        while (offset <= half_width) : (offset += 1) {
            const ox = @as(i32, @intFromFloat(px * @as(f32, @floatFromInt(offset))));
            const oy = @as(i32, @intFromFloat(py * @as(f32, @floatFromInt(offset))));

            // Temporarily set line width to 1 for inner draws
            const saved_width = self.options.line_width;
            self.options.line_width = 1;
            self.drawLine(x0 + ox, y0 + oy, x1 + ox, y1 + oy, color);
            self.options.line_width = saved_width;
        }
    }

    /// Draw horizontal line (optimized)
    pub fn drawHLine(self: *Graphics, x: i32, y: i32, length: u16, color: Color) void {
        if (y < 0 or y >= self.frame_buffer.config.height) return;

        var start_x = x;
        var len = length;

        // Clip to bounds
        if (start_x < 0) {
            if (-start_x >= length) return;
            len -= @intCast(-start_x);
            start_x = 0;
        }

        const end_x = start_x + @as(i32, len);
        if (end_x > self.frame_buffer.config.width) {
            len = @intCast(self.frame_buffer.config.width - @as(u16, @intCast(start_x)));
        }

        // Apply clip rect
        if (self.clip_rect) |clip| {
            if (y < clip.y or y >= clip.y + @as(i32, clip.height)) return;
            if (start_x < clip.x) {
                const diff = clip.x - start_x;
                if (diff >= len) return;
                len -= @intCast(diff);
                start_x = clip.x;
            }
            const clip_end = clip.x + @as(i32, clip.width);
            if (start_x + @as(i32, len) > clip_end) {
                len = @intCast(clip_end - start_x);
            }
        }

        self.frame_buffer.hLine(@intCast(start_x), @intCast(y), len, color);
    }

    /// Draw vertical line (optimized)
    pub fn drawVLine(self: *Graphics, x: i32, y: i32, length: u16, color: Color) void {
        if (x < 0 or x >= self.frame_buffer.config.width) return;

        var start_y = y;
        var len = length;

        // Clip to bounds
        if (start_y < 0) {
            if (-start_y >= length) return;
            len -= @intCast(-start_y);
            start_y = 0;
        }

        const end_y = start_y + @as(i32, len);
        if (end_y > self.frame_buffer.config.height) {
            len = @intCast(self.frame_buffer.config.height - @as(u16, @intCast(start_y)));
        }

        // Apply clip rect
        if (self.clip_rect) |clip| {
            if (x < clip.x or x >= clip.x + @as(i32, clip.width)) return;
            if (start_y < clip.y) {
                const diff = clip.y - start_y;
                if (diff >= len) return;
                len -= @intCast(diff);
                start_y = clip.y;
            }
            const clip_end = clip.y + @as(i32, clip.height);
            if (start_y + @as(i32, len) > clip_end) {
                len = @intCast(clip_end - start_y);
            }
        }

        self.frame_buffer.vLine(@intCast(x), @intCast(start_y), len, color);
    }

    /// Draw rectangle outline
    pub fn drawRect(self: *Graphics, x: i32, y: i32, width: u16, height: u16, color: Color) void {
        if (width == 0 or height == 0) return;

        self.drawHLine(x, y, width, color);
        self.drawHLine(x, y + @as(i32, height) - 1, width, color);
        self.drawVLine(x, y, height, color);
        self.drawVLine(x + @as(i32, width) - 1, y, height, color);
    }

    /// Fill rectangle
    pub fn fillRect(self: *Graphics, x: i32, y: i32, width: u16, height: u16, color: Color) void {
        if (width == 0 or height == 0) return;

        // Simple implementation using frame buffer's fillRect
        if (x >= 0 and y >= 0 and self.clip_rect == null) {
            self.frame_buffer.fillRect(@intCast(x), @intCast(y), width, height, color);
            return;
        }

        // Clipped version
        var py = y;
        const end_y = y + @as(i32, height);
        while (py < end_y) : (py += 1) {
            self.drawHLine(x, py, width, color);
        }
    }

    /// Draw rounded rectangle outline
    pub fn drawRoundRect(self: *Graphics, x: i32, y: i32, width: u16, height: u16, radius: u16, color: Color) void {
        if (width == 0 or height == 0) return;

        const r = @min(radius, @min(width / 2, height / 2));
        const w = @as(i32, width);
        const h = @as(i32, height);
        const ri = @as(i32, r);

        // Draw straight edges
        self.drawHLine(x + ri, y, width - r * 2, color);
        self.drawHLine(x + ri, y + h - 1, width - r * 2, color);
        self.drawVLine(x, y + ri, height - r * 2, color);
        self.drawVLine(x + w - 1, y + ri, height - r * 2, color);

        // Draw corners
        self.drawCircleQuadrant(x + ri, y + ri, r, 0b0001, color);
        self.drawCircleQuadrant(x + w - ri - 1, y + ri, r, 0b0010, color);
        self.drawCircleQuadrant(x + w - ri - 1, y + h - ri - 1, r, 0b0100, color);
        self.drawCircleQuadrant(x + ri, y + h - ri - 1, r, 0b1000, color);
    }

    /// Fill rounded rectangle
    pub fn fillRoundRect(self: *Graphics, x: i32, y: i32, width: u16, height: u16, radius: u16, color: Color) void {
        if (width == 0 or height == 0) return;

        const r = @min(radius, @min(width / 2, height / 2));
        const h = @as(i32, height);
        const ri = @as(i32, r);

        // Fill center rectangle
        self.fillRect(x, y + ri, width, height - r * 2, color);

        // Fill top and bottom rectangles
        self.fillRect(x + ri, y, width - r * 2, r, color);
        self.fillRect(x + ri, y + h - ri, width - r * 2, r, color);

        // Fill corners
        self.fillCircleQuadrant(x + ri, y + ri, r, 0b0001, color);
        self.fillCircleQuadrant(x + @as(i32, width) - ri - 1, y + ri, r, 0b0010, color);
        self.fillCircleQuadrant(x + @as(i32, width) - ri - 1, y + h - ri - 1, r, 0b0100, color);
        self.fillCircleQuadrant(x + ri, y + h - ri - 1, r, 0b1000, color);
    }

    /// Draw circle using midpoint algorithm
    pub fn drawCircle(self: *Graphics, cx: i32, cy: i32, radius: u16, color: Color) void {
        if (radius == 0) {
            self.drawPixel(cx, cy, color);
            return;
        }

        var x: i32 = 0;
        var y: i32 = @as(i32, radius);
        var d: i32 = 1 - @as(i32, radius);

        while (x <= y) {
            self.drawPixel(cx + x, cy + y, color);
            self.drawPixel(cx - x, cy + y, color);
            self.drawPixel(cx + x, cy - y, color);
            self.drawPixel(cx - x, cy - y, color);
            self.drawPixel(cx + y, cy + x, color);
            self.drawPixel(cx - y, cy + x, color);
            self.drawPixel(cx + y, cy - x, color);
            self.drawPixel(cx - y, cy - x, color);

            if (d < 0) {
                d += 2 * x + 3;
            } else {
                d += 2 * (x - y) + 5;
                y -= 1;
            }
            x += 1;
        }
    }

    /// Fill circle
    pub fn fillCircle(self: *Graphics, cx: i32, cy: i32, radius: i32, color: Color) void {
        if (radius <= 0) {
            self.drawPixel(cx, cy, color);
            return;
        }

        var x: i32 = 0;
        var y: i32 = radius;
        var d: i32 = 1 - radius;

        while (x <= y) {
            self.drawHLine(cx - x, cy + y, @intCast(x * 2 + 1), color);
            self.drawHLine(cx - x, cy - y, @intCast(x * 2 + 1), color);
            self.drawHLine(cx - y, cy + x, @intCast(y * 2 + 1), color);
            self.drawHLine(cx - y, cy - x, @intCast(y * 2 + 1), color);

            if (d < 0) {
                d += 2 * x + 3;
            } else {
                d += 2 * (x - y) + 5;
                y -= 1;
            }
            x += 1;
        }
    }

    /// Draw circle quadrant (for rounded rectangles)
    /// quadrants: bit 0 = top-left, bit 1 = top-right, bit 2 = bottom-right, bit 3 = bottom-left
    fn drawCircleQuadrant(self: *Graphics, cx: i32, cy: i32, radius: u16, quadrants: u4, color: Color) void {
        var x: i32 = 0;
        var y: i32 = @as(i32, radius);
        var d: i32 = 1 - @as(i32, radius);

        while (x <= y) {
            if (quadrants & 0b0001 != 0) { // Top-left
                self.drawPixel(cx - x, cy - y, color);
                self.drawPixel(cx - y, cy - x, color);
            }
            if (quadrants & 0b0010 != 0) { // Top-right
                self.drawPixel(cx + x, cy - y, color);
                self.drawPixel(cx + y, cy - x, color);
            }
            if (quadrants & 0b0100 != 0) { // Bottom-right
                self.drawPixel(cx + x, cy + y, color);
                self.drawPixel(cx + y, cy + x, color);
            }
            if (quadrants & 0b1000 != 0) { // Bottom-left
                self.drawPixel(cx - x, cy + y, color);
                self.drawPixel(cx - y, cy + x, color);
            }

            if (d < 0) {
                d += 2 * x + 3;
            } else {
                d += 2 * (x - y) + 5;
                y -= 1;
            }
            x += 1;
        }
    }

    /// Fill circle quadrant
    fn fillCircleQuadrant(self: *Graphics, cx: i32, cy: i32, radius: u16, quadrants: u4, color: Color) void {
        var x: i32 = 0;
        var y: i32 = @as(i32, radius);
        var d: i32 = 1 - @as(i32, radius);

        while (x <= y) {
            if (quadrants & 0b0001 != 0) { // Top-left
                self.drawHLine(cx - x, cy - y, @intCast(x + 1), color);
                self.drawHLine(cx - y, cy - x, @intCast(y + 1), color);
            }
            if (quadrants & 0b0010 != 0) { // Top-right
                self.drawHLine(cx, cy - y, @intCast(x + 1), color);
                self.drawHLine(cx, cy - x, @intCast(y + 1), color);
            }
            if (quadrants & 0b0100 != 0) { // Bottom-right
                self.drawHLine(cx, cy + y, @intCast(x + 1), color);
                self.drawHLine(cx, cy + x, @intCast(y + 1), color);
            }
            if (quadrants & 0b1000 != 0) { // Bottom-left
                self.drawHLine(cx - x, cy + y, @intCast(x + 1), color);
                self.drawHLine(cx - y, cy + x, @intCast(y + 1), color);
            }

            if (d < 0) {
                d += 2 * x + 3;
            } else {
                d += 2 * (x - y) + 5;
                y -= 1;
            }
            x += 1;
        }
    }

    /// Draw arc (portion of circle)
    pub fn drawArc(self: *Graphics, cx: i32, cy: i32, radius: u16, start_angle: f32, end_angle: f32, color: Color) void {
        const steps = @max(16, radius * 2);
        const angle_range = end_angle - start_angle;
        const step_angle = angle_range / @as(f32, @floatFromInt(steps));

        var prev_x: ?i32 = null;
        var prev_y: ?i32 = null;
        var angle = start_angle;

        var i: u32 = 0;
        while (i <= steps) : (i += 1) {
            const rad = angle * std.math.pi / 180.0;
            const px = cx + @as(i32, @intFromFloat(@cos(rad) * @as(f32, @floatFromInt(radius))));
            const py = cy + @as(i32, @intFromFloat(@sin(rad) * @as(f32, @floatFromInt(radius))));

            if (prev_x) |px0| {
                if (prev_y) |py0| {
                    self.drawLine(px0, py0, px, py, color);
                }
            }

            prev_x = px;
            prev_y = py;
            angle += step_angle;
        }
    }

    /// Draw ellipse
    pub fn drawEllipse(self: *Graphics, cx: i32, cy: i32, rx: u16, ry: u16, color: Color) void {
        if (rx == 0 or ry == 0) return;

        var x: i32 = 0;
        var y: i32 = @as(i32, ry);

        const rx2 = @as(i64, rx) * @as(i64, rx);
        const ry2 = @as(i64, ry) * @as(i64, ry);

        var px: i64 = 0;
        var py: i64 = 2 * rx2 * y;

        // Region 1
        var p: i64 = ry2 - rx2 * @as(i64, ry) + rx2 / 4;

        while (px < py) {
            self.drawPixel(cx + x, cy + y, color);
            self.drawPixel(cx - x, cy + y, color);
            self.drawPixel(cx + x, cy - y, color);
            self.drawPixel(cx - x, cy - y, color);

            x += 1;
            px += 2 * ry2;

            if (p < 0) {
                p += ry2 + px;
            } else {
                y -= 1;
                py -= 2 * rx2;
                p += ry2 + px - py;
            }
        }

        // Region 2
        p = ry2 * (x * x + x) + rx2 * (y - 1) * (y - 1) - rx2 * ry2;

        while (y >= 0) {
            self.drawPixel(cx + x, cy + y, color);
            self.drawPixel(cx - x, cy + y, color);
            self.drawPixel(cx + x, cy - y, color);
            self.drawPixel(cx - x, cy - y, color);

            y -= 1;
            py -= 2 * rx2;

            if (p > 0) {
                p += rx2 - py;
            } else {
                x += 1;
                px += 2 * ry2;
                p += rx2 - py + px;
            }
        }
    }

    /// Fill ellipse
    pub fn fillEllipse(self: *Graphics, cx: i32, cy: i32, rx: u16, ry: u16, color: Color) void {
        if (rx == 0 or ry == 0) return;

        var x: i32 = 0;
        var y: i32 = @as(i32, ry);

        const rx2 = @as(i64, rx) * @as(i64, rx);
        const ry2 = @as(i64, ry) * @as(i64, ry);

        var px: i64 = 0;
        var py: i64 = 2 * rx2 * y;

        // Region 1
        var p: i64 = ry2 - rx2 * @as(i64, ry) + rx2 / 4;
        var last_y = y;

        while (px < py) {
            if (y != last_y) {
                self.drawHLine(cx - x + 1, cy + last_y, @intCast((x - 1) * 2 + 1), color);
                self.drawHLine(cx - x + 1, cy - last_y, @intCast((x - 1) * 2 + 1), color);
                last_y = y;
            }

            x += 1;
            px += 2 * ry2;

            if (p < 0) {
                p += ry2 + px;
            } else {
                y -= 1;
                py -= 2 * rx2;
                p += ry2 + px - py;
            }
        }

        // Draw remaining scanlines
        self.drawHLine(cx - x, cy + y, @intCast(x * 2 + 1), color);
        self.drawHLine(cx - x, cy - y, @intCast(x * 2 + 1), color);

        // Region 2
        p = ry2 * (x * x + x) + rx2 * (y - 1) * (y - 1) - rx2 * ry2;

        while (y >= 0) {
            self.drawHLine(cx - x, cy + y, @intCast(x * 2 + 1), color);
            self.drawHLine(cx - x, cy - y, @intCast(x * 2 + 1), color);

            y -= 1;
            py -= 2 * rx2;

            if (p > 0) {
                p += rx2 - py;
            } else {
                x += 1;
                px += 2 * ry2;
                p += rx2 - py + px;
            }
        }
    }

    /// Draw triangle outline
    pub fn drawTriangle(self: *Graphics, x0: i32, y0: i32, x1: i32, y1: i32, x2: i32, y2: i32, color: Color) void {
        self.drawLine(x0, y0, x1, y1, color);
        self.drawLine(x1, y1, x2, y2, color);
        self.drawLine(x2, y2, x0, y0, color);
    }

    /// Fill triangle using scanline algorithm
    pub fn fillTriangle(self: *Graphics, x0: i32, y0: i32, x1: i32, y1: i32, x2: i32, y2: i32, color: Color) void {
        // Sort vertices by y coordinate
        var vx0 = x0;
        var vy0 = y0;
        var vx1 = x1;
        var vy1 = y1;
        var vx2 = x2;
        var vy2 = y2;

        if (vy0 > vy1) {
            std.mem.swap(i32, &vx0, &vx1);
            std.mem.swap(i32, &vy0, &vy1);
        }
        if (vy1 > vy2) {
            std.mem.swap(i32, &vx1, &vx2);
            std.mem.swap(i32, &vy1, &vy2);
        }
        if (vy0 > vy1) {
            std.mem.swap(i32, &vx0, &vx1);
            std.mem.swap(i32, &vy0, &vy1);
        }

        if (vy0 == vy2) {
            // Degenerate triangle (all on same line)
            var minx = @min(@min(vx0, vx1), vx2);
            var maxx = @max(@max(vx0, vx1), vx2);
            if (maxx >= minx) {
                self.drawHLine(minx, vy0, @intCast(maxx - minx + 1), color);
            }
            return;
        }

        // Calculate interpolation
        const total_height = vy2 - vy0;

        var y = vy0;
        while (y <= vy2) : (y += 1) {
            const second_half = y > vy1 or vy1 == vy0;
            const segment_height = if (second_half) vy2 - vy1 else vy1 - vy0;

            if (segment_height == 0) continue;

            const alpha = @as(f32, @floatFromInt(y - vy0)) / @as(f32, @floatFromInt(total_height));
            const beta = if (second_half)
                @as(f32, @floatFromInt(y - vy1)) / @as(f32, @floatFromInt(segment_height))
            else
                @as(f32, @floatFromInt(y - vy0)) / @as(f32, @floatFromInt(segment_height));

            var ax = vx0 + @as(i32, @intFromFloat(@as(f32, @floatFromInt(vx2 - vx0)) * alpha));
            var bx = if (second_half)
                vx1 + @as(i32, @intFromFloat(@as(f32, @floatFromInt(vx2 - vx1)) * beta))
            else
                vx0 + @as(i32, @intFromFloat(@as(f32, @floatFromInt(vx1 - vx0)) * beta));

            if (ax > bx) std.mem.swap(i32, &ax, &bx);

            self.drawHLine(ax, y, @intCast(bx - ax + 1), color);
        }
    }

    /// Draw polygon outline
    pub fn drawPolygon(self: *Graphics, points: []const Point, color: Color) void {
        if (points.len < 2) return;

        var i: usize = 0;
        while (i < points.len) : (i += 1) {
            const p0 = points[i];
            const p1 = points[(i + 1) % points.len];
            self.drawLine(p0.x, p0.y, p1.x, p1.y, color);
        }
    }

    /// Draw quadratic Bezier curve
    pub fn drawQuadBezier(self: *Graphics, x0: i32, y0: i32, x1: i32, y1: i32, x2: i32, y2: i32, color: Color) void {
        const steps: u32 = 32;

        var prev_x = x0;
        var prev_y = y0;

        var i: u32 = 1;
        while (i <= steps) : (i += 1) {
            const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(steps));
            const t2 = t * t;
            const mt = 1.0 - t;
            const mt2 = mt * mt;

            const px0 = @as(f32, @floatFromInt(x0));
            const py0 = @as(f32, @floatFromInt(y0));
            const px1 = @as(f32, @floatFromInt(x1));
            const py1 = @as(f32, @floatFromInt(y1));
            const px2 = @as(f32, @floatFromInt(x2));
            const py2 = @as(f32, @floatFromInt(y2));

            const x = @as(i32, @intFromFloat(mt2 * px0 + 2.0 * mt * t * px1 + t2 * px2));
            const y = @as(i32, @intFromFloat(mt2 * py0 + 2.0 * mt * t * py1 + t2 * py2));

            self.drawLine(prev_x, prev_y, x, y, color);
            prev_x = x;
            prev_y = y;
        }
    }

    /// Draw cubic Bezier curve
    pub fn drawCubicBezier(self: *Graphics, x0: i32, y0: i32, x1: i32, y1: i32, x2: i32, y2: i32, x3: i32, y3: i32, color: Color) void {
        const steps: u32 = 48;

        var prev_x = x0;
        var prev_y = y0;

        var i: u32 = 1;
        while (i <= steps) : (i += 1) {
            const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(steps));
            const t2 = t * t;
            const t3 = t2 * t;
            const mt = 1.0 - t;
            const mt2 = mt * mt;
            const mt3 = mt2 * mt;

            const px0 = @as(f32, @floatFromInt(x0));
            const py0 = @as(f32, @floatFromInt(y0));
            const px1 = @as(f32, @floatFromInt(x1));
            const py1 = @as(f32, @floatFromInt(y1));
            const px2 = @as(f32, @floatFromInt(x2));
            const py2 = @as(f32, @floatFromInt(y2));
            const px3 = @as(f32, @floatFromInt(x3));
            const py3 = @as(f32, @floatFromInt(y3));

            const x = @as(i32, @intFromFloat(mt3 * px0 + 3.0 * mt2 * t * px1 + 3.0 * mt * t2 * px2 + t3 * px3));
            const y = @as(i32, @intFromFloat(mt3 * py0 + 3.0 * mt2 * t * py1 + 3.0 * mt * t2 * py2 + t3 * py3));

            self.drawLine(prev_x, prev_y, x, y, color);
            prev_x = x;
            prev_y = y;
        }
    }
};

/// Bitmap font for text rendering
pub const BitmapFont = struct {
    data: []const u8,
    char_width: u8,
    char_height: u8,
    first_char: u8 = 32, // Space
    char_count: u8 = 95, // ASCII printable

    /// Get glyph data for character
    pub fn getGlyph(self: *const BitmapFont, char: u8) ?[]const u8 {
        if (char < self.first_char) return null;
        const idx = char - self.first_char;
        if (idx >= self.char_count) return null;

        const bytes_per_char = (@as(usize, self.char_width) + 7) / 8 * self.char_height;
        const start = @as(usize, idx) * bytes_per_char;
        const end = start + bytes_per_char;

        if (end > self.data.len) return null;
        return self.data[start..end];
    }
};

/// Text rendering utilities
pub const TextRenderer = struct {
    graphics: *Graphics,
    font: *const BitmapFont,
    color: Color = Colors.white,
    bg_color: ?Color = null,
    scale: u8 = 1,

    /// Create text renderer
    pub fn init(graphics: *Graphics, font: *const BitmapFont) TextRenderer {
        return .{
            .graphics = graphics,
            .font = font,
        };
    }

    /// Draw single character
    pub fn drawChar(self: *TextRenderer, x: i32, y: i32, char: u8) void {
        const glyph = self.font.getGlyph(char) orelse return;
        const bytes_per_row = (@as(usize, self.font.char_width) + 7) / 8;

        var py: u8 = 0;
        while (py < self.font.char_height) : (py += 1) {
            var px: u8 = 0;
            while (px < self.font.char_width) : (px += 1) {
                const byte_idx = @as(usize, py) * bytes_per_row + @as(usize, px) / 8;
                const bit_idx: u3 = @intCast(7 - (px % 8));
                const is_set = (glyph[byte_idx] >> bit_idx) & 1 != 0;

                const draw_x = x + @as(i32, px) * @as(i32, self.scale);
                const draw_y = y + @as(i32, py) * @as(i32, self.scale);

                if (is_set) {
                    if (self.scale == 1) {
                        self.graphics.drawPixel(draw_x, draw_y, self.color);
                    } else {
                        self.graphics.fillRect(draw_x, draw_y, self.scale, self.scale, self.color);
                    }
                } else if (self.bg_color) |bg| {
                    if (self.scale == 1) {
                        self.graphics.drawPixel(draw_x, draw_y, bg);
                    } else {
                        self.graphics.fillRect(draw_x, draw_y, self.scale, self.scale, bg);
                    }
                }
            }
        }
    }

    /// Draw string
    pub fn drawString(self: *TextRenderer, x: i32, y: i32, text: []const u8) void {
        const char_advance = @as(i32, self.font.char_width) * @as(i32, self.scale);
        var cx = x;

        for (text) |char| {
            if (char == '\n') {
                cx = x;
                continue;
            }
            self.drawChar(cx, y, char);
            cx += char_advance;
        }
    }

    /// Get string width in pixels
    pub fn getStringWidth(self: *const TextRenderer, text: []const u8) u32 {
        var max_width: u32 = 0;
        var current_width: u32 = 0;

        for (text) |char| {
            if (char == '\n') {
                max_width = @max(max_width, current_width);
                current_width = 0;
            } else {
                current_width += @as(u32, self.font.char_width) * @as(u32, self.scale);
            }
        }

        return @max(max_width, current_width);
    }

    /// Get string height in pixels
    pub fn getStringHeight(self: *const TextRenderer, text: []const u8) u32 {
        var lines: u32 = 1;
        for (text) |char| {
            if (char == '\n') lines += 1;
        }
        return lines * @as(u32, self.font.char_height) * @as(u32, self.scale);
    }
};

// Built-in 5x7 font (minimal ASCII subset for testing)
pub const font_5x7 = BitmapFont{
    .data = &[_]u8{
        // Space (32)
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        // ! (33)
        0x04, 0x04, 0x04, 0x04, 0x00, 0x04, 0x00,
        // " (34)
        0x0A, 0x0A, 0x00, 0x00, 0x00, 0x00, 0x00,
        // # (35)
        0x0A, 0x1F, 0x0A, 0x1F, 0x0A, 0x00, 0x00,
        // $ (36)
        0x04, 0x0F, 0x14, 0x0E, 0x05, 0x1E, 0x04,
        // More characters would be added here...
    },
    .char_width = 5,
    .char_height = 7,
    .first_char = 32,
    .char_count = 5, // Only 5 chars in this minimal set
};

// Tests
test "Point operations" {
    const p1 = Point.init(10, 20);
    const p2 = Point.init(5, 10);

    const sum = p1.add(p2);
    try std.testing.expectEqual(@as(i32, 15), sum.x);
    try std.testing.expectEqual(@as(i32, 30), sum.y);

    const diff = p1.sub(p2);
    try std.testing.expectEqual(@as(i32, 5), diff.x);
    try std.testing.expectEqual(@as(i32, 10), diff.y);
}

test "Rect contains" {
    const rect = Rect.init(10, 20, 100, 50);

    try std.testing.expect(rect.contains(Point.init(50, 40)));
    try std.testing.expect(!rect.contains(Point.init(5, 40)));
    try std.testing.expect(!rect.contains(Point.init(50, 100)));
}

test "Rect intersects" {
    const rect1 = Rect.init(0, 0, 100, 100);
    const rect2 = Rect.init(50, 50, 100, 100);
    const rect3 = Rect.init(200, 200, 50, 50);

    try std.testing.expect(rect1.intersects(rect2));
    try std.testing.expect(!rect1.intersects(rect3));
}

test "Graphics initialization" {
    const allocator = std.testing.allocator;
    var frame_buffer = try fb.FrameBuffer.init(allocator, .{});
    defer frame_buffer.deinit();

    var gfx = Graphics.init(&frame_buffer);
    try std.testing.expect(gfx.clip_rect == null);
}

test "BitmapFont getGlyph" {
    // Test that we can get glyph for space
    const glyph = font_5x7.getGlyph(' ');
    try std.testing.expect(glyph != null);
    try std.testing.expectEqual(@as(usize, 7), glyph.?.len);

    // Test out of range
    const invalid = font_5x7.getGlyph(0);
    try std.testing.expect(invalid == null);
}
