//! Object Pooling System
//!
//! Provides efficient object reuse to minimize allocations and GC pressure
//! during gameplay, particularly useful for bullets, particles, and effects.

const std = @import("std");

/// Pool item state
pub const PoolItemState = enum(u8) {
    available = 0,
    in_use = 1,
};

/// Pool item wrapper
pub fn PoolItem(comptime T: type) type {
    return struct {
        data: T,
        state: PoolItemState = .available,
        generation: u32 = 0,
    };
}

/// Handle to a pooled object
pub fn PoolHandle(comptime T: type) type {
    _ = T;
    return struct {
        index: usize,
        generation: u32,

        pub const invalid = @This(){ .index = std.math.maxInt(usize), .generation = 0 };

        pub fn isValid(self: @This()) bool {
            return self.index != std.math.maxInt(usize);
        }
    };
}

/// Generic object pool
pub fn ObjectPool(comptime T: type) type {
    return struct {
        const Self = @This();
        const Item = PoolItem(T);
        const Handle = PoolHandle(T);

        allocator: std.mem.Allocator,
        items: std.ArrayListUnmanaged(Item) = .{},
        free_list: std.ArrayListUnmanaged(usize) = .{},
        initial_capacity: usize,
        max_capacity: usize,
        auto_expand: bool = true,

        // Statistics
        total_acquired: u64 = 0,
        total_released: u64 = 0,
        peak_usage: usize = 0,

        // Callbacks
        on_create: ?*const fn (*T) void = null,
        on_acquire: ?*const fn (*T) void = null,
        on_release: ?*const fn (*T) void = null,
        on_destroy: ?*const fn (*T) void = null,

        pub fn init(allocator: std.mem.Allocator, initial_capacity: usize) !Self {
            return initEx(allocator, initial_capacity, initial_capacity * 4, true);
        }

        pub fn initEx(allocator: std.mem.Allocator, initial_capacity: usize, max_capacity: usize, auto_expand: bool) !Self {
            var pool = Self{
                .allocator = allocator,
                .initial_capacity = initial_capacity,
                .max_capacity = max_capacity,
                .auto_expand = auto_expand,
            };

            // Pre-allocate items
            try pool.items.ensureTotalCapacity(allocator, initial_capacity);
            try pool.free_list.ensureTotalCapacity(allocator, initial_capacity);

            for (0..initial_capacity) |i| {
                try pool.items.append(allocator, .{ .data = undefined });
                try pool.free_list.append(allocator, i);
            }

            return pool;
        }

        pub fn deinit(self: *Self) void {
            // Call destroy callback for all items
            if (self.on_destroy) |destroy| {
                for (self.items.items) |*item| {
                    destroy(&item.data);
                }
            }

            self.items.deinit(self.allocator);
            self.free_list.deinit(self.allocator);
        }

        pub const PoolError = error{PoolExhausted};

        /// Acquire an object from the pool
        pub fn acquire(self: *Self) (PoolError || std.mem.Allocator.Error)!Handle {
            var index: usize = undefined;

            if (self.free_list.items.len > 0) {
                index = self.free_list.pop();
            } else if (self.auto_expand and self.items.items.len < self.max_capacity) {
                index = self.items.items.len;
                try self.items.append(self.allocator, .{ .data = undefined });

                if (self.on_create) |create| {
                    create(&self.items.items[index].data);
                }
            } else {
                return error.PoolExhausted;
            }

            self.items.items[index].state = .in_use;
            self.items.items[index].generation +%= 1;
            self.total_acquired += 1;

            const current_usage = self.getUsedCount();
            if (current_usage > self.peak_usage) {
                self.peak_usage = current_usage;
            }

            if (self.on_acquire) |acquire_cb| {
                acquire_cb(&self.items.items[index].data);
            }

            return Handle{
                .index = index,
                .generation = self.items.items[index].generation,
            };
        }

        /// Acquire with initialization
        pub fn acquireWith(self: *Self, init_fn: *const fn (*T) void) !Handle {
            const handle = try self.acquire();
            if (!handle.isValid()) return handle;

            init_fn(self.get(handle).?);
            return handle;
        }

        /// Release an object back to the pool
        pub fn release(self: *Self, handle: Handle) void {
            if (!self.isValid(handle)) return;

            const item = &self.items.items[handle.index];

            if (self.on_release) |release_cb| {
                release_cb(&item.data);
            }

            item.state = .available;
            self.free_list.append(self.allocator, handle.index) catch {};
            self.total_released += 1;
        }

        /// Get object by handle
        pub fn get(self: *Self, handle: Handle) ?*T {
            if (!self.isValid(handle)) return null;
            return &self.items.items[handle.index].data;
        }

        /// Check if handle is valid
        pub fn isValid(self: *const Self, handle: Handle) bool {
            if (handle.index >= self.items.items.len) return false;
            const item = self.items.items[handle.index];
            return item.state == .in_use and item.generation == handle.generation;
        }

        /// Get number of available objects
        pub fn getAvailableCount(self: *const Self) usize {
            return self.free_list.items.len;
        }

        /// Get number of objects in use
        pub fn getUsedCount(self: *const Self) usize {
            return self.items.items.len - self.free_list.items.len;
        }

        /// Get total capacity
        pub fn getCapacity(self: *const Self) usize {
            return self.items.items.len;
        }

        /// Clear all objects (release all)
        pub fn releaseAll(self: *Self) void {
            self.free_list.clearRetainingCapacity();

            for (self.items.items, 0..) |*item, i| {
                if (item.state == .in_use) {
                    if (self.on_release) |release_cb| {
                        release_cb(&item.data);
                    }
                    item.state = .available;
                    self.free_list.append(self.allocator, i) catch {};
                }
            }
        }

        /// Iterate over all active items
        pub fn iterator(self: *Self) Iterator {
            return .{ .pool = self, .index = 0 };
        }

        pub const Iterator = struct {
            pool: *Self,
            index: usize,

            pub fn next(self: *Iterator) ?*T {
                while (self.index < self.pool.items.items.len) {
                    const i = self.index;
                    self.index += 1;
                    if (self.pool.items.items[i].state == .in_use) {
                        return &self.pool.items.items[i].data;
                    }
                }
                return null;
            }

            pub fn reset(self: *Iterator) void {
                self.index = 0;
            }
        };

        /// Shrink pool to fit current usage
        pub fn shrinkToFit(self: *Self) void {
            // Only keep items that are in use
            var new_items = std.ArrayListUnmanaged(Item){};
            var new_free_list = std.ArrayListUnmanaged(usize){};

            for (self.items.items) |item| {
                if (item.state == .in_use) {
                    const idx = new_items.items.len;
                    new_items.append(self.allocator, item) catch {};
                    _ = idx;
                }
            }

            // Keep at least initial_capacity
            while (new_items.items.len < self.initial_capacity) {
                const idx = new_items.items.len;
                new_items.append(self.allocator, .{ .data = undefined }) catch {};
                new_free_list.append(self.allocator, idx) catch {};
            }

            self.items.deinit(self.allocator);
            self.free_list.deinit(self.allocator);
            self.items = new_items;
            self.free_list = new_free_list;
        }
    };
}

