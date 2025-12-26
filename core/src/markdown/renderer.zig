//! Markdown HTML Renderer
//!
//! Renders parsed Markdown AST to HTML output.

const std = @import("std");
const types = @import("types.zig");

const Node = types.Node;
const NodeType = types.NodeType;

/// Renderer options
pub const RenderOptions = struct {
    /// Use XHTML-style self-closing tags
    xhtml: bool = false,
    /// Add soft breaks between block elements
    soft_breaks: bool = true,
    /// Escape HTML in text content
    escape_html: bool = true,
    /// Use syntax highlighting for code blocks
    highlight_code: bool = false,
    /// Custom class prefix for elements
    class_prefix: []const u8 = "md-",
    /// Render math as MathML (vs raw content)
    math_renderer: MathRenderer = .katex,
    /// Custom link target for external links
    external_link_target: ?[]const u8 = "_blank",
    /// Add rel="noopener noreferrer" to external links
    external_link_rel: bool = true,
};

pub const MathRenderer = enum {
    raw,
    katex,
    mathjax,
};

/// HTML Renderer
pub const HtmlRenderer = struct {
    allocator: std.mem.Allocator,
    options: RenderOptions,
    output: std.ArrayListUnmanaged(u8),
    footnotes: std.ArrayListUnmanaged(*Node),
    heading_count: u32 = 0,

    pub fn init(allocator: std.mem.Allocator, options: RenderOptions) HtmlRenderer {
        return .{
            .allocator = allocator,
            .options = options,
            .output = .{},
            .footnotes = .{},
        };
    }

    pub fn deinit(self: *HtmlRenderer) void {
        self.output.deinit(self.allocator);
        self.footnotes.deinit(self.allocator);
    }

    /// Render AST to HTML string
    pub fn render(self: *HtmlRenderer, root: *Node) ![]const u8 {
        self.output.clearRetainingCapacity();
        try self.renderNode(root);

        // Render footnotes if any
        if (self.footnotes.items.len > 0) {
            try self.renderFootnotes();
        }

        return try self.allocator.dupe(u8, self.output.items);
    }

    fn renderNode(self: *HtmlRenderer, node: *Node) anyerror!void {
        switch (node.node_type) {
            .document => try self.renderChildren(node),
            .paragraph => try self.renderParagraph(node),
            .heading => try self.renderHeading(node),
            .blockquote => try self.renderBlockquote(node),
            .code_block => try self.renderCodeBlock(node),
            .fenced_code => try self.renderFencedCode(node),
            .thematic_break => try self.renderThematicBreak(),
            .list => try self.renderList(node),
            .list_item => try self.renderListItem(node),
            .html_block => try self.renderHtmlBlock(node),
            .text => try self.renderText(node),
            .soft_break => try self.renderSoftBreak(),
            .hard_break => try self.renderHardBreak(),
            .emphasis => try self.renderEmphasis(node),
            .strong => try self.renderStrong(node),
            .code_span => try self.renderCodeSpan(node),
            .link => try self.renderLink(node),
            .image => try self.renderImage(node),
            .html_inline => try self.renderHtmlInline(node),
            .strikethrough => try self.renderStrikethrough(node),
            .table => try self.renderTable(node),
            .table_row => try self.renderTableRow(node),
            .table_cell => try self.renderTableCell(node),
            .task_list_item => try self.renderTaskListItem(node),
            .autolink => try self.renderAutolink(node),
            .message_box => try self.renderMessageBox(node),
            .accordion => try self.renderAccordion(node),
            .accordion_item => try self.renderAccordionItem(node),
            .math_inline => try self.renderMathInline(node),
            .math_block => try self.renderMathBlock(node),
            .mermaid => try self.renderMermaid(node),
            .footnote_ref => try self.renderFootnoteRef(node),
            .footnote_def => try self.collectFootnote(node),
            .toc => try self.renderToc(node),
            .highlight => try self.renderHighlight(node),
            .superscript => try self.renderSuperscript(node),
            .subscript => try self.renderSubscript(node),
            .definition_list => try self.renderDefinitionList(node),
            .definition_term => try self.renderDefinitionTerm(node),
            .definition_desc => try self.renderDefinitionDesc(node),
            .abbr => try self.renderAbbr(node),
            .wiki_link => try self.renderWikiLink(node),
            .emoji => try self.renderEmoji(node),
        }
    }

    fn renderChildren(self: *HtmlRenderer, node: *Node) anyerror!void {
        var child = node.first_child;
        while (child) |c| {
            try self.renderNode(c);
            child = c.next;
        }
    }

    fn renderParagraph(self: *HtmlRenderer, node: *Node) !void {
        try self.write("<p>");
        try self.renderChildren(node);
        try self.write("</p>\n");
    }

    fn renderHeading(self: *HtmlRenderer, node: *Node) !void {
        const level = node.data.heading.level;
        const id = node.data.heading.id;

        try self.write("<h");
        try self.writeChar('0' + level);

        if (id) |heading_id| {
            try self.write(" id=\"");
            try self.escapeHtml(heading_id);
            try self.write("\"");
        }

        try self.write(">");
        try self.renderChildren(node);
        try self.write("</h");
        try self.writeChar('0' + level);
        try self.write(">\n");

        self.heading_count += 1;
    }

    fn renderBlockquote(self: *HtmlRenderer, node: *Node) !void {
        try self.write("<blockquote>\n");
        try self.renderChildren(node);
        try self.write("</blockquote>\n");
    }

    fn renderCodeBlock(self: *HtmlRenderer, node: *Node) !void {
        try self.write("<pre><code>");
        try self.escapeHtml(node.data.code_block.content);
        try self.write("</code></pre>\n");
    }

    fn renderFencedCode(self: *HtmlRenderer, node: *Node) !void {
        try self.write("<pre><code");

        if (node.data.fenced_code.info) |info| {
            // Extract language from info string
            var lang_end: usize = 0;
            while (lang_end < info.len and info[lang_end] != ' ' and info[lang_end] != '\t') {
                lang_end += 1;
            }
            if (lang_end > 0) {
                try self.write(" class=\"language-");
                try self.escapeHtml(info[0..lang_end]);
                try self.write("\"");
            }
        }

        try self.write(">");
        try self.escapeHtml(node.data.fenced_code.content);
        try self.write("</code></pre>\n");
    }

    fn renderThematicBreak(self: *HtmlRenderer) !void {
        if (self.options.xhtml) {
            try self.write("<hr />\n");
        } else {
            try self.write("<hr>\n");
        }
    }

    fn renderList(self: *HtmlRenderer, node: *Node) !void {
        const data = node.data.list;

        if (data.list_type == .ordered) {
            try self.write("<ol");
            if (data.start != 1) {
                try self.write(" start=\"");
                var buf: [16]u8 = undefined;
                const formatted = std.fmt.bufPrint(&buf, "{d}", .{data.start}) catch unreachable;
                try self.output.appendSlice(self.allocator, formatted);
                try self.write("\"");
            }
            try self.write(">\n");
        } else {
            try self.write("<ul>\n");
        }

        try self.renderChildren(node);

        if (data.list_type == .ordered) {
            try self.write("</ol>\n");
        } else {
            try self.write("</ul>\n");
        }
    }

    fn renderListItem(self: *HtmlRenderer, node: *Node) !void {
        try self.write("<li>");
        try self.renderChildren(node);
        try self.write("</li>\n");
    }

    fn renderHtmlBlock(self: *HtmlRenderer, node: *Node) !void {
        try self.output.appendSlice(self.allocator, node.data.html_block.content);
        try self.write("\n");
    }

    fn renderText(self: *HtmlRenderer, node: *Node) !void {
        if (self.options.escape_html) {
            try self.escapeHtml(node.data.text.content);
        } else {
            try self.output.appendSlice(self.allocator, node.data.text.content);
        }
    }

    fn renderSoftBreak(self: *HtmlRenderer) !void {
        if (self.options.soft_breaks) {
            try self.write("\n");
        } else {
            try self.write(" ");
        }
    }

    fn renderHardBreak(self: *HtmlRenderer) !void {
        if (self.options.xhtml) {
            try self.write("<br />\n");
        } else {
            try self.write("<br>\n");
        }
    }

    fn renderEmphasis(self: *HtmlRenderer, node: *Node) !void {
        try self.write("<em>");
        try self.renderChildren(node);
        try self.write("</em>");
    }

    fn renderStrong(self: *HtmlRenderer, node: *Node) !void {
        try self.write("<strong>");
        try self.renderChildren(node);
        try self.write("</strong>");
    }

    fn renderCodeSpan(self: *HtmlRenderer, node: *Node) !void {
        try self.write("<code>");
        try self.escapeHtml(node.data.code_span.content);
        try self.write("</code>");
    }

    fn renderLink(self: *HtmlRenderer, node: *Node) !void {
        const data = node.data.link;

        try self.write("<a href=\"");
        try self.escapeHtml(data.url);
        try self.write("\"");

        if (data.title) |title| {
            try self.write(" title=\"");
            try self.escapeHtml(title);
            try self.write("\"");
        }

        // External link handling
        if (self.isExternalUrl(data.url)) {
            if (self.options.external_link_target) |target| {
                try self.write(" target=\"");
                try self.write(target);
                try self.write("\"");
            }
            if (self.options.external_link_rel) {
                try self.write(" rel=\"noopener noreferrer\"");
            }
        }

        try self.write(">");
        try self.renderChildren(node);
        try self.write("</a>");
    }

    fn renderImage(self: *HtmlRenderer, node: *Node) !void {
        const data = node.data.image;

        try self.write("<img src=\"");
        try self.escapeHtml(data.url);
        try self.write("\" alt=\"");

        // Render children as alt text
        var child = node.first_child;
        while (child) |c| {
            if (c.node_type == .text) {
                try self.escapeHtml(c.data.text.content);
            }
            child = c.next;
        }

        try self.write("\"");

        if (data.title) |title| {
            try self.write(" title=\"");
            try self.escapeHtml(title);
            try self.write("\"");
        }

        if (self.options.xhtml) {
            try self.write(" />");
        } else {
            try self.write(">");
        }
    }

    fn renderHtmlInline(self: *HtmlRenderer, node: *Node) !void {
        try self.output.appendSlice(self.allocator, node.data.html_inline.content);
    }

    fn renderStrikethrough(self: *HtmlRenderer, node: *Node) !void {
        try self.write("<del>");
        try self.renderChildren(node);
        try self.write("</del>");
    }

    fn renderTable(self: *HtmlRenderer, node: *Node) !void {
        try self.write("<table>\n");

        var in_header = true;
        var child = node.first_child;

        while (child) |row| {
            if (in_header) {
                try self.write("<thead>\n");
                try self.renderNode(row);
                try self.write("</thead>\n<tbody>\n");
                in_header = false;
            } else {
                try self.renderNode(row);
            }
            child = row.next;
        }

        if (!in_header) {
            try self.write("</tbody>\n");
        }

        try self.write("</table>\n");
    }

    fn renderTableRow(self: *HtmlRenderer, node: *Node) !void {
        try self.write("<tr>");
        try self.renderChildren(node);
        try self.write("</tr>\n");
    }

    fn renderTableCell(self: *HtmlRenderer, node: *Node) !void {
        const data = node.data.table_cell;
        const tag = if (data.is_header) "th" else "td";

        try self.write("<");
        try self.write(tag);

        if (data.alignment != .none) {
            try self.write(" style=\"text-align: ");
            try self.write(switch (data.alignment) {
                .left => "left",
                .center => "center",
                .right => "right",
                .none => unreachable,
            });
            try self.write("\"");
        }

        try self.write(">");
        try self.renderChildren(node);
        try self.write("</");
        try self.write(tag);
        try self.write(">");
    }

    fn renderTaskListItem(self: *HtmlRenderer, node: *Node) !void {
        const checked = node.data.task_list_item.checked;

        try self.write("<li class=\"task-list-item\"><input type=\"checkbox\" disabled");
        if (checked) {
            try self.write(" checked");
        }
        if (self.options.xhtml) {
            try self.write(" />");
        } else {
            try self.write(">");
        }
        try self.renderChildren(node);
        try self.write("</li>\n");
    }

    fn renderAutolink(self: *HtmlRenderer, node: *Node) !void {
        const data = node.data.autolink;

        try self.write("<a href=\"");
        try self.escapeHtml(data.url);
        try self.write("\">");

        // Display without mailto: prefix for emails
        const display = if (data.is_email and std.mem.startsWith(u8, data.url, "mailto:"))
            data.url[7..]
        else
            data.url;

        try self.escapeHtml(display);
        try self.write("</a>");
    }

    fn renderMessageBox(self: *HtmlRenderer, node: *Node) !void {
        const data = node.data.message_box;
        const type_str = @tagName(data.box_type);

        try self.write("<div class=\"");
        try self.write(self.options.class_prefix);
        try self.write("message-box ");
        try self.write(self.options.class_prefix);
        try self.write(type_str);
        try self.write("\">\n");

        if (data.title) |title| {
            try self.write("<div class=\"");
            try self.write(self.options.class_prefix);
            try self.write("message-title\">");
            try self.escapeHtml(title);
            try self.write("</div>\n");
        }

        try self.write("<div class=\"");
        try self.write(self.options.class_prefix);
        try self.write("message-content\">\n");
        try self.renderChildren(node);
        try self.write("</div>\n</div>\n");
    }

    fn renderAccordion(self: *HtmlRenderer, node: *Node) !void {
        try self.write("<div class=\"");
        try self.write(self.options.class_prefix);
        try self.write("accordion\">\n");
        try self.renderChildren(node);
        try self.write("</div>\n");
    }

    fn renderAccordionItem(self: *HtmlRenderer, node: *Node) !void {
        const data = node.data.accordion_item;

        try self.write("<details");
        if (data.open) {
            try self.write(" open");
        }
        try self.write(">\n<summary>");
        try self.escapeHtml(data.title);
        try self.write("</summary>\n<div class=\"");
        try self.write(self.options.class_prefix);
        try self.write("accordion-content\">\n");
        try self.renderChildren(node);
        try self.write("</div>\n</details>\n");
    }

    fn renderMathInline(self: *HtmlRenderer, node: *Node) !void {
        const content = node.data.math_inline.content;

        switch (self.options.math_renderer) {
            .raw => {
                try self.write("<span class=\"math-inline\">$");
                try self.escapeHtml(content);
                try self.write("$</span>");
            },
            .katex => {
                try self.write("<span class=\"math-inline\" data-math=\"");
                try self.escapeHtml(content);
                try self.write("\"></span>");
            },
            .mathjax => {
                try self.write("\\(");
                try self.escapeHtml(content);
                try self.write("\\)");
            },
        }
    }

    fn renderMathBlock(self: *HtmlRenderer, node: *Node) !void {
        const content = node.data.math_block.content;

        switch (self.options.math_renderer) {
            .raw => {
                try self.write("<div class=\"math-block\">$$");
                try self.escapeHtml(content);
                try self.write("$$</div>\n");
            },
            .katex => {
                try self.write("<div class=\"math-block\" data-math=\"");
                try self.escapeHtml(content);
                try self.write("\"></div>\n");
            },
            .mathjax => {
                try self.write("\\[\n");
                try self.escapeHtml(content);
                try self.write("\n\\]\n");
            },
        }
    }

    fn renderMermaid(self: *HtmlRenderer, node: *Node) !void {
        try self.write("<div class=\"mermaid\">\n");
        try self.escapeHtml(node.data.mermaid.content);
        try self.write("</div>\n");
    }

    fn renderFootnoteRef(self: *HtmlRenderer, node: *Node) !void {
        const data = node.data.footnote_ref;

        try self.write("<sup class=\"footnote-ref\"><a href=\"#fn-");
        try self.escapeHtml(data.label);
        try self.write("\" id=\"fnref-");
        try self.escapeHtml(data.label);
        try self.write("\">");
        var buf: [16]u8 = undefined;
        const formatted = std.fmt.bufPrint(&buf, "{d}", .{data.index}) catch unreachable;
        try self.output.appendSlice(self.allocator, formatted);
        try self.write("</a></sup>");
    }

    fn collectFootnote(self: *HtmlRenderer, node: *Node) !void {
        try self.footnotes.append(self.allocator, node);
    }

    fn renderFootnotes(self: *HtmlRenderer) !void {
        if (self.footnotes.items.len == 0) return;

        try self.write("<section class=\"footnotes\">\n<ol>\n");

        for (self.footnotes.items) |fn_node| {
            const data = fn_node.data.footnote_def;

            try self.write("<li id=\"fn-");
            try self.escapeHtml(data.label);
            try self.write("\">");
            try self.renderChildren(fn_node);
            try self.write(" <a href=\"#fnref-");
            try self.escapeHtml(data.label);
            try self.write("\" class=\"footnote-backref\">↩</a></li>\n");
        }

        try self.write("</ol>\n</section>\n");
    }

    fn renderToc(self: *HtmlRenderer, node: *Node) !void {
        _ = node;
        try self.write("<nav class=\"table-of-contents\">\n");
        try self.write("<!-- TOC will be generated by client-side JavaScript -->\n");
        try self.write("</nav>\n");
    }

    fn renderHighlight(self: *HtmlRenderer, node: *Node) !void {
        try self.write("<mark>");
        try self.renderChildren(node);
        try self.write("</mark>");
    }

    fn renderSuperscript(self: *HtmlRenderer, node: *Node) !void {
        try self.write("<sup>");
        try self.renderChildren(node);
        try self.write("</sup>");
    }

    fn renderSubscript(self: *HtmlRenderer, node: *Node) !void {
        try self.write("<sub>");
        try self.renderChildren(node);
        try self.write("</sub>");
    }

    fn renderDefinitionList(self: *HtmlRenderer, node: *Node) !void {
        try self.write("<dl>\n");
        try self.renderChildren(node);
        try self.write("</dl>\n");
    }

    fn renderDefinitionTerm(self: *HtmlRenderer, node: *Node) !void {
        try self.write("<dt>");
        try self.renderChildren(node);
        try self.write("</dt>\n");
    }

    fn renderDefinitionDesc(self: *HtmlRenderer, node: *Node) !void {
        try self.write("<dd>");
        try self.renderChildren(node);
        try self.write("</dd>\n");
    }

    fn renderAbbr(self: *HtmlRenderer, node: *Node) !void {
        const data = node.data.abbr;

        try self.write("<abbr title=\"");
        try self.escapeHtml(data.expansion);
        try self.write("\">");
        try self.escapeHtml(data.abbr);
        try self.write("</abbr>");
    }

    fn renderWikiLink(self: *HtmlRenderer, node: *Node) !void {
        const data = node.data.wiki_link;

        try self.write("<a href=\"");
        try self.escapeHtml(data.target);
        try self.write("\" class=\"wiki-link\">");
        try self.escapeHtml(data.display orelse data.target);
        try self.write("</a>");
    }

    fn renderEmoji(self: *HtmlRenderer, node: *Node) !void {
        const data = node.data.emoji;

        if (data.unicode) |unicode| {
            try self.output.appendSlice(self.allocator, unicode);
        } else {
            try self.write("<span class=\"emoji\" data-emoji=\":");
            try self.escapeHtml(data.shortcode);
            try self.write(":\">:");
            try self.escapeHtml(data.shortcode);
            try self.write(":</span>");
        }
    }

    // Helper functions

    fn write(self: *HtmlRenderer, str: []const u8) !void {
        try self.output.appendSlice(self.allocator, str);
    }

    fn writeChar(self: *HtmlRenderer, c: u8) !void {
        try self.output.append(self.allocator, c);
    }

    fn escapeHtml(self: *HtmlRenderer, text: []const u8) !void {
        for (text) |c| {
            switch (c) {
                '&' => try self.write("&amp;"),
                '<' => try self.write("&lt;"),
                '>' => try self.write("&gt;"),
                '"' => try self.write("&quot;"),
                '\'' => try self.write("&#39;"),
                else => try self.writeChar(c),
            }
        }
    }

    fn isExternalUrl(self: *HtmlRenderer, url: []const u8) bool {
        _ = self;
        return std.mem.startsWith(u8, url, "http://") or
            std.mem.startsWith(u8, url, "https://") or
            std.mem.startsWith(u8, url, "//");
    }
};

