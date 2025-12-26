//! Markdown AST Type Definitions
//!
//! Defines the node types and structures for representing parsed Markdown
//! as an Abstract Syntax Tree (AST).

const std = @import("std");

/// Maximum depth for nested blocks (prevents stack overflow)
pub const MAX_NESTING_DEPTH: usize = 32;

/// Node type enumeration for all Markdown elements
pub const NodeType = enum(u8) {
    // Document root
    document,

    // Block-level elements (CommonMark)
    paragraph,
    heading,
    blockquote,
    code_block,
    fenced_code,
    thematic_break,
    list,
    list_item,
    html_block,

    // Inline elements (CommonMark)
    text,
    soft_break,
    hard_break,
    emphasis,
    strong,
    code_span,
    link,
    image,
    html_inline,

    // GFM extensions
    strikethrough,
    table,
    table_row,
    table_cell,
    task_list_item,
    autolink,

    // Custom extensions
    message_box,
    accordion,
    accordion_item,
    math_inline,
    math_block,
    mermaid,
    footnote_ref,
    footnote_def,
    toc,
    highlight,
    superscript,
    subscript,
    definition_list,
    definition_term,
    definition_desc,
    abbr,
    wiki_link,
    emoji,
};

/// List type
pub const ListType = enum(u8) {
    bullet,
    ordered,
};

/// Heading level (1-6)
pub const HeadingLevel = u8;

/// Message box type for admonitions
pub const MessageBoxType = enum(u8) {
    note,
    tip,
    info,
    warning,
    danger,
    success,
    question,
    quote,
    caution,
    important,
};

/// Table cell alignment
pub const TableAlign = enum(u8) {
    none,
    left,
    center,
    right,
};

/// Source position in the original text
pub const SourcePos = struct {
    start_line: u32 = 0,
    start_col: u32 = 0,
    end_line: u32 = 0,
    end_col: u32 = 0,
    start_offset: u32 = 0,
    end_offset: u32 = 0,

    pub fn init(start_line: u32, start_col: u32, start_offset: u32) SourcePos {
        return .{
            .start_line = start_line,
            .start_col = start_col,
            .start_offset = start_offset,
            .end_line = start_line,
            .end_col = start_col,
            .end_offset = start_offset,
        };
    }

    pub fn extend(self: *SourcePos, end_line: u32, end_col: u32, end_offset: u32) void {
        self.end_line = end_line;
        self.end_col = end_col;
        self.end_offset = end_offset;
    }
};

/// Node attributes based on node type
pub const NodeData = union(NodeType) {
    document: void,
    paragraph: void,
    heading: struct {
        level: HeadingLevel,
        id: ?[]const u8 = null, // Auto-generated or explicit ID
    },
    blockquote: void,
    code_block: struct {
        content: []const u8,
    },
    fenced_code: struct {
        info: ?[]const u8 = null, // Language info string
        content: []const u8,
    },
    thematic_break: void,
    list: struct {
        list_type: ListType,
        start: u32 = 1, // Start number for ordered lists
        tight: bool = true,
    },
    list_item: struct {
        task_checked: ?bool = null, // null = not a task, true/false = checked state
    },
    html_block: struct {
        content: []const u8,
    },

    // Inline elements
    text: struct {
        content: []const u8,
    },
    soft_break: void,
    hard_break: void,
    emphasis: void,
    strong: void,
    code_span: struct {
        content: []const u8,
    },
    link: struct {
        url: []const u8,
        title: ?[]const u8 = null,
    },
    image: struct {
        url: []const u8,
        title: ?[]const u8 = null,
        alt: ?[]const u8 = null,
    },
    html_inline: struct {
        content: []const u8,
    },

    // GFM extensions
    strikethrough: void,
    table: struct {
        col_count: u16 = 0,
        alignments: []const TableAlign = &.{},
    },
    table_row: struct {
        is_header: bool = false,
    },
    table_cell: struct {
        alignment: TableAlign = .none,
        is_header: bool = false,
    },
    task_list_item: struct {
        checked: bool,
    },
    autolink: struct {
        url: []const u8,
        is_email: bool = false,
    },

    // Custom extensions
    message_box: struct {
        box_type: MessageBoxType,
        title: ?[]const u8 = null,
    },
    accordion: struct {
        open: bool = false,
    },
    accordion_item: struct {
        title: []const u8,
        open: bool = false,
    },
    math_inline: struct {
        content: []const u8,
    },
    math_block: struct {
        content: []const u8,
    },
    mermaid: struct {
        content: []const u8,
    },
    footnote_ref: struct {
        label: []const u8,
        index: u32 = 0,
    },
    footnote_def: struct {
        label: []const u8,
        index: u32 = 0,
    },
    toc: struct {
        max_level: u8 = 6,
        min_level: u8 = 1,
    },
    highlight: void,
    superscript: void,
    subscript: void,
    definition_list: void,
    definition_term: void,
    definition_desc: void,
    abbr: struct {
        abbr: []const u8,
        expansion: []const u8,
    },
    wiki_link: struct {
        target: []const u8,
        display: ?[]const u8 = null,
    },
    emoji: struct {
        shortcode: []const u8,
        unicode: ?[]const u8 = null,
    },

    pub fn getContent(self: NodeData) ?[]const u8 {
        return switch (self) {
            .text => |d| d.content,
            .code_span => |d| d.content,
            .code_block => |d| d.content,
            .fenced_code => |d| d.content,
            .html_block => |d| d.content,
            .html_inline => |d| d.content,
            .math_inline => |d| d.content,
            .math_block => |d| d.content,
            .mermaid => |d| d.content,
            else => null,
        };
    }
};

