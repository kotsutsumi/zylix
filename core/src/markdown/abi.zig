//! Markdown C ABI Exports
//!
//! Provides C-compatible interface for the Markdown parser,
//! enabling integration with platform shells (iOS/Android/Desktop).

const std = @import("std");
const types = @import("types.zig");
const parser = @import("parser.zig");
const renderer_mod = @import("renderer.zig");

const Node = types.Node;
const MarkdownParser = parser.MarkdownParser;
const HtmlRenderer = renderer_mod.HtmlRenderer;

// ============================================================================
// Opaque Handle Types
// ============================================================================

/// Opaque handle to MarkdownParser
pub const ZylixMarkdownParser = opaque {};

/// Opaque handle to Node
pub const ZylixMarkdownNode = opaque {};

// ============================================================================
// Result Codes
// ============================================================================

pub const MarkdownResult = enum(i32) {
    ok = 0,
    err_invalid_arg = 1,
    err_out_of_memory = 2,
    err_parse_error = 3,
    err_render_error = 4,
    err_invalid_handle = 5,
};

// ============================================================================
// Parser Options (C-compatible struct)
// ============================================================================

pub const ZylixMarkdownOptions = extern struct {
    gfm: bool = true,
    math: bool = true,
    mermaid: bool = true,
    message_boxes: bool = true,
    accordion: bool = true,
    footnotes: bool = true,
    wiki_links: bool = true,
    emoji: bool = true,
    highlight: bool = true,
    super_subscript: bool = true,
    abbreviations: bool = true,
    definition_lists: bool = true,
    toc: bool = true,
    smart_punctuation: bool = false,
    tab_size: u8 = 4,
    allow_html: bool = true,
    backslash_breaks: bool = true,
    heading_ids: bool = true,

    fn toInternal(self: ZylixMarkdownOptions) types.ParserOptions {
        return .{
            .gfm = self.gfm,
            .math = self.math,
            .mermaid = self.mermaid,
            .message_boxes = self.message_boxes,
            .accordion = self.accordion,
            .footnotes = self.footnotes,
            .wiki_links = self.wiki_links,
            .emoji = self.emoji,
            .highlight = self.highlight,
            .super_subscript = self.super_subscript,
            .abbreviations = self.abbreviations,
            .definition_lists = self.definition_lists,
            .toc = self.toc,
            .smart_punctuation = self.smart_punctuation,
            .tab_size = self.tab_size,
            .allow_html = self.allow_html,
            .backslash_breaks = self.backslash_breaks,
            .heading_ids = self.heading_ids,
        };
    }
};

pub const ZylixRenderOptions = extern struct {
    xhtml: bool = false,
    soft_breaks: bool = true,
    escape_html: bool = true,
    highlight_code: bool = false,
    external_link_target: ?[*:0]const u8 = null,
    external_link_rel: bool = true,

    fn toInternal(self: ZylixRenderOptions) renderer_mod.RenderOptions {
        return .{
            .xhtml = self.xhtml,
            .soft_breaks = self.soft_breaks,
            .escape_html = self.escape_html,
            .highlight_code = self.highlight_code,
            .external_link_target = if (self.external_link_target) |t|
                std.mem.span(t)
            else
                "_blank",
            .external_link_rel = self.external_link_rel,
        };
    }
};

// ============================================================================
// Node Info (C-compatible struct for node inspection)
// ============================================================================

pub const ZylixNodeInfo = extern struct {
    node_type: u8,
    start_line: u32,
    start_col: u32,
    end_line: u32,
    end_col: u32,
    child_count: u32,
    content_ptr: ?[*]const u8,
    content_len: usize,
};

// ============================================================================
// Global State
// ============================================================================

var global_allocator: std.mem.Allocator = std.heap.page_allocator;
var last_error: MarkdownResult = .ok;
var last_html_output: ?[]const u8 = null;

// ============================================================================
// Lifecycle Functions
// ============================================================================

