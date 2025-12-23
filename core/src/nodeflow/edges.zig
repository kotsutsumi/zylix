//! Connection/Edge System API
//!
//! Manage node connections with support for:
//! - Visual connection creation by dragging
//! - Connection validation rules
//! - Multiple edge types (straight, bezier, step)
//! - Edge labels and markers
//! - Custom styling and animations
//!
//! This module provides the edge/connection system for React Flow-style node graphs.

const std = @import("std");
const nodes = @import("nodes.zig");

/// Edge error types
pub const EdgeError = error{
    InvalidSource,
    InvalidTarget,
    SelfConnection,
    DuplicateConnection,
    ValidationFailed,
    HandleNotFound,
    IncompatibleHandles,
    MaxConnectionsReached,
    OutOfMemory,
};

/// Unique edge identifier
pub const EdgeId = struct {
    id: u64,

    pub fn eql(self: EdgeId, other: EdgeId) bool {
        return self.id == other.id;
    }

    pub fn hash(self: EdgeId) u64 {
        return self.id;
    }
};

/// Edge type for visual rendering
pub const EdgeType = enum(u8) {
    straight = 0, // Direct line
    bezier = 1, // Smooth bezier curve (default)
    step = 2, // Right-angle steps
    smooth_step = 3, // Rounded step corners
    simplebezier = 4, // Simplified bezier

    pub fn toString(self: EdgeType) []const u8 {
        return switch (self) {
            .straight => "Straight",
            .bezier => "Bezier",
            .step => "Step",
            .smooth_step => "SmoothStep",
            .simplebezier => "SimpleBezier",
        };
    }

    pub fn requiresControlPoints(self: EdgeType) bool {
        return switch (self) {
            .bezier, .simplebezier => true,
            else => false,
        };
    }
};

/// Edge marker type for arrows/decorations
pub const MarkerType = enum(u8) {
    none = 0,
    arrow = 1,
    arrow_closed = 2,
    circle = 3,
    diamond = 4,

    pub fn toString(self: MarkerType) []const u8 {
        return switch (self) {
            .none => "None",
            .arrow => "Arrow",
            .arrow_closed => "ArrowClosed",
            .circle => "Circle",
            .diamond => "Diamond",
        };
    }
};

/// Edge marker configuration
pub const EdgeMarker = struct {
    marker_type: MarkerType = .none,
    size: f32 = 8.0,
    color: ?u32 = null, // RGBA, null = inherit from edge
    stroke_width: f32 = 1.0,
};

/// Edge label position
pub const LabelPosition = enum(u8) {
    start = 0,
    center = 1,
    end = 2,

    pub fn toFraction(self: LabelPosition) f32 {
        return switch (self) {
            .start => 0.15,
            .center => 0.5,
            .end => 0.85,
        };
    }
};

/// Edge label configuration
pub const EdgeLabel = struct {
    text: []const u8,
    position: LabelPosition = .center,
    offset_x: f32 = 0,
    offset_y: f32 = 0,
    background_color: ?u32 = null,
    text_color: u32 = 0x000000FF,
    font_size: f32 = 12.0,
    show_background: bool = true,
    padding: f32 = 4.0,
};

/// Edge style configuration
pub const EdgeStyle = struct {
    stroke_color: u32 = 0x808080FF, // Gray
    stroke_width: f32 = 2.0,
    stroke_dasharray: ?[]const u8 = null, // e.g., "5,5" for dashed
    opacity: f32 = 1.0,
    animated: bool = false,
    animation_speed: f32 = 1.0,
    glow_color: ?u32 = null,
    glow_radius: f32 = 0,

    // Selected state
    selected_stroke_color: u32 = 0x1A73E8FF,
    selected_stroke_width: f32 = 3.0,

    // Hover state
    hover_stroke_color: u32 = 0x4285F4FF,
    hover_stroke_width: f32 = 2.5,

    pub fn withColor(self: EdgeStyle, color: u32) EdgeStyle {
        var style = self;
        style.stroke_color = color;
        return style;
    }

    pub fn withWidth(self: EdgeStyle, width: f32) EdgeStyle {
        var style = self;
        style.stroke_width = width;
        return style;
    }

    pub fn dashed(self: EdgeStyle) EdgeStyle {
        var style = self;
        style.stroke_dasharray = "5,5";
        return style;
    }

    pub fn animated_flow(self: EdgeStyle) EdgeStyle {
        var style = self;
        style.animated = true;
        style.stroke_dasharray = "5,5";
        return style;
    }
};

