// ZigDom Virtual DOM & Reconciliation
// Phase 5.5: Efficient UI updates through diffing
//
// Architecture:
//   1. VNode tree represents desired UI state
//   2. Diff algorithm compares old vs new trees
//   3. Patches describe minimal DOM operations
//   4. Reconciler applies patches via render commands
//
// Philosophy:
//   - Zig does all computation (diffing, patching)
//   - JavaScript just applies patches to real DOM

const std = @import("std");
const component = @import("component.zig");
const dsl = @import("dsl.zig");

// ============================================================================
// Virtual DOM Node
// ============================================================================

pub const MAX_VNODE_CHILDREN = 16;
pub const MAX_VNODE_KEY_LEN = 32;
pub const MAX_VNODE_TEXT_LEN = 128;
pub const MAX_VNODE_CLASS_LEN = 64;
pub const MAX_VNODES = 256;
pub const MAX_PATCHES = 128;

pub const VNodeType = enum(u8) {
    element = 0, // DOM element (div, button, etc.)
    text = 1, // Text node
    component = 2, // Component reference
    fragment = 3, // Fragment (no DOM element)
};

pub const ElementTag = enum(u8) {
    div = 0,
    span = 1,
    section = 2,
    article = 3,
    header = 4,
    footer = 5,
    nav = 6,
    main = 7,
    aside = 8,
    h1 = 9,
    h2 = 10,
    h3 = 11,
    h4 = 12,
    h5 = 13,
    h6 = 14,
    p = 15,
    button = 16,
    a = 17,
    input = 18,
    img = 19,
    ul = 20,
    ol = 21,
    li = 22,
    form = 23,
    label = 24,
};

pub const VNodeProps = struct {
    // Styling
    class: [MAX_VNODE_CLASS_LEN]u8 = undefined,
    class_len: u8 = 0,
    style_id: u32 = 0,

    // Events (callback IDs)
    on_click: u32 = 0,
    on_input: u32 = 0,
    on_change: u32 = 0,

    // Input specific
    input_type: u8 = 0,
    placeholder: [64]u8 = undefined,
    placeholder_len: u8 = 0,
    disabled: bool = false,

    // Link specific
    href: [128]u8 = undefined,
    href_len: u8 = 0,

    // Image specific
    src: [128]u8 = undefined,
    src_len: u8 = 0,
    alt: [64]u8 = undefined,
    alt_len: u8 = 0,

    pub fn setClass(self: *VNodeProps, value: []const u8) void {
        const len = @min(value.len, MAX_VNODE_CLASS_LEN);
        @memcpy(self.class[0..len], value[0..len]);
        self.class_len = @intCast(len);
    }

    pub fn getClass(self: *const VNodeProps) []const u8 {
        return self.class[0..self.class_len];
    }

    pub fn setPlaceholder(self: *VNodeProps, value: []const u8) void {
        const len = @min(value.len, 64);
        @memcpy(self.placeholder[0..len], value[0..len]);
        self.placeholder_len = @intCast(len);
    }

    pub fn setHref(self: *VNodeProps, value: []const u8) void {
        const len = @min(value.len, 128);
        @memcpy(self.href[0..len], value[0..len]);
        self.href_len = @intCast(len);
    }

    pub fn setSrc(self: *VNodeProps, value: []const u8) void {
        const len = @min(value.len, 128);
        @memcpy(self.src[0..len], value[0..len]);
        self.src_len = @intCast(len);
    }

    pub fn setAlt(self: *VNodeProps, value: []const u8) void {
        const len = @min(value.len, 64);
        @memcpy(self.alt[0..len], value[0..len]);
        self.alt_len = @intCast(len);
    }

    pub fn equals(self: *const VNodeProps, other: *const VNodeProps) bool {
        if (self.class_len != other.class_len) return false;
        if (!std.mem.eql(u8, self.class[0..self.class_len], other.class[0..other.class_len])) return false;
        if (self.style_id != other.style_id) return false;
        if (self.on_click != other.on_click) return false;
        if (self.on_input != other.on_input) return false;
        if (self.on_change != other.on_change) return false;
        if (self.input_type != other.input_type) return false;
        if (self.disabled != other.disabled) return false;
        if (self.placeholder_len != other.placeholder_len) return false;
        if (self.href_len != other.href_len) return false;
        if (self.src_len != other.src_len) return false;
        if (self.alt_len != other.alt_len) return false;
        return true;
    }
};

