//! Component Gallery - UI Views
//!
//! Main gallery UI that displays component categories and examples.

const std = @import("std");
const app = @import("app.zig");

// ============================================================================
// Virtual DOM Types
// ============================================================================

pub const VNode = struct {
    tag: Tag,
    props: Props = .{},
    children: []const VNode = &.{},
    text: ?[]const u8 = null,
};

pub const Tag = enum {
    div,
    row,
    column,
    text,
    button,
    icon,
    card,
    spacer,
    scroll,
    text_field,
    checkbox,
    toggle,
    slider,
    badge,
    divider,
};

pub const Props = struct {
    id: ?[]const u8 = null,
    class: ?[]const u8 = null,
    style: ?Style = null,
    on_click: ?*const fn () void = null,
    disabled: bool = false,
    visible: bool = true,
};

pub const Style = struct {
    width: ?Size = null,
    height: ?Size = null,
    padding: ?Spacing = null,
    margin: ?Spacing = null,
    background: ?app.Color = null,
    color: ?app.Color = null,
    font_size: ?u32 = null,
    font_weight: ?FontWeight = null,
    alignment: ?Alignment = null,
    justify: ?Justify = null,
    border_radius: ?u32 = null,
    gap: ?u32 = null,
};

pub const Size = union(enum) { px: u32, percent: f32, fill, wrap };
pub const Spacing = struct {
    top: u32 = 0,
    right: u32 = 0,
    bottom: u32 = 0,
    left: u32 = 0,

    pub fn all(v: u32) Spacing {
        return .{ .top = v, .right = v, .bottom = v, .left = v };
    }
};
pub const FontWeight = enum { normal, bold, light };
pub const Alignment = enum { start, center, end, stretch };
pub const Justify = enum { start, center, end, space_between, space_around };

// ============================================================================
// Gallery Builder
// ============================================================================

/// Build the main gallery view
pub fn buildGallery(state: *const app.AppState) VNode {
    const colors = state.current_theme.colors();

    return column(.{
        .style = .{
            .height = .fill,
            .background = colors.background,
        },
    }, &.{
        // Header
        buildHeader(state),

        // Main content
        row(.{
            .style = .{
                .height = .fill,
            },
        }, &.{
            // Sidebar
            buildSidebar(state),

            // Content area
            buildContent(state),
        }),
    });
}

/// Build the header bar
fn buildHeader(state: *const app.AppState) VNode {
    const colors = state.current_theme.colors();

    return row(.{
        .style = .{
            .padding = Spacing.all(16),
            .background = colors.surface,
            .justify = .space_between,
            .alignment = .center,
        },
    }, &.{
        // Logo and title
        row(.{
            .style = .{ .alignment = .center, .gap = 12 },
        }, &.{
            text("Zylix", .{
                .style = .{
                    .font_size = 24,
                    .font_weight = .bold,
                    .color = colors.primary,
                },
            }),
            text("Component Gallery", .{
                .style = .{
                    .font_size = 18,
                    .color = colors.text_secondary,
                },
            }),
        }),

        // Theme toggle
        button(if (state.current_theme == .light) "Dark Mode" else "Light Mode", .{
            .style = .{
                .padding = .{ .top = 8, .right = 16, .bottom = 8, .left = 16 },
                .background = colors.primary,
                .color = app.Color{ .r = 255, .g = 255, .b = 255 },
                .border_radius = 8,
            },
        }),
    });
}

/// Build the category sidebar
fn buildSidebar(state: *const app.AppState) VNode {
    const colors = state.current_theme.colors();

    const categories = [_]app.ComponentCategory{
        .layout,
        .inputs,
        .display,
        .navigation,
        .feedback,
        .lists,
    };

    var items: [categories.len]VNode = undefined;
    for (categories, 0..) |cat, i| {
        items[i] = buildCategoryItem(cat, state.selected_category == cat, colors);
    }

    return column(.{
        .style = .{
            .width = .{ .px = 200 },
            .padding = Spacing.all(16),
            .background = colors.surface,
            .gap = 8,
        },
    }, &items);
}

/// Build a single category item
fn buildCategoryItem(category: app.ComponentCategory, selected: bool, colors: app.ThemeColors) VNode {
    const bg = if (selected) colors.primary else colors.surface;
    const txt_color = if (selected) app.Color{ .r = 255, .g = 255, .b = 255 } else colors.text;

    return button(category.name(), .{
        .id = @tagName(category),
        .style = .{
            .padding = Spacing.all(12),
            .background = bg,
            .color = txt_color,
            .border_radius = 8,
        },
    });
}

/// Build the main content area
fn buildContent(state: *const app.AppState) VNode {
    const colors = state.current_theme.colors();

    return column(.{
        .style = .{
            .width = .fill,
            .padding = Spacing.all(24),
            .gap = 24,
        },
    }, &.{
        // Category title
        text(state.selected_category.name(), .{
            .style = .{
                .font_size = 28,
                .font_weight = .bold,
                .color = colors.text,
            },
        }),

        // Component grid
        buildComponentGrid(state),
    });
}

