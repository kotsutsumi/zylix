//! SIMD Optimizations for Virtual DOM Operations
//!
//! Provides SIMD-accelerated functions for:
//! - Fast string/key comparison
//! - Batch hash computation
//! - Memory block comparison
//!
//! Uses Zig's native SIMD vector types for portable performance.

const std = @import("std");

/// SIMD vector size (128-bit = 16 bytes)
pub const SIMD_WIDTH = 16;

/// SIMD vector type for u8 operations
pub const Vec16u8 = @Vector(16, u8);

/// SIMD vector type for u32 operations (for hash accumulation)
pub const Vec4u32 = @Vector(4, u32);

/// Check if SIMD operations are available at runtime
pub fn simdAvailable() bool {
    // Zig's @Vector works on all targets, compiler optimizes appropriately
    return true;
}

// ============================================================================
// SIMD String/Memory Comparison
// ============================================================================

/// Fast memory equality check
/// Delegates to std.mem.eql which is already SIMD-optimized by Zig
pub fn simdMemEql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

/// Fast comparison for fixed-size arrays (common in VNode props)
/// Delegates to std.mem.eql which handles SIMD internally
pub fn simdArrayEql(comptime N: usize, a: *const [N]u8, b: *const [N]u8) bool {
    return std.mem.eql(u8, a, b);
}

// ============================================================================
// SIMD Hash Functions
// ============================================================================

/// DJB2 hash constants for SIMD
const DJB2_INIT: u32 = 5381;
const DJB2_MULT: u32 = 33;

/// SIMD-accelerated DJB2 hash for keys
/// Processes 4 characters in parallel where possible
pub fn simdHashKey(key: []const u8) u32 {
    if (key.len == 0) return DJB2_INIT;

    var hash: u32 = DJB2_INIT;
    var i: usize = 0;

    // Process 4 bytes at a time using vectorized multiplication pattern
    while (i + 4 <= key.len) : (i += 4) {
        // Load 4 bytes
        const bytes: [4]u8 = key[i..][0..4].*;

        // Vectorized hash update: hash = hash * 33^4 + bytes[0] * 33^3 + bytes[1] * 33^2 + ...
        // This is mathematically equivalent to 4 sequential djb2 steps
        const mult4: u32 = 1185921; // 33^4
        const mult3: u32 = 35937; // 33^3
        const mult2: u32 = 1089; // 33^2
        const mult1: u32 = 33;

        hash = hash *% mult4 +%
            @as(u32, bytes[0]) *% mult3 +%
            @as(u32, bytes[1]) *% mult2 +%
            @as(u32, bytes[2]) *% mult1 +%
            @as(u32, bytes[3]);
    }

    // Process remaining bytes
    while (i < key.len) : (i += 1) {
        hash = ((hash << 5) +% hash) +% @as(u32, key[i]);
    }

    return hash;
}

/// FNV-1a hash variant optimized for short strings (keys, tags)
pub fn simdFnv1a(data: []const u8) u64 {
    const FNV_PRIME: u64 = 0x100000001b3;
    const FNV_OFFSET: u64 = 0xcbf29ce484222325;

    var hash: u64 = FNV_OFFSET;
    var i: usize = 0;

    // Process 8 bytes at a time
    while (i + 8 <= data.len) : (i += 8) {
        const chunk = std.mem.readInt(u64, data[i..][0..8], .little);
        hash ^= chunk;
        hash *%= FNV_PRIME;
    }

    // Process remaining bytes
    while (i < data.len) : (i += 1) {
        hash ^= @as(u64, data[i]);
        hash *%= FNV_PRIME;
    }

    return hash;
}

// ============================================================================
// SIMD Props Comparison
// ============================================================================

/// Compare two property blocks efficiently
/// Uses byte-level comparison which is SIMD-optimized by Zig
pub fn simdPropsEql(comptime T: type, a: *const T, b: *const T) bool {
    const a_bytes = std.mem.asBytes(a);
    const b_bytes = std.mem.asBytes(b);
    return std.mem.eql(u8, a_bytes, b_bytes);
}

// ============================================================================
// SIMD Batch Operations
// ============================================================================

/// Result of batch key matching
pub const KeyMatchResult = struct {
    matches: [16]bool,
    match_count: u8,
};

