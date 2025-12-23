//! Core Node System API
//!
//! React Flow-style node system with support for:
//! - Customizable node types and content
//! - Handle positions and ports
//! - Node selection and grouping
//! - Drag-and-drop placement
//!
//! This module provides the core node primitives for visual programming.

const std = @import("std");

/// Node error types
pub const NodeError = error{
    NodeNotFound,
    InvalidPosition,
    InvalidDimensions,
    HandleNotFound,
    DuplicateId,
    GroupNotFound,
    OutOfMemory,
};

/// Unique node identifier
pub const NodeId = struct {
    id: u64,

    pub fn isValid(self: *const NodeId) bool {
        return self.id > 0;
    }

    pub fn eql(self: *const NodeId, other: NodeId) bool {
        return self.id == other.id;
    }
};

/// 2D position
pub const Position = struct {
    x: f32 = 0,
    y: f32 = 0,

    pub fn add(self: Position, other: Position) Position {
        return .{ .x = self.x + other.x, .y = self.y + other.y };
    }

    pub fn sub(self: Position, other: Position) Position {
        return .{ .x = self.x - other.x, .y = self.y - other.y };
    }

    pub fn scale(self: Position, factor: f32) Position {
        return .{ .x = self.x * factor, .y = self.y * factor };
    }

    pub fn distance(self: Position, other: Position) f32 {
        const dx = self.x - other.x;
        const dy = self.y - other.y;
        return @sqrt(dx * dx + dy * dy);
    }
};

/// 2D dimensions
pub const Dimensions = struct {
    width: f32 = 150,
    height: f32 = 50,

    pub fn contains(self: Dimensions, pos: Position, origin: Position) bool {
        return pos.x >= origin.x and pos.x <= origin.x + self.width and
               pos.y >= origin.y and pos.y <= origin.y + self.height;
    }
};

/// Handle/port position on node
pub const HandlePosition = enum(u8) {
    top = 0,
    right = 1,
    bottom = 2,
    left = 3,

    pub fn isHorizontal(self: HandlePosition) bool {
        return self == .left or self == .right;
    }

    pub fn isVertical(self: HandlePosition) bool {
        return self == .top or self == .bottom;
    }

    pub fn opposite(self: HandlePosition) HandlePosition {
        return switch (self) {
            .top => .bottom,
            .bottom => .top,
            .left => .right,
            .right => .left,
        };
    }
};

/// Handle/port type
pub const HandleType = enum(u8) {
    source = 0,  // Output
    target = 1,  // Input
    both = 2,    // Bidirectional

    pub fn canConnect(self: HandleType, other: HandleType) bool {
        if (self == .both or other == .both) return true;
        return self != other;
    }
};

/// Handle/port definition
pub const Handle = struct {
    id: []const u8,
    handle_type: HandleType = .source,
    position: HandlePosition = .right,
    /// Offset from default position (0.0 - 1.0)
    offset: f32 = 0.5,
    /// Maximum number of connections (0 = unlimited)
    max_connections: u32 = 0,
    /// Current connection count
    connection_count: u32 = 0,
    /// Is handle currently connectable
    connectable: bool = true,
    /// Custom style class
    style_class: ?[]const u8 = null,

    pub fn canAcceptConnection(self: *const Handle) bool {
        if (!self.connectable) return false;
        if (self.max_connections == 0) return true;
        return self.connection_count < self.max_connections;
    }

    /// Get absolute position of handle on node
    pub fn getAbsolutePosition(self: *const Handle, node_pos: Position, node_dim: Dimensions) Position {
        return switch (self.position) {
            .top => .{
                .x = node_pos.x + node_dim.width * self.offset,
                .y = node_pos.y,
            },
            .bottom => .{
                .x = node_pos.x + node_dim.width * self.offset,
                .y = node_pos.y + node_dim.height,
            },
            .left => .{
                .x = node_pos.x,
                .y = node_pos.y + node_dim.height * self.offset,
            },
            .right => .{
                .x = node_pos.x + node_dim.width,
                .y = node_pos.y + node_dim.height * self.offset,
            },
        };
    }
};

/// Node type category
pub const NodeType = enum(u8) {
    default = 0,
    input = 1,
    output = 2,
    custom = 3,
    group = 4,

    pub fn toString(self: NodeType) []const u8 {
        return switch (self) {
            .default => "default",
            .input => "input",
            .output => "output",
            .custom => "custom",
            .group => "group",
        };
    }
};

