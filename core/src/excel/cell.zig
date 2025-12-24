//! Zylix Excel - Cell Operations
//!
//! Individual cell data storage and manipulation.

const std = @import("std");
const types = @import("types.zig");

const CellType = types.CellType;
const CellValue = types.CellValue;
const Date = types.Date;
const Time = types.Time;
const DateTime = types.DateTime;
const Formula = types.Formula;
const CellErrorValue = types.CellErrorValue;

/// Individual cell in a worksheet
pub const Cell = struct {
    allocator: std.mem.Allocator,

    /// Cell position
    row: u32,
    col: u16,

    /// Cell value
    value: CellValue,

    /// Style index (references workbook style manager)
    style_index: u32,

    /// Whether this cell has owned string data
    owns_string: bool,

    /// Create a new empty cell
    pub fn init(allocator: std.mem.Allocator, row: u32, col: u16) !*Cell {
        const cell = try allocator.create(Cell);
        cell.* = .{
            .allocator = allocator,
            .row = row,
            .col = col,
            .value = .{ .empty = {} },
            .style_index = 0,
            .owns_string = false,
        };
        return cell;
    }

    /// Free cell resources
    pub fn deinit(self: *Cell) void {
        self.clearValue();
        self.allocator.destroy(self);
    }

    /// Clear the cell value and free any owned memory
    fn clearValue(self: *Cell) void {
        switch (self.value) {
            .string => |s| {
                if (self.owns_string) {
                    self.allocator.free(s);
                }
            },
            .formula => |f| {
                if (self.owns_string) {
                    self.allocator.free(f.expression);
                }
            },
            else => {},
        }
        self.value = .{ .empty = {} };
        self.owns_string = false;
    }

    /// Get the cell type
    pub fn getCellType(self: *const Cell) CellType {
        return self.value;
    }

    /// Check if cell is empty
    pub fn isEmpty(self: *const Cell) bool {
        return self.value == .empty;
    }

    /// Set string value
    pub fn setString(self: *Cell, allocator: std.mem.Allocator, value: []const u8) !void {
        self.clearValue();
        const owned = try allocator.dupe(u8, value);
        self.value = .{ .string = owned };
        self.owns_string = true;
    }

    /// Set string value without copying (caller retains ownership)
    pub fn setStringRef(self: *Cell, value: []const u8) void {
        self.clearValue();
        self.value = .{ .string = value };
        self.owns_string = false;
    }

    /// Get string value
    pub fn getString(self: *const Cell) ?[]const u8 {
        return switch (self.value) {
            .string => |s| s,
            else => null,
        };
    }

    /// Set number value
    pub fn setNumber(self: *Cell, value: f64) void {
        self.clearValue();
        self.value = .{ .number = value };
    }

    /// Get number value
    pub fn getNumber(self: *const Cell) ?f64 {
        return switch (self.value) {
            .number => |n| n,
            else => null,
        };
    }

    /// Set boolean value
    pub fn setBoolean(self: *Cell, value: bool) void {
        self.clearValue();
        self.value = .{ .boolean = value };
    }

    /// Get boolean value
    pub fn getBoolean(self: *const Cell) ?bool {
        return switch (self.value) {
            .boolean => |b| b,
            else => null,
        };
    }

    /// Set date value
    pub fn setDate(self: *Cell, date: Date) void {
        self.clearValue();
        self.value = .{ .date = date };
    }

    /// Get date value
    pub fn getDate(self: *const Cell) ?Date {
        return switch (self.value) {
            .date => |d| d,
            else => null,
        };
    }

    /// Set time value
    pub fn setTime(self: *Cell, time: Time) void {
        self.clearValue();
        self.value = .{ .time = time };
    }

    /// Get time value
    pub fn getTime(self: *const Cell) ?Time {
        return switch (self.value) {
            .time => |t| t,
            else => null,
        };
    }

    /// Set datetime value
    pub fn setDateTime(self: *Cell, datetime: DateTime) void {
        self.clearValue();
        self.value = .{ .datetime = datetime };
    }

    /// Get datetime value
    pub fn getDateTime(self: *const Cell) ?DateTime {
        return switch (self.value) {
            .datetime => |dt| dt,
            else => null,
        };
    }

    /// Set formula
    pub fn setFormula(self: *Cell, allocator: std.mem.Allocator, expression: []const u8) !void {
        self.clearValue();
        const owned = try allocator.dupe(u8, expression);
        self.value = .{ .formula = .{ .expression = owned, .cached_value = null } };
        self.owns_string = true;
    }

    /// Get formula
    pub fn getFormula(self: *const Cell) ?Formula {
        return switch (self.value) {
            .formula => |f| f,
            else => null,
        };
    }

    /// Set error value
    pub fn setError(self: *Cell, err: CellErrorValue) void {
        self.clearValue();
        self.value = .{ .error_value = err };
    }

    /// Get error value
    pub fn getError(self: *const Cell) ?CellErrorValue {
        return switch (self.value) {
            .error_value => |e| e,
            else => null,
        };
    }

    /// Get the value as a number (converts dates/times to serial)
    pub fn getNumericValue(self: *const Cell) ?f64 {
        return switch (self.value) {
            .number => |n| n,
            .date => |d| d.toSerial(),
            .time => |t| t.toFraction(),
            .datetime => |dt| dt.toSerial(),
            .boolean => |b| if (b) @as(f64, 1) else @as(f64, 0),
            else => null,
        };
    }

    /// Get the value as a display string
    pub fn getDisplayValue(self: *const Cell, buffer: []u8) []const u8 {
        return switch (self.value) {
            .empty => "",
            .string => |s| s,
            .number => |n| std.fmt.bufPrint(buffer, "{d}", .{n}) catch "",
            .boolean => |b| if (b) "TRUE" else "FALSE",
            .date => |d| std.fmt.bufPrint(buffer, "{d}-{d:0>2}-{d:0>2}", .{ d.year, d.month, d.day }) catch "",
            .time => |t| std.fmt.bufPrint(buffer, "{d:0>2}:{d:0>2}:{d:0>2}", .{ t.hour, t.minute, t.second }) catch "",
            .datetime => |dt| std.fmt.bufPrint(buffer, "{d}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}", .{
                dt.date.year,
                dt.date.month,
                dt.date.day,
                dt.time.hour,
                dt.time.minute,
            }) catch "",
            .formula => |f| f.expression,
            .error_value => |e| e.toString(),
            .rich_string => |rs| rs.text,
        };
    }

    /// Copy cell value to another cell
    pub fn copyTo(self: *const Cell, other: *Cell) !void {
        other.clearValue();

        switch (self.value) {
            .empty => other.value = .{ .empty = {} },
            .string => |s| {
                const owned = try other.allocator.dupe(u8, s);
                other.value = .{ .string = owned };
                other.owns_string = true;
            },
            .number => |n| other.value = .{ .number = n },
            .boolean => |b| other.value = .{ .boolean = b },
            .date => |d| other.value = .{ .date = d },
            .time => |t| other.value = .{ .time = t },
            .datetime => |dt| other.value = .{ .datetime = dt },
            .formula => |f| {
                const owned = try other.allocator.dupe(u8, f.expression);
                other.value = .{ .formula = .{ .expression = owned, .cached_value = f.cached_value } };
                other.owns_string = true;
            },
            .error_value => |e| other.value = .{ .error_value = e },
            .rich_string => |rs| {
                // For simplicity, just copy text without runs
                const owned = try other.allocator.dupe(u8, rs.text);
                other.value = .{ .string = owned };
                other.owns_string = true;
            },
        }

        other.style_index = self.style_index;
    }
};

