//! Text Buffer
//!
//! High-level text buffer API combining piece tree, undo/redo,
//! and optional file I/O support.

const std = @import("std");
const types = @import("types.zig");
const piece_tree = @import("piece_tree.zig");
const undo_mod = @import("undo.zig");

const Piece = types.Piece;
const LineCol = types.LineCol;
const BufferStats = types.BufferStats;
const BufferError = types.BufferError;
const PieceTree = piece_tree.PieceTree;
const UndoStack = undo_mod.UndoStack;

/// Text Buffer with full editing support
pub const TextBuffer = struct {
    allocator: std.mem.Allocator,
    tree: PieceTree,
    undo: UndoStack,

    /// Cursor position (offset)
    cursor: u64 = 0,

    /// File path if associated with a file
    file_path: ?[]const u8 = null,
    owns_path: bool = false,

    /// Modification flag
    modified: bool = false,

    /// Create an empty buffer
    pub fn init(allocator: std.mem.Allocator) TextBuffer {
        return .{
            .allocator = allocator,
            .tree = PieceTree.init(allocator),
            .undo = UndoStack.init(allocator),
        };
    }

    /// Create buffer with initial content
    pub fn initWithContent(allocator: std.mem.Allocator, content: []const u8) !TextBuffer {
        return .{
            .allocator = allocator,
            .tree = try PieceTree.initWithContent(allocator, content),
            .undo = UndoStack.init(allocator),
        };
    }

    /// Create buffer from file
    pub fn initFromFile(allocator: std.mem.Allocator, path: []const u8) !TextBuffer {
        const file = std.fs.cwd().openFile(path, .{}) catch |err| {
            return switch (err) {
                error.FileNotFound, error.AccessDenied => BufferError.IoError,
                else => BufferError.IoError,
            };
        };
        defer file.close();

        const content = file.readToEndAlloc(allocator, std.math.maxInt(usize)) catch {
            return BufferError.IoError;
        };

        const path_copy = try allocator.dupe(u8, path);

        return .{
            .allocator = allocator,
            .tree = try PieceTree.initWithOwnedContent(allocator, content),
            .undo = UndoStack.init(allocator),
            .file_path = path_copy,
            .owns_path = true,
        };
    }

    /// Deinitialize the buffer
    pub fn deinit(self: *TextBuffer) void {
        self.tree.deinit();
        self.undo.deinit();
        if (self.owns_path) {
            if (self.file_path) |path| {
                self.allocator.free(path);
            }
        }
    }

    /// Insert text at cursor position
    pub fn insert(self: *TextBuffer, text: []const u8) !void {
        try self.insertAt(self.cursor, text);
    }

    /// Insert text at specific offset
    pub fn insertAt(self: *TextBuffer, offset: u64, text: []const u8) !void {
        const cursor_before = self.cursor;
        try self.tree.insert(offset, text);
        self.cursor = offset + text.len;
        try self.undo.recordInsert(offset, text, cursor_before, self.cursor);
        self.modified = true;
    }

    /// Delete text backwards from cursor (backspace)
    pub fn backspace(self: *TextBuffer, count: u64) !void {
        if (self.cursor == 0 or count == 0) return;

        const delete_count = @min(count, self.cursor);
        const start = self.cursor - delete_count;

        try self.deleteRange(start, delete_count);
        self.cursor = start;
    }

    /// Delete text forwards from cursor (delete key)
    pub fn deleteForward(self: *TextBuffer, count: u64) !void {
        const len = self.tree.length();
        if (self.cursor >= len or count == 0) return;

        const delete_count = @min(count, len - self.cursor);
        try self.deleteRange(self.cursor, delete_count);
    }

    /// Delete a range of text
    pub fn deleteRange(self: *TextBuffer, start: u64, len: u64) !void {
        if (len == 0) return;

        const cursor_before = self.cursor;

        // Get text before deleting for undo
        const deleted_text = try self.tree.getText(start, len);
        defer self.allocator.free(deleted_text);

        try self.tree.delete(start, len);

        // Adjust cursor if needed
        if (self.cursor > start) {
            if (self.cursor >= start + len) {
                self.cursor -= len;
            } else {
                self.cursor = start;
            }
        }

        try self.undo.recordDelete(start, deleted_text, cursor_before, self.cursor);
        self.modified = true;
    }

    /// Replace text in range
    pub fn replace(self: *TextBuffer, start: u64, len: u64, new_text: []const u8) !void {
        try self.undo.beginGroup(self.cursor);

        if (len > 0) {
            // Get text before deleting for undo
            const deleted_text = try self.tree.getText(start, len);
            defer self.allocator.free(deleted_text);

            try self.tree.delete(start, len);
            try self.undo.recordDelete(start, deleted_text, self.cursor, start);
        }

        if (new_text.len > 0) {
            try self.tree.insert(start, new_text);
            try self.undo.recordInsert(start, new_text, start, start + new_text.len);
        }

        self.cursor = start + new_text.len;
        try self.undo.endGroup();
        self.modified = true;
    }

    /// Get text in range
    pub fn getText(self: *TextBuffer, start: u64, len: u64) ![]const u8 {
        return self.tree.getText(start, len);
    }

    /// Get all text
    pub fn getAllText(self: *TextBuffer) ![]const u8 {
        return self.tree.getAllText();
    }

    /// Get a specific line (0-indexed)
    pub fn getLine(self: *TextBuffer, line: u32) ![]const u8 {
        return self.tree.getLine(line);
    }

    /// Get total buffer length
    pub fn length(self: *const TextBuffer) u64 {
        return self.tree.length();
    }

    /// Get total line count
    pub fn lineCount(self: *const TextBuffer) u32 {
        return self.tree.lineCount();
    }

    /// Move cursor to offset
    pub fn setCursor(self: *TextBuffer, offset: u64) void {
        self.cursor = @min(offset, self.tree.length());
    }

    /// Move cursor by delta
    pub fn moveCursor(self: *TextBuffer, delta: i64) void {
        if (delta < 0) {
            const abs_delta: u64 = @intCast(-delta);
            if (abs_delta > self.cursor) {
                self.cursor = 0;
            } else {
                self.cursor -= abs_delta;
            }
        } else {
            const abs_delta: u64 = @intCast(delta);
            self.cursor = @min(self.cursor + abs_delta, self.tree.length());
        }
    }

    /// Get cursor position
    pub fn getCursor(self: *const TextBuffer) u64 {
        return self.cursor;
    }

    /// Get cursor as line/column
    pub fn getCursorLineCol(self: *TextBuffer) LineCol {
        return self.tree.offsetToLineCol(self.cursor);
    }

    /// Set cursor by line/column
    pub fn setCursorLineCol(self: *TextBuffer, lc: LineCol) !void {
        self.cursor = try self.tree.lineColToOffset(lc);
    }

    /// Convert offset to line/column
    pub fn offsetToLineCol(self: *TextBuffer, offset: u64) LineCol {
        return self.tree.offsetToLineCol(offset);
    }

    /// Convert line/column to offset
    pub fn lineColToOffset(self: *TextBuffer, lc: LineCol) !u64 {
        return self.tree.lineColToOffset(lc);
    }

    /// Undo last operation
    pub fn undoOp(self: *TextBuffer) !bool {
        if (try self.undo.undo(&self.tree)) |new_cursor| {
            self.cursor = new_cursor;
            self.modified = true;
            return true;
        }
        return false;
    }

    /// Redo last undone operation
    pub fn redoOp(self: *TextBuffer) !bool {
        if (try self.undo.redo(&self.tree)) |new_cursor| {
            self.cursor = new_cursor;
            self.modified = true;
            return true;
        }
        return false;
    }

    /// Check if undo is available
    pub fn canUndo(self: *const TextBuffer) bool {
        return self.undo.canUndo();
    }

    /// Check if redo is available
    pub fn canRedo(self: *const TextBuffer) bool {
        return self.undo.canRedo();
    }

    /// Save to file
    pub fn save(self: *TextBuffer) !void {
        if (self.file_path) |path| {
            try self.saveAs(path);
        } else {
            return BufferError.IoError;
        }
    }

    /// Save to specific file
    pub fn saveAs(self: *TextBuffer, path: []const u8) !void {
        const content = try self.tree.getAllText();
        defer self.allocator.free(content);

        const file = std.fs.cwd().createFile(path, .{}) catch {
            return BufferError.IoError;
        };
        defer file.close();

        file.writeAll(content) catch {
            return BufferError.IoError;
        };

        // Update path if different
        if (self.file_path == null or !std.mem.eql(u8, self.file_path.?, path)) {
            if (self.owns_path) {
                if (self.file_path) |old_path| {
                    self.allocator.free(old_path);
                }
            }
            self.file_path = try self.allocator.dupe(u8, path);
            self.owns_path = true;
        }

        self.modified = false;
    }

    /// Get buffer statistics
    pub fn getStats(self: *const TextBuffer) BufferStats {
        const tree_height = self.calculateTreeHeight();

        return .{
            .total_length = self.tree.length(),
            .line_count = self.tree.lineCount(),
            .piece_count = self.tree.pieceCount(),
            .original_size = self.tree.original.len,
            .add_buffer_size = self.tree.add_buffer.items.len,
            .tree_height = tree_height,
        };
    }

    fn calculateTreeHeight(self: *const TextBuffer) u32 {
        return self.calculateNodeHeight(self.tree.tree.root);
    }

    fn calculateNodeHeight(self: *const TextBuffer, node: ?*types.TreeNode) u32 {
        _ = self;
        if (node == null) return 0;
        const n = node.?;
        const left_height = if (n.left) |l| calculateNodeHeightStatic(l) else 0;
        const right_height = if (n.right) |r| calculateNodeHeightStatic(r) else 0;
        return 1 + @max(left_height, right_height);
    }

    fn calculateNodeHeightStatic(node: *types.TreeNode) u32 {
        const left_height = if (node.left) |l| calculateNodeHeightStatic(l) else 0;
        const right_height = if (node.right) |r| calculateNodeHeightStatic(r) else 0;
        return 1 + @max(left_height, right_height);
    }

    /// Check if buffer has been modified
    pub fn isModified(self: *const TextBuffer) bool {
        return self.modified;
    }

    /// Mark buffer as unmodified
    pub fn markUnmodified(self: *TextBuffer) void {
        self.modified = false;
    }

    /// Clear undo/redo history
    pub fn clearHistory(self: *TextBuffer) void {
        self.undo.clearHistory();
    }
};

