//! Virtual DOM Reconciler for M5Stack
//!
//! Applies diff changes to the actual graphics context.
//! Bridges virtual DOM operations to hardware rendering.

const std = @import("std");
const graphics_mod = @import("../graphics/graphics.zig");
const vdom = @import("vdom.zig");
const diff = @import("diff.zig");

const VNode = vdom.VNode;
const VNodeType = vdom.VNodeType;
const VNodeProps = vdom.VNodeProps;
const VDom = vdom.VDom;
const DiffResult = diff.DiffResult;
const Change = diff.Change;
const ChangeType = diff.ChangeType;

/// Reconciler configuration
pub const ReconcilerConfig = struct {
    /// Enable dirty region optimization
    use_dirty_regions: bool = true,

    /// Enable double buffering
    double_buffer: bool = true,

    /// Background color for clearing
    background_color: u16 = 0x0000,
};

/// Reconciler for applying VDOM changes to graphics
pub const Reconciler = struct {
    allocator: std.mem.Allocator,
    graphics: ?*graphics_mod.Graphics = null,
    config: ReconcilerConfig = .{},

    // Statistics
    nodes_rendered: u64 = 0,
    regions_cleared: u64 = 0,

    /// Initialize reconciler
    pub fn init(allocator: std.mem.Allocator) Reconciler {
        return .{
            .allocator = allocator,
        };
    }

    /// Set graphics context
    pub fn setGraphics(self: *Reconciler, graphics: *graphics_mod.Graphics) void {
        self.graphics = graphics;
    }

    /// Apply diff result to graphics
    pub fn apply(self: *Reconciler, result: DiffResult) !void {
        const graphics = self.graphics orelse return error.NoGraphics;

        // Clear dirty regions first
        if (self.config.use_dirty_regions) {
            for (result.dirty_rects.items) |rect| {
                graphics.fillRect(rect.x, rect.y, rect.width, rect.height, self.config.background_color);
                self.regions_cleared += 1;
            }
        }

        // Apply changes in order
        for (result.changes.items) |change| {
            try self.applyChange(graphics, change);
        }
    }

    /// Apply a single change
    fn applyChange(self: *Reconciler, graphics: *graphics_mod.Graphics, change: Change) !void {
        switch (change.change_type) {
            .create => {
                if (change.new_props) |props| {
                    try self.renderNode(graphics, change.node_type, props);
                }
            },
            .update => {
                // For updates, we re-render with new props
                // Old region was already cleared via dirty rects
                if (change.new_props) |props| {
                    try self.renderNode(graphics, change.node_type, props);
                }
            },
            .remove => {
                // Node removal handled by dirty rect clearing
                // No additional action needed
            },
            .move => {
                // Move is handled as clear old + render new
                if (change.new_props) |props| {
                    try self.renderNode(graphics, change.node_type, props);
                }
            },
        }
    }

    /// Render a node to graphics
    fn renderNode(self: *Reconciler, graphics: *graphics_mod.Graphics, node_type: VNodeType, props: VNodeProps) !void {
        if (!props.visible) return;

        switch (node_type) {
            .rect => self.renderRect(graphics, props),
            .circle => self.renderCircle(graphics, props),
            .line => self.renderLine(graphics, props),
            .text => self.renderText(graphics, props),
            .button => self.renderButton(graphics, props),
            .label => self.renderLabel(graphics, props),
            .panel => self.renderPanel(graphics, props),
            .progress => self.renderProgress(graphics, props),
            .container, .stack_h, .stack_v => self.renderContainer(graphics, props),
            else => {},
        }

        self.nodes_rendered += 1;
    }

    /// Render rectangle
    fn renderRect(self: *Reconciler, graphics: *graphics_mod.Graphics, props: VNodeProps) void {
        _ = self;
        if (props.corner_radius > 0) {
            graphics.fillRoundedRect(
                props.x,
                props.y,
                props.width,
                props.height,
                props.corner_radius,
                props.color,
            );
        } else {
            graphics.fillRect(props.x, props.y, props.width, props.height, props.color);
        }

        // Draw border if specified
        if (props.border_width > 0) {
            graphics.drawRect(props.x, props.y, props.width, props.height, props.border_color);
        }
    }

    /// Render circle
    fn renderCircle(self: *Reconciler, graphics: *graphics_mod.Graphics, props: VNodeProps) void {
        _ = self;
        graphics.fillCircle(props.x, props.y, props.radius, props.color);
    }

    /// Render line
    fn renderLine(self: *Reconciler, graphics: *graphics_mod.Graphics, props: VNodeProps) void {
        _ = self;
        // Line uses x,y as start and width,height as end point
        graphics.drawLine(
            props.x,
            props.y,
            props.x + @as(i32, props.width),
            props.y + @as(i32, props.height),
            props.color,
        );
    }

    /// Render text
    fn renderText(self: *Reconciler, graphics: *graphics_mod.Graphics, props: VNodeProps) void {
        _ = self;
        graphics.drawText(props.x, props.y, props.text, props.color);
    }

    /// Render button
    fn renderButton(self: *Reconciler, graphics: *graphics_mod.Graphics, props: VNodeProps) void {
        _ = self;
        const bg_color = if (props.pressed) darken(props.background) else props.background;

        // Draw button background
        if (props.corner_radius > 0) {
            graphics.fillRoundedRect(
                props.x,
                props.y,
                props.width,
                props.height,
                props.corner_radius,
                bg_color,
            );
        } else {
            graphics.fillRect(props.x, props.y, props.width, props.height, bg_color);
        }

        // Draw border
        if (props.border_width > 0) {
            graphics.drawRoundedRect(
                props.x,
                props.y,
                props.width,
                props.height,
                props.corner_radius,
                props.border_color,
            );
        }

        // Draw text centered
        if (props.text.len > 0) {
            const text_width = @as(i32, @intCast(props.text.len * 8)); // Approximate
            const text_x = props.x + @divTrunc(@as(i32, props.width) - text_width, 2);
            const text_y = props.y + @divTrunc(@as(i32, props.height) - 8, 2);
            graphics.drawText(text_x, text_y, props.text, props.color);
        }
    }

    /// Render label
    fn renderLabel(self: *Reconciler, graphics: *graphics_mod.Graphics, props: VNodeProps) void {
        _ = self;
        if (props.text.len == 0) return;

        var text_x = props.x;

        // Text alignment
        switch (props.text_align) {
            1 => { // Center
                const text_width = @as(i32, @intCast(props.text.len * 8));
                text_x = props.x + @divTrunc(@as(i32, props.width) - text_width, 2);
            },
            2 => { // Right
                const text_width = @as(i32, @intCast(props.text.len * 8));
                text_x = props.x + @as(i32, props.width) - text_width;
            },
            else => {}, // Left (default)
        }

        graphics.drawText(text_x, props.y, props.text, props.color);
    }

    /// Render panel
    fn renderPanel(self: *Reconciler, graphics: *graphics_mod.Graphics, props: VNodeProps) void {
        _ = self;
        // Draw background
        if (props.corner_radius > 0) {
            graphics.fillRoundedRect(
                props.x,
                props.y,
                props.width,
                props.height,
                props.corner_radius,
                props.background,
            );
        } else {
            graphics.fillRect(props.x, props.y, props.width, props.height, props.background);
        }

        // Draw border
        if (props.border_width > 0) {
            if (props.corner_radius > 0) {
                graphics.drawRoundedRect(
                    props.x,
                    props.y,
                    props.width,
                    props.height,
                    props.corner_radius,
                    props.border_color,
                );
            } else {
                graphics.drawRect(props.x, props.y, props.width, props.height, props.border_color);
            }
        }
    }

    /// Render progress bar
    fn renderProgress(self: *Reconciler, graphics: *graphics_mod.Graphics, props: VNodeProps) void {
        _ = self;
        // Background
        graphics.fillRect(props.x, props.y, props.width, props.height, props.background);

        // Calculate fill width based on flex property (0-100)
        const progress = @as(f32, @floatFromInt(@min(props.flex, 100))) / 100.0;
        const fill_width: u16 = @intFromFloat(@as(f32, @floatFromInt(props.width)) * progress);

        if (fill_width > 0) {
            graphics.fillRect(props.x, props.y, fill_width, props.height, props.color);
        }
    }

    /// Render container (background only, children handled separately)
    fn renderContainer(self: *Reconciler, graphics: *graphics_mod.Graphics, props: VNodeProps) void {
        _ = self;
        if (props.background != 0) {
            graphics.fillRect(props.x, props.y, props.width, props.height, props.background);
        }
    }

    /// Render full VDOM tree (for force redraw)
    pub fn renderFull(self: *Reconciler, tree: *VDom) !void {
        const graphics = self.graphics orelse return error.NoGraphics;

        // Clear entire screen
        graphics.clear(self.config.background_color);

        // Render from root
        if (tree.root) |root| {
            try self.renderTree(graphics, root);
        }
    }

    /// Recursively render tree
    fn renderTree(self: *Reconciler, graphics: *graphics_mod.Graphics, node: *VNode) !void {
        // Render this node
        try self.renderNode(graphics, node.node_type, node.props);

        // Render children
        var child = node.first_child;
        while (child) |c| {
            try self.renderTree(graphics, c);
            child = c.next_sibling;
        }
    }

    /// Get render statistics
    pub fn getStats(self: *const Reconciler) struct { nodes_rendered: u64, regions_cleared: u64 } {
        return .{
            .nodes_rendered = self.nodes_rendered,
            .regions_cleared = self.regions_cleared,
        };
    }

    /// Reset statistics
    pub fn resetStats(self: *Reconciler) void {
        self.nodes_rendered = 0;
        self.regions_cleared = 0;
    }
};

