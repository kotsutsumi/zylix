//! Buffer Type Definitions
//!
//! Core types for the Piece Tree text buffer implementation.
//! Provides O(log n) insert/delete operations for efficient text editing.

const std = @import("std");

/// Source of text content
pub const Source = enum(u1) {
    /// Original file content (read-only, potentially mmap'd)
    original,
    /// Add buffer for edits (append-only)
    add,
};

/// Color for Red-Black tree nodes
pub const Color = enum(u1) {
    red,
    black,
};

/// A piece represents a contiguous range of text in a source buffer
pub const Piece = struct {
    /// Which buffer this piece references
    source: Source,
    /// Start offset in the source buffer
    start: u64,
    /// Length of this piece in bytes
    length: u64,
    /// Number of line breaks (LF) in this piece
    line_breaks: u32,

    /// Create a new piece
    pub fn init(source: Source, start: u64, length: u64, line_breaks: u32) Piece {
        return .{
            .source = source,
            .start = start,
            .length = length,
            .line_breaks = line_breaks,
        };
    }

    /// Check if this piece is empty
    pub fn isEmpty(self: Piece) bool {
        return self.length == 0;
    }
};

/// Red-Black tree node containing a piece and subtree metadata
pub const TreeNode = struct {
    /// The piece of text this node represents
    piece: Piece,

    /// Left child
    left: ?*TreeNode = null,
    /// Right child
    right: ?*TreeNode = null,
    /// Parent node
    parent: ?*TreeNode = null,

    /// Node color for red-black balancing
    color: Color = .red,

    // Subtree metadata for O(log n) lookups
    /// Total length of all pieces in this subtree (including self)
    subtree_length: u64 = 0,
    /// Total line breaks in this subtree (including self)
    subtree_line_breaks: u32 = 0,
    /// Size of left subtree in bytes (for offset calculations)
    left_subtree_length: u64 = 0,
    /// Line breaks in left subtree (for line calculations)
    left_subtree_line_breaks: u32 = 0,

    allocator: std.mem.Allocator,

    /// Create a new tree node
    pub fn create(allocator: std.mem.Allocator, piece: Piece) !*TreeNode {
        const node = try allocator.create(TreeNode);
        node.* = .{
            .piece = piece,
            .subtree_length = piece.length,
            .subtree_line_breaks = piece.line_breaks,
            .allocator = allocator,
        };
        return node;
    }

    /// Free this node
    pub fn destroy(self: *TreeNode) void {
        self.allocator.destroy(self);
    }

    /// Update subtree metadata based on children
    pub fn updateMetadata(self: *TreeNode) void {
        var left_len: u64 = 0;
        var left_lines: u32 = 0;
        var right_len: u64 = 0;
        var right_lines: u32 = 0;

        if (self.left) |left| {
            left_len = left.subtree_length;
            left_lines = left.subtree_line_breaks;
        }
        if (self.right) |right| {
            right_len = right.subtree_length;
            right_lines = right.subtree_line_breaks;
        }

        self.left_subtree_length = left_len;
        self.left_subtree_line_breaks = left_lines;
        self.subtree_length = left_len + self.piece.length + right_len;
        self.subtree_line_breaks = left_lines + self.piece.line_breaks + right_lines;
    }

    /// Get the minimum (leftmost) node in this subtree
    pub fn minimum(self: *TreeNode) *TreeNode {
        var node = self;
        while (node.left) |left| {
            node = left;
        }
        return node;
    }

    /// Get the maximum (rightmost) node in this subtree
    pub fn maximum(self: *TreeNode) *TreeNode {
        var node = self;
        while (node.right) |right| {
            node = right;
        }
        return node;
    }

    /// Get the in-order successor of this node
    pub fn successor(self: *TreeNode) ?*TreeNode {
        // If right subtree exists, find its minimum
        if (self.right) |right| {
            return right.minimum();
        }

        // Otherwise, go up until we find a node that is a left child
        var node = self;
        var p = self.parent;
        while (p) |parent| {
            if (node != parent.right) {
                return parent;
            }
            node = parent;
            p = parent.parent;
        }
        return null;
    }

    /// Get the in-order predecessor of this node
    pub fn predecessor(self: *TreeNode) ?*TreeNode {
        // If left subtree exists, find its maximum
        if (self.left) |left| {
            return left.maximum();
        }

        // Otherwise, go up until we find a node that is a right child
        var node = self;
        var p = self.parent;
        while (p) |parent| {
            if (node != parent.left) {
                return parent;
            }
            node = parent;
            p = parent.parent;
        }
        return null;
    }

    /// Check if this node is a left child
    pub fn isLeftChild(self: *TreeNode) bool {
        if (self.parent) |parent| {
            return parent.left == self;
        }
        return false;
    }

    /// Check if this node is a right child
    pub fn isRightChild(self: *TreeNode) bool {
        if (self.parent) |parent| {
            return parent.right == self;
        }
        return false;
    }

    /// Get sibling node
    pub fn sibling(self: *TreeNode) ?*TreeNode {
        if (self.parent) |parent| {
            if (self.isLeftChild()) {
                return parent.right;
            } else {
                return parent.left;
            }
        }
        return null;
    }

    /// Get uncle node (parent's sibling)
    pub fn uncle(self: *TreeNode) ?*TreeNode {
        if (self.parent) |parent| {
            return parent.sibling();
        }
        return null;
    }

    /// Get grandparent node
    pub fn grandparent(self: *TreeNode) ?*TreeNode {
        if (self.parent) |parent| {
            return parent.parent;
        }
        return null;
    }
};