// Tests
test "empty buffer" {
    const allocator = std.testing.allocator;

    var buf = TextBuffer.init(allocator);
    defer buf.deinit();

    try std.testing.expectEqual(@as(u64, 0), buf.length());
    try std.testing.expectEqual(@as(u32, 1), buf.lineCount());
    try std.testing.expect(!buf.isModified());
}

test "insert and delete" {
    const allocator = std.testing.allocator;

    var buf = TextBuffer.init(allocator);
    defer buf.deinit();

    try buf.insert("Hello");
    try std.testing.expectEqual(@as(u64, 5), buf.length());
    try std.testing.expectEqual(@as(u64, 5), buf.getCursor());

    try buf.insert(" World");
    try std.testing.expectEqual(@as(u64, 11), buf.length());

    const text = try buf.getAllText();
    defer allocator.free(text);
    try std.testing.expectEqualStrings("Hello World", text);

    // Backspace
    try buf.backspace(6);
    const text2 = try buf.getAllText();
    defer allocator.free(text2);
    try std.testing.expectEqualStrings("Hello", text2);
}

test "undo and redo" {
    const allocator = std.testing.allocator;

    var buf = TextBuffer.init(allocator);
    defer buf.deinit();

    try buf.insert("Hello");
    try buf.insert(" World");

    // Undo
    try std.testing.expect(try buf.undoOp());
    const text1 = try buf.getAllText();
    defer allocator.free(text1);
    try std.testing.expectEqualStrings("Hello", text1);

    // Redo
    try std.testing.expect(try buf.redoOp());
    const text2 = try buf.getAllText();
    defer allocator.free(text2);
    try std.testing.expectEqualStrings("Hello World", text2);
}

