---
title: Virtual DOM
weight: 1
---

The Virtual DOM (VDOM) is Zylix's core abstraction for efficient UI updates. Instead of manipulating platform UI elements directly, you describe your UI as a tree of lightweight `VNode` structures. Zylix then computes the minimal set of changes needed to update the actual UI.

## Why Virtual DOM?

Direct UI manipulation is expensive and error-prone:

```
// Without VDOM - Every change touches real UI
textLabel.text = "Count: 1"  // UI update
textLabel.text = "Count: 2"  // UI update
textLabel.text = "Count: 3"  // UI update
// 3 UI updates for 3 state changes
```

With Virtual DOM:

```
// With VDOM - Batch changes efficiently
state.count = 3              // State update
render()                     // Build new VDOM
diff(oldTree, newTree)       // Compute patches
apply(patches)               // Single UI update
```

## VNode Structure

A `VNode` represents a single node in the virtual tree:

```zig
pub const VNode = struct {
    id: u32 = 0,                    // Unique node identifier
    node_type: VNodeType = .element, // element, text, component, fragment
    tag: ElementTag = .div,          // HTML-like tag (div, span, button, etc.)

    // Key for efficient list reconciliation
    key: [MAX_VNODE_KEY_LEN]u8 = undefined,
    key_len: u8 = 0,

    // Text content (for text nodes)
    text: [MAX_VNODE_TEXT_LEN]u8 = undefined,
    text_len: u16 = 0,

    // Properties (class, styles, event handlers)
    props: VNodeProps = .{},

    // Child node IDs
    children: [MAX_VNODE_CHILDREN]u32 = undefined,
    child_count: u8 = 0,

    // DOM reference (for updates)
    dom_id: u32 = 0,

    // Dirty flag for change detection
    dirty: bool = true,
};
```

## Node Types

Zylix supports four node types:

### Element Nodes

Standard UI elements like `div`, `button`, `input`:

```zig
pub const VNodeType = enum(u8) {
    element = 0,    // DOM element (div, button, etc.)
    text = 1,       // Text node
    component = 2,  // Component reference
    fragment = 3,   // Fragment (no DOM element)
};
```

### Element Tags

All standard HTML-like elements are supported:

```zig
pub const ElementTag = enum(u8) {
    div = 0,     span = 1,    section = 2,  article = 3,
    header = 4,  footer = 5,  nav = 6,      main = 7,
    aside = 8,   h1 = 9,      h2 = 10,      h3 = 11,
    h4 = 12,     h5 = 13,     h6 = 14,      p = 15,
    button = 16, a = 17,      input = 18,   img = 19,
    ul = 20,     ol = 21,     li = 22,      form = 23,
    label = 24,
};
```

## Creating VNodes

### Using Factory Functions

```zig
const vdom = @import("vdom.zig");

// Create an element node
var div = vdom.VNode.element(.div);

// Create a text node
var text = vdom.VNode.textNode("Hello, World!");

// Create a fragment (groups children without DOM element)
var fragment = vdom.VNode.fragment();
```

### Method Chaining

VNodes support fluent method chaining for configuration:

```zig
var button = vdom.VNode.element(.button)
    .withClass("primary-button")
    .withStyle(style_id)
    .withOnClick(callback_id)
    .withText("Click Me");
```

## VNode Properties

Properties control appearance and behavior:

```zig
pub const VNodeProps = struct {
    // Styling
    class: [MAX_VNODE_CLASS_LEN]u8 = undefined,
    class_len: u8 = 0,
    style_id: u32 = 0,  // Reference to CSS style

    // Event handlers (callback IDs)
    on_click: u32 = 0,
    on_input: u32 = 0,
    on_change: u32 = 0,

    // Input-specific
    input_type: u8 = 0,
    placeholder: [64]u8 = undefined,
    placeholder_len: u8 = 0,
    disabled: bool = false,

    // Link-specific
    href: [128]u8 = undefined,
    href_len: u8 = 0,

    // Image-specific
    src: [128]u8 = undefined,
    src_len: u8 = 0,
    alt: [64]u8 = undefined,
    alt_len: u8 = 0,
};
```

### Setting Properties

```zig
var props = vdom.VNodeProps{};

// Set class name
props.setClass("container");

// Set click handler
props.on_click = 42;  // Callback ID

// Set placeholder for input
props.setPlaceholder("Enter text...");
```

## Virtual DOM Tree

Nodes are organized into a tree structure:

```zig
pub const VTree = struct {
    nodes: [MAX_VNODES]VNode = undefined,
    count: u32 = 0,
    root_id: u32 = 0,
    next_id: u32 = 1,

    pub fn create(self: *VTree, node: VNode) u32;
    pub fn get(self: *VTree, id: u32) ?*VNode;
    pub fn addChild(self: *VTree, parent_id: u32, child_id: u32) bool;
    pub fn setRoot(self: *VTree, id: u32) void;
};
```

### Building a Tree

