//! Zylix PDF - Common Types
//!
//! Core type definitions for PDF document handling.
//! Inspired by PDF 1.7 specification (ISO 32000-1:2008).

const std = @import("std");

/// PDF version enumeration
pub const PdfVersion = enum(u8) {
    v1_0 = 10,
    v1_1 = 11,
    v1_2 = 12,
    v1_3 = 13,
    v1_4 = 14,
    v1_5 = 15,
    v1_6 = 16,
    v1_7 = 17,
    v2_0 = 20,

    pub fn toString(self: PdfVersion) []const u8 {
        return switch (self) {
            .v1_0 => "1.0",
            .v1_1 => "1.1",
            .v1_2 => "1.2",
            .v1_3 => "1.3",
            .v1_4 => "1.4",
            .v1_5 => "1.5",
            .v1_6 => "1.6",
            .v1_7 => "1.7",
            .v2_0 => "2.0",
        };
    }
};

/// Standard page sizes (in points, 1 point = 1/72 inch)
pub const PageSize = struct {
    width: f32,
    height: f32,

    // ISO 216 A series
    pub const A0 = PageSize{ .width = 2384, .height = 3370 };
    pub const A1 = PageSize{ .width = 1684, .height = 2384 };
    pub const A2 = PageSize{ .width = 1190, .height = 1684 };
    pub const A3 = PageSize{ .width = 842, .height = 1190 };
    pub const A4 = PageSize{ .width = 595, .height = 842 };
    pub const A5 = PageSize{ .width = 420, .height = 595 };
    pub const A6 = PageSize{ .width = 298, .height = 420 };

    // ISO 216 B series
    pub const B0 = PageSize{ .width = 2834, .height = 4008 };
    pub const B1 = PageSize{ .width = 2004, .height = 2834 };
    pub const B2 = PageSize{ .width = 1417, .height = 2004 };
    pub const B3 = PageSize{ .width = 1000, .height = 1417 };
    pub const B4 = PageSize{ .width = 708, .height = 1000 };
    pub const B5 = PageSize{ .width = 498, .height = 708 };

    // US sizes
    pub const Letter = PageSize{ .width = 612, .height = 792 };
    pub const Legal = PageSize{ .width = 612, .height = 1008 };
    pub const Tabloid = PageSize{ .width = 792, .height = 1224 };
    pub const Ledger = PageSize{ .width = 1224, .height = 792 };
    pub const Executive = PageSize{ .width = 522, .height = 756 };

    /// Create custom page size in points
    pub fn custom(width: f32, height: f32) PageSize {
        return .{ .width = width, .height = height };
    }

    /// Create page size from millimeters
    pub fn fromMm(width_mm: f32, height_mm: f32) PageSize {
        return .{
            .width = width_mm * 2.83465,
            .height = height_mm * 2.83465,
        };
    }

    /// Create page size from inches
    pub fn fromInches(width_in: f32, height_in: f32) PageSize {
        return .{
            .width = width_in * 72,
            .height = height_in * 72,
        };
    }

    /// Get landscape orientation
    pub fn landscape(self: PageSize) PageSize {
        return .{ .width = self.height, .height = self.width };
    }
};

/// Page orientation
pub const Orientation = enum {
    portrait,
    landscape,
};

/// Rectangle (used for bounding boxes, media boxes, etc.)
pub const Rectangle = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,

    pub fn init(x: f32, y: f32, width: f32, height: f32) Rectangle {
        return .{ .x = x, .y = y, .width = width, .height = height };
    }

    pub fn fromPageSize(size: PageSize) Rectangle {
        return .{ .x = 0, .y = 0, .width = size.width, .height = size.height };
    }
};

/// Point in 2D space
pub const Point = struct {
    x: f32,
    y: f32,

    pub fn init(x: f32, y: f32) Point {
        return .{ .x = x, .y = y };
    }
};

