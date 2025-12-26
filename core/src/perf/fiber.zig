//! Fiber-based Incremental Rendering
//!
//! Implements React-like Fiber architecture for:
//! - Incremental rendering (work can be paused/resumed)
//! - Priority-based scheduling (urgent updates first)
//! - Concurrent mode (multiple renders in progress)

const std = @import("std");

// ============================================================================
// Priority Levels
// ============================================================================

/// Work priority levels (higher = more urgent)
pub const Priority = enum(u8) {
    /// Background work (prefetching, prerendering)
    idle = 0,
    /// Normal updates (state changes, data fetching)
    normal = 1,
    /// High priority (hover, focus)
    high = 2,
    /// User blocking (input, clicks)
    user_blocking = 3,
    /// Immediate (animations, gestures)
    immediate = 4,
    /// Sync (forced layout, measurements)
    sync = 5,

    /// Get time budget in nanoseconds for this priority
    pub fn getTimeBudget(self: Priority) u64 {
        return switch (self) {
            .idle => 50_000_000, // 50ms
            .normal => 16_000_000, // 16ms (60fps)
            .high => 10_000_000, // 10ms
            .user_blocking => 5_000_000, // 5ms
            .immediate => 1_000_000, // 1ms
            .sync => 0, // No budget - run to completion
        };
    }

    /// Check if this priority can interrupt another
    pub fn canInterrupt(self: Priority, other: Priority) bool {
        return @intFromEnum(self) > @intFromEnum(other);
    }
};

// ============================================================================
// Fiber Work Unit
// ============================================================================

pub const MAX_FIBERS = 512;

/// Work status for a fiber
pub const FiberStatus = enum(u8) {
    /// Fiber is pending execution
    pending = 0,
    /// Fiber is currently being processed
    in_progress = 1,
    /// Fiber work is complete
    completed = 2,
    /// Fiber was cancelled
    cancelled = 3,
};

/// Fiber work type
pub const FiberWorkType = enum(u8) {
    /// Create a new node
    create = 0,
    /// Update an existing node
    update = 1,
    /// Delete a node
    delete = 2,
    /// Reconcile children
    reconcile = 3,
    /// Apply effects (after render)
    effect = 4,
    /// Layout measurement
    layout = 5,
};

/// A unit of work in the fiber system
pub const Fiber = struct {
    /// Unique fiber ID
    id: u32 = 0,

    /// VNode ID this fiber references
    vnode_id: u32 = 0,

    /// DOM ID for this fiber
    dom_id: u32 = 0,

    /// Type of work to perform
    work_type: FiberWorkType = .create,

    /// Current status
    status: FiberStatus = .pending,

    /// Priority level
    priority: Priority = .normal,

    /// Tree navigation
    parent: u32 = 0,
    first_child: u32 = 0,
    sibling: u32 = 0,

    /// Alternate fiber (for double buffering)
    alternate: u32 = 0,

    /// Effect flags
    has_effect: bool = false,
    needs_layout: bool = false,

    /// Timestamp when work started
    start_time: u64 = 0,

    /// Is this fiber valid/in-use?
    valid: bool = false,

    pub fn init(id: u32, vnode_id: u32, work_type: FiberWorkType, priority: Priority) Fiber {
        return .{
            .id = id,
            .vnode_id = vnode_id,
            .work_type = work_type,
            .priority = priority,
            .status = .pending,
            .valid = true,
        };
    }

    pub fn reset(self: *Fiber) void {
        self.* = .{};
    }
};

// ============================================================================
// Fiber Scheduler
// ============================================================================

