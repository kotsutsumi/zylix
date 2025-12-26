//! Red-Black Tree Implementation
//!
//! Self-balancing binary search tree for the Piece Tree.
//! Maintains O(log n) height through red-black properties.

const std = @import("std");
const types = @import("types.zig");

const TreeNode = types.TreeNode;
const Piece = types.Piece;
const Color = types.Color;
const NodePosition = types.NodePosition;
const BufferError = types.BufferError;

/// Red-Black Tree for storing pieces
pub const RedBlackTree = struct {
    root: ?*TreeNode = null,
    allocator: std.mem.Allocator,
    node_count: u32 = 0,

    pub fn init(allocator: std.mem.Allocator) RedBlackTree {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *RedBlackTree) void {
        if (self.root) |root| {
            self.freeSubtree(root);
        }
        self.root = null;
        self.node_count = 0;
    }

    fn freeSubtree(self: *RedBlackTree, node: *TreeNode) void {
        if (node.left) |left| {
            self.freeSubtree(left);
        }
        if (node.right) |right| {
            self.freeSubtree(right);
        }
        node.destroy();
    }

    /// Get total length of all text in the tree
    pub fn totalLength(self: *const RedBlackTree) u64 {
        if (self.root) |root| {
            return root.subtree_length;
        }
        return 0;
    }

    /// Get total line count
    pub fn totalLineBreaks(self: *const RedBlackTree) u32 {
        if (self.root) |root| {
            return root.subtree_line_breaks;
        }
        return 0;
    }

    /// Find the node containing a given offset
    pub fn findByOffset(self: *RedBlackTree, offset: u64) BufferError!NodePosition {
        if (self.root == null) {
            return BufferError.EmptyBuffer;
        }

        var node = self.root.?;
        var current_offset: u64 = 0;

        while (true) {
            const left_length = node.left_subtree_length;

            if (offset < current_offset + left_length) {
                // Go left
                if (node.left) |left| {
                    node = left;
                } else {
                    return BufferError.InvalidOffset;
                }
            } else if (offset < current_offset + left_length + node.piece.length) {
                // Found in this node
                return NodePosition{
                    .node = node,
                    .offset_in_piece = offset - current_offset - left_length,
                    .node_start_offset = current_offset + left_length,
                };
            } else {
                // Go right
                current_offset += left_length + node.piece.length;
                if (node.right) |right| {
                    node = right;
                } else {
                    // Offset is exactly at the end
                    if (offset == current_offset) {
                        return NodePosition{
                            .node = node,
                            .offset_in_piece = node.piece.length,
                            .node_start_offset = current_offset - node.piece.length,
                        };
                    }
                    return BufferError.InvalidOffset;
                }
            }
        }
    }

    /// Find the node containing a given line number
    pub fn findByLine(self: *RedBlackTree, line: u32) BufferError!NodePosition {
        if (self.root == null) {
            return BufferError.EmptyBuffer;
        }

        if (line == 0) {
            // First line starts at offset 0
            const first = self.root.?.minimum();
            return NodePosition{
                .node = first,
                .offset_in_piece = 0,
                .node_start_offset = 0,
            };
        }

        var node = self.root.?;
        var current_offset: u64 = 0;
        var current_line: u32 = 0;

        while (true) {
            const left_lines = node.left_subtree_line_breaks;
            const left_length = node.left_subtree_length;

            if (line <= current_line + left_lines) {
                // Line is in left subtree
                if (node.left) |left| {
                    node = left;
                } else {
                    return BufferError.InvalidLine;
                }
            } else if (line <= current_line + left_lines + node.piece.line_breaks) {
                // Line starts in this node
                return NodePosition{
                    .node = node,
                    .offset_in_piece = 0, // Will need to scan for exact position
                    .node_start_offset = current_offset + left_length,
                };
            } else {
                // Line is in right subtree
                current_line += left_lines + node.piece.line_breaks;
                current_offset += left_length + node.piece.length;
                if (node.right) |right| {
                    node = right;
                } else {
                    return BufferError.InvalidLine;
                }
            }
        }
    }

    /// Insert a new piece at a specific position in the sequence
    /// Returns the inserted node
    pub fn insertAt(self: *RedBlackTree, piece: Piece, after_node: ?*TreeNode) !*TreeNode {
        const new_node = try TreeNode.create(self.allocator, piece);
        errdefer new_node.destroy();

        if (self.root == null) {
            self.root = new_node;
            new_node.color = .black;
            self.node_count = 1;
            return new_node;
        }

        if (after_node) |after| {
            // Insert after the given node
            if (after.right == null) {
                after.right = new_node;
                new_node.parent = after;
            } else {
                // Find the leftmost node in the right subtree
                const successor = after.right.?.minimum();
                successor.left = new_node;
                new_node.parent = successor;
            }
        } else {
            // Insert at the beginning (before all nodes)
            const first = self.root.?.minimum();
            first.left = new_node;
            new_node.parent = first;
        }

        self.node_count += 1;
        self.insertFixup(new_node);
        self.updateMetadataToRoot(new_node);

        return new_node;
    }

    /// Insert a piece to represent all content (for initial load)
    pub fn insertInitial(self: *RedBlackTree, piece: Piece) !*TreeNode {
        return self.insertAt(piece, null);
    }

    /// Remove a node from the tree
    pub fn remove(self: *RedBlackTree, node: *TreeNode) void {
        var replacement: ?*TreeNode = null;
        var fix_node: ?*TreeNode = null;
        var fix_parent: ?*TreeNode = null;
        var original_color = node.color;

        if (node.left == null) {
            replacement = node.right;
            fix_node = replacement;
            fix_parent = node.parent;
            self.transplant(node, node.right);
        } else if (node.right == null) {
            replacement = node.left;
            fix_node = replacement;
            fix_parent = node.parent;
            self.transplant(node, node.left);
        } else {
            // Node has two children
            const successor = node.right.?.minimum();
            original_color = successor.color;
            replacement = successor.right;
            fix_node = replacement;

            if (successor.parent == node) {
                fix_parent = successor;
                if (replacement) |r| {
                    r.parent = successor;
                }
            } else {
                fix_parent = successor.parent;
                self.transplant(successor, successor.right);
                successor.right = node.right;
                if (successor.right) |r| {
                    r.parent = successor;
                }
            }

            self.transplant(node, successor);
            successor.left = node.left;
            if (successor.left) |l| {
                l.parent = successor;
            }
            successor.color = node.color;

            // Update metadata for successor
            successor.updateMetadata();
        }

        // Update metadata up to root
        if (fix_parent) |parent| {
            self.updateMetadataToRoot(parent);
        }

        if (original_color == .black) {
            self.deleteFixup(fix_node, fix_parent);
        }

        self.node_count -= 1;
        node.destroy();
    }

    /// Replace subtree rooted at u with subtree rooted at v
    fn transplant(self: *RedBlackTree, u: *TreeNode, v: ?*TreeNode) void {
        if (u.parent == null) {
            self.root = v;
        } else if (u.isLeftChild()) {
            u.parent.?.left = v;
        } else {
            u.parent.?.right = v;
        }

        if (v) |node| {
            node.parent = u.parent;
        }
    }

    /// Fix red-black properties after insertion
    fn insertFixup(self: *RedBlackTree, node: *TreeNode) void {
        var z = node;

        while (z.parent != null and z.parent.?.color == .red) {
            const parent = z.parent.?;
            const grandparent = parent.parent orelse break;

            if (parent.isLeftChild()) {
                const uncle = grandparent.right;

                if (uncle != null and uncle.?.color == .red) {
                    // Case 1: Uncle is red
                    parent.color = .black;
                    uncle.?.color = .black;
                    grandparent.color = .red;
                    z = grandparent;
                } else {
                    if (z.isRightChild()) {
                        // Case 2: Uncle is black, z is right child
                        z = parent;
                        self.rotateLeft(z);
                    }
                    // Case 3: Uncle is black, z is left child
                    z.parent.?.color = .black;
                    z.parent.?.parent.?.color = .red;
                    self.rotateRight(z.parent.?.parent.?);
                }
            } else {
                // Mirror cases
                const uncle = grandparent.left;

                if (uncle != null and uncle.?.color == .red) {
                    parent.color = .black;
                    uncle.?.color = .black;
                    grandparent.color = .red;
                    z = grandparent;
                } else {
                    if (z.isLeftChild()) {
                        z = parent;
                        self.rotateRight(z);
                    }
                    z.parent.?.color = .black;
                    z.parent.?.parent.?.color = .red;
                    self.rotateLeft(z.parent.?.parent.?);
                }
            }
        }

        self.root.?.color = .black;
    }

    /// Fix red-black properties after deletion
    fn deleteFixup(self: *RedBlackTree, node: ?*TreeNode, parent: ?*TreeNode) void {
        var x = node;
        var p = parent;

        while ((x == null or x.?.color == .black) and x != self.root) {
            if (p == null) break;

            if (x == p.?.left) {
                var w = p.?.right;

                if (w != null and w.?.color == .red) {
                    // Case 1
                    w.?.color = .black;
                    p.?.color = .red;
                    self.rotateLeft(p.?);
                    w = p.?.right;
                }

                if (w == null) break;

                const w_left_black = w.?.left == null or w.?.left.?.color == .black;
                const w_right_black = w.?.right == null or w.?.right.?.color == .black;

                if (w_left_black and w_right_black) {
                    // Case 2
                    w.?.color = .red;
                    x = p;
                    p = x.?.parent;
                } else {
                    if (w_right_black) {
                        // Case 3
                        if (w.?.left) |wl| {
                            wl.color = .black;
                        }
                        w.?.color = .red;
                        self.rotateRight(w.?);
                        w = p.?.right;
                    }
                    // Case 4
                    if (w) |wn| {
                        wn.color = p.?.color;
                        if (wn.right) |wr| {
                            wr.color = .black;
                        }
                    }
                    p.?.color = .black;
                    self.rotateLeft(p.?);
                    x = self.root;
                    break;
                }
            } else {
                // Mirror cases
                var w = p.?.left;

                if (w != null and w.?.color == .red) {
                    w.?.color = .black;
                    p.?.color = .red;
                    self.rotateRight(p.?);
                    w = p.?.left;
                }

                if (w == null) break;

                const w_left_black = w.?.left == null or w.?.left.?.color == .black;
                const w_right_black = w.?.right == null or w.?.right.?.color == .black;

                if (w_left_black and w_right_black) {
                    w.?.color = .red;
                    x = p;
                    p = x.?.parent;
                } else {
                    if (w_left_black) {
                        if (w.?.right) |wr| {
                            wr.color = .black;
                        }
                        w.?.color = .red;
                        self.rotateLeft(w.?);
                        w = p.?.left;
                    }
                    if (w) |wn| {
                        wn.color = p.?.color;
                        if (wn.left) |wl| {
                            wl.color = .black;
                        }
                    }
                    p.?.color = .black;
                    self.rotateRight(p.?);
                    x = self.root;
                    break;
                }
            }
        }

        if (x) |xn| {
            xn.color = .black;
        }
    }

    /// Left rotation
    fn rotateLeft(self: *RedBlackTree, x: *TreeNode) void {
        const y = x.right orelse return;

        x.right = y.left;
        if (y.left) |left| {
            left.parent = x;
        }

        y.parent = x.parent;
        if (x.parent == null) {
            self.root = y;
        } else if (x.isLeftChild()) {
            x.parent.?.left = y;
        } else {
            x.parent.?.right = y;
        }

        y.left = x;
        x.parent = y;

        // Update metadata
        x.updateMetadata();
        y.updateMetadata();
    }

    /// Right rotation
    fn rotateRight(self: *RedBlackTree, y: *TreeNode) void {
        const x = y.left orelse return;

        y.left = x.right;
        if (x.right) |right| {
            right.parent = y;
        }

        x.parent = y.parent;
        if (y.parent == null) {
            self.root = x;
        } else if (y.isLeftChild()) {
            y.parent.?.left = x;
        } else {
            y.parent.?.right = x;
        }

        x.right = y;
        y.parent = x;

        // Update metadata
        y.updateMetadata();
        x.updateMetadata();
    }

    /// Update metadata from a node up to the root
    pub fn updateMetadataToRoot(self: *RedBlackTree, start: *TreeNode) void {
        _ = self;
        var node: ?*TreeNode = start;
        while (node) |n| {
            n.updateMetadata();
            node = n.parent;
        }
    }

    /// Get tree height (for testing/debugging)
    pub fn height(self: *const RedBlackTree) u32 {
        if (self.root) |root| {
            return self.nodeHeight(root);
        }
        return 0;
    }

    fn nodeHeight(self: *const RedBlackTree, node: *TreeNode) u32 {
        var left_height: u32 = 0;
        var right_height: u32 = 0;

        if (node.left) |left| {
            left_height = self.nodeHeight(left);
        }
        if (node.right) |right| {
            right_height = self.nodeHeight(right);
        }

        return 1 + @max(left_height, right_height);
    }

    /// Verify red-black properties (for testing)
    pub fn verify(self: *const RedBlackTree) bool {
        if (self.root == null) return true;

        // Root must be black
        if (self.root.?.color != .black) return false;

        // Verify properties recursively
        const result = self.verifyNode(self.root.?, 0);
        return result.valid;
    }

    const VerifyResult = struct {
        valid: bool,
        black_height: u32,
    };

    fn verifyNode(self: *const RedBlackTree, node: *TreeNode, _: u32) VerifyResult {
        var left_result = VerifyResult{ .valid = true, .black_height = 0 };
        var right_result = VerifyResult{ .valid = true, .black_height = 0 };

        // Check children
        if (node.left) |left| {
            // Red node cannot have red child
            if (node.color == .red and left.color == .red) {
                return .{ .valid = false, .black_height = 0 };
            }
            left_result = self.verifyNode(left, 0);
            if (!left_result.valid) return left_result;
        }

        if (node.right) |right| {
            if (node.color == .red and right.color == .red) {
                return .{ .valid = false, .black_height = 0 };
            }
            right_result = self.verifyNode(right, 0);
            if (!right_result.valid) return right_result;
        }

        // Black heights must match
        if (left_result.black_height != right_result.black_height) {
            return .{ .valid = false, .black_height = 0 };
        }

        const black_height = left_result.black_height + @as(u32, if (node.color == .black) 1 else 0);
        return .{ .valid = true, .black_height = black_height };
    }

    /// In-order traversal iterator
    pub fn iterator(self: *RedBlackTree) Iterator {
        return Iterator.init(self);
    }

    pub const Iterator = struct {
        current: ?*TreeNode,

        pub fn init(tree: *RedBlackTree) Iterator {
            if (tree.root) |root| {
                return .{ .current = root.minimum() };
            }
            return .{ .current = null };
        }

        pub fn next(self: *Iterator) ?*TreeNode {
            const node = self.current orelse return null;
            self.current = node.successor();
            return node;
        }
    };
};

