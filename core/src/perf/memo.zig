//! Component-level Memoization
//!
//! Caches component render results based on props hash to skip
//! redundant re-renders when props haven't changed.

const std = @import("std");
const simd = @import("simd.zig");

// ============================================================================
// Memoization Entry
// ============================================================================

/// Cached render result for a component
pub const MemoEntry = struct {
    /// Hash of component props (for comparison)
    props_hash: u32,
    /// Hash of component state
    state_hash: u32,
    /// Number of children when cached
    child_count: u8,
    /// Whether the entry is valid
    valid: bool,
    /// Number of times this cache entry was used
    hit_count: u32,
    /// Last access timestamp (for LRU eviction)
    last_access: u64,

    pub fn init() MemoEntry {
        return .{
            .props_hash = 0,
            .state_hash = 0,
            .child_count = 0,
            .valid = false,
            .hit_count = 0,
            .last_access = 0,
        };
    }
};

// ============================================================================
// Memoization Cache
// ============================================================================

/// Component memoization cache with fixed capacity
pub fn MemoCache(comptime capacity: usize) type {
    return struct {
        const Self = @This();

        /// Cache entries indexed by component ID
        entries: [capacity]MemoEntry = undefined,

        /// Global access counter for LRU
        access_counter: u64 = 0,

        /// Statistics
        hits: u64 = 0,
        misses: u64 = 0,
        invalidations: u64 = 0,

        pub fn init() Self {
            var self = Self{};
            for (&self.entries) |*entry| {
                entry.* = MemoEntry.init();
            }
            return self;
        }

        /// Check if component can use cached render (props unchanged)
        pub fn canSkipRender(self: *Self, component_id: u32, props_hash: u32, state_hash: u32, child_count: u8) bool {
            if (component_id >= capacity) {
                self.misses += 1;
                return false;
            }

            const entry = &self.entries[component_id];

            if (entry.valid and
                entry.props_hash == props_hash and
                entry.state_hash == state_hash and
                entry.child_count == child_count)
            {
                // Cache hit - update access info
                self.access_counter += 1;
                entry.last_access = self.access_counter;
                entry.hit_count += 1;
                self.hits += 1;
                return true;
            }

            self.misses += 1;
            return false;
        }

        /// Store component render result in cache
        pub fn cache(self: *Self, component_id: u32, props_hash: u32, state_hash: u32, child_count: u8) void {
            if (component_id >= capacity) return;

            self.access_counter += 1;
            self.entries[component_id] = .{
                .props_hash = props_hash,
                .state_hash = state_hash,
                .child_count = child_count,
                .valid = true,
                .hit_count = 0,
                .last_access = self.access_counter,
            };
        }

        /// Invalidate cache for a specific component
        pub fn invalidate(self: *Self, component_id: u32) void {
            if (component_id >= capacity) return;

            if (self.entries[component_id].valid) {
                self.entries[component_id].valid = false;
                self.invalidations += 1;
            }
        }

        /// Invalidate cache for component and all its potential children
        pub fn invalidateSubtree(self: *Self, component_id: u32, children: []const u32) void {
            self.invalidate(component_id);
            for (children) |child_id| {
                self.invalidate(child_id);
            }
        }

        /// Clear all cache entries
        pub fn clear(self: *Self) void {
            for (&self.entries) |*entry| {
                entry.* = MemoEntry.init();
            }
            self.hits = 0;
            self.misses = 0;
            self.invalidations = 0;
            self.access_counter = 0;
        }

        /// Get cache statistics
        pub fn getStats(self: *const Self) MemoStats {
            const total = self.hits + self.misses;
            const hit_rate = if (total > 0)
                @as(f64, @floatFromInt(self.hits)) / @as(f64, @floatFromInt(total))
            else
                0.0;

            return .{
                .hits = self.hits,
                .misses = self.misses,
                .invalidations = self.invalidations,
                .hit_rate = hit_rate,
                .cached_count = self.getCachedCount(),
            };
        }

        /// Get number of valid cache entries
        pub fn getCachedCount(self: *const Self) u32 {
            var count: u32 = 0;
            for (self.entries) |entry| {
                if (entry.valid) count += 1;
            }
            return count;
        }

        /// Get entry for inspection
        pub fn getEntry(self: *const Self, component_id: u32) ?*const MemoEntry {
            if (component_id >= capacity) return null;
            if (!self.entries[component_id].valid) return null;
            return &self.entries[component_id];
        }
    };
}

/// Memoization statistics
pub const MemoStats = struct {
    hits: u64,
    misses: u64,
    invalidations: u64,
    hit_rate: f64,
    cached_count: u32,
};

// ============================================================================
// Props Hashing
// ============================================================================

/// Compute hash of component props for memoization comparison
/// Uses SIMD-accelerated hashing where beneficial
pub fn hashProps(props: anytype) u32 {
    const T = @TypeOf(props);
    const bytes = std.mem.asBytes(&props);

    // Use SIMD hash for props larger than 16 bytes
    if (bytes.len >= 16) {
        return simd.simdFnv1a(bytes);
    }

    // Simple DJB2 for smaller structs
    var hash: u32 = 5381;
    for (bytes) |byte| {
        hash = hash *% 33 +% byte;
    }
    return hash;
}

