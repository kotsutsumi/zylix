//! Debug Adapter Protocol (DAP) Integration
//!
//! Provides debugging capabilities through the Debug Adapter Protocol:
//! - Launch and attach debugging
//! - Breakpoints (line, function, conditional, exception)
//! - Step execution (into, over, out)
//! - Variable inspection
//! - Call stack navigation
//! - Watch expressions
//! - Output and logging
//!
//! This module enables IDE debugging support for Zylix applications.

const std = @import("std");
const project = @import("project.zig");

/// DAP error types
pub const DapError = error{
    NotInitialized,
    InvalidProject,
    InvalidSession,
    LaunchFailed,
    AttachFailed,
    BreakpointFailed,
    StepFailed,
    ConnectionLost,
    OutOfMemory,
};

/// Debug adapter identifier
pub const AdapterId = struct {
    id: u64,
    port: u16,
    started_at: i64,

    pub fn isValid(self: *const AdapterId) bool {
        return self.id > 0;
    }
};

/// Debug adapter state
pub const AdapterState = enum(u8) {
    stopped = 0,
    starting = 1,
    initialized = 2,
    running = 3,
    paused = 4,
    terminated = 5,
    error_state = 6,

    pub fn isActive(self: AdapterState) bool {
        return switch (self) {
            .initialized, .running, .paused => true,
            else => false,
        };
    }

    pub fn toString(self: AdapterState) []const u8 {
        return switch (self) {
            .stopped => "Stopped",
            .starting => "Starting",
            .initialized => "Initialized",
            .running => "Running",
            .paused => "Paused",
            .terminated => "Terminated",
            .error_state => "Error",
        };
    }
};

/// Debug configuration
pub const DapConfig = struct {
    /// Server port (0 for auto-assign)
    port: u16 = 0,
    /// Stop at entry point
    stop_at_entry: bool = false,
    /// Enable source maps
    source_maps: bool = true,
    /// Program arguments
    args: []const []const u8 = &.{},
    /// Environment variables
    env: []const []const u8 = &.{},
    /// Working directory
    cwd: ?[]const u8 = null,
    /// Enable logging
    logging: bool = true,
    /// Enable exception breakpoints
    exception_breakpoints: bool = true,
};

/// Breakpoint type
pub const BreakpointType = enum(u8) {
    line = 0,
    function = 1,
    conditional = 2,
    exception = 3,
    data = 4,
    log = 5,
};

/// Breakpoint information
pub const Breakpoint = struct {
    id: u64,
    breakpoint_type: BreakpointType,
    verified: bool,
    source_path: ?[]const u8 = null,
    line: ?u32 = null,
    column: ?u32 = null,
    condition: ?[]const u8 = null,
    hit_condition: ?[]const u8 = null,
    log_message: ?[]const u8 = null,
    hit_count: u32 = 0,
};

/// Thread information
pub const Thread = struct {
    id: u64,
    name: []const u8,
};

/// Stack frame information
pub const StackFrame = struct {
    id: u64,
    name: []const u8,
    source_path: ?[]const u8 = null,
    line: u32,
    column: u32,
    end_line: ?u32 = null,
    end_column: ?u32 = null,
    module_id: ?u64 = null,
};

/// Variable scope
pub const Scope = struct {
    name: []const u8,
    variables_reference: u64,
    named_variables: ?u32 = null,
    indexed_variables: ?u32 = null,
    expensive: bool = false,
};

/// Variable information
pub const Variable = struct {
    name: []const u8,
    value: []const u8,
    variable_type: ?[]const u8 = null,
    variables_reference: u64 = 0,
    named_variables: ?u32 = null,
    indexed_variables: ?u32 = null,
    evaluate_name: ?[]const u8 = null,
};

/// Evaluation result
pub const EvaluateResult = struct {
    result: []const u8,
    result_type: ?[]const u8 = null,
    variables_reference: u64 = 0,
    named_variables: ?u32 = null,
    indexed_variables: ?u32 = null,
};

