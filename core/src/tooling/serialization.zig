//! UI Layout Serialization API (Issue #59)
//!
//! Provides JSON-based serialization and deserialization of component trees.
//! Enables Live Preview tools to save/load UI layouts and sync with IDE.
//!
//! Features:
//! - Component tree to JSON serialization
//! - JSON to component tree deserialization
//! - Compact and pretty-print output formats
//! - C ABI for external tool integration

const std = @import("std");
const component = @import("../component.zig");
const vdom = @import("../vdom.zig");

// ============================================================================
// Serialization Configuration
// ============================================================================

pub const MAX_JSON_SIZE = 65536; // 64KB max JSON output
pub const MAX_DEPTH = 32; // Maximum nesting depth

pub const SerializeOptions = struct {
    pretty_print: bool = false,
    indent_size: u8 = 2,
    include_defaults: bool = false,
    include_metadata: bool = true,
};

pub const DeserializeOptions = struct {
    strict_mode: bool = false, // Fail on unknown properties
    validate_types: bool = true,
};

// ============================================================================
// JSON Writer
// ============================================================================

pub const JsonWriter = struct {
    buffer: []u8,
    pos: usize = 0,
    options: SerializeOptions = .{},
    depth: u8 = 0,
    needs_comma: bool = false,

    pub fn init(buffer: []u8, options: SerializeOptions) JsonWriter {
        return .{
            .buffer = buffer,
            .options = options,
        };
    }

    fn write(self: *JsonWriter, data: []const u8) bool {
        if (self.pos + data.len > self.buffer.len) return false;
        @memcpy(self.buffer[self.pos..][0..data.len], data);
        self.pos += data.len;
        return true;
    }

    fn writeChar(self: *JsonWriter, c: u8) bool {
        if (self.pos >= self.buffer.len) return false;
        self.buffer[self.pos] = c;
        self.pos += 1;
        return true;
    }

    fn writeIndent(self: *JsonWriter) bool {
        if (!self.options.pretty_print) return true;
        if (!self.writeChar('\n')) return false;
        const indent_count = @as(usize, self.depth) * @as(usize, self.options.indent_size);
        var i: usize = 0;
        while (i < indent_count) : (i += 1) {
            if (!self.writeChar(' ')) return false;
        }
        return true;
    }

    fn maybeComma(self: *JsonWriter) bool {
        if (self.needs_comma) {
            if (!self.writeChar(',')) return false;
        }
        self.needs_comma = false;
        return true;
    }

    pub fn beginObject(self: *JsonWriter) bool {
        if (!self.maybeComma()) return false;
        if (!self.writeChar('{')) return false;
        if (self.depth >= MAX_DEPTH) return false; // Overflow protection
        self.depth += 1;
        self.needs_comma = false;
        return true;
    }

    pub fn endObject(self: *JsonWriter) bool {
        if (self.depth == 0) return false; // Underflow protection
        self.depth -= 1;
        if (!self.writeIndent()) return false;
        if (!self.writeChar('}')) return false;
        self.needs_comma = true;
        return true;
    }

    pub fn beginArray(self: *JsonWriter) bool {
        if (!self.maybeComma()) return false;
        if (!self.writeChar('[')) return false;
        if (self.depth >= MAX_DEPTH) return false; // Overflow protection
        self.depth += 1;
        self.needs_comma = false;
        return true;
    }

    pub fn endArray(self: *JsonWriter) bool {
        if (self.depth == 0) return false; // Underflow protection
        self.depth -= 1;
        if (!self.writeIndent()) return false;
        if (!self.writeChar(']')) return false;
        self.needs_comma = true;
        return true;
    }

    pub fn writeKey(self: *JsonWriter, key: []const u8) bool {
        if (!self.maybeComma()) return false;
        if (!self.writeIndent()) return false;
        if (!self.writeChar('"')) return false;
        if (!self.write(key)) return false;
        if (!self.writeChar('"')) return false;
        if (!self.writeChar(':')) return false;
        if (self.options.pretty_print) {
            if (!self.writeChar(' ')) return false;
        }
        self.needs_comma = false;
        return true;
    }

    pub fn writeString(self: *JsonWriter, value: []const u8) bool {
        if (!self.maybeComma()) return false;
        if (!self.writeChar('"')) return false;
        // Escape special characters (full JSON compliance)
        const hex_chars = "0123456789abcdef";
        for (value) |c| {
            switch (c) {
                '"' => {
                    if (!self.write("\\\"")) return false;
                },
                '\\' => {
                    if (!self.write("\\\\")) return false;
                },
                '\n' => {
                    if (!self.write("\\n")) return false;
                },
                '\r' => {
                    if (!self.write("\\r")) return false;
                },
                '\t' => {
                    if (!self.write("\\t")) return false;
                },
                0x08 => { // backspace
                    if (!self.write("\\b")) return false;
                },
                0x0C => { // formfeed
                    if (!self.write("\\f")) return false;
                },
                0x00...0x07, 0x0B, 0x0E...0x1F => {
                    // Other control characters: use \u00XX
                    if (!self.write("\\u00")) return false;
                    if (!self.writeChar(hex_chars[c >> 4])) return false;
                    if (!self.writeChar(hex_chars[c & 0xF])) return false;
                },
                else => {
                    if (!self.writeChar(c)) return false;
                },
            }
        }
        if (!self.writeChar('"')) return false;
        self.needs_comma = true;
        return true;
    }

    pub fn writeNumber(self: *JsonWriter, value: i64) bool {
        if (!self.maybeComma()) return false;
        var buf: [20]u8 = undefined;
        const formatted = std.fmt.bufPrint(&buf, "{}", .{value}) catch return false;
        if (!self.write(formatted)) return false;
        self.needs_comma = true;
        return true;
    }

    pub fn writeFloat(self: *JsonWriter, value: f32) bool {
        if (!self.maybeComma()) return false;
        var buf: [32]u8 = undefined;
        const formatted = std.fmt.bufPrint(&buf, "{d:.4}", .{value}) catch return false;
        if (!self.write(formatted)) return false;
        self.needs_comma = true;
        return true;
    }

    pub fn writeBool(self: *JsonWriter, value: bool) bool {
        if (!self.maybeComma()) return false;
        if (!self.write(if (value) "true" else "false")) return false;
        self.needs_comma = true;
        return true;
    }

    pub fn writeNull(self: *JsonWriter) bool {
        if (!self.maybeComma()) return false;
        if (!self.write("null")) return false;
        self.needs_comma = true;
        return true;
    }

    pub fn getOutput(self: *const JsonWriter) []const u8 {
        return self.buffer[0..self.pos];
    }
};

