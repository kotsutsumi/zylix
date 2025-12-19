//! Zylix Scheduler - Time Management System
//!
//! Cross-platform scheduler for timers, animations, and deferred execution.
//! Works on native platforms and WASM.
//!
//! Design Philosophy:
//! - Frame-rate independent timing
//! - Zero allocation after initialization (arena-based)
//! - Deterministic execution order
//! - WASM-compatible (no threads, relies on host callbacks)

const std = @import("std");

/// Maximum number of scheduled tasks
pub const MAX_TASKS: usize = 256;

/// Task state
pub const TaskState = enum(u8) {
    inactive = 0,
    pending = 1,
    running = 2,
    completed = 3,
    cancelled = 4,
};

/// Task type
pub const TaskType = enum(u8) {
    /// Execute once after delay
    once = 0,
    /// Execute repeatedly at interval
    repeating = 1,
    /// Execute every frame
    every_frame = 2,
    /// Execute after N frames
    after_frames = 3,
};

/// Task ID (handle for external reference)
pub const TaskId = u32;

/// Invalid task ID sentinel
pub const INVALID_TASK_ID: TaskId = 0;

/// Task callback signature
/// Returns true to keep task alive (for repeating), false to complete
pub const TaskCallback = *const fn (task_id: TaskId, user_data: ?*anyopaque) bool;

/// Scheduled task
pub const Task = struct {
    id: TaskId = INVALID_TASK_ID,
    state: TaskState = .inactive,
    task_type: TaskType = .once,

    /// Time until execution (seconds)
    delay: f32 = 0,
    /// Original delay for repeating tasks
    interval: f32 = 0,
    /// Frame counter for frame-based tasks
    frames: u32 = 0,
    /// Original frame count for repeating
    frame_interval: u32 = 0,

    /// Callback function
    callback: ?TaskCallback = null,
    /// User data pointer
    user_data: ?*anyopaque = null,

    /// Number of times executed
    execution_count: u32 = 0,
    /// Maximum executions (0 = unlimited)
    max_executions: u32 = 0,

    /// Priority (higher = earlier execution)
    priority: i16 = 0,

    pub fn reset(self: *Task) void {
        self.* = Task{};
    }
};

/// Scheduler statistics
pub const SchedulerStats = extern struct {
    /// Total tasks created
    tasks_created: u32 = 0,
    /// Currently active tasks
    active_tasks: u32 = 0,
    /// Tasks completed this frame
    completed_this_frame: u32 = 0,
    /// Total callbacks executed
    callbacks_executed: u64 = 0,
    /// Current frame number
    frame_number: u64 = 0,
    /// Total elapsed time
    total_time: f32 = 0,
    /// Delta time of last update
    delta_time: f32 = 0,
    /// Time scale (1.0 = normal)
    time_scale: f32 = 1.0,
};

// === WASM Event Queue (for JS interop) ===

/// Maximum events in queue
pub const MAX_EVENTS: usize = 64;

/// Timer event for WASM (fired events that JS should handle)
pub const TimerEvent = extern struct {
    /// Task ID that fired
    task_id: TaskId = INVALID_TASK_ID,
    /// User-defined tag (for JS to identify callback)
    tag: u32 = 0,
    /// Execution count
    execution_count: u32 = 0,
    /// Is this a repeating timer?
    is_repeating: u8 = 0,
    _pad: [3]u8 = .{ 0, 0, 0 },
};

/// WASM timer task (simplified for JS interop)
pub const WasmTimer = struct {
    id: TaskId = INVALID_TASK_ID,
    state: TaskState = .inactive,
    task_type: TaskType = .once,
    delay: f32 = 0,
    interval: f32 = 0,
    tag: u32 = 0, // JS callback identifier
};

var wasm_timers: [MAX_TASKS]WasmTimer = undefined;
var event_queue: [MAX_EVENTS]TimerEvent = undefined;
var event_write_idx: usize = 0;
var event_read_idx: usize = 0;

// === Global State ===

var tasks: [MAX_TASKS]Task = undefined;
var next_task_id: TaskId = 1;
var stats: SchedulerStats = .{};
var initialized: bool = false;
var paused: bool = false;

// === Initialization ===

/// Initialize the scheduler
pub fn init() void {
    for (&tasks) |*task| {
        task.reset();
    }
    next_task_id = 1;
    stats = .{};
    initialized = true;
    paused = false;
}

/// Deinitialize the scheduler
pub fn deinit() void {
    initialized = false;
}

/// Reset scheduler (clear all tasks)
pub fn reset() void {
    if (initialized) {
        init();
    }
}

// === Task Creation ===

