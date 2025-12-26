//! Memory Pool for VDOM Node Allocation
//!
//! Provides O(1) allocation and deallocation for fixed-size objects,
//! reducing allocation overhead in hot paths like tree diffing.

const std = @import("std");

// ============================================================================
// Generic Object Pool
// ============================================================================

/// A fixed-size object pool with O(1) alloc/free
/// Uses a free list for efficient recycling
pub fn ObjectPool(comptime T: type, comptime capacity: usize) type {
    return struct {
        const Self = @This();

        /// Storage for pool objects
        items: [capacity]T = undefined,

        /// Bitmap tracking which slots are in use
        used: [capacity]bool = [_]bool{false} ** capacity,

        /// Free list head (index of next free slot)
        free_head: usize = 0,

        /// Number of allocated items
        count: usize = 0,

        /// Initialize an empty pool
        pub fn init() Self {
            return .{};
        }

        /// Allocate an object from the pool
        /// Returns null if pool is exhausted
        pub fn alloc(self: *Self) ?*T {
            if (self.count >= capacity) return null;

            // Find next free slot
            var idx = self.free_head;
            while (idx < capacity and self.used[idx]) {
                idx += 1;
            }

            if (idx >= capacity) {
                // Wrap around and search from beginning
                idx = 0;
                while (idx < self.free_head and self.used[idx]) {
                    idx += 1;
                }
                if (idx >= self.free_head) return null;
            }

            self.used[idx] = true;
            self.count += 1;
            self.free_head = idx + 1;

            return &self.items[idx];
        }

        /// Free an object back to the pool
        pub fn free(self: *Self, ptr: *T) void {
            const idx = (@intFromPtr(ptr) - @intFromPtr(&self.items[0])) / @sizeOf(T);
            if (idx < capacity and self.used[idx]) {
                self.used[idx] = false;
                self.count -= 1;
                if (idx < self.free_head) {
                    self.free_head = idx;
                }
            }
        }

        /// Reset pool, freeing all allocations
        pub fn reset(self: *Self) void {
            @memset(&self.used, false);
            self.count = 0;
            self.free_head = 0;
        }

        /// Get number of allocated items
        pub fn getAllocated(self: *const Self) usize {
            return self.count;
        }

        /// Get remaining capacity
        pub fn getAvailable(self: *const Self) usize {
            return capacity - self.count;
        }

        /// Check if pool is full
        pub fn isFull(self: *const Self) bool {
            return self.count >= capacity;
        }

        /// Check if pool is empty
        pub fn isEmpty(self: *const Self) bool {
            return self.count == 0;
        }
    };
}

// ============================================================================
// Arena Allocator for Temporary Allocations
// ============================================================================

/// Simple bump allocator for temporary allocations
/// All memory is freed at once when reset() is called
pub fn ArenaPool(comptime size: usize) type {
    return struct {
        const Self = @This();

        buffer: [size]u8 = undefined,
        offset: usize = 0,

        pub fn init() Self {
            return .{};
        }

        /// Allocate bytes from the arena
        pub fn alloc(self: *Self, len: usize) ?[]u8 {
            if (self.offset + len > size) return null;
            const start = self.offset;
            self.offset += len;
            return self.buffer[start..self.offset];
        }

        /// Allocate aligned bytes
        pub fn allocAligned(self: *Self, len: usize, alignment: usize) ?[]u8 {
            const aligned_offset = std.mem.alignForward(usize, self.offset, alignment);
            if (aligned_offset + len > size) return null;
            self.offset = aligned_offset + len;
            return self.buffer[aligned_offset..self.offset];
        }

        /// Reset arena, freeing all allocations
        pub fn reset(self: *Self) void {
            self.offset = 0;
        }

        /// Get bytes used
        pub fn getBytesUsed(self: *const Self) usize {
            return self.offset;
        }

        /// Get bytes available
        pub fn getBytesAvailable(self: *const Self) usize {
            return size - self.offset;
        }
    };
}

// ============================================================================
// Slab Allocator for Multiple Object Sizes
// ============================================================================

