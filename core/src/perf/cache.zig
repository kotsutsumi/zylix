//! LRU Cache for VDOM Diff Results
//!
//! Caches diff results to avoid recomputing identical comparisons.
//! Uses a fixed-size LRU eviction policy.

const std = @import("std");
const simd = @import("simd.zig");

// ============================================================================
// LRU Cache
// ============================================================================

/// Fixed-size LRU cache with O(1) lookup and O(1) eviction
pub fn LRUCache(comptime K: type, comptime V: type, comptime capacity: usize) type {
    return struct {
        const Self = @This();

        /// Cache entry
        const Entry = struct {
            key: K,
            value: V,
            prev: ?usize,
            next: ?usize,
            valid: bool,
        };

        /// Storage
        entries: [capacity]Entry = undefined,

        /// LRU list head (most recently used)
        head: ?usize = null,

        /// LRU list tail (least recently used)
        tail: ?usize = null,

        /// Number of valid entries
        count: usize = 0,

        /// Cache statistics
        hits: u64 = 0,
        misses: u64 = 0,

        pub fn init() Self {
            var self = Self{};
            for (&self.entries) |*entry| {
                entry.valid = false;
                entry.prev = null;
                entry.next = null;
            }
            return self;
        }

        /// Look up a value by key
        pub fn get(self: *Self, key: K) ?V {
            for (self.entries[0..capacity], 0..) |*entry, i| {
                if (entry.valid and self.keysEqual(entry.key, key)) {
                    self.hits += 1;
                    self.moveToFront(i);
                    return entry.value;
                }
            }
            self.misses += 1;
            return null;
        }

        /// Insert or update a key-value pair
        pub fn put(self: *Self, key: K, value: V) void {
            // Check if key already exists
            for (self.entries[0..capacity], 0..) |*entry, i| {
                if (entry.valid and self.keysEqual(entry.key, key)) {
                    entry.value = value;
                    self.moveToFront(i);
                    return;
                }
            }

            // Find slot for new entry
            var slot: usize = undefined;
            if (self.count < capacity) {
                // Find first invalid slot
                for (self.entries[0..capacity], 0..) |*entry, i| {
                    if (!entry.valid) {
                        slot = i;
                        break;
                    }
                }
                self.count += 1;
            } else {
                // Evict LRU (tail)
                slot = self.tail.?;
                self.removeFromList(slot);
            }

            // Insert new entry
            self.entries[slot] = .{
                .key = key,
                .value = value,
                .prev = null,
                .next = self.head,
                .valid = true,
            };

            if (self.head) |h| {
                self.entries[h].prev = slot;
            }
            self.head = slot;
            if (self.tail == null) {
                self.tail = slot;
            }
        }

        /// Remove entry from LRU list
        fn removeFromList(self: *Self, idx: usize) void {
            const entry = &self.entries[idx];

            if (entry.prev) |p| {
                self.entries[p].next = entry.next;
            } else {
                self.head = entry.next;
            }

            if (entry.next) |n| {
                self.entries[n].prev = entry.prev;
            } else {
                self.tail = entry.prev;
            }

            entry.prev = null;
            entry.next = null;
        }

        /// Move entry to front of LRU list
        fn moveToFront(self: *Self, idx: usize) void {
            if (self.head == idx) return;

            self.removeFromList(idx);

            self.entries[idx].next = self.head;
            self.entries[idx].prev = null;

            if (self.head) |h| {
                self.entries[h].prev = idx;
            }
            self.head = idx;

            if (self.tail == null) {
                self.tail = idx;
            }
        }

        /// Compare keys for equality
        fn keysEqual(self: *const Self, a: K, b: K) bool {
            _ = self;
            if (K == []const u8) {
                return simd.simdMemEql(a, b);
            } else {
                return a == b;
            }
        }

        /// Clear all entries
        pub fn clear(self: *Self) void {
            for (&self.entries) |*entry| {
                entry.valid = false;
                entry.prev = null;
                entry.next = null;
            }
            self.head = null;
            self.tail = null;
            self.count = 0;
        }

        /// Get cache statistics
        pub fn getStats(self: *const Self) struct { hits: u64, misses: u64, hit_rate: f64 } {
            const total = self.hits + self.misses;
            const hit_rate = if (total > 0) @as(f64, @floatFromInt(self.hits)) / @as(f64, @floatFromInt(total)) else 0.0;
            return .{
                .hits = self.hits,
                .misses = self.misses,
                .hit_rate = hit_rate,
            };
        }

        /// Get number of cached entries
        pub fn getCount(self: *const Self) usize {
            return self.count;
        }
    };
}

// ============================================================================
// Hash-based Cache (faster lookup for large caches)
// ============================================================================

