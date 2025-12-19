// ZigDom Declarative UI DSL
// Phase 5.4: Comptime UI declarations in Zig
//
// Usage:
//   const ui = zdom.div(.{ .class = "container" }, .{
//       zdom.h1(.{}, "Welcome"),
//       zdom.p(.{}, "Hello, ZigDom!"),
//       zdom.button(.{ .onClick = 1 }, "Click Me"),
//   });
//
// This generates a component tree that can be rendered to DOM.

const std = @import("std");
const css = @import("css.zig");
const component = @import("component.zig");

// ============================================================================
// Element Attributes
// ============================================================================

pub const Attrs = struct {
    // Common attributes
    id: ?[]const u8 = null,
    class: ?[]const u8 = null,
    style: ?u32 = null, // CSS style ID

    // Accessibility
    aria_label: ?[]const u8 = null,
    role: ?[]const u8 = null,
    tab_index: ?i8 = null,

    // Event handlers (callback IDs)
    onClick: ?u32 = null,
    onInput: ?u32 = null,
    onChange: ?u32 = null,
    onFocus: ?u32 = null,
    onBlur: ?u32 = null,
    onSubmit: ?u32 = null,

    // Input-specific
    input_type: ?component.InputType = null,
    placeholder: ?[]const u8 = null,
    value: ?[]const u8 = null,
    disabled: bool = false,

    // Link-specific
    href: ?[]const u8 = null,
    target_blank: bool = false,

    // Image-specific
    src: ?[]const u8 = null,
    alt: ?[]const u8 = null,

    // Custom data
    data: ?i64 = null,
};

// ============================================================================
// Element Node (DSL intermediate representation)
// ============================================================================

pub const MAX_DSL_CHILDREN = 16;
pub const MAX_DSL_TEXT = 256;

pub const ElementType = enum(u8) {
    // Container elements
    div,
    span,
    section,
    article,
    header,
    footer,
    nav,
    main,
    aside,

    // Text elements
    h1,
    h2,
    h3,
    h4,
    h5,
    h6,
    p,
    text,

    // Interactive elements
    button,
    a,
    input,

    // Media elements
    img,

    // List elements
    ul,
    ol,
    li,

    // Form elements
    form,
    label,

    // Fragments
    fragment,
};

pub const Element = struct {
    element_type: ElementType,
    attrs: Attrs,
    text: ?[]const u8,
    children: []const Element,

    // Convert to Component for rendering
    pub fn toComponent(self: *const Element, tree: *component.ComponentTree) u32 {
        return self.buildComponent(tree);
    }

    fn buildComponent(self: *const Element, tree: *component.ComponentTree) u32 {
        // Create the appropriate component based on element type
        var comp = switch (self.element_type) {
            .div, .span, .section, .article, .header, .footer, .nav, .main, .aside, .fragment =>
                component.Component.container(),
            .h1 => component.Component.heading(.h1, self.text orelse ""),
            .h2 => component.Component.heading(.h2, self.text orelse ""),
            .h3 => component.Component.heading(.h3, self.text orelse ""),
            .h4 => component.Component.heading(.h4, self.text orelse ""),
            .h5 => component.Component.heading(.h5, self.text orelse ""),
            .h6 => component.Component.heading(.h6, self.text orelse ""),
            .p => component.Component.paragraph(self.text orelse ""),
            .text => component.Component.text(self.text orelse ""),
            .button => component.Component.button(self.text orelse ""),
            .a => blk: {
                const href = self.attrs.href orelse "#";
                const link_label = self.text orelse "";
                break :blk component.Component.link(href, link_label);
            },
            .input => component.Component.input(self.attrs.input_type orelse .text),
            .img => blk: {
                const src_val = self.attrs.src orelse "";
                const alt_val = self.attrs.alt orelse "";
                break :blk component.Component.image(src_val, alt_val);
            },
            .ul, .ol => component.Component.container(),
            .li => component.Component.container(),
            .form => component.Component.container(),
            .label => component.Component.text(self.text orelse ""),
        };

        // Apply attributes
        if (self.attrs.style) |style_id| {
            comp = comp.withStyle(style_id);
        }
        if (self.attrs.class) |class_name| {
            comp = comp.withClass(class_name);
        }
        if (self.attrs.aria_label) |aria_label_text| {
            comp = comp.withAriaLabel(aria_label_text);
        }
        if (self.attrs.tab_index) |index| {
            comp = comp.withTabIndex(index);
        }
        if (self.attrs.data) |value| {
            comp = comp.withData(value);
        }
        if (self.attrs.placeholder) |placeholder_text| {
            comp = comp.withPlaceholder(placeholder_text);
        }
        if (self.attrs.disabled) {
            comp = comp.disabled();
        }

        // Apply event handlers
        if (self.attrs.onClick) |callback_id| {
            comp = comp.onClick(callback_id);
        }
        if (self.attrs.onInput) |callback_id| {
            comp = comp.onInput(callback_id);
        }
        if (self.attrs.onChange) |callback_id| {
            comp = comp.onChange(callback_id);
        }
        if (self.attrs.onFocus) |callback_id| {
            comp = comp.onFocus(callback_id);
        }
        if (self.attrs.onBlur) |callback_id| {
            comp = comp.onBlur(callback_id);
        }

        // Create the component in the tree
        const id = tree.create(comp);

        // Add children recursively
        for (self.children) |child| {
            const child_id = child.buildComponent(tree);
            _ = tree.addChild(id, child_id);
        }

        return id;
    }
};

