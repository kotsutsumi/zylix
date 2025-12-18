//! Zylix Core - Cross-platform application runtime
//!
//! This is the central brain of Zylix applications.
//! It manages state, handles events, and provides C ABI exports
//! for platform shells (iOS/Android/Desktop).

const std = @import("std");
const state = @import("state.zig");
const events = @import("events.zig");
const abi = @import("abi.zig");

// Re-export ABI functions
pub const zylix_init = abi.zylix_init;
pub const zylix_deinit = abi.zylix_deinit;
pub const zylix_get_abi_version = abi.zylix_get_abi_version;
pub const zylix_get_state = abi.zylix_get_state;
pub const zylix_get_state_version = abi.zylix_get_state_version;
pub const zylix_dispatch = abi.zylix_dispatch;
pub const zylix_get_last_error = abi.zylix_get_last_error;
pub const zylix_copy_string = abi.zylix_copy_string;

// Re-export types for internal use
pub const State = state.State;
pub const AppState = state.AppState;
pub const UIState = state.UIState;
pub const EventType = events.EventType;

test {
    std.testing.refAllDecls(@This());
}
