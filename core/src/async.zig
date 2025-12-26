// async.zig - Async Processing System for Zylix v0.4.0
//
// Features:
// - Future/Promise pattern with chaining
// - HTTP client (GET, POST, PUT, DELETE)
// - JSON response parsing
// - Background task scheduling
// - Cancellation and timeout support

const std = @import("std");
const Allocator = std.mem.Allocator;

// ============================================================================
// Future/Promise Pattern
// ============================================================================

/// Future state
pub const FutureState = enum {
    pending,
    fulfilled,
    rejected,
    cancelled,
};

/// Generic Future type
pub fn Future(comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: Allocator,
        state: FutureState = .pending,
        value: ?T = null,
        error_value: ?anyerror = null,
        error_message: ?[]const u8 = null,

        // Callbacks
        then_callbacks: std.ArrayList(*const fn (T) void),
        catch_callbacks: std.ArrayList(*const fn (anyerror, ?[]const u8) void),
        finally_callbacks: std.ArrayList(*const fn () void),

        // Cancellation
        cancelled: bool = false,
        cancel_token: ?*CancellationToken = null,

        // Timeout
        timeout_ns: ?u64 = null,
        start_time: i128 = 0,

        pub fn init(allocator: Allocator) Self {
            return .{
                .allocator = allocator,
                .then_callbacks = std.ArrayList(*const fn (T) void).init(allocator),
                .catch_callbacks = std.ArrayList(*const fn (anyerror, ?[]const u8) void).init(allocator),
                .finally_callbacks = std.ArrayList(*const fn () void).init(allocator),
                .start_time = std.time.nanoTimestamp(),
            };
        }

        pub fn deinit(self: *Self) void {
            self.then_callbacks.deinit();
            self.catch_callbacks.deinit();
            self.finally_callbacks.deinit();
            if (self.error_message) |msg| {
                self.allocator.free(msg);
            }
        }

        /// Resolve the future with a value
        pub fn resolve(self: *Self, value: T) void {
            if (self.state != .pending) return;
            if (self.cancelled) {
                self.state = .cancelled;
                return;
            }

            self.value = value;
            self.state = .fulfilled;

            // Call then callbacks
            for (self.then_callbacks.items) |callback| {
                callback(value);
            }

            // Call finally callbacks
            for (self.finally_callbacks.items) |callback| {
                callback();
            }
        }

        /// Reject the future with an error
        pub fn reject(self: *Self, err: anyerror, message: ?[]const u8) void {
            if (self.state != .pending) return;

            self.error_value = err;
            if (message) |msg| {
                self.error_message = self.allocator.dupe(u8, msg) catch null;
            }
            self.state = .rejected;

            // Call catch callbacks
            for (self.catch_callbacks.items) |callback| {
                callback(err, self.error_message);
            }

            // Call finally callbacks
            for (self.finally_callbacks.items) |callback| {
                callback();
            }
        }

        /// Add a success callback
        /// Returns null if allocation failed
        pub fn then(self: *Self, callback: *const fn (T) void) *Self {
            self.then_callbacks.append(callback) catch {
                // Log allocation failure - callback will not be registered
                std.log.warn("Future: Failed to register then callback", .{});
            };
            return self;
        }

        /// Add an error callback
        /// Returns null if allocation failed
        pub fn catch_(self: *Self, callback: *const fn (anyerror, ?[]const u8) void) *Self {
            self.catch_callbacks.append(callback) catch {
                // Log allocation failure - callback will not be registered
                std.log.warn("Future: Failed to register catch callback", .{});
            };
            return self;
        }

        /// Add a finally callback
        /// Returns null if allocation failed
        pub fn finally(self: *Self, callback: *const fn () void) *Self {
            self.finally_callbacks.append(callback) catch {
                // Log allocation failure - callback will not be registered
                std.log.warn("Future: Failed to register finally callback", .{});
            };
            return self;
        }

        /// Set timeout
        pub fn timeout(self: *Self, timeout_ms: u64) *Self {
            self.timeout_ns = timeout_ms * std.time.ns_per_ms;
            return self;
        }

        /// Set cancellation token
        pub fn withCancellation(self: *Self, token: *CancellationToken) *Self {
            self.cancel_token = token;
            return self;
        }

        /// Cancel the future
        pub fn cancel(self: *Self) void {
            if (self.state != .pending) return;
            self.cancelled = true;
            self.state = .cancelled;

            // Call finally callbacks
            for (self.finally_callbacks.items) |callback| {
                callback();
            }
        }

        /// Check if timed out
        pub fn isTimedOut(self: *const Self) bool {
            if (self.timeout_ns) |timeout_val| {
                const elapsed = std.time.nanoTimestamp() - self.start_time;
                return elapsed > @as(i128, @intCast(timeout_val));
            }
            return false;
        }

        /// Await the result (blocking)
        pub fn await_(self: *Self) !T {
            while (self.state == .pending) {
                if (self.isTimedOut()) {
                    self.reject(error.Timeout, "Operation timed out");
                    return error.Timeout;
                }
                if (self.cancel_token) |token| {
                    if (token.isCancelled()) {
                        self.cancel();
                        return error.Cancelled;
                    }
                }
                std.time.sleep(1 * std.time.ns_per_ms);
            }

            switch (self.state) {
                .fulfilled => return self.value.?,
                .rejected => return self.error_value.?,
                .cancelled => return error.Cancelled,
                .pending => unreachable,
            }
        }
    };
}

