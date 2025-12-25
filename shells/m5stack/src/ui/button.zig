//! Button Component for M5Stack UI
//!
//! Touchable button with label, icon support, and various styles.

const std = @import("std");
const graphics_mod = @import("../graphics/graphics.zig");
const touch_input = @import("../touch/input.zig");
const mod = @import("mod.zig");

const Theme = mod.Theme;
const Dimensions = mod.Dimensions;
const Rect = mod.Rect;
const Component = mod.Component;
const ComponentState = mod.ComponentState;

/// Button style
pub const ButtonStyle = enum {
    filled,      // Solid background
    outlined,    // Border only
    text,        // Text only, no border
    elevated,    // With shadow effect
};

/// Button configuration
pub const ButtonConfig = struct {
    x: i32 = 0,
    y: i32 = 0,
    width: u16 = Dimensions.button_min_width,
    height: u16 = Dimensions.button_height,
    label: []const u8 = "",
    style: ButtonStyle = .filled,
    color: u16 = Theme.primary,
    text_color: u16 = Theme.text_on_primary,
    disabled_color: u16 = Theme.secondary_light,
    pressed_color: ?u16 = null,
    corner_radius: u16 = Dimensions.button_radius,
    tag: u32 = 0,
    on_press: ?*const fn (*Button) void = null,
    on_release: ?*const fn (*Button) void = null,
};

/// Button component
pub const Button = struct {
    // Base component
    component: Component,

    // Button-specific properties
    label: []const u8,
    style: ButtonStyle,
    color: u16,
    text_color: u16,
    disabled_color: u16,
    pressed_color: u16,
    corner_radius: u16,

    // Callbacks
    on_press: ?*const fn (*Button) void,
    on_release: ?*const fn (*Button) void,

    // State tracking
    is_pressed: bool = false,
    press_start_time: u64 = 0,

    /// Create a new button
    pub fn init(config: ButtonConfig) Button {
        var btn = Button{
            .component = .{
                .bounds = .{
                    .x = config.x,
                    .y = config.y,
                    .width = config.width,
                    .height = config.height,
                },
                .tag = config.tag,
                .draw_fn = drawButton,
                .hit_test_fn = hitTestButton,
                .on_touch_fn = handleButtonTouch,
            },
            .label = config.label,
            .style = config.style,
            .color = config.color,
            .text_color = config.text_color,
            .disabled_color = config.disabled_color,
            .pressed_color = config.pressed_color orelse darkenColor(config.color),
            .corner_radius = config.corner_radius,
            .on_press = config.on_press,
            .on_release = config.on_release,
        };
        return btn;
    }

    /// Get component pointer
    pub fn asComponent(self: *Button) *Component {
        return &self.component;
    }

    /// Set label
    pub fn setLabel(self: *Button, label: []const u8) void {
        self.label = label;
    }

    /// Set enabled
    pub fn setEnabled(self: *Button, enabled: bool) void {
        self.component.setEnabled(enabled);
    }

    /// Check if pressed
    pub fn isPressed(self: *const Button) bool {
        return self.is_pressed;
    }

    /// Draw button (static wrapper)
    fn drawButton(comp: *Component, graphics: *graphics_mod.Graphics) void {
        const self: *Button = @fieldParentPtr("component", comp);
        self.draw(graphics);
    }

    /// Draw the button
    pub fn draw(self: *Button, graphics: *graphics_mod.Graphics) void {
        const bounds = self.component.bounds;
        const state = self.component.state;

        // Determine colors based on state
        var bg_color = self.color;
        var txt_color = self.text_color;

        switch (state) {
            .disabled => {
                bg_color = self.disabled_color;
                txt_color = Theme.text_disabled;
            },
            .pressed => {
                bg_color = self.pressed_color;
            },
            else => {},
        }

        // Draw based on style
        switch (self.style) {
            .filled => {
                // Draw filled background
                if (self.corner_radius > 0) {
                    graphics.fillRoundedRect(
                        bounds.x,
                        bounds.y,
                        bounds.width,
                        bounds.height,
                        self.corner_radius,
                        bg_color,
                    );
                } else {
                    graphics.fillRect(bounds.x, bounds.y, bounds.width, bounds.height, bg_color);
                }
            },
            .outlined => {
                // Draw outline only
                if (self.corner_radius > 0) {
                    graphics.drawRoundedRect(
                        bounds.x,
                        bounds.y,
                        bounds.width,
                        bounds.height,
                        self.corner_radius,
                        bg_color,
                    );
                } else {
                    graphics.drawRect(bounds.x, bounds.y, bounds.width, bounds.height, bg_color);
                }
                txt_color = bg_color;
            },
            .text => {
                // Text only, no background
                txt_color = bg_color;
            },
            .elevated => {
                // Draw shadow
                graphics.fillRect(
                    bounds.x + 2,
                    bounds.y + 2,
                    bounds.width,
                    bounds.height,
                    Theme.secondary_dark,
                );
                // Draw button
                if (self.corner_radius > 0) {
                    graphics.fillRoundedRect(
                        bounds.x,
                        bounds.y,
                        bounds.width,
                        bounds.height,
                        self.corner_radius,
                        bg_color,
                    );
                } else {
                    graphics.fillRect(bounds.x, bounds.y, bounds.width, bounds.height, bg_color);
                }
            },
        }

        // Draw label centered
        if (self.label.len > 0) {
            const text_width = self.label.len * 8; // Approximate character width
            const text_height: u16 = 8;

            const text_x = bounds.x + @divTrunc(@as(i32, bounds.width) - @as(i32, @intCast(text_width)), 2);
            const text_y = bounds.y + @divTrunc(@as(i32, bounds.height) - @as(i32, text_height), 2);

            graphics.drawText(text_x, text_y, self.label, txt_color);
        }
    }

    /// Hit test (static wrapper)
    fn hitTestButton(comp: *Component, x: i32, y: i32) bool {
        return comp.bounds.contains(x, y);
    }

    /// Handle touch (static wrapper)
    fn handleButtonTouch(comp: *Component, touch: touch_input.Touch) void {
        const self: *Button = @fieldParentPtr("component", comp);
        self.handleTouch(touch);
    }

    /// Handle touch event
    pub fn handleTouch(self: *Button, touch: touch_input.Touch) void {
        if (!self.component.enabled) return;

        switch (touch.phase) {
            .began => {
                self.is_pressed = true;
                self.press_start_time = touch.timestamp;
                self.component.state = .pressed;
                if (self.on_press) |callback| {
                    callback(self);
                }
            },
            .ended => {
                if (self.is_pressed) {
                    self.is_pressed = false;
                    self.component.state = .normal;
                    if (self.on_release) |callback| {
                        callback(self);
                    }
                }
            },
            .cancelled => {
                self.is_pressed = false;
                self.component.state = .normal;
            },
            .moved => {
                // Check if touch moved outside button
                if (!self.component.bounds.contains(touch.x, touch.y)) {
                    self.is_pressed = false;
                    self.component.state = .normal;
                }
            },
            .stationary => {},
        }
    }
};