/// Node visual style
pub const NodeStyle = struct {
    background_color: u32 = 0xFFFFFFFF,
    border_color: u32 = 0xFF000000,
    border_width: f32 = 1.0,
    border_radius: f32 = 4.0,
    /// Selected state colors
    selected_border_color: u32 = 0xFF0066FF,
    selected_border_width: f32 = 2.0,
    /// Shadow
    shadow_enabled: bool = true,
    shadow_color: u32 = 0x40000000,
    shadow_blur: f32 = 4.0,
    shadow_offset_x: f32 = 2.0,
    shadow_offset_y: f32 = 2.0,
    /// Opacity
    opacity: f32 = 1.0,
    /// Custom CSS class
    css_class: ?[]const u8 = null,
};

/// Node data payload
pub const NodeData = struct {
    /// Display label
    label: ?[]const u8 = null,
    /// Custom data (JSON string)
    custom_data: ?[]const u8 = null,
    /// Icon identifier
    icon: ?[]const u8 = null,
    /// Tooltip text
    tooltip: ?[]const u8 = null,
};

/// Node definition
pub const Node = struct {
    id: NodeId,
    node_type: NodeType = .default,
    position: Position = .{},
    dimensions: Dimensions = .{},
    data: NodeData = .{},
    style: NodeStyle = .{},
    /// Input/output handles
    handles: []const Handle = &.{},
    /// Is node selected
    selected: bool = false,
    /// Is node draggable
    draggable: bool = true,
    /// Is node selectable
    selectable: bool = true,
    /// Is node connectable
    connectable: bool = true,
    /// Is node deletable
    deletable: bool = true,
    /// Parent group node ID (if in group)
    parent_id: ?NodeId = null,
    /// Z-index for layering
    z_index: i32 = 0,
    /// Is node hidden
    hidden: bool = false,
    /// Is node resizable
    resizable: bool = false,
    /// Minimum dimensions (for resizable)
    min_dimensions: ?Dimensions = null,
    /// Maximum dimensions (for resizable)
    max_dimensions: ?Dimensions = null,

    /// Get node bounds
    pub fn getBounds(self: *const Node) struct { min: Position, max: Position } {
        return .{
            .min = self.position,
            .max = .{
                .x = self.position.x + self.dimensions.width,
                .y = self.position.y + self.dimensions.height,
            },
        };
    }

    /// Get center position
    pub fn getCenter(self: *const Node) Position {
        return .{
            .x = self.position.x + self.dimensions.width / 2,
            .y = self.position.y + self.dimensions.height / 2,
        };
    }

    /// Check if point is inside node
    pub fn containsPoint(self: *const Node, point: Position) bool {
        return self.dimensions.contains(point, self.position);
    }

    /// Find handle by ID
    pub fn getHandle(self: *const Node, handle_id: []const u8) ?Handle {
        for (self.handles) |handle| {
            if (std.mem.eql(u8, handle.id, handle_id)) {
                return handle;
            }
        }
        return null;
    }

    /// Get handles by type
    /// Note: Currently returns all handles; in full implementation would filter by type
    pub fn getHandlesByType(self: *const Node, handle_type: HandleType) []const Handle {
        _ = handle_type;
        // Note: In real implementation, would return filtered slice
        return self.handles;
    }
};

/// Node creation configuration
pub const NodeConfig = struct {
    node_type: NodeType = .default,
    position: Position = .{},
    dimensions: Dimensions = .{},
    data: NodeData = .{},
    style: NodeStyle = .{},
    handles: []const Handle = &.{},
    draggable: bool = true,
    selectable: bool = true,
    connectable: bool = true,
    deletable: bool = true,
    resizable: bool = false,
};

/// Node change event
pub const NodeChange = union(enum) {
    position: struct { id: NodeId, position: Position },
    dimensions: struct { id: NodeId, dimensions: Dimensions },
    selection: struct { id: NodeId, selected: bool },
    remove: NodeId,
    add: Node,
    data: struct { id: NodeId, data: NodeData },
    style: struct { id: NodeId, style: NodeStyle },
};

/// Node change callback
pub const NodeChangeCallback = *const fn (NodeChange) void;

