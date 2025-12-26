//! Build Executor Implementation
//!
//! Implements actual build execution using child processes:
//! - Zig build command invocation
//! - Target-specific build arguments
//! - Output parsing and progress tracking
//!
//! This module provides the real build execution for Issue #50.

const std = @import("std");
const project = @import("project.zig");
const build_mod = @import("build.zig");

/// Build execution error types
pub const ExecutorError = error{
    BuildFailed,
    ProcessSpawnFailed,
    InvalidProjectPath,
    ZigNotFound,
    OutOfMemory,
    IoError,
    Timeout,
};

/// Execution result
pub const ExecutionResult = union(enum) {
    ok: struct {
        exit_code: u8,
        duration_ms: u64,
        output_path: ?[]const u8,
    },
    err: ExecutorError,

    pub fn isOk(self: ExecutionResult) bool {
        return self == .ok;
    }
};

/// Build context for execution
pub const BuildContext = struct {
    project_path: []const u8,
    project_name: []const u8,
    target: project.Target,
    config: build_mod.BuildConfig,
    build_id: build_mod.BuildId,
};

/// Get Zig target triple for platform
pub fn getTargetTriple(target: project.Target) []const u8 {
    return switch (target) {
        .ios => "aarch64-macos",
        .android => "aarch64-linux-android",
        .web => "wasm32-freestanding",
        .macos => "aarch64-macos",
        .windows => "x86_64-windows",
        .linux => "x86_64-linux",
        .embedded => "thumb-freestanding",
    };
}

/// Get optimization flag for build mode
pub fn getOptimizeFlag(mode: build_mod.BuildMode) []const u8 {
    return switch (mode) {
        .debug => "Debug",
        .release => "ReleaseFast",
        .release_safe => "ReleaseSafe",
        .release_small => "ReleaseSmall",
    };
}

/// Build command result with owned allocations
pub const BuildCommandResult = struct {
    args: std.ArrayListUnmanaged([]const u8),
    owned_strings: std.ArrayListUnmanaged([]const u8),

    pub fn deinit(self: *BuildCommandResult, allocator: std.mem.Allocator) void {
        // Free all owned strings first
        for (self.owned_strings.items) |str| {
            allocator.free(str);
        }
        self.owned_strings.deinit(allocator);
        self.args.deinit(allocator);
    }
};

/// Build command arguments for zig build
pub fn buildCommandArgs(
    allocator: std.mem.Allocator,
    ctx: BuildContext,
) !BuildCommandResult {
    var args: std.ArrayListUnmanaged([]const u8) = .{};
    var owned_strings: std.ArrayListUnmanaged([]const u8) = .{};

    errdefer {
        for (owned_strings.items) |str| {
            allocator.free(str);
        }
        owned_strings.deinit(allocator);
        args.deinit(allocator);
    }

    // Base command
    try args.append(allocator, "zig");
    try args.append(allocator, "build");

    // Build file location
    const build_file = try std.fs.path.join(allocator, &.{ ctx.project_path, "build.zig" });
    try owned_strings.append(allocator, build_file);
    try args.append(allocator, "--build-file");
    try args.append(allocator, build_file);

    // Target triple
    try args.append(allocator, "-Dtarget");
    try args.append(allocator, getTargetTriple(ctx.target));

    // Optimization mode
    try args.append(allocator, "-Doptimize");
    try args.append(allocator, getOptimizeFlag(ctx.config.mode));

    // Parallel compilation jobs
    if (ctx.config.max_jobs > 0) {
        const jobs_str = try std.fmt.allocPrint(allocator, "-j{d}", .{ctx.config.max_jobs});
        try owned_strings.append(allocator, jobs_str);
        try args.append(allocator, jobs_str);
    }

    // Add extra flags if specified
    for (ctx.config.extra_flags) |flag| {
        try args.append(allocator, flag);
    }

    return .{ .args = args, .owned_strings = owned_strings };
}

