//! Output formatting for Zylix Test CLI
//!
//! Provides consistent terminal output with colors and formatting.
//! Compatible with Zig 0.15.

const std = @import("std");

/// ANSI color codes
pub const Color = enum {
    reset,
    bold,
    dim,
    red,
    green,
    yellow,
    blue,
    magenta,
    cyan,
    white,

    pub fn code(self: Color) []const u8 {
        return switch (self) {
            .reset => "\x1b[0m",
            .bold => "\x1b[1m",
            .dim => "\x1b[2m",
            .red => "\x1b[31m",
            .green => "\x1b[32m",
            .yellow => "\x1b[33m",
            .blue => "\x1b[34m",
            .magenta => "\x1b[35m",
            .cyan => "\x1b[36m",
            .white => "\x1b[37m",
        };
    }
};

var use_colors: bool = true;

fn stdout() std.fs.File {
    return std.fs.File.stdout();
}

fn stderr() std.fs.File {
    return std.fs.File.stderr();
}

/// Print formatted text
pub fn print(comptime fmt: []const u8, args: anytype) void {
    var buf: [4096]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, fmt, args) catch return;
    _ = stdout().write(msg) catch {};
}

/// Print literal string (no formatting)
pub fn printLiteral(s: []const u8) void {
    _ = stdout().write(s) catch {};
}

/// Print colored text
pub fn printColor(color: Color, comptime fmt: []const u8, args: anytype) void {
    if (use_colors) {
        printLiteral(color.code());
    }
    print(fmt, args);
    if (use_colors) {
        printLiteral(Color.reset.code());
    }
}

/// Print error message to stderr
pub fn printError(comptime fmt: []const u8, args: anytype) void {
    var buf: [4096]u8 = undefined;
    if (use_colors) {
        _ = stderr().write(Color.red.code()) catch {};
        _ = stderr().write("error:") catch {};
        _ = stderr().write(Color.reset.code()) catch {};
    } else {
        _ = stderr().write("error:") catch {};
    }
    _ = stderr().write(" ") catch {};
    const msg = std.fmt.bufPrint(&buf, fmt, args) catch return;
    _ = stderr().write(msg) catch {};
    _ = stderr().write("\n") catch {};
}

/// Print warning message
pub fn printWarning(comptime fmt: []const u8, args: anytype) void {
    var buf: [4096]u8 = undefined;
    if (use_colors) {
        _ = stderr().write(Color.yellow.code()) catch {};
        _ = stderr().write("warning:") catch {};
        _ = stderr().write(Color.reset.code()) catch {};
    } else {
        _ = stderr().write("warning:") catch {};
    }
    _ = stderr().write(" ") catch {};
    const msg = std.fmt.bufPrint(&buf, fmt, args) catch return;
    _ = stderr().write(msg) catch {};
    _ = stderr().write("\n") catch {};
}

/// Print info message
pub fn printInfo(comptime fmt: []const u8, args: anytype) void {
    if (use_colors) {
        printLiteral(Color.blue.code());
        printLiteral("info:");
        printLiteral(Color.reset.code());
    } else {
        printLiteral("info:");
    }
    printLiteral(" ");
    print(fmt, args);
    printLiteral("\n");
}

/// Print success message
pub fn printSuccess(comptime fmt: []const u8, args: anytype) void {
    if (use_colors) {
        printLiteral(Color.green.code());
        printLiteral("✓");
        printLiteral(Color.reset.code());
    } else {
        printLiteral("[OK]");
    }
    printLiteral(" ");
    print(fmt, args);
    printLiteral("\n");
}

/// Print failure message
pub fn printFailure(comptime fmt: []const u8, args: anytype) void {
    if (use_colors) {
        printLiteral(Color.red.code());
        printLiteral("✗");
        printLiteral(Color.reset.code());
    } else {
        printLiteral("[FAIL]");
    }
    printLiteral(" ");
    print(fmt, args);
    printLiteral("\n");
}

/// Print test result
pub fn printTestResult(name: []const u8, passed: bool, duration_ms: u64) void {
    if (passed) {
        printSuccess("{s} ({d}ms)", .{ name, duration_ms });
    } else {
        printFailure("{s} ({d}ms)", .{ name, duration_ms });
    }
}

/// Print a horizontal separator line
pub fn printSeparator() void {
    printLiteral("────────────────────────────────────────────────────────────\n");
}

/// Print a header with emphasis
pub fn printHeader(text: []const u8) void {
    printLiteral("\n");
    if (use_colors) {
        printLiteral(Color.bold.code());
        printLiteral(text);
        printLiteral(Color.reset.code());
        printLiteral("\n");
    } else {
        printLiteral(text);
        printLiteral("\n");
    }
    printSeparator();
}

/// Print a summary of test results
pub fn printSummary(passed: usize, failed: usize, skipped: usize, duration_ms: u64) void {
    printSeparator();

    const total = passed + failed + skipped;

    printLiteral("\n");
    if (use_colors) {
        printLiteral(Color.bold.code());
        printLiteral("Test Results:");
        printLiteral(Color.reset.code());
        printLiteral(" ");

        printLiteral(Color.green.code());
        print("{d} passed", .{passed});
        printLiteral(Color.reset.code());

        if (failed > 0) {
            printLiteral(", ");
            printLiteral(Color.red.code());
            print("{d} failed", .{failed});
            printLiteral(Color.reset.code());
        }

        if (skipped > 0) {
            printLiteral(", ");
            printLiteral(Color.yellow.code());
            print("{d} skipped", .{skipped});
            printLiteral(Color.reset.code());
        }
    } else {
        print("Test Results: {d} passed", .{passed});
        if (failed > 0) print(", {d} failed", .{failed});
        if (skipped > 0) print(", {d} skipped", .{skipped});
    }

    print(" ({d} total)\n", .{total});
    print("Duration: {d}ms\n\n", .{duration_ms});
}

test "output formatting" {
    _ = Color.reset.code();
    _ = Color.red.code();
    _ = Color.green.code();
}