// ============================================================================
// Component Serialization
// ============================================================================

pub fn serializeComponent(
    comp: *const component.Component,
    tree: *const component.ComponentTree,
    writer: *JsonWriter,
) bool {
    if (!writer.beginObject()) return false;

    // Type
    if (!writer.writeKey("type")) return false;
    if (!writer.writeString(componentTypeName(comp.component_type))) return false;

    // ID
    if (!writer.writeKey("id")) return false;
    if (!writer.writeNumber(@intCast(comp.id))) return false;

    // Props
    if (!writer.writeKey("props")) return false;
    if (!serializeProps(&comp.props, writer)) return false;

    // State
    if (!writer.writeKey("state")) return false;
    if (!serializeState(&comp.state, writer)) return false;

    // Children
    if (comp.child_count > 0) {
        if (!writer.writeKey("children")) return false;
        if (!writer.beginArray()) return false;

        for (comp.children[0..comp.child_count]) |child_id| {
            if (tree.getConst(child_id)) |child| {
                if (!serializeComponent(child, tree, writer)) return false;
            }
        }

        if (!writer.endArray()) return false;
    }

    if (!writer.endObject()) return false;
    return true;
}

fn serializeProps(props: *const component.ComponentProps, writer: *JsonWriter) bool {
    if (!writer.beginObject()) return false;

    // Text content
    if (props.text_len > 0) {
        if (!writer.writeKey("text")) return false;
        if (!writer.writeString(props.getText())) return false;
    }

    // Class name
    if (props.class_name_len > 0) {
        if (!writer.writeKey("className")) return false;
        if (!writer.writeString(props.class_name[0..props.class_name_len])) return false;
    }

    // Style ID
    if (props.style_id != 0) {
        if (!writer.writeKey("styleId")) return false;
        if (!writer.writeNumber(@intCast(props.style_id))) return false;
    }

    // Layout ID
    if (props.layout_id != 0) {
        if (!writer.writeKey("layoutId")) return false;
        if (!writer.writeNumber(@intCast(props.layout_id))) return false;
    }

    // Input type
    if (props.input_type != .text) {
        if (!writer.writeKey("inputType")) return false;
        if (!writer.writeString(inputTypeName(props.input_type))) return false;
    }

    // Placeholder
    if (props.placeholder_len > 0) {
        if (!writer.writeKey("placeholder")) return false;
        if (!writer.writeString(props.placeholder[0..props.placeholder_len])) return false;
    }

    // Value
    if (props.value_len > 0) {
        if (!writer.writeKey("value")) return false;
        if (!writer.writeString(props.value[0..props.value_len])) return false;
    }

    // Href
    if (props.href_len > 0) {
        if (!writer.writeKey("href")) return false;
        if (!writer.writeString(props.href[0..props.href_len])) return false;
    }

    // Src
    if (props.src_len > 0) {
        if (!writer.writeKey("src")) return false;
        if (!writer.writeString(props.src[0..props.src_len])) return false;
    }

    // Alt
    if (props.alt_len > 0) {
        if (!writer.writeKey("alt")) return false;
        if (!writer.writeString(props.alt[0..props.alt_len])) return false;
    }

    // Stack props
    if (props.stack_direction != .vertical) {
        if (!writer.writeKey("stackDirection")) return false;
        if (!writer.writeString(stackDirectionName(props.stack_direction))) return false;
    }

    if (props.stack_spacing != 0) {
        if (!writer.writeKey("stackSpacing")) return false;
        if (!writer.writeNumber(@intCast(props.stack_spacing))) return false;
    }

    // Progress props
    if (props.progress_value != 0.0) {
        if (!writer.writeKey("progressValue")) return false;
        if (!writer.writeFloat(props.progress_value)) return false;
    }

    // Data value
    if (props.data_value != 0) {
        if (!writer.writeKey("dataValue")) return false;
        if (!writer.writeNumber(props.data_value)) return false;
    }

    if (!writer.endObject()) return false;
    return true;
}