pub const VNode = struct {
    id: u32 = 0,
    node_type: VNodeType = .element,
    tag: ElementTag = .div,

    // Key for reconciliation (optional, for list items)
    key: [MAX_VNODE_KEY_LEN]u8 = undefined,
    key_len: u8 = 0,

    // Text content (for text nodes)
    text: [MAX_VNODE_TEXT_LEN]u8 = undefined,
    text_len: u16 = 0,

    // Properties
    props: VNodeProps = .{},

    // Children
    children: [MAX_VNODE_CHILDREN]u32 = undefined,
    child_count: u8 = 0,

    // DOM reference (for updates)
    dom_id: u32 = 0,

    // Dirty flag
    dirty: bool = true,

    pub fn element(tag: ElementTag) VNode {
        return .{
            .node_type = .element,
            .tag = tag,
        };
    }

    pub fn textNode(content: []const u8) VNode {
        var node = VNode{
            .node_type = .text,
        };
        node.setText(content);
        return node;
    }

    pub fn fragment() VNode {
        return .{
            .node_type = .fragment,
        };
    }

    pub fn setText(self: *VNode, content: []const u8) void {
        const len = @min(content.len, MAX_VNODE_TEXT_LEN);
        @memcpy(self.text[0..len], content[0..len]);
        self.text_len = @intCast(len);
    }

    pub fn getText(self: *const VNode) []const u8 {
        return self.text[0..self.text_len];
    }

    pub fn setKey(self: *VNode, k: []const u8) void {
        const len = @min(k.len, MAX_VNODE_KEY_LEN);
        @memcpy(self.key[0..len], k[0..len]);
        self.key_len = @intCast(len);
    }

    pub fn getKey(self: *const VNode) []const u8 {
        return self.key[0..self.key_len];
    }

    pub fn hasKey(self: *const VNode) bool {
        return self.key_len > 0;
    }

    pub fn withClass(self: VNode, class_name: []const u8) VNode {
        var node = self;
        node.props.setClass(class_name);
        return node;
    }

    pub fn withStyle(self: VNode, style_id: u32) VNode {
        var node = self;
        node.props.style_id = style_id;
        return node;
    }

    pub fn withOnClick(self: VNode, callback_id: u32) VNode {
        var node = self;
        node.props.on_click = callback_id;
        return node;
    }

    pub fn withText(self: VNode, content: []const u8) VNode {
        var node = self;
        node.setText(content);
        return node;
    }

    pub fn isSameType(self: *const VNode, other: *const VNode) bool {
        if (self.node_type != other.node_type) return false;
        if (self.node_type == .element and self.tag != other.tag) return false;
        return true;
    }

    pub fn isSameKey(self: *const VNode, other: *const VNode) bool {
        if (self.key_len != other.key_len) return false;
        if (self.key_len == 0) return true; // Both have no key
        return std.mem.eql(u8, self.key[0..self.key_len], other.key[0..other.key_len]);
    }
};

// ============================================================================
// Virtual DOM Tree
// ============================================================================

pub const VTree = struct {
    nodes: [MAX_VNODES]VNode = undefined,
    count: u32 = 0,
    root_id: u32 = 0,
    next_id: u32 = 1,

    pub fn init() VTree {
        return .{};
    }

    pub fn reset(self: *VTree) void {
        self.count = 0;
        self.root_id = 0;
        self.next_id = 1;
    }

    pub fn create(self: *VTree, node: VNode) u32 {
        if (self.count >= MAX_VNODES) return 0;

        const id = self.next_id;
        self.next_id += 1;

        var new_node = node;
        new_node.id = id;
        self.nodes[self.count] = new_node;
        self.count += 1;

        return id;
    }

    pub fn get(self: *VTree, id: u32) ?*VNode {
        if (id == 0) return null;
        for (self.nodes[0..self.count]) |*node| {
            if (node.id == id) return node;
        }
        return null;
    }

    pub fn getConst(self: *const VTree, id: u32) ?*const VNode {
        if (id == 0) return null;
        for (self.nodes[0..self.count]) |*node| {
            if (node.id == id) return node;
        }
        return null;
    }

    pub fn addChild(self: *VTree, parent_id: u32, child_id: u32) bool {
        if (self.get(parent_id)) |parent| {
            if (parent.child_count >= MAX_VNODE_CHILDREN) return false;
            parent.children[parent.child_count] = child_id;
            parent.child_count += 1;
            return true;
        }
        return false;
    }

    pub fn setRoot(self: *VTree, id: u32) void {
        self.root_id = id;
    }

    pub fn getNodeCount(self: *const VTree) u32 {
        return self.count;
    }
};

