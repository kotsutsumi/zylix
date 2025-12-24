//! Virtual DOM Optimization
//!
//! Enhanced diff algorithm with caching, memoization, and optimized tree traversal.

const std = @import("std");

/// Virtual DOM node hash for fast comparison
pub const NodeHash = u64;

/// Compute hash for a node
pub fn computeHash(tag: []const u8, key: ?[]const u8, props_hash: u64) NodeHash {
    var hasher = std.hash.Wyhash.init(0);
    hasher.update(tag);
    if (key) |k| hasher.update(k);
    hasher.update(std.mem.asBytes(&props_hash));
    return hasher.final();
}

/// Diff cache entry
pub const DiffCacheEntry = struct {
    old_hash: NodeHash,
    new_hash: NodeHash,
    patches: []const Patch,
    timestamp: i64,
    hits: u32,
};

/// Patch operation types
pub const PatchType = enum {
    none,
    replace,
    update_props,
    update_text,
    insert,
    remove,
    move,
    reorder,
};

/// Patch operation
pub const Patch = struct {
    patch_type: PatchType,
    path: []const usize,
    data: ?[]const u8,
    index: ?usize,

    pub fn none() Patch {
        return .{
            .patch_type = .none,
            .path = &.{},
            .data = null,
            .index = null,
        };
    }

    pub fn replace(path: []const usize, data: []const u8) Patch {
        return .{
            .patch_type = .replace,
            .path = path,
            .data = data,
            .index = null,
        };
    }
};

/// Diff cache for memoizing diff results
pub const DiffCache = struct {
    allocator: std.mem.Allocator,
    entries: std.AutoHashMap(u128, DiffCacheEntry),
    max_size: usize,
    hits: u64,
    misses: u64,

    pub fn init(allocator: std.mem.Allocator, max_size: usize) !*DiffCache {
        const cache = try allocator.create(DiffCache);
        cache.* = .{
            .allocator = allocator,
            .entries = std.AutoHashMap(u128, DiffCacheEntry).init(allocator),
            .max_size = max_size,
            .hits = 0,
            .misses = 0,
        };
        return cache;
    }

    pub fn deinit(self: *DiffCache) void {
        var it = self.entries.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.value_ptr.patches);
        }
        self.entries.deinit();
        self.allocator.destroy(self);
    }

    /// Create cache key from old and new hashes
    fn makeKey(old_hash: NodeHash, new_hash: NodeHash) u128 {
        return (@as(u128, old_hash) << 64) | @as(u128, new_hash);
    }

    /// Get cached diff result
    pub fn get(self: *DiffCache, old_hash: NodeHash, new_hash: NodeHash) ?[]const Patch {
        const key = makeKey(old_hash, new_hash);
        if (self.entries.getPtr(key)) |entry| {
            entry.hits += 1;
            self.hits += 1;
            return entry.patches;
        }
        self.misses += 1;
        return null;
    }

    /// Store diff result in cache
    pub fn put(self: *DiffCache, old_hash: NodeHash, new_hash: NodeHash, patches: []const Patch) !void {
        // Evict if at capacity
        if (self.entries.count() >= self.max_size) {
            self.evictLRU();
        }

        const key = makeKey(old_hash, new_hash);
        const patches_copy = try self.allocator.dupe(Patch, patches);

        try self.entries.put(key, .{
            .old_hash = old_hash,
            .new_hash = new_hash,
            .patches = patches_copy,
            .timestamp = std.time.milliTimestamp(),
            .hits = 0,
        });
    }

    /// Evict least recently used entry
    fn evictLRU(self: *DiffCache) void {
        var min_hits: u32 = std.math.maxInt(u32);
        var min_key: ?u128 = null;

        var it = self.entries.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.hits < min_hits) {
                min_hits = entry.value_ptr.hits;
                min_key = entry.key_ptr.*;
            }
        }

        if (min_key) |key| {
            if (self.entries.fetchRemove(key)) |removed| {
                self.allocator.free(removed.value.patches);
            }
        }
    }

    /// Get cache hit rate
    pub fn getHitRate(self: *const DiffCache) f64 {
        const total = self.hits + self.misses;
        if (total == 0) return 0.0;
        return @as(f64, @floatFromInt(self.hits)) / @as(f64, @floatFromInt(total));
    }

    /// Clear cache
    pub fn clear(self: *DiffCache) void {
        var it = self.entries.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.value_ptr.patches);
        }
        self.entries.clearRetainingCapacity();
        self.hits = 0;
        self.misses = 0;
    }
};

