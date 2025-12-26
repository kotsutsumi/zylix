//! Syntax Highlighting Engine
//!
//! Provides incremental syntax highlighting for source code.
//! Optimized for piece tree text buffers with line-based caching.

const std = @import("std");
const tokens = @import("tokens.zig");
const languages = @import("languages.zig");

const TokenType = tokens.TokenType;
const TokenSpan = tokens.TokenSpan;
const TokenModifier = tokens.TokenModifier;
const LineTokens = tokens.LineTokens;
const LanguageId = languages.LanguageId;
const LanguageGrammar = languages.LanguageGrammar;
const KeywordCategory = languages.KeywordCategory;

/// Scanner state for incremental parsing
pub const ScannerState = struct {
    /// Current state ID (for multi-line constructs)
    state_id: u32 = 0,
    /// Nesting depth for brackets/blocks
    nesting_depth: u16 = 0,
    /// Active scope flags
    in_string: bool = false,
    in_comment: bool = false,
    in_block_comment: bool = false,
    string_char: u8 = 0,

    pub fn hash(self: ScannerState) u32 {
        var h: u32 = self.state_id;
        h = h *% 31 +% self.nesting_depth;
        h = h *% 31 +% @as(u32, @intFromBool(self.in_string));
        h = h *% 31 +% @as(u32, @intFromBool(self.in_comment));
        h = h *% 31 +% @as(u32, @intFromBool(self.in_block_comment));
        h = h *% 31 +% @as(u32, self.string_char);
        return h;
    }

    pub fn isClean(self: ScannerState) bool {
        return !self.in_string and !self.in_comment and !self.in_block_comment;
    }
};

