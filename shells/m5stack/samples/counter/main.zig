//! Counter Sample for M5Stack CoreS3
//!
//! Demonstrates state management and touch interaction.
//! Features increment/decrement buttons with visual feedback.

const std = @import("std");
const platform = @import("../../src/platform/mod.zig");
const ui = @import("../../src/ui/mod.zig");
const touch_input = @import("../../src/touch/input.zig");

const Theme = ui.Theme;
const Color = platform.Color;
const Button = ui.button.Button;
const Label = ui.label.Label;

/// Counter application state
const CounterApp = struct {
    count: i32 = 0,
    min_value: i32 = -99,
    max_value: i32 = 99,

    // UI components
    decrement_btn: Button,
    increment_btn: Button,
    reset_btn: Button,
    count_label: Label,

    // Animation
    last_change: u64 = 0,
    flash_alpha: u8 = 0,

    const Self = @This();

    /// Initialize counter app
    pub fn init() Self {
        var app = Self{
            .decrement_btn = Button.init(.{
                .x = 20,
                .y = 100,
                .width = 80,
                .height = 60,
                .label = "-",
                .style = .filled,
                .background = Theme.error_color,
                .on_press = onDecrement,
            }),
            .increment_btn = Button.init(.{
                .x = 220,
                .y = 100,
                .width = 80,
                .height = 60,
                .label = "+",
                .style = .filled,
                .background = Theme.success,
                .on_press = onIncrement,
            }),
            .reset_btn = Button.init(.{
                .x = 110,
                .y = 180,
                .width = 100,
                .height = 40,
                .label = "Reset",
                .style = .outlined,
                .on_press = onReset,
            }),
            .count_label = Label.init(.{
                .x = 110,
                .y = 100,
                .width = 100,
                .height = 60,
                .text = "0",
                .alignment = .center,
                .font_size = 3,
                .color = Theme.text_primary,
            }),
        };

        return app;
    }

    /// Increment counter
    pub fn increment(self: *Self) void {
        if (self.count < self.max_value) {
            self.count += 1;
            self.flash_alpha = 255;
            self.updateLabel();
        }
    }

    /// Decrement counter
    pub fn decrement(self: *Self) void {
        if (self.count > self.min_value) {
            self.count -= 1;
            self.flash_alpha = 255;
            self.updateLabel();
        }
    }

    /// Reset counter
    pub fn reset(self: *Self) void {
        self.count = 0;
        self.flash_alpha = 255;
        self.updateLabel();
    }

    /// Update the count label text
    fn updateLabel(self: *Self) void {
        _ = self;
        // Label would be updated with the new count
        // In a real implementation, this would update the label text
    }

    /// Update animation state
    pub fn update(self: *Self) void {
        // Fade out flash effect
        if (self.flash_alpha > 0) {
            self.flash_alpha = if (self.flash_alpha > 10) self.flash_alpha - 10 else 0;
        }
    }

    /// Handle touch event
    pub fn handleTouch(self: *Self, touch: touch_input.Touch) void {
        // Check button hits
        if (self.decrement_btn.component.containsPoint(touch.x, touch.y)) {
            self.decrement_btn.handleTouch(touch);
        }
        if (self.increment_btn.component.containsPoint(touch.x, touch.y)) {
            self.increment_btn.handleTouch(touch);
        }
        if (self.reset_btn.component.containsPoint(touch.x, touch.y)) {
            self.reset_btn.handleTouch(touch);
        }
    }
};

/// Button callbacks
fn onDecrement(btn: *Button) void {
    _ = btn;
    // Would need access to app state
    // For demo purposes, this shows the callback structure
}

fn onIncrement(btn: *Button) void {
    _ = btn;
}

fn onReset(btn: *Button) void {
    _ = btn;
}

