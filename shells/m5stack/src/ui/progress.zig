//! Progress Bar Component for M5Stack UI
//!
//! Displays progress with various styles: bar, circular, spinner.

const std = @import("std");
const graphics_mod = @import("../graphics/graphics.zig");
const mod = @import("mod.zig");

const Theme = mod.Theme;
const Dimensions = mod.Dimensions;
const Rect = mod.Rect;
const Component = mod.Component;

/// Progress style
pub const ProgressStyle = enum {
    bar,         // Horizontal bar
    bar_vertical, // Vertical bar
    circular,    // Circular progress
};

/// Progress configuration
pub const ProgressConfig = struct {
    x: i32 = 0,
    y: i32 = 0,
    width: u16 = 100,
    height: u16 = Dimensions.progress_height,
    style: ProgressStyle = .bar,
    value: f32 = 0,          // 0.0 to 1.0
    min_value: f32 = 0,
    max_value: f32 = 1.0,
    foreground: u16 = Theme.primary,
    background: u16 = Theme.secondary_light,
    corner_radius: u16 = Dimensions.progress_radius,
    show_text: bool = false,
    text_color: u16 = Theme.text_primary,
    animate: bool = false,
};

/// Progress bar component
pub const ProgressBar = struct {
    // Base component
    component: Component,

    // Progress-specific properties
    style: ProgressStyle,
    value: f32,
    min_value: f32,
    max_value: f32,
    foreground: u16,
    background: u16,
    corner_radius: u16,
    show_text: bool,
    text_color: u16,
    animate: bool,

    // Animation state
    animation_offset: i32 = 0,
    last_update: u64 = 0,

    /// Create a new progress bar
    pub fn init(config: ProgressConfig) ProgressBar {
        return ProgressBar{
            .component = .{
                .bounds = .{
                    .x = config.x,
                    .y = config.y,
                    .width = config.width,
                    .height = config.height,
                },
                .draw_fn = drawProgress,
            },
            .style = config.style,
            .value = config.value,
            .min_value = config.min_value,
            .max_value = config.max_value,
            .foreground = config.foreground,
            .background = config.background,
            .corner_radius = config.corner_radius,
            .show_text = config.show_text,
            .text_color = config.text_color,
            .animate = config.animate,
        };
    }

    /// Get component pointer
    pub fn asComponent(self: *ProgressBar) *Component {
        return &self.component;
    }

    /// Set value (0.0 to 1.0)
    pub fn setValue(self: *ProgressBar, value: f32) void {
        self.value = std.math.clamp(value, self.min_value, self.max_value);
    }

    /// Set value from integer (0 to max)
    pub fn setValueInt(self: *ProgressBar, value: i32, max: i32) void {
        if (max <= 0) return;
        self.value = @as(f32, @floatFromInt(value)) / @as(f32, @floatFromInt(max));
    }

    /// Get normalized value (0.0 to 1.0)
    pub fn getNormalizedValue(self: *const ProgressBar) f32 {
        const range = self.max_value - self.min_value;
        if (range <= 0) return 0;
        return (self.value - self.min_value) / range;
    }

    /// Get percentage (0 to 100)
    pub fn getPercentage(self: *const ProgressBar) u8 {
        return @intFromFloat(self.getNormalizedValue() * 100);
    }

    /// Update animation
    pub fn update(self: *ProgressBar, timestamp: u64) void {
        if (!self.animate) return;

        const elapsed = timestamp - self.last_update;
        if (elapsed >= 50_000) { // 50ms
            self.animation_offset += 2;
            if (self.animation_offset >= 20) {
                self.animation_offset = 0;
            }
            self.last_update = timestamp;
        }
    }

    /// Draw progress (static wrapper)
    fn drawProgress(comp: *Component, graphics: *graphics_mod.Graphics) void {
        const self: *ProgressBar = @fieldParentPtr("component", comp);
        self.draw(graphics);
    }

    /// Draw the progress bar
    pub fn draw(self: *ProgressBar, graphics: *graphics_mod.Graphics) void {
        switch (self.style) {
            .bar => self.drawBar(graphics),
            .bar_vertical => self.drawBarVertical(graphics),
            .circular => self.drawCircular(graphics),
        }
    }

    /// Draw horizontal bar style
    fn drawBar(self: *ProgressBar, graphics: *graphics_mod.Graphics) void {
        const bounds = self.component.bounds;
        const normalized = self.getNormalizedValue();

        // Draw background
        if (self.corner_radius > 0) {
            graphics.fillRoundedRect(
                bounds.x,
                bounds.y,
                bounds.width,
                bounds.height,
                self.corner_radius,
                self.background,
            );
        } else {
            graphics.fillRect(bounds.x, bounds.y, bounds.width, bounds.height, self.background);
        }

        // Draw filled portion
        if (normalized > 0) {
            const fill_width: u16 = @intFromFloat(@as(f32, @floatFromInt(bounds.width)) * normalized);
            if (fill_width > 0) {
                if (self.corner_radius > 0) {
                    graphics.fillRoundedRect(
                        bounds.x,
                        bounds.y,
                        fill_width,
                        bounds.height,
                        self.corner_radius,
                        self.foreground,
                    );
                } else {
                    graphics.fillRect(bounds.x, bounds.y, fill_width, bounds.height, self.foreground);
                }
            }
        }

        // Draw text if enabled
        if (self.show_text) {
            var buf: [8]u8 = undefined;
            const text = std.fmt.bufPrint(&buf, "{d}%", .{self.getPercentage()}) catch return;
            const text_x = bounds.x + @divTrunc(@as(i32, bounds.width) - @as(i32, @intCast(text.len * 8)), 2);
            const text_y = bounds.y + @divTrunc(@as(i32, bounds.height) - 8, 2);
            graphics.drawText(text_x, text_y, text, self.text_color);
        }
    }

    /// Draw vertical bar style
    fn drawBarVertical(self: *ProgressBar, graphics: *graphics_mod.Graphics) void {
        const bounds = self.component.bounds;
        const normalized = self.getNormalizedValue();

        // Draw background
        graphics.fillRect(bounds.x, bounds.y, bounds.width, bounds.height, self.background);

        // Draw filled portion (from bottom)
        if (normalized > 0) {
            const fill_height: u16 = @intFromFloat(@as(f32, @floatFromInt(bounds.height)) * normalized);
            if (fill_height > 0) {
                const fill_y = bounds.y + @as(i32, bounds.height - fill_height);
                graphics.fillRect(bounds.x, fill_y, bounds.width, fill_height, self.foreground);
            }
        }
    }

    /// Draw circular style
    fn drawCircular(self: *ProgressBar, graphics: *graphics_mod.Graphics) void {
        const bounds = self.component.bounds;
        const center_x = bounds.x + @divTrunc(@as(i32, bounds.width), 2);
        const center_y = bounds.y + @divTrunc(@as(i32, bounds.height), 2);
        const radius: u16 = @intCast(@min(bounds.width, bounds.height) / 2);

        // Draw background circle
        graphics.drawCircle(center_x, center_y, radius, self.background);

        // Draw arc based on value
        const normalized = self.getNormalizedValue();
        if (normalized > 0) {
            const arc_angle: f32 = normalized * 360.0;
            graphics.drawArc(center_x, center_y, radius, -90, @as(i32, @intFromFloat(arc_angle)) - 90, self.foreground);
        }

        // Draw percentage text
        if (self.show_text) {
            var buf: [8]u8 = undefined;
            const text = std.fmt.bufPrint(&buf, "{d}%", .{self.getPercentage()}) catch return;
            const text_x = center_x - @as(i32, @intCast(text.len * 4));
            const text_y = center_y - 4;
            graphics.drawText(text_x, text_y, text, self.text_color);
        }
    }
};

