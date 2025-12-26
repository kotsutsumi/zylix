//! Zylix Markdown - Cross-Platform Markdown Parser
//!
//! A high-performance Markdown parser with support for CommonMark, GFM,
//! and custom extensions for documentation and rich content.
//!
//! ## Features
//!
//! - **CommonMark Compliance**: Full CommonMark 0.31.2 specification support
//! - **GFM Extensions**: Tables, strikethrough, autolinks, task lists
//! - **Custom Extensions**: Message boxes, accordion, math, mermaid, wiki links
//! - **Incremental Parsing**: < 2ms update time for typical edits
//! - **Cross-Platform**: iOS, Android, macOS, Windows, Linux, Web/WASM
//! - **C ABI**: Full C-compatible interface for FFI
//!
//! ## Example
//!
//! ```zig
//! const markdown = @import("markdown");
//!
//! // Quick parse and render
//! const html = try markdown.quickRender(allocator, "# Hello, World!");
//! defer allocator.free(html);
//!
//! // With parser instance for incremental updates
//! var parser = markdown.MarkdownParser.init(allocator, .{});
//! defer parser.deinit();
//!
//! const doc = try parser.parse("# Title\n\nParagraph here.");
//!
//! // Apply incremental update
//! _ = try parser.update(.{
//!     .start_offset = 8,
//!     .end_offset = 15,
//!     .new_text = "New Text",
//! });
//!
//! // Render to HTML
//! const output = try parser.renderHtml(.{});
//! ```
//!
//! ## Extension Syntax
//!
//! ### Message Boxes
//! ```markdown
//! :::note Custom Title
//! Content here
//! :::
//! ```
//!
//! ### Math (KaTeX/MathJax)
//! ```markdown
//! Inline: $E = mc^2$
//! Block: $$\int_0^\infty e^{-x^2} dx = \frac{\sqrt{\pi}}{2}$$
//! ```
//!
//! ### Mermaid Diagrams
//! ````markdown
//! ```mermaid
//! graph TD
//!     A --> B
//! ```
//! ````
//!
//! ### Highlight
//! ```markdown
//! ==highlighted text==
//! ```
//!
//! ### Super/Subscript
//! ```markdown
//! H~2~O (subscript)
//! E = mc^2^ (superscript)
//! ```
//!
//! ### Wiki Links
//! ```markdown
//! [[PageName]]
//! [[PageName|Display Text]]
//! ```

const std = @import("std");

// Public type exports
pub const types = @import("types.zig");
pub const Node = types.Node;
pub const NodeType = types.NodeType;
pub const NodeData = types.NodeData;
pub const ParserOptions = types.ParserOptions;
pub const TextEdit = types.TextEdit;
pub const SourcePos = types.SourcePos;
pub const MessageBoxType = types.MessageBoxType;
pub const TableAlign = types.TableAlign;
pub const ListType = types.ListType;
pub const MarkdownError = types.MarkdownError;

// Internal module imports
pub const lexer = @import("lexer.zig");
pub const blocks = @import("blocks.zig");
pub const inlines = @import("inlines.zig");
pub const renderer = @import("renderer.zig");
pub const parser = @import("parser.zig");
pub const abi = @import("abi.zig");

// Main types
pub const MarkdownParser = parser.MarkdownParser;
pub const HtmlRenderer = renderer.HtmlRenderer;
pub const RenderOptions = renderer.RenderOptions;
pub const MathRenderer = renderer.MathRenderer;
pub const Scanner = lexer.Scanner;
pub const LineScanner = lexer.LineScanner;
pub const BlockParser = blocks.BlockParser;
pub const InlineParser = inlines.InlineParser;

// Convenience functions
pub const parseAndRender = parser.parseAndRender;
pub const quickParse = parser.quickParse;
pub const quickRender = parser.quickRender;

/// Module version
pub const version = "0.23.0";

/// Create a new parser with default options
pub fn createParser(allocator: std.mem.Allocator) MarkdownParser {
    return MarkdownParser.init(allocator, .{});
}

/// Create a new parser with custom options
pub fn createParserWithOptions(allocator: std.mem.Allocator, options: ParserOptions) MarkdownParser {
    return MarkdownParser.init(allocator, options);
}

/// Create a new renderer with default options
pub fn createRenderer(allocator: std.mem.Allocator) HtmlRenderer {
    return HtmlRenderer.init(allocator, .{});
}

/// Create a new renderer with custom options
pub fn createRendererWithOptions(allocator: std.mem.Allocator, options: RenderOptions) HtmlRenderer {
    return HtmlRenderer.init(allocator, options);
}