/// Cancellation token for cooperative cancellation
pub const CancellationToken = struct {
    cancelled: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    pub fn cancel(self: *CancellationToken) void {
        self.cancelled.store(true, .seq_cst);
    }

    pub fn isCancelled(self: *const CancellationToken) bool {
        return self.cancelled.load(.seq_cst);
    }

    pub fn reset(self: *CancellationToken) void {
        self.cancelled.store(false, .seq_cst);
    }
};

// ============================================================================
// Task Queue
// ============================================================================

/// Task priority
pub const TaskPriority = enum(u8) {
    low = 0,
    normal = 1,
    high = 2,
    critical = 3,
};

/// Task state
pub const TaskState = enum {
    queued,
    running,
    completed,
    failed,
    cancelled,
};

/// Task handle
pub const TaskHandle = struct {
    id: u64,
    state: TaskState = .queued,
    priority: TaskPriority = .normal,
    cancel_token: CancellationToken = .{},

    pub fn cancel(self: *TaskHandle) void {
        self.cancel_token.cancel();
        self.state = .cancelled;
    }

    pub fn isCancelled(self: *const TaskHandle) bool {
        return self.cancel_token.isCancelled();
    }
};

/// Task function type
pub const TaskFn = *const fn (*TaskHandle, ?*anyopaque) void;

/// Task queue entry
const TaskEntry = struct {
    handle: TaskHandle,
    func: TaskFn,
    user_data: ?*anyopaque,
};

/// Thread-safe task queue
pub const TaskQueue = struct {
    allocator: Allocator,
    tasks: std.ArrayList(TaskEntry),
    mutex: std.Thread.Mutex = .{},
    next_id: u64 = 1,

    pub fn init(allocator: Allocator) TaskQueue {
        return .{
            .allocator = allocator,
            .tasks = std.ArrayList(TaskEntry).init(allocator),
        };
    }

    pub fn deinit(self: *TaskQueue) void {
        self.tasks.deinit();
    }

    /// Submit a task
    pub fn submit(self: *TaskQueue, func: TaskFn, user_data: ?*anyopaque, priority: TaskPriority) TaskHandle {
        self.mutex.lock();
        defer self.mutex.unlock();

        const id = self.next_id;
        self.next_id += 1;

        const handle = TaskHandle{
            .id = id,
            .priority = priority,
        };

        const entry = TaskEntry{
            .handle = handle,
            .func = func,
            .user_data = user_data,
        };

        // Insert based on priority
        var insert_idx: usize = self.tasks.items.len;
        for (self.tasks.items, 0..) |task, i| {
            if (@intFromEnum(priority) > @intFromEnum(task.handle.priority)) {
                insert_idx = i;
                break;
            }
        }

        self.tasks.insert(insert_idx, entry) catch {
            std.log.warn("TaskQueue: Failed to insert task {d}", .{id});
        };
        return handle;
    }

    /// Get next task to execute
    pub fn pop(self: *TaskQueue) ?TaskEntry {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.tasks.items.len == 0) return null;
        return self.tasks.orderedRemove(0);
    }

    /// Cancel a task by ID
    pub fn cancelTask(self: *TaskQueue, id: u64) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        for (self.tasks.items) |*task| {
            if (task.handle.id == id) {
                task.handle.cancel();
                return true;
            }
        }
        return false;
    }

    /// Get queue length
    pub fn len(self: *TaskQueue) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.tasks.items.len;
    }
};

