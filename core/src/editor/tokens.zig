//! Token Types for Syntax Highlighting
//!
//! Defines token categories, spans, and styling information for syntax highlighting.
//! Optimized for incremental highlighting with piece tree buffers.

const std = @import("std");

/// Token category for syntax highlighting
pub const TokenType = enum(u8) {
    // Basic types
    plain = 0,
    whitespace = 1,
    newline = 2,

    // Comments
    comment = 10,
    comment_line = 11,
    comment_block = 12,
    comment_doc = 13,

    // Keywords
    keyword = 20,
    keyword_control = 21, // if, else, while, for, return, break, continue
    keyword_type = 22, // fn, struct, enum, union, const, var
    keyword_modifier = 23, // pub, export, extern, inline, comptime
    keyword_operator = 24, // and, or, not, orelse, catch

    // Literals
    string = 30,
    string_escape = 31,
    string_interpolation = 32,
    character = 33,
    number = 34,
    number_float = 35,
    number_hex = 36,
    number_binary = 37,
    boolean = 38,
    null_value = 39,

    // Identifiers
    identifier = 40,
    identifier_type = 41, // Type names (capitalized)
    identifier_constant = 42, // Constants (ALL_CAPS)
    identifier_function = 43, // Function names
    identifier_parameter = 44, // Function parameters
    identifier_builtin = 45, // @import, @intCast, etc.

    // Operators
    operator = 50,
    operator_arithmetic = 51,
    operator_comparison = 52,
    operator_assignment = 53,
    operator_bitwise = 54,
    operator_logical = 55,

    // Punctuation
    punctuation = 60,
    punctuation_bracket = 61, // (), [], {}
    punctuation_delimiter = 62, // ,, ;, :
    punctuation_accessor = 63, // ., .*, .?

    // Special
    preprocessor = 70, // #include, #define (for C/C++)
    attribute = 71, // @..., [[...]]
    label = 72, // Labels for goto/break/continue
    embedded = 73, // Embedded language content

    // Semantic tokens (LSP-compatible)
    namespace = 80,
    class = 81,
    interface = 82,
    struct_type = 83,
    enum_type = 84,
    enum_member = 85,
    type_parameter = 86,
    macro = 87,
    property = 88,
    event = 89,
    method = 90,
    decorator = 91,
    regexp = 92,

    // Errors
    invalid = 253,
    error_token = 254,
    unknown = 255,

    pub fn isComment(self: TokenType) bool {
        return @intFromEnum(self) >= 10 and @intFromEnum(self) <= 13;
    }

    pub fn isKeyword(self: TokenType) bool {
        return @intFromEnum(self) >= 20 and @intFromEnum(self) <= 24;
    }

    pub fn isLiteral(self: TokenType) bool {
        return @intFromEnum(self) >= 30 and @intFromEnum(self) <= 39;
    }

    pub fn isIdentifier(self: TokenType) bool {
        return @intFromEnum(self) >= 40 and @intFromEnum(self) <= 45;
    }

    pub fn isOperator(self: TokenType) bool {
        return @intFromEnum(self) >= 50 and @intFromEnum(self) <= 55;
    }

    pub fn isPunctuation(self: TokenType) bool {
        return @intFromEnum(self) >= 60 and @intFromEnum(self) <= 63;
    }
};

/// Token modifier flags (can be combined)
pub const TokenModifier = packed struct {
    declaration: bool = false,
    definition: bool = false,
    readonly: bool = false,
    static: bool = false,
    deprecated: bool = false,
    abstract: bool = false,
    async_mod: bool = false,
    documentation: bool = false,
    default_library: bool = false,
    modification: bool = false, // For tracking changes
    _padding: u6 = 0,

    pub fn toInt(self: TokenModifier) u16 {
        return @bitCast(self);
    }

    pub fn fromInt(value: u16) TokenModifier {
        return @bitCast(value);
    }
};