/// Stop reason
pub const StopReason = enum(u8) {
    step = 0,
    breakpoint = 1,
    exception = 2,
    pause = 3,
    entry = 4,
    goto_target = 5,
    function_breakpoint = 6,
    data_breakpoint = 7,
};

/// Debug session
pub const DapSession = struct {
    id: AdapterId,
    state: AdapterState,
    config: DapConfig,
    project_path: []const u8,
    breakpoint_count: u32 = 0,
    thread_count: u32 = 0,
    current_thread_id: ?u64 = null,
    current_frame_id: ?u64 = null,
    stop_reason: ?StopReason = null,
};

/// Debug capabilities
pub const DebugCapabilities = struct {
    supports_configuration_done: bool = true,
    supports_function_breakpoints: bool = true,
    supports_conditional_breakpoints: bool = true,
    supports_hit_conditional_breakpoints: bool = true,
    supports_evaluate_for_hovers: bool = true,
    supports_step_back: bool = false,
    supports_set_variable: bool = true,
    supports_restart_frame: bool = false,
    supports_goto_targets: bool = false,
    supports_stepping_granularity: bool = true,
    supports_instruction_breakpoints: bool = false,
    supports_exception_breakpoints: bool = true,
    supports_value_formatting: bool = true,
    supports_exception_info: bool = true,
    supports_terminate_debuggee: bool = true,
    supports_suspend_debuggee: bool = true,
    supports_log_points: bool = true,
};

/// DAP event
pub const DapEvent = union(enum) {
    adapter_started: AdapterId,
    adapter_stopped: AdapterId,
    launched: void,
    attached: void,
    terminated: void,
    breakpoint_hit: struct { breakpoint_id: u64, thread_id: u64 },
    stopped: struct { reason: StopReason, thread_id: u64 },
    continued: u64, // thread_id
    thread_started: Thread,
    thread_exited: u64, // thread_id
    output: struct { category: []const u8, output: []const u8 },
    error_occurred: []const u8,
};

/// Event callback type
pub const EventCallback = *const fn (DapEvent) void;

/// Future result wrapper
pub fn Future(comptime T: type) type {
    return struct {
        const Self = @This();

        result: ?T = null,
        err: ?DapError = null,
        completed: bool = false,

        pub fn init() Self {
            return .{};
        }

        pub fn complete(self: *Self, value: T) void {
            self.result = value;
            self.completed = true;
        }

        pub fn fail(self: *Self, err: DapError) void {
            self.err = err;
            self.completed = true;
        }

        pub fn isCompleted(self: *const Self) bool {
            return self.completed;
        }

        pub fn get(self: *const Self) DapError!T {
            if (self.err) |e| return e;
            if (self.result) |r| return r;
            return DapError.NotInitialized;
        }
    };
}

/// Adapter entry
const AdapterEntry = struct {
    session: DapSession,
    event_callback: ?EventCallback = null,
    capabilities: DebugCapabilities = .{},
    breakpoints: std.AutoHashMapUnmanaged(u64, Breakpoint) = .{},
    next_breakpoint_id: u64 = 1,
};