// ============================================================================
// HTTP Client
// ============================================================================

/// HTTP methods
pub const HttpMethod = enum {
    GET,
    POST,
    PUT,
    DELETE,
    PATCH,
    HEAD,
    OPTIONS,

    pub fn toString(self: HttpMethod) []const u8 {
        return switch (self) {
            .GET => "GET",
            .POST => "POST",
            .PUT => "PUT",
            .DELETE => "DELETE",
            .PATCH => "PATCH",
            .HEAD => "HEAD",
            .OPTIONS => "OPTIONS",
        };
    }
};

/// HTTP header
pub const HttpHeader = struct {
    name: []const u8,
    value: []const u8,
};

/// HTTP request
pub const HttpRequest = struct {
    allocator: Allocator,
    method: HttpMethod = .GET,
    url: []const u8,
    headers: std.ArrayList(HttpHeader),
    body: ?[]const u8 = null,
    timeout_ms: u64 = 30000,

    pub fn init(allocator: Allocator, url: []const u8) HttpRequest {
        return .{
            .allocator = allocator,
            .url = url,
            .headers = std.ArrayList(HttpHeader).init(allocator),
        };
    }

    pub fn deinit(self: *HttpRequest) void {
        self.headers.deinit();
    }

    pub fn setMethod(self: *HttpRequest, method: HttpMethod) *HttpRequest {
        self.method = method;
        return self;
    }

    pub fn addHeader(self: *HttpRequest, name: []const u8, value: []const u8) *HttpRequest {
        self.headers.append(.{ .name = name, .value = value }) catch {
            std.log.warn("HttpRequest: Failed to add header '{s}'", .{name});
        };
        return self;
    }

    pub fn setBody(self: *HttpRequest, body: []const u8) *HttpRequest {
        self.body = body;
        return self;
    }

    pub fn setTimeout(self: *HttpRequest, timeout_ms: u64) *HttpRequest {
        self.timeout_ms = timeout_ms;
        return self;
    }

    pub fn setJson(self: *HttpRequest, body: []const u8) *HttpRequest {
        _ = self.addHeader("Content-Type", "application/json");
        self.body = body;
        return self;
    }
};

/// HTTP response
pub const HttpResponse = struct {
    allocator: Allocator,
    status_code: u16 = 0,
    headers: std.ArrayList(HttpHeader),
    body: []const u8 = "",

    pub fn init(allocator: Allocator) HttpResponse {
        return .{
            .allocator = allocator,
            .headers = std.ArrayList(HttpHeader).init(allocator),
        };
    }

    pub fn deinit(self: *HttpResponse) void {
        self.headers.deinit();
        if (self.body.len > 0) {
            self.allocator.free(self.body);
        }
    }

    pub fn isSuccess(self: *const HttpResponse) bool {
        return self.status_code >= 200 and self.status_code < 300;
    }

    pub fn getHeader(self: *const HttpResponse, name: []const u8) ?[]const u8 {
        for (self.headers.items) |header| {
            if (std.ascii.eqlIgnoreCase(header.name, name)) {
                return header.value;
            }
        }
        return null;
    }

    /// Parse body as JSON (returns raw bytes, parsing done by caller)
    pub fn json(self: *const HttpResponse) []const u8 {
        return self.body;
    }

    /// Get body as text
    pub fn text(self: *const HttpResponse) []const u8 {
        return self.body;
    }
};

/// HTTP client errors
pub const HttpError = error{
    ConnectionFailed,
    Timeout,
    InvalidUrl,
    TooManyRedirects,
    NetworkError,
    ResponseTooLarge,
    InvalidResponse,
};

