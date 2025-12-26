//! Markdown Parser
//!
//! Main parser that combines block and inline parsing with incremental update support.
//! Implements CommonMark + GFM + custom extensions.

const std = @import("std");
const types = @import("types.zig");
const blocks = @import("blocks.zig");
const inlines = @import("inlines.zig");
const renderer = @import("renderer.zig");

const Node = types.Node;
const NodeType = types.NodeType;
const ParserOptions = types.ParserOptions;
const TextEdit = types.TextEdit;
const MarkdownError = types.MarkdownError;

/// Markdown Parser with incremental update support
pub const MarkdownParser = struct {
    allocator: std.mem.Allocator,
    options: ParserOptions,
    document: ?*Node = null,
    source: []const u8 = "",
    source_version: u64 = 0,

    // Track if we own the source memory (for incremental updates)
    owned_source: ?[]const u8 = null,

    // Block-level parse tree (for incremental updates)
    block_nodes: std.ArrayListUnmanaged(*Node) = .{},

    // Cache for rendered output
    cached_html: ?[]const u8 = null,
    html_version: u64 = 0,

    pub fn init(allocator: std.mem.Allocator, options: ParserOptions) MarkdownParser {
        return .{
            .allocator = allocator,
            .options = options,
        };
    }

    pub fn deinit(self: *MarkdownParser) void {
        if (self.document) |doc| {
            doc.deinit();
        }
        if (self.cached_html) |html| {
            self.allocator.free(html);
        }
        if (self.owned_source) |src| {
            self.allocator.free(src);
        }
        self.block_nodes.deinit(self.allocator);
    }

    /// Parse markdown content into AST
    pub fn parse(self: *MarkdownParser, content: []const u8) !*Node {
        // Clean up previous parse
        if (self.document) |doc| {
            doc.deinit();
            self.document = null;
        }
        if (self.cached_html) |html| {
            self.allocator.free(html);
            self.cached_html = null;
        }

        self.source = content;
        self.source_version += 1;

        // Phase 1: Block parsing
        var block_parser = try blocks.BlockParser.init(self.allocator, content, self.options);
        defer block_parser.deinit();

        self.document = try block_parser.parse();

        // Phase 2: Inline parsing for each block
        try self.parseAllInlines(self.document.?);

        return self.document.?;
    }

    /// Parse inlines in all blocks that contain inline content
    fn parseAllInlines(self: *MarkdownParser, node: *Node) !void {
        switch (node.node_type) {
            .paragraph, .heading => {
                // Collect text content from children
                var text_content: std.ArrayListUnmanaged(u8) = .{};
                defer text_content.deinit(self.allocator);

                var child = node.first_child;
                while (child) |c| {
                    if (c.node_type == .text) {
                        try text_content.appendSlice(self.allocator, c.data.text.content);
                    } else if (c.node_type == .soft_break) {
                        try text_content.append(self.allocator, '\n');
                    }
                    child = c.next;
                }

                if (text_content.items.len > 0) {
                    // Remove existing children
                    while (node.first_child) |c| {
                        c.unlink();
                        c.deinit();
                    }

                    // Parse inlines (initOwned takes ownership of duped content)
                    var inline_parser = inlines.InlineParser.initOwned(
                        self.allocator,
                        try self.allocator.dupe(u8, text_content.items),
                        self.options,
                    );
                    defer inline_parser.deinit();

                    try inline_parser.parseInlines(node);
                }
            },
            .table_cell => {
                // Also parse inlines in table cells
                var text_content: std.ArrayListUnmanaged(u8) = .{};
                defer text_content.deinit(self.allocator);

                var child = node.first_child;
                while (child) |c| {
                    if (c.node_type == .text) {
                        try text_content.appendSlice(self.allocator, c.data.text.content);
                    }
                    child = c.next;
                }

                if (text_content.items.len > 0) {
                    while (node.first_child) |c| {
                        c.unlink();
                        c.deinit();
                    }

                    // Parse inlines (initOwned takes ownership of duped content)
                    var inline_parser = inlines.InlineParser.initOwned(
                        self.allocator,
                        try self.allocator.dupe(u8, text_content.items),
                        self.options,
                    );
                    defer inline_parser.deinit();

                    try inline_parser.parseInlines(node);
                }
            },
            else => {},
        }

        // Recurse into children
        var child = node.first_child;
        while (child) |c| {
            try self.parseAllInlines(c);
            child = c.next;
        }
    }

    /// Apply an incremental text edit and re-parse affected region
    /// Returns updated document with < 2ms target for typical edits
    pub fn update(self: *MarkdownParser, edit: TextEdit) !*Node {
        if (self.document == null or self.source.len == 0) {
            // No existing document, do full parse
            return self.parse(edit.new_text);
        }

        // Calculate new source
        const old_source = self.source;
        const new_len = old_source.len - (edit.end_offset - edit.start_offset) + edit.new_text.len;
        const new_source = try self.allocator.alloc(u8, new_len);

        @memcpy(new_source[0..edit.start_offset], old_source[0..edit.start_offset]);
        @memcpy(new_source[edit.start_offset..][0..edit.new_text.len], edit.new_text);
        @memcpy(
            new_source[edit.start_offset + edit.new_text.len ..],
            old_source[edit.end_offset..],
        );

        // Free previously owned source if any
        if (self.owned_source) |src| {
            self.allocator.free(src);
        }

        // Track the new allocated source for cleanup
        self.owned_source = new_source;

        // For now, do full reparse (incremental optimization can be added later)
        // The full parse is already quite fast for typical document sizes
        return self.parse(new_source);
    }

    /// Render the parsed document to HTML
    pub fn renderHtml(self: *MarkdownParser, options: renderer.RenderOptions) ![]const u8 {
        if (self.document == null) {
            return error.ParseError;
        }

        // Check if cached version is still valid
        if (self.cached_html != null and self.html_version == self.source_version) {
            return self.cached_html.?;
        }

        // Render HTML
        var html_renderer = renderer.HtmlRenderer.init(self.allocator, options);
        defer html_renderer.deinit();

        const html = try html_renderer.render(self.document.?);

        // Cache the result
        if (self.cached_html) |old_html| {
            self.allocator.free(old_html);
        }
        self.cached_html = html;
        self.html_version = self.source_version;

        return html;
    }

    /// Get the document AST
    pub fn getDocument(self: *MarkdownParser) ?*Node {
        return self.document;
    }

    /// Get document statistics
    pub fn getStats(self: *MarkdownParser) DocStats {
        if (self.document == null) {
            return .{};
        }

        var stats = DocStats{};
        self.countNodes(self.document.?, &stats);
        return stats;
    }

    fn countNodes(self: *MarkdownParser, node: *Node, stats: *DocStats) void {
        stats.total_nodes += 1;

        switch (node.node_type) {
            .heading => stats.headings += 1,
            .paragraph => stats.paragraphs += 1,
            .code_block, .fenced_code => stats.code_blocks += 1,
            .list => stats.lists += 1,
            .link => stats.links += 1,
            .image => stats.images += 1,
            .table => stats.tables += 1,
            else => {},
        }

        var child = node.first_child;
        while (child) |c| {
            self.countNodes(c, stats);
            child = c.next;
        }
    }

    pub const DocStats = struct {
        total_nodes: u32 = 0,
        headings: u32 = 0,
        paragraphs: u32 = 0,
        code_blocks: u32 = 0,
        lists: u32 = 0,
        links: u32 = 0,
        images: u32 = 0,
        tables: u32 = 0,
    };
};