/// Create a simple progress bar
pub fn bar(x: i32, y: i32, width: u16) ProgressBar {
    return ProgressBar.init(.{
        .x = x,
        .y = y,
        .width = width,
        .height = Dimensions.progress_height,
        .style = .bar,
    });
}

/// Create a progress bar with percentage text
pub fn barWithText(x: i32, y: i32, width: u16) ProgressBar {
    return ProgressBar.init(.{
        .x = x,
        .y = y,
        .width = width,
        .height = 16,
        .style = .bar,
        .show_text = true,
    });
}

/// Create a circular progress
pub fn circular(x: i32, y: i32, size: u16) ProgressBar {
    return ProgressBar.init(.{
        .x = x,
        .y = y,
        .width = size,
        .height = size,
        .style = .circular,
        .show_text = true,
    });
}

// Tests
test "ProgressBar initialization" {
    const pb = ProgressBar.init(.{
        .x = 10,
        .y = 20,
        .width = 100,
        .height = 8,
    });

    try std.testing.expectEqual(@as(f32, 0), pb.value);
    try std.testing.expectEqual(ProgressStyle.bar, pb.style);
}

test "ProgressBar setValue" {
    var pb = ProgressBar.init(.{});

    pb.setValue(0.5);
    try std.testing.expectEqual(@as(f32, 0.5), pb.value);

    pb.setValue(1.5); // Should clamp
    try std.testing.expectEqual(@as(f32, 1.0), pb.value);

    pb.setValue(-0.5); // Should clamp
    try std.testing.expectEqual(@as(f32, 0), pb.value);
}

test "ProgressBar getPercentage" {
    var pb = ProgressBar.init(.{});

    pb.setValue(0);
    try std.testing.expectEqual(@as(u8, 0), pb.getPercentage());

    pb.setValue(0.5);
    try std.testing.expectEqual(@as(u8, 50), pb.getPercentage());

    pb.setValue(1.0);
    try std.testing.expectEqual(@as(u8, 100), pb.getPercentage());
}