```zig
var tree = vdom.VTree.init();

// Create nodes
const container_id = tree.create(vdom.VNode.element(.div));
const title_id = tree.create(vdom.VNode.element(.h1));
const text_id = tree.create(vdom.VNode.textNode("Welcome!"));

// Build hierarchy
_ = tree.addChild(title_id, text_id);
_ = tree.addChild(container_id, title_id);

// Set root
tree.setRoot(container_id);
```

## Keyed Reconciliation

Keys enable efficient list updates. Without keys, adding an item at the start of a list would cause all items to re-render:

```zig
// Without keys: Insert at start → update all items
// [A, B, C] → [X, A, B, C]  // Updates: 4 (all items shift)

// With keys: Insert at start → only insert new item
// [A:1, B:2, C:3] → [X:4, A:1, B:2, C:3]  // Updates: 1 (only X)
```

### Using Keys

```zig
for (todos) |todo, i| {
    var item = vdom.VNode.element(.li);

    // Set unique key for reconciliation
    var key_buf: [32]u8 = undefined;
    const key = std.fmt.bufPrint(&key_buf, "todo-{d}", .{todo.id}) catch "todo";
    item.setKey(key);

    // Add to list
    _ = tree.addChild(list_id, tree.create(item));
}
```

## Diff Algorithm

The diff algorithm compares two trees and produces minimal patches:

```zig
pub const Differ = struct {
    result: DiffResult = .{},
    next_dom_id: u32 = 1,

    /// Diff two virtual trees and produce patches
    pub fn diff(
        self: *Differ,
        old_tree: ?*const VTree,
        new_tree: *const VTree
    ) *const DiffResult;
};
```

### Patch Types

```zig
pub const PatchType = enum(u8) {
    none = 0,
    create = 1,       // Create new DOM node
    remove = 2,       // Remove DOM node
    replace = 3,      // Replace node with different type
    update_props = 4, // Update properties
    update_text = 5,  // Update text content
    reorder = 6,      // Reorder children
    insert_child = 7, // Insert child at index
    remove_child = 8, // Remove child at index
};
```

### Example: Text Update

```zig
// Old tree: <p>Hello</p>
// New tree: <p>World</p>

const patches = differ.diff(&old_tree, &new_tree);
// Result: [Patch{ .patch_type = .update_text, .text = "World" }]
```

## Reconciler

The `Reconciler` manages the rendering lifecycle:

```zig
pub const Reconciler = struct {
    current_tree: VTree,
    next_tree: VTree,
    differ: Differ,
    is_first_render: bool,

    /// Get the next tree for building new UI
    pub fn getNextTree(self: *Reconciler) *VTree;

    /// Commit the next tree and generate patches
    pub fn commit(self: *Reconciler) *const DiffResult;

    /// Get current tree (for inspection)
    pub fn getCurrentTree(self: *Reconciler) *const VTree;
};
```

### Render Cycle

```zig
// 1. Get tree for building
var tree = reconciler.getNextTree();

// 2. Build virtual DOM from state
buildUI(tree, state);

// 3. Commit and get patches
const patches = reconciler.commit();

// 4. Platform applies patches
for (patches.patches[0..patches.count]) |patch| {
    applyPatch(patch);
}
```

## Performance Characteristics

| Operation | Complexity | Notes |
|-----------|------------|-------|
| Create VNode | O(1) | Fixed-size allocation |
| Add Child | O(1) | Array append |
| Tree Diff | O(n) | Linear in tree size |
| Keyed Lookup | O(k) | Linear in siblings with keys |

### Memory Limits

```zig
pub const MAX_VNODE_CHILDREN = 16;   // Children per node
pub const MAX_VNODE_KEY_LEN = 32;    // Key string length
pub const MAX_VNODE_TEXT_LEN = 128;  // Text content length
pub const MAX_VNODE_CLASS_LEN = 64;  // Class name length
pub const MAX_VNODES = 256;          // Nodes per tree
pub const MAX_PATCHES = 128;         // Patches per diff
```

## Best Practices

### 1. Use Keys for Lists

```zig
// Good: Unique keys for list items
for (items) |item| {
    var node = VNode.element(.li);
    node.setKey(item.id);  // Use unique ID
    // ...
}

// Bad: No keys → inefficient updates
for (items) |item| {
    var node = VNode.element(.li);
    // No key → full re-render on change
    // ...
}
```

### 2. Minimize Tree Depth

```zig
// Good: Flat structure
<div>
    <button/>
    <button/>
    <button/>
</div>

// Avoid: Deep nesting
<div>
    <div>
        <div>
            <button/>
        </div>
    </div>
</div>
```

### 3. Reuse Node Configurations

```zig
// Good: Shared configuration
const button_props = VNodeProps{ .class = "btn" };

for (buttons) |_| {
    var btn = VNode.element(.button);
    btn.props = button_props;
    // ...
}
```

## Next Steps

- [State Management](../state-management) - Learn how state triggers re-renders
- [Components](../components) - Build reusable UI components
- [Events](../events) - Handle user interactions
