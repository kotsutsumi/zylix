//! UI Component System for M5Stack CoreS3
//!
//! Provides basic UI components for building applications:
//! - Button: Touchable button with label
//! - Label: Text display
//! - Panel: Container with background
//! - ProgressBar: Progress indicator
//! - Switch: Toggle switch
//! - Slider: Value slider
//!
//! All components support hit testing and can receive touch events.

const std = @import("std");
const graphics_mod = @import("../graphics/graphics.zig");
const framebuffer_mod = @import("../graphics/framebuffer.zig");
const touch_input = @import("../touch/input.zig");

pub const button = @import("button.zig");
pub const label = @import("label.zig");
pub const panel = @import("panel.zig");
pub const progress = @import("progress.zig");
pub const list = @import("list.zig");

// Re-export common types
pub const Button = button.Button;
pub const Label = label.Label;
pub const Panel = panel.Panel;
pub const ProgressBar = progress.ProgressBar;
pub const ListView = list.ListView;

/// Common color palette
pub const Theme = struct {
    // Primary colors
    pub const primary: u16 = 0x2D7F;      // Blue
    pub const primary_dark: u16 = 0x1A5F;
    pub const primary_light: u16 = 0x5DFF;

    // Secondary colors
    pub const secondary: u16 = 0x7BEF;    // Gray
    pub const secondary_dark: u16 = 0x4208;
    pub const secondary_light: u16 = 0xBDF7;

    // Accent colors
    pub const accent: u16 = 0xFBE0;       // Orange
    pub const success: u16 = 0x07E0;      // Green
    pub const warning: u16 = 0xFE00;      // Yellow
    pub const error_color: u16 = 0xF800;  // Red

    // Background colors
    pub const background: u16 = 0xFFFF;    // White
    pub const background_dark: u16 = 0x0000; // Black
    pub const surface: u16 = 0xF7BE;       // Light gray

    // Text colors
    pub const text_primary: u16 = 0x0000;   // Black
    pub const text_secondary: u16 = 0x7BEF; // Gray
    pub const text_on_primary: u16 = 0xFFFF; // White
    pub const text_disabled: u16 = 0xBDF7;   // Light gray

    // Border
    pub const border: u16 = 0xC618;
    pub const border_focus: u16 = 0x2D7F;
};

/// Common UI dimensions
pub const Dimensions = struct {
    pub const button_height: u16 = 44;
    pub const button_min_width: u16 = 80;
    pub const button_padding: u16 = 12;
    pub const button_radius: u16 = 8;

    pub const label_padding: u16 = 4;

    pub const panel_padding: u16 = 8;
    pub const panel_radius: u16 = 4;

    pub const progress_height: u16 = 8;
    pub const progress_radius: u16 = 4;

    pub const switch_width: u16 = 48;
    pub const switch_height: u16 = 28;

    pub const slider_height: u16 = 24;
    pub const slider_thumb_size: u16 = 20;

    pub const list_item_height: u16 = 48;
    pub const list_divider_height: u16 = 1;
};

/// Rectangle for bounds
pub const Rect = struct {
    x: i32,
    y: i32,
    width: u16,
    height: u16,

    /// Check if point is inside rectangle
    pub fn contains(self: Rect, px: i32, py: i32) bool {
        return px >= self.x and
            px < self.x + @as(i32, self.width) and
            py >= self.y and
            py < self.y + @as(i32, self.height);
    }

    /// Get center point
    pub fn center(self: Rect) struct { x: i32, y: i32 } {
        return .{
            .x = self.x + @divTrunc(@as(i32, self.width), 2),
            .y = self.y + @divTrunc(@as(i32, self.height), 2),
        };
    }

    /// Expand by margin
    pub fn expand(self: Rect, margin: i32) Rect {
        return .{
            .x = self.x - margin,
            .y = self.y - margin,
            .width = @intCast(@as(i32, self.width) + margin * 2),
            .height = @intCast(@as(i32, self.height) + margin * 2),
        };
    }

    /// Shrink by margin
    pub fn shrink(self: Rect, margin: i32) Rect {
        const new_width = @as(i32, self.width) - margin * 2;
        const new_height = @as(i32, self.height) - margin * 2;
        return .{
            .x = self.x + margin,
            .y = self.y + margin,
            .width = if (new_width > 0) @intCast(new_width) else 0,
            .height = if (new_height > 0) @intCast(new_height) else 0,
        };
    }
};

