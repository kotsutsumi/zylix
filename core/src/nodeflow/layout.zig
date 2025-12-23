//! Layout & Styling API
//!
//! Manage node graph layout and visual styling:
//! - Auto-layout algorithms (tree, dagre, force-directed)
//! - Viewport and pan/zoom management
//! - Minimap component
//! - Grid and snapping
//! - Theme support
//!
//! This module provides layout and styling for React Flow-style node graphs.

const std = @import("std");
const nodes = @import("nodes.zig");
const edges = @import("edges.zig");

/// Layout error types
pub const LayoutError = error{
    InvalidLayout,
    CycleDetected,
    NoRootNode,
    LayoutFailed,
    ViewportError,
    OutOfMemory,
};

/// Layout direction
pub const LayoutDirection = enum(u8) {
    top_to_bottom = 0,
    bottom_to_top = 1,
    left_to_right = 2,
    right_to_left = 3,

    pub fn isHorizontal(self: LayoutDirection) bool {
        return self == .left_to_right or self == .right_to_left;
    }

    pub fn isVertical(self: LayoutDirection) bool {
        return self == .top_to_bottom or self == .bottom_to_top;
    }
};

/// Layout algorithm type
pub const LayoutAlgorithm = enum(u8) {
    manual = 0, // No auto-layout
    tree = 1, // Hierarchical tree layout
    dagre = 2, // Directed acyclic graph layout
    force = 3, // Force-directed layout
    grid = 4, // Grid-based layout
    radial = 5, // Radial/circular layout

    pub fn toString(self: LayoutAlgorithm) []const u8 {
        return switch (self) {
            .manual => "Manual",
            .tree => "Tree",
            .dagre => "Dagre",
            .force => "Force",
            .grid => "Grid",
            .radial => "Radial",
        };
    }

    pub fn isAutomatic(self: LayoutAlgorithm) bool {
        return self != .manual;
    }
};

/// Layout options
pub const LayoutOptions = struct {
    algorithm: LayoutAlgorithm = .dagre,
    direction: LayoutDirection = .top_to_bottom,
    node_spacing: f32 = 50.0,
    rank_spacing: f32 = 100.0, // Space between levels/ranks
    edge_spacing: f32 = 20.0,
    center_graph: bool = true,
    fit_view: bool = true,
    animate: bool = true,
    animation_duration: f32 = 300.0, // ms
};

/// Viewport bounds
pub const Bounds = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,

    pub fn center(self: Bounds) nodes.Position {
        return .{
            .x = self.x + self.width / 2,
            .y = self.y + self.height / 2,
        };
    }

    pub fn contains(self: Bounds, pos: nodes.Position) bool {
        return pos.x >= self.x and pos.x <= self.x + self.width and
            pos.y >= self.y and pos.y <= self.y + self.height;
    }

    pub fn expand(self: Bounds, padding: f32) Bounds {
        return .{
            .x = self.x - padding,
            .y = self.y - padding,
            .width = self.width + padding * 2,
            .height = self.height + padding * 2,
        };
    }

    pub fn intersects(self: Bounds, other: Bounds) bool {
        return !(self.x + self.width < other.x or
            other.x + other.width < self.x or
            self.y + self.height < other.y or
            other.y + other.height < self.y);
    }
};

