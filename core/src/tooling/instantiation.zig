//! Component Instantiation API (Issue #60)
//!
//! Provides component creation from serialized data and templates.
//! Enables Live Preview tools to instantiate UI layouts from JSON.
//!
//! Features:
//! - Component creation from type and props
//! - Template-based instantiation
//! - Batch component creation
//! - C ABI for external tool integration

const std = @import("std");
const component = @import("../component.zig");
const vdom = @import("../vdom.zig");
const registry = @import("registry.zig");

// ============================================================================
// Instantiation Types
// ============================================================================

pub const MAX_TEMPLATE_SIZE = 4096;
pub const MAX_TEMPLATE_CHILDREN = 16;

/// Component creation specification
pub const ComponentSpec = struct {
    component_type: component.ComponentType = .container,

    // Text content
    text: ?[]const u8 = null,

    // Class name
    class_name: ?[]const u8 = null,

    // Style ID
    style_id: u32 = 0,

    // Layout ID
    layout_id: u32 = 0,

    // Event handlers (callback IDs)
    on_click: u32 = 0,
    on_input: u32 = 0,
    on_change: u32 = 0,

    // Input-specific
    input_type: component.InputType = .text,
    placeholder: ?[]const u8 = null,
    value: ?[]const u8 = null,

    // Link-specific
    href: ?[]const u8 = null,

    // Image-specific
    src: ?[]const u8 = null,
    alt: ?[]const u8 = null,

    // Stack props
    stack_direction: component.StackDirection = .vertical,
    stack_spacing: u16 = 0,

    // Progress props
    progress_value: f32 = 0.0,

    // State
    disabled: bool = false,
    checked: bool = false,
    expanded: bool = false,
};

/// VNode creation specification
pub const VNodeSpec = struct {
    node_type: vdom.VNodeType = .element,
    tag: vdom.ElementTag = .div,
    key: ?[]const u8 = null,
    text: ?[]const u8 = null,
    class_name: ?[]const u8 = null,
    style_id: u32 = 0,
    on_click: u32 = 0,
    on_input: u32 = 0,
    disabled: bool = false,
};

/// Template for batch component creation
pub const ComponentTemplate = struct {
    spec: ComponentSpec = .{},
    children: [MAX_TEMPLATE_CHILDREN]?*const ComponentTemplate = [_]?*const ComponentTemplate{null} ** MAX_TEMPLATE_CHILDREN,
    child_count: u8 = 0,

    pub fn addChild(self: *ComponentTemplate, child: *const ComponentTemplate) bool {
        if (self.child_count >= MAX_TEMPLATE_CHILDREN) return false;
        self.children[self.child_count] = child;
        self.child_count += 1;
        return true;
    }
};

// ============================================================================
// Factory Functions
// ============================================================================

