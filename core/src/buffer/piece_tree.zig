//! Piece Tree Implementation
//!
//! Core piece tree data structure for efficient text editing.
//! Uses a red-black tree to store pieces with O(log n) operations.

const std = @import("std");
const types = @import("types.zig");
const red_black = @import("red_black.zig");

const Piece = types.Piece;
const TreeNode = types.TreeNode;
const Source = types.Source;
const NodePosition = types.NodePosition;
const LineCol = types.LineCol;
const BufferError = types.BufferError;
const RedBlackTree = red_black.RedBlackTree;

/// Piece Tree for efficient text editing
pub const PieceTree = struct {
    allocator: std.mem.Allocator,
    tree: RedBlackTree,

    /// Original text content (read-only)
    original: []const u8,
    /// Whether we own the original buffer
    owns_original: bool,

    /// Add buffer for edits (append-only)
    add_buffer: std.ArrayListUnmanaged(u8),

    /// Line break positions in original buffer (for fast line lookups)
    original_line_breaks: std.ArrayListUnmanaged(u64),
    /// Line break positions in add buffer
    add_line_breaks: std.ArrayListUnmanaged(u64),

    /// Initialize an empty piece tree
    pub fn init(allocator: std.mem.Allocator) PieceTree {
        return .{
            .allocator = allocator,
            .tree = RedBlackTree.init(allocator),
            .original = "",
            .owns_original = false,
            .add_buffer = .{},
            .original_line_breaks = .{},
            .add_line_breaks = .{},
        };
    }

    /// Initialize with original content
    pub fn initWithContent(allocator: std.mem.Allocator, content: []const u8) !PieceTree {
        var pt = init(allocator);
        errdefer pt.deinit();

        // Store original content
        pt.original = content;
        pt.owns_original = false;

        // Build line break index for original
        try pt.buildLineBreakIndex(content, &pt.original_line_breaks);

        // Create initial piece for the content
        if (content.len > 0) {
            const line_breaks = countLineBreaks(content);
            const piece = Piece.init(.original, 0, content.len, line_breaks);
            _ = try pt.tree.insertInitial(piece);
        }

        return pt;
    }

    /// Initialize with owned content (takes ownership)
    pub fn initWithOwnedContent(allocator: std.mem.Allocator, content: []const u8) !PieceTree {
        var pt = try initWithContent(allocator, content);
        pt.owns_original = true;
        return pt;
    }

    /// Deinitialize the piece tree
    pub fn deinit(self: *PieceTree) void {
        self.tree.deinit();
        self.add_buffer.deinit(self.allocator);
        self.original_line_breaks.deinit(self.allocator);
        self.add_line_breaks.deinit(self.allocator);

        if (self.owns_original and self.original.len > 0) {
            self.allocator.free(self.original);
        }
    }

    /// Get total length of text
    pub fn length(self: *const PieceTree) u64 {
        if (self.tree.root) |root| {
            return root.subtree_length;
        }
        return 0;
    }

    /// Get total line count (number of newlines + 1)
    pub fn lineCount(self: *const PieceTree) u32 {
        if (self.tree.root) |root| {
            return root.subtree_line_breaks + 1;
        }
        return 1; // Empty buffer has 1 line
    }

    /// Insert text at the given offset
    pub fn insert(self: *PieceTree, offset: u64, text: []const u8) !void {
        if (text.len == 0) return;

        // Append text to add buffer
        const add_start = self.add_buffer.items.len;
        try self.add_buffer.appendSlice(self.allocator, text);

        // Track line breaks in the added text
        const add_offset: u64 = @intCast(add_start);
        for (text, 0..) |c, i| {
            if (c == '\n') {
                try self.add_line_breaks.append(self.allocator, add_offset + i);
            }
        }

        // Create new piece
        const line_breaks = countLineBreaks(text);
        const new_piece = Piece.init(.add, add_start, text.len, line_breaks);

        // Handle empty tree
        if (self.tree.root == null) {
            _ = try self.tree.insertInitial(new_piece);
            return;
        }

        // Find insertion point
        const total_len = self.length();
        if (offset > total_len) {
            return BufferError.InvalidOffset;
        }

        if (offset == total_len) {
            // Insert at end - after the last node
            const last_node = if (self.tree.root) |root| root.maximum() else null;
            _ = try self.tree.insertAt(new_piece, last_node);
        } else if (offset == 0) {
            // Insert at beginning - before all nodes (after_node = null inserts at start)
            _ = try self.tree.insertAt(new_piece, null);
        } else {
            // Insert in middle - may need to split a piece
            const pos = try self.tree.findByOffset(offset);

            if (pos.offset_in_piece == 0) {
                // Insert at piece boundary - before this node (after predecessor)
                const prev_node = pos.node.predecessor();
                _ = try self.tree.insertAt(new_piece, prev_node);
            } else {
                // Split the piece
                try self.splitAndInsert(pos, new_piece);
            }
        }
    }

    /// Split a piece and insert new content
    fn splitAndInsert(self: *PieceTree, pos: NodePosition, new_piece: Piece) !void {
        const node = pos.node;
        const split_offset = pos.offset_in_piece;

        // Get content for the piece being split
        const piece_content = self.getPieceContent(node.piece);

        // Calculate line breaks for each part
        const first_part = piece_content[0..split_offset];
        const second_part = piece_content[split_offset..];

        const first_lines = countLineBreaks(first_part);
        const second_lines = countLineBreaks(second_part);

        // Create pieces for split parts
        const first_piece = Piece.init(
            node.piece.source,
            node.piece.start,
            split_offset,
            first_lines,
        );

        const second_piece = Piece.init(
            node.piece.source,
            node.piece.start + split_offset,
            node.piece.length - split_offset,
            second_lines,
        );

        // Update the original node to be the first part
        node.piece = first_piece;
        node.updateMetadata();
        self.tree.updateMetadataToRoot(node);

        // Insert the new piece after the first part (which is now `node`)
        const new_node = try self.tree.insertAt(new_piece, node);

        // Insert the second part after the new piece
        _ = try self.tree.insertAt(second_piece, new_node);
    }

    /// Delete text in the given range
    pub fn delete(self: *PieceTree, start_offset: u64, delete_length: u64) !void {
        if (delete_length == 0) return;

        const total_len = self.length();
        if (start_offset >= total_len) {
            return BufferError.InvalidOffset;
        }

        const end_offset = @min(start_offset + delete_length, total_len);
        const actual_length = end_offset - start_offset;

        // Find start and end positions
        const start_pos = try self.tree.findByOffset(start_offset);

        // Check if deletion is within a single piece
        if (start_pos.offset_in_piece + actual_length <= start_pos.node.piece.length) {
            // Deletion within single piece
            try self.deleteWithinPiece(start_pos, actual_length);
        } else {
            // Deletion spans multiple pieces
            try self.deleteAcrossPieces(start_offset, end_offset);
        }
    }

    /// Delete within a single piece
    fn deleteWithinPiece(self: *PieceTree, pos: NodePosition, delete_length: u64) !void {
        const node = pos.node;
        const piece = node.piece;
        const offset = pos.offset_in_piece;

        if (offset == 0 and delete_length == piece.length) {
            // Delete entire piece
            self.tree.remove(node);
        } else if (offset == 0) {
            // Delete from start of piece
            const content = self.getPieceContent(piece);
            const remaining = content[delete_length..];
            const new_lines = countLineBreaks(remaining);

            node.piece = Piece.init(
                piece.source,
                piece.start + delete_length,
                piece.length - delete_length,
                new_lines,
            );
            node.updateMetadata();
            self.tree.updateMetadataToRoot(node);
        } else if (offset + delete_length == piece.length) {
            // Delete from end of piece
            const content = self.getPieceContent(piece);
            const remaining = content[0..offset];
            const new_lines = countLineBreaks(remaining);

            node.piece = Piece.init(
                piece.source,
                piece.start,
                offset,
                new_lines,
            );
            node.updateMetadata();
            self.tree.updateMetadataToRoot(node);
        } else {
            // Delete from middle - need to split
            const content = self.getPieceContent(piece);
            const first_part = content[0..offset];
            const second_part = content[offset + delete_length ..];

            const first_lines = countLineBreaks(first_part);
            const second_lines = countLineBreaks(second_part);

            // Update node to be first part
            node.piece = Piece.init(
                piece.source,
                piece.start,
                offset,
                first_lines,
            );
            node.updateMetadata();
            self.tree.updateMetadataToRoot(node);

            // Insert second part after the first part (node)
            const second_piece = Piece.init(
                piece.source,
                piece.start + offset + delete_length,
                piece.length - offset - delete_length,
                second_lines,
            );

            _ = try self.tree.insertAt(second_piece, node);
        }
    }

    /// Delete across multiple pieces
    fn deleteAcrossPieces(self: *PieceTree, start_offset: u64, end_offset: u64) !void {
        // Collect nodes to modify/remove
        var nodes_to_remove: std.ArrayListUnmanaged(*TreeNode) = .{};
        defer nodes_to_remove.deinit(self.allocator);

        var it = self.tree.iterator();
        var current_offset: u64 = 0;

        while (it.next()) |node| {
            const node_end = current_offset + node.piece.length;

            if (node_end <= start_offset) {
                // Before deletion range
                current_offset = node_end;
                continue;
            }

            if (current_offset >= end_offset) {
                // After deletion range
                break;
            }

            // Node overlaps with deletion range
            if (current_offset >= start_offset and node_end <= end_offset) {
                // Entirely within deletion range
                try nodes_to_remove.append(self.allocator, node);
            } else if (current_offset < start_offset and node_end > end_offset) {
                // Deletion is entirely within this node
                const piece = node.piece;
                const content = self.getPieceContent(piece);

                const local_start = start_offset - current_offset;
                const local_end = end_offset - current_offset;

                const first_part = content[0..local_start];
                const second_part = content[local_end..];

                const first_lines = countLineBreaks(first_part);
                const second_lines = countLineBreaks(second_part);

                // Update to first part
                node.piece = Piece.init(piece.source, piece.start, local_start, first_lines);
                node.updateMetadata();
                self.tree.updateMetadataToRoot(node);

                // Insert second part after the first part (node)
                const second_piece = Piece.init(
                    piece.source,
                    piece.start + local_end,
                    piece.length - local_end,
                    second_lines,
                );
                _ = try self.tree.insertAt(second_piece, node);

                return;
            } else if (current_offset < start_offset) {
                // Partial overlap at start
                const local_start = start_offset - current_offset;
                const content = self.getPieceContent(node.piece);
                const remaining = content[0..local_start];
                const new_lines = countLineBreaks(remaining);

                node.piece = Piece.init(
                    node.piece.source,
                    node.piece.start,
                    local_start,
                    new_lines,
                );
                node.updateMetadata();
                self.tree.updateMetadataToRoot(node);
            } else if (node_end > end_offset) {
                // Partial overlap at end
                const local_end = end_offset - current_offset;
                const content = self.getPieceContent(node.piece);
                const remaining = content[local_end..];
                const new_lines = countLineBreaks(remaining);

                node.piece = Piece.init(
                    node.piece.source,
                    node.piece.start + local_end,
                    node.piece.length - local_end,
                    new_lines,
                );
                node.updateMetadata();
                self.tree.updateMetadataToRoot(node);
            }

            current_offset = node_end;
        }

        // Remove collected nodes
        for (nodes_to_remove.items) |node| {
            self.tree.remove(node);
        }
    }

    /// Get text content in the given range
    pub fn getText(self: *PieceTree, start: u64, len: u64) ![]const u8 {
        const total_len = self.length();
        if (start >= total_len) {
            return "";
        }

        const actual_len = @min(len, total_len - start);
        if (actual_len == 0) {
            return "";
        }

        var result = try self.allocator.alloc(u8, actual_len);
        errdefer self.allocator.free(result);

        var written: usize = 0;
        var it = self.tree.iterator();
        var current_offset: u64 = 0;

        while (it.next()) |node| {
            const node_end = current_offset + node.piece.length;

            if (node_end <= start) {
                current_offset = node_end;
                continue;
            }

            if (current_offset >= start + actual_len) {
                break;
            }

            const content = self.getPieceContent(node.piece);

            // Calculate overlap
            const read_start = if (current_offset < start) start - current_offset else 0;
            const remaining_to_read = actual_len - written;
            const available = node.piece.length - read_start;
            const read_len = @min(remaining_to_read, available);

            @memcpy(result[written..][0..read_len], content[read_start..][0..read_len]);
            written += read_len;

            if (written >= actual_len) break;

            current_offset = node_end;
        }

        return result;
    }

    /// Get all text content
    pub fn getAllText(self: *PieceTree) ![]const u8 {
        return self.getText(0, self.length());
    }

    /// Get a specific line (0-indexed)
    pub fn getLine(self: *PieceTree, line_num: u32) ![]const u8 {
        if (line_num >= self.lineCount()) {
            return BufferError.InvalidLine;
        }

        // Find line start offset
        const line_start = self.getLineStartOffset(line_num);
        const line_end = self.getLineEndOffset(line_num);

        return self.getText(line_start, line_end - line_start);
    }

    /// Get the starting offset of a line
    fn getLineStartOffset(self: *PieceTree, line_num: u32) u64 {
        if (line_num == 0) return 0;

        var lines_found: u32 = 0;
        var it = self.tree.iterator();
        var current_offset: u64 = 0;

        while (it.next()) |node| {
            if (lines_found + node.piece.line_breaks >= line_num) {
                // The target line starts in this piece
                const content = self.getPieceContent(node.piece);
                var local_lines: u32 = 0;

                for (content, 0..) |c, i| {
                    if (c == '\n') {
                        local_lines += 1;
                        if (lines_found + local_lines == line_num) {
                            return current_offset + i + 1;
                        }
                    }
                }
            }

            lines_found += node.piece.line_breaks;
            current_offset += node.piece.length;
        }

        return current_offset;
    }

    /// Get the ending offset of a line (before newline or at end)
    fn getLineEndOffset(self: *PieceTree, line_num: u32) u64 {
        var lines_found: u32 = 0;
        var it = self.tree.iterator();
        var current_offset: u64 = 0;

        while (it.next()) |node| {
            if (lines_found + node.piece.line_breaks > line_num) {
                // The line ends in this piece
                const content = self.getPieceContent(node.piece);
                var local_lines: u32 = 0;

                for (content, 0..) |c, i| {
                    if (lines_found + local_lines == line_num and c == '\n') {
                        return current_offset + i;
                    }
                    if (c == '\n') {
                        local_lines += 1;
                    }
                }
            }

            lines_found += node.piece.line_breaks;
            current_offset += node.piece.length;
        }

        // Line extends to end of buffer
        return self.length();
    }

    /// Convert offset to line/column
    pub fn offsetToLineCol(self: *PieceTree, offset: u64) LineCol {
        var line: u32 = 0;
        var col: u32 = 0;
        var it = self.tree.iterator();
        var current_offset: u64 = 0;

        while (it.next()) |node| {
            const node_end = current_offset + node.piece.length;

            if (node_end <= offset) {
                // Before target offset
                line += node.piece.line_breaks;
                current_offset = node_end;

                // Calculate column if no line breaks
                if (node.piece.line_breaks == 0) {
                    col += @intCast(node.piece.length);
                } else {
                    // Find position after last line break
                    const content = self.getPieceContent(node.piece);
                    var last_newline: ?usize = null;
                    for (content, 0..) |c, i| {
                        if (c == '\n') {
                            last_newline = i;
                        }
                    }
                    if (last_newline) |pos| {
                        col = @intCast(content.len - pos - 1);
                    }
                }
                continue;
            }

            // Target is in this piece
            const content = self.getPieceContent(node.piece);
            const local_offset = offset - current_offset;

            for (content[0..local_offset]) |c| {
                if (c == '\n') {
                    line += 1;
                    col = 0;
                } else {
                    col += 1;
                }
            }

            return LineCol.init(line, col);
        }

        return LineCol.init(line, col);
    }

    /// Convert line/column to offset
    pub fn lineColToOffset(self: *PieceTree, lc: LineCol) !u64 {
        if (lc.line >= self.lineCount()) {
            return BufferError.InvalidLine;
        }

        const line_start = self.getLineStartOffset(lc.line);
        const line_end = self.getLineEndOffset(lc.line);
        const line_len = line_end - line_start;

        if (lc.col > line_len) {
            return BufferError.InvalidOffset;
        }

        return line_start + lc.col;
    }

    /// Get content for a piece
    fn getPieceContent(self: *const PieceTree, piece: Piece) []const u8 {
        return switch (piece.source) {
            .original => self.original[piece.start..][0..piece.length],
            .add => self.add_buffer.items[piece.start..][0..piece.length],
        };
    }

    /// Build line break index for content
    fn buildLineBreakIndex(self: *PieceTree, content: []const u8, index: *std.ArrayListUnmanaged(u64)) !void {
        for (content, 0..) |c, i| {
            if (c == '\n') {
                try index.append(self.allocator, @intCast(i));
            }
        }
    }

    /// Count line breaks in content
    fn countLineBreaks(content: []const u8) u32 {
        var count: u32 = 0;
        for (content) |c| {
            if (c == '\n') count += 1;
        }
        return count;
    }

    /// Get piece count for statistics
    pub fn pieceCount(self: *const PieceTree) u32 {
        return self.tree.node_count;
    }
};

