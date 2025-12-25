//! Project Scaffolding File I/O Implementation
//!
//! Implements actual file system operations for project creation:
//! - Directory structure creation
//! - Template file generation
//! - Configuration file writing
//!
//! This module provides the real file I/O for Issue #49.

const std = @import("std");
const project = @import("project.zig");

/// File I/O error types
pub const IoError = error{
    DirectoryExists,
    DirectoryNotFound,
    PermissionDenied,
    OutOfMemory,
    IoError,
    InvalidPath,
};

/// Result type for I/O operations
pub const IoResult = union(enum) {
    ok: void,
    err: IoError,

    pub fn isOk(self: IoResult) bool {
        return self == .ok;
    }
};

/// Create project directory structure on disk
pub fn createProjectDirectory(
    allocator: std.mem.Allocator,
    output_dir: []const u8,
    config: project.ProjectConfig,
) IoResult {
    // Generate the directory list
    const dirs = project.generateProjectStructure(allocator, config) catch {
        return .{ .err = IoError.OutOfMemory };
    };
    defer allocator.free(dirs);

    // Create base directory
    std.fs.cwd().makePath(output_dir) catch |err| {
        return switch (err) {
            error.AccessDenied => .{ .err = IoError.PermissionDenied },
            else => .{ .err = IoError.IoError },
        };
    };

    // Create subdirectories
    for (dirs) |dir| {
        const full_path = std.fs.path.join(allocator, &.{ output_dir, dir }) catch {
            return .{ .err = IoError.OutOfMemory };
        };
        defer allocator.free(full_path);

        std.fs.cwd().makePath(full_path) catch |err| {
            return switch (err) {
                error.AccessDenied => .{ .err = IoError.PermissionDenied },
                else => .{ .err = IoError.IoError },
            };
        };
    }

    return .{ .ok = {} };
}

/// Write a file to the project directory
pub fn writeProjectFile(
    allocator: std.mem.Allocator,
    output_dir: []const u8,
    relative_path: []const u8,
    content: []const u8,
) IoResult {
    const full_path = std.fs.path.join(allocator, &.{ output_dir, relative_path }) catch {
        return .{ .err = IoError.OutOfMemory };
    };
    defer allocator.free(full_path);

    // Ensure parent directory exists
    if (std.fs.path.dirname(full_path)) |parent| {
        std.fs.cwd().makePath(parent) catch |err| {
            return switch (err) {
                error.AccessDenied => .{ .err = IoError.PermissionDenied },
                else => .{ .err = IoError.IoError },
            };
        };
    }

    // Write file
    const file = std.fs.cwd().createFile(full_path, .{}) catch |err| {
        return switch (err) {
            error.AccessDenied => .{ .err = IoError.PermissionDenied },
            else => .{ .err = IoError.IoError },
        };
    };
    defer file.close();

    file.writeAll(content) catch {
        return .{ .err = IoError.IoError };
    };

    return .{ .ok = {} };
}

/// Generate zylix.json project configuration file
pub fn generateZylixJson(
    allocator: std.mem.Allocator,
    config: project.ProjectConfig,
) ![]const u8 {
    var buf: std.ArrayListUnmanaged(u8) = .{};
    const writer = buf.writer(allocator);

    try writer.writeAll("{\n");
    try writer.print("  \"name\": \"{s}\",\n", .{config.name});
    try writer.print("  \"version\": \"{s}\",\n", .{config.version});

    if (config.description.len > 0) {
        try writer.print("  \"description\": \"{s}\",\n", .{config.description});
    }

    if (config.author) |author| {
        try writer.print("  \"author\": \"{s}\",\n", .{author});
    }

    if (config.license) |license| {
        try writer.print("  \"license\": \"{s}\",\n", .{license});
    }

    if (config.org_id) |org_id| {
        try writer.print("  \"organizationId\": \"{s}\",\n", .{org_id});
    }

    // Write project type
    try writer.print("  \"type\": \"{s}\",\n", .{@tagName(config.project_type)});

    // Write targets
    try writer.writeAll("  \"targets\": [");
    for (config.targets, 0..) |target, i| {
        if (i > 0) try writer.writeAll(", ");
        try writer.print("\"{s}\"", .{target.toString()});
    }
    try writer.writeAll("],\n");

    // Write template if specified
    if (config.template_id) |template_id| {
        try writer.print("  \"template\": \"{s}\",\n", .{template_id});
    }

    try writer.writeAll("  \"zylix\": {\n");
    try writer.writeAll("    \"version\": \"0.19.1\"\n");
    try writer.writeAll("  }\n");
    try writer.writeAll("}\n");

    return try buf.toOwnedSlice(allocator);
}

