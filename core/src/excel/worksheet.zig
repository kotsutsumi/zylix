//! Zylix Excel - Worksheet Operations
//!
//! Manages individual worksheet data including cells,
//! rows, columns, and sheet-level formatting.

const std = @import("std");
const types = @import("types.zig");
const cell_mod = @import("cell.zig");

const ExcelError = types.ExcelError;
const CellValue = types.CellValue;
const CellStyle = types.CellStyle;
const CellRef = types.CellRef;
const CellRange = types.CellRange;
const Cell = cell_mod.Cell;

/// Forward declaration for Workbook
const Workbook = @import("workbook.zig").Workbook;

/// Excel worksheet containing cells and formatting
pub const Worksheet = struct {
    allocator: std.mem.Allocator,

    /// Sheet name (max 31 chars)
    name: []const u8,

    /// Parent workbook reference
    workbook: *Workbook,

    /// Cell storage (row -> col -> cell)
    cells: std.AutoHashMapUnmanaged(u64, *Cell),

    /// Row heights (row index -> height in points)
    row_heights: std.AutoHashMapUnmanaged(u32, f32),

    /// Column widths (col index -> width in characters)
    col_widths: std.AutoHashMapUnmanaged(u16, f32),

    /// Hidden rows
    hidden_rows: std.AutoHashMapUnmanaged(u32, void),

    /// Hidden columns
    hidden_cols: std.AutoHashMapUnmanaged(u16, void),

    /// Merged cell ranges
    merged_cells: std.ArrayList(CellRange),

    /// Sheet-level options
    options: SheetOptions,

    /// Tracked dimensions (for efficient writing)
    min_row: u32 = std.math.maxInt(u32),
    max_row: u32 = 0,
    min_col: u16 = std.math.maxInt(u16),
    max_col: u16 = 0,

    /// Create a new worksheet
    pub fn init(allocator: std.mem.Allocator, name: []const u8, workbook: *Workbook) !*Worksheet {
        const ws = try allocator.create(Worksheet);
        errdefer allocator.destroy(ws);

        const name_copy = try allocator.dupe(u8, name);
        errdefer allocator.free(name_copy);

        ws.* = .{
            .allocator = allocator,
            .name = name_copy,
            .workbook = workbook,
            .cells = .{},
            .row_heights = .{},
            .col_widths = .{},
            .hidden_rows = .{},
            .hidden_cols = .{},
            .merged_cells = .{},
            .options = .{},
        };

        return ws;
    }

    /// Free worksheet resources
    pub fn deinit(self: *Worksheet) void {
        // Free all cells
        var it = self.cells.valueIterator();
        while (it.next()) |cell_ptr| {
            cell_ptr.*.deinit();
        }
        self.cells.deinit(self.allocator);

        self.row_heights.deinit(self.allocator);
        self.col_widths.deinit(self.allocator);
        self.hidden_rows.deinit(self.allocator);
        self.hidden_cols.deinit(self.allocator);
        self.merged_cells.deinit(self.allocator);

        self.allocator.free(self.name);
        self.allocator.destroy(self);
    }

    /// Generate a unique key for cell coordinates
    fn cellKey(row: u32, col: u16) u64 {
        return (@as(u64, row) << 16) | @as(u64, col);
    }

    /// Update tracked dimensions
    fn updateDimensions(self: *Worksheet, row: u32, col: u16) void {
        self.min_row = @min(self.min_row, row);
        self.max_row = @max(self.max_row, row);
        self.min_col = @min(self.min_col, col);
        self.max_col = @max(self.max_col, col);
    }

    /// Get or create a cell at the specified position
    pub fn getOrCreateCell(self: *Worksheet, row: u32, col: u16) !*Cell {
        const key = cellKey(row, col);

        if (self.cells.get(key)) |existing| {
            return existing;
        }

        // Create new cell
        const new_cell = try Cell.init(self.allocator, row, col);
        try self.cells.put(self.allocator, key, new_cell);
        self.updateDimensions(row, col);

        return new_cell;
    }

    /// Get a cell at the specified position (returns null if not exists)
    pub fn getCell(self: *const Worksheet, row: u32, col: u16) ?*Cell {
        return self.cells.get(cellKey(row, col));
    }

    /// Get a cell by reference string (e.g., "A1")
    pub fn getCellByRef(self: *const Worksheet, ref: []const u8) !?*Cell {
        const cell_ref = try CellRef.parse(ref);
        return self.getCell(cell_ref.row, cell_ref.col);
    }

    /// Set a string value
    pub fn setString(self: *Worksheet, row: u32, col: u16, value: []const u8) !void {
        const c = try self.getOrCreateCell(row, col);
        try c.setString(self.allocator, value);
    }

    /// Set a number value
    pub fn setNumber(self: *Worksheet, row: u32, col: u16, value: f64) !void {
        const c = try self.getOrCreateCell(row, col);
        c.setNumber(value);
    }

    /// Set a boolean value
    pub fn setBoolean(self: *Worksheet, row: u32, col: u16, value: bool) !void {
        const c = try self.getOrCreateCell(row, col);
        c.setBoolean(value);
    }

    /// Set a formula
    pub fn setFormula(self: *Worksheet, row: u32, col: u16, formula: []const u8) !void {
        const c = try self.getOrCreateCell(row, col);
        try c.setFormula(self.allocator, formula);
    }

    /// Set a date value
    pub fn setDate(self: *Worksheet, row: u32, col: u16, date: types.Date) !void {
        const c = try self.getOrCreateCell(row, col);
        c.setDate(date);
    }

    /// Set cell style
    pub fn setCellStyle(self: *Worksheet, row: u32, col: u16, style_index: u32) !void {
        const c = try self.getOrCreateCell(row, col);
        c.style_index = style_index;
    }

    /// Set row height
    pub fn setRowHeight(self: *Worksheet, row: u32, height: f32) !void {
        try self.row_heights.put(self.allocator, row, height);
    }

    /// Get row height
    pub fn getRowHeight(self: *const Worksheet, row: u32) f32 {
        return self.row_heights.get(row) orelse 15.0; // Default height
    }

    /// Set column width
    pub fn setColWidth(self: *Worksheet, col: u16, width: f32) !void {
        try self.col_widths.put(self.allocator, col, width);
    }

    /// Get column width
    pub fn getColWidth(self: *const Worksheet, col: u16) f32 {
        return self.col_widths.get(col) orelse 8.43; // Default width
    }

    /// Hide a row
    pub fn hideRow(self: *Worksheet, row: u32) !void {
        try self.hidden_rows.put(self.allocator, row, {});
    }

    /// Show a hidden row
    pub fn showRow(self: *Worksheet, row: u32) void {
        _ = self.hidden_rows.remove(row);
    }

    /// Check if row is hidden
    pub fn isRowHidden(self: *const Worksheet, row: u32) bool {
        return self.hidden_rows.contains(row);
    }

    /// Hide a column
    pub fn hideCol(self: *Worksheet, col: u16) !void {
        try self.hidden_cols.put(self.allocator, col, {});
    }

    /// Show a hidden column
    pub fn showCol(self: *Worksheet, col: u16) void {
        _ = self.hidden_cols.remove(col);
    }

    /// Check if column is hidden
    pub fn isColHidden(self: *const Worksheet, col: u16) bool {
        return self.hidden_cols.contains(col);
    }

    /// Merge cells in the given range
    pub fn mergeCells(self: *Worksheet, range: CellRange) !void {
        try self.merged_cells.append(self.allocator, range);
    }

    /// Merge cells by reference string (e.g., "A1:C3")
    pub fn mergeCellsByRef(self: *Worksheet, ref: []const u8) !void {
        const range = try CellRange.parse(ref);
        try self.mergeCells(range);
    }

    /// Get the used range dimensions
    pub fn getUsedRange(self: *const Worksheet) ?CellRange {
        if (self.min_row > self.max_row) {
            return null; // No cells
        }
        return .{
            .start = .{ .col = self.min_col, .row = self.min_row },
            .end = .{ .col = self.max_col, .row = self.max_row },
        };
    }

    /// Count non-empty cells
    pub fn cellCount(self: *const Worksheet) usize {
        return self.cells.count();
    }

    /// Iterate over all cells
    pub fn cellIterator(self: *const Worksheet) std.AutoHashMap(u64, *Cell).ValueIterator {
        return self.cells.valueIterator();
    }

    /// Clear all cells in a range
    pub fn clearRange(self: *Worksheet, range: CellRange) void {
        var row = range.start.row;
        while (row <= range.end.row) : (row += 1) {
            var col = range.start.col;
            while (col <= range.end.col) : (col += 1) {
                const key = cellKey(row, col);
                if (self.cells.fetchRemove(key)) |kv| {
                    kv.value.deinit();
                }
            }
        }
    }
};

