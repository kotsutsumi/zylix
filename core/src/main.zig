//! Zylix Core - Cross-platform application runtime
//!
//! This is the central brain of Zylix applications.
//! It manages state, handles events, and provides C ABI exports
//! for platform shells (iOS/Android/Desktop).

const std = @import("std");
pub const state = @import("state.zig");
pub const events = @import("events.zig");
pub const abi = @import("abi.zig");
pub const ai = @import("ai/ai.zig");
pub const animation = @import("animation/animation.zig");

// Re-export types for internal use
pub const State = state.State;
pub const AppState = state.AppState;
pub const UIState = state.UIState;
pub const EventType = events.EventType;

// Re-export AI types
pub const ModelType = ai.ModelType;
pub const ModelConfig = ai.ModelConfig;
pub const ModelFormat = ai.ModelFormat;

// Force the abi module to be analyzed (which triggers @export)
comptime {
    _ = abi;
}

test {
    std.testing.refAllDecls(@This());
}