/// Create a new Markdown parser
pub fn zylix_markdown_create(options: ?*const ZylixMarkdownOptions) callconv(.c) ?*ZylixMarkdownParser {
    const opts = if (options) |o| o.toInternal() else types.ParserOptions{};

    const parser_ptr = global_allocator.create(MarkdownParser) catch {
        last_error = .err_out_of_memory;
        return null;
    };

    parser_ptr.* = MarkdownParser.init(global_allocator, opts);
    last_error = .ok;

    return @ptrCast(parser_ptr);
}

/// Destroy a Markdown parser
pub fn zylix_markdown_destroy(handle: ?*ZylixMarkdownParser) callconv(.c) i32 {
    const parser_ptr = @as(?*MarkdownParser, @ptrCast(@alignCast(handle))) orelse {
        last_error = .err_invalid_handle;
        return @intFromEnum(MarkdownResult.err_invalid_handle);
    };

    parser_ptr.deinit();
    global_allocator.destroy(parser_ptr);

    last_error = .ok;
    return @intFromEnum(MarkdownResult.ok);
}

// ============================================================================
// Parsing Functions
// ============================================================================

/// Parse Markdown content
pub fn zylix_markdown_parse(
    handle: ?*ZylixMarkdownParser,
    content: ?[*]const u8,
    content_len: usize,
) callconv(.c) ?*ZylixMarkdownNode {
    const parser_ptr = @as(?*MarkdownParser, @ptrCast(@alignCast(handle))) orelse {
        last_error = .err_invalid_handle;
        return null;
    };

    const source = if (content) |c| c[0..content_len] else {
        last_error = .err_invalid_arg;
        return null;
    };

    const doc = parser_ptr.parse(source) catch {
        last_error = .err_parse_error;
        return null;
    };

    last_error = .ok;
    return @ptrCast(doc);
}

/// Apply incremental update
pub fn zylix_markdown_update(
    handle: ?*ZylixMarkdownParser,
    start_offset: u32,
    end_offset: u32,
    new_text: ?[*]const u8,
    new_text_len: usize,
) callconv(.c) ?*ZylixMarkdownNode {
    const parser_ptr = @as(?*MarkdownParser, @ptrCast(@alignCast(handle))) orelse {
        last_error = .err_invalid_handle;
        return null;
    };

    const text = if (new_text) |t| t[0..new_text_len] else "";

    const doc = parser_ptr.update(.{
        .start_offset = start_offset,
        .end_offset = end_offset,
        .new_text = text,
    }) catch {
        last_error = .err_parse_error;
        return null;
    };

    last_error = .ok;
    return @ptrCast(doc);
}

// ============================================================================
// Rendering Functions
// ============================================================================

/// Render to HTML
pub fn zylix_markdown_render_html(
    handle: ?*ZylixMarkdownParser,
    options: ?*const ZylixRenderOptions,
    out_html: ?*[*]const u8,
    out_len: ?*usize,
) callconv(.c) i32 {
    const parser_ptr = @as(?*MarkdownParser, @ptrCast(@alignCast(handle))) orelse {
        last_error = .err_invalid_handle;
        return @intFromEnum(MarkdownResult.err_invalid_handle);
    };

    const render_opts = if (options) |o| o.toInternal() else renderer_mod.RenderOptions{};

    const html = parser_ptr.renderHtml(render_opts) catch {
        last_error = .err_render_error;
        return @intFromEnum(MarkdownResult.err_render_error);
    };

    // Store globally for later retrieval
    if (last_html_output) |old| {
        global_allocator.free(old);
    }
    last_html_output = html;

    if (out_html) |ptr| {
        ptr.* = html.ptr;
    }
    if (out_len) |len| {
        len.* = html.len;
    }

    last_error = .ok;
    return @intFromEnum(MarkdownResult.ok);
}