/// Sheet-level options
pub const SheetOptions = struct {
    /// Default row height
    default_row_height: f32 = 15.0,

    /// Default column width
    default_col_width: f32 = 8.43,

    /// Show gridlines
    show_gridlines: bool = true,

    /// Show row/column headers
    show_headers: bool = true,

    /// Sheet protection
    protected: bool = false,

    /// Tab color (ARGB)
    tab_color: ?u32 = null,

    /// Zoom scale (percent)
    zoom: u16 = 100,

    /// Frozen pane configuration
    freeze_row: u32 = 0,
    freeze_col: u16 = 0,

    /// Page setup
    page_setup: types.PageSetup = .{},
};

// Unit tests
test "Worksheet cell operations" {
    const allocator = std.testing.allocator;

    // Create minimal workbook for testing
    const workbook = @import("workbook.zig");
    var wb = try workbook.Workbook.init(allocator);
    defer wb.deinit();

    var ws = try Worksheet.init(allocator, "Test", wb);
    defer ws.deinit();

    // Test setString
    try ws.setString(0, 0, "Hello");
    const c1 = ws.getCell(0, 0);
    try std.testing.expect(c1 != null);
    try std.testing.expectEqualStrings("Hello", c1.?.getString().?);

    // Test setNumber
    try ws.setNumber(1, 0, 42.5);
    const c2 = ws.getCell(1, 0);
    try std.testing.expect(c2 != null);
    try std.testing.expectEqual(@as(f64, 42.5), c2.?.getNumber().?);

    // Test setBoolean
    try ws.setBoolean(2, 0, true);
    const c3 = ws.getCell(2, 0);
    try std.testing.expect(c3 != null);
    try std.testing.expectEqual(true, c3.?.getBoolean().?);
}

