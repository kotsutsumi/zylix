//! Zylix PDF - Font Management
//!
//! Font handling for PDF documents including standard fonts and custom fonts.

const std = @import("std");
const types = @import("types.zig");

const StandardFont = types.StandardFont;
const PdfError = types.PdfError;

/// Font metrics for character positioning
pub const FontMetrics = struct {
    units_per_em: u16 = 1000,
    ascender: i16 = 800,
    descender: i16 = -200,
    line_gap: i16 = 0,
    cap_height: i16 = 700,
    x_height: i16 = 500,
    average_width: u16 = 500,

    /// Standard Helvetica metrics
    pub const helvetica = FontMetrics{
        .units_per_em = 1000,
        .ascender = 718,
        .descender = -207,
        .cap_height = 718,
        .x_height = 523,
        .average_width = 513,
    };

    /// Standard Times Roman metrics
    pub const times = FontMetrics{
        .units_per_em = 1000,
        .ascender = 683,
        .descender = -217,
        .cap_height = 662,
        .x_height = 450,
        .average_width = 401,
    };

    /// Standard Courier metrics
    pub const courier = FontMetrics{
        .units_per_em = 1000,
        .ascender = 629,
        .descender = -157,
        .cap_height = 562,
        .x_height = 426,
        .average_width = 600,
    };
};

/// Font glyph information
pub const Glyph = struct {
    unicode: u21,
    width: u16,
    name: ?[]const u8 = null,
};

/// Font representation
pub const Font = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    font_type: FontType,
    metrics: FontMetrics,
    standard_font: ?StandardFont,
    embedded_data: ?[]const u8,
    glyphs: std.AutoHashMap(u21, Glyph),

    pub const FontType = enum {
        type1, // Standard PDF fonts
        truetype,
        opentype,
        type0, // CID fonts for CJK
    };

    /// Create a standard PDF font
    pub fn createStandard(allocator: std.mem.Allocator, font: StandardFont) !*Font {
        const f = try allocator.create(Font);
        f.* = .{
            .allocator = allocator,
            .name = font.toName(),
            .font_type = .type1,
            .metrics = getStandardMetrics(font),
            .standard_font = font,
            .embedded_data = null,
            .glyphs = std.AutoHashMap(u21, Glyph).init(allocator),
        };
        return f;
    }

    /// Load a TrueType font from data
    /// Note: This function takes ownership by copying the data.
    /// The caller can free their original data after this call.
    pub fn loadTrueType(allocator: std.mem.Allocator, data: []const u8) !*Font {
        const f = try allocator.create(Font);
        errdefer allocator.destroy(f);

        // Copy the data to take ownership
        const data_copy = try allocator.dupe(u8, data);
        errdefer allocator.free(data_copy);

        f.* = .{
            .allocator = allocator,
            .name = "CustomFont",
            .font_type = .truetype,
            .metrics = FontMetrics{},
            .standard_font = null,
            .embedded_data = data_copy,
            .glyphs = std.AutoHashMap(u21, Glyph).init(allocator),
        };

        // TODO: Parse TrueType font data
        // For now, we just store the data

        return f;
    }

    /// Load a font from file
    pub fn loadFromFile(allocator: std.mem.Allocator, path: []const u8) !*Font {
        const file = std.fs.cwd().openFile(path, .{}) catch {
            return PdfError.FontNotFound;
        };
        defer file.close();

        const stat = try file.stat();
        const data = try allocator.alloc(u8, stat.size);
        defer allocator.free(data); // loadTrueType copies the data

        _ = try file.readAll(data);

        return loadTrueType(allocator, data);
    }

    pub fn deinit(self: *Font) void {
        if (self.embedded_data) |data| {
            self.allocator.free(data);
        }
        self.glyphs.deinit();
    }

    /// Get glyph width for a character
    pub fn getGlyphWidth(self: *const Font, char: u21) u16 {
        if (self.glyphs.get(char)) |glyph| {
            return glyph.width;
        }
        return self.metrics.average_width;
    }

    /// Calculate text width in font units
    /// Uses UTF-8 decoding to properly handle multi-byte characters
    pub fn getTextWidth(self: *const Font, text: []const u8) u32 {
        var width: u32 = 0;
        var utf8_view = std.unicode.Utf8View.initUnchecked(text);
        var iter = utf8_view.iterator();
        while (iter.nextCodepoint()) |codepoint| {
            width += self.getGlyphWidth(codepoint);
        }
        return width;
    }

    /// Calculate text width in points
    pub fn getTextWidthPoints(self: *const Font, text: []const u8, size: f32) f32 {
        const width = self.getTextWidth(text);
        return @as(f32, @floatFromInt(width)) * size / @as(f32, @floatFromInt(self.metrics.units_per_em));
    }

    /// Get line height in points
    pub fn getLineHeight(self: *const Font, size: f32) f32 {
        const ascender = @as(f32, @floatFromInt(self.metrics.ascender));
        const descender = @as(f32, @floatFromInt(self.metrics.descender));
        const line_gap = @as(f32, @floatFromInt(self.metrics.line_gap));
        const units = @as(f32, @floatFromInt(self.metrics.units_per_em));
        return (ascender - descender + line_gap) * size / units;
    }

    /// Check if this is a standard font
    pub fn isStandard(self: *const Font) bool {
        return self.standard_font != null;
    }

    /// Get PDF font name
    pub fn getPdfName(self: *const Font) []const u8 {
        return self.name;
    }
};