// ============================================================================
// Patch Types
// ============================================================================

pub const PatchType = enum(u8) {
    none = 0,
    create = 1, // Create new DOM node
    remove = 2, // Remove DOM node
    replace = 3, // Replace node with different type
    update_props = 4, // Update properties
    update_text = 5, // Update text content
    reorder = 6, // Reorder children
    insert_child = 7, // Insert child at index
    remove_child = 8, // Remove child at index
};

pub const Patch = struct {
    patch_type: PatchType = .none,
    node_id: u32 = 0, // VNode ID
    dom_id: u32 = 0, // DOM element ID (for updates)
    parent_id: u32 = 0, // Parent DOM ID (for inserts)
    index: u16 = 0, // Child index (for reorder/insert)

    // New node data (for create/replace)
    new_tag: ElementTag = .div,
    new_node_type: VNodeType = .element,

    // Property changes
    props: VNodeProps = .{},

    // Text change
    text: [MAX_VNODE_TEXT_LEN]u8 = undefined,
    text_len: u16 = 0,

    pub fn create(node_id: u32, parent_id: u32, tag: ElementTag) Patch {
        return .{
            .patch_type = .create,
            .node_id = node_id,
            .parent_id = parent_id,
            .new_tag = tag,
            .new_node_type = .element,
        };
    }

    pub fn createText(node_id: u32, parent_id: u32, content: []const u8) Patch {
        var patch = Patch{
            .patch_type = .create,
            .node_id = node_id,
            .parent_id = parent_id,
            .new_node_type = .text,
        };
        const len = @min(content.len, MAX_VNODE_TEXT_LEN);
        @memcpy(patch.text[0..len], content[0..len]);
        patch.text_len = @intCast(len);
        return patch;
    }

    pub fn remove(dom_id: u32) Patch {
        return .{
            .patch_type = .remove,
            .dom_id = dom_id,
        };
    }

    pub fn replace(dom_id: u32, node_id: u32, tag: ElementTag) Patch {
        return .{
            .patch_type = .replace,
            .dom_id = dom_id,
            .node_id = node_id,
            .new_tag = tag,
            .new_node_type = .element,
        };
    }

    pub fn updateProps(dom_id: u32, props: VNodeProps) Patch {
        return .{
            .patch_type = .update_props,
            .dom_id = dom_id,
            .props = props,
        };
    }

    pub fn updateText(dom_id: u32, content: []const u8) Patch {
        var patch = Patch{
            .patch_type = .update_text,
            .dom_id = dom_id,
        };
        const len = @min(content.len, MAX_VNODE_TEXT_LEN);
        @memcpy(patch.text[0..len], content[0..len]);
        patch.text_len = @intCast(len);
        return patch;
    }

    pub fn insertChild(parent_dom_id: u32, child_node_id: u32, index: u16) Patch {
        return .{
            .patch_type = .insert_child,
            .parent_id = parent_dom_id,
            .node_id = child_node_id,
            .index = index,
        };
    }

    pub fn removeChild(parent_dom_id: u32, index: u16) Patch {
        return .{
            .patch_type = .remove_child,
            .parent_id = parent_dom_id,
            .index = index,
        };
    }
};

// ============================================================================
// Diff Algorithm
// ============================================================================

pub const DiffResult = struct {
    patches: [MAX_PATCHES]Patch = undefined,
    count: u32 = 0,

    pub fn addPatch(self: *DiffResult, patch: Patch) bool {
        if (self.count >= MAX_PATCHES) return false;
        self.patches[self.count] = patch;
        self.count += 1;
        return true;
    }

    pub fn getPatch(self: *const DiffResult, index: u32) ?*const Patch {
        if (index >= self.count) return null;
        return &self.patches[index];
    }
};

