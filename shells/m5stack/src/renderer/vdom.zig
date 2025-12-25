//! Virtual DOM Node Definitions
//!
//! Defines the structure of virtual DOM nodes for M5Stack.
//! Optimized for embedded systems with fixed-size allocations.

const std = @import("std");

/// Node type enumeration
pub const VNodeType = enum(u8) {
    // Primitives
    rect,
    circle,
    line,
    text,
    image,

    // Components
    button,
    label,
    panel,
    progress,
    list,
    list_item,

    // Layout
    container,
    scroll_view,
    stack_h,  // Horizontal stack
    stack_v,  // Vertical stack

    // Special
    root,
    fragment,
};

/// Node properties
pub const VNodeProps = struct {
    // Position
    x: i32 = 0,
    y: i32 = 0,

    // Size
    width: u16 = 0,
    height: u16 = 0,

    // Appearance
    color: u16 = 0xFFFF,
    background: u16 = 0x0000,
    border_color: u16 = 0x0000,
    border_width: u8 = 0,
    corner_radius: u8 = 0,
    opacity: u8 = 255,

    // Text
    text: []const u8 = "",
    font_size: u8 = 1,
    text_align: u8 = 0, // 0=left, 1=center, 2=right

    // Shape specific
    radius: u16 = 0,
    line_width: u8 = 1,

    // State
    visible: bool = true,
    enabled: bool = true,
    focused: bool = false,
    pressed: bool = false,

    // Flex layout
    flex: u8 = 0,
    padding: u8 = 0,
    margin: u8 = 0,
    gap: u8 = 0,

    // Identity
    key: u32 = 0,
    tag: u32 = 0,

    /// Compare two props for equality
    pub fn eql(self: VNodeProps, other: VNodeProps) bool {
        return self.x == other.x and
            self.y == other.y and
            self.width == other.width and
            self.height == other.height and
            self.color == other.color and
            self.background == other.background and
            self.visible == other.visible and
            self.enabled == other.enabled and
            std.mem.eql(u8, self.text, other.text);
    }
};

/// Virtual DOM node
pub const VNode = struct {
    /// Node type
    node_type: VNodeType,

    /// Node properties
    props: VNodeProps,

    /// Parent node (null for root)
    parent: ?*VNode = null,

    /// First child
    first_child: ?*VNode = null,

    /// Last child (for efficient appending)
    last_child: ?*VNode = null,

    /// Next sibling
    next_sibling: ?*VNode = null,

    /// Previous sibling
    prev_sibling: ?*VNode = null,

    /// Depth in tree
    depth: u8 = 0,

    /// Node ID (for diffing)
    id: u32 = 0,

    /// Dirty flag
    dirty: bool = true,

    /// User data
    user_data: ?*anyopaque = null,

    /// Add child node
    pub fn appendChild(self: *VNode, child: *VNode) void {
        child.parent = self;
        child.depth = self.depth + 1;
        child.prev_sibling = self.last_child;

        if (self.last_child) |last| {
            last.next_sibling = child;
        } else {
            self.first_child = child;
        }
        self.last_child = child;
    }

    /// Remove child node
    pub fn removeChild(self: *VNode, child: *VNode) void {
        if (child.parent != self) return;

        // Update siblings
        if (child.prev_sibling) |prev| {
            prev.next_sibling = child.next_sibling;
        } else {
            self.first_child = child.next_sibling;
        }

        if (child.next_sibling) |next| {
            next.prev_sibling = child.prev_sibling;
        } else {
            self.last_child = child.prev_sibling;
        }

        child.parent = null;
        child.prev_sibling = null;
        child.next_sibling = null;
    }

    /// Get child count
    pub fn childCount(self: *const VNode) usize {
        var count: usize = 0;
        var child = self.first_child;
        while (child) |c| {
            count += 1;
            child = c.next_sibling;
        }
        return count;
    }

    /// Get child at index
    pub fn childAt(self: *VNode, index: usize) ?*VNode {
        var i: usize = 0;
        var child = self.first_child;
        while (child) |c| {
            if (i == index) return c;
            i += 1;
            child = c.next_sibling;
        }
        return null;
    }

    /// Iterate over children
    pub fn children(self: *VNode) ChildIterator {
        return .{ .current = self.first_child };
    }

    pub const ChildIterator = struct {
        current: ?*VNode,

        pub fn next(self: *ChildIterator) ?*VNode {
            const node = self.current orelse return null;
            self.current = node.next_sibling;
            return node;
        }
    };

    /// Mark node and ancestors as dirty
    pub fn markDirty(self: *VNode) void {
        self.dirty = true;
        if (self.parent) |p| {
            p.markDirty();
        }
    }

    /// Get bounds as rect
    pub fn getBounds(self: *const VNode) struct { x: i32, y: i32, width: u16, height: u16 } {
        return .{
            .x = self.props.x,
            .y = self.props.y,
            .width = self.props.width,
            .height = self.props.height,
        };
    }

    /// Check if point is inside node
    pub fn containsPoint(self: *const VNode, px: i32, py: i32) bool {
        return px >= self.props.x and
            px < self.props.x + @as(i32, self.props.width) and
            py >= self.props.y and
            py < self.props.y + @as(i32, self.props.height);
    }
};

