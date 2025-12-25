//! Touch Event System for M5Stack CoreS3
//!
//! Event queue and dispatch system for touch events.
//! Integrates with Zylix core event system.
//!
//! Features:
//! - Event queue with priority handling
//! - Event coalescing for move events
//! - Hit testing support
//! - Event bubbling and capture phases

const std = @import("std");
const input = @import("input.zig");
const gesture = @import("gesture.zig");

const Touch = input.Touch;
const TouchPhase = input.TouchPhase;
const GestureEvent = gesture.GestureEvent;

/// Event types
pub const EventType = enum {
    touch,
    gesture,
};

/// Touch event for Zylix integration
pub const TouchEvent = struct {
    touches: []const Touch,
    primary: Touch,
    timestamp: u64,

    /// Get touch by ID
    pub fn getTouchById(self: TouchEvent, id: u4) ?Touch {
        for (self.touches) |t| {
            if (t.id == id) return t;
        }
        return null;
    }

    /// Get number of active touches
    pub fn touchCount(self: TouchEvent) usize {
        return self.touches.len;
    }
};

/// Combined event type
pub const Event = union(EventType) {
    touch: TouchEvent,
    gesture: GestureEvent,
};

/// Event priority
pub const EventPriority = enum(u8) {
    low = 0,
    normal = 1,
    high = 2,
    critical = 3,
};

/// Event handler function type
pub const EventHandler = *const fn (Event, ?*anyopaque) bool;

/// Event listener registration
pub const EventListener = struct {
    event_type: ?EventType, // null = all events
    handler: EventHandler,
    user_data: ?*anyopaque,
    priority: EventPriority,
    capture: bool, // Handle during capture phase
};

/// Event queue entry
const QueueEntry = struct {
    event: Event,
    priority: EventPriority,
    timestamp: u64,
};

