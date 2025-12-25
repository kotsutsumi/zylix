//! Panel Component for M5Stack UI
//!
//! Container component with background, border, and shadow options.

const std = @import("std");
const graphics_mod = @import("../graphics/graphics.zig");
const mod = @import("mod.zig");

const Theme = mod.Theme;
const Dimensions = mod.Dimensions;
const Rect = mod.Rect;
const Component = mod.Component;

/// Panel style
pub const PanelStyle = enum {
    flat,        // No border or shadow
    bordered,    // With border
    elevated,    // With shadow
    card,        // Card style (bordered + elevated)
};

/// Panel configuration
pub const PanelConfig = struct {
    x: i32 = 0,
    y: i32 = 0,
    width: u16 = 100,
    height: u16 = 100,
    style: PanelStyle = .flat,
    background: u16 = Theme.surface,
    border_color: u16 = Theme.border,
    border_width: u8 = 1,
    corner_radius: u16 = Dimensions.panel_radius,
    padding: u8 = Dimensions.panel_padding,
    shadow_offset: u8 = 2,
    shadow_color: u16 = Theme.secondary_dark,
};

/// Panel component
pub const Panel = struct {
    // Base component
    component: Component,

    // Panel-specific properties
    style: PanelStyle,
    background: u16,
    border_color: u16,
    border_width: u8,
    corner_radius: u16,
    padding: u8,
    shadow_offset: u8,
    shadow_color: u16,

    // Child components
    const MAX_CHILDREN = 16;
    children: [MAX_CHILDREN]?*Component = [_]?*Component{null} ** MAX_CHILDREN,
    child_count: usize = 0,

    /// Create a new panel
    pub fn init(config: PanelConfig) Panel {
        return Panel{
            .component = .{
                .bounds = .{
                    .x = config.x,
                    .y = config.y,
                    .width = config.width,
                    .height = config.height,
                },
                .draw_fn = drawPanel,
            },
            .style = config.style,
            .background = config.background,
            .border_color = config.border_color,
            .border_width = config.border_width,
            .corner_radius = config.corner_radius,
            .padding = config.padding,
            .shadow_offset = config.shadow_offset,
            .shadow_color = config.shadow_color,
        };
    }

    /// Get component pointer
    pub fn asComponent(self: *Panel) *Component {
        return &self.component;
    }

    /// Add child component
    pub fn addChild(self: *Panel, child: *Component) bool {
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
    pub fn removeChild(self: *Panel, child: *Component) bool {
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

    /// Get content bounds (inside padding)
    pub fn getContentBounds(self: *const Panel) Rect {
        const p = @as(i32, self.padding);
        return .{
            .x = self.component.bounds.x + p,
            .y = self.component.bounds.y + p,
            .width = if (self.component.bounds.width > self.padding * 2)
                self.component.bounds.width - self.padding * 2
            else
                0,
            .height = if (self.component.bounds.height > self.padding * 2)
                self.component.bounds.height - self.padding * 2
            else
                0,
        };
    }

    /// Draw panel (static wrapper)
    fn drawPanel(comp: *Component, graphics: *graphics_mod.Graphics) void {
        const self: *Panel = @fieldParentPtr("component", comp);
        self.draw(graphics);
    }

    /// Draw the panel
    pub fn draw(self: *Panel, graphics: *graphics_mod.Graphics) void {
        const bounds = self.component.bounds;

        // Draw shadow for elevated/card styles
        if (self.style == .elevated or self.style == .card) {
            const shadow_x = bounds.x + @as(i32, self.shadow_offset);
            const shadow_y = bounds.y + @as(i32, self.shadow_offset);

            if (self.corner_radius > 0) {
                graphics.fillRoundedRect(
                    shadow_x,
                    shadow_y,
                    bounds.width,
                    bounds.height,
                    self.corner_radius,
                    self.shadow_color,
                );
            } else {
                graphics.fillRect(shadow_x, shadow_y, bounds.width, bounds.height, self.shadow_color);
            }
        }

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

        // Draw border for bordered/card styles
        if (self.style == .bordered or self.style == .card) {
            if (self.corner_radius > 0) {
                graphics.drawRoundedRect(
                    bounds.x,
                    bounds.y,
                    bounds.width,
                    bounds.height,
                    self.corner_radius,
                    self.border_color,
                );
            } else {
                graphics.drawRect(bounds.x, bounds.y, bounds.width, bounds.height, self.border_color);
            }
        }

        // Draw children
        for (self.children) |maybe_child| {
            if (maybe_child) |child| {
                child.draw(graphics);
            }
        }
    }

    /// Hit test children
    pub fn hitTest(self: *Panel, x: i32, y: i32) ?*Component {
        // Test children in reverse order (top to bottom)
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
};

/// Create a flat panel
pub fn flat(x: i32, y: i32, width: u16, height: u16) Panel {
    return Panel.init(.{
        .x = x,
        .y = y,
        .width = width,
        .height = height,
        .style = .flat,
    });
}

/// Create a bordered panel
pub fn bordered(x: i32, y: i32, width: u16, height: u16) Panel {
    return Panel.init(.{
        .x = x,
        .y = y,
        .width = width,
        .height = height,
        .style = .bordered,
    });
}

/// Create an elevated panel
pub fn elevated(x: i32, y: i32, width: u16, height: u16) Panel {
    return Panel.init(.{
        .x = x,
        .y = y,
        .width = width,
        .height = height,
        .style = .elevated,
    });
}

/// Create a card panel
pub fn card(x: i32, y: i32, width: u16, height: u16) Panel {
    return Panel.init(.{
        .x = x,
        .y = y,
        .width = width,
        .height = height,
        .style = .card,
    });
}

// Tests
test "Panel initialization" {
    const pnl = Panel.init(.{
        .x = 10,
        .y = 20,
        .width = 100,
        .height = 80,
        .style = .card,
    });

    try std.testing.expectEqual(@as(i32, 10), pnl.component.bounds.x);
    try std.testing.expectEqual(@as(u16, 100), pnl.component.bounds.width);
    try std.testing.expectEqual(PanelStyle.card, pnl.style);
}

test "Panel content bounds" {
    const pnl = Panel.init(.{
        .x = 10,
        .y = 10,
        .width = 100,
        .height = 100,
        .padding = 8,
    });

    const content = pnl.getContentBounds();
    try std.testing.expectEqual(@as(i32, 18), content.x);
    try std.testing.expectEqual(@as(i32, 18), content.y);
    try std.testing.expectEqual(@as(u16, 84), content.width);
    try std.testing.expectEqual(@as(u16, 84), content.height);
}
