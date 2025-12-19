//! ZigDom Layout Engine
//!
//! Flexbox/Grid layout algorithm implemented in Zig.
//! Computes element positions and sizes for JavaScript to apply.
//!
//! Philosophy: Zig computes layout, JavaScript applies to DOM.

const std = @import("std");
const css = @import("css.zig");

// === Layout Types ===

pub const LayoutResult = extern struct {
    x: f32 = 0,
    y: f32 = 0,
    width: f32 = 0,
    height: f32 = 0,
};

pub const Size = extern struct {
    width: f32 = 0,
    height: f32 = 0,
};

pub const BoxModel = extern struct {
    // Content size
    content_width: f32 = 0,
    content_height: f32 = 0,

    // Padding
    padding_top: f32 = 0,
    padding_right: f32 = 0,
    padding_bottom: f32 = 0,
    padding_left: f32 = 0,

    // Margin
    margin_top: f32 = 0,
    margin_right: f32 = 0,
    margin_bottom: f32 = 0,
    margin_left: f32 = 0,

    // Border
    border_top: f32 = 0,
    border_right: f32 = 0,
    border_bottom: f32 = 0,
    border_left: f32 = 0,

    pub fn totalWidth(self: BoxModel) f32 {
        return self.content_width +
            self.padding_left + self.padding_right +
            self.border_left + self.border_right +
            self.margin_left + self.margin_right;
    }

    pub fn totalHeight(self: BoxModel) f32 {
        return self.content_height +
            self.padding_top + self.padding_bottom +
            self.border_top + self.border_bottom +
            self.margin_top + self.margin_bottom;
    }

    pub fn innerWidth(self: BoxModel) f32 {
        return self.content_width + self.padding_left + self.padding_right;
    }

    pub fn innerHeight(self: BoxModel) f32 {
        return self.content_height + self.padding_top + self.padding_bottom;
    }
};

// === Layout Node ===

pub const MAX_CHILDREN = 32;

pub const LayoutNode = extern struct {
    // Identity
    id: u32 = 0,
    parent_id: u32 = 0xFFFFFFFF, // 0xFFFFFFFF = no parent

    // Style (subset for layout)
    display: css.Display = .block,
    flex_direction: css.FlexDirection = .row,
    flex_wrap: css.FlexWrap = .nowrap,
    justify_content: css.JustifyContent = .start,
    align_items: css.AlignItems = .stretch,

    // Flex item properties
    flex_grow: f32 = 0,
    flex_shrink: f32 = 1,
    flex_basis: f32 = 0, // 0 = auto

    // Dimensions
    width: f32 = 0, // 0 = auto
    height: f32 = 0, // 0 = auto
    min_width: f32 = 0,
    min_height: f32 = 0,
    max_width: f32 = 0, // 0 = none
    max_height: f32 = 0, // 0 = none

    // Spacing (in pixels)
    gap: f32 = 0,
    padding_top: f32 = 0,
    padding_right: f32 = 0,
    padding_bottom: f32 = 0,
    padding_left: f32 = 0,
    margin_top: f32 = 0,
    margin_right: f32 = 0,
    margin_bottom: f32 = 0,
    margin_left: f32 = 0,

    // Children (stored as indices)
    children: [MAX_CHILDREN]u32 = [_]u32{0xFFFFFFFF} ** MAX_CHILDREN,
    child_count: u32 = 0,

    // Computed layout result
    result: LayoutResult = .{},
    computed: bool = false,

    // Content size (for text/intrinsic content)
    intrinsic_width: f32 = 0,
    intrinsic_height: f32 = 0,

    pub fn addChild(self: *LayoutNode, child_id: u32) bool {
        if (self.child_count >= MAX_CHILDREN) return false;
        self.children[self.child_count] = child_id;
        self.child_count += 1;
        return true;
    }

    pub fn isFlexContainer(self: *const LayoutNode) bool {
        return self.display == .flex or self.display == .inline_flex;
    }

    pub fn isRow(self: *const LayoutNode) bool {
        return self.flex_direction == .row or self.flex_direction == .row_reverse;
    }

    pub fn isReverse(self: *const LayoutNode) bool {
        return self.flex_direction == .row_reverse or self.flex_direction == .col_reverse;
    }

    pub fn getMainSize(self: *const LayoutNode) f32 {
        return if (self.isRow()) self.result.width else self.result.height;
    }

    pub fn getCrossSize(self: *const LayoutNode) f32 {
        return if (self.isRow()) self.result.height else self.result.width;
    }

    pub fn getPaddingMain(self: *const LayoutNode) f32 {
        return if (self.isRow())
            self.padding_left + self.padding_right
        else
            self.padding_top + self.padding_bottom;
    }

    pub fn getPaddingCross(self: *const LayoutNode) f32 {
        return if (self.isRow())
            self.padding_top + self.padding_bottom
        else
            self.padding_left + self.padding_right;
    }
};