/// Scheduler manages fiber execution with priority queues
pub const Scheduler = struct {
    const Self = @This();

    /// Priority queues (index = priority level)
    queues: [6]PriorityQueue = undefined,

    /// Current executing fiber
    current_fiber: u32 = 0,

    /// Is work in progress?
    working: bool = false,

    /// Frame deadline (timestamp)
    deadline: u64 = 0,

    /// Statistics
    fibers_processed: u64 = 0,
    fibers_yielded: u64 = 0,
    total_work_time: u64 = 0,

    pub fn init() Self {
        var self = Self{};
        for (&self.queues) |*q| {
            q.* = PriorityQueue.init();
        }
        return self;
    }

    /// Schedule a fiber for execution
    pub fn schedule(self: *Self, fiber_id: u32, priority: Priority) void {
        self.queues[@intFromEnum(priority)].push(fiber_id);
    }

    /// Get next fiber to process (highest priority first)
    pub fn getNextFiber(self: *Self) ?u32 {
        // Check queues from highest to lowest priority
        var i: usize = 5;
        while (i > 0) : (i -= 1) {
            if (self.queues[i].pop()) |fiber_id| {
                return fiber_id;
            }
        }
        if (self.queues[0].pop()) |fiber_id| {
            return fiber_id;
        }
        return null;
    }

    /// Check if we should yield (deadline exceeded)
    pub fn shouldYield(self: *const Self, priority: Priority) bool {
        if (priority == .sync) return false; // Sync never yields

        const now = getTimestamp();
        return now >= self.deadline;
    }

    /// Set deadline for current frame
    pub fn setDeadline(self: *Self, priority: Priority) void {
        self.deadline = getTimestamp() + priority.getTimeBudget();
    }

    /// Cancel all pending work
    pub fn cancelAll(self: *Self) void {
        for (&self.queues) |*q| {
            q.clear();
        }
        self.working = false;
        self.current_fiber = 0;
    }

    /// Get pending work count
    pub fn getPendingCount(self: *const Self) u32 {
        var count: u32 = 0;
        for (self.queues) |q| {
            count += q.count;
        }
        return count;
    }

    /// Get scheduler statistics
    pub fn getStats(self: *const Self) SchedulerStats {
        return .{
            .fibers_processed = self.fibers_processed,
            .fibers_yielded = self.fibers_yielded,
            .total_work_time = self.total_work_time,
            .pending_count = self.getPendingCount(),
        };
    }
};

/// Scheduler statistics
pub const SchedulerStats = struct {
    fibers_processed: u64,
    fibers_yielded: u64,
    total_work_time: u64,
    pending_count: u32,
};

/// Simple priority queue (ring buffer)
pub const PriorityQueue = struct {
    items: [64]u32 = undefined,
    head: u32 = 0,
    tail: u32 = 0,
    count: u32 = 0,

    pub fn init() PriorityQueue {
        return .{};
    }

    pub fn push(self: *PriorityQueue, item: u32) void {
        if (self.count >= 64) return; // Queue full
        self.items[self.tail] = item;
        self.tail = (self.tail + 1) % 64;
        self.count += 1;
    }

    pub fn pop(self: *PriorityQueue) ?u32 {
        if (self.count == 0) return null;
        const item = self.items[self.head];
        self.head = (self.head + 1) % 64;
        self.count -= 1;
        return item;
    }

    pub fn clear(self: *PriorityQueue) void {
        self.head = 0;
        self.tail = 0;
        self.count = 0;
    }
};

// ============================================================================
// Fiber Pool
// ============================================================================

/// Pool of reusable Fiber objects
pub const FiberPool = struct {
    const Self = @This();

    fibers: [MAX_FIBERS]Fiber = undefined,
    free_list: [MAX_FIBERS]u32 = undefined,
    free_count: u32 = MAX_FIBERS,
    next_id: u32 = 1,

    pub fn init() Self {
        var self = Self{};
        for (&self.fibers, 0..) |*f, i| {
            f.* = Fiber{};
            self.free_list[i] = @intCast(i);
        }
        return self;
    }

    /// Allocate a new fiber
    pub fn alloc(self: *Self, vnode_id: u32, work_type: FiberWorkType, priority: Priority) ?*Fiber {
        if (self.free_count == 0) return null;

        self.free_count -= 1;
        const idx = self.free_list[self.free_count];
        const fiber = &self.fibers[idx];

        fiber.* = Fiber.init(self.next_id, vnode_id, work_type, priority);
        self.next_id += 1;

        return fiber;
    }

    /// Free a fiber back to the pool
    pub fn free(self: *Self, fiber: *Fiber) void {
        if (!fiber.valid) return;

        const idx = self.getFiberIndex(fiber);
        if (idx) |i| {
            fiber.reset();
            self.free_list[self.free_count] = i;
            self.free_count += 1;
        }
    }

    /// Get fiber by ID
    pub fn get(self: *Self, id: u32) ?*Fiber {
        for (&self.fibers) |*f| {
            if (f.valid and f.id == id) return f;
        }
        return null;
    }

    /// Get fiber index in pool
    fn getFiberIndex(self: *Self, fiber: *Fiber) ?u32 {
        const ptr = @intFromPtr(fiber);
        const base = @intFromPtr(&self.fibers[0]);
        const size = @sizeOf(Fiber);

        if (ptr < base) return null;
        const offset = ptr - base;
        if (offset % size != 0) return null;

        const idx = offset / size;
        if (idx >= MAX_FIBERS) return null;

        return @intCast(idx);
    }

    /// Get number of active fibers
    pub fn getActiveCount(self: *const Self) u32 {
        return MAX_FIBERS - self.free_count;
    }

    /// Reset all fibers
    pub fn reset(self: *Self) void {
        for (&self.fibers, 0..) |*f, i| {
            f.* = Fiber{};
            self.free_list[i] = @intCast(i);
        }
        self.free_count = MAX_FIBERS;
    }
};