/// AST Node structure
pub const Node = struct {
    node_type: NodeType,
    data: NodeData,
    pos: SourcePos = .{},

    // Tree structure (intrusive linked list)
    parent: ?*Node = null,
    first_child: ?*Node = null,
    last_child: ?*Node = null,
    prev: ?*Node = null,
    next: ?*Node = null,

    allocator: std.mem.Allocator,

    pub fn create(allocator: std.mem.Allocator, node_type: NodeType, data: NodeData) !*Node {
        const node = try allocator.create(Node);
        node.* = .{
            .node_type = node_type,
            .data = data,
            .allocator = allocator,
        };
        return node;
    }

    pub fn deinit(self: *Node) void {
        // Recursively deinit children
        var child = self.first_child;
        while (child) |c| {
            const next = c.next;
            c.deinit();
            child = next;
        }

        // Free allocated content based on node type
        switch (self.data) {
            .text => |d| self.allocator.free(d.content),
            .code_block => |d| self.allocator.free(d.content),
            .fenced_code => |d| {
                self.allocator.free(d.content);
                if (d.info) |info| self.allocator.free(info);
            },
            .html_block => |d| self.allocator.free(d.content),
            .code_span => |d| self.allocator.free(d.content),
            .html_inline => |d| self.allocator.free(d.content),
            .math_inline => |d| self.allocator.free(d.content),
            .math_block => |d| self.allocator.free(d.content),
            .mermaid => |d| self.allocator.free(d.content),
            .link => |d| {
                self.allocator.free(d.url);
                if (d.title) |title| self.allocator.free(title);
            },
            .image => |d| {
                self.allocator.free(d.url);
                if (d.title) |title| self.allocator.free(title);
                if (d.alt) |alt| self.allocator.free(alt);
            },
            .autolink => |d| self.allocator.free(d.url),
            .heading => |d| {
                if (d.id) |id| self.allocator.free(id);
            },
            .message_box => |d| {
                if (d.title) |title| self.allocator.free(title);
            },
            .accordion_item => |d| self.allocator.free(d.title),
            .footnote_ref => |d| self.allocator.free(d.label),
            .footnote_def => |d| self.allocator.free(d.label),
            .abbr => |d| {
                self.allocator.free(d.abbr);
                self.allocator.free(d.expansion);
            },
            .wiki_link => |d| {
                self.allocator.free(d.target);
                if (d.display) |display| self.allocator.free(display);
            },
            .emoji => |d| {
                self.allocator.free(d.shortcode);
                if (d.unicode) |unicode| self.allocator.free(unicode);
            },
            else => {},
        }

        self.allocator.destroy(self);
    }

    pub fn appendChild(self: *Node, child: *Node) void {
        child.parent = self;
        child.prev = self.last_child;
        child.next = null;

        if (self.last_child) |last| {
            last.next = child;
        } else {
            self.first_child = child;
        }
        self.last_child = child;
    }

    pub fn prependChild(self: *Node, child: *Node) void {
        child.parent = self;
        child.prev = null;
        child.next = self.first_child;

        if (self.first_child) |first| {
            first.prev = child;
        } else {
            self.last_child = child;
        }
        self.first_child = child;
    }

    pub fn insertBefore(self: *Node, sibling: *Node) void {
        sibling.parent = self.parent;
        sibling.prev = self.prev;
        sibling.next = self;

        if (self.prev) |prev| {
            prev.next = sibling;
        } else if (self.parent) |parent| {
            parent.first_child = sibling;
        }
        self.prev = sibling;
    }

    pub fn unlink(self: *Node) void {
        if (self.prev) |prev| {
            prev.next = self.next;
        } else if (self.parent) |parent| {
            parent.first_child = self.next;
        }

        if (self.next) |next| {
            next.prev = self.prev;
        } else if (self.parent) |parent| {
            parent.last_child = self.prev;
        }

        self.parent = null;
        self.prev = null;
        self.next = null;
    }

    pub fn childCount(self: *const Node) usize {
        var count: usize = 0;
        var child = self.first_child;
        while (child) |c| {
            count += 1;
            child = c.next;
        }
        return count;
    }

    pub fn isBlock(self: *const Node) bool {
        return switch (self.node_type) {
            .document,
            .paragraph,
            .heading,
            .blockquote,
            .code_block,
            .fenced_code,
            .thematic_break,
            .list,
            .list_item,
            .html_block,
            .table,
            .table_row,
            .message_box,
            .accordion,
            .accordion_item,
            .math_block,
            .mermaid,
            .footnote_def,
            .toc,
            .definition_list,
            .definition_term,
            .definition_desc,
            => true,
            else => false,
        };
    }

    pub fn isInline(self: *const Node) bool {
        return !self.isBlock();
    }

    /// Iterator for children
    pub fn children(self: *const Node) ChildIterator {
        return .{ .current = self.first_child };
    }

    pub const ChildIterator = struct {
        current: ?*Node,

        pub fn next(self: *ChildIterator) ?*Node {
            const node = self.current orelse return null;
            self.current = node.next;
            return node;
        }
    };

    /// Depth-first traversal iterator
    pub fn walk(self: *Node) WalkIterator {
        return .{ .root = self, .current = self };
    }

    pub const WalkIterator = struct {
        root: *Node,
        current: ?*Node,

        pub fn next(self: *WalkIterator) ?*Node {
            const node = self.current orelse return null;

            // Try to go to first child
            if (node.first_child) |child| {
                self.current = child;
                return node;
            }

            // Try to go to next sibling
            if (node.next) |sibling| {
                self.current = sibling;
                return node;
            }

            // Go up to parent and find next sibling
            var parent = node.parent;
            while (parent) |p| {
                if (p == self.root) {
                    self.current = null;
                    return node;
                }
                if (p.next) |sibling| {
                    self.current = sibling;
                    return node;
                }
                parent = p.parent;
            }

            self.current = null;
            return node;
        }
    };
};