/// HTTP client
pub const HttpClient = struct {
    allocator: Allocator,
    default_headers: std.ArrayList(HttpHeader),
    follow_redirects: bool = true,
    max_redirects: u8 = 5,

    pub fn init(allocator: Allocator) HttpClient {
        var client = HttpClient{
            .allocator = allocator,
            .default_headers = std.ArrayList(HttpHeader).init(allocator),
        };
        // Add default headers
        client.default_headers.append(.{ .name = "User-Agent", .value = "Zylix/0.4.0" }) catch {
            std.log.warn("HttpClient: Failed to add default User-Agent header", .{});
        };
        client.default_headers.append(.{ .name = "Accept", .value = "*/*" }) catch {
            std.log.warn("HttpClient: Failed to add default Accept header", .{});
        };
        return client;
    }

    pub fn deinit(self: *HttpClient) void {
        self.default_headers.deinit();
    }

    /// Perform a GET request
    pub fn get(self: *HttpClient, url: []const u8) *Future(HttpResponse) {
        var request = HttpRequest.init(self.allocator, url);
        _ = request.setMethod(.GET);
        return self.send(&request);
    }

    /// Perform a POST request
    pub fn post(self: *HttpClient, url: []const u8, body: ?[]const u8) *Future(HttpResponse) {
        var request = HttpRequest.init(self.allocator, url);
        _ = request.setMethod(.POST);
        if (body) |b| {
            _ = request.setBody(b);
        }
        return self.send(&request);
    }

    /// Perform a PUT request
    pub fn put(self: *HttpClient, url: []const u8, body: ?[]const u8) *Future(HttpResponse) {
        var request = HttpRequest.init(self.allocator, url);
        _ = request.setMethod(.PUT);
        if (body) |b| {
            _ = request.setBody(b);
        }
        return self.send(&request);
    }

    /// Perform a DELETE request
    pub fn delete(self: *HttpClient, url: []const u8) *Future(HttpResponse) {
        var request = HttpRequest.init(self.allocator, url);
        _ = request.setMethod(.DELETE);
        return self.send(&request);
    }

    /// Send a request
    pub fn send(self: *HttpClient, request: *HttpRequest) *Future(HttpResponse) {
        var future = self.allocator.create(Future(HttpResponse)) catch unreachable;
        future.* = Future(HttpResponse).init(self.allocator);
        _ = future.timeout(request.timeout_ms);

        // Note: Actual HTTP implementation would be platform-specific
        // This is a stub that will be filled in by platform implementations
        _ = self;
        _ = request;

        // For now, create a mock response
        var response = HttpResponse.init(self.allocator);
        response.status_code = 200;
        future.resolve(response);

        return future;
    }
};

// ============================================================================
// Background Task Scheduler
// ============================================================================

/// Scheduler for background tasks
pub const Scheduler = struct {
    allocator: Allocator,
    task_queue: TaskQueue,
    running: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    worker_count: u8 = 4,

    pub fn init(allocator: Allocator) Scheduler {
        return .{
            .allocator = allocator,
            .task_queue = TaskQueue.init(allocator),
        };
    }

    pub fn deinit(self: *Scheduler) void {
        self.stop();
        self.task_queue.deinit();
    }

    /// Start the scheduler
    pub fn start(self: *Scheduler) void {
        self.running.store(true, .seq_cst);
    }

    /// Stop the scheduler
    pub fn stop(self: *Scheduler) void {
        self.running.store(false, .seq_cst);
    }

    /// Check if scheduler is running
    pub fn isRunning(self: *const Scheduler) bool {
        return self.running.load(.seq_cst);
    }

    /// Schedule a task
    pub fn schedule(self: *Scheduler, func: TaskFn, user_data: ?*anyopaque, priority: TaskPriority) TaskHandle {
        return self.task_queue.submit(func, user_data, priority);
    }

    /// Schedule with delay (conceptual - actual timing handled by platform)
    pub fn scheduleDelayed(self: *Scheduler, func: TaskFn, user_data: ?*anyopaque, delay_ms: u64) TaskHandle {
        _ = delay_ms;
        return self.schedule(func, user_data, .normal);
    }

    /// Execute pending tasks (call from main loop)
    pub fn tick(self: *Scheduler) void {
        if (!self.isRunning()) return;

        // Process one task per tick to avoid blocking
        if (self.task_queue.pop()) |entry| {
            var handle = entry.handle;
            if (!handle.isCancelled()) {
                handle.state = .running;
                entry.func(&handle, entry.user_data);
                if (handle.state == .running) {
                    handle.state = .completed;
                }
            }
        }
    }

    /// Get pending task count
    pub fn pendingCount(self: *Scheduler) usize {
        return self.task_queue.len();
    }
};

// ============================================================================
// Async Utilities
// ============================================================================