/// Node Manager
pub const NodeManager = struct {
    allocator: std.mem.Allocator,
    nodes: std.AutoHashMapUnmanaged(u64, Node) = .{},
    next_id: u64 = 1,
    selected_nodes: std.ArrayListUnmanaged(NodeId) = .{},
    change_callbacks: std.ArrayListUnmanaged(NodeChangeCallback) = .{},

    pub fn init(allocator: std.mem.Allocator) NodeManager {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *NodeManager) void {
        self.nodes.deinit(self.allocator);
        self.selected_nodes.deinit(self.allocator);
        self.change_callbacks.deinit(self.allocator);
    }

    /// Add a new node
    pub fn addNode(self: *NodeManager, config: NodeConfig) !NodeId {
        const id = NodeId{ .id = self.next_id };
        self.next_id += 1;

        const node = Node{
            .id = id,
            .node_type = config.node_type,
            .position = config.position,
            .dimensions = config.dimensions,
            .data = config.data,
            .style = config.style,
            .handles = config.handles,
            .draggable = config.draggable,
            .selectable = config.selectable,
            .connectable = config.connectable,
            .deletable = config.deletable,
            .resizable = config.resizable,
        };

        try self.nodes.put(self.allocator, id.id, node);
        self.emitChange(.{ .add = node });

        return id;
    }

    /// Remove a node
    pub fn removeNode(self: *NodeManager, id: NodeId) bool {
        if (self.nodes.get(id.id)) |node| {
            if (!node.deletable) return false;

            // Remove from selection
            self.deselectNode(id);

            _ = self.nodes.remove(id.id);
            self.emitChange(.{ .remove = id });
            return true;
        }
        return false;
    }

    /// Get a node by ID
    pub fn getNode(self: *const NodeManager, id: NodeId) ?Node {
        return self.nodes.get(id.id);
    }

    /// Update node position
    pub fn setNodePosition(self: *NodeManager, id: NodeId, position: Position) void {
        if (self.nodes.getPtr(id.id)) |node| {
            if (!node.draggable) return;
            node.position = position;
            self.emitChange(.{ .position = .{ .id = id, .position = position } });
        }
    }

    /// Update node dimensions
    pub fn setNodeDimensions(self: *NodeManager, id: NodeId, dimensions: Dimensions) void {
        if (self.nodes.getPtr(id.id)) |node| {
            if (!node.resizable) return;

            // Apply min/max constraints
            var new_dims = dimensions;
            if (node.min_dimensions) |min| {
                new_dims.width = @max(new_dims.width, min.width);
                new_dims.height = @max(new_dims.height, min.height);
            }
            if (node.max_dimensions) |max| {
                new_dims.width = @min(new_dims.width, max.width);
                new_dims.height = @min(new_dims.height, max.height);
            }

            node.dimensions = new_dims;
            self.emitChange(.{ .dimensions = .{ .id = id, .dimensions = new_dims } });
        }
    }

    /// Select a node
    pub fn selectNode(self: *NodeManager, id: NodeId) void {
        if (self.nodes.getPtr(id.id)) |node| {
            if (!node.selectable or node.selected) return;

            node.selected = true;
            self.selected_nodes.append(self.allocator, id) catch return;
            self.emitChange(.{ .selection = .{ .id = id, .selected = true } });
        }
    }

    /// Deselect a node
    pub fn deselectNode(self: *NodeManager, id: NodeId) void {
        if (self.nodes.getPtr(id.id)) |node| {
            if (!node.selected) return;

            node.selected = false;

            // Remove from selected list
            for (self.selected_nodes.items, 0..) |selected_id, i| {
                if (selected_id.id == id.id) {
                    _ = self.selected_nodes.swapRemove(i);
                    break;
                }
            }

            self.emitChange(.{ .selection = .{ .id = id, .selected = false } });
        }
    }

    /// Select all nodes
    pub fn selectAll(self: *NodeManager) void {
        var iter = self.nodes.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.selectable and !entry.value_ptr.selected) {
                entry.value_ptr.selected = true;
                self.selected_nodes.append(self.allocator, entry.value_ptr.id) catch continue;
                self.emitChange(.{ .selection = .{ .id = entry.value_ptr.id, .selected = true } });
            }
        }
    }

    /// Deselect all nodes
    pub fn deselectAll(self: *NodeManager) void {
        for (self.selected_nodes.items) |id| {
            if (self.nodes.getPtr(id.id)) |node| {
                node.selected = false;
                self.emitChange(.{ .selection = .{ .id = id, .selected = false } });
            }
        }
        self.selected_nodes.clearRetainingCapacity();
    }

    /// Get selected node IDs
    pub fn getSelectedNodes(self: *const NodeManager) []const NodeId {
        return self.selected_nodes.items;
    }

    /// Update node data
    pub fn setNodeData(self: *NodeManager, id: NodeId, data: NodeData) void {
        if (self.nodes.getPtr(id.id)) |node| {
            node.data = data;
            self.emitChange(.{ .data = .{ .id = id, .data = data } });
        }
    }

    /// Update node style
    pub fn setNodeStyle(self: *NodeManager, id: NodeId, style: NodeStyle) void {
        if (self.nodes.getPtr(id.id)) |node| {
            node.style = style;
            self.emitChange(.{ .style = .{ .id = id, .style = style } });
        }
    }

    /// Find nodes at position
    pub fn getNodesAtPosition(self: *const NodeManager, pos: Position) ![]NodeId {
        var result: std.ArrayListUnmanaged(NodeId) = .{};
        var iter = self.nodes.iterator();
        while (iter.next()) |entry| {
            if (!entry.value_ptr.hidden and entry.value_ptr.containsPoint(pos)) {
                try result.append(self.allocator, entry.value_ptr.id);
            }
        }
        return try result.toOwnedSlice(self.allocator);
    }

    /// Find nodes in rectangle
    pub fn getNodesInRect(self: *const NodeManager, min: Position, max: Position) ![]NodeId {
        var result: std.ArrayListUnmanaged(NodeId) = .{};
        var iter = self.nodes.iterator();
        while (iter.next()) |entry| {
            const node = entry.value_ptr;
            if (node.hidden) continue;

            const bounds = node.getBounds();
            // Check intersection
            if (bounds.max.x >= min.x and bounds.min.x <= max.x and
                bounds.max.y >= min.y and bounds.min.y <= max.y)
            {
                try result.append(self.allocator, node.id);
            }
        }
        return try result.toOwnedSlice(self.allocator);
    }

    /// Get total node count
    pub fn count(self: *const NodeManager) usize {
        return self.nodes.count();
    }

    /// Register change callback
    pub fn onNodeChange(self: *NodeManager, callback: NodeChangeCallback) void {
        self.change_callbacks.append(self.allocator, callback) catch return;
    }

    /// Emit change to all callbacks
    fn emitChange(self: *NodeManager, change: NodeChange) void {
        for (self.change_callbacks.items) |callback| {
            callback(change);
        }
    }

    /// Move selected nodes by delta
    pub fn moveSelectedNodes(self: *NodeManager, delta: Position) void {
        for (self.selected_nodes.items) |id| {
            if (self.nodes.getPtr(id.id)) |node| {
                if (node.draggable) {
                    node.position = node.position.add(delta);
                    self.emitChange(.{ .position = .{ .id = id, .position = node.position } });
                }
            }
        }
    }

    /// Delete selected nodes
    pub fn deleteSelectedNodes(self: *NodeManager) usize {
        var deleted: usize = 0;
        // Copy to avoid modifying while iterating
        var to_delete: std.ArrayListUnmanaged(NodeId) = .{};
        defer to_delete.deinit(self.allocator);

        for (self.selected_nodes.items) |id| {
            if (self.nodes.get(id.id)) |node| {
                if (node.deletable) {
                    to_delete.append(self.allocator, id) catch continue;
                }
            }
        }

        for (to_delete.items) |id| {
            if (self.removeNode(id)) {
                deleted += 1;
            }
        }

        return deleted;
    }

    /// Set node hidden state
    pub fn setNodeHidden(self: *NodeManager, id: NodeId, hidden: bool) void {
        if (self.nodes.getPtr(id.id)) |node| {
            node.hidden = hidden;
            if (hidden and node.selected) {
                self.deselectNode(id);
            }
        }
    }

    /// Set node z-index
    pub fn setNodeZIndex(self: *NodeManager, id: NodeId, z_index: i32) void {
        if (self.nodes.getPtr(id.id)) |node| {
            node.z_index = z_index;
        }
    }

    /// Bring node to front
    pub fn bringToFront(self: *NodeManager, id: NodeId) void {
        var max_z: i32 = 0;
        var iter = self.nodes.iterator();
        while (iter.next()) |entry| {
            max_z = @max(max_z, entry.value_ptr.z_index);
        }
        self.setNodeZIndex(id, max_z + 1);
    }

    /// Send node to back
    pub fn sendToBack(self: *NodeManager, id: NodeId) void {
        var min_z: i32 = 0;
        var iter = self.nodes.iterator();
        while (iter.next()) |entry| {
            min_z = @min(min_z, entry.value_ptr.z_index);
        }
        self.setNodeZIndex(id, min_z - 1);
    }
};