/// Component state
pub const ComponentState = enum {
    normal,
    pressed,
    focused,
    disabled,
    selected,
};

/// Base component interface
pub const Component = struct {
    bounds: Rect,
    state: ComponentState = .normal,
    visible: bool = true,
    enabled: bool = true,
    tag: u32 = 0,
    user_data: ?*anyopaque = null,

    /// Virtual draw function pointer
    draw_fn: ?*const fn (*Component, *graphics_mod.Graphics) void = null,

    /// Virtual hit test function pointer
    hit_test_fn: ?*const fn (*Component, i32, i32) bool = null,

    /// Touch event handler
    on_touch_fn: ?*const fn (*Component, touch_input.Touch) void = null,

    /// Draw the component
    pub fn draw(self: *Component, graphics: *graphics_mod.Graphics) void {
        if (!self.visible) return;
        if (self.draw_fn) |f| {
            f(self, graphics);
        }
    }

    /// Hit test
    pub fn hitTest(self: *Component, x: i32, y: i32) bool {
        if (!self.visible or !self.enabled) return false;
        if (self.hit_test_fn) |f| {
            return f(self, x, y);
        }
        return self.bounds.contains(x, y);
    }

    /// Handle touch event
    pub fn handleTouch(self: *Component, touch: touch_input.Touch) void {
        if (!self.enabled) return;
        if (self.on_touch_fn) |f| {
            f(self, touch);
        }
    }

    /// Set position
    pub fn setPosition(self: *Component, x: i32, y: i32) void {
        self.bounds.x = x;
        self.bounds.y = y;
    }

    /// Set size
    pub fn setSize(self: *Component, width: u16, height: u16) void {
        self.bounds.width = width;
        self.bounds.height = height;
    }

    /// Set enabled state
    pub fn setEnabled(self: *Component, enabled: bool) void {
        self.enabled = enabled;
        self.state = if (enabled) .normal else .disabled;
    }
};

/// View container for organizing components
pub const View = struct {
    const MAX_CHILDREN = 32;

    bounds: Rect,
    background_color: ?u16 = null,
    children: [MAX_CHILDREN]?*Component = [_]?*Component{null} ** MAX_CHILDREN,
    child_count: usize = 0,
    visible: bool = true,

    /// Add child component
    pub fn addChild(self: *View, child: *Component) bool {
        if (self.child_count >= MAX_CHILDREN) return false;

        for (&self.children) |*slot| {
            if (slot.* == null) {
                slot.* = child;
                self.child_count += 1;
                return true;
            }
        }
        return false;
    }

    /// Remove child component
    pub fn removeChild(self: *View, child: *Component) bool {
        for (&self.children) |*slot| {
            if (slot.*) |c| {
                if (c == child) {
                    slot.* = null;
                    self.child_count -= 1;
                    return true;
                }
            }
        }
        return false;
    }

    /// Draw all children
    pub fn draw(self: *View, graphics: *graphics_mod.Graphics) void {
        if (!self.visible) return;

        // Draw background
        if (self.background_color) |color| {
            graphics.fillRect(self.bounds.x, self.bounds.y, self.bounds.width, self.bounds.height, color);
        }

        // Draw children
        for (self.children) |maybe_child| {
            if (maybe_child) |child| {
                child.draw(graphics);
            }
        }
    }

    /// Hit test children (returns topmost hit)
    pub fn hitTest(self: *View, x: i32, y: i32) ?*Component {
        if (!self.visible) return null;

        // Test in reverse order (top to bottom)
        var i: usize = MAX_CHILDREN;
        while (i > 0) {
            i -= 1;
            if (self.children[i]) |child| {
                if (child.hitTest(x, y)) {
                    return child;
                }
            }
        }
        return null;
    }

    /// Handle touch event
    pub fn handleTouch(self: *View, touch: touch_input.Touch) bool {
        if (self.hitTest(touch.x, touch.y)) |child| {
            child.handleTouch(touch);
            return true;
        }
        return false;
    }
};

