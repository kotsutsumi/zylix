//! Buffer C ABI Exports
//!
//! C-compatible API for FFI integration with iOS, Android, and other platforms.

const std = @import("std");
const buffer = @import("buffer.zig");
const types = @import("types.zig");

const TextBuffer = buffer.TextBuffer;
const LineCol = types.LineCol;

/// Opaque handle for text buffer
pub const ZylixBuffer = opaque {};

/// Result status codes
pub const ZylixStatus = enum(i32) {
    ok = 0,
    error_out_of_memory = -1,
    error_invalid_offset = -2,
    error_invalid_line = -3,
    error_invalid_range = -4,
    error_empty_buffer = -5,
    error_io = -6,
    error_invalid_handle = -7,
    error_null_pointer = -8,
};

/// Line/column position for C
pub const ZylixLineCol = extern struct {
    line: u32,
    col: u32,
};

/// Buffer statistics for C
pub const ZylixBufferStats = extern struct {
    total_length: u64,
    line_count: u32,
    piece_count: u32,
    original_size: u64,
    add_buffer_size: u64,
    tree_height: u32,
};

// Global allocator for FFI (using page allocator for thread safety)
var global_allocator: std.mem.Allocator = std.heap.page_allocator;

/// Set custom allocator (must be called before any other functions)
export fn zylix_buffer_set_allocator(alloc_fn: ?*const fn (usize) callconv(.c) ?*anyopaque, free_fn: ?*const fn (?*anyopaque, usize) callconv(.c) void) void {
    // For now, just use page allocator
    // Custom allocator support can be added later
    _ = alloc_fn;
    _ = free_fn;
}

/// Create a new empty buffer
export fn zylix_buffer_create() ?*ZylixBuffer {
    const buf = global_allocator.create(TextBuffer) catch return null;
    buf.* = TextBuffer.init(global_allocator);
    return @ptrCast(buf);
}

/// Create a buffer with initial content
export fn zylix_buffer_create_with_content(content: [*]const u8, len: usize) ?*ZylixBuffer {
    if (len == 0) {
        return zylix_buffer_create();
    }

    const buf = global_allocator.create(TextBuffer) catch return null;
    buf.* = TextBuffer.initWithContent(global_allocator, content[0..len]) catch {
        global_allocator.destroy(buf);
        return null;
    };
    return @ptrCast(buf);
}

/// Create a buffer from file
export fn zylix_buffer_create_from_file(path: [*:0]const u8) ?*ZylixBuffer {
    const path_slice = std.mem.span(path);

    const buf = global_allocator.create(TextBuffer) catch return null;
    buf.* = TextBuffer.initFromFile(global_allocator, path_slice) catch {
        global_allocator.destroy(buf);
        return null;
    };
    return @ptrCast(buf);
}

/// Destroy a buffer
export fn zylix_buffer_destroy(handle: ?*ZylixBuffer) void {
    if (handle) |h| {
        const buf: *TextBuffer = @ptrCast(@alignCast(h));
        buf.deinit();
        global_allocator.destroy(buf);
    }
}

/// Get buffer length
export fn zylix_buffer_length(handle: ?*ZylixBuffer) u64 {
    if (handle) |h| {
        const buf: *const TextBuffer = @ptrCast(@alignCast(h));
        return buf.length();
    }
    return 0;
}

/// Get line count
export fn zylix_buffer_line_count(handle: ?*ZylixBuffer) u32 {
    if (handle) |h| {
        const buf: *const TextBuffer = @ptrCast(@alignCast(h));
        return buf.lineCount();
    }
    return 0;
}

/// Insert text at cursor
export fn zylix_buffer_insert(handle: ?*ZylixBuffer, text: [*]const u8, len: usize) ZylixStatus {
    if (handle == null) return .error_invalid_handle;

    const buf: *TextBuffer = @ptrCast(@alignCast(handle.?));

    if (len == 0) return .ok;

    buf.insert(text[0..len]) catch |err| {
        return mapError(err);
    };
    return .ok;
}

/// Insert text at specific offset
export fn zylix_buffer_insert_at(handle: ?*ZylixBuffer, offset: u64, text: [*]const u8, len: usize) ZylixStatus {
    if (handle == null) return .error_invalid_handle;

    const buf: *TextBuffer = @ptrCast(@alignCast(handle.?));

    if (len == 0) return .ok;

    buf.insertAt(offset, text[0..len]) catch |err| {
        return mapError(err);
    };
    return .ok;
}

/// Delete text backwards from cursor
export fn zylix_buffer_backspace(handle: ?*ZylixBuffer, count: u64) ZylixStatus {
    if (handle == null) return .error_invalid_handle;

    const buf: *TextBuffer = @ptrCast(@alignCast(handle.?));
    buf.backspace(count) catch |err| {
        return mapError(err);
    };
    return .ok;
}

/// Delete text forwards from cursor
export fn zylix_buffer_delete_forward(handle: ?*ZylixBuffer, count: u64) ZylixStatus {
    if (handle == null) return .error_invalid_handle;

    const buf: *TextBuffer = @ptrCast(@alignCast(handle.?));
    buf.deleteForward(count) catch |err| {
        return mapError(err);
    };
    return .ok;
}

