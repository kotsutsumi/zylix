//! NodeFlow - React Flow-style Node-based UI
//!
//! A comprehensive node-based UI system for visual programming interfaces.
//!
//! ## Features
//! - Core Node System: Nodes, handles, ports, selection
//! - Connection System: Edges with bezier/step/straight paths
//! - Layout & Styling: Auto-layout, themes, grid, minimap
//! - Interactions: Context menus, shortcuts, touch, drag-drop
//! - Data & Events: Serialization, undo/redo, clipboard
//!
//! ## Quick Start
//! ```zig
//! const nodeflow = @import("nodeflow");
//!
//! var flow = nodeflow.createFlow(allocator);
//! defer flow.deinit();
//!
//! // Add nodes
//! const node1 = try flow.addNode(.{
//!     .position = .{ .x = 100, .y = 100 },
//!     .node_type = .default,
//! });
//!
//! const node2 = try flow.addNode(.{
//!     .position = .{ .x = 300, .y = 100 },
//!     .node_type = .default,
//! });
//!
//! // Connect nodes
//! _ = try flow.addEdge(.{
//!     .source = .{ .node_id = node1 },
//!     .target = .{ .node_id = node2 },
//! });
//!
//! // Apply auto-layout
//! try flow.applyLayout();
//!
//! // Serialize to JSON
//! const json = try flow.serialize();
//! ```

const std = @import("std");

// Re-export all submodules
pub const nodes = @import("nodes.zig");
pub const edges = @import("edges.zig");
pub const layout = @import("layout.zig");
pub const interaction = @import("interaction.zig");
pub const flow = @import("flow.zig");

// Convenience type aliases
pub const Node = nodes.Node;
pub const NodeId = nodes.NodeId;
pub const NodeType = nodes.NodeType;
pub const NodeConfig = nodes.NodeConfig;
pub const NodeManager = nodes.NodeManager;
pub const Position = nodes.Position;
pub const Dimensions = nodes.Dimensions;
pub const Handle = nodes.Handle;
pub const HandleType = nodes.HandleType;
pub const HandlePosition = nodes.HandlePosition;

pub const Edge = edges.Edge;
pub const EdgeId = edges.EdgeId;
pub const EdgeType = edges.EdgeType;
pub const EdgeConfig = edges.EdgeConfig;
pub const EdgeManager = edges.EdgeManager;
pub const EdgeStyle = edges.EdgeStyle;
pub const EdgeLabel = edges.EdgeLabel;
pub const ConnectionEndpoint = edges.ConnectionEndpoint;

pub const LayoutManager = layout.LayoutManager;
pub const LayoutAlgorithm = layout.LayoutAlgorithm;
pub const LayoutDirection = layout.LayoutDirection;
pub const LayoutOptions = layout.LayoutOptions;
pub const Viewport = layout.Viewport;
pub const Bounds = layout.Bounds;
pub const GridConfig = layout.GridConfig;
pub const MinimapConfig = layout.MinimapConfig;
pub const Theme = layout.Theme;
pub const ThemeColors = layout.ThemeColors;

pub const InteractionManager = interaction.InteractionManager;
pub const PointerEvent = interaction.PointerEvent;
pub const PointerButton = interaction.PointerButton;
pub const KeyEvent = interaction.KeyEvent;
pub const Key = interaction.Key;
pub const Modifiers = interaction.Modifiers;
pub const Action = interaction.Action;
pub const Shortcut = interaction.Shortcut;
pub const ContextMenu = interaction.ContextMenu;
pub const MenuItem = interaction.MenuItem;
pub const DragState = interaction.DragState;
pub const SelectionBox = interaction.SelectionBox;

pub const FlowManager = flow.FlowManager;
pub const FlowEvent = flow.FlowEvent;
pub const FlowEventType = flow.FlowEventType;
pub const FlowStats = flow.FlowStats;
pub const SerializedFlow = flow.SerializedFlow;
pub const SerializedNode = flow.SerializedNode;
pub const SerializedEdge = flow.SerializedEdge;
pub const HistoryAction = flow.HistoryAction;
pub const HistoryActionType = flow.HistoryActionType;
pub const ClipboardContent = flow.ClipboardContent;