/// Layout helpers
pub const Layout = struct {
    /// Arrange components horizontally with spacing
    pub fn horizontal(components: []const *Component, start_x: i32, y: i32, spacing: i32) void {
        var x = start_x;
        for (components) |comp| {
            comp.bounds.x = x;
            comp.bounds.y = y;
            x += @as(i32, comp.bounds.width) + spacing;
        }
    }

    /// Arrange components vertically with spacing
    pub fn vertical(components: []const *Component, x: i32, start_y: i32, spacing: i32) void {
        var y = start_y;
        for (components) |comp| {
            comp.bounds.x = x;
            comp.bounds.y = y;
            y += @as(i32, comp.bounds.height) + spacing;
        }
    }

    /// Center component horizontally in container
    pub fn centerHorizontal(comp: *Component, container_width: u16) void {
        comp.bounds.x = @divTrunc(@as(i32, container_width) - @as(i32, comp.bounds.width), 2);
    }

    /// Center component vertically in container
    pub fn centerVertical(comp: *Component, container_height: u16) void {
        comp.bounds.y = @divTrunc(@as(i32, container_height) - @as(i32, comp.bounds.height), 2);
    }

    /// Center component in container
    pub fn center(comp: *Component, container_width: u16, container_height: u16) void {
        centerHorizontal(comp, container_width);
        centerVertical(comp, container_height);
    }
};

/// Animation easing functions
pub const Easing = struct {
    /// Linear interpolation
    pub fn linear(t: f32) f32 {
        return t;
    }

    /// Ease in (quadratic)
    pub fn easeIn(t: f32) f32 {
        return t * t;
    }

    /// Ease out (quadratic)
    pub fn easeOut(t: f32) f32 {
        return t * (2 - t);
    }

    /// Ease in-out (quadratic)
    pub fn easeInOut(t: f32) f32 {
        if (t < 0.5) {
            return 2 * t * t;
        }
        return -1 + (4 - 2 * t) * t;
    }

    /// Bounce
    pub fn bounce(t: f32) f32 {
        if (t < 1 / 2.75) {
            return 7.5625 * t * t;
        } else if (t < 2 / 2.75) {
            const t2 = t - 1.5 / 2.75;
            return 7.5625 * t2 * t2 + 0.75;
        } else if (t < 2.5 / 2.75) {
            const t2 = t - 2.25 / 2.75;
            return 7.5625 * t2 * t2 + 0.9375;
        }
        const t2 = t - 2.625 / 2.75;
        return 7.5625 * t2 * t2 + 0.984375;
    }
};

// Tests
test "Rect contains" {
    const rect = Rect{ .x = 10, .y = 10, .width = 100, .height = 50 };

    try std.testing.expect(rect.contains(10, 10));
    try std.testing.expect(rect.contains(50, 30));
    try std.testing.expect(rect.contains(109, 59));
    try std.testing.expect(!rect.contains(110, 60));
    try std.testing.expect(!rect.contains(9, 10));
}

test "Rect center" {
    const rect = Rect{ .x = 0, .y = 0, .width = 100, .height = 50 };
    const c = rect.center();

    try std.testing.expectEqual(@as(i32, 50), c.x);
    try std.testing.expectEqual(@as(i32, 25), c.y);
}

test "Theme colors" {
    try std.testing.expect(Theme.primary != Theme.secondary);
    try std.testing.expect(Theme.background != Theme.background_dark);
}

test "Easing functions" {
    try std.testing.expectEqual(@as(f32, 0), Easing.linear(0));
    try std.testing.expectEqual(@as(f32, 1), Easing.linear(1));
    try std.testing.expectEqual(@as(f32, 0.5), Easing.linear(0.5));

    try std.testing.expectEqual(@as(f32, 0), Easing.easeIn(0));
    try std.testing.expectEqual(@as(f32, 1), Easing.easeIn(1));
}
