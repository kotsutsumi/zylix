// Zylix Test Framework - Parallel Test Execution
// Multi-threaded test runner with work stealing

const std = @import("std");
const Allocator = std.mem.Allocator;
const Thread = std.Thread;

/// Parallel execution configuration
pub const ParallelConfig = struct {
    /// Number of worker threads (0 = auto-detect CPU count)
    worker_count: u32 = 0,
    /// Maximum tests per batch
    batch_size: u32 = 10,
    /// Timeout per test in milliseconds
    test_timeout_ms: u64 = 60000,
    /// Enable work stealing between threads
    work_stealing: bool = true,
    /// Isolate tests (separate process per test)
    isolate: bool = false,
    /// Shuffle test order for detecting dependencies
    shuffle: bool = false,
    /// Random seed for shuffling (0 = random)
    seed: u64 = 0,
};

/// Test task for parallel execution
pub const TestTask = struct {
    id: u64,
    name: []const u8,
    suite: []const u8,
    func: *const fn (*TestContext) anyerror!void,
    priority: i32 = 0,
    timeout_ms: u64 = 60000,
    retries: u32 = 0,
    tags: []const []const u8 = &.{},

    pub fn compare(_: void, a: TestTask, b: TestTask) std.math.Order {
        // Higher priority first
        if (a.priority > b.priority) return .lt;
        if (a.priority < b.priority) return .gt;
        return .eq;
    }
};

/// Test execution result
pub const TaskResult = struct {
    task_id: u64,
    status: Status,
    duration_ns: u64,
    message: ?[]const u8,
    stdout: ?[]const u8,
    stderr: ?[]const u8,
    retry_count: u32,
    worker_id: u32,

    pub const Status = enum {
        passed,
        failed,
        skipped,
        timeout,
        error_,
    };
};

/// Test context passed to test functions
pub const TestContext = struct {
    allocator: Allocator,
    task: *const TestTask,
    worker_id: u32,
    start_time: i128,

    /// Log a message from the test
    pub fn log(self: *TestContext, comptime fmt: []const u8, args: anytype) void {
        _ = self;
        std.debug.print(fmt ++ "\n", args);
    }

    /// Skip the current test
    pub fn skip(self: *TestContext, reason: []const u8) error{TestSkipped} {
        _ = self;
        _ = reason;
        return error.TestSkipped;
    }

    /// Get elapsed time in milliseconds
    pub fn elapsedMs(self: *TestContext) u64 {
        const now = std.time.nanoTimestamp();
        return @intCast(@divFloor(now - self.start_time, std.time.ns_per_ms));
    }
};

/// Work queue for parallel execution
pub const WorkQueue = struct {
    tasks: std.PriorityQueue(TestTask, void, TestTask.compare),
    mutex: Thread.Mutex,
    completed: std.ArrayList(TaskResult),
    active_count: std.atomic.Value(u32),
    total_tasks: u32,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .tasks = std.PriorityQueue(TestTask, void, TestTask.compare).init(allocator, {}),
            .mutex = .{},
            .completed = std.ArrayList(TaskResult).init(allocator),
            .active_count = std.atomic.Value(u32).init(0),
            .total_tasks = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.tasks.deinit();
        self.completed.deinit();
    }

    pub fn addTask(self: *Self, task: TestTask) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.tasks.add(task);
        self.total_tasks += 1;
    }

    pub fn getTask(self: *Self) ?TestTask {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.tasks.removeOrNull();
    }

    pub fn addResult(self: *Self, result: TaskResult) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.completed.append(result);
    }

    pub fn progress(self: *Self) struct { completed: usize, total: u32, active: u32 } {
        self.mutex.lock();
        defer self.mutex.unlock();
        return .{
            .completed = self.completed.items.len,
            .total = self.total_tasks,
            .active = self.active_count.load(.acquire),
        };
    }
};

