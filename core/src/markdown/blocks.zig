//! Block-Level Markdown Parsing
//!
//! Handles parsing of block-level elements like paragraphs, headings,
//! lists, blockquotes, code blocks, and custom extensions.

const std = @import("std");
const types = @import("types.zig");
const lexer = @import("lexer.zig");

const Node = types.Node;
const NodeType = types.NodeType;
const NodeData = types.NodeData;
const ParserOptions = types.ParserOptions;
const Line = lexer.Line;
const LineScanner = lexer.LineScanner;

/// Block parser state
pub const BlockParser = struct {
    allocator: std.mem.Allocator,
    options: ParserOptions,
    scanner: LineScanner,
    document: *Node,
    open_blocks: std.ArrayListUnmanaged(*Node),
    line_num: u32 = 1,

    pub fn init(allocator: std.mem.Allocator, source: []const u8, options: ParserOptions) !BlockParser {
        const doc = try Node.create(allocator, .document, .{ .document = {} });

        var open_blocks: std.ArrayListUnmanaged(*Node) = .{};
        try open_blocks.append(allocator, doc);

        return .{
            .allocator = allocator,
            .options = options,
            .scanner = LineScanner.initWithTabSize(source, options.tab_size),
            .document = doc,
            .open_blocks = open_blocks,
        };
    }

    pub fn deinit(self: *BlockParser) void {
        self.open_blocks.deinit(self.allocator);
        // Note: document is returned to caller, not freed here
    }

    /// Parse all blocks and return the document root
    pub fn parse(self: *BlockParser) !*Node {
        while (self.scanner.nextLine()) |line| {
            try self.processLine(line);
            self.line_num += 1;
        }

        // Close all remaining open blocks
        try self.finalizeDocument();

        return self.document;
    }

    /// Process a single line
    fn processLine(self: *BlockParser, line: Line) !void {
        // Check for blank line
        if (line.is_blank) {
            try self.handleBlankLine();
            return;
        }

        // Try to match block starts in order of precedence
        if (try self.tryThematicBreak(line)) return;
        if (try self.tryAtxHeading(line)) return;
        if (try self.tryFencedCodeBlock(line)) return;
        if (try self.tryMessageBox(line)) return;
        if (try self.tryBlockquote(line)) return;
        if (try self.tryListItem(line)) return;
        if (try self.tryHtmlBlock(line)) return;
        if (try self.tryTable(line)) return;

        // Default: paragraph
        try self.addParagraph(line);
    }

    fn handleBlankLine(self: *BlockParser) !void {
        // Close paragraph if open
        if (self.open_blocks.items.len > 1) {
            const last = self.open_blocks.items[self.open_blocks.items.len - 1];
            if (last.node_type == .paragraph) {
                _ = self.open_blocks.pop();
            }
        }
    }

    /// Try to parse ATX heading (# Heading)
    fn tryAtxHeading(self: *BlockParser, line: Line) !bool {
        const content = line.trimmed();
        if (content.len == 0 or content[0] != '#') return false;

        // Count # characters
        var level: u8 = 0;
        while (level < content.len and level < 7 and content[level] == '#') {
            level += 1;
        }

        if (level > 6) return false;

        // Must be followed by space or end of line
        if (level < content.len and content[level] != ' ' and content[level] != '\t') {
            return false;
        }

        // Extract heading text
        var text_start = level;
        while (text_start < content.len and (content[text_start] == ' ' or content[text_start] == '\t')) {
            text_start += 1;
        }

        var text_end = content.len;
        // Remove trailing # characters and spaces
        while (text_end > text_start and content[text_end - 1] == '#') {
            text_end -= 1;
        }
        while (text_end > text_start and (content[text_end - 1] == ' ' or content[text_end - 1] == '\t')) {
            text_end -= 1;
        }

        const heading_text = if (text_start < text_end) content[text_start..text_end] else "";

        // Close any open blocks and add heading
        try self.closeOpenBlocks();

        const heading = try Node.create(self.allocator, .heading, .{
            .heading = .{
                .level = level,
                .id = if (self.options.heading_ids) try self.generateHeadingId(heading_text) else null,
            },
        });
        heading.pos = types.SourcePos.init(line.line_num, @intCast(line.indent + 1), line.start_offset);

        self.document.appendChild(heading);

        // Add text node if there's content
        if (heading_text.len > 0) {
            const text_node = try Node.create(self.allocator, .text, .{
                .text = .{ .content = try self.allocator.dupe(u8, heading_text) },
            });
            heading.appendChild(text_node);
        }

        return true;
    }

    /// Generate a slug ID from heading text
    fn generateHeadingId(self: *BlockParser, text: []const u8) !?[]const u8 {
        // For now, just return the text as-is (duped for ownership)
        // TODO: Proper slug generation (lowercase, replace spaces, remove special chars)
        if (text.len == 0) return null;
        return try self.allocator.dupe(u8, text);
    }

    /// Try to parse thematic break (---, ***, ___)
    fn tryThematicBreak(self: *BlockParser, line: Line) !bool {
        const content = line.trimmed();
        if (content.len < 3) return false;

        const first = content[0];
        if (first != '-' and first != '*' and first != '_') return false;

        var count: usize = 0;
        for (content) |c| {
            if (c == first) {
                count += 1;
            } else if (c != ' ' and c != '\t') {
                return false;
            }
        }

        if (count < 3) return false;

        try self.closeOpenBlocks();

        const hr = try Node.create(self.allocator, .thematic_break, .{ .thematic_break = {} });
        hr.pos = types.SourcePos.init(line.line_num, @intCast(line.indent + 1), line.start_offset);
        self.document.appendChild(hr);

        return true;
    }

    /// Try to parse fenced code block (``` or ~~~)
    fn tryFencedCodeBlock(self: *BlockParser, line: Line) !bool {
        const content = line.trimmed();
        if (content.len < 3) return false;

        const fence_char = content[0];
        if (fence_char != '`' and fence_char != '~') return false;

        // Count fence characters
        var fence_len: usize = 0;
        while (fence_len < content.len and content[fence_len] == fence_char) {
            fence_len += 1;
        }

        if (fence_len < 3) return false;

        // Check for backticks inside info string (not allowed for backtick fences)
        if (fence_char == '`') {
            for (content[fence_len..]) |c| {
                if (c == '`') return false;
            }
        }

        // Extract info string
        var info_start = fence_len;
        while (info_start < content.len and (content[info_start] == ' ' or content[info_start] == '\t')) {
            info_start += 1;
        }
        var info_end = content.len;
        while (info_end > info_start and (content[info_end - 1] == ' ' or content[info_end - 1] == '\t')) {
            info_end -= 1;
        }

        const info: ?[]const u8 = if (info_start < info_end)
            try self.allocator.dupe(u8, content[info_start..info_end])
        else
            null;

        // Check for special extensions
        if (self.options.mermaid and info != null and std.mem.eql(u8, info.?, "mermaid")) {
            // Free the duped info since mermaid block doesn't use it
            self.allocator.free(info.?);
            return self.tryMermaidBlock(line, fence_char, fence_len);
        }

        try self.closeOpenBlocks();

        // Read code content
        var code_content: std.ArrayListUnmanaged(u8) = .{};
        defer code_content.deinit(self.allocator);

        while (self.scanner.nextLine()) |code_line| {
            const code_trimmed = code_line.trimmed();

            // Check for closing fence
            if (code_trimmed.len >= fence_len) {
                var close_count: usize = 0;
                while (close_count < code_trimmed.len and code_trimmed[close_count] == fence_char) {
                    close_count += 1;
                }
                if (close_count >= fence_len) {
                    // Check rest is whitespace
                    var all_space = true;
                    for (code_trimmed[close_count..]) |c| {
                        if (c != ' ' and c != '\t') {
                            all_space = false;
                            break;
                        }
                    }
                    if (all_space) break;
                }
            }

            // Add line to code content
            try code_content.appendSlice(self.allocator, code_line.content);
            try code_content.append(self.allocator, '\n');
        }

        const fenced = try Node.create(self.allocator, .fenced_code, .{
            .fenced_code = .{
                .info = info,
                .content = try self.allocator.dupe(u8, code_content.items),
            },
        });
        fenced.pos = types.SourcePos.init(line.line_num, @intCast(line.indent + 1), line.start_offset);
        self.document.appendChild(fenced);

        return true;
    }

    /// Try to parse mermaid diagram block
    fn tryMermaidBlock(self: *BlockParser, line: Line, fence_char: u8, fence_len: usize) !bool {
        var content: std.ArrayListUnmanaged(u8) = .{};
        defer content.deinit(self.allocator);

        while (self.scanner.nextLine()) |code_line| {
            const code_trimmed = code_line.trimmed();

            // Check for closing fence
            if (code_trimmed.len >= fence_len) {
                var close_count: usize = 0;
                while (close_count < code_trimmed.len and code_trimmed[close_count] == fence_char) {
                    close_count += 1;
                }
                if (close_count >= fence_len) break;
            }

            try content.appendSlice(self.allocator, code_line.content);
            try content.append(self.allocator, '\n');
        }

        const mermaid = try Node.create(self.allocator, .mermaid, .{
            .mermaid = .{
                .content = try self.allocator.dupe(u8, content.items),
            },
        });
        mermaid.pos = types.SourcePos.init(line.line_num, @intCast(line.indent + 1), line.start_offset);
        self.document.appendChild(mermaid);

        return true;
    }

    /// Try to parse message box (:::note, :::warning, etc.)
    fn tryMessageBox(self: *BlockParser, line: Line) !bool {
        if (!self.options.message_boxes) return false;

        const content = line.trimmed();
        if (content.len < 3 or !std.mem.startsWith(u8, content, ":::")) return false;

        // Extract type
        var type_start: usize = 3;
        while (type_start < content.len and (content[type_start] == ' ' or content[type_start] == '\t')) {
            type_start += 1;
        }

        var type_end = type_start;
        while (type_end < content.len and content[type_end] != ' ' and content[type_end] != '\t' and content[type_end] != '\n') {
            type_end += 1;
        }

        if (type_end == type_start) return false;

        const type_str = content[type_start..type_end];
        const box_type = parseMessageBoxType(type_str) orelse return false;

        // Check for title after type
        var title_start = type_end;
        while (title_start < content.len and (content[title_start] == ' ' or content[title_start] == '\t')) {
            title_start += 1;
        }
        const title: ?[]const u8 = if (title_start < content.len)
            try self.allocator.dupe(u8, content[title_start..])
        else
            null;

        try self.closeOpenBlocks();

        const msg_box = try Node.create(self.allocator, .message_box, .{
            .message_box = .{
                .box_type = box_type,
                .title = title,
            },
        });
        msg_box.pos = types.SourcePos.init(line.line_num, @intCast(line.indent + 1), line.start_offset);
        self.document.appendChild(msg_box);

        try self.open_blocks.append(self.allocator, msg_box);

        return true;
    }

    fn parseMessageBoxType(type_str: []const u8) ?types.MessageBoxType {
        if (std.ascii.eqlIgnoreCase(type_str, "note")) return .note;
        if (std.ascii.eqlIgnoreCase(type_str, "tip")) return .tip;
        if (std.ascii.eqlIgnoreCase(type_str, "info")) return .info;
        if (std.ascii.eqlIgnoreCase(type_str, "warning")) return .warning;
        if (std.ascii.eqlIgnoreCase(type_str, "danger")) return .danger;
        if (std.ascii.eqlIgnoreCase(type_str, "success")) return .success;
        if (std.ascii.eqlIgnoreCase(type_str, "question")) return .question;
        if (std.ascii.eqlIgnoreCase(type_str, "quote")) return .quote;
        if (std.ascii.eqlIgnoreCase(type_str, "caution")) return .caution;
        if (std.ascii.eqlIgnoreCase(type_str, "important")) return .important;
        return null;
    }

    /// Try to parse blockquote (> quote)
    fn tryBlockquote(self: *BlockParser, line: Line) !bool {
        const content = line.trimmed();
        if (content.len == 0 or content[0] != '>') return false;

        // Check if we're continuing an existing blockquote
        const current_block = self.currentOpenBlock();
        if (current_block.node_type != .blockquote) {
            try self.closeOpenBlocks();
            const bq = try Node.create(self.allocator, .blockquote, .{ .blockquote = {} });
            bq.pos = types.SourcePos.init(line.line_num, @intCast(line.indent + 1), line.start_offset);
            self.document.appendChild(bq);
            try self.open_blocks.append(self.allocator, bq);
        }

        // Extract content after >
        var text_start: usize = 1;
        if (text_start < content.len and (content[text_start] == ' ' or content[text_start] == '\t')) {
            text_start += 1;
        }

        if (text_start < content.len) {
            const quote_text = content[text_start..];
            // Add as paragraph within blockquote
            const para = try Node.create(self.allocator, .paragraph, .{ .paragraph = {} });
            const text_node = try Node.create(self.allocator, .text, .{ .text = .{ .content = try self.allocator.dupe(u8, quote_text) } });
            para.appendChild(text_node);
            self.currentOpenBlock().appendChild(para);
        }

        return true;
    }

    /// Try to parse list item (-, *, +, or 1.)
    fn tryListItem(self: *BlockParser, line: Line) !bool {
        const content = line.trimmed();
        if (content.len == 0) return false;

        var list_type: types.ListType = undefined;
        var marker_end: usize = 0;
        var start_num: u32 = 1;

        const first = content[0];
        if (first == '-' or first == '*' or first == '+') {
            // Bullet list
            if (content.len < 2 or (content[1] != ' ' and content[1] != '\t')) {
                return false;
            }
            list_type = .bullet;
            marker_end = 1;
        } else if (first >= '0' and first <= '9') {
            // Ordered list
            var num_end: usize = 0;
            while (num_end < content.len and content[num_end] >= '0' and content[num_end] <= '9') {
                num_end += 1;
            }
            if (num_end == 0 or num_end >= content.len) return false;
            if (content[num_end] != '.' and content[num_end] != ')') return false;
            if (num_end + 1 >= content.len or (content[num_end + 1] != ' ' and content[num_end + 1] != '\t')) {
                return false;
            }

            start_num = std.fmt.parseInt(u32, content[0..num_end], 10) catch return false;
            list_type = .ordered;
            marker_end = num_end + 1;
        } else {
            return false;
        }

        // Create or continue list
        const current_block = self.currentOpenBlock();
        var list_node: *Node = undefined;

        if (current_block.node_type == .list) {
            list_node = current_block;
        } else if (current_block.node_type == .list_item) {
            // We're inside a list item, check if parent is a list we can continue
            if (current_block.parent) |parent| {
                if (parent.node_type == .list) {
                    // Close the current list item and continue with the parent list
                    _ = self.open_blocks.pop();
                    list_node = parent;
                } else {
                    // Nested list case - create new list
                    list_node = try Node.create(self.allocator, .list, .{
                        .list = .{
                            .list_type = list_type,
                            .start = start_num,
                            .tight = true,
                        },
                    });
                    list_node.pos = types.SourcePos.init(line.line_num, @intCast(line.indent + 1), line.start_offset);
                    current_block.appendChild(list_node);
                    try self.open_blocks.append(self.allocator, list_node);
                }
            } else {
                // Orphan list item (shouldn't happen), create new list
                list_node = try Node.create(self.allocator, .list, .{
                    .list = .{
                        .list_type = list_type,
                        .start = start_num,
                        .tight = true,
                    },
                });
                list_node.pos = types.SourcePos.init(line.line_num, @intCast(line.indent + 1), line.start_offset);
                try self.closeOpenBlocks();
                self.document.appendChild(list_node);
                try self.open_blocks.append(self.allocator, list_node);
            }
        } else {
            // Create new list
            list_node = try Node.create(self.allocator, .list, .{
                .list = .{
                    .list_type = list_type,
                    .start = start_num,
                    .tight = true,
                },
            });
            list_node.pos = types.SourcePos.init(line.line_num, @intCast(line.indent + 1), line.start_offset);

            try self.closeOpenBlocks();
            self.document.appendChild(list_node);
            try self.open_blocks.append(self.allocator, list_node);
        }

        // Create list item
        var text_start = marker_end + 1;
        while (text_start < content.len and (content[text_start] == ' ' or content[text_start] == '\t')) {
            text_start += 1;
        }

        // Check for task list item
        var task_checked: ?bool = null;
        if (self.options.gfm and text_start + 3 <= content.len) {
            const checkbox = content[text_start..][0..3];
            if (std.mem.eql(u8, checkbox, "[ ]")) {
                task_checked = false;
                text_start += 3;
                while (text_start < content.len and content[text_start] == ' ') text_start += 1;
            } else if (std.mem.eql(u8, checkbox, "[x]") or std.mem.eql(u8, checkbox, "[X]")) {
                task_checked = true;
                text_start += 3;
                while (text_start < content.len and content[text_start] == ' ') text_start += 1;
            }
        }

        const item = try Node.create(self.allocator, .list_item, .{
            .list_item = .{ .task_checked = task_checked },
        });
        list_node.appendChild(item);
        try self.open_blocks.append(self.allocator, item);

        // Add content as paragraph
        if (text_start < content.len) {
            const item_text = content[text_start..];
            const para = try Node.create(self.allocator, .paragraph, .{ .paragraph = {} });
            const text_node = try Node.create(self.allocator, .text, .{ .text = .{ .content = try self.allocator.dupe(u8, item_text) } });
            para.appendChild(text_node);
            item.appendChild(para);
        }

        return true;
    }

    /// Try to parse HTML block
    fn tryHtmlBlock(self: *BlockParser, line: Line) !bool {
        if (!self.options.allow_html) return false;

        const content = line.trimmed();
        if (content.len == 0 or content[0] != '<') return false;

        // Simple check for HTML-like content
        // TODO: Full HTML block detection per CommonMark spec
        if (content.len > 1 and (content[1] == '!' or content[1] == '?' or std.ascii.isAlphabetic(content[1]) or content[1] == '/')) {
            try self.closeOpenBlocks();

            const html = try Node.create(self.allocator, .html_block, .{
                .html_block = .{ .content = try self.allocator.dupe(u8, content) },
            });
            html.pos = types.SourcePos.init(line.line_num, @intCast(line.indent + 1), line.start_offset);
            self.document.appendChild(html);

            return true;
        }

        return false;
    }

    /// Try to parse GFM table
    fn tryTable(self: *BlockParser, line: Line) !bool {
        if (!self.options.gfm) return false;

        const content = line.trimmed();

        // Tables must have at least one pipe
        if (std.mem.indexOf(u8, content, "|") == null) return false;

        // Peek at next line to check for delimiter row
        const next_line = self.scanner.peekLine() orelse return false;
        if (!isTableDelimiterRow(next_line.trimmed())) return false;

        try self.closeOpenBlocks();

        // Create table
        const table = try Node.create(self.allocator, .table, .{
            .table = .{
                .col_count = 0,
                .alignments = &.{},
            },
        });
        table.pos = types.SourcePos.init(line.line_num, @intCast(line.indent + 1), line.start_offset);
        self.document.appendChild(table);

        // Parse header row
        const header_row = try Node.create(self.allocator, .table_row, .{ .table_row = .{ .is_header = true } });
        table.appendChild(header_row);

        var cells = std.mem.splitScalar(u8, content, '|');
        while (cells.next()) |cell_content| {
            const trimmed = std.mem.trim(u8, cell_content, " \t");
            if (trimmed.len > 0 or cells.peek() != null) {
                const cell = try Node.create(self.allocator, .table_cell, .{
                    .table_cell = .{ .is_header = true },
                });
                if (trimmed.len > 0) {
                    const text = try Node.create(self.allocator, .text, .{ .text = .{ .content = try self.allocator.dupe(u8, trimmed) } });
                    cell.appendChild(text);
                }
                header_row.appendChild(cell);
            }
        }

        // Consume delimiter row
        _ = self.scanner.nextLine();

        // Parse data rows
        while (self.scanner.peekLine()) |data_line| {
            const data_content = data_line.trimmed();
            if (std.mem.indexOf(u8, data_content, "|") == null) break;

            _ = self.scanner.nextLine();

            const data_row = try Node.create(self.allocator, .table_row, .{ .table_row = .{ .is_header = false } });
            table.appendChild(data_row);

            var data_cells = std.mem.splitScalar(u8, data_content, '|');
            while (data_cells.next()) |cell_content| {
                const trimmed = std.mem.trim(u8, cell_content, " \t");
                if (trimmed.len > 0 or data_cells.peek() != null) {
                    const cell = try Node.create(self.allocator, .table_cell, .{
                        .table_cell = .{ .is_header = false },
                    });
                    if (trimmed.len > 0) {
                        const text = try Node.create(self.allocator, .text, .{ .text = .{ .content = try self.allocator.dupe(u8, trimmed) } });
                        cell.appendChild(text);
                    }
                    data_row.appendChild(cell);
                }
            }
        }

        return true;
    }

    fn isTableDelimiterRow(content: []const u8) bool {
        // Must have at least one pipe
        if (std.mem.indexOf(u8, content, "|") == null) return false;

        // Each cell must be: optional :, one or more -, optional :
        var cells = std.mem.splitScalar(u8, content, '|');
        var has_valid_cell = false;

        while (cells.next()) |cell| {
            const trimmed = std.mem.trim(u8, cell, " \t");
            if (trimmed.len == 0) continue;

            // Check pattern: :?-+:?
            var i: usize = 0;
            if (i < trimmed.len and trimmed[i] == ':') i += 1;

            var dash_count: usize = 0;
            while (i < trimmed.len and trimmed[i] == '-') {
                dash_count += 1;
                i += 1;
            }

            if (dash_count == 0) return false;

            if (i < trimmed.len and trimmed[i] == ':') i += 1;
            if (i != trimmed.len) return false;

            has_valid_cell = true;
        }

        return has_valid_cell;
    }

    /// Add paragraph (default block)
    fn addParagraph(self: *BlockParser, line: Line) !void {
        const content = line.trimmed();
        if (content.len == 0) return;

        // Check if we can append to existing paragraph
        const current = self.currentOpenBlock();
        if (current.node_type == .paragraph) {
            // Append text to existing paragraph
            if (current.last_child) |last_text| {
                if (last_text.node_type == .text) {
                    // Create new text node with space separator
                    const sep = try Node.create(self.allocator, .soft_break, .{ .soft_break = {} });
                    current.appendChild(sep);
                }
            }
            const text = try Node.create(self.allocator, .text, .{ .text = .{ .content = try self.allocator.dupe(u8, content) } });
            current.appendChild(text);
        } else {
            // Create new paragraph
            const para = try Node.create(self.allocator, .paragraph, .{ .paragraph = {} });
            para.pos = types.SourcePos.init(line.line_num, @intCast(line.indent + 1), line.start_offset);

            const text = try Node.create(self.allocator, .text, .{ .text = .{ .content = try self.allocator.dupe(u8, content) } });
            para.appendChild(text);

            self.document.appendChild(para);
            try self.open_blocks.append(self.allocator, para);
        }
    }

    fn currentOpenBlock(self: *BlockParser) *Node {
        return self.open_blocks.items[self.open_blocks.items.len - 1];
    }

    fn closeOpenBlocks(self: *BlockParser) !void {
        while (self.open_blocks.items.len > 1) {
            _ = self.open_blocks.pop();
        }
    }

    fn finalizeDocument(self: *BlockParser) !void {
        try self.closeOpenBlocks();
    }
};

