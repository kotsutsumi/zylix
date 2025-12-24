//! Zylix Excel - Style Management
//!
//! Manages cell styles including fonts, fills, borders,
//! number formats, and alignment.

const std = @import("std");
const types = @import("types.zig");

const CellStyle = types.CellStyle;
const FontStyle = types.FontStyle;
const FillStyle = types.FillStyle;
const Border = types.Border;
const Color = types.Color;
const NumberFormat = types.NumberFormat;

/// Manages styles for a workbook
pub const StyleManager = struct {
    allocator: std.mem.Allocator,

    /// Registered styles
    styles: std.ArrayList(CellStyle),

    /// Font cache (for deduplication)
    fonts: std.ArrayList(FontStyle),

    /// Fill cache
    fills: std.ArrayList(FillStyle),

    /// Border cache
    borders: std.ArrayList(Border),

    /// Number format cache
    number_formats: std.StringHashMapUnmanaged(u32),
    number_format_list: std.ArrayList([]const u8),

    /// Create a new style manager
    pub fn init(allocator: std.mem.Allocator) !*StyleManager {
        const mgr = try allocator.create(StyleManager);
        errdefer allocator.destroy(mgr);

        mgr.* = .{
            .allocator = allocator,
            .styles = .{},
            .fonts = .{},
            .fills = .{},
            .borders = .{},
            .number_formats = .{},
            .number_format_list = .{},
        };

        // Add default style
        try mgr.styles.append(allocator, .{});

        // Add default font
        try mgr.fonts.append(allocator, .{});

        // Add default fills (Excel requires at least 2)
        try mgr.fills.append(allocator, .{}); // None
        try mgr.fills.append(allocator, .{ .pattern = .gray_125 }); // Gray 125

        // Add default border
        try mgr.borders.append(allocator, .{});

        // Add built-in number formats
        try mgr.addBuiltInFormats();

        return mgr;
    }

    /// Free style manager resources
    pub fn deinit(self: *StyleManager) void {
        self.styles.deinit(self.allocator);
        self.fonts.deinit(self.allocator);
        self.fills.deinit(self.allocator);
        self.borders.deinit(self.allocator);

        // Free owned format strings
        for (self.number_format_list.items) |fmt| {
            self.allocator.free(fmt);
        }
        self.number_format_list.deinit(self.allocator);
        self.number_formats.deinit(self.allocator);

        self.allocator.destroy(self);
    }

    /// Add built-in Excel number formats
    fn addBuiltInFormats(self: *StyleManager) !void {
        const built_ins = [_]struct { id: u32, format: []const u8 }{
            .{ .id = 0, .format = "General" },
            .{ .id = 1, .format = "0" },
            .{ .id = 2, .format = "0.00" },
            .{ .id = 3, .format = "#,##0" },
            .{ .id = 4, .format = "#,##0.00" },
            .{ .id = 9, .format = "0%" },
            .{ .id = 10, .format = "0.00%" },
            .{ .id = 11, .format = "0.00E+00" },
            .{ .id = 14, .format = "m/d/yy" },
            .{ .id = 15, .format = "d-mmm-yy" },
            .{ .id = 16, .format = "d-mmm" },
            .{ .id = 17, .format = "mmm-yy" },
            .{ .id = 18, .format = "h:mm AM/PM" },
            .{ .id = 19, .format = "h:mm:ss AM/PM" },
            .{ .id = 20, .format = "h:mm" },
            .{ .id = 21, .format = "h:mm:ss" },
            .{ .id = 22, .format = "m/d/yy h:mm" },
            .{ .id = 49, .format = "@" },
        };

        for (built_ins) |bi| {
            const owned = try self.allocator.dupe(u8, bi.format);
            try self.number_format_list.append(self.allocator, owned);
            try self.number_formats.put(self.allocator, owned, bi.id);
        }
    }

    /// Register a new style and return its index
    pub fn addStyle(self: *StyleManager, style_to_add: CellStyle) !u32 {
        // Check for existing identical style
        for (self.styles.items, 0..) |existing, i| {
            if (stylesEqual(existing, style_to_add)) {
                return @intCast(i);
            }
        }

        const index: u32 = @intCast(self.styles.items.len);
        try self.styles.append(self.allocator, style_to_add);
        return index;
    }

    /// Get a style by index
    pub fn getStyle(self: *const StyleManager, index: u32) ?CellStyle {
        if (index >= self.styles.items.len) {
            return null;
        }
        return self.styles.items[index];
    }

    /// Register a font and return its index
    pub fn addFont(self: *StyleManager, font: FontStyle) !u32 {
        // Check for existing identical font
        for (self.fonts.items, 0..) |existing, i| {
            if (fontsEqual(existing, font)) {
                return @intCast(i);
            }
        }

        const index: u32 = @intCast(self.fonts.items.len);
        try self.fonts.append(self.allocator, font);
        return index;
    }

    /// Register a fill and return its index
    pub fn addFill(self: *StyleManager, fill: FillStyle) !u32 {
        for (self.fills.items, 0..) |existing, i| {
            if (fillsEqual(existing, fill)) {
                return @intCast(i);
            }
        }

        const index: u32 = @intCast(self.fills.items.len);
        try self.fills.append(self.allocator, fill);
        return index;
    }

    /// Register a border and return its index
    pub fn addBorder(self: *StyleManager, border: Border) !u32 {
        for (self.borders.items, 0..) |existing, i| {
            if (bordersEqual(existing, border)) {
                return @intCast(i);
            }
        }

        const index: u32 = @intCast(self.borders.items.len);
        try self.borders.append(self.allocator, border);
        return index;
    }

    /// Register a number format and return its ID
    pub fn addNumberFormat(self: *StyleManager, format: []const u8) !u32 {
        // Check for existing format
        if (self.number_formats.get(format)) |id| {
            return id;
        }

        // Custom formats start at ID 164
        const id: u32 = 164 + @as(u32, @intCast(self.number_format_list.items.len));
        const owned = try self.allocator.dupe(u8, format);
        try self.number_format_list.append(self.allocator, owned);
        try self.number_formats.put(self.allocator, owned, id);

        return id;
    }

    /// Get number of registered styles
    pub fn styleCount(self: *const StyleManager) usize {
        return self.styles.items.len;
    }

    /// Get number of registered fonts
    pub fn fontCount(self: *const StyleManager) usize {
        return self.fonts.items.len;
    }

    /// Get number of registered fills
    pub fn fillCount(self: *const StyleManager) usize {
        return self.fills.items.len;
    }

    /// Get number of registered borders
    pub fn borderCount(self: *const StyleManager) usize {
        return self.borders.items.len;
    }

    // Style builder methods
    pub const StyleBuilder = struct {
        style: CellStyle,
        manager: *StyleManager,

        pub fn font(self: *StyleBuilder, f: FontStyle) *StyleBuilder {
            self.style.font = f;
            return self;
        }

        pub fn bold(self: *StyleBuilder) *StyleBuilder {
            self.style.font.bold = true;
            return self;
        }

        pub fn italic(self: *StyleBuilder) *StyleBuilder {
            self.style.font.italic = true;
            return self;
        }

        pub fn fontSize(self: *StyleBuilder, size: f32) *StyleBuilder {
            self.style.font.size = size;
            return self;
        }

        pub fn fontColor(self: *StyleBuilder, color: Color) *StyleBuilder {
            self.style.font.color = color;
            return self;
        }

        pub fn fill(self: *StyleBuilder, f: FillStyle) *StyleBuilder {
            self.style.fill = f;
            return self;
        }

        pub fn bgColor(self: *StyleBuilder, color: Color) *StyleBuilder {
            self.style.fill.pattern = .solid;
            self.style.fill.fg_color = color;
            return self;
        }

        pub fn border(self: *StyleBuilder, b: Border) *StyleBuilder {
            self.style.border = b;
            return self;
        }

        pub fn numberFormat(self: *StyleBuilder, format: []const u8) *StyleBuilder {
            self.style.number_format = format;
            return self;
        }

        pub fn hAlign(self: *StyleBuilder, alignment: types.HorizontalAlign) *StyleBuilder {
            self.style.h_align = alignment;
            return self;
        }

        pub fn vAlign(self: *StyleBuilder, alignment: types.VerticalAlign) *StyleBuilder {
            self.style.v_align = alignment;
            return self;
        }

        pub fn wrapText(self: *StyleBuilder) *StyleBuilder {
            self.style.wrap_text = true;
            return self;
        }

        pub fn build(self: *StyleBuilder) !u32 {
            return self.manager.addStyle(self.style);
        }
    };

    /// Create a style builder
    pub fn createStyle(self: *StyleManager) StyleBuilder {
        return .{
            .style = .{},
            .manager = self,
        };
    }
};

