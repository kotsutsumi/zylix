//! ZigDom CSS Utility System
//!
//! TailwindCSS-like utility system implemented in Zig.
//! Generates CSS strings or inline style objects for JavaScript to apply.
//!
//! Philosophy: Zig computes styles, JavaScript applies them to DOM.

const std = @import("std");

// === Color System ===

pub const Color = extern struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
    a: u8 = 255,

    pub fn rgb(r: u8, g: u8, b: u8) Color {
        return .{ .r = r, .g = g, .b = b, .a = 255 };
    }

    pub fn rgba(r: u8, g: u8, b: u8, a: u8) Color {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    pub fn hex(value: u32) Color {
        return .{
            .r = @truncate((value >> 16) & 0xFF),
            .g = @truncate((value >> 8) & 0xFF),
            .b = @truncate(value & 0xFF),
            .a = 255,
        };
    }

    pub fn toRgbaString(self: Color, buf: []u8) []const u8 {
        const len = std.fmt.bufPrint(buf, "rgba({d},{d},{d},{d})", .{
            self.r,
            self.g,
            self.b,
            @as(f32, @floatFromInt(self.a)) / 255.0,
        }) catch return "";
        return buf[0..len.len];
    }
};

// === Predefined Colors (TailwindCSS-like) ===

pub const colors = struct {
    // Slate
    pub const slate_50 = Color.hex(0xf8fafc);
    pub const slate_100 = Color.hex(0xf1f5f9);
    pub const slate_200 = Color.hex(0xe2e8f0);
    pub const slate_300 = Color.hex(0xcbd5e1);
    pub const slate_400 = Color.hex(0x94a3b8);
    pub const slate_500 = Color.hex(0x64748b);
    pub const slate_600 = Color.hex(0x475569);
    pub const slate_700 = Color.hex(0x334155);
    pub const slate_800 = Color.hex(0x1e293b);
    pub const slate_900 = Color.hex(0x0f172a);
    pub const slate_950 = Color.hex(0x020617);

    // Gray
    pub const gray_50 = Color.hex(0xf9fafb);
    pub const gray_100 = Color.hex(0xf3f4f6);
    pub const gray_500 = Color.hex(0x6b7280);
    pub const gray_900 = Color.hex(0x111827);

    // Red
    pub const red_50 = Color.hex(0xfef2f2);
    pub const red_500 = Color.hex(0xef4444);
    pub const red_600 = Color.hex(0xdc2626);
    pub const red_700 = Color.hex(0xb91c1c);

    // Green
    pub const green_50 = Color.hex(0xf0fdf4);
    pub const green_500 = Color.hex(0x22c55e);
    pub const green_600 = Color.hex(0x16a34a);

    // Blue
    pub const blue_50 = Color.hex(0xeff6ff);
    pub const blue_500 = Color.hex(0x3b82f6);
    pub const blue_600 = Color.hex(0x2563eb);
    pub const blue_700 = Color.hex(0x1d4ed8);

    // Indigo
    pub const indigo_500 = Color.hex(0x6366f1);
    pub const indigo_600 = Color.hex(0x4f46e5);

    // Purple
    pub const purple_500 = Color.hex(0xa855f7);
    pub const purple_600 = Color.hex(0x9333ea);

    // White/Black
    pub const white = Color.hex(0xffffff);
    pub const black = Color.hex(0x000000);
    pub const transparent = Color.rgba(0, 0, 0, 0);
};

// === Spacing System ===

