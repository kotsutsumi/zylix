//! Inline-Level Markdown Parsing
//!
//! Handles parsing of inline elements like emphasis, links, code spans,
//! and custom extensions within block-level content.

const std = @import("std");
const types = @import("types.zig");
const lexer = @import("lexer.zig");

const Node = types.Node;
const NodeType = types.NodeType;
const NodeData = types.NodeData;
const ParserOptions = types.ParserOptions;
const Scanner = lexer.Scanner;

/// Delimiter types for emphasis parsing
const DelimiterType = enum {
    asterisk,
    underscore,
    tilde,
    caret,
    equal,
};

/// Delimiter run for emphasis parsing
const DelimiterRun = struct {
    char: u8,
    count: usize,
    can_open: bool,
    can_close: bool,
    position: usize,
    node: *Node,
};

/// Inline parser
pub const InlineParser = struct {
    allocator: std.mem.Allocator,
    options: ParserOptions,
    scanner: Scanner,
    delimiters: std.ArrayListUnmanaged(DelimiterRun),
    bracket_stack: std.ArrayListUnmanaged(BracketEntry),
    owned_content: ?[]const u8,

    const BracketEntry = struct {
        position: usize,
        node: *Node,
        is_image: bool,
        active: bool,
    };

    pub fn init(allocator: std.mem.Allocator, source: []const u8, options: ParserOptions) InlineParser {
        return .{
            .allocator = allocator,
            .options = options,
            .scanner = Scanner.init(source),
            .delimiters = .{},
            .bracket_stack = .{},
            .owned_content = null,
        };
    }

    /// Initialize with owned content that will be freed on deinit
    pub fn initOwned(allocator: std.mem.Allocator, owned_source: []const u8, options: ParserOptions) InlineParser {
        return .{
            .allocator = allocator,
            .options = options,
            .scanner = Scanner.init(owned_source),
            .delimiters = .{},
            .bracket_stack = .{},
            .owned_content = owned_source,
        };
    }

    pub fn deinit(self: *InlineParser) void {
        self.delimiters.deinit(self.allocator);
        self.bracket_stack.deinit(self.allocator);
        if (self.owned_content) |content| {
            self.allocator.free(content);
        }
    }

    /// Parse inline content and add children to parent node
    pub fn parseInlines(self: *InlineParser, parent: *Node) !void {
        while (!self.scanner.isEof()) {
            const c = self.scanner.peek() orelse break;

            switch (c) {
                '\\' => try self.parseBackslash(parent),
                '`' => try self.parseCodeSpan(parent),
                '*', '_' => try self.parseEmphasisDelimiter(parent, c),
                '[' => try self.parseLinkStart(parent, false),
                '!' => {
                    if (self.scanner.peekAt(1) == @as(u8, '[')) {
                        _ = self.scanner.advance();
                        try self.parseLinkStart(parent, true);
                    } else {
                        try self.addText(parent, "!");
                        _ = self.scanner.advance();
                    }
                },
                ']' => try self.parseLinkEnd(parent),
                '<' => try self.parseAutolink(parent),
                '~' => {
                    if (self.options.gfm) {
                        try self.parseStrikethrough(parent);
                    } else {
                        try self.addText(parent, "~");
                        _ = self.scanner.advance();
                    }
                },
                '$' => {
                    if (self.options.math) {
                        try self.parseMath(parent);
                    } else {
                        try self.addText(parent, "$");
                        _ = self.scanner.advance();
                    }
                },
                '=' => {
                    if (self.options.highlight) {
                        try self.parseHighlight(parent);
                    } else {
                        try self.addText(parent, "=");
                        _ = self.scanner.advance();
                    }
                },
                '^' => {
                    if (self.options.super_subscript) {
                        try self.parseSuperscript(parent);
                    } else {
                        try self.addText(parent, "^");
                        _ = self.scanner.advance();
                    }
                },
                ':' => {
                    if (self.options.emoji) {
                        try self.parseEmoji(parent);
                    } else {
                        try self.addText(parent, ":");
                        _ = self.scanner.advance();
                    }
                },
                '\n' => try self.parseNewline(parent),
                else => try self.parseText(parent),
            }
        }

        // Process remaining delimiters
        try self.processEmphasis(parent);
    }

    /// Parse backslash escape
    fn parseBackslash(self: *InlineParser, parent: *Node) !void {
        _ = self.scanner.advance(); // consume backslash

        if (self.scanner.peek()) |next| {
            if (lexer.isPunctuation(next)) {
                // Escaped punctuation
                try self.addText(parent, self.scanner.source[self.scanner.pos..][0..1]);
                _ = self.scanner.advance();
            } else if (next == '\n' and self.options.backslash_breaks) {
                // Hard break
                const br = try Node.create(self.allocator, .hard_break, .{ .hard_break = {} });
                parent.appendChild(br);
                _ = self.scanner.advance();
            } else {
                // Literal backslash
                try self.addText(parent, "\\");
            }
        } else {
            try self.addText(parent, "\\");
        }
    }

    /// Parse code span (`code`)
    fn parseCodeSpan(self: *InlineParser, parent: *Node) !void {
        const start_pos = self.scanner.pos;

        // Count opening backticks
        var open_count: usize = 0;
        while (self.scanner.peek() == @as(u8, '`')) {
            open_count += 1;
            _ = self.scanner.advance();
        }

        // Find matching closing backticks
        const content_start = self.scanner.pos;
        var content_end = content_start;
        var found_close = false;

        while (!self.scanner.isEof()) {
            if (self.scanner.peek() == @as(u8, '`')) {
                const close_start = self.scanner.pos;
                var close_count: usize = 0;
                while (self.scanner.peek() == @as(u8, '`')) {
                    close_count += 1;
                    _ = self.scanner.advance();
                }

                if (close_count == open_count) {
                    content_end = close_start;
                    found_close = true;
                    break;
                }
            } else {
                content_end = self.scanner.pos + 1;
                _ = self.scanner.advance();
            }
        }

        if (found_close) {
            var content = self.scanner.source[content_start..content_end];

            // Strip one leading/trailing space if present
            if (content.len >= 2 and content[0] == ' ' and content[content.len - 1] == ' ') {
                content = content[1 .. content.len - 1];
            }

            // Normalize line endings to spaces
            var normalized: std.ArrayListUnmanaged(u8) = .{};
            defer normalized.deinit(self.allocator);

            for (content) |c| {
                if (c == '\n' or c == '\r') {
                    try normalized.append(self.allocator, ' ');
                } else {
                    try normalized.append(self.allocator, c);
                }
            }

            const code = try Node.create(self.allocator, .code_span, .{
                .code_span = .{ .content = try self.allocator.dupe(u8, normalized.items) },
            });
            parent.appendChild(code);
        } else {
            // No matching close, treat as literal text
            try self.addText(parent, self.scanner.source[start_pos..self.scanner.pos]);
        }
    }

    /// Parse emphasis delimiter (* or _)
    fn parseEmphasisDelimiter(self: *InlineParser, parent: *Node, char: u8) !void {
        const run_start = self.scanner.pos;

        // Count delimiter characters
        var count: usize = 0;
        while (self.scanner.peek() == char) {
            count += 1;
            _ = self.scanner.advance();
        }

        // Determine if can open/close based on surrounding characters
        const before = if (run_start > 0) self.scanner.source[run_start - 1] else ' ';
        const after = self.scanner.peek() orelse ' ';

        const before_is_space = lexer.isWhitespace(before);
        const after_is_space = lexer.isWhitespace(after);
        const before_is_punct = lexer.isPunctuation(before);
        const after_is_punct = lexer.isPunctuation(after);

        // Left-flanking: not followed by whitespace, and either:
        // - not followed by punctuation, or
        // - preceded by whitespace or punctuation
        const left_flanking = !after_is_space and (!after_is_punct or before_is_space or before_is_punct);

        // Right-flanking: not preceded by whitespace, and either:
        // - not preceded by punctuation, or
        // - followed by whitespace or punctuation
        const right_flanking = !before_is_space and (!before_is_punct or after_is_space or after_is_punct);

        var can_open: bool = undefined;
        var can_close: bool = undefined;

        if (char == '*') {
            can_open = left_flanking;
            can_close = right_flanking;
        } else {
            // _ has additional restrictions
            can_open = left_flanking and (!right_flanking or before_is_punct);
            can_close = right_flanking and (!left_flanking or after_is_punct);
        }

        // Create text node for the delimiter
        const delim_text = self.scanner.source[run_start..self.scanner.pos];
        const text_node = try Node.create(self.allocator, .text, .{
            .text = .{ .content = try self.allocator.dupe(u8, delim_text) },
        });
        parent.appendChild(text_node);

        // Add to delimiter stack
        try self.delimiters.append(self.allocator, .{
            .char = char,
            .count = count,
            .can_open = can_open,
            .can_close = can_close,
            .position = run_start,
            .node = text_node,
        });
    }

    /// Process emphasis delimiters
    fn processEmphasis(self: *InlineParser, parent: *Node) !void {
        _ = parent;

        // Find matching opener for each closer
        var closer_idx = self.delimiters.items.len;
        while (closer_idx > 0) {
            closer_idx -= 1;
            const closer = &self.delimiters.items[closer_idx];

            if (!closer.can_close or closer.count == 0) continue;

            // Look for matching opener
            var opener_idx = closer_idx;
            while (opener_idx > 0) {
                opener_idx -= 1;
                const opener = &self.delimiters.items[opener_idx];

                if (!opener.can_open or opener.char != closer.char or opener.count == 0) {
                    continue;
                }

                // Found match - determine emphasis type
                const use_delims = @min(@min(opener.count, closer.count), 2);

                if (use_delims == 0) continue;

                // Create emphasis node
                const emphasis_type: NodeType = if (use_delims == 2) .strong else .emphasis;
                const emphasis = try Node.create(self.allocator, emphasis_type, switch (emphasis_type) {
                    .strong => .{ .strong = {} },
                    .emphasis => .{ .emphasis = {} },
                    else => unreachable,
                });

                // Move nodes between opener and closer into emphasis
                var node = opener.node.next;
                while (node != null and node != closer.node) {
                    const next = node.?.next;
                    node.?.unlink();
                    emphasis.appendChild(node.?);
                    node = next;
                }

                // Insert emphasis after opener
                emphasis.parent = opener.node.parent;
                emphasis.prev = opener.node;
                emphasis.next = closer.node;
                opener.node.next = emphasis;
                closer.node.prev = emphasis;

                // Update delimiter counts
                opener.count -= use_delims;
                closer.count -= use_delims;

                // Update text content
                if (opener.count == 0) {
                    opener.node.unlink();
                    self.allocator.destroy(opener.node);
                }
                if (closer.count == 0) {
                    closer.node.unlink();
                    self.allocator.destroy(closer.node);
                }

                break;
            }
        }
    }

    /// Parse link/image start [
    fn parseLinkStart(self: *InlineParser, parent: *Node, is_image: bool) !void {
        _ = self.scanner.advance(); // consume [

        const text_node = try Node.create(self.allocator, .text, .{
            .text = .{ .content = try self.allocator.dupe(u8, if (is_image) "![" else "[") },
        });
        parent.appendChild(text_node);

        try self.bracket_stack.append(self.allocator, .{
            .position = self.scanner.pos,
            .node = text_node,
            .is_image = is_image,
            .active = true,
        });
    }

    /// Parse link end ]
    fn parseLinkEnd(self: *InlineParser, parent: *Node) !void {
        _ = self.scanner.advance(); // consume ]

        // Find matching opener
        var opener: ?*BracketEntry = null;
        var opener_idx: usize = self.bracket_stack.items.len;
        while (opener_idx > 0) {
            opener_idx -= 1;
            if (self.bracket_stack.items[opener_idx].active) {
                opener = &self.bracket_stack.items[opener_idx];
                break;
            }
        }

        if (opener == null) {
            try self.addText(parent, "]");
            return;
        }

        const bracket = opener.?;

        // Check for inline link: [text](url "title")
        if (self.scanner.peek() == @as(u8, '(')) {
            _ = self.scanner.advance();
            _ = self.scanner.skipSpaces();

            // Parse URL
            const url = try self.parseUrl();
            _ = self.scanner.skipSpaces();

            // Parse optional title
            var title: ?[]const u8 = null;
            const title_char = self.scanner.peek();
            if (title_char == @as(u8, '"') or title_char == @as(u8, '\'') or title_char == @as(u8, '(')) {
                title = try self.parseTitle();
                _ = self.scanner.skipSpaces();
            }

            if (self.scanner.peek() == @as(u8, ')')) {
                _ = self.scanner.advance();

                // Dupe url and title for ownership
                const duped_url = try self.allocator.dupe(u8, url);
                const duped_title: ?[]const u8 = if (title) |t| try self.allocator.dupe(u8, t) else null;

                // Create link or image
                const node_type: NodeType = if (bracket.is_image) .image else .link;
                const link = try Node.create(self.allocator, node_type, switch (node_type) {
                    .link => .{ .link = .{ .url = duped_url, .title = duped_title } },
                    .image => .{ .image = .{ .url = duped_url, .title = duped_title, .alt = null } },
                    else => unreachable,
                });

                // Move content between bracket and ] into link
                var node = bracket.node.next;
                while (node != null) {
                    const next = node.?.next;
                    if (node.?.node_type == .text) {
                        const text_data = node.?.data.text;
                        if (text_data.content.len == 1 and text_data.content[0] == ']') {
                            break;
                        }
                    }
                    node.?.unlink();
                    link.appendChild(node.?);
                    node = next;
                }

                // Replace bracket text with link
                bracket.node.unlink();
                bracket.node.deinit(); // Free the "[" or "![" text node
                parent.appendChild(link);

                // Deactivate brackets
                for (self.bracket_stack.items[opener_idx..]) |*b| {
                    b.active = false;
                }

                return;
            }
        }

        // No valid link syntax, treat as text
        bracket.active = false;
        try self.addText(parent, "]");
    }

    fn parseUrl(self: *InlineParser) ![]const u8 {
        const start = self.scanner.pos;

        // Handle angle-bracketed URL
        if (self.scanner.peek() == @as(u8, '<')) {
            _ = self.scanner.advance();
            while (self.scanner.peek()) |c| {
                if (c == '>') {
                    const url = self.scanner.source[start + 1 .. self.scanner.pos];
                    _ = self.scanner.advance();
                    return url;
                }
                if (c == '\n' or c == '<') break;
                _ = self.scanner.advance();
            }
            return self.scanner.source[start..self.scanner.pos];
        }

        // Regular URL
        var paren_depth: i32 = 0;
        while (self.scanner.peek()) |c| {
            if (lexer.isWhitespace(c)) break;
            if (c == '(') paren_depth += 1;
            if (c == ')') {
                if (paren_depth == 0) break;
                paren_depth -= 1;
            }
            _ = self.scanner.advance();
        }

        return self.scanner.source[start..self.scanner.pos];
    }

    fn parseTitle(self: *InlineParser) !?[]const u8 {
        const quote = self.scanner.advance() orelse return null;
        const close_char: u8 = if (quote == '(') ')' else quote;

        const start = self.scanner.pos;
        while (self.scanner.peek()) |c| {
            if (c == close_char) {
                const title = self.scanner.source[start..self.scanner.pos];
                _ = self.scanner.advance();
                return title;
            }
            if (c == '\\' and self.scanner.peekAt(1) != null) {
                _ = self.scanner.advance();
            }
            _ = self.scanner.advance();
        }

        return null;
    }

    /// Parse autolink <url> or <email>
    fn parseAutolink(self: *InlineParser, parent: *Node) !void {
        const start = self.scanner.pos;
        _ = self.scanner.advance(); // consume <

        const content_start = self.scanner.pos;

        // Find >
        while (self.scanner.peek()) |c| {
            if (c == '>') {
                const content = self.scanner.source[content_start..self.scanner.pos];
                _ = self.scanner.advance();

                // Check if it's a URL or email
                const is_email = std.mem.indexOf(u8, content, "@") != null and
                    std.mem.indexOf(u8, content, ":") == null;

                const autolink = try Node.create(self.allocator, .autolink, .{
                    .autolink = .{
                        .url = if (is_email)
                            try std.fmt.allocPrint(self.allocator, "mailto:{s}", .{content})
                        else
                            try self.allocator.dupe(u8, content),
                        .is_email = is_email,
                    },
                });
                parent.appendChild(autolink);
                return;
            }
            if (c == ' ' or c == '\n' or c == '<') break;
            _ = self.scanner.advance();
        }

        // Not a valid autolink, treat as text
        self.scanner.pos = start + 1;
        try self.addText(parent, "<");
    }

    /// Parse strikethrough ~~text~~
    fn parseStrikethrough(self: *InlineParser, parent: *Node) !void {
        if (self.scanner.peekAt(1) != @as(u8, '~')) {
            try self.addText(parent, "~");
            _ = self.scanner.advance();
            return;
        }

        _ = self.scanner.advance();
        _ = self.scanner.advance();

        const start = self.scanner.pos;

        // Find closing ~~
        while (!self.scanner.isEof()) {
            if (self.scanner.peek() == @as(u8, '~') and self.scanner.peekAt(1) == @as(u8, '~')) {
                const content = self.scanner.source[start..self.scanner.pos];
                _ = self.scanner.advance();
                _ = self.scanner.advance();

                const strike = try Node.create(self.allocator, .strikethrough, .{ .strikethrough = {} });
                const text = try Node.create(self.allocator, .text, .{ .text = .{ .content = try self.allocator.dupe(u8, content) } });
                strike.appendChild(text);
                parent.appendChild(strike);
                return;
            }
            _ = self.scanner.advance();
        }

        // No closing, treat as text
        try self.addText(parent, "~~");
        try self.addText(parent, self.scanner.source[start..]);
    }

    /// Parse math ($inline$ or $$block$$)
    fn parseMath(self: *InlineParser, parent: *Node) !void {
        const is_block = self.scanner.peekAt(1) == @as(u8, '$');

        if (is_block) {
            _ = self.scanner.advance();
            _ = self.scanner.advance();

            const start = self.scanner.pos;

            // Find closing $$
            while (!self.scanner.isEof()) {
                if (self.scanner.peek() == @as(u8, '$') and self.scanner.peekAt(1) == @as(u8, '$')) {
                    const content = self.scanner.source[start..self.scanner.pos];
                    _ = self.scanner.advance();
                    _ = self.scanner.advance();

                    const math = try Node.create(self.allocator, .math_block, .{
                        .math_block = .{ .content = try self.allocator.dupe(u8, content) },
                    });
                    parent.appendChild(math);
                    return;
                }
                _ = self.scanner.advance();
            }

            try self.addText(parent, "$$");
            try self.addText(parent, self.scanner.source[start..]);
        } else {
            _ = self.scanner.advance();

            const start = self.scanner.pos;

            // Find closing $
            while (!self.scanner.isEof()) {
                if (self.scanner.peek() == @as(u8, '$')) {
                    const content = self.scanner.source[start..self.scanner.pos];
                    _ = self.scanner.advance();

                    const math = try Node.create(self.allocator, .math_inline, .{
                        .math_inline = .{ .content = try self.allocator.dupe(u8, content) },
                    });
                    parent.appendChild(math);
                    return;
                }
                if (self.scanner.peek() == @as(u8, '\n')) break;
                _ = self.scanner.advance();
            }

            try self.addText(parent, "$");
            try self.addText(parent, self.scanner.source[start..self.scanner.pos]);
        }
    }

    /// Parse highlight ==text==
    fn parseHighlight(self: *InlineParser, parent: *Node) !void {
        if (self.scanner.peekAt(1) != @as(u8, '=')) {
            try self.addText(parent, "=");
            _ = self.scanner.advance();
            return;
        }

        _ = self.scanner.advance();
        _ = self.scanner.advance();

        const start = self.scanner.pos;

        while (!self.scanner.isEof()) {
            if (self.scanner.peek() == @as(u8, '=') and self.scanner.peekAt(1) == @as(u8, '=')) {
                const content = self.scanner.source[start..self.scanner.pos];
                _ = self.scanner.advance();
                _ = self.scanner.advance();

                const highlight = try Node.create(self.allocator, .highlight, .{ .highlight = {} });
                const text = try Node.create(self.allocator, .text, .{ .text = .{ .content = try self.allocator.dupe(u8, content) } });
                highlight.appendChild(text);
                parent.appendChild(highlight);
                return;
            }
            _ = self.scanner.advance();
        }

        try self.addText(parent, "==");
        try self.addText(parent, self.scanner.source[start..]);
    }

    /// Parse superscript ^text^
    fn parseSuperscript(self: *InlineParser, parent: *Node) !void {
        _ = self.scanner.advance();

        const start = self.scanner.pos;

        while (!self.scanner.isEof()) {
            const c = self.scanner.peek() orelse break;
            if (c == '^') {
                const content = self.scanner.source[start..self.scanner.pos];
                _ = self.scanner.advance();

                const sup = try Node.create(self.allocator, .superscript, .{ .superscript = {} });
                const text = try Node.create(self.allocator, .text, .{ .text = .{ .content = try self.allocator.dupe(u8, content) } });
                sup.appendChild(text);
                parent.appendChild(sup);
                return;
            }
            if (lexer.isWhitespace(c)) break;
            _ = self.scanner.advance();
        }

        try self.addText(parent, "^");
        try self.addText(parent, self.scanner.source[start..self.scanner.pos]);
    }

    /// Parse emoji :shortcode:
    fn parseEmoji(self: *InlineParser, parent: *Node) !void {
        const start = self.scanner.pos;
        _ = self.scanner.advance();

        const code_start = self.scanner.pos;

        while (!self.scanner.isEof()) {
            const c = self.scanner.peek() orelse break;
            if (c == ':') {
                const shortcode = self.scanner.source[code_start..self.scanner.pos];
                _ = self.scanner.advance();

                if (shortcode.len > 0) {
                    const emoji = try Node.create(self.allocator, .emoji, .{
                        .emoji = .{
                            .shortcode = shortcode,
                            .unicode = null, // TODO: emoji lookup
                        },
                    });
                    parent.appendChild(emoji);
                    return;
                }
            }
            if (!std.ascii.isAlphanumeric(c) and c != '_' and c != '+' and c != '-') break;
            _ = self.scanner.advance();
        }

        // Not valid emoji, reset and add as text
        self.scanner.pos = start + 1;
        try self.addText(parent, ":");
    }

    /// Parse newline
    fn parseNewline(self: *InlineParser, parent: *Node) !void {
        // Check for hard break (two spaces before newline)
        // This is handled at a higher level, so just create soft break
        _ = self.scanner.advance();
        const br = try Node.create(self.allocator, .soft_break, .{ .soft_break = {} });
        parent.appendChild(br);
    }

    /// Parse regular text
    fn parseText(self: *InlineParser, parent: *Node) !void {
        const start = self.scanner.pos;

        while (self.scanner.peek()) |c| {
            if (lexer.isDelimiterChar(c) or c == '\n' or c == '\\' or c == '<') {
                break;
            }
            _ = self.scanner.advance();
        }

        if (self.scanner.pos > start) {
            try self.addText(parent, self.scanner.source[start..self.scanner.pos]);
        }
    }

    /// Add text node (merging with previous if possible)
    fn addText(self: *InlineParser, parent: *Node, content: []const u8) !void {
        if (content.len == 0) return;

        // Try to merge with previous text node
        if (parent.last_child) |last| {
            if (last.node_type == .text) {
                // Can't easily merge due to immutable slices, create new node
            }
        }

        const text = try Node.create(self.allocator, .text, .{
            .text = .{ .content = try self.allocator.dupe(u8, content) },
        });
        parent.appendChild(text);
    }
};