/// Delete a range of text
export fn zylix_buffer_delete_range(handle: ?*ZylixBuffer, start: u64, length: u64) ZylixStatus {
    if (handle == null) return .error_invalid_handle;

    const buf: *TextBuffer = @ptrCast(@alignCast(handle.?));
    buf.deleteRange(start, length) catch |err| {
        return mapError(err);
    };
    return .ok;
}

/// Get text in range (caller must free with zylix_buffer_free_text)
export fn zylix_buffer_get_text(handle: ?*ZylixBuffer, start: u64, length: u64, out_len: *usize) ?[*]u8 {
    if (handle == null) {
        out_len.* = 0;
        return null;
    }

    const buf: *TextBuffer = @ptrCast(@alignCast(handle.?));
    const text = buf.getText(start, length) catch {
        out_len.* = 0;
        return null;
    };

    out_len.* = text.len;
    return @constCast(text.ptr);
}

/// Get a specific line (caller must free with zylix_buffer_free_text)
export fn zylix_buffer_get_line(handle: ?*ZylixBuffer, line: u32, out_len: *usize) ?[*]u8 {
    if (handle == null) {
        out_len.* = 0;
        return null;
    }

    const buf: *TextBuffer = @ptrCast(@alignCast(handle.?));
    const text = buf.getLine(line) catch {
        out_len.* = 0;
        return null;
    };

    out_len.* = text.len;
    return @constCast(text.ptr);
}

/// Free text returned by get functions
export fn zylix_buffer_free_text(text: ?[*]u8, len: usize) void {
    if (text) |t| {
        if (len > 0) {
            global_allocator.free(t[0..len]);
        }
    }
}

/// Get cursor position
export fn zylix_buffer_get_cursor(handle: ?*ZylixBuffer) u64 {
    if (handle) |h| {
        const buf: *const TextBuffer = @ptrCast(@alignCast(h));
        return buf.getCursor();
    }
    return 0;
}

/// Set cursor position
export fn zylix_buffer_set_cursor(handle: ?*ZylixBuffer, offset: u64) void {
    if (handle) |h| {
        const buf: *TextBuffer = @ptrCast(@alignCast(h));
        buf.setCursor(offset);
    }
}

/// Move cursor by delta
export fn zylix_buffer_move_cursor(handle: ?*ZylixBuffer, delta: i64) void {
    if (handle) |h| {
        const buf: *TextBuffer = @ptrCast(@alignCast(h));
        buf.moveCursor(delta);
    }
}

/// Get cursor as line/column
export fn zylix_buffer_get_cursor_line_col(handle: ?*ZylixBuffer) ZylixLineCol {
    if (handle) |h| {
        const buf: *TextBuffer = @ptrCast(@alignCast(h));
        const lc = buf.getCursorLineCol();
        return .{ .line = lc.line, .col = lc.col };
    }
    return .{ .line = 0, .col = 0 };
}

/// Set cursor by line/column
export fn zylix_buffer_set_cursor_line_col(handle: ?*ZylixBuffer, line: u32, col: u32) ZylixStatus {
    if (handle == null) return .error_invalid_handle;

    const buf: *TextBuffer = @ptrCast(@alignCast(handle.?));
    buf.setCursorLineCol(LineCol.init(line, col)) catch |err| {
        return mapError(err);
    };
    return .ok;
}

/// Convert offset to line/column
export fn zylix_buffer_offset_to_line_col(handle: ?*ZylixBuffer, offset: u64) ZylixLineCol {
    if (handle) |h| {
        const buf: *TextBuffer = @ptrCast(@alignCast(h));
        const lc = buf.offsetToLineCol(offset);
        return .{ .line = lc.line, .col = lc.col };
    }
    return .{ .line = 0, .col = 0 };
}

/// Convert line/column to offset
export fn zylix_buffer_line_col_to_offset(handle: ?*ZylixBuffer, line: u32, col: u32, out_offset: *u64) ZylixStatus {
    if (handle == null) return .error_invalid_handle;

    const buf: *TextBuffer = @ptrCast(@alignCast(handle.?));
    out_offset.* = buf.lineColToOffset(LineCol.init(line, col)) catch |err| {
        return mapError(err);
    };
    return .ok;
}

/// Undo last operation
export fn zylix_buffer_undo(handle: ?*ZylixBuffer) ZylixStatus {
    if (handle == null) return .error_invalid_handle;

    const buf: *TextBuffer = @ptrCast(@alignCast(handle.?));
    _ = buf.undoOp() catch |err| {
        return mapError(err);
    };
    return .ok;
}

/// Redo last undone operation
export fn zylix_buffer_redo(handle: ?*ZylixBuffer) ZylixStatus {
    if (handle == null) return .error_invalid_handle;

    const buf: *TextBuffer = @ptrCast(@alignCast(handle.?));
    _ = buf.redoOp() catch |err| {
        return mapError(err);
    };
    return .ok;
}