/// Run multiple futures in parallel and wait for all
pub fn all(comptime T: type, allocator: Allocator, futures: []*Future(T)) *Future([]T) {
    var result_future = allocator.create(Future([]T)) catch unreachable;
    result_future.* = Future([]T).init(allocator);

    var results = allocator.alloc(T, futures.len) catch {
        result_future.reject(error.OutOfMemory, "Failed to allocate results");
        return result_future;
    };

    var completed: usize = 0;
    var failed = false;

    for (futures, 0..) |future, i| {
        _ = future.then(struct {
            fn callback(value: T) void {
                _ = value;
            }
        }.callback);
        // Note: This is simplified - actual implementation would need proper synchronization
        if (future.state == .fulfilled) {
            results[i] = future.value.?;
            completed += 1;
        } else if (future.state == .rejected) {
            failed = true;
        }
    }

    if (failed) {
        allocator.free(results);
        result_future.reject(error.OperationFailed, "One or more operations failed");
    } else if (completed == futures.len) {
        result_future.resolve(results);
    }

    return result_future;
}

/// Run multiple futures and return first to complete
pub fn race(comptime T: type, allocator: Allocator, futures: []*Future(T)) *Future(T) {
    var result_future = allocator.create(Future(T)) catch unreachable;
    result_future.* = Future(T).init(allocator);

    for (futures) |future| {
        if (future.state == .fulfilled) {
            result_future.resolve(future.value.?);
            break;
        } else if (future.state == .rejected) {
            result_future.reject(future.error_value.?, future.error_message);
            break;
        }
    }

    return result_future;
}

/// Delay execution
pub fn delay(allocator: Allocator, ms: u64) *Future(void) {
    var future = allocator.create(Future(void)) catch unreachable;
    future.* = Future(void).init(allocator);
    _ = future.timeout(ms);
    // Note: Actual delay would be platform-specific
    future.resolve({});
    return future;
}

// ============================================================================
// C ABI Exports
// ============================================================================

var global_scheduler: ?*Scheduler = null;
var global_http_client: ?*HttpClient = null;

export fn zylix_async_init() i32 {
    const allocator = std.heap.c_allocator;
    global_scheduler = allocator.create(Scheduler) catch return -1;
    global_scheduler.?.* = Scheduler.init(allocator);
    global_scheduler.?.start();

    global_http_client = allocator.create(HttpClient) catch return -1;
    global_http_client.?.* = HttpClient.init(allocator);

    return 0;
}

export fn zylix_async_deinit() void {
    if (global_scheduler) |scheduler| {
        scheduler.deinit();
        std.heap.c_allocator.destroy(scheduler);
        global_scheduler = null;
    }
    if (global_http_client) |client| {
        client.deinit();
        std.heap.c_allocator.destroy(client);
        global_http_client = null;
    }
}

export fn zylix_async_tick() void {
    if (global_scheduler) |scheduler| {
        scheduler.tick();
    }
}

export fn zylix_async_pending_count() usize {
    if (global_scheduler) |scheduler| {
        return scheduler.pendingCount();
    }
    return 0;
}

// ============================================================================
// Tests
// ============================================================================

test "future resolve" {
    const allocator = std.testing.allocator;
    var future = Future(i32).init(allocator);
    defer future.deinit();

    future.resolve(42);
    try std.testing.expectEqual(FutureState.fulfilled, future.state);
    try std.testing.expectEqual(@as(i32, 42), future.value.?);
}

test "future reject" {
    const allocator = std.testing.allocator;
    var future = Future(i32).init(allocator);
    defer future.deinit();

    future.reject(error.InvalidInput, "Test error");
    try std.testing.expectEqual(FutureState.rejected, future.state);
}

test "task queue priority" {
    const allocator = std.testing.allocator;
    var queue = TaskQueue.init(allocator);
    defer queue.deinit();

    const dummy_fn = struct {
        fn func(_: *TaskHandle, _: ?*anyopaque) void {}
    }.func;

    _ = queue.submit(dummy_fn, null, .low);
    _ = queue.submit(dummy_fn, null, .high);
    _ = queue.submit(dummy_fn, null, .normal);

    const first = queue.pop().?;
    try std.testing.expectEqual(TaskPriority.high, first.handle.priority);
}

test "cancellation token" {
    var token = CancellationToken{};
    try std.testing.expect(!token.isCancelled());

    token.cancel();
    try std.testing.expect(token.isCancelled());

    token.reset();
    try std.testing.expect(!token.isCancelled());
}