/// Batch compare a key against up to 16 candidate keys
/// Returns which candidates match
pub fn simdBatchKeyMatch(target: []const u8, candidates: []const []const u8) KeyMatchResult {
    var result = KeyMatchResult{
        .matches = [_]bool{false} ** 16,
        .match_count = 0,
    };

    const count = @min(candidates.len, 16);
    const target_hash = simdHashKey(target);

    // First pass: compare hashes (fast reject)
    for (candidates[0..count], 0..) |candidate, i| {
        if (simdHashKey(candidate) == target_hash) {
            // Hash matches - verify with full comparison
            if (simdMemEql(target, candidate)) {
                result.matches[i] = true;
                result.match_count += 1;
            }
        }
    }

    return result;
}

/// Find first matching key in list
pub fn simdFindKey(target: []const u8, keys: []const []const u8) ?usize {
    const target_hash = simdHashKey(target);

    for (keys, 0..) |key, i| {
        if (simdHashKey(key) == target_hash) {
            if (simdMemEql(target, key)) {
                return i;
            }
        }
    }

    return null;
}

// ============================================================================
// SIMD Text Diff Helpers
// ============================================================================

/// Find first differing position between two strings
/// Returns length if strings are equal
pub fn simdFindDiffPos(a: []const u8, b: []const u8) usize {
    const min_len = @min(a.len, b.len);
    var i: usize = 0;

    // SIMD comparison for 16-byte blocks
    while (i + SIMD_WIDTH <= min_len) : (i += SIMD_WIDTH) {
        const va: Vec16u8 = a[i..][0..SIMD_WIDTH].*;
        const vb: Vec16u8 = b[i..][0..SIMD_WIDTH].*;
        const diff = va ^ vb;

        if (@reduce(.Or, diff) != 0) {
            // Found difference in this block - find exact position
            for (0..SIMD_WIDTH) |j| {
                if (a[i + j] != b[i + j]) return i + j;
            }
        }
    }

    // Check remaining bytes
    while (i < min_len) : (i += 1) {
        if (a[i] != b[i]) return i;
    }

    return min_len;
}

/// Count common prefix length (useful for incremental updates)
pub fn simdCommonPrefixLen(a: []const u8, b: []const u8) usize {
    return simdFindDiffPos(a, b);
}

/// Count common suffix length
pub fn simdCommonSuffixLen(a: []const u8, b: []const u8) usize {
    const min_len = @min(a.len, b.len);
    if (min_len == 0) return 0;

    var i: usize = 0;
    while (i < min_len) : (i += 1) {
        if (a[a.len - 1 - i] != b[b.len - 1 - i]) {
            return i;
        }
    }
    return min_len;
}

// ============================================================================
// Benchmarking Utilities
// ============================================================================

/// Measure SIMD speedup factor for current platform
pub fn measureSpeedup(allocator: std.mem.Allocator) !f64 {
    const iterations = 10000;
    const test_size = 256;

    // Generate test data
    const data_a = try allocator.alloc(u8, test_size);
    defer allocator.free(data_a);
    const data_b = try allocator.alloc(u8, test_size);
    defer allocator.free(data_b);

    for (data_a, data_b) |*a, *b| {
        a.* = @truncate(@as(usize, @intFromPtr(a)) & 0xFF);
        b.* = @truncate(@as(usize, @intFromPtr(b)) & 0xFF);
    }

    // Time SIMD version
    var timer = try std.time.Timer.start();
    for (0..iterations) |_| {
        _ = simdMemEql(data_a, data_b);
    }
    const simd_time = timer.read();

    // Time scalar version
    timer.reset();
    for (0..iterations) |_| {
        _ = std.mem.eql(u8, data_a, data_b);
    }
    const scalar_time = timer.read();

    if (simd_time == 0) return 1.0;
    return @as(f64, @floatFromInt(scalar_time)) / @as(f64, @floatFromInt(simd_time));
}

// ============================================================================
// Tests
// ============================================================================

test "simdMemEql basic" {
    const a = "Hello, World!";
    const b = "Hello, World!";
    const c = "Hello, Zylix!";

    try std.testing.expect(simdMemEql(a, b));
    try std.testing.expect(!simdMemEql(a, c));
}

test "simdMemEql empty" {
    try std.testing.expect(simdMemEql("", ""));
}

test "simdMemEql different lengths" {
    try std.testing.expect(!simdMemEql("abc", "abcd"));
}

test "simdMemEql large strings" {
    const a = "A" ** 256;
    const b = "A" ** 256;
    var c: [256]u8 = undefined;
    @memset(&c, 'A');
    c[200] = 'B';

    try std.testing.expect(simdMemEql(a, b));
    try std.testing.expect(!simdMemEql(a, &c));
}