// ============================================================================
// Element Builders (DSL API)
// ============================================================================

// Helper to create element with text content
fn makeElement(comptime element_type: ElementType, attrs: Attrs, text_content: ?[]const u8, children: []const Element) Element {
    return Element{
        .element_type = element_type,
        .attrs = attrs,
        .text = text_content,
        .children = children,
    };
}

// Container elements
pub fn div(attrs: Attrs, children: anytype) Element {
    return makeElement(.div, attrs, null, tupleToSlice(children));
}

pub fn span(attrs: Attrs, children: anytype) Element {
    return makeElement(.span, attrs, null, tupleToSlice(children));
}

pub fn section(attrs: Attrs, children: anytype) Element {
    return makeElement(.section, attrs, null, tupleToSlice(children));
}

pub fn article(attrs: Attrs, children: anytype) Element {
    return makeElement(.article, attrs, null, tupleToSlice(children));
}

pub fn header(attrs: Attrs, children: anytype) Element {
    return makeElement(.header, attrs, null, tupleToSlice(children));
}

pub fn footer(attrs: Attrs, children: anytype) Element {
    return makeElement(.footer, attrs, null, tupleToSlice(children));
}

pub fn nav(attrs: Attrs, children: anytype) Element {
    return makeElement(.nav, attrs, null, tupleToSlice(children));
}

pub fn main_elem(attrs: Attrs, children: anytype) Element {
    return makeElement(.main, attrs, null, tupleToSlice(children));
}

pub fn aside(attrs: Attrs, children: anytype) Element {
    return makeElement(.aside, attrs, null, tupleToSlice(children));
}

// Heading elements
pub fn h1(attrs: Attrs, content: []const u8) Element {
    return makeElement(.h1, attrs, content, &[_]Element{});
}

pub fn h2(attrs: Attrs, content: []const u8) Element {
    return makeElement(.h2, attrs, content, &[_]Element{});
}

pub fn h3(attrs: Attrs, content: []const u8) Element {
    return makeElement(.h3, attrs, content, &[_]Element{});
}

pub fn h4(attrs: Attrs, content: []const u8) Element {
    return makeElement(.h4, attrs, content, &[_]Element{});
}

pub fn h5(attrs: Attrs, content: []const u8) Element {
    return makeElement(.h5, attrs, content, &[_]Element{});
}

pub fn h6(attrs: Attrs, content: []const u8) Element {
    return makeElement(.h6, attrs, content, &[_]Element{});
}

// Text elements
pub fn p(attrs: Attrs, content: []const u8) Element {
    return makeElement(.p, attrs, content, &[_]Element{});
}

pub fn text(content: []const u8) Element {
    return makeElement(.text, .{}, content, &[_]Element{});
}

// Interactive elements
pub fn button(attrs: Attrs, button_label: []const u8) Element {
    return makeElement(.button, attrs, button_label, &[_]Element{});
}

pub fn a(attrs: Attrs, link_text: []const u8) Element {
    return makeElement(.a, attrs, link_text, &[_]Element{});
}

pub fn input(attrs: Attrs) Element {
    return makeElement(.input, attrs, null, &[_]Element{});
}

// Media elements
pub fn img(attrs: Attrs) Element {
    return makeElement(.img, attrs, null, &[_]Element{});
}

// List elements
pub fn ul(attrs: Attrs, children: anytype) Element {
    return makeElement(.ul, attrs, null, tupleToSlice(children));
}

pub fn ol(attrs: Attrs, children: anytype) Element {
    return makeElement(.ol, attrs, null, tupleToSlice(children));
}

pub fn li(attrs: Attrs, children: anytype) Element {
    return makeElement(.li, attrs, null, tupleToSlice(children));
}

// Form elements
pub fn form(attrs: Attrs, children: anytype) Element {
    return makeElement(.form, attrs, null, tupleToSlice(children));
}

