//! Zylix Excel - Workbook Management
//!
//! Manages Excel workbook structure including worksheets,
//! shared strings, styles, and metadata.

const std = @import("std");
const types = @import("types.zig");
const worksheet = @import("worksheet.zig");
const style = @import("style.zig");

const ExcelError = types.ExcelError;
const Worksheet = worksheet.Worksheet;
const StyleManager = style.StyleManager;

/// Excel workbook containing multiple worksheets
pub const Workbook = struct {
    allocator: std.mem.Allocator,

    /// Worksheets in this workbook
    sheets: std.ArrayList(*Worksheet),

    /// Shared strings table (for string deduplication)
    shared_strings: std.StringHashMapUnmanaged(u32),
    shared_strings_list: std.ArrayList([]const u8),

    /// Style manager for cell formatting
    styles: *StyleManager,

    /// Workbook metadata
    properties: WorkbookProperties,

    /// Active sheet index
    active_sheet: usize,

    /// Create a new empty workbook
    pub fn init(allocator: std.mem.Allocator) !*Workbook {
        const wb = try allocator.create(Workbook);
        errdefer allocator.destroy(wb);

        const styles_mgr = try StyleManager.init(allocator);
        errdefer styles_mgr.deinit();

        wb.* = .{
            .allocator = allocator,
            .sheets = .{},
            .shared_strings = .{},
            .shared_strings_list = .{},
            .styles = styles_mgr,
            .properties = .{},
            .active_sheet = 0,
        };

        return wb;
    }

    /// Free all workbook resources
    pub fn deinit(self: *Workbook) void {
        // Free all worksheets
        for (self.sheets.items) |sheet| {
            sheet.deinit();
        }
        self.sheets.deinit(self.allocator);

        // Free shared strings (we own the copies)
        for (self.shared_strings_list.items) |str| {
            self.allocator.free(str);
        }
        self.shared_strings_list.deinit(self.allocator);
        self.shared_strings.deinit(self.allocator);

        // Free style manager
        self.styles.deinit();

        // Free self
        self.allocator.destroy(self);
    }

    /// Add a new worksheet with the given name
    pub fn addSheet(self: *Workbook, name: []const u8) !*Worksheet {
        // Validate sheet name
        if (name.len == 0 or name.len > 31) {
            return ExcelError.InvalidFile;
        }

        // Check for duplicate names
        for (self.sheets.items) |existing| {
            if (std.mem.eql(u8, existing.name, name)) {
                return ExcelError.SheetNotFound; // Sheet already exists
            }
        }

        // Create and add the new sheet
        const sheet = try Worksheet.init(self.allocator, name, self);
        try self.sheets.append(self.allocator, sheet);

        return sheet;
    }

    /// Get a worksheet by name
    pub fn getSheet(self: *Workbook, name: []const u8) ?*Worksheet {
        for (self.sheets.items) |sheet| {
            if (std.mem.eql(u8, sheet.name, name)) {
                return sheet;
            }
        }
        return null;
    }

    /// Get a worksheet by index
    pub fn getSheetByIndex(self: *Workbook, index: usize) ?*Worksheet {
        if (index >= self.sheets.items.len) {
            return null;
        }
        return self.sheets.items[index];
    }

    /// Get number of worksheets
    pub fn sheetCount(self: *const Workbook) usize {
        return self.sheets.items.len;
    }

    /// Remove a worksheet by name
    pub fn removeSheet(self: *Workbook, name: []const u8) !void {
        for (self.sheets.items, 0..) |sheet, i| {
            if (std.mem.eql(u8, sheet.name, name)) {
                _ = self.sheets.orderedRemove(i);
                sheet.deinit();

                // Adjust active sheet index
                if (self.active_sheet >= self.sheets.items.len and self.sheets.items.len > 0) {
                    self.active_sheet = self.sheets.items.len - 1;
                }
                return;
            }
        }
        return ExcelError.SheetNotFound;
    }

    /// Add a string to the shared strings table
    /// Returns the index of the string
    pub fn addSharedString(self: *Workbook, str: []const u8) !u32 {
        // Check if string already exists
        if (self.shared_strings.get(str)) |index| {
            return index;
        }

        // Add new string
        const index: u32 = @intCast(self.shared_strings_list.items.len);
        const owned = try self.allocator.dupe(u8, str);
        errdefer self.allocator.free(owned);

        try self.shared_strings_list.append(self.allocator, owned);
        try self.shared_strings.put(self.allocator, owned, index);

        return index;
    }

    /// Get a shared string by index
    pub fn getSharedString(self: *const Workbook, index: u32) ?[]const u8 {
        if (index >= self.shared_strings_list.items.len) {
            return null;
        }
        return self.shared_strings_list.items[index];
    }

    /// Set the active worksheet
    pub fn setActiveSheet(self: *Workbook, index: usize) !void {
        if (index >= self.sheets.items.len) {
            return ExcelError.SheetNotFound;
        }
        self.active_sheet = index;
    }

    /// Get the active worksheet
    pub fn getActiveSheet(self: *Workbook) ?*Worksheet {
        return self.getSheetByIndex(self.active_sheet);
    }
};

