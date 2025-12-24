//! UI Components
//!
//! This module defines the UI structure using Zylix's Virtual DOM.
//! Customize this file to build your application's user interface.

const std = @import("std");
const app = @import("app.zig");

// ============================================================================
// Virtual DOM Types
// ============================================================================

/// Virtual DOM node representing a UI element
pub const VNode = struct {
    /// Element type (div, text, button, etc.)
    tag: Tag,

    /// Element properties
    props: Props = .{},

    /// Child nodes
    children: []const VNode = &.{},

    /// Text content (for text nodes)
    text: ?[]const u8 = null,
};

/// Available UI element tags
pub const Tag = enum {
    // Layout
    div,
    row,
    column,
    stack,
    scroll,
    spacer,

    // Content
    text,
    image,
    icon,

    // Interactive
    button,
    text_field,
    checkbox,
    toggle,
    slider,

    // List
    list,
    list_item,

    // Navigation
    nav_bar,
    tab_bar,
    drawer,
};

/// Element properties
pub const Props = struct {
    id: ?[]const u8 = null,
    class: ?[]const u8 = null,
    style: ?Style = null,
    on_click: ?*const fn () void = null,
    on_change: ?*const fn ([]const u8) void = null,
    disabled: bool = false,
    visible: bool = true,
};

/// Style properties
pub const Style = struct {
    width: ?Size = null,
    height: ?Size = null,
    padding: ?Spacing = null,
    margin: ?Spacing = null,
    background: ?Color = null,
    color: ?Color = null,
    font_size: ?u32 = null,
    font_weight: ?FontWeight = null,
    alignment: ?Alignment = null,
    justify: ?Justify = null,
    border_radius: ?u32 = null,
};

pub const Size = union(enum) {
    px: u32,
    percent: f32,
    fill,
    wrap,
};

pub const Spacing = struct {
    top: u32 = 0,
    right: u32 = 0,
    bottom: u32 = 0,
    left: u32 = 0,

    pub fn all(value: u32) Spacing {
        return .{ .top = value, .right = value, .bottom = value, .left = value };
    }

    pub fn symmetric(vertical: u32, horizontal: u32) Spacing {
        return .{ .top = vertical, .right = horizontal, .bottom = vertical, .left = horizontal };
    }
};

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,

    pub const white = Color{ .r = 255, .g = 255, .b = 255 };
    pub const black = Color{ .r = 0, .g = 0, .b = 0 };
    pub const primary = Color{ .r = 59, .g = 130, .b = 246 }; // Blue
    pub const secondary = Color{ .r = 107, .g = 114, .b = 128 }; // Gray
    pub const success = Color{ .r = 34, .g = 197, .b = 94 }; // Green
    pub const danger = Color{ .r = 239, .g = 68, .b = 68 }; // Red
};

pub const FontWeight = enum { normal, bold, light };
pub const Alignment = enum { start, center, end, stretch };
pub const Justify = enum { start, center, end, space_between, space_around };

// ============================================================================
// UI Builder Functions
// ============================================================================

/// Build the main application view
pub fn buildMainView(state: *const app.AppState) VNode {
    return column(.{
        .style = .{
            .padding = Spacing.all(16),
            .alignment = .center,
            .justify = .center,
            .height = .fill,
        },
    }, &.{
        // Header
        text(state.app_name, .{
            .style = .{
                .font_size = 24,
                .font_weight = .bold,
                .color = Color.primary,
            },
        }),

        spacer(16),

        // Welcome message
        text("Welcome to your new Zylix app!", .{
            .style = .{
                .font_size = 16,
                .color = Color.secondary,
            },
        }),

        spacer(32),

        // Counter example
        buildCounterSection(state),

        spacer(32),

        // Version info
        text(state.version, .{
            .style = .{
                .font_size = 12,
                .color = Color.secondary,
            },
        }),
    });
}

/// Build the counter section (example component)
/// Note: Uses static buffer for counter text - safe for single-threaded rendering.
/// In production, consider passing numeric values to the renderer for formatting.
fn buildCounterSection(state: *const app.AppState) VNode {
    // Use static buffer to avoid dangling pointer from stack allocation
    const S = struct {
        var counter_text: [32]u8 = undefined;
    };
    const counter_str = std.fmt.bufPrint(&S.counter_text, "Count: {d}", .{state.counter}) catch "Count: ?";

    return column(.{
        .style = .{
            .padding = Spacing.all(24),
            .background = Color{ .r = 243, .g = 244, .b = 246 },
            .border_radius = 12,
            .alignment = .center,
        },
    }, &.{
        text(counter_str, .{
            .style = .{
                .font_size = 32,
                .font_weight = .bold,
            },
        }),

        spacer(16),

        row(.{
            .style = .{ .justify = .center },
        }, &.{
            button("-", .{
                .id = "decrement",
                .style = .{
                    .padding = Spacing.symmetric(8, 16),
                    .background = Color.secondary,
                    .color = Color.white,
                    .border_radius = 8,
                },
            }),

            spacer(16),

            button("+", .{
                .id = "increment",
                .style = .{
                    .padding = Spacing.symmetric(8, 16),
                    .background = Color.primary,
                    .color = Color.white,
                    .border_radius = 8,
                },
            }),
        }),
    });
}

// ============================================================================
// Element Constructors
// ============================================================================

pub fn div(props: Props, children: []const VNode) VNode {
    return .{ .tag = .div, .props = props, .children = children };
}

pub fn row(props: Props, children: []const VNode) VNode {
    return .{ .tag = .row, .props = props, .children = children };
}

pub fn column(props: Props, children: []const VNode) VNode {
    return .{ .tag = .column, .props = props, .children = children };
}

pub fn text(content: []const u8, props: Props) VNode {
    return .{ .tag = .text, .props = props, .text = content };
}

pub fn button(label: []const u8, props: Props) VNode {
    return .{ .tag = .button, .props = props, .text = label };
}

pub fn spacer(size: u32) VNode {
    return .{
        .tag = .spacer,
        .props = .{
            .style = .{
                .height = .{ .px = size },
                .width = .{ .px = size },
            },
        },
    };
}

pub fn image(src: []const u8, props: Props) VNode {
    return .{ .tag = .image, .props = props, .text = src };
}

// ============================================================================
// Tests
// ============================================================================

test "build main view" {
    const state = app.AppState{ .initialized = true };
    const view = buildMainView(&state);

    try std.testing.expectEqual(Tag.column, view.tag);
    try std.testing.expect(view.children.len > 0);
}

test "spacing helpers" {
    const all = Spacing.all(16);
    try std.testing.expectEqual(@as(u32, 16), all.top);
    try std.testing.expectEqual(@as(u32, 16), all.right);
    try std.testing.expectEqual(@as(u32, 16), all.bottom);
    try std.testing.expectEqual(@as(u32, 16), all.left);

    const sym = Spacing.symmetric(8, 16);
    try std.testing.expectEqual(@as(u32, 8), sym.top);
    try std.testing.expectEqual(@as(u32, 16), sym.right);
    try std.testing.expectEqual(@as(u32, 8), sym.bottom);
    try std.testing.expectEqual(@as(u32, 16), sym.left);
}