pub fn label(attrs: Attrs, content: []const u8) Element {
    return makeElement(.label, attrs, content, &[_]Element{});
}

// Fragment (no DOM element, just children)
pub fn fragment(children: anytype) Element {
    return makeElement(.fragment, .{}, null, tupleToSlice(children));
}

// ============================================================================
// Helper: Convert tuple to slice
// ============================================================================

fn tupleToSlice(tuple: anytype) []const Element {
    const T = @TypeOf(tuple);
    const info = @typeInfo(T);

    if (info == .@"struct" and info.@"struct".is_tuple) {
        const fields = info.@"struct".fields;
        if (fields.len == 0) {
            return &[_]Element{};
        }

        comptime var result: [fields.len]Element = undefined;
        inline for (fields, 0..) |field, i| {
            result[i] = @field(tuple, field.name);
        }
        return &result;
    } else if (T == void or (info == .@"struct" and info.@"struct".fields.len == 0)) {
        return &[_]Element{};
    } else {
        @compileError("Expected tuple of Elements");
    }
}

// ============================================================================
// Runtime DSL Builder (for dynamic UI)
// ============================================================================

pub const RuntimeBuilder = struct {
    tree: *component.ComponentTree,

    pub fn init(tree: *component.ComponentTree) RuntimeBuilder {
        return .{ .tree = tree };
    }

    pub fn build(self: *RuntimeBuilder, element: *const Element) u32 {
        return element.toComponent(self.tree);
    }

    pub fn reset(self: *RuntimeBuilder) void {
        self.tree.reset();
    }
};

// ============================================================================
// Global Runtime Builder
// ============================================================================

var global_builder: ?RuntimeBuilder = null;

pub fn initBuilder() void {
    component.initGlobal();
    global_builder = RuntimeBuilder.init(component.getTree());
}

pub fn getBuilder() *RuntimeBuilder {
    if (global_builder == null) {
        initBuilder();
    }
    return &global_builder.?;
}

pub fn buildElement(element: *const Element) u32 {
    return getBuilder().build(element);
}

pub fn resetBuilder() void {
    if (global_builder) |*builder| {
        builder.reset();
    }
}

// ============================================================================
// Prebuilt UI Components (shadcn-like)
// ============================================================================

