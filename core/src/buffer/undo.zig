//! Undo/Redo Stack
//!
//! Manages edit history for the text buffer with support for
//! grouping operations and cursor position tracking.

const std = @import("std");
const types = @import("types.zig");
const piece_tree = @import("piece_tree.zig");

const EditOperation = types.EditOperation;
const UndoEntry = types.UndoEntry;
const PieceTree = piece_tree.PieceTree;

/// Undo/Redo manager
pub const UndoStack = struct {
    allocator: std.mem.Allocator,

    /// Stack of undo entries
    undo_stack: std.ArrayListUnmanaged(UndoEntry),
    /// Stack of redo entries
    redo_stack: std.ArrayListUnmanaged(UndoEntry),

    /// Maximum number of undo entries
    max_entries: u32 = 1000,

    /// Current group being built (for grouping multiple ops)
    current_group: ?*UndoEntry = null,

    pub fn init(allocator: std.mem.Allocator) UndoStack {
        return .{
            .allocator = allocator,
            .undo_stack = .{},
            .redo_stack = .{},
        };
    }

    pub fn deinit(self: *UndoStack) void {
        self.clearStack(&self.undo_stack);
        self.clearStack(&self.redo_stack);
        self.undo_stack.deinit(self.allocator);
        self.redo_stack.deinit(self.allocator);
    }

    fn clearStack(self: *UndoStack, stack: *std.ArrayListUnmanaged(UndoEntry)) void {
        for (stack.items) |*entry| {
            entry.deinit(self.allocator);
        }
        stack.clearRetainingCapacity();
    }

    /// Record an insert operation
    pub fn recordInsert(self: *UndoStack, offset: u64, text: []const u8, cursor_before: u64, cursor_after: u64) !void {
        // Clear redo stack on new edit
        self.clearStack(&self.redo_stack);

        // Duplicate the text for storage
        const text_copy = try self.allocator.dupe(u8, text);

        const op = EditOperation{ .insert = .{
            .offset = offset,
            .text = text_copy,
        } };

        if (self.current_group) |group| {
            try group.operations.append(self.allocator, op);
            group.cursor_after = cursor_after;
        } else {
            var entry = UndoEntry.init(self.allocator);
            entry.cursor_before = cursor_before;
            entry.cursor_after = cursor_after;
            try entry.operations.append(self.allocator, op);
            try self.pushEntry(entry);
        }
    }

    /// Record a delete operation
    pub fn recordDelete(self: *UndoStack, offset: u64, deleted_text: []const u8, cursor_before: u64, cursor_after: u64) !void {
        // Clear redo stack on new edit
        self.clearStack(&self.redo_stack);

        // Duplicate the text for storage
        const text_copy = try self.allocator.dupe(u8, deleted_text);

        const op = EditOperation{ .delete = .{
            .offset = offset,
            .deleted_text = text_copy,
        } };

        if (self.current_group) |group| {
            try group.operations.append(self.allocator, op);
            group.cursor_after = cursor_after;
        } else {
            var entry = UndoEntry.init(self.allocator);
            entry.cursor_before = cursor_before;
            entry.cursor_after = cursor_after;
            try entry.operations.append(self.allocator, op);
            try self.pushEntry(entry);
        }
    }

    /// Begin a group of operations (for composite edits)
    pub fn beginGroup(self: *UndoStack, cursor_before: u64) !void {
        if (self.current_group != null) {
            // Nested groups not supported, auto-end previous
            try self.endGroup();
        }

        const group = try self.allocator.create(UndoEntry);
        group.* = UndoEntry.init(self.allocator);
        group.cursor_before = cursor_before;
        self.current_group = group;
    }

    /// End the current group
    pub fn endGroup(self: *UndoStack) !void {
        if (self.current_group) |group| {
            if (group.operations.items.len > 0) {
                try self.pushEntry(group.*);
            } else {
                // Empty group, just clean up
                group.deinit(self.allocator);
            }
            self.allocator.destroy(group);
            self.current_group = null;
        }
    }

    /// Push an entry to the undo stack
    fn pushEntry(self: *UndoStack, entry: UndoEntry) !void {
        // Enforce max entries
        while (self.undo_stack.items.len >= self.max_entries) {
            var old_entry = self.undo_stack.orderedRemove(0);
            old_entry.deinit(self.allocator);
        }

        try self.undo_stack.append(self.allocator, entry);
    }

    /// Undo the last operation
    pub fn undo(self: *UndoStack, tree: *PieceTree) !?u64 {
        if (self.undo_stack.items.len == 0) return null;

        const entry = self.undo_stack.pop() orelse return null;

        // Apply operations in reverse order
        var i = entry.operations.items.len;
        while (i > 0) {
            i -= 1;
            const op = entry.operations.items[i];
            switch (op) {
                .insert => |ins| {
                    // Undo insert = delete
                    try tree.delete(ins.offset, ins.text.len);
                },
                .delete => |del| {
                    // Undo delete = insert
                    try tree.insert(del.offset, del.deleted_text);
                },
            }
        }

        // Move to redo stack
        try self.redo_stack.append(self.allocator, entry);

        return entry.cursor_before;
    }

    /// Redo the last undone operation
    pub fn redo(self: *UndoStack, tree: *PieceTree) !?u64 {
        if (self.redo_stack.items.len == 0) return null;

        const entry = self.redo_stack.pop() orelse return null;

        // Apply operations in forward order
        for (entry.operations.items) |op| {
            switch (op) {
                .insert => |ins| {
                    try tree.insert(ins.offset, ins.text);
                },
                .delete => |del| {
                    try tree.delete(del.offset, del.deleted_text.len);
                },
            }
        }

        // Move to undo stack
        try self.undo_stack.append(self.allocator, entry);

        return entry.cursor_after;
    }

    /// Check if undo is available
    pub fn canUndo(self: *const UndoStack) bool {
        return self.undo_stack.items.len > 0;
    }

    /// Check if redo is available
    pub fn canRedo(self: *const UndoStack) bool {
        return self.redo_stack.items.len > 0;
    }

    /// Get the number of undo entries
    pub fn undoCount(self: *const UndoStack) usize {
        return self.undo_stack.items.len;
    }

    /// Get the number of redo entries
    pub fn redoCount(self: *const UndoStack) usize {
        return self.redo_stack.items.len;
    }

    /// Clear all history
    pub fn clearHistory(self: *UndoStack) void {
        self.clearStack(&self.undo_stack);
        self.clearStack(&self.redo_stack);
    }
};