// Tests
test "empty tree" {
    const allocator = std.testing.allocator;
    var tree = RedBlackTree.init(allocator);
    defer tree.deinit();

    try std.testing.expectEqual(@as(u64, 0), tree.totalLength());
    try std.testing.expectEqual(@as(u32, 0), tree.totalLineBreaks());
    try std.testing.expect(tree.verify());
}

test "single insert" {
    const allocator = std.testing.allocator;
    var tree = RedBlackTree.init(allocator);
    defer tree.deinit();

    const piece = Piece.init(.original, 0, 100, 5);
    _ = try tree.insertInitial(piece);

    try std.testing.expectEqual(@as(u64, 100), tree.totalLength());
    try std.testing.expectEqual(@as(u32, 5), tree.totalLineBreaks());
    try std.testing.expectEqual(@as(u32, 1), tree.node_count);
    try std.testing.expect(tree.verify());
}

test "multiple inserts maintain balance" {
    const allocator = std.testing.allocator;
    var tree = RedBlackTree.init(allocator);
    defer tree.deinit();

    // Insert 10 pieces
    var prev: ?*TreeNode = null;
    for (0..10) |i| {
        const piece = Piece.init(.add, @intCast(i * 10), 10, 1);
        prev = try tree.insertAt(piece, prev);
    }

    try std.testing.expectEqual(@as(u64, 100), tree.totalLength());
    try std.testing.expectEqual(@as(u32, 10), tree.totalLineBreaks());
    try std.testing.expectEqual(@as(u32, 10), tree.node_count);
    try std.testing.expect(tree.verify());

    // Height should be O(log n)
    const h = tree.height();
    try std.testing.expect(h <= 7); // 2 * log2(10) + 1
}