/// Viewport state
pub const Viewport = struct {
    x: f32 = 0, // Pan X
    y: f32 = 0, // Pan Y
    zoom: f32 = 1.0, // Zoom level
    min_zoom: f32 = 0.1,
    max_zoom: f32 = 4.0,

    pub fn screenToWorld(self: Viewport, screen_x: f32, screen_y: f32) nodes.Position {
        return .{
            .x = (screen_x - self.x) / self.zoom,
            .y = (screen_y - self.y) / self.zoom,
        };
    }

    pub fn worldToScreen(self: Viewport, world_x: f32, world_y: f32) nodes.Position {
        return .{
            .x = world_x * self.zoom + self.x,
            .y = world_y * self.zoom + self.y,
        };
    }

    pub fn setZoom(self: *Viewport, zoom: f32) void {
        self.zoom = std.math.clamp(zoom, self.min_zoom, self.max_zoom);
    }

    pub fn zoomIn(self: *Viewport, factor: f32) void {
        self.setZoom(self.zoom * factor);
    }

    pub fn zoomOut(self: *Viewport, factor: f32) void {
        self.setZoom(self.zoom / factor);
    }

    pub fn pan(self: *Viewport, dx: f32, dy: f32) void {
        self.x += dx;
        self.y += dy;
    }

    pub fn reset(self: *Viewport) void {
        self.x = 0;
        self.y = 0;
        self.zoom = 1.0;
    }

    pub fn fitBounds(self: *Viewport, bounds: Bounds, view_width: f32, view_height: f32, padding: f32) void {
        const padded = bounds.expand(padding);
        const zoom_x = view_width / padded.width;
        const zoom_y = view_height / padded.height;
        self.zoom = std.math.clamp(@min(zoom_x, zoom_y), self.min_zoom, self.max_zoom);

        const center = padded.center();
        self.x = view_width / 2 - center.x * self.zoom;
        self.y = view_height / 2 - center.y * self.zoom;
    }
};

/// Grid configuration
pub const GridConfig = struct {
    enabled: bool = true,
    size: f32 = 20.0,
    snap_to_grid: bool = true,
    show_grid: bool = true,
    grid_color: u32 = 0xE0E0E020, // Light gray, low opacity
    grid_style: GridStyle = .dots,

    pub fn snapPosition(self: GridConfig, pos: nodes.Position) nodes.Position {
        if (!self.snap_to_grid) return pos;
        return .{
            .x = @round(pos.x / self.size) * self.size,
            .y = @round(pos.y / self.size) * self.size,
        };
    }
};

/// Grid visual style
pub const GridStyle = enum(u8) {
    lines = 0,
    dots = 1,
    cross = 2,
};

/// Minimap configuration
pub const MinimapConfig = struct {
    enabled: bool = true,
    position: MinimapPosition = .bottom_right,
    width: f32 = 200.0,
    height: f32 = 150.0,
    margin: f32 = 10.0,
    background_color: u32 = 0xFFFFFF80,
    border_color: u32 = 0xCCCCCCFF,
    node_color: u32 = 0x1A73E8FF,
    mask_color: u32 = 0x00000020,
    show_mask: bool = true,
};

/// Minimap position
pub const MinimapPosition = enum(u8) {
    top_left = 0,
    top_right = 1,
    bottom_left = 2,
    bottom_right = 3,
};

/// Theme colors
pub const ThemeColors = struct {
    background: u32 = 0xF8F8F8FF,
    node_background: u32 = 0xFFFFFFFF,
    node_border: u32 = 0xCCCCCCFF,
    node_selected_border: u32 = 0x1A73E8FF,
    handle_color: u32 = 0x555555FF,
    handle_connected: u32 = 0x1A73E8FF,
    edge_color: u32 = 0x808080FF,
    edge_selected: u32 = 0x1A73E8FF,
    text_primary: u32 = 0x333333FF,
    text_secondary: u32 = 0x666666FF,
    selection_box: u32 = 0x1A73E830,
    selection_border: u32 = 0x1A73E8FF,
};

/// Built-in themes
pub const Theme = enum(u8) {
    light = 0,
    dark = 1,
    high_contrast = 2,
    custom = 255,

    pub fn getColors(self: Theme) ThemeColors {
        return switch (self) {
            .light => .{},
            .dark => .{
                .background = 0x1E1E1EFF,
                .node_background = 0x2D2D2DFF,
                .node_border = 0x404040FF,
                .node_selected_border = 0x4FC3F7FF,
                .handle_color = 0x808080FF,
                .handle_connected = 0x4FC3F7FF,
                .edge_color = 0x606060FF,
                .edge_selected = 0x4FC3F7FF,
                .text_primary = 0xE0E0E0FF,
                .text_secondary = 0xA0A0A0FF,
                .selection_box = 0x4FC3F730,
                .selection_border = 0x4FC3F7FF,
            },
            .high_contrast => .{
                .background = 0x000000FF,
                .node_background = 0x000000FF,
                .node_border = 0xFFFFFFFF,
                .node_selected_border = 0xFFFF00FF,
                .handle_color = 0xFFFFFFFF,
                .handle_connected = 0xFFFF00FF,
                .edge_color = 0xFFFFFFFF,
                .edge_selected = 0xFFFF00FF,
                .text_primary = 0xFFFFFFFF,
                .text_secondary = 0xCCCCCCFF,
                .selection_box = 0xFFFF0040,
                .selection_border = 0xFFFF00FF,
            },
            .custom => .{},
        };
    }
};