pub const Spacing = enum(u8) {
    s0 = 0, // 0px
    s0_5 = 1, // 0.125rem = 2px
    s1 = 2, // 0.25rem = 4px
    s1_5 = 3, // 0.375rem = 6px
    s2 = 4, // 0.5rem = 8px
    s2_5 = 5, // 0.625rem = 10px
    s3 = 6, // 0.75rem = 12px
    s3_5 = 7, // 0.875rem = 14px
    s4 = 8, // 1rem = 16px
    s5 = 9, // 1.25rem = 20px
    s6 = 10, // 1.5rem = 24px
    s7 = 11, // 1.75rem = 28px
    s8 = 12, // 2rem = 32px
    s9 = 13, // 2.25rem = 36px
    s10 = 14, // 2.5rem = 40px
    s11 = 15, // 2.75rem = 44px
    s12 = 16, // 3rem = 48px
    s14 = 17, // 3.5rem = 56px
    s16 = 18, // 4rem = 64px
    s20 = 19, // 5rem = 80px
    s24 = 20, // 6rem = 96px
    s28 = 21, // 7rem = 112px
    s32 = 22, // 8rem = 128px
    s36 = 23, // 9rem = 144px
    s40 = 24, // 10rem = 160px
    s44 = 25, // 11rem = 176px
    s48 = 26, // 12rem = 192px
    s52 = 27, // 13rem = 208px
    s56 = 28, // 14rem = 224px
    s60 = 29, // 15rem = 240px
    s64 = 30, // 16rem = 256px
    s72 = 31, // 18rem = 288px
    s80 = 32, // 20rem = 320px
    s96 = 33, // 24rem = 384px
    auto = 255,

    pub fn toPixels(self: Spacing) ?u16 {
        return switch (self) {
            .s0 => 0,
            .s0_5 => 2,
            .s1 => 4,
            .s1_5 => 6,
            .s2 => 8,
            .s2_5 => 10,
            .s3 => 12,
            .s3_5 => 14,
            .s4 => 16,
            .s5 => 20,
            .s6 => 24,
            .s7 => 28,
            .s8 => 32,
            .s9 => 36,
            .s10 => 40,
            .s11 => 44,
            .s12 => 48,
            .s14 => 56,
            .s16 => 64,
            .s20 => 80,
            .s24 => 96,
            .s28 => 112,
            .s32 => 128,
            .s36 => 144,
            .s40 => 160,
            .s44 => 176,
            .s48 => 192,
            .s52 => 208,
            .s56 => 224,
            .s60 => 240,
            .s64 => 256,
            .s72 => 288,
            .s80 => 320,
            .s96 => 384,
            .auto => null,
        };
    }
};

// === Display ===

pub const Display = enum(u8) {
    block,
    inline_block,
    @"inline",
    flex,
    inline_flex,
    grid,
    inline_grid,
    hidden,
    contents,

    pub fn toCss(self: Display) []const u8 {
        return switch (self) {
            .block => "block",
            .inline_block => "inline-block",
            .@"inline" => "inline",
            .flex => "flex",
            .inline_flex => "inline-flex",
            .grid => "grid",
            .inline_grid => "inline-grid",
            .hidden => "none",
            .contents => "contents",
        };
    }
};

// === Flexbox ===

pub const FlexDirection = enum(u8) {
    row,
    row_reverse,
    col,
    col_reverse,

    pub fn toCss(self: FlexDirection) []const u8 {
        return switch (self) {
            .row => "row",
            .row_reverse => "row-reverse",
            .col => "column",
            .col_reverse => "column-reverse",
        };
    }
};

pub const FlexWrap = enum(u8) {
    nowrap,
    wrap,
    wrap_reverse,

    pub fn toCss(self: FlexWrap) []const u8 {
        return switch (self) {
            .nowrap => "nowrap",
            .wrap => "wrap",
            .wrap_reverse => "wrap-reverse",
        };
    }
};

pub const JustifyContent = enum(u8) {
    start,
    end,
    center,
    between,
    around,
    evenly,
    stretch,

    pub fn toCss(self: JustifyContent) []const u8 {
        return switch (self) {
            .start => "flex-start",
            .end => "flex-end",
            .center => "center",
            .between => "space-between",
            .around => "space-around",
            .evenly => "space-evenly",
            .stretch => "stretch",
        };
    }
};

pub const AlignItems = enum(u8) {
    start,
    end,
    center,
    baseline,
    stretch,

    pub fn toCss(self: AlignItems) []const u8 {
        return switch (self) {
            .start => "flex-start",
            .end => "flex-end",
            .center => "center",
            .baseline => "baseline",
            .stretch => "stretch",
        };
    }
};

// === Typography ===

pub const FontSize = enum(u8) {
    xs, // 0.75rem
    sm, // 0.875rem
    base, // 1rem
    lg, // 1.125rem
    xl, // 1.25rem
    xl2, // 1.5rem
    xl3, // 1.875rem
    xl4, // 2.25rem
    xl5, // 3rem
    xl6, // 3.75rem
    xl7, // 4.5rem
    xl8, // 6rem
    xl9, // 8rem

    pub fn toPixels(self: FontSize) u8 {
        return switch (self) {
            .xs => 12,
            .sm => 14,
            .base => 16,
            .lg => 18,
            .xl => 20,
            .xl2 => 24,
            .xl3 => 30,
            .xl4 => 36,
            .xl5 => 48,
            .xl6 => 60,
            .xl7 => 72,
            .xl8 => 96,
            .xl9 => 128,
        };
    }
};

