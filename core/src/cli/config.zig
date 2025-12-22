//! Configuration management for Zylix Test CLI
//!
//! Handles loading and parsing of zylix-test.json configuration files.

const std = @import("std");
const output = @import("output.zig");

/// Platform types for testing
pub const Platform = enum {
    web,
    ios,
    android,
    macos,
    windows,
    linux,
    auto,

    pub fn fromString(str: []const u8) ?Platform {
        if (std.mem.eql(u8, str, "web")) return .web;
        if (std.mem.eql(u8, str, "ios")) return .ios;
        if (std.mem.eql(u8, str, "android")) return .android;
        if (std.mem.eql(u8, str, "macos")) return .macos;
        if (std.mem.eql(u8, str, "windows")) return .windows;
        if (std.mem.eql(u8, str, "linux")) return .linux;
        if (std.mem.eql(u8, str, "auto")) return .auto;
        return null;
    }

    pub fn toString(self: Platform) []const u8 {
        return switch (self) {
            .web => "web",
            .ios => "ios",
            .android => "android",
            .macos => "macos",
            .windows => "windows",
            .linux => "linux",
            .auto => "auto",
        };
    }

    pub fn defaultPort(self: Platform) u16 {
        return switch (self) {
            .web => 9515,
            .ios => 8100,
            .android => 4724,
            .macos => 8200,
            .windows => 4723,
            .linux => 8300,
            .auto => 0,
        };
    }
};

/// Browser types for web testing
pub const Browser = enum {
    chrome,
    firefox,
    safari,
    edge,

    pub fn fromString(str: []const u8) ?Browser {
        if (std.mem.eql(u8, str, "chrome") or std.mem.eql(u8, str, "chromium")) return .chrome;
        if (std.mem.eql(u8, str, "firefox")) return .firefox;
        if (std.mem.eql(u8, str, "safari") or std.mem.eql(u8, str, "webkit")) return .safari;
        if (std.mem.eql(u8, str, "edge")) return .edge;
        return null;
    }
};

/// Report format options
pub const ReportFormat = enum {
    console,
    junit,
    json,
    html,
    markdown,
    all,

    pub fn fromString(str: []const u8) ?ReportFormat {
        if (std.mem.eql(u8, str, "console")) return .console;
        if (std.mem.eql(u8, str, "junit")) return .junit;
        if (std.mem.eql(u8, str, "json")) return .json;
        if (std.mem.eql(u8, str, "html")) return .html;
        if (std.mem.eql(u8, str, "markdown") or std.mem.eql(u8, str, "md")) return .markdown;
        if (std.mem.eql(u8, str, "all")) return .all;
        return null;
    }
};

/// Test run configuration
pub const RunConfig = struct {
    /// Target platform
    platform: Platform = .auto,

    /// Browser for web tests
    browser: Browser = .chrome,

    /// Run browser in headless mode
    headless: bool = true,

    /// Number of parallel workers (0 = auto)
    parallel: u32 = 0,

    /// Test timeout in milliseconds
    timeout_ms: u32 = 30000,

    /// Number of retries for failed tests
    retry_count: u32 = 0,

    /// Report format
    reporter: ReportFormat = .console,

    /// Output directory for reports
    output_dir: ?[]const u8 = null,

    /// Test filter pattern
    filter: ?[]const u8 = null,

    /// Test tag filter
    tag: ?[]const u8 = null,

    /// Shard configuration (index/total)
    shard_index: ?u32 = null,
    shard_total: ?u32 = null,

    /// Enable debug output
    debug: bool = false,

    /// Dry run (don't execute tests)
    dry_run: bool = false,

    /// Config file path
    config_file: ?[]const u8 = null,
};

/// Server configuration
pub const ServerConfig = struct {
    platform: Platform,
    port: u16,
    host: []const u8 = "127.0.0.1",
    daemon: bool = false,
};

/// Project configuration (from zylix-test.json)
pub const ProjectConfig = struct {
    /// Project name
    name: []const u8 = "zylix-tests",

    /// Project version
    version: []const u8 = "0.1.0",

    /// Target platforms
    platforms: []const Platform = &[_]Platform{.web},

    /// Test source directory
    test_dir: []const u8 = "tests",

    /// Output directory
    output_dir: []const u8 = "test-results",

    /// Default timeout
    timeout_ms: u32 = 30000,

    /// Default retry count
    retry_count: u32 = 0,

    /// Default report format
    reporter: ReportFormat = .console,

    /// Web-specific config
    web: WebConfig = .{},

    /// iOS-specific config
    ios: IOSConfig = .{},

    /// Android-specific config
    android: AndroidConfig = .{},
};

pub const WebConfig = struct {
    browser: Browser = .chrome,
    headless: bool = true,
    viewport_width: u32 = 1280,
    viewport_height: u32 = 720,
    base_url: ?[]const u8 = null,
};