test "Worksheet dimensions tracking" {
    const allocator = std.testing.allocator;

    const workbook = @import("workbook.zig");
    var wb = try workbook.Workbook.init(allocator);
    defer wb.deinit();

    var ws = try Worksheet.init(allocator, "Test", wb);
    defer ws.deinit();

    try ws.setString(5, 3, "A");
    try ws.setString(10, 8, "B");
    try ws.setString(2, 1, "C");

    const range = ws.getUsedRange();
    try std.testing.expect(range != null);
    try std.testing.expectEqual(@as(u32, 2), range.?.start.row);
    try std.testing.expectEqual(@as(u16, 1), range.?.start.col);
    try std.testing.expectEqual(@as(u32, 10), range.?.end.row);
    try std.testing.expectEqual(@as(u16, 8), range.?.end.col);
}

test "Worksheet row/column sizing" {
    const allocator = std.testing.allocator;

    const workbook = @import("workbook.zig");
    var wb = try workbook.Workbook.init(allocator);
    defer wb.deinit();

    var ws = try Worksheet.init(allocator, "Test", wb);
    defer ws.deinit();

    try ws.setRowHeight(0, 30.0);
    try ws.setColWidth(0, 20.0);

    try std.testing.expectEqual(@as(f32, 30.0), ws.getRowHeight(0));
    try std.testing.expectEqual(@as(f32, 20.0), ws.getColWidth(0));

    // Default values for unset rows/columns
    try std.testing.expectEqual(@as(f32, 15.0), ws.getRowHeight(99));
    try std.testing.expectEqual(@as(f32, 8.43), ws.getColWidth(99));
}