test "find by offset" {
    const allocator = std.testing.allocator;
    var tree = RedBlackTree.init(allocator);
    defer tree.deinit();

    // Insert pieces: [0-50), [50-100), [100-150)
    var prev: ?*TreeNode = null;
    for (0..3) |i| {
        const piece = Piece.init(.original, @intCast(i * 50), 50, 2);
        prev = try tree.insertAt(piece, prev);
    }

    // Find offset 75 (should be in second piece at offset 25)
    const pos = try tree.findByOffset(75);
    try std.testing.expectEqual(@as(u64, 25), pos.offset_in_piece);
    try std.testing.expectEqual(@as(u64, 50), pos.node_start_offset);
}

test "remove node" {
    const allocator = std.testing.allocator;
    var tree = RedBlackTree.init(allocator);
    defer tree.deinit();

    // Insert 5 pieces
    var nodes: [5]*TreeNode = undefined;
    var prev: ?*TreeNode = null;
    for (0..5) |i| {
        const piece = Piece.init(.add, @intCast(i * 20), 20, 1);
        nodes[i] = try tree.insertAt(piece, prev);
        prev = nodes[i];
    }

    try std.testing.expectEqual(@as(u32, 5), tree.node_count);

    // Remove middle node
    tree.remove(nodes[2]);

    try std.testing.expectEqual(@as(u32, 4), tree.node_count);
    try std.testing.expectEqual(@as(u64, 80), tree.totalLength());
    try std.testing.expect(tree.verify());
}

test "iterator" {
    const allocator = std.testing.allocator;
    var tree = RedBlackTree.init(allocator);
    defer tree.deinit();

    var prev: ?*TreeNode = null;
    for (0..5) |i| {
        const piece = Piece.init(.add, @intCast(i * 10), 10, 0);
        prev = try tree.insertAt(piece, prev);
    }

    var iter = tree.iterator();
    var count: u32 = 0;
    var prev_start: u64 = 0;

    while (iter.next()) |node| {
        if (count > 0) {
            try std.testing.expect(node.piece.start > prev_start);
        }
        prev_start = node.piece.start;
        count += 1;
    }

    try std.testing.expectEqual(@as(u32, 5), count);
}
