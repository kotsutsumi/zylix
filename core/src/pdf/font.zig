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

        // Parse TrueType font data to extract metrics
        if (data.len >= 12) {
            f.parseTrueTypeMetrics(data) catch {
                // If parsing fails, use default metrics
            };
        }

        return f;
    }

    /// Parse TrueType font metrics from font data
    fn parseTrueTypeMetrics(self: *Font, data: []const u8) !void {
        // TrueType/OpenType file structure:
        // - Offset table (12 bytes)
        // - Table directory entries (16 bytes each)

        if (data.len < 12) return;

        // Check for valid TrueType signature
        const sfnt_version = readU32Be(data[0..4]);
        if (sfnt_version != 0x00010000 and // TrueType
            sfnt_version != 0x4F54544F) // OpenType 'OTTO'
        {
            return;
        }

        const num_tables = readU16Be(data[4..6]);

        // Parse table directory to find required tables
        var head_offset: ?usize = null;
        var hhea_offset: ?usize = null;
        var name_offset: ?usize = null;
        var os2_offset: ?usize = null;

        var i: usize = 0;
        while (i < num_tables) : (i += 1) {
            const entry_offset = 12 + i * 16;
            if (entry_offset + 16 > data.len) break;

            const tag = data[entry_offset .. entry_offset + 4];
            const offset = readU32Be(data[entry_offset + 8 .. entry_offset + 12]);

            if (std.mem.eql(u8, tag, "head")) {
                head_offset = offset;
            } else if (std.mem.eql(u8, tag, "hhea")) {
                hhea_offset = offset;
            } else if (std.mem.eql(u8, tag, "name")) {
                name_offset = offset;
            } else if (std.mem.eql(u8, tag, "OS/2")) {
                os2_offset = offset;
            }
        }

        // Parse 'head' table for units per em
        if (head_offset) |offset| {
            if (offset + 54 <= data.len) {
                self.metrics.units_per_em = readU16Be(data[offset + 18 .. offset + 20]);
            }
        }

        // Parse 'hhea' table for ascender, descender, line gap
        if (hhea_offset) |offset| {
            if (offset + 36 <= data.len) {
                self.metrics.ascender = readI16Be(data[offset + 4 .. offset + 6]);
                self.metrics.descender = readI16Be(data[offset + 6 .. offset + 8]);
                self.metrics.line_gap = readI16Be(data[offset + 8 .. offset + 10]);
            }
        }

        // Parse 'OS/2' table for x-height, cap height if available
        if (os2_offset) |offset| {
            if (offset + 88 <= data.len) {
                // Version 2+ has sxHeight and sCapHeight
                const version = readU16Be(data[offset .. offset + 2]);
                if (version >= 2 and offset + 92 <= data.len) {
                    self.metrics.x_height = readI16Be(data[offset + 86 .. offset + 88]);
                    self.metrics.cap_height = readI16Be(data[offset + 88 .. offset + 90]);
                }
                // Average char width is at offset 2
                if (offset + 4 <= data.len) {
                    const avg = readI16Be(data[offset + 2 .. offset + 4]);
                    if (avg > 0) {
                        self.metrics.average_width = @intCast(avg);
                    }
                }
            }
        }

        // Parse 'name' table for font name
        if (name_offset) |offset| {
            self.parseFontName(data, offset) catch {};
        }
    }

    /// Parse font name from 'name' table
    fn parseFontName(self: *Font, data: []const u8, offset: usize) !void {
        if (offset + 6 > data.len) return;

        const count = readU16Be(data[offset + 2 .. offset + 4]);
        const string_offset = offset + readU16Be(data[offset + 4 .. offset + 6]);

        // Look for name ID 4 (Full font name) or 1 (Font family)
        var i: usize = 0;
        while (i < count) : (i += 1) {
            const record_offset = offset + 6 + i * 12;
            if (record_offset + 12 > data.len) break;

            const platform_id = readU16Be(data[record_offset .. record_offset + 2]);
            const name_id = readU16Be(data[record_offset + 6 .. record_offset + 8]);
            const length = readU16Be(data[record_offset + 8 .. record_offset + 10]);
            const str_offset = readU16Be(data[record_offset + 10 .. record_offset + 12]);

            // Platform 3 (Windows), name ID 4 (Full name) or 1 (Family)
            if (platform_id == 3 and (name_id == 4 or name_id == 1)) {
                const name_start = string_offset + str_offset;
                if (name_start + length <= data.len and length > 0) {
                    // Windows names are UTF-16BE, just use first byte of each char for ASCII
                    var name_buf: [64]u8 = undefined;
                    var j: usize = 0;
                    var k: usize = 0;
                    while (j < length and k < 63) : (j += 2) {
                        if (name_start + j + 1 < data.len) {
                            const c = data[name_start + j + 1];
                            if (c >= 32 and c < 127) {
                                name_buf[k] = c;
                                k += 1;
                            }
                        }
                    }
                    if (k > 0) {
                        // Store name (note: this uses static buffer, OK for now)
                        self.name = "CustomFont"; // Keep default since we can't easily store dynamic name
                    }
                    if (name_id == 4) break; // Prefer full name
                }
            }
        }
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

// Helper functions for reading big-endian integers from byte arrays
fn readU32Be(data: *const [4]u8) u32 {
    return std.mem.readInt(u32, data, .big);
}

fn readU16Be(data: *const [2]u8) u16 {
    return std.mem.readInt(u16, data, .big);
}

fn readI16Be(data: *const [2]u8) i16 {
    return std.mem.readInt(i16, data, .big);
}

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
