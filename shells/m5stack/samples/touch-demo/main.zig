//! Touch Demo Sample for M5Stack CoreS3
//!
//! Demonstrates touch input and gesture recognition.
//! Features drawing canvas, gesture display, and multi-touch visualization.

const std = @import("std");
const platform = @import("../../src/platform/mod.zig");
const ui = @import("../../src/ui/mod.zig");
const touch_input = @import("../../src/touch/input.zig");
const gesture_mod = @import("../../src/touch/gesture.zig");

const Theme = ui.Theme;
const Color = platform.Color;

/// Touch point for trail visualization
const TouchPoint = struct {
    x: i32,
    y: i32,
    age: u16, // Frames since created
};

/// Touch demo application state
const TouchDemoApp = struct {
    // Current touch state
    current_touch: ?touch_input.Touch = null,
    touch_count: u8 = 0,

    // Touch trail for drawing effect
    trail: [64]?TouchPoint = [_]?TouchPoint{null} ** 64,
    trail_head: usize = 0,

    // Last gesture detected
    last_gesture: ?gesture_mod.GestureType = null,
    gesture_display_time: u16 = 0,

    // Drawing mode
    draw_color: u16 = 0xF800, // Red
    brush_size: u8 = 4,

    // Canvas (simplified - stores last N points)
    canvas_points: [256]?CanvasPoint = [_]?CanvasPoint{null} ** 256,
    canvas_head: usize = 0,

    // Color palette
    const PALETTE = [_]u16{
        0xF800, // Red
        0x07E0, // Green
        0x001F, // Blue
        0xFFE0, // Yellow
        0xF81F, // Magenta
        0x07FF, // Cyan
        0xFFFF, // White
        0x0000, // Black
    };

    const CanvasPoint = struct {
        x: i32,
        y: i32,
        color: u16,
        size: u8,
    };

    const Self = @This();

    /// Update state
    pub fn update(self: *Self) void {
        // Age trail points
        for (&self.trail) |*point| {
            if (point.*) |*p| {
                p.age += 1;
                if (p.age > 30) {
                    point.* = null;
                }
            }
        }

        // Decrease gesture display time
        if (self.gesture_display_time > 0) {
            self.gesture_display_time -= 1;
            if (self.gesture_display_time == 0) {
                self.last_gesture = null;
            }
        }
    }

    /// Handle touch event
    pub fn handleTouch(self: *Self, touch: touch_input.Touch) void {
        self.current_touch = touch;
        self.touch_count = touch.touch_count;

        switch (touch.phase) {
            .began, .moved => {
                // Add to trail
                self.trail[self.trail_head] = .{
                    .x = touch.x,
                    .y = touch.y,
                    .age = 0,
                };
                self.trail_head = (self.trail_head + 1) % self.trail.len;

                // Add to canvas if in canvas area
                if (touch.y > 60 and touch.y < 200) {
                    self.canvas_points[self.canvas_head] = .{
                        .x = touch.x,
                        .y = touch.y,
                        .color = self.draw_color,
                        .size = self.brush_size,
                    };
                    self.canvas_head = (self.canvas_head + 1) % self.canvas_points.len;
                }

                // Check color palette hits
                if (touch.y >= 210 and touch.y <= 235) {
                    const palette_x = touch.x - 20;
                    if (palette_x >= 0 and palette_x < 280) {
                        const color_index = @as(usize, @intCast(palette_x)) / 35;
                        if (color_index < Self.PALETTE.len) {
                            self.draw_color = Self.PALETTE[color_index];
                        }
                    }
                }
            },
            .ended => {
                self.current_touch = null;
            },
            else => {},
        }
    }

    /// Handle gesture event
    pub fn handleGesture(self: *Self, gesture: gesture_mod.GestureEvent) void {
        self.last_gesture = gesture.gesture_type;
        self.gesture_display_time = 60; // Show for 2 seconds at 30fps

        // Handle specific gestures
        switch (gesture.gesture_type) {
            .double_tap => {
                // Clear canvas
                self.clearCanvas();
            },
            .pinch => {
                // Adjust brush size
                if (gesture.scale) |scale| {
                    if (scale > 1.0) {
                        self.brush_size = @min(self.brush_size + 1, 20);
                    } else if (scale < 1.0) {
                        self.brush_size = @max(self.brush_size, 2) - 1;
                    }
                }
            },
            else => {},
        }
    }

    /// Clear the canvas
    pub fn clearCanvas(self: *Self) void {
        for (&self.canvas_points) |*point| {
            point.* = null;
        }
        self.canvas_head = 0;
    }
};