// ============================================================================
// Concurrent Renderer
// ============================================================================

/// Concurrent mode render state
pub const RenderLane = enum(u8) {
    /// Synchronous blocking render
    sync = 0,
    /// Default concurrent render
    concurrent = 1,
    /// Transition (low priority UI updates)
    transition = 2,
    /// Deferred (can be interrupted)
    deferred = 3,
};

/// Concurrent renderer manages multiple render lanes
pub const ConcurrentRenderer = struct {
    const Self = @This();

    /// Fiber pool for allocation
    fiber_pool: FiberPool = FiberPool.init(),

    /// Scheduler for priority management
    scheduler: Scheduler = Scheduler.init(),

    /// Current render lane
    current_lane: RenderLane = .sync,

    /// Work-in-progress root fiber
    wip_root: u32 = 0,

    /// Current root fiber (committed)
    current_root: u32 = 0,

    /// Pending effects to run after commit
    pending_effects: [64]u32 = undefined,
    effect_count: u32 = 0,

    /// Is a render in progress?
    render_in_progress: bool = false,

    /// Statistics
    renders_completed: u64 = 0,
    renders_interrupted: u64 = 0,

    pub fn init() Self {
        return .{};
    }

    /// Start a new render
    pub fn startRender(self: *Self, root_vnode_id: u32, lane: RenderLane) ?*Fiber {
        // Allocate root fiber
        const priority: Priority = switch (lane) {
            .sync => .sync,
            .concurrent => .normal,
            .transition => .high,
            .deferred => .idle,
        };

        const root = self.fiber_pool.alloc(root_vnode_id, .reconcile, priority) orelse return null;

        self.wip_root = root.id;
        self.current_lane = lane;
        self.render_in_progress = true;

        // Schedule the root fiber
        self.scheduler.schedule(root.id, priority);
        self.scheduler.setDeadline(priority);

        return root;
    }

    /// Perform work loop (call each frame)
    pub fn workLoop(self: *Self) WorkLoopResult {
        const start_time = getTimestamp();
        var fibers_processed: u32 = 0;

        while (self.scheduler.getNextFiber()) |fiber_id| {
            const fiber = self.fiber_pool.get(fiber_id) orelse continue;

            // Check if we should yield
            if (self.scheduler.shouldYield(fiber.priority)) {
                // Re-schedule this fiber
                self.scheduler.schedule(fiber_id, fiber.priority);
                self.scheduler.fibers_yielded += 1;
                break;
            }

            // Process the fiber
            self.processFilber(fiber);
            fibers_processed += 1;
            self.scheduler.fibers_processed += 1;
        }

        const work_time = getTimestamp() - start_time;
        self.scheduler.total_work_time += work_time;

        // Check if render is complete
        if (self.scheduler.getPendingCount() == 0 and self.render_in_progress) {
            self.render_in_progress = false;
            self.renders_completed += 1;
            return .{ .completed = true, .fibers_processed = fibers_processed, .work_time_ns = work_time };
        }

        return .{ .completed = false, .fibers_processed = fibers_processed, .work_time_ns = work_time };
    }

    /// Process a single fiber
    fn processFilber(self: *Self, fiber: *Fiber) void {
        fiber.status = .in_progress;
        fiber.start_time = getTimestamp();

        switch (fiber.work_type) {
            .create => self.performCreate(fiber),
            .update => self.performUpdate(fiber),
            .delete => self.performDelete(fiber),
            .reconcile => self.performReconcile(fiber),
            .effect => self.performEffect(fiber),
            .layout => self.performLayout(fiber),
        }

        fiber.status = .completed;
    }

    fn performCreate(self: *Self, fiber: *Fiber) void {
        // Schedule child fibers
        if (fiber.first_child != 0) {
            self.scheduler.schedule(fiber.first_child, fiber.priority);
        }
        // Schedule sibling
        if (fiber.sibling != 0) {
            self.scheduler.schedule(fiber.sibling, fiber.priority);
        }
        // Mark for effect if needed
        if (fiber.has_effect) {
            self.queueEffect(fiber.id);
        }
    }

    fn performUpdate(self: *Self, fiber: *Fiber) void {
        // Similar to create but for updates
        if (fiber.first_child != 0) {
            self.scheduler.schedule(fiber.first_child, fiber.priority);
        }
        if (fiber.sibling != 0) {
            self.scheduler.schedule(fiber.sibling, fiber.priority);
        }
    }

    fn performDelete(self: *Self, fiber: *Fiber) void {
        // Cleanup fiber
        _ = fiber;
    }

    fn performReconcile(self: *Self, fiber: *Fiber) void {
        // Reconcile children - would compare with alternate
        if (fiber.first_child != 0) {
            self.scheduler.schedule(fiber.first_child, fiber.priority);
        }
    }

    fn performEffect(self: *Self, fiber: *Fiber) void {
        // Run effect callbacks
        _ = fiber;
    }

    fn performLayout(self: *Self, fiber: *Fiber) void {
        // Measure and layout
        _ = fiber;
    }

    fn queueEffect(self: *Self, fiber_id: u32) void {
        if (self.effect_count < 64) {
            self.pending_effects[self.effect_count] = fiber_id;
            self.effect_count += 1;
        }
    }

    /// Commit the current render
    pub fn commit(self: *Self) void {
        // Swap current and WIP roots
        self.current_root = self.wip_root;
        self.wip_root = 0;

        // Run pending effects
        for (self.pending_effects[0..self.effect_count]) |fiber_id| {
            if (self.fiber_pool.get(fiber_id)) |fiber| {
                fiber.work_type = .effect;
                self.scheduler.schedule(fiber_id, .immediate);
            }
        }
        self.effect_count = 0;
    }

    /// Interrupt current render for higher priority work
    pub fn interrupt(self: *Self, new_priority: Priority) bool {
        if (!self.render_in_progress) return false;

        // Check if new work can interrupt
        const current_priority: Priority = switch (self.current_lane) {
            .sync => return false, // Sync cannot be interrupted
            .concurrent => .normal,
            .transition => .high,
            .deferred => .idle,
        };

        if (new_priority.canInterrupt(current_priority)) {
            self.renders_interrupted += 1;
            return true;
        }

        return false;
    }

    /// Cancel current render
    pub fn cancelRender(self: *Self) void {
        self.scheduler.cancelAll();
        self.render_in_progress = false;
        self.wip_root = 0;
        self.effect_count = 0;
    }

    /// Get renderer statistics
    pub fn getStats(self: *const Self) RendererStats {
        return .{
            .renders_completed = self.renders_completed,
            .renders_interrupted = self.renders_interrupted,
            .active_fibers = self.fiber_pool.getActiveCount(),
            .pending_work = self.scheduler.getPendingCount(),
            .scheduler_stats = self.scheduler.getStats(),
        };
    }

    /// Reset renderer state
    pub fn reset(self: *Self) void {
        self.fiber_pool.reset();
        self.scheduler = Scheduler.init();
        self.current_lane = .sync;
        self.wip_root = 0;
        self.current_root = 0;
        self.effect_count = 0;
        self.render_in_progress = false;
    }
};

