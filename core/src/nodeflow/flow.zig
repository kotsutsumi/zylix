//! Flow Data & Events API
//!
//! Manage flow state and data:
//! - Serialization/deserialization (JSON)
//! - Undo/redo history
//! - Clipboard operations
//! - Event system
//! - State management
//!
//! This module provides data management for React Flow-style node graphs.

const std = @import("std");
const nodes = @import("nodes.zig");
const edges = @import("edges.zig");
const layout = @import("layout.zig");

/// Flow error types
pub const FlowError = error{
    SerializationFailed,
    DeserializationFailed,
    InvalidFormat,
    HistoryEmpty,
    ClipboardEmpty,
    InvalidState,
    OutOfMemory,
};

/// Flow event type
pub const FlowEventType = enum(u8) {
    // Node events
    node_added = 0,
    node_removed = 1,
    node_moved = 2,
    node_resized = 3,
    node_selected = 4,
    node_deselected = 5,
    node_data_changed = 6,

    // Edge events
    edge_added = 10,
    edge_removed = 11,
    edge_selected = 12,
    edge_deselected = 13,
    edge_reconnected = 14,

    // View events
    viewport_changed = 20,
    zoom_changed = 21,
    fit_view = 22,

    // Selection events
    selection_changed = 30,
    selection_cleared = 31,

    // History events
    undo = 40,
    redo = 41,
    history_changed = 42,

    // Layout events
    layout_applied = 50,

    // Flow events
    flow_loaded = 60,
    flow_saved = 61,
    flow_cleared = 62,

    pub fn isNodeEvent(self: FlowEventType) bool {
        return @intFromEnum(self) < 10;
    }

    pub fn isEdgeEvent(self: FlowEventType) bool {
        const val = @intFromEnum(self);
        return val >= 10 and val < 20;
    }
};

/// Flow event data
pub const FlowEvent = struct {
    event_type: FlowEventType,
    timestamp: i64,
    node_id: ?nodes.NodeId = null,
    edge_id: ?edges.EdgeId = null,
    data: ?*anyopaque = null,
};

/// Serializable node data
pub const SerializedNode = struct {
    id: u64,
    node_type: u8,
    position_x: f32,
    position_y: f32,
    width: f32,
    height: f32,
    label: ?[]const u8 = null,
    data: ?[]const u8 = null, // JSON string
    handles: []const SerializedHandle = &.{},
};

/// Serializable handle data
pub const SerializedHandle = struct {
    id: []const u8,
    handle_type: u8,
    position: u8,
};

/// Serializable edge data
pub const SerializedEdge = struct {
    id: u64,
    source_node: u64,
    source_handle: ?[]const u8 = null,
    target_node: u64,
    target_handle: ?[]const u8 = null,
    edge_type: u8 = 1, // bezier
    label: ?[]const u8 = null,
};

/// Serializable flow data
pub const SerializedFlow = struct {
    version: []const u8 = "1.0",
    nodes: []const SerializedNode = &.{},
    edges: []const SerializedEdge = &.{},
    viewport_x: f32 = 0,
    viewport_y: f32 = 0,
    viewport_zoom: f32 = 1.0,
};

/// History action for undo/redo
pub const HistoryAction = struct {
    action_type: HistoryActionType,
    timestamp: i64,
    // Store serialized state snapshots
    before_state: ?[]const u8 = null,
    after_state: ?[]const u8 = null,
    description: []const u8 = "",
};

/// History action type
pub const HistoryActionType = enum(u8) {
    add_node = 0,
    remove_node = 1,
    move_nodes = 2,
    add_edge = 3,
    remove_edge = 4,
    batch = 5, // Multiple actions combined
    paste = 6,
    layout = 7,
    custom = 255,

    pub fn toString(self: HistoryActionType) []const u8 {
        return switch (self) {
            .add_node => "Add Node",
            .remove_node => "Remove Node",
            .move_nodes => "Move Nodes",
            .add_edge => "Add Edge",
            .remove_edge => "Remove Edge",
            .batch => "Batch Action",
            .paste => "Paste",
            .layout => "Apply Layout",
            .custom => "Custom Action",
        };
    }
};