// Tests
test "render paragraph" {
    const allocator = std.testing.allocator;

    const doc = try Node.create(allocator, .document, .{ .document = {} });
    defer doc.deinit();

    const para = try Node.create(allocator, .paragraph, .{ .paragraph = {} });
    doc.appendChild(para);

    const text = try Node.create(allocator, .text, .{ .text = .{ .content = try allocator.dupe(u8, "Hello, World!") } });
    para.appendChild(text);

    var renderer = HtmlRenderer.init(allocator, .{});
    defer renderer.deinit();

    const html = try renderer.render(doc);
    defer allocator.free(html);

    try std.testing.expectEqualStrings("<p>Hello, World!</p>\n", html);
}

test "render heading" {
    const allocator = std.testing.allocator;

    const doc = try Node.create(allocator, .document, .{ .document = {} });
    defer doc.deinit();

    const h1 = try Node.create(allocator, .heading, .{ .heading = .{ .level = 1, .id = try allocator.dupe(u8, "title") } });
    doc.appendChild(h1);

    const text = try Node.create(allocator, .text, .{ .text = .{ .content = try allocator.dupe(u8, "Title") } });
    h1.appendChild(text);

    var renderer = HtmlRenderer.init(allocator, .{});
    defer renderer.deinit();

    const html = try renderer.render(doc);
    defer allocator.free(html);

    try std.testing.expectEqualStrings("<h1 id=\"title\">Title</h1>\n", html);
}