/// Generate build.zig file
pub fn generateBuildZig(
    allocator: std.mem.Allocator,
    config: project.ProjectConfig,
) ![]const u8 {
    var buf: std.ArrayListUnmanaged(u8) = .{};
    const writer = buf.writer(allocator);

    try writer.writeAll(
        \\const std = @import("std");
        \\
        \\pub fn build(b: *std.Build) void {
        \\    const target = b.standardTargetOptions(.{});
        \\    const optimize = b.standardOptimizeOption(.{});
        \\
        \\    const lib = b.addLibrary(.{
        \\        .linkage = .static,
        \\
    );
    try writer.print("        .name = \"{s}\",\n", .{config.name});
    try writer.writeAll(
        \\        .root_module = b.createModule(.{
        \\            .root_source_file = b.path("src/main.zig"),
        \\            .target = target,
        \\            .optimize = optimize,
        \\        }),
        \\    });
        \\
        \\    b.installArtifact(lib);
        \\
        \\    const unit_tests = b.addTest(.{
        \\        .root_module = b.createModule(.{
        \\            .root_source_file = b.path("src/main.zig"),
        \\            .target = target,
        \\            .optimize = optimize,
        \\        }),
        \\    });
        \\
        \\    const run_unit_tests = b.addRunArtifact(unit_tests);
        \\    const test_step = b.step("test", "Run unit tests");
        \\    test_step.dependOn(&run_unit_tests.step);
        \\}
        \\
    );

    return try buf.toOwnedSlice(allocator);
}

/// Generate main.zig entry point
pub fn generateMainZig(
    allocator: std.mem.Allocator,
    config: project.ProjectConfig,
) ![]const u8 {
    var buf: std.ArrayListUnmanaged(u8) = .{};
    const writer = buf.writer(allocator);

    try writer.print("//! {s}\n", .{config.name});
    if (config.description.len > 0) {
        try writer.print("//! {s}\n", .{config.description});
    }
    try writer.writeAll(
        \\
        \\const std = @import("std");
        \\
        \\/// Application entry point
        \\pub fn main() !void {
        \\    const stdout = std.io.getStdOut().writer();
        \\    try stdout.print("Hello from Zylix!\n", .{});
        \\}
        \\
        \\test "basic test" {
        \\    try std.testing.expect(true);
        \\}
        \\
    );

    return try buf.toOwnedSlice(allocator);
}

/// Generate .gitignore file
pub fn generateGitignore(allocator: std.mem.Allocator) ![]const u8 {
    _ = allocator;
    return
        \\# Zig build artifacts
        \\zig-cache/
        \\zig-out/
        \\.zig-cache/
        \\
        \\# Zylix artifacts
        \\.zylix/
        \\build/
        \\dist/
        \\
        \\# IDE
        \\.idea/
        \\.vscode/
        \\*.swp
        \\*.swo
        \\*~
        \\
        \\# macOS
        \\.DS_Store
        \\
        \\# Platform specific
        \\platforms/ios/build/
        \\platforms/ios/Pods/
        \\platforms/android/.gradle/
        \\platforms/android/build/
        \\platforms/web/node_modules/
        \\
    ;
}