/// Clipboard content
pub const ClipboardContent = struct {
    nodes: []const SerializedNode,
    edges: []const SerializedEdge,
    offset_x: f32 = 20, // Paste offset
    offset_y: f32 = 20,
};

/// Flow statistics
pub const FlowStats = struct {
    node_count: usize = 0,
    edge_count: usize = 0,
    selected_nodes: usize = 0,
    selected_edges: usize = 0,
    history_size: usize = 0,
    can_undo: bool = false,
    can_redo: bool = false,
};

/// Flow Manager - Main state manager
pub const FlowManager = struct {
    allocator: std.mem.Allocator,
    node_manager: nodes.NodeManager,
    edge_manager: edges.EdgeManager,
    layout_manager: layout.LayoutManager,

    // History
    history: std.ArrayListUnmanaged(HistoryAction) = .{},
    history_index: usize = 0,
    max_history: usize = 100,
    history_enabled: bool = true,

    // Clipboard
    clipboard: ?ClipboardContent = null,

    // Event system
    event_listeners: std.ArrayListUnmanaged(*const fn (FlowEvent) void) = .{},

    // State
    dirty: bool = false, // Has unsaved changes
    flow_name: []const u8 = "Untitled",

    pub fn init(allocator: std.mem.Allocator) FlowManager {
        return .{
            .allocator = allocator,
            .node_manager = nodes.NodeManager.init(allocator),
            .edge_manager = edges.EdgeManager.init(allocator),
            .layout_manager = layout.LayoutManager.init(allocator),
        };
    }

    pub fn deinit(self: *FlowManager) void {
        self.history.deinit(self.allocator);
        self.event_listeners.deinit(self.allocator);
        self.layout_manager.deinit();
        self.edge_manager.deinit();
        self.node_manager.deinit();
    }

    /// Add event listener
    pub fn addEventListener(self: *FlowManager, listener: *const fn (FlowEvent) void) !void {
        try self.event_listeners.append(self.allocator, listener);
    }

    /// Emit event to all listeners
    pub fn emitEvent(self: *FlowManager, event: FlowEvent) void {
        for (self.event_listeners.items) |listener| {
            listener(event);
        }
    }

    /// Add a node
    pub fn addNode(self: *FlowManager, config: nodes.NodeConfig) !nodes.NodeId {
        const node_id = try self.node_manager.addNode(config);
        self.markDirty();

        if (self.history_enabled) {
            try self.pushHistory(.{
                .action_type = .add_node,
                .timestamp = std.time.timestamp(),
                .description = "Add node",
            });
        }

        self.emitEvent(.{
            .event_type = .node_added,
            .timestamp = std.time.timestamp(),
            .node_id = node_id,
        });

        return node_id;
    }

    /// Remove a node
    pub fn removeNode(self: *FlowManager, node_id: nodes.NodeId) bool {
        // Remove connected edges first
        _ = self.edge_manager.removeNodeEdges(node_id);

        const removed = self.node_manager.removeNode(node_id);
        if (removed) {
            self.markDirty();

            if (self.history_enabled) {
                self.pushHistory(.{
                    .action_type = .remove_node,
                    .timestamp = std.time.timestamp(),
                    .description = "Remove node",
                }) catch {};
            }

            self.emitEvent(.{
                .event_type = .node_removed,
                .timestamp = std.time.timestamp(),
                .node_id = node_id,
            });
        }
        return removed;
    }

    /// Add an edge
    pub fn addEdge(self: *FlowManager, config: edges.EdgeConfig) !edges.EdgeId {
        const edge_id = try self.edge_manager.addEdge(config);
        self.markDirty();

        if (self.history_enabled) {
            try self.pushHistory(.{
                .action_type = .add_edge,
                .timestamp = std.time.timestamp(),
                .description = "Add edge",
            });
        }

        self.emitEvent(.{
            .event_type = .edge_added,
            .timestamp = std.time.timestamp(),
            .edge_id = edge_id,
        });

        return edge_id;
    }

    /// Remove an edge
    pub fn removeEdge(self: *FlowManager, edge_id: edges.EdgeId) bool {
        const removed = self.edge_manager.removeEdge(edge_id);
        if (removed) {
            self.markDirty();

            if (self.history_enabled) {
                self.pushHistory(.{
                    .action_type = .remove_edge,
                    .timestamp = std.time.timestamp(),
                    .description = "Remove edge",
                }) catch {};
            }

            self.emitEvent(.{
                .event_type = .edge_removed,
                .timestamp = std.time.timestamp(),
                .edge_id = edge_id,
            });
        }
        return removed;
    }

    /// Delete selected elements
    pub fn deleteSelected(self: *FlowManager) u32 {
        var deleted: u32 = 0;

        // Delete selected edges
        const selected_edges = self.edge_manager.getSelectedEdges();
        for (selected_edges) |edge_id| {
            if (self.removeEdge(edge_id)) {
                deleted += 1;
            }
        }

        // Delete selected nodes (and their edges)
        const selected_nodes = self.node_manager.getSelectedNodes();
        for (selected_nodes) |node_id| {
            if (self.removeNode(node_id)) {
                deleted += 1;
            }
        }

        return deleted;
    }

    /// Clear all content
    pub fn clear(self: *FlowManager) void {
        // Clear edges first
        var edge_iter = self.edge_manager.edges.iterator();
        var edges_to_remove: std.ArrayListUnmanaged(edges.EdgeId) = .{};
        defer edges_to_remove.deinit(self.allocator);

        while (edge_iter.next()) |entry| {
            edges_to_remove.append(self.allocator, .{ .id = entry.key_ptr.* }) catch continue;
        }
        for (edges_to_remove.items) |edge_id| {
            _ = self.edge_manager.removeEdge(edge_id);
        }

        // Clear nodes
        var node_iter = self.node_manager.nodes.iterator();
        var nodes_to_remove: std.ArrayListUnmanaged(nodes.NodeId) = .{};
        defer nodes_to_remove.deinit(self.allocator);

        while (node_iter.next()) |entry| {
            nodes_to_remove.append(self.allocator, .{ .id = entry.key_ptr.* }) catch continue;
        }
        for (nodes_to_remove.items) |node_id| {
            _ = self.node_manager.removeNode(node_id);
        }

        self.dirty = false;

        self.emitEvent(.{
            .event_type = .flow_cleared,
            .timestamp = std.time.timestamp(),
        });
    }

    /// Serialize flow to JSON string
    pub fn serialize(self: *const FlowManager) ![]u8 {
        var node_list = std.ArrayListUnmanaged(SerializedNode){};
        defer node_list.deinit(self.allocator);

        var node_iter = self.node_manager.nodes.iterator();
        while (node_iter.next()) |entry| {
            const node = entry.value_ptr;
            try node_list.append(self.allocator, .{
                .id = node.id.id,
                .node_type = @intFromEnum(node.node_type),
                .position_x = node.position.x,
                .position_y = node.position.y,
                .width = node.dimensions.width,
                .height = node.dimensions.height,
            });
        }

        var edge_list = std.ArrayListUnmanaged(SerializedEdge){};
        defer edge_list.deinit(self.allocator);

        var edge_iter = self.edge_manager.edges.iterator();
        while (edge_iter.next()) |entry| {
            const edge = entry.value_ptr;
            try edge_list.append(self.allocator, .{
                .id = edge.id.id,
                .source_node = edge.source.node_id.id,
                .source_handle = edge.source.handle_id,
                .target_node = edge.target.node_id.id,
                .target_handle = edge.target.handle_id,
                .edge_type = @intFromEnum(edge.edge_type),
            });
        }

        // Build JSON manually (simplified)
        var result = std.ArrayListUnmanaged(u8){};
        errdefer result.deinit(self.allocator);

        try result.appendSlice(self.allocator, "{\"version\":\"1.0\",\"nodes\":[");

        for (node_list.items, 0..) |node, i| {
            if (i > 0) try result.append(self.allocator, ',');
            const node_json = try std.fmt.allocPrint(self.allocator, "{{\"id\":{d},\"type\":{d},\"x\":{d:.2},\"y\":{d:.2},\"w\":{d:.2},\"h\":{d:.2}}}", .{
                node.id,
                node.node_type,
                node.position_x,
                node.position_y,
                node.width,
                node.height,
            });
            defer self.allocator.free(node_json);
            try result.appendSlice(self.allocator, node_json);
        }

        try result.appendSlice(self.allocator, "],\"edges\":[");

        for (edge_list.items, 0..) |edge, i| {
            if (i > 0) try result.append(self.allocator, ',');
            const edge_json = try std.fmt.allocPrint(self.allocator, "{{\"id\":{d},\"src\":{d},\"tgt\":{d},\"type\":{d}}}", .{
                edge.id,
                edge.source_node,
                edge.target_node,
                edge.edge_type,
            });
            defer self.allocator.free(edge_json);
            try result.appendSlice(self.allocator, edge_json);
        }

        try result.appendSlice(self.allocator, "],\"viewport\":{\"x\":");
        const vx = try std.fmt.allocPrint(self.allocator, "{d:.2}", .{self.layout_manager.viewport.x});
        defer self.allocator.free(vx);
        try result.appendSlice(self.allocator, vx);

        try result.appendSlice(self.allocator, ",\"y\":");
        const vy = try std.fmt.allocPrint(self.allocator, "{d:.2}", .{self.layout_manager.viewport.y});
        defer self.allocator.free(vy);
        try result.appendSlice(self.allocator, vy);

        try result.appendSlice(self.allocator, ",\"zoom\":");
        const vz = try std.fmt.allocPrint(self.allocator, "{d:.2}", .{self.layout_manager.viewport.zoom});
        defer self.allocator.free(vz);
        try result.appendSlice(self.allocator, vz);

        try result.appendSlice(self.allocator, "}}");

        return try result.toOwnedSlice(self.allocator);
    }

    /// Copy selected elements to clipboard
    pub fn copy(self: *FlowManager) !void {
        const selected_nodes = self.node_manager.getSelectedNodes();
        if (selected_nodes.len == 0) return;

        var node_list = std.ArrayListUnmanaged(SerializedNode){};
        defer node_list.deinit(self.allocator);

        for (selected_nodes) |node_id| {
            if (self.node_manager.getNode(node_id)) |node| {
                try node_list.append(self.allocator, .{
                    .id = node.id.id,
                    .node_type = @intFromEnum(node.node_type),
                    .position_x = node.position.x,
                    .position_y = node.position.y,
                    .width = node.dimensions.width,
                    .height = node.dimensions.height,
                });
            }
        }

        // Copy edges between selected nodes
        var edge_list = std.ArrayListUnmanaged(SerializedEdge){};
        defer edge_list.deinit(self.allocator);

        var edge_iter = self.edge_manager.edges.iterator();
        while (edge_iter.next()) |entry| {
            const edge = entry.value_ptr;
            var source_selected = false;
            var target_selected = false;

            for (selected_nodes) |sel_id| {
                if (edge.source.node_id.eql(sel_id)) source_selected = true;
                if (edge.target.node_id.eql(sel_id)) target_selected = true;
            }

            if (source_selected and target_selected) {
                try edge_list.append(self.allocator, .{
                    .id = edge.id.id,
                    .source_node = edge.source.node_id.id,
                    .target_node = edge.target.node_id.id,
                    .edge_type = @intFromEnum(edge.edge_type),
                });
            }
        }

        self.clipboard = .{
            .nodes = try node_list.toOwnedSlice(self.allocator),
            .edges = try edge_list.toOwnedSlice(self.allocator),
        };
    }

    /// Paste from clipboard
    pub fn paste(self: *FlowManager) !void {
        const clip = self.clipboard orelse return;
        if (clip.nodes.len == 0) return;

        // Map old IDs to new IDs
        var id_map = std.AutoHashMapUnmanaged(u64, u64){};
        defer id_map.deinit(self.allocator);

        // Clear selection
        self.node_manager.clearSelection();

        // Create new nodes
        for (clip.nodes) |node_data| {
            const new_id = try self.node_manager.addNode(.{
                .node_type = @enumFromInt(node_data.node_type),
                .position = .{
                    .x = node_data.position_x + clip.offset_x,
                    .y = node_data.position_y + clip.offset_y,
                },
                .dimensions = .{
                    .width = node_data.width,
                    .height = node_data.height,
                },
            });
            try id_map.put(self.allocator, node_data.id, new_id.id);
            self.node_manager.selectNode(new_id);
        }

        // Create new edges
        for (clip.edges) |edge_data| {
            const new_source = id_map.get(edge_data.source_node) orelse continue;
            const new_target = id_map.get(edge_data.target_node) orelse continue;

            _ = self.edge_manager.addEdge(.{
                .source = .{ .node_id = .{ .id = new_source } },
                .target = .{ .node_id = .{ .id = new_target } },
                .edge_type = @enumFromInt(edge_data.edge_type),
            }) catch continue;
        }

        self.markDirty();

        if (self.history_enabled) {
            try self.pushHistory(.{
                .action_type = .paste,
                .timestamp = std.time.timestamp(),
                .description = "Paste",
            });
        }
    }

    /// Cut selected elements
    pub fn cut(self: *FlowManager) !void {
        try self.copy();
        _ = self.deleteSelected();
    }

    /// Push action to history
    pub fn pushHistory(self: *FlowManager, action: HistoryAction) !void {
        // Remove any redo history
        if (self.history_index < self.history.items.len) {
            self.history.shrinkRetainingCapacity(self.history_index);
        }

        // Add new action
        try self.history.append(self.allocator, action);
        self.history_index = self.history.items.len;

        // Trim old history if needed
        if (self.history.items.len > self.max_history) {
            _ = self.history.orderedRemove(0);
            self.history_index -= 1;
        }

        self.emitEvent(.{
            .event_type = .history_changed,
            .timestamp = std.time.timestamp(),
        });
    }

    /// Undo last action
    pub fn undo(self: *FlowManager) bool {
        if (self.history_index == 0) return false;

        self.history_index -= 1;
        // In a full implementation, restore state from history[history_index].before_state

        self.emitEvent(.{
            .event_type = .undo,
            .timestamp = std.time.timestamp(),
        });

        return true;
    }

    /// Redo last undone action
    pub fn redo(self: *FlowManager) bool {
        if (self.history_index >= self.history.items.len) return false;

        // In a full implementation, restore state from history[history_index].after_state
        self.history_index += 1;

        self.emitEvent(.{
            .event_type = .redo,
            .timestamp = std.time.timestamp(),
        });

        return true;
    }

    /// Check if undo is available
    pub fn canUndo(self: *const FlowManager) bool {
        return self.history_index > 0;
    }

    /// Check if redo is available
    pub fn canRedo(self: *const FlowManager) bool {
        return self.history_index < self.history.items.len;
    }

    /// Clear history
    pub fn clearHistory(self: *FlowManager) void {
        self.history.clearRetainingCapacity();
        self.history_index = 0;
    }

    /// Get flow statistics
    pub fn getStats(self: *const FlowManager) FlowStats {
        return .{
            .node_count = self.node_manager.count(),
            .edge_count = self.edge_manager.count(),
            .selected_nodes = self.node_manager.getSelectedNodes().len,
            .selected_edges = self.edge_manager.getSelectedEdges().len,
            .history_size = self.history.items.len,
            .can_undo = self.canUndo(),
            .can_redo = self.canRedo(),
        };
    }

    /// Mark flow as having unsaved changes
    pub fn markDirty(self: *FlowManager) void {
        self.dirty = true;
    }

    /// Mark flow as saved
    pub fn markClean(self: *FlowManager) void {
        self.dirty = false;
    }

    /// Check if flow has unsaved changes
    pub fn isDirty(self: *const FlowManager) bool {
        return self.dirty;
    }

    /// Apply auto-layout
    pub fn applyLayout(self: *FlowManager) !void {
        _ = try self.layout_manager.applyLayout(&self.node_manager, &self.edge_manager);
        self.markDirty();

        if (self.history_enabled) {
            try self.pushHistory(.{
                .action_type = .layout,
                .timestamp = std.time.timestamp(),
                .description = "Apply layout",
            });
        }

        self.emitEvent(.{
            .event_type = .layout_applied,
            .timestamp = std.time.timestamp(),
        });
    }

    /// Select all elements
    pub fn selectAll(self: *FlowManager) void {
        var node_iter = self.node_manager.nodes.iterator();
        while (node_iter.next()) |entry| {
            self.node_manager.selectNode(.{ .id = entry.key_ptr.* });
        }

        var edge_iter = self.edge_manager.edges.iterator();
        while (edge_iter.next()) |entry| {
            self.edge_manager.selectEdge(.{ .id = entry.key_ptr.* });
        }

        self.emitEvent(.{
            .event_type = .selection_changed,
            .timestamp = std.time.timestamp(),
        });
    }

    /// Clear all selections
    pub fn clearSelection(self: *FlowManager) void {
        self.node_manager.clearSelection();
        self.edge_manager.clearSelection();

        self.emitEvent(.{
            .event_type = .selection_cleared,
            .timestamp = std.time.timestamp(),
        });
    }
};