/// Pool manager for multiple object types
pub const PoolManager = struct {
    allocator: std.mem.Allocator,
    pools: std.StringHashMapUnmanaged(*anyopaque) = .{},

    pub fn init(allocator: std.mem.Allocator) PoolManager {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *PoolManager) void {
        self.pools.deinit(self.allocator);
    }

    pub fn register(self: *PoolManager, comptime T: type, name: []const u8, capacity: usize) !*ObjectPool(T) {
        const pool = try self.allocator.create(ObjectPool(T));
        pool.* = try ObjectPool(T).init(self.allocator, capacity);
        try self.pools.put(self.allocator, name, pool);
        return pool;
    }

    pub fn get(self: *PoolManager, comptime T: type, name: []const u8) ?*ObjectPool(T) {
        const ptr = self.pools.get(name) orelse return null;
        return @ptrCast(@alignCast(ptr));
    }
};

// Common pooled types for games
pub const Bullet = struct {
    x: f32 = 0,
    y: f32 = 0,
    vx: f32 = 0,
    vy: f32 = 0,
    damage: f32 = 1,
    lifetime: f32 = 5,
    owner_id: u32 = 0,
    active: bool = false,
};

pub const Particle = struct {
    x: f32 = 0,
    y: f32 = 0,
    vx: f32 = 0,
    vy: f32 = 0,
    life: f32 = 1,
    max_life: f32 = 1,
    size: f32 = 1,
    rotation: f32 = 0,
    color_r: f32 = 1,
    color_g: f32 = 1,
    color_b: f32 = 1,
    color_a: f32 = 1,
};