/// Syntax highlighter with incremental support
pub const SyntaxHighlighter = struct {
    allocator: std.mem.Allocator,
    grammar: ?*const LanguageGrammar,
    language: LanguageId,

    /// Line token cache
    line_cache: std.AutoHashMap(u32, CachedLine),

    /// Current scanner state
    state: ScannerState,

    const CachedLine = struct {
        tokens: []TokenSpan,
        end_state: u32,
        version: u32,
    };

    pub fn init(allocator: std.mem.Allocator, language: LanguageId) SyntaxHighlighter {
        return .{
            .allocator = allocator,
            .grammar = languages.getGrammar(language),
            .language = language,
            .line_cache = std.AutoHashMap(u32, CachedLine).init(allocator),
            .state = .{},
        };
    }

    pub fn deinit(self: *SyntaxHighlighter) void {
        var iter = self.line_cache.valueIterator();
        while (iter.next()) |cached| {
            self.allocator.free(cached.tokens);
        }
        self.line_cache.deinit();
    }

    /// Set language for highlighting
    pub fn setLanguage(self: *SyntaxHighlighter, language: LanguageId) void {
        if (self.language != language) {
            self.language = language;
            self.grammar = languages.getGrammar(language);
            self.invalidateCache();
        }
    }

    /// Invalidate all cached lines
    pub fn invalidateCache(self: *SyntaxHighlighter) void {
        var iter = self.line_cache.valueIterator();
        while (iter.next()) |cached| {
            self.allocator.free(cached.tokens);
        }
        self.line_cache.clearRetainingCapacity();
        self.state = .{};
    }

    /// Invalidate cache from a specific line onwards
    pub fn invalidateFrom(self: *SyntaxHighlighter, line_num: u32) void {
        var to_remove: std.ArrayList(u32) = .{};
        defer to_remove.deinit(self.allocator);

        var iter = self.line_cache.iterator();
        while (iter.next()) |entry| {
            if (entry.key_ptr.* >= line_num) {
                self.allocator.free(entry.value_ptr.tokens);
                to_remove.append(self.allocator, entry.key_ptr.*) catch {};
            }
        }

        for (to_remove.items) |key| {
            _ = self.line_cache.remove(key);
        }
    }

    /// Highlight a single line
    pub fn highlightLine(self: *SyntaxHighlighter, line: []const u8, line_num: u32) ![]TokenSpan {
        // Check cache first
        if (self.line_cache.get(line_num)) |cached| {
            // Return copy of cached tokens
            const result = try self.allocator.alloc(TokenSpan, cached.tokens.len);
            @memcpy(result, cached.tokens);
            return result;
        }

        // Tokenize the line
        const result = try self.tokenizeLine(line, line_num);

        // Cache the result
        const cached_tokens = try self.allocator.alloc(TokenSpan, result.len);
        @memcpy(cached_tokens, result);

        try self.line_cache.put(line_num, .{
            .tokens = cached_tokens,
            .end_state = self.state.hash(),
            .version = 0,
        });

        return result;
    }

    /// Tokenize a line into token spans
    fn tokenizeLine(self: *SyntaxHighlighter, line: []const u8, line_num: u32) ![]TokenSpan {
        _ = line_num;

        var result: std.ArrayList(TokenSpan) = .{};
        errdefer result.deinit(self.allocator);

        if (self.grammar == null) {
            // No grammar - return plain text
            if (line.len > 0) {
                try result.append(self.allocator, .{
                    .start = 0,
                    .length = @intCast(@min(line.len, std.math.maxInt(u16))),
                    .token_type = .plain,
                });
            }
            return try result.toOwnedSlice(self.allocator);
        }

        const grammar = self.grammar.?;
        var pos: usize = 0;

        while (pos < line.len) {
            const start_pos = pos;

            // Handle multi-line state continuation
            if (self.state.in_block_comment) {
                if (self.scanBlockCommentEnd(line, &pos, grammar)) {
                    try result.append(self.allocator, .{
                        .start = @intCast(start_pos),
                        .length = @intCast(pos - start_pos),
                        .token_type = .comment_block,
                    });
                    self.state.in_block_comment = false;
                    continue;
                } else {
                    // Rest of line is comment
                    try result.append(self.allocator, .{
                        .start = @intCast(start_pos),
                        .length = @intCast(line.len - start_pos),
                        .token_type = .comment_block,
                    });
                    break;
                }
            }

            if (self.state.in_string) {
                if (self.scanStringEnd(line, &pos)) {
                    try result.append(self.allocator, .{
                        .start = @intCast(start_pos),
                        .length = @intCast(pos - start_pos),
                        .token_type = .string,
                    });
                    self.state.in_string = false;
                    continue;
                } else {
                    // Rest of line is string
                    try result.append(self.allocator, .{
                        .start = @intCast(start_pos),
                        .length = @intCast(line.len - start_pos),
                        .token_type = .string,
                    });
                    break;
                }
            }

            const c = line[pos];

            // Whitespace
            if (c == ' ' or c == '\t') {
                const ws_start = pos;
                while (pos < line.len and (line[pos] == ' ' or line[pos] == '\t')) {
                    pos += 1;
                }
                try result.append(self.allocator, .{
                    .start = @intCast(ws_start),
                    .length = @intCast(pos - ws_start),
                    .token_type = .whitespace,
                });
                continue;
            }

            // Line comment
            if (grammar.comment_style.line_prefix) |line_comment| {
                if (pos + line_comment.len <= line.len and
                    std.mem.eql(u8, line[pos..][0..line_comment.len], line_comment))
                {
                    try result.append(self.allocator, .{
                        .start = @intCast(pos),
                        .length = @intCast(line.len - pos),
                        .token_type = .comment_line,
                    });
                    break; // Rest of line is comment
                }
            }

            // Block comment start
            if (grammar.comment_style.block_start) |block_start| {
                if (pos + block_start.len <= line.len and
                    std.mem.eql(u8, line[pos..][0..block_start.len], block_start))
                {
                    pos += block_start.len;
                    self.state.in_block_comment = true;

                    // Check if block comment ends on same line
                    if (self.scanBlockCommentEnd(line, &pos, grammar)) {
                        try result.append(self.allocator, .{
                            .start = @intCast(start_pos),
                            .length = @intCast(pos - start_pos),
                            .token_type = .comment_block,
                        });
                        self.state.in_block_comment = false;
                    } else {
                        // Rest of line is comment
                        try result.append(self.allocator, .{
                            .start = @intCast(start_pos),
                            .length = @intCast(line.len - start_pos),
                            .token_type = .comment_block,
                        });
                        break;
                    }
                    continue;
                }
            }

            // String literal
            if (self.isStringStart(c, grammar)) {
                const string_start = pos;
                self.state.string_char = c;
                pos += 1;

                if (self.scanStringEnd(line, &pos)) {
                    try result.append(self.allocator, .{
                        .start = @intCast(string_start),
                        .length = @intCast(pos - string_start),
                        .token_type = .string,
                    });
                } else {
                    // Multi-line string
                    self.state.in_string = true;
                    try result.append(self.allocator, .{
                        .start = @intCast(string_start),
                        .length = @intCast(line.len - string_start),
                        .token_type = .string,
                    });
                    break;
                }
                continue;
            }

            // Number
            if (isDigit(c) or (c == '.' and pos + 1 < line.len and isDigit(line[pos + 1]))) {
                const num_start = pos;
                const token_type = self.scanNumber(line, &pos, grammar);
                try result.append(self.allocator, .{
                    .start = @intCast(num_start),
                    .length = @intCast(pos - num_start),
                    .token_type = token_type,
                });
                continue;
            }

            // Identifier or keyword
            if (isIdentifierStart(c)) {
                const ident_start = pos;
                while (pos < line.len and isIdentifierChar(line[pos])) {
                    pos += 1;
                }

                const ident = line[ident_start..pos];
                const token_type = self.classifyIdentifier(ident, grammar);

                try result.append(self.allocator, .{
                    .start = @intCast(ident_start),
                    .length = @intCast(pos - ident_start),
                    .token_type = token_type,
                });
                continue;
            }

            // Builtin (e.g., @import in Zig)
            if (c == '@' and pos + 1 < line.len and isIdentifierStart(line[pos + 1])) {
                const builtin_start = pos;
                pos += 1; // Skip @
                while (pos < line.len and isIdentifierChar(line[pos])) {
                    pos += 1;
                }
                try result.append(self.allocator, .{
                    .start = @intCast(builtin_start),
                    .length = @intCast(pos - builtin_start),
                    .token_type = .identifier_builtin,
                });
                continue;
            }

            // Operators and punctuation
            const op_result = self.scanOperator(line, &pos, grammar);
            try result.append(self.allocator, .{
                .start = @intCast(start_pos),
                .length = @intCast(pos - start_pos),
                .token_type = op_result,
            });
        }

        return try result.toOwnedSlice(self.allocator);
    }

    fn isStringStart(self: *SyntaxHighlighter, c: u8, grammar: *const LanguageGrammar) bool {
        _ = self;
        if (grammar.string_style.double_quote and c == '"') return true;
        if (grammar.string_style.single_quote and c == '\'') return true;
        if (grammar.string_style.backtick and c == '`') return true;
        return false;
    }

    fn scanStringEnd(self: *SyntaxHighlighter, line: []const u8, pos: *usize) bool {
        const quote_char = self.state.string_char;
        while (pos.* < line.len) {
            const c = line[pos.*];
            if (c == '\\' and pos.* + 1 < line.len) {
                pos.* += 2; // Skip escape sequence
                continue;
            }
            if (c == quote_char) {
                pos.* += 1;
                self.state.string_char = 0;
                return true;
            }
            pos.* += 1;
        }
        return false;
    }

    fn scanBlockCommentEnd(self: *SyntaxHighlighter, line: []const u8, pos: *usize, grammar: *const LanguageGrammar) bool {
        _ = self;
        const end_marker = grammar.comment_style.block_end orelse return false;

        while (pos.* + end_marker.len <= line.len) {
            if (std.mem.eql(u8, line[pos.*..][0..end_marker.len], end_marker)) {
                pos.* += end_marker.len;
                return true;
            }
            pos.* += 1;
        }
        // Handle case where we're at the end
        if (pos.* < line.len) {
            pos.* = line.len;
        }
        return false;
    }

    fn scanNumber(self: *SyntaxHighlighter, line: []const u8, pos: *usize, grammar: *const LanguageGrammar) TokenType {
        _ = self;
        const start = pos.*;

        // Check for hex/binary/octal prefix
        if (line[start] == '0' and pos.* + 1 < line.len) {
            const next = line[pos.* + 1];
            if ((next == 'x' or next == 'X') and grammar.number_style.hex_prefix != null) {
                pos.* += 2;
                while (pos.* < line.len and isHexDigit(line[pos.*])) {
                    pos.* += 1;
                }
                return .number_hex;
            }
            if ((next == 'b' or next == 'B') and grammar.number_style.binary_prefix != null) {
                pos.* += 2;
                while (pos.* < line.len and (line[pos.*] == '0' or line[pos.*] == '1')) {
                    pos.* += 1;
                }
                return .number_binary;
            }
            if ((next == 'o' or next == 'O') and grammar.number_style.octal_prefix != null) {
                pos.* += 2;
                while (pos.* < line.len and line[pos.*] >= '0' and line[pos.*] <= '7') {
                    pos.* += 1;
                }
                return .number;
            }
        }

        // Regular number
        var has_dot = false;
        var has_exp = false;

        while (pos.* < line.len) {
            const c = line[pos.*];
            if (isDigit(c) or c == '_') {
                pos.* += 1;
            } else if (c == '.' and !has_dot and grammar.number_style.float_suffix) {
                // Check it's not a method call or range operator
                if (pos.* + 1 < line.len and isDigit(line[pos.* + 1])) {
                    has_dot = true;
                    pos.* += 1;
                } else {
                    break;
                }
            } else if ((c == 'e' or c == 'E') and !has_exp and grammar.number_style.float_suffix) {
                has_exp = true;
                pos.* += 1;
                if (pos.* < line.len and (line[pos.*] == '+' or line[pos.*] == '-')) {
                    pos.* += 1;
                }
            } else {
                break;
            }
        }

        return if (has_dot or has_exp) .number_float else .number;
    }

    fn classifyIdentifier(self: *SyntaxHighlighter, ident: []const u8, grammar: *const LanguageGrammar) TokenType {
        _ = self;

        // Check keywords
        for (grammar.keywords) |kw| {
            if (std.mem.eql(u8, ident, kw.word)) {
                return switch (kw.category) {
                    .control => .keyword_control,
                    .type_keyword => .keyword_type,
                    .modifier => .keyword_modifier,
                    .operator => .keyword_operator,
                    .literal => .boolean,
                    .other => .keyword,
                };
            }
        }

        // Check if it looks like a type (starts with uppercase)
        if (ident.len > 0 and ident[0] >= 'A' and ident[0] <= 'Z') {
            return .identifier_type;
        }

        // Check if it looks like a constant (ALL_CAPS)
        var all_upper = true;
        for (ident) |c| {
            if (c != '_' and (c < 'A' or c > 'Z') and (c < '0' or c > '9')) {
                all_upper = false;
                break;
            }
        }
        if (all_upper and ident.len > 1) {
            return .identifier_constant;
        }

        return .identifier;
    }

    fn scanOperator(self: *SyntaxHighlighter, line: []const u8, pos: *usize, grammar: *const LanguageGrammar) TokenType {
        _ = self;
        _ = grammar;

        const c = line[pos.*];
        pos.* += 1;

        // Brackets
        if (c == '(' or c == ')' or c == '[' or c == ']' or c == '{' or c == '}') {
            return .punctuation_bracket;
        }

        // Delimiters
        if (c == ',' or c == ';' or c == ':') {
            return .punctuation_delimiter;
        }

        // Accessors
        if (c == '.') {
            return .punctuation_accessor;
        }

        // Assignment operators (check for compound assignment)
        if (c == '=' or c == '+' or c == '-' or c == '*' or c == '/' or c == '%' or
            c == '&' or c == '|' or c == '^' or c == '!' or c == '<' or c == '>')
        {
            // Check for multi-char operators
            if (pos.* < line.len) {
                const next = line[pos.*];
                if (next == '=') {
                    pos.* += 1;
                    if (c == '=' or c == '!' or c == '<' or c == '>') {
                        return .operator_comparison;
                    }
                    return .operator_assignment;
                }
                if ((c == '<' and next == '<') or (c == '>' and next == '>')) {
                    pos.* += 1;
                    return .operator_bitwise;
                }
                if ((c == '&' and next == '&') or (c == '|' and next == '|')) {
                    pos.* += 1;
                    return .operator_logical;
                }
                if ((c == '+' and next == '+') or (c == '-' and next == '-')) {
                    pos.* += 1;
                    return .operator_arithmetic;
                }
                if (c == '-' and next == '>') {
                    pos.* += 1;
                    return .punctuation_accessor;
                }
            }

            if (c == '=' and pos.* == 1) {
                return .operator_assignment;
            }
            if (c == '<' or c == '>' or c == '!') {
                return .operator_comparison;
            }
            if (c == '&' or c == '|' or c == '^' or c == '~') {
                return .operator_bitwise;
            }
            return .operator_arithmetic;
        }

        return .punctuation;
    }
};

