//! Zylix PDF - PDF Parser
//!
//! PDF file parsing and content extraction.

const std = @import("std");
const types = @import("types.zig");

const PdfVersion = types.PdfVersion;
const PdfError = types.PdfError;
const Metadata = types.Metadata;
const Rectangle = types.Rectangle;
const ObjectRef = types.ObjectRef;

/// PDF Object representation
pub const PdfObject = union(enum) {
    null_obj,
    boolean: bool,
    integer: i64,
    real: f64,
    string: []const u8,
    hex_string: []const u8,
    name: []const u8,
    array: std.ArrayList(PdfObject),
    dictionary: std.StringHashMap(PdfObject),
    stream: Stream,
    reference: ObjectRef,

    pub const Stream = struct {
        dict: std.StringHashMap(PdfObject),
        data: []const u8,
    };
};

/// PDF Parser
pub const Parser = struct {
    allocator: std.mem.Allocator,
    data: []const u8,
    pos: usize,
    version: PdfVersion,
    xref_table: std.AutoHashMap(u32, XrefEntry),
    trailer: ?PdfObject,

    pub const XrefEntry = struct {
        offset: usize,
        generation: u16,
        in_use: bool,
    };

    pub fn init(allocator: std.mem.Allocator, data: []const u8) Parser {
        return .{
            .allocator = allocator,
            .data = data,
            .pos = 0,
            .version = .v1_7,
            .xref_table = .{},
            .trailer = null,
        };
    }

    pub fn deinit(self: *Parser) void {
        self.xref_table.deinit(self.allocator);
        // TODO: When parseTrailer() is fully implemented to populate self.trailer,
        // we'll need to recursively free PdfObject contents (arrays, dictionaries, streams)
    }

    /// Parse the PDF document
    pub fn parse(self: *Parser) !void {
        try self.parseHeader();
        try self.parseXref();
        try self.parseTrailer();
    }

    /// Parse PDF header
    fn parseHeader(self: *Parser) !void {
        if (!std.mem.startsWith(u8, self.data, "%PDF-")) {
            return PdfError.InvalidPdf;
        }

        self.pos = 5;

        // Parse version
        if (self.pos + 3 <= self.data.len) {
            const ver_str = self.data[self.pos .. self.pos + 3];

            self.version = if (std.mem.eql(u8, ver_str, "1.0"))
                .v1_0
            else if (std.mem.eql(u8, ver_str, "1.1"))
                .v1_1
            else if (std.mem.eql(u8, ver_str, "1.2"))
                .v1_2
            else if (std.mem.eql(u8, ver_str, "1.3"))
                .v1_3
            else if (std.mem.eql(u8, ver_str, "1.4"))
                .v1_4
            else if (std.mem.eql(u8, ver_str, "1.5"))
                .v1_5
            else if (std.mem.eql(u8, ver_str, "1.6"))
                .v1_6
            else if (std.mem.eql(u8, ver_str, "1.7"))
                .v1_7
            else if (std.mem.eql(u8, ver_str, "2.0"))
                .v2_0
            else
                .v1_7;
        }

        // Skip to end of line
        while (self.pos < self.data.len and self.data[self.pos] != '\n') {
            self.pos += 1;
        }
    }

    /// Parse cross-reference table
    fn parseXref(self: *Parser) !void {
        // Find startxref
        const startxref_pos = self.findLastOccurrence("startxref");
        if (startxref_pos == null) {
            return PdfError.InvalidPdf;
        }

        self.pos = startxref_pos.? + 9;
        self.skipWhitespace();

        // Parse xref offset
        const xref_offset = try self.parseInteger();

        // Go to xref table
        self.pos = @as(usize, @intCast(xref_offset));

        // Check for xref keyword
        if (self.pos + 4 <= self.data.len and std.mem.eql(u8, self.data[self.pos .. self.pos + 4], "xref")) {
            self.pos += 4;
            self.skipWhitespace();

            // Parse xref sections
            while (self.pos < self.data.len) {
                if (std.mem.startsWith(u8, self.data[self.pos..], "trailer")) {
                    break;
                }

                // Parse object range
                const first_obj = try self.parseInteger();
                self.skipWhitespace();
                const count = try self.parseInteger();
                self.skipWhitespace();

                // Parse entries
                var i: usize = 0;
                while (i < @as(usize, @intCast(count))) : (i += 1) {
                    if (self.pos + 20 > self.data.len) break;

                    const offset_str = self.data[self.pos .. self.pos + 10];
                    self.pos += 11; // 10 digits + space
                    const gen_str = self.data[self.pos .. self.pos + 5];
                    self.pos += 6; // 5 digits + space
                    const in_use = self.data[self.pos] == 'n';
                    self.pos += 1;

                    // Skip to next line
                    while (self.pos < self.data.len and (self.data[self.pos] == '\r' or self.data[self.pos] == '\n' or self.data[self.pos] == ' ')) {
                        self.pos += 1;
                    }

                    const offset = std.fmt.parseInt(usize, std.mem.trim(u8, offset_str, " "), 10) catch 0;
                    const gen = std.fmt.parseInt(u16, std.mem.trim(u8, gen_str, " "), 10) catch 0;

                    const obj_num = @as(u32, @intCast(first_obj)) + @as(u32, @intCast(i));
                    try self.xref_table.put(self.allocator, obj_num, .{
                        .offset = offset,
                        .generation = gen,
                        .in_use = in_use,
                    });
                }
            }
        }
    }

    /// Parse trailer dictionary
    fn parseTrailer(self: *Parser) !void {
        const trailer_pos = self.findLastOccurrence("trailer");
        if (trailer_pos == null) {
            return;
        }

        self.pos = trailer_pos.? + 7;
        self.skipWhitespace();

        // Parse trailer dictionary
        // Simplified - just skip for now
    }

    /// Get the PDF version
    pub fn getVersion(self: *const Parser) PdfVersion {
        return self.version;
    }

    /// Get page count from trailer
    pub fn getPageCount(self: *const Parser) usize {
        // Would need to follow /Root -> /Pages -> /Count
        _ = self;
        return 0;
    }

    /// Extract text from page
    pub fn extractText(self: *Parser, page_num: usize) ![]const u8 {
        _ = page_num;
        // Would need to parse page content stream and extract text operators
        return self.allocator.dupe(u8, "");
    }

    /// Get document metadata
    pub fn getMetadata(self: *const Parser) Metadata {
        // Would need to parse /Info dictionary
        _ = self;
        return .{};
    }

    // Helper functions

    fn skipWhitespace(self: *Parser) void {
        while (self.pos < self.data.len) {
            const c = self.data[self.pos];
            if (c == ' ' or c == '\t' or c == '\r' or c == '\n') {
                self.pos += 1;
            } else if (c == '%') {
                // Skip comment
                while (self.pos < self.data.len and self.data[self.pos] != '\n') {
                    self.pos += 1;
                }
            } else {
                break;
            }
        }
    }

    fn parseInteger(self: *Parser) !i64 {
        self.skipWhitespace();

        var start = self.pos;
        if (self.pos < self.data.len and (self.data[self.pos] == '+' or self.data[self.pos] == '-')) {
            self.pos += 1;
        }

        while (self.pos < self.data.len and self.data[self.pos] >= '0' and self.data[self.pos] <= '9') {
            self.pos += 1;
        }

        if (self.pos == start) {
            return PdfError.InvalidPdf;
        }

        return std.fmt.parseInt(i64, self.data[start..self.pos], 10) catch {
            return PdfError.InvalidPdf;
        };
    }

    fn findLastOccurrence(self: *const Parser, needle: []const u8) ?usize {
        if (self.data.len < needle.len) return null;

        var i = self.data.len - needle.len;
        while (i > 0) : (i -= 1) {
            if (std.mem.eql(u8, self.data[i .. i + needle.len], needle)) {
                return i;
            }
        }

        if (std.mem.eql(u8, self.data[0..needle.len], needle)) {
            return 0;
        }

        return null;
    }
};

