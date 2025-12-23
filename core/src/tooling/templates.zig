//! Template Catalog API
//!
//! Manage project templates with support for:
//! - List available project templates
//! - Template metadata and requirements
//! - Custom template registration
//! - Template versioning
//!
//! This module provides template management for project scaffolding.

const std = @import("std");
const project = @import("project.zig");

/// Template error types
pub const TemplateError = error{
    NotFound,
    InvalidTemplate,
    AlreadyExists,
    ValidationFailed,
    IncompatibleVersion,
    OutOfMemory,
};

/// Template category
pub const TemplateCategory = enum(u8) {
    app = 0,
    library = 1,
    component = 2,
    plugin = 3,
    starter = 4,
    example = 5,

    pub fn toString(self: TemplateCategory) []const u8 {
        return switch (self) {
            .app => "Application",
            .library => "Library",
            .component => "Component",
            .plugin => "Plugin",
            .starter => "Starter",
            .example => "Example",
        };
    }
};

/// Template source
pub const TemplateSource = enum(u8) {
    builtin = 0, // Built-in templates
    local = 1, // Local file system
    git = 2, // Git repository
    registry = 3, // Template registry

    pub fn toString(self: TemplateSource) []const u8 {
        return switch (self) {
            .builtin => "Built-in",
            .local => "Local",
            .git => "Git",
            .registry => "Registry",
        };
    }
};

/// Template metadata
pub const Template = struct {
    /// Unique template identifier
    id: []const u8,
    /// Display name
    name: []const u8,
    /// Description
    description: []const u8,
    /// Category
    category: TemplateCategory,
    /// Source
    source: TemplateSource,
    /// Version
    version: []const u8,
    /// Author
    author: ?[]const u8 = null,
    /// Supported targets
    targets: []const project.Target = &.{},
    /// Tags for searching
    tags: []const []const u8 = &.{},
    /// Preview image URL
    preview_url: ?[]const u8 = null,
    /// Repository URL
    repo_url: ?[]const u8 = null,
};

/// Template details (extended information)
pub const TemplateDetails = struct {
    template: Template,
    /// Full documentation
    readme: ?[]const u8 = null,
    /// Required dependencies
    dependencies: []const Dependency = &.{},
    /// Configuration options
    options: []const TemplateOption = &.{},
    /// File structure preview
    file_structure: []const []const u8 = &.{},
    /// Download count (for registry templates)
    downloads: u64 = 0,
    /// Rating (0-5)
    rating: f32 = 0,
    /// Last updated timestamp
    updated_at: i64 = 0,
};

/// Template dependency
pub const Dependency = struct {
    name: []const u8,
    version: []const u8,
    optional: bool = false,
};

/// Template configuration option
pub const TemplateOption = struct {
    name: []const u8,
    label: []const u8,
    description: ?[]const u8 = null,
    option_type: OptionType,
    default_value: ?[]const u8 = null,
    required: bool = false,
};

/// Option type
pub const OptionType = enum(u8) {
    string = 0,
    boolean = 1,
    number = 2,
    select = 3,
};

/// Custom template for registration
pub const CustomTemplate = struct {
    /// Template metadata
    metadata: Template,
    /// Source path or URL
    source_path: []const u8,
    /// Template files
    files: []const TemplateFile = &.{},
};

/// Template file
pub const TemplateFile = struct {
    /// Relative path
    path: []const u8,
    /// File content (with template variables)
    content: []const u8,
    /// Is executable
    executable: bool = false,
};

/// Future result wrapper
pub fn Future(comptime T: type) type {
    return struct {
        const Self = @This();

        result: ?T = null,
        err: ?TemplateError = null,
        completed: bool = false,

        pub fn init() Self {
            return .{};
        }

        pub fn complete(self: *Self, value: T) void {
            self.result = value;
            self.completed = true;
        }

        pub fn fail(self: *Self, err: TemplateError) void {
            self.err = err;
            self.completed = true;
        }

        pub fn isCompleted(self: *const Self) bool {
            return self.completed;
        }

        pub fn get(self: *const Self) TemplateError!T {
            if (self.err) |e| return e;
            if (self.result) |r| return r;
            return TemplateError.NotFound;
        }
    };
}

