//! Zylix Excel Module
//!
//! Cross-platform Excel file processing library supporting
//! reading and writing XLSX files (Office Open XML format).
//!
//! ## Features
//! - Read and write XLSX files
//! - Cell value types: strings, numbers, dates, formulas
//! - Rich formatting: fonts, colors, borders, fills
//! - Multiple worksheets per workbook
//! - Row/column sizing and visibility
//! - Cell merging and ranges
//!
//! ## Example
//! ```zig
//! const excel = @import("excel");
//!
//! // Create a new workbook
//! var workbook = excel.Workbook.init(allocator);
//! defer workbook.deinit();
//!
//! // Add a worksheet
//! var sheet = workbook.addSheet("Sales Data") catch unreachable;
//!
//! // Write data
//! sheet.setString(0, 0, "Product");
//! sheet.setString(0, 1, "Revenue");
//! sheet.setNumber(1, 0, "Widget");
//! sheet.setNumber(1, 1, 1500.50);
//!
//! // Save to file
//! workbook.save("report.xlsx") catch |err| {
//!     std.debug.print("Error: {}\n", .{err});
//! };
//! ```

const std = @import("std");

// Re-export all public types
pub const types = @import("types.zig");
pub const workbook = @import("workbook.zig");
pub const worksheet = @import("worksheet.zig");
pub const cell = @import("cell.zig");
pub const style = @import("style.zig");
pub const writer = @import("writer.zig");
pub const reader = @import("reader.zig");

// Convenience type aliases
pub const ExcelError = types.ExcelError;
pub const CellType = types.CellType;
pub const CellValue = types.CellValue;
pub const CellRef = types.CellRef;
pub const CellRange = types.CellRange;
pub const CellStyle = types.CellStyle;
pub const Color = types.Color;
pub const FontStyle = types.FontStyle;
pub const FillStyle = types.FillStyle;
pub const Border = types.Border;
pub const NumberFormat = types.NumberFormat;
pub const Date = types.Date;
pub const Time = types.Time;
pub const DateTime = types.DateTime;

pub const Workbook = workbook.Workbook;
pub const Worksheet = worksheet.Worksheet;
pub const Cell = cell.Cell;
pub const StyleManager = style.StyleManager;
pub const XlsxWriter = writer.XlsxWriter;
pub const XlsxReader = reader.XlsxReader;

/// Create a new empty workbook
pub fn createWorkbook(allocator: std.mem.Allocator) !*Workbook {
    return Workbook.init(allocator);
}

/// Open an existing XLSX file
pub fn openWorkbook(allocator: std.mem.Allocator, path: []const u8) !*Workbook {
    return XlsxReader.read(allocator, path);
}

/// Quick save a workbook to file
pub fn saveWorkbook(wb: *Workbook, path: []const u8) !void {
    return XlsxWriter.write(wb, path);
}

// Unit tests
test "module imports" {
    // Verify all submodules compile
    _ = types;
    _ = workbook;
    _ = worksheet;
    _ = cell;
    _ = style;
    _ = writer;
    _ = reader;
}