pub const Differ = struct {
    result: DiffResult = .{},
    next_dom_id: u32 = 1,

    pub fn init() Differ {
        return .{};
    }

    pub fn reset(self: *Differ) void {
        self.result = .{};
        self.next_dom_id = 1;
    }

    /// Diff two virtual trees and produce patches
    pub fn diff(self: *Differ, old_tree: ?*const VTree, new_tree: *const VTree) *const DiffResult {
        self.result = .{};

        if (old_tree == null) {
            // Initial render - create all nodes
            if (new_tree.root_id != 0) {
                self.createSubtree(new_tree, new_tree.root_id, 0);
            }
        } else {
            // Diff existing trees
            self.diffNode(old_tree.?, new_tree, old_tree.?.root_id, new_tree.root_id, 0);
        }

        return &self.result;
    }

    fn createSubtree(self: *Differ, tree: *const VTree, node_id: u32, parent_dom_id: u32) void {
        const node = tree.getConst(node_id) orelse return;

        // Assign DOM ID
        const dom_id = self.next_dom_id;
        self.next_dom_id += 1;

        // Create patch based on node type
        switch (node.node_type) {
            .element => {
                var patch = Patch.create(node_id, parent_dom_id, node.tag);
                patch.dom_id = dom_id;
                patch.props = node.props;
                if (node.text_len > 0) {
                    @memcpy(patch.text[0..node.text_len], node.text[0..node.text_len]);
                    patch.text_len = node.text_len;
                }
                _ = self.result.addPatch(patch);
            },
            .text => {
                var patch = Patch.createText(node_id, parent_dom_id, node.getText());
                patch.dom_id = dom_id;
                _ = self.result.addPatch(patch);
            },
            .fragment => {
                // Fragment doesn't create DOM node, children get parent's DOM ID
                for (node.children[0..node.child_count]) |child_id| {
                    self.createSubtree(tree, child_id, parent_dom_id);
                }
                return;
            },
            .component => {
                // Component reference - would need component resolution
            },
        }

        // Create children
        for (node.children[0..node.child_count]) |child_id| {
            self.createSubtree(tree, child_id, dom_id);
        }
    }

    fn diffNode(self: *Differ, old_tree: *const VTree, new_tree: *const VTree, old_id: u32, new_id: u32, parent_dom_id: u32) void {
        const old_node = old_tree.getConst(old_id);
        const new_node = new_tree.getConst(new_id);

        // Both null - nothing to do
        if (old_node == null and new_node == null) return;

        // New node added
        if (old_node == null and new_node != null) {
            self.createSubtree(new_tree, new_id, parent_dom_id);
            return;
        }

        // Old node removed
        if (old_node != null and new_node == null) {
            _ = self.result.addPatch(Patch.remove(old_node.?.dom_id));
            return;
        }

        // Both exist - compare them
        const old = old_node.?;
        const new = new_node.?;

        // Different type/tag - replace entire subtree
        if (!old.isSameType(new)) {
            _ = self.result.addPatch(Patch.remove(old.dom_id));
            self.createSubtree(new_tree, new_id, parent_dom_id);
            return;
        }

        // Same type - check for updates
        const dom_id = old.dom_id;

        switch (new.node_type) {
            .text => {
                // Text node - check if content changed
                if (!std.mem.eql(u8, old.getText(), new.getText())) {
                    _ = self.result.addPatch(Patch.updateText(dom_id, new.getText()));
                }
            },
            .element => {
                // Element - check props
                if (!old.props.equals(&new.props)) {
                    _ = self.result.addPatch(Patch.updateProps(dom_id, new.props));
                }

                // Check text content
                if (!std.mem.eql(u8, old.getText(), new.getText())) {
                    _ = self.result.addPatch(Patch.updateText(dom_id, new.getText()));
                }

                // Diff children
                self.diffChildren(old_tree, new_tree, old, new, dom_id);
            },
            .fragment => {
                // Fragment - diff children with parent's DOM ID
                self.diffChildren(old_tree, new_tree, old, new, parent_dom_id);
            },
            .component => {
                // Component diffing would go here
            },
        }
    }

    fn diffChildren(self: *Differ, old_tree: *const VTree, new_tree: *const VTree, old_node: *const VNode, new_node: *const VNode, parent_dom_id: u32) void {
        const old_count = old_node.child_count;
        const new_count = new_node.child_count;

        // Simple algorithm: diff by index
        // TODO: Key-based reconciliation for better performance
        const max_count = @max(old_count, new_count);

        var i: u8 = 0;
        while (i < max_count) : (i += 1) {
            const old_child_id = if (i < old_count) old_node.children[i] else 0;
            const new_child_id = if (i < new_count) new_node.children[i] else 0;

            if (old_child_id != 0 and new_child_id != 0) {
                // Both exist - check if keyed
                const old_child = old_tree.getConst(old_child_id);
                const new_child = new_tree.getConst(new_child_id);

                if (old_child != null and new_child != null) {
                    if (old_child.?.hasKey() and new_child.?.hasKey()) {
                        if (!old_child.?.isSameKey(new_child.?)) {
                            // Keys differ - try to find matching key
                            // For now, just replace
                            _ = self.result.addPatch(Patch.remove(old_child.?.dom_id));
                            self.createSubtree(new_tree, new_child_id, parent_dom_id);
                            continue;
                        }
                    }
                }

                self.diffNode(old_tree, new_tree, old_child_id, new_child_id, parent_dom_id);
            } else if (new_child_id != 0) {
                // New child added
                self.createSubtree(new_tree, new_child_id, parent_dom_id);
            } else if (old_child_id != 0) {
                // Old child removed
                if (old_tree.getConst(old_child_id)) |old_child| {
                    _ = self.result.addPatch(Patch.remove(old_child.dom_id));
                }
            }
        }
    }

    pub fn getPatchCount(self: *const Differ) u32 {
        return self.result.count;
    }

    pub fn getPatches(self: *const Differ) *const DiffResult {
        return &self.result;
    }
};