/// Template Manager
pub const Templates = struct {
    allocator: std.mem.Allocator,
    custom_templates: std.StringHashMapUnmanaged(CustomTemplate) = .{},

    pub fn init(allocator: std.mem.Allocator) Templates {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Templates) void {
        self.custom_templates.deinit(self.allocator);
    }

    /// List all available templates
    pub fn list(self: *const Templates) []const Template {
        _ = self;
        return &builtin_templates;
    }

    /// List templates by category
    pub fn listByCategory(self: *const Templates, category: TemplateCategory) []const Template {
        _ = self;
        var count: usize = 0;
        for (builtin_templates) |t| {
            if (t.category == category) count += 1;
        }
        // Return static filtered list (simplified)
        return &builtin_templates;
    }

    /// Get template details
    pub fn getDetails(self: *const Templates, template_id: []const u8) ?TemplateDetails {
        // Check custom templates first
        if (self.custom_templates.get(template_id)) |custom| {
            return .{
                .template = custom.metadata,
            };
        }

        // Check built-in templates
        for (builtin_templates) |t| {
            if (std.mem.eql(u8, t.id, template_id)) {
                return getBuiltinDetails(template_id);
            }
        }

        return null;
    }

    /// Register a custom template
    pub fn register(self: *Templates, template: CustomTemplate) *Future(void) {
        const future = self.allocator.create(Future(void)) catch {
            const err_future = self.allocator.create(Future(void)) catch unreachable;
            err_future.* = Future(void).init();
            err_future.fail(TemplateError.OutOfMemory);
            return err_future;
        };
        future.* = Future(void).init();

        // Check if already exists
        if (self.custom_templates.contains(template.metadata.id)) {
            future.fail(TemplateError.AlreadyExists);
            return future;
        }

        // Validate template
        if (template.metadata.id.len == 0 or template.metadata.name.len == 0) {
            future.fail(TemplateError.InvalidTemplate);
            return future;
        }

        self.custom_templates.put(self.allocator, template.metadata.id, template) catch {
            future.fail(TemplateError.OutOfMemory);
            return future;
        };

        future.complete({});
        return future;
    }

    /// Unregister a custom template
    pub fn unregister(self: *Templates, template_id: []const u8) bool {
        return self.custom_templates.remove(template_id);
    }

    /// Search templates by query
    pub fn search(self: *const Templates, query: []const u8) []const Template {
        _ = self;
        _ = query;
        // In real implementation, would search by name, description, tags
        return &builtin_templates;
    }

    /// Get custom template count
    pub fn customCount(self: *const Templates) usize {
        return self.custom_templates.count();
    }

    /// Validate template ID exists
    pub fn exists(self: *const Templates, template_id: []const u8) bool {
        if (self.custom_templates.contains(template_id)) return true;

        for (builtin_templates) |t| {
            if (std.mem.eql(u8, t.id, template_id)) return true;
        }

        return false;
    }
};

// Built-in templates
const builtin_templates = [_]Template{
    .{
        .id = "app",
        .name = "Basic App",
        .description = "A minimal cross-platform application template",
        .category = .app,
        .source = .builtin,
        .version = "1.0.0",
        .author = "Zylix Team",
        .targets = &.{ .ios, .android, .web, .macos, .windows, .linux },
        .tags = &.{ "starter", "minimal", "cross-platform" },
    },
    .{
        .id = "app-navigation",
        .name = "App with Navigation",
        .description = "Application template with built-in navigation stack",
        .category = .app,
        .source = .builtin,
        .version = "1.0.0",
        .author = "Zylix Team",
        .targets = &.{ .ios, .android, .web, .macos, .windows, .linux },
        .tags = &.{ "navigation", "tabs", "routing" },
    },
    .{
        .id = "game-2d",
        .name = "2D Game",
        .description = "2D game template with sprite rendering and physics",
        .category = .starter,
        .source = .builtin,
        .version = "1.0.0",
        .author = "Zylix Team",
        .targets = &.{ .ios, .android, .web, .macos, .windows, .linux },
        .tags = &.{ "game", "2d", "sprites", "physics" },
    },
    .{
        .id = "game-3d",
        .name = "3D Game",
        .description = "3D game template with scene graph and rendering",
        .category = .starter,
        .source = .builtin,
        .version = "1.0.0",
        .author = "Zylix Team",
        .targets = &.{ .ios, .android, .macos, .windows, .linux },
        .tags = &.{ "game", "3d", "scene-graph" },
    },
    .{
        .id = "library",
        .name = "Zylix Library",
        .description = "Reusable library template with testing setup",
        .category = .library,
        .source = .builtin,
        .version = "1.0.0",
        .author = "Zylix Team",
        .targets = &.{ .ios, .android, .web, .macos, .windows, .linux },
        .tags = &.{ "library", "package", "reusable" },
    },
    .{
        .id = "component",
        .name = "UI Component",
        .description = "UI component package template",
        .category = .component,
        .source = .builtin,
        .version = "1.0.0",
        .author = "Zylix Team",
        .targets = &.{ .ios, .android, .web, .macos, .windows, .linux },
        .tags = &.{ "ui", "component", "widget" },
    },
    .{
        .id = "plugin-ios",
        .name = "iOS Plugin",
        .description = "Native iOS plugin template",
        .category = .plugin,
        .source = .builtin,
        .version = "1.0.0",
        .author = "Zylix Team",
        .targets = &.{.ios},
        .tags = &.{ "plugin", "native", "ios" },
    },
    .{
        .id = "plugin-android",
        .name = "Android Plugin",
        .description = "Native Android plugin template",
        .category = .plugin,
        .source = .builtin,
        .version = "1.0.0",
        .author = "Zylix Team",
        .targets = &.{.android},
        .tags = &.{ "plugin", "native", "android" },
    },
};