/// Create all project files from template
pub fn scaffoldProject(
    allocator: std.mem.Allocator,
    output_dir: []const u8,
    config: project.ProjectConfig,
) IoResult {
    // Create directory structure
    const dir_result = createProjectDirectory(allocator, output_dir, config);
    if (dir_result != .ok) return dir_result;

    // Generate and write zylix.json
    const zylix_json = generateZylixJson(allocator, config) catch {
        return .{ .err = IoError.OutOfMemory };
    };
    defer allocator.free(zylix_json);

    const json_result = writeProjectFile(allocator, output_dir, "zylix.json", zylix_json);
    if (json_result != .ok) return json_result;

    // Generate and write build.zig
    const build_zig = generateBuildZig(allocator, config) catch {
        return .{ .err = IoError.OutOfMemory };
    };
    defer allocator.free(build_zig);

    const build_result = writeProjectFile(allocator, output_dir, "build.zig", build_zig);
    if (build_result != .ok) return build_result;

    // Generate and write src/main.zig
    const main_zig = generateMainZig(allocator, config) catch {
        return .{ .err = IoError.OutOfMemory };
    };
    defer allocator.free(main_zig);

    const main_result = writeProjectFile(allocator, output_dir, "src/main.zig", main_zig);
    if (main_result != .ok) return main_result;

    // Generate and write .gitignore if git init is enabled
    if (config.init_git) {
        const gitignore = generateGitignore(allocator) catch {
            return .{ .err = IoError.OutOfMemory };
        };

        const git_result = writeProjectFile(allocator, output_dir, ".gitignore", gitignore);
        if (git_result != .ok) return git_result;
    }

    return .{ .ok = {} };
}

/// Check if a directory exists
pub fn directoryExists(path: []const u8) bool {
    std.fs.cwd().access(path, .{}) catch return false;
    return true;
}

/// Delete a directory and its contents
pub fn deleteDirectory(path: []const u8) IoResult {
    std.fs.cwd().deleteTree(path) catch |err| {
        return switch (err) {
            error.AccessDenied => .{ .err = IoError.PermissionDenied },
            else => .{ .err = IoError.IoError },
        };
    };
    return .{ .ok = {} };
}

// =============================================================================
// TESTS
// =============================================================================

test "generate zylix.json" {
    const allocator = std.testing.allocator;

    const targets = [_]project.Target{ .ios, .android, .web };
    const config = project.ProjectConfig{
        .name = "test-app",
        .description = "A test application",
        .version = "1.0.0",
        .targets = &targets,
        .author = "Test Author",
        .license = "MIT",
    };

    const json = try generateZylixJson(allocator, config);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"name\": \"test-app\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"version\": \"1.0.0\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"ios\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"android\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"web\"") != null);
}

test "generate build.zig" {
    const allocator = std.testing.allocator;

    const config = project.ProjectConfig{
        .name = "my-app",
    };

    const build_zig = try generateBuildZig(allocator, config);
    defer allocator.free(build_zig);

    try std.testing.expect(std.mem.indexOf(u8, build_zig, ".name = \"my-app\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, build_zig, "pub fn build") != null);
}

test "generate main.zig" {
    const allocator = std.testing.allocator;

    const config = project.ProjectConfig{
        .name = "hello-world",
        .description = "A simple hello world app",
    };

    const main_zig = try generateMainZig(allocator, config);
    defer allocator.free(main_zig);

    try std.testing.expect(std.mem.indexOf(u8, main_zig, "//! hello-world") != null);
    try std.testing.expect(std.mem.indexOf(u8, main_zig, "pub fn main()") != null);
}

test "generate gitignore" {
    const allocator = std.testing.allocator;

    const gitignore = try generateGitignore(allocator);

    try std.testing.expect(std.mem.indexOf(u8, gitignore, "zig-cache/") != null);
    try std.testing.expect(std.mem.indexOf(u8, gitignore, ".zylix/") != null);
}