/// Layout result for a single node
pub const NodeLayout = struct {
    node_id: nodes.NodeId,
    position: nodes.Position,
    level: u32 = 0, // Hierarchy level
};

/// Complete layout result
pub const LayoutResult = struct {
    node_layouts: []const NodeLayout,
    bounds: Bounds,
    levels: u32,
    success: bool = true,
    message: ?[]const u8 = null,
};

/// Layout Manager
pub const LayoutManager = struct {
    allocator: std.mem.Allocator,
    viewport: Viewport = .{},
    grid: GridConfig = .{},
    minimap: MinimapConfig = .{},
    theme: Theme = .light,
    custom_colors: ThemeColors = .{},
    options: LayoutOptions = .{},

    pub fn init(allocator: std.mem.Allocator) LayoutManager {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *LayoutManager) void {
        _ = self;
        // Nothing to free currently
    }

    /// Set layout options
    pub fn setOptions(self: *LayoutManager, options: LayoutOptions) void {
        self.options = options;
    }

    /// Set theme
    pub fn setTheme(self: *LayoutManager, theme: Theme) void {
        self.theme = theme;
        if (theme != .custom) {
            self.custom_colors = theme.getColors();
        }
    }

    /// Set custom theme colors
    pub fn setCustomColors(self: *LayoutManager, colors: ThemeColors) void {
        self.theme = .custom;
        self.custom_colors = colors;
    }

    /// Get current theme colors
    pub fn getColors(self: *const LayoutManager) ThemeColors {
        return if (self.theme == .custom) self.custom_colors else self.theme.getColors();
    }

    /// Apply auto-layout to nodes
    pub fn applyLayout(self: *LayoutManager, node_manager: *nodes.NodeManager, edge_manager: *const edges.EdgeManager) LayoutError!LayoutResult {
        return switch (self.options.algorithm) {
            .manual => self.manualLayout(node_manager),
            .tree => self.treeLayout(node_manager, edge_manager),
            .dagre => self.dagreLayout(node_manager, edge_manager),
            .grid => self.gridLayout(node_manager),
            .force => self.forceLayout(node_manager, edge_manager),
            .radial => self.radialLayout(node_manager, edge_manager),
        };
    }

    /// Calculate graph bounds
    pub fn calculateBounds(self: *const LayoutManager, node_manager: *const nodes.NodeManager) Bounds {
        _ = self;
        var min_x: f32 = std.math.floatMax(f32);
        var min_y: f32 = std.math.floatMax(f32);
        var max_x: f32 = std.math.floatMin(f32);
        var max_y: f32 = std.math.floatMin(f32);

        var found_any = false;
        var iter = node_manager.nodes.iterator();
        while (iter.next()) |entry| {
            const node = entry.value_ptr;
            found_any = true;
            min_x = @min(min_x, node.position.x);
            min_y = @min(min_y, node.position.y);
            max_x = @max(max_x, node.position.x + node.dimensions.width);
            max_y = @max(max_y, node.position.y + node.dimensions.height);
        }

        if (!found_any) {
            return .{ .x = 0, .y = 0, .width = 0, .height = 0 };
        }

        return .{
            .x = min_x,
            .y = min_y,
            .width = max_x - min_x,
            .height = max_y - min_y,
        };
    }

    /// Fit viewport to show all nodes
    pub fn fitView(self: *LayoutManager, node_manager: *const nodes.NodeManager, view_width: f32, view_height: f32, padding: f32) void {
        const bounds = self.calculateBounds(node_manager);
        self.viewport.fitBounds(bounds, view_width, view_height, padding);
    }

    /// Center viewport on a specific node
    pub fn centerOnNode(self: *LayoutManager, node_manager: *const nodes.NodeManager, node_id: nodes.NodeId, view_width: f32, view_height: f32) void {
        if (node_manager.getNode(node_id)) |node| {
            const center_x = node.position.x + node.dimensions.width / 2;
            const center_y = node.position.y + node.dimensions.height / 2;
            self.viewport.x = view_width / 2 - center_x * self.viewport.zoom;
            self.viewport.y = view_height / 2 - center_y * self.viewport.zoom;
        }
    }

    /// Snap position to grid if enabled
    pub fn snapToGrid(self: *const LayoutManager, pos: nodes.Position) nodes.Position {
        return self.grid.snapPosition(pos);
    }

    // Layout algorithm implementations

    fn manualLayout(self: *LayoutManager, node_manager: *nodes.NodeManager) LayoutResult {
        return .{
            .node_layouts = &.{},
            .bounds = self.calculateBounds(node_manager),
            .levels = 0,
        };
    }

    fn treeLayout(self: *LayoutManager, node_manager: *nodes.NodeManager, edge_manager: *const edges.EdgeManager) LayoutResult {
        // Find root nodes (nodes with no incoming edges)
        var roots = std.ArrayListUnmanaged(nodes.NodeId){};
        defer roots.deinit(self.allocator);

        var iter = node_manager.nodes.iterator();
        while (iter.next()) |entry| {
            const node_id = nodes.NodeId{ .id = entry.key_ptr.* };
            const incoming = edge_manager.getIncomingEdges(node_id);
            if (incoming.len == 0) {
                roots.append(self.allocator, node_id) catch continue;
            }
        }

        if (roots.items.len == 0) {
            return .{
                .node_layouts = &.{},
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
                .levels = 0,
                .success = false,
                .message = "No root nodes found",
            };
        }

        // BFS layout from roots
        var layouts = std.ArrayListUnmanaged(NodeLayout){};
        defer layouts.deinit(self.allocator);

        var visited = std.AutoHashMapUnmanaged(u64, bool){};
        defer visited.deinit(self.allocator);

        var queue = std.ArrayListUnmanaged(struct { id: nodes.NodeId, level: u32 }){};
        defer queue.deinit(self.allocator);

        // Initialize with roots
        for (roots.items, 0..) |root, i| {
            queue.append(self.allocator, .{ .id = root, .level = 0 }) catch continue;
            visited.put(self.allocator, root.id, true) catch continue;

            const x = @as(f32, @floatFromInt(i)) * (150.0 + self.options.node_spacing);
            const y: f32 = 0;

            if (node_manager.getNodeMut(root)) |node| {
                node.position = .{ .x = x, .y = y };
            }

            layouts.append(self.allocator, .{
                .node_id = root,
                .position = .{ .x = x, .y = y },
                .level = 0,
            }) catch continue;
        }

        var max_level: u32 = 0;
        var queue_idx: usize = 0;
        while (queue_idx < queue.items.len) {
            const current = queue.items[queue_idx];
            queue_idx += 1;

            const outgoing = edge_manager.getOutgoingEdges(current.id);
            var child_idx: usize = 0;

            for (outgoing) |edge_id| {
                if (edge_manager.getEdge(edge_id)) |edge| {
                    const child_id = edge.target.node_id;
                    if (!visited.contains(child_id.id)) {
                        visited.put(self.allocator, child_id.id, true) catch continue;
                        queue.append(self.allocator, .{ .id = child_id, .level = current.level + 1 }) catch continue;

                        const x = @as(f32, @floatFromInt(child_idx)) * (150.0 + self.options.node_spacing);
                        const y = @as(f32, @floatFromInt(current.level + 1)) * self.options.rank_spacing;

                        if (node_manager.getNodeMut(child_id)) |node| {
                            node.position = .{ .x = x, .y = y };
                        }

                        layouts.append(self.allocator, .{
                            .node_id = child_id,
                            .position = .{ .x = x, .y = y },
                            .level = current.level + 1,
                        }) catch continue;

                        max_level = @max(max_level, current.level + 1);
                        child_idx += 1;
                    }
                }
            }
        }

        const owned_layouts = layouts.toOwnedSlice(self.allocator) catch &.{};

        return .{
            .node_layouts = owned_layouts,
            .bounds = self.calculateBounds(node_manager),
            .levels = max_level + 1,
        };
    }

    fn dagreLayout(self: *LayoutManager, node_manager: *nodes.NodeManager, edge_manager: *const edges.EdgeManager) LayoutResult {
        // Simplified dagre-like layout (uses tree layout as base)
        return self.treeLayout(node_manager, edge_manager);
    }

    fn gridLayout(self: *LayoutManager, node_manager: *nodes.NodeManager) LayoutResult {
        var layouts = std.ArrayListUnmanaged(NodeLayout){};
        defer layouts.deinit(self.allocator);

        const node_count = node_manager.count();
        const cols = @as(u32, @intFromFloat(@ceil(@sqrt(@as(f64, @floatFromInt(node_count))))));

        var idx: u32 = 0;
        var iter = node_manager.nodes.iterator();
        while (iter.next()) |entry| {
            const node = entry.value_ptr;
            const col = idx % cols;
            const row = idx / cols;

            const x = @as(f32, @floatFromInt(col)) * (150.0 + self.options.node_spacing);
            const y = @as(f32, @floatFromInt(row)) * (100.0 + self.options.node_spacing);

            node.position = .{ .x = x, .y = y };
            layouts.append(self.allocator, .{
                .node_id = node.id,
                .position = .{ .x = x, .y = y },
                .level = row,
            }) catch continue;

            idx += 1;
        }

        const owned_layouts = layouts.toOwnedSlice(self.allocator) catch &.{};

        return .{
            .node_layouts = owned_layouts,
            .bounds = self.calculateBounds(node_manager),
            .levels = if (cols > 0) (node_count + cols - 1) / cols else 0,
        };
    }

    fn forceLayout(self: *LayoutManager, node_manager: *nodes.NodeManager, edge_manager: *const edges.EdgeManager) LayoutResult {
        // Simplified force-directed layout
        _ = edge_manager;

        // For now, just use grid layout as placeholder
        return self.gridLayout(node_manager);
    }

    fn radialLayout(self: *LayoutManager, node_manager: *nodes.NodeManager, edge_manager: *const edges.EdgeManager) LayoutResult {
        _ = edge_manager;

        var layouts = std.ArrayListUnmanaged(NodeLayout){};
        defer layouts.deinit(self.allocator);

        const node_count = node_manager.count();
        if (node_count == 0) {
            return .{
                .node_layouts = &.{},
                .bounds = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
                .levels = 0,
            };
        }

        const radius: f32 = @as(f32, @floatFromInt(node_count)) * 30.0;
        const angle_step = 2.0 * std.math.pi / @as(f32, @floatFromInt(node_count));

        var idx: u32 = 0;
        var iter = node_manager.nodes.iterator();
        while (iter.next()) |entry| {
            const node = entry.value_ptr;
            const angle = @as(f32, @floatFromInt(idx)) * angle_step;

            const x = radius * @cos(angle);
            const y = radius * @sin(angle);

            node.position = .{ .x = x, .y = y };
            layouts.append(self.allocator, .{
                .node_id = node.id,
                .position = .{ .x = x, .y = y },
                .level = 0,
            }) catch continue;

            idx += 1;
        }

        const owned_layouts = layouts.toOwnedSlice(self.allocator) catch &.{};

        return .{
            .node_layouts = owned_layouts,
            .bounds = self.calculateBounds(node_manager),
            .levels = 1,
        };
    }
};

