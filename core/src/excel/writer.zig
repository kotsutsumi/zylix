//! Zylix Excel - XLSX Writer
//!
//! Generates Office Open XML (XLSX) files.
//! XLSX is a ZIP archive containing XML files.

const std = @import("std");
const types = @import("types.zig");
const workbook_mod = @import("workbook.zig");
const worksheet_mod = @import("worksheet.zig");
const cell_mod = @import("cell.zig");
const style_mod = @import("style.zig");

const ExcelError = types.ExcelError;
const Workbook = workbook_mod.Workbook;
const Worksheet = worksheet_mod.Worksheet;
const Cell = cell_mod.Cell;
const CellRef = types.CellRef;
const CellValue = types.CellValue;

/// ZIP archive entry
const ZipEntry = struct {
    name: []const u8,
    data: []const u8,
};

/// XLSX file writer
pub const XlsxWriter = struct {
    allocator: std.mem.Allocator,
    workbook: *Workbook,

    /// Buffer for building XML content
    buffer: std.ArrayList(u8),

    /// Write workbook to file
    pub fn write(workbook: *Workbook, path: []const u8) !void {
        var writer = XlsxWriter{
            .allocator = workbook.allocator,
            .workbook = workbook,
            .buffer = .{},
        };
        defer writer.buffer.deinit(workbook.allocator);

        try writer.writeToFile(path);
    }

    /// Write workbook to byte buffer
    pub fn writeToBuffer(workbook: *Workbook, output: *std.ArrayList(u8)) !void {
        var writer = XlsxWriter{
            .allocator = workbook.allocator,
            .workbook = workbook,
            .buffer = .{},
        };
        defer writer.buffer.deinit(workbook.allocator);

        try writer.generateZip(output);
    }

    fn writeToFile(self: *XlsxWriter, path: []const u8) !void {
        var output: std.ArrayList(u8) = .{};
        defer output.deinit(self.allocator);

        try self.generateZip(&output);

        // Write to file
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        try file.writeAll(output.items);
    }

    fn generateZip(self: *XlsxWriter, output: *std.ArrayList(u8)) !void {
        // For now, generate minimal valid XLSX structure as raw bytes
        // A proper implementation would use a ZIP library

        // Generate XML content for each part
        const content_types = try self.generateContentTypes();
        defer self.allocator.free(content_types);

        const rels = try self.generateRels();
        defer self.allocator.free(rels);

        const workbook_xml = try self.generateWorkbookXml();
        defer self.allocator.free(workbook_xml);

        const workbook_rels = try self.generateWorkbookRels();
        defer self.allocator.free(workbook_rels);

        const shared_strings = try self.generateSharedStrings();
        defer self.allocator.free(shared_strings);

        const styles_xml = try self.generateStyles();
        defer self.allocator.free(styles_xml);

        // Generate worksheet XMLs
        var sheet_xmls: std.ArrayList([]const u8) = .{};
        defer {
            for (sheet_xmls.items) |xml| {
                self.allocator.free(xml);
            }
            sheet_xmls.deinit(self.allocator);
        }

        for (self.workbook.sheets.items) |sheet| {
            const sheet_xml = try self.generateSheetXml(sheet);
            try sheet_xmls.append(self.allocator, sheet_xml);
        }

        // Create simple ZIP structure
        // Note: This is a minimal implementation. Production code should use proper ZIP library.
        try self.writeMinimalZip(output, content_types, rels, workbook_xml, workbook_rels, shared_strings, styles_xml, sheet_xmls.items);
    }

    fn writeMinimalZip(
        self: *XlsxWriter,
        output: *std.ArrayList(u8),
        content_types: []const u8,
        rels: []const u8,
        workbook_xml: []const u8,
        workbook_rels: []const u8,
        shared_strings: []const u8,
        styles_xml: []const u8,
        sheet_xmls: []const []const u8,
    ) !void {
        // ZIP file structure entries
        var entries: std.ArrayList(ZipEntry) = .{};
        defer entries.deinit(self.allocator);

        try entries.append(self.allocator, .{ .name = "[Content_Types].xml", .data = content_types });
        try entries.append(self.allocator, .{ .name = "_rels/.rels", .data = rels });
        try entries.append(self.allocator, .{ .name = "xl/workbook.xml", .data = workbook_xml });
        try entries.append(self.allocator, .{ .name = "xl/_rels/workbook.xml.rels", .data = workbook_rels });
        try entries.append(self.allocator, .{ .name = "xl/sharedStrings.xml", .data = shared_strings });
        try entries.append(self.allocator, .{ .name = "xl/styles.xml", .data = styles_xml });

        for (sheet_xmls, 0..) |sheet_xml, i| {
            var name_buf: [64]u8 = undefined;
            const name = try std.fmt.bufPrint(&name_buf, "xl/worksheets/sheet{d}.xml", .{i + 1});
            const name_copy = try self.allocator.dupe(u8, name);
            try entries.append(self.allocator, .{ .name = name_copy, .data = sheet_xml });
        }

        // Write minimal ZIP structure
        try writeZipEntries(self.allocator, output, entries.items);

        // Free dynamically allocated sheet names
        for (entries.items[6..]) |entry| {
            self.allocator.free(@constCast(entry.name));
        }
    }

    fn generateContentTypes(self: *XlsxWriter) ![]const u8 {
        self.buffer.clearRetainingCapacity();
        const w = self.buffer.writer(self.allocator);

        try w.writeAll(
            \\<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            \\<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
            \\<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
            \\<Default Extension="xml" ContentType="application/xml"/>
            \\<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
            \\<Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
            \\<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
        );

        for (self.workbook.sheets.items, 0..) |_, i| {
            try w.print(
                \\<Override PartName="/xl/worksheets/sheet{d}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
            , .{i + 1});
        }

        try w.writeAll("</Types>");
        return try self.allocator.dupe(u8, self.buffer.items);
    }

    fn generateRels(self: *XlsxWriter) ![]const u8 {
        self.buffer.clearRetainingCapacity();
        const w = self.buffer.writer(self.allocator);

        try w.writeAll(
            \\<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            \\<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            \\<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
            \\</Relationships>
        );

        return try self.allocator.dupe(u8, self.buffer.items);
    }

    fn generateWorkbookXml(self: *XlsxWriter) ![]const u8 {
        self.buffer.clearRetainingCapacity();
        const w = self.buffer.writer(self.allocator);

        try w.writeAll(
            \\<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            \\<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
            \\<sheets>
        );

        for (self.workbook.sheets.items, 0..) |sheet, i| {
            try w.print(
                \\<sheet name="{s}" sheetId="{d}" r:id="rId{d}"/>
            , .{ sheet.name, i + 1, i + 1 });
        }

        try w.writeAll("</sheets></workbook>");
        return try self.allocator.dupe(u8, self.buffer.items);
    }

    fn generateWorkbookRels(self: *XlsxWriter) ![]const u8 {
        self.buffer.clearRetainingCapacity();
        const w = self.buffer.writer(self.allocator);

        try w.writeAll(
            \\<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            \\<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        );

        for (self.workbook.sheets.items, 0..) |_, i| {
            try w.print(
                \\<Relationship Id="rId{d}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet{d}.xml"/>
            , .{ i + 1, i + 1 });
        }

        const sheet_count = self.workbook.sheets.items.len;
        try w.print(
            \\<Relationship Id="rId{d}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>
            \\<Relationship Id="rId{d}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
        , .{ sheet_count + 1, sheet_count + 2 });

        try w.writeAll("</Relationships>");
        return try self.allocator.dupe(u8, self.buffer.items);
    }

    fn generateSharedStrings(self: *XlsxWriter) ![]const u8 {
        self.buffer.clearRetainingCapacity();
        const w = self.buffer.writer(self.allocator);

        const count = self.workbook.shared_strings_list.items.len;

        try w.print(
            \\<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            \\<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="{d}" uniqueCount="{d}">
        , .{ count, count });

        for (self.workbook.shared_strings_list.items) |str| {
            try w.writeAll("<si><t>");
            try writeXmlEscaped(w, str);
            try w.writeAll("</t></si>");
        }

        try w.writeAll("</sst>");
        return try self.allocator.dupe(u8, self.buffer.items);
    }

    fn generateStyles(self: *XlsxWriter) ![]const u8 {
        self.buffer.clearRetainingCapacity();
        const w = self.buffer.writer(self.allocator);

        try w.writeAll(
            \\<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            \\<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
            \\<fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>
            \\<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>
            \\<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>
            \\<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
            \\<cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>
            \\</styleSheet>
        );

        return try self.allocator.dupe(u8, self.buffer.items);
    }

    fn generateSheetXml(self: *XlsxWriter, sheet: *Worksheet) ![]const u8 {
        self.buffer.clearRetainingCapacity();
        const w = self.buffer.writer(self.allocator);

        try w.writeAll(
            \\<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            \\<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
        );

        // Write dimension
        if (sheet.getUsedRange()) |range| {
            var start_buf: [16]u8 = undefined;
            var end_buf: [16]u8 = undefined;
            const start_ref = range.start.toString(&start_buf);
            const end_ref = range.end.toString(&end_buf);
            try w.print("<dimension ref=\"{s}:{s}\"/>", .{ start_ref, end_ref });
        }

        try w.writeAll("<sheetData>");

        // Collect cells by row
        if (sheet.getUsedRange()) |range| {
            var row: u32 = range.start.row;
            while (row <= range.end.row) : (row += 1) {
                var has_cells = false;
                var col: u16 = range.start.col;
                while (col <= range.end.col) : (col += 1) {
                    if (sheet.getCell(row, col)) |_| {
                        has_cells = true;
                        break;
                    }
                }

                if (has_cells) {
                    try w.print("<row r=\"{d}\">", .{row + 1});

                    col = range.start.col;
                    while (col <= range.end.col) : (col += 1) {
                        if (sheet.getCell(row, col)) |c| {
                            try self.writeCellXml(w, c);
                        }
                    }

                    try w.writeAll("</row>");
                }
            }
        }

        try w.writeAll("</sheetData></worksheet>");
        return try self.allocator.dupe(u8, self.buffer.items);
    }

    fn writeCellXml(self: *XlsxWriter, w: anytype, c: *Cell) !void {
        var ref_buf: [16]u8 = undefined;
        const ref = CellRef{ .col = c.col, .row = c.row };
        const ref_str = ref.toString(&ref_buf);

        switch (c.value) {
            .empty => {},
            .string => |s| {
                // Use shared string
                const idx = try self.workbook.addSharedString(s);
                try w.print("<c r=\"{s}\" t=\"s\"><v>{d}</v></c>", .{ ref_str, idx });
            },
            .number => |n| {
                try w.print("<c r=\"{s}\"><v>{d}</v></c>", .{ ref_str, n });
            },
            .boolean => |b| {
                try w.print("<c r=\"{s}\" t=\"b\"><v>{d}</v></c>", .{ ref_str, if (b) @as(u8, 1) else @as(u8, 0) });
            },
            .date => |d| {
                try w.print("<c r=\"{s}\"><v>{d}</v></c>", .{ ref_str, d.toSerial() });
            },
            .time => |t| {
                try w.print("<c r=\"{s}\"><v>{d}</v></c>", .{ ref_str, t.toFraction() });
            },
            .datetime => |dt| {
                try w.print("<c r=\"{s}\"><v>{d}</v></c>", .{ ref_str, dt.toSerial() });
            },
            .formula => |f| {
                try w.print("<c r=\"{s}\"><f>", .{ref_str});
                // Skip leading = if present
                const expr = if (f.expression.len > 0 and f.expression[0] == '=')
                    f.expression[1..]
                else
                    f.expression;
                try writeXmlEscaped(w, expr);
                try w.writeAll("</f></c>");
            },
            .error_value => |e| {
                try w.print("<c r=\"{s}\" t=\"e\"><v>{s}</v></c>", .{ ref_str, e.toString() });
            },
            .rich_string => |rs| {
                const idx = try self.workbook.addSharedString(rs.text);
                try w.print("<c r=\"{s}\" t=\"s\"><v>{d}</v></c>", .{ ref_str, idx });
            },
        }
    }
};