/// Darken a color (for pressed state)
fn darken(color: u16) u16 {
    // RGB565: RRRRRGGG GGGBBBBB
    const r = (color >> 11) & 0x1F;
    const g = (color >> 5) & 0x3F;
    const b = color & 0x1F;

    // Reduce each component by 25%
    const new_r = r * 3 / 4;
    const new_g = g * 3 / 4;
    const new_b = b * 3 / 4;

    return (@as(u16, @intCast(new_r)) << 11) | (@as(u16, @intCast(new_g)) << 5) | @as(u16, @intCast(new_b));
}

/// Lighten a color (for hover state)
fn lighten(color: u16) u16 {
    const r = (color >> 11) & 0x1F;
    const g = (color >> 5) & 0x3F;
    const b = color & 0x1F;

    // Increase each component by 25%, capping at max
    const new_r = @min(r + r / 4, 0x1F);
    const new_g = @min(g + g / 4, 0x3F);
    const new_b = @min(b + b / 4, 0x1F);

    return (@as(u16, @intCast(new_r)) << 11) | (@as(u16, @intCast(new_g)) << 5) | @as(u16, @intCast(new_b));
}

// Tests
test "Reconciler initialization" {
    const allocator = std.testing.allocator;
    var rec = Reconciler.init(allocator);

    try std.testing.expectEqual(@as(u64, 0), rec.nodes_rendered);
    try std.testing.expect(rec.graphics == null);
}

test "darken color" {
    const white: u16 = 0xFFFF;
    const darkened = darken(white);

    // Should be darker (smaller values)
    try std.testing.expect(darkened < white);
}

test "lighten color" {
    const dark: u16 = 0x8410; // Mid-gray
    const lightened = lighten(dark);

    // Should be lighter (larger values)
    try std.testing.expect(lightened > dark);
}