/// Event dispatcher
pub const EventDispatcher = struct {
    const MAX_LISTENERS = 32;
    const QUEUE_SIZE = 64;

    listeners: [MAX_LISTENERS]?EventListener = [_]?EventListener{null} ** MAX_LISTENERS,
    listener_count: usize = 0,

    queue: [QUEUE_SIZE]?QueueEntry = [_]?QueueEntry{null} ** QUEUE_SIZE,
    queue_head: usize = 0,
    queue_tail: usize = 0,

    // Event coalescing
    last_move_event: ?Event = null,
    coalesce_moves: bool = true,

    // Statistics
    events_dispatched: u64 = 0,
    events_dropped: u64 = 0,

    /// Add event listener
    pub fn addListener(
        self: *EventDispatcher,
        event_type: ?EventType,
        handler: EventHandler,
        user_data: ?*anyopaque,
        priority: EventPriority,
        capture: bool,
    ) bool {
        if (self.listener_count >= MAX_LISTENERS) return false;

        // Find empty slot
        for (&self.listeners) |*slot| {
            if (slot.* == null) {
                slot.* = .{
                    .event_type = event_type,
                    .handler = handler,
                    .user_data = user_data,
                    .priority = priority,
                    .capture = capture,
                };
                self.listener_count += 1;
                return true;
            }
        }
        return false;
    }

    /// Remove event listener
    pub fn removeListener(self: *EventDispatcher, handler: EventHandler) bool {
        for (&self.listeners) |*slot| {
            if (slot.*) |listener| {
                if (listener.handler == handler) {
                    slot.* = null;
                    self.listener_count -= 1;
                    return true;
                }
            }
        }
        return false;
    }

    /// Queue an event for later dispatch
    pub fn queueEvent(self: *EventDispatcher, event: Event, priority: EventPriority, timestamp: u64) bool {
        // Coalesce move events
        if (self.coalesce_moves) {
            switch (event) {
                .touch => |touch_event| {
                    if (touch_event.primary.phase == .moved) {
                        self.last_move_event = event;
                        return true;
                    }
                },
                .gesture => |gesture_event| {
                    switch (gesture_event) {
                        .pan => {
                            self.last_move_event = event;
                            return true;
                        },
                        else => {},
                    }
                },
            }
        }

        // Check if queue is full
        const next_tail = (self.queue_tail + 1) % QUEUE_SIZE;
        if (next_tail == self.queue_head) {
            self.events_dropped += 1;
            return false;
        }

        self.queue[self.queue_tail] = .{
            .event = event,
            .priority = priority,
            .timestamp = timestamp,
        };
        self.queue_tail = next_tail;
        return true;
    }

    /// Dispatch all queued events
    pub fn dispatchQueued(self: *EventDispatcher) void {
        // Dispatch coalesced move event first
        if (self.last_move_event) |event| {
            _ = self.dispatch(event);
            self.last_move_event = null;
        }

        // Dispatch queued events in order
        while (self.queue_head != self.queue_tail) {
            if (self.queue[self.queue_head]) |entry| {
                _ = self.dispatch(entry.event);
                self.queue[self.queue_head] = null;
            }
            self.queue_head = (self.queue_head + 1) % QUEUE_SIZE;
        }
    }

    /// Dispatch event immediately
    pub fn dispatch(self: *EventDispatcher, event: Event) bool {
        self.events_dispatched += 1;
        var handled = false;

        // Capture phase (high priority first)
        var priority: i8 = @intFromEnum(EventPriority.critical);
        while (priority >= 0) : (priority -= 1) {
            for (self.listeners) |maybe_listener| {
                if (maybe_listener) |listener| {
                    if (listener.capture and
                        @intFromEnum(listener.priority) == priority and
                        self.matchesEventType(listener.event_type, event))
                    {
                        if (listener.handler(event, listener.user_data)) {
                            handled = true;
                        }
                    }
                }
            }
        }

        // Bubble phase (low priority first for natural bubbling)
        priority = 0;
        while (priority <= @intFromEnum(EventPriority.critical)) : (priority += 1) {
            for (self.listeners) |maybe_listener| {
                if (maybe_listener) |listener| {
                    if (!listener.capture and
                        @intFromEnum(listener.priority) == priority and
                        self.matchesEventType(listener.event_type, event))
                    {
                        if (listener.handler(event, listener.user_data)) {
                            handled = true;
                        }
                    }
                }
            }
        }

        return handled;
    }

    /// Check if listener matches event type
    fn matchesEventType(self: *EventDispatcher, listener_type: ?EventType, event: Event) bool {
        _ = self;
        if (listener_type == null) return true; // Wildcard
        return listener_type.? == @as(EventType, event);
    }

    /// Get statistics
    pub fn getStats(self: *const EventDispatcher) struct { dispatched: u64, dropped: u64 } {
        return .{
            .dispatched = self.events_dispatched,
            .dropped = self.events_dropped,
        };
    }

    /// Clear all listeners
    pub fn clearListeners(self: *EventDispatcher) void {
        for (&self.listeners) |*slot| {
            slot.* = null;
        }
        self.listener_count = 0;
    }

    /// Clear event queue
    pub fn clearQueue(self: *EventDispatcher) void {
        self.queue_head = 0;
        self.queue_tail = 0;
        for (&self.queue) |*slot| {
            slot.* = null;
        }
        self.last_move_event = null;
    }
};

/// Hit test result
pub const HitTestResult = struct {
    target: ?*anyopaque, // Pointer to hit element
    local_x: i32, // X coordinate in target's local space
    local_y: i32, // Y coordinate in target's local space
};

/// Hit tester interface
pub const HitTester = struct {
    test_fn: *const fn (x: i32, y: i32, context: ?*anyopaque) HitTestResult,
    context: ?*anyopaque,

    /// Perform hit test
    pub fn hitTest(self: HitTester, x: i32, y: i32) HitTestResult {
        return self.test_fn(x, y, self.context);
    }
};