// Tests
test "empty piece tree" {
    const allocator = std.testing.allocator;

    var pt = PieceTree.init(allocator);
    defer pt.deinit();

    try std.testing.expectEqual(@as(u64, 0), pt.length());
    try std.testing.expectEqual(@as(u32, 1), pt.lineCount());
}

test "piece tree with initial content" {
    const allocator = std.testing.allocator;

    var pt = try PieceTree.initWithContent(allocator, "Hello, World!");
    defer pt.deinit();

    try std.testing.expectEqual(@as(u64, 13), pt.length());
    try std.testing.expectEqual(@as(u32, 1), pt.lineCount());
}

test "insert at end" {
    const allocator = std.testing.allocator;

    var pt = try PieceTree.initWithContent(allocator, "Hello");
    defer pt.deinit();

    try pt.insert(5, ", World!");

    const text = try pt.getAllText();
    defer allocator.free(text);

    try std.testing.expectEqualStrings("Hello, World!", text);
}

test "insert at beginning" {
    const allocator = std.testing.allocator;

    var pt = try PieceTree.initWithContent(allocator, "World!");
    defer pt.deinit();

    try pt.insert(0, "Hello, ");

    const text = try pt.getAllText();
    defer allocator.free(text);

    try std.testing.expectEqualStrings("Hello, World!", text);
}

