//! Zylix Gesture - Unified Gesture Recognition Module
//!
//! Cross-platform gesture recognition system supporting:
//! - Touch gestures: Tap, Long Press, Pan, Swipe
//! - Multi-touch: Pinch to zoom, Rotation
//! - Drag and Drop: Platform-aware (long-press on mobile)
//!
//! ## Design Principles
//!
//! 1. **Unified API**: Same gesture API across all platforms
//! 2. **Platform Optimized**: Native feel on each platform
//! 3. **Composable**: Gestures can work simultaneously
//! 4. **Efficient**: Minimal allocations, optimized for 60fps
//!
//! ## Usage
//!
//! ```zig
//! const gesture = @import("gesture/gesture.zig");
//!
//! // Initialize
//! gesture.init();
//! defer gesture.deinit();
//!
//! // Tap recognizer
//! const tap = gesture.recognizers.TapRecognizer.init(.{
//!     .required_taps = 2,  // Double tap
//! });
//! tap.setCallback(onDoubleTap);
//!
//! // Pinch recognizer
//! const pinch = gesture.recognizers.PinchRecognizer.init(.{});
//! pinch.setCallback(onPinch);
//!
//! // Drag and drop
//! const drag = gesture.drag_drop.getManager();
//! drag.registerDropTarget(myDropTarget);
//! ```

const std = @import("std");

// === Module Re-exports ===

/// Common gesture types (Point, Touch, GestureState, etc.)
pub const types = @import("types.zig");
pub const Point = types.Point;
pub const Touch = types.Touch;
pub const TouchEvent = types.TouchEvent;
pub const TouchPhase = types.TouchPhase;
pub const TouchType = types.TouchType;
pub const GestureState = types.GestureState;
pub const SwipeDirection = types.SwipeDirection;
pub const Edge = types.Edge;
pub const Velocity = types.Velocity;
pub const Transform = types.Transform;
pub const GestureCallback = types.GestureCallback;

/// Gesture recognizers (Tap, Pan, Swipe, Pinch, etc.)
pub const recognizers = @import("recognizers.zig");
pub const TapRecognizer = recognizers.TapRecognizer;
pub const LongPressRecognizer = recognizers.LongPressRecognizer;
pub const PanRecognizer = recognizers.PanRecognizer;
pub const SwipeRecognizer = recognizers.SwipeRecognizer;
pub const PinchRecognizer = recognizers.PinchRecognizer;
pub const RotationRecognizer = recognizers.RotationRecognizer;

/// Drag and drop support
pub const drag_drop = @import("drag_drop.zig");
pub const DragDropManager = drag_drop.DragDropManager;
pub const DragItem = drag_drop.DragItem;
pub const DropTarget = drag_drop.DropTarget;
pub const DropOperation = drag_drop.DropOperation;
pub const DragState = drag_drop.DragState;
pub const DragSession = drag_drop.DragSession;
pub const DragEvent = drag_drop.DragEvent;
pub const DragDataType = drag_drop.DragDataType;
pub const DragPlatform = drag_drop.DragPlatform;
pub const DragDropConfig = drag_drop.DragDropConfig;

// === Constants ===

/// Zylix Gesture module version
pub const VERSION: u32 = 0x00_0A_00; // v0.10.0

/// Version string
pub const VERSION_STRING = "0.10.0";

// === Global State ===

var initialized: bool = false;

// === Recognizer Registry ===

/// Maximum registered recognizers
const MAX_RECOGNIZERS = 32;

/// Recognizer entry
const RecognizerEntry = struct {
    id: u32 = 0,
    recognizer_type: RecognizerType = .tap,
    ptr: ?*anyopaque = null,
    enabled: bool = true,
};

/// Recognizer type enum
pub const RecognizerType = enum(u8) {
    tap = 0,
    long_press = 1,
    pan = 2,
    swipe = 3,
    pinch = 4,
    rotation = 5,
};