/// Line and column position
pub const LineCol = struct {
    line: u32,
    col: u32,

    pub fn init(line: u32, col: u32) LineCol {
        return .{ .line = line, .col = col };
    }
};

/// Result of finding a position in the tree
pub const NodePosition = struct {
    /// The node containing the position
    node: *TreeNode,
    /// Offset within the node's piece
    offset_in_piece: u64,
    /// Global offset at the start of this node
    node_start_offset: u64,
};

/// Edit operation for undo/redo
pub const EditOperation = union(enum) {
    insert: struct {
        offset: u64,
        text: []const u8,
    },
    delete: struct {
        offset: u64,
        deleted_text: []const u8,
    },
};

/// Undo entry containing one or more edit operations
pub const UndoEntry = struct {
    operations: std.ArrayListUnmanaged(EditOperation),
    /// Cursor position before the edit
    cursor_before: u64,
    /// Cursor position after the edit
    cursor_after: u64,

    pub fn init(allocator: std.mem.Allocator) UndoEntry {
        _ = allocator;
        return .{
            .operations = .{},
            .cursor_before = 0,
            .cursor_after = 0,
        };
    }

    pub fn deinit(self: *UndoEntry, allocator: std.mem.Allocator) void {
        for (self.operations.items) |op| {
            switch (op) {
                .insert => |ins| allocator.free(ins.text),
                .delete => |del| allocator.free(del.deleted_text),
            }
        }
        self.operations.deinit(allocator);
    }
};

/// Buffer statistics
pub const BufferStats = struct {
    /// Total length in bytes
    total_length: u64,
    /// Total number of lines
    line_count: u32,
    /// Number of pieces in the tree
    piece_count: u32,
    /// Size of the original buffer
    original_size: u64,
    /// Size of the add buffer
    add_buffer_size: u64,
    /// Tree height (for balance verification)
    tree_height: u32,
};

/// Buffer error types
pub const BufferError = error{
    OutOfMemory,
    InvalidOffset,
    InvalidLine,
    InvalidRange,
    EmptyBuffer,
    IoError,
    MmapError,
};

// Tests
test "piece creation" {
    const piece = Piece.init(.original, 0, 100, 5);
    try std.testing.expectEqual(Source.original, piece.source);
    try std.testing.expectEqual(@as(u64, 0), piece.start);
    try std.testing.expectEqual(@as(u64, 100), piece.length);
    try std.testing.expectEqual(@as(u32, 5), piece.line_breaks);
    try std.testing.expect(!piece.isEmpty());
}

test "tree node creation and metadata" {
    const allocator = std.testing.allocator;

    const piece = Piece.init(.add, 10, 50, 2);
    const node = try TreeNode.create(allocator, piece);
    defer node.destroy();

    try std.testing.expectEqual(@as(u64, 50), node.subtree_length);
    try std.testing.expectEqual(@as(u32, 2), node.subtree_line_breaks);
    try std.testing.expectEqual(@as(u64, 0), node.left_subtree_length);
}

test "line col initialization" {
    const lc = LineCol.init(10, 5);
    try std.testing.expectEqual(@as(u32, 10), lc.line);
    try std.testing.expectEqual(@as(u32, 5), lc.col);
}