/// Create a component from specification
pub fn createComponent(spec: ComponentSpec) component.Component {
    var comp: component.Component = switch (spec.component_type) {
        .container => component.Component.container(),
        .text => component.Component.text(spec.text orelse ""),
        .button => component.Component.button(spec.text orelse ""),
        .input => component.Component.input(spec.input_type),
        .image => component.Component.image(spec.src orelse "", spec.alt orelse ""),
        .link => component.Component.link(spec.href orelse "", spec.text orelse ""),
        .heading => component.Component.heading(.h1, spec.text orelse ""),
        .paragraph => component.Component.paragraph(spec.text orelse ""),
        .select => component.Component.selectDropdown(spec.placeholder orelse ""),
        .checkbox => component.Component.checkbox(spec.text orelse ""),
        .radio => component.Component.radio(spec.text orelse "", spec.class_name orelse ""),
        .textarea => component.Component.textarea(spec.placeholder orelse ""),
        .toggle_switch => component.Component.toggleSwitch(spec.text orelse ""),
        .stack => blk: {
            var c = if (spec.stack_direction == .horizontal)
                component.Component.hstack()
            else if (spec.stack_direction == .z_stack)
                component.Component.zstack()
            else
                component.Component.vstack();
            c.props.stack_spacing = spec.stack_spacing;
            break :blk c;
        },
        .scroll_view => component.Component.scrollView(),
        .spacer => component.Component.spacerComponent(),
        .divider => component.Component.dividerComponent(),
        .card => component.Component.cardContainer(),
        .nav_bar => component.Component.navBar(spec.text orelse ""),
        .tab_bar => component.Component.tabBar(),
        .alert => component.Component.alertDialog(spec.text orelse "", .info),
        .toast => component.Component.toastNotification(spec.text orelse "", .bottom),
        .modal => component.Component.modalDialog(spec.text orelse ""),
        .progress => blk: {
            var c = component.Component.progressIndicator(.linear);
            c.props.progress_value = spec.progress_value;
            break :blk c;
        },
        .spinner => component.Component.loadingSpinner(),
        .badge => component.Component.badgeComponent(0),
        .icon => component.Component.iconComponent(spec.text orelse ""),
        .avatar => component.Component.avatarComponent(spec.src orelse "", spec.alt orelse ""),
        .tag => component.Component.tagComponent(spec.text orelse ""),
        .accordion => component.Component.accordionComponent(spec.text orelse ""),
        .form => component.Component.formContainer(),
        else => component.Component.container(),
    };

    // Apply common properties
    if (spec.class_name) |cn| {
        comp = comp.withClass(cn);
    }

    if (spec.style_id != 0) {
        comp = comp.withStyle(spec.style_id);
    }

    if (spec.layout_id != 0) {
        comp = comp.withLayout(spec.layout_id);
    }

    if (spec.on_click != 0) {
        comp = comp.onClick(spec.on_click);
    }

    if (spec.on_input != 0) {
        comp = comp.onInput(spec.on_input);
    }

    if (spec.on_change != 0) {
        comp = comp.onChange(spec.on_change);
    }

    if (spec.placeholder) |ph| {
        comp = comp.withPlaceholder(ph);
    }

    // Apply state
    if (spec.disabled) {
        comp = comp.disabled();
    }

    if (spec.checked) {
        comp.state.checked = true;
    }

    if (spec.expanded) {
        comp.state.expanded = true;
    }

    return comp;
}

/// Create a VNode from specification
pub fn createVNode(spec: VNodeSpec) vdom.VNode {
    var node: vdom.VNode = switch (spec.node_type) {
        .element => vdom.VNode.element(spec.tag),
        .text => vdom.VNode.textNode(spec.text orelse ""),
        .fragment => vdom.VNode.fragment(),
        .component => vdom.VNode.element(spec.tag),
    };

    if (spec.key) |k| {
        node.setKey(k);
    }

    if (spec.text) |t| {
        node.setText(t);
    }

    if (spec.class_name) |cn| {
        node = node.withClass(cn);
    }

    if (spec.style_id != 0) {
        node = node.withStyle(spec.style_id);
    }

    if (spec.on_click != 0) {
        node = node.withOnClick(spec.on_click);
    }

    if (spec.on_input != 0) {
        node.props.on_input = spec.on_input;
    }

    if (spec.disabled) {
        node.props.disabled = true;
    }

    return node;
}

/// Instantiate component in tree
pub fn instantiateInTree(tree: *component.ComponentTree, spec: ComponentSpec) u32 {
    const comp = createComponent(spec);
    return tree.create(comp);
}

/// Instantiate template recursively
pub fn instantiateTemplate(tree: *component.ComponentTree, template: *const ComponentTemplate) u32 {
    const comp_id = instantiateInTree(tree, template.spec);
    if (comp_id == 0) return 0;

    for (template.children[0..template.child_count]) |maybe_child| {
        if (maybe_child) |child| {
            const child_id = instantiateTemplate(tree, child);
            if (child_id != 0) {
                _ = tree.addChild(comp_id, child_id);
            }
        }
    }

    return comp_id;
}

/// Instantiate VNode in tree
pub fn instantiateVNode(tree: *vdom.VTree, spec: VNodeSpec) u32 {
    const node = createVNode(spec);
    return tree.create(node);
}

// ============================================================================
// Quick Builders
// ============================================================================

/// Create a button quickly
pub fn button(label: []const u8, on_click: u32) ComponentSpec {
    return .{
        .component_type = .button,
        .text = label,
        .on_click = on_click,
    };
}

/// Create a text element quickly
pub fn textElement(content: []const u8) ComponentSpec {
    return .{
        .component_type = .text,
        .text = content,
    };
}