// === Layout Engine ===

pub const MAX_NODES = 256;

pub const LayoutEngine = struct {
    nodes: [MAX_NODES]LayoutNode = [_]LayoutNode{.{}} ** MAX_NODES,
    node_count: u32 = 0,
    root_id: u32 = 0xFFFFFFFF,

    pub fn init(self: *LayoutEngine) void {
        self.node_count = 0;
        self.root_id = 0xFFFFFFFF;
        for (&self.nodes) |*node| {
            node.* = .{};
        }
    }

    pub fn createNode(self: *LayoutEngine) ?u32 {
        if (self.node_count >= MAX_NODES) return null;
        const id = self.node_count;
        self.nodes[id] = .{ .id = id };
        self.node_count += 1;
        return id;
    }

    pub fn getNode(self: *LayoutEngine, id: u32) ?*LayoutNode {
        if (id >= self.node_count) return null;
        return &self.nodes[id];
    }

    pub fn setRoot(self: *LayoutEngine, id: u32) void {
        self.root_id = id;
    }

    pub fn addChild(self: *LayoutEngine, parent_id: u32, child_id: u32) bool {
        if (self.getNode(parent_id)) |parent| {
            if (self.getNode(child_id)) |child| {
                child.parent_id = parent_id;
                return parent.addChild(child_id);
            }
        }
        return false;
    }

    /// Compute layout for entire tree
    pub fn compute(self: *LayoutEngine, container_width: f32, container_height: f32) void {
        if (self.root_id == 0xFFFFFFFF) return;

        // Reset computed flags
        for (self.nodes[0..self.node_count]) |*node| {
            node.computed = false;
        }

        // Layout root with container constraints
        self.layoutNode(self.root_id, container_width, container_height);
    }

    fn layoutNode(self: *LayoutEngine, node_id: u32, available_width: f32, available_height: f32) void {
        const node = self.getNode(node_id) orelse return;
        if (node.computed) return;

        // Determine node dimensions
        var width = node.width;
        var height = node.height;

        // Auto width/height
        if (width == 0) width = available_width - node.margin_left - node.margin_right;
        if (height == 0) height = available_height - node.margin_top - node.margin_bottom;

        // Apply min/max constraints
        if (node.min_width > 0 and width < node.min_width) width = node.min_width;
        if (node.max_width > 0 and width > node.max_width) width = node.max_width;
        if (node.min_height > 0 and height < node.min_height) height = node.min_height;
        if (node.max_height > 0 and height > node.max_height) height = node.max_height;

        node.result.width = width;
        node.result.height = height;

        // Layout children based on display type
        if (node.isFlexContainer()) {
            self.layoutFlexContainer(node_id);
        } else {
            self.layoutBlockChildren(node_id);
        }

        node.computed = true;
    }

    fn layoutFlexContainer(self: *LayoutEngine, container_id: u32) void {
        const container = self.getNode(container_id) orelse return;
        if (container.child_count == 0) return;

        const is_row = container.isRow();
        const is_reverse = container.isReverse();

        // Available space for children
        const padding_main = container.getPaddingMain();
        const padding_cross = container.getPaddingCross();
        const main_size = if (is_row) container.result.width else container.result.height;
        const cross_size = if (is_row) container.result.height else container.result.width;
        const available_main = main_size - padding_main;
        const available_cross = cross_size - padding_cross;

        // Calculate total gap
        const total_gap = container.gap * @as(f32, @floatFromInt(container.child_count - 1));

        // First pass: calculate intrinsic sizes and flex factors
        var total_flex_grow: f32 = 0;
        var total_fixed_main: f32 = 0;
        var max_cross: f32 = 0;

        for (container.children[0..container.child_count]) |child_id| {
            if (child_id == 0xFFFFFFFF) continue;
            const child = self.getNode(child_id) orelse continue;

            // Get child's base size
            var child_main: f32 = 0;
            var child_cross: f32 = 0;

            if (child.flex_basis > 0) {
                child_main = child.flex_basis;
            } else if (is_row and child.width > 0) {
                child_main = child.width;
            } else if (!is_row and child.height > 0) {
                child_main = child.height;
            } else {
                // Use intrinsic size or minimum
                child_main = if (is_row) child.intrinsic_width else child.intrinsic_height;
                if (child_main == 0) child_main = 50; // Default minimum
            }

            if (is_row and child.height > 0) {
                child_cross = child.height;
            } else if (!is_row and child.width > 0) {
                child_cross = child.width;
            } else {
                child_cross = if (is_row) child.intrinsic_height else child.intrinsic_width;
                if (child_cross == 0) child_cross = available_cross;
            }

            // Store temporary sizes
            if (is_row) {
                child.result.width = child_main;
                child.result.height = child_cross;
            } else {
                child.result.width = child_cross;
                child.result.height = child_main;
            }

            total_flex_grow += child.flex_grow;
            if (child.flex_grow == 0) {
                total_fixed_main += child_main;
            }
            if (child_cross > max_cross) max_cross = child_cross;
        }

        // Calculate remaining space for flex items
        var remaining_main = available_main - total_fixed_main - total_gap;
        if (remaining_main < 0) remaining_main = 0;

        // Second pass: distribute flex space and position children
        var current_pos: f32 = if (is_row) container.padding_left else container.padding_top;

        // Handle justify-content
        var spacing: f32 = 0;
        var start_offset: f32 = 0;

        if (total_flex_grow == 0) {
            // No flex-grow, use justify-content
            var total_children_main: f32 = total_fixed_main + total_gap;
            for (container.children[0..container.child_count]) |child_id| {
                if (child_id == 0xFFFFFFFF) continue;
                const child = self.getNode(child_id) orelse continue;
                if (child.flex_grow > 0) {
                    total_children_main += 50; // Minimum for flex items
                }
            }

            const free_space = available_main - total_children_main;
            if (free_space > 0) {
                switch (container.justify_content) {
                    .start => {},
                    .end => start_offset = free_space,
                    .center => start_offset = free_space / 2,
                    .between => {
                        if (container.child_count > 1) {
                            spacing = free_space / @as(f32, @floatFromInt(container.child_count - 1));
                        }
                    },
                    .around => {
                        spacing = free_space / @as(f32, @floatFromInt(container.child_count));
                        start_offset = spacing / 2;
                    },
                    .evenly => {
                        spacing = free_space / @as(f32, @floatFromInt(container.child_count + 1));
                        start_offset = spacing;
                    },
                    .stretch => {},
                }
            }
            current_pos += start_offset;
        }

        // Position children
        const child_indices = container.children[0..container.child_count];
        var i: usize = 0;
        while (i < container.child_count) : (i += 1) {
            const idx = if (is_reverse) container.child_count - 1 - @as(u32, @intCast(i)) else @as(u32, @intCast(i));
            const child_id = child_indices[idx];
            if (child_id == 0xFFFFFFFF) continue;

            const child = self.getNode(child_id) orelse continue;

            // Calculate flex-grow distribution
            var child_main = if (is_row) child.result.width else child.result.height;
            if (child.flex_grow > 0 and total_flex_grow > 0) {
                child_main += (remaining_main * child.flex_grow) / total_flex_grow;
            }

            // Set final dimensions
            if (is_row) {
                child.result.width = child_main;
                child.result.x = current_pos;
            } else {
                child.result.height = child_main;
                child.result.y = current_pos;
            }

            // Handle cross-axis alignment
            var child_cross = if (is_row) child.result.height else child.result.width;
            const cross_start = if (is_row) container.padding_top else container.padding_left;
            const usable_cross = available_cross;

            var cross_pos: f32 = cross_start;
            switch (container.align_items) {
                .start => cross_pos = cross_start,
                .end => cross_pos = cross_start + usable_cross - child_cross,
                .center => cross_pos = cross_start + (usable_cross - child_cross) / 2,
                .stretch => {
                    child_cross = usable_cross;
                    cross_pos = cross_start;
                },
                .baseline => cross_pos = cross_start, // Simplified
            }

            if (is_row) {
                child.result.y = cross_pos;
                child.result.height = child_cross;
            } else {
                child.result.x = cross_pos;
                child.result.width = child_cross;
            }

            // Recursively layout child's children
            self.layoutNode(child_id, child.result.width, child.result.height);

            // Move to next position
            current_pos += child_main + container.gap + spacing;
        }
    }

    fn layoutBlockChildren(self: *LayoutEngine, container_id: u32) void {
        const container = self.getNode(container_id) orelse return;
        if (container.child_count == 0) return;

        var current_y = container.padding_top;
        const available_width = container.result.width - container.padding_left - container.padding_right;

        for (container.children[0..container.child_count]) |child_id| {
            if (child_id == 0xFFFFFFFF) continue;
            const child = self.getNode(child_id) orelse continue;

            // Block children stack vertically
            child.result.x = container.padding_left + child.margin_left;
            child.result.y = current_y + child.margin_top;

            // Width: fill available or use specified
            var child_width = child.width;
            if (child_width == 0) {
                child_width = available_width - child.margin_left - child.margin_right;
            }
            child.result.width = child_width;

            // Height: use specified or intrinsic
            var child_height = child.height;
            if (child_height == 0) {
                child_height = child.intrinsic_height;
                if (child_height == 0) child_height = 50; // Default
            }
            child.result.height = child_height;

            // Recursively layout child
            self.layoutNode(child_id, child.result.width, child.result.height);

            current_y += child.margin_top + child.result.height + child.margin_bottom;
        }
    }

    /// Get layout results as a flat array for WASM transfer
    pub fn getResults(self: *LayoutEngine) []const LayoutResult {
        // Build results array
        var results: [MAX_NODES]LayoutResult = undefined;
        for (self.nodes[0..self.node_count], 0..) |node, i| {
            results[i] = node.result;
        }
        return results[0..self.node_count];
    }
};

// === Global State for WASM ===

var global_engine: LayoutEngine = .{};

// === WASM Exports ===

pub fn init() void {
    global_engine.init();
}

pub fn createNode() u32 {
    return global_engine.createNode() orelse 0xFFFFFFFF;
}

pub fn getNode(id: u32) ?*LayoutNode {
    return global_engine.getNode(id);
}

pub fn setRoot(id: u32) void {
    global_engine.setRoot(id);
}

pub fn addChild(parent_id: u32, child_id: u32) bool {
    return global_engine.addChild(parent_id, child_id);
}

pub fn compute(width: f32, height: f32) void {
    global_engine.compute(width, height);
}

pub fn getNodeCount() u32 {
    return global_engine.node_count;
}

pub fn getResultsPtr() ?*const LayoutResult {
    if (global_engine.node_count == 0) return null;
    return &global_engine.nodes[0].result;
}

pub fn getResultSize() usize {
    return @sizeOf(LayoutResult);
}