/// Connection endpoint (source or target)
pub const ConnectionEndpoint = struct {
    node_id: nodes.NodeId,
    handle_id: ?[]const u8 = null, // null = default handle

    pub fn eql(self: ConnectionEndpoint, other: ConnectionEndpoint) bool {
        if (!self.node_id.eql(other.node_id)) return false;
        if (self.handle_id == null and other.handle_id == null) return true;
        if (self.handle_id == null or other.handle_id == null) return false;
        return std.mem.eql(u8, self.handle_id.?, other.handle_id.?);
    }
};

/// Control point for bezier curves
pub const ControlPoint = struct {
    x: f32,
    y: f32,
};

/// Edge path data for rendering
pub const EdgePath = struct {
    /// SVG path string
    d: []const u8,
    /// Calculated control points
    control_points: []const ControlPoint = &.{},
    /// Total path length
    length: f32 = 0,
    /// Source point
    source_x: f32,
    source_y: f32,
    /// Target point
    target_x: f32,
    target_y: f32,
};

/// Edge data structure
pub const Edge = struct {
    id: EdgeId,
    source: ConnectionEndpoint,
    target: ConnectionEndpoint,
    edge_type: EdgeType = .bezier,
    style: EdgeStyle = .{},
    label: ?EdgeLabel = null,
    marker_start: EdgeMarker = .{},
    marker_end: EdgeMarker = .{ .marker_type = .arrow },
    z_index: i32 = 0,
    selected: bool = false,
    hovered: bool = false,
    hidden: bool = false,
    interactable: bool = true,
    data: ?*anyopaque = null, // Custom user data

    pub fn isValid(self: *const Edge) bool {
        return !self.source.node_id.eql(self.target.node_id);
    }

    pub fn connects(self: *const Edge, node_id: nodes.NodeId) bool {
        return self.source.node_id.eql(node_id) or self.target.node_id.eql(node_id);
    }

    pub fn connectsNodes(self: *const Edge, node_a: nodes.NodeId, node_b: nodes.NodeId) bool {
        return (self.source.node_id.eql(node_a) and self.target.node_id.eql(node_b)) or
            (self.source.node_id.eql(node_b) and self.target.node_id.eql(node_a));
    }

    pub fn getOtherNode(self: *const Edge, node_id: nodes.NodeId) ?nodes.NodeId {
        if (self.source.node_id.eql(node_id)) return self.target.node_id;
        if (self.target.node_id.eql(node_id)) return self.source.node_id;
        return null;
    }

    pub fn setSelected(self: *Edge, selected: bool) void {
        self.selected = selected;
    }

    pub fn setHovered(self: *Edge, hovered: bool) void {
        self.hovered = hovered;
    }

    pub fn getCurrentStyle(self: *const Edge) EdgeStyle {
        var style = self.style;
        if (self.selected) {
            style.stroke_color = style.selected_stroke_color;
            style.stroke_width = style.selected_stroke_width;
        } else if (self.hovered) {
            style.stroke_color = style.hover_stroke_color;
            style.stroke_width = style.hover_stroke_width;
        }
        return style;
    }
};