/// Parser options
pub const ParserOptions = struct {
    /// Enable GFM extensions (tables, strikethrough, autolinks, task lists)
    gfm: bool = true,
    /// Enable math syntax ($ for inline, $$ for block)
    math: bool = true,
    /// Enable mermaid diagrams (```mermaid)
    mermaid: bool = true,
    /// Enable message boxes (:::note, :::warning, etc.)
    message_boxes: bool = true,
    /// Enable accordion (:::accordion)
    accordion: bool = true,
    /// Enable footnotes
    footnotes: bool = true,
    /// Enable wiki-style links ([[link]])
    wiki_links: bool = true,
    /// Enable emoji shortcodes (:smile:)
    emoji: bool = true,
    /// Enable highlight syntax (==highlight==)
    highlight: bool = true,
    /// Enable super/subscript (^super^ and ~sub~)
    super_subscript: bool = true,
    /// Enable abbreviations
    abbreviations: bool = true,
    /// Enable definition lists
    definition_lists: bool = true,
    /// Enable table of contents ([[toc]])
    toc: bool = true,
    /// Enable smart punctuation (quotes, dashes)
    smart_punctuation: bool = false,
    /// Tab size for indentation
    tab_size: u8 = 4,
    /// Enable HTML blocks and inline HTML
    allow_html: bool = true,
    /// Enable hard line breaks on backslash before newline
    backslash_breaks: bool = true,
    /// Auto-generate heading IDs for linking
    heading_ids: bool = true,
};

/// Text edit for incremental parsing
pub const TextEdit = struct {
    start_offset: u32,
    end_offset: u32,
    new_text: []const u8,
};

/// Markdown error types
pub const MarkdownError = error{
    OutOfMemory,
    InvalidUtf8,
    NestingTooDeep,
    UnexpectedToken,
    ParseError,
    RenderError,
};

// Tests
test "node creation and tree operations" {
    const allocator = std.testing.allocator;

    const doc = try Node.create(allocator, .document, .{ .document = {} });
    defer doc.deinit();

    const para = try Node.create(allocator, .paragraph, .{ .paragraph = {} });
    doc.appendChild(para);

    const text = try Node.create(allocator, .text, .{ .text = .{ .content = try allocator.dupe(u8, "Hello") } });
    para.appendChild(text);

    try std.testing.expectEqual(@as(usize, 1), doc.childCount());
    try std.testing.expectEqual(@as(usize, 1), para.childCount());
    try std.testing.expect(para.parent == doc);
    try std.testing.expect(text.parent == para);
}

test "node type classification" {
    const allocator = std.testing.allocator;

    const para = try Node.create(allocator, .paragraph, .{ .paragraph = {} });
    defer para.deinit();
    try std.testing.expect(para.isBlock());
    try std.testing.expect(!para.isInline());

    const text = try Node.create(allocator, .text, .{ .text = .{ .content = try allocator.dupe(u8, "test") } });
    defer text.deinit();
    try std.testing.expect(!text.isBlock());
    try std.testing.expect(text.isInline());
}