/// Create a flow manager
pub fn createFlowManager(allocator: std.mem.Allocator) FlowManager {
    return FlowManager.init(allocator);
}

// Tests
test "FlowManager initialization" {
    const allocator = std.testing.allocator;
    var manager = createFlowManager(allocator);
    defer manager.deinit();

    const stats = manager.getStats();
    try std.testing.expectEqual(@as(usize, 0), stats.node_count);
    try std.testing.expectEqual(@as(usize, 0), stats.edge_count);
    try std.testing.expect(!manager.isDirty());
}

test "Add and remove nodes" {
    const allocator = std.testing.allocator;
    var manager = createFlowManager(allocator);
    defer manager.deinit();

    const node_id = try manager.addNode(.{
        .position = .{ .x = 100, .y = 100 },
    });

    try std.testing.expectEqual(@as(usize, 1), manager.node_manager.count());
    try std.testing.expect(manager.isDirty());

    try std.testing.expect(manager.removeNode(node_id));
    try std.testing.expectEqual(@as(usize, 0), manager.node_manager.count());
}

test "Add and remove edges" {
    const allocator = std.testing.allocator;
    var manager = createFlowManager(allocator);
    defer manager.deinit();

    _ = try manager.addNode(.{ .position = .{ .x = 0, .y = 0 } });
    _ = try manager.addNode(.{ .position = .{ .x = 200, .y = 0 } });

    const edge_id = try manager.addEdge(.{
        .source = .{ .node_id = .{ .id = 1 } },
        .target = .{ .node_id = .{ .id = 2 } },
    });

    try std.testing.expectEqual(@as(usize, 1), manager.edge_manager.count());

    try std.testing.expect(manager.removeEdge(edge_id));
    try std.testing.expectEqual(@as(usize, 0), manager.edge_manager.count());
}

