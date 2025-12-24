//! Zylix PDF - Text Rendering
//!
//! Text layout and rendering utilities for PDF documents.

const std = @import("std");
const types = @import("types.zig");

const Color = types.Color;
const StandardFont = types.StandardFont;
const TextAlign = types.TextAlign;
const VerticalAlign = types.VerticalAlign;
const Rectangle = types.Rectangle;

/// Text style configuration
pub const TextStyle = struct {
    font: ?StandardFont = null,
    size: f32 = 12,
    color: Color = Color.black,
    align_horizontal: TextAlign = .left,
    align_vertical: VerticalAlign = .top,
    line_height: f32 = 1.2,
    letter_spacing: f32 = 0,
    word_spacing: f32 = 0,
    underline: bool = false,
    strikethrough: bool = false,

    pub fn withFont(self: TextStyle, font_type: StandardFont) TextStyle {
        var result = self;
        result.font = font_type;
        return result;
    }

    pub fn withSize(self: TextStyle, size: f32) TextStyle {
        var result = self;
        result.size = size;
        return result;
    }

    pub fn withColor(self: TextStyle, color: Color) TextStyle {
        var result = self;
        result.color = color;
        return result;
    }

    pub fn withAlignment(self: TextStyle, align_h: TextAlign) TextStyle {
        var result = self;
        result.align_horizontal = align_h;
        return result;
    }
};

/// Text block for multi-line text rendering
pub const TextBlock = struct {
    allocator: std.mem.Allocator,
    text: []const u8,
    style: TextStyle,
    bounds: Rectangle,
    lines: std.ArrayList(TextLine),

    pub const TextLine = struct {
        text: []const u8,
        width: f32,
        start_index: usize,
        end_index: usize,
    };

    pub fn create(allocator: std.mem.Allocator, text: []const u8, bounds: Rectangle, style: TextStyle) !TextBlock {
        var block = TextBlock{
            .allocator = allocator,
            .text = text,
            .style = style,
            .bounds = bounds,
            .lines = .{},
        };

        try block.layout();
        return block;
    }

    pub fn deinit(self: *TextBlock) void {
        self.lines.deinit(self.allocator);
    }

    fn layout(self: *TextBlock) !void {
        // Simple word-wrap layout
        var line_start: usize = 0;
        var last_space: usize = 0;
        var current_width: f32 = 0;
        const char_width = self.style.size * 0.5; // Approximate character width
        const max_width = self.bounds.width;

        for (self.text, 0..) |c, i| {
            if (c == ' ') {
                last_space = i;
            }

            if (c == '\n') {
                try self.lines.append(self.allocator, .{
                    .text = self.text[line_start..i],
                    .width = current_width,
                    .start_index = line_start,
                    .end_index = i,
                });
                line_start = i + 1;
                current_width = 0;
                continue;
            }

            current_width += char_width;

            if (current_width > max_width and last_space > line_start) {
                try self.lines.append(self.allocator, .{
                    .text = self.text[line_start..last_space],
                    .width = @as(f32, @floatFromInt(last_space - line_start)) * char_width,
                    .start_index = line_start,
                    .end_index = last_space,
                });
                line_start = last_space + 1;
                current_width = @as(f32, @floatFromInt(i - last_space)) * char_width;
            }
        }

        // Add remaining text
        if (line_start < self.text.len) {
            try self.lines.append(self.allocator, .{
                .text = self.text[line_start..],
                .width = current_width,
                .start_index = line_start,
                .end_index = self.text.len,
            });
        }
    }

    pub fn getLineCount(self: *const TextBlock) usize {
        return self.lines.items.len;
    }

    pub fn getTotalHeight(self: *const TextBlock) f32 {
        const line_count = @as(f32, @floatFromInt(self.lines.items.len));
        return line_count * self.style.size * self.style.line_height;
    }
};

/// Rich text segment with individual styling
pub const RichTextSegment = struct {
    text: []const u8,
    style: TextStyle,
};

/// Rich text for mixed-style text rendering
pub const RichText = struct {
    allocator: std.mem.Allocator,
    segments: std.ArrayList(RichTextSegment),

    pub fn create(allocator: std.mem.Allocator) RichText {
        return .{
            .allocator = allocator,
            .segments = .{},
        };
    }

    pub fn deinit(self: *RichText) void {
        self.segments.deinit(self.allocator);
    }

    pub fn append(self: *RichText, text: []const u8, style: TextStyle) !void {
        try self.segments.append(self.allocator, .{
            .text = text,
            .style = style,
        });
    }

    pub fn appendText(self: *RichText, text: []const u8) !void {
        try self.append(text, .{});
    }
};

/// Calculate approximate text width
pub fn measureTextWidth(text: []const u8, font: StandardFont, size: f32) f32 {
    // Approximate character widths for standard fonts (as fraction of font size)
    const avg_width: f32 = switch (font) {
        .helvetica, .helvetica_bold, .helvetica_oblique, .helvetica_bold_oblique => 0.52,
        .times_roman, .times_bold, .times_italic, .times_bold_italic => 0.48,
        .courier, .courier_bold, .courier_oblique, .courier_bold_oblique => 0.60,
        .symbol, .zapf_dingbats => 0.55,
    };

    return @as(f32, @floatFromInt(text.len)) * size * avg_width;
}

/// Calculate text height for given line count
pub fn measureTextHeight(line_count: usize, size: f32, line_height: f32) f32 {
    return @as(f32, @floatFromInt(line_count)) * size * line_height;
}

// Unit tests
test "TextStyle builder" {
    const style = (TextStyle{}).withFont(.helvetica_bold).withSize(16).withColor(Color.blue);

    try std.testing.expectEqual(style.font.?, .helvetica_bold);
    try std.testing.expectEqual(style.size, 16);
    try std.testing.expectEqual(style.color.b, 1.0);
}

test "TextBlock layout" {
    const allocator = std.testing.allocator;

    var block = try TextBlock.create(
        allocator,
        "Hello World",
        Rectangle.init(0, 0, 200, 100),
        .{},
    );
    defer block.deinit();

    try std.testing.expect(block.getLineCount() >= 1);
}

test "measureTextWidth" {
    const width = measureTextWidth("Hello", .helvetica, 12);
    try std.testing.expect(width > 0);
    try std.testing.expect(width < 100);
}
