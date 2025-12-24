//! Memory Pool and Allocation Optimization
//!
//! High-performance memory management with pooling, arena allocation,
//! and zero-allocation patterns for hot paths.

const std = @import("std");

/// Fixed-size memory pool for fast allocation/deallocation
pub const MemoryPool = struct {
    allocator: std.mem.Allocator,
    buffer: []u8,
    block_size: usize,
    free_list: ?*FreeBlock,
    allocated_count: usize,
    total_blocks: usize,

    const FreeBlock = struct {
        next: ?*FreeBlock,
    };

    pub fn init(allocator: std.mem.Allocator, total_size: usize) !*MemoryPool {
        return initWithBlockSize(allocator, total_size, 64);
    }

    pub fn initWithBlockSize(allocator: std.mem.Allocator, total_size: usize, block_size: usize) !*MemoryPool {
        const actual_block_size = @max(block_size, @sizeOf(FreeBlock));
        const num_blocks = total_size / actual_block_size;

        const pool = try allocator.create(MemoryPool);
        errdefer allocator.destroy(pool);

        const buffer = try allocator.alloc(u8, num_blocks * actual_block_size);
        errdefer allocator.free(buffer);

        pool.* = .{
            .allocator = allocator,
            .buffer = buffer,
            .block_size = actual_block_size,
            .free_list = null,
            .allocated_count = 0,
            .total_blocks = num_blocks,
        };

        // Initialize free list
        var i: usize = 0;
        while (i < num_blocks) : (i += 1) {
            const block_ptr: *FreeBlock = @ptrCast(@alignCast(&buffer[i * actual_block_size]));
            block_ptr.next = pool.free_list;
            pool.free_list = block_ptr;
        }

        return pool;
    }

    pub fn deinit(self: *MemoryPool) void {
        self.allocator.free(self.buffer);
        self.allocator.destroy(self);
    }

    /// Allocate a block from the pool
    pub fn alloc(self: *MemoryPool) ?[]u8 {
        if (self.free_list) |block| {
            self.free_list = block.next;
            self.allocated_count += 1;
            const ptr: [*]u8 = @ptrCast(block);
            return ptr[0..self.block_size];
        }
        return null;
    }

    /// Free a block back to the pool
    pub fn free(self: *MemoryPool, ptr: []u8) void {
        const block: *FreeBlock = @ptrCast(@alignCast(ptr.ptr));
        block.next = self.free_list;
        self.free_list = block;
        self.allocated_count -= 1;
    }

    /// Get pool utilization (0.0 - 1.0)
    pub fn getUtilization(self: *const MemoryPool) f64 {
        if (self.total_blocks == 0) return 0.0;
        return @as(f64, @floatFromInt(self.allocated_count)) / @as(f64, @floatFromInt(self.total_blocks));
    }

    /// Check if pool has available blocks
    pub fn hasCapacity(self: *const MemoryPool) bool {
        return self.free_list != null;
    }

    /// Get number of available blocks
    pub fn availableBlocks(self: *const MemoryPool) usize {
        return self.total_blocks - self.allocated_count;
    }
};

/// Generic object pool for typed allocations
pub fn ObjectPool(comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        items: std.ArrayListUnmanaged(*T),
        available: std.ArrayListUnmanaged(*T),
        factory: ?*const fn () T,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
                .items = .{},
                .available = .{},
                .factory = null,
            };
        }

        pub fn initWithFactory(allocator: std.mem.Allocator, factory: *const fn () T) Self {
            return .{
                .allocator = allocator,
                .items = .{},
                .available = .{},
                .factory = factory,
            };
        }

        pub fn deinit(self: *Self) void {
            for (self.items.items) |item| {
                self.allocator.destroy(item);
            }
            self.items.deinit(self.allocator);
            self.available.deinit(self.allocator);
        }

        /// Get an object from the pool or create new
        pub fn acquire(self: *Self) !*T {
            if (self.available.items.len > 0) {
                const last_idx = self.available.items.len - 1;
                const item = self.available.items[last_idx];
                self.available.items.len = last_idx;
                return item;
            }

            // Create new object
            const item = try self.allocator.create(T);
            errdefer self.allocator.destroy(item);

            if (self.factory) |factory| {
                item.* = factory();
            } else {
                item.* = std.mem.zeroes(T);
            }

            try self.items.append(self.allocator, item);
            return item;
        }

        /// Return object to pool
        pub fn release(self: *Self, item: *T) void {
            self.available.append(self.allocator, item) catch {};
        }

        /// Pre-allocate objects
        pub fn preallocate(self: *Self, count: usize) !void {
            var i: usize = 0;
            while (i < count) : (i += 1) {
                const item = try self.acquire();
                self.release(item);
            }
        }

        /// Get pool statistics
        pub fn getStats(self: *const Self) PoolStats {
            return .{
                .total = self.items.items.len,
                .available = self.available.items.len,
                .in_use = self.items.items.len - self.available.items.len,
            };
        }

        pub const PoolStats = struct {
            total: usize,
            available: usize,
            in_use: usize,
        };
    };
}

