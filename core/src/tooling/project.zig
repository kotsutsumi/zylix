//! Project Scaffolding API
//!
//! Create and manage Zylix project layouts with support for:
//! - All 7 target platforms (iOS, Android, Web, macOS, Windows, Linux, Embedded)
//! - Template-based project initialization
//! - Configuration generation
//! - Dependency resolution
//!
//! This module provides the foundation for the `zylix new` CLI command.

const std = @import("std");
const project_io = @import("project_io.zig");

/// Project error types
pub const ProjectError = error{
    InvalidTemplate,
    InvalidTarget,
    DirectoryExists,
    DirectoryNotFound,
    PermissionDenied,
    ConfigurationError,
    DependencyError,
    ValidationFailed,
    OutOfMemory,
};

/// Target platform
pub const Target = enum(u8) {
    ios = 0,
    android = 1,
    web = 2,
    macos = 3,
    windows = 4,
    linux = 5,
    embedded = 6,

    pub fn toString(self: Target) []const u8 {
        return switch (self) {
            .ios => "ios",
            .android => "android",
            .web => "web",
            .macos => "macos",
            .windows => "windows",
            .linux => "linux",
            .embedded => "embedded",
        };
    }

    pub fn fromString(s: []const u8) ?Target {
        const targets = [_]struct { name: []const u8, target: Target }{
            .{ .name = "ios", .target = .ios },
            .{ .name = "android", .target = .android },
            .{ .name = "web", .target = .web },
            .{ .name = "macos", .target = .macos },
            .{ .name = "windows", .target = .windows },
            .{ .name = "linux", .target = .linux },
            .{ .name = "embedded", .target = .embedded },
        };
        for (targets) |t| {
            if (std.mem.eql(u8, s, t.name)) return t.target;
        }
        return null;
    }

    pub fn isMobile(self: Target) bool {
        return self == .ios or self == .android;
    }

    pub fn isDesktop(self: Target) bool {
        return self == .macos or self == .windows or self == .linux;
    }
};

/// Project type
pub const ProjectType = enum(u8) {
    app = 0, // Full application
    library = 1, // Reusable library
    component = 2, // UI component package
    plugin = 3, // Platform plugin
};

/// Project identifier
pub const ProjectId = struct {
    id: u64,
    name: []const u8,
    path: []const u8,

    pub fn isValid(self: *const ProjectId) bool {
        return self.id > 0 and self.name.len > 0;
    }
};

/// Project configuration
pub const ProjectConfig = struct {
    /// Project name
    name: []const u8,
    /// Project description
    description: []const u8 = "",
    /// Project version
    version: []const u8 = "0.1.0",
    /// Project type
    project_type: ProjectType = .app,
    /// Target platforms
    targets: []const Target = &.{},
    /// Template ID to use
    template_id: ?[]const u8 = null,
    /// Author name
    author: ?[]const u8 = null,
    /// License identifier
    license: ?[]const u8 = null,
    /// Organization/bundle identifier prefix
    org_id: ?[]const u8 = null,
    /// Enable git initialization
    init_git: bool = true,
    /// Install dependencies after creation
    install_deps: bool = true,
};

/// Project information
pub const ProjectInfo = struct {
    id: ProjectId,
    config: ProjectConfig,
    created_at: i64,
    modified_at: i64,
    /// List of source directories
    source_dirs: []const []const u8 = &.{},
    /// List of asset directories
    asset_dirs: []const []const u8 = &.{},
    /// Dependencies
    dependencies: []const Dependency = &.{},
};

/// Dependency specification
pub const Dependency = struct {
    name: []const u8,
    version: []const u8,
    source: DependencySource = .registry,
    optional: bool = false,
};

/// Dependency source
pub const DependencySource = enum(u8) {
    registry = 0, // Package registry
    git = 1, // Git repository
    path = 2, // Local path
    url = 3, // Direct URL
};

/// Validation result
pub const ValidationResult = struct {
    valid: bool,
    errors: []const ValidationError = &.{},
    warnings: []const ValidationWarning = &.{},

    pub fn isValid(self: *const ValidationResult) bool {
        return self.valid and self.errors.len == 0;
    }
};

/// Validation error
pub const ValidationError = struct {
    code: []const u8,
    message: []const u8,
    file: ?[]const u8 = null,
    line: ?u32 = null,
};

/// Validation warning
pub const ValidationWarning = struct {
    code: []const u8,
    message: []const u8,
    file: ?[]const u8 = null,
};

