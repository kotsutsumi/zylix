//! C ABI Exports Module
//!
//! Provides the public C ABI interface for platform shells.
//! All functions here use C calling convention and C-compatible types.

const std = @import("std");
const state = @import("state.zig");
const events = @import("events.zig");

/// ABI version number
pub const ABI_VERSION: u32 = 1;

/// Result codes
pub const Result = enum(i32) {
    ok = 0,
    err_invalid_arg = 1,
    err_out_of_memory = 2,
    err_invalid_state = 3,
    err_not_initialized = 4,
};

/// Error messages
const error_messages = [_][*:0]const u8{
    "Success",
    "Invalid argument",
    "Out of memory",
    "Invalid state",
    "Not initialized",
};

var last_error: Result = .ok;
var abi_state_cache: state.ABIState = undefined;

// === Lifecycle Functions ===

/// Initialize Zylix Core
pub fn zylix_init() callconv(.c) i32 {
    state.init();
    last_error = .ok;
    return @intFromEnum(Result.ok);
}

/// Shutdown Zylix Core
pub fn zylix_deinit() callconv(.c) i32 {
    state.deinit();
    last_error = .ok;
    return @intFromEnum(Result.ok);
}

/// Get ABI version
pub fn zylix_get_abi_version() callconv(.c) u32 {
    return ABI_VERSION;
}

// === State Access Functions ===

/// Get current state snapshot
pub fn zylix_get_state() callconv(.c) ?*const state.ABIState {
    if (!state.isInitialized()) {
        last_error = .err_not_initialized;
        return null;
    }
    abi_state_cache = state.getState().toABI();
    return &abi_state_cache;
}

/// Get state version
pub fn zylix_get_state_version() callconv(.c) u64 {
    if (!state.isInitialized()) {
        return 0;
    }
    return state.getVersion();
}

// === Event Dispatch ===

/// Dispatch an event to Zylix Core
pub fn zylix_dispatch(
    event_type: u32,
    payload: ?*const anyopaque,
    payload_len: usize,
) callconv(.c) i32 {
    const result = events.dispatch(event_type, payload, payload_len);

    switch (result) {
        .ok => {
            last_error = .ok;
            return @intFromEnum(Result.ok);
        },
        .not_initialized => {
            last_error = .err_not_initialized;
            return @intFromEnum(Result.err_not_initialized);
        },
        .unknown_event => {
            last_error = .err_invalid_arg;
            return @intFromEnum(Result.err_invalid_arg);
        },
        .invalid_payload => {
            last_error = .err_invalid_arg;
            return @intFromEnum(Result.err_invalid_arg);
        },
    }
}

// === Error Handling ===

/// Get last error message
pub fn zylix_get_last_error() callconv(.c) [*:0]const u8 {
    const idx: usize = @intCast(@intFromEnum(last_error));
    if (idx < error_messages.len) {
        return error_messages[idx];
    }
    return error_messages[0];
}

// === Utility Functions ===

/// Copy string from Zylix memory to shell buffer
pub fn zylix_copy_string(
    src: ?[*]const u8,
    src_len: usize,
    dst: ?[*]u8,
    dst_len: usize,
) callconv(.c) usize {
    if (src == null or dst == null) {
        return 0;
    }

    const copy_len = @min(src_len, if (dst_len > 0) dst_len - 1 else 0);
    if (copy_len > 0) {
        @memcpy(dst.?[0..copy_len], src.?[0..copy_len]);
    }

    // Null-terminate
    if (dst_len > 0) {
        dst.?[copy_len] = 0;
    }

    return copy_len;
}

// === Export symbols for C ABI ===
comptime {
    @export(&zylix_init, .{ .name = "zylix_init" });
    @export(&zylix_deinit, .{ .name = "zylix_deinit" });
    @export(&zylix_get_abi_version, .{ .name = "zylix_get_abi_version" });
    @export(&zylix_get_state, .{ .name = "zylix_get_state" });
    @export(&zylix_get_state_version, .{ .name = "zylix_get_state_version" });
    @export(&zylix_dispatch, .{ .name = "zylix_dispatch" });
    @export(&zylix_get_last_error, .{ .name = "zylix_get_last_error" });
    @export(&zylix_copy_string, .{ .name = "zylix_copy_string" });
}

// === Tests ===

test "abi init/deinit" {
    try std.testing.expectEqual(@as(i32, 0), zylix_init());
    try std.testing.expect(zylix_get_state() != null);
    try std.testing.expectEqual(@as(i32, 0), zylix_deinit());
}

test "abi version" {
    try std.testing.expectEqual(ABI_VERSION, zylix_get_abi_version());
}

test "abi dispatch" {
    _ = zylix_init();
    defer _ = zylix_deinit();

    // Counter increment
    const result = zylix_dispatch(0x1000, null, 0);
    try std.testing.expectEqual(@as(i32, 0), result);

    // Check state
    const st = zylix_get_state();
    try std.testing.expect(st != null);
    try std.testing.expectEqual(@as(u64, 1), st.?.version);
}

test "abi not initialized" {
    const st = zylix_get_state();
    try std.testing.expect(st == null);

    const result = zylix_dispatch(0x1000, null, 0);
    try std.testing.expectEqual(@intFromEnum(Result.err_not_initialized), result);
}

test "abi copy string" {
    var dst: [32]u8 = undefined;
    const src = "Hello, Zylix!";

    const copied = zylix_copy_string(src.ptr, src.len, &dst, dst.len);
    try std.testing.expectEqual(src.len, copied);
    try std.testing.expectEqualStrings(src, dst[0..copied]);
}