// Helper functions
fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

fn isHexDigit(c: u8) bool {
    return isDigit(c) or (c >= 'a' and c <= 'f') or (c >= 'A' and c <= 'F');
}

fn isIdentifierStart(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_';
}

fn isIdentifierChar(c: u8) bool {
    return isIdentifierStart(c) or isDigit(c);
}

// Tests
test "highlighter initialization" {
    const allocator = std.testing.allocator;
    var highlighter = SyntaxHighlighter.init(allocator, .zig);
    defer highlighter.deinit();

    try std.testing.expect(highlighter.grammar != null);
    try std.testing.expectEqual(LanguageId.zig, highlighter.language);
}

test "highlight zig code" {
    const allocator = std.testing.allocator;
    var highlighter = SyntaxHighlighter.init(allocator, .zig);
    defer highlighter.deinit();

    const line = "const x = 42;";
    const spans = try highlighter.highlightLine(line, 0);
    defer allocator.free(spans);

    try std.testing.expect(spans.len > 0);

    // First token should be 'const' keyword
    try std.testing.expectEqual(TokenType.keyword_type, spans[0].token_type);
    try std.testing.expectEqual(@as(u32, 0), spans[0].start);
    try std.testing.expectEqual(@as(u16, 5), spans[0].length);
}

test "highlight comments" {
    const allocator = std.testing.allocator;
    var highlighter = SyntaxHighlighter.init(allocator, .zig);
    defer highlighter.deinit();

    const line = "// this is a comment";
    const spans = try highlighter.highlightLine(line, 0);
    defer allocator.free(spans);

    try std.testing.expectEqual(@as(usize, 1), spans.len);
    try std.testing.expectEqual(TokenType.comment_line, spans[0].token_type);
}