/// Work loop result
pub const WorkLoopResult = struct {
    completed: bool,
    fibers_processed: u32,
    work_time_ns: u64,
};

/// Renderer statistics
pub const RendererStats = struct {
    renders_completed: u64,
    renders_interrupted: u64,
    active_fibers: u32,
    pending_work: u32,
    scheduler_stats: SchedulerStats,
};

// ============================================================================
// Global Instance
// ============================================================================

var global_renderer: ConcurrentRenderer = ConcurrentRenderer.init();

pub fn getRenderer() *ConcurrentRenderer {
    return &global_renderer;
}

pub fn resetRenderer() void {
    global_renderer.reset();
}

// ============================================================================
// Utilities
// ============================================================================

/// Get current timestamp in nanoseconds
fn getTimestamp() u64 {
    return @intCast(std.time.nanoTimestamp());
}

// ============================================================================
// Tests
// ============================================================================

test "Priority time budgets" {
    try std.testing.expectEqual(@as(u64, 50_000_000), Priority.idle.getTimeBudget());
    try std.testing.expectEqual(@as(u64, 16_000_000), Priority.normal.getTimeBudget());
    try std.testing.expectEqual(@as(u64, 0), Priority.sync.getTimeBudget());
}

test "Priority interruption" {
    try std.testing.expect(Priority.immediate.canInterrupt(.normal));
    try std.testing.expect(Priority.user_blocking.canInterrupt(.high));
    try std.testing.expect(!Priority.normal.canInterrupt(.high));
    try std.testing.expect(!Priority.idle.canInterrupt(.normal));
}