pub const FontWeight = enum(u16) {
    thin = 100,
    extralight = 200,
    light = 300,
    normal = 400,
    medium = 500,
    semibold = 600,
    bold = 700,
    extrabold = 800,
    black = 900,
};

pub const TextAlign = enum(u8) {
    left,
    center,
    right,
    justify,
    start,
    end,

    pub fn toCss(self: TextAlign) []const u8 {
        return switch (self) {
            .left => "left",
            .center => "center",
            .right => "right",
            .justify => "justify",
            .start => "start",
            .end => "end",
        };
    }
};

// === Border ===

pub const BorderRadius = enum(u8) {
    none,
    sm,
    base,
    md,
    lg,
    xl,
    xl2,
    xl3,
    full,

    pub fn toPixels(self: BorderRadius) ?u16 {
        return switch (self) {
            .none => 0,
            .sm => 2,
            .base => 4,
            .md => 6,
            .lg => 8,
            .xl => 12,
            .xl2 => 16,
            .xl3 => 24,
            .full => null, // 9999px
        };
    }
};

pub const BorderWidth = enum(u8) {
    w0 = 0,
    w1 = 1,
    w2 = 2,
    w4 = 4,
    w8 = 8,
};

// === Shadow ===

pub const Shadow = enum(u8) {
    none,
    sm,
    base,
    md,
    lg,
    xl,
    xl2,
    inner,

    pub fn toCss(self: Shadow) []const u8 {
        return switch (self) {
            .none => "none",
            .sm => "0 1px 2px 0 rgb(0 0 0 / 0.05)",
            .base => "0 1px 3px 0 rgb(0 0 0 / 0.1), 0 1px 2px -1px rgb(0 0 0 / 0.1)",
            .md => "0 4px 6px -1px rgb(0 0 0 / 0.1), 0 2px 4px -2px rgb(0 0 0 / 0.1)",
            .lg => "0 10px 15px -3px rgb(0 0 0 / 0.1), 0 4px 6px -4px rgb(0 0 0 / 0.1)",
            .xl => "0 20px 25px -5px rgb(0 0 0 / 0.1), 0 8px 10px -6px rgb(0 0 0 / 0.1)",
            .xl2 => "0 25px 50px -12px rgb(0 0 0 / 0.25)",
            .inner => "inset 0 2px 4px 0 rgb(0 0 0 / 0.05)",
        };
    }
};

// === Complete Style Definition ===

