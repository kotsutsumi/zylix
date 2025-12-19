//! C ABI Exports Module
//!
//! Provides the public C ABI interface for platform shells.
//! All functions here use C calling convention and C-compatible types.
//!
//! Phase 2: Added event queue and diff functions.

const std = @import("std");
const state = @import("state.zig");
const events = @import("events.zig");
const queue_mod = @import("queue.zig");
const diff_mod = @import("diff.zig");

/// ABI version number (bumped for Phase 2)
pub const ABI_VERSION: u32 = 2;

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

// Phase 2: Global event queue
var event_queue: queue_mod.EventQueue = queue_mod.EventQueue.init();

// Phase 2: Diff cache (using type from diff module)
var abi_diff_cache: diff_mod.ABIDiff = .{
    .changed_mask = 0,
    .change_count = 0,
    .version = 0,
};

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

// === Phase 2: Event Queue Functions ===

/// Queue an event for later processing
pub fn zylix_queue_event(
    event_type: u32,
    payload: ?*const anyopaque,
    payload_len: usize,
    priority: u8,
) callconv(.c) i32 {
    if (!state.isInitialized()) {
        last_error = .err_not_initialized;
        return @intFromEnum(Result.err_not_initialized);
    }

    if (payload_len > queue_mod.MAX_PAYLOAD) {
        last_error = .err_invalid_arg;
        return @intFromEnum(Result.err_invalid_arg);
    }

    const prio: queue_mod.Priority = switch (priority) {
        0 => .low,
        1 => .normal,
        2 => .high,
        3 => .immediate,
        else => .normal,
    };

    // Immediate priority bypasses queue
    if (prio == .immediate) {
        return zylix_dispatch(event_type, payload, payload_len);
    }

    var event = queue_mod.Event.init(event_type, prio);
    if (payload) |p| {
        const payload_bytes: [*]const u8 = @ptrCast(p);
        event.setPayload(payload_bytes[0..payload_len]);
    }

    event_queue.push(event) catch {
        last_error = .err_out_of_memory;
        return @intFromEnum(Result.err_out_of_memory);
    };

    last_error = .ok;
    return @intFromEnum(Result.ok);
}

/// Process queued events
pub fn zylix_process_events(max_events: u32) callconv(.c) u32 {
    if (!state.isInitialized()) {
        return 0;
    }

    const handler = struct {
        fn handle(event: *const queue_mod.Event) bool {
            const payload_ptr: ?*const anyopaque = if (event.payload_len > 0)
                @ptrCast(&event.payload)
            else
                null;
            _ = events.dispatch(event.event_type, payload_ptr, event.payload_len);
            return true;
        }
    }.handle;

    const processed = event_queue.process(@intCast(@min(max_events, 65535)), &handler);

    // Reset scratch arena after processing cycle
    state.resetScratchArena();

    return processed;
}

/// Get number of events in queue
pub fn zylix_queue_depth() callconv(.c) u32 {
    return event_queue.count();
}

/// Clear all queued events
pub fn zylix_queue_clear() callconv(.c) void {
    event_queue.clear();
}

// === Phase 2: Diff Functions ===

/// Get diff since last state change
pub fn zylix_get_diff() callconv(.c) ?*const diff_mod.ABIDiff {
    if (!state.isInitialized()) {
        return null;
    }

    const diff = state.getDiff();
    abi_diff_cache = .{
        .changed_mask = diff.changed_mask,
        .change_count = diff.change_count,
        .version = diff.version,
    };
    return &abi_diff_cache;
}

/// Check if a specific field changed
pub fn zylix_field_changed(field_id: u16) callconv(.c) bool {
    if (!state.isInitialized()) {
        return false;
    }

    const diff = state.getDiff();
    return diff.hasFieldChanged(field_id);
}

// === Export symbols for C ABI ===
comptime {
    // Phase 1 exports
    @export(&zylix_init, .{ .name = "zylix_init" });
    @export(&zylix_deinit, .{ .name = "zylix_deinit" });
    @export(&zylix_get_abi_version, .{ .name = "zylix_get_abi_version" });
    @export(&zylix_get_state, .{ .name = "zylix_get_state" });
    @export(&zylix_get_state_version, .{ .name = "zylix_get_state_version" });
    @export(&zylix_dispatch, .{ .name = "zylix_dispatch" });
    @export(&zylix_get_last_error, .{ .name = "zylix_get_last_error" });
    @export(&zylix_copy_string, .{ .name = "zylix_copy_string" });

    // Phase 2 exports
    @export(&zylix_queue_event, .{ .name = "zylix_queue_event" });
    @export(&zylix_process_events, .{ .name = "zylix_process_events" });
    @export(&zylix_queue_depth, .{ .name = "zylix_queue_depth" });
    @export(&zylix_queue_clear, .{ .name = "zylix_queue_clear" });
    @export(&zylix_get_diff, .{ .name = "zylix_get_diff" });
    @export(&zylix_field_changed, .{ .name = "zylix_field_changed" });
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