/// Edge configuration for creation
pub const EdgeConfig = struct {
    source: ConnectionEndpoint,
    target: ConnectionEndpoint,
    edge_type: EdgeType = .bezier,
    style: EdgeStyle = .{},
    label: ?EdgeLabel = null,
    marker_start: EdgeMarker = .{},
    marker_end: EdgeMarker = .{ .marker_type = .arrow },
    z_index: i32 = 0,
    data: ?*anyopaque = null,
};

/// Edge change event type
pub const EdgeChangeType = enum(u8) {
    add,
    remove,
    select,
    deselect,
    update_style,
    update_label,
    update_type,
    reconnect,
};

/// Edge change event
pub const EdgeChange = struct {
    change_type: EdgeChangeType,
    edge_id: EdgeId,
    old_value: ?*anyopaque = null,
    new_value: ?*anyopaque = null,
};

/// Connection validation rule
pub const ValidationRule = struct {
    /// Maximum connections per source handle (0 = unlimited)
    max_source_connections: u32 = 0,
    /// Maximum connections per target handle (0 = unlimited)
    max_target_connections: u32 = 1,
    /// Allow self-connections
    allow_self_connection: bool = false,
    /// Allow duplicate connections
    allow_duplicates: bool = false,
    /// Custom validation function
    custom_validator: ?*const fn (source: ConnectionEndpoint, target: ConnectionEndpoint) bool = null,
};