pub const Style = extern struct {
    // Display
    display: Display = .block,

    // Flexbox
    flex_direction: FlexDirection = .row,
    flex_wrap: FlexWrap = .nowrap,
    justify_content: JustifyContent = .start,
    align_items: AlignItems = .stretch,
    gap: Spacing = .s0,
    row_gap: Spacing = .s0,
    col_gap: Spacing = .s0,

    // Spacing
    padding_top: Spacing = .s0,
    padding_right: Spacing = .s0,
    padding_bottom: Spacing = .s0,
    padding_left: Spacing = .s0,
    margin_top: Spacing = .s0,
    margin_right: Spacing = .s0,
    margin_bottom: Spacing = .s0,
    margin_left: Spacing = .s0,

    // Size
    width_px: u16 = 0, // 0 = auto
    height_px: u16 = 0, // 0 = auto
    min_width_px: u16 = 0,
    min_height_px: u16 = 0,
    max_width_px: u16 = 0, // 0 = none
    max_height_px: u16 = 0, // 0 = none

    // Typography
    font_size: FontSize = .base,
    font_weight: FontWeight = .normal,
    text_align: TextAlign = .start,

    // Colors (stored as packed RGBA)
    color: Color = colors.black,
    background_color: Color = colors.transparent,
    border_color: Color = colors.gray_500,

    // Border
    border_radius: BorderRadius = .none,
    border_width: BorderWidth = .w0,

    // Effects
    shadow: Shadow = .none,
    opacity: u8 = 255, // 0-255

    // === Builder Methods ===

    pub fn flex() Style {
        return .{ .display = .flex };
    }

    pub fn flexCol() Style {
        return .{ .display = .flex, .flex_direction = .col };
    }

    pub fn grid() Style {
        return .{ .display = .grid };
    }

    pub fn center() Style {
        return .{
            .display = .flex,
            .justify_content = .center,
            .align_items = .center,
        };
    }

    // Padding helpers
    pub fn p(self: Style, all: Spacing) Style {
        var s = self;
        s.padding_top = all;
        s.padding_right = all;
        s.padding_bottom = all;
        s.padding_left = all;
        return s;
    }

    pub fn px(self: Style, horizontal: Spacing) Style {
        var s = self;
        s.padding_left = horizontal;
        s.padding_right = horizontal;
        return s;
    }

    pub fn py(self: Style, vertical: Spacing) Style {
        var s = self;
        s.padding_top = vertical;
        s.padding_bottom = vertical;
        return s;
    }

    // Margin helpers
    pub fn m(self: Style, all: Spacing) Style {
        var s = self;
        s.margin_top = all;
        s.margin_right = all;
        s.margin_bottom = all;
        s.margin_left = all;
        return s;
    }

    pub fn mx(self: Style, horizontal: Spacing) Style {
        var s = self;
        s.margin_left = horizontal;
        s.margin_right = horizontal;
        return s;
    }

    pub fn my(self: Style, vertical: Spacing) Style {
        var s = self;
        s.margin_top = vertical;
        s.margin_bottom = vertical;
        return s;
    }

    // Gap helper
    pub fn withGap(self: Style, g: Spacing) Style {
        var s = self;
        s.gap = g;
        return s;
    }

    // Color helpers
    pub fn bg(self: Style, c: Color) Style {
        var s = self;
        s.background_color = c;
        return s;
    }

    pub fn textColor(self: Style, c: Color) Style {
        var s = self;
        s.color = c;
        return s;
    }

    // Border helpers
    pub fn rounded(self: Style, r: BorderRadius) Style {
        var s = self;
        s.border_radius = r;
        return s;
    }

    pub fn border(self: Style, w: BorderWidth, c: Color) Style {
        var s = self;
        s.border_width = w;
        s.border_color = c;
        return s;
    }

    // Shadow helper
    pub fn withShadow(self: Style, sh: Shadow) Style {
        var s = self;
        s.shadow = sh;
        return s;
    }

    // Typography helpers
    pub fn text(self: Style, size: FontSize) Style {
        var s = self;
        s.font_size = size;
        return s;
    }

    pub fn weight(self: Style, w: FontWeight) Style {
        var s = self;
        s.font_weight = w;
        return s;
    }

    pub fn textAlign(self: Style, a: TextAlign) Style {
        var s = self;
        s.text_align = a;
        return s;
    }
};

// === Style Buffer for CSS Generation ===

pub const MAX_CSS_LEN = 2048;

pub const StyleBuffer = struct {
    data: [MAX_CSS_LEN]u8 = [_]u8{0} ** MAX_CSS_LEN,
    len: usize = 0,

    pub fn append(self: *StyleBuffer, str: []const u8) void {
        const available = MAX_CSS_LEN - self.len;
        const copy_len = @min(str.len, available);
        @memcpy(self.data[self.len..][0..copy_len], str[0..copy_len]);
        self.len += copy_len;
    }

    pub fn appendFmt(self: *StyleBuffer, comptime fmt: []const u8, args: anytype) void {
        const result = std.fmt.bufPrint(self.data[self.len..], fmt, args) catch return;
        self.len += result.len;
    }

    pub fn slice(self: *const StyleBuffer) []const u8 {
        return self.data[0..self.len];
    }

    pub fn reset(self: *StyleBuffer) void {
        self.len = 0;
    }
};

// === CSS Generation ===

