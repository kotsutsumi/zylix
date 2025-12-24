//! Zylix Excel - Type Definitions
//!
//! Core types for Excel file processing.

const std = @import("std");

/// Excel error types
pub const ExcelError = error{
    InvalidFile,
    CorruptedFile,
    UnsupportedFormat,
    SheetNotFound,
    CellOutOfRange,
    InvalidFormula,
    InvalidStyle,
    WriteError,
    ReadError,
    CompressionError,
    OutOfMemory,
};

/// Cell value types
pub const CellType = enum {
    empty,
    string,
    number,
    boolean,
    date,
    time,
    datetime,
    formula,
    error_value,
    rich_string,
};

/// Cell value union
pub const CellValue = union(CellType) {
    empty: void,
    string: []const u8,
    number: f64,
    boolean: bool,
    date: Date,
    time: Time,
    datetime: DateTime,
    formula: Formula,
    error_value: CellErrorValue,
    rich_string: RichString,
};

/// Date representation
pub const Date = struct {
    year: i16,
    month: u8,
    day: u8,

    pub fn toSerial(self: Date) f64 {
        // Excel serial date (days since 1899-12-30)
        // Simplified calculation
        var days: i32 = 0;
        const y: i32 = @intCast(self.year);
        const m = self.month;

        // Years
        if (y > 1900) {
            days += (y - 1900) * 365;
            days += @divFloor(y - 1901, 4); // Leap years
        }

        // Months
        const days_in_month = [_]u8{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
        var i: usize = 0;
        while (i < m - 1) : (i += 1) {
            days += days_in_month[i];
        }

        // Leap year adjustment
        if (m > 2 and @mod(y, 4) == 0 and (@mod(y, 100) != 0 or @mod(y, 400) == 0)) {
            days += 1;
        }

        days += self.day;
        return @floatFromInt(days);
    }

    pub fn fromSerial(serial: f64) Date {
        const days: i32 = @intFromFloat(serial);
        // Simplified reverse calculation
        var remaining = days;
        var year: i16 = 1900;

        while (remaining > 365) {
            const is_leap = @mod(year, 4) == 0 and (@mod(year, 100) != 0 or @mod(year, 400) == 0);
            const year_days: i32 = if (is_leap) 366 else 365;
            if (remaining >= year_days) {
                remaining -= year_days;
                year += 1;
            } else {
                break;
            }
        }

        const days_in_month = [_]u8{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
        var month: u8 = 1;
        for (days_in_month) |dim| {
            if (remaining <= dim) break;
            remaining -= dim;
            month += 1;
        }

        return .{
            .year = year,
            .month = month,
            .day = @intCast(@max(1, remaining)),
        };
    }
};

/// Time representation
pub const Time = struct {
    hour: u8,
    minute: u8,
    second: u8,
    millisecond: u16 = 0,

    pub fn toFraction(self: Time) f64 {
        const seconds = @as(f64, @floatFromInt(self.hour)) * 3600 +
            @as(f64, @floatFromInt(self.minute)) * 60 +
            @as(f64, @floatFromInt(self.second)) +
            @as(f64, @floatFromInt(self.millisecond)) / 1000.0;
        return seconds / 86400.0;
    }
};

/// DateTime representation
pub const DateTime = struct {
    date: Date,
    time: Time,

    pub fn toSerial(self: DateTime) f64 {
        return self.date.toSerial() + self.time.toFraction();
    }
};

/// Formula representation
pub const Formula = struct {
    expression: []const u8,
    cached_value: ?f64 = null,
};

/// Cell error values
pub const CellErrorValue = enum {
    null_error, // #NULL!
    div_zero, // #DIV/0!
    value_error, // #VALUE!
    ref_error, // #REF!
    name_error, // #NAME?
    num_error, // #NUM!
    na_error, // #N/A
    getting_data, // #GETTING_DATA

    pub fn toString(self: CellErrorValue) []const u8 {
        return switch (self) {
            .null_error => "#NULL!",
            .div_zero => "#DIV/0!",
            .value_error => "#VALUE!",
            .ref_error => "#REF!",
            .name_error => "#NAME?",
            .num_error => "#NUM!",
            .na_error => "#N/A",
            .getting_data => "#GETTING_DATA",
        };
    }
};

/// Rich string with formatting runs
pub const RichString = struct {
    text: []const u8,
    runs: []const TextRun,

    pub const TextRun = struct {
        start: usize,
        length: usize,
        font: ?FontStyle = null,
    };
};

/// Cell reference (e.g., "A1", "B2")
pub const CellRef = struct {
    col: u16,
    row: u32,

    /// Parse cell reference string (e.g., "A1" -> {0, 0})
    pub fn parse(ref: []const u8) !CellRef {
        var col: u16 = 0;
        var i: usize = 0;

        // Parse column letters
        while (i < ref.len and std.ascii.isAlphabetic(ref[i])) {
            const c = std.ascii.toUpper(ref[i]);
            col = col * 26 + (c - 'A' + 1);
            i += 1;
        }

        if (col == 0 or i == ref.len) return ExcelError.CellOutOfRange;
        col -= 1; // 0-based

        // Parse row number
        const row = std.fmt.parseInt(u32, ref[i..], 10) catch return ExcelError.CellOutOfRange;
        if (row == 0) return ExcelError.CellOutOfRange;

        return .{ .col = col, .row = row - 1 }; // 0-based
    }

    /// Convert to string (e.g., {0, 0} -> "A1")
    pub fn toString(self: CellRef, buffer: []u8) []const u8 {
        var col = self.col + 1;
        var col_str: [8]u8 = undefined;
        var col_len: usize = 0;

        while (col > 0) {
            col -= 1;
            col_str[col_len] = @intCast('A' + @mod(col, 26));
            col /= 26;
            col_len += 1;
        }

        // Reverse column string
        var j: usize = 0;
        while (j < col_len / 2) : (j += 1) {
            const tmp = col_str[j];
            col_str[j] = col_str[col_len - 1 - j];
            col_str[col_len - 1 - j] = tmp;
        }

        // Format row
        const row_str = std.fmt.bufPrint(buffer[col_len..], "{d}", .{self.row + 1}) catch return "";
        @memcpy(buffer[0..col_len], col_str[0..col_len]);

        return buffer[0 .. col_len + row_str.len];
    }
};

/// Cell range (e.g., "A1:C3")
pub const CellRange = struct {
    start: CellRef,
    end: CellRef,

    pub fn parse(range: []const u8) !CellRange {
        const colon_pos = std.mem.indexOf(u8, range, ":") orelse return ExcelError.CellOutOfRange;
        return .{
            .start = try CellRef.parse(range[0..colon_pos]),
            .end = try CellRef.parse(range[colon_pos + 1 ..]),
        };
    }

    pub fn width(self: CellRange) u16 {
        return self.end.col - self.start.col + 1;
    }

    pub fn height(self: CellRange) u32 {
        return self.end.row - self.start.row + 1;
    }
};

/// Font style
pub const FontStyle = struct {
    name: []const u8 = "Calibri",
    size: f32 = 11,
    bold: bool = false,
    italic: bool = false,
    underline: Underline = .none,
    strikethrough: bool = false,
    color: Color = Color.black,

    pub const Underline = enum {
        none,
        single,
        double,
        single_accounting,
        double_accounting,
    };
};

/// Color representation
pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,

    pub const black = Color{ .r = 0, .g = 0, .b = 0 };
    pub const white = Color{ .r = 255, .g = 255, .b = 255 };
    pub const red = Color{ .r = 255, .g = 0, .b = 0 };
    pub const green = Color{ .r = 0, .g = 255, .b = 0 };
    pub const blue = Color{ .r = 0, .g = 0, .b = 255 };
    pub const yellow = Color{ .r = 255, .g = 255, .b = 0 };

    pub fn toHex(self: Color) u32 {
        return (@as(u32, self.a) << 24) |
            (@as(u32, self.r) << 16) |
            (@as(u32, self.g) << 8) |
            @as(u32, self.b);
    }

    pub fn fromHex(hex: u32) Color {
        return .{
            .a = @intCast((hex >> 24) & 0xFF),
            .r = @intCast((hex >> 16) & 0xFF),
            .g = @intCast((hex >> 8) & 0xFF),
            .b = @intCast(hex & 0xFF),
        };
    }
};

/// Fill pattern
pub const FillPattern = enum {
    none,
    solid,
    gray_125,
    gray_0625,
    dark_horizontal,
    dark_vertical,
    dark_down,
    dark_up,
    dark_grid,
    dark_trellis,
    light_horizontal,
    light_vertical,
    light_down,
    light_up,
    light_grid,
    light_trellis,
};

/// Fill style
pub const FillStyle = struct {
    pattern: FillPattern = .none,
    fg_color: Color = Color.white,
    bg_color: Color = Color.white,
};

/// Border style
pub const BorderStyle = enum {
    none,
    thin,
    medium,
    dashed,
    dotted,
    thick,
    double,
    hair,
    medium_dashed,
    dash_dot,
    medium_dash_dot,
    dash_dot_dot,
    medium_dash_dot_dot,
    slant_dash_dot,
};

/// Border configuration
pub const Border = struct {
    left: BorderSide = .{},
    right: BorderSide = .{},
    top: BorderSide = .{},
    bottom: BorderSide = .{},
    diagonal: BorderSide = .{},
    diagonal_up: bool = false,
    diagonal_down: bool = false,

    pub const BorderSide = struct {
        style: BorderStyle = .none,
        color: Color = Color.black,
    };
};

/// Horizontal alignment
pub const HorizontalAlign = enum {
    general,
    left,
    center,
    right,
    fill,
    justify,
    center_continuous,
    distributed,
};

/// Vertical alignment
pub const VerticalAlign = enum {
    top,
    center,
    bottom,
    justify,
    distributed,
};

/// Cell style
pub const CellStyle = struct {
    font: FontStyle = .{},
    fill: FillStyle = .{},
    border: Border = .{},
    h_align: HorizontalAlign = .general,
    v_align: VerticalAlign = .bottom,
    wrap_text: bool = false,
    shrink_to_fit: bool = false,
    text_rotation: i16 = 0, // -90 to 90
    indent: u8 = 0,
    number_format: []const u8 = "General",
    locked: bool = true,
    hidden: bool = false,
};

/// Number format presets
pub const NumberFormat = struct {
    pub const general = "General";
    pub const number = "0";
    pub const number_2dp = "0.00";
    pub const number_thousands = "#,##0";
    pub const number_thousands_2dp = "#,##0.00";
    pub const currency = "$#,##0.00";
    pub const currency_negative_red = "$#,##0.00;[Red]-$#,##0.00";
    pub const percentage = "0%";
    pub const percentage_2dp = "0.00%";
    pub const scientific = "0.00E+00";
    pub const date_short = "m/d/yy";
    pub const date_long = "d-mmm-yy";
    pub const date_full = "d-mmm-yyyy";
    pub const time_short = "h:mm";
    pub const time_long = "h:mm:ss";
    pub const datetime = "m/d/yy h:mm";
    pub const text = "@";
};

/// Paper size for printing
pub const PaperSize = enum(u8) {
    letter = 1,
    letter_small = 2,
    tabloid = 3,
    ledger = 4,
    legal = 5,
    statement = 6,
    executive = 7,
    a3 = 8,
    a4 = 9,
    a4_small = 10,
    a5 = 11,
    b4 = 12,
    b5 = 13,
};

/// Page orientation
pub const Orientation = enum {
    portrait,
    landscape,
};

/// Page setup
pub const PageSetup = struct {
    paper_size: PaperSize = .letter,
    orientation: Orientation = .portrait,
    scale: u16 = 100,
    fit_to_width: ?u16 = null,
    fit_to_height: ?u16 = null,
    first_page_number: ?u16 = null,
    print_gridlines: bool = false,
    print_headings: bool = false,
    center_horizontally: bool = false,
    center_vertically: bool = false,
    margin_left: f64 = 0.7,
    margin_right: f64 = 0.7,
    margin_top: f64 = 0.75,
    margin_bottom: f64 = 0.75,
    margin_header: f64 = 0.3,
    margin_footer: f64 = 0.3,
};

// Unit tests
test "CellRef parse" {
    const a1 = try CellRef.parse("A1");
    try std.testing.expectEqual(@as(u16, 0), a1.col);
    try std.testing.expectEqual(@as(u32, 0), a1.row);

    const z26 = try CellRef.parse("Z26");
    try std.testing.expectEqual(@as(u16, 25), z26.col);
    try std.testing.expectEqual(@as(u32, 25), z26.row);

    const aa1 = try CellRef.parse("AA1");
    try std.testing.expectEqual(@as(u16, 26), aa1.col);
}

test "CellRef toString" {
    var buffer: [16]u8 = undefined;

    const a1 = CellRef{ .col = 0, .row = 0 };
    try std.testing.expectEqualStrings("A1", a1.toString(&buffer));

    const z26 = CellRef{ .col = 25, .row = 25 };
    try std.testing.expectEqualStrings("Z26", z26.toString(&buffer));
}

test "Date serial conversion" {
    const date = Date{ .year = 2024, .month = 1, .day = 1 };
    const serial = date.toSerial();
    try std.testing.expect(serial > 45000); // Approximate check

    const back = Date.fromSerial(serial);
    try std.testing.expectEqual(date.year, back.year);
}

test "Color hex conversion" {
    const red = Color.red;
    const hex = red.toHex();
    const back = Color.fromHex(hex);
    try std.testing.expectEqual(red.r, back.r);
    try std.testing.expectEqual(red.g, back.g);
    try std.testing.expectEqual(red.b, back.b);
}
