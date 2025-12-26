//! Editor Module
//!
//! Text editing infrastructure including syntax highlighting,
//! tokenization, and language support.
//!
//! ## Components
//!
//! - **tokens**: Token types and styling for syntax highlighting
//! - **languages**: Language grammar definitions
//! - **syntax**: Incremental syntax highlighting engine
//!
//! ## Example Usage
//!
//! ```zig
//! const editor = @import("editor");
//!
//! // Detect language from filename
//! const lang = editor.languages.detectLanguage("main.zig");
//!
//! // Create highlighter
//! var highlighter = editor.SyntaxHighlighter.init(allocator, lang);
//! defer highlighter.deinit();
//!
//! // Highlight a line
//! const tokens = try highlighter.highlightLine("const x = 42;", 0);
//! defer allocator.free(tokens);
//!
//! // Apply theme colors
//! var theme = try editor.Theme.defaultDark(allocator);
//! defer theme.deinit();
//!
//! for (tokens) |token| {
//!     if (theme.getStyle(token.token_type)) |style| {
//!         // Render with style.foreground, style.bold, etc.
//!     }
//! }
//! ```

const std = @import("std");

// Sub-modules
pub const tokens = @import("tokens.zig");
pub const languages = @import("languages.zig");
pub const syntax = @import("syntax.zig");

// Re-export main types for convenience

// Token types
pub const TokenType = tokens.TokenType;
pub const TokenModifier = tokens.TokenModifier;
pub const TokenSpan = tokens.TokenSpan;
pub const LineTokens = tokens.LineTokens;
pub const TokenScope = tokens.TokenScope;

// Styling
pub const Color = tokens.Color;
pub const TextStyle = tokens.TextStyle;
pub const Theme = tokens.Theme;

// Languages
pub const LanguageId = languages.LanguageId;
pub const LanguageGrammar = languages.LanguageGrammar;
pub const KeywordDef = languages.KeywordDef;
pub const KeywordCategory = languages.KeywordCategory;
pub const CommentStyle = languages.CommentStyle;
pub const StringStyle = languages.StringStyle;
pub const NumberStyle = languages.NumberStyle;

// Syntax highlighting
pub const SyntaxHighlighter = syntax.SyntaxHighlighter;
pub const ScannerState = syntax.ScannerState;

// Convenience functions
pub const getGrammar = languages.getGrammar;
pub const detectLanguage = languages.detectLanguage;

/// Editor configuration options
pub const EditorConfig = struct {
    /// Tab width in spaces
    tab_width: u8 = 4,
    /// Insert spaces instead of tabs
    insert_spaces: bool = true,
    /// Enable word wrap
    word_wrap: bool = true,
    /// Wrap column (0 = viewport width)
    wrap_column: u32 = 0,
    /// Enable line numbers
    show_line_numbers: bool = true,
    /// Enable minimap
    show_minimap: bool = true,
    /// Enable bracket matching
    bracket_matching: bool = true,
    /// Enable auto-indent
    auto_indent: bool = true,
    /// Enable syntax highlighting
    syntax_highlighting: bool = true,
    /// Theme name
    theme: []const u8 = "default-dark",
    /// Font size in points
    font_size: f32 = 14.0,
    /// Font family
    font_family: []const u8 = "monospace",
    /// Cursor style
    cursor_style: CursorStyle = .line,
    /// Cursor blink rate in ms (0 = no blink)
    cursor_blink_rate: u32 = 530,
    /// Smooth scrolling
    smooth_scrolling: bool = true,
    /// Scroll speed multiplier
    scroll_speed: f32 = 1.0,
};

/// Cursor display style
pub const CursorStyle = enum(u8) {
    line,
    block,
    underline,
    line_thin,
    block_outline,
    underline_thin,
};

/// Selection mode
pub const SelectionMode = enum(u8) {
    none,
    character,
    word,
    line,
    block,
};

/// Text selection range
pub const Selection = struct {
    /// Anchor position (start of selection)
    anchor_line: u32,
    anchor_col: u32,
    /// Active position (cursor end of selection)
    active_line: u32,
    active_col: u32,
    /// Selection mode
    mode: SelectionMode = .character,

    pub fn isEmpty(self: Selection) bool {
        return self.anchor_line == self.active_line and
            self.anchor_col == self.active_col;
    }

    pub fn isReversed(self: Selection) bool {
        return self.anchor_line > self.active_line or
            (self.anchor_line == self.active_line and self.anchor_col > self.active_col);
    }

    pub fn normalize(self: Selection) Selection {
        if (self.isReversed()) {
            return .{
                .anchor_line = self.active_line,
                .anchor_col = self.active_col,
                .active_line = self.anchor_line,
                .active_col = self.anchor_col,
                .mode = self.mode,
            };
        }
        return self;
    }
};

