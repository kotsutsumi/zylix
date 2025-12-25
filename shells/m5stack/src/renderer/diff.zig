//! Virtual DOM Diff Algorithm
//!
//! Calculates differences between two Virtual DOM trees.
//! Optimized for embedded systems with minimal allocations.

const std = @import("std");
const vdom = @import("vdom.zig");

const VNode = vdom.VNode;
const VNodeType = vdom.VNodeType;
const VNodeProps = vdom.VNodeProps;
const VDom = vdom.VDom;

/// Type of change
pub const ChangeType = enum {
    create,   // New node created
    update,   // Node properties changed
    remove,   // Node removed
    move,     // Node moved to different position
};

/// A single change operation
pub const Change = struct {
    change_type: ChangeType,
    node_id: u32,
    parent_id: u32,
    old_props: ?VNodeProps,
    new_props: ?VNodeProps,
    node_type: VNodeType,
    index: usize,
};

/// Result of diff calculation
pub const DiffResult = struct {
    changes: std.ArrayList(Change),
    dirty_rects: std.ArrayList(DirtyRect),
    allocator: std.mem.Allocator,

    /// Dirty rectangle for optimized redraw
    pub const DirtyRect = struct {
        x: i32,
        y: i32,
        width: u16,
        height: u16,

        /// Merge with another rect
        pub fn merge(self: *DirtyRect, other: DirtyRect) void {
            const new_x = @min(self.x, other.x);
            const new_y = @min(self.y, other.y);
            const max_x = @max(self.x + @as(i32, self.width), other.x + @as(i32, other.width));
            const max_y = @max(self.y + @as(i32, self.height), other.y + @as(i32, other.height));

            self.x = new_x;
            self.y = new_y;
            self.width = @intCast(max_x - new_x);
            self.height = @intCast(max_y - new_y);
        }
    };

    /// Initialize diff result
    pub fn init(allocator: std.mem.Allocator) DiffResult {
        return .{
            .changes = std.ArrayList(Change).init(allocator),
            .dirty_rects = std.ArrayList(DirtyRect).init(allocator),
            .allocator = allocator,
        };
    }

    /// Clean up
    pub fn deinit(self: *const DiffResult) void {
        @constCast(&self.changes).deinit();
        @constCast(&self.dirty_rects).deinit();
    }

    /// Check if there are any changes
    pub fn hasChanges(self: *const DiffResult) bool {
        return self.changes.items.len > 0;
    }

    /// Get number of changes
    pub fn changeCount(self: *const DiffResult) usize {
        return self.changes.items.len;
    }
};

/// Calculate diff between two VDom trees
pub fn calculate(allocator: std.mem.Allocator, old_tree: *VDom, new_tree: *VDom) !DiffResult {
    var result = DiffResult.init(allocator);

    const old_root = old_tree.root orelse return result;
    const new_root = new_tree.root orelse return result;

    try diffNode(&result, old_root, new_root, 0);

    return result;
}

/// Diff a single node and its children
fn diffNode(result: *DiffResult, old_node: ?*VNode, new_node: ?*VNode, index: usize) !void {
    // Both null - no change
    if (old_node == null and new_node == null) {
        return;
    }

    // New node created
    if (old_node == null) {
        if (new_node) |node| {
            try addCreateChange(result, node, index);
        }
        return;
    }

    // Old node removed
    if (new_node == null) {
        if (old_node) |node| {
            try addRemoveChange(result, node);
        }
        return;
    }

    const old = old_node.?;
    const new = new_node.?;

    // Different node types - replace
    if (old.node_type != new.node_type) {
        try addRemoveChange(result, old);
        try addCreateChange(result, new, index);
        return;
    }

    // Same type - check for updates
    if (!old.props.eql(new.props)) {
        try addUpdateChange(result, old, new);
    }

    // Diff children
    try diffChildren(result, old, new);
}

/// Diff children of two nodes
fn diffChildren(result: *DiffResult, old_parent: *VNode, new_parent: *VNode) !void {
    var old_child = old_parent.first_child;
    var new_child = new_parent.first_child;
    var index: usize = 0;

    // Simple linear diff (could be optimized with key-based reconciliation)
    while (old_child != null or new_child != null) {
        try diffNode(result, old_child, new_child, index);

        if (old_child) |oc| {
            old_child = oc.next_sibling;
        }
        if (new_child) |nc| {
            new_child = nc.next_sibling;
        }
        index += 1;
    }
}