/// Virtual DOM tree container
pub const VDom = struct {
    /// Node pool
    nodes: []VNode,

    /// Number of nodes in use
    node_count: usize,

    /// Root node
    root: ?*VNode,

    /// Next node ID
    next_id: u32,

    /// Create a new VDom
    pub fn create(allocator: std.mem.Allocator, max_nodes: usize) !*VDom {
        const vdom = try allocator.create(VDom);
        vdom.nodes = try allocator.alloc(VNode, max_nodes);
        vdom.node_count = 0;
        vdom.next_id = 1;

        // Create root node
        vdom.root = vdom.allocNode(.root, .{});

        return vdom;
    }

    /// Destroy VDom
    pub fn destroy(self: *VDom, allocator: std.mem.Allocator) void {
        allocator.free(self.nodes);
        allocator.destroy(self);
    }

    /// Clear all nodes except root
    pub fn clear(self: *VDom) void {
        // Reset all nodes
        for (self.nodes) |*node| {
            node.* = .{
                .node_type = .fragment,
                .props = .{},
            };
        }
        self.node_count = 0;

        // Recreate root
        self.root = self.allocNode(.root, .{});
    }

    /// Allocate a new node
    fn allocNode(self: *VDom, node_type: VNodeType, props: VNodeProps) ?*VNode {
        if (self.node_count >= self.nodes.len) return null;

        const node = &self.nodes[self.node_count];
        node.* = .{
            .node_type = node_type,
            .props = props,
            .id = self.next_id,
        };
        self.node_count += 1;
        self.next_id += 1;

        return node;
    }

    /// Create a node and add to root
    pub fn createNode(self: *VDom, node_type: VNodeType, props: VNodeProps) !*VNode {
        const node = self.allocNode(node_type, props) orelse return error.OutOfNodes;
        if (self.root) |root| {
            root.appendChild(node);
        }
        return node;
    }

    /// Create a node as child of parent
    pub fn createChildNode(self: *VDom, parent: *VNode, node_type: VNodeType, props: VNodeProps) !*VNode {
        const node = self.allocNode(node_type, props) orelse return error.OutOfNodes;
        parent.appendChild(node);
        return node;
    }

    /// Get node by ID
    pub fn getNodeById(self: *VDom, id: u32) ?*VNode {
        for (self.nodes[0..self.node_count]) |*node| {
            if (node.id == id) return node;
        }
        return null;
    }

    /// Get node by key
    pub fn getNodeByKey(self: *VDom, key: u32) ?*VNode {
        for (self.nodes[0..self.node_count]) |*node| {
            if (node.props.key == key) return node;
        }
        return null;
    }

    /// Find node at point
    pub fn hitTest(self: *VDom, x: i32, y: i32) ?*VNode {
        // Traverse in reverse order (top to bottom visually)
        var i = self.node_count;
        while (i > 0) {
            i -= 1;
            const node = &self.nodes[i];
            if (node.props.visible and node.containsPoint(x, y)) {
                return node;
            }
        }
        return null;
    }
};

// Tests
test "VNode creation" {
    const node = VNode{
        .node_type = .rect,
        .props = .{
            .x = 10,
            .y = 20,
            .width = 100,
            .height = 50,
            .color = 0xF800,
        },
    };

    try std.testing.expectEqual(VNodeType.rect, node.node_type);
    try std.testing.expectEqual(@as(i32, 10), node.props.x);
    try std.testing.expectEqual(@as(u16, 100), node.props.width);
}

test "VNode containsPoint" {
    const node = VNode{
        .node_type = .rect,
        .props = .{
            .x = 10,
            .y = 10,
            .width = 100,
            .height = 50,
        },
    };

    try std.testing.expect(node.containsPoint(10, 10));
    try std.testing.expect(node.containsPoint(50, 30));
    try std.testing.expect(node.containsPoint(109, 59));
    try std.testing.expect(!node.containsPoint(110, 60));
}

test "VNodeProps equality" {
    const props1 = VNodeProps{ .x = 10, .y = 20, .color = 0xFFFF };
    const props2 = VNodeProps{ .x = 10, .y = 20, .color = 0xFFFF };
    const props3 = VNodeProps{ .x = 10, .y = 30, .color = 0xFFFF };

    try std.testing.expect(props1.eql(props2));
    try std.testing.expect(!props1.eql(props3));
}