test "highlight strings" {
    const allocator = std.testing.allocator;
    var highlighter = SyntaxHighlighter.init(allocator, .zig);
    defer highlighter.deinit();

    const line = "const s = \"hello\";";
    const spans = try highlighter.highlightLine(line, 0);
    defer allocator.free(spans);

    // Find string token
    var found_string = false;
    for (spans) |span| {
        if (span.token_type == .string) {
            found_string = true;
            break;
        }
    }
    try std.testing.expect(found_string);
}

test "highlight numbers" {
    const allocator = std.testing.allocator;
    var highlighter = SyntaxHighlighter.init(allocator, .zig);
    defer highlighter.deinit();

    {
        const line = "const x = 0xFF;";
        const spans = try highlighter.highlightLine(line, 0);
        defer allocator.free(spans);

        var found_hex = false;
        for (spans) |span| {
            if (span.token_type == .number_hex) {
                found_hex = true;
                break;
            }
        }
        try std.testing.expect(found_hex);
    }

    highlighter.invalidateCache();

    {
        const line = "const y = 3.14;";
        const spans = try highlighter.highlightLine(line, 1);
        defer allocator.free(spans);

        var found_float = false;
        for (spans) |span| {
            if (span.token_type == .number_float) {
                found_float = true;
                break;
            }
        }
        try std.testing.expect(found_float);
    }
}

