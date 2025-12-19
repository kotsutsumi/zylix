//! Arena Allocator
//!
//! Fixed-size bump allocator for temporary allocations.
//! Supports checkpoints for partial rollback.

const std = @import("std");

/// Default arena size (4KB)
pub const DEFAULT_SIZE: usize = 4096;

/// Arena allocator with fixed buffer
pub fn Arena(comptime SIZE: usize) type {
    return struct {
        const Self = @This();

        /// Internal buffer
        buffer: [SIZE]u8,

        /// Current allocation offset
        offset: usize,

        /// Peak usage (high water mark)
        peak: usize,

        /// Allocation count
        alloc_count: usize,

        /// Initialize arena
        pub fn init() Self {
            return .{
                .buffer = undefined,
                .offset = 0,
                .peak = 0,
                .alloc_count = 0,
            };
        }

        /// Allocate memory for a single item
        pub fn create(self: *Self, comptime T: type) ?*T {
            return self.allocItems(T, 1);
        }

        /// Allocate memory for multiple items
        pub fn allocItems(self: *Self, comptime T: type, count: usize) ?*T {
            const slice = self.alloc(T, count) orelse return null;
            return &slice[0];
        }

        /// Allocate slice
        pub fn alloc(self: *Self, comptime T: type, count: usize) ?[]T {
            const size = @sizeOf(T) * count;
            const alignment = @alignOf(T);

            // Align offset
            const aligned_offset = std.mem.alignForward(usize, self.offset, alignment);

            // Check bounds
            if (aligned_offset + size > SIZE) {
                return null;
            }

            const ptr: [*]T = @ptrCast(@alignCast(&self.buffer[aligned_offset]));
            self.offset = aligned_offset + size;

            // Update peak
            if (self.offset > self.peak) {
                self.peak = self.offset;
            }

            self.alloc_count += 1;

            // Zero-initialize
            @memset(ptr[0..count], std.mem.zeroes(T));

            return ptr[0..count];
        }

        /// Allocate raw bytes (untyped)
        pub fn allocBytes(self: *Self, size: usize, alignment: usize) ?[]u8 {
            const aligned_offset = std.mem.alignForward(usize, self.offset, alignment);

            if (aligned_offset + size > SIZE) {
                return null;
            }

            const result = self.buffer[aligned_offset .. aligned_offset + size];
            self.offset = aligned_offset + size;

            if (self.offset > self.peak) {
                self.peak = self.offset;
            }

            self.alloc_count += 1;

            @memset(result, 0);
            return result;
        }

        /// Duplicate a slice
        pub fn dupe(self: *Self, comptime T: type, slice: []const T) ?[]T {
            const new_slice = self.alloc(T, slice.len) orelse return null;
            @memcpy(new_slice, slice);
            return new_slice;
        }

        /// Duplicate a string (with null terminator)
        pub fn dupeZ(self: *Self, str: []const u8) ?[:0]u8 {
            const buf = self.alloc(u8, str.len + 1) orelse return null;
            @memcpy(buf[0..str.len], str);
            buf[str.len] = 0;
            return buf[0..str.len :0];
        }

        /// Create checkpoint for partial rollback
        pub fn checkpoint(self: *const Self) Checkpoint {
            return .{
                .offset = self.offset,
                .alloc_count = self.alloc_count,
            };
        }

        /// Restore to checkpoint
        pub fn restore(self: *Self, cp: Checkpoint) void {
            self.offset = cp.offset;
            self.alloc_count = cp.alloc_count;
        }

        /// Reset arena (free all allocations)
        pub fn reset(self: *Self) void {
            self.offset = 0;
            self.alloc_count = 0;
        }

        /// Get remaining capacity
        pub fn remaining(self: *const Self) usize {
            return SIZE - self.offset;
        }

        /// Get used bytes
        pub fn used(self: *const Self) usize {
            return self.offset;
        }

        /// Get total capacity
        pub fn capacity() usize {
            return SIZE;
        }

        /// Get peak usage
        pub fn getPeak(self: *const Self) usize {
            return self.peak;
        }

        /// Get allocation count since last reset
        pub fn getAllocCount(self: *const Self) usize {
            return self.alloc_count;
        }

        /// Checkpoint for partial rollback
        pub const Checkpoint = struct {
            offset: usize,
            alloc_count: usize,
        };

        /// Std allocator interface
        pub fn allocator(self: *Self) std.mem.Allocator {
            return .{
                .ptr = self,
                .vtable = &.{
                    .alloc = stdAlloc,
                    .resize = stdResize,
                    .remap = stdRemap,
                    .free = stdFree,
                },
            };
        }

        fn stdAlloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, _: usize) ?[*]u8 {
            const self: *Self = @ptrCast(@alignCast(ctx));
            const align_val = alignment.toByteUnits();
            const result = self.allocBytes(len, align_val) orelse return null;
            return result.ptr;
        }

        fn stdResize(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) bool {
            // Arena doesn't support resize
            return false;
        }

        fn stdRemap(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) ?[*]u8 {
            // Arena doesn't support remap
            return null;
        }

        fn stdFree(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize) void {
            // Arena doesn't free individual allocations
        }
    };
}

