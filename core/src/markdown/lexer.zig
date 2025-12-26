//! Markdown Lexer/Scanner
//!
//! Provides low-level character scanning and token extraction for the parser.
//! Optimized for UTF-8 text processing with minimal allocations.

const std = @import("std");
const types = @import("types.zig");

/// Character classes for fast classification
pub const CharClass = enum(u8) {
    space, // ' ', '\t'
    newline, // '\n', '\r'
    digit, // '0'-'9'
    alpha, // 'a'-'z', 'A'-'Z'
    punct, // Various punctuation
    special, // Markdown-significant characters
    other, // Everything else
};

/// Special markdown characters
pub const SPECIAL_CHARS = "#*_`[](){}\\!<>|-+.~^=:$@";

/// Line structure for efficient line-based parsing
pub const Line = struct {
    content: []const u8,
    indent: u16 = 0,
    line_num: u32,
    start_offset: u32,
    is_blank: bool = false,
    continuation_indent: u16 = 0,

    pub fn trimmed(self: Line) []const u8 {
        if (self.indent >= self.content.len) return "";
        return self.content[self.indent..];
    }

    pub fn isEmpty(self: Line) bool {
        for (self.content) |c| {
            if (c != ' ' and c != '\t') return false;
        }
        return true;
    }
};

/// Scanner state
pub const Scanner = struct {
    source: []const u8,
    pos: usize = 0,
    line: u32 = 1,
    col: u32 = 1,
    line_start: usize = 0,
    tab_size: u8 = 4,

    pub fn init(source: []const u8) Scanner {
        return .{
            .source = source,
        };
    }

    pub fn initWithOptions(source: []const u8, tab_size: u8) Scanner {
        return .{
            .source = source,
            .tab_size = tab_size,
        };
    }

    /// Check if at end of input
    pub fn isEof(self: *const Scanner) bool {
        return self.pos >= self.source.len;
    }

    /// Peek at current character without advancing
    pub fn peek(self: *const Scanner) ?u8 {
        if (self.pos >= self.source.len) return null;
        return self.source[self.pos];
    }

    /// Peek at character at offset from current position
    pub fn peekAt(self: *const Scanner, offset: usize) ?u8 {
        const idx = self.pos + offset;
        if (idx >= self.source.len) return null;
        return self.source[idx];
    }

    /// Peek multiple characters ahead
    pub fn peekSlice(self: *const Scanner, len: usize) ?[]const u8 {
        const end = @min(self.pos + len, self.source.len);
        if (self.pos >= self.source.len) return null;
        return self.source[self.pos..end];
    }

    /// Advance by one character
    pub fn advance(self: *Scanner) ?u8 {
        if (self.pos >= self.source.len) return null;
        const c = self.source[self.pos];
        self.pos += 1;

        if (c == '\n') {
            self.line += 1;
            self.col = 1;
            self.line_start = self.pos;
        } else if (c == '\t') {
            self.col += self.tab_size - ((self.col - 1) % self.tab_size);
        } else {
            self.col += 1;
        }

        return c;
    }

    /// Advance by n characters
    pub fn advanceBy(self: *Scanner, n: usize) void {
        var i: usize = 0;
        while (i < n) : (i += 1) {
            _ = self.advance() orelse break;
        }
    }

    /// Skip whitespace (spaces and tabs)
    pub fn skipSpaces(self: *Scanner) u16 {
        var count: u16 = 0;
        while (self.peek()) |c| {
            if (c == ' ') {
                count += 1;
                _ = self.advance();
            } else if (c == '\t') {
                count += self.tab_size - @as(u16, @intCast((self.col - 1) % self.tab_size));
                _ = self.advance();
            } else {
                break;
            }
        }
        return count;
    }

    /// Skip to end of line (but don't consume newline)
    pub fn skipToEol(self: *Scanner) []const u8 {
        const start = self.pos;
        while (self.peek()) |c| {
            if (c == '\n' or c == '\r') break;
            _ = self.advance();
        }
        return self.source[start..self.pos];
    }

    /// Consume newline (handles \n, \r, \r\n)
    pub fn consumeNewline(self: *Scanner) bool {
        if (self.peek()) |c| {
            if (c == '\r') {
                _ = self.advance();
                if (self.peek() == @as(u8, '\n')) {
                    _ = self.advance();
                }
                return true;
            } else if (c == '\n') {
                _ = self.advance();
                return true;
            }
        }
        return false;
    }

    /// Get remaining source from current position
    pub fn remaining(self: *const Scanner) []const u8 {
        if (self.pos >= self.source.len) return "";
        return self.source[self.pos..];
    }

    /// Get current line content
    pub fn currentLine(self: *const Scanner) []const u8 {
        var end = self.line_start;
        while (end < self.source.len and self.source[end] != '\n' and self.source[end] != '\r') {
            end += 1;
        }
        return self.source[self.line_start..end];
    }

    /// Check if string matches at current position (case-sensitive)
    pub fn matches(self: *const Scanner, pattern: []const u8) bool {
        if (self.pos + pattern.len > self.source.len) return false;
        return std.mem.eql(u8, self.source[self.pos..][0..pattern.len], pattern);
    }

    /// Check if string matches at current position (case-insensitive)
    pub fn matchesIgnoreCase(self: *const Scanner, pattern: []const u8) bool {
        if (self.pos + pattern.len > self.source.len) return false;
        const slice = self.source[self.pos..][0..pattern.len];
        return std.ascii.eqlIgnoreCase(slice, pattern);
    }

    /// Try to consume a specific string
    pub fn consume(self: *Scanner, pattern: []const u8) bool {
        if (self.matches(pattern)) {
            self.advanceBy(pattern.len);
            return true;
        }
        return false;
    }

    /// Count consecutive occurrences of a character
    pub fn countChar(self: *const Scanner, char: u8) usize {
        var count: usize = 0;
        while (self.peekAt(count) == char) {
            count += 1;
        }
        return count;
    }

    /// Get source position info
    pub fn getPos(self: *const Scanner) types.SourcePos {
        return types.SourcePos.init(
            self.line,
            self.col,
            @intCast(self.pos),
        );
    }

    /// Save current position for backtracking
    pub fn saveState(self: *const Scanner) ScannerState {
        return .{
            .pos = self.pos,
            .line = self.line,
            .col = self.col,
            .line_start = self.line_start,
        };
    }

    /// Restore to a saved position
    pub fn restoreState(self: *Scanner, state: ScannerState) void {
        self.pos = state.pos;
        self.line = state.line;
        self.col = state.col;
        self.line_start = state.line_start;
    }

    pub const ScannerState = struct {
        pos: usize,
        line: u32,
        col: u32,
        line_start: usize,
    };
};