pub const IOSConfig = struct {
    bundle_id: ?[]const u8 = null,
    device_name: ?[]const u8 = null,
    platform_version: ?[]const u8 = null,
};

pub const AndroidConfig = struct {
    package_name: ?[]const u8 = null,
    activity_name: ?[]const u8 = null,
    device_name: ?[]const u8 = null,
};

/// Load configuration from file
pub fn loadConfig(allocator: std.mem.Allocator, path: []const u8) !ProjectConfig {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        if (err == error.FileNotFound) {
            return ProjectConfig{};
        }
        return err;
    };
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);

    return parseConfig(allocator, content);
}

/// Parse configuration from JSON string
pub fn parseConfig(allocator: std.mem.Allocator, json_content: []const u8) !ProjectConfig {
    _ = allocator;

    // Simple JSON parsing - in production would use a proper JSON parser
    var config = ProjectConfig{};

    // Parse name
    if (findJsonString(json_content, "name")) |name| {
        config.name = name;
    }

    // Parse version
    if (findJsonString(json_content, "version")) |version| {
        config.version = version;
    }

    // Parse test_dir
    if (findJsonString(json_content, "testDir")) |dir| {
        config.test_dir = dir;
    }

    // Parse timeout
    if (findJsonNumber(json_content, "timeout")) |timeout| {
        config.timeout_ms = @intCast(timeout);
    }

    return config;
}

/// Find a string value in JSON (simple implementation)
fn findJsonString(json: []const u8, key: []const u8) ?[]const u8 {
    // Look for "key": "value"
    var search_pattern: [256]u8 = undefined;
    const pattern = std.fmt.bufPrint(&search_pattern, "\"{s}\":", .{key}) catch return null;

    if (std.mem.indexOf(u8, json, pattern)) |key_pos| {
        const value_start = key_pos + pattern.len;
        // Skip whitespace and find opening quote
        var i = value_start;
        while (i < json.len and (json[i] == ' ' or json[i] == '\t' or json[i] == '\n')) : (i += 1) {}

        if (i < json.len and json[i] == '"') {
            const str_start = i + 1;
            // Find closing quote
            if (std.mem.indexOfScalar(u8, json[str_start..], '"')) |end_offset| {
                return json[str_start .. str_start + end_offset];
            }
        }
    }
    return null;
}

/// Find a number value in JSON (simple implementation)
fn findJsonNumber(json: []const u8, key: []const u8) ?i64 {
    var search_pattern: [256]u8 = undefined;
    const pattern = std.fmt.bufPrint(&search_pattern, "\"{s}\":", .{key}) catch return null;

    if (std.mem.indexOf(u8, json, pattern)) |key_pos| {
        const value_start = key_pos + pattern.len;
        // Skip whitespace
        var i = value_start;
        while (i < json.len and (json[i] == ' ' or json[i] == '\t' or json[i] == '\n')) : (i += 1) {}

        // Parse number
        var end = i;
        while (end < json.len and (json[end] >= '0' and json[end] <= '9')) : (end += 1) {}

        if (end > i) {
            return std.fmt.parseInt(i64, json[i..end], 10) catch null;
        }
    }
    return null;
}

/// Generate default configuration file content
pub fn generateDefaultConfig(project_name: []const u8) []const u8 {
    _ = project_name;
    return
        \\{
        \\  "name": "my-tests",
        \\  "version": "0.1.0",
        \\  "testDir": "tests",
        \\  "outputDir": "test-results",
        \\  "timeout": 30000,
        \\  "retries": 0,
        \\  "reporter": "console",
        \\  "platforms": ["web"],
        \\  "web": {
        \\    "browser": "chrome",
        \\    "headless": true,
        \\    "viewport": {
        \\      "width": 1280,
        \\      "height": 720
        \\    }
        \\  }
        \\}
        \\
    ;
}

/// Find configuration file in current directory or parents
pub fn findConfigFile(allocator: std.mem.Allocator) ?[]const u8 {
    const config_names = [_][]const u8{
        "zylix-test.json",
        "zylix-test.config.json",
        ".zylixrc.json",
    };

    // Start from current directory
    var dir = std.fs.cwd();

    // Try each config name
    for (config_names) |name| {
        if (dir.access(name, .{})) |_| {
            return allocator.dupe(u8, name) catch null;
        } else |_| {}
    }

    return null;
}

test "config parsing" {
    const json =
        \\{
        \\  "name": "my-tests",
        \\  "version": "1.0.0",
        \\  "timeout": 5000
        \\}
    ;

    const config = try parseConfig(std.testing.allocator, json);
    try std.testing.expectEqualStrings("my-tests", config.name);
    try std.testing.expectEqualStrings("1.0.0", config.version);
    try std.testing.expect(config.timeout_ms == 5000);
}

test "platform from string" {
    try std.testing.expect(Platform.fromString("web") == .web);
    try std.testing.expect(Platform.fromString("ios") == .ios);
    try std.testing.expect(Platform.fromString("invalid") == null);
}