/// Cursor position
pub const CursorPosition = struct {
    line: u32,
    column: u32,
    /// Preferred column for vertical movement
    preferred_column: u32 = 0,
};

/// Editor view state
pub const ViewState = struct {
    /// First visible line
    scroll_top: u32 = 0,
    /// Horizontal scroll offset
    scroll_left: u32 = 0,
    /// Viewport height in lines
    viewport_height: u32 = 0,
    /// Viewport width in characters
    viewport_width: u32 = 0,
    /// Current cursor position
    cursor: CursorPosition = .{ .line = 0, .column = 0 },
    /// Active selections
    selections: []Selection = &.{},

    pub fn visibleRange(self: ViewState) struct { start: u32, end: u32 } {
        return .{
            .start = self.scroll_top,
            .end = self.scroll_top + self.viewport_height,
        };
    }

    pub fn isLineVisible(self: ViewState, line: u32) bool {
        return line >= self.scroll_top and line < self.scroll_top + self.viewport_height;
    }
};

/// Edit operation for undo/redo
pub const EditOperation = struct {
    /// Start position
    start_line: u32,
    start_col: u32,
    /// End position (before edit)
    end_line: u32,
    end_col: u32,
    /// Deleted text
    old_text: []const u8,
    /// Inserted text
    new_text: []const u8,
    /// Timestamp
    timestamp: i64,
    /// Group ID for compound edits
    group_id: u32 = 0,
};

/// Bracket pair for matching
pub const BracketPair = struct {
    open: u8,
    close: u8,

    pub const PAIRS: []const BracketPair = &.{
        .{ .open = '(', .close = ')' },
        .{ .open = '[', .close = ']' },
        .{ .open = '{', .close = '}' },
    };

    pub fn findMatch(char: u8) ?BracketPair {
        for (PAIRS) |pair| {
            if (pair.open == char or pair.close == char) {
                return pair;
            }
        }
        return null;
    }

    pub fn isOpen(self: BracketPair, char: u8) bool {
        return char == self.open;
    }

    pub fn isClose(self: BracketPair, char: u8) bool {
        return char == self.close;
    }
};

// Tests
test "editor config defaults" {
    const config = EditorConfig{};
    try std.testing.expectEqual(@as(u8, 4), config.tab_width);
    try std.testing.expect(config.syntax_highlighting);
    try std.testing.expectEqual(CursorStyle.line, config.cursor_style);
}

test "selection operations" {
    const sel = Selection{
        .anchor_line = 5,
        .anchor_col = 10,
        .active_line = 3,
        .active_col = 5,
    };

    try std.testing.expect(!sel.isEmpty());
    try std.testing.expect(sel.isReversed());

    const normalized = sel.normalize();
    try std.testing.expectEqual(@as(u32, 3), normalized.anchor_line);
    try std.testing.expectEqual(@as(u32, 5), normalized.active_line);
}

test "view state visibility" {
    const view = ViewState{
        .scroll_top = 10,
        .viewport_height = 20,
    };

    try std.testing.expect(view.isLineVisible(15));
    try std.testing.expect(!view.isLineVisible(5));
    try std.testing.expect(!view.isLineVisible(35));

    const range = view.visibleRange();
    try std.testing.expectEqual(@as(u32, 10), range.start);
    try std.testing.expectEqual(@as(u32, 30), range.end);
}

test "bracket matching" {
    const pair = BracketPair.findMatch('(');
    try std.testing.expect(pair != null);
    try std.testing.expectEqual(@as(u8, '('), pair.?.open);
    try std.testing.expectEqual(@as(u8, ')'), pair.?.close);

    try std.testing.expect(pair.?.isOpen('('));
    try std.testing.expect(pair.?.isClose(')'));
    try std.testing.expect(!pair.?.isOpen(')'));

    try std.testing.expect(BracketPair.findMatch('x') == null);
}

test "module imports" {
    // Verify all sub-modules are accessible
    _ = tokens;
    _ = languages;
    _ = syntax;

    // Verify re-exports work
    try std.testing.expect(@TypeOf(TokenType.keyword) == TokenType);
    try std.testing.expect(@TypeOf(LanguageId.zig) == LanguageId);
}