fn serializeState(state: *const component.ComponentState, writer: *JsonWriter) bool {
    if (!writer.beginObject()) return false;

    if (state.hover) {
        if (!writer.writeKey("hover")) return false;
        if (!writer.writeBool(true)) return false;
    }
    if (state.focus) {
        if (!writer.writeKey("focus")) return false;
        if (!writer.writeBool(true)) return false;
    }
    if (state.active) {
        if (!writer.writeKey("active")) return false;
        if (!writer.writeBool(true)) return false;
    }
    if (state.disabled) {
        if (!writer.writeKey("disabled")) return false;
        if (!writer.writeBool(true)) return false;
    }
    if (state.checked) {
        if (!writer.writeKey("checked")) return false;
        if (!writer.writeBool(true)) return false;
    }
    if (state.expanded) {
        if (!writer.writeKey("expanded")) return false;
        if (!writer.writeBool(true)) return false;
    }
    if (state.loading) {
        if (!writer.writeKey("loading")) return false;
        if (!writer.writeBool(true)) return false;
    }
    if (state.error_state) {
        if (!writer.writeKey("error")) return false;
        if (!writer.writeBool(true)) return false;
    }

    if (!writer.endObject()) return false;
    return true;
}

/// Serialize entire component tree
pub fn serializeTree(tree: *const component.ComponentTree, buffer: []u8, options: SerializeOptions) ?[]const u8 {
    var writer = JsonWriter.init(buffer, options);

    if (tree.root_id == 0) {
        if (!writer.writeNull()) return null;
        return writer.getOutput();
    }

    const root = tree.getConst(tree.root_id) orelse return null;

    if (!serializeComponent(root, tree, &writer)) return null;

    return writer.getOutput();
}

// ============================================================================
// VNode Serialization
// ============================================================================

pub fn serializeVNode(node: *const vdom.VNode, tree: *const vdom.VTree, writer: *JsonWriter) bool {
    if (!writer.beginObject()) return false;

    // Node type
    if (!writer.writeKey("nodeType")) return false;
    if (!writer.writeString(vnodeTypeName(node.node_type))) return false;

    // Tag (for elements)
    if (node.node_type == .element) {
        if (!writer.writeKey("tag")) return false;
        if (!writer.writeString(elementTagName(node.tag))) return false;
    }

    // ID
    if (!writer.writeKey("id")) return false;
    if (!writer.writeNumber(@intCast(node.id))) return false;

    // Key
    if (node.key_len > 0) {
        if (!writer.writeKey("key")) return false;
        if (!writer.writeString(node.getKey())) return false;
    }

    // Text content
    if (node.text_len > 0) {
        if (!writer.writeKey("text")) return false;
        if (!writer.writeString(node.getText())) return false;
    }

    // Props
    if (!writer.writeKey("props")) return false;
    if (!serializeVNodeProps(&node.props, writer)) return false;

    // Children
    if (node.child_count > 0) {
        if (!writer.writeKey("children")) return false;
        if (!writer.beginArray()) return false;

        for (node.children[0..node.child_count]) |child_id| {
            if (tree.getConst(child_id)) |child| {
                if (!serializeVNode(child, tree, writer)) return false;
            }
        }

        if (!writer.endArray()) return false;
    }

    if (!writer.endObject()) return false;
    return true;
}