/// Default arena type
pub const DefaultArena = Arena(DEFAULT_SIZE);

/// Scoped arena - automatically resets when scope ends
pub fn ScopedArena(comptime SIZE: usize) type {
    return struct {
        const Self = @This();

        arena: *Arena(SIZE),
        checkpoint_val: Arena(SIZE).Checkpoint,

        pub fn init(arena: *Arena(SIZE)) Self {
            return .{
                .arena = arena,
                .checkpoint_val = arena.checkpoint(),
            };
        }

        pub fn deinit(self: *Self) void {
            self.arena.restore(self.checkpoint_val);
        }

        pub fn alloc(self: *Self, comptime T: type, count: usize) ?[]T {
            return self.arena.alloc(T, count);
        }

        pub fn create(self: *Self, comptime T: type) ?*T {
            return self.arena.create(T);
        }
    };
}

// === Tests ===

test "arena init" {
    var arena = DefaultArena.init();

    try std.testing.expectEqual(@as(usize, 0), arena.used());
    try std.testing.expectEqual(@as(usize, DEFAULT_SIZE), arena.remaining());
}

test "arena alloc single" {
    var arena = DefaultArena.init();

    const ptr = arena.create(i32).?;
    ptr.* = 42;

    try std.testing.expectEqual(@as(i32, 42), ptr.*);
    try std.testing.expect(arena.used() >= @sizeOf(i32));
}

test "arena alloc slice" {
    var arena = DefaultArena.init();

    const slice = arena.alloc(u8, 100).?;
    try std.testing.expectEqual(@as(usize, 100), slice.len);

    // Check zeroed
    for (slice) |byte| {
        try std.testing.expectEqual(@as(u8, 0), byte);
    }
}

test "arena alloc multiple types" {
    var arena = DefaultArena.init();

    const int_ptr = arena.create(i64).?;
    const str = arena.dupe(u8, "hello").?;
    const float_ptr = arena.create(f32).?;

    int_ptr.* = 123;
    float_ptr.* = 3.14;

    try std.testing.expectEqual(@as(i64, 123), int_ptr.*);
    try std.testing.expectEqualStrings("hello", str);
    try std.testing.expectApproxEqAbs(@as(f32, 3.14), float_ptr.*, 0.001);
}

test "arena dupeZ null terminator" {
    var arena = DefaultArena.init();

    const str = arena.dupeZ("test").?;

    try std.testing.expectEqualStrings("test", str);
    try std.testing.expectEqual(@as(u8, 0), str[str.len]);
}

test "arena checkpoint and restore" {
    var arena = DefaultArena.init();

    _ = arena.alloc(u8, 100);
    const cp = arena.checkpoint();

    _ = arena.alloc(u8, 200);
    try std.testing.expect(arena.used() >= 300);

    arena.restore(cp);
    try std.testing.expect(arena.used() < 200);
}

test "arena reset" {
    var arena = DefaultArena.init();

    _ = arena.alloc(u8, 1000);
    try std.testing.expect(arena.used() >= 1000);

    arena.reset();
    try std.testing.expectEqual(@as(usize, 0), arena.used());
}

test "arena out of memory" {
    var arena = Arena(64).init();

    const result = arena.alloc(u8, 100);
    try std.testing.expect(result == null);
}

test "arena peak tracking" {
    var arena = DefaultArena.init();

    _ = arena.alloc(u8, 500);
    _ = arena.alloc(u8, 500);

    try std.testing.expect(arena.getPeak() >= 1000);

    arena.reset();
    try std.testing.expect(arena.getPeak() >= 1000); // Peak preserved
}

test "arena alloc count" {
    var arena = DefaultArena.init();

    _ = arena.create(i32);
    _ = arena.create(i64);
    _ = arena.alloc(u8, 10);

    try std.testing.expectEqual(@as(usize, 3), arena.getAllocCount());

    arena.reset();
    try std.testing.expectEqual(@as(usize, 0), arena.getAllocCount());
}

test "scoped arena" {
    var arena = DefaultArena.init();

    _ = arena.alloc(u8, 100);
    const before = arena.used();

    {
        var scoped = ScopedArena(DEFAULT_SIZE).init(&arena);
        defer scoped.deinit();

        _ = scoped.alloc(u8, 500);
        try std.testing.expect(arena.used() >= 600);
    }

    // Should be restored after scope
    try std.testing.expectEqual(before, arena.used());
}

test "arena alignment" {
    var arena = DefaultArena.init();

    _ = arena.create(u8);
    const aligned_ptr = arena.create(i64).?;

    // Check alignment
    const addr = @intFromPtr(aligned_ptr);
    try std.testing.expectEqual(@as(usize, 0), addr % @alignOf(i64));
}

test "arena std allocator interface" {
    var arena = DefaultArena.init();
    const ally = arena.allocator();

    const slice = try ally.alloc(u8, 50);
    try std.testing.expectEqual(@as(usize, 50), slice.len);

    // Free is no-op for arena
    ally.free(slice);
    try std.testing.expect(arena.used() >= 50);
}