/// DAP Manager
pub const Dap = struct {
    allocator: std.mem.Allocator,
    adapters: std.AutoHashMapUnmanaged(u64, AdapterEntry) = .{},
    next_id: u64 = 1,
    next_port: u16 = 6000,

    pub fn init(allocator: std.mem.Allocator) Dap {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Dap) void {
        var iter = self.adapters.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.breakpoints.deinit(self.allocator);
        }
        self.adapters.deinit(self.allocator);
    }

    /// Start debug adapter
    pub fn start(
        self: *Dap,
        project_id: project.ProjectId,
        config: DapConfig,
    ) *Future(AdapterId) {
        const future = self.allocator.create(Future(AdapterId)) catch {
            const err_future = self.allocator.create(Future(AdapterId)) catch unreachable;
            err_future.* = Future(AdapterId).init();
            err_future.fail(DapError.OutOfMemory);
            return err_future;
        };
        future.* = Future(AdapterId).init();

        if (!project_id.isValid()) {
            future.fail(DapError.InvalidProject);
            return future;
        }

        const port = if (config.port == 0) blk: {
            const p = self.next_port;
            self.next_port += 1;
            break :blk p;
        } else config.port;

        const adapter_id = AdapterId{
            .id = self.next_id,
            .port = port,
            .started_at = std.time.timestamp(),
        };
        self.next_id += 1;

        const session = DapSession{
            .id = adapter_id,
            .state = .starting,
            .config = config,
            .project_path = project_id.path,
        };

        self.adapters.put(self.allocator, adapter_id.id, .{
            .session = session,
        }) catch {
            future.fail(DapError.OutOfMemory);
            return future;
        };

        // Transition to initialized state
        if (self.adapters.getPtr(adapter_id.id)) |entry| {
            entry.session.state = .initialized;
        }

        future.complete(adapter_id);
        return future;
    }

    /// Stop debug adapter
    pub fn stop(self: *Dap, adapter_id: AdapterId) void {
        if (self.adapters.getPtr(adapter_id.id)) |entry| {
            entry.session.state = .terminated;
            if (entry.event_callback) |cb| {
                cb(.{ .adapter_stopped = adapter_id });
            }
            entry.breakpoints.deinit(self.allocator);
        }
        _ = self.adapters.remove(adapter_id.id);
    }

    /// Launch debuggee
    pub fn launch(self: *Dap, adapter_id: AdapterId) *Future(void) {
        const future = self.allocator.create(Future(void)) catch {
            const err_future = self.allocator.create(Future(void)) catch unreachable;
            err_future.* = Future(void).init();
            err_future.fail(DapError.OutOfMemory);
            return err_future;
        };
        future.* = Future(void).init();

        if (self.adapters.getPtr(adapter_id.id)) |entry| {
            entry.session.state = .running;
            if (entry.event_callback) |cb| {
                cb(.{ .launched = {} });
            }
            future.complete({});
        } else {
            future.fail(DapError.InvalidSession);
        }

        return future;
    }

    /// Attach to running process
    pub fn attach(self: *Dap, adapter_id: AdapterId, process_id: u64) *Future(void) {
        const future = self.allocator.create(Future(void)) catch {
            const err_future = self.allocator.create(Future(void)) catch unreachable;
            err_future.* = Future(void).init();
            err_future.fail(DapError.OutOfMemory);
            return err_future;
        };
        future.* = Future(void).init();

        _ = process_id; // Would use in real implementation

        if (self.adapters.getPtr(adapter_id.id)) |entry| {
            entry.session.state = .running;
            if (entry.event_callback) |cb| {
                cb(.{ .attached = {} });
            }
            future.complete({});
        } else {
            future.fail(DapError.InvalidSession);
        }

        return future;
    }

    /// Set breakpoint
    pub fn setBreakpoint(
        self: *Dap,
        adapter_id: AdapterId,
        source_path: []const u8,
        line: u32,
        condition: ?[]const u8,
    ) *Future(Breakpoint) {
        const future = self.allocator.create(Future(Breakpoint)) catch {
            const err_future = self.allocator.create(Future(Breakpoint)) catch unreachable;
            err_future.* = Future(Breakpoint).init();
            err_future.fail(DapError.OutOfMemory);
            return err_future;
        };
        future.* = Future(Breakpoint).init();

        if (self.adapters.getPtr(adapter_id.id)) |entry| {
            const bp_id = entry.next_breakpoint_id;
            entry.next_breakpoint_id += 1;

            const bp = Breakpoint{
                .id = bp_id,
                .breakpoint_type = if (condition != null) .conditional else .line,
                .verified = true,
                .source_path = source_path,
                .line = line,
                .condition = condition,
            };

            entry.breakpoints.put(self.allocator, bp_id, bp) catch {
                future.fail(DapError.OutOfMemory);
                return future;
            };

            entry.session.breakpoint_count += 1;
            future.complete(bp);
        } else {
            future.fail(DapError.InvalidSession);
        }

        return future;
    }

    /// Remove breakpoint
    pub fn removeBreakpoint(self: *Dap, adapter_id: AdapterId, breakpoint_id: u64) bool {
        if (self.adapters.getPtr(adapter_id.id)) |entry| {
            if (entry.breakpoints.remove(breakpoint_id)) {
                if (entry.session.breakpoint_count > 0) {
                    entry.session.breakpoint_count -= 1;
                }
                return true;
            }
        }
        return false;
    }

    /// Continue execution
    pub fn continueExecution(self: *Dap, adapter_id: AdapterId, thread_id: u64) void {
        if (self.adapters.getPtr(adapter_id.id)) |entry| {
            entry.session.state = .running;
            entry.session.stop_reason = null;
            if (entry.event_callback) |cb| {
                cb(.{ .continued = thread_id });
            }
        }
    }

    /// Pause execution
    pub fn pause(self: *Dap, adapter_id: AdapterId, thread_id: u64) void {
        if (self.adapters.getPtr(adapter_id.id)) |entry| {
            entry.session.state = .paused;
            entry.session.stop_reason = .pause;
            entry.session.current_thread_id = thread_id;
            if (entry.event_callback) |cb| {
                cb(.{ .stopped = .{ .reason = .pause, .thread_id = thread_id } });
            }
        }
    }

    /// Step into
    pub fn stepInto(self: *Dap, adapter_id: AdapterId, thread_id: u64) void {
        if (self.adapters.getPtr(adapter_id.id)) |entry| {
            // Simulate stepping
            entry.session.state = .paused;
            entry.session.stop_reason = .step;
            entry.session.current_thread_id = thread_id;
            if (entry.event_callback) |cb| {
                cb(.{ .stopped = .{ .reason = .step, .thread_id = thread_id } });
            }
        }
    }

    /// Step over
    pub fn stepOver(self: *Dap, adapter_id: AdapterId, thread_id: u64) void {
        if (self.adapters.getPtr(adapter_id.id)) |entry| {
            entry.session.state = .paused;
            entry.session.stop_reason = .step;
            entry.session.current_thread_id = thread_id;
            if (entry.event_callback) |cb| {
                cb(.{ .stopped = .{ .reason = .step, .thread_id = thread_id } });
            }
        }
    }

    /// Step out
    pub fn stepOut(self: *Dap, adapter_id: AdapterId, thread_id: u64) void {
        if (self.adapters.getPtr(adapter_id.id)) |entry| {
            entry.session.state = .paused;
            entry.session.stop_reason = .step;
            entry.session.current_thread_id = thread_id;
            if (entry.event_callback) |cb| {
                cb(.{ .stopped = .{ .reason = .step, .thread_id = thread_id } });
            }
        }
    }

    /// Get session information
    pub fn getSession(self: *const Dap, adapter_id: AdapterId) ?DapSession {
        if (self.adapters.get(adapter_id.id)) |entry| {
            return entry.session;
        }
        return null;
    }

    /// Get capabilities
    pub fn getCapabilities(self: *const Dap, adapter_id: AdapterId) ?DebugCapabilities {
        if (self.adapters.get(adapter_id.id)) |entry| {
            return entry.capabilities;
        }
        return null;
    }

    /// Get threads (stub)
    pub fn getThreads(self: *Dap, adapter_id: AdapterId) ![]Thread {
        if (self.adapters.getPtr(adapter_id.id)) |_| {
            // Stub: return empty thread list
            return &.{};
        }
        return DapError.InvalidSession;
    }

    /// Get stack trace (stub)
    pub fn getStackTrace(self: *Dap, adapter_id: AdapterId, thread_id: u64) ![]StackFrame {
        _ = thread_id;
        if (self.adapters.getPtr(adapter_id.id)) |_| {
            // Stub: return empty stack
            return &.{};
        }
        return DapError.InvalidSession;
    }

    /// Get scopes (stub)
    pub fn getScopes(self: *Dap, adapter_id: AdapterId, frame_id: u64) ![]Scope {
        _ = frame_id;
        if (self.adapters.getPtr(adapter_id.id)) |_| {
            // Stub: return empty scopes
            return &.{};
        }
        return DapError.InvalidSession;
    }

    /// Get variables (stub)
    pub fn getVariables(self: *Dap, adapter_id: AdapterId, variables_reference: u64) ![]Variable {
        _ = variables_reference;
        if (self.adapters.getPtr(adapter_id.id)) |_| {
            // Stub: return empty variables
            return &.{};
        }
        return DapError.InvalidSession;
    }

    /// Evaluate expression (stub)
    pub fn evaluate(self: *Dap, adapter_id: AdapterId, expression: []const u8, frame_id: ?u64) !EvaluateResult {
        _ = expression;
        _ = frame_id;
        if (self.adapters.getPtr(adapter_id.id)) |_| {
            // Stub: return dummy result
            return EvaluateResult{
                .result = "",
            };
        }
        return DapError.InvalidSession;
    }

    /// Register event callback
    pub fn onEvent(self: *Dap, adapter_id: AdapterId, callback: EventCallback) void {
        if (self.adapters.getPtr(adapter_id.id)) |entry| {
            entry.event_callback = callback;
        }
    }

    /// Get active adapter count
    pub fn activeCount(self: *const Dap) usize {
        var count: usize = 0;
        var iter = self.adapters.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.session.state.isActive()) {
                count += 1;
            }
        }
        return count;
    }

    /// Get total adapter count
    pub fn totalCount(self: *const Dap) usize {
        return self.adapters.count();
    }
};