/// Color representation
pub const Color = struct {
    r: f32, // 0.0 - 1.0
    g: f32,
    b: f32,
    a: f32 = 1.0,

    // Predefined colors
    pub const black = Color{ .r = 0, .g = 0, .b = 0 };
    pub const white = Color{ .r = 1, .g = 1, .b = 1 };
    pub const red = Color{ .r = 1, .g = 0, .b = 0 };
    pub const green = Color{ .r = 0, .g = 1, .b = 0 };
    pub const blue = Color{ .r = 0, .g = 0, .b = 1 };
    pub const yellow = Color{ .r = 1, .g = 1, .b = 0 };
    pub const cyan = Color{ .r = 0, .g = 1, .b = 1 };
    pub const magenta = Color{ .r = 1, .g = 0, .b = 1 };
    pub const gray = Color{ .r = 0.5, .g = 0.5, .b = 0.5 };
    pub const light_gray = Color{ .r = 0.75, .g = 0.75, .b = 0.75 };
    pub const dark_gray = Color{ .r = 0.25, .g = 0.25, .b = 0.25 };

    /// Create color from RGB values (0-255)
    pub fn rgb(r: u8, g: u8, b: u8) Color {
        return .{
            .r = @as(f32, @floatFromInt(r)) / 255.0,
            .g = @as(f32, @floatFromInt(g)) / 255.0,
            .b = @as(f32, @floatFromInt(b)) / 255.0,
        };
    }

    /// Create color from RGBA values (0-255)
    pub fn rgba(r: u8, g: u8, b: u8, a: u8) Color {
        return .{
            .r = @as(f32, @floatFromInt(r)) / 255.0,
            .g = @as(f32, @floatFromInt(g)) / 255.0,
            .b = @as(f32, @floatFromInt(b)) / 255.0,
            .a = @as(f32, @floatFromInt(a)) / 255.0,
        };
    }

    /// Create color from hex string (e.g., "#FF0000" or "FF0000")
    pub fn fromHex(hex: []const u8) !Color {
        const start: usize = if (hex.len > 0 and hex[0] == '#') 1 else 0;
        if (hex.len - start < 6) return error.InvalidHexColor;

        const r = std.fmt.parseInt(u8, hex[start .. start + 2], 16) catch return error.InvalidHexColor;
        const g = std.fmt.parseInt(u8, hex[start + 2 .. start + 4], 16) catch return error.InvalidHexColor;
        const b = std.fmt.parseInt(u8, hex[start + 4 .. start + 6], 16) catch return error.InvalidHexColor;

        return rgb(r, g, b);
    }

    /// Create grayscale color
    pub fn grayscale(value: f32) Color {
        return .{ .r = value, .g = value, .b = value };
    }
};

/// Line cap style
pub const LineCap = enum(u8) {
    butt = 0,
    round = 1,
    square = 2,
};

/// Line join style
pub const LineJoin = enum(u8) {
    miter = 0,
    round = 1,
    bevel = 2,
};

/// Text alignment
pub const TextAlign = enum {
    left,
    center,
    right,
    justify,
};

/// Vertical alignment
pub const VerticalAlign = enum {
    top,
    middle,
    bottom,
};

/// Font weight
pub const FontWeight = enum {
    thin,
    extra_light,
    light,
    normal,
    medium,
    semi_bold,
    bold,
    extra_bold,
    black,
};

/// Font style
pub const FontStyle = enum {
    normal,
    italic,
    oblique,
};

/// Standard PDF fonts (Base 14 fonts)
pub const StandardFont = enum {
    // Sans-serif
    helvetica,
    helvetica_bold,
    helvetica_oblique,
    helvetica_bold_oblique,

    // Serif
    times_roman,
    times_bold,
    times_italic,
    times_bold_italic,

    // Monospace
    courier,
    courier_bold,
    courier_oblique,
    courier_bold_oblique,

    // Special
    symbol,
    zapf_dingbats,

    pub fn toName(self: StandardFont) []const u8 {
        return switch (self) {
            .helvetica => "Helvetica",
            .helvetica_bold => "Helvetica-Bold",
            .helvetica_oblique => "Helvetica-Oblique",
            .helvetica_bold_oblique => "Helvetica-BoldOblique",
            .times_roman => "Times-Roman",
            .times_bold => "Times-Bold",
            .times_italic => "Times-Italic",
            .times_bold_italic => "Times-BoldItalic",
            .courier => "Courier",
            .courier_bold => "Courier-Bold",
            .courier_oblique => "Courier-Oblique",
            .courier_bold_oblique => "Courier-BoldOblique",
            .symbol => "Symbol",
            .zapf_dingbats => "ZapfDingbats",
        };
    }
};

