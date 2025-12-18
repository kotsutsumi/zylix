//! Zylix Core - Cross-platform application runtime
//!
//! This is the central brain of Zylix applications.
//! It manages state, handles events, and provides C ABI exports
//! for platform shells (iOS/Android/Desktop).

const std = @import("std");
pub const state = @import("state.zig");
pub const events = @import("events.zig");
pub const abi = @import("abi.zig");

// Re-export types for internal use
pub const State = state.State;
pub const AppState = state.AppState;
pub const UIState = state.UIState;
pub const EventType = events.EventType;

// Force the abi module to be analyzed (which triggers @export)
comptime {
    _ = abi;
}

test {
    std.testing.refAllDecls(@This());
}
