//! Render Batching and Scheduling
//!
//! Efficient render scheduling with frame budgeting, priority queues,
//! and automatic batching for optimal performance.

const std = @import("std");

/// Render priority levels
pub const Priority = enum(u8) {
    /// Critical updates (user input response)
    critical = 0,
    /// High priority (animations)
    high = 1,
    /// Normal priority (state updates)
    normal = 2,
    /// Low priority (background updates)
    low = 3,
    /// Idle (deferred updates)
    idle = 4,
};

/// Render task
pub const RenderTask = struct {
    id: u64,
    priority: Priority,
    callback: *const fn (*RenderTask) void,
    data: ?*anyopaque,
    deadline_ns: ?u64,
    created_at: i64,

    pub fn execute(self: *RenderTask) void {
        self.callback(self);
    }
};

/// Priority queue for render tasks
pub const PriorityQueue = struct {
    allocator: std.mem.Allocator,
    queues: [5]std.ArrayListUnmanaged(RenderTask),
    next_id: u64,

    pub fn init(allocator: std.mem.Allocator) !*PriorityQueue {
        const pq = try allocator.create(PriorityQueue);
        pq.* = .{
            .allocator = allocator,
            .queues = .{ .{}, .{}, .{}, .{}, .{} },
            .next_id = 0,
        };

        return pq;
    }

    pub fn deinit(self: *PriorityQueue) void {
        for (&self.queues) |*queue| {
            queue.deinit(self.allocator);
        }
        self.allocator.destroy(self);
    }

    /// Add task to queue
    pub fn push(self: *PriorityQueue, priority: Priority, callback: *const fn (*RenderTask) void, data: ?*anyopaque) !u64 {
        const id = self.next_id;
        self.next_id += 1;

        try self.queues[@intFromEnum(priority)].append(self.allocator, .{
            .id = id,
            .priority = priority,
            .callback = callback,
            .data = data,
            .deadline_ns = null,
            .created_at = std.time.milliTimestamp(),
        });

        return id;
    }

    /// Add task with deadline
    pub fn pushWithDeadline(self: *PriorityQueue, priority: Priority, callback: *const fn (*RenderTask) void, data: ?*anyopaque, deadline_ns: u64) !u64 {
        const id = self.next_id;
        self.next_id += 1;

        try self.queues[@intFromEnum(priority)].append(self.allocator, .{
            .id = id,
            .priority = priority,
            .callback = callback,
            .data = data,
            .deadline_ns = deadline_ns,
            .created_at = std.time.milliTimestamp(),
        });

        return id;
    }

    /// Pop highest priority task
    pub fn pop(self: *PriorityQueue) ?RenderTask {
        for (&self.queues) |*queue| {
            if (queue.items.len > 0) {
                return queue.orderedRemove(0);
            }
        }
        return null;
    }

    /// Peek at highest priority task
    pub fn peek(self: *const PriorityQueue) ?*const RenderTask {
        for (&self.queues) |*queue| {
            if (queue.items.len > 0) {
                return &queue.items[0];
            }
        }
        return null;
    }

    /// Get total task count
    pub fn count(self: *const PriorityQueue) usize {
        var total: usize = 0;
        for (&self.queues) |*queue| {
            total += queue.items.len;
        }
        return total;
    }

    /// Clear all tasks
    pub fn clear(self: *PriorityQueue) void {
        for (&self.queues) |*queue| {
            queue.clearRetainingCapacity();
        }
    }

    /// Check if queue is empty
    pub fn isEmpty(self: *const PriorityQueue) bool {
        return self.count() == 0;
    }
};