/// Parallel test executor
pub const ParallelExecutor = struct {
    allocator: Allocator,
    config: ParallelConfig,
    queue: WorkQueue,
    workers: []Thread,
    running: std.atomic.Value(bool),

    const Self = @This();

    pub fn init(allocator: Allocator, config: ParallelConfig) Self {
        return .{
            .allocator = allocator,
            .config = config,
            .queue = WorkQueue.init(allocator),
            .workers = &.{},
            .running = std.atomic.Value(bool).init(false),
        };
    }

    pub fn deinit(self: *Self) void {
        self.queue.deinit();
        if (self.workers.len > 0) {
            self.allocator.free(self.workers);
        }
    }

    /// Add a test to the execution queue
    pub fn addTest(self: *Self, task: TestTask) !void {
        try self.queue.addTask(task);
    }

    /// Execute all queued tests in parallel
    pub fn execute(self: *Self) ![]TaskResult {
        const worker_count = if (self.config.worker_count == 0)
            @max(1, std.Thread.getCpuCount() catch 4)
        else
            self.config.worker_count;

        self.running.store(true, .release);

        // Start worker threads
        self.workers = try self.allocator.alloc(Thread, worker_count);
        for (self.workers, 0..) |*worker, i| {
            worker.* = try Thread.spawn(.{}, workerLoop, .{ self, @as(u32, @intCast(i)) });
        }

        // Wait for all workers to complete
        for (self.workers) |worker| {
            worker.join();
        }

        self.running.store(false, .release);

        return self.queue.completed.items;
    }

    /// Stop all workers
    pub fn stop(self: *Self) void {
        self.running.store(false, .release);
    }

    fn workerLoop(self: *Self, worker_id: u32) void {
        while (self.running.load(.acquire)) {
            if (self.queue.getTask()) |task| {
                _ = self.queue.active_count.fetchAdd(1, .acq_rel);
                defer _ = self.queue.active_count.fetchSub(1, .acq_rel);

                const result = self.executeTask(task, worker_id);
                self.queue.addResult(result) catch {};
            } else {
                // No tasks available, check if we should exit
                const prog = self.queue.progress();
                if (prog.completed >= prog.total and prog.active == 0) {
                    break;
                }
                std.time.sleep(1 * std.time.ns_per_ms);
            }
        }
    }

    fn executeTask(self: *Self, task: TestTask, worker_id: u32) TaskResult {
        const start = std.time.nanoTimestamp();

        var ctx = TestContext{
            .allocator = self.allocator,
            .task = &task,
            .worker_id = worker_id,
            .start_time = start,
        };

        var retry_count: u32 = 0;
        var status: TaskResult.Status = .passed;
        var message: ?[]const u8 = null;

        while (retry_count <= task.retries) {
            // Check timeout
            if (ctx.elapsedMs() > task.timeout_ms) {
                status = .timeout;
                message = "Test exceeded timeout";
                break;
            }

            // Execute test
            if (task.func(&ctx)) |_| {
                status = .passed;
                message = null;
                break;
            } else |err| {
                switch (err) {
                    error.TestSkipped => {
                        status = .skipped;
                        message = "Test skipped";
                        break;
                    },
                    else => {
                        status = .failed;
                        message = @errorName(err);
                        retry_count += 1;
                    },
                }
            }
        }

        const end = std.time.nanoTimestamp();

        return TaskResult{
            .task_id = task.id,
            .status = status,
            .duration_ns = @intCast(end - start),
            .message = message,
            .stdout = null,
            .stderr = null,
            .retry_count = retry_count,
            .worker_id = worker_id,
        };
    }
};

/// Test sharding for distributed execution
pub const TestShard = struct {
    shard_index: u32,
    total_shards: u32,

    const Self = @This();

    pub fn init(shard_index: u32, total_shards: u32) Self {
        return .{
            .shard_index = shard_index,
            .total_shards = total_shards,
        };
    }

    /// Check if a test should run in this shard
    pub fn shouldRun(self: Self, test_index: u64) bool {
        return (test_index % self.total_shards) == self.shard_index;
    }

    /// Filter tests for this shard
    pub fn filterTests(self: Self, tests: []const TestTask, allocator: Allocator) ![]TestTask {
        var filtered = std.ArrayList(TestTask).init(allocator);

        for (tests, 0..) |test_task, i| {
            if (self.shouldRun(i)) {
                try filtered.append(test_task);
            }
        }

        return filtered.toOwnedSlice();
    }
};