/// Line-based scanner for block parsing
pub const LineScanner = struct {
    source: []const u8,
    pos: usize = 0,
    line_num: u32 = 1,
    tab_size: u8 = 4,

    pub fn init(source: []const u8) LineScanner {
        return .{ .source = source };
    }

    pub fn initWithTabSize(source: []const u8, tab_size: u8) LineScanner {
        return .{ .source = source, .tab_size = tab_size };
    }

    pub fn isEof(self: *const LineScanner) bool {
        return self.pos >= self.source.len;
    }

    /// Get next line
    pub fn nextLine(self: *LineScanner) ?Line {
        if (self.pos >= self.source.len) return null;

        const start = self.pos;
        var end = start;

        // Find end of line
        while (end < self.source.len and self.source[end] != '\n' and self.source[end] != '\r') {
            end += 1;
        }

        const content = self.source[start..end];

        // Calculate indent
        var indent: u16 = 0;
        var content_start: usize = 0;
        for (content) |c| {
            if (c == ' ') {
                indent += 1;
                content_start += 1;
            } else if (c == '\t') {
                indent += self.tab_size - (indent % self.tab_size);
                content_start += 1;
            } else {
                break;
            }
        }

        const line = Line{
            .content = content,
            .indent = indent,
            .line_num = self.line_num,
            .start_offset = @intCast(start),
            .is_blank = content_start >= content.len,
        };

        // Skip past newline
        if (end < self.source.len) {
            if (self.source[end] == '\r') {
                end += 1;
                if (end < self.source.len and self.source[end] == '\n') {
                    end += 1;
                }
            } else if (self.source[end] == '\n') {
                end += 1;
            }
        }

        self.pos = end;
        self.line_num += 1;

        return line;
    }

    /// Peek at next line without consuming
    pub fn peekLine(self: *LineScanner) ?Line {
        const saved_pos = self.pos;
        const saved_line = self.line_num;
        defer {
            self.pos = saved_pos;
            self.line_num = saved_line;
        }
        return self.nextLine();
    }

    /// Get all remaining lines as slice
    pub fn remaining(self: *const LineScanner) []const u8 {
        if (self.pos >= self.source.len) return "";
        return self.source[self.pos..];
    }
};