// Tests
test "parse ATX heading" {
    const allocator = std.testing.allocator;

    var parser = try BlockParser.init(allocator, "# Heading 1\n## Heading 2", .{});
    defer parser.deinit();

    const doc = try parser.parse();
    defer doc.deinit();

    try std.testing.expectEqual(@as(usize, 2), doc.childCount());

    const h1 = doc.first_child.?;
    try std.testing.expectEqual(NodeType.heading, h1.node_type);
    try std.testing.expectEqual(@as(u8, 1), h1.data.heading.level);
}

test "parse thematic break" {
    const allocator = std.testing.allocator;

    var parser = try BlockParser.init(allocator, "---\n***\n___", .{});
    defer parser.deinit();

    const doc = try parser.parse();
    defer doc.deinit();

    try std.testing.expectEqual(@as(usize, 3), doc.childCount());

    var child = doc.first_child;
    while (child) |c| {
        try std.testing.expectEqual(NodeType.thematic_break, c.node_type);
        child = c.next;
    }
}

test "parse fenced code block" {
    const allocator = std.testing.allocator;

    var parser = try BlockParser.init(allocator, "```javascript\nconsole.log('hi');\n```", .{});
    defer parser.deinit();

    const doc = try parser.parse();
    defer doc.deinit();

    try std.testing.expectEqual(@as(usize, 1), doc.childCount());

    const code = doc.first_child.?;
    try std.testing.expectEqual(NodeType.fenced_code, code.node_type);
    try std.testing.expectEqualStrings("javascript", code.data.fenced_code.info.?);
}

test "parse list" {
    const allocator = std.testing.allocator;

    var parser = try BlockParser.init(allocator, "- Item 1\n- Item 2\n- Item 3", .{});
    defer parser.deinit();

    const doc = try parser.parse();
    defer doc.deinit();

    const list = doc.first_child.?;
    try std.testing.expectEqual(NodeType.list, list.node_type);
    try std.testing.expectEqual(types.ListType.bullet, list.data.list.list_type);
    try std.testing.expectEqual(@as(usize, 3), list.childCount());
}

test "parse message box" {
    const allocator = std.testing.allocator;

    var parser = try BlockParser.init(allocator, ":::note Custom Title\nContent here\n:::", .{});
    defer parser.deinit();

    const doc = try parser.parse();
    defer doc.deinit();

    const msg = doc.first_child.?;
    try std.testing.expectEqual(NodeType.message_box, msg.node_type);
    try std.testing.expectEqual(types.MessageBoxType.note, msg.data.message_box.box_type);
}