/// Find a free task slot
fn findFreeSlot() ?*Task {
    for (&tasks) |*task| {
        if (task.state == .inactive) {
            return task;
        }
    }
    return null;
}

/// Schedule a one-time task after delay (seconds)
pub fn scheduleAfter(delay: f32, callback: TaskCallback, user_data: ?*anyopaque) TaskId {
    return scheduleTask(.{
        .task_type = .once,
        .delay = delay,
        .callback = callback,
        .user_data = user_data,
    });
}

/// Schedule a repeating task at interval (seconds)
pub fn scheduleRepeating(interval: f32, callback: TaskCallback, user_data: ?*anyopaque) TaskId {
    return scheduleTask(.{
        .task_type = .repeating,
        .delay = interval,
        .interval = interval,
        .callback = callback,
        .user_data = user_data,
    });
}

/// Schedule a task to run every frame
pub fn scheduleEveryFrame(callback: TaskCallback, user_data: ?*anyopaque) TaskId {
    return scheduleTask(.{
        .task_type = .every_frame,
        .callback = callback,
        .user_data = user_data,
    });
}

/// Schedule a task to run after N frames
pub fn scheduleAfterFrames(frames: u32, callback: TaskCallback, user_data: ?*anyopaque) TaskId {
    return scheduleTask(.{
        .task_type = .after_frames,
        .frames = frames,
        .callback = callback,
        .user_data = user_data,
    });
}

/// Internal task scheduling
fn scheduleTask(config: struct {
    task_type: TaskType = .once,
    delay: f32 = 0,
    interval: f32 = 0,
    frames: u32 = 0,
    frame_interval: u32 = 0,
    callback: ?TaskCallback = null,
    user_data: ?*anyopaque = null,
    max_executions: u32 = 0,
    priority: i16 = 0,
}) TaskId {
    if (!initialized) return INVALID_TASK_ID;

    const slot = findFreeSlot() orelse return INVALID_TASK_ID;

    const id = next_task_id;
    next_task_id +%= 1;
    if (next_task_id == INVALID_TASK_ID) next_task_id = 1;

    slot.* = .{
        .id = id,
        .state = .pending,
        .task_type = config.task_type,
        .delay = config.delay,
        .interval = config.interval,
        .frames = config.frames,
        .frame_interval = config.frame_interval,
        .callback = config.callback,
        .user_data = config.user_data,
        .max_executions = config.max_executions,
        .priority = config.priority,
    };

    stats.tasks_created += 1;
    stats.active_tasks += 1;

    return id;
}

// === Task Management ===

/// Find task by ID
fn findTask(id: TaskId) ?*Task {
    if (id == INVALID_TASK_ID) return null;
    for (&tasks) |*task| {
        if (task.id == id and task.state != .inactive) {
            return task;
        }
    }
    return null;
}

/// Cancel a scheduled task
pub fn cancel(id: TaskId) bool {
    if (findTask(id)) |task| {
        task.state = .cancelled;
        stats.active_tasks -|= 1;
        return true;
    }
    return false;
}

/// Check if task exists and is active
pub fn isActive(id: TaskId) bool {
    if (findTask(id)) |task| {
        return task.state == .pending or task.state == .running;
    }
    return false;
}

/// Get remaining time for a task (seconds)
pub fn getRemainingTime(id: TaskId) f32 {
    if (findTask(id)) |task| {
        return task.delay;
    }
    return 0;
}

/// Get remaining frames for a frame-based task
pub fn getRemainingFrames(id: TaskId) u32 {
    if (findTask(id)) |task| {
        return task.frames;
    }
    return 0;
}

// === Time Control ===

/// Pause the scheduler
pub fn pause() void {
    paused = true;
}

/// Resume the scheduler
pub fn resume_() void {
    paused = false;
}

/// Check if paused
pub fn isPaused() bool {
    return paused;
}

/// Set time scale (1.0 = normal, 0.5 = half speed, 2.0 = double speed)
pub fn setTimeScale(scale: f32) void {
    stats.time_scale = @max(0.0, scale);
}

/// Get time scale
pub fn getTimeScale() f32 {
    return stats.time_scale;
}

// === Update ===