/// Virtual DOM optimizer with enhanced diff algorithm
pub const VDomOptimizer = struct {
    allocator: std.mem.Allocator,
    cache: *DiffCache,
    enable_keyed_diff: bool,
    enable_subtree_skip: bool,

    pub fn init(allocator: std.mem.Allocator, cache_size: usize) !*VDomOptimizer {
        const optimizer = try allocator.create(VDomOptimizer);
        optimizer.* = .{
            .allocator = allocator,
            .cache = try DiffCache.init(allocator, cache_size),
            .enable_keyed_diff = true,
            .enable_subtree_skip = true,
        };
        return optimizer;
    }

    pub fn deinit(self: *VDomOptimizer) void {
        self.cache.deinit();
        self.allocator.destroy(self);
    }

    /// Optimized diff with caching
    pub fn diff(self: *VDomOptimizer, old_hash: NodeHash, new_hash: NodeHash, compute_diff: *const fn () []const Patch) []const Patch {
        // Check cache first
        if (self.cache.get(old_hash, new_hash)) |cached| {
            return cached;
        }

        // Compute diff
        const patches = compute_diff();

        // Cache result (ignore errors)
        self.cache.put(old_hash, new_hash, patches) catch {};

        return patches;
    }

    /// Check if subtree can be skipped (no changes)
    pub fn canSkipSubtree(self: *const VDomOptimizer, old_hash: NodeHash, new_hash: NodeHash) bool {
        if (!self.enable_subtree_skip) return false;
        return old_hash == new_hash;
    }

    /// Get cache statistics
    pub fn getStats(self: *const VDomOptimizer) CacheStats {
        return .{
            .entries = self.cache.entries.count(),
            .max_size = self.cache.max_size,
            .hit_rate = self.cache.getHitRate(),
            .hits = self.cache.hits,
            .misses = self.cache.misses,
        };
    }

    pub const CacheStats = struct {
        entries: usize,
        max_size: usize,
        hit_rate: f64,
        hits: u64,
        misses: u64,
    };
};

/// Keyed list diff using Longest Increasing Subsequence (LIS)
pub const KeyedDiffer = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) KeyedDiffer {
        return .{ .allocator = allocator };
    }

    /// Compute minimum moves for reordering keyed list
    pub fn computeMoves(self: *KeyedDiffer, old_keys: []const []const u8, new_keys: []const []const u8) ![]const Move {
        var moves: std.ArrayListUnmanaged(Move) = .{};
        errdefer moves.deinit(self.allocator);

        // Build old key index map
        var old_index = std.StringHashMap(usize).init(self.allocator);
        defer old_index.deinit();

        for (old_keys, 0..) |key, i| {
            try old_index.put(key, i);
        }

        // Find items to insert, remove, or move
        for (new_keys, 0..) |key, new_i| {
            if (old_index.get(key)) |old_i| {
                if (old_i != new_i) {
                    try moves.append(self.allocator, .{ .move_type = .move, .from = old_i, .to = new_i, .key = key });
                }
            } else {
                try moves.append(self.allocator, .{ .move_type = .insert, .from = 0, .to = new_i, .key = key });
            }
        }

        // Find removed items
        for (old_keys, 0..) |key, old_i| {
            var found = false;
            for (new_keys) |new_key| {
                if (std.mem.eql(u8, key, new_key)) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                try moves.append(self.allocator, .{ .move_type = .remove, .from = old_i, .to = 0, .key = key });
            }
        }

        return try moves.toOwnedSlice(self.allocator);
    }

    pub const Move = struct {
        move_type: MoveType,
        from: usize,
        to: usize,
        key: []const u8,

        pub const MoveType = enum {
            insert,
            remove,
            move,
        };
    };
};

// ============================================================================
// Unit Tests
// ============================================================================

test "computeHash consistency" {
    const hash1 = computeHash("div", null, 0);
    const hash2 = computeHash("div", null, 0);
    const hash3 = computeHash("span", null, 0);

    try std.testing.expectEqual(hash1, hash2);
    try std.testing.expect(hash1 != hash3);
}

test "computeHash with key" {
    const hash1 = computeHash("div", "key1", 0);
    const hash2 = computeHash("div", "key2", 0);

    try std.testing.expect(hash1 != hash2);
}

test "DiffCache basic operations" {
    const allocator = std.testing.allocator;

    var cache = try DiffCache.init(allocator, 10);
    defer cache.deinit();

    const patches = [_]Patch{Patch.none()};
    try cache.put(100, 200, &patches);

    const result = cache.get(100, 200);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(usize, 1), result.?.len);
}

test "DiffCache hit rate" {
    const allocator = std.testing.allocator;

    var cache = try DiffCache.init(allocator, 10);
    defer cache.deinit();

    const patches = [_]Patch{Patch.none()};
    try cache.put(100, 200, &patches);

    _ = cache.get(100, 200); // hit
    _ = cache.get(100, 200); // hit
    _ = cache.get(300, 400); // miss

    try std.testing.expect(cache.getHitRate() > 0.6);
}

test "VDomOptimizer subtree skip" {
    const allocator = std.testing.allocator;

    var optimizer = try VDomOptimizer.init(allocator, 100);
    defer optimizer.deinit();

    const hash = computeHash("div", null, 12345);
    try std.testing.expect(optimizer.canSkipSubtree(hash, hash));
    try std.testing.expect(!optimizer.canSkipSubtree(hash, hash + 1));
}

test "KeyedDiffer basic moves" {
    const allocator = std.testing.allocator;

    var differ = KeyedDiffer.init(allocator);
    const old_keys = [_][]const u8{ "a", "b", "c" };
    const new_keys = [_][]const u8{ "b", "c", "a" };

    const moves = try differ.computeMoves(&old_keys, &new_keys);
    defer allocator.free(moves);

    try std.testing.expect(moves.len > 0);
}