test "PriorityQueue operations" {
    var queue = PriorityQueue.init();

    queue.push(1);
    queue.push(2);
    queue.push(3);

    try std.testing.expectEqual(@as(?u32, 1), queue.pop());
    try std.testing.expectEqual(@as(?u32, 2), queue.pop());
    try std.testing.expectEqual(@as(?u32, 3), queue.pop());
    try std.testing.expectEqual(@as(?u32, null), queue.pop());
}

test "FiberPool allocation" {
    var pool = FiberPool.init();

    const f1 = pool.alloc(1, .create, .normal);
    try std.testing.expect(f1 != null);
    try std.testing.expectEqual(@as(u32, 1), f1.?.vnode_id);

    const f2 = pool.alloc(2, .update, .high);
    try std.testing.expect(f2 != null);
    try std.testing.expectEqual(@as(u32, 2), f2.?.vnode_id);

    try std.testing.expectEqual(@as(u32, 2), pool.getActiveCount());

    pool.free(f1.?);
    try std.testing.expectEqual(@as(u32, 1), pool.getActiveCount());
}

test "Scheduler priority ordering" {
    var scheduler = Scheduler.init();

    scheduler.schedule(1, .idle);
    scheduler.schedule(2, .normal);
    scheduler.schedule(3, .immediate);

    // Should get highest priority first
    try std.testing.expectEqual(@as(?u32, 3), scheduler.getNextFiber());
    try std.testing.expectEqual(@as(?u32, 2), scheduler.getNextFiber());
    try std.testing.expectEqual(@as(?u32, 1), scheduler.getNextFiber());
    try std.testing.expectEqual(@as(?u32, null), scheduler.getNextFiber());
}

test "ConcurrentRenderer basic flow" {
    var renderer = ConcurrentRenderer.init();

    // Start a render
    const root = renderer.startRender(1, .concurrent);
    try std.testing.expect(root != null);
    try std.testing.expect(renderer.render_in_progress);

    // Work loop should process the fiber
    const result = renderer.workLoop();
    try std.testing.expect(result.fibers_processed > 0);
}

test "ConcurrentRenderer interrupt" {
    var renderer = ConcurrentRenderer.init();

    _ = renderer.startRender(1, .deferred);
    try std.testing.expect(renderer.render_in_progress);

    // High priority can interrupt deferred
    try std.testing.expect(renderer.interrupt(.immediate));

    // Sync cannot be interrupted
    renderer.reset();
    _ = renderer.startRender(1, .sync);
    try std.testing.expect(!renderer.interrupt(.immediate));
}

test "Global renderer" {
    resetRenderer();
    const renderer = getRenderer();

    const stats = renderer.getStats();
    try std.testing.expectEqual(@as(u64, 0), stats.renders_completed);
}