// Get built-in template details
fn getBuiltinDetails(template_id: []const u8) TemplateDetails {
    for (builtin_templates) |t| {
        if (std.mem.eql(u8, t.id, template_id)) {
            return .{
                .template = t,
                .file_structure = getFileStructure(template_id),
                .options = getTemplateOptions(template_id),
            };
        }
    }
    return .{ .template = builtin_templates[0] };
}

fn getFileStructure(template_id: []const u8) []const []const u8 {
    if (std.mem.eql(u8, template_id, "app")) {
        return &app_file_structure;
    }
    return &.{};
}

const app_file_structure = [_][]const u8{
    "src/",
    "src/main.zig",
    "src/app.zig",
    "assets/",
    "tests/",
    "build.zig",
    "build.zig.zon",
};

fn getTemplateOptions(template_id: []const u8) []const TemplateOption {
    _ = template_id;
    return &default_options;
}

const default_options = [_]TemplateOption{
    .{ .name = "name", .label = "Project Name", .option_type = .string, .required = true },
    .{ .name = "description", .label = "Description", .option_type = .string },
    .{ .name = "author", .label = "Author", .option_type = .string },
    .{ .name = "license", .label = "License", .option_type = .select, .default_value = "MIT" },
};

/// Create a template manager
pub fn createTemplateManager(allocator: std.mem.Allocator) Templates {
    return Templates.init(allocator);
}

// Tests
test "Templates initialization" {
    const allocator = std.testing.allocator;
    var templates = createTemplateManager(allocator);
    defer templates.deinit();

    const list = templates.list();
    try std.testing.expect(list.len > 0);
}

test "Template categories" {
    try std.testing.expect(std.mem.eql(u8, "Application", TemplateCategory.app.toString()));
    try std.testing.expect(std.mem.eql(u8, "Library", TemplateCategory.library.toString()));
}

test "Template details" {
    const allocator = std.testing.allocator;
    var templates = createTemplateManager(allocator);
    defer templates.deinit();

    const details = templates.getDetails("app");
    try std.testing.expect(details != null);
    try std.testing.expect(std.mem.eql(u8, "app", details.?.template.id));

    try std.testing.expect(templates.getDetails("nonexistent") == null);
}

test "Template exists" {
    const allocator = std.testing.allocator;
    var templates = createTemplateManager(allocator);
    defer templates.deinit();

    try std.testing.expect(templates.exists("app"));
    try std.testing.expect(templates.exists("library"));
    try std.testing.expect(!templates.exists("nonexistent"));
}

test "Custom template registration" {
    const allocator = std.testing.allocator;
    var templates = createTemplateManager(allocator);
    defer templates.deinit();

    const custom = CustomTemplate{
        .metadata = .{
            .id = "my-template",
            .name = "My Custom Template",
            .description = "A custom template",
            .category = .app,
            .source = .local,
            .version = "1.0.0",
        },
        .source_path = "/path/to/template",
    };

    const future = templates.register(custom);
    defer allocator.destroy(future);
    try std.testing.expect(future.isCompleted());
    _ = try future.get();

    try std.testing.expectEqual(@as(usize, 1), templates.customCount());
    try std.testing.expect(templates.exists("my-template"));

    // Duplicate registration should fail
    const future2 = templates.register(custom);
    defer allocator.destroy(future2);
    try std.testing.expect(future2.isCompleted());
    try std.testing.expectError(TemplateError.AlreadyExists, future2.get());
}

test "Custom template unregister" {
    const allocator = std.testing.allocator;
    var templates = createTemplateManager(allocator);
    defer templates.deinit();

    const custom = CustomTemplate{
        .metadata = .{
            .id = "temp-template",
            .name = "Temporary",
            .description = "Will be removed",
            .category = .app,
            .source = .local,
            .version = "1.0.0",
        },
        .source_path = "/tmp",
    };

    const reg_future = templates.register(custom);
    defer allocator.destroy(reg_future);
    try std.testing.expect(templates.exists("temp-template"));

    try std.testing.expect(templates.unregister("temp-template"));
    try std.testing.expect(!templates.exists("temp-template"));
    try std.testing.expect(!templates.unregister("temp-template")); // Already removed
}

test "Invalid template registration" {
    const allocator = std.testing.allocator;
    var templates = createTemplateManager(allocator);
    defer templates.deinit();

    const invalid = CustomTemplate{
        .metadata = .{
            .id = "",
            .name = "",
            .description = "",
            .category = .app,
            .source = .local,
            .version = "",
        },
        .source_path = "",
    };

    const future = templates.register(invalid);
    defer allocator.destroy(future);
    try std.testing.expect(future.isCompleted());
    try std.testing.expectError(TemplateError.InvalidTemplate, future.get());
}