/// Classify a character
pub fn classifyChar(c: u8) CharClass {
    return switch (c) {
        ' ', '\t' => .space,
        '\n', '\r' => .newline,
        '0'...'9' => .digit,
        'a'...'z', 'A'...'Z' => .alpha,
        '#', '*', '_', '`', '[', ']', '(', ')', '{', '}', '\\', '!', '<', '>', '|', '-', '+', '.', '~', '^', '=', ':', '$', '@' => .special,
        ',', ';', '\'', '"', '/', '?', '%', '&' => .punct,
        else => .other,
    };
}

/// Check if character is ASCII punctuation
pub fn isPunctuation(c: u8) bool {
    return switch (c) {
        '!', '"', '#', '$', '%', '&', '\'', '(', ')', '*', '+', ',', '-', '.', '/', ':', ';', '<', '=', '>', '?', '@', '[', '\\', ']', '^', '_', '`', '{', '|', '}', '~' => true,
        else => false,
    };
}

/// Check if character is ASCII whitespace
pub fn isWhitespace(c: u8) bool {
    return c == ' ' or c == '\t' or c == '\n' or c == '\r';
}

/// Check if character is a Unicode whitespace (simplified)
pub fn isUnicodeWhitespace(c: u8) bool {
    // For now, just handle ASCII whitespace
    // TODO: Handle full Unicode whitespace
    return isWhitespace(c);
}

/// Check if character starts a special inline delimiter
pub fn isDelimiterChar(c: u8) bool {
    return switch (c) {
        '*', '_', '~', '`', '^', '=', '[', ']', '!', '$' => true,
        else => false,
    };
}

// Tests
test "scanner basic operations" {
    var scanner = Scanner.init("Hello\nWorld");

    try std.testing.expectEqual(@as(?u8, 'H'), scanner.peek());
    try std.testing.expectEqual(@as(?u8, 'H'), scanner.advance());
    try std.testing.expectEqual(@as(?u8, 'e'), scanner.peek());
    try std.testing.expectEqual(@as(u32, 1), scanner.line);
    try std.testing.expectEqual(@as(u32, 2), scanner.col);
}

test "scanner newline handling" {
    var scanner = Scanner.init("Line1\nLine2");

    while (scanner.peek()) |c| {
        if (c == '\n') break;
        _ = scanner.advance();
    }

    try std.testing.expectEqual(@as(u32, 1), scanner.line);
    _ = scanner.advance(); // consume newline
    try std.testing.expectEqual(@as(u32, 2), scanner.line);
    try std.testing.expectEqual(@as(u32, 1), scanner.col);
}

test "line scanner" {
    var scanner = LineScanner.init("Line 1\nLine 2\n  Indented");

    const line1 = scanner.nextLine().?;
    try std.testing.expectEqualStrings("Line 1", line1.content);
    try std.testing.expectEqual(@as(u16, 0), line1.indent);

    const line2 = scanner.nextLine().?;
    try std.testing.expectEqualStrings("Line 2", line2.content);

    const line3 = scanner.nextLine().?;
    try std.testing.expectEqualStrings("  Indented", line3.content);
    try std.testing.expectEqual(@as(u16, 2), line3.indent);
}

test "character classification" {
    try std.testing.expectEqual(CharClass.space, classifyChar(' '));
    try std.testing.expectEqual(CharClass.newline, classifyChar('\n'));
    try std.testing.expectEqual(CharClass.digit, classifyChar('5'));
    try std.testing.expectEqual(CharClass.alpha, classifyChar('a'));
    try std.testing.expectEqual(CharClass.special, classifyChar('#'));
}