/// Flaky test detector
pub const FlakyDetector = struct {
    allocator: Allocator,
    history: std.StringHashMap(TestHistory),
    threshold: f32,

    const TestHistory = struct {
        runs: u32,
        passes: u32,
        failures: u32,
        last_status: TaskResult.Status,
    };

    const Self = @This();

    pub fn init(allocator: Allocator, threshold: f32) Self {
        return .{
            .allocator = allocator,
            .history = std.StringHashMap(TestHistory).init(allocator),
            .threshold = threshold,
        };
    }

    pub fn deinit(self: *Self) void {
        self.history.deinit();
    }

    /// Record a test result
    pub fn recordResult(self: *Self, name: []const u8, status: TaskResult.Status) !void {
        const entry = try self.history.getOrPut(name);
        if (!entry.found_existing) {
            entry.value_ptr.* = .{
                .runs = 0,
                .passes = 0,
                .failures = 0,
                .last_status = status,
            };
        }

        entry.value_ptr.runs += 1;
        entry.value_ptr.last_status = status;

        switch (status) {
            .passed => entry.value_ptr.passes += 1,
            .failed, .timeout, .error_ => entry.value_ptr.failures += 1,
            .skipped => {},
        }
    }

    /// Check if a test is flaky
    pub fn isFlaky(self: *Self, name: []const u8) bool {
        const history = self.history.get(name) orelse return false;

        if (history.runs < 3) return false;

        const pass_rate = @as(f32, @floatFromInt(history.passes)) /
            @as(f32, @floatFromInt(history.runs));

        // Flaky if not consistently passing or failing
        return pass_rate > 0.1 and pass_rate < 0.9;
    }

    /// Get flaky tests
    pub fn getFlakyTests(self: *Self, allocator: Allocator) ![][]const u8 {
        var flaky = std.ArrayList([]const u8).init(allocator);

        var iter = self.history.iterator();
        while (iter.next()) |entry| {
            if (self.isFlaky(entry.key_ptr.*)) {
                try flaky.append(entry.key_ptr.*);
            }
        }

        return flaky.toOwnedSlice();
    }
};

// Tests
test "ParallelConfig defaults" {
    const config = ParallelConfig{};
    try std.testing.expectEqual(@as(u32, 0), config.worker_count);
    try std.testing.expectEqual(@as(u32, 10), config.batch_size);
    try std.testing.expect(config.work_stealing);
}

test "TestShard filtering" {
    const allocator = std.testing.allocator;

    const shard0 = TestShard.init(0, 3);
    const shard1 = TestShard.init(1, 3);
    const shard2 = TestShard.init(2, 3);

    // Test index 0 should run on shard 0
    try std.testing.expect(shard0.shouldRun(0));
    try std.testing.expect(!shard1.shouldRun(0));
    try std.testing.expect(!shard2.shouldRun(0));

    // Test index 1 should run on shard 1
    try std.testing.expect(!shard0.shouldRun(1));
    try std.testing.expect(shard1.shouldRun(1));
    try std.testing.expect(!shard2.shouldRun(1));

    // Test index 2 should run on shard 2
    try std.testing.expect(!shard0.shouldRun(2));
    try std.testing.expect(!shard1.shouldRun(2));
    try std.testing.expect(shard2.shouldRun(2));

    _ = allocator;
}

test "WorkQueue operations" {
    const allocator = std.testing.allocator;

    var queue = WorkQueue.init(allocator);
    defer queue.deinit();

    const dummyFunc = struct {
        fn f(_: *TestContext) anyerror!void {}
    }.f;

    try queue.addTask(.{
        .id = 1,
        .name = "test1",
        .suite = "suite1",
        .func = dummyFunc,
    });

    try queue.addTask(.{
        .id = 2,
        .name = "test2",
        .suite = "suite1",
        .func = dummyFunc,
        .priority = 10,
    });

    // Higher priority should come first
    const task1 = queue.getTask();
    try std.testing.expect(task1 != null);
    try std.testing.expectEqual(@as(u64, 2), task1.?.id);

    const task2 = queue.getTask();
    try std.testing.expect(task2 != null);
    try std.testing.expectEqual(@as(u64, 1), task2.?.id);

    const task3 = queue.getTask();
    try std.testing.expect(task3 == null);
}

test "FlakyDetector" {
    const allocator = std.testing.allocator;

    var detector = FlakyDetector.init(allocator, 0.8);
    defer detector.deinit();

    // Record consistent passes - not flaky
    try detector.recordResult("stable_test", .passed);
    try detector.recordResult("stable_test", .passed);
    try detector.recordResult("stable_test", .passed);
    try std.testing.expect(!detector.isFlaky("stable_test"));

    // Record mixed results - flaky
    try detector.recordResult("flaky_test", .passed);
    try detector.recordResult("flaky_test", .failed);
    try detector.recordResult("flaky_test", .passed);
    try detector.recordResult("flaky_test", .failed);
    try std.testing.expect(detector.isFlaky("flaky_test"));
}
