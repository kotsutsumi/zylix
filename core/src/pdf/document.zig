//! Zylix PDF - Document Management
//!
//! High-level PDF document API for creating and manipulating PDF files.

const std = @import("std");
const types = @import("types.zig");
const page_mod = @import("page.zig");
const writer_mod = @import("writer.zig");
const font_mod = @import("font.zig");
const parser_mod = @import("parser.zig");

const PageSize = types.PageSize;
const Metadata = types.Metadata;
const PdfVersion = types.PdfVersion;
const PdfError = types.PdfError;
const Compression = types.Compression;
const ObjectRef = types.ObjectRef;

const Page = page_mod.Page;
const Writer = writer_mod.Writer;
const Font = font_mod.Font;
const Parser = parser_mod.Parser;
const PdfObject = parser_mod.PdfObject;

/// PDF Document
pub const Document = struct {
    allocator: std.mem.Allocator,
    version: PdfVersion,
    metadata: Metadata,
    pages: std.ArrayList(*Page),
    fonts: std.ArrayList(*Font),
    compression: Compression,
    next_object_id: u32,

    /// Create a new empty document
    pub fn create(allocator: std.mem.Allocator) !*Document {
        const doc = try allocator.create(Document);
        doc.* = .{
            .allocator = allocator,
            .version = .v1_7,
            .metadata = .{
                .producer = "Zylix PDF v0.18.0",
                .creation_date = std.time.timestamp(),
            },
            .pages = .{},
            .fonts = .{},
            .compression = .flate,
            .next_object_id = 1,
        };
        return doc;
    }

    /// Open existing PDF from memory
    pub fn open(allocator: std.mem.Allocator, data: []const u8) !*Document {
        const doc = try allocator.create(Document);
        errdefer allocator.destroy(doc);

        doc.* = .{
            .allocator = allocator,
            .version = .v1_7,
            .metadata = .{},
            .pages = .{},
            .fonts = .{},
            .compression = .flate,
            .next_object_id = 1,
        };

        // Parse the PDF data
        try doc.parse(data);

        return doc;
    }

    /// Open PDF from file
    pub fn openFile(allocator: std.mem.Allocator, path: []const u8) !*Document {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const stat = try file.stat();
        const data = try allocator.alloc(u8, stat.size);
        defer allocator.free(data);

        _ = try file.readAll(data);
        return open(allocator, data);
    }

    /// Clean up document resources
    pub fn deinit(self: *Document) void {
        // Free all pages
        for (self.pages.items) |pg| {
            pg.deinit();
            self.allocator.destroy(pg);
        }
        self.pages.deinit(self.allocator);

        // Free all fonts
        for (self.fonts.items) |f| {
            f.deinit();
            self.allocator.destroy(f);
        }
        self.fonts.deinit(self.allocator);

        self.allocator.destroy(self);
    }

    /// Add a new page to the document
    pub fn addPage(self: *Document, size: PageSize) !*Page {
        const pg = try Page.create(self.allocator, self, size);
        try self.pages.append(self.allocator, pg);
        return pg;
    }

    /// Add a new page with custom options
    pub fn addPageWithOptions(self: *Document, options: Page.Options) !*Page {
        const pg = try Page.createWithOptions(self.allocator, self, options);
        try self.pages.append(self.allocator, pg);
        return pg;
    }

    /// Insert a page at specific index
    pub fn insertPage(self: *Document, index: usize, size: PageSize) !*Page {
        if (index > self.pages.items.len) {
            return PdfError.InvalidPageIndex;
        }
        const pg = try Page.create(self.allocator, self, size);
        try self.pages.insert(self.allocator, index, pg);
        return pg;
    }

    /// Remove a page by index
    pub fn removePage(self: *Document, index: usize) !void {
        if (index >= self.pages.items.len) {
            return PdfError.InvalidPageIndex;
        }
        const pg = self.pages.orderedRemove(index);
        pg.deinit();
        self.allocator.destroy(pg);
    }

    /// Get page by index
    pub fn getPage(self: *Document, index: usize) !*Page {
        if (index >= self.pages.items.len) {
            return PdfError.InvalidPageIndex;
        }
        return self.pages.items[index];
    }

    /// Get total number of pages
    pub fn getPageCount(self: *const Document) usize {
        return self.pages.items.len;
    }

    /// Set document metadata
    pub fn setMetadata(self: *Document, metadata: Metadata) void {
        self.metadata = metadata;
        self.metadata.modification_date = std.time.timestamp();
    }

    /// Set PDF version
    pub fn setVersion(self: *Document, ver: PdfVersion) void {
        self.version = ver;
    }

    /// Set compression method
    pub fn setCompression(self: *Document, compression: Compression) void {
        self.compression = compression;
    }

    /// Allocate a new object ID
    pub fn allocateObjectId(self: *Document) u32 {
        const id = self.next_object_id;
        self.next_object_id += 1;
        return id;
    }

    /// Save document to memory buffer
    pub fn save(self: *Document) ![]u8 {
        var output: std.ArrayList(u8) = .{};
        errdefer output.deinit(self.allocator);

        var w = Writer.init(&output, self.allocator);
        try w.writeDocument(self);

        return output.toOwnedSlice(self.allocator);
    }

    /// Save document to file
    pub fn saveToFile(self: *Document, path: []const u8) !void {
        const data = try self.save();
        defer self.allocator.free(data);

        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        try file.writeAll(data);
    }

    /// Merge another document into this one
    pub fn merge(self: *Document, other: *Document) !void {
        for (other.pages.items) |pg| {
            const new_page = try pg.clone(self.allocator, self);
            errdefer {
                new_page.deinit();
                self.allocator.destroy(new_page);
            }
            try self.pages.append(self.allocator, new_page);
        }
    }

    /// Split document into multiple documents (one per page)
    pub fn split(self: *Document) !std.ArrayList(*Document) {
        var docs: std.ArrayList(*Document) = .{};
        errdefer {
            for (docs.items) |doc| {
                doc.deinit();
            }
            docs.deinit(self.allocator);
        }

        for (self.pages.items) |pg| {
            const new_doc = try Document.create(self.allocator);
            new_doc.metadata = self.metadata;
            new_doc.version = self.version;

            const new_page = try pg.clone(self.allocator, new_doc);
            try new_doc.pages.append(self.allocator, new_page);
            try docs.append(self.allocator, new_doc);
        }

        return docs;
    }

    /// Parse PDF data using the internal parser
    fn parse(self: *Document, data: []const u8) !void {
        // Check minimum size
        if (data.len < 8) {
            return PdfError.InvalidPdf;
        }

        // Use the full parser for xref/trailer parsing
        var parser = Parser.init(self.allocator, data);
        defer parser.deinit();

        try parser.parse();

        // Extract version from parser
        self.version = parser.getVersion();

        // Extract metadata from trailer /Info dictionary if present
        if (parser.trailer) |trailer| {
            if (trailer == .dictionary) {
                const dict = trailer.dictionary;

                // Look for /Info reference and extract metadata
                if (dict.get("Info")) |info_ref| {
                    self.extractMetadataFromRef(&parser, info_ref);
                }
            }
        }

        // Extract page count using simple heuristic
        const page_count = parser_mod.getPageCount(data) catch 0;
        _ = page_count; // Page count available but pages not loaded for read-only access
    }

    /// Extract metadata from an Info dictionary reference
    fn extractMetadataFromRef(self: *Document, parser: *Parser, info_ref: PdfObject) void {
        if (info_ref != .reference) return;

        const ref = info_ref.reference;

        // Look up object in xref table
        if (parser.xref_table.get(ref.object_number)) |entry| {
            if (!entry.in_use) return;

            // Parse object at offset (simplified - just extract strings)
            self.parseInfoDictAt(parser.data, entry.offset);
        }
    }

    /// Parse Info dictionary at a given offset
    fn parseInfoDictAt(self: *Document, data: []const u8, offset: usize) void {
        if (offset >= data.len) return;

        // Search for common metadata fields starting from offset
        const search_end = @min(offset + 2048, data.len); // Limit search range
        const search_data = data[offset..search_end];

        // Extract Title
        if (findPdfString(search_data, "/Title")) |title| {
            self.metadata.title = title;
        }

        // Extract Author
        if (findPdfString(search_data, "/Author")) |author| {
            self.metadata.author = author;
        }

        // Extract Subject
        if (findPdfString(search_data, "/Subject")) |subject| {
            self.metadata.subject = subject;
        }

        // Extract Creator
        if (findPdfString(search_data, "/Creator")) |creator| {
            self.metadata.creator = creator;
        }

        // Extract Producer
        if (findPdfString(search_data, "/Producer")) |producer| {
            self.metadata.producer = producer;
        }
    }

    /// Find a PDF string value after a given key
    fn findPdfString(data: []const u8, key: []const u8) ?[]const u8 {
        // Find key position
        var pos: usize = 0;
        while (pos + key.len < data.len) : (pos += 1) {
            if (std.mem.startsWith(u8, data[pos..], key)) {
                pos += key.len;
                break;
            }
        } else {
            return null;
        }

        // Skip whitespace
        while (pos < data.len and (data[pos] == ' ' or data[pos] == '\t' or data[pos] == '\r' or data[pos] == '\n')) {
            pos += 1;
        }

        if (pos >= data.len) return null;

        // Parse string (literal or hex)
        if (data[pos] == '(') {
            // Literal string
            pos += 1;
            const start = pos;
            var paren_depth: u32 = 1;

            while (pos < data.len and paren_depth > 0) {
                if (data[pos] == '\\' and pos + 1 < data.len) {
                    pos += 2;
                } else if (data[pos] == '(') {
                    paren_depth += 1;
                    pos += 1;
                } else if (data[pos] == ')') {
                    paren_depth -= 1;
                    if (paren_depth > 0) pos += 1;
                } else {
                    pos += 1;
                }
            }

            return data[start..pos];
        } else if (data[pos] == '<' and (pos + 1 >= data.len or data[pos + 1] != '<')) {
            // Hex string
            pos += 1;
            const start = pos;
            while (pos < data.len and data[pos] != '>') {
                pos += 1;
            }
            return data[start..pos];
        }

        return null;
    }

    /// Add a standard font to the document
    pub fn addStandardFont(self: *Document, font_type: types.StandardFont) !*Font {
        const f = try Font.createStandard(self.allocator, font_type);
        try self.fonts.append(self.allocator, f);
        return f;
    }
};

