//! Build Orchestration API
//!
//! Multi-target build execution with support for:
//! - Build configuration management
//! - Progress and log streaming
//! - Parallel build support
//! - Build caching and incremental builds
//!
//! This module provides the foundation for the `zylix build` CLI command.

const std = @import("std");
const project = @import("project.zig");
const build_executor = @import("build_executor.zig");

/// Build error types
pub const BuildError = error{
    NotInitialized,
    InvalidProject,
    InvalidTarget,
    InvalidConfiguration,
    BuildFailed,
    BuildCancelled,
    DependencyError,
    CompilationError,
    LinkingError,
    SigningError,
    OutOfMemory,
};

/// Build identifier
pub const BuildId = struct {
    id: u64,
    project_name: []const u8,
    target: project.Target,
    started_at: i64,

    pub fn isValid(self: *const BuildId) bool {
        return self.id > 0;
    }
};

/// Build configuration
pub const BuildConfig = struct {
    /// Build mode
    mode: BuildMode = .debug,
    /// Optimization level
    optimization: OptimizationLevel = .none,
    /// Enable code signing
    sign: bool = false,
    /// Code signing identity
    signing_identity: ?[]const u8 = null,
    /// Enable parallel compilation
    parallel: bool = true,
    /// Maximum parallel jobs
    max_jobs: u8 = 0, // 0 = auto-detect
    /// Enable incremental build
    incremental: bool = true,
    /// Enable build cache
    cache: bool = true,
    /// Additional compiler flags
    extra_flags: []const []const u8 = &.{},
    /// Environment variables
    env: []const EnvVar = &.{},
    /// Output directory override
    output_dir: ?[]const u8 = null,
};

/// Environment variable
pub const EnvVar = struct {
    key: []const u8,
    value: []const u8,
};

/// Build mode
pub const BuildMode = enum(u8) {
    debug = 0,
    release = 1,
    release_safe = 2,
    release_small = 3,

    pub fn toString(self: BuildMode) []const u8 {
        return switch (self) {
            .debug => "debug",
            .release => "release",
            .release_safe => "release-safe",
            .release_small => "release-small",
        };
    }
};

/// Optimization level
pub const OptimizationLevel = enum(u8) {
    none = 0, // -O0
    size = 1, // -Os
    speed = 2, // -O2
    aggressive = 3, // -O3

    pub fn toFlag(self: OptimizationLevel) []const u8 {
        return switch (self) {
            .none => "-O0",
            .size => "-Os",
            .speed => "-O2",
            .aggressive => "-O3",
        };
    }
};

/// Build status
pub const BuildStatus = struct {
    state: BuildState,
    progress: f32, // 0.0 - 1.0
    current_step: ?[]const u8 = null,
    files_compiled: u32 = 0,
    files_total: u32 = 0,
    errors: u32 = 0,
    warnings: u32 = 0,
    elapsed_ms: u64 = 0,
};

/// Build state
pub const BuildState = enum(u8) {
    pending = 0,
    preparing = 1,
    compiling = 2,
    linking = 3,
    signing = 4,
    packaging = 5,
    completed = 6,
    failed = 7,
    cancelled = 8,

    pub fn isFinished(self: BuildState) bool {
        return self == .completed or self == .failed or self == .cancelled;
    }

    pub fn isSuccess(self: BuildState) bool {
        return self == .completed;
    }
};

/// Build progress event
pub const BuildProgress = struct {
    build_id: BuildId,
    state: BuildState,
    progress: f32,
    message: ?[]const u8 = null,
    file: ?[]const u8 = null,
    timestamp: i64,
};

/// Log entry
pub const LogEntry = struct {
    build_id: BuildId,
    level: LogLevel,
    message: []const u8,
    file: ?[]const u8 = null,
    line: ?u32 = null,
    column: ?u32 = null,
    timestamp: i64,
};

/// Log level
pub const LogLevel = enum(u8) {
    debug = 0,
    info = 1,
    warning = 2,
    err = 3,

    pub fn toString(self: LogLevel) []const u8 {
        return switch (self) {
            .debug => "DEBUG",
            .info => "INFO",
            .warning => "WARN",
            .err => "ERROR",
        };
    }
};

/// Build result
pub const BuildResult = struct {
    build_id: BuildId,
    success: bool,
    duration_ms: u64,
    output_path: ?[]const u8 = null,
    errors: []const BuildDiagnostic = &.{},
    warnings: []const BuildDiagnostic = &.{},
};

