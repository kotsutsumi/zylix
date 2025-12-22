//! Zylix Test CLI
//!
//! Command-line interface for running E2E tests across all platforms.
//!
//! Usage:
//!   zylix-test <command> [options]
//!
//! Commands:
//!   run       Run tests
//!   init      Initialize a new test project
//!   server    Start/stop bridge servers
//!   list      List available tests
//!   report    Generate test reports
//!   version   Show version information

const std = @import("std");
const builtin = @import("builtin");

// CLI modules
pub const commands = @import("commands.zig");
pub const config = @import("config.zig");
pub const output = @import("output.zig");

pub const version = struct {
    pub const major = 0;
    pub const minor = 9;
    pub const patch = 0;
    pub const string = "0.9.0";
};

pub const ExitCode = enum(u8) {
    success = 0,
    test_failure = 1,
    invalid_args = 2,
    config_error = 3,
    runtime_error = 4,
    _,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const exit_code = run(allocator) catch |err| blk: {
        output.printError("Fatal error: {s}", .{@errorName(err)});
        break :blk ExitCode.runtime_error;
    };

    std.process.exit(@intFromEnum(exit_code));
}

fn run(allocator: std.mem.Allocator) !ExitCode {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Skip program name
    const cli_args = if (args.len > 1) args[1..] else args[0..0];

    if (cli_args.len == 0) {
        printUsage();
        return ExitCode.success;
    }

    const command = cli_args[0];
    const command_args = if (cli_args.len > 1) cli_args[1..] else cli_args[0..0];

    // Handle global flags
    if (std.mem.eql(u8, command, "--help") or std.mem.eql(u8, command, "-h")) {
        printUsage();
        return ExitCode.success;
    }

    if (std.mem.eql(u8, command, "--version") or std.mem.eql(u8, command, "-v")) {
        printVersion();
        return ExitCode.success;
    }

    // Dispatch to command handlers
    if (std.mem.eql(u8, command, "run")) {
        return commands.runTests(allocator, command_args);
    } else if (std.mem.eql(u8, command, "init")) {
        return commands.initProject(allocator, command_args);
    } else if (std.mem.eql(u8, command, "server")) {
        return commands.serverCommand(allocator, command_args);
    } else if (std.mem.eql(u8, command, "list")) {
        return commands.listTests(allocator, command_args);
    } else if (std.mem.eql(u8, command, "report")) {
        return commands.generateReport(allocator, command_args);
    } else if (std.mem.eql(u8, command, "version")) {
        printVersion();
        return ExitCode.success;
    } else if (std.mem.eql(u8, command, "help")) {
        if (command_args.len > 0) {
            printCommandHelp(command_args[0]);
        } else {
            printUsage();
        }
        return ExitCode.success;
    } else {
        output.printError("Unknown command: {s}", .{command});
        output.print("\nRun 'zylix-test --help' for usage.\n", .{});
        return ExitCode.invalid_args;
    }
}

fn printUsage() void {
    const usage =
        \\Zylix Test Framework v{s}
        \\
        \\Usage: zylix-test <command> [options]
        \\
        \\Commands:
        \\  run       Run E2E tests
        \\  init      Initialize a new test project
        \\  server    Manage bridge servers
        \\  list      List available tests
        \\  report    Generate test reports
        \\  version   Show version information
        \\  help      Show help for a command
        \\
        \\Options:
        \\  -h, --help     Show this help message
        \\  -v, --version  Show version information
        \\
        \\Examples:
        \\  zylix-test run                     Run all tests
        \\  zylix-test run --platform web      Run web tests only
        \\  zylix-test init my-project         Create new test project
        \\  zylix-test server start --web      Start web bridge server
        \\
        \\For more information: https://zylix.dev/docs/testing
        \\
    ;
    output.print(usage, .{version.string});
}

fn printVersion() void {
    output.print("zylix-test {s}\n", .{version.string});
    output.print("Zig {s}\n", .{builtin.zig_version_string});

    const os_name = switch (builtin.os.tag) {
        .macos => "macOS",
        .windows => "Windows",
        .linux => "Linux",
        .ios => "iOS",
        else => @tagName(builtin.os.tag),
    };
    const arch_name = @tagName(builtin.cpu.arch);
    output.print("Platform: {s} ({s})\n", .{ os_name, arch_name });
}