/// Check if undo is available
export fn zylix_buffer_can_undo(handle: ?*ZylixBuffer) bool {
    if (handle) |h| {
        const buf: *const TextBuffer = @ptrCast(@alignCast(h));
        return buf.canUndo();
    }
    return false;
}

/// Check if redo is available
export fn zylix_buffer_can_redo(handle: ?*ZylixBuffer) bool {
    if (handle) |h| {
        const buf: *const TextBuffer = @ptrCast(@alignCast(h));
        return buf.canRedo();
    }
    return false;
}

/// Check if buffer is modified
export fn zylix_buffer_is_modified(handle: ?*ZylixBuffer) bool {
    if (handle) |h| {
        const buf: *const TextBuffer = @ptrCast(@alignCast(h));
        return buf.isModified();
    }
    return false;
}

/// Mark buffer as unmodified
export fn zylix_buffer_mark_unmodified(handle: ?*ZylixBuffer) void {
    if (handle) |h| {
        const buf: *TextBuffer = @ptrCast(@alignCast(h));
        buf.markUnmodified();
    }
}

/// Save buffer to file
export fn zylix_buffer_save(handle: ?*ZylixBuffer) ZylixStatus {
    if (handle == null) return .error_invalid_handle;

    const buf: *TextBuffer = @ptrCast(@alignCast(handle.?));
    buf.save() catch |err| {
        return mapError(err);
    };
    return .ok;
}

/// Save buffer to specific file
export fn zylix_buffer_save_as(handle: ?*ZylixBuffer, path: [*:0]const u8) ZylixStatus {
    if (handle == null) return .error_invalid_handle;

    const path_slice = std.mem.span(path);
    const buf: *TextBuffer = @ptrCast(@alignCast(handle.?));
    buf.saveAs(path_slice) catch |err| {
        return mapError(err);
    };
    return .ok;
}

/// Get buffer statistics
export fn zylix_buffer_get_stats(handle: ?*ZylixBuffer) ZylixBufferStats {
    if (handle) |h| {
        const buf: *const TextBuffer = @ptrCast(@alignCast(h));
        const stats = buf.getStats();
        return .{
            .total_length = stats.total_length,
            .line_count = stats.line_count,
            .piece_count = stats.piece_count,
            .original_size = stats.original_size,
            .add_buffer_size = stats.add_buffer_size,
            .tree_height = stats.tree_height,
        };
    }
    return std.mem.zeroes(ZylixBufferStats);
}

/// Clear undo/redo history
export fn zylix_buffer_clear_history(handle: ?*ZylixBuffer) void {
    if (handle) |h| {
        const buf: *TextBuffer = @ptrCast(@alignCast(h));
        buf.clearHistory();
    }
}

/// Map internal errors to status codes
fn mapError(err: anyerror) ZylixStatus {
    return switch (err) {
        error.OutOfMemory => .error_out_of_memory,
        error.InvalidOffset => .error_invalid_offset,
        error.InvalidLine => .error_invalid_line,
        error.InvalidRange => .error_invalid_range,
        error.EmptyBuffer => .error_empty_buffer,
        error.IoError, error.MmapError => .error_io,
        else => .error_io,
    };
}

// Tests
test "abi create and destroy" {
    const handle = zylix_buffer_create();
    try std.testing.expect(handle != null);
    zylix_buffer_destroy(handle);
}

test "abi insert and get" {
    const handle = zylix_buffer_create().?;
    defer zylix_buffer_destroy(handle);

    const text = "Hello, World!";
    const status = zylix_buffer_insert(handle, text.ptr, text.len);
    try std.testing.expectEqual(ZylixStatus.ok, status);

    try std.testing.expectEqual(@as(u64, 13), zylix_buffer_length(handle));

    var len: usize = 0;
    const result = zylix_buffer_get_text(handle, 0, 13, &len);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(usize, 13), len);

    try std.testing.expectEqualStrings("Hello, World!", result.?[0..len]);
    zylix_buffer_free_text(result, len);
}

test "abi cursor operations" {
    const handle = zylix_buffer_create_with_content("Hello\nWorld", 11).?;
    defer zylix_buffer_destroy(handle);

    try std.testing.expectEqual(@as(u64, 0), zylix_buffer_get_cursor(handle));

    zylix_buffer_set_cursor(handle, 6);
    try std.testing.expectEqual(@as(u64, 6), zylix_buffer_get_cursor(handle));

    const lc = zylix_buffer_get_cursor_line_col(handle);
    try std.testing.expectEqual(@as(u32, 1), lc.line);
    try std.testing.expectEqual(@as(u32, 0), lc.col);
}

test "abi undo redo" {
    const handle = zylix_buffer_create().?;
    defer zylix_buffer_destroy(handle);

    _ = zylix_buffer_insert(handle, "Hello", 5);
    try std.testing.expect(zylix_buffer_can_undo(handle));

    _ = zylix_buffer_undo(handle);
    try std.testing.expectEqual(@as(u64, 0), zylix_buffer_length(handle));

    try std.testing.expect(zylix_buffer_can_redo(handle));
    _ = zylix_buffer_redo(handle);
    try std.testing.expectEqual(@as(u64, 5), zylix_buffer_length(handle));
}