/// Execute build with progress tracking
pub fn executeBuild(
    allocator: std.mem.Allocator,
    ctx: BuildContext,
    progress_callback: ?*const fn (build_mod.BuildState, f32, ?[]const u8) void,
    log_callback: ?*const fn (build_mod.LogLevel, []const u8) void,
) ExecutionResult {
    const start_time = std.time.milliTimestamp();

    // Report preparing state
    if (progress_callback) |cb| {
        cb(.preparing, 0.05, "Preparing build environment");
    }

    // Build the command arguments
    var cmd_result = buildCommandArgs(allocator, ctx) catch {
        return .{ .err = ExecutorError.OutOfMemory };
    };
    defer cmd_result.deinit(allocator);

    // Log the command being executed
    if (log_callback) |cb| {
        var cmd_buf: [1024]u8 = undefined;
        var cmd_len: usize = 0;
        for (cmd_result.args.items) |arg| {
            if (cmd_len + arg.len + 1 < cmd_buf.len) {
                @memcpy(cmd_buf[cmd_len..][0..arg.len], arg);
                cmd_len += arg.len;
                cmd_buf[cmd_len] = ' ';
                cmd_len += 1;
            }
        }
        cb(.info, cmd_buf[0..cmd_len]);
    }

    // Check if build.zig exists
    const build_file = std.fs.path.join(allocator, &.{ ctx.project_path, "build.zig" }) catch {
        return .{ .err = ExecutorError.OutOfMemory };
    };
    defer allocator.free(build_file);

    std.fs.cwd().access(build_file, .{}) catch {
        if (log_callback) |cb| {
            cb(.err, "build.zig not found in project directory");
        }
        return .{ .err = ExecutorError.InvalidProjectPath };
    };

    // Report compiling state
    if (progress_callback) |cb| {
        cb(.compiling, 0.2, "Compiling source files");
    }

    // Prepare child process
    const args_slice = cmd_result.args.items;

    var child = std.process.Child.init(args_slice, allocator);
    // Use project path as working directory
    child.cwd = ctx.project_path;

    // Set environment variables from config
    if (ctx.config.env.len > 0) {
        var env_map = std.process.EnvMap.init(allocator);
        defer env_map.deinit();

        for (ctx.config.env) |env_var| {
            env_map.put(env_var.key, env_var.value) catch continue;
        }
        child.env_map = &env_map;
    }

    // Capture stdout and stderr
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    // Spawn the process
    child.spawn() catch {
        if (log_callback) |cb| {
            cb(.err, "Failed to spawn zig build process");
        }
        return .{ .err = ExecutorError.ProcessSpawnFailed };
    };

    // Report linking state (simulated progress)
    if (progress_callback) |cb| {
        cb(.linking, 0.6, "Linking objects");
    }

    // Wait for process completion
    const result = child.wait() catch {
        if (log_callback) |cb| {
            cb(.err, "Build process failed unexpectedly");
        }
        return .{ .err = ExecutorError.BuildFailed };
    };

    const end_time = std.time.milliTimestamp();
    const duration_ms: u64 = @intCast(end_time - start_time);

    // Read stderr for any error output
    if (child.stderr) |stderr| {
        var stderr_buf: [4096]u8 = undefined;
        const stderr_len = stderr.readAll(&stderr_buf) catch 0;
        if (stderr_len > 0) {
            if (log_callback) |cb| {
                cb(.warning, stderr_buf[0..stderr_len]);
            }
        }
    }

    // Check result
    switch (result) {
        .Exited => |code| {
            if (code == 0) {
                // Build succeeded
                if (progress_callback) |cb| {
                    cb(.completed, 1.0, "Build completed successfully");
                }
                if (log_callback) |cb| {
                    cb(.info, "Build completed successfully");
                }

                // Determine output path
                const output_dir = ctx.config.output_dir orelse "zig-out";
                const output_path = std.fs.path.join(allocator, &.{ ctx.project_path, output_dir }) catch null;

                return .{
                    .ok = .{
                        .exit_code = code,
                        .duration_ms = duration_ms,
                        .output_path = output_path,
                    },
                };
            } else {
                // Build failed
                if (progress_callback) |cb| {
                    cb(.failed, 0.0, "Build failed with errors");
                }
                if (log_callback) |cb| {
                    var err_msg: [64]u8 = undefined;
                    const msg = std.fmt.bufPrint(&err_msg, "Build failed with exit code: {d}", .{code}) catch "Build failed";
                    cb(.err, msg);
                }
                return .{ .err = ExecutorError.BuildFailed };
            }
        },
        .Signal => {
            if (progress_callback) |cb| {
                cb(.failed, 0.0, "Build process terminated by signal");
            }
            return .{ .err = ExecutorError.BuildFailed };
        },
        else => {
            if (progress_callback) |cb| {
                cb(.failed, 0.0, "Build process terminated abnormally");
            }
            return .{ .err = ExecutorError.BuildFailed };
        },
    }
}

