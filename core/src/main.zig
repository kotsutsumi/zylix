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
pub const graphics3d = @import("graphics3d/graphics3d.zig");
pub const integration = @import("integration/integration.zig");
pub const tooling = @import("tooling/tooling.zig");

// Re-export types for internal use
pub const State = state.State;
pub const AppState = state.AppState;
pub const UIState = state.UIState;
pub const EventType = events.EventType;

// Re-export AI types
pub const ModelType = ai.ModelType;
pub const ModelConfig = ai.ModelConfig;
pub const ModelFormat = ai.ModelFormat;

// Re-export Graphics3D types
pub const Vec3 = graphics3d.Vec3;
pub const Mat4 = graphics3d.Mat4;
pub const Camera = graphics3d.Camera;
pub const Scene = graphics3d.Scene;
pub const Mesh = graphics3d.Mesh;

// Force the abi module to be analyzed (which triggers @export)
comptime {
    _ = abi;
}

test {
    std.testing.refAllDecls(@This());
}