// Tests
test "basic undo/redo" {
    const allocator = std.testing.allocator;

    var tree = try PieceTree.initWithContent(allocator, "Hello");
    defer tree.deinit();

    var undo = UndoStack.init(allocator);
    defer undo.deinit();

    // Insert " World"
    try tree.insert(5, " World");
    try undo.recordInsert(5, " World", 5, 11);

    // Verify current state
    const text1 = try tree.getAllText();
    defer allocator.free(text1);
    try std.testing.expectEqualStrings("Hello World", text1);

    // Undo
    _ = try undo.undo(&tree);

    const text2 = try tree.getAllText();
    defer allocator.free(text2);
    try std.testing.expectEqualStrings("Hello", text2);

    // Redo
    _ = try undo.redo(&tree);

    const text3 = try tree.getAllText();
    defer allocator.free(text3);
    try std.testing.expectEqualStrings("Hello World", text3);
}

test "undo delete" {
    const allocator = std.testing.allocator;

    var tree = try PieceTree.initWithContent(allocator, "Hello World");
    defer tree.deinit();

    var undo = UndoStack.init(allocator);
    defer undo.deinit();

    // Get text before delete for recording
    const deleted = try tree.getText(5, 6);
    defer allocator.free(deleted);

    // Delete " World"
    try tree.delete(5, 6);
    try undo.recordDelete(5, deleted, 5, 5);

    // Verify delete worked
    const text1 = try tree.getAllText();
    defer allocator.free(text1);
    try std.testing.expectEqualStrings("Hello", text1);

    // Undo the delete
    _ = try undo.undo(&tree);

    const text2 = try tree.getAllText();
    defer allocator.free(text2);
    try std.testing.expectEqualStrings("Hello World", text2);
}

test "grouped operations" {
    const allocator = std.testing.allocator;

    var tree = try PieceTree.initWithContent(allocator, "AB");
    defer tree.deinit();

    var undo = UndoStack.init(allocator);
    defer undo.deinit();

    // Group: delete A, insert X
    try undo.beginGroup(0);

    // Get text before delete
    const deleted = try tree.getText(0, 1);
    defer allocator.free(deleted);

    try tree.delete(0, 1);
    try undo.recordDelete(0, deleted, 0, 0);

    try tree.insert(0, "X");
    try undo.recordInsert(0, "X", 0, 1);

    try undo.endGroup();

    // Should be one undo entry
    try std.testing.expectEqual(@as(usize, 1), undo.undoCount());

    // Verify current state
    const text1 = try tree.getAllText();
    defer allocator.free(text1);
    try std.testing.expectEqualStrings("XB", text1);

    // Undo entire group
    _ = try undo.undo(&tree);

    const text2 = try tree.getAllText();
    defer allocator.free(text2);
    try std.testing.expectEqualStrings("AB", text2);
}

test "redo cleared on new edit" {
    const allocator = std.testing.allocator;

    var tree = try PieceTree.initWithContent(allocator, "Hello");
    defer tree.deinit();

    var undo = UndoStack.init(allocator);
    defer undo.deinit();

    // Insert and record
    try tree.insert(5, " World");
    try undo.recordInsert(5, " World", 5, 11);

    // Undo
    _ = try undo.undo(&tree);
    try std.testing.expect(undo.canRedo());

    // New edit should clear redo
    try tree.insert(5, "!");
    try undo.recordInsert(5, "!", 5, 6);

    try std.testing.expect(!undo.canRedo());
}
