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

    // === Performance Optimization Fields ===
    // Style hash for cache invalidation (dirty tracking)
    style_hash: u32 = 0,
    // Cached direction flags (avoid repeated enum checks)
    cached_is_row: bool = true,
    cached_is_reverse: bool = false,
    cached_is_flex: bool = false,
    // Dirty flag for incremental updates
    dirty: bool = true,

    pub fn addChild(self: *LayoutNode, child_id: u32) bool {
        if (self.child_count >= MAX_CHILDREN) return false;
        self.children[self.child_count] = child_id;
        self.child_count += 1;
        self.dirty = true;
        return true;
    }

    /// Compute style hash for cache invalidation (FNV-1a)
    pub fn computeStyleHash(self: *const LayoutNode) u32 {
        var hash: u32 = 2166136261; // FNV offset basis
        const prime: u32 = 16777619;

        // Hash style properties that affect layout
        hash ^= @intFromEnum(self.display);
        hash *%= prime;
        hash ^= @intFromEnum(self.flex_direction);
        hash *%= prime;
        hash ^= @intFromEnum(self.flex_wrap);
        hash *%= prime;
        hash ^= @intFromEnum(self.justify_content);
        hash *%= prime;
        hash ^= @intFromEnum(self.align_items);
        hash *%= prime;

        // Hash float values as bits
        hash ^= @as(u32, @bitCast(self.width));
        hash *%= prime;
        hash ^= @as(u32, @bitCast(self.height));
        hash *%= prime;
        hash ^= @as(u32, @bitCast(self.flex_grow));
        hash *%= prime;
        hash ^= @as(u32, @bitCast(self.gap));
        hash *%= prime;

        return hash;
    }

    /// Update cached flags after style changes (call after modifying style properties)
    pub fn updateCachedFlags(self: *LayoutNode) void {
        self.cached_is_flex = self.display == .flex or self.display == .inline_flex;
        self.cached_is_row = self.flex_direction == .row or self.flex_direction == .row_reverse;
        self.cached_is_reverse = self.flex_direction == .row_reverse or self.flex_direction == .col_reverse;

        const new_hash = self.computeStyleHash();
        if (new_hash != self.style_hash) {
            self.style_hash = new_hash;
            self.dirty = true;
            self.computed = false;
        }
    }

    /// Mark node as dirty (requires re-layout)
    pub fn markDirty(self: *LayoutNode) void {
        self.dirty = true;
        self.computed = false;
    }

    pub fn isFlexContainer(self: *const LayoutNode) bool {
        return self.cached_is_flex;
    }

    pub fn isRow(self: *const LayoutNode) bool {
        return self.cached_is_row;
    }

    pub fn isReverse(self: *const LayoutNode) bool {
        return self.cached_is_reverse;
    }

    /// Legacy methods for compatibility (use cached versions when possible)
    pub fn isFlexContainerCompute(self: *const LayoutNode) bool {
        return self.display == .flex or self.display == .inline_flex;
    }

    pub fn isRowCompute(self: *const LayoutNode) bool {
        return self.flex_direction == .row or self.flex_direction == .row_reverse;
    }

    pub fn isReverseCompute(self: *const LayoutNode) bool {
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
    // Performance: track if any node is dirty
    needs_layout: bool = true,
    // Cache last container size for incremental updates
    last_container_width: f32 = 0,
    last_container_height: f32 = 0,

    pub fn init(self: *LayoutEngine) void {
        self.node_count = 0;
        self.root_id = 0xFFFFFFFF;
        self.needs_layout = true;
        self.last_container_width = 0;
        self.last_container_height = 0;
        for (&self.nodes) |*node| {
            node.* = .{};
        }
    }

    pub fn createNode(self: *LayoutEngine) ?u32 {
        if (self.node_count >= MAX_NODES) return null;
        const id = self.node_count;
        self.nodes[id] = .{ .id = id };
        self.nodes[id].updateCachedFlags(); // Initialize cached flags
        self.node_count += 1;
        self.needs_layout = true;
        return id;
    }

    pub fn getNode(self: *LayoutEngine, id: u32) ?*LayoutNode {
        if (id >= self.node_count) return null;
        return &self.nodes[id];
    }

    pub fn setRoot(self: *LayoutEngine, id: u32) void {
        if (self.root_id != id) {
            self.root_id = id;
            self.needs_layout = true;
        }
    }

    pub fn addChild(self: *LayoutEngine, parent_id: u32, child_id: u32) bool {
        if (self.getNode(parent_id)) |parent| {
            if (self.getNode(child_id)) |child| {
                child.parent_id = parent_id;
                const result = parent.addChild(child_id);
                if (result) self.needs_layout = true;
                return result;
            }
        }
        return false;
    }

    /// Mark specific node as dirty (triggers re-layout)
    pub fn markNodeDirty(self: *LayoutEngine, id: u32) void {
        if (self.getNode(id)) |node| {
            node.markDirty();
            self.needs_layout = true;
        }
    }

    /// Check if layout needs recomputation
    pub fn needsLayout(self: *const LayoutEngine) bool {
        return self.needs_layout;
    }

    /// Compute layout for entire tree
    pub fn compute(self: *LayoutEngine, container_width: f32, container_height: f32) void {
        if (self.root_id == 0xFFFFFFFF) return;

        // Check if we can skip layout (no dirty nodes and same container size)
        const container_changed = container_width != self.last_container_width or
            container_height != self.last_container_height;

        if (!self.needs_layout and !container_changed) {
            return; // Skip layout - nothing changed
        }

        // Update container cache
        self.last_container_width = container_width;
        self.last_container_height = container_height;

        // Reset computed flags
        for (self.nodes[0..self.node_count]) |*node| {
            node.computed = false;
        }

        // Layout root with container constraints
        self.layoutNode(self.root_id, container_width, container_height);

        // Mark layout as clean
        self.needs_layout = false;
        for (self.nodes[0..self.node_count]) |*node| {
            node.dirty = false;
        }
    }

    /// Force layout recomputation (ignores dirty flags)
    pub fn forceCompute(self: *LayoutEngine, container_width: f32, container_height: f32) void {
        self.needs_layout = true;
        self.compute(container_width, container_height);
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
    /// Returns a pointer to internal storage - valid until next compute() call
    pub fn getResults(self: *LayoutEngine) []const LayoutResult {
        // Return slice of results directly from nodes (zero-copy)
        // Note: This returns pointers into the node array, so results are
        // interleaved with other node data. For WASM, use getResultsPtr().
        if (self.node_count == 0) return &[_]LayoutResult{};

        // For efficiency, we return a pointer to the first result
        // and the count. The stride between results is sizeof(LayoutNode).
        // WASM should use getResultsPtr() and getResultSize() for proper access.
        return @as([*]const LayoutResult, @ptrCast(&self.nodes[0].result))[0..1];
    }

    /// Get direct pointer to results array for efficient WASM transfer
    /// Each result is at offset (i * sizeof(LayoutNode)) from this pointer
    pub fn getResultsDirect(self: *LayoutEngine) struct { ptr: *const LayoutResult, count: u32, stride: usize } {
        return .{
            .ptr = &self.nodes[0].result,
            .count = self.node_count,
            .stride = @sizeOf(LayoutNode),
        };
    }

    /// Copy results to a contiguous buffer (for WASM transfer when stride access isn't available)
    pub fn copyResultsToBuffer(self: *LayoutEngine, buffer: []LayoutResult) u32 {
        const count = @min(self.node_count, @as(u32, @intCast(buffer.len)));
        for (self.nodes[0..count], 0..) |node, i| {
            buffer[i] = node.result;
        }
        return count;
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

// ============================================================================
// Tests
// ============================================================================

test "LayoutResult default values" {
    const result = LayoutResult{};
    try std.testing.expectEqual(@as(f32, 0), result.x);
    try std.testing.expectEqual(@as(f32, 0), result.y);
    try std.testing.expectEqual(@as(f32, 0), result.width);
    try std.testing.expectEqual(@as(f32, 0), result.height);
}

test "Size default values" {
    const size = Size{};
    try std.testing.expectEqual(@as(f32, 0), size.width);
    try std.testing.expectEqual(@as(f32, 0), size.height);
}

test "BoxModel totalWidth" {
    const box = BoxModel{
        .content_width = 100,
        .padding_left = 10,
        .padding_right = 10,
        .border_left = 2,
        .border_right = 2,
        .margin_left = 5,
        .margin_right = 5,
    };
    try std.testing.expectEqual(@as(f32, 134), box.totalWidth());
}

test "BoxModel totalHeight" {
    const box = BoxModel{
        .content_height = 200,
        .padding_top = 15,
        .padding_bottom = 15,
        .border_top = 3,
        .border_bottom = 3,
        .margin_top = 10,
        .margin_bottom = 10,
    };
    try std.testing.expectEqual(@as(f32, 256), box.totalHeight());
}

test "BoxModel innerWidth" {
    const box = BoxModel{
        .content_width = 100,
        .padding_left = 10,
        .padding_right = 10,
    };
    try std.testing.expectEqual(@as(f32, 120), box.innerWidth());
}

test "BoxModel innerHeight" {
    const box = BoxModel{
        .content_height = 200,
        .padding_top = 15,
        .padding_bottom = 15,
    };
    try std.testing.expectEqual(@as(f32, 230), box.innerHeight());
}

test "LayoutNode addChild" {
    var node = LayoutNode{};
    try std.testing.expect(node.addChild(1));
    try std.testing.expect(node.addChild(2));
    try std.testing.expectEqual(@as(u32, 2), node.child_count);
    try std.testing.expectEqual(@as(u32, 1), node.children[0]);
    try std.testing.expectEqual(@as(u32, 2), node.children[1]);
}

test "LayoutNode addChild max children" {
    var node = LayoutNode{};
    // Fill up to max
    var i: u32 = 0;
    while (i < MAX_CHILDREN) : (i += 1) {
        try std.testing.expect(node.addChild(i));
    }
    // Should fail on max+1
    try std.testing.expect(!node.addChild(999));
    try std.testing.expectEqual(@as(u32, MAX_CHILDREN), node.child_count);
}

test "LayoutNode isFlexContainer" {
    var node = LayoutNode{};

    node.display = .block;
    try std.testing.expect(!node.isFlexContainer());

    node.display = .flex;
    try std.testing.expect(node.isFlexContainer());

    node.display = .inline_flex;
    try std.testing.expect(node.isFlexContainer());
}

test "LayoutNode isRow" {
    var node = LayoutNode{};

    node.flex_direction = .row;
    try std.testing.expect(node.isRow());

    node.flex_direction = .row_reverse;
    try std.testing.expect(node.isRow());

    node.flex_direction = .col;
    try std.testing.expect(!node.isRow());

    node.flex_direction = .col_reverse;
    try std.testing.expect(!node.isRow());
}

test "LayoutNode isReverse" {
    var node = LayoutNode{};

    node.flex_direction = .row;
    try std.testing.expect(!node.isReverse());

    node.flex_direction = .row_reverse;
    try std.testing.expect(node.isReverse());

    node.flex_direction = .col;
    try std.testing.expect(!node.isReverse());

    node.flex_direction = .col_reverse;
    try std.testing.expect(node.isReverse());
}

test "LayoutNode getMainSize and getCrossSize row" {
    var node = LayoutNode{};
    node.flex_direction = .row;
    node.result.width = 100;
    node.result.height = 50;

    try std.testing.expectEqual(@as(f32, 100), node.getMainSize());
    try std.testing.expectEqual(@as(f32, 50), node.getCrossSize());
}

test "LayoutNode getMainSize and getCrossSize column" {
    var node = LayoutNode{};
    node.flex_direction = .col;
    node.result.width = 100;
    node.result.height = 50;

    try std.testing.expectEqual(@as(f32, 50), node.getMainSize());
    try std.testing.expectEqual(@as(f32, 100), node.getCrossSize());
}

test "LayoutNode getPaddingMain row" {
    var node = LayoutNode{};
    node.flex_direction = .row;
    node.padding_left = 10;
    node.padding_right = 15;
    node.padding_top = 5;
    node.padding_bottom = 20;

    try std.testing.expectEqual(@as(f32, 25), node.getPaddingMain());
}

test "LayoutNode getPaddingCross row" {
    var node = LayoutNode{};
    node.flex_direction = .row;
    node.padding_left = 10;
    node.padding_right = 15;
    node.padding_top = 5;
    node.padding_bottom = 20;

    try std.testing.expectEqual(@as(f32, 25), node.getPaddingCross());
}

test "LayoutNode getPaddingMain column" {
    var node = LayoutNode{};
    node.flex_direction = .col;
    node.padding_left = 10;
    node.padding_right = 15;
    node.padding_top = 5;
    node.padding_bottom = 20;

    try std.testing.expectEqual(@as(f32, 25), node.getPaddingMain());
}

test "LayoutEngine init" {
    var engine = LayoutEngine{};
    engine.init();

    try std.testing.expectEqual(@as(u32, 0), engine.node_count);
    try std.testing.expectEqual(@as(u32, 0xFFFFFFFF), engine.root_id);
}

test "LayoutEngine createNode" {
    var engine = LayoutEngine{};
    engine.init();

    const id1 = engine.createNode();
    try std.testing.expect(id1 != null);
    try std.testing.expectEqual(@as(u32, 0), id1.?);

    const id2 = engine.createNode();
    try std.testing.expect(id2 != null);
    try std.testing.expectEqual(@as(u32, 1), id2.?);

    try std.testing.expectEqual(@as(u32, 2), engine.node_count);
}

test "LayoutEngine getNode" {
    var engine = LayoutEngine{};
    engine.init();

    const id = engine.createNode().?;
    const node = engine.getNode(id);
    try std.testing.expect(node != null);
    try std.testing.expectEqual(id, node.?.id);

    // Invalid ID should return null
    try std.testing.expect(engine.getNode(999) == null);
}

test "LayoutEngine setRoot" {
    var engine = LayoutEngine{};
    engine.init();

    const id = engine.createNode().?;
    engine.setRoot(id);
    try std.testing.expectEqual(id, engine.root_id);
}

test "LayoutEngine addChild" {
    var engine = LayoutEngine{};
    engine.init();

    const parent = engine.createNode().?;
    const child1 = engine.createNode().?;
    const child2 = engine.createNode().?;

    try std.testing.expect(engine.addChild(parent, child1));
    try std.testing.expect(engine.addChild(parent, child2));

    const parent_node = engine.getNode(parent).?;
    try std.testing.expectEqual(@as(u32, 2), parent_node.child_count);

    const child_node = engine.getNode(child1).?;
    try std.testing.expectEqual(parent, child_node.parent_id);
}

test "LayoutEngine addChild invalid" {
    var engine = LayoutEngine{};
    engine.init();

    const id = engine.createNode().?;
    // Invalid parent
    try std.testing.expect(!engine.addChild(999, id));
    // Invalid child
    try std.testing.expect(!engine.addChild(id, 999));
}

test "LayoutEngine compute with no root" {
    var engine = LayoutEngine{};
    engine.init();

    // Should not crash with no root set
    engine.compute(800, 600);
}

test "LayoutEngine compute simple layout" {
    var engine = LayoutEngine{};
    engine.init();

    const root = engine.createNode().?;
    engine.setRoot(root);

    const root_node = engine.getNode(root).?;
    root_node.display = .block;
    root_node.width = 400;
    root_node.height = 300;

    engine.compute(800, 600);

    try std.testing.expectEqual(@as(f32, 400), root_node.result.width);
    try std.testing.expectEqual(@as(f32, 300), root_node.result.height);
}

test "LayoutEngine compute flex row" {
    var engine = LayoutEngine{};
    engine.init();

    const root = engine.createNode().?;
    const child1 = engine.createNode().?;
    const child2 = engine.createNode().?;

    engine.setRoot(root);
    _ = engine.addChild(root, child1);
    _ = engine.addChild(root, child2);

    const root_node = engine.getNode(root).?;
    root_node.display = .flex;
    root_node.flex_direction = .row;
    root_node.width = 400;
    root_node.height = 100;

    const child1_node = engine.getNode(child1).?;
    child1_node.width = 100;

    const child2_node = engine.getNode(child2).?;
    child2_node.width = 100;

    engine.compute(800, 600);

    try std.testing.expectEqual(@as(f32, 400), root_node.result.width);
    try std.testing.expectEqual(@as(f32, 100), root_node.result.height);
}

test "LayoutEngine compute block children" {
    var engine = LayoutEngine{};
    engine.init();

    const root = engine.createNode().?;
    const child1 = engine.createNode().?;
    const child2 = engine.createNode().?;

    engine.setRoot(root);
    _ = engine.addChild(root, child1);
    _ = engine.addChild(root, child2);

    const root_node = engine.getNode(root).?;
    root_node.display = .block;
    root_node.width = 400;
    root_node.height = 300;
    root_node.padding_top = 10;
    root_node.padding_left = 20;

    const child1_node = engine.getNode(child1).?;
    child1_node.height = 50;

    const child2_node = engine.getNode(child2).?;
    child2_node.height = 50;

    engine.compute(800, 600);

    // Children should be positioned vertically
    try std.testing.expectEqual(@as(f32, 20), child1_node.result.x);
    try std.testing.expectEqual(@as(f32, 10), child1_node.result.y);
}

test "LayoutNode min/max constraints" {
    var engine = LayoutEngine{};
    engine.init();

    const root = engine.createNode().?;
    engine.setRoot(root);

    const root_node = engine.getNode(root).?;
    root_node.display = .block;
    root_node.min_width = 200;
    root_node.max_width = 600;

    engine.compute(800, 600);

    // Width should be constrained to max
    try std.testing.expect(root_node.result.width <= 600);
    try std.testing.expect(root_node.result.width >= 200);
}

test "WASM export functions" {
    // Reset global state
    init();

    const id = createNode();
    try std.testing.expect(id != 0xFFFFFFFF);

    setRoot(id);

    const node = getNode(id);
    try std.testing.expect(node != null);

    compute(800, 600);

    try std.testing.expectEqual(@as(u32, 1), getNodeCount());
    try std.testing.expectEqual(@sizeOf(LayoutResult), getResultSize());
}

test "LayoutEngine flex with gap" {
    var engine = LayoutEngine{};
    engine.init();

    const root = engine.createNode().?;
    const child1 = engine.createNode().?;
    const child2 = engine.createNode().?;

    engine.setRoot(root);
    _ = engine.addChild(root, child1);
    _ = engine.addChild(root, child2);

    const root_node = engine.getNode(root).?;
    root_node.display = .flex;
    root_node.flex_direction = .row;
    root_node.gap = 10;
    root_node.width = 400;
    root_node.height = 100;

    const child1_node = engine.getNode(child1).?;
    child1_node.width = 100;

    const child2_node = engine.getNode(child2).?;
    child2_node.width = 100;

    engine.compute(800, 600);

    // Children should be separated by gap
    const expected_x2 = child1_node.result.x + child1_node.result.width + root_node.gap;
    try std.testing.expectEqual(expected_x2, child2_node.result.x);
}

// === Performance Optimization Tests ===

test "LayoutNode computeStyleHash deterministic" {
    var node1 = LayoutNode{};
    var node2 = LayoutNode{};

    // Same properties should produce same hash
    try std.testing.expectEqual(node1.computeStyleHash(), node2.computeStyleHash());

    // Different properties should produce different hash
    node2.width = 100;
    try std.testing.expect(node1.computeStyleHash() != node2.computeStyleHash());
}

test "LayoutNode updateCachedFlags" {
    var node = LayoutNode{};

    // Default is block layout (not flex)
    node.updateCachedFlags();
    try std.testing.expect(!node.cached_is_flex);
    try std.testing.expect(node.cached_is_row); // row is default

    // Change to flex
    node.display = .flex;
    node.flex_direction = .col;
    node.updateCachedFlags();
    try std.testing.expect(node.cached_is_flex);
    try std.testing.expect(!node.cached_is_row);
    try std.testing.expect(!node.cached_is_reverse);

    // Change to reverse
    node.flex_direction = .col_reverse;
    node.updateCachedFlags();
    try std.testing.expect(node.cached_is_reverse);
}

test "LayoutNode dirty flag on addChild" {
    var node = LayoutNode{};
    node.dirty = false;

    _ = node.addChild(1);
    try std.testing.expect(node.dirty);
}

test "LayoutNode markDirty" {
    var node = LayoutNode{};
    node.dirty = false;
    node.computed = true;

    node.markDirty();
    try std.testing.expect(node.dirty);
    try std.testing.expect(!node.computed);
}

test "LayoutEngine needsLayout tracking" {
    var engine = LayoutEngine{};
    engine.init();

    // Initially needs layout
    try std.testing.expect(engine.needsLayout());

    const root = engine.createNode().?;
    engine.setRoot(root);

    // After compute, should not need layout
    engine.compute(800, 600);
    try std.testing.expect(!engine.needsLayout());

    // After marking dirty, should need layout
    engine.markNodeDirty(root);
    try std.testing.expect(engine.needsLayout());
}

test "LayoutEngine skips redundant layout" {
    var engine = LayoutEngine{};
    engine.init();

    const root = engine.createNode().?;
    engine.setRoot(root);

    const root_node = engine.getNode(root).?;
    root_node.width = 400;
    root_node.height = 300;

    // First compute
    engine.compute(800, 600);
    try std.testing.expect(!engine.needsLayout());

    // Same size compute should skip (needs_layout is false)
    engine.compute(800, 600);
    try std.testing.expect(!engine.needsLayout());

    // Different size should trigger layout
    engine.compute(1024, 768);
    try std.testing.expect(!engine.needsLayout()); // computed successfully
    try std.testing.expectEqual(@as(f32, 1024), engine.last_container_width);
}

test "LayoutEngine forceCompute" {
    var engine = LayoutEngine{};
    engine.init();

    const root = engine.createNode().?;
    engine.setRoot(root);

    engine.compute(800, 600);
    try std.testing.expect(!engine.needsLayout());

    // Force compute should work even when not dirty
    engine.forceCompute(800, 600);
    try std.testing.expect(!engine.needsLayout()); // Still clean after
}

test "LayoutEngine getResultsDirect" {
    var engine = LayoutEngine{};
    engine.init();

    const root = engine.createNode().?;
    const child = engine.createNode().?;
    engine.setRoot(root);
    _ = engine.addChild(root, child);

    engine.compute(800, 600);

    const direct = engine.getResultsDirect();
    try std.testing.expectEqual(@as(u32, 2), direct.count);
    try std.testing.expectEqual(@sizeOf(LayoutNode), direct.stride);
}

test "LayoutEngine copyResultsToBuffer" {
    var engine = LayoutEngine{};
    engine.init();

    const root = engine.createNode().?;
    const child = engine.createNode().?;
    engine.setRoot(root);
    _ = engine.addChild(root, child);

    const root_node = engine.getNode(root).?;
    root_node.width = 400;
    root_node.height = 300;

    engine.compute(800, 600);

    var buffer: [10]LayoutResult = undefined;
    const count = engine.copyResultsToBuffer(&buffer);

    try std.testing.expectEqual(@as(u32, 2), count);
    try std.testing.expectEqual(@as(f32, 400), buffer[0].width);
}
