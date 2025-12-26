//! Language Definitions for Syntax Highlighting
//!
//! Provides grammar definitions for various programming languages.
//! Each language defines keywords, operators, and highlighting rules.

const std = @import("std");
const tokens = @import("tokens.zig");
const TokenType = tokens.TokenType;

/// Language identifier
pub const LanguageId = enum(u8) {
    plain = 0,
    zig = 1,
    javascript = 2,
    typescript = 3,
    python = 4,
    rust = 5,
    c = 6,
    cpp = 7,
    go = 8,
    java = 9,
    markdown = 10,
    json = 11,
    yaml = 12,
    html = 13,
    css = 14,
    sql = 15,
    bash = 16,
    toml = 17,

    /// Get language name
    pub fn name(self: LanguageId) []const u8 {
        return switch (self) {
            .plain => "Plain Text",
            .zig => "Zig",
            .javascript => "JavaScript",
            .typescript => "TypeScript",
            .python => "Python",
            .rust => "Rust",
            .c => "C",
            .cpp => "C++",
            .go => "Go",
            .java => "Java",
            .markdown => "Markdown",
            .json => "JSON",
            .yaml => "YAML",
            .html => "HTML",
            .css => "CSS",
            .sql => "SQL",
            .bash => "Bash",
            .toml => "TOML",
        };
    }

    /// Get file extensions for this language
    pub fn extensions(self: LanguageId) []const []const u8 {
        return switch (self) {
            .plain => &.{".txt"},
            .zig => &.{".zig"},
            .javascript => &.{ ".js", ".mjs", ".cjs" },
            .typescript => &.{ ".ts", ".tsx" },
            .python => &.{ ".py", ".pyw" },
            .rust => &.{".rs"},
            .c => &.{ ".c", ".h" },
            .cpp => &.{ ".cpp", ".cxx", ".cc", ".hpp", ".hxx", ".hh" },
            .go => &.{".go"},
            .java => &.{".java"},
            .markdown => &.{ ".md", ".markdown" },
            .json => &.{".json"},
            .yaml => &.{ ".yaml", ".yml" },
            .html => &.{ ".html", ".htm" },
            .css => &.{".css"},
            .sql => &.{".sql"},
            .bash => &.{ ".sh", ".bash" },
            .toml => &.{".toml"},
        };
    }
};

/// Keyword category
pub const KeywordCategory = enum(u8) {
    control,
    type_keyword,
    modifier,
    operator,
    literal,
    other,
};

/// Keyword definition
pub const KeywordDef = struct {
    word: []const u8,
    token_type: TokenType,
    category: KeywordCategory,
};

/// Comment style
pub const CommentStyle = struct {
    line_prefix: ?[]const u8 = null,
    block_start: ?[]const u8 = null,
    block_end: ?[]const u8 = null,
    doc_prefix: ?[]const u8 = null,
    nested_blocks: bool = false,
};

/// String style
pub const StringStyle = struct {
    single_quote: bool = true,
    double_quote: bool = true,
    backtick: bool = false, // Template literals
    multiline: bool = false,
    escape_char: u8 = '\\',
    raw_prefix: ?[]const u8 = null, // r"..." for raw strings
};

/// Number style
pub const NumberStyle = struct {
    decimal: bool = true,
    hex_prefix: ?[]const u8 = "0x",
    binary_prefix: ?[]const u8 = "0b",
    octal_prefix: ?[]const u8 = "0o",
    float_suffix: bool = true,
    underscore_separator: bool = false,
};

/// Language grammar definition
pub const LanguageGrammar = struct {
    id: LanguageId,
    keywords: []const KeywordDef,
    operators: []const u8,
    comment_style: CommentStyle,
    string_style: StringStyle,
    number_style: NumberStyle,
    builtin_prefix: ?[]const u8,
    case_sensitive: bool,

    /// Check if a character is an operator
    pub fn isOperatorChar(self: *const LanguageGrammar, c: u8) bool {
        for (self.operators) |op| {
            if (op == c) return true;
        }
        return false;
    }

    /// Find keyword token type
    pub fn lookupKeyword(self: *const LanguageGrammar, word: []const u8) ?TokenType {
        for (self.keywords) |kw| {
            if (self.case_sensitive) {
                if (std.mem.eql(u8, kw.word, word)) return kw.token_type;
            } else {
                if (std.ascii.eqlIgnoreCase(kw.word, word)) return kw.token_type;
            }
        }
        return null;
    }
};