/// Create a layout manager
pub fn createLayoutManager(allocator: std.mem.Allocator) LayoutManager {
    return LayoutManager.init(allocator);
}

// Tests
test "LayoutManager initialization" {
    const allocator = std.testing.allocator;
    var manager = createLayoutManager(allocator);
    defer manager.deinit();

    try std.testing.expectEqual(Theme.light, manager.theme);
    try std.testing.expectEqual(LayoutAlgorithm.dagre, manager.options.algorithm);
}

test "Viewport operations" {
    var viewport = Viewport{};

    try std.testing.expectEqual(@as(f32, 1.0), viewport.zoom);

    viewport.zoomIn(1.5);
    try std.testing.expectEqual(@as(f32, 1.5), viewport.zoom);

    viewport.zoomOut(1.5);
    try std.testing.expectEqual(@as(f32, 1.0), viewport.zoom);

    viewport.pan(100, 50);
    try std.testing.expectEqual(@as(f32, 100), viewport.x);
    try std.testing.expectEqual(@as(f32, 50), viewport.y);

    viewport.reset();
    try std.testing.expectEqual(@as(f32, 0), viewport.x);
    try std.testing.expectEqual(@as(f32, 0), viewport.y);
    try std.testing.expectEqual(@as(f32, 1.0), viewport.zoom);
}