/// Write XML-escaped string
fn writeXmlEscaped(w: anytype, s: []const u8) !void {
    for (s) |c| {
        switch (c) {
            '<' => try w.writeAll("&lt;"),
            '>' => try w.writeAll("&gt;"),
            '&' => try w.writeAll("&amp;"),
            '"' => try w.writeAll("&quot;"),
            '\'' => try w.writeAll("&apos;"),
            else => try w.writeByte(c),
        }
    }
}

/// Write ZIP file with entries (minimal implementation)
fn writeZipEntries(allocator: std.mem.Allocator, output: *std.ArrayList(u8), entries: []const ZipEntry) !void {
    const w = output.writer(allocator);

    var central_directory: std.ArrayList(u8) = .{};
    defer central_directory.deinit(allocator);
    const cd_writer = central_directory.writer(allocator);

    var offset: u32 = 0;

    // Write local file headers and data
    for (entries) |entry| {
        const local_header_start = offset;

        // Local file header signature
        try w.writeAll(&[_]u8{ 0x50, 0x4b, 0x03, 0x04 });
        // Version needed (2.0)
        try w.writeInt(u16, 20, .little);
        // General purpose bit flag
        try w.writeInt(u16, 0, .little);
        // Compression method (0 = store)
        try w.writeInt(u16, 0, .little);
        // Last mod time
        try w.writeInt(u16, 0, .little);
        // Last mod date
        try w.writeInt(u16, 0, .little);
        // CRC-32
        const crc = crc32(entry.data);
        try w.writeInt(u32, crc, .little);
        // Compressed size
        try w.writeInt(u32, @intCast(entry.data.len), .little);
        // Uncompressed size
        try w.writeInt(u32, @intCast(entry.data.len), .little);
        // File name length
        try w.writeInt(u16, @intCast(entry.name.len), .little);
        // Extra field length
        try w.writeInt(u16, 0, .little);
        // File name
        try w.writeAll(entry.name);
        // File data
        try w.writeAll(entry.data);

        offset += 30 + @as(u32, @intCast(entry.name.len)) + @as(u32, @intCast(entry.data.len));

        // Central directory entry
        // Signature
        try cd_writer.writeAll(&[_]u8{ 0x50, 0x4b, 0x01, 0x02 });
        // Version made by
        try cd_writer.writeInt(u16, 20, .little);
        // Version needed
        try cd_writer.writeInt(u16, 20, .little);
        // Flags
        try cd_writer.writeInt(u16, 0, .little);
        // Compression
        try cd_writer.writeInt(u16, 0, .little);
        // Time
        try cd_writer.writeInt(u16, 0, .little);
        // Date
        try cd_writer.writeInt(u16, 0, .little);
        // CRC
        try cd_writer.writeInt(u32, crc, .little);
        // Compressed size
        try cd_writer.writeInt(u32, @intCast(entry.data.len), .little);
        // Uncompressed size
        try cd_writer.writeInt(u32, @intCast(entry.data.len), .little);
        // Name length
        try cd_writer.writeInt(u16, @intCast(entry.name.len), .little);
        // Extra length
        try cd_writer.writeInt(u16, 0, .little);
        // Comment length
        try cd_writer.writeInt(u16, 0, .little);
        // Disk number
        try cd_writer.writeInt(u16, 0, .little);
        // Internal attributes
        try cd_writer.writeInt(u16, 0, .little);
        // External attributes
        try cd_writer.writeInt(u32, 0, .little);
        // Relative offset
        try cd_writer.writeInt(u32, local_header_start, .little);
        // Name
        try cd_writer.writeAll(entry.name);
    }

    const cd_offset = offset;
    const cd_size: u32 = @intCast(central_directory.items.len);

    // Write central directory
    try w.writeAll(central_directory.items);

    // End of central directory
    try w.writeAll(&[_]u8{ 0x50, 0x4b, 0x05, 0x06 });
    // Disk number
    try w.writeInt(u16, 0, .little);
    // CD start disk
    try w.writeInt(u16, 0, .little);
    // CD entries on disk
    try w.writeInt(u16, @intCast(entries.len), .little);
    // Total CD entries
    try w.writeInt(u16, @intCast(entries.len), .little);
    // CD size
    try w.writeInt(u32, cd_size, .little);
    // CD offset
    try w.writeInt(u32, cd_offset, .little);
    // Comment length
    try w.writeInt(u16, 0, .little);
}