pub const ui = struct {
    // Card component
    pub fn card(attrs: Attrs, children: anytype) Element {
        var card_attrs = attrs;
        card_attrs.class = attrs.class orelse "card";
        return div(card_attrs, children);
    }

    pub fn cardHeader(attrs: Attrs, children: anytype) Element {
        var header_attrs = attrs;
        header_attrs.class = attrs.class orelse "card-header";
        return div(header_attrs, children);
    }

    pub fn cardTitle(attrs: Attrs, content: []const u8) Element {
        var title_attrs = attrs;
        title_attrs.class = attrs.class orelse "card-title";
        return h2(title_attrs, content);
    }

    pub fn cardContent(attrs: Attrs, children: anytype) Element {
        var content_attrs = attrs;
        content_attrs.class = attrs.class orelse "card-content";
        return div(content_attrs, children);
    }

    pub fn cardFooter(attrs: Attrs, children: anytype) Element {
        var footer_attrs = attrs;
        footer_attrs.class = attrs.class orelse "card-footer";
        return div(footer_attrs, children);
    }

    // Button variants
    pub fn primaryButton(attrs: Attrs, label_text: []const u8) Element {
        var btn_attrs = attrs;
        btn_attrs.class = attrs.class orelse "btn-primary";
        return button(btn_attrs, label_text);
    }

    pub fn secondaryButton(attrs: Attrs, label_text: []const u8) Element {
        var btn_attrs = attrs;
        btn_attrs.class = attrs.class orelse "btn-secondary";
        return button(btn_attrs, label_text);
    }

    pub fn outlineButton(attrs: Attrs, label_text: []const u8) Element {
        var btn_attrs = attrs;
        btn_attrs.class = attrs.class orelse "btn-outline";
        return button(btn_attrs, label_text);
    }

    pub fn ghostButton(attrs: Attrs, label_text: []const u8) Element {
        var btn_attrs = attrs;
        btn_attrs.class = attrs.class orelse "btn-ghost";
        return button(btn_attrs, label_text);
    }

    pub fn dangerButton(attrs: Attrs, label_text: []const u8) Element {
        var btn_attrs = attrs;
        btn_attrs.class = attrs.class orelse "btn-danger";
        return button(btn_attrs, label_text);
    }

    // Input variants
    pub fn textInput(attrs: Attrs) Element {
        var input_attrs = attrs;
        input_attrs.input_type = .text;
        input_attrs.class = attrs.class orelse "input";
        return input(input_attrs);
    }

    pub fn passwordInput(attrs: Attrs) Element {
        var input_attrs = attrs;
        input_attrs.input_type = .password;
        input_attrs.class = attrs.class orelse "input";
        return input(input_attrs);
    }

    pub fn emailInput(attrs: Attrs) Element {
        var input_attrs = attrs;
        input_attrs.input_type = .email;
        input_attrs.class = attrs.class orelse "input";
        return input(input_attrs);
    }

    pub fn searchInput(attrs: Attrs) Element {
        var input_attrs = attrs;
        input_attrs.input_type = .search;
        input_attrs.class = attrs.class orelse "input";
        return input(input_attrs);
    }

    // Alert component
    pub fn alert(attrs: Attrs, children: anytype) Element {
        var alert_attrs = attrs;
        alert_attrs.class = attrs.class orelse "alert";
        alert_attrs.role = "alert";
        return div(alert_attrs, children);
    }

    pub fn alertTitle(attrs: Attrs, content: []const u8) Element {
        var title_attrs = attrs;
        title_attrs.class = attrs.class orelse "alert-title";
        return h4(title_attrs, content);
    }

    pub fn alertDescription(attrs: Attrs, content: []const u8) Element {
        var desc_attrs = attrs;
        desc_attrs.class = attrs.class orelse "alert-description";
        return p(desc_attrs, content);
    }

    // Badge component
    pub fn badge(attrs: Attrs, content: []const u8) Element {
        var badge_attrs = attrs;
        badge_attrs.class = attrs.class orelse "badge";
        return span(badge_attrs, .{text(content)});
    }

    // Separator
    pub fn separator(attrs: Attrs) Element {
        var sep_attrs = attrs;
        sep_attrs.class = attrs.class orelse "separator";
        sep_attrs.role = "separator";
        return div(sep_attrs, .{});
    }

    // Flex containers
    pub fn flex(attrs: Attrs, children: anytype) Element {
        var flex_attrs = attrs;
        flex_attrs.class = attrs.class orelse "flex";
        return div(flex_attrs, children);
    }

    pub fn flexRow(attrs: Attrs, children: anytype) Element {
        var flex_attrs = attrs;
        flex_attrs.class = attrs.class orelse "flex-row";
        return div(flex_attrs, children);
    }

    pub fn flexCol(attrs: Attrs, children: anytype) Element {
        var flex_attrs = attrs;
        flex_attrs.class = attrs.class orelse "flex-col";
        return div(flex_attrs, children);
    }

    // Grid
    pub fn grid(attrs: Attrs, children: anytype) Element {
        var grid_attrs = attrs;
        grid_attrs.class = attrs.class orelse "grid";
        return div(grid_attrs, children);
    }

    // Stack (vertical by default)
    pub fn stack(attrs: Attrs, children: anytype) Element {
        var stack_attrs = attrs;
        stack_attrs.class = attrs.class orelse "stack";
        return div(stack_attrs, children);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "simple element creation" {
    const elem = h1(.{}, "Hello, World!");
    try std.testing.expectEqual(ElementType.h1, elem.element_type);
    try std.testing.expectEqualStrings("Hello, World!", elem.text.?);
}

test "nested elements" {
    const elem = div(.{ .class = "container" }, .{
        h1(.{}, "Title"),
        p(.{}, "Content"),
    });

    try std.testing.expectEqual(ElementType.div, elem.element_type);
    try std.testing.expectEqual(@as(usize, 2), elem.children.len);
    try std.testing.expectEqual(ElementType.h1, elem.children[0].element_type);
    try std.testing.expectEqual(ElementType.p, elem.children[1].element_type);
}

test "button with event handler" {
    const elem = button(.{ .onClick = 42 }, "Click Me");

    try std.testing.expectEqual(ElementType.button, elem.element_type);
    try std.testing.expectEqualStrings("Click Me", elem.text.?);
    try std.testing.expectEqual(@as(?u32, 42), elem.attrs.onClick);
}

test "ui component card" {
    const elem = ui.card(.{}, .{
        ui.cardHeader(.{}, .{
            ui.cardTitle(.{}, "Welcome"),
        }),
        ui.cardContent(.{}, .{
            p(.{}, "Hello from ZigDom!"),
        }),
    });

    try std.testing.expectEqual(ElementType.div, elem.element_type);
    try std.testing.expectEqualStrings("card", elem.attrs.class.?);
}

test "build to component tree" {
    var tree = component.ComponentTree.init();

    const elem = div(.{}, .{
        h1(.{}, "Test"),
        button(.{ .onClick = 1 }, "Click"),
    });

    const id = elem.toComponent(&tree);
    try std.testing.expect(id > 0);
    try std.testing.expectEqual(@as(u32, 3), tree.count());
}