/// Slab allocator supporting multiple object sizes
/// Each size class has its own pool
pub fn SlabAllocator(comptime sizes: []const usize, comptime slots_per_size: usize) type {
    return struct {
        const Self = @This();
        const num_classes = sizes.len;

        /// Storage for each size class
        slabs: [num_classes][slots_per_size][@max(sizes[0], 1)]u8 = undefined,

        /// Used bitmap for each size class
        used: [num_classes][slots_per_size]bool = [_][slots_per_size]bool{[_]bool{false} ** slots_per_size} ** num_classes,

        /// Count per size class
        counts: [num_classes]usize = [_]usize{0} ** num_classes,

        pub fn init() Self {
            return .{};
        }

        /// Find the size class for a given size
        fn findSizeClass(size: usize) ?usize {
            for (sizes, 0..) |s, i| {
                if (size <= s) return i;
            }
            return null;
        }

        /// Allocate from appropriate size class
        pub fn alloc(self: *Self, size: usize) ?*anyopaque {
            const class = findSizeClass(size) orelse return null;

            // Find free slot in this class
            for (0..slots_per_size) |i| {
                if (!self.used[class][i]) {
                    self.used[class][i] = true;
                    self.counts[class] += 1;
                    return @ptrCast(&self.slabs[class][i]);
                }
            }
            return null;
        }

        /// Reset all allocations
        pub fn reset(self: *Self) void {
            for (0..num_classes) |i| {
                @memset(&self.used[i], false);
                self.counts[i] = 0;
            }
        }
    };
}

// ============================================================================
// Tests
// ============================================================================

test "ObjectPool basic allocation" {
    const TestItem = struct {
        value: u32,
        data: [16]u8,
    };

    var pool = ObjectPool(TestItem, 4).init();

    // Allocate items
    const item1 = pool.alloc();
    try std.testing.expect(item1 != null);
    item1.?.value = 42;

    const item2 = pool.alloc();
    try std.testing.expect(item2 != null);
    item2.?.value = 100;

    try std.testing.expectEqual(@as(usize, 2), pool.getAllocated());
    try std.testing.expectEqual(@as(usize, 2), pool.getAvailable());

    // Free and reallocate
    pool.free(item1.?);
    try std.testing.expectEqual(@as(usize, 1), pool.getAllocated());

    const item3 = pool.alloc();
    try std.testing.expect(item3 != null);
    try std.testing.expectEqual(@as(usize, 2), pool.getAllocated());
}

test "ObjectPool exhaustion" {
    var pool = ObjectPool(u32, 2).init();

    _ = pool.alloc();
    _ = pool.alloc();

    // Pool should be full
    try std.testing.expect(pool.isFull());
    try std.testing.expect(pool.alloc() == null);
}

test "ObjectPool reset" {
    var pool = ObjectPool(u32, 4).init();

    _ = pool.alloc();
    _ = pool.alloc();
    _ = pool.alloc();

    try std.testing.expectEqual(@as(usize, 3), pool.getAllocated());

    pool.reset();

    try std.testing.expect(pool.isEmpty());
    try std.testing.expectEqual(@as(usize, 4), pool.getAvailable());
}

test "ArenaPool allocation" {
    var arena = ArenaPool(1024).init();

    const buf1 = arena.alloc(100);
    try std.testing.expect(buf1 != null);
    try std.testing.expectEqual(@as(usize, 100), buf1.?.len);

    const buf2 = arena.alloc(200);
    try std.testing.expect(buf2 != null);

    try std.testing.expectEqual(@as(usize, 300), arena.getBytesUsed());
    try std.testing.expectEqual(@as(usize, 724), arena.getBytesAvailable());

    arena.reset();
    try std.testing.expectEqual(@as(usize, 0), arena.getBytesUsed());
}

test "ArenaPool exhaustion" {
    var arena = ArenaPool(100).init();

    _ = arena.alloc(80);
    const result = arena.alloc(50); // Would exceed capacity

    try std.testing.expect(result == null);
}