/// Convenience function to create a node manager
pub fn createNodeManager(allocator: std.mem.Allocator) NodeManager {
    return NodeManager.init(allocator);
}

/// Create default input node handles
pub fn createInputHandles() [1]Handle {
    return .{
        .{ .id = "output", .handle_type = .source, .position = .right },
    };
}

/// Create default output node handles
pub fn createOutputHandles() [1]Handle {
    return .{
        .{ .id = "input", .handle_type = .target, .position = .left },
    };
}

/// Create default node handles (input and output)
pub fn createDefaultHandles() [2]Handle {
    return .{
        .{ .id = "input", .handle_type = .target, .position = .left },
        .{ .id = "output", .handle_type = .source, .position = .right },
    };
}

// Tests
test "NodeManager initialization" {
    const allocator = std.testing.allocator;
    var manager = createNodeManager(allocator);
    defer manager.deinit();

    try std.testing.expectEqual(@as(usize, 0), manager.count());
}

test "Add and remove nodes" {
    const allocator = std.testing.allocator;
    var manager = createNodeManager(allocator);
    defer manager.deinit();

    const id = try manager.addNode(.{
        .position = .{ .x = 100, .y = 100 },
        .data = .{ .label = "Test Node" },
    });

    try std.testing.expect(id.isValid());
    try std.testing.expectEqual(@as(usize, 1), manager.count());

    const node = manager.getNode(id);
    try std.testing.expect(node != null);
    try std.testing.expectApproxEqAbs(@as(f32, 100), node.?.position.x, 0.01);

    try std.testing.expect(manager.removeNode(id));
    try std.testing.expectEqual(@as(usize, 0), manager.count());
}