test "Viewport coordinate transformation" {
    var viewport = Viewport{ .x = 100, .y = 50, .zoom = 2.0 };

    const world_pos = viewport.screenToWorld(300, 150);
    try std.testing.expectEqual(@as(f32, 100), world_pos.x);
    try std.testing.expectEqual(@as(f32, 50), world_pos.y);

    const screen_pos = viewport.worldToScreen(100, 50);
    try std.testing.expectEqual(@as(f32, 300), screen_pos.x);
    try std.testing.expectEqual(@as(f32, 150), screen_pos.y);
}

test "Bounds operations" {
    const bounds = Bounds{ .x = 10, .y = 20, .width = 100, .height = 80 };

    const center = bounds.center();
    try std.testing.expectEqual(@as(f32, 60), center.x);
    try std.testing.expectEqual(@as(f32, 60), center.y);

    try std.testing.expect(bounds.contains(.{ .x = 50, .y = 50 }));
    try std.testing.expect(!bounds.contains(.{ .x = 0, .y = 0 }));

    const expanded = bounds.expand(10);
    try std.testing.expectEqual(@as(f32, 0), expanded.x);
    try std.testing.expectEqual(@as(f32, 10), expanded.y);
    try std.testing.expectEqual(@as(f32, 120), expanded.width);
}