pub const FloatingText = struct {
    x: f32 = 0,
    y: f32 = 0,
    text: [32]u8 = undefined,
    text_len: usize = 0,
    lifetime: f32 = 1,
    font_size: f32 = 16,
    color: u32 = 0xFFFFFFFF,

    pub fn setText(self: *FloatingText, text: []const u8) void {
        const len = @min(text.len, 32);
        @memcpy(self.text[0..len], text[0..len]);
        self.text_len = len;
    }

    pub fn getText(self: *const FloatingText) []const u8 {
        return self.text[0..self.text_len];
    }
};

test "ObjectPool basic" {
    const allocator = std.testing.allocator;

    const TestObj = struct { value: i32 = 0 };

    var pool = try ObjectPool(TestObj).init(allocator, 10);
    defer pool.deinit();

    try std.testing.expectEqual(@as(usize, 10), pool.getAvailableCount());
    try std.testing.expectEqual(@as(usize, 0), pool.getUsedCount());

    const handle1 = try pool.acquire();
    try std.testing.expect(handle1.isValid());
    try std.testing.expectEqual(@as(usize, 9), pool.getAvailableCount());

    const obj = pool.get(handle1);
    try std.testing.expect(obj != null);
    obj.?.value = 42;

    pool.release(handle1);
    try std.testing.expectEqual(@as(usize, 10), pool.getAvailableCount());
    try std.testing.expect(!pool.isValid(handle1)); // Generation changed
}

test "ObjectPool handle invalidation" {
    const allocator = std.testing.allocator;

    const TestObj = struct { value: i32 = 0 };

    var pool = try ObjectPool(TestObj).init(allocator, 5);
    defer pool.deinit();

    const handle1 = try pool.acquire();
    pool.release(handle1);

    // Handle should be invalid after release
    try std.testing.expect(!pool.isValid(handle1));

    // New acquisition should work
    const handle2 = try pool.acquire();
    try std.testing.expect(handle2.isValid());

    // Old handle and new handle point to same index but different generation
    try std.testing.expectEqual(handle1.index, handle2.index);
    try std.testing.expect(handle1.generation != handle2.generation);
}

test "ObjectPool iteration" {
    const allocator = std.testing.allocator;

    const TestObj = struct { value: i32 = 0 };

    var pool = try ObjectPool(TestObj).init(allocator, 10);
    defer pool.deinit();

    // Acquire some objects
    const h1 = try pool.acquire();
    const h2 = try pool.acquire();
    const h3 = try pool.acquire();

    pool.get(h1).?.value = 1;
    pool.get(h2).?.value = 2;
    pool.get(h3).?.value = 3;

    var iter = pool.iterator();
    var sum: i32 = 0;
    while (iter.next()) |obj| {
        sum += obj.value;
    }

    try std.testing.expectEqual(@as(i32, 6), sum);
}

test "ObjectPool auto expand" {
    const allocator = std.testing.allocator;

    const TestObj = struct { value: i32 = 0 };

    var pool = try ObjectPool(TestObj).initEx(allocator, 2, 10, true);
    defer pool.deinit();

    // Exhaust initial capacity
    _ = try pool.acquire();
    _ = try pool.acquire();

    // Should auto-expand
    const handle = try pool.acquire();
    try std.testing.expect(handle.isValid());
    try std.testing.expectEqual(@as(usize, 3), pool.getCapacity());
}