// Unit tests
test "Document creation" {
    const allocator = std.testing.allocator;

    const doc = try Document.create(allocator);
    defer doc.deinit();

    try std.testing.expectEqual(doc.version, .v1_7);
    try std.testing.expectEqual(doc.getPageCount(), 0);
}

test "Add pages" {
    const allocator = std.testing.allocator;

    const doc = try Document.create(allocator);
    defer doc.deinit();

    _ = try doc.addPage(PageSize.A4);
    _ = try doc.addPage(PageSize.Letter);

    try std.testing.expectEqual(doc.getPageCount(), 2);
}

test "Remove page" {
    const allocator = std.testing.allocator;

    const doc = try Document.create(allocator);
    defer doc.deinit();

    _ = try doc.addPage(PageSize.A4);
    _ = try doc.addPage(PageSize.Letter);
    _ = try doc.addPage(PageSize.A5);

    try doc.removePage(1);

    try std.testing.expectEqual(doc.getPageCount(), 2);
}

test "Set metadata" {
    const allocator = std.testing.allocator;

    const doc = try Document.create(allocator);
    defer doc.deinit();

    doc.setMetadata(.{
        .title = "Test Document",
        .author = "Test Author",
    });

    try std.testing.expectEqualStrings("Test Document", doc.metadata.title.?);
    try std.testing.expectEqualStrings("Test Author", doc.metadata.author.?);
}