test "Grid snapping" {
    const grid = GridConfig{ .size = 20.0, .snap_to_grid = true };

    const snapped = grid.snapPosition(.{ .x = 15, .y = 27 });
    try std.testing.expectEqual(@as(f32, 20), snapped.x);
    try std.testing.expectEqual(@as(f32, 20), snapped.y);
}

test "Theme colors" {
    const light = Theme.light.getColors();
    try std.testing.expectEqual(@as(u32, 0xF8F8F8FF), light.background);

    const dark = Theme.dark.getColors();
    try std.testing.expectEqual(@as(u32, 0x1E1E1EFF), dark.background);
}

test "Layout direction" {
    try std.testing.expect(LayoutDirection.left_to_right.isHorizontal());
    try std.testing.expect(LayoutDirection.right_to_left.isHorizontal());
    try std.testing.expect(!LayoutDirection.top_to_bottom.isHorizontal());

    try std.testing.expect(LayoutDirection.top_to_bottom.isVertical());
    try std.testing.expect(!LayoutDirection.left_to_right.isVertical());
}

test "Layout algorithm" {
    try std.testing.expect(std.mem.eql(u8, "Dagre", LayoutAlgorithm.dagre.toString()));
    try std.testing.expect(LayoutAlgorithm.dagre.isAutomatic());
    try std.testing.expect(!LayoutAlgorithm.manual.isAutomatic());
}

test "Bounds intersection" {
    const b1 = Bounds{ .x = 0, .y = 0, .width = 100, .height = 100 };
    const b2 = Bounds{ .x = 50, .y = 50, .width = 100, .height = 100 };
    const b3 = Bounds{ .x = 200, .y = 200, .width = 50, .height = 50 };

    try std.testing.expect(b1.intersects(b2));
    try std.testing.expect(!b1.intersects(b3));
}

test "Viewport zoom limits" {
    var viewport = Viewport{};

    viewport.setZoom(0.01);
    try std.testing.expectEqual(@as(f32, 0.1), viewport.zoom);

    viewport.setZoom(10.0);
    try std.testing.expectEqual(@as(f32, 4.0), viewport.zoom);
}