test "Node selection" {
    const allocator = std.testing.allocator;
    var manager = createNodeManager(allocator);
    defer manager.deinit();

    const id1 = try manager.addNode(.{ .position = .{ .x = 0, .y = 0 } });
    const id2 = try manager.addNode(.{ .position = .{ .x = 200, .y = 0 } });

    manager.selectNode(id1);
    try std.testing.expectEqual(@as(usize, 1), manager.getSelectedNodes().len);

    manager.selectNode(id2);
    try std.testing.expectEqual(@as(usize, 2), manager.getSelectedNodes().len);

    manager.deselectNode(id1);
    try std.testing.expectEqual(@as(usize, 1), manager.getSelectedNodes().len);

    manager.deselectAll();
    try std.testing.expectEqual(@as(usize, 0), manager.getSelectedNodes().len);
}

test "Node position update" {
    const allocator = std.testing.allocator;
    var manager = createNodeManager(allocator);
    defer manager.deinit();

    const id = try manager.addNode(.{ .position = .{ .x = 0, .y = 0 } });

    manager.setNodePosition(id, .{ .x = 150, .y = 200 });

    const node = manager.getNode(id);
    try std.testing.expect(node != null);
    try std.testing.expectApproxEqAbs(@as(f32, 150), node.?.position.x, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 200), node.?.position.y, 0.01);
}

test "Position operations" {
    const p1 = Position{ .x = 10, .y = 20 };
    const p2 = Position{ .x = 5, .y = 10 };

    const sum = p1.add(p2);
    try std.testing.expectApproxEqAbs(@as(f32, 15), sum.x, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 30), sum.y, 0.01);

    const diff = p1.sub(p2);
    try std.testing.expectApproxEqAbs(@as(f32, 5), diff.x, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 10), diff.y, 0.01);

    const scaled = p1.scale(2);
    try std.testing.expectApproxEqAbs(@as(f32, 20), scaled.x, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 40), scaled.y, 0.01);
}

test "Handle position calculation" {
    const handle = Handle{
        .id = "test",
        .position = .right,
        .offset = 0.5,
    };

    const node_pos = Position{ .x = 100, .y = 100 };
    const node_dim = Dimensions{ .width = 150, .height = 50 };

    const abs_pos = handle.getAbsolutePosition(node_pos, node_dim);
    try std.testing.expectApproxEqAbs(@as(f32, 250), abs_pos.x, 0.01); // 100 + 150
    try std.testing.expectApproxEqAbs(@as(f32, 125), abs_pos.y, 0.01); // 100 + 50 * 0.5
}