/// Extract text from a PDF document
pub fn extractAllText(allocator: std.mem.Allocator, data: []const u8) ![]const u8 {
    var parser = Parser.init(allocator, data);
    defer parser.deinit();

    try parser.parse();

    // For now, return empty string
    // Full implementation would iterate pages and extract text
    return allocator.dupe(u8, "");
}

/// Get page count from PDF
pub fn getPageCount(data: []const u8) !usize {
    if (!std.mem.startsWith(u8, data, "%PDF-")) {
        return PdfError.InvalidPdf;
    }

    // Need at least 12 bytes to search for "/Type /Page"
    if (data.len < 12) {
        return 0;
    }

    // Simple heuristic: count /Type /Page occurrences
    var count: usize = 0;
    var i: usize = 0;
    const search_limit = data.len - 11; // Prevent overflow: need 11 bytes for "/Type /Page"

    while (i < search_limit) : (i += 1) {
        if (std.mem.eql(u8, data[i .. i + 11], "/Type /Page")) {
            // Make sure it's not /Type /Pages
            if (i + 12 < data.len and data[i + 11] != 's') {
                count += 1;
            }
        }
    }

    return count;
}

// Unit tests
test "Parser header" {
    const allocator = std.testing.allocator;

    const pdf_data = "%PDF-1.7\n%\xE2\xE3\xCF\xD3\n";

    var parser = Parser.init(allocator, pdf_data);
    defer parser.deinit();

    try parser.parseHeader();

    try std.testing.expectEqual(parser.version, .v1_7);
}

test "Invalid PDF detection" {
    const allocator = std.testing.allocator;

    const invalid_data = "Not a PDF file";

    var parser = Parser.init(allocator, invalid_data);
    defer parser.deinit();

    try std.testing.expectError(PdfError.InvalidPdf, parser.parseHeader());
}

test "Find last occurrence" {
    const allocator = std.testing.allocator;

    const data = "hello world startxref\n12345\n%%EOF\n";

    var parser = Parser.init(allocator, data);
    defer parser.deinit();

    const pos = parser.findLastOccurrence("startxref");
    try std.testing.expect(pos != null);
    try std.testing.expectEqual(pos.?, 12);
}