/// Arena allocator optimizer with reset capabilities
pub const ArenaOptimizer = struct {
    allocator: std.mem.Allocator,
    arena: std.heap.ArenaAllocator,
    high_water_mark: usize,
    allocation_count: usize,
    reset_count: usize,

    pub fn init(allocator: std.mem.Allocator) !*ArenaOptimizer {
        const optimizer = try allocator.create(ArenaOptimizer);
        optimizer.* = .{
            .allocator = allocator,
            .arena = std.heap.ArenaAllocator.init(allocator),
            .high_water_mark = 0,
            .allocation_count = 0,
            .reset_count = 0,
        };
        return optimizer;
    }

    pub fn deinit(self: *ArenaOptimizer) void {
        self.arena.deinit();
        self.allocator.destroy(self);
    }

    /// Get arena allocator for temporary allocations
    pub fn arenaAllocator(self: *ArenaOptimizer) std.mem.Allocator {
        return self.arena.allocator();
    }

    /// Allocate from arena
    pub fn alloc(self: *ArenaOptimizer, comptime T: type, n: usize) ![]T {
        self.allocation_count += 1;
        return self.arena.allocator().alloc(T, n);
    }

    /// Reset arena (free all allocations at once)
    pub fn reset(self: *ArenaOptimizer) void {
        // Track high water mark before reset
        // Note: ArenaAllocator doesn't expose total allocation size directly
        self.reset_count += 1;
        self.allocation_count = 0;
        _ = self.arena.reset(.retain_capacity);
    }

    /// Full reset (release memory back to OS)
    pub fn fullReset(self: *ArenaOptimizer) void {
        self.reset_count += 1;
        self.allocation_count = 0;
        _ = self.arena.reset(.free_all);
    }

    /// Get statistics
    pub fn getStats(self: *const ArenaOptimizer) ArenaStats {
        return .{
            .allocation_count = self.allocation_count,
            .reset_count = self.reset_count,
            .high_water_mark = self.high_water_mark,
        };
    }

    pub const ArenaStats = struct {
        allocation_count: usize,
        reset_count: usize,
        high_water_mark: usize,
    };
};

/// Stack allocator for fast LIFO allocations
pub const StackAllocator = struct {
    buffer: []u8,
    offset: usize,

    pub fn init(buffer: []u8) StackAllocator {
        return .{
            .buffer = buffer,
            .offset = 0,
        };
    }

    /// Push allocation onto stack
    pub fn push(self: *StackAllocator, comptime T: type, count: usize) ?[]T {
        const size = @sizeOf(T) * count;
        const alignment = @alignOf(T);

        // Align offset
        const aligned_offset = std.mem.alignForward(usize, self.offset, alignment);
        if (aligned_offset + size > self.buffer.len) return null;

        const ptr: [*]T = @ptrCast(@alignCast(&self.buffer[aligned_offset]));
        self.offset = aligned_offset + size;
        return ptr[0..count];
    }

    /// Pop (reset to previous state)
    pub fn pop(self: *StackAllocator, saved_offset: usize) void {
        self.offset = saved_offset;
    }

    /// Save current state for later pop
    pub fn save(self: *const StackAllocator) usize {
        return self.offset;
    }

    /// Reset entire stack
    pub fn reset(self: *StackAllocator) void {
        self.offset = 0;
    }

    /// Get remaining capacity
    pub fn remaining(self: *const StackAllocator) usize {
        return self.buffer.len - self.offset;
    }
};

