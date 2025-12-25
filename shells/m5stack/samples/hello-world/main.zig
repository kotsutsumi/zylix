//! Hello World Sample for M5Stack CoreS3
//!
//! Demonstrates basic display output and simple animation.
//! Shows the Zylix logo and greeting text.

const std = @import("std");
const platform = @import("../../src/platform/mod.zig");
const ui = @import("../../src/ui/mod.zig");
const renderer = @import("../../src/renderer/mod.zig");

const Theme = ui.Theme;
const Color = platform.Color;

/// Application state
const HelloApp = struct {
    frame_count: u32 = 0,
    animation_offset: i32 = 0,
    direction: i8 = 1,

    /// Update application state
    pub fn update(self: *HelloApp) void {
        self.frame_count += 1;

        // Simple bounce animation for the text
        self.animation_offset += self.direction;
        if (self.animation_offset > 20 or self.animation_offset < -20) {
            self.direction = -self.direction;
        }
    }
};

/// Draw callback
fn draw(app_ptr: *anyopaque, graphics: *platform.Graphics) void {
    const app: *HelloApp = @ptrCast(@alignCast(app_ptr));
    _ = app;

    // Clear background with gradient effect
    graphics.fillRect(0, 0, 320, 240, Theme.background);

    // Draw decorative header bar
    graphics.fillRect(0, 0, 320, 50, Theme.primary);

    // Draw "Zylix" title
    graphics.drawText(110, 15, "ZYLIX", Color.white);

    // Draw M5Stack subtitle
    graphics.drawText(80, 70, "M5Stack CoreS3 SE", Theme.text_secondary);

    // Draw Hello World message with animation
    const text_y: i32 = 120;
    graphics.drawText(80, text_y, "Hello, World!", Theme.primary);

    // Draw decorative elements
    drawDecorativeElements(graphics);

    // Draw version info
    graphics.drawText(100, 200, "Zylix v0.20.0", Theme.text_disabled);

    // Draw frame counter (for debugging)
    // graphics.drawText(10, 220, "Frame:", Theme.text_secondary);
}

/// Draw decorative elements
fn drawDecorativeElements(graphics: *platform.Graphics) void {
    // Draw corners
    const corner_size: u16 = 15;
    const corner_color = Theme.primary_light;

    // Top-left
    graphics.drawHLine(0, 50, corner_size, corner_color);
    graphics.drawVLine(0, 50, corner_size, corner_color);

    // Top-right
    graphics.drawHLine(320 - corner_size, 50, corner_size, corner_color);
    graphics.drawVLine(319, 50, corner_size, corner_color);

    // Bottom-left
    graphics.drawHLine(0, 190, corner_size, corner_color);
    graphics.drawVLine(0, 190 - corner_size, corner_size, corner_color);

    // Bottom-right
    graphics.drawHLine(320 - corner_size, 190, corner_size, corner_color);
    graphics.drawVLine(319, 190 - corner_size, corner_size, corner_color);

    // Draw center circle decoration
    graphics.drawCircle(160, 150, 40, Theme.secondary_light);
    graphics.drawCircle(160, 150, 35, Theme.secondary);
}

/// Main entry point
pub fn main() !void {
    // Initialize platform
    var plat = try platform.Platform.init(.{
        .rotation = .portrait,
        .backlight_percent = 80,
        .target_fps = 30,
    });
    defer plat.deinit();

    // Create application state
    var app = HelloApp{};

    // Set callbacks
    plat.setCallbacks(.{
        .on_update = struct {
            fn update(ctx: *anyopaque) void {
                const a: *HelloApp = @ptrCast(@alignCast(ctx));
                a.update();
            }
        }.update,
        .on_draw = draw,
        .user_data = &app,
    });

    // Run main loop
    plat.run();
}

// Tests
test "HelloApp initialization" {
    var app = HelloApp{};
    try std.testing.expectEqual(@as(u32, 0), app.frame_count);
}

test "HelloApp update" {
    var app = HelloApp{};
    app.update();
    try std.testing.expectEqual(@as(u32, 1), app.frame_count);
    try std.testing.expectEqual(@as(i32, 1), app.animation_offset);
}