fn serializeVNodeProps(props: *const vdom.VNodeProps, writer: *JsonWriter) bool {
    if (!writer.beginObject()) return false;

    if (props.class_len > 0) {
        if (!writer.writeKey("class")) return false;
        if (!writer.writeString(props.getClass())) return false;
    }

    if (props.style_id != 0) {
        if (!writer.writeKey("styleId")) return false;
        if (!writer.writeNumber(@intCast(props.style_id))) return false;
    }

    if (props.on_click != 0) {
        if (!writer.writeKey("onClick")) return false;
        if (!writer.writeNumber(@intCast(props.on_click))) return false;
    }

    if (props.on_input != 0) {
        if (!writer.writeKey("onInput")) return false;
        if (!writer.writeNumber(@intCast(props.on_input))) return false;
    }

    if (props.on_change != 0) {
        if (!writer.writeKey("onChange")) return false;
        if (!writer.writeNumber(@intCast(props.on_change))) return false;
    }

    if (props.disabled) {
        if (!writer.writeKey("disabled")) return false;
        if (!writer.writeBool(true)) return false;
    }

    if (!writer.endObject()) return false;
    return true;
}

/// Serialize VTree
pub fn serializeVTree(tree: *const vdom.VTree, buffer: []u8, options: SerializeOptions) ?[]const u8 {
    var writer = JsonWriter.init(buffer, options);

    if (tree.root_id == 0) {
        if (!writer.writeNull()) return null;
        return writer.getOutput();
    }

    const root = tree.getConst(tree.root_id) orelse return null;

    if (!serializeVNode(root, tree, &writer)) return null;

    return writer.getOutput();
}

// ============================================================================
// Helper Functions
// ============================================================================

fn componentTypeName(t: component.ComponentType) []const u8 {
    return switch (t) {
        .container => "container",
        .text => "text",
        .button => "button",
        .input => "input",
        .image => "image",
        .link => "link",
        .list => "list",
        .list_item => "listItem",
        .heading => "heading",
        .paragraph => "paragraph",
        .select => "select",
        .checkbox => "checkbox",
        .radio => "radio",
        .textarea => "textarea",
        .toggle_switch => "toggleSwitch",
        .slider => "slider",
        .date_picker => "datePicker",
        .time_picker => "timePicker",
        .file_input => "fileInput",
        .color_picker => "colorPicker",
        .form => "form",
        .stack => "stack",
        .grid => "grid",
        .scroll_view => "scrollView",
        .spacer => "spacer",
        .divider => "divider",
        .card => "card",
        .aspect_ratio => "aspectRatio",
        .safe_area => "safeArea",
        .nav_bar => "navBar",
        .tab_bar => "tabBar",
        .drawer => "drawer",
        .breadcrumb => "breadcrumb",
        .pagination => "pagination",
        .alert => "alert",
        .toast => "toast",
        .modal => "modal",
        .progress => "progress",
        .spinner => "spinner",
        .skeleton => "skeleton",
        .badge => "badge",
        .table => "table",
        .avatar => "avatar",
        .icon => "icon",
        .tag => "tag",
        .tooltip => "tooltip",
        .accordion => "accordion",
        .carousel => "carousel",
        .custom => "custom",
    };
}

fn inputTypeName(t: component.InputType) []const u8 {
    return switch (t) {
        .text => "text",
        .password => "password",
        .email => "email",
        .number => "number",
        .search => "search",
        .tel => "tel",
        .url => "url",
        .checkbox => "checkbox",
        .radio => "radio",
    };
}

fn stackDirectionName(d: component.StackDirection) []const u8 {
    return switch (d) {
        .vertical => "vertical",
        .horizontal => "horizontal",
        .z_stack => "zStack",
    };
}

fn vnodeTypeName(t: vdom.VNodeType) []const u8 {
    return switch (t) {
        .element => "element",
        .text => "text",
        .component => "component",
        .fragment => "fragment",
    };
}