/// Zero-allocation string builder using fixed buffer
pub const FixedStringBuilder = struct {
    buffer: []u8,
    len: usize,

    pub fn init(buffer: []u8) FixedStringBuilder {
        return .{
            .buffer = buffer,
            .len = 0,
        };
    }

    /// Append string
    pub fn append(self: *FixedStringBuilder, str: []const u8) bool {
        if (self.len + str.len > self.buffer.len) return false;
        @memcpy(self.buffer[self.len..][0..str.len], str);
        self.len += str.len;
        return true;
    }

    /// Append formatted string
    pub fn appendFmt(self: *FixedStringBuilder, comptime fmt: []const u8, args: anytype) bool {
        const remaining = self.buffer[self.len..];
        const result = std.fmt.bufPrint(remaining, fmt, args) catch return false;
        self.len += result.len;
        return true;
    }

    /// Get current string
    pub fn slice(self: *const FixedStringBuilder) []const u8 {
        return self.buffer[0..self.len];
    }

    /// Clear builder
    pub fn clear(self: *FixedStringBuilder) void {
        self.len = 0;
    }
};

// ============================================================================
// Unit Tests
// ============================================================================

test "MemoryPool basic allocation" {
    const allocator = std.testing.allocator;

    var pool = try MemoryPool.initWithBlockSize(allocator, 1024, 64);
    defer pool.deinit();

    const block1 = pool.alloc();
    try std.testing.expect(block1 != null);
    try std.testing.expectEqual(@as(usize, 1), pool.allocated_count);

    const block2 = pool.alloc();
    try std.testing.expect(block2 != null);
    try std.testing.expectEqual(@as(usize, 2), pool.allocated_count);

    pool.free(block1.?);
    try std.testing.expectEqual(@as(usize, 1), pool.allocated_count);
}

test "MemoryPool utilization" {
    const allocator = std.testing.allocator;

    var pool = try MemoryPool.initWithBlockSize(allocator, 256, 64);
    defer pool.deinit();

    try std.testing.expect(pool.getUtilization() == 0.0);

    _ = pool.alloc();
    _ = pool.alloc();

    try std.testing.expect(pool.getUtilization() > 0.0);
}

test "ObjectPool acquire and release" {
    const allocator = std.testing.allocator;

    const TestStruct = struct {
        value: u32,
    };

    var pool = ObjectPool(TestStruct).init(allocator);
    defer pool.deinit();

    const obj1 = try pool.acquire();
    obj1.value = 42;

    const stats1 = pool.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats1.total);
    try std.testing.expectEqual(@as(usize, 1), stats1.in_use);

    pool.release(obj1);

    const stats2 = pool.getStats();
    try std.testing.expectEqual(@as(usize, 1), stats2.available);

    // Acquire should reuse
    const obj2 = try pool.acquire();
    try std.testing.expectEqual(obj1, obj2);
}

test "ArenaOptimizer reset" {
    const allocator = std.testing.allocator;

    var arena = try ArenaOptimizer.init(allocator);
    defer arena.deinit();

    _ = try arena.alloc(u8, 100);
    _ = try arena.alloc(u8, 200);

    try std.testing.expectEqual(@as(usize, 2), arena.allocation_count);

    arena.reset();
    try std.testing.expectEqual(@as(usize, 0), arena.allocation_count);
    try std.testing.expectEqual(@as(usize, 1), arena.reset_count);
}

test "StackAllocator push and pop" {
    var buffer: [1024]u8 = undefined;
    var stack = StackAllocator.init(&buffer);

    const saved = stack.save();

    const slice1 = stack.push(u32, 10);
    try std.testing.expect(slice1 != null);
    try std.testing.expectEqual(@as(usize, 10), slice1.?.len);

    const slice2 = stack.push(u8, 100);
    try std.testing.expect(slice2 != null);

    stack.pop(saved);
    try std.testing.expectEqual(@as(usize, 0), stack.offset);
}

test "FixedStringBuilder append" {
    var buffer: [64]u8 = undefined;
    var builder = FixedStringBuilder.init(&buffer);

    try std.testing.expect(builder.append("Hello, "));
    try std.testing.expect(builder.append("World!"));
    try std.testing.expectEqualStrings("Hello, World!", builder.slice());
}

test "FixedStringBuilder appendFmt" {
    var buffer: [64]u8 = undefined;
    var builder = FixedStringBuilder.init(&buffer);

    try std.testing.expect(builder.appendFmt("Value: {d}", .{42}));
    try std.testing.expectEqualStrings("Value: 42", builder.slice());
}