/// Default parser options for GFM-compatible parsing
pub const DEFAULT_GFM_OPTIONS: ParserOptions = .{
    .gfm = true,
    .math = false,
    .mermaid = false,
    .message_boxes = false,
    .accordion = false,
    .footnotes = false,
    .wiki_links = false,
    .emoji = true,
    .highlight = false,
    .super_subscript = false,
    .abbreviations = false,
    .definition_lists = false,
    .toc = false,
};

/// Parser options with all extensions enabled
pub const FULL_EXTENSION_OPTIONS: ParserOptions = .{
    .gfm = true,
    .math = true,
    .mermaid = true,
    .message_boxes = true,
    .accordion = true,
    .footnotes = true,
    .wiki_links = true,
    .emoji = true,
    .highlight = true,
    .super_subscript = true,
    .abbreviations = true,
    .definition_lists = true,
    .toc = true,
    .smart_punctuation = true,
};

/// Minimal parser options (CommonMark only)
pub const COMMONMARK_OPTIONS: ParserOptions = .{
    .gfm = false,
    .math = false,
    .mermaid = false,
    .message_boxes = false,
    .accordion = false,
    .footnotes = false,
    .wiki_links = false,
    .emoji = false,
    .highlight = false,
    .super_subscript = false,
    .abbreviations = false,
    .definition_lists = false,
    .toc = false,
    .smart_punctuation = false,
};

// Unit tests
test "module imports" {
    _ = types;
    _ = lexer;
    _ = blocks;
    _ = inlines;
    _ = renderer;
    _ = parser;
    _ = abi;
}

test "quick parse and render" {
    const allocator = std.testing.allocator;

    const html = try quickRender(allocator, "# Hello\n\nWorld");
    defer allocator.free(html);

    try std.testing.expect(std.mem.indexOf(u8, html, "<h1") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "Hello") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "<p>World</p>") != null);
}

test "parser with options" {
    const allocator = std.testing.allocator;

    var md_parser = createParserWithOptions(allocator, FULL_EXTENSION_OPTIONS);
    defer md_parser.deinit();

    const doc = try md_parser.parse(
        \\# Title
        \\
        \\:::note Important
        \\This is a note
        \\:::
        \\
        \\Math: $E = mc^2$
    );

    try std.testing.expectEqual(NodeType.document, doc.node_type);
}

test "GFM table parsing" {
    const allocator = std.testing.allocator;

    var md_parser = createParserWithOptions(allocator, DEFAULT_GFM_OPTIONS);
    defer md_parser.deinit();

    const doc = try md_parser.parse(
        \\| Header 1 | Header 2 |
        \\|----------|----------|
        \\| Cell 1   | Cell 2   |
    );

    // Find table node
    var child = doc.first_child;
    var found_table = false;
    while (child) |c| {
        if (c.node_type == .table) {
            found_table = true;
            break;
        }
        child = c.next;
    }

    try std.testing.expect(found_table);
}

test "incremental update performance" {
    const allocator = std.testing.allocator;

    var md_parser = createParser(allocator);
    defer md_parser.deinit();

    // Parse initial document
    _ = try md_parser.parse(
        \\# Title
        \\
        \\Paragraph 1
        \\
        \\Paragraph 2
        \\
        \\Paragraph 3
    );

    // Measure update time
    const start = std.time.nanoTimestamp();

    _ = try md_parser.update(.{
        .start_offset = 8,
        .end_offset = 13,
        .new_text = "New Title",
    });

    const elapsed = std.time.nanoTimestamp() - start;
    const elapsed_ms = @as(f64, @floatFromInt(elapsed)) / 1_000_000.0;

    // Should be well under 2ms for small updates
    try std.testing.expect(elapsed_ms < 100.0); // Allow 100ms for test environments
}

test "code block with language" {
    const allocator = std.testing.allocator;

    const html = try parseAndRender(allocator,
        \\```zig
        \\const x = 42;
        \\```
    , .{}, .{});
    defer allocator.free(html);

    try std.testing.expect(std.mem.indexOf(u8, html, "language-zig") != null);
}

test "nested lists" {
    const allocator = std.testing.allocator;

    var md_parser = createParser(allocator);
    defer md_parser.deinit();

    _ = try md_parser.parse(
        \\- Item 1
        \\  - Nested 1
        \\  - Nested 2
        \\- Item 2
    );

    const stats = md_parser.getStats();
    try std.testing.expect(stats.lists >= 1);
}