// Unit tests
test "Cell string operations" {
    const allocator = std.testing.allocator;

    var cell = try Cell.init(allocator, 0, 0);
    defer cell.deinit();

    try cell.setString(allocator, "Hello, World!");
    try std.testing.expectEqualStrings("Hello, World!", cell.getString().?);
    try std.testing.expect(!cell.isEmpty());
}

test "Cell number operations" {
    const allocator = std.testing.allocator;

    var cell = try Cell.init(allocator, 0, 0);
    defer cell.deinit();

    cell.setNumber(3.14159);
    try std.testing.expectEqual(@as(f64, 3.14159), cell.getNumber().?);
}

test "Cell boolean operations" {
    const allocator = std.testing.allocator;

    var cell = try Cell.init(allocator, 0, 0);
    defer cell.deinit();

    cell.setBoolean(true);
    try std.testing.expectEqual(true, cell.getBoolean().?);

    cell.setBoolean(false);
    try std.testing.expectEqual(false, cell.getBoolean().?);
}

test "Cell date operations" {
    const allocator = std.testing.allocator;

    var cell = try Cell.init(allocator, 0, 0);
    defer cell.deinit();

    const date = Date{ .year = 2024, .month = 12, .day = 25 };
    cell.setDate(date);

    const retrieved = cell.getDate().?;
    try std.testing.expectEqual(@as(i16, 2024), retrieved.year);
    try std.testing.expectEqual(@as(u8, 12), retrieved.month);
    try std.testing.expectEqual(@as(u8, 25), retrieved.day);
}

test "Cell formula operations" {
    const allocator = std.testing.allocator;

    var cell = try Cell.init(allocator, 0, 0);
    defer cell.deinit();

    try cell.setFormula(allocator, "=SUM(A1:A10)");
    const formula = cell.getFormula().?;
    try std.testing.expectEqualStrings("=SUM(A1:A10)", formula.expression);
}

test "Cell error operations" {
    const allocator = std.testing.allocator;

    var cell = try Cell.init(allocator, 0, 0);
    defer cell.deinit();

    cell.setError(.div_zero);
    try std.testing.expectEqual(CellErrorValue.div_zero, cell.getError().?);

    var buffer: [32]u8 = undefined;
    try std.testing.expectEqualStrings("#DIV/0!", cell.getDisplayValue(&buffer));
}

test "Cell value overwrite" {
    const allocator = std.testing.allocator;

    var cell = try Cell.init(allocator, 0, 0);
    defer cell.deinit();

    // Set string
    try cell.setString(allocator, "Hello");
    try std.testing.expectEqualStrings("Hello", cell.getString().?);

    // Overwrite with number (should free string)
    cell.setNumber(42.0);
    try std.testing.expectEqual(@as(f64, 42.0), cell.getNumber().?);
    try std.testing.expect(cell.getString() == null);
}

test "Cell copy" {
    const allocator = std.testing.allocator;

    var cell1 = try Cell.init(allocator, 0, 0);
    defer cell1.deinit();

    var cell2 = try Cell.init(allocator, 1, 1);
    defer cell2.deinit();

    try cell1.setString(allocator, "Copy me");
    cell1.style_index = 5;

    try cell1.copyTo(cell2);

    try std.testing.expectEqualStrings("Copy me", cell2.getString().?);
    try std.testing.expectEqual(@as(u32, 5), cell2.style_index);
}