/// A highlighted span in the text
pub const TokenSpan = struct {
    /// Start offset in the text
    start: u32,
    /// Length of the span
    length: u16,
    /// Token type
    token_type: TokenType,
    /// Optional modifiers
    modifiers: TokenModifier = .{},

    pub fn end(self: TokenSpan) u32 {
        return self.start + self.length;
    }

    pub fn overlaps(self: TokenSpan, other: TokenSpan) bool {
        return self.start < other.end() and other.start < self.end();
    }

    pub fn contains(self: TokenSpan, offset: u32) bool {
        return offset >= self.start and offset < self.end();
    }
};

/// Line token cache for incremental highlighting
pub const LineTokens = struct {
    /// Line number (0-indexed)
    line: u32,
    /// Tokens on this line
    tokens: []TokenSpan,
    /// End state hash for incremental parsing
    end_state: u32,
    /// Whether this line needs rehighlighting
    dirty: bool,

    pub fn init(line: u32, tokens: []TokenSpan, end_state: u32) LineTokens {
        return .{
            .line = line,
            .tokens = tokens,
            .end_state = end_state,
            .dirty = false,
        };
    }
};

/// Token scope for nested structures
pub const TokenScope = struct {
    /// Scope type (e.g., "string.quoted", "comment.block")
    scope: []const u8,
    /// Start offset
    start: u32,
    /// Nesting depth
    depth: u16,

    pub fn isNested(self: TokenScope, other: TokenScope) bool {
        return self.depth < other.depth and
            std.mem.startsWith(u8, other.scope, self.scope);
    }
};

/// Color representation for styling
pub const Color = packed struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,

    pub fn fromHex(hex: u32) Color {
        return .{
            .r = @truncate((hex >> 16) & 0xFF),
            .g = @truncate((hex >> 8) & 0xFF),
            .b = @truncate(hex & 0xFF),
            .a = 255,
        };
    }

    pub fn toHex(self: Color) u32 {
        return (@as(u32, self.r) << 16) | (@as(u32, self.g) << 8) | @as(u32, self.b);
    }
};

/// Text style for rendering
pub const TextStyle = struct {
    foreground: ?Color = null,
    background: ?Color = null,
    bold: bool = false,
    italic: bool = false,
    underline: bool = false,
    strikethrough: bool = false,
};