/// Zig language keywords
pub const zig_keywords = [_]KeywordDef{
    // Control flow
    .{ .word = "if", .token_type = .keyword_control, .category = .control },
    .{ .word = "else", .token_type = .keyword_control, .category = .control },
    .{ .word = "while", .token_type = .keyword_control, .category = .control },
    .{ .word = "for", .token_type = .keyword_control, .category = .control },
    .{ .word = "return", .token_type = .keyword_control, .category = .control },
    .{ .word = "break", .token_type = .keyword_control, .category = .control },
    .{ .word = "continue", .token_type = .keyword_control, .category = .control },
    .{ .word = "switch", .token_type = .keyword_control, .category = .control },
    .{ .word = "defer", .token_type = .keyword_control, .category = .control },
    .{ .word = "errdefer", .token_type = .keyword_control, .category = .control },
    .{ .word = "try", .token_type = .keyword_control, .category = .control },
    .{ .word = "catch", .token_type = .keyword_operator, .category = .operator },
    .{ .word = "orelse", .token_type = .keyword_operator, .category = .operator },
    .{ .word = "unreachable", .token_type = .keyword_control, .category = .control },
    .{ .word = "async", .token_type = .keyword_control, .category = .control },
    .{ .word = "await", .token_type = .keyword_control, .category = .control },
    .{ .word = "suspend", .token_type = .keyword_control, .category = .control },
    .{ .word = "resume", .token_type = .keyword_control, .category = .control },

    // Type keywords
    .{ .word = "fn", .token_type = .keyword_type, .category = .type_keyword },
    .{ .word = "struct", .token_type = .keyword_type, .category = .type_keyword },
    .{ .word = "enum", .token_type = .keyword_type, .category = .type_keyword },
    .{ .word = "union", .token_type = .keyword_type, .category = .type_keyword },
    .{ .word = "error", .token_type = .keyword_type, .category = .type_keyword },
    .{ .word = "const", .token_type = .keyword_type, .category = .type_keyword },
    .{ .word = "var", .token_type = .keyword_type, .category = .type_keyword },
    .{ .word = "type", .token_type = .keyword_type, .category = .type_keyword },
    .{ .word = "opaque", .token_type = .keyword_type, .category = .type_keyword },
    .{ .word = "anytype", .token_type = .keyword_type, .category = .type_keyword },

    // Modifiers
    .{ .word = "pub", .token_type = .keyword_modifier, .category = .modifier },
    .{ .word = "extern", .token_type = .keyword_modifier, .category = .modifier },
    .{ .word = "export", .token_type = .keyword_modifier, .category = .modifier },
    .{ .word = "inline", .token_type = .keyword_modifier, .category = .modifier },
    .{ .word = "noinline", .token_type = .keyword_modifier, .category = .modifier },
    .{ .word = "comptime", .token_type = .keyword_modifier, .category = .modifier },
    .{ .word = "volatile", .token_type = .keyword_modifier, .category = .modifier },
    .{ .word = "align", .token_type = .keyword_modifier, .category = .modifier },
    .{ .word = "packed", .token_type = .keyword_modifier, .category = .modifier },
    .{ .word = "threadlocal", .token_type = .keyword_modifier, .category = .modifier },
    .{ .word = "linksection", .token_type = .keyword_modifier, .category = .modifier },
    .{ .word = "callconv", .token_type = .keyword_modifier, .category = .modifier },
    .{ .word = "noalias", .token_type = .keyword_modifier, .category = .modifier },
    .{ .word = "allowzero", .token_type = .keyword_modifier, .category = .modifier },

    // Operators as keywords
    .{ .word = "and", .token_type = .keyword_operator, .category = .operator },
    .{ .word = "or", .token_type = .keyword_operator, .category = .operator },

    // Literals
    .{ .word = "true", .token_type = .boolean, .category = .literal },
    .{ .word = "false", .token_type = .boolean, .category = .literal },
    .{ .word = "null", .token_type = .null_value, .category = .literal },
    .{ .word = "undefined", .token_type = .null_value, .category = .literal },

    // Other
    .{ .word = "test", .token_type = .keyword, .category = .other },
    .{ .word = "usingnamespace", .token_type = .keyword, .category = .other },
    .{ .word = "asm", .token_type = .keyword, .category = .other },
};