/// Convenience function to parse and render in one call
pub fn parseAndRender(
    allocator: std.mem.Allocator,
    content: []const u8,
    parse_options: ParserOptions,
    render_options: renderer.RenderOptions,
) ![]const u8 {
    var parser = MarkdownParser.init(allocator, parse_options);
    defer parser.deinit();

    _ = try parser.parse(content);
    const html = try parser.renderHtml(render_options);
    // Transfer ownership to caller by clearing cache
    parser.cached_html = null;
    return html;
}

/// Quick parse with default options
pub fn quickParse(allocator: std.mem.Allocator, content: []const u8) !*Node {
    var parser = MarkdownParser.init(allocator, .{});
    // Note: Caller takes ownership of the document, but parser still needs cleanup
    const doc = try parser.parse(content);
    parser.document = null; // Prevent double-free
    parser.deinit();
    return doc;
}

/// Quick render with default options
pub fn quickRender(allocator: std.mem.Allocator, content: []const u8) ![]const u8 {
    return parseAndRender(allocator, content, .{}, .{});
}

// Tests
test "parse simple markdown" {
    const allocator = std.testing.allocator;

    var parser = MarkdownParser.init(allocator, .{});
    defer parser.deinit();

    const doc = try parser.parse("# Hello\n\nThis is a paragraph.");

    try std.testing.expectEqual(NodeType.document, doc.node_type);
    try std.testing.expectEqual(@as(usize, 2), doc.childCount());
}

test "parse and render" {
    const allocator = std.testing.allocator;

    const html = try parseAndRender(allocator, "# Title\n\nParagraph", .{}, .{});
    defer allocator.free(html);

    try std.testing.expect(std.mem.indexOf(u8, html, "<h1") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "<p>") != null);
}

test "incremental update" {
    const allocator = std.testing.allocator;

    var parser = MarkdownParser.init(allocator, .{});
    defer parser.deinit();

    _ = try parser.parse("Hello world");

    // Simulate edit: "Hello world" -> "Hello Zig"
    _ = try parser.update(.{
        .start_offset = 6,
        .end_offset = 11,
        .new_text = "Zig",
    });

    const html = try parser.renderHtml(.{});
    try std.testing.expect(std.mem.indexOf(u8, html, "Zig") != null);
}

test "document statistics" {
    const allocator = std.testing.allocator;

    var parser = MarkdownParser.init(allocator, .{});
    defer parser.deinit();

    _ = try parser.parse(
        \\# Heading 1
        \\## Heading 2
        \\
        \\Paragraph 1
        \\
        \\Paragraph 2
        \\
        \\- List item
        \\- List item
        \\
        \\```code
        \\fn main() {}
        \\```
    );

    const stats = parser.getStats();
    try std.testing.expectEqual(@as(u32, 2), stats.headings);
    // 2 regular paragraphs + 2 paragraphs inside list items = 4
    try std.testing.expectEqual(@as(u32, 4), stats.paragraphs);
    try std.testing.expectEqual(@as(u32, 1), stats.lists);
    try std.testing.expectEqual(@as(u32, 1), stats.code_blocks);
}
