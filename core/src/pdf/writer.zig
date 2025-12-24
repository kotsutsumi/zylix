//! Zylix PDF - PDF Writer
//!
//! Low-level PDF file writing according to PDF 1.7 specification.

const std = @import("std");
const types = @import("types.zig");

const PdfVersion = types.PdfVersion;
const Rectangle = types.Rectangle;
const Metadata = types.Metadata;
const ObjectRef = types.ObjectRef;

const Document = @import("document.zig").Document;
const Page = @import("page.zig").Page;

/// PDF Writer
pub const Writer = struct {
    output: *std.ArrayList(u8),
    xref_offsets: std.ArrayList(usize),
    allocator: std.mem.Allocator,

    pub fn init(output: *std.ArrayList(u8), allocator: std.mem.Allocator) Writer {
        return .{
            .output = output,
            .xref_offsets = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Writer) void {
        self.xref_offsets.deinit(self.allocator);
    }

    /// Write complete document
    pub fn writeDocument(self: *Writer, doc: *Document) !void {
        defer self.deinit();

        // Reserve space for object 0 (always free)
        try self.xref_offsets.append(self.allocator, 0);

        // Write header
        try self.writeHeader(doc.version);

        // Write catalog and page tree
        const catalog_id = try self.writeCatalog(doc);
        const pages_id = catalog_id + 1;

        // Write pages
        var page_ids: std.ArrayList(u32) = .{};
        defer page_ids.deinit(self.allocator);

        for (doc.pages.items) |pg| {
            const page_id = try self.writePage(pg, pages_id);
            try page_ids.append(self.allocator, page_id);
        }

        // Write pages dictionary
        try self.writePageTree(pages_id, page_ids.items, doc);

        // Write info dictionary (metadata)
        const info_id = try self.writeInfo(doc.metadata);

        // Write xref table
        const xref_offset = self.output.items.len;
        try self.writeXref();

        // Write trailer
        try self.writeTrailer(catalog_id, info_id, xref_offset);
    }

    fn writeHeader(self: *Writer, version: PdfVersion) !void {
        try self.write("%PDF-");
        try self.write(version.toString());
        try self.write("\n");
        // Binary marker (recommended for binary content)
        try self.write("%\xE2\xE3\xCF\xD3\n");
    }

    fn writeCatalog(self: *Writer, doc: *Document) !u32 {
        const obj_id = @as(u32, @intCast(self.xref_offsets.items.len));
        try self.xref_offsets.append(self.allocator, self.output.items.len);

        try self.writeFmt("{d} 0 obj\n", .{obj_id});
        try self.write("<<\n");
        try self.write("/Type /Catalog\n");
        try self.writeFmt("/Pages {d} 0 R\n", .{obj_id + 1});

        // Add metadata reference if present
        if (doc.metadata.title != null or doc.metadata.author != null) {
            // Metadata handled in Info dictionary
        }

        try self.write(">>\n");
        try self.write("endobj\n\n");

        return obj_id;
    }

    fn writePageTree(self: *Writer, pages_id: u32, page_ids: []const u32, doc: *Document) !void {
        // Ensure we have space for pages_id
        while (self.xref_offsets.items.len <= pages_id) {
            try self.xref_offsets.append(self.allocator, 0);
        }
        self.xref_offsets.items[pages_id] = self.output.items.len;

        try self.writeFmt("{d} 0 obj\n", .{pages_id});
        try self.write("<<\n");
        try self.write("/Type /Pages\n");

        // Kids array
        try self.write("/Kids [");
        for (page_ids, 0..) |pid, i| {
            if (i > 0) try self.write(" ");
            try self.writeFmt("{d} 0 R", .{pid});
        }
        try self.write("]\n");

        try self.writeFmt("/Count {d}\n", .{doc.pages.items.len});
        try self.write(">>\n");
        try self.write("endobj\n\n");
    }

    fn writePage(self: *Writer, pg: *Page, parent_id: u32) !u32 {
        // Page object
        const page_id = @as(u32, @intCast(self.xref_offsets.items.len));
        try self.xref_offsets.append(self.allocator, self.output.items.len);

        try self.writeFmt("{d} 0 obj\n", .{page_id});
        try self.write("<<\n");
        try self.write("/Type /Page\n");
        try self.writeFmt("/Parent {d} 0 R\n", .{parent_id});
        try self.writeFmt("/MediaBox [0 0 {d} {d}]\n", .{ pg.size.width, pg.size.height });

        // Resources (fonts)
        try self.write("/Resources <<\n");
        try self.write("  /Font <<\n");
        try self.write("    /Helvetica << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\n");
        try self.write("    /Helvetica-Bold << /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>\n");
        try self.write("    /Times-Roman << /Type /Font /Subtype /Type1 /BaseFont /Times-Roman >>\n");
        try self.write("    /Courier << /Type /Font /Subtype /Type1 /BaseFont /Courier >>\n");
        try self.write("  >>\n");
        try self.write(">>\n");

        // Content stream reference
        const content_id = page_id + 1;
        try self.writeFmt("/Contents {d} 0 R\n", .{content_id});

        try self.write(">>\n");
        try self.write("endobj\n\n");

        // Content stream object
        try self.xref_offsets.append(self.allocator, self.output.items.len);
        try self.writeContentStream(content_id, pg.getContentStream());

        return page_id;
    }

    fn writeContentStream(self: *Writer, obj_id: u32, content: []const u8) !void {
        try self.writeFmt("{d} 0 obj\n", .{obj_id});
        try self.write("<<\n");
        try self.writeFmt("/Length {d}\n", .{content.len});
        try self.write(">>\n");
        try self.write("stream\n");
        try self.write(content);
        if (content.len > 0 and content[content.len - 1] != '\n') {
            try self.write("\n");
        }
        try self.write("endstream\n");
        try self.write("endobj\n\n");
    }

    fn writeInfo(self: *Writer, metadata: Metadata) !u32 {
        const obj_id = @as(u32, @intCast(self.xref_offsets.items.len));
        try self.xref_offsets.append(self.allocator, self.output.items.len);

        try self.writeFmt("{d} 0 obj\n", .{obj_id});
        try self.write("<<\n");

        if (metadata.title) |title| {
            try self.write("/Title (");
            try self.writePdfString(title);
            try self.write(")\n");
        }

        if (metadata.author) |author| {
            try self.write("/Author (");
            try self.writePdfString(author);
            try self.write(")\n");
        }

        if (metadata.subject) |subject| {
            try self.write("/Subject (");
            try self.writePdfString(subject);
            try self.write(")\n");
        }

        if (metadata.keywords) |keywords| {
            try self.write("/Keywords (");
            try self.writePdfString(keywords);
            try self.write(")\n");
        }

        if (metadata.creator) |creator| {
            try self.write("/Creator (");
            try self.writePdfString(creator);
            try self.write(")\n");
        }

        if (metadata.producer) |producer| {
            try self.write("/Producer (");
            try self.writePdfString(producer);
            try self.write(")\n");
        }

        if (metadata.creation_date) |date| {
            try self.write("/CreationDate (");
            try self.writePdfDate(date);
            try self.write(")\n");
        }

        if (metadata.modification_date) |date| {
            try self.write("/ModDate (");
            try self.writePdfDate(date);
            try self.write(")\n");
        }

        try self.write(">>\n");
        try self.write("endobj\n\n");

        return obj_id;
    }

    fn writeXref(self: *Writer) !void {
        try self.write("xref\n");
        try self.writeFmt("0 {d}\n", .{self.xref_offsets.items.len});

        // Object 0 is always free
        try self.write("0000000000 65535 f \n");

        // Other objects
        for (self.xref_offsets.items[1..]) |offset| {
            try self.writeFmt("{d:0>10} 00000 n \n", .{offset});
        }
    }

    fn writeTrailer(self: *Writer, catalog_id: u32, info_id: u32, xref_offset: usize) !void {
        try self.write("trailer\n");
        try self.write("<<\n");
        try self.writeFmt("/Size {d}\n", .{self.xref_offsets.items.len});
        try self.writeFmt("/Root {d} 0 R\n", .{catalog_id});
        try self.writeFmt("/Info {d} 0 R\n", .{info_id});
        try self.write(">>\n");
        try self.write("startxref\n");
        try self.writeFmt("{d}\n", .{xref_offset});
        try self.write("%%EOF\n");
    }

    fn write(self: *Writer, data: []const u8) !void {
        try self.output.appendSlice(self.allocator, data);
    }

    fn writeFmt(self: *Writer, comptime fmt: []const u8, args: anytype) !void {
        var buf: [512]u8 = undefined;
        const result = std.fmt.bufPrint(&buf, fmt, args) catch |err| switch (err) {
            error.NoSpaceLeft => {
                const formatted = try std.fmt.allocPrint(self.allocator, fmt, args);
                defer self.allocator.free(formatted);
                try self.output.appendSlice(self.allocator, formatted);
                return;
            },
        };
        try self.output.appendSlice(self.allocator, result);
    }

    fn writePdfString(self: *Writer, str: []const u8) !void {
        for (str) |c| {
            switch (c) {
                '(' => try self.write("\\("),
                ')' => try self.write("\\)"),
                '\\' => try self.write("\\\\"),
                '\n' => try self.write("\\n"),
                '\r' => try self.write("\\r"),
                '\t' => try self.write("\\t"),
                else => {
                    var buf: [1]u8 = .{c};
                    try self.output.appendSlice(self.allocator, &buf);
                },
            }
        }
    }

    fn writePdfDate(self: *Writer, timestamp: i64) !void {
        // PDF date format: D:YYYYMMDDHHmmSS
        // Clamp pre-epoch (negative) timestamps to Unix epoch
        const epoch_seconds: u64 = if (timestamp >= 0) @intCast(timestamp) else 0;
        const epoch = std.time.epoch.EpochSeconds{ .secs = epoch_seconds };
        const day = epoch.getEpochDay();
        const year_day = day.calculateYearDay();
        const month_day = year_day.calculateMonthDay();
        const day_seconds = epoch.getDaySeconds();

        try self.writeFmt("D:{d:0>4}{d:0>2}{d:0>2}{d:0>2}{d:0>2}{d:0>2}", .{
            year_day.year,
            month_day.month.numeric(),
            month_day.day_index + 1,
            day_seconds.getHoursIntoDay(),
            day_seconds.getMinutesIntoHour(),
            day_seconds.getSecondsIntoMinute(),
        });
    }
};

// Unit tests
test "Writer basic output" {
    const allocator = std.testing.allocator;

    var output: std.ArrayList(u8) = .{};
    defer output.deinit(allocator);

    const doc = @import("document.zig");
    var document = try doc.Document.create(allocator);
    defer document.deinit();

    _ = try document.addPage(types.PageSize.A4);

    var writer = Writer.init(&output, allocator);
    try writer.writeDocument(document);

    // Verify PDF structure
    try std.testing.expect(std.mem.startsWith(u8, output.items, "%PDF-1.7"));
    try std.testing.expect(std.mem.indexOf(u8, output.items, "%%EOF") != null);
}