test "render code block" {
    const allocator = std.testing.allocator;

    const doc = try Node.create(allocator, .document, .{ .document = {} });
    defer doc.deinit();

    const code = try Node.create(allocator, .fenced_code, .{
        .fenced_code = .{ .info = try allocator.dupe(u8, "javascript"), .content = try allocator.dupe(u8, "console.log('hi');") },
    });
    doc.appendChild(code);

    var renderer = HtmlRenderer.init(allocator, .{});
    defer renderer.deinit();

    const html = try renderer.render(doc);
    defer allocator.free(html);

    try std.testing.expectEqualStrings("<pre><code class=\"language-javascript\">console.log(&#39;hi&#39;);</code></pre>\n", html);
}

test "escape html entities" {
    const allocator = std.testing.allocator;

    const doc = try Node.create(allocator, .document, .{ .document = {} });
    defer doc.deinit();

    const para = try Node.create(allocator, .paragraph, .{ .paragraph = {} });
    doc.appendChild(para);

    const text = try Node.create(allocator, .text, .{ .text = .{ .content = try allocator.dupe(u8, "<script>alert('xss')</script>") } });
    para.appendChild(text);

    var renderer = HtmlRenderer.init(allocator, .{});
    defer renderer.deinit();

    const html = try renderer.render(doc);
    defer allocator.free(html);

    try std.testing.expectEqualStrings("<p>&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;</p>\n", html);
}