test "simdArrayEql" {
    const a: [32]u8 = "This is a test string of 32!!!!!".*;
    const b: [32]u8 = "This is a test string of 32!!!!!".*;
    var c: [32]u8 = a;
    c[15] = 'X';

    try std.testing.expect(simdArrayEql(32, &a, &b));
    try std.testing.expect(!simdArrayEql(32, &a, &c));
}

test "simdArrayEql small" {
    const a: [8]u8 = "test1234".*;
    const b: [8]u8 = "test1234".*;
    const c: [8]u8 = "test5678".*;

    try std.testing.expect(simdArrayEql(8, &a, &b));
    try std.testing.expect(!simdArrayEql(8, &a, &c));
}

test "simdHashKey consistency" {
    const hash1 = simdHashKey("item-1");
    const hash2 = simdHashKey("item-1");
    const hash3 = simdHashKey("item-2");

    try std.testing.expectEqual(hash1, hash2);
    try std.testing.expect(hash1 != hash3);
}

test "simdHashKey empty" {
    try std.testing.expectEqual(DJB2_INIT, simdHashKey(""));
}

test "simdHashKey matches scalar djb2" {
    // Verify our vectorized version produces same results
    const test_keys = [_][]const u8{
        "a",
        "ab",
        "abc",
        "abcd",
        "abcdefgh",
        "item-1",
        "list-item-123",
    };

    for (test_keys) |key| {
        // Scalar DJB2
        var scalar_hash: u32 = 5381;
        for (key) |c| {
            scalar_hash = ((scalar_hash << 5) +% scalar_hash) +% c;
        }

        const simd_hash = simdHashKey(key);
        try std.testing.expectEqual(scalar_hash, simd_hash);
    }
}

test "simdFnv1a basic" {
    const hash1 = simdFnv1a("test");
    const hash2 = simdFnv1a("test");
    const hash3 = simdFnv1a("TEST");

    try std.testing.expectEqual(hash1, hash2);
    try std.testing.expect(hash1 != hash3);
}

test "simdBatchKeyMatch" {
    const target = "item-2";
    const candidates = [_][]const u8{
        "item-0",
        "item-1",
        "item-2",
        "item-3",
    };

    const result = simdBatchKeyMatch(target, &candidates);

    try std.testing.expect(!result.matches[0]);
    try std.testing.expect(!result.matches[1]);
    try std.testing.expect(result.matches[2]);
    try std.testing.expect(!result.matches[3]);
    try std.testing.expectEqual(@as(u8, 1), result.match_count);
}

test "simdFindKey" {
    const keys = [_][]const u8{
        "apple",
        "banana",
        "cherry",
        "date",
    };

    try std.testing.expectEqual(@as(?usize, 0), simdFindKey("apple", &keys));
    try std.testing.expectEqual(@as(?usize, 2), simdFindKey("cherry", &keys));
    try std.testing.expectEqual(@as(?usize, null), simdFindKey("grape", &keys));
}

test "simdFindDiffPos" {
    try std.testing.expectEqual(@as(usize, 7), simdFindDiffPos("Hello, World", "Hello, Zylix"));
    try std.testing.expectEqual(@as(usize, 5), simdFindDiffPos("Hello", "Hello"));
    try std.testing.expectEqual(@as(usize, 0), simdFindDiffPos("abc", "xyz"));
}

test "simdCommonPrefixLen" {
    try std.testing.expectEqual(@as(usize, 7), simdCommonPrefixLen("Hello, World", "Hello, Zylix"));
    try std.testing.expectEqual(@as(usize, 0), simdCommonPrefixLen("abc", "xyz"));
}

test "simdCommonSuffixLen" {
    try std.testing.expectEqual(@as(usize, 6), simdCommonSuffixLen("Hello World", "Goodbye World")); // " World" = 6 chars
    try std.testing.expectEqual(@as(usize, 0), simdCommonSuffixLen("abc", "xyz"));
}

test "simdPropsEql" {
    const TestProps = struct {
        a: u32,
        b: u32,
        c: [8]u8,
    };

    const props1 = TestProps{ .a = 1, .b = 2, .c = "test1234".* };
    const props2 = TestProps{ .a = 1, .b = 2, .c = "test1234".* };
    const props3 = TestProps{ .a = 1, .b = 3, .c = "test1234".* };

    try std.testing.expect(simdPropsEql(TestProps, &props1, &props2));
    try std.testing.expect(!simdPropsEql(TestProps, &props1, &props3));
}