/// Hash-based cache with O(1) average lookup
pub fn HashCache(comptime V: type, comptime capacity: usize) type {
    return struct {
        const Self = @This();

        const Entry = struct {
            key_hash: u32,
            value: V,
            valid: bool,
        };

        entries: [capacity]Entry = undefined,
        count: usize = 0,
        hits: u64 = 0,
        misses: u64 = 0,

        pub fn init() Self {
            var self = Self{};
            for (&self.entries) |*entry| {
                entry.valid = false;
            }
            return self;
        }

        /// Get value by key (using pre-computed hash)
        pub fn getByHash(self: *Self, key_hash: u32) ?V {
            const idx = key_hash % capacity;
            const entry = &self.entries[idx];

            if (entry.valid and entry.key_hash == key_hash) {
                self.hits += 1;
                return entry.value;
            }
            self.misses += 1;
            return null;
        }

        /// Get value by string key
        pub fn get(self: *Self, key: []const u8) ?V {
            return self.getByHash(simd.simdHashKey(key));
        }

        /// Put value with pre-computed hash
        pub fn putByHash(self: *Self, key_hash: u32, value: V) void {
            const idx = key_hash % capacity;
            const entry = &self.entries[idx];

            if (!entry.valid) {
                self.count += 1;
            }

            entry.key_hash = key_hash;
            entry.value = value;
            entry.valid = true;
        }

        /// Put value by string key
        pub fn put(self: *Self, key: []const u8, value: V) void {
            self.putByHash(simd.simdHashKey(key), value);
        }

        /// Clear all entries
        pub fn clear(self: *Self) void {
            for (&self.entries) |*entry| {
                entry.valid = false;
            }
            self.count = 0;
        }

        /// Get statistics
        pub fn getStats(self: *const Self) struct { hits: u64, misses: u64, hit_rate: f64 } {
            const total = self.hits + self.misses;
            const hit_rate = if (total > 0) @as(f64, @floatFromInt(self.hits)) / @as(f64, @floatFromInt(total)) else 0.0;
            return .{
                .hits = self.hits,
                .misses = self.misses,
                .hit_rate = hit_rate,
            };
        }
    };
}

// ============================================================================
// Diff Result Cache
// ============================================================================

/// Cached diff result
pub const DiffCacheEntry = struct {
    /// Hash of old node
    old_hash: u32,
    /// Hash of new node
    new_hash: u32,
    /// Whether nodes are equal
    equal: bool,
    /// Number of patches generated
    patch_count: u8,
};

/// Specialized cache for VDOM diff results
pub const DiffCache = struct {
    cache: HashCache(DiffCacheEntry, 256),

    pub fn init() DiffCache {
        return .{
            .cache = HashCache(DiffCacheEntry, 256).init(),
        };
    }

    /// Check if diff result is cached
    pub fn lookup(self: *DiffCache, old_hash: u32, new_hash: u32) ?DiffCacheEntry {
        const combined_hash = old_hash ^ (new_hash *% 31);
        if (self.cache.getByHash(combined_hash)) |entry| {
            if (entry.old_hash == old_hash and entry.new_hash == new_hash) {
                return entry;
            }
        }
        return null;
    }

    /// Store diff result
    pub fn store(self: *DiffCache, old_hash: u32, new_hash: u32, equal: bool, patch_count: u8) void {
        const combined_hash = old_hash ^ (new_hash *% 31);
        self.cache.putByHash(combined_hash, .{
            .old_hash = old_hash,
            .new_hash = new_hash,
            .equal = equal,
            .patch_count = patch_count,
        });
    }

    /// Clear cache
    pub fn clear(self: *DiffCache) void {
        self.cache.clear();
    }

    /// Get statistics
    pub fn getStats(self: *const DiffCache) struct { hits: u64, misses: u64, hit_rate: f64 } {
        return self.cache.getStats();
    }
};

// ============================================================================
// Tests
// ============================================================================

test "LRUCache basic operations" {
    var cache = LRUCache(u32, u32, 3).init();

    cache.put(1, 100);
    cache.put(2, 200);
    cache.put(3, 300);

    try std.testing.expectEqual(@as(?u32, 100), cache.get(1));
    try std.testing.expectEqual(@as(?u32, 200), cache.get(2));
    try std.testing.expectEqual(@as(?u32, 300), cache.get(3));
    try std.testing.expectEqual(@as(?u32, null), cache.get(4));
}

test "LRUCache eviction" {
    var cache = LRUCache(u32, u32, 2).init();

    cache.put(1, 100);
    cache.put(2, 200);

    // Access 1 to make it recently used
    _ = cache.get(1);

    // Add 3, should evict 2 (LRU)
    cache.put(3, 300);

    try std.testing.expectEqual(@as(?u32, 100), cache.get(1));
    try std.testing.expectEqual(@as(?u32, null), cache.get(2)); // Evicted
    try std.testing.expectEqual(@as(?u32, 300), cache.get(3));
}

test "LRUCache statistics" {
    var cache = LRUCache(u32, u32, 2).init();

    cache.put(1, 100);

    _ = cache.get(1); // Hit
    _ = cache.get(1); // Hit
    _ = cache.get(2); // Miss
    _ = cache.get(3); // Miss

    const stats = cache.getStats();
    try std.testing.expectEqual(@as(u64, 2), stats.hits);
    try std.testing.expectEqual(@as(u64, 2), stats.misses);
    try std.testing.expect(stats.hit_rate > 0.49 and stats.hit_rate < 0.51);
}

test "HashCache basic operations" {
    var cache = HashCache(u32, 16).init();

    cache.put("key1", 100);
    cache.put("key2", 200);

    try std.testing.expectEqual(@as(?u32, 100), cache.get("key1"));
    try std.testing.expectEqual(@as(?u32, 200), cache.get("key2"));
    try std.testing.expectEqual(@as(?u32, null), cache.get("key3"));
}

test "DiffCache operations" {
    var cache = DiffCache.init();

    // Store and lookup
    cache.store(100, 200, true, 0);

    const result = cache.lookup(100, 200);
    try std.testing.expect(result != null);
    try std.testing.expect(result.?.equal);
    try std.testing.expectEqual(@as(u8, 0), result.?.patch_count);

    // Miss
    try std.testing.expect(cache.lookup(100, 300) == null);
}