/// Build diagnostic
pub const BuildDiagnostic = struct {
    message: []const u8,
    file: ?[]const u8 = null,
    line: ?u32 = null,
    column: ?u32 = null,
    code: ?[]const u8 = null,
};

/// Progress callback type
pub const ProgressCallback = *const fn (BuildProgress) void;

/// Log callback type
pub const LogCallback = *const fn (LogEntry) void;

/// Future result wrapper
pub fn Future(comptime T: type) type {
    return struct {
        const Self = @This();

        result: ?T = null,
        err: ?BuildError = null,
        completed: bool = false,
        callback: ?*const fn (?T, ?BuildError) void = null,

        pub fn init() Self {
            return .{};
        }

        pub fn complete(self: *Self, value: T) void {
            self.result = value;
            self.completed = true;
            if (self.callback) |cb| {
                cb(value, null);
            }
        }

        pub fn fail(self: *Self, err: BuildError) void {
            self.err = err;
            self.completed = true;
            if (self.callback) |cb| {
                cb(null, err);
            }
        }

        pub fn isCompleted(self: *const Self) bool {
            return self.completed;
        }

        pub fn get(self: *const Self) BuildError!T {
            if (self.err) |e| return e;
            if (self.result) |r| return r;
            return BuildError.NotInitialized;
        }
    };
}

/// Build state entry
const BuildEntry = struct {
    id: BuildId,
    config: BuildConfig,
    status: BuildStatus,
    progress_callback: ?ProgressCallback = null,
    log_callback: ?LogCallback = null,
};