pub fn styleToCss(style: *const Style, buf: *StyleBuffer) void {
    buf.reset();

    // Display
    buf.append("display:");
    buf.append(style.display.toCss());
    buf.append(";");

    // Flexbox properties (only if flex/grid)
    if (style.display == .flex or style.display == .inline_flex) {
        buf.append("flex-direction:");
        buf.append(style.flex_direction.toCss());
        buf.append(";flex-wrap:");
        buf.append(style.flex_wrap.toCss());
        buf.append(";justify-content:");
        buf.append(style.justify_content.toCss());
        buf.append(";align-items:");
        buf.append(style.align_items.toCss());
        buf.append(";");

        if (style.gap.toPixels()) |px| {
            if (px > 0) buf.appendFmt("gap:{d}px;", .{px});
        }
    }

    // Padding
    if (style.padding_top.toPixels()) |px| {
        if (px > 0) buf.appendFmt("padding-top:{d}px;", .{px});
    }
    if (style.padding_right.toPixels()) |px| {
        if (px > 0) buf.appendFmt("padding-right:{d}px;", .{px});
    }
    if (style.padding_bottom.toPixels()) |px| {
        if (px > 0) buf.appendFmt("padding-bottom:{d}px;", .{px});
    }
    if (style.padding_left.toPixels()) |px| {
        if (px > 0) buf.appendFmt("padding-left:{d}px;", .{px});
    }

    // Margin
    if (style.margin_top.toPixels()) |px| {
        if (px > 0) buf.appendFmt("margin-top:{d}px;", .{px});
    }
    if (style.margin_right.toPixels()) |px| {
        if (px > 0) buf.appendFmt("margin-right:{d}px;", .{px});
    }
    if (style.margin_bottom.toPixels()) |px| {
        if (px > 0) buf.appendFmt("margin-bottom:{d}px;", .{px});
    }
    if (style.margin_left.toPixels()) |px| {
        if (px > 0) buf.appendFmt("margin-left:{d}px;", .{px});
    }

    // Size
    if (style.width_px > 0) buf.appendFmt("width:{d}px;", .{style.width_px});
    if (style.height_px > 0) buf.appendFmt("height:{d}px;", .{style.height_px});
    if (style.min_width_px > 0) buf.appendFmt("min-width:{d}px;", .{style.min_width_px});
    if (style.min_height_px > 0) buf.appendFmt("min-height:{d}px;", .{style.min_height_px});
    if (style.max_width_px > 0) buf.appendFmt("max-width:{d}px;", .{style.max_width_px});
    if (style.max_height_px > 0) buf.appendFmt("max-height:{d}px;", .{style.max_height_px});

    // Typography
    buf.appendFmt("font-size:{d}px;", .{style.font_size.toPixels()});
    buf.appendFmt("font-weight:{d};", .{@intFromEnum(style.font_weight)});
    buf.append("text-align:");
    buf.append(style.text_align.toCss());
    buf.append(";");

    // Colors
    if (style.background_color.a > 0) {
        buf.appendFmt("background-color:rgba({d},{d},{d},{d});", .{
            style.background_color.r,
            style.background_color.g,
            style.background_color.b,
            @as(f32, @floatFromInt(style.background_color.a)) / 255.0,
        });
    }
    buf.appendFmt("color:rgba({d},{d},{d},{d});", .{
        style.color.r,
        style.color.g,
        style.color.b,
        @as(f32, @floatFromInt(style.color.a)) / 255.0,
    });

    // Border
    if (style.border_width != .w0) {
        buf.appendFmt("border:{d}px solid rgba({d},{d},{d},{d});", .{
            @intFromEnum(style.border_width),
            style.border_color.r,
            style.border_color.g,
            style.border_color.b,
            @as(f32, @floatFromInt(style.border_color.a)) / 255.0,
        });
    }

    // Border radius
    if (style.border_radius != .none) {
        if (style.border_radius.toPixels()) |px| {
            buf.appendFmt("border-radius:{d}px;", .{px});
        } else {
            buf.append("border-radius:9999px;"); // full
        }
    }

    // Shadow
    if (style.shadow != .none) {
        buf.append("box-shadow:");
        buf.append(style.shadow.toCss());
        buf.append(";");
    }

    // Opacity
    if (style.opacity < 255) {
        buf.appendFmt("opacity:{d};", .{@as(f32, @floatFromInt(style.opacity)) / 255.0});
    }
}

// === Global State for WASM ===

var global_style_buffer: StyleBuffer = .{};
var global_styles: [64]Style = [_]Style{.{}} ** 64;
var global_style_count: u32 = 0;

// === WASM Exports ===

pub fn init() void {
    global_style_count = 0;
    global_style_buffer.reset();
}

pub fn createStyle() u32 {
    if (global_style_count >= 64) return 0xFFFFFFFF;
    const id = global_style_count;
    global_styles[id] = .{};
    global_style_count += 1;
    return id;
}

pub fn getStylePtr(id: u32) ?*Style {
    if (id >= global_style_count) return null;
    return &global_styles[id];
}

pub fn generateCss(id: u32) ?[*]const u8 {
    if (id >= global_style_count) return null;
    styleToCss(&global_styles[id], &global_style_buffer);
    return global_style_buffer.data[0..].ptr;
}

pub fn getCssLen() usize {
    return global_style_buffer.len;
}

pub fn getStyleCount() u32 {
    return global_style_count;
}
