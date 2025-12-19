//! Event Queue System
//!
//! Ring buffer-based event queue with priority levels.
//! Supports async event dispatch and batch processing.

const std = @import("std");

/// Queue size (must be power of 2)
pub const QUEUE_SIZE: usize = 64;

/// Maximum inline payload size
pub const MAX_PAYLOAD: usize = 64;

/// Event priority levels
pub const Priority = enum(u2) {
    low = 0,
    normal = 1,
    high = 2,
    immediate = 3, // Bypass queue, process immediately
};

/// Event structure with inline payload
pub const Event = struct {
    /// Event type identifier
    event_type: u32,

    /// Inline payload buffer (aligned for common structs)
    payload: [MAX_PAYLOAD]u8 align(8),

    /// Actual payload length
    payload_len: u16,

    /// Event priority
    priority: Priority,

    /// Sequence number (for ordering)
    sequence: u64,

    /// Initialize empty event
    pub fn init(event_type: u32, priority: Priority) Event {
        return .{
            .event_type = event_type,
            .payload = [_]u8{0} ** MAX_PAYLOAD,
            .payload_len = 0,
            .priority = priority,
            .sequence = 0,
        };
    }

    /// Initialize event with payload
    pub fn initWithPayload(event_type: u32, payload: []const u8, priority: Priority) Event {
        var event = Event.init(event_type, priority);
        event.setPayload(payload);
        return event;
    }

    /// Set payload data
    pub fn setPayload(self: *Event, data: []const u8) void {
        const copy_len = @min(data.len, MAX_PAYLOAD);
        @memcpy(self.payload[0..copy_len], data[0..copy_len]);
        self.payload_len = @intCast(copy_len);
    }

    /// Get payload as slice
    pub fn getPayload(self: *const Event) []const u8 {
        return self.payload[0..self.payload_len];
    }

    /// Get payload as typed pointer (for structured payloads)
    pub fn getPayloadAs(self: *const Event, comptime T: type) ?*const T {
        if (self.payload_len < @sizeOf(T)) return null;
        return @ptrCast(@alignCast(&self.payload));
    }
};