/// Build Orchestrator
pub const Build = struct {
    allocator: std.mem.Allocator,
    builds: std.AutoHashMapUnmanaged(u64, BuildEntry) = .{},
    next_id: u64 = 1,

    pub fn init(allocator: std.mem.Allocator) Build {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Build) void {
        self.builds.deinit(self.allocator);
    }

    /// Start a new build
    pub fn start(
        self: *Build,
        project_id: project.ProjectId,
        target: project.Target,
        config: BuildConfig,
    ) *Future(BuildId) {
        const future = self.allocator.create(Future(BuildId)) catch {
            const err_future = self.allocator.create(Future(BuildId)) catch unreachable;
            err_future.* = Future(BuildId).init();
            err_future.fail(BuildError.OutOfMemory);
            return err_future;
        };
        future.* = Future(BuildId).init();

        if (!project_id.isValid()) {
            future.fail(BuildError.InvalidProject);
            return future;
        }

        const build_id = BuildId{
            .id = self.next_id,
            .project_name = project_id.name,
            .target = target,
            .started_at = std.time.timestamp(),
        };
        self.next_id += 1;

        const entry = BuildEntry{
            .id = build_id,
            .config = config,
            .status = .{
                .state = .pending,
                .progress = 0.0,
            },
        };

        self.builds.put(self.allocator, build_id.id, entry) catch {
            future.fail(BuildError.OutOfMemory);
            return future;
        };

        // Execute actual build process
        const exec_result = build_executor.runBuildSync(
            self.allocator,
            project_id.path,
            project_id.name,
            target,
            config,
            build_id,
        );

        switch (exec_result) {
            .ok => |result| {
                // Update build status to completed
                if (self.builds.getPtr(build_id.id)) |build_entry| {
                    build_entry.status.state = .completed;
                    build_entry.status.progress = 1.0;
                    build_entry.status.elapsed_ms = result.duration_ms;
                }
                future.complete(build_id);
            },
            .err => |err| {
                // Update build status to failed
                if (self.builds.getPtr(build_id.id)) |build_entry| {
                    build_entry.status.state = .failed;
                }
                switch (err) {
                    build_executor.ExecutorError.InvalidProjectPath => future.fail(BuildError.InvalidProject),
                    build_executor.ExecutorError.ProcessSpawnFailed => future.fail(BuildError.BuildFailed),
                    build_executor.ExecutorError.OutOfMemory => future.fail(BuildError.OutOfMemory),
                    else => future.fail(BuildError.BuildFailed),
                }
            },
        }
        return future;
    }

    /// Start a build with progress and log callbacks
    pub fn startWithCallbacks(
        self: *Build,
        project_id: project.ProjectId,
        target: project.Target,
        config: BuildConfig,
        progress_cb: ?ProgressCallback,
        log_cb: ?LogCallback,
    ) *Future(BuildId) {
        const future = self.allocator.create(Future(BuildId)) catch {
            const err_future = self.allocator.create(Future(BuildId)) catch unreachable;
            err_future.* = Future(BuildId).init();
            err_future.fail(BuildError.OutOfMemory);
            return err_future;
        };
        future.* = Future(BuildId).init();

        if (!project_id.isValid()) {
            future.fail(BuildError.InvalidProject);
            return future;
        }

        const build_id = BuildId{
            .id = self.next_id,
            .project_name = project_id.name,
            .target = target,
            .started_at = std.time.timestamp(),
        };
        self.next_id += 1;

        const entry = BuildEntry{
            .id = build_id,
            .config = config,
            .status = .{
                .state = .pending,
                .progress = 0.0,
            },
            .progress_callback = progress_cb,
            .log_callback = log_cb,
        };

        self.builds.put(self.allocator, build_id.id, entry) catch {
            future.fail(BuildError.OutOfMemory);
            return future;
        };

        // Create internal callback wrappers
        const ProgressWrapper = struct {
            fn wrap(state: BuildState, prog: f32, msg: ?[]const u8) void {
                _ = state;
                _ = prog;
                _ = msg;
                // In a full implementation, this would update the entry
            }
        };

        const LogWrapper = struct {
            fn wrap(level: LogLevel, msg: []const u8) void {
                _ = level;
                _ = msg;
                // In a full implementation, this would emit to the log callback
            }
        };

        // Execute build with callbacks
        const ctx = build_executor.BuildContext{
            .project_path = project_id.path,
            .project_name = project_id.name,
            .target = target,
            .config = config,
            .build_id = build_id,
        };

        const exec_result = build_executor.executeBuild(
            self.allocator,
            ctx,
            ProgressWrapper.wrap,
            LogWrapper.wrap,
        );

        switch (exec_result) {
            .ok => |result| {
                if (self.builds.getPtr(build_id.id)) |build_entry| {
                    build_entry.status.state = .completed;
                    build_entry.status.progress = 1.0;
                    build_entry.status.elapsed_ms = result.duration_ms;
                }
                future.complete(build_id);
            },
            .err => |err| {
                if (self.builds.getPtr(build_id.id)) |build_entry| {
                    build_entry.status.state = .failed;
                }
                switch (err) {
                    build_executor.ExecutorError.InvalidProjectPath => future.fail(BuildError.InvalidProject),
                    build_executor.ExecutorError.ProcessSpawnFailed => future.fail(BuildError.BuildFailed),
                    build_executor.ExecutorError.OutOfMemory => future.fail(BuildError.OutOfMemory),
                    else => future.fail(BuildError.BuildFailed),
                }
            },
        }
        return future;
    }

    /// Cancel a running build
    pub fn cancel(self: *Build, build_id: BuildId) void {
        if (self.builds.getPtr(build_id.id)) |entry| {
            if (!entry.status.state.isFinished()) {
                entry.status.state = .cancelled;
            }
        }
    }

    /// Get build status
    pub fn getStatus(self: *const Build, build_id: BuildId) ?BuildStatus {
        if (self.builds.get(build_id.id)) |entry| {
            return entry.status;
        }
        return null;
    }

    /// Register progress callback
    pub fn onProgress(self: *Build, build_id: BuildId, callback: ProgressCallback) void {
        if (self.builds.getPtr(build_id.id)) |entry| {
            entry.progress_callback = callback;
        }
    }

    /// Register log callback
    pub fn onLog(self: *Build, build_id: BuildId, callback: LogCallback) void {
        if (self.builds.getPtr(build_id.id)) |entry| {
            entry.log_callback = callback;
        }
    }

    /// Update build progress (called internally)
    pub fn updateProgress(self: *Build, build_id: BuildId, state: BuildState, progress: f32, message: ?[]const u8) void {
        if (self.builds.getPtr(build_id.id)) |entry| {
            entry.status.state = state;
            entry.status.progress = progress;
            entry.status.current_step = message;

            if (entry.progress_callback) |cb| {
                cb(.{
                    .build_id = build_id,
                    .state = state,
                    .progress = progress,
                    .message = message,
                    .timestamp = std.time.timestamp(),
                });
            }
        }
    }

    /// Emit log entry (called internally)
    pub fn emitLog(self: *Build, build_id: BuildId, level: LogLevel, message: []const u8) void {
        if (self.builds.get(build_id.id)) |entry| {
            if (entry.log_callback) |cb| {
                cb(.{
                    .build_id = build_id,
                    .level = level,
                    .message = message,
                    .timestamp = std.time.timestamp(),
                });
            }
        }
    }

    /// Get active build count
    pub fn activeCount(self: *const Build) usize {
        var count: usize = 0;
        var iter = self.builds.iterator();
        while (iter.next()) |entry| {
            if (!entry.value_ptr.status.state.isFinished()) {
                count += 1;
            }
        }
        return count;
    }

    /// Get total build count
    pub fn totalCount(self: *const Build) usize {
        return self.builds.count();
    }
};