/// Darken a color for pressed state
fn darkenColor(color: u16) u16 {
    // Extract RGB565 components
    const r = (color >> 11) & 0x1F;
    const g = (color >> 5) & 0x3F;
    const b = color & 0x1F;

    // Darken by 25%
    const new_r = r * 3 / 4;
    const new_g = g * 3 / 4;
    const new_b = b * 3 / 4;

    return (@as(u16, @intCast(new_r)) << 11) |
        (@as(u16, @intCast(new_g)) << 5) |
        @as(u16, @intCast(new_b));
}

/// Create a primary button
pub fn primaryButton(x: i32, y: i32, label: []const u8, on_release: ?*const fn (*Button) void) Button {
    return Button.init(.{
        .x = x,
        .y = y,
        .label = label,
        .style = .filled,
        .color = Theme.primary,
        .on_release = on_release,
    });
}

/// Create a secondary button
pub fn secondaryButton(x: i32, y: i32, label: []const u8, on_release: ?*const fn (*Button) void) Button {
    return Button.init(.{
        .x = x,
        .y = y,
        .label = label,
        .style = .outlined,
        .color = Theme.secondary,
        .on_release = on_release,
    });
}

/// Create a danger button
pub fn dangerButton(x: i32, y: i32, label: []const u8, on_release: ?*const fn (*Button) void) Button {
    return Button.init(.{
        .x = x,
        .y = y,
        .label = label,
        .style = .filled,
        .color = Theme.error_color,
        .on_release = on_release,
    });
}

// Tests
test "Button initialization" {
    const btn = Button.init(.{
        .x = 10,
        .y = 20,
        .width = 100,
        .height = 40,
        .label = "Test",
    });

    try std.testing.expectEqual(@as(i32, 10), btn.component.bounds.x);
    try std.testing.expectEqual(@as(i32, 20), btn.component.bounds.y);
    try std.testing.expectEqual(@as(u16, 100), btn.component.bounds.width);
    try std.testing.expectEqual(@as(u16, 40), btn.component.bounds.height);
    try std.testing.expectEqualStrings("Test", btn.label);
}

test "Button state" {
    var btn = Button.init(.{
        .x = 0,
        .y = 0,
        .width = 100,
        .height = 40,
    });

    try std.testing.expect(!btn.isPressed());
    try std.testing.expectEqual(ComponentState.normal, btn.component.state);

    btn.setEnabled(false);
    try std.testing.expectEqual(ComponentState.disabled, btn.component.state);
}

test "darkenColor" {
    const white: u16 = 0xFFFF;
    const darkened = darkenColor(white);
    try std.testing.expect(darkened < white);
}