/// Ring buffer event queue
pub const EventQueue = struct {
    /// Event buffer
    buffer: [QUEUE_SIZE]Event,

    /// Read position
    head: u16,

    /// Write position
    tail: u16,

    /// Next sequence number
    next_sequence: u64,

    /// Statistics
    stats: Stats,

    pub const Stats = struct {
        enqueued: u64 = 0,
        processed: u64 = 0,
        dropped: u64 = 0,
        immediate: u64 = 0,
    };

    /// Error type
    pub const Error = error{
        QueueFull,
        PayloadTooLarge,
    };

    /// Initialize empty queue
    pub fn init() EventQueue {
        return .{
            .buffer = undefined,
            .head = 0,
            .tail = 0,
            .next_sequence = 0,
            .stats = .{},
        };
    }

    /// Check if queue is empty
    pub fn isEmpty(self: *const EventQueue) bool {
        return self.head == self.tail;
    }

    /// Check if queue is full
    pub fn isFull(self: *const EventQueue) bool {
        return self.nextIndex(self.tail) == self.head;
    }

    /// Get number of events in queue
    pub fn count(self: *const EventQueue) u16 {
        if (self.tail >= self.head) {
            return self.tail - self.head;
        } else {
            return @intCast(QUEUE_SIZE - @as(usize, self.head) + @as(usize, self.tail));
        }
    }

    /// Push event to queue
    pub fn push(self: *EventQueue, event: Event) Error!void {
        if (self.isFull()) {
            self.stats.dropped += 1;
            return Error.QueueFull;
        }

        var evt = event;
        evt.sequence = self.next_sequence;
        self.next_sequence +%= 1;

        self.buffer[self.tail] = evt;
        self.tail = self.nextIndex(self.tail);
        self.stats.enqueued += 1;
    }

    /// Push event with type and payload
    pub fn pushEvent(self: *EventQueue, event_type: u32, payload: ?[]const u8, priority: Priority) Error!void {
        if (payload) |p| {
            if (p.len > MAX_PAYLOAD) {
                return Error.PayloadTooLarge;
            }
        }

        var event = Event.init(event_type, priority);
        if (payload) |p| {
            event.setPayload(p);
        }

        try self.push(event);
    }

    /// Pop event from queue
    pub fn pop(self: *EventQueue) ?Event {
        if (self.isEmpty()) return null;

        const event = self.buffer[self.head];
        self.head = self.nextIndex(self.head);
        return event;
    }

    /// Peek at next event without removing
    pub fn peek(self: *const EventQueue) ?*const Event {
        if (self.isEmpty()) return null;
        return &self.buffer[self.head];
    }

    /// Process events with callback
    pub fn process(
        self: *EventQueue,
        max_events: u16,
        handler: *const fn (event: *const Event) bool,
    ) u16 {
        var processed: u16 = 0;

        while (processed < max_events) {
            const event = self.pop() orelse break;

            // Call handler; if it returns false, stop processing
            if (!handler(&event)) {
                break;
            }

            self.stats.processed += 1;
            processed += 1;
        }

        return processed;
    }

    /// Process all events
    pub fn processAll(self: *EventQueue, handler: *const fn (event: *const Event) bool) u16 {
        return self.process(QUEUE_SIZE, handler);
    }

    /// Process events with context
    pub fn processWithContext(
        self: *EventQueue,
        comptime Context: type,
        ctx: Context,
        max_events: u16,
        handler: *const fn (ctx: Context, event: *const Event) bool,
    ) u16 {
        var processed: u16 = 0;

        while (processed < max_events) {
            const event = self.pop() orelse break;

            if (!handler(ctx, &event)) {
                break;
            }

            self.stats.processed += 1;
            processed += 1;
        }

        return processed;
    }

    /// Clear all events
    pub fn clear(self: *EventQueue) void {
        self.head = 0;
        self.tail = 0;
    }

    /// Get statistics
    pub fn getStats(self: *const EventQueue) Stats {
        return self.stats;
    }

    /// Reset statistics
    pub fn resetStats(self: *EventQueue) void {
        self.stats = .{};
    }

    /// Calculate next index with wrap-around
    fn nextIndex(self: *const EventQueue, index: u16) u16 {
        _ = self;
        return @intCast((@as(usize, index) + 1) & (QUEUE_SIZE - 1));
    }
};

/// Priority queue that processes high priority events first
pub const PriorityEventQueue = struct {
    /// Separate queues per priority level
    queues: [4]EventQueue,

    /// Initialize
    pub fn init() PriorityEventQueue {
        return .{
            .queues = .{
                EventQueue.init(),
                EventQueue.init(),
                EventQueue.init(),
                EventQueue.init(),
            },
        };
    }

    /// Push event to appropriate priority queue
    pub fn push(self: *PriorityEventQueue, event: Event) EventQueue.Error!void {
        const priority_index = @intFromEnum(event.priority);
        try self.queues[priority_index].push(event);
    }

    /// Pop highest priority event
    pub fn pop(self: *PriorityEventQueue) ?Event {
        // Check from highest to lowest priority
        var i: usize = 3;
        while (true) : (i -%= 1) {
            if (self.queues[i].pop()) |event| {
                return event;
            }
            if (i == 0) break;
        }
        return null;
    }

    /// Check if all queues are empty
    pub fn isEmpty(self: *const PriorityEventQueue) bool {
        for (self.queues) |queue| {
            if (!queue.isEmpty()) return false;
        }
        return true;
    }

    /// Get total count across all queues
    pub fn count(self: *const PriorityEventQueue) u16 {
        var total: u16 = 0;
        for (self.queues) |queue| {
            total += queue.count();
        }
        return total;
    }

    /// Process events respecting priority
    pub fn process(
        self: *PriorityEventQueue,
        max_events: u16,
        handler: *const fn (event: *const Event) bool,
    ) u16 {
        var processed: u16 = 0;

        while (processed < max_events) {
            const event = self.pop() orelse break;

            if (!handler(&event)) {
                break;
            }

            processed += 1;
        }

        return processed;
    }
};

// === Tests ===