/// Draw callback
fn draw(app_ptr: *anyopaque, graphics: *platform.Graphics) void {
    const app: *CounterApp = @ptrCast(@alignCast(app_ptr));

    // Clear background
    graphics.fillRect(0, 0, 320, 240, Theme.background);

    // Draw header
    graphics.fillRect(0, 0, 320, 50, Theme.primary);
    graphics.drawText(100, 15, "Counter", Color.white);

    // Draw flash effect on count change
    if (app.flash_alpha > 0) {
        const flash_color = blendColor(Theme.background, Theme.primary_light, app.flash_alpha);
        graphics.fillRect(100, 90, 120, 80, flash_color);
    }

    // Draw count display background
    graphics.fillRoundedRect(100, 90, 120, 80, 10, Theme.secondary_light);
    graphics.drawRoundedRect(100, 90, 120, 80, 10, Theme.border);

    // Draw count value
    var buf: [8]u8 = undefined;
    const count_str = std.fmt.bufPrint(&buf, "{d}", .{app.count}) catch "?";
    const text_x: i32 = 160 - @as(i32, @intCast(count_str.len * 12));
    graphics.drawText(text_x, 115, count_str, Theme.text_primary);

    // Draw buttons
    drawButton(graphics, &app.decrement_btn);
    drawButton(graphics, &app.increment_btn);
    drawButton(graphics, &app.reset_btn);

    // Draw min/max labels
    graphics.drawText(20, 165, "Min: -99", Theme.text_secondary);
    graphics.drawText(220, 165, "Max: 99", Theme.text_secondary);

    // Draw instructions
    graphics.drawText(70, 220, "Tap buttons to count", Theme.text_disabled);
}

/// Draw a button
fn drawButton(graphics: *platform.Graphics, btn: *const Button) void {
    const bounds = btn.component.bounds;
    const bg = if (btn.is_pressed) darkenColor(btn.background) else btn.background;

    // Draw button background
    graphics.fillRoundedRect(bounds.x, bounds.y, bounds.width, bounds.height, 8, bg);

    // Draw border
    graphics.drawRoundedRect(bounds.x, bounds.y, bounds.width, bounds.height, 8, Theme.border);

    // Draw label centered
    const text_x = bounds.x + @divTrunc(@as(i32, bounds.width) - @as(i32, @intCast(btn.label.len * 8)), 2);
    const text_y = bounds.y + @divTrunc(@as(i32, bounds.height) - 8, 2);
    graphics.drawText(text_x, text_y, btn.label, btn.text_color);
}

/// Blend two colors
fn blendColor(c1: u16, c2: u16, alpha: u8) u16 {
    const r1 = (c1 >> 11) & 0x1F;
    const g1 = (c1 >> 5) & 0x3F;
    const b1 = c1 & 0x1F;

    const r2 = (c2 >> 11) & 0x1F;
    const g2 = (c2 >> 5) & 0x3F;
    const b2 = c2 & 0x1F;

    const a = @as(u16, alpha);
    const inv_a = 255 - a;

    const r = (r1 * inv_a + r2 * a) / 255;
    const g = (g1 * inv_a + g2 * a) / 255;
    const b = (b1 * inv_a + b2 * a) / 255;

    return (@as(u16, @intCast(r)) << 11) | (@as(u16, @intCast(g)) << 5) | @as(u16, @intCast(b));
}

/// Darken a color
fn darkenColor(color: u16) u16 {
    const r = ((color >> 11) & 0x1F) * 3 / 4;
    const g = ((color >> 5) & 0x3F) * 3 / 4;
    const b = (color & 0x1F) * 3 / 4;
    return (@as(u16, @intCast(r)) << 11) | (@as(u16, @intCast(g)) << 5) | @as(u16, @intCast(b));
}

/// Touch callback
fn onTouch(app_ptr: *anyopaque, touch: touch_input.Touch) void {
    const app: *CounterApp = @ptrCast(@alignCast(app_ptr));
    app.handleTouch(touch);
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

    // Create application
    var app = CounterApp.init();

    // Set callbacks
    plat.setCallbacks(.{
        .on_update = struct {
            fn update(ctx: *anyopaque) void {
                const a: *CounterApp = @ptrCast(@alignCast(ctx));
                a.update();
            }
        }.update,
        .on_draw = draw,
        .on_touch = onTouch,
        .user_data = &app,
    });

    // Run main loop
    plat.run();
}

// Tests
test "CounterApp initialization" {
    const app = CounterApp.init();
    try std.testing.expectEqual(@as(i32, 0), app.count);
}

test "CounterApp increment" {
    var app = CounterApp.init();
    app.increment();
    try std.testing.expectEqual(@as(i32, 1), app.count);
}

test "CounterApp decrement" {
    var app = CounterApp.init();
    app.decrement();
    try std.testing.expectEqual(@as(i32, -1), app.count);
}

test "CounterApp max limit" {
    var app = CounterApp.init();
    app.count = 99;
    app.increment();
    try std.testing.expectEqual(@as(i32, 99), app.count);
}

test "CounterApp min limit" {
    var app = CounterApp.init();
    app.count = -99;
    app.decrement();
    try std.testing.expectEqual(@as(i32, -99), app.count);
}

test "CounterApp reset" {
    var app = CounterApp.init();
    app.count = 50;
    app.reset();
    try std.testing.expectEqual(@as(i32, 0), app.count);
}
