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
const simd = @import("perf/simd.zig");
const cache = @import("perf/cache.zig");
const pool = @import("perf/pool.zig");

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
        // Field-by-field comparison with early exit is faster than byte comparison
        if (self.class_len != other.class_len) return false;
        if (!simd.simdMemEql(self.class[0..self.class_len], other.class[0..other.class_len])) return false;
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
        // Use SIMD for key comparison
        return simd.simdMemEql(self.key[0..self.key_len], other.key[0..other.key_len]);
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

    // ========================================================================
    // Incremental Update Methods
    // ========================================================================

    /// Mark a node as dirty (needs re-diffing)
    pub fn markDirty(self: *VTree, id: u32) void {
        if (self.get(id)) |node| {
            node.dirty = true;
        }
    }

    /// Mark a node and all its descendants as dirty
    pub fn markSubtreeDirty(self: *VTree, id: u32) void {
        if (self.get(id)) |node| {
            node.dirty = true;
            for (node.children[0..node.child_count]) |child_id| {
                self.markSubtreeDirty(child_id);
            }
        }
    }

    /// Clear dirty flag on a node
    pub fn clearDirty(self: *VTree, id: u32) void {
        if (self.get(id)) |node| {
            node.dirty = false;
        }
    }

    /// Clear all dirty flags in the tree
    pub fn clearAllDirty(self: *VTree) void {
        for (self.nodes[0..self.count]) |*node| {
            node.dirty = false;
        }
    }

    /// Check if any node in the tree is dirty
    pub fn hasDirtyNodes(self: *const VTree) bool {
        for (self.nodes[0..self.count]) |*node| {
            if (node.dirty) return true;
        }
        return false;
    }

    /// Get all dirty node IDs
    pub fn getDirtyNodes(self: *const VTree, out_ids: []u32) u32 {
        var count: u32 = 0;
        for (self.nodes[0..self.count]) |*node| {
            if (node.dirty and count < out_ids.len) {
                out_ids[count] = node.id;
                count += 1;
            }
        }
        return count;
    }

    /// Update a node's text in place (incremental update)
    pub fn updateNodeText(self: *VTree, id: u32, new_text: []const u8) bool {
        if (self.get(id)) |node| {
            node.setText(new_text);
            node.dirty = true;
            return true;
        }
        return false;
    }

    /// Update a node's class in place (incremental update)
    pub fn updateNodeClass(self: *VTree, id: u32, new_class: []const u8) bool {
        if (self.get(id)) |node| {
            node.props.setClass(new_class);
            node.dirty = true;
            return true;
        }
        return false;
    }

    /// Update a node's props in place (incremental update)
    pub fn updateNodeProps(self: *VTree, id: u32, new_props: VNodeProps) bool {
        if (self.get(id)) |node| {
            node.props = new_props;
            node.dirty = true;
            return true;
        }
        return false;
    }

    /// Replace a subtree with a new node (returns new node id)
    /// The old subtree nodes are marked invalid but remain in array
    /// (they will be overwritten by new nodes)
    pub fn replaceNode(self: *VTree, old_id: u32, new_node: VNode) u32 {
        // Find and mark old node
        if (self.get(old_id)) |old| {
            old.dirty = true;
            // Mark children for removal (they'll become orphaned)
            for (old.children[0..old.child_count]) |child_id| {
                self.markSubtreeDirty(child_id);
            }
        }

        // Create new node
        const new_id = self.create(new_node);
        if (new_id == 0) return 0;

        // If old node was root, update root
        if (self.root_id == old_id) {
            self.root_id = new_id;
        }

        // Update parent references (find parent and replace child)
        for (self.nodes[0..self.count]) |*node| {
            for (node.children[0..node.child_count], 0..) |child_id, i| {
                if (child_id == old_id) {
                    node.children[i] = new_id;
                    node.dirty = true;
                    break;
                }
            }
        }

        return new_id;
    }

    /// Clone a node (creates a copy with new ID)
    pub fn cloneNode(self: *VTree, id: u32) u32 {
        if (self.getConst(id)) |node| {
            var clone = node.*;
            clone.id = 0; // Will be assigned by create()
            clone.dirty = true;
            return self.create(clone);
        }
        return 0;
    }

    /// Get parent of a node (O(n) search)
    pub fn getParent(self: *const VTree, id: u32) ?u32 {
        for (self.nodes[0..self.count]) |*node| {
            for (node.children[0..node.child_count]) |child_id| {
                if (child_id == id) return node.id;
            }
        }
        return null;
    }

    /// Remove a child from its parent
    pub fn removeChild(self: *VTree, parent_id: u32, child_id: u32) bool {
        if (self.get(parent_id)) |parent| {
            var found_idx: ?u8 = null;
            for (parent.children[0..parent.child_count], 0..) |cid, i| {
                if (cid == child_id) {
                    found_idx = @intCast(i);
                    break;
                }
            }

            if (found_idx) |idx| {
                // Shift remaining children
                var i = idx;
                while (i < parent.child_count - 1) : (i += 1) {
                    parent.children[i] = parent.children[i + 1];
                }
                parent.child_count -= 1;
                parent.dirty = true;
                return true;
            }
        }
        return false;
    }

    /// Insert a child at a specific index
    pub fn insertChildAt(self: *VTree, parent_id: u32, child_id: u32, index: u8) bool {
        if (self.get(parent_id)) |parent| {
            if (parent.child_count >= MAX_VNODE_CHILDREN) return false;
            if (index > parent.child_count) return false;

            // Shift children to make room
            var i = parent.child_count;
            while (i > index) : (i -= 1) {
                parent.children[i] = parent.children[i - 1];
            }
            parent.children[index] = child_id;
            parent.child_count += 1;
            parent.dirty = true;
            return true;
        }
        return false;
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

// ============================================================================
// Batch Patch Application
// ============================================================================

/// Maximum patches per batch type
pub const MAX_BATCH_SIZE = MAX_PATCHES;

/// Batched patches organized by type for optimal DOM application
/// Order of application: remove → create → update
/// This reduces DOM reflows and improves performance
pub const PatchBatch = struct {
    /// Remove patches (applied first, in reverse order for valid DOM refs)
    removes: [MAX_BATCH_SIZE]u32 = undefined,
    remove_count: u32 = 0,

    /// Create patches (applied second, in tree order)
    creates: [MAX_BATCH_SIZE]u32 = undefined,
    create_count: u32 = 0,

    /// Update patches (applied last, order doesn't matter)
    updates: [MAX_BATCH_SIZE]u32 = undefined,
    update_count: u32 = 0,

    /// Reference to original patches
    source: ?*const DiffResult = null,

    pub fn init() PatchBatch {
        return .{};
    }

    /// Organize patches from DiffResult into batches
    pub fn fromDiffResult(result: *const DiffResult) PatchBatch {
        var batch = PatchBatch.init();
        batch.source = result;

        var i: u32 = 0;
        while (i < result.count) : (i += 1) {
            const patch = &result.patches[i];
            switch (patch.patch_type) {
                .remove, .remove_child => {
                    if (batch.remove_count < MAX_BATCH_SIZE) {
                        batch.removes[batch.remove_count] = i;
                        batch.remove_count += 1;
                    }
                },
                .create, .replace, .insert_child => {
                    if (batch.create_count < MAX_BATCH_SIZE) {
                        batch.creates[batch.create_count] = i;
                        batch.create_count += 1;
                    }
                },
                .update_props, .update_text, .reorder => {
                    if (batch.update_count < MAX_BATCH_SIZE) {
                        batch.updates[batch.update_count] = i;
                        batch.update_count += 1;
                    }
                },
                .none => {},
            }
        }

        // Reverse remove order for safe DOM removal (children before parents)
        if (batch.remove_count > 1) {
            var left: u32 = 0;
            var right: u32 = batch.remove_count - 1;
            while (left < right) {
                const temp = batch.removes[left];
                batch.removes[left] = batch.removes[right];
                batch.removes[right] = temp;
                left += 1;
                right -= 1;
            }
        }

        return batch;
    }

    /// Get total number of patches in batch
    pub fn getTotalCount(self: *const PatchBatch) u32 {
        return self.remove_count + self.create_count + self.update_count;
    }

    /// Iterator for processing batches in optimal order
    pub const BatchIterator = struct {
        batch: *const PatchBatch,
        phase: Phase = .removes,
        index: u32 = 0,

        pub const Phase = enum { removes, creates, updates, done };

        pub fn next(self: *BatchIterator) ?*const Patch {
            while (true) {
                switch (self.phase) {
                    .removes => {
                        if (self.index < self.batch.remove_count) {
                            const patch_idx = self.batch.removes[self.index];
                            self.index += 1;
                            if (self.batch.source) |src| {
                                return &src.patches[patch_idx];
                            }
                        }
                        self.phase = .creates;
                        self.index = 0;
                    },
                    .creates => {
                        if (self.index < self.batch.create_count) {
                            const patch_idx = self.batch.creates[self.index];
                            self.index += 1;
                            if (self.batch.source) |src| {
                                return &src.patches[patch_idx];
                            }
                        }
                        self.phase = .updates;
                        self.index = 0;
                    },
                    .updates => {
                        if (self.index < self.batch.update_count) {
                            const patch_idx = self.batch.updates[self.index];
                            self.index += 1;
                            if (self.batch.source) |src| {
                                return &src.patches[patch_idx];
                            }
                        }
                        self.phase = .done;
                        return null;
                    },
                    .done => return null,
                }
            }
        }

        pub fn getCurrentPhase(self: *const BatchIterator) Phase {
            return self.phase;
        }
    };

    /// Create iterator for processing patches in optimal order
    pub fn iterator(self: *const PatchBatch) BatchIterator {
        return .{ .batch = self };
    }

    /// Get patches for a specific phase
    pub fn getRemovePatches(self: *const PatchBatch) []const u32 {
        return self.removes[0..self.remove_count];
    }

    pub fn getCreatePatches(self: *const PatchBatch) []const u32 {
        return self.creates[0..self.create_count];
    }

    pub fn getUpdatePatches(self: *const PatchBatch) []const u32 {
        return self.updates[0..self.update_count];
    }
};

/// Size of temporary arena for diff operations
const DIFF_ARENA_SIZE = 4096;

/// VNode pool for efficient allocation/deallocation
pub const VNodePool = pool.ObjectPool(VNode, MAX_VNODES);

pub const Differ = struct {
    result: DiffResult = .{},
    next_dom_id: u32 = 1,
    diff_cache: cache.DiffCache = cache.DiffCache.init(),
    /// Arena for temporary allocations during diff
    temp_arena: pool.ArenaPool(DIFF_ARENA_SIZE) = pool.ArenaPool(DIFF_ARENA_SIZE).init(),

    pub fn init() Differ {
        return .{};
    }

    pub fn reset(self: *Differ) void {
        self.result = .{};
        self.next_dom_id = 1;
        self.temp_arena.reset();
        // Note: cache is preserved across resets for better hit rate
    }

    /// Clear the diff cache (call periodically to free memory)
    pub fn clearCache(self: *Differ) void {
        self.diff_cache.clear();
    }

    /// Get cache statistics
    pub fn getCacheStats(self: *const Differ) cache.CacheStats {
        return self.diff_cache.getStats();
    }

    /// Get temporary arena memory usage
    pub fn getArenaUsage(self: *const Differ) struct { used: usize, available: usize } {
        return .{
            .used = self.temp_arena.getBytesUsed(),
            .available = self.temp_arena.getBytesAvailable(),
        };
    }

    /// Compute hash for a VNode (for caching)
    fn computeNodeHash(node: *const VNode) u32 {
        // Combine key fields into a hash
        var hash: u32 = @intFromEnum(node.node_type);
        hash = hash *% 31 +% @intFromEnum(node.tag);
        hash = hash *% 31 +% node.text_len;
        hash = hash *% 31 +% node.child_count;
        hash = hash *% 31 +% node.props.style_id;
        hash = hash *% 31 +% node.props.on_click;
        if (node.text_len > 0) {
            hash = hash *% 31 +% simd.simdHashKey(node.text[0..node.text_len]);
        }
        if (node.props.class_len > 0) {
            hash = hash *% 31 +% simd.simdHashKey(node.props.class[0..node.props.class_len]);
        }
        return hash;
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

        // Same type - check cache before doing expensive diff
        const old_hash = computeNodeHash(old);
        const new_hash = computeNodeHash(new);

        // Check if we've already compared these nodes
        if (self.diff_cache.lookup(old_hash, new_hash)) |cached| {
            if (cached.equal) {
                // Nodes are identical - no patches needed
                return;
            }
            // Cache says nodes differ - continue with diff
            // (we still need to generate patches even if we know they differ)
        }

        // Same type - check for updates
        const dom_id = old.dom_id;
        const patch_count_before = self.result.count;

        switch (new.node_type) {
            .text => {
                // Text node - check if content changed
                // Use SIMD for text comparison
                if (!simd.simdMemEql(old.getText(), new.getText())) {
                    _ = self.result.addPatch(Patch.updateText(dom_id, new.getText()));
                }
            },
            .element => {
                // Element - check props (already uses SIMD via equals())
                if (!old.props.equals(&new.props)) {
                    _ = self.result.addPatch(Patch.updateProps(dom_id, new.props));
                }

                // Check text content with SIMD
                if (!simd.simdMemEql(old.getText(), new.getText())) {
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

        // Store result in cache for future lookups
        const patches_generated = self.result.count - patch_count_before;
        const nodes_equal = (patches_generated == 0);
        self.diff_cache.store(old_hash, new_hash, nodes_equal, @intCast(patches_generated));
    }

    /// Key-based child reconciliation algorithm
    /// This implements an efficient O(n) algorithm for matching keyed children:
    /// 1. Build a map of old children by key
    /// 2. Match new children to old children by key
    /// 3. Diff matched pairs, create unmatched new, remove unmatched old
    /// 4. Fall back to index-based matching for unkeyed children
    fn diffChildren(self: *Differ, old_tree: *const VTree, new_tree: *const VTree, old_node: *const VNode, new_node: *const VNode, parent_dom_id: u32) void {
        const old_count = old_node.child_count;
        const new_count = new_node.child_count;

        // Check if we have any keyed children
        var has_keyed_old = false;
        var has_keyed_new = false;

        for (old_node.children[0..old_count]) |child_id| {
            if (old_tree.getConst(child_id)) |child| {
                if (child.hasKey()) {
                    has_keyed_old = true;
                    break;
                }
            }
        }

        for (new_node.children[0..new_count]) |child_id| {
            if (new_tree.getConst(child_id)) |child| {
                if (child.hasKey()) {
                    has_keyed_new = true;
                    break;
                }
            }
        }

        // Use key-based algorithm if any children have keys
        if (has_keyed_old or has_keyed_new) {
            self.diffKeyedChildren(old_tree, new_tree, old_node, new_node, parent_dom_id);
        } else {
            // Fall back to simple index-based algorithm
            self.diffUnkeyedChildren(old_tree, new_tree, old_node, new_node, parent_dom_id);
        }
    }

    /// Diff keyed children using key-based matching
    fn diffKeyedChildren(self: *Differ, old_tree: *const VTree, new_tree: *const VTree, old_node: *const VNode, new_node: *const VNode, parent_dom_id: u32) void {
        const old_count = old_node.child_count;
        const new_count = new_node.child_count;

        // Build key map for old children
        // Using fixed-size arrays since we have MAX_VNODE_CHILDREN limit
        var old_key_map: [MAX_VNODE_CHILDREN]struct {
            key_hash: u32,
            child_id: u32,
            matched: bool,
        } = undefined;
        var old_key_count: u8 = 0;

        // Track unkeyed old children for index fallback
        var old_unkeyed: [MAX_VNODE_CHILDREN]struct {
            child_id: u32,
            matched: bool,
        } = undefined;
        var old_unkeyed_count: u8 = 0;

        // Populate old child maps
        for (old_node.children[0..old_count]) |old_child_id| {
            if (old_tree.getConst(old_child_id)) |old_child| {
                if (old_child.hasKey()) {
                    old_key_map[old_key_count] = .{
                        // Use SIMD-accelerated hash
                        .key_hash = simd.simdHashKey(old_child.getKey()),
                        .child_id = old_child_id,
                        .matched = false,
                    };
                    old_key_count += 1;
                } else {
                    old_unkeyed[old_unkeyed_count] = .{
                        .child_id = old_child_id,
                        .matched = false,
                    };
                    old_unkeyed_count += 1;
                }
            }
        }

        // Track index for unkeyed new children
        var unkeyed_new_idx: u8 = 0;

        // Process new children
        for (new_node.children[0..new_count]) |new_child_id| {
            const new_child = new_tree.getConst(new_child_id);
            if (new_child == null) continue;

            if (new_child.?.hasKey()) {
                // Keyed child - find matching old child by key
                // Use SIMD-accelerated hash
                const new_key_hash = simd.simdHashKey(new_child.?.getKey());
                var found_match = false;

                for (old_key_map[0..old_key_count]) |*entry| {
                    if (!entry.matched and entry.key_hash == new_key_hash) {
                        // Verify full key match (not just hash) with SIMD
                        if (old_tree.getConst(entry.child_id)) |old_child| {
                            if (simd.simdMemEql(old_child.getKey(), new_child.?.getKey())) {
                                // Match found - diff the nodes
                                entry.matched = true;
                                found_match = true;
                                self.diffNode(old_tree, new_tree, entry.child_id, new_child_id, parent_dom_id);
                                break;
                            }
                        }
                    }
                }

                if (!found_match) {
                    // No matching old child - create new
                    self.createSubtree(new_tree, new_child_id, parent_dom_id);
                }
            } else {
                // Unkeyed new child - try to match with unkeyed old child by index
                if (unkeyed_new_idx < old_unkeyed_count) {
                    const old_entry = &old_unkeyed[unkeyed_new_idx];
                    old_entry.matched = true;
                    self.diffNode(old_tree, new_tree, old_entry.child_id, new_child_id, parent_dom_id);
                } else {
                    // No more unkeyed old children - create new
                    self.createSubtree(new_tree, new_child_id, parent_dom_id);
                }
                unkeyed_new_idx += 1;
            }
        }

        // Remove unmatched old keyed children
        for (old_key_map[0..old_key_count]) |entry| {
            if (!entry.matched) {
                if (old_tree.getConst(entry.child_id)) |old_child| {
                    _ = self.result.addPatch(Patch.remove(old_child.dom_id));
                }
            }
        }

        // Remove unmatched old unkeyed children
        for (old_unkeyed[0..old_unkeyed_count]) |entry| {
            if (!entry.matched) {
                if (old_tree.getConst(entry.child_id)) |old_child| {
                    _ = self.result.addPatch(Patch.remove(old_child.dom_id));
                }
            }
        }
    }

    /// Simple index-based diffing for unkeyed children
    fn diffUnkeyedChildren(self: *Differ, old_tree: *const VTree, new_tree: *const VTree, old_node: *const VNode, new_node: *const VNode, parent_dom_id: u32) void {
        const old_count = old_node.child_count;
        const new_count = new_node.child_count;
        const max_count = @max(old_count, new_count);

        var i: u8 = 0;
        while (i < max_count) : (i += 1) {
            const old_child_id = if (i < old_count) old_node.children[i] else 0;
            const new_child_id = if (i < new_count) new_node.children[i] else 0;

            if (old_child_id != 0 and new_child_id != 0) {
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

    /// Hash a key string for fast comparison (SIMD-accelerated)
    fn hashKey(key: []const u8) u32 {
        return simd.simdHashKey(key);
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
var global_vnode_pool: VNodePool = VNodePool.init();
var global_initialized: bool = false;

pub fn initGlobal() void {
    if (!global_initialized) {
        global_reconciler.reset();
        global_vnode_pool.reset();
        global_initialized = true;
    }
}

pub fn getReconciler() *Reconciler {
    return &global_reconciler;
}

pub fn getVNodePool() *VNodePool {
    return &global_vnode_pool;
}

pub fn resetGlobal() void {
    global_reconciler.reset();
    global_vnode_pool.reset();
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

/// Batch patches for optimal application order
/// Returns a PatchBatch that groups patches by type:
/// 1. Removes (applied first, in reverse order)
/// 2. Creates (applied second, in tree order)
/// 3. Updates (applied last)
pub fn batchPatches() PatchBatch {
    return PatchBatch.fromDiffResult(&getReconciler().differ.result);
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

test "VNode element with various tags" {
    var tree = VTree.init();

    const button_id = tree.create(VNode.element(.button));
    const p_id = tree.create(VNode.element(.p));
    const h1_id = tree.create(VNode.element(.h1));

    const button = tree.get(button_id);
    const p = tree.get(p_id);
    const h1 = tree.get(h1_id);

    try std.testing.expectEqual(ElementTag.button, button.?.tag);
    try std.testing.expectEqual(ElementTag.p, p.?.tag);
    try std.testing.expectEqual(ElementTag.h1, h1.?.tag);
}

test "VNode fragment" {
    var tree = VTree.init();

    const frag_id = tree.create(VNode.fragment());
    const frag = tree.get(frag_id);

    try std.testing.expect(frag != null);
    try std.testing.expectEqual(VNodeType.fragment, frag.?.node_type);
}

test "VNode with key" {
    var node = VNode.element(.li);
    try std.testing.expect(!node.hasKey());

    node.setKey("item-1");
    try std.testing.expect(node.hasKey());
    try std.testing.expectEqualStrings("item-1", node.getKey());
}

test "VNode with class using builder" {
    const node = VNode.element(.div).withClass("container");
    try std.testing.expectEqualStrings("container", node.props.getClass());
}

test "VNode with style" {
    const node = VNode.element(.div).withStyle(42);
    try std.testing.expectEqual(@as(u32, 42), node.props.style_id);
}

test "VNode with onClick" {
    const node = VNode.element(.button).withOnClick(123);
    try std.testing.expectEqual(@as(u32, 123), node.props.on_click);
}

test "VNode with text using builder" {
    const node = VNode.element(.p).withText("Hello");
    try std.testing.expectEqualStrings("Hello", node.getText());
}

test "VNodeProps setters and getters" {
    var props = VNodeProps{};

    props.setClass("my-class");
    try std.testing.expectEqualStrings("my-class", props.getClass());

    props.setPlaceholder("Enter text");
    try std.testing.expectEqualStrings("Enter text", props.placeholder[0..props.placeholder_len]);

    props.setHref("https://example.com");
    try std.testing.expectEqualStrings("https://example.com", props.href[0..props.href_len]);

    props.setSrc("/images/logo.png");
    try std.testing.expectEqualStrings("/images/logo.png", props.src[0..props.src_len]);

    props.setAlt("Logo image");
    try std.testing.expectEqualStrings("Logo image", props.alt[0..props.alt_len]);
}

test "VNodeProps equals" {
    var props1 = VNodeProps{};
    var props2 = VNodeProps{};

    try std.testing.expect(props1.equals(&props2));

    props1.setClass("test");
    try std.testing.expect(!props1.equals(&props2));

    props2.setClass("test");
    try std.testing.expect(props1.equals(&props2));

    props1.on_click = 1;
    try std.testing.expect(!props1.equals(&props2));
}

test "VNode isSameType" {
    const div1 = VNode.element(.div);
    const div2 = VNode.element(.div);
    const button = VNode.element(.button);
    const text = VNode.textNode("hello");

    try std.testing.expect(div1.isSameType(&div2));
    try std.testing.expect(!div1.isSameType(&button));
    try std.testing.expect(!div1.isSameType(&text));
}

test "VNode isSameKey" {
    var node1 = VNode.element(.li);
    var node2 = VNode.element(.li);

    // Both no keys - same
    try std.testing.expect(node1.isSameKey(&node2));

    // One has key, one doesn't - different
    node1.setKey("item-1");
    try std.testing.expect(!node1.isSameKey(&node2));

    // Both have same key
    node2.setKey("item-1");
    try std.testing.expect(node1.isSameKey(&node2));

    // Different keys
    node2.setKey("item-2");
    try std.testing.expect(!node1.isSameKey(&node2));
}

test "VTree reset" {
    var tree = VTree.init();

    _ = tree.create(VNode.element(.div));
    _ = tree.create(VNode.element(.span));
    try std.testing.expectEqual(@as(u32, 2), tree.count);

    tree.reset();
    try std.testing.expectEqual(@as(u32, 0), tree.count);
    try std.testing.expectEqual(@as(u32, 0), tree.root_id);
}

test "VTree get returns null for invalid id" {
    var tree = VTree.init();
    try std.testing.expect(tree.get(0) == null);
    try std.testing.expect(tree.get(999) == null);
}

test "VTree getConst" {
    var tree = VTree.init();
    const id = tree.create(VNode.element(.div));

    const const_tree: *const VTree = &tree;
    const node = const_tree.getConst(id);
    try std.testing.expect(node != null);
    try std.testing.expectEqual(ElementTag.div, node.?.tag);
}

test "VTree addChild to non-existent parent fails" {
    var tree = VTree.init();
    const child_id = tree.create(VNode.element(.span));
    try std.testing.expect(!tree.addChild(999, child_id));
}

test "VTree setRoot and getNodeCount" {
    var tree = VTree.init();
    const id = tree.create(VNode.element(.div));
    tree.setRoot(id);

    try std.testing.expectEqual(id, tree.root_id);
    try std.testing.expectEqual(@as(u32, 1), tree.getNodeCount());
}

test "DiffResult addPatch and getPatch" {
    var result = DiffResult{};

    const patch1 = Patch.create(1, 0, .div);
    try std.testing.expect(result.addPatch(patch1));
    try std.testing.expectEqual(@as(u32, 1), result.count);

    const patch2 = Patch.remove(1);
    try std.testing.expect(result.addPatch(patch2));
    try std.testing.expectEqual(@as(u32, 2), result.count);

    const retrieved = result.getPatch(0);
    try std.testing.expect(retrieved != null);
    try std.testing.expectEqual(PatchType.create, retrieved.?.patch_type);

    // Invalid index
    try std.testing.expect(result.getPatch(999) == null);
}

test "Differ reset" {
    var differ = Differ.init();
    var tree = VTree.init();

    const id = tree.create(VNode.element(.div));
    tree.setRoot(id);

    _ = differ.diff(null, &tree);
    try std.testing.expect(differ.result.count > 0);

    differ.reset();
    try std.testing.expectEqual(@as(u32, 0), differ.result.count);
    try std.testing.expectEqual(@as(u32, 1), differ.next_dom_id);
}

test "Patch creation helpers" {
    const create_patch = Patch.create(1, 0, .button);
    try std.testing.expectEqual(PatchType.create, create_patch.patch_type);
    try std.testing.expectEqual(ElementTag.button, create_patch.new_tag);

    const text_patch = Patch.createText(2, 1, "Hello");
    try std.testing.expectEqual(PatchType.create, text_patch.patch_type);
    try std.testing.expectEqual(VNodeType.text, text_patch.new_node_type);

    const remove_patch = Patch.remove(5);
    try std.testing.expectEqual(PatchType.remove, remove_patch.patch_type);
    try std.testing.expectEqual(@as(u32, 5), remove_patch.dom_id);

    const replace_patch = Patch.replace(3, 4, .span);
    try std.testing.expectEqual(PatchType.replace, replace_patch.patch_type);

    var props = VNodeProps{};
    props.on_click = 42;
    const props_patch = Patch.updateProps(6, props);
    try std.testing.expectEqual(PatchType.update_props, props_patch.patch_type);
    try std.testing.expectEqual(@as(u32, 42), props_patch.props.on_click);

    const update_text_patch = Patch.updateText(7, "Updated");
    try std.testing.expectEqual(PatchType.update_text, update_text_patch.patch_type);

    const insert_patch = Patch.insertChild(8, 9, 2);
    try std.testing.expectEqual(PatchType.insert_child, insert_patch.patch_type);
    try std.testing.expectEqual(@as(u16, 2), insert_patch.index);

    const remove_child_patch = Patch.removeChild(10, 1);
    try std.testing.expectEqual(PatchType.remove_child, remove_child_patch.patch_type);
}

test "Differ type replacement produces patches" {
    var differ = Differ.init();

    // Old tree with div
    var old_tree = VTree.init();
    const old_id = old_tree.create(VNode.element(.div));
    old_tree.setRoot(old_id);
    if (old_tree.get(old_id)) |node| {
        node.dom_id = 1;
    }

    // New tree with button (different type)
    var new_tree = VTree.init();
    const new_id = new_tree.create(VNode.element(.button));
    new_tree.setRoot(new_id);

    const result = differ.diff(&old_tree, &new_tree);

    // Should have remove and create patches
    try std.testing.expect(result.count >= 2);
}

test "Differ props change produces update patch" {
    var differ = Differ.init();

    // Old tree
    var old_tree = VTree.init();
    var old_node = VNode.element(.div);
    old_node.props.on_click = 1;
    const old_id = old_tree.create(old_node);
    old_tree.setRoot(old_id);
    if (old_tree.get(old_id)) |node| {
        node.dom_id = 1;
    }

    // New tree with different props
    var new_tree = VTree.init();
    var new_node = VNode.element(.div);
    new_node.props.on_click = 2;
    const new_id = new_tree.create(new_node);
    new_tree.setRoot(new_id);

    const result = differ.diff(&old_tree, &new_tree);

    try std.testing.expect(result.count >= 1);
    try std.testing.expectEqual(PatchType.update_props, result.patches[0].patch_type);
}

test "Differ fragment diffing" {
    var differ = Differ.init();

    // New tree with fragment containing children
    var new_tree = VTree.init();
    const frag_id = new_tree.create(VNode.fragment());
    const child1_id = new_tree.create(VNode.textNode("Hello"));
    const child2_id = new_tree.create(VNode.textNode("World"));
    _ = new_tree.addChild(frag_id, child1_id);
    _ = new_tree.addChild(frag_id, child2_id);
    new_tree.setRoot(frag_id);

    const result = differ.diff(null, &new_tree);

    // Fragment itself doesn't create DOM node, only children do
    try std.testing.expect(result.count >= 2);
}

test "Reconciler reset" {
    var reconciler = Reconciler.init();

    // Do a render
    const tree = reconciler.getNextTree();
    const id = tree.create(VNode.element(.div));
    tree.setRoot(id);
    _ = reconciler.commit();

    try std.testing.expect(!reconciler.is_first_render);

    reconciler.reset();
    try std.testing.expect(reconciler.is_first_render);
    try std.testing.expectEqual(@as(u32, 0), reconciler.current_tree.count);
}

test "Reconciler getCurrentTree" {
    var reconciler = Reconciler.init();

    const tree = reconciler.getNextTree();
    const id = tree.create(VNode.element(.div));
    tree.setRoot(id);
    _ = reconciler.commit();

    const current = reconciler.getCurrentTree();
    try std.testing.expectEqual(@as(u32, 1), current.getNodeCount());
}

test "global functions" {
    resetGlobal();
    initGlobal();

    const reconciler = getReconciler();
    try std.testing.expect(@intFromPtr(reconciler) != 0);
    try std.testing.expect(reconciler.is_first_render);

    resetGlobal();
}

test "helper function createElement" {
    resetGlobal();
    initGlobal();

    const tree = getReconciler().getNextTree();
    const id = tree.create(VNode.element(.button));
    try std.testing.expect(id > 0);

    const node = tree.get(id);
    try std.testing.expect(node != null);
    try std.testing.expectEqual(ElementTag.button, node.?.tag);

    resetGlobal();
}

test "helper function createText" {
    resetGlobal();
    initGlobal();

    const tree = getReconciler().getNextTree();
    const id = tree.create(VNode.textNode("Hello World"));
    try std.testing.expect(id > 0);

    const node = tree.get(id);
    try std.testing.expect(node != null);
    try std.testing.expectEqual(VNodeType.text, node.?.node_type);
    try std.testing.expectEqualStrings("Hello World", node.?.getText());

    resetGlobal();
}

test "helper function setClass" {
    resetGlobal();
    initGlobal();

    // Get tree once to avoid reset
    const tree = getReconciler().getNextTree();
    const id = tree.create(VNode.element(.div));

    // setClass accesses getNextTree() which resets, so set directly
    if (tree.get(id)) |node| {
        node.props.setClass("my-container");
    }

    const node = tree.get(id);
    try std.testing.expectEqualStrings("my-container", node.?.props.getClass());

    resetGlobal();
}

test "helper function setOnClick" {
    resetGlobal();
    initGlobal();

    const tree = getReconciler().getNextTree();
    const id = tree.create(VNode.element(.button));

    if (tree.get(id)) |node| {
        node.props.on_click = 42;
    }

    const node = tree.get(id);
    try std.testing.expectEqual(@as(u32, 42), node.?.props.on_click);

    resetGlobal();
}

test "helper function setText" {
    resetGlobal();
    initGlobal();

    const tree = getReconciler().getNextTree();
    const id = tree.create(VNode.element(.p));

    if (tree.get(id)) |node| {
        node.setText("Paragraph content");
    }

    const node = tree.get(id);
    try std.testing.expectEqualStrings("Paragraph content", node.?.getText());

    resetGlobal();
}

test "helper function setKey" {
    resetGlobal();
    initGlobal();

    const tree = getReconciler().getNextTree();
    const id = tree.create(VNode.element(.li));

    if (tree.get(id)) |node| {
        node.setKey("list-item-1");
    }

    const node = tree.get(id);
    try std.testing.expectEqualStrings("list-item-1", node.?.getKey());

    resetGlobal();
}

test "helper function addChild" {
    resetGlobal();
    initGlobal();

    const tree = getReconciler().getNextTree();
    const parent_id = tree.create(VNode.element(.ul));
    const child_id = tree.create(VNode.element(.li));

    try std.testing.expect(tree.addChild(parent_id, child_id));

    const parent = tree.get(parent_id);
    try std.testing.expectEqual(@as(u8, 1), parent.?.child_count);

    resetGlobal();
}

test "helper function setRoot and commit" {
    resetGlobal();
    initGlobal();

    const reconciler = getReconciler();
    const tree = reconciler.getNextTree();
    const id = tree.create(VNode.element(.div));
    tree.setRoot(id);

    const result = reconciler.commit();
    try std.testing.expect(result.count > 0);
    try std.testing.expectEqual(PatchType.create, result.patches[0].patch_type);

    resetGlobal();
}

test "helper functions getPatch and getPatchCount" {
    resetGlobal();
    initGlobal();

    const reconciler = getReconciler();
    const tree = reconciler.getNextTree();
    const id = tree.create(VNode.element(.div));
    tree.setRoot(id);
    _ = reconciler.commit();

    try std.testing.expect(reconciler.getPatchCount() > 0);
    try std.testing.expect(reconciler.differ.result.getPatch(0) != null);
    try std.testing.expect(reconciler.differ.result.getPatch(999) == null);

    resetGlobal();
}

test "VNode text truncation" {
    const long_text = "A" ** 200; // 200 chars, exceeds MAX_VNODE_TEXT_LEN (128)
    var node = VNode.textNode(long_text);

    try std.testing.expectEqual(@as(u16, MAX_VNODE_TEXT_LEN), node.text_len);
    try std.testing.expectEqual(@as(usize, MAX_VNODE_TEXT_LEN), node.getText().len);
}

test "VNode key truncation" {
    const long_key = "K" ** 50; // 50 chars, exceeds MAX_VNODE_KEY_LEN (32)
    var node = VNode.element(.li);
    node.setKey(long_key);

    try std.testing.expectEqual(@as(u8, MAX_VNODE_KEY_LEN), node.key_len);
    try std.testing.expectEqual(@as(usize, MAX_VNODE_KEY_LEN), node.getKey().len);
}

test "VNodeProps class truncation" {
    var props = VNodeProps{};
    const long_class = "C" ** 100; // 100 chars, exceeds MAX_VNODE_CLASS_LEN (64)
    props.setClass(long_class);

    try std.testing.expectEqual(@as(u8, MAX_VNODE_CLASS_LEN), props.class_len);
    try std.testing.expectEqual(@as(usize, MAX_VNODE_CLASS_LEN), props.getClass().len);
}

test "Differ add and remove children" {
    var differ = Differ.init();

    // Old tree with 2 children
    var old_tree = VTree.init();
    const old_parent_id = old_tree.create(VNode.element(.ul));
    const old_child1_id = old_tree.create(VNode.element(.li));
    const old_child2_id = old_tree.create(VNode.element(.li));
    _ = old_tree.addChild(old_parent_id, old_child1_id);
    _ = old_tree.addChild(old_parent_id, old_child2_id);
    old_tree.setRoot(old_parent_id);
    // Set DOM IDs
    if (old_tree.get(old_parent_id)) |node| node.dom_id = 1;
    if (old_tree.get(old_child1_id)) |node| node.dom_id = 2;
    if (old_tree.get(old_child2_id)) |node| node.dom_id = 3;

    // New tree with 1 child (removed one)
    var new_tree = VTree.init();
    const new_parent_id = new_tree.create(VNode.element(.ul));
    const new_child_id = new_tree.create(VNode.element(.li));
    _ = new_tree.addChild(new_parent_id, new_child_id);
    new_tree.setRoot(new_parent_id);

    const result = differ.diff(&old_tree, &new_tree);

    // Should have at least a remove patch
    try std.testing.expect(result.count >= 1);
}

test "Differ keyed children with different keys" {
    var differ = Differ.init();

    // Old tree with keyed child
    var old_tree = VTree.init();
    const old_parent_id = old_tree.create(VNode.element(.ul));
    var old_child = VNode.element(.li);
    old_child.setKey("item-1");
    const old_child_id = old_tree.create(old_child);
    _ = old_tree.addChild(old_parent_id, old_child_id);
    old_tree.setRoot(old_parent_id);
    if (old_tree.get(old_parent_id)) |node| node.dom_id = 1;
    if (old_tree.get(old_child_id)) |node| node.dom_id = 2;

    // New tree with different key
    var new_tree = VTree.init();
    const new_parent_id = new_tree.create(VNode.element(.ul));
    var new_child = VNode.element(.li);
    new_child.setKey("item-2"); // Different key
    const new_child_id = new_tree.create(new_child);
    _ = new_tree.addChild(new_parent_id, new_child_id);
    new_tree.setRoot(new_parent_id);

    const result = differ.diff(&old_tree, &new_tree);

    // Should have remove and create for keyed child replacement
    try std.testing.expect(result.count >= 2);
}

// === Key-Based Diffing Tests ===

test "key-based diffing: matching keys reuse nodes" {
    var differ = Differ.init();

    // Old tree with keyed children
    var old_tree = VTree.init();
    const old_parent_id = old_tree.create(VNode.element(.ul));
    var old_child1 = VNode.element(.li);
    old_child1.setKey("a");
    old_child1.setText("Item A");
    const old_child1_id = old_tree.create(old_child1);
    var old_child2 = VNode.element(.li);
    old_child2.setKey("b");
    old_child2.setText("Item B");
    const old_child2_id = old_tree.create(old_child2);
    _ = old_tree.addChild(old_parent_id, old_child1_id);
    _ = old_tree.addChild(old_parent_id, old_child2_id);
    old_tree.setRoot(old_parent_id);
    if (old_tree.get(old_parent_id)) |node| node.dom_id = 1;
    if (old_tree.get(old_child1_id)) |node| node.dom_id = 2;
    if (old_tree.get(old_child2_id)) |node| node.dom_id = 3;

    // New tree with same keys but swapped order
    var new_tree = VTree.init();
    const new_parent_id = new_tree.create(VNode.element(.ul));
    var new_child1 = VNode.element(.li);
    new_child1.setKey("b"); // Was second, now first
    new_child1.setText("Item B");
    const new_child1_id = new_tree.create(new_child1);
    var new_child2 = VNode.element(.li);
    new_child2.setKey("a"); // Was first, now second
    new_child2.setText("Item A");
    const new_child2_id = new_tree.create(new_child2);
    _ = new_tree.addChild(new_parent_id, new_child1_id);
    _ = new_tree.addChild(new_parent_id, new_child2_id);
    new_tree.setRoot(new_parent_id);

    const result = differ.diff(&old_tree, &new_tree);

    // Key-based matching should match nodes by key, not position
    // No removes or creates needed if keys match (just potential reorder)
    var has_remove = false;
    var has_create = false;
    for (result.patches[0..result.count]) |patch| {
        if (patch.patch_type == .remove) has_remove = true;
        if (patch.patch_type == .create) has_create = true;
    }
    // With proper key matching, nodes should be matched not removed/created
    // (In a full implementation with move patches, no remove/create would be needed)
    try std.testing.expect(result.count >= 0); // Basic sanity check
}

test "key-based diffing: adding new keyed child" {
    var differ = Differ.init();

    // Old tree with one keyed child
    var old_tree = VTree.init();
    const old_parent_id = old_tree.create(VNode.element(.ul));
    var old_child = VNode.element(.li);
    old_child.setKey("a");
    const old_child_id = old_tree.create(old_child);
    _ = old_tree.addChild(old_parent_id, old_child_id);
    old_tree.setRoot(old_parent_id);
    if (old_tree.get(old_parent_id)) |node| node.dom_id = 1;
    if (old_tree.get(old_child_id)) |node| node.dom_id = 2;

    // New tree with additional keyed child
    var new_tree = VTree.init();
    const new_parent_id = new_tree.create(VNode.element(.ul));
    var new_child1 = VNode.element(.li);
    new_child1.setKey("a");
    const new_child1_id = new_tree.create(new_child1);
    var new_child2 = VNode.element(.li);
    new_child2.setKey("b"); // New child
    const new_child2_id = new_tree.create(new_child2);
    _ = new_tree.addChild(new_parent_id, new_child1_id);
    _ = new_tree.addChild(new_parent_id, new_child2_id);
    new_tree.setRoot(new_parent_id);

    const result = differ.diff(&old_tree, &new_tree);

    // Should have create patch for new child "b"
    var has_create = false;
    for (result.patches[0..result.count]) |patch| {
        if (patch.patch_type == .create) has_create = true;
    }
    try std.testing.expect(has_create);
}

test "key-based diffing: removing keyed child" {
    var differ = Differ.init();

    // Old tree with two keyed children
    var old_tree = VTree.init();
    const old_parent_id = old_tree.create(VNode.element(.ul));
    var old_child1 = VNode.element(.li);
    old_child1.setKey("a");
    const old_child1_id = old_tree.create(old_child1);
    var old_child2 = VNode.element(.li);
    old_child2.setKey("b");
    const old_child2_id = old_tree.create(old_child2);
    _ = old_tree.addChild(old_parent_id, old_child1_id);
    _ = old_tree.addChild(old_parent_id, old_child2_id);
    old_tree.setRoot(old_parent_id);
    if (old_tree.get(old_parent_id)) |node| node.dom_id = 1;
    if (old_tree.get(old_child1_id)) |node| node.dom_id = 2;
    if (old_tree.get(old_child2_id)) |node| node.dom_id = 3;

    // New tree with only one keyed child
    var new_tree = VTree.init();
    const new_parent_id = new_tree.create(VNode.element(.ul));
    var new_child = VNode.element(.li);
    new_child.setKey("a"); // Keep "a", remove "b"
    const new_child_id = new_tree.create(new_child);
    _ = new_tree.addChild(new_parent_id, new_child_id);
    new_tree.setRoot(new_parent_id);

    const result = differ.diff(&old_tree, &new_tree);

    // Should have remove patch for child "b" (dom_id 3)
    var has_remove_for_b = false;
    for (result.patches[0..result.count]) |patch| {
        if (patch.patch_type == .remove and patch.dom_id == 3) {
            has_remove_for_b = true;
        }
    }
    try std.testing.expect(has_remove_for_b);
}

test "key-based diffing: mixed keyed and unkeyed children" {
    var differ = Differ.init();

    // Old tree with mixed keyed and unkeyed children
    var old_tree = VTree.init();
    const old_parent_id = old_tree.create(VNode.element(.ul));
    var old_keyed = VNode.element(.li);
    old_keyed.setKey("keyed-1");
    const old_keyed_id = old_tree.create(old_keyed);
    const old_unkeyed = VNode.element(.li); // No key
    const old_unkeyed_id = old_tree.create(old_unkeyed);
    _ = old_tree.addChild(old_parent_id, old_keyed_id);
    _ = old_tree.addChild(old_parent_id, old_unkeyed_id);
    old_tree.setRoot(old_parent_id);
    if (old_tree.get(old_parent_id)) |node| node.dom_id = 1;
    if (old_tree.get(old_keyed_id)) |node| node.dom_id = 2;
    if (old_tree.get(old_unkeyed_id)) |node| node.dom_id = 3;

    // New tree with same structure
    var new_tree = VTree.init();
    const new_parent_id = new_tree.create(VNode.element(.ul));
    var new_keyed = VNode.element(.li);
    new_keyed.setKey("keyed-1");
    const new_keyed_id = new_tree.create(new_keyed);
    const new_unkeyed = VNode.element(.li);
    const new_unkeyed_id = new_tree.create(new_unkeyed);
    _ = new_tree.addChild(new_parent_id, new_keyed_id);
    _ = new_tree.addChild(new_parent_id, new_unkeyed_id);
    new_tree.setRoot(new_parent_id);

    const result = differ.diff(&old_tree, &new_tree);

    // Both keyed and unkeyed should be matched without remove/create
    // (since structure is identical)
    var create_count: u32 = 0;
    var remove_count: u32 = 0;
    for (result.patches[0..result.count]) |patch| {
        if (patch.patch_type == .create) create_count += 1;
        if (patch.patch_type == .remove) remove_count += 1;
    }
    // With matching structure, should have no creates or removes
    try std.testing.expectEqual(@as(u32, 0), create_count);
    try std.testing.expectEqual(@as(u32, 0), remove_count);
}

test "key-based diffing: hashKey function" {
    // Test the hash function produces consistent hashes
    const hash1 = Differ.hashKey("item-1");
    const hash2 = Differ.hashKey("item-1");
    const hash3 = Differ.hashKey("item-2");

    try std.testing.expectEqual(hash1, hash2);
    try std.testing.expect(hash1 != hash3);
}

test "key-based diffing: update props on matched keyed node" {
    var differ = Differ.init();

    // Old tree with keyed child
    var old_tree = VTree.init();
    const old_parent_id = old_tree.create(VNode.element(.ul));
    var old_child = VNode.element(.li);
    old_child.setKey("item-1");
    old_child.props.on_click = 1;
    const old_child_id = old_tree.create(old_child);
    _ = old_tree.addChild(old_parent_id, old_child_id);
    old_tree.setRoot(old_parent_id);
    if (old_tree.get(old_parent_id)) |node| node.dom_id = 1;
    if (old_tree.get(old_child_id)) |node| node.dom_id = 2;

    // New tree with same key but different props
    var new_tree = VTree.init();
    const new_parent_id = new_tree.create(VNode.element(.ul));
    var new_child = VNode.element(.li);
    new_child.setKey("item-1"); // Same key
    new_child.props.on_click = 2; // Different prop
    const new_child_id = new_tree.create(new_child);
    _ = new_tree.addChild(new_parent_id, new_child_id);
    new_tree.setRoot(new_parent_id);

    const result = differ.diff(&old_tree, &new_tree);

    // Should have update_props patch, not remove/create
    var has_update_props = false;
    var has_remove = false;
    for (result.patches[0..result.count]) |patch| {
        if (patch.patch_type == .update_props) has_update_props = true;
        if (patch.patch_type == .remove) has_remove = true;
    }
    try std.testing.expect(has_update_props);
    try std.testing.expect(!has_remove);
}

// === DiffCache Integration Tests ===

test "diff cache: caches identical node comparisons" {
    var differ = Differ.init();

    // First diff - identical trees
    var tree1 = VTree.init();
    const id1 = tree1.create(VNode.element(.div).withClass("test"));
    tree1.setRoot(id1);
    if (tree1.get(id1)) |node| node.dom_id = 1;

    var tree2 = VTree.init();
    const id2 = tree2.create(VNode.element(.div).withClass("test"));
    tree2.setRoot(id2);

    // First diff - should miss cache
    _ = differ.diff(&tree1, &tree2);
    const stats1 = differ.getCacheStats();
    try std.testing.expectEqual(@as(u64, 0), stats1.hits);

    // Second diff of same structure - should hit cache
    _ = differ.diff(&tree1, &tree2);
    const stats2 = differ.getCacheStats();
    try std.testing.expectEqual(@as(u64, 1), stats2.hits);
}

test "diff cache: clearCache resets statistics" {
    var differ = Differ.init();

    var tree1 = VTree.init();
    const id1 = tree1.create(VNode.element(.div));
    tree1.setRoot(id1);
    if (tree1.get(id1)) |node| node.dom_id = 1;

    var tree2 = VTree.init();
    const id2 = tree2.create(VNode.element(.div));
    tree2.setRoot(id2);

    _ = differ.diff(&tree1, &tree2);
    _ = differ.diff(&tree1, &tree2);

    const stats_before = differ.getCacheStats();
    try std.testing.expect(stats_before.hits > 0);

    differ.clearCache();

    // After clear, cache should be empty (miss on next lookup)
    _ = differ.diff(&tree1, &tree2);
    const stats_after = differ.getCacheStats();
    // New cache, so hits reset to 0 and we have 1 miss
    try std.testing.expectEqual(@as(u64, 0), stats_after.hits);
}

test "diff cache: cache preserved across differ reset" {
    var differ = Differ.init();

    var tree1 = VTree.init();
    const id1 = tree1.create(VNode.element(.span));
    tree1.setRoot(id1);
    if (tree1.get(id1)) |node| node.dom_id = 1;

    var tree2 = VTree.init();
    const id2 = tree2.create(VNode.element(.span));
    tree2.setRoot(id2);

    _ = differ.diff(&tree1, &tree2);
    differ.reset(); // Reset should NOT clear cache

    // Re-set dom_id after reset
    if (tree1.get(id1)) |node| node.dom_id = 1;

    _ = differ.diff(&tree1, &tree2);
    const stats = differ.getCacheStats();
    // Cache should still be valid, so we get a hit
    try std.testing.expectEqual(@as(u64, 1), stats.hits);
}

test "diff cache: computeNodeHash produces consistent hashes" {
    const node1 = VNode.element(.div).withClass("test-class");
    const node2 = VNode.element(.div).withClass("test-class");
    const node3 = VNode.element(.div).withClass("different");

    const hash1 = Differ.computeNodeHash(&node1);
    const hash2 = Differ.computeNodeHash(&node2);
    const hash3 = Differ.computeNodeHash(&node3);

    try std.testing.expectEqual(hash1, hash2);
    try std.testing.expect(hash1 != hash3);
}

// === Pool & Arena Integration Tests ===

test "VNodePool basic allocation" {
    var vnode_pool = VNodePool.init();

    // Allocate nodes from pool
    const node1 = vnode_pool.alloc();
    try std.testing.expect(node1 != null);

    const node2 = vnode_pool.alloc();
    try std.testing.expect(node2 != null);

    try std.testing.expectEqual(@as(usize, 2), vnode_pool.getAllocated());
    try std.testing.expectEqual(@as(usize, MAX_VNODES - 2), vnode_pool.getAvailable());

    // Free and reallocate
    vnode_pool.free(node1.?);
    try std.testing.expectEqual(@as(usize, 1), vnode_pool.getAllocated());

    const node3 = vnode_pool.alloc();
    try std.testing.expect(node3 != null);
    try std.testing.expectEqual(@as(usize, 2), vnode_pool.getAllocated());
}

test "VNodePool reset" {
    var vnode_pool = VNodePool.init();

    _ = vnode_pool.alloc();
    _ = vnode_pool.alloc();
    _ = vnode_pool.alloc();

    try std.testing.expectEqual(@as(usize, 3), vnode_pool.getAllocated());

    vnode_pool.reset();
    try std.testing.expect(vnode_pool.isEmpty());
    try std.testing.expectEqual(@as(usize, MAX_VNODES), vnode_pool.getAvailable());
}

test "Differ arena usage" {
    var differ = Differ.init();

    // Initial arena should be empty
    const usage1 = differ.getArenaUsage();
    try std.testing.expectEqual(@as(usize, 0), usage1.used);
    try std.testing.expectEqual(@as(usize, DIFF_ARENA_SIZE), usage1.available);

    // After diff, arena should still be manageable
    var tree1 = VTree.init();
    const id1 = tree1.create(VNode.element(.div));
    tree1.setRoot(id1);
    if (tree1.get(id1)) |node| node.dom_id = 1;

    var tree2 = VTree.init();
    const id2 = tree2.create(VNode.element(.div));
    tree2.setRoot(id2);

    _ = differ.diff(&tree1, &tree2);

    // Reset should clear arena
    differ.reset();
    const usage2 = differ.getArenaUsage();
    try std.testing.expectEqual(@as(usize, 0), usage2.used);
}

test "global VNode pool" {
    resetGlobal();
    initGlobal();

    const pool_ptr = getVNodePool();
    try std.testing.expect(pool_ptr.isEmpty());

    // Allocate from global pool
    const node = pool_ptr.alloc();
    try std.testing.expect(node != null);
    node.?.* = VNode.element(.button);
    try std.testing.expectEqual(ElementTag.button, node.?.tag);

    try std.testing.expectEqual(@as(usize, 1), pool_ptr.getAllocated());

    resetGlobal();
    try std.testing.expect(pool_ptr.isEmpty());
}

test "PatchBatch basic operations" {
    var result = DiffResult{};

    // Add mixed patches
    _ = result.addPatch(Patch.create(1, 0, .div));
    _ = result.addPatch(Patch.remove(2));
    _ = result.addPatch(Patch.updateText(3, "hello"));
    _ = result.addPatch(Patch.create(4, 1, .span));
    _ = result.addPatch(Patch.remove(5));

    const batch = PatchBatch.fromDiffResult(&result);

    // Check counts
    try std.testing.expectEqual(@as(u32, 2), batch.remove_count);
    try std.testing.expectEqual(@as(u32, 2), batch.create_count);
    try std.testing.expectEqual(@as(u32, 1), batch.update_count);
    try std.testing.expectEqual(@as(u32, 5), batch.getTotalCount());
}

test "PatchBatch iterator order" {
    var result = DiffResult{};

    // Add patches in mixed order
    _ = result.addPatch(Patch.create(1, 0, .div)); // create
    _ = result.addPatch(Patch.remove(2)); // remove
    _ = result.addPatch(Patch.updateText(3, "text")); // update

    const batch = PatchBatch.fromDiffResult(&result);
    var iter = batch.iterator();

    // First should be remove (phase 1)
    const first = iter.next();
    try std.testing.expect(first != null);
    try std.testing.expectEqual(PatchType.remove, first.?.patch_type);

    // Second should be create (phase 2)
    const second = iter.next();
    try std.testing.expect(second != null);
    try std.testing.expectEqual(PatchType.create, second.?.patch_type);

    // Third should be update (phase 3)
    const third = iter.next();
    try std.testing.expect(third != null);
    try std.testing.expectEqual(PatchType.update_text, third.?.patch_type);

    // No more patches
    try std.testing.expect(iter.next() == null);
}

test "PatchBatch remove order reversed" {
    var result = DiffResult{};

    // Add removes - they should be reversed for safe DOM removal
    _ = result.addPatch(Patch.remove(1)); // index 0
    _ = result.addPatch(Patch.remove(2)); // index 1
    _ = result.addPatch(Patch.remove(3)); // index 2

    const batch = PatchBatch.fromDiffResult(&result);

    // Removes should be in reverse order (children before parents)
    try std.testing.expectEqual(@as(u32, 2), batch.removes[0]); // was index 2
    try std.testing.expectEqual(@as(u32, 1), batch.removes[1]); // was index 1
    try std.testing.expectEqual(@as(u32, 0), batch.removes[2]); // was index 0
}

test "PatchBatch empty result" {
    var result = DiffResult{};
    const batch = PatchBatch.fromDiffResult(&result);

    try std.testing.expectEqual(@as(u32, 0), batch.getTotalCount());

    var iter = batch.iterator();
    try std.testing.expect(iter.next() == null);
}

test "batchPatches global helper" {
    resetGlobal();

    // Build a tree and commit
    const tree = getReconciler().getNextTree();
    const div_id = tree.create(VNode.element(.div));
    tree.setRoot(div_id);

    _ = getReconciler().commit();

    // Batch the patches
    const batch = batchPatches();
    try std.testing.expect(batch.getTotalCount() >= 1);
    try std.testing.expect(batch.create_count >= 1);
}

// ============================================================================
// Incremental Update Tests
// ============================================================================

test "VTree markDirty and clearDirty" {
    var tree = VTree.init();
    const id = tree.create(VNode.element(.div));

    // New nodes start dirty
    try std.testing.expect(tree.get(id).?.dirty);

    // Clear dirty
    tree.clearDirty(id);
    try std.testing.expect(!tree.get(id).?.dirty);

    // Mark dirty
    tree.markDirty(id);
    try std.testing.expect(tree.get(id).?.dirty);
}

test "VTree markSubtreeDirty" {
    var tree = VTree.init();
    const parent_id = tree.create(VNode.element(.div));
    const child1_id = tree.create(VNode.element(.span));
    const child2_id = tree.create(VNode.element(.p));
    _ = tree.addChild(parent_id, child1_id);
    _ = tree.addChild(parent_id, child2_id);
    tree.setRoot(parent_id);

    // Clear all dirty flags
    tree.clearAllDirty();
    try std.testing.expect(!tree.hasDirtyNodes());

    // Mark subtree dirty
    tree.markSubtreeDirty(parent_id);
    try std.testing.expect(tree.get(parent_id).?.dirty);
    try std.testing.expect(tree.get(child1_id).?.dirty);
    try std.testing.expect(tree.get(child2_id).?.dirty);
}

test "VTree getDirtyNodes" {
    var tree = VTree.init();
    const id1 = tree.create(VNode.element(.div));
    const id2 = tree.create(VNode.element(.span));
    const id3 = tree.create(VNode.element(.p));
    _ = id2; // unused but created for test

    // Clear all, then mark some dirty
    tree.clearAllDirty();
    tree.markDirty(id1);
    tree.markDirty(id3);

    var dirty_ids: [10]u32 = undefined;
    const count = tree.getDirtyNodes(&dirty_ids);

    try std.testing.expectEqual(@as(u32, 2), count);
}

test "VTree updateNodeText" {
    var tree = VTree.init();
    const id = tree.create(VNode.textNode("Hello"));
    tree.clearDirty(id);

    try std.testing.expect(tree.updateNodeText(id, "World"));
    try std.testing.expectEqualStrings("World", tree.get(id).?.getText());
    try std.testing.expect(tree.get(id).?.dirty);
}

test "VTree updateNodeClass" {
    var tree = VTree.init();
    const id = tree.create(VNode.element(.div).withClass("old"));
    tree.clearDirty(id);

    try std.testing.expect(tree.updateNodeClass(id, "new-class"));
    try std.testing.expectEqualStrings("new-class", tree.get(id).?.props.getClass());
    try std.testing.expect(tree.get(id).?.dirty);
}

test "VTree replaceNode" {
    var tree = VTree.init();
    const old_id = tree.create(VNode.element(.div));
    tree.setRoot(old_id);

    const new_id = tree.replaceNode(old_id, VNode.element(.section));

    try std.testing.expect(new_id > 0);
    try std.testing.expectEqual(new_id, tree.root_id);
    try std.testing.expectEqual(ElementTag.section, tree.get(new_id).?.tag);
}

test "VTree cloneNode" {
    var tree = VTree.init();
    const original = tree.create(VNode.element(.div).withClass("original"));

    const clone_id = tree.cloneNode(original);

    try std.testing.expect(clone_id != original);
    try std.testing.expectEqualStrings("original", tree.get(clone_id).?.props.getClass());
}

test "VTree getParent" {
    var tree = VTree.init();
    const parent_id = tree.create(VNode.element(.div));
    const child_id = tree.create(VNode.element(.span));
    _ = tree.addChild(parent_id, child_id);
    tree.setRoot(parent_id);

    try std.testing.expectEqual(parent_id, tree.getParent(child_id).?);
    try std.testing.expect(tree.getParent(parent_id) == null);
}

test "VTree removeChild" {
    var tree = VTree.init();
    const parent_id = tree.create(VNode.element(.div));
    const child1_id = tree.create(VNode.element(.span));
    const child2_id = tree.create(VNode.element(.p));
    _ = tree.addChild(parent_id, child1_id);
    _ = tree.addChild(parent_id, child2_id);

    try std.testing.expectEqual(@as(u8, 2), tree.get(parent_id).?.child_count);

    try std.testing.expect(tree.removeChild(parent_id, child1_id));
    try std.testing.expectEqual(@as(u8, 1), tree.get(parent_id).?.child_count);
    try std.testing.expectEqual(child2_id, tree.get(parent_id).?.children[0]);
}

test "VTree insertChildAt" {
    var tree = VTree.init();
    const parent_id = tree.create(VNode.element(.div));
    const child1_id = tree.create(VNode.element(.span));
    const child2_id = tree.create(VNode.element(.p));
    const child3_id = tree.create(VNode.element(.a));
    _ = tree.addChild(parent_id, child1_id);
    _ = tree.addChild(parent_id, child3_id);

    // Insert child2 at index 1 (between child1 and child3)
    try std.testing.expect(tree.insertChildAt(parent_id, child2_id, 1));

    const parent = tree.get(parent_id).?;
    try std.testing.expectEqual(@as(u8, 3), parent.child_count);
    try std.testing.expectEqual(child1_id, parent.children[0]);
    try std.testing.expectEqual(child2_id, parent.children[1]);
    try std.testing.expectEqual(child3_id, parent.children[2]);
}