// ============================================================================
// Reconciler (Applies patches)
// ============================================================================

pub const Reconciler = struct {
    current_tree: VTree = VTree.init(),
    next_tree: VTree = VTree.init(),
    differ: Differ = Differ.init(),
    is_first_render: bool = true,

    pub fn init() Reconciler {
        return .{};
    }

    pub fn reset(self: *Reconciler) void {
        self.current_tree.reset();
        self.next_tree.reset();
        self.differ.reset();
        self.is_first_render = true;
    }

    /// Get the next tree for building new UI
    pub fn getNextTree(self: *Reconciler) *VTree {
        self.next_tree.reset();
        return &self.next_tree;
    }

    /// Commit the next tree and generate patches
    pub fn commit(self: *Reconciler) *const DiffResult {
        const old_tree: ?*const VTree = if (self.is_first_render) null else &self.current_tree;

        // Diff trees
        const result = self.differ.diff(old_tree, &self.next_tree);

        // Swap trees
        self.current_tree = self.next_tree;
        self.is_first_render = false;

        return result;
    }

    /// Get current tree (for inspection)
    pub fn getCurrentTree(self: *Reconciler) *const VTree {
        return &self.current_tree;
    }

    pub fn getPatchCount(self: *const Reconciler) u32 {
        return self.differ.getPatchCount();
    }
};

// ============================================================================
// Global Instance
// ============================================================================

var global_reconciler: Reconciler = .{};
var global_initialized: bool = false;

pub fn initGlobal() void {
    if (!global_initialized) {
        global_reconciler.reset();
        global_initialized = true;
    }
}

pub fn getReconciler() *Reconciler {
    return &global_reconciler;
}

pub fn resetGlobal() void {
    global_reconciler.reset();
}

// ============================================================================
// Helper Functions
// ============================================================================

/// Create element in the next tree
pub fn createElement(tag: ElementTag) u32 {
    return getReconciler().getNextTree().create(VNode.element(tag));
}

/// Create text node in the next tree
pub fn createText(content: []const u8) u32 {
    return getReconciler().getNextTree().create(VNode.textNode(content));
}

/// Set node properties
pub fn setClass(node_id: u32, class_name: []const u8) void {
    if (getReconciler().getNextTree().get(node_id)) |node| {
        node.props.setClass(class_name);
    }
}