/// Future result wrapper for async operations
pub fn Future(comptime T: type) type {
    return struct {
        const Self = @This();

        result: ?T = null,
        err: ?ProjectError = null,
        completed: bool = false,
        callback: ?*const fn (?T, ?ProjectError) void = null,

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

        pub fn fail(self: *Self, err: ProjectError) void {
            self.err = err;
            self.completed = true;
            if (self.callback) |cb| {
                cb(null, err);
            }
        }

        pub fn isCompleted(self: *const Self) bool {
            return self.completed;
        }

        pub fn get(self: *const Self) ProjectError!T {
            if (self.err) |e| return e;
            if (self.result) |r| return r;
            return ProjectError.ConfigurationError;
        }

        pub fn onComplete(self: *Self, callback: *const fn (?T, ?ProjectError) void) void {
            self.callback = callback;
            if (self.completed) {
                callback(self.result, self.err);
            }
        }
    };
}

/// Project Manager
pub const Project = struct {
    allocator: std.mem.Allocator,
    projects: std.StringHashMapUnmanaged(ProjectInfo) = .{},
    next_id: u64 = 1,

    pub fn init(allocator: std.mem.Allocator) Project {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Project) void {
        self.projects.deinit(self.allocator);
    }

    /// Create a new project from template
    pub fn create(
        self: *Project,
        template_id: []const u8,
        targets: []const Target,
        output_dir: []const u8,
        config: ProjectConfig,
    ) *Future(ProjectId) {
        const future = self.allocator.create(Future(ProjectId)) catch {
            const err_future = self.allocator.create(Future(ProjectId)) catch unreachable;
            err_future.* = Future(ProjectId).init();
            err_future.fail(ProjectError.OutOfMemory);
            return err_future;
        };
        future.* = Future(ProjectId).init();

        // Validate template
        if (template_id.len == 0) {
            future.fail(ProjectError.InvalidTemplate);
            return future;
        }

        // Validate targets
        if (targets.len == 0) {
            future.fail(ProjectError.InvalidTarget);
            return future;
        }

        // Create project ID
        const project_id = ProjectId{
            .id = self.next_id,
            .name = config.name,
            .path = output_dir,
        };
        self.next_id += 1;

        // Store project info
        const info = ProjectInfo{
            .id = project_id,
            .config = config,
            .created_at = std.time.timestamp(),
            .modified_at = std.time.timestamp(),
        };

        self.projects.put(self.allocator, config.name, info) catch {
            future.fail(ProjectError.OutOfMemory);
            return future;
        };

        // Create actual project structure on disk
        const full_config = ProjectConfig{
            .name = config.name,
            .description = config.description,
            .version = config.version,
            .project_type = config.project_type,
            .targets = targets,
            .template_id = if (config.template_id) |tid| tid else template_id,
            .author = config.author,
            .license = config.license,
            .org_id = config.org_id,
            .init_git = config.init_git,
            .install_deps = config.install_deps,
        };

        const io_result = project_io.scaffoldProject(self.allocator, output_dir, full_config);
        switch (io_result) {
            .ok => future.complete(project_id),
            .err => |err| {
                // Clean up the project from registry on I/O failure
                _ = self.projects.remove(config.name);
                switch (err) {
                    project_io.IoError.DirectoryExists => future.fail(ProjectError.DirectoryExists),
                    project_io.IoError.PermissionDenied => future.fail(ProjectError.PermissionDenied),
                    project_io.IoError.OutOfMemory => future.fail(ProjectError.OutOfMemory),
                    else => future.fail(ProjectError.ConfigurationError),
                }
            },
        }
        return future;
    }

    /// Validate an existing project
    pub fn validate(self: *Project, project_id: ProjectId) *Future(ValidationResult) {
        const future = self.allocator.create(Future(ValidationResult)) catch {
            const err_future = self.allocator.create(Future(ValidationResult)) catch unreachable;
            err_future.* = Future(ValidationResult).init();
            err_future.fail(ProjectError.OutOfMemory);
            return err_future;
        };
        future.* = Future(ValidationResult).init();

        // Check if project exists
        if (!project_id.isValid()) {
            future.complete(.{
                .valid = false,
                .errors = &.{.{
                    .code = "E001",
                    .message = "Invalid project ID",
                }},
            });
            return future;
        }

        // In real implementation, would validate project structure
        future.complete(.{
            .valid = true,
        });
        return future;
    }

    /// Get project information
    pub fn getInfo(self: *const Project, name: []const u8) ?ProjectInfo {
        return self.projects.get(name);
    }

    /// List all projects
    pub fn listProjects(self: *const Project) []const []const u8 {
        var names = std.ArrayList([]const u8).init(self.allocator);
        var iter = self.projects.iterator();
        while (iter.next()) |entry| {
            names.append(entry.key_ptr.*) catch continue;
        }
        return names.toOwnedSlice() catch &.{};
    }

    /// Delete a project
    pub fn delete(self: *Project, name: []const u8) bool {
        return self.projects.remove(name);
    }

    /// Get project count
    pub fn count(self: *const Project) usize {
        return self.projects.count();
    }
};

