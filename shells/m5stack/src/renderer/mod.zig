//! Virtual DOM Renderer for M5Stack CoreS3
//!
//! Lightweight Virtual DOM implementation optimized for embedded displays.
//! Provides efficient diffing and minimal redraws.
//!
//! Features:
//! - Node-based UI tree representation
//! - Efficient diff algorithm
//! - Dirty region tracking
//! - Integration with graphics subsystem
//!
//! Architecture:
//! App State → VDOM Tree → Diff → Render Commands → Graphics

const std = @import("std");
const graphics_mod = @import("../graphics/graphics.zig");
const framebuffer_mod = @import("../graphics/framebuffer.zig");
const ui_mod = @import("../ui/mod.zig");

pub const vdom = @import("vdom.zig");
pub const diff = @import("diff.zig");
pub const reconciler = @import("reconciler.zig");

// Re-export types
pub const VNode = vdom.VNode;
pub const VNodeType = vdom.VNodeType;
pub const VNodeProps = vdom.VNodeProps;
pub const VDom = vdom.VDom;
pub const DiffResult = diff.DiffResult;
pub const Reconciler = reconciler.Reconciler;

/// Renderer configuration
pub const RendererConfig = struct {
    /// Maximum nodes in virtual DOM tree
    max_nodes: usize = 256,

    /// Enable dirty region optimization
    dirty_regions: bool = true,

    /// Enable node reuse (object pooling)
    node_pooling: bool = true,

    /// Maximum depth of tree
    max_depth: u8 = 16,

    /// Allocator for dynamic allocations
    allocator: ?std.mem.Allocator = null,
};

/// Render statistics
pub const RenderStats = struct {
    nodes_created: u64 = 0,
    nodes_updated: u64 = 0,
    nodes_removed: u64 = 0,
    diffs_calculated: u64 = 0,
    frames_rendered: u64 = 0,
    dirty_regions_used: u64 = 0,
};

/// Main renderer for M5Stack Virtual DOM
pub const Renderer = struct {
    config: RendererConfig,
    allocator: std.mem.Allocator,

    // Virtual DOM trees (double-buffered for diffing)
    current_tree: ?*vdom.VDom = null,
    next_tree: ?*vdom.VDom = null,

    // Reconciler for applying diffs
    reconciler_instance: ?reconciler.Reconciler = null,

    // Graphics context
    graphics: ?*graphics_mod.Graphics = null,

    // Statistics
    stats: RenderStats = .{},

    // State
    initialized: bool = false,

    /// Initialize renderer
    pub fn init(config: RendererConfig) !Renderer {
        const allocator = config.allocator orelse return error.NoAllocator;

        var renderer = Renderer{
            .config = config,
            .allocator = allocator,
        };

        // Create virtual DOM trees
        renderer.current_tree = try vdom.VDom.create(allocator, config.max_nodes);
        renderer.next_tree = try vdom.VDom.create(allocator, config.max_nodes);

        // Create reconciler
        renderer.reconciler_instance = reconciler.Reconciler.init(allocator);

        renderer.initialized = true;
        return renderer;
    }

    /// Deinitialize renderer
    pub fn deinit(self: *Renderer) void {
        if (self.current_tree) |tree| {
            tree.destroy(self.allocator);
        }
        if (self.next_tree) |tree| {
            tree.destroy(self.allocator);
        }
        self.initialized = false;
    }

    /// Set graphics context
    pub fn setGraphics(self: *Renderer, graphics: *graphics_mod.Graphics) void {
        self.graphics = graphics;
        if (self.reconciler_instance) |*rec| {
            rec.setGraphics(graphics);
        }
    }

    /// Begin building new VDOM tree
    pub fn begin(self: *Renderer) !*vdom.VDom {
        if (self.next_tree) |tree| {
            tree.clear();
            return tree;
        }
        return error.NotInitialized;
    }

    /// Render the VDOM tree
    pub fn render(self: *Renderer) !void {
        if (!self.initialized) return error.NotInitialized;

        const current = self.current_tree orelse return error.NotInitialized;
        const next = self.next_tree orelse return error.NotInitialized;

        // Calculate diff
        const diff_result = try diff.calculate(self.allocator, current, next);
        defer diff_result.deinit();

        self.stats.diffs_calculated += 1;

        // Apply changes through reconciler
        if (self.reconciler_instance) |*rec| {
            try rec.apply(diff_result);
            self.updateStatsFromDiff(diff_result);
        }

        // Swap trees
        const temp = self.current_tree;
        self.current_tree = self.next_tree;
        self.next_tree = temp;

        self.stats.frames_rendered += 1;
    }

    /// Force full redraw
    pub fn forceRedraw(self: *Renderer) !void {
        if (!self.initialized) return error.NotInitialized;

        if (self.current_tree) |tree| {
            if (self.reconciler_instance) |*rec| {
                try rec.renderFull(tree);
            }
        }
    }

    /// Update statistics from diff result
    fn updateStatsFromDiff(self: *Renderer, result: diff.DiffResult) void {
        for (result.changes.items) |change| {
            switch (change.change_type) {
                .create => self.stats.nodes_created += 1,
                .update => self.stats.nodes_updated += 1,
                .remove => self.stats.nodes_removed += 1,
                .move => self.stats.nodes_updated += 1,
            }
        }
    }

    /// Get render statistics
    pub fn getStats(self: *const Renderer) RenderStats {
        return self.stats;
    }

    /// Reset statistics
    pub fn resetStats(self: *Renderer) void {
        self.stats = .{};
    }
};

/// Helper to create a text node
pub fn text(tree: *vdom.VDom, content: []const u8, x: i32, y: i32, color: u16) !*vdom.VNode {
    return tree.createNode(.text, .{
        .text = content,
        .x = x,
        .y = y,
        .color = color,
    });
}

/// Helper to create a rect node
pub fn rect(tree: *vdom.VDom, x: i32, y: i32, width: u16, height: u16, color: u16) !*vdom.VNode {
    return tree.createNode(.rect, .{
        .x = x,
        .y = y,
        .width = width,
        .height = height,
        .color = color,
    });
}

/// Helper to create a circle node
pub fn circle(tree: *vdom.VDom, cx: i32, cy: i32, radius: u16, color: u16) !*vdom.VNode {
    return tree.createNode(.circle, .{
        .x = cx,
        .y = cy,
        .radius = radius,
        .color = color,
    });
}

/// Helper to create a button node
pub fn button(tree: *vdom.VDom, x: i32, y: i32, width: u16, height: u16, label: []const u8) !*vdom.VNode {
    return tree.createNode(.button, .{
        .x = x,
        .y = y,
        .width = width,
        .height = height,
        .text = label,
    });
}

/// Helper to create a container node
pub fn container(tree: *vdom.VDom, x: i32, y: i32, width: u16, height: u16) !*vdom.VNode {
    return tree.createNode(.container, .{
        .x = x,
        .y = y,
        .width = width,
        .height = height,
    });
}

// Tests
test "Renderer configuration defaults" {
    const config = RendererConfig{};
    try std.testing.expectEqual(@as(usize, 256), config.max_nodes);
    try std.testing.expect(config.dirty_regions);
    try std.testing.expect(config.node_pooling);
}

test "RenderStats initialization" {
    const stats = RenderStats{};
    try std.testing.expectEqual(@as(u64, 0), stats.nodes_created);
    try std.testing.expectEqual(@as(u64, 0), stats.frames_rendered);
}