// Tests
test "parse code span" {
    const allocator = std.testing.allocator;

    const doc = try Node.create(allocator, .document, .{ .document = {} });
    defer doc.deinit();

    var parser = InlineParser.init(allocator, "`code here`", .{});
    defer parser.deinit();

    try parser.parseInlines(doc);

    try std.testing.expectEqual(@as(usize, 1), doc.childCount());
    try std.testing.expectEqual(NodeType.code_span, doc.first_child.?.node_type);
}

test "parse link" {
    const allocator = std.testing.allocator;

    const doc = try Node.create(allocator, .document, .{ .document = {} });
    defer doc.deinit();

    var parser = InlineParser.init(allocator, "[text](https://example.com)", .{});
    defer parser.deinit();

    try parser.parseInlines(doc);

    const link = doc.first_child.?;
    try std.testing.expectEqual(NodeType.link, link.node_type);
    try std.testing.expectEqualStrings("https://example.com", link.data.link.url);
}

test "parse strikethrough" {
    const allocator = std.testing.allocator;

    const doc = try Node.create(allocator, .document, .{ .document = {} });
    defer doc.deinit();

    var parser = InlineParser.init(allocator, "~~deleted~~", .{ .gfm = true });
    defer parser.deinit();

    try parser.parseInlines(doc);

    try std.testing.expectEqual(NodeType.strikethrough, doc.first_child.?.node_type);
}

test "parse math inline" {
    const allocator = std.testing.allocator;

    const doc = try Node.create(allocator, .document, .{ .document = {} });
    defer doc.deinit();

    var parser = InlineParser.init(allocator, "$E = mc^2$", .{ .math = true });
    defer parser.deinit();

    try parser.parseInlines(doc);

    const math = doc.first_child.?;
    try std.testing.expectEqual(NodeType.math_inline, math.node_type);
    try std.testing.expectEqualStrings("E = mc^2", math.data.math_inline.content);
}