/// Update scheduler (call every frame with delta time in seconds)
pub fn update(delta_time: f32) void {
    if (!initialized or paused) return;

    const scaled_dt = delta_time * stats.time_scale;
    stats.delta_time = scaled_dt;
    stats.total_time += scaled_dt;
    stats.frame_number += 1;
    stats.completed_this_frame = 0;

    // Process all pending tasks
    for (&tasks) |*task| {
        if (task.state != .pending) continue;

        var should_execute = false;

        switch (task.task_type) {
            .once, .repeating => {
                task.delay -= scaled_dt;
                if (task.delay <= 0) {
                    should_execute = true;
                }
            },
            .every_frame => {
                should_execute = true;
            },
            .after_frames => {
                if (task.frames > 0) {
                    task.frames -= 1;
                }
                if (task.frames == 0) {
                    should_execute = true;
                }
            },
        }

        if (should_execute) {
            executeTask(task);
        }
    }

    // Cleanup completed/cancelled tasks
    for (&tasks) |*task| {
        if (task.state == .completed or task.state == .cancelled) {
            task.reset();
        }
    }
}

/// Execute a task
fn executeTask(task: *Task) void {
    task.state = .running;

    var keep_alive = false;
    if (task.callback) |cb| {
        keep_alive = cb(task.id, task.user_data);
        stats.callbacks_executed += 1;
    }

    task.execution_count += 1;

    // Check if task should continue
    const max_reached = task.max_executions > 0 and task.execution_count >= task.max_executions;

    if (keep_alive and !max_reached) {
        // Reschedule based on type
        switch (task.task_type) {
            .repeating => {
                task.delay = task.interval;
                task.state = .pending;
            },
            .every_frame => {
                task.state = .pending;
            },
            .after_frames => {
                task.frames = task.frame_interval;
                if (task.frame_interval > 0) {
                    task.state = .pending;
                } else {
                    task.state = .completed;
                    stats.completed_this_frame += 1;
                    stats.active_tasks -|= 1;
                }
            },
            .once => {
                task.state = .completed;
                stats.completed_this_frame += 1;
                stats.active_tasks -|= 1;
            },
        }
    } else {
        task.state = .completed;
        stats.completed_this_frame += 1;
        stats.active_tasks -|= 1;
    }
}

// === Statistics ===

/// Get scheduler statistics
pub fn getStats() *const SchedulerStats {
    return &stats;
}

/// Get active task count
pub fn getActiveTaskCount() u32 {
    return stats.active_tasks;
}

/// Get total elapsed time
pub fn getTotalTime() f32 {
    return stats.total_time;
}

/// Get current frame number
pub fn getFrameNumber() u64 {
    return stats.frame_number;
}

// === Convenience Functions ===

/// Schedule a task to run after N milliseconds
pub fn scheduleAfterMs(ms: u32, callback: TaskCallback, user_data: ?*anyopaque) TaskId {
    return scheduleAfter(@as(f32, @floatFromInt(ms)) / 1000.0, callback, user_data);
}

/// Create a simple timer (returns task ID)
pub fn createTimer(duration_seconds: f32, callback: TaskCallback) TaskId {
    return scheduleAfter(duration_seconds, callback, null);
}

/// Create an interval timer (repeating)
pub fn createInterval(interval_seconds: f32, callback: TaskCallback) TaskId {
    return scheduleRepeating(interval_seconds, callback, null);
}

// === WASM Timer API (for JavaScript interop) ===

/// Initialize WASM timer system
pub fn initWasmTimers() void {
    for (&wasm_timers) |*timer| {
        timer.* = WasmTimer{};
    }
    for (&event_queue) |*event| {
        event.* = TimerEvent{};
    }
    event_write_idx = 0;
    event_read_idx = 0;
}

/// Find free WASM timer slot
fn findFreeWasmSlot() ?*WasmTimer {
    for (&wasm_timers) |*timer| {
        if (timer.state == .inactive) {
            return timer;
        }
    }
    return null;
}

/// Create a one-shot WASM timer (JS-friendly)
pub fn createWasmTimer(delay_seconds: f32, tag: u32) TaskId {
    const slot = findFreeWasmSlot() orelse return INVALID_TASK_ID;

    const id = next_task_id;
    next_task_id +%= 1;
    if (next_task_id == INVALID_TASK_ID) next_task_id = 1;

    slot.* = .{
        .id = id,
        .state = .pending,
        .task_type = .once,
        .delay = delay_seconds,
        .interval = 0,
        .tag = tag,
    };

    stats.tasks_created += 1;
    stats.active_tasks += 1;

    return id;
}

/// Create a repeating WASM timer (JS-friendly)
pub fn createWasmInterval(interval_seconds: f32, tag: u32) TaskId {
    const slot = findFreeWasmSlot() orelse return INVALID_TASK_ID;

    const id = next_task_id;
    next_task_id +%= 1;
    if (next_task_id == INVALID_TASK_ID) next_task_id = 1;

    slot.* = .{
        .id = id,
        .state = .pending,
        .task_type = .repeating,
        .delay = interval_seconds,
        .interval = interval_seconds,
        .tag = tag,
    };

    stats.tasks_created += 1;
    stats.active_tasks += 1;

    return id;
}