/// JavaScript language keywords
pub const javascript_keywords = [_]KeywordDef{
    // Control flow
    .{ .word = "if", .token_type = .keyword_control, .category = .control },
    .{ .word = "else", .token_type = .keyword_control, .category = .control },
    .{ .word = "while", .token_type = .keyword_control, .category = .control },
    .{ .word = "for", .token_type = .keyword_control, .category = .control },
    .{ .word = "return", .token_type = .keyword_control, .category = .control },
    .{ .word = "break", .token_type = .keyword_control, .category = .control },
    .{ .word = "continue", .token_type = .keyword_control, .category = .control },
    .{ .word = "switch", .token_type = .keyword_control, .category = .control },
    .{ .word = "case", .token_type = .keyword_control, .category = .control },
    .{ .word = "default", .token_type = .keyword_control, .category = .control },
    .{ .word = "try", .token_type = .keyword_control, .category = .control },
    .{ .word = "catch", .token_type = .keyword_control, .category = .control },
    .{ .word = "finally", .token_type = .keyword_control, .category = .control },
    .{ .word = "throw", .token_type = .keyword_control, .category = .control },
    .{ .word = "async", .token_type = .keyword_control, .category = .control },
    .{ .word = "await", .token_type = .keyword_control, .category = .control },
    .{ .word = "yield", .token_type = .keyword_control, .category = .control },

    // Declarations
    .{ .word = "const", .token_type = .keyword_type, .category = .type_keyword },
    .{ .word = "let", .token_type = .keyword_type, .category = .type_keyword },
    .{ .word = "var", .token_type = .keyword_type, .category = .type_keyword },
    .{ .word = "function", .token_type = .keyword_type, .category = .type_keyword },
    .{ .word = "class", .token_type = .keyword_type, .category = .type_keyword },

    // Modifiers
    .{ .word = "export", .token_type = .keyword_modifier, .category = .modifier },
    .{ .word = "import", .token_type = .keyword_modifier, .category = .modifier },
    .{ .word = "from", .token_type = .keyword_modifier, .category = .modifier },
    .{ .word = "extends", .token_type = .keyword_modifier, .category = .modifier },
    .{ .word = "static", .token_type = .keyword_modifier, .category = .modifier },
    .{ .word = "new", .token_type = .keyword_modifier, .category = .modifier },

    // Operators
    .{ .word = "typeof", .token_type = .keyword_operator, .category = .operator },
    .{ .word = "instanceof", .token_type = .keyword_operator, .category = .operator },
    .{ .word = "in", .token_type = .keyword_operator, .category = .operator },
    .{ .word = "of", .token_type = .keyword_operator, .category = .operator },
    .{ .word = "delete", .token_type = .keyword_operator, .category = .operator },
    .{ .word = "void", .token_type = .keyword_operator, .category = .operator },

    // Literals
    .{ .word = "true", .token_type = .boolean, .category = .literal },
    .{ .word = "false", .token_type = .boolean, .category = .literal },
    .{ .word = "null", .token_type = .null_value, .category = .literal },
    .{ .word = "undefined", .token_type = .null_value, .category = .literal },
    .{ .word = "NaN", .token_type = .number, .category = .literal },
    .{ .word = "Infinity", .token_type = .number, .category = .literal },

    // Other
    .{ .word = "this", .token_type = .keyword, .category = .other },
    .{ .word = "super", .token_type = .keyword, .category = .other },
    .{ .word = "debugger", .token_type = .keyword, .category = .other },
    .{ .word = "with", .token_type = .keyword, .category = .other },
};