test "cursor movement" {
    const allocator = std.testing.allocator;

    var buf = try TextBuffer.initWithContent(allocator, "Hello\nWorld");
    defer buf.deinit();

    try std.testing.expectEqual(@as(u64, 0), buf.getCursor());

    buf.setCursor(6);
    try std.testing.expectEqual(@as(u64, 6), buf.getCursor());

    const lc = buf.getCursorLineCol();
    try std.testing.expectEqual(@as(u32, 1), lc.line);
    try std.testing.expectEqual(@as(u32, 0), lc.col);

    buf.moveCursor(-3);
    try std.testing.expectEqual(@as(u64, 3), buf.getCursor());

    buf.moveCursor(100); // Should clamp to end
    try std.testing.expectEqual(@as(u64, 11), buf.getCursor());
}

test "replace text" {
    const allocator = std.testing.allocator;

    var buf = try TextBuffer.initWithContent(allocator, "Hello World");
    defer buf.deinit();

    try buf.replace(6, 5, "Zig");

    const text = try buf.getAllText();
    defer allocator.free(text);
    try std.testing.expectEqualStrings("Hello Zig", text);

    // Should be single undo operation
    try std.testing.expect(try buf.undoOp());
    const text2 = try buf.getAllText();
    defer allocator.free(text2);
    try std.testing.expectEqualStrings("Hello World", text2);
}

test "line operations" {
    const allocator = std.testing.allocator;

    var buf = try TextBuffer.initWithContent(allocator, "Line 1\nLine 2\nLine 3");
    defer buf.deinit();

    try std.testing.expectEqual(@as(u32, 3), buf.lineCount());

    const line1 = try buf.getLine(1);
    defer allocator.free(line1);
    try std.testing.expectEqualStrings("Line 2", line1);

    // Set cursor by line/col
    try buf.setCursorLineCol(LineCol.init(1, 2));
    try std.testing.expectEqual(@as(u64, 9), buf.getCursor());
}

test "buffer stats" {
    const allocator = std.testing.allocator;

    var buf = try TextBuffer.initWithContent(allocator, "Hello\nWorld");
    defer buf.deinit();

    const stats = buf.getStats();
    try std.testing.expectEqual(@as(u64, 11), stats.total_length);
    try std.testing.expectEqual(@as(u32, 2), stats.line_count);
    try std.testing.expectEqual(@as(u32, 1), stats.piece_count);
}