/// Draw callback
fn draw(app_ptr: *anyopaque, graphics: *platform.Graphics) void {
    const app: *TouchDemoApp = @ptrCast(@alignCast(app_ptr));

    // Clear background
    graphics.fillRect(0, 0, 320, 240, Theme.background);

    // Draw header
    graphics.fillRect(0, 0, 320, 50, Theme.primary);
    graphics.drawText(80, 15, "Touch Demo", Color.white);

    // Draw canvas area
    graphics.drawRect(10, 55, 300, 150, Theme.border);

    // Draw canvas points
    for (app.canvas_points) |point_opt| {
        if (point_opt) |point| {
            graphics.fillCircle(point.x, point.y, point.size, point.color);
        }
    }

    // Draw touch trail with fading effect
    for (app.trail) |point_opt| {
        if (point_opt) |point| {
            const alpha = 255 - @min(point.age * 8, 255);
            const trail_color = fadeColor(Theme.primary, alpha);
            const size = @max(1, 8 - @as(u8, @intCast(@min(point.age / 4, 7))));
            graphics.fillCircle(point.x, point.y, size, trail_color);
        }
    }

    // Draw current touch indicator
    if (app.current_touch) |touch| {
        // Main touch point
        graphics.fillCircle(touch.x, touch.y, 12, Theme.primary);
        graphics.drawCircle(touch.x, touch.y, 14, Theme.primary_dark);

        // Touch coordinates
        var buf: [32]u8 = undefined;
        const coord_str = std.fmt.bufPrint(&buf, "({d}, {d})", .{ touch.x, touch.y }) catch "?";
        graphics.drawText(10, 55, coord_str, Theme.text_secondary);
    }

    // Draw gesture display
    if (app.last_gesture) |gesture| {
        const gesture_name = gestureToString(gesture);
        graphics.fillRoundedRect(90, 100, 140, 40, 8, Theme.success);
        graphics.drawText(100, 112, gesture_name, Color.white);
    }

    // Draw color palette
    drawColorPalette(graphics, app.draw_color);

    // Draw brush size indicator
    var size_buf: [16]u8 = undefined;
    const size_str = std.fmt.bufPrint(&size_buf, "Size: {d}", .{app.brush_size}) catch "?";
    graphics.drawText(260, 55, size_str, Theme.text_secondary);

    // Draw instructions
    graphics.drawText(10, 205, "Draw | Double-tap: Clear | Pinch: Size", Theme.text_disabled);

    // Draw touch count
    if (app.touch_count > 1) {
        var count_buf: [16]u8 = undefined;
        const count_str = std.fmt.bufPrint(&count_buf, "Touches: {d}", .{app.touch_count}) catch "?";
        graphics.drawText(240, 30, count_str, Color.white);
    }
}

/// Draw color palette
fn drawColorPalette(graphics: *platform.Graphics, selected_color: u16) void {
    const y: i32 = 210;
    const size: u16 = 25;
    const spacing: i32 = 35;

    for (TouchDemoApp.PALETTE, 0..) |color, i| {
        const x: i32 = 20 + @as(i32, @intCast(i)) * spacing;

        // Draw color swatch
        graphics.fillRoundedRect(x, y, size, size, 4, color);

        // Draw selection indicator
        if (color == selected_color) {
            graphics.drawRoundedRect(x - 2, y - 2, size + 4, size + 4, 6, Theme.primary);
        }
    }
}

/// Fade a color towards background
fn fadeColor(color: u16, alpha: u16) u16 {
    const bg = Theme.background;

    const r1 = (color >> 11) & 0x1F;
    const g1 = (color >> 5) & 0x3F;
    const b1 = color & 0x1F;

    const r2 = (bg >> 11) & 0x1F;
    const g2 = (bg >> 5) & 0x3F;
    const b2 = bg & 0x1F;

    const inv_alpha = 255 - alpha;

    const r = (r1 * alpha + r2 * inv_alpha) / 255;
    const g = (g1 * alpha + g2 * inv_alpha) / 255;
    const b = (b1 * alpha + b2 * inv_alpha) / 255;

    return (@as(u16, @intCast(r)) << 11) | (@as(u16, @intCast(g)) << 5) | @as(u16, @intCast(b));
}

/// Convert gesture type to string
fn gestureToString(gesture: gesture_mod.GestureType) []const u8 {
    return switch (gesture) {
        .tap => "Tap",
        .double_tap => "Double Tap",
        .long_press => "Long Press",
        .swipe_left => "Swipe Left",
        .swipe_right => "Swipe Right",
        .swipe_up => "Swipe Up",
        .swipe_down => "Swipe Down",
        .pinch => "Pinch",
        .rotate => "Rotate",
        .pan => "Pan",
    };
}

/// Touch callback
fn onTouch(app_ptr: *anyopaque, touch: touch_input.Touch) void {
    const app: *TouchDemoApp = @ptrCast(@alignCast(app_ptr));
    app.handleTouch(touch);
}

/// Gesture callback
fn onGesture(app_ptr: *anyopaque, gesture: gesture_mod.GestureEvent) void {
    const app: *TouchDemoApp = @ptrCast(@alignCast(app_ptr));
    app.handleGesture(gesture);
}

/// Main entry point
pub fn main() !void {
    // Initialize platform
    var plat = try platform.Platform.init(.{
        .rotation = .portrait,
        .backlight_percent = 80,
        .target_fps = 30,
        .enable_gestures = true,
    });
    defer plat.deinit();

    // Create application
    var app = TouchDemoApp{};

    // Set callbacks
    plat.setCallbacks(.{
        .on_update = struct {
            fn update(ctx: *anyopaque) void {
                const a: *TouchDemoApp = @ptrCast(@alignCast(ctx));
                a.update();
            }
        }.update,
        .on_draw = draw,
        .on_touch = onTouch,
        .on_gesture = onGesture,
        .user_data = &app,
    });

    // Run main loop
    plat.run();
}

// Tests
test "TouchDemoApp initialization" {
    const app = TouchDemoApp{};
    try std.testing.expect(app.current_touch == null);
    try std.testing.expectEqual(@as(u16, 0xF800), app.draw_color);
}

test "TouchDemoApp clearCanvas" {
    var app = TouchDemoApp{};
    app.canvas_points[0] = .{ .x = 100, .y = 100, .color = 0xFFFF, .size = 4 };
    app.canvas_head = 1;

    app.clearCanvas();

    try std.testing.expect(app.canvas_points[0] == null);
    try std.testing.expectEqual(@as(usize, 0), app.canvas_head);
}

test "gestureToString" {
    try std.testing.expectEqualStrings("Tap", gestureToString(.tap));
    try std.testing.expectEqualStrings("Double Tap", gestureToString(.double_tap));
    try std.testing.expectEqualStrings("Swipe Left", gestureToString(.swipe_left));
}