/// Zig language grammar
pub const zig_grammar = LanguageGrammar{
    .id = .zig,
    .keywords = &zig_keywords,
    .operators = "+-*/%=<>!&|^~?@.,:;()[]{}",
    .comment_style = .{
        .line_prefix = "//",
        .block_start = null,
        .block_end = null,
        .doc_prefix = "///",
    },
    .string_style = .{
        .single_quote = true,
        .double_quote = true,
        .backtick = false,
        .multiline = true,
        .escape_char = '\\',
        .raw_prefix = null,
    },
    .number_style = .{
        .decimal = true,
        .hex_prefix = "0x",
        .binary_prefix = "0b",
        .octal_prefix = "0o",
        .float_suffix = true,
        .underscore_separator = true,
    },
    .builtin_prefix = "@",
    .case_sensitive = true,
};

/// JavaScript language grammar
pub const javascript_grammar = LanguageGrammar{
    .id = .javascript,
    .keywords = &javascript_keywords,
    .operators = "+-*/%=<>!&|^~?.:;()[]{}",
    .comment_style = .{
        .line_prefix = "//",
        .block_start = "/*",
        .block_end = "*/",
        .doc_prefix = "/**",
    },
    .string_style = .{
        .single_quote = true,
        .double_quote = true,
        .backtick = true,
        .multiline = true,
        .escape_char = '\\',
        .raw_prefix = null,
    },
    .number_style = .{
        .decimal = true,
        .hex_prefix = "0x",
        .binary_prefix = "0b",
        .octal_prefix = "0o",
        .float_suffix = true,
        .underscore_separator = true,
    },
    .builtin_prefix = null,
    .case_sensitive = true,
};

/// Plain text grammar (no highlighting)
pub const plain_grammar = LanguageGrammar{
    .id = .plain,
    .keywords = &.{},
    .operators = "",
    .comment_style = .{},
    .string_style = .{
        .single_quote = false,
        .double_quote = false,
        .backtick = false,
        .multiline = false,
    },
    .number_style = .{
        .decimal = false,
    },
    .builtin_prefix = null,
    .case_sensitive = true,
};

/// Get grammar for a language
pub fn getGrammar(lang: LanguageId) *const LanguageGrammar {
    return switch (lang) {
        .zig => &zig_grammar,
        .javascript, .typescript => &javascript_grammar,
        else => &plain_grammar,
    };
}

/// Detect language from file extension
pub fn detectLanguage(filename: []const u8) LanguageId {
    const ext_start = std.mem.lastIndexOfScalar(u8, filename, '.');
    if (ext_start == null) return .plain;

    const ext = filename[ext_start.?..];

    // Check each language
    inline for (std.meta.fields(LanguageId)) |field| {
        const lang_id: LanguageId = @enumFromInt(field.value);
        for (lang_id.extensions()) |lang_ext| {
            if (std.ascii.eqlIgnoreCase(ext, lang_ext)) {
                return lang_id;
            }
        }
    }

    return .plain;
}

// Tests
test "LanguageId properties" {
    try std.testing.expect(std.mem.eql(u8, "Zig", LanguageId.zig.name()));
    try std.testing.expect(LanguageId.zig.extensions()[0][0] == '.');
}

test "Keyword lookup" {
    const kw = zig_grammar.lookupKeyword("if");
    try std.testing.expect(kw != null);
    try std.testing.expectEqual(TokenType.keyword_control, kw.?);

    const not_kw = zig_grammar.lookupKeyword("notakeyword");
    try std.testing.expect(not_kw == null);
}

test "Operator detection" {
    try std.testing.expect(zig_grammar.isOperatorChar('+'));
    try std.testing.expect(zig_grammar.isOperatorChar('@'));
    try std.testing.expect(!zig_grammar.isOperatorChar('a'));
}

test "Language detection" {
    try std.testing.expectEqual(LanguageId.zig, detectLanguage("main.zig"));
    try std.testing.expectEqual(LanguageId.javascript, detectLanguage("app.js"));
    try std.testing.expectEqual(LanguageId.plain, detectLanguage("README"));
}