pub fn setOnClick(node_id: u32, callback_id: u32) void {
    if (getReconciler().getNextTree().get(node_id)) |node| {
        node.props.on_click = callback_id;
    }
}

pub fn setText(node_id: u32, content: []const u8) void {
    if (getReconciler().getNextTree().get(node_id)) |node| {
        node.setText(content);
    }
}

pub fn setKey(node_id: u32, k: []const u8) void {
    if (getReconciler().getNextTree().get(node_id)) |node| {
        node.setKey(k);
    }
}

/// Add child to parent
pub fn addChild(parent_id: u32, child_id: u32) bool {
    return getReconciler().getNextTree().addChild(parent_id, child_id);
}

/// Set root node
pub fn setRoot(node_id: u32) void {
    getReconciler().getNextTree().setRoot(node_id);
}

/// Commit changes and get patches
pub fn commit() *const DiffResult {
    return getReconciler().commit();
}

/// Get patch at index
pub fn getPatch(index: u32) ?*const Patch {
    return getReconciler().differ.result.getPatch(index);
}

/// Get total patch count
pub fn getPatchCount() u32 {
    return getReconciler().getPatchCount();
}

// ============================================================================
// Tests
// ============================================================================

test "create simple vnode" {
    var tree = VTree.init();

    const div_id = tree.create(VNode.element(.div));
    try std.testing.expect(div_id > 0);

    const div = tree.get(div_id);
    try std.testing.expect(div != null);
    try std.testing.expectEqual(ElementTag.div, div.?.tag);
}

test "create text node" {
    var tree = VTree.init();

    const text_id = tree.create(VNode.textNode("Hello, World!"));
    const text = tree.get(text_id);

    try std.testing.expect(text != null);
    try std.testing.expectEqual(VNodeType.text, text.?.node_type);
    try std.testing.expectEqualStrings("Hello, World!", text.?.getText());
}

test "add children" {
    var tree = VTree.init();

    const parent_id = tree.create(VNode.element(.div));
    const child1_id = tree.create(VNode.element(.p));
    const child2_id = tree.create(VNode.element(.button));

    try std.testing.expect(tree.addChild(parent_id, child1_id));
    try std.testing.expect(tree.addChild(parent_id, child2_id));

    const parent = tree.get(parent_id);
    try std.testing.expectEqual(@as(u8, 2), parent.?.child_count);
}

test "initial render produces create patches" {
    var differ = Differ.init();
    var tree = VTree.init();

    const div_id = tree.create(VNode.element(.div));
    const text_id = tree.create(VNode.textNode("Hello"));
    _ = tree.addChild(div_id, text_id);
    tree.setRoot(div_id);

    const result = differ.diff(null, &tree);

    try std.testing.expect(result.count >= 2);
    try std.testing.expectEqual(PatchType.create, result.patches[0].patch_type);
}

test "text change produces update patch" {
    var differ = Differ.init();

    // Old tree
    var old_tree = VTree.init();
    const old_text_id = old_tree.create(VNode.textNode("Hello"));
    old_tree.setRoot(old_text_id);
    if (old_tree.get(old_text_id)) |node| {
        node.dom_id = 1;
    }

    // New tree
    var new_tree = VTree.init();
    const new_text_id = new_tree.create(VNode.textNode("World"));
    new_tree.setRoot(new_text_id);

    const result = differ.diff(&old_tree, &new_tree);

    try std.testing.expect(result.count >= 1);
    try std.testing.expectEqual(PatchType.update_text, result.patches[0].patch_type);
}

test "reconciler workflow" {
    var reconciler = Reconciler.init();

    // First render
    {
        const tree = reconciler.getNextTree();
        const div_id = tree.create(VNode.element(.div));
        const text_id = tree.create(VNode.textNode("Initial"));
        _ = tree.addChild(div_id, text_id);
        tree.setRoot(div_id);

        const patches = reconciler.commit();
        try std.testing.expect(patches.count >= 2);
    }

    // Second render with update
    {
        const tree = reconciler.getNextTree();
        const div_id = tree.create(VNode.element(.div));
        const text_id = tree.create(VNode.textNode("Updated"));
        _ = tree.addChild(div_id, text_id);
        tree.setRoot(div_id);

        const patches = reconciler.commit();
        try std.testing.expect(patches.count >= 1);
    }
}