fn elementTagName(tag: vdom.ElementTag) []const u8 {
    return switch (tag) {
        .div => "div",
        .span => "span",
        .section => "section",
        .article => "article",
        .header => "header",
        .footer => "footer",
        .nav => "nav",
        .main => "main",
        .aside => "aside",
        .h1 => "h1",
        .h2 => "h2",
        .h3 => "h3",
        .h4 => "h4",
        .h5 => "h5",
        .h6 => "h6",
        .p => "p",
        .button => "button",
        .a => "a",
        .input => "input",
        .img => "img",
        .ul => "ul",
        .ol => "ol",
        .li => "li",
        .form => "form",
        .label => "label",
    };
}

// ============================================================================
// C ABI Exports
// ============================================================================

// Thread-local storage for C ABI thread safety
threadlocal var serialize_buffer: [MAX_JSON_SIZE]u8 = undefined;
threadlocal var output_len: usize = 0;

/// Serialize component tree to JSON
pub fn zylix_serialize_tree(pretty: bool) callconv(.c) ?[*]const u8 {
    const tree = component.getTree();

    const options = SerializeOptions{
        .pretty_print = pretty,
    };

    if (serializeTree(tree, &serialize_buffer, options)) |output| {
        output_len = output.len;
        return output.ptr;
    }
    return null;
}

/// Get length of last serialized output
pub fn zylix_serialize_len() callconv(.c) usize {
    return output_len;
}

/// Serialize VTree to JSON
pub fn zylix_serialize_vtree(pretty: bool) callconv(.c) ?[*]const u8 {
    const tree = vdom.getReconciler().getCurrentTree();

    const options = SerializeOptions{
        .pretty_print = pretty,
    };

    if (serializeVTree(tree, &serialize_buffer, options)) |output| {
        output_len = output.len;
        return output.ptr;
    }
    return null;
}

// === Export symbols for C ABI ===
comptime {
    @export(&zylix_serialize_tree, .{ .name = "zylix_serialize_tree" });
    @export(&zylix_serialize_len, .{ .name = "zylix_serialize_len" });
    @export(&zylix_serialize_vtree, .{ .name = "zylix_serialize_vtree" });
}

// ============================================================================
// Tests
// ============================================================================

test "json writer basic" {
    var buffer: [256]u8 = undefined;
    var writer = JsonWriter.init(&buffer, .{});

    try std.testing.expect(writer.beginObject());
    try std.testing.expect(writer.writeKey("name"));
    try std.testing.expect(writer.writeString("test"));
    try std.testing.expect(writer.writeKey("count"));
    try std.testing.expect(writer.writeNumber(42));
    try std.testing.expect(writer.endObject());

    const output = writer.getOutput();
    try std.testing.expectEqualStrings("{\"name\":\"test\",\"count\":42}", output);
}

test "json writer array" {
    var buffer: [256]u8 = undefined;
    var writer = JsonWriter.init(&buffer, .{});

    try std.testing.expect(writer.beginArray());
    try std.testing.expect(writer.writeNumber(1));
    try std.testing.expect(writer.writeNumber(2));
    try std.testing.expect(writer.writeNumber(3));
    try std.testing.expect(writer.endArray());

    const output = writer.getOutput();
    try std.testing.expectEqualStrings("[1,2,3]", output);
}

test "serialize component tree" {
    var tree = component.ComponentTree.init();

    const container_id = tree.create(component.Component.container());
    const text_id = tree.create(component.Component.text("Hello"));
    _ = tree.addChild(container_id, text_id);

    var buffer: [1024]u8 = undefined;

    const output = serializeTree(&tree, &buffer, .{});
    try std.testing.expect(output != null);

    // Check that output contains expected parts
    const json = output.?;
    try std.testing.expect(std.mem.indexOf(u8, json, "\"type\":\"container\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"text\":\"Hello\"") != null);
}

test "serialize vtree" {
    var tree = vdom.VTree.init();

    const div_id = tree.create(vdom.VNode.element(.div).withClass("main"));
    const text_id = tree.create(vdom.VNode.textNode("Content"));
    _ = tree.addChild(div_id, text_id);
    tree.setRoot(div_id);

    var buffer: [1024]u8 = undefined;

    const output = serializeVTree(&tree, &buffer, .{});
    try std.testing.expect(output != null);

    const json = output.?;
    try std.testing.expect(std.mem.indexOf(u8, json, "\"nodeType\":\"element\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"tag\":\"div\"") != null);
}