/// Create a DAP manager
pub fn createDapManager(allocator: std.mem.Allocator) Dap {
    return Dap.init(allocator);
}

// Tests
test "Dap initialization" {
    const allocator = std.testing.allocator;
    var dap = createDapManager(allocator);
    defer dap.deinit();

    try std.testing.expectEqual(@as(usize, 0), dap.totalCount());
}

test "AdapterState methods" {
    try std.testing.expect(!AdapterState.stopped.isActive());
    try std.testing.expect(AdapterState.running.isActive());
    try std.testing.expect(AdapterState.paused.isActive());
    try std.testing.expect(!AdapterState.terminated.isActive());

    try std.testing.expect(std.mem.eql(u8, "Running", AdapterState.running.toString()));
}

test "Start debug adapter" {
    const allocator = std.testing.allocator;
    var dap = createDapManager(allocator);
    defer dap.deinit();

    const project_id = project.ProjectId{
        .id = 1,
        .name = "test",
        .path = "/tmp",
    };

    const future = dap.start(project_id, .{});
    defer allocator.destroy(future);
    try std.testing.expect(future.isCompleted());

    const adapter_id = try future.get();
    try std.testing.expect(adapter_id.isValid());
    try std.testing.expectEqual(@as(usize, 1), dap.totalCount());
}