/// Generate project directory structure
pub fn generateProjectStructure(
    allocator: std.mem.Allocator,
    config: ProjectConfig,
) ![]const []const u8 {
    var dirs: std.ArrayListUnmanaged([]const u8) = .{};

    // Common directories
    try dirs.append(allocator, "src");
    try dirs.append(allocator, "assets");
    try dirs.append(allocator, "tests");

    // Platform-specific directories
    for (config.targets) |target| {
        const platform_dir = switch (target) {
            .ios => "platforms/ios",
            .android => "platforms/android",
            .web => "platforms/web",
            .macos => "platforms/macos",
            .windows => "platforms/windows",
            .linux => "platforms/linux",
            .embedded => "platforms/embedded",
        };
        try dirs.append(allocator, platform_dir);
    }

    return try dirs.toOwnedSlice(allocator);
}

/// Create a project manager
pub fn createProjectManager(allocator: std.mem.Allocator) Project {
    return Project.init(allocator);
}

// Tests
test "Project initialization" {
    const allocator = std.testing.allocator;
    var project = createProjectManager(allocator);
    defer project.deinit();

    try std.testing.expectEqual(@as(usize, 0), project.count());
}

test "Target conversion" {
    try std.testing.expect(std.mem.eql(u8, "ios", Target.ios.toString()));
    try std.testing.expect(std.mem.eql(u8, "android", Target.android.toString()));
    try std.testing.expect(std.mem.eql(u8, "web", Target.web.toString()));

    try std.testing.expectEqual(Target.ios, Target.fromString("ios").?);
    try std.testing.expectEqual(Target.android, Target.fromString("android").?);
    try std.testing.expect(Target.fromString("invalid") == null);
}

test "Target categories" {
    try std.testing.expect(Target.ios.isMobile());
    try std.testing.expect(Target.android.isMobile());
    try std.testing.expect(!Target.web.isMobile());

    try std.testing.expect(Target.macos.isDesktop());
    try std.testing.expect(Target.windows.isDesktop());
    try std.testing.expect(Target.linux.isDesktop());
    try std.testing.expect(!Target.ios.isDesktop());
}

test "Project creation" {
    const allocator = std.testing.allocator;
    var project = createProjectManager(allocator);
    defer project.deinit();

    const targets = [_]Target{ .ios, .android, .web };
    const future = project.create("app", &targets, "/tmp/myapp", .{
        .name = "myapp",
        .description = "My test app",
    });
    defer allocator.destroy(future);

    try std.testing.expect(future.isCompleted());
    const project_id = try future.get();
    try std.testing.expect(project_id.isValid());
    try std.testing.expectEqual(@as(usize, 1), project.count());
}

test "Project validation" {
    const allocator = std.testing.allocator;
    var project = createProjectManager(allocator);
    defer project.deinit();

    // Valid project
    const valid_id = ProjectId{ .id = 1, .name = "test", .path = "/tmp" };
    const valid_future = project.validate(valid_id);
    defer allocator.destroy(valid_future);
    try std.testing.expect(valid_future.isCompleted());
    const valid_result = try valid_future.get();
    try std.testing.expect(valid_result.isValid());

    // Invalid project
    const invalid_id = ProjectId{ .id = 0, .name = "", .path = "" };
    const invalid_future = project.validate(invalid_id);
    defer allocator.destroy(invalid_future);
    try std.testing.expect(invalid_future.isCompleted());
    const invalid_result = try invalid_future.get();
    try std.testing.expect(!invalid_result.isValid());
}

test "Project structure generation" {
    const allocator = std.testing.allocator;
    const targets = [_]Target{ .ios, .web };
    const dirs = try generateProjectStructure(allocator, .{
        .name = "test",
        .targets = &targets,
    });
    defer allocator.free(dirs);

    try std.testing.expect(dirs.len >= 5); // src, assets, tests, platforms/ios, platforms/web
}

test "ValidationResult" {
    const valid = ValidationResult{ .valid = true };
    try std.testing.expect(valid.isValid());

    const invalid = ValidationResult{
        .valid = false,
        .errors = &.{.{ .code = "E001", .message = "Error" }},
    };
    try std.testing.expect(!invalid.isValid());
}