test "Node contains point" {
    const allocator = std.testing.allocator;
    var manager = createNodeManager(allocator);
    defer manager.deinit();

    const id = try manager.addNode(.{
        .position = .{ .x = 100, .y = 100 },
        .dimensions = .{ .width = 100, .height = 50 },
    });

    const node = manager.getNode(id).?;

    try std.testing.expect(node.containsPoint(.{ .x = 150, .y = 125 }));
    try std.testing.expect(!node.containsPoint(.{ .x = 50, .y = 50 }));
    try std.testing.expect(!node.containsPoint(.{ .x = 250, .y = 125 }));
}

test "HandlePosition operations" {
    try std.testing.expect(HandlePosition.left.isHorizontal());
    try std.testing.expect(HandlePosition.right.isHorizontal());
    try std.testing.expect(!HandlePosition.top.isHorizontal());

    try std.testing.expectEqual(HandlePosition.bottom, HandlePosition.top.opposite());
    try std.testing.expectEqual(HandlePosition.left, HandlePosition.right.opposite());
}

test "HandleType connection rules" {
    try std.testing.expect(HandleType.source.canConnect(.target));
    try std.testing.expect(!HandleType.source.canConnect(.source));
    try std.testing.expect(HandleType.both.canConnect(.source));
    try std.testing.expect(HandleType.both.canConnect(.target));
}

test "Node bounds and center" {
    const allocator = std.testing.allocator;
    var manager = createNodeManager(allocator);
    defer manager.deinit();

    const id = try manager.addNode(.{
        .position = .{ .x = 100, .y = 100 },
        .dimensions = .{ .width = 100, .height = 50 },
    });

    const node = manager.getNode(id).?;
    const bounds = node.getBounds();

    try std.testing.expectApproxEqAbs(@as(f32, 100), bounds.min.x, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 100), bounds.min.y, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 200), bounds.max.x, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 150), bounds.max.y, 0.01);

    const center = node.getCenter();
    try std.testing.expectApproxEqAbs(@as(f32, 150), center.x, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 125), center.y, 0.01);
}

test "Select all and delete selected" {
    const allocator = std.testing.allocator;
    var manager = createNodeManager(allocator);
    defer manager.deinit();

    _ = try manager.addNode(.{ .position = .{ .x = 0, .y = 0 } });
    _ = try manager.addNode(.{ .position = .{ .x = 100, .y = 0 } });
    _ = try manager.addNode(.{ .position = .{ .x = 200, .y = 0 } });

    try std.testing.expectEqual(@as(usize, 3), manager.count());

    manager.selectAll();
    try std.testing.expectEqual(@as(usize, 3), manager.getSelectedNodes().len);

    const deleted = manager.deleteSelectedNodes();
    try std.testing.expectEqual(@as(usize, 3), deleted);
    try std.testing.expectEqual(@as(usize, 0), manager.count());
}

test "Move selected nodes" {
    const allocator = std.testing.allocator;
    var manager = createNodeManager(allocator);
    defer manager.deinit();

    const id1 = try manager.addNode(.{ .position = .{ .x = 0, .y = 0 } });
    const id2 = try manager.addNode(.{ .position = .{ .x = 100, .y = 100 } });

    manager.selectNode(id1);
    manager.selectNode(id2);

    manager.moveSelectedNodes(.{ .x = 50, .y = 25 });

    const node1 = manager.getNode(id1).?;
    const node2 = manager.getNode(id2).?;

    try std.testing.expectApproxEqAbs(@as(f32, 50), node1.position.x, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 25), node1.position.y, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 150), node2.position.x, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 125), node2.position.y, 0.01);
}

test "Z-index operations" {
    const allocator = std.testing.allocator;
    var manager = createNodeManager(allocator);
    defer manager.deinit();

    const id1 = try manager.addNode(.{ .position = .{ .x = 0, .y = 0 } });
    const id2 = try manager.addNode(.{ .position = .{ .x = 100, .y = 0 } });

    manager.bringToFront(id1);
    const node1 = manager.getNode(id1).?;
    try std.testing.expect(node1.z_index > 0);

    manager.sendToBack(id2);
    const node2 = manager.getNode(id2).?;
    try std.testing.expect(node2.z_index < 0);
}