test "highlight builtin" {
    const allocator = std.testing.allocator;
    var highlighter = SyntaxHighlighter.init(allocator, .zig);
    defer highlighter.deinit();

    const line = "@import(\"std\");";
    const spans = try highlighter.highlightLine(line, 0);
    defer allocator.free(spans);

    try std.testing.expect(spans.len > 0);
    try std.testing.expectEqual(TokenType.identifier_builtin, spans[0].token_type);
}

test "highlight javascript" {
    const allocator = std.testing.allocator;
    var highlighter = SyntaxHighlighter.init(allocator, .javascript);
    defer highlighter.deinit();

    const line = "function test() { return true; }";
    const spans = try highlighter.highlightLine(line, 0);
    defer allocator.free(spans);

    try std.testing.expect(spans.len > 0);
    // First token should be 'function' keyword
    try std.testing.expectEqual(TokenType.keyword_type, spans[0].token_type);
}

test "line cache" {
    const allocator = std.testing.allocator;
    var highlighter = SyntaxHighlighter.init(allocator, .zig);
    defer highlighter.deinit();

    const line = "const x = 42;";

    // First call
    const spans1 = try highlighter.highlightLine(line, 0);
    defer allocator.free(spans1);

    // Second call should use cache
    const spans2 = try highlighter.highlightLine(line, 0);
    defer allocator.free(spans2);

    try std.testing.expectEqual(spans1.len, spans2.len);
}