test "History undo/redo" {
    const allocator = std.testing.allocator;
    var manager = createFlowManager(allocator);
    defer manager.deinit();

    try std.testing.expect(!manager.canUndo());

    _ = try manager.addNode(.{ .position = .{ .x = 0, .y = 0 } });
    try std.testing.expect(manager.canUndo());
    try std.testing.expect(!manager.canRedo());

    try std.testing.expect(manager.undo());
    try std.testing.expect(!manager.canUndo());
    try std.testing.expect(manager.canRedo());

    try std.testing.expect(manager.redo());
    try std.testing.expect(manager.canUndo());
    try std.testing.expect(!manager.canRedo());
}

test "Clear history" {
    const allocator = std.testing.allocator;
    var manager = createFlowManager(allocator);
    defer manager.deinit();

    _ = try manager.addNode(.{ .position = .{ .x = 0, .y = 0 } });
    _ = try manager.addNode(.{ .position = .{ .x = 100, .y = 0 } });

    try std.testing.expect(manager.history.items.len > 0);

    manager.clearHistory();
    try std.testing.expectEqual(@as(usize, 0), manager.history.items.len);
    try std.testing.expect(!manager.canUndo());
}

test "Serialization" {
    const allocator = std.testing.allocator;
    var manager = createFlowManager(allocator);
    defer manager.deinit();

    _ = try manager.addNode(.{
        .position = .{ .x = 100, .y = 200 },
        .dimensions = .{ .width = 150, .height = 50 },
    });

    const json = try manager.serialize();
    defer allocator.free(json);

    try std.testing.expect(json.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"version\":\"1.0\"") != null);
}

