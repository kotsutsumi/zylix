//! Zylix PDF - Page Management
//!
//! PDF page creation and manipulation.

const std = @import("std");
const types = @import("types.zig");
const graphics_mod = @import("graphics.zig");
const text_mod = @import("text.zig");

const PageSize = types.PageSize;
const Rectangle = types.Rectangle;
const Point = types.Point;
const Color = types.Color;
const LineCap = types.LineCap;
const LineJoin = types.LineJoin;
const StandardFont = types.StandardFont;
const Margins = types.Margins;
const Orientation = types.Orientation;
const PdfError = types.PdfError;

const GraphicsState = graphics_mod.GraphicsState;
const Path = graphics_mod.Path;
const TextStyle = text_mod.TextStyle;

/// Forward declaration for Document
const Document = @import("document.zig").Document;

/// PDF Page
pub const Page = struct {
    allocator: std.mem.Allocator,
    document: *Document,
    size: PageSize,
    margins: Margins,
    orientation: Orientation,
    media_box: Rectangle,
    content_stream: std.ArrayList(u8),
    graphics_state: GraphicsState,
    state_stack: std.ArrayList(GraphicsState),
    current_font: ?StandardFont,
    current_font_size: f32,
    object_id: u32,

    /// Page creation options
    pub const Options = struct {
        size: PageSize = PageSize.A4,
        margins: Margins = Margins.normal,
        orientation: Orientation = .portrait,
    };

    /// Create a new page
    pub fn create(allocator: std.mem.Allocator, doc: *Document, size: PageSize) !*Page {
        return createWithOptions(allocator, doc, .{ .size = size });
    }

    /// Create a new page with options
    pub fn createWithOptions(allocator: std.mem.Allocator, doc: *Document, options: Options) !*Page {
        const pg = try allocator.create(Page);

        const effective_size = if (options.orientation == .landscape)
            options.size.landscape()
        else
            options.size;

        pg.* = .{
            .allocator = allocator,
            .document = doc,
            .size = effective_size,
            .margins = options.margins,
            .orientation = options.orientation,
            .media_box = Rectangle.fromPageSize(effective_size),
            .content_stream = .{},
            .graphics_state = GraphicsState.default(),
            .state_stack = .{},
            .current_font = null,
            .current_font_size = 12,
            .object_id = doc.allocateObjectId(),
        };

        return pg;
    }

    /// Clean up page resources
    pub fn deinit(self: *Page) void {
        self.content_stream.deinit(self.allocator);
        self.state_stack.deinit(self.allocator);
    }

    /// Clone this page for another document
    pub fn clone(self: *Page, allocator: std.mem.Allocator, doc: *Document) !*Page {
        const new_page = try allocator.create(Page);
        new_page.* = .{
            .allocator = allocator,
            .document = doc,
            .size = self.size,
            .margins = self.margins,
            .orientation = self.orientation,
            .media_box = self.media_box,
            .content_stream = try self.content_stream.clone(allocator),
            .graphics_state = self.graphics_state,
            .state_stack = try self.state_stack.clone(allocator),
            .current_font = self.current_font,
            .current_font_size = self.current_font_size,
            .object_id = doc.allocateObjectId(),
        };
        return new_page;
    }

    /// Get content area (page size minus margins)
    pub fn getContentArea(self: *const Page) Rectangle {
        return .{
            .x = self.margins.left,
            .y = self.margins.bottom,
            .width = self.size.width - self.margins.left - self.margins.right,
            .height = self.size.height - self.margins.top - self.margins.bottom,
        };
    }

    // ========================================================================
    // Graphics State
    // ========================================================================

    /// Save the current graphics state
    pub fn saveState(self: *Page) !void {
        try self.state_stack.append(self.allocator, self.graphics_state);
        try self.appendContent("q\n");
    }

    /// Restore the previous graphics state
    pub fn restoreState(self: *Page) !void {
        if (self.state_stack.items.len > 0) {
            self.graphics_state = self.state_stack.pop();
            try self.appendContent("Q\n");
        }
    }

    // ========================================================================
    // Color
    // ========================================================================

    /// Set the fill color
    pub fn setFillColor(self: *Page, color: Color) !void {
        self.graphics_state.fill_color = color;
        try self.appendContentFmt("{d} {d} {d} rg\n", .{ color.r, color.g, color.b });
    }

    /// Set the stroke color
    pub fn setStrokeColor(self: *Page, color: Color) !void {
        self.graphics_state.stroke_color = color;
        try self.appendContentFmt("{d} {d} {d} RG\n", .{ color.r, color.g, color.b });
    }

    // ========================================================================
    // Line Style
    // ========================================================================

    /// Set line width
    pub fn setLineWidth(self: *Page, width: f32) !void {
        self.graphics_state.line_width = width;
        try self.appendContentFmt("{d} w\n", .{width});
    }

    /// Set line cap style
    pub fn setLineCap(self: *Page, cap: LineCap) !void {
        self.graphics_state.line_cap = cap;
        try self.appendContentFmt("{d} J\n", .{@intFromEnum(cap)});
    }

    /// Set line join style
    pub fn setLineJoin(self: *Page, join: LineJoin) !void {
        self.graphics_state.line_join = join;
        try self.appendContentFmt("{d} j\n", .{@intFromEnum(join)});
    }

    /// Set dash pattern
    pub fn setDashPattern(self: *Page, pattern: []const f32, phase: f32) !void {
        try self.appendContent("[");
        for (pattern, 0..) |val, i| {
            if (i > 0) try self.appendContent(" ");
            try self.appendContentFmt("{d}", .{val});
        }
        try self.appendContentFmt("] {d} d\n", .{phase});
    }

    // ========================================================================
    // Text
    // ========================================================================

    /// Set the current font
    pub fn setFont(self: *Page, font_type: StandardFont, size: f32) !void {
        self.current_font = font_type;
        self.current_font_size = size;
        // Font will be set in the content stream when drawing text
    }

    /// Draw text at position
    pub fn drawText(self: *Page, text_str: []const u8, x: f32, y: f32) !void {
        const font_name = if (self.current_font) |f| f.toName() else "Helvetica";
        const font_size = self.current_font_size;

        try self.appendContent("BT\n");
        try self.appendContentFmt("/{s} {d} Tf\n", .{ font_name, font_size });
        try self.appendContentFmt("{d} {d} Td\n", .{ x, y });
        try self.appendContent("(");
        try self.appendPdfString(text_str);
        try self.appendContent(") Tj\n");
        try self.appendContent("ET\n");
    }

    /// Draw text with style
    pub fn drawTextStyled(self: *Page, text_str: []const u8, x: f32, y: f32, style: TextStyle) !void {
        try self.setFillColor(style.color);
        if (style.font) |f| {
            self.current_font = f;
        }
        self.current_font_size = style.size;
        try self.drawText(text_str, x, y);
    }

    // ========================================================================
    // Basic Shapes
    // ========================================================================

    /// Draw a line
    pub fn drawLine(self: *Page, x1: f32, y1: f32, x2: f32, y2: f32) !void {
        try self.appendContentFmt("{d} {d} m\n", .{ x1, y1 });
        try self.appendContentFmt("{d} {d} l\n", .{ x2, y2 });
        try self.appendContent("S\n");
    }

    /// Draw a rectangle (stroke only)
    pub fn drawRect(self: *Page, x: f32, y: f32, width: f32, height: f32) !void {
        try self.appendContentFmt("{d} {d} {d} {d} re\n", .{ x, y, width, height });
        try self.appendContent("S\n");
    }

    /// Fill a rectangle
    pub fn fillRect(self: *Page, x: f32, y: f32, width: f32, height: f32) !void {
        try self.appendContentFmt("{d} {d} {d} {d} re\n", .{ x, y, width, height });
        try self.appendContent("f\n");
    }

    /// Draw and fill a rectangle
    pub fn drawFillRect(self: *Page, x: f32, y: f32, width: f32, height: f32) !void {
        try self.appendContentFmt("{d} {d} {d} {d} re\n", .{ x, y, width, height });
        try self.appendContent("B\n");
    }

    /// Draw a circle (stroke only)
    pub fn drawCircle(self: *Page, cx: f32, cy: f32, radius: f32) !void {
        try self.drawEllipse(cx, cy, radius, radius);
    }

    /// Fill a circle
    pub fn fillCircle(self: *Page, cx: f32, cy: f32, radius: f32) !void {
        try self.fillEllipse(cx, cy, radius, radius);
    }

    /// Draw an ellipse (stroke only)
    pub fn drawEllipse(self: *Page, cx: f32, cy: f32, rx: f32, ry: f32) !void {
        try self.appendEllipsePath(cx, cy, rx, ry);
        try self.appendContent("S\n");
    }

    /// Fill an ellipse
    pub fn fillEllipse(self: *Page, cx: f32, cy: f32, rx: f32, ry: f32) !void {
        try self.appendEllipsePath(cx, cy, rx, ry);
        try self.appendContent("f\n");
    }

    // ========================================================================
    // Paths
    // ========================================================================

    /// Begin a new path
    pub fn beginPath(self: *Page) !void {
        // Path starts implicitly with moveTo
        _ = self;
    }

    /// Move to position
    pub fn moveTo(self: *Page, x: f32, y: f32) !void {
        try self.appendContentFmt("{d} {d} m\n", .{ x, y });
    }

    /// Line to position
    pub fn lineTo(self: *Page, x: f32, y: f32) !void {
        try self.appendContentFmt("{d} {d} l\n", .{ x, y });
    }

    /// Bezier curve to position
    pub fn curveTo(self: *Page, cp1x: f32, cp1y: f32, cp2x: f32, cp2y: f32, x: f32, y: f32) !void {
        try self.appendContentFmt("{d} {d} {d} {d} {d} {d} c\n", .{ cp1x, cp1y, cp2x, cp2y, x, y });
    }

    /// Close the current path
    pub fn closePath(self: *Page) !void {
        try self.appendContent("h\n");
    }

    /// Stroke the current path
    pub fn stroke(self: *Page) !void {
        try self.appendContent("S\n");
    }

    /// Fill the current path
    pub fn fill(self: *Page) !void {
        try self.appendContent("f\n");
    }

    /// Stroke and fill the current path
    pub fn strokeAndFill(self: *Page) !void {
        try self.appendContent("B\n");
    }

    // ========================================================================
    // Transformations
    // ========================================================================

    /// Translate coordinate system
    pub fn translate(self: *Page, tx: f32, ty: f32) !void {
        try self.appendContentFmt("1 0 0 1 {d} {d} cm\n", .{ tx, ty });
    }

    /// Scale coordinate system
    pub fn scale(self: *Page, sx: f32, sy: f32) !void {
        try self.appendContentFmt("{d} 0 0 {d} 0 0 cm\n", .{ sx, sy });
    }

    /// Rotate coordinate system (angle in radians)
    pub fn rotate(self: *Page, angle: f32) !void {
        const cos_a = @cos(angle);
        const sin_a = @sin(angle);
        try self.appendContentFmt("{d} {d} {d} {d} 0 0 cm\n", .{ cos_a, sin_a, -sin_a, cos_a });
    }

    // ========================================================================
    // Internal helpers
    // ========================================================================

    fn appendContent(self: *Page, content: []const u8) !void {
        try self.content_stream.appendSlice(self.allocator, content);
    }

    fn appendContentFmt(self: *Page, comptime fmt: []const u8, args: anytype) !void {
        var buf: [256]u8 = undefined;
        const result = std.fmt.bufPrint(&buf, fmt, args) catch |err| switch (err) {
            error.NoSpaceLeft => {
                // Fallback to dynamic allocation for large content
                const formatted = try std.fmt.allocPrint(self.allocator, fmt, args);
                defer self.allocator.free(formatted);
                try self.content_stream.appendSlice(self.allocator, formatted);
                return;
            },
        };
        try self.content_stream.appendSlice(self.allocator, result);
    }

    fn appendPdfString(self: *Page, str: []const u8) !void {
        for (str) |c| {
            switch (c) {
                '(' => try self.appendContent("\\("),
                ')' => try self.appendContent("\\)"),
                '\\' => try self.appendContent("\\\\"),
                '\n' => try self.appendContent("\\n"),
                '\r' => try self.appendContent("\\r"),
                '\t' => try self.appendContent("\\t"),
                else => {
                    var buf: [1]u8 = .{c};
                    try self.content_stream.appendSlice(self.allocator, &buf);
                },
            }
        }
    }

    fn appendEllipsePath(self: *Page, cx: f32, cy: f32, rx: f32, ry: f32) !void {
        // Approximate ellipse with 4 bezier curves
        const k: f32 = 0.5522847498; // (4/3) * tan(pi/8)
        const kx = rx * k;
        const ky = ry * k;

        try self.appendContentFmt("{d} {d} m\n", .{ cx + rx, cy });
        try self.appendContentFmt("{d} {d} {d} {d} {d} {d} c\n", .{ cx + rx, cy + ky, cx + kx, cy + ry, cx, cy + ry });
        try self.appendContentFmt("{d} {d} {d} {d} {d} {d} c\n", .{ cx - kx, cy + ry, cx - rx, cy + ky, cx - rx, cy });
        try self.appendContentFmt("{d} {d} {d} {d} {d} {d} c\n", .{ cx - rx, cy - ky, cx - kx, cy - ry, cx, cy - ry });
        try self.appendContentFmt("{d} {d} {d} {d} {d} {d} c\n", .{ cx + kx, cy - ry, cx + rx, cy - ky, cx + rx, cy });
    }

    /// Get the content stream data
    pub fn getContentStream(self: *const Page) []const u8 {
        return self.content_stream.items;
    }
};