// Helper functions for equality checks
fn stylesEqual(a: CellStyle, b: CellStyle) bool {
    return fontsEqual(a.font, b.font) and
        fillsEqual(a.fill, b.fill) and
        bordersEqual(a.border, b.border) and
        a.h_align == b.h_align and
        a.v_align == b.v_align and
        a.wrap_text == b.wrap_text and
        a.shrink_to_fit == b.shrink_to_fit and
        a.text_rotation == b.text_rotation and
        a.indent == b.indent and
        std.mem.eql(u8, a.number_format, b.number_format);
}

fn fontsEqual(a: FontStyle, b: FontStyle) bool {
    return std.mem.eql(u8, a.name, b.name) and
        a.size == b.size and
        a.bold == b.bold and
        a.italic == b.italic and
        a.underline == b.underline and
        a.strikethrough == b.strikethrough and
        colorsEqual(a.color, b.color);
}

fn fillsEqual(a: FillStyle, b: FillStyle) bool {
    return a.pattern == b.pattern and
        colorsEqual(a.fg_color, b.fg_color) and
        colorsEqual(a.bg_color, b.bg_color);
}

fn bordersEqual(a: Border, b: Border) bool {
    return borderSidesEqual(a.left, b.left) and
        borderSidesEqual(a.right, b.right) and
        borderSidesEqual(a.top, b.top) and
        borderSidesEqual(a.bottom, b.bottom) and
        borderSidesEqual(a.diagonal, b.diagonal) and
        a.diagonal_up == b.diagonal_up and
        a.diagonal_down == b.diagonal_down;
}

