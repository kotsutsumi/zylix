//! Label Component for M5Stack UI
//!
//! Text display with various alignment and styling options.

const std = @import("std");
const graphics_mod = @import("../graphics/graphics.zig");
const mod = @import("mod.zig");

const Theme = mod.Theme;
const Rect = mod.Rect;
const Component = mod.Component;

/// Text alignment
pub const TextAlign = enum {
    left,
    center,
    right,
};

/// Text vertical alignment
pub const VerticalAlign = enum {
    top,
    middle,
    bottom,
};

/// Label configuration
pub const LabelConfig = struct {
    x: i32 = 0,
    y: i32 = 0,
    width: u16 = 100,
    height: u16 = 16,
    text: []const u8 = "",
    color: u16 = Theme.text_primary,
    background: ?u16 = null,
    align: TextAlign = .left,
    vertical_align: VerticalAlign = .middle,
    font_scale: u8 = 1,
    padding: u8 = 4,
};

/// Label component
pub const Label = struct {
    // Base component
    component: Component,

    // Label-specific properties
    text: []const u8,
    color: u16,
    background: ?u16,
    align: TextAlign,
    vertical_align: VerticalAlign,
    font_scale: u8,
    padding: u8,

    // Dynamic text buffer (for formatted text)
    text_buffer: [256]u8 = undefined,
    text_buffer_len: usize = 0,
    use_buffer: bool = false,

    /// Create a new label
    pub fn init(config: LabelConfig) Label {
        return Label{
            .component = .{
                .bounds = .{
                    .x = config.x,
                    .y = config.y,
                    .width = config.width,
                    .height = config.height,
                },
                .draw_fn = drawLabel,
            },
            .text = config.text,
            .color = config.color,
            .background = config.background,
            .align = config.align,
            .vertical_align = config.vertical_align,
            .font_scale = config.font_scale,
            .padding = config.padding,
        };
    }

    /// Get component pointer
    pub fn asComponent(self: *Label) *Component {
        return &self.component;
    }

    /// Set text
    pub fn setText(self: *Label, text: []const u8) void {
        self.text = text;
        self.use_buffer = false;
    }

    /// Set formatted text (integer)
    pub fn setInt(self: *Label, value: i64) void {
        const result = std.fmt.bufPrint(&self.text_buffer, "{d}", .{value}) catch return;
        self.text_buffer_len = result.len;
        self.use_buffer = true;
    }

    /// Set formatted text (float)
    pub fn setFloat(self: *Label, value: f64, precision: u8) void {
        const fmt_str = switch (precision) {
            0 => "{d:.0}",
            1 => "{d:.1}",
            2 => "{d:.2}",
            else => "{d:.3}",
        };
        const result = std.fmt.bufPrint(&self.text_buffer, fmt_str, .{value}) catch return;
        self.text_buffer_len = result.len;
        self.use_buffer = true;
    }

    /// Set color
    pub fn setColor(self: *Label, color: u16) void {
        self.color = color;
    }

    /// Get current text
    pub fn getText(self: *const Label) []const u8 {
        if (self.use_buffer) {
            return self.text_buffer[0..self.text_buffer_len];
        }
        return self.text;
    }

    /// Draw label (static wrapper)
    fn drawLabel(comp: *Component, graphics: *graphics_mod.Graphics) void {
        const self: *Label = @fieldParentPtr("component", comp);
        self.draw(graphics);
    }

    /// Draw the label
    pub fn draw(self: *Label, graphics: *graphics_mod.Graphics) void {
        const bounds = self.component.bounds;

        // Draw background if set
        if (self.background) |bg| {
            graphics.fillRect(bounds.x, bounds.y, bounds.width, bounds.height, bg);
        }

        // Get text to draw
        const text = self.getText();
        if (text.len == 0) return;

        // Calculate text dimensions
        const char_width: i32 = 8 * @as(i32, self.font_scale);
        const char_height: i32 = 8 * @as(i32, self.font_scale);
        const text_width: i32 = @as(i32, @intCast(text.len)) * char_width;

        // Calculate X position based on alignment
        const content_width = @as(i32, bounds.width) - @as(i32, self.padding) * 2;
        var text_x = bounds.x + @as(i32, self.padding);

        switch (self.align) {
            .left => {},
            .center => {
                text_x += @divTrunc(content_width - text_width, 2);
            },
            .right => {
                text_x += content_width - text_width;
            },
        }

        // Calculate Y position based on vertical alignment
        const content_height = @as(i32, bounds.height) - @as(i32, self.padding) * 2;
        var text_y = bounds.y + @as(i32, self.padding);

        switch (self.vertical_align) {
            .top => {},
            .middle => {
                text_y += @divTrunc(content_height - char_height, 2);
            },
            .bottom => {
                text_y += content_height - char_height;
            },
        }

        // Draw text
        if (self.font_scale == 1) {
            graphics.drawText(text_x, text_y, text, self.color);
        } else {
            graphics.drawTextScaled(text_x, text_y, text, self.color, self.font_scale);
        }
    }
};

/// Create a title label (large, centered)
pub fn title(x: i32, y: i32, width: u16, text: []const u8) Label {
    return Label.init(.{
        .x = x,
        .y = y,
        .width = width,
        .height = 24,
        .text = text,
        .color = Theme.text_primary,
        .align = .center,
        .font_scale = 2,
    });
}

/// Create a subtitle label
pub fn subtitle(x: i32, y: i32, width: u16, text: []const u8) Label {
    return Label.init(.{
        .x = x,
        .y = y,
        .width = width,
        .height = 16,
        .text = text,
        .color = Theme.text_secondary,
        .align = .center,
    });
}

/// Create a body text label
pub fn body(x: i32, y: i32, width: u16, text: []const u8) Label {
    return Label.init(.{
        .x = x,
        .y = y,
        .width = width,
        .height = 16,
        .text = text,
        .color = Theme.text_primary,
        .align = .left,
    });
}

/// Create a caption label (small text)
pub fn caption(x: i32, y: i32, width: u16, text: []const u8) Label {
    return Label.init(.{
        .x = x,
        .y = y,
        .width = width,
        .height = 12,
        .text = text,
        .color = Theme.text_secondary,
        .align = .left,
    });
}

// Tests
test "Label initialization" {
    const lbl = Label.init(.{
        .x = 10,
        .y = 20,
        .width = 100,
        .height = 20,
        .text = "Hello",
    });

    try std.testing.expectEqual(@as(i32, 10), lbl.component.bounds.x);
    try std.testing.expectEqualStrings("Hello", lbl.getText());
}

test "Label setInt" {
    var lbl = Label.init(.{});

    lbl.setInt(42);
    try std.testing.expectEqualStrings("42", lbl.getText());

    lbl.setInt(-123);
    try std.testing.expectEqualStrings("-123", lbl.getText());
}

test "Label alignment" {
    const left_lbl = Label.init(.{ .align = .left });
    const center_lbl = Label.init(.{ .align = .center });
    const right_lbl = Label.init(.{ .align = .right });

    try std.testing.expectEqual(TextAlign.left, left_lbl.align);
    try std.testing.expectEqual(TextAlign.center, center_lbl.align);
    try std.testing.expectEqual(TextAlign.right, right_lbl.align);
}
