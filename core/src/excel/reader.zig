//! Zylix Excel - XLSX Reader
//!
//! Parses Office Open XML (XLSX) files.
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
const Date = types.Date;

/// XLSX file reader
pub const XlsxReader = struct {
    allocator: std.mem.Allocator,
    workbook: *Workbook,

    /// Read workbook from file
    pub fn read(allocator: std.mem.Allocator, path: []const u8) !*Workbook {
        const file = std.fs.cwd().openFile(path, .{}) catch {
            return ExcelError.ReadError;
        };
        defer file.close();

        const data = file.readToEndAlloc(allocator, 100 * 1024 * 1024) catch {
            return ExcelError.ReadError;
        };
        defer allocator.free(data);

        return readFromBuffer(allocator, data);
    }

    /// Read workbook from byte buffer
    pub fn readFromBuffer(allocator: std.mem.Allocator, data: []const u8) !*Workbook {
        var reader = XlsxReader{
            .allocator = allocator,
            .workbook = try Workbook.init(allocator),
        };
        errdefer reader.workbook.deinit();

        try reader.parseZip(data);

        return reader.workbook;
    }

    fn parseZip(self: *XlsxReader, data: []const u8) !void {
        // Find and parse ZIP entries
        var entries = try self.extractZipEntries(data);
        defer {
            for (entries.items) |entry| {
                self.allocator.free(entry.data);
            }
            entries.deinit(self.allocator);
        }

        // Parse shared strings first
        for (entries.items) |entry| {
            if (std.mem.eql(u8, entry.name, "xl/sharedStrings.xml")) {
                try self.parseSharedStrings(entry.data);
                break;
            }
        }

        // Parse workbook to get sheet names
        var sheet_names: std.ArrayList([]const u8) = .{};
        defer {
            for (sheet_names.items) |name| {
                self.allocator.free(name);
            }
            sheet_names.deinit(self.allocator);
        }

        for (entries.items) |entry| {
            if (std.mem.eql(u8, entry.name, "xl/workbook.xml")) {
                try self.parseWorkbookXml(entry.data, &sheet_names);
                break;
            }
        }

        // Parse worksheets
        for (entries.items) |entry| {
            if (std.mem.startsWith(u8, entry.name, "xl/worksheets/sheet") and
                std.mem.endsWith(u8, entry.name, ".xml"))
            {
                // Extract sheet number from filename
                const start = "xl/worksheets/sheet".len;
                const end = entry.name.len - ".xml".len;
                const num_str = entry.name[start..end];
                const sheet_idx = std.fmt.parseInt(usize, num_str, 10) catch continue;

                if (sheet_idx > 0 and sheet_idx <= sheet_names.items.len) {
                    const name = sheet_names.items[sheet_idx - 1];
                    const sheet = try self.workbook.addSheet(name);
                    try self.parseSheetXml(entry.data, sheet);
                }
            }
        }
    }

    const ZipEntry = struct {
        name: []const u8,
        data: []const u8,
    };

    fn extractZipEntries(self: *XlsxReader, data: []const u8) !std.ArrayList(ZipEntry) {
        var entries: std.ArrayList(ZipEntry) = .{};
        errdefer {
            for (entries.items) |entry| {
                self.allocator.free(entry.data);
            }
            entries.deinit(self.allocator);
        }

        var pos: usize = 0;

        while (pos + 30 <= data.len) {
            // Check for local file header signature
            if (data[pos] != 0x50 or data[pos + 1] != 0x4b) break;
            if (data[pos + 2] != 0x03 or data[pos + 3] != 0x04) break;

            // Parse header fields
            const compression = std.mem.readInt(u16, data[pos + 8 ..][0..2], .little);
            const compressed_size = std.mem.readInt(u32, data[pos + 18 ..][0..4], .little);
            const uncompressed_size = std.mem.readInt(u32, data[pos + 22 ..][0..4], .little);
            const name_len = std.mem.readInt(u16, data[pos + 26 ..][0..2], .little);
            const extra_len = std.mem.readInt(u16, data[pos + 28 ..][0..2], .little);

            const name_start = pos + 30;
            const name_end = name_start + name_len;
            const data_start = name_end + extra_len;
            const data_end = data_start + compressed_size;

            if (data_end > data.len) break;

            const name = data[name_start..name_end];

            // Only handle uncompressed entries for now
            if (compression == 0) {
                const entry_data = try self.allocator.dupe(u8, data[data_start..data_end]);
                try entries.append(self.allocator, .{
                    .name = name,
                    .data = entry_data,
                });
            } else if (compression == 8) {
                // DEFLATE compression - use std.compress.zlib
                const decompressed = try self.decompressDeflate(data[data_start..data_end], uncompressed_size);
                try entries.append(self.allocator, .{
                    .name = name,
                    .data = decompressed,
                });
            }

            pos = data_end;
        }

        return entries;
    }

    fn decompressDeflate(self: *XlsxReader, compressed: []const u8, expected_size: u32) ![]const u8 {
        // Use Zig's built-in DEFLATE decompression
        var output = try self.allocator.alloc(u8, expected_size);
        errdefer self.allocator.free(output);

        var fbs = std.io.fixedBufferStream(compressed);
        var decompressor = std.compress.flate.decompressor(.raw, fbs.reader());

        var total_read: usize = 0;
        while (total_read < expected_size) {
            const n = decompressor.read(output[total_read..]) catch |err| {
                if (err == error.EndOfStream) break;
                return ExcelError.CompressionError;
            };
            if (n == 0) break;
            total_read += n;
        }

        if (total_read != expected_size) {
            // Resize to actual size
            return self.allocator.realloc(output, total_read) catch output;
        }

        return output;
    }

    fn parseSharedStrings(self: *XlsxReader, xml: []const u8) !void {
        // Simple XML parsing for shared strings
        var pos: usize = 0;

        while (pos < xml.len) {
            // Find <t> tags
            const t_start = std.mem.indexOfPos(u8, xml, pos, "<t>") orelse
                std.mem.indexOfPos(u8, xml, pos, "<t ") orelse break;

            // Find the closing >
            const content_start = std.mem.indexOfPos(u8, xml, t_start, ">") orelse break;
            const content_begin = content_start + 1;

            // Find </t>
            const t_end = std.mem.indexOfPos(u8, xml, content_begin, "</t>") orelse break;

            const text = xml[content_begin..t_end];
            const decoded = try self.decodeXmlEntities(text);
            errdefer self.allocator.free(decoded);

            _ = try self.workbook.addSharedString(decoded);
            self.allocator.free(decoded);

            pos = t_end + 4;
        }
    }

    fn parseWorkbookXml(self: *XlsxReader, xml: []const u8, sheet_names: *std.ArrayList([]const u8)) !void {
        var pos: usize = 0;

        while (pos < xml.len) {
            // Find <sheet tags
            const sheet_start = std.mem.indexOfPos(u8, xml, pos, "<sheet ") orelse break;
            const sheet_end = std.mem.indexOfPos(u8, xml, sheet_start, "/>") orelse
                std.mem.indexOfPos(u8, xml, sheet_start, ">") orelse break;

            const sheet_tag = xml[sheet_start..sheet_end];

            // Extract name attribute
            if (std.mem.indexOf(u8, sheet_tag, "name=\"")) |name_start| {
                const value_start = name_start + 6;
                if (std.mem.indexOfPos(u8, sheet_tag, value_start, "\"")) |name_end| {
                    const name = sheet_tag[value_start..name_end];
                    const decoded = try self.decodeXmlEntities(name);
                    try sheet_names.append(self.allocator, decoded);
                }
            }

            pos = sheet_end + 1;
        }
    }

    fn parseSheetXml(self: *XlsxReader, xml: []const u8, sheet: *Worksheet) !void {
        var pos: usize = 0;

        while (pos < xml.len) {
            // Find <c (cell) tags
            const c_start = std.mem.indexOfPos(u8, xml, pos, "<c ") orelse break;
            const c_end = std.mem.indexOfPos(u8, xml, c_start, "</c>") orelse
                std.mem.indexOfPos(u8, xml, c_start, "/>") orelse break;

            const cell_xml = xml[c_start..c_end];

            try self.parseCellXml(cell_xml, sheet);

            pos = c_end + 1;
        }
    }

    fn parseCellXml(self: *XlsxReader, cell_xml: []const u8, sheet: *Worksheet) !void {
        // Extract cell reference
        const r_start = std.mem.indexOf(u8, cell_xml, "r=\"") orelse return;
        const r_value_start = r_start + 3;
        const r_end = std.mem.indexOfPos(u8, cell_xml, r_value_start, "\"") orelse return;
        const ref_str = cell_xml[r_value_start..r_end];

        const cell_ref = CellRef.parse(ref_str) catch return;

        // Determine cell type
        var cell_type: u8 = 'n'; // Default to number
        if (std.mem.indexOf(u8, cell_xml, "t=\"s\"")) |_| {
            cell_type = 's'; // Shared string
        } else if (std.mem.indexOf(u8, cell_xml, "t=\"b\"")) |_| {
            cell_type = 'b'; // Boolean
        } else if (std.mem.indexOf(u8, cell_xml, "t=\"e\"")) |_| {
            cell_type = 'e'; // Error
        } else if (std.mem.indexOf(u8, cell_xml, "t=\"str\"")) |_| {
            cell_type = 'i'; // Inline string
        }

        // Extract value
        const v_start = std.mem.indexOf(u8, cell_xml, "<v>") orelse return;
        const v_value_start = v_start + 3;
        const v_end = std.mem.indexOfPos(u8, cell_xml, v_value_start, "</v>") orelse return;
        const value_str = cell_xml[v_value_start..v_end];

        switch (cell_type) {
            's' => {
                // Shared string index
                const idx = std.fmt.parseInt(u32, value_str, 10) catch return;
                if (self.workbook.getSharedString(idx)) |str| {
                    try sheet.setString(cell_ref.row, cell_ref.col, str);
                }
            },
            'b' => {
                // Boolean
                const val = std.mem.eql(u8, value_str, "1") or std.mem.eql(u8, value_str, "true");
                try sheet.setBoolean(cell_ref.row, cell_ref.col, val);
            },
            'e' => {
                // Error - treat as string
                try sheet.setString(cell_ref.row, cell_ref.col, value_str);
            },
            'i' => {
                // Inline string
                const decoded = try self.decodeXmlEntities(value_str);
                defer self.allocator.free(decoded);
                try sheet.setString(cell_ref.row, cell_ref.col, decoded);
            },
            else => {
                // Number
                const num = std.fmt.parseFloat(f64, value_str) catch return;
                try sheet.setNumber(cell_ref.row, cell_ref.col, num);
            },
        }
    }

    fn decodeXmlEntities(self: *XlsxReader, text: []const u8) ![]const u8 {
        var result: std.ArrayList(u8) = .{};
        errdefer result.deinit(self.allocator);

        var i: usize = 0;
        while (i < text.len) {
            if (text[i] == '&') {
                if (std.mem.startsWith(u8, text[i..], "&lt;")) {
                    try result.append(self.allocator, '<');
                    i += 4;
                } else if (std.mem.startsWith(u8, text[i..], "&gt;")) {
                    try result.append(self.allocator, '>');
                    i += 4;
                } else if (std.mem.startsWith(u8, text[i..], "&amp;")) {
                    try result.append(self.allocator, '&');
                    i += 5;
                } else if (std.mem.startsWith(u8, text[i..], "&quot;")) {
                    try result.append(self.allocator, '"');
                    i += 6;
                } else if (std.mem.startsWith(u8, text[i..], "&apos;")) {
                    try result.append(self.allocator, '\'');
                    i += 6;
                } else {
                    try result.append(self.allocator, text[i]);
                    i += 1;
                }
            } else {
                try result.append(self.allocator, text[i]);
                i += 1;
            }
        }

        return result.toOwnedSlice(self.allocator);
    }
};