test "queue init empty" {
    var queue = EventQueue.init();

    try std.testing.expect(queue.isEmpty());
    try std.testing.expect(!queue.isFull());
    try std.testing.expectEqual(@as(u16, 0), queue.count());
}

test "queue push and pop" {
    var queue = EventQueue.init();

    const event1 = Event.init(0x1000, .normal);
    const event2 = Event.init(0x1001, .normal);

    try queue.push(event1);
    try queue.push(event2);

    try std.testing.expectEqual(@as(u16, 2), queue.count());

    const popped1 = queue.pop().?;
    try std.testing.expectEqual(@as(u32, 0x1000), popped1.event_type);

    const popped2 = queue.pop().?;
    try std.testing.expectEqual(@as(u32, 0x1001), popped2.event_type);

    try std.testing.expect(queue.isEmpty());
}

test "queue with payload" {
    var queue = EventQueue.init();

    const payload = "hello";
    try queue.pushEvent(0x100, payload, .normal);

    const event = queue.pop().?;
    try std.testing.expectEqualStrings("hello", event.getPayload());
}

test "queue sequence numbers" {
    var queue = EventQueue.init();

    try queue.push(Event.init(0x01, .normal));
    try queue.push(Event.init(0x02, .normal));
    try queue.push(Event.init(0x03, .normal));

    try std.testing.expectEqual(@as(u64, 0), queue.pop().?.sequence);
    try std.testing.expectEqual(@as(u64, 1), queue.pop().?.sequence);
    try std.testing.expectEqual(@as(u64, 2), queue.pop().?.sequence);
}

test "queue full" {
    var queue = EventQueue.init();

    // Fill queue
    var i: usize = 0;
    while (i < QUEUE_SIZE - 1) : (i += 1) {
        try queue.push(Event.init(@intCast(i), .normal));
    }

    try std.testing.expect(queue.isFull());

    // Should fail to push
    try std.testing.expectError(EventQueue.Error.QueueFull, queue.push(Event.init(999, .normal)));
}

test "queue process with handler" {
    var queue = EventQueue.init();

    try queue.push(Event.init(0x01, .normal));
    try queue.push(Event.init(0x02, .normal));
    try queue.push(Event.init(0x03, .normal));

    const handler = struct {
        fn handle(event: *const Event) bool {
            _ = event;
            return true;
        }
    }.handle;

    const processed = queue.process(10, &handler);

    try std.testing.expectEqual(@as(u16, 3), processed);
    try std.testing.expect(queue.isEmpty());
}

test "queue peek" {
    var queue = EventQueue.init();

    try queue.push(Event.init(0x42, .normal));

    const peeked = queue.peek().?;
    try std.testing.expectEqual(@as(u32, 0x42), peeked.event_type);

    // Should still be there
    try std.testing.expect(!queue.isEmpty());
}

test "queue stats" {
    var queue = EventQueue.init();

    try queue.push(Event.init(0x01, .normal));
    try queue.push(Event.init(0x02, .normal));
    _ = queue.pop();

    const stats = queue.getStats();
    try std.testing.expectEqual(@as(u64, 2), stats.enqueued);
}

test "priority queue ordering" {
    var pq = PriorityEventQueue.init();

    try pq.push(Event.init(0x01, .low));
    try pq.push(Event.init(0x02, .normal));
    try pq.push(Event.init(0x03, .high));

    // Should get high priority first
    try std.testing.expectEqual(@as(u32, 0x03), pq.pop().?.event_type);
    try std.testing.expectEqual(@as(u32, 0x02), pq.pop().?.event_type);
    try std.testing.expectEqual(@as(u32, 0x01), pq.pop().?.event_type);
}

test "event typed payload" {
    const ButtonEvent = extern struct {
        button_id: u32,
        pressed: bool,
    };

    var event = Event.init(0x100, .normal);
    const btn = ButtonEvent{ .button_id = 42, .pressed = true };
    event.setPayload(std.mem.asBytes(&btn));

    const payload = event.getPayloadAs(ButtonEvent).?;
    try std.testing.expectEqual(@as(u32, 42), payload.button_id);
    try std.testing.expect(payload.pressed);
}