test "insert in middle" {
    const allocator = std.testing.allocator;

    var pt = try PieceTree.initWithContent(allocator, "Hello!");
    defer pt.deinit();

    try pt.insert(5, ", World");

    const text = try pt.getAllText();
    defer allocator.free(text);

    try std.testing.expectEqualStrings("Hello, World!", text);
}

test "delete from beginning" {
    const allocator = std.testing.allocator;

    var pt = try PieceTree.initWithContent(allocator, "Hello, World!");
    defer pt.deinit();

    try pt.delete(0, 7);

    const text = try pt.getAllText();
    defer allocator.free(text);

    try std.testing.expectEqualStrings("World!", text);
}

test "delete from end" {
    const allocator = std.testing.allocator;

    var pt = try PieceTree.initWithContent(allocator, "Hello, World!");
    defer pt.deinit();

    try pt.delete(5, 8);

    const text = try pt.getAllText();
    defer allocator.free(text);

    try std.testing.expectEqualStrings("Hello", text);
}

test "delete from middle" {
    const allocator = std.testing.allocator;

    var pt = try PieceTree.initWithContent(allocator, "Hello, World!");
    defer pt.deinit();

    try pt.delete(5, 2);

    const text = try pt.getAllText();
    defer allocator.free(text);

    try std.testing.expectEqualStrings("HelloWorld!", text);
}