/// Add a create change
fn addCreateChange(result: *DiffResult, node: *VNode, index: usize) !void {
    const parent_id = if (node.parent) |p| p.id else 0;

    try result.changes.append(.{
        .change_type = .create,
        .node_id = node.id,
        .parent_id = parent_id,
        .old_props = null,
        .new_props = node.props,
        .node_type = node.node_type,
        .index = index,
    });

    try addDirtyRect(result, node.props);

    // Add children
    var child = node.first_child;
    var child_index: usize = 0;
    while (child) |c| {
        try addCreateChange(result, c, child_index);
        child = c.next_sibling;
        child_index += 1;
    }
}

/// Add a remove change
fn addRemoveChange(result: *DiffResult, node: *VNode) !void {
    try result.changes.append(.{
        .change_type = .remove,
        .node_id = node.id,
        .parent_id = if (node.parent) |p| p.id else 0,
        .old_props = node.props,
        .new_props = null,
        .node_type = node.node_type,
        .index = 0,
    });

    try addDirtyRect(result, node.props);
}

/// Add an update change
fn addUpdateChange(result: *DiffResult, old_node: *VNode, new_node: *VNode) !void {
    try result.changes.append(.{
        .change_type = .update,
        .node_id = old_node.id,
        .parent_id = if (old_node.parent) |p| p.id else 0,
        .old_props = old_node.props,
        .new_props = new_node.props,
        .node_type = old_node.node_type,
        .index = 0,
    });

    // Add both old and new positions as dirty
    try addDirtyRect(result, old_node.props);
    try addDirtyRect(result, new_node.props);
}

/// Add dirty rectangle
fn addDirtyRect(result: *DiffResult, props: VNodeProps) !void {
    const rect = DiffResult.DirtyRect{
        .x = props.x,
        .y = props.y,
        .width = props.width,
        .height = props.height,
    };

    // Merge with existing if overlapping
    for (result.dirty_rects.items) |*existing| {
        if (rectsOverlap(existing.*, rect)) {
            existing.merge(rect);
            return;
        }
    }

    try result.dirty_rects.append(rect);
}

/// Check if two rects overlap
fn rectsOverlap(a: DiffResult.DirtyRect, b: DiffResult.DirtyRect) bool {
    return a.x < b.x + @as(i32, b.width) and
        a.x + @as(i32, a.width) > b.x and
        a.y < b.y + @as(i32, b.height) and
        a.y + @as(i32, a.height) > b.y;
}

// Tests
test "DiffResult initialization" {
    const allocator = std.testing.allocator;
    var result = DiffResult.init(allocator);
    defer result.deinit();

    try std.testing.expect(!result.hasChanges());
    try std.testing.expectEqual(@as(usize, 0), result.changeCount());
}

test "DirtyRect merge" {
    var rect1 = DiffResult.DirtyRect{
        .x = 0,
        .y = 0,
        .width = 50,
        .height = 50,
    };

    const rect2 = DiffResult.DirtyRect{
        .x = 40,
        .y = 40,
        .width = 50,
        .height = 50,
    };

    rect1.merge(rect2);

    try std.testing.expectEqual(@as(i32, 0), rect1.x);
    try std.testing.expectEqual(@as(i32, 0), rect1.y);
    try std.testing.expectEqual(@as(u16, 90), rect1.width);
    try std.testing.expectEqual(@as(u16, 90), rect1.height);
}

test "rectsOverlap" {
    const rect1 = DiffResult.DirtyRect{ .x = 0, .y = 0, .width = 50, .height = 50 };
    const rect2 = DiffResult.DirtyRect{ .x = 40, .y = 40, .width = 50, .height = 50 };
    const rect3 = DiffResult.DirtyRect{ .x = 100, .y = 100, .width = 50, .height = 50 };

    try std.testing.expect(rectsOverlap(rect1, rect2));
    try std.testing.expect(!rectsOverlap(rect1, rect3));
}