/// Theme definition for syntax colors
pub const Theme = struct {
    name: []const u8,
    styles: std.AutoHashMapUnmanaged(TokenType, TextStyle),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) Theme {
        return .{
            .name = name,
            .styles = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Theme) void {
        self.styles.deinit(self.allocator);
    }

    pub fn setStyle(self: *Theme, token_type: TokenType, style: TextStyle) !void {
        try self.styles.put(self.allocator, token_type, style);
    }

    pub fn getStyle(self: *const Theme, token_type: TokenType) ?TextStyle {
        return self.styles.get(token_type);
    }

    /// Create default dark theme
    pub fn defaultDark(allocator: std.mem.Allocator) !Theme {
        var theme = Theme.init(allocator, "default-dark");
        errdefer theme.deinit();

        try theme.setStyle(.plain, .{ .foreground = Color.fromHex(0xD4D4D4) });
        try theme.setStyle(.comment, .{ .foreground = Color.fromHex(0x6A9955), .italic = true });
        try theme.setStyle(.keyword, .{ .foreground = Color.fromHex(0x569CD6) });
        try theme.setStyle(.keyword_control, .{ .foreground = Color.fromHex(0xC586C0) });
        try theme.setStyle(.string, .{ .foreground = Color.fromHex(0xCE9178) });
        try theme.setStyle(.number, .{ .foreground = Color.fromHex(0xB5CEA8) });
        try theme.setStyle(.identifier_function, .{ .foreground = Color.fromHex(0xDCDCAA) });
        try theme.setStyle(.identifier_type, .{ .foreground = Color.fromHex(0x4EC9B0) });
        try theme.setStyle(.identifier_builtin, .{ .foreground = Color.fromHex(0xD7BA7D) });
        try theme.setStyle(.operator, .{ .foreground = Color.fromHex(0xD4D4D4) });
        try theme.setStyle(.punctuation, .{ .foreground = Color.fromHex(0xD4D4D4) });

        return theme;
    }

    /// Create default light theme
    pub fn defaultLight(allocator: std.mem.Allocator) !Theme {
        var theme = Theme.init(allocator, "default-light");
        errdefer theme.deinit();

        try theme.setStyle(.plain, .{ .foreground = Color.fromHex(0x000000) });
        try theme.setStyle(.comment, .{ .foreground = Color.fromHex(0x008000), .italic = true });
        try theme.setStyle(.keyword, .{ .foreground = Color.fromHex(0x0000FF) });
        try theme.setStyle(.keyword_control, .{ .foreground = Color.fromHex(0xAF00DB) });
        try theme.setStyle(.string, .{ .foreground = Color.fromHex(0xA31515) });
        try theme.setStyle(.number, .{ .foreground = Color.fromHex(0x098658) });
        try theme.setStyle(.identifier_function, .{ .foreground = Color.fromHex(0x795E26) });
        try theme.setStyle(.identifier_type, .{ .foreground = Color.fromHex(0x267F99) });
        try theme.setStyle(.identifier_builtin, .{ .foreground = Color.fromHex(0x811F3F) });
        try theme.setStyle(.operator, .{ .foreground = Color.fromHex(0x000000) });
        try theme.setStyle(.punctuation, .{ .foreground = Color.fromHex(0x000000) });

        return theme;
    }
};

// Tests
test "TokenType classification" {
    try std.testing.expect(TokenType.comment.isComment());
    try std.testing.expect(TokenType.comment_line.isComment());
    try std.testing.expect(TokenType.comment_block.isComment());
    try std.testing.expect(!TokenType.keyword.isComment());

    try std.testing.expect(TokenType.keyword.isKeyword());
    try std.testing.expect(TokenType.keyword_control.isKeyword());
    try std.testing.expect(!TokenType.string.isKeyword());

    try std.testing.expect(TokenType.string.isLiteral());
    try std.testing.expect(TokenType.number.isLiteral());
    try std.testing.expect(!TokenType.keyword.isLiteral());
}

test "TokenSpan operations" {
    const span1 = TokenSpan{ .start = 10, .length = 5, .token_type = .keyword };
    const span2 = TokenSpan{ .start = 12, .length = 8, .token_type = .string };
    const span3 = TokenSpan{ .start = 20, .length = 3, .token_type = .number };

    try std.testing.expect(span1.overlaps(span2));
    try std.testing.expect(!span1.overlaps(span3));
    try std.testing.expect(span1.contains(12));
    try std.testing.expect(!span1.contains(15));
    try std.testing.expectEqual(@as(u32, 15), span1.end());
}

test "TokenModifier packing" {
    var mods = TokenModifier{ .declaration = true, .readonly = true };
    const packed_val = mods.toInt();
    const unpacked = TokenModifier.fromInt(packed_val);
    try std.testing.expect(unpacked.declaration);
    try std.testing.expect(unpacked.readonly);
    try std.testing.expect(!unpacked.static);
}

test "Color operations" {
    const color = Color.fromHex(0xCE9178);
    try std.testing.expectEqual(@as(u8, 0xCE), color.r);
    try std.testing.expectEqual(@as(u8, 0x91), color.g);
    try std.testing.expectEqual(@as(u8, 0x78), color.b);
    try std.testing.expectEqual(@as(u32, 0xCE9178), color.toHex());
}

test "Theme creation" {
    const allocator = std.testing.allocator;
    var theme = try Theme.defaultDark(allocator);
    defer theme.deinit();

    const keyword_style = theme.getStyle(.keyword);
    try std.testing.expect(keyword_style != null);
}