/// Workbook metadata properties
pub const WorkbookProperties = struct {
    /// Document title
    title: ?[]const u8 = null,

    /// Document subject
    subject: ?[]const u8 = null,

    /// Document author
    author: ?[]const u8 = null,

    /// Document keywords
    keywords: ?[]const u8 = null,

    /// Document comments/description
    comments: ?[]const u8 = null,

    /// Application that created the document
    application: []const u8 = "Zylix",

    /// Document creation date
    created: ?i64 = null,

    /// Document modification date
    modified: ?i64 = null,
};

// Unit tests
test "Workbook creation" {
    const allocator = std.testing.allocator;

    var wb = try Workbook.init(allocator);
    defer wb.deinit();

    try std.testing.expectEqual(@as(usize, 0), wb.sheetCount());
}

test "Workbook add sheets" {
    const allocator = std.testing.allocator;

    var wb = try Workbook.init(allocator);
    defer wb.deinit();

    _ = try wb.addSheet("Sheet1");
    _ = try wb.addSheet("Sheet2");

    try std.testing.expectEqual(@as(usize, 2), wb.sheetCount());

    const sheet = wb.getSheet("Sheet1");
    try std.testing.expect(sheet != null);
    try std.testing.expectEqualStrings("Sheet1", sheet.?.name);
}

test "Workbook shared strings" {
    const allocator = std.testing.allocator;

    var wb = try Workbook.init(allocator);
    defer wb.deinit();

    const idx1 = try wb.addSharedString("Hello");
    const idx2 = try wb.addSharedString("World");
    const idx3 = try wb.addSharedString("Hello"); // Duplicate

    try std.testing.expectEqual(@as(u32, 0), idx1);
    try std.testing.expectEqual(@as(u32, 1), idx2);
    try std.testing.expectEqual(@as(u32, 0), idx3); // Should return existing index

    try std.testing.expectEqualStrings("Hello", wb.getSharedString(0).?);
    try std.testing.expectEqualStrings("World", wb.getSharedString(1).?);
}

test "Workbook remove sheet" {
    const allocator = std.testing.allocator;

    var wb = try Workbook.init(allocator);
    defer wb.deinit();

    _ = try wb.addSheet("Sheet1");
    _ = try wb.addSheet("Sheet2");

    try std.testing.expectEqual(@as(usize, 2), wb.sheetCount());

    try wb.removeSheet("Sheet1");
    try std.testing.expectEqual(@as(usize, 1), wb.sheetCount());

    try std.testing.expect(wb.getSheet("Sheet1") == null);
    try std.testing.expect(wb.getSheet("Sheet2") != null);
}