test "scanner state" {
    var state = ScannerState{};
    try std.testing.expect(state.isClean());

    state.in_string = true;
    try std.testing.expect(!state.isClean());

    const hash1 = state.hash();
    state.in_comment = true;
    const hash2 = state.hash();
    try std.testing.expect(hash1 != hash2);
}

test "invalidate cache" {
    const allocator = std.testing.allocator;
    var highlighter = SyntaxHighlighter.init(allocator, .zig);
    defer highlighter.deinit();

    // Populate cache
    const line = "const x = 42;";
    const spans1 = try highlighter.highlightLine(line, 0);
    allocator.free(spans1);
    const spans2 = try highlighter.highlightLine(line, 1);
    allocator.free(spans2);
    const spans3 = try highlighter.highlightLine(line, 2);
    allocator.free(spans3);

    // Invalidate from line 1
    highlighter.invalidateFrom(1);

    // Line 0 should still be cached
    try std.testing.expect(highlighter.line_cache.contains(0));
    // Lines 1 and 2 should be removed
    try std.testing.expect(!highlighter.line_cache.contains(1));
    try std.testing.expect(!highlighter.line_cache.contains(2));
}

test "plain text fallback" {
    const allocator = std.testing.allocator;
    var highlighter = SyntaxHighlighter.init(allocator, .plain);
    defer highlighter.deinit();

    // Plain text uses plain_grammar which has no keywords/strings/etc.
    try std.testing.expect(highlighter.grammar != null);
    try std.testing.expectEqual(LanguageId.plain, highlighter.grammar.?.id);

    const line = "some text here";
    const spans = try highlighter.highlightLine(line, 0);
    defer allocator.free(spans);

    // Should get some tokens (identifiers and whitespace)
    try std.testing.expect(spans.len > 0);
}