/// Recognizer registry
var recognizer_registry: [MAX_RECOGNIZERS]?RecognizerEntry = [_]?RecognizerEntry{null} ** MAX_RECOGNIZERS;
var recognizer_count: usize = 0;
var next_recognizer_id: u32 = 1;

// === Initialization ===

/// Initialize gesture module
pub fn init() void {
    if (initialized) return;

    // Initialize submodules
    drag_drop.init();

    // Clear registry
    recognizer_count = 0;
    next_recognizer_id = 1;
    for (&recognizer_registry) |*entry| entry.* = null;

    initialized = true;
}

/// Deinitialize gesture module
pub fn deinit() void {
    if (!initialized) return;

    // Deinit submodules
    drag_drop.deinit();

    // Clear registry
    for (&recognizer_registry) |*entry| entry.* = null;
    recognizer_count = 0;

    initialized = false;
}

/// Check if initialized
pub fn isInitialized() bool {
    return initialized;
}

/// Get version
pub fn getVersion() u32 {
    return VERSION;
}

/// Get version string
pub fn getVersionString() []const u8 {
    return VERSION_STRING;
}

// === Recognizer Registration ===

/// Register a recognizer
pub fn registerRecognizer(recognizer_type: RecognizerType, ptr: *anyopaque) u32 {
    if (recognizer_count >= MAX_RECOGNIZERS) return 0;

    const id = next_recognizer_id;
    next_recognizer_id += 1;

    for (&recognizer_registry) |*slot| {
        if (slot.* == null) {
            slot.* = .{
                .id = id,
                .recognizer_type = recognizer_type,
                .ptr = ptr,
                .enabled = true,
            };
            recognizer_count += 1;
            return id;
        }
    }
    return 0;
}

/// Unregister a recognizer
pub fn unregisterRecognizer(id: u32) bool {
    for (&recognizer_registry) |*slot| {
        if (slot.*) |entry| {
            if (entry.id == id) {
                slot.* = null;
                recognizer_count -= 1;
                return true;
            }
        }
    }
    return false;
}

/// Enable/disable a recognizer
pub fn setRecognizerEnabled(id: u32, enabled: bool) bool {
    for (&recognizer_registry) |*slot| {
        if (slot.*) |*entry| {
            if (entry.id == id) {
                entry.enabled = enabled;
                return true;
            }
        }
    }
    return false;
}

// === Touch Event Dispatch ===

/// Dispatch touch event to all registered recognizers
pub fn dispatchTouchEvent(event: TouchEvent) void {
    // Dispatch to drag/drop manager
    drag_drop.getManager().handleTouch(event);

    // Dispatch to all registered recognizers
    for (&recognizer_registry) |*slot| {
        if (slot.*) |entry| {
            if (!entry.enabled) continue;
            if (entry.ptr == null) continue;

            switch (entry.recognizer_type) {
                .tap => {
                    const tap: *TapRecognizer = @ptrCast(@alignCast(entry.ptr));
                    tap.handleTouch(event);
                },
                .long_press => {
                    const lp: *LongPressRecognizer = @ptrCast(@alignCast(entry.ptr));
                    lp.handleTouch(event);
                },
                .pan => {
                    const pan: *PanRecognizer = @ptrCast(@alignCast(entry.ptr));
                    pan.handleTouch(event);
                },
                .swipe => {
                    const swipe: *SwipeRecognizer = @ptrCast(@alignCast(entry.ptr));
                    swipe.handleTouch(event);
                },
                .pinch => {
                    const pinch: *PinchRecognizer = @ptrCast(@alignCast(entry.ptr));
                    pinch.handleTouch(event);
                },
                .rotation => {
                    const rot: *RotationRecognizer = @ptrCast(@alignCast(entry.ptr));
                    rot.handleTouch(event);
                },
            }
        }
    }
}

// === Convenience Functions ===

/// Get drag/drop manager
pub fn getDragDropManager() *DragDropManager {
    return drag_drop.getManager();
}