/// Render batcher for combining similar operations
pub const RenderBatcher = struct {
    allocator: std.mem.Allocator,
    batches: std.ArrayListUnmanaged(Batch),
    max_batch_size: usize,
    current_batch: ?*Batch,

    pub const Batch = struct {
        allocator: std.mem.Allocator,
        operations: std.ArrayListUnmanaged(Operation),
        batch_type: BatchType,
        created_at: i64,

        pub const BatchType = enum {
            dom_updates,
            style_updates,
            layout_updates,
            paint_updates,
        };

        pub fn init(allocator: std.mem.Allocator, batch_type: BatchType) Batch {
            return .{
                .allocator = allocator,
                .operations = .{},
                .batch_type = batch_type,
                .created_at = std.time.milliTimestamp(),
            };
        }

        pub fn deinit(self: *Batch) void {
            self.operations.deinit(self.allocator);
        }
    };

    pub const Operation = struct {
        op_type: OperationType,
        target_id: u64,
        data: ?[]const u8,

        pub const OperationType = enum {
            create,
            update,
            delete,
            move,
            style,
            attribute,
        };
    };

    pub fn init(allocator: std.mem.Allocator) !*RenderBatcher {
        const batcher = try allocator.create(RenderBatcher);
        batcher.* = .{
            .allocator = allocator,
            .batches = .{},
            .max_batch_size = 100,
            .current_batch = null,
        };
        return batcher;
    }

    pub fn deinit(self: *RenderBatcher) void {
        for (self.batches.items) |*batch| {
            batch.deinit();
        }
        self.batches.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    /// Begin a new batch
    pub fn beginBatch(self: *RenderBatcher, batch_type: Batch.BatchType) !void {
        try self.batches.append(self.allocator, Batch.init(self.allocator, batch_type));
        self.current_batch = &self.batches.items[self.batches.items.len - 1];
    }

    /// Add operation to current batch
    pub fn addOperation(self: *RenderBatcher, op: Operation) !void {
        if (self.current_batch) |batch| {
            try batch.operations.append(batch.allocator, op);

            // Auto-flush if batch is full
            if (batch.operations.items.len >= self.max_batch_size) {
                try self.flush();
            }
        }
    }

    /// End current batch
    pub fn endBatch(self: *RenderBatcher) void {
        self.current_batch = null;
    }

    /// Flush all batches
    pub fn flush(self: *RenderBatcher) !void {
        // Process and clear batches
        for (self.batches.items) |*batch| {
            batch.deinit();
        }
        self.batches.clearRetainingCapacity();
        self.current_batch = null;
    }

    /// Get pending operation count
    pub fn pendingCount(self: *const RenderBatcher) usize {
        var count: usize = 0;
        for (self.batches.items) |batch| {
            count += batch.operations.items.len;
        }
        return count;
    }
};

/// Frame scheduler for maintaining target frame rate
pub const FrameScheduler = struct {
    allocator: std.mem.Allocator,
    target_frame_time_ns: u64,
    last_frame_time: i128,
    frame_count: u64,
    dropped_frames: u64,
    task_queue: *PriorityQueue,
    frame_budget_used_ns: u64,

    pub fn init(allocator: std.mem.Allocator, target_frame_time_ns: u64) !*FrameScheduler {
        const scheduler = try allocator.create(FrameScheduler);
        errdefer allocator.destroy(scheduler);

        scheduler.* = .{
            .allocator = allocator,
            .target_frame_time_ns = target_frame_time_ns,
            .last_frame_time = std.time.nanoTimestamp(),
            .frame_count = 0,
            .dropped_frames = 0,
            .task_queue = try PriorityQueue.init(allocator),
            .frame_budget_used_ns = 0,
        };

        return scheduler;
    }

    pub fn deinit(self: *FrameScheduler) void {
        self.task_queue.deinit();
        self.allocator.destroy(self);
    }

    /// Schedule a task
    pub fn schedule(self: *FrameScheduler, priority: Priority, callback: *const fn (*RenderTask) void, data: ?*anyopaque) !u64 {
        return self.task_queue.push(priority, callback, data);
    }

    /// Begin frame processing
    pub fn beginFrame(self: *FrameScheduler) FrameContext {
        const now = std.time.nanoTimestamp();
        const delta = now - self.last_frame_time;

        // Check for dropped frames
        if (@as(u64, @intCast(delta)) > self.target_frame_time_ns * 2) {
            self.dropped_frames += 1;
        }

        self.last_frame_time = now;
        self.frame_count += 1;
        self.frame_budget_used_ns = 0;

        return .{
            .scheduler = self,
            .start_time = now,
            .budget_ns = self.target_frame_time_ns,
        };
    }

    /// Process tasks within frame budget
    pub fn processTasks(self: *FrameScheduler, ctx: *FrameContext) usize {
        var processed: usize = 0;

        while (ctx.hasRemainingBudget()) {
            if (self.task_queue.pop()) |*task| {
                const start = std.time.nanoTimestamp();
                @constCast(task).execute();
                const elapsed = @as(u64, @intCast(std.time.nanoTimestamp() - start));
                ctx.consumeBudget(elapsed);
                processed += 1;
            } else {
                break;
            }
        }

        return processed;
    }

    /// Get frame statistics
    pub fn getStats(self: *const FrameScheduler) FrameStats {
        return .{
            .frame_count = self.frame_count,
            .dropped_frames = self.dropped_frames,
            .pending_tasks = self.task_queue.count(),
            .target_fps = @as(f64, 1_000_000_000.0) / @as(f64, @floatFromInt(self.target_frame_time_ns)),
        };
    }

    pub const FrameContext = struct {
        scheduler: *FrameScheduler,
        start_time: i128,
        budget_ns: u64,

        /// Check if there's remaining frame budget
        pub fn hasRemainingBudget(self: *const FrameContext) bool {
            const elapsed = @as(u64, @intCast(std.time.nanoTimestamp() - self.start_time));
            return elapsed < self.budget_ns;
        }

        /// Get remaining budget in nanoseconds
        pub fn remainingBudget(self: *const FrameContext) u64 {
            const elapsed = @as(u64, @intCast(std.time.nanoTimestamp() - self.start_time));
            if (elapsed >= self.budget_ns) return 0;
            return self.budget_ns - elapsed;
        }

        /// Consume budget
        pub fn consumeBudget(self: *FrameContext, amount_ns: u64) void {
            self.scheduler.frame_budget_used_ns += amount_ns;
        }
    };

    pub const FrameStats = struct {
        frame_count: u64,
        dropped_frames: u64,
        pending_tasks: usize,
        target_fps: f64,
    };
};

/// Request animation frame emulation
pub const AnimationFrameScheduler = struct {
    allocator: std.mem.Allocator,
    callbacks: std.ArrayListUnmanaged(Callback),
    next_id: u64,
    is_running: bool,

    const Callback = struct {
        id: u64,
        func: *const fn (u64) void,
        cancelled: bool,
    };

    pub fn init(allocator: std.mem.Allocator) !*AnimationFrameScheduler {
        const scheduler = try allocator.create(AnimationFrameScheduler);
        scheduler.* = .{
            .allocator = allocator,
            .callbacks = .{},
            .next_id = 1,
            .is_running = false,
        };
        return scheduler;
    }

    pub fn deinit(self: *AnimationFrameScheduler) void {
        self.callbacks.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    /// Request animation frame (similar to browser API)
    pub fn requestAnimationFrame(self: *AnimationFrameScheduler, callback: *const fn (u64) void) u64 {
        const id = self.next_id;
        self.next_id += 1;

        self.callbacks.append(self.allocator, .{
            .id = id,
            .func = callback,
            .cancelled = false,
        }) catch return 0;

        return id;
    }

    /// Cancel animation frame
    pub fn cancelAnimationFrame(self: *AnimationFrameScheduler, id: u64) void {
        for (self.callbacks.items) |*cb| {
            if (cb.id == id) {
                cb.cancelled = true;
                return;
            }
        }
    }

    /// Execute pending callbacks
    pub fn tick(self: *AnimationFrameScheduler, timestamp: u64) void {
        // Copy callbacks to avoid mutation during iteration
        const callbacks = self.callbacks.items;
        self.callbacks.clearRetainingCapacity();

        for (callbacks) |cb| {
            if (!cb.cancelled) {
                cb.func(timestamp);
            }
        }
    }

    /// Get pending callback count
    pub fn pendingCount(self: *const AnimationFrameScheduler) usize {
        var count: usize = 0;
        for (self.callbacks.items) |cb| {
            if (!cb.cancelled) count += 1;
        }
        return count;
    }
};

// ============================================================================
// Unit Tests
// ============================================================================

test "PriorityQueue basic operations" {
    const allocator = std.testing.allocator;

    var pq = try PriorityQueue.init(allocator);
    defer pq.deinit();

    const callback = struct {
        fn cb(_: *RenderTask) void {}
    }.cb;

    _ = try pq.push(.normal, callback, null);
    _ = try pq.push(.critical, callback, null);
    _ = try pq.push(.low, callback, null);

    try std.testing.expectEqual(@as(usize, 3), pq.count());

    // Should pop critical first
    const task1 = pq.pop();
    try std.testing.expect(task1 != null);
    try std.testing.expectEqual(Priority.critical, task1.?.priority);
}

test "RenderBatcher operations" {
    const allocator = std.testing.allocator;

    var batcher = try RenderBatcher.init(allocator);
    defer batcher.deinit();

    try batcher.beginBatch(.dom_updates);
    try batcher.addOperation(.{ .op_type = .create, .target_id = 1, .data = null });
    try batcher.addOperation(.{ .op_type = .update, .target_id = 2, .data = null });
    batcher.endBatch();

    try std.testing.expectEqual(@as(usize, 2), batcher.pendingCount());

    try batcher.flush();
    try std.testing.expectEqual(@as(usize, 0), batcher.pendingCount());
}

test "FrameScheduler basic usage" {
    const allocator = std.testing.allocator;

    var scheduler = try FrameScheduler.init(allocator, 16_666_667);
    defer scheduler.deinit();

    const callback = struct {
        fn cb(_: *RenderTask) void {}
    }.cb;

    _ = try scheduler.schedule(.normal, callback, null);
    _ = try scheduler.schedule(.high, callback, null);

    const stats = scheduler.getStats();
    try std.testing.expectEqual(@as(usize, 2), stats.pending_tasks);
}

test "FrameScheduler frame context" {
    const allocator = std.testing.allocator;

    var scheduler = try FrameScheduler.init(allocator, 16_666_667);
    defer scheduler.deinit();

    var ctx = scheduler.beginFrame();
    try std.testing.expect(ctx.hasRemainingBudget());
    try std.testing.expect(ctx.remainingBudget() > 0);
}

test "AnimationFrameScheduler request and cancel" {
    const allocator = std.testing.allocator;

    var scheduler = try AnimationFrameScheduler.init(allocator);
    defer scheduler.deinit();

    var called = false;
    const callback = struct {
        fn cb(_: u64) void {
            // Cannot capture mutable variable, so this is a simplified test
        }
    }.cb;
    _ = &called;

    const id1 = scheduler.requestAnimationFrame(callback);
    const id2 = scheduler.requestAnimationFrame(callback);

    try std.testing.expectEqual(@as(usize, 2), scheduler.pendingCount());

    scheduler.cancelAnimationFrame(id1);
    try std.testing.expectEqual(@as(usize, 1), scheduler.pendingCount());

    _ = id2;
}