test "line operations" {
    const allocator = std.testing.allocator;

    var pt = try PieceTree.initWithContent(allocator, "Line 1\nLine 2\nLine 3");
    defer pt.deinit();

    try std.testing.expectEqual(@as(u32, 3), pt.lineCount());

    const line0 = try pt.getLine(0);
    defer allocator.free(line0);
    try std.testing.expectEqualStrings("Line 1", line0);

    const line1 = try pt.getLine(1);
    defer allocator.free(line1);
    try std.testing.expectEqualStrings("Line 2", line1);

    const line2 = try pt.getLine(2);
    defer allocator.free(line2);
    try std.testing.expectEqualStrings("Line 3", line2);
}

test "offset to line/col" {
    const allocator = std.testing.allocator;

    var pt = try PieceTree.initWithContent(allocator, "AB\nCD\nEF");
    defer pt.deinit();

    // Position 0 = A (line 0, col 0)
    var lc = pt.offsetToLineCol(0);
    try std.testing.expectEqual(@as(u32, 0), lc.line);
    try std.testing.expectEqual(@as(u32, 0), lc.col);

    // Position 3 = C (line 1, col 0)
    lc = pt.offsetToLineCol(3);
    try std.testing.expectEqual(@as(u32, 1), lc.line);
    try std.testing.expectEqual(@as(u32, 0), lc.col);

    // Position 4 = D (line 1, col 1)
    lc = pt.offsetToLineCol(4);
    try std.testing.expectEqual(@as(u32, 1), lc.line);
    try std.testing.expectEqual(@as(u32, 1), lc.col);
}

test "line/col to offset" {
    const allocator = std.testing.allocator;

    var pt = try PieceTree.initWithContent(allocator, "AB\nCD\nEF");
    defer pt.deinit();

    try std.testing.expectEqual(@as(u64, 0), try pt.lineColToOffset(LineCol.init(0, 0)));
    try std.testing.expectEqual(@as(u64, 1), try pt.lineColToOffset(LineCol.init(0, 1)));
    try std.testing.expectEqual(@as(u64, 3), try pt.lineColToOffset(LineCol.init(1, 0)));
    try std.testing.expectEqual(@as(u64, 6), try pt.lineColToOffset(LineCol.init(2, 0)));
}

test "multiple edits" {
    const allocator = std.testing.allocator;

    var pt = PieceTree.init(allocator);
    defer pt.deinit();

    try pt.insert(0, "Hello");
    try pt.insert(5, " World");
    try pt.insert(11, "!");

    const text = try pt.getAllText();
    defer allocator.free(text);

    try std.testing.expectEqualStrings("Hello World!", text);

    // Now delete some
    try pt.delete(5, 1); // Delete space

    const text2 = try pt.getAllText();
    defer allocator.free(text2);

    try std.testing.expectEqualStrings("HelloWorld!", text2);
}