/// Quick render (parse + render in one call)
pub fn zylix_markdown_quick_render(
    content: ?[*]const u8,
    content_len: usize,
    options: ?*const ZylixMarkdownOptions,
    render_options: ?*const ZylixRenderOptions,
    out_html: ?*[*]const u8,
    out_len: ?*usize,
) callconv(.c) i32 {
    const source = if (content) |c| c[0..content_len] else {
        last_error = .err_invalid_arg;
        return @intFromEnum(MarkdownResult.err_invalid_arg);
    };

    const parse_opts = if (options) |o| o.toInternal() else types.ParserOptions{};
    const rend_opts = if (render_options) |o| o.toInternal() else renderer_mod.RenderOptions{};

    const html = parser.parseAndRender(global_allocator, source, parse_opts, rend_opts) catch {
        last_error = .err_parse_error;
        return @intFromEnum(MarkdownResult.err_parse_error);
    };

    // Store globally
    if (last_html_output) |old| {
        global_allocator.free(old);
    }
    last_html_output = html;

    if (out_html) |ptr| {
        ptr.* = html.ptr;
    }
    if (out_len) |len| {
        len.* = html.len;
    }

    last_error = .ok;
    return @intFromEnum(MarkdownResult.ok);
}

// ============================================================================
// Node Inspection Functions
// ============================================================================

/// Get node information
pub fn zylix_markdown_node_info(
    node_handle: ?*ZylixMarkdownNode,
    info: ?*ZylixNodeInfo,
) callconv(.c) i32 {
    const node = @as(?*Node, @ptrCast(@alignCast(node_handle))) orelse {
        last_error = .err_invalid_handle;
        return @intFromEnum(MarkdownResult.err_invalid_handle);
    };

    const info_ptr = info orelse {
        last_error = .err_invalid_arg;
        return @intFromEnum(MarkdownResult.err_invalid_arg);
    };

    // Get content if available
    const content = node.data.getContent();

    info_ptr.* = .{
        .node_type = @intFromEnum(node.node_type),
        .start_line = node.pos.start_line,
        .start_col = node.pos.start_col,
        .end_line = node.pos.end_line,
        .end_col = node.pos.end_col,
        .child_count = @intCast(node.childCount()),
        .content_ptr = if (content) |c| c.ptr else null,
        .content_len = if (content) |c| c.len else 0,
    };

    last_error = .ok;
    return @intFromEnum(MarkdownResult.ok);
}

/// Get first child node
pub fn zylix_markdown_node_first_child(node_handle: ?*ZylixMarkdownNode) callconv(.c) ?*ZylixMarkdownNode {
    const node = @as(?*Node, @ptrCast(@alignCast(node_handle))) orelse {
        last_error = .err_invalid_handle;
        return null;
    };

    return @ptrCast(node.first_child);
}

/// Get next sibling node
pub fn zylix_markdown_node_next(node_handle: ?*ZylixMarkdownNode) callconv(.c) ?*ZylixMarkdownNode {
    const node = @as(?*Node, @ptrCast(@alignCast(node_handle))) orelse {
        last_error = .err_invalid_handle;
        return null;
    };

    return @ptrCast(node.next);
}

/// Get parent node
pub fn zylix_markdown_node_parent(node_handle: ?*ZylixMarkdownNode) callconv(.c) ?*ZylixMarkdownNode {
    const node = @as(?*Node, @ptrCast(@alignCast(node_handle))) orelse {
        last_error = .err_invalid_handle;
        return null;
    };

    return @ptrCast(node.parent);
}

// ============================================================================
// Error Handling
// ============================================================================

/// Get last error code
pub fn zylix_markdown_get_last_error() callconv(.c) i32 {
    return @intFromEnum(last_error);
}

/// Get error message for code
pub fn zylix_markdown_get_error_message(code: i32) callconv(.c) [*:0]const u8 {
    const result: MarkdownResult = @enumFromInt(code);
    return switch (result) {
        .ok => "Success",
        .err_invalid_arg => "Invalid argument",
        .err_out_of_memory => "Out of memory",
        .err_parse_error => "Parse error",
        .err_render_error => "Render error",
        .err_invalid_handle => "Invalid handle",
    };
}