/// Synchronous build execution (blocking)
pub fn runBuildSync(
    allocator: std.mem.Allocator,
    project_path: []const u8,
    project_name: []const u8,
    target: project.Target,
    config: build_mod.BuildConfig,
    build_id: build_mod.BuildId,
) ExecutionResult {
    const ctx = BuildContext{
        .project_path = project_path,
        .project_name = project_name,
        .target = target,
        .config = config,
        .build_id = build_id,
    };

    return executeBuild(allocator, ctx, null, null);
}

/// Validate build environment
pub fn validateEnvironment(allocator: std.mem.Allocator) bool {
    // Check if zig is available
    const args = [_][]const u8{ "zig", "version" };

    var child = std.process.Child.init(&args, allocator);
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;

    child.spawn() catch return false;

    const result = child.wait() catch return false;

    return switch (result) {
        .Exited => |code| code == 0,
        else => false,
    };
}

/// Get Zig version string
pub fn getZigVersion(allocator: std.mem.Allocator) ?[]const u8 {
    const args = [_][]const u8{ "zig", "version" };

    var child = std.process.Child.init(&args, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Ignore;

    child.spawn() catch return null;

    if (child.stdout) |stdout| {
        var buf: [64]u8 = undefined;
        const len = stdout.readAll(&buf) catch return null;
        if (len > 0) {
            // Trim whitespace
            var end = len;
            while (end > 0 and (buf[end - 1] == '\n' or buf[end - 1] == '\r')) {
                end -= 1;
            }
            const result = allocator.alloc(u8, end) catch return null;
            @memcpy(result, buf[0..end]);
            return result;
        }
    }

    _ = child.wait() catch {};
    return null;
}

// =============================================================================
// TESTS
// =============================================================================

test "getTargetTriple" {
    try std.testing.expect(std.mem.eql(u8, "aarch64-macos", getTargetTriple(.ios)));
    try std.testing.expect(std.mem.eql(u8, "aarch64-linux-android", getTargetTriple(.android)));
    try std.testing.expect(std.mem.eql(u8, "wasm32-freestanding", getTargetTriple(.web)));
    try std.testing.expect(std.mem.eql(u8, "aarch64-macos", getTargetTriple(.macos)));
    try std.testing.expect(std.mem.eql(u8, "x86_64-windows", getTargetTriple(.windows)));
    try std.testing.expect(std.mem.eql(u8, "x86_64-linux", getTargetTriple(.linux)));
}

test "getOptimizeFlag" {
    try std.testing.expect(std.mem.eql(u8, "Debug", getOptimizeFlag(.debug)));
    try std.testing.expect(std.mem.eql(u8, "ReleaseFast", getOptimizeFlag(.release)));
    try std.testing.expect(std.mem.eql(u8, "ReleaseSafe", getOptimizeFlag(.release_safe)));
    try std.testing.expect(std.mem.eql(u8, "ReleaseSmall", getOptimizeFlag(.release_small)));
}

test "buildCommandArgs" {
    const allocator = std.testing.allocator;

    const ctx = BuildContext{
        .project_path = "/tmp/myproject",
        .project_name = "myproject",
        .target = .ios,
        .config = .{ .mode = .release },
        .build_id = .{
            .id = 1,
            .project_name = "myproject",
            .target = .ios,
            .started_at = 0,
        },
    };

    var result = try buildCommandArgs(allocator, ctx);
    defer result.deinit(allocator);

    try std.testing.expect(result.args.items.len >= 7);
    try std.testing.expect(std.mem.eql(u8, "zig", result.args.items[0]));
    try std.testing.expect(std.mem.eql(u8, "build", result.args.items[1]));
}

test "validateEnvironment" {
    const allocator = std.testing.allocator;
    // This test checks if zig is available in the environment
    const has_zig = validateEnvironment(allocator);
    // We expect zig to be available in the test environment
    try std.testing.expect(has_zig);
}