/// Cancel a WASM timer
pub fn cancelWasmTimer(id: TaskId) bool {
    if (id == INVALID_TASK_ID) return false;
    for (&wasm_timers) |*timer| {
        if (timer.id == id and timer.state != .inactive) {
            timer.state = .cancelled;
            stats.active_tasks -|= 1;
            return true;
        }
    }
    return false;
}

/// Push event to queue
fn pushEvent(event: TimerEvent) void {
    event_queue[event_write_idx] = event;
    event_write_idx = (event_write_idx + 1) % MAX_EVENTS;
}

/// Update WASM timers (call from main update or separately)
pub fn updateWasmTimers(delta_time: f32) void {
    if (paused) return;

    const scaled_dt = delta_time * stats.time_scale;

    for (&wasm_timers) |*timer| {
        if (timer.state != .pending) continue;

        timer.delay -= scaled_dt;

        if (timer.delay <= 0) {
            // Push event for JS
            pushEvent(.{
                .task_id = timer.id,
                .tag = timer.tag,
                .execution_count = 1,
                .is_repeating = if (timer.task_type == .repeating) 1 else 0,
            });

            stats.callbacks_executed += 1;

            if (timer.task_type == .repeating) {
                timer.delay = timer.interval;
            } else {
                timer.state = .completed;
                stats.active_tasks -|= 1;
                stats.completed_this_frame += 1;
            }
        }
    }

    // Cleanup completed/cancelled timers
    for (&wasm_timers) |*timer| {
        if (timer.state == .completed or timer.state == .cancelled) {
            timer.* = WasmTimer{};
        }
    }
}

/// Get number of pending events
pub fn getEventCount() u32 {
    if (event_write_idx >= event_read_idx) {
        return @intCast(event_write_idx - event_read_idx);
    } else {
        return @intCast(MAX_EVENTS - event_read_idx + event_write_idx);
    }
}

/// Pop next event from queue (returns null if empty)
pub fn popEvent() ?TimerEvent {
    if (event_read_idx == event_write_idx) return null;

    const event = event_queue[event_read_idx];
    event_read_idx = (event_read_idx + 1) % MAX_EVENTS;
    return event;
}

/// Get event buffer pointer (for direct access from JS)
pub fn getEventBuffer() *const [MAX_EVENTS]TimerEvent {
    return &event_queue;
}

/// Get event buffer size
pub fn getEventBufferSize() usize {
    return @sizeOf([MAX_EVENTS]TimerEvent);
}

/// Get single event size
pub fn getEventSize() usize {
    return @sizeOf(TimerEvent);
}

// === Tests ===

var test_counter: u32 = 0;

fn testCallback(_: TaskId, _: ?*anyopaque) bool {
    test_counter += 1;
    return false;
}

fn testRepeatingCallback(_: TaskId, _: ?*anyopaque) bool {
    test_counter += 1;
    return true; // Keep alive
}

test "scheduler initialization" {
    init();
    try std.testing.expect(initialized);
    try std.testing.expectEqual(@as(u32, 0), stats.active_tasks);
    deinit();
}

test "schedule once task" {
    init();
    test_counter = 0;

    const id = scheduleAfter(0.5, testCallback, null);
    try std.testing.expect(id != INVALID_TASK_ID);
    try std.testing.expect(isActive(id));

    // Not yet fired
    update(0.4);
    try std.testing.expectEqual(@as(u32, 0), test_counter);

    // Should fire now
    update(0.2);
    try std.testing.expectEqual(@as(u32, 1), test_counter);
    try std.testing.expect(!isActive(id));

    deinit();
}

test "schedule repeating task" {
    init();
    test_counter = 0;

    const id = scheduleRepeating(0.1, testRepeatingCallback, null);
    try std.testing.expect(id != INVALID_TASK_ID);

    // Fire 3 times
    update(0.1);
    update(0.1);
    update(0.1);
    try std.testing.expectEqual(@as(u32, 3), test_counter);

    // Cancel
    _ = cancel(id);
    update(0.1);
    try std.testing.expectEqual(@as(u32, 3), test_counter);

    deinit();
}

test "time scale" {
    init();
    test_counter = 0;

    _ = scheduleAfter(1.0, testCallback, null);
    setTimeScale(2.0); // Double speed

    update(0.5); // Effective: 1.0 second
    try std.testing.expectEqual(@as(u32, 1), test_counter);

    deinit();
}