/// Edge Manager for managing all edges
pub const EdgeManager = struct {
    allocator: std.mem.Allocator,
    edges: std.AutoHashMapUnmanaged(u64, Edge) = .{},
    next_id: u64 = 1,
    validation_rules: ValidationRule = .{},
    change_callback: ?*const fn (EdgeChange) void = null,
    selected_edges: std.ArrayListUnmanaged(EdgeId) = .{},

    // Indices for fast lookup
    source_index: std.AutoHashMapUnmanaged(u64, std.ArrayListUnmanaged(EdgeId)) = .{},
    target_index: std.AutoHashMapUnmanaged(u64, std.ArrayListUnmanaged(EdgeId)) = .{},

    pub fn init(allocator: std.mem.Allocator) EdgeManager {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *EdgeManager) void {
        // Free source index lists
        var source_iter = self.source_index.iterator();
        while (source_iter.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.source_index.deinit(self.allocator);

        // Free target index lists
        var target_iter = self.target_index.iterator();
        while (target_iter.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.target_index.deinit(self.allocator);

        self.edges.deinit(self.allocator);
        self.selected_edges.deinit(self.allocator);
    }

    /// Add a new edge
    pub fn addEdge(self: *EdgeManager, config: EdgeConfig) EdgeError!EdgeId {
        // Validate connection
        try self.validateConnection(config.source, config.target);

        const id = EdgeId{ .id = self.next_id };
        self.next_id += 1;

        const edge = Edge{
            .id = id,
            .source = config.source,
            .target = config.target,
            .edge_type = config.edge_type,
            .style = config.style,
            .label = config.label,
            .marker_start = config.marker_start,
            .marker_end = config.marker_end,
            .z_index = config.z_index,
            .data = config.data,
        };

        self.edges.put(self.allocator, id.id, edge) catch return EdgeError.OutOfMemory;

        // Update indices
        self.addToIndex(&self.source_index, config.source.node_id.id, id) catch return EdgeError.OutOfMemory;
        self.addToIndex(&self.target_index, config.target.node_id.id, id) catch return EdgeError.OutOfMemory;

        // Notify callback
        if (self.change_callback) |callback| {
            callback(.{ .change_type = .add, .edge_id = id });
        }

        return id;
    }

    /// Remove an edge
    pub fn removeEdge(self: *EdgeManager, id: EdgeId) bool {
        const edge = self.edges.get(id.id) orelse return false;

        // Remove from indices
        self.removeFromIndex(&self.source_index, edge.source.node_id.id, id);
        self.removeFromIndex(&self.target_index, edge.target.node_id.id, id);

        // Remove from selection
        self.removeFromSelection(id);

        _ = self.edges.remove(id.id);

        // Notify callback
        if (self.change_callback) |callback| {
            callback(.{ .change_type = .remove, .edge_id = id });
        }

        return true;
    }

    /// Get an edge by ID
    pub fn getEdge(self: *const EdgeManager, id: EdgeId) ?*const Edge {
        if (self.edges.getPtr(id.id)) |ptr| {
            return ptr;
        }
        return null;
    }

    /// Get mutable edge by ID
    pub fn getEdgeMut(self: *EdgeManager, id: EdgeId) ?*Edge {
        return self.edges.getPtr(id.id);
    }

    /// Get all edges connected to a node
    pub fn getNodeEdges(self: *const EdgeManager, node_id: nodes.NodeId) []const EdgeId {
        var result: std.ArrayListUnmanaged(EdgeId) = .{};

        // Get outgoing edges
        if (self.source_index.get(node_id.id)) |list| {
            for (list.items) |edge_id| {
                result.append(self.allocator, edge_id) catch continue;
            }
        }

        // Get incoming edges
        if (self.target_index.get(node_id.id)) |list| {
            for (list.items) |edge_id| {
                // Avoid duplicates (shouldn't happen normally)
                var found = false;
                for (result.items) |existing| {
                    if (existing.eql(edge_id)) {
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    result.append(self.allocator, edge_id) catch continue;
                }
            }
        }

        return result.items;
    }

    /// Get outgoing edges from a node
    pub fn getOutgoingEdges(self: *const EdgeManager, node_id: nodes.NodeId) []const EdgeId {
        if (self.source_index.get(node_id.id)) |list| {
            return list.items;
        }
        return &.{};
    }

    /// Get incoming edges to a node
    pub fn getIncomingEdges(self: *const EdgeManager, node_id: nodes.NodeId) []const EdgeId {
        if (self.target_index.get(node_id.id)) |list| {
            return list.items;
        }
        return &.{};
    }

    /// Remove all edges connected to a node
    pub fn removeNodeEdges(self: *EdgeManager, node_id: nodes.NodeId) u32 {
        var removed: u32 = 0;

        // Collect edges to remove (to avoid modifying while iterating)
        var to_remove: std.ArrayListUnmanaged(EdgeId) = .{};
        defer to_remove.deinit(self.allocator);

        var iter = self.edges.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.connects(node_id)) {
                to_remove.append(self.allocator, entry.value_ptr.id) catch continue;
            }
        }

        // Remove collected edges
        for (to_remove.items) |edge_id| {
            if (self.removeEdge(edge_id)) {
                removed += 1;
            }
        }

        return removed;
    }

    /// Select an edge
    pub fn selectEdge(self: *EdgeManager, id: EdgeId) void {
        if (self.edges.getPtr(id.id)) |edge| {
            if (!edge.selected) {
                edge.selected = true;
                self.selected_edges.append(self.allocator, id) catch return;

                if (self.change_callback) |callback| {
                    callback(.{ .change_type = .select, .edge_id = id });
                }
            }
        }
    }

    /// Deselect an edge
    pub fn deselectEdge(self: *EdgeManager, id: EdgeId) void {
        if (self.edges.getPtr(id.id)) |edge| {
            if (edge.selected) {
                edge.selected = false;
                self.removeFromSelection(id);

                if (self.change_callback) |callback| {
                    callback(.{ .change_type = .deselect, .edge_id = id });
                }
            }
        }
    }

    /// Clear all edge selections
    pub fn clearSelection(self: *EdgeManager) void {
        for (self.selected_edges.items) |edge_id| {
            if (self.edges.getPtr(edge_id.id)) |edge| {
                edge.selected = false;
            }
        }
        self.selected_edges.clearRetainingCapacity();
    }

    /// Get selected edges
    pub fn getSelectedEdges(self: *const EdgeManager) []const EdgeId {
        return self.selected_edges.items;
    }

    /// Update edge style
    pub fn updateEdgeStyle(self: *EdgeManager, id: EdgeId, style: EdgeStyle) bool {
        if (self.edges.getPtr(id.id)) |edge| {
            edge.style = style;

            if (self.change_callback) |callback| {
                callback(.{ .change_type = .update_style, .edge_id = id });
            }
            return true;
        }
        return false;
    }

    /// Update edge type
    pub fn updateEdgeType(self: *EdgeManager, id: EdgeId, edge_type: EdgeType) bool {
        if (self.edges.getPtr(id.id)) |edge| {
            edge.edge_type = edge_type;

            if (self.change_callback) |callback| {
                callback(.{ .change_type = .update_type, .edge_id = id });
            }
            return true;
        }
        return false;
    }

    /// Set edge label
    pub fn setEdgeLabel(self: *EdgeManager, id: EdgeId, label: ?EdgeLabel) bool {
        if (self.edges.getPtr(id.id)) |edge| {
            edge.label = label;

            if (self.change_callback) |callback| {
                callback(.{ .change_type = .update_label, .edge_id = id });
            }
            return true;
        }
        return false;
    }

    /// Get edge count
    pub fn count(self: *const EdgeManager) usize {
        return self.edges.count();
    }

    /// Check if edge exists between two nodes
    pub fn hasConnection(self: *const EdgeManager, source: nodes.NodeId, target: nodes.NodeId) bool {
        if (self.source_index.get(source.id)) |list| {
            for (list.items) |edge_id| {
                if (self.edges.get(edge_id.id)) |edge| {
                    if (edge.target.node_id.eql(target)) {
                        return true;
                    }
                }
            }
        }
        return false;
    }

    /// Set validation rules
    pub fn setValidationRules(self: *EdgeManager, rules: ValidationRule) void {
        self.validation_rules = rules;
    }

    /// Set change callback
    pub fn setChangeCallback(self: *EdgeManager, callback: *const fn (EdgeChange) void) void {
        self.change_callback = callback;
    }

    // Private helpers

    fn validateConnection(self: *const EdgeManager, source: ConnectionEndpoint, target: ConnectionEndpoint) EdgeError!void {
        // Check self-connection
        if (source.node_id.eql(target.node_id) and !self.validation_rules.allow_self_connection) {
            return EdgeError.SelfConnection;
        }

        // Check duplicates
        if (!self.validation_rules.allow_duplicates) {
            if (self.source_index.get(source.node_id.id)) |list| {
                for (list.items) |edge_id| {
                    if (self.edges.get(edge_id.id)) |edge| {
                        if (edge.source.eql(source) and edge.target.eql(target)) {
                            return EdgeError.DuplicateConnection;
                        }
                    }
                }
            }
        }

        // Check max connections
        if (self.validation_rules.max_source_connections > 0) {
            const source_count = self.getSourceConnectionCount(source);
            if (source_count >= self.validation_rules.max_source_connections) {
                return EdgeError.MaxConnectionsReached;
            }
        }

        if (self.validation_rules.max_target_connections > 0) {
            const target_count = self.getTargetConnectionCount(target);
            if (target_count >= self.validation_rules.max_target_connections) {
                return EdgeError.MaxConnectionsReached;
            }
        }

        // Custom validation
        if (self.validation_rules.custom_validator) |validator| {
            if (!validator(source, target)) {
                return EdgeError.ValidationFailed;
            }
        }
    }

    fn getSourceConnectionCount(self: *const EdgeManager, endpoint: ConnectionEndpoint) u32 {
        var connection_count: u32 = 0;
        if (self.source_index.get(endpoint.node_id.id)) |list| {
            for (list.items) |edge_id| {
                if (self.edges.get(edge_id.id)) |edge| {
                    if (edge.source.eql(endpoint)) {
                        connection_count += 1;
                    }
                }
            }
        }
        return connection_count;
    }

    fn getTargetConnectionCount(self: *const EdgeManager, endpoint: ConnectionEndpoint) u32 {
        var connection_count: u32 = 0;
        if (self.target_index.get(endpoint.node_id.id)) |list| {
            for (list.items) |edge_id| {
                if (self.edges.get(edge_id.id)) |edge| {
                    if (edge.target.eql(endpoint)) {
                        connection_count += 1;
                    }
                }
            }
        }
        return connection_count;
    }

    fn addToIndex(self: *EdgeManager, index: *std.AutoHashMapUnmanaged(u64, std.ArrayListUnmanaged(EdgeId)), key: u64, edge_id: EdgeId) !void {
        if (index.getPtr(key)) |list| {
            try list.append(self.allocator, edge_id);
        } else {
            var list = std.ArrayListUnmanaged(EdgeId){};
            try list.append(self.allocator, edge_id);
            try index.put(self.allocator, key, list);
        }
    }

    fn removeFromIndex(_: *EdgeManager, index: *std.AutoHashMapUnmanaged(u64, std.ArrayListUnmanaged(EdgeId)), key: u64, edge_id: EdgeId) void {
        if (index.getPtr(key)) |list| {
            var i: usize = 0;
            while (i < list.items.len) {
                if (list.items[i].eql(edge_id)) {
                    _ = list.orderedRemove(i);
                } else {
                    i += 1;
                }
            }
        }
    }

    fn removeFromSelection(self: *EdgeManager, id: EdgeId) void {
        var i: usize = 0;
        while (i < self.selected_edges.items.len) {
            if (self.selected_edges.items[i].eql(id)) {
                _ = self.selected_edges.orderedRemove(i);
            } else {
                i += 1;
            }
        }
    }
};

/// Path calculation utilities
pub const PathUtils = struct {
    /// Calculate straight line path
    pub fn straightPath(source_x: f32, source_y: f32, target_x: f32, target_y: f32, allocator: std.mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(allocator, "M {d},{d} L {d},{d}", .{ source_x, source_y, target_x, target_y });
    }

    /// Calculate bezier curve path
    pub fn bezierPath(source_x: f32, source_y: f32, target_x: f32, target_y: f32, source_pos: nodes.HandlePosition, target_pos: nodes.HandlePosition, allocator: std.mem.Allocator) ![]u8 {
        const control_offset = @abs(target_x - source_x) * 0.5;

        const c1 = getControlPoint(source_x, source_y, source_pos, control_offset);
        const c2 = getControlPoint(target_x, target_y, target_pos, control_offset);

        return std.fmt.allocPrint(allocator, "M {d},{d} C {d},{d} {d},{d} {d},{d}", .{ source_x, source_y, c1.x, c1.y, c2.x, c2.y, target_x, target_y });
    }

    /// Calculate step path
    pub fn stepPath(source_x: f32, source_y: f32, target_x: f32, target_y: f32, allocator: std.mem.Allocator) ![]u8 {
        const mid_x = (source_x + target_x) / 2;
        return std.fmt.allocPrint(allocator, "M {d},{d} L {d},{d} L {d},{d} L {d},{d}", .{ source_x, source_y, mid_x, source_y, mid_x, target_y, target_x, target_y });
    }

    /// Calculate smooth step path with rounded corners
    pub fn smoothStepPath(source_x: f32, source_y: f32, target_x: f32, target_y: f32, border_radius: f32, allocator: std.mem.Allocator) ![]u8 {
        const mid_x = (source_x + target_x) / 2;
        const radius = @min(border_radius, @abs(target_y - source_y) / 2);

        if (radius < 1) {
            return stepPath(source_x, source_y, target_x, target_y, allocator);
        }

        const direction: f32 = if (target_y > source_y) 1 else -1;

        return std.fmt.allocPrint(allocator, "M {d},{d} L {d},{d} Q {d},{d} {d},{d} L {d},{d} Q {d},{d} {d},{d} L {d},{d}", .{
            source_x,
            source_y,
            mid_x - radius,
            source_y,
            mid_x,
            source_y,
            mid_x,
            source_y + radius * direction,
            mid_x,
            target_y - radius * direction,
            mid_x,
            target_y,
            mid_x + radius,
            target_y,
            target_x,
            target_y,
        });
    }

    fn getControlPoint(x: f32, y: f32, position: nodes.HandlePosition, offset: f32) ControlPoint {
        return switch (position) {
            .top => .{ .x = x, .y = y - offset },
            .bottom => .{ .x = x, .y = y + offset },
            .left => .{ .x = x - offset, .y = y },
            .right => .{ .x = x + offset, .y = y },
        };
    }
};

/// Create an edge manager
pub fn createEdgeManager(allocator: std.mem.Allocator) EdgeManager {
    return EdgeManager.init(allocator);
}

// Tests
test "EdgeManager initialization" {
    const allocator = std.testing.allocator;
    var manager = createEdgeManager(allocator);
    defer manager.deinit();

    try std.testing.expectEqual(@as(usize, 0), manager.count());
}

test "Add and remove edge" {
    const allocator = std.testing.allocator;
    var manager = createEdgeManager(allocator);
    defer manager.deinit();

    const edge_id = try manager.addEdge(.{
        .source = .{ .node_id = .{ .id = 1 } },
        .target = .{ .node_id = .{ .id = 2 } },
    });

    try std.testing.expectEqual(@as(usize, 1), manager.count());

    const edge = manager.getEdge(edge_id);
    try std.testing.expect(edge != null);
    try std.testing.expect(edge.?.source.node_id.eql(.{ .id = 1 }));
    try std.testing.expect(edge.?.target.node_id.eql(.{ .id = 2 }));

    try std.testing.expect(manager.removeEdge(edge_id));
    try std.testing.expectEqual(@as(usize, 0), manager.count());
}

test "Self-connection validation" {
    const allocator = std.testing.allocator;
    var manager = createEdgeManager(allocator);
    defer manager.deinit();

    const result = manager.addEdge(.{
        .source = .{ .node_id = .{ .id = 1 } },
        .target = .{ .node_id = .{ .id = 1 } },
    });

    try std.testing.expectError(EdgeError.SelfConnection, result);
}

test "Duplicate connection validation" {
    const allocator = std.testing.allocator;
    var manager = createEdgeManager(allocator);
    defer manager.deinit();

    _ = try manager.addEdge(.{
        .source = .{ .node_id = .{ .id = 1 } },
        .target = .{ .node_id = .{ .id = 2 } },
    });

    const result = manager.addEdge(.{
        .source = .{ .node_id = .{ .id = 1 } },
        .target = .{ .node_id = .{ .id = 2 } },
    });

    try std.testing.expectError(EdgeError.DuplicateConnection, result);
}

test "Edge selection" {
    const allocator = std.testing.allocator;
    var manager = createEdgeManager(allocator);
    defer manager.deinit();

    const edge_id = try manager.addEdge(.{
        .source = .{ .node_id = .{ .id = 1 } },
        .target = .{ .node_id = .{ .id = 2 } },
    });

    manager.selectEdge(edge_id);
    try std.testing.expectEqual(@as(usize, 1), manager.getSelectedEdges().len);

    const edge = manager.getEdge(edge_id);
    try std.testing.expect(edge.?.selected);

    manager.deselectEdge(edge_id);
    try std.testing.expectEqual(@as(usize, 0), manager.getSelectedEdges().len);
}

test "Edge type methods" {
    try std.testing.expect(std.mem.eql(u8, "Bezier", EdgeType.bezier.toString()));
    try std.testing.expect(EdgeType.bezier.requiresControlPoints());
    try std.testing.expect(!EdgeType.straight.requiresControlPoints());
}

test "Edge style builder" {
    const style = EdgeStyle{};
    const colored = style.withColor(0xFF0000FF);
    try std.testing.expectEqual(@as(u32, 0xFF0000FF), colored.stroke_color);

    const wide = style.withWidth(5.0);
    try std.testing.expectEqual(@as(f32, 5.0), wide.stroke_width);
}

test "Connection endpoint equality" {
    const e1 = ConnectionEndpoint{ .node_id = .{ .id = 1 }, .handle_id = "output" };
    const e2 = ConnectionEndpoint{ .node_id = .{ .id = 1 }, .handle_id = "output" };
    const e3 = ConnectionEndpoint{ .node_id = .{ .id = 1 }, .handle_id = "input" };
    const e4 = ConnectionEndpoint{ .node_id = .{ .id = 2 }, .handle_id = "output" };

    try std.testing.expect(e1.eql(e2));
    try std.testing.expect(!e1.eql(e3));
    try std.testing.expect(!e1.eql(e4));
}

test "Has connection check" {
    const allocator = std.testing.allocator;
    var manager = createEdgeManager(allocator);
    defer manager.deinit();

    _ = try manager.addEdge(.{
        .source = .{ .node_id = .{ .id = 1 } },
        .target = .{ .node_id = .{ .id = 2 } },
    });

    try std.testing.expect(manager.hasConnection(.{ .id = 1 }, .{ .id = 2 }));
    try std.testing.expect(!manager.hasConnection(.{ .id = 2 }, .{ .id = 1 }));
    try std.testing.expect(!manager.hasConnection(.{ .id = 1 }, .{ .id = 3 }));
}

test "Remove node edges" {
    const allocator = std.testing.allocator;
    var manager = createEdgeManager(allocator);
    defer manager.deinit();

    // Allow unlimited connections for this test
    manager.setValidationRules(.{ .max_target_connections = 0 });

    _ = try manager.addEdge(.{
        .source = .{ .node_id = .{ .id = 1 } },
        .target = .{ .node_id = .{ .id = 2 } },
    });
    _ = try manager.addEdge(.{
        .source = .{ .node_id = .{ .id = 2 } },
        .target = .{ .node_id = .{ .id = 3 } },
    });
    _ = try manager.addEdge(.{
        .source = .{ .node_id = .{ .id = 1 } },
        .target = .{ .node_id = .{ .id = 3 } },
    });

    try std.testing.expectEqual(@as(usize, 3), manager.count());

    const removed = manager.removeNodeEdges(.{ .id = 1 });
    try std.testing.expectEqual(@as(u32, 2), removed);
    try std.testing.expectEqual(@as(usize, 1), manager.count());
}

test "Max connections validation" {
    const allocator = std.testing.allocator;
    var manager = createEdgeManager(allocator);
    defer manager.deinit();

    manager.setValidationRules(.{
        .max_target_connections = 1,
    });

    _ = try manager.addEdge(.{
        .source = .{ .node_id = .{ .id = 1 } },
        .target = .{ .node_id = .{ .id = 3 } },
    });

    const result = manager.addEdge(.{
        .source = .{ .node_id = .{ .id = 2 } },
        .target = .{ .node_id = .{ .id = 3 } },
    });

    try std.testing.expectError(EdgeError.MaxConnectionsReached, result);
}

test "Label position" {
    try std.testing.expectEqual(@as(f32, 0.15), LabelPosition.start.toFraction());
    try std.testing.expectEqual(@as(f32, 0.5), LabelPosition.center.toFraction());
    try std.testing.expectEqual(@as(f32, 0.85), LabelPosition.end.toFraction());
}

test "Marker type" {
    try std.testing.expect(std.mem.eql(u8, "Arrow", MarkerType.arrow.toString()));
    try std.testing.expect(std.mem.eql(u8, "None", MarkerType.none.toString()));
}