test "Parse PDF header and xref" {
    const allocator = std.testing.allocator;

    // Minimal valid PDF structure
    const pdf_data =
        \\%PDF-1.7
        \\%âãÏÓ
        \\1 0 obj
        \\<< /Type /Catalog /Pages 2 0 R >>
        \\endobj
        \\2 0 obj
        \\<< /Type /Pages /Kids [] /Count 0 >>
        \\endobj
        \\xref
        \\0 3
        \\0000000000 65535 f
        \\0000000009 00000 n
        \\0000000058 00000 n
        \\trailer
        \\<< /Root 1 0 R /Size 3 >>
        \\startxref
        \\114
        \\%%EOF
    ;

    const doc = try Document.open(allocator, pdf_data);
    defer doc.deinit();

    try std.testing.expectEqual(doc.version, .v1_7);
}

test "findPdfString extracts literal strings" {
    const data = "/Title (Test Document) /Author (John Doe)";
    const title = Document.findPdfString(data, "/Title");
    try std.testing.expect(title != null);
    try std.testing.expectEqualStrings("Test Document", title.?);

    const author = Document.findPdfString(data, "/Author");
    try std.testing.expect(author != null);
    try std.testing.expectEqualStrings("John Doe", author.?);
}

test "findPdfString handles nested parentheses" {
    const data = "/Title (Test (Nested) Document)";
    const title = Document.findPdfString(data, "/Title");
    try std.testing.expect(title != null);
    try std.testing.expectEqualStrings("Test (Nested) Document", title.?);
}

test "findPdfString returns null for missing key" {
    const data = "/Title (Test)";
    const author = Document.findPdfString(data, "/Author");
    try std.testing.expect(author == null);
}