// ============================================================================
// Statistics
// ============================================================================

pub const ZylixMarkdownStats = extern struct {
    total_nodes: u32,
    headings: u32,
    paragraphs: u32,
    code_blocks: u32,
    lists: u32,
    links: u32,
    images: u32,
    tables: u32,
};

/// Get document statistics
pub fn zylix_markdown_get_stats(
    handle: ?*ZylixMarkdownParser,
    stats: ?*ZylixMarkdownStats,
) callconv(.c) i32 {
    const parser_ptr = @as(?*MarkdownParser, @ptrCast(@alignCast(handle))) orelse {
        last_error = .err_invalid_handle;
        return @intFromEnum(MarkdownResult.err_invalid_handle);
    };

    const stats_ptr = stats orelse {
        last_error = .err_invalid_arg;
        return @intFromEnum(MarkdownResult.err_invalid_arg);
    };

    const internal_stats = parser_ptr.getStats();

    stats_ptr.* = .{
        .total_nodes = internal_stats.total_nodes,
        .headings = internal_stats.headings,
        .paragraphs = internal_stats.paragraphs,
        .code_blocks = internal_stats.code_blocks,
        .lists = internal_stats.lists,
        .links = internal_stats.links,
        .images = internal_stats.images,
        .tables = internal_stats.tables,
    };

    last_error = .ok;
    return @intFromEnum(MarkdownResult.ok);
}

// ============================================================================
// Exports
// ============================================================================

comptime {
    // Lifecycle
    @export(&zylix_markdown_create, .{ .name = "zylix_markdown_create" });
    @export(&zylix_markdown_destroy, .{ .name = "zylix_markdown_destroy" });

    // Parsing
    @export(&zylix_markdown_parse, .{ .name = "zylix_markdown_parse" });
    @export(&zylix_markdown_update, .{ .name = "zylix_markdown_update" });

    // Rendering
    @export(&zylix_markdown_render_html, .{ .name = "zylix_markdown_render_html" });
    @export(&zylix_markdown_quick_render, .{ .name = "zylix_markdown_quick_render" });

    // Node inspection
    @export(&zylix_markdown_node_info, .{ .name = "zylix_markdown_node_info" });
    @export(&zylix_markdown_node_first_child, .{ .name = "zylix_markdown_node_first_child" });
    @export(&zylix_markdown_node_next, .{ .name = "zylix_markdown_node_next" });
    @export(&zylix_markdown_node_parent, .{ .name = "zylix_markdown_node_parent" });

    // Error handling
    @export(&zylix_markdown_get_last_error, .{ .name = "zylix_markdown_get_last_error" });
    @export(&zylix_markdown_get_error_message, .{ .name = "zylix_markdown_get_error_message" });

    // Statistics
    @export(&zylix_markdown_get_stats, .{ .name = "zylix_markdown_get_stats" });
}

// Tests
test "C ABI create and destroy" {
    const handle = zylix_markdown_create(null);
    try std.testing.expect(handle != null);

    const result = zylix_markdown_destroy(handle);
    try std.testing.expectEqual(@as(i32, 0), result);
}

test "C ABI parse" {
    const handle = zylix_markdown_create(null);
    defer _ = zylix_markdown_destroy(handle);

    const content = "# Hello World";
    const node = zylix_markdown_parse(handle, content.ptr, content.len);
    try std.testing.expect(node != null);
}

test "C ABI render" {
    const handle = zylix_markdown_create(null);
    defer _ = zylix_markdown_destroy(handle);

    const content = "# Hello";
    _ = zylix_markdown_parse(handle, content.ptr, content.len);

    var html_ptr: [*]const u8 = undefined;
    var html_len: usize = undefined;

    const result = zylix_markdown_render_html(handle, null, &html_ptr, &html_len);
    try std.testing.expectEqual(@as(i32, 0), result);
    try std.testing.expect(html_len > 0);
}