// Unit tests
test "Page creation" {
    const allocator = std.testing.allocator;

    // Create a mock document
    const doc = @import("document.zig");
    const document = try doc.Document.create(allocator);
    defer document.deinit();

    const pg = try Page.create(allocator, document, PageSize.A4);
    defer {
        pg.deinit();
        allocator.destroy(pg);
    }

    try std.testing.expectEqual(pg.size.width, 595);
    try std.testing.expectEqual(pg.size.height, 842);
}

test "Draw text" {
    const allocator = std.testing.allocator;

    const doc = @import("document.zig");
    const document = try doc.Document.create(allocator);
    defer document.deinit();

    const pg = try Page.create(allocator, document, PageSize.A4);
    defer {
        pg.deinit();
        allocator.destroy(pg);
    }

    try pg.setFont(.helvetica, 12);
    try pg.drawText("Hello, World!", 72, 720);

    const content = pg.getContentStream();
    try std.testing.expect(content.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, content, "Hello, World!") != null);
}

test "Draw shapes" {
    const allocator = std.testing.allocator;

    const doc = @import("document.zig");
    const document = try doc.Document.create(allocator);
    defer document.deinit();

    const pg = try Page.create(allocator, document, PageSize.A4);
    defer {
        pg.deinit();
        allocator.destroy(pg);
    }

    try pg.setStrokeColor(Color.black);
    try pg.setFillColor(Color.red);
    try pg.drawRect(100, 100, 200, 150);
    try pg.fillRect(100, 300, 200, 150);

    const content = pg.getContentStream();
    try std.testing.expect(content.len > 0);
}