fn printCommandHelp(command: []const u8) void {
    if (std.mem.eql(u8, command, "run")) {
        const help =
            \\zylix-test run - Run E2E tests
            \\
            \\Usage: zylix-test run [options] [test-pattern]
            \\
            \\Options:
            \\  --platform <platform>   Target platform (web, ios, android, macos, windows, linux)
            \\  --browser <browser>     Browser type for web tests (chrome, firefox, safari)
            \\  --headless              Run browser in headless mode
            \\  --parallel <n>          Number of parallel workers (default: CPU count)
            \\  --timeout <ms>          Test timeout in milliseconds (default: 30000)
            \\  --retry <n>             Number of retries for failed tests (default: 0)
            \\  --reporter <format>     Output format (console, junit, json, html)
            \\  --output <dir>          Output directory for reports
            \\  --config <file>         Path to config file
            \\  --filter <pattern>      Filter tests by name pattern
            \\  --tag <tag>             Run tests with specific tag
            \\  --shard <n/total>       Run shard n of total shards (CI mode)
            \\  --debug                 Enable debug output
            \\  --dry-run               Show tests without running
            \\
            \\Examples:
            \\  zylix-test run                           Run all tests
            \\  zylix-test run --platform web            Run web tests
            \\  zylix-test run --filter "login*"         Run login tests
            \\  zylix-test run --parallel 4 --retry 2    Run with 4 workers and retry
            \\
        ;
        output.print(help, .{});
    } else if (std.mem.eql(u8, command, "init")) {
        const help =
            \\zylix-test init - Initialize a new test project
            \\
            \\Usage: zylix-test init [project-name] [options]
            \\
            \\Options:
            \\  --template <name>   Project template (basic, full, mobile, web)
            \\  --platforms <list>  Target platforms (comma-separated)
            \\  --force             Overwrite existing files
            \\
            \\Examples:
            \\  zylix-test init my-tests
            \\  zylix-test init --template mobile --platforms ios,android
            \\
        ;
        output.print(help, .{});
    } else if (std.mem.eql(u8, command, "server")) {
        const help =
            \\zylix-test server - Manage bridge servers
            \\
            \\Usage: zylix-test server <action> [options]
            \\
            \\Actions:
            \\  start    Start bridge server(s)
            \\  stop     Stop bridge server(s)
            \\  status   Show server status
            \\  restart  Restart bridge server(s)
            \\
            \\Options:
            \\  --web       Web/Playwright server (port 9515)
            \\  --ios       iOS/XCUITest server (port 8100)
            \\  --android   Android/UiAutomator2 server (port 4724)
            \\  --macos     macOS/Accessibility server (port 8200)
            \\  --windows   Windows/UIAutomation server (port 4723)
            \\  --linux     Linux/AT-SPI server (port 8300)
            \\  --all       All platform servers
            \\  --port <n>  Custom port number
            \\  --daemon    Run in background
            \\
            \\Examples:
            \\  zylix-test server start --web
            \\  zylix-test server status --all
            \\  zylix-test server stop --ios --android
            \\
        ;
        output.print(help, .{});
    } else if (std.mem.eql(u8, command, "list")) {
        const help =
            \\zylix-test list - List available tests
            \\
            \\Usage: zylix-test list [options]
            \\
            \\Options:
            \\  --platform <platform>   Filter by platform
            \\  --tag <tag>             Filter by tag
            \\  --json                  Output as JSON
            \\
            \\Examples:
            \\  zylix-test list
            \\  zylix-test list --platform web --json
            \\
        ;
        output.print(help, .{});
    } else if (std.mem.eql(u8, command, "report")) {
        const help =
            \\zylix-test report - Generate test reports
            \\
            \\Usage: zylix-test report [options]
            \\
            \\Options:
            \\  --input <dir>       Input directory with test results
            \\  --output <dir>      Output directory for reports
            \\  --format <format>   Report format (html, junit, json, markdown)
            \\  --merge             Merge multiple result files
            \\  --open              Open report in browser (HTML only)
            \\
            \\Examples:
            \\  zylix-test report --format html --open
            \\  zylix-test report --input results/ --format junit
            \\
        ;
        output.print(help, .{});
    } else {
        output.printError("Unknown command: {s}", .{command});
    }
}

test "cli main" {
    // Basic test that the module compiles
    _ = commands;
    _ = config;
    _ = output;
}