/// Image format
pub const ImageFormat = enum {
    jpeg,
    png,
    gif,
    bmp,
    tiff,
};

/// Compression method
pub const Compression = enum {
    none,
    flate, // zlib/deflate
    lzw,
    jpeg,
    jpeg2000,
    jbig2,
    ccitt, // CCITT Group 3/4 fax
    run_length,
};

/// PDF object types (for internal use)
pub const ObjectType = enum {
    null,
    boolean,
    integer,
    real,
    string,
    name,
    array,
    dictionary,
    stream,
    indirect_reference,
};

/// PDF object reference
pub const ObjectRef = struct {
    object_number: u32,
    generation: u16 = 0,
};

/// Document metadata
pub const Metadata = struct {
    title: ?[]const u8 = null,
    author: ?[]const u8 = null,
    subject: ?[]const u8 = null,
    keywords: ?[]const u8 = null,
    creator: ?[]const u8 = null,
    producer: ?[]const u8 = null,
    creation_date: ?i64 = null, // Unix timestamp
    modification_date: ?i64 = null,
};

/// Page margins
pub const Margins = struct {
    top: f32,
    right: f32,
    bottom: f32,
    left: f32,

    pub const zero = Margins{ .top = 0, .right = 0, .bottom = 0, .left = 0 };
    pub const normal = Margins{ .top = 72, .right = 72, .bottom = 72, .left = 72 }; // 1 inch
    pub const narrow = Margins{ .top = 36, .right = 36, .bottom = 36, .left = 36 }; // 0.5 inch
    pub const wide = Margins{ .top = 72, .right = 144, .bottom = 72, .left = 144 }; // 1 inch top/bottom, 2 inch sides

    pub fn uniform(value: f32) Margins {
        return .{ .top = value, .right = value, .bottom = value, .left = value };
    }

    pub fn symmetric(vertical: f32, horizontal: f32) Margins {
        return .{ .top = vertical, .right = horizontal, .bottom = vertical, .left = horizontal };
    }
};

/// Blend mode for transparency
pub const BlendMode = enum {
    normal,
    multiply,
    screen,
    overlay,
    darken,
    lighten,
    color_dodge,
    color_burn,
    hard_light,
    soft_light,
    difference,
    exclusion,
};

/// PDF error types
pub const PdfError = error{
    InvalidPdf,
    UnsupportedVersion,
    CorruptedFile,
    PasswordProtected,
    InvalidObjectReference,
    StreamDecodingFailed,
    FontNotFound,
    ImageDecodingFailed,
    OutOfMemory,
    IoError,
    InvalidHexColor,
    InvalidOperation,
    PageNotFound,
    InvalidPageIndex,
};

// Unit tests
test "PageSize conversions" {
    const size_mm = PageSize.fromMm(210, 297); // A4 in mm
    try std.testing.expectApproxEqAbs(size_mm.width, 595.0, 1.0);
    try std.testing.expectApproxEqAbs(size_mm.height, 842.0, 1.0);

    const size_in = PageSize.fromInches(8.5, 11); // Letter in inches
    try std.testing.expectApproxEqAbs(size_in.width, 612.0, 0.1);
    try std.testing.expectApproxEqAbs(size_in.height, 792.0, 0.1);
}

test "Color from hex" {
    const red = try Color.fromHex("#FF0000");
    try std.testing.expectApproxEqAbs(red.r, 1.0, 0.01);
    try std.testing.expectApproxEqAbs(red.g, 0.0, 0.01);
    try std.testing.expectApproxEqAbs(red.b, 0.0, 0.01);

    const blue = try Color.fromHex("0000FF");
    try std.testing.expectApproxEqAbs(blue.b, 1.0, 0.01);
}

test "Rectangle from PageSize" {
    const rect = Rectangle.fromPageSize(PageSize.A4);
    try std.testing.expectEqual(rect.x, 0);
    try std.testing.expectEqual(rect.y, 0);
    try std.testing.expectEqual(rect.width, 595);
    try std.testing.expectEqual(rect.height, 842);
}