test "Flow statistics" {
    const allocator = std.testing.allocator;
    var manager = createFlowManager(allocator);
    defer manager.deinit();

    const node1 = try manager.addNode(.{ .position = .{ .x = 0, .y = 0 } });
    _ = try manager.addNode(.{ .position = .{ .x = 200, .y = 0 } });
    _ = try manager.addEdge(.{
        .source = .{ .node_id = .{ .id = 1 } },
        .target = .{ .node_id = .{ .id = 2 } },
    });

    manager.node_manager.selectNode(node1);

    const stats = manager.getStats();
    try std.testing.expectEqual(@as(usize, 2), stats.node_count);
    try std.testing.expectEqual(@as(usize, 1), stats.edge_count);
    try std.testing.expectEqual(@as(usize, 1), stats.selected_nodes);
}

test "FlowEventType categories" {
    try std.testing.expect(FlowEventType.node_added.isNodeEvent());
    try std.testing.expect(!FlowEventType.edge_added.isNodeEvent());
    try std.testing.expect(FlowEventType.edge_added.isEdgeEvent());
}

test "HistoryActionType toString" {
    try std.testing.expect(std.mem.eql(u8, "Add Node", HistoryActionType.add_node.toString()));
    try std.testing.expect(std.mem.eql(u8, "Undo", HistoryActionType.batch.toString()) == false);
}

test "Clear flow" {
    const allocator = std.testing.allocator;
    var manager = createFlowManager(allocator);
    defer manager.deinit();

    _ = try manager.addNode(.{ .position = .{ .x = 0, .y = 0 } });
    _ = try manager.addNode(.{ .position = .{ .x = 200, .y = 0 } });

    manager.clear();

    const stats = manager.getStats();
    try std.testing.expectEqual(@as(usize, 0), stats.node_count);
    try std.testing.expect(!manager.isDirty());
}

test "Dirty state" {
    const allocator = std.testing.allocator;
    var manager = createFlowManager(allocator);
    defer manager.deinit();

    try std.testing.expect(!manager.isDirty());

    _ = try manager.addNode(.{ .position = .{ .x = 0, .y = 0 } });
    try std.testing.expect(manager.isDirty());

    manager.markClean();
    try std.testing.expect(!manager.isDirty());
}