/// Create a build orchestrator
pub fn createBuildOrchestrator(allocator: std.mem.Allocator) Build {
    return Build.init(allocator);
}

// Tests
test "Build initialization" {
    const allocator = std.testing.allocator;
    var build = createBuildOrchestrator(allocator);
    defer build.deinit();

    try std.testing.expectEqual(@as(usize, 0), build.totalCount());
}

test "BuildMode conversion" {
    try std.testing.expect(std.mem.eql(u8, "debug", BuildMode.debug.toString()));
    try std.testing.expect(std.mem.eql(u8, "release", BuildMode.release.toString()));
}

test "OptimizationLevel flags" {
    try std.testing.expect(std.mem.eql(u8, "-O0", OptimizationLevel.none.toFlag()));
    try std.testing.expect(std.mem.eql(u8, "-O2", OptimizationLevel.speed.toFlag()));
    try std.testing.expect(std.mem.eql(u8, "-O3", OptimizationLevel.aggressive.toFlag()));
}

test "BuildState checks" {
    try std.testing.expect(!BuildState.pending.isFinished());
    try std.testing.expect(!BuildState.compiling.isFinished());
    try std.testing.expect(BuildState.completed.isFinished());
    try std.testing.expect(BuildState.failed.isFinished());
    try std.testing.expect(BuildState.cancelled.isFinished());

    try std.testing.expect(BuildState.completed.isSuccess());
    try std.testing.expect(!BuildState.failed.isSuccess());
}

test "Build start" {
    const allocator = std.testing.allocator;
    var build = createBuildOrchestrator(allocator);
    defer build.deinit();

    const project_id = project.ProjectId{
        .id = 1,
        .name = "test",
        .path = "/tmp",
    };

    const future = build.start(project_id, .ios, .{});
    defer allocator.destroy(future);
    try std.testing.expect(future.isCompleted());

    const build_id = try future.get();
    try std.testing.expect(build_id.isValid());
    try std.testing.expectEqual(@as(usize, 1), build.totalCount());
}

test "Build cancel" {
    const allocator = std.testing.allocator;
    var build = createBuildOrchestrator(allocator);
    defer build.deinit();

    const project_id = project.ProjectId{
        .id = 1,
        .name = "test",
        .path = "/tmp",
    };

    const future = build.start(project_id, .web, .{});
    defer allocator.destroy(future);
    const build_id = try future.get();

    build.cancel(build_id);

    const status = build.getStatus(build_id);
    try std.testing.expect(status != null);
    try std.testing.expectEqual(BuildState.cancelled, status.?.state);
}

test "Build progress update" {
    const allocator = std.testing.allocator;
    var build = createBuildOrchestrator(allocator);
    defer build.deinit();

    const project_id = project.ProjectId{
        .id = 1,
        .name = "test",
        .path = "/tmp",
    };

    const future = build.start(project_id, .android, .{});
    defer allocator.destroy(future);
    const build_id = try future.get();

    build.updateProgress(build_id, .compiling, 0.5, "Compiling main.zig");

    const status = build.getStatus(build_id);
    try std.testing.expect(status != null);
    try std.testing.expectEqual(BuildState.compiling, status.?.state);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), status.?.progress, 0.01);
}

test "LogLevel conversion" {
    try std.testing.expect(std.mem.eql(u8, "DEBUG", LogLevel.debug.toString()));
    try std.testing.expect(std.mem.eql(u8, "ERROR", LogLevel.err.toString()));
}