/// Touch event bridge to Zylix core events
pub const ZylixEventBridge = struct {
    dispatcher: *EventDispatcher,
    touch_input: *input.TouchInput,
    gesture_recognizer: *gesture.GestureRecognizer,

    /// Create bridge
    pub fn init(
        dispatcher: *EventDispatcher,
        touch_input: *input.TouchInput,
        gesture_recognizer: *gesture.GestureRecognizer,
    ) ZylixEventBridge {
        var bridge = ZylixEventBridge{
            .dispatcher = dispatcher,
            .touch_input = touch_input,
            .gesture_recognizer = gesture_recognizer,
        };

        // Set up callbacks
        touch_input.setOnTouchBegan(onTouchBeganCallback);
        touch_input.setOnTouchMoved(onTouchMovedCallback);
        touch_input.setOnTouchEnded(onTouchEndedCallback);
        gesture_recognizer.setOnGesture(onGestureCallback);

        return bridge;
    }

    /// Touch began callback
    fn onTouchBeganCallback(touch: Touch) void {
        // Note: This is a simplified callback. In real implementation,
        // we'd need access to the bridge instance.
        _ = touch;
    }

    /// Touch moved callback
    fn onTouchMovedCallback(touch: Touch) void {
        _ = touch;
    }

    /// Touch ended callback
    fn onTouchEndedCallback(touch: Touch) void {
        _ = touch;
    }

    /// Gesture callback
    fn onGestureCallback(gesture_event: GestureEvent) void {
        _ = gesture_event;
    }

    /// Update and dispatch events (call every frame)
    pub fn update(self: *ZylixEventBridge, timestamp_us: u64) void {
        // Update touch input
        self.touch_input.update(timestamp_us);

        // Get active touches and dispatch
        const touches = self.touch_input.getActiveTouches();
        if (touches.len > 0) {
            const event = Event{
                .touch = .{
                    .touches = touches,
                    .primary = touches[0],
                    .timestamp = timestamp_us,
                },
            };
            self.dispatcher.queueEvent(event, .normal, timestamp_us);
        }

        // Update gesture recognizer
        self.gesture_recognizer.update(timestamp_us);

        // Process gesture for multi-touch
        if (touches.len >= 2) {
            self.gesture_recognizer.processMultiTouch(touches, timestamp_us);
        }

        // Dispatch all queued events
        self.dispatcher.dispatchQueued();
    }
};

/// Convenience functions for common event patterns
pub fn onTap(dispatcher: *EventDispatcher, handler: EventHandler, user_data: ?*anyopaque) bool {
    return dispatcher.addListener(.gesture, handler, user_data, .normal, false);
}

pub fn onLongPress(dispatcher: *EventDispatcher, handler: EventHandler, user_data: ?*anyopaque) bool {
    return dispatcher.addListener(.gesture, handler, user_data, .normal, false);
}

pub fn onSwipe(dispatcher: *EventDispatcher, handler: EventHandler, user_data: ?*anyopaque) bool {
    return dispatcher.addListener(.gesture, handler, user_data, .normal, false);
}

pub fn onPinch(dispatcher: *EventDispatcher, handler: EventHandler, user_data: ?*anyopaque) bool {
    return dispatcher.addListener(.gesture, handler, user_data, .normal, false);
}

pub fn onAnyTouch(dispatcher: *EventDispatcher, handler: EventHandler, user_data: ?*anyopaque) bool {
    return dispatcher.addListener(.touch, handler, user_data, .normal, false);
}

pub fn onAnyEvent(dispatcher: *EventDispatcher, handler: EventHandler, user_data: ?*anyopaque) bool {
    return dispatcher.addListener(null, handler, user_data, .normal, false);
}

// Tests
test "EventDispatcher add/remove listener" {
    var dispatcher = EventDispatcher{};

    const handler = struct {
        fn handle(_: Event, _: ?*anyopaque) bool {
            return true;
        }
    }.handle;

    try std.testing.expect(dispatcher.addListener(.touch, handler, null, .normal, false));
    try std.testing.expectEqual(@as(usize, 1), dispatcher.listener_count);

    try std.testing.expect(dispatcher.removeListener(handler));
    try std.testing.expectEqual(@as(usize, 0), dispatcher.listener_count);
}

test "EventDispatcher queue event" {
    var dispatcher = EventDispatcher{};

    const touch = Touch{
        .id = 0,
        .x = 100,
        .y = 100,
        .phase = .began,
        .timestamp = 1000,
        .pressure = 0.5,
    };

    const event = Event{
        .touch = .{
            .touches = &[_]Touch{touch},
            .primary = touch,
            .timestamp = 1000,
        },
    };

    try std.testing.expect(dispatcher.queueEvent(event, .normal, 1000));
}

test "EventType enum" {
    try std.testing.expectEqual(EventType.touch, EventType.touch);
    try std.testing.expectEqual(EventType.gesture, EventType.gesture);
}

test "EventPriority order" {
    try std.testing.expect(@intFromEnum(EventPriority.critical) > @intFromEnum(EventPriority.high));
    try std.testing.expect(@intFromEnum(EventPriority.high) > @intFromEnum(EventPriority.normal));
    try std.testing.expect(@intFromEnum(EventPriority.normal) > @intFromEnum(EventPriority.low));
}