/// Compute hash for VNode props (from vdom.zig)
pub fn hashVNodeProps(
    class: []const u8,
    style_id: u32,
    on_click: u32,
    on_input: u32,
    on_change: u32,
    input_type: u8,
    disabled: bool,
) u32 {
    var hash: u32 = 5381;

    // Hash class using SIMD if long enough
    if (class.len > 0) {
        hash = hash *% 31 +% simd.simdHashKey(class);
    }

    // Hash other fields
    hash = hash *% 31 +% style_id;
    hash = hash *% 31 +% on_click;
    hash = hash *% 31 +% on_input;
    hash = hash *% 31 +% on_change;
    hash = hash *% 31 +% input_type;
    hash = hash *% 31 +% @as(u32, @intFromBool(disabled));

    return hash;
}

/// Compute hash for component state
pub fn hashState(
    hover: bool,
    focus: bool,
    active: bool,
    disabled: bool,
    checked: bool,
    expanded: bool,
    loading: bool,
    error_state: bool,
) u32 {
    var hash: u32 = 0;
    if (hover) hash |= 0x01;
    if (focus) hash |= 0x02;
    if (active) hash |= 0x04;
    if (disabled) hash |= 0x08;
    if (checked) hash |= 0x10;
    if (expanded) hash |= 0x20;
    if (loading) hash |= 0x40;
    if (error_state) hash |= 0x80;
    return hash;
}

// ============================================================================
// Global Memo Cache
// ============================================================================

/// Default cache size for components (matches MAX_COMPONENTS)
pub const DEFAULT_CACHE_SIZE = 256;

/// Global memoization cache
var global_memo_cache: MemoCache(DEFAULT_CACHE_SIZE) = MemoCache(DEFAULT_CACHE_SIZE).init();

pub fn getGlobalMemoCache() *MemoCache(DEFAULT_CACHE_SIZE) {
    return &global_memo_cache;
}

pub fn resetGlobalMemoCache() void {
    global_memo_cache.clear();
}

// ============================================================================
// Tests
// ============================================================================

test "MemoCache basic operations" {
    var cache = MemoCache(16).init();

    // Initially should miss
    try std.testing.expect(!cache.canSkipRender(1, 100, 0, 2));

    // Cache the result
    cache.cache(1, 100, 0, 2);

    // Now should hit
    try std.testing.expect(cache.canSkipRender(1, 100, 0, 2));

    // Different props should miss
    try std.testing.expect(!cache.canSkipRender(1, 200, 0, 2));
}

test "MemoCache invalidation" {
    var cache = MemoCache(16).init();

    cache.cache(1, 100, 0, 2);
    try std.testing.expect(cache.canSkipRender(1, 100, 0, 2));

    cache.invalidate(1);
    try std.testing.expect(!cache.canSkipRender(1, 100, 0, 2));
}

test "MemoCache statistics" {
    var cache = MemoCache(16).init();

    cache.cache(1, 100, 0, 2);
    _ = cache.canSkipRender(1, 100, 0, 2); // hit
    _ = cache.canSkipRender(1, 100, 0, 2); // hit
    _ = cache.canSkipRender(1, 200, 0, 2); // miss (different props)
    _ = cache.canSkipRender(2, 100, 0, 2); // miss (different component)

    const stats = cache.getStats();
    try std.testing.expectEqual(@as(u64, 2), stats.hits);
    try std.testing.expectEqual(@as(u64, 2), stats.misses);
    try std.testing.expect(stats.hit_rate > 0.49 and stats.hit_rate < 0.51);
}

test "MemoCache child count change" {
    var cache = MemoCache(16).init();

    cache.cache(1, 100, 0, 2);
    try std.testing.expect(cache.canSkipRender(1, 100, 0, 2));

    // Child count change should miss
    try std.testing.expect(!cache.canSkipRender(1, 100, 0, 3));
}

test "MemoCache state change" {
    var cache = MemoCache(16).init();

    cache.cache(1, 100, 0, 2);
    try std.testing.expect(cache.canSkipRender(1, 100, 0, 2));

    // State change should miss
    try std.testing.expect(!cache.canSkipRender(1, 100, 1, 2));
}

test "hashVNodeProps consistency" {
    const hash1 = hashVNodeProps("button", 1, 42, 0, 0, 0, false);
    const hash2 = hashVNodeProps("button", 1, 42, 0, 0, 0, false);
    const hash3 = hashVNodeProps("button", 1, 43, 0, 0, 0, false); // different on_click

    try std.testing.expectEqual(hash1, hash2);
    try std.testing.expect(hash1 != hash3);
}

test "hashState" {
    const state1 = hashState(true, false, false, false, false, false, false, false);
    const state2 = hashState(true, false, false, false, false, false, false, false);
    const state3 = hashState(false, true, false, false, false, false, false, false);

    try std.testing.expectEqual(state1, state2);
    try std.testing.expect(state1 != state3);
    try std.testing.expectEqual(@as(u32, 0x01), state1); // hover bit
    try std.testing.expectEqual(@as(u32, 0x02), state3); // focus bit
}

test "global memo cache" {
    resetGlobalMemoCache();

    const cache = getGlobalMemoCache();
    cache.cache(5, 500, 0, 1);

    try std.testing.expect(cache.canSkipRender(5, 500, 0, 1));

    resetGlobalMemoCache();
    try std.testing.expect(!cache.canSkipRender(5, 500, 0, 1));
}