/// Get standard font metrics
fn getStandardMetrics(font: StandardFont) FontMetrics {
    return switch (font) {
        .helvetica, .helvetica_bold, .helvetica_oblique, .helvetica_bold_oblique => FontMetrics.helvetica,
        .times_roman, .times_bold, .times_italic, .times_bold_italic => FontMetrics.times,
        .courier, .courier_bold, .courier_oblique, .courier_bold_oblique => FontMetrics.courier,
        .symbol, .zapf_dingbats => FontMetrics{},
    };
}

/// Font family for easier font selection
pub const FontFamily = struct {
    regular: StandardFont,
    bold: StandardFont,
    italic: StandardFont,
    bold_italic: StandardFont,

    pub const helvetica = FontFamily{
        .regular = .helvetica,
        .bold = .helvetica_bold,
        .italic = .helvetica_oblique,
        .bold_italic = .helvetica_bold_oblique,
    };

    pub const times = FontFamily{
        .regular = .times_roman,
        .bold = .times_bold,
        .italic = .times_italic,
        .bold_italic = .times_bold_italic,
    };

    pub const courier = FontFamily{
        .regular = .courier,
        .bold = .courier_bold,
        .italic = .courier_oblique,
        .bold_italic = .courier_bold_oblique,
    };

    pub fn get(self: FontFamily, bold: bool, italic: bool) StandardFont {
        if (bold and italic) return self.bold_italic;
        if (bold) return self.bold;
        if (italic) return self.italic;
        return self.regular;
    }
};

// Unit tests
test "Font creation" {
    const allocator = std.testing.allocator;

    const font = try Font.createStandard(allocator, .helvetica);
    defer {
        font.deinit();
        allocator.destroy(font);
    }

    try std.testing.expectEqualStrings("Helvetica", font.name);
    try std.testing.expect(font.isStandard());
}

test "FontFamily selection" {
    const family = FontFamily.helvetica;

    try std.testing.expectEqual(family.get(false, false), .helvetica);
    try std.testing.expectEqual(family.get(true, false), .helvetica_bold);
    try std.testing.expectEqual(family.get(false, true), .helvetica_oblique);
    try std.testing.expectEqual(family.get(true, true), .helvetica_bold_oblique);
}

test "Font metrics" {
    const allocator = std.testing.allocator;

    const font = try Font.createStandard(allocator, .helvetica);
    defer {
        font.deinit();
        allocator.destroy(font);
    }

    const line_height = font.getLineHeight(12);
    try std.testing.expect(line_height > 10);
    try std.testing.expect(line_height < 20);
}