fn borderSidesEqual(a: Border.BorderSide, b: Border.BorderSide) bool {
    return a.style == b.style and colorsEqual(a.color, b.color);
}

fn colorsEqual(a: Color, b: Color) bool {
    return a.r == b.r and a.g == b.g and a.b == b.b and a.a == b.a;
}

// Unit tests
test "StyleManager creation" {
    const allocator = std.testing.allocator;

    var mgr = try StyleManager.init(allocator);
    defer mgr.deinit();

    // Should have default style
    try std.testing.expectEqual(@as(usize, 1), mgr.styleCount());
    try std.testing.expectEqual(@as(usize, 1), mgr.fontCount());
    try std.testing.expectEqual(@as(usize, 2), mgr.fillCount());
    try std.testing.expectEqual(@as(usize, 1), mgr.borderCount());
}

test "StyleManager add style" {
    const allocator = std.testing.allocator;

    var mgr = try StyleManager.init(allocator);
    defer mgr.deinit();

    const style1 = CellStyle{
        .font = .{ .bold = true },
    };

    const idx1 = try mgr.addStyle(style1);
    try std.testing.expectEqual(@as(u32, 1), idx1);

    // Adding same style should return existing index
    const idx2 = try mgr.addStyle(style1);
    try std.testing.expectEqual(@as(u32, 1), idx2);

    // Different style should get new index
    const style2 = CellStyle{
        .font = .{ .italic = true },
    };
    const idx3 = try mgr.addStyle(style2);
    try std.testing.expectEqual(@as(u32, 2), idx3);
}

test "StyleManager builder" {
    const allocator = std.testing.allocator;

    var mgr = try StyleManager.init(allocator);
    defer mgr.deinit();

    var builder = mgr.createStyle();
    const idx = try builder
        .bold()
        .fontSize(14)
        .fontColor(Color.red)
        .bgColor(Color.yellow)
        .hAlign(.center)
        .build();

    const style = mgr.getStyle(idx).?;
    try std.testing.expect(style.font.bold);
    try std.testing.expectEqual(@as(f32, 14), style.font.size);
    try std.testing.expectEqual(types.HorizontalAlign.center, style.h_align);
}

test "StyleManager number format" {
    const allocator = std.testing.allocator;

    var mgr = try StyleManager.init(allocator);
    defer mgr.deinit();

    // Built-in format should have low ID
    const general_id = mgr.number_formats.get("General").?;
    try std.testing.expectEqual(@as(u32, 0), general_id);

    // Custom format should start at 164+
    const custom_id = try mgr.addNumberFormat("yyyy-mm-dd");
    try std.testing.expect(custom_id >= 164);
}