/// Create an input quickly
pub fn input(input_type: component.InputType, placeholder: ?[]const u8) ComponentSpec {
    return .{
        .component_type = .input,
        .input_type = input_type,
        .placeholder = placeholder,
    };
}

/// Create a container quickly
pub fn container() ComponentSpec {
    return .{
        .component_type = .container,
    };
}

/// Create a VStack quickly
pub fn vstack(spacing: u16) ComponentSpec {
    return .{
        .component_type = .stack,
        .stack_direction = .vertical,
        .stack_spacing = spacing,
    };
}

/// Create a HStack quickly
pub fn hstack(spacing: u16) ComponentSpec {
    return .{
        .component_type = .stack,
        .stack_direction = .horizontal,
        .stack_spacing = spacing,
    };
}

/// Create an image quickly
pub fn image(src: []const u8, alt: []const u8) ComponentSpec {
    return .{
        .component_type = .image,
        .src = src,
        .alt = alt,
    };
}

// ============================================================================
// C ABI Exports
// ============================================================================

/// ABI structure for component specification
pub const ABIComponentSpec = extern struct {
    component_type: u8,
    text: [256]u8,
    text_len: u16,
    class_name: [64]u8,
    class_name_len: u8,
    style_id: u32,
    layout_id: u32,
    on_click: u32,
    on_input: u32,
    on_change: u32,
    input_type: u8,
    placeholder: [128]u8,
    placeholder_len: u8,
    value: [256]u8,
    value_len: u16,
    href: [256]u8,
    href_len: u16,
    src: [256]u8,
    src_len: u16,
    alt: [128]u8,
    alt_len: u8,
    stack_direction: u8,
    stack_spacing: u16,
    progress_value: f32,
    disabled: bool,
    checked: bool,
    expanded: bool,
};

/// Convert ABI spec to ComponentSpec
fn abiToSpec(abi: *const ABIComponentSpec) ComponentSpec {
    return .{
        .component_type = @enumFromInt(abi.component_type),
        .text = if (abi.text_len > 0) abi.text[0..abi.text_len] else null,
        .class_name = if (abi.class_name_len > 0) abi.class_name[0..abi.class_name_len] else null,
        .style_id = abi.style_id,
        .layout_id = abi.layout_id,
        .on_click = abi.on_click,
        .on_input = abi.on_input,
        .on_change = abi.on_change,
        .input_type = @enumFromInt(abi.input_type),
        .placeholder = if (abi.placeholder_len > 0) abi.placeholder[0..abi.placeholder_len] else null,
        .value = if (abi.value_len > 0) abi.value[0..abi.value_len] else null,
        .href = if (abi.href_len > 0) abi.href[0..abi.href_len] else null,
        .src = if (abi.src_len > 0) abi.src[0..abi.src_len] else null,
        .alt = if (abi.alt_len > 0) abi.alt[0..abi.alt_len] else null,
        .stack_direction = @enumFromInt(abi.stack_direction),
        .stack_spacing = abi.stack_spacing,
        .progress_value = abi.progress_value,
        .disabled = abi.disabled,
        .checked = abi.checked,
        .expanded = abi.expanded,
    };
}

/// Create component from ABI spec
pub fn zylix_instantiate_component(spec: ?*const ABIComponentSpec) callconv(.c) u32 {
    if (spec == null) return 0;

    const tree = component.getTree();
    const parsed_spec = abiToSpec(spec.?);

    return instantiateInTree(tree, parsed_spec);
}

/// Create component with parent
pub fn zylix_instantiate_child(parent_id: u32, spec: ?*const ABIComponentSpec) callconv(.c) u32 {
    if (spec == null) return 0;

    const tree = component.getTree();
    const parsed_spec = abiToSpec(spec.?);

    const child_id = instantiateInTree(tree, parsed_spec);
    if (child_id != 0 and parent_id != 0) {
        _ = tree.addChild(parent_id, child_id);
    }

    return child_id;
}

/// Maximum text length for C ABI safety
const MAX_ABI_TEXT_LEN: u16 = 4096;