test "Stop debug adapter" {
    const allocator = std.testing.allocator;
    var dap = createDapManager(allocator);
    defer dap.deinit();

    const project_id = project.ProjectId{ .id = 1, .name = "test", .path = "/tmp" };
    const future = dap.start(project_id, .{});
    defer allocator.destroy(future);
    const adapter_id = try future.get();

    dap.stop(adapter_id);
    try std.testing.expectEqual(@as(usize, 0), dap.totalCount());
}

test "Launch debuggee" {
    const allocator = std.testing.allocator;
    var dap = createDapManager(allocator);
    defer dap.deinit();

    const project_id = project.ProjectId{ .id = 1, .name = "test", .path = "/tmp" };
    const start_future = dap.start(project_id, .{});
    defer allocator.destroy(start_future);
    const adapter_id = try start_future.get();

    const launch_future = dap.launch(adapter_id);
    defer allocator.destroy(launch_future);
    try std.testing.expect(launch_future.isCompleted());

    const session = dap.getSession(adapter_id);
    try std.testing.expect(session != null);
    try std.testing.expectEqual(AdapterState.running, session.?.state);
}

test "Set breakpoint" {
    const allocator = std.testing.allocator;
    var dap = createDapManager(allocator);
    defer dap.deinit();

    const project_id = project.ProjectId{ .id = 1, .name = "test", .path = "/tmp" };
    const start_future = dap.start(project_id, .{});
    defer allocator.destroy(start_future);
    const adapter_id = try start_future.get();

    const bp_future = dap.setBreakpoint(adapter_id, "/test.zy", 10, null);
    defer allocator.destroy(bp_future);
    try std.testing.expect(bp_future.isCompleted());

    const bp = try bp_future.get();
    try std.testing.expect(bp.verified);
    try std.testing.expectEqual(@as(u32, 10), bp.line.?);

    const session = dap.getSession(adapter_id);
    try std.testing.expectEqual(@as(u32, 1), session.?.breakpoint_count);
}