// Error types
pub const NodeError = nodes.NodeError;
pub const EdgeError = edges.EdgeError;
pub const LayoutError = layout.LayoutError;
pub const InteractionError = interaction.InteractionError;
pub const FlowError = flow.FlowError;

/// Create a new flow manager (main entry point)
pub fn createFlow(allocator: std.mem.Allocator) FlowManager {
    return flow.createFlowManager(allocator);
}

/// Create a standalone node manager
pub fn createNodeManager(allocator: std.mem.Allocator) NodeManager {
    return nodes.createNodeManager(allocator);
}

/// Create a standalone edge manager
pub fn createEdgeManager(allocator: std.mem.Allocator) EdgeManager {
    return edges.createEdgeManager(allocator);
}

/// Create a standalone layout manager
pub fn createLayoutManager(allocator: std.mem.Allocator) LayoutManager {
    return layout.createLayoutManager(allocator);
}

/// Create a standalone interaction manager
pub fn createInteractionManager(allocator: std.mem.Allocator) InteractionManager {
    return interaction.createInteractionManager(allocator);
}

/// NodeFlow version
pub const version = "0.17.0";

/// NodeFlow capabilities
pub const Capabilities = struct {
    pub const max_nodes: usize = 10000;
    pub const max_edges: usize = 50000;
    pub const max_handles_per_node: usize = 32;
    pub const max_history_entries: usize = 100;
    pub const supports_touch: bool = true;
    pub const supports_multiselect: bool = true;
    pub const supports_undo_redo: bool = true;
    pub const supports_clipboard: bool = true;
    pub const supports_serialization: bool = true;
};

// Tests
test "NodeFlow module exports" {
    // Verify all types are accessible
    _ = Node;
    _ = NodeId;
    _ = Edge;
    _ = EdgeId;
    _ = FlowManager;
    _ = LayoutManager;
    _ = InteractionManager;
}

test "Create flow manager" {
    const allocator = std.testing.allocator;
    var mgr = createFlow(allocator);
    defer mgr.deinit();

    try std.testing.expectEqual(@as(usize, 0), mgr.node_manager.count());
}

test "Create standalone managers" {
    const allocator = std.testing.allocator;

    var nm = createNodeManager(allocator);
    defer nm.deinit();

    var em = createEdgeManager(allocator);
    defer em.deinit();

    var lm = createLayoutManager(allocator);
    defer lm.deinit();

    var im = createInteractionManager(allocator);
    defer im.deinit();
}

test "Full workflow" {
    const allocator = std.testing.allocator;
    var mgr = createFlow(allocator);
    defer mgr.deinit();

    // Add nodes
    const n1 = try mgr.addNode(.{
        .position = .{ .x = 0, .y = 0 },
        .node_type = .input,
    });
    const n2 = try mgr.addNode(.{
        .position = .{ .x = 200, .y = 0 },
        .node_type = .default,
    });
    const n3 = try mgr.addNode(.{
        .position = .{ .x = 400, .y = 0 },
        .node_type = .output,
    });

    // Add edges
    _ = try mgr.addEdge(.{
        .source = .{ .node_id = n1 },
        .target = .{ .node_id = n2 },
    });
    _ = try mgr.addEdge(.{
        .source = .{ .node_id = n2 },
        .target = .{ .node_id = n3 },
    });

    // Check stats
    const stats = mgr.getStats();
    try std.testing.expectEqual(@as(usize, 3), stats.node_count);
    try std.testing.expectEqual(@as(usize, 2), stats.edge_count);

    // Serialize
    const json = try mgr.serialize();
    defer allocator.free(json);
    try std.testing.expect(json.len > 0);

    // Test history
    try std.testing.expect(mgr.canUndo());
    try std.testing.expect(mgr.undo());
}

test "Version and capabilities" {
    try std.testing.expect(std.mem.eql(u8, "0.17.0", version));
    try std.testing.expect(Capabilities.max_nodes >= 1000);
    try std.testing.expect(Capabilities.supports_touch);
}