/// Create a touch event from raw input
pub fn createTouchEvent(touches: []const Touch, timestamp: i64) TouchEvent {
    var event = TouchEvent{ .timestamp = timestamp };
    for (touches) |touch| {
        if (!event.addTouch(touch)) break;
    }
    return event;
}

/// Calculate gesture velocity from two points and time delta
pub fn calculateVelocity(from: Point, to: Point, time_delta: f64) Velocity {
    if (time_delta <= 0) return .{};
    return .{
        .x = (to.x - from.x) / time_delta,
        .y = (to.y - from.y) / time_delta,
    };
}

/// Detect swipe direction from velocity
pub fn detectSwipeDirection(velocity: Velocity) ?SwipeDirection {
    const abs_x = @abs(velocity.x);
    const abs_y = @abs(velocity.y);

    if (abs_x > abs_y) {
        if (velocity.x > 0) return .right;
        if (velocity.x < 0) return .left;
    } else {
        if (velocity.y > 0) return .down;
        if (velocity.y < 0) return .up;
    }
    return null;
}

/// Check if point is near edge
pub fn isNearEdge(point: Point, edge: Edge, screen_width: f64, screen_height: f64, threshold: f64) bool {
    return switch (edge) {
        .top => point.y < threshold,
        .bottom => point.y > screen_height - threshold,
        .left => point.x < threshold,
        .right => point.x > screen_width - threshold,
        .all => point.y < threshold or
            point.y > screen_height - threshold or
            point.x < threshold or
            point.x > screen_width - threshold,
    };
}

// === Tests ===

test "gesture module initialization" {
    init();
    try std.testing.expect(isInitialized());

    // Double init should be ok
    init();
    try std.testing.expect(isInitialized());

    deinit();
    try std.testing.expect(!isInitialized());
}

test "version" {
    try std.testing.expectEqual(@as(u32, 0x00_0A_00), getVersion());
    try std.testing.expectEqualStrings("0.10.0", getVersionString());
}

test "velocity calculation" {
    const from = Point{ .x = 0, .y = 0 };
    const to = Point{ .x = 100, .y = 200 };
    const vel = calculateVelocity(from, to, 0.1);

    try std.testing.expectApproxEqAbs(@as(f64, 1000), vel.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 2000), vel.y, 0.001);
}

test "swipe direction detection" {
    try std.testing.expectEqual(SwipeDirection.right, detectSwipeDirection(.{ .x = 500, .y = 100 }));
    try std.testing.expectEqual(SwipeDirection.left, detectSwipeDirection(.{ .x = -500, .y = 100 }));
    try std.testing.expectEqual(SwipeDirection.down, detectSwipeDirection(.{ .x = 100, .y = 500 }));
    try std.testing.expectEqual(SwipeDirection.up, detectSwipeDirection(.{ .x = 100, .y = -500 }));
}

test "edge detection" {
    const width: f64 = 1920;
    const height: f64 = 1080;
    const threshold: f64 = 20;

    try std.testing.expect(isNearEdge(.{ .x = 10, .y = 500 }, .left, width, height, threshold));
    try std.testing.expect(isNearEdge(.{ .x = 1915, .y = 500 }, .right, width, height, threshold));
    try std.testing.expect(isNearEdge(.{ .x = 500, .y = 5 }, .top, width, height, threshold));
    try std.testing.expect(isNearEdge(.{ .x = 500, .y = 1075 }, .bottom, width, height, threshold));
    try std.testing.expect(!isNearEdge(.{ .x = 500, .y = 500 }, .all, width, height, threshold));
}

test "touch event creation" {
    const touches = [_]Touch{
        .{ .id = 1, .location = .{ .x = 100, .y = 200 } },
        .{ .id = 2, .location = .{ .x = 300, .y = 400 } },
    };
    const event = createTouchEvent(&touches, 12345);

    try std.testing.expectEqual(@as(usize, 2), event.touch_count);
    try std.testing.expectEqual(@as(i64, 12345), event.timestamp);
}

// Include submodule tests
test {
    _ = types;
    _ = recognizers;
    _ = drag_drop;
}