/// CRC-32 calculation for ZIP
fn crc32(data: []const u8) u32 {
    const table = comptime blk: {
        @setEvalBranchQuota(3000);
        var t: [256]u32 = undefined;
        for (0..256) |i| {
            var c: u32 = @intCast(i);
            for (0..8) |_| {
                if (c & 1 != 0) {
                    c = 0xedb88320 ^ (c >> 1);
                } else {
                    c = c >> 1;
                }
            }
            t[i] = c;
        }
        break :blk t;
    };

    var c: u32 = 0xffffffff;
    for (data) |b| {
        c = table[(c ^ b) & 0xff] ^ (c >> 8);
    }
    return c ^ 0xffffffff;
}

// Unit tests
test "XlsxWriter basic" {
    const allocator = std.testing.allocator;

    var wb = try Workbook.init(allocator);
    defer wb.deinit();

    var sheet = try wb.addSheet("Test");
    try sheet.setString(0, 0, "Hello");
    try sheet.setNumber(0, 1, 42);

    var output: std.ArrayList(u8) = .{};
    defer output.deinit(allocator);

    try XlsxWriter.writeToBuffer(wb, &output);

    // Verify ZIP signature
    try std.testing.expect(output.items.len > 4);
    try std.testing.expectEqual(@as(u8, 0x50), output.items[0]);
    try std.testing.expectEqual(@as(u8, 0x4b), output.items[1]);
    try std.testing.expectEqual(@as(u8, 0x03), output.items[2]);
    try std.testing.expectEqual(@as(u8, 0x04), output.items[3]);
}

test "XML escaping" {
    var buf: [100]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const w = fbs.writer();

    try writeXmlEscaped(w, "a < b & c > d");

    try std.testing.expectEqualStrings("a &lt; b &amp; c &gt; d", fbs.getWritten());
}

test "CRC32 calculation" {
    const data = "Hello, World!";
    const crc = crc32(data);
    // Known CRC-32 value for "Hello, World!"
    try std.testing.expectEqual(@as(u32, 0xec4ac3d0), crc);
}