// Unit tests
test "XlsxReader decode XML entities" {
    const allocator = std.testing.allocator;

    // Create a minimal workbook for testing
    var wb = try Workbook.init(allocator);
    defer wb.deinit();

    var reader = XlsxReader{
        .allocator = allocator,
        .workbook = wb,
    };

    const decoded = try reader.decodeXmlEntities("a &lt; b &amp; c &gt; d");
    defer allocator.free(decoded);

    try std.testing.expectEqualStrings("a < b & c > d", decoded);
}

test "XlsxReader parse simple shared strings" {
    const allocator = std.testing.allocator;

    var wb = try Workbook.init(allocator);
    defer wb.deinit();

    var reader = XlsxReader{
        .allocator = allocator,
        .workbook = wb,
    };

    const xml =
        \\<?xml version="1.0"?>
        \\<sst><si><t>Hello</t></si><si><t>World</t></si></sst>
    ;

    try reader.parseSharedStrings(xml);

    try std.testing.expectEqualStrings("Hello", wb.getSharedString(0).?);
    try std.testing.expectEqualStrings("World", wb.getSharedString(1).?);
}

test "XlsxReader parse workbook sheets" {
    const allocator = std.testing.allocator;

    var wb = try Workbook.init(allocator);
    defer wb.deinit();

    var reader = XlsxReader{
        .allocator = allocator,
        .workbook = wb,
    };

    const xml =
        \\<?xml version="1.0"?>
        \\<workbook><sheets>
        \\<sheet name="Sheet1" sheetId="1" r:id="rId1"/>
        \\<sheet name="Data" sheetId="2" r:id="rId2"/>
        \\</sheets></workbook>
    ;

    var sheet_names: std.ArrayList([]const u8) = .{};
    defer {
        for (sheet_names.items) |name| {
            allocator.free(name);
        }
        sheet_names.deinit(allocator);
    }

    try reader.parseWorkbookXml(xml, &sheet_names);

    try std.testing.expectEqual(@as(usize, 2), sheet_names.items.len);
    try std.testing.expectEqualStrings("Sheet1", sheet_names.items[0]);
    try std.testing.expectEqualStrings("Data", sheet_names.items[1]);
}

test "XlsxReader parse sheet cells" {
    const allocator = std.testing.allocator;

    var wb = try Workbook.init(allocator);
    defer wb.deinit();

    _ = try wb.addSharedString("Hello");
    _ = try wb.addSharedString("World");

    var reader = XlsxReader{
        .allocator = allocator,
        .workbook = wb,
    };

    var sheet = try wb.addSheet("Test");

    const xml =
        \\<?xml version="1.0"?>
        \\<worksheet><sheetData>
        \\<row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1"><v>42</v></c></row>
        \\</sheetData></worksheet>
    ;

    try reader.parseSheetXml(xml, sheet);

    const c1 = sheet.getCell(0, 0);
    try std.testing.expect(c1 != null);
    try std.testing.expectEqualStrings("Hello", c1.?.getString().?);

    const c2 = sheet.getCell(0, 1);
    try std.testing.expect(c2 != null);
    try std.testing.expectEqual(@as(f64, 42), c2.?.getNumber().?);
}