/// Create simple component by type
/// Note: Caller must ensure text_ptr points to valid memory of at least text_len bytes
pub fn zylix_instantiate_simple(
    comp_type: u8,
    text_ptr: ?[*]const u8,
    text_len: u16,
    on_click: u32,
) callconv(.c) u32 {
    const tree = component.getTree();

    // Cap text_len to prevent excessive reads (defensive C ABI boundary check)
    const safe_len = @min(text_len, MAX_ABI_TEXT_LEN);
    const spec = ComponentSpec{
        .component_type = @enumFromInt(comp_type),
        .text = if (text_ptr != null and safe_len > 0) text_ptr.?[0..safe_len] else null,
        .on_click = on_click,
    };

    return instantiateInTree(tree, spec);
}

/// Remove component from tree
pub fn zylix_remove_component(id: u32, recursive: bool) callconv(.c) void {
    const tree = component.getTree();
    tree.remove(id, recursive);
}

/// Set component as tree root
pub fn zylix_set_root(id: u32) callconv(.c) void {
    component.getTree().root_id = id;
}

/// Get component tree root
pub fn zylix_get_root() callconv(.c) u32 {
    return component.getTree().root_id;
}

// === Export symbols for C ABI ===
comptime {
    @export(&zylix_instantiate_component, .{ .name = "zylix_instantiate_component" });
    @export(&zylix_instantiate_child, .{ .name = "zylix_instantiate_child" });
    @export(&zylix_instantiate_simple, .{ .name = "zylix_instantiate_simple" });
    @export(&zylix_remove_component, .{ .name = "zylix_remove_component" });
    @export(&zylix_set_root, .{ .name = "zylix_set_root" });
    @export(&zylix_get_root, .{ .name = "zylix_get_root" });
}

// ============================================================================
// Tests
// ============================================================================

test "create component from spec" {
    const spec = button("Click me", 42);
    const comp = createComponent(spec);

    try std.testing.expectEqual(component.ComponentType.button, comp.component_type);
    try std.testing.expectEqualStrings("Click me", comp.props.getText());
    try std.testing.expect(comp.handler_count == 1);
}

test "create text component" {
    const spec = textElement("Hello, World!");
    const comp = createComponent(spec);

    try std.testing.expectEqual(component.ComponentType.text, comp.component_type);
    try std.testing.expectEqualStrings("Hello, World!", comp.props.getText());
}

test "create vstack component" {
    const spec = vstack(8);
    const comp = createComponent(spec);

    try std.testing.expectEqual(component.ComponentType.stack, comp.component_type);
    try std.testing.expectEqual(component.StackDirection.vertical, comp.props.stack_direction);
    try std.testing.expectEqual(@as(u16, 8), comp.props.stack_spacing);
}

test "instantiate in tree" {
    var tree = component.ComponentTree.init();

    const container_id = instantiateInTree(&tree, container());
    const btn_id = instantiateInTree(&tree, button("Test", 1));

    try std.testing.expect(container_id > 0);
    try std.testing.expect(btn_id > 0);

    try std.testing.expect(tree.addChild(container_id, btn_id));

    const container_comp = tree.get(container_id);
    try std.testing.expect(container_comp != null);
    try std.testing.expectEqual(@as(u8, 1), container_comp.?.child_count);
}

test "create vnode from spec" {
    const spec = VNodeSpec{
        .node_type = .element,
        .tag = .button,
        .text = "Click",
        .on_click = 42,
    };

    const node = createVNode(spec);

    try std.testing.expectEqual(vdom.VNodeType.element, node.node_type);
    try std.testing.expectEqual(vdom.ElementTag.button, node.tag);
    try std.testing.expectEqualStrings("Click", node.getText());
    try std.testing.expectEqual(@as(u32, 42), node.props.on_click);
}

test "instantiate template" {
    var tree = component.ComponentTree.init();

    var container_template = ComponentTemplate{
        .spec = container(),
    };

    var btn_template = ComponentTemplate{
        .spec = button("Button 1", 1),
    };

    var text_template = ComponentTemplate{
        .spec = textElement("Label"),
    };

    _ = container_template.addChild(&btn_template);
    _ = container_template.addChild(&text_template);

    const root_id = instantiateTemplate(&tree, &container_template);

    try std.testing.expect(root_id > 0);

    const root = tree.get(root_id);
    try std.testing.expect(root != null);
    try std.testing.expectEqual(@as(u8, 2), root.?.child_count);
}