test "Pause and continue" {
    const allocator = std.testing.allocator;
    var dap = createDapManager(allocator);
    defer dap.deinit();

    const project_id = project.ProjectId{ .id = 1, .name = "test", .path = "/tmp" };
    const start_future = dap.start(project_id, .{});
    defer allocator.destroy(start_future);
    const adapter_id = try start_future.get();

    const launch_future = dap.launch(adapter_id);
    defer allocator.destroy(launch_future);
    _ = try launch_future.get();

    // Pause
    dap.pause(adapter_id, 1);
    var session = dap.getSession(adapter_id);
    try std.testing.expectEqual(AdapterState.paused, session.?.state);
    try std.testing.expectEqual(StopReason.pause, session.?.stop_reason.?);

    // Continue
    dap.continueExecution(adapter_id, 1);
    session = dap.getSession(adapter_id);
    try std.testing.expectEqual(AdapterState.running, session.?.state);
}

test "Step operations" {
    const allocator = std.testing.allocator;
    var dap = createDapManager(allocator);
    defer dap.deinit();

    const project_id = project.ProjectId{ .id = 1, .name = "test", .path = "/tmp" };
    const start_future = dap.start(project_id, .{});
    defer allocator.destroy(start_future);
    const adapter_id = try start_future.get();

    dap.stepInto(adapter_id, 1);
    var session = dap.getSession(adapter_id);
    try std.testing.expectEqual(AdapterState.paused, session.?.state);
    try std.testing.expectEqual(StopReason.step, session.?.stop_reason.?);

    dap.stepOver(adapter_id, 1);
    session = dap.getSession(adapter_id);
    try std.testing.expectEqual(StopReason.step, session.?.stop_reason.?);

    dap.stepOut(adapter_id, 1);
    session = dap.getSession(adapter_id);
    try std.testing.expectEqual(StopReason.step, session.?.stop_reason.?);
}

test "Active count" {
    const allocator = std.testing.allocator;
    var dap = createDapManager(allocator);
    defer dap.deinit();

    const project_id = project.ProjectId{ .id = 1, .name = "test", .path = "/tmp" };
    const future = dap.start(project_id, .{});
    defer allocator.destroy(future);
    _ = try future.get();

    try std.testing.expectEqual(@as(usize, 1), dap.activeCount());
}

test "Get capabilities" {
    const allocator = std.testing.allocator;
    var dap = createDapManager(allocator);
    defer dap.deinit();

    const project_id = project.ProjectId{ .id = 1, .name = "test", .path = "/tmp" };
    const future = dap.start(project_id, .{});
    defer allocator.destroy(future);
    const adapter_id = try future.get();

    const caps = dap.getCapabilities(adapter_id);
    try std.testing.expect(caps != null);
    try std.testing.expect(caps.?.supports_configuration_done);
    try std.testing.expect(caps.?.supports_conditional_breakpoints);
}