/// Build the component showcase grid
fn buildComponentGrid(state: *const app.AppState) VNode {
    return switch (state.selected_category) {
        .layout => buildLayoutComponents(state),
        .inputs => buildInputComponents(state),
        .display => buildDisplayComponents(state),
        .navigation => buildNavigationComponents(state),
        .feedback => buildFeedbackComponents(state),
        .lists => buildListComponents(state),
    };
}

// ============================================================================
// Component Builders by Category
// ============================================================================

fn buildLayoutComponents(state: *const app.AppState) VNode {
    const colors = state.current_theme.colors();
    return column(.{ .style = .{ .gap = 16 } }, &.{
        buildComponentCard("Row", "Horizontal flex container", colors),
        buildComponentCard("Column", "Vertical flex container", colors),
        buildComponentCard("Stack", "Layered container", colors),
        buildComponentCard("Grid", "CSS Grid layout", colors),
    });
}

fn buildInputComponents(state: *const app.AppState) VNode {
    const colors = state.current_theme.colors();
    return column(.{ .style = .{ .gap = 16 } }, &.{
        buildComponentCard("Button", "Clickable button", colors),
        buildComponentCard("TextField", "Text input", colors),
        buildComponentCard("Checkbox", "Boolean input", colors),
        buildComponentCard("Toggle", "On/off switch", colors),
        buildComponentCard("Slider", "Range input", colors),
    });
}

fn buildDisplayComponents(state: *const app.AppState) VNode {
    const colors = state.current_theme.colors();
    return column(.{ .style = .{ .gap = 16 } }, &.{
        buildComponentCard("Text", "Typography styles", colors),
        buildComponentCard("Image", "Image display", colors),
        buildComponentCard("Icon", "Vector icons", colors),
        buildComponentCard("Card", "Content container", colors),
        buildComponentCard("Badge", "Status indicator", colors),
    });
}

fn buildNavigationComponents(state: *const app.AppState) VNode {
    const colors = state.current_theme.colors();
    return column(.{ .style = .{ .gap = 16 } }, &.{
        buildComponentCard("TabBar", "Tab navigation", colors),
        buildComponentCard("NavBar", "Navigation bar", colors),
        buildComponentCard("Drawer", "Side drawer", colors),
        buildComponentCard("Breadcrumb", "Navigation path", colors),
    });
}

fn buildFeedbackComponents(state: *const app.AppState) VNode {
    const colors = state.current_theme.colors();
    return column(.{ .style = .{ .gap = 16 } }, &.{
        buildComponentCard("Alert", "Alert messages", colors),
        buildComponentCard("Toast", "Notifications", colors),
        buildComponentCard("Progress", "Progress indicator", colors),
        buildComponentCard("Spinner", "Loading spinner", colors),
        buildComponentCard("Skeleton", "Loading placeholder", colors),
    });
}

fn buildListComponents(state: *const app.AppState) VNode {
    const colors = state.current_theme.colors();
    return column(.{ .style = .{ .gap = 16 } }, &.{
        buildComponentCard("List", "Vertical list", colors),
        buildComponentCard("ListItem", "List item", colors),
        buildComponentCard("ScrollView", "Scrollable container", colors),
    });
}

/// Build a component preview card
fn buildComponentCard(name: []const u8, description: []const u8, colors: app.ThemeColors) VNode {
    return div(.{
        .style = .{
            .padding = Spacing.all(16),
            .background = colors.surface,
            .border_radius = 12,
        },
    }, &.{
        row(.{
            .style = .{ .justify = .space_between, .alignment = .center },
        }, &.{
            column(.{ .style = .{ .gap = 4 } }, &.{
                text(name, .{
                    .style = .{
                        .font_size = 16,
                        .font_weight = .bold,
                        .color = colors.text,
                    },
                }),
                text(description, .{
                    .style = .{
                        .font_size = 14,
                        .color = colors.text_secondary,
                    },
                }),
            }),
            button("View", .{
                .style = .{
                    .padding = .{ .top = 6, .right = 12, .bottom = 6, .left = 12 },
                    .background = colors.primary,
                    .color = app.Color{ .r = 255, .g = 255, .b = 255 },
                    .border_radius = 6,
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
            .style = .{ .height = .{ .px = size }, .width = .{ .px = size } },
        },
    };
}

// ============================================================================
// Tests
// ============================================================================

test "build gallery" {
    const state = app.AppState{ .initialized = true };
    const view = buildGallery(&state);

    try std.testing.expectEqual(Tag.column, view.tag);
    try std.testing.expect(view.children.len > 0);
}

test "category item selected state" {
    const colors = app.Theme.light.colors();

    const selected = buildCategoryItem(.layout, true, colors);
    try std.testing.expectEqual(Tag.button, selected.tag);

    const unselected = buildCategoryItem(.inputs, false, colors);
    try std.testing.expectEqual(Tag.button, unselected.tag);
}

test "component card" {
    const colors = app.Theme.light.colors();
    const card = buildComponentCard("Button", "Test", colors);

    try std.testing.expectEqual(Tag.div, card.tag);
}
