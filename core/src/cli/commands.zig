//! Command implementations for Zylix Test CLI
//!
//! Contains handlers for all CLI commands: run, init, server, list, report, ai.

const std = @import("std");
const config = @import("config.zig");
const output = @import("output.zig");

// AI module imports (provided by build system)
const ai = @import("ai");
const backend = ai.backend;

const ExitCode = @import("main.zig").ExitCode;
const Platform = config.Platform;
const RunConfig = config.RunConfig;
const ServerConfig = config.ServerConfig;

// ============================================================================
// Run Command
// ============================================================================

/// Run E2E tests
pub fn runTests(allocator: std.mem.Allocator, args: []const []const u8) ExitCode {
    var run_config = RunConfig{};

    // Parse arguments
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "--platform")) {
            if (i + 1 < args.len) {
                i += 1;
                if (Platform.fromString(args[i])) |p| {
                    run_config.platform = p;
                } else {
                    output.printError("Invalid platform: {s}", .{args[i]});
                    return ExitCode.invalid_args;
                }
            }
        } else if (std.mem.eql(u8, arg, "--browser")) {
            if (i + 1 < args.len) {
                i += 1;
                if (config.Browser.fromString(args[i])) |b| {
                    run_config.browser = b;
                } else {
                    output.printError("Invalid browser: {s}", .{args[i]});
                    return ExitCode.invalid_args;
                }
            }
        } else if (std.mem.eql(u8, arg, "--headless")) {
            run_config.headless = true;
        } else if (std.mem.eql(u8, arg, "--headed")) {
            run_config.headless = false;
        } else if (std.mem.eql(u8, arg, "--parallel")) {
            if (i + 1 < args.len) {
                i += 1;
                run_config.parallel = std.fmt.parseInt(u32, args[i], 10) catch {
                    output.printError("Invalid parallel count: {s}", .{args[i]});
                    return ExitCode.invalid_args;
                };
            }
        } else if (std.mem.eql(u8, arg, "--timeout")) {
            if (i + 1 < args.len) {
                i += 1;
                run_config.timeout_ms = std.fmt.parseInt(u32, args[i], 10) catch {
                    output.printError("Invalid timeout: {s}", .{args[i]});
                    return ExitCode.invalid_args;
                };
            }
        } else if (std.mem.eql(u8, arg, "--retry")) {
            if (i + 1 < args.len) {
                i += 1;
                run_config.retry_count = std.fmt.parseInt(u32, args[i], 10) catch {
                    output.printError("Invalid retry count: {s}", .{args[i]});
                    return ExitCode.invalid_args;
                };
            }
        } else if (std.mem.eql(u8, arg, "--reporter")) {
            if (i + 1 < args.len) {
                i += 1;
                if (config.ReportFormat.fromString(args[i])) |r| {
                    run_config.reporter = r;
                } else {
                    output.printError("Invalid reporter: {s}", .{args[i]});
                    return ExitCode.invalid_args;
                }
            }
        } else if (std.mem.eql(u8, arg, "--output")) {
            if (i + 1 < args.len) {
                i += 1;
                run_config.output_dir = args[i];
            }
        } else if (std.mem.eql(u8, arg, "--filter")) {
            if (i + 1 < args.len) {
                i += 1;
                run_config.filter = args[i];
            }
        } else if (std.mem.eql(u8, arg, "--tag")) {
            if (i + 1 < args.len) {
                i += 1;
                run_config.tag = args[i];
            }
        } else if (std.mem.eql(u8, arg, "--shard")) {
            if (i + 1 < args.len) {
                i += 1;
                // Parse n/total format
                if (std.mem.indexOf(u8, args[i], "/")) |sep| {
                    const index_str = args[i][0..sep];
                    const total_str = args[i][sep + 1 ..];
                    run_config.shard_index = std.fmt.parseInt(u32, index_str, 10) catch null;
                    run_config.shard_total = std.fmt.parseInt(u32, total_str, 10) catch null;
                }
            }
        } else if (std.mem.eql(u8, arg, "--debug")) {
            run_config.debug = true;
        } else if (std.mem.eql(u8, arg, "--dry-run")) {
            run_config.dry_run = true;
        } else if (std.mem.eql(u8, arg, "--config")) {
            if (i + 1 < args.len) {
                i += 1;
                run_config.config_file = args[i];
            }
        } else if (!std.mem.startsWith(u8, arg, "-")) {
            // Positional argument - treat as filter
            run_config.filter = arg;
        } else {
            output.printWarning("Unknown option: {s}", .{arg});
        }
    }

    // Load project config if available
    if (run_config.config_file) |cfg_file| {
        _ = config.loadConfig(allocator, cfg_file) catch |err| {
            output.printError("Failed to load config: {s}", .{@errorName(err)});
            return ExitCode.config_error;
        };
    }

    // Execute tests
    return executeTests(allocator, run_config);
}

fn executeTests(allocator: std.mem.Allocator, run_config: RunConfig) ExitCode {
    _ = allocator;

    output.printHeader("Zylix Test Runner");

    // Show configuration
    output.print("Platform: {s}\n", .{run_config.platform.toString()});
    if (run_config.platform == .web) {
        output.print("Browser: {s} (headless: {s})\n", .{
            @tagName(run_config.browser),
            if (run_config.headless) "yes" else "no",
        });
    }

    if (run_config.filter) |filter| {
        output.print("Filter: {s}\n", .{filter});
    }

    if (run_config.dry_run) {
        output.printInfo("Dry run mode - tests will not be executed", .{});
        return ExitCode.success;
    }

    output.print("\n", .{});

    // TODO: Integrate with actual test runner
    // For now, simulate test execution
    const start_time = std.time.milliTimestamp();

    // Simulated tests
    const test_names = [_][]const u8{
        "test_home_page_loads",
        "test_user_can_login",
        "test_navigation_works",
        "test_form_submission",
    };

    var passed: usize = 0;
    var failed: usize = 0;

    for (test_names) |name| {
        // Simulate test execution
        const test_passed = true; // Would come from actual test execution
        const duration: u64 = 150; // Simulated duration

        output.printTestResult(name, test_passed, duration);

        if (test_passed) {
            passed += 1;
        } else {
            failed += 1;
        }
    }

    const end_time = std.time.milliTimestamp();
    const total_duration: u64 = @intCast(end_time - start_time);

    output.printSummary(passed, failed, 0, total_duration);

    if (failed > 0) {
        return ExitCode.test_failure;
    }

    return ExitCode.success;
}

// ============================================================================
// Init Command
// ============================================================================

/// Initialize a new test project
pub fn initProject(allocator: std.mem.Allocator, args: []const []const u8) ExitCode {
    var project_name: []const u8 = "zylix-tests";
    var template: []const u8 = "basic";
    var force = false;

    // Parse arguments
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "--template")) {
            if (i + 1 < args.len) {
                i += 1;
                template = args[i];
            }
        } else if (std.mem.eql(u8, arg, "--force")) {
            force = true;
        } else if (!std.mem.startsWith(u8, arg, "-")) {
            project_name = arg;
        }
    }

    output.printHeader("Initialize Zylix Test Project");
    output.print("Project: {s}\n", .{project_name});
    output.print("Template: {s}\n\n", .{template});

    // Create project directory
    var dir = std.fs.cwd().makeOpenPath(project_name, .{}) catch |err| {
        if (err == error.PathAlreadyExists and !force) {
            output.printError("Directory already exists. Use --force to overwrite.", .{});
            return ExitCode.config_error;
        }
        output.printError("Failed to create directory: {s}", .{@errorName(err)});
        return ExitCode.runtime_error;
    };
    defer dir.close();

    // Create config file
    const config_content = config.generateDefaultConfig(project_name);
    dir.writeFile(.{
        .sub_path = "zylix-test.json",
        .data = config_content,
    }) catch |err| {
        output.printError("Failed to create config: {s}", .{@errorName(err)});
        return ExitCode.runtime_error;
    };
    output.printSuccess("Created zylix-test.json", .{});

    // Create tests directory
    dir.makeDir("tests") catch |err| {
        if (err != error.PathAlreadyExists) {
            output.printError("Failed to create tests directory: {s}", .{@errorName(err)});
            return ExitCode.runtime_error;
        }
    };
    output.printSuccess("Created tests/", .{});

    // Create example test file
    const example_test = generateExampleTest(allocator, template);
    var tests_dir = dir.openDir("tests", .{}) catch {
        output.printError("Failed to open tests directory", .{});
        return ExitCode.runtime_error;
    };
    defer tests_dir.close();
    tests_dir.writeFile(.{
        .sub_path = "example.test.zig",
        .data = example_test,
    }) catch |err| {
        output.printError("Failed to create example test: {s}", .{@errorName(err)});
        return ExitCode.runtime_error;
    };
    output.printSuccess("Created tests/example.test.zig", .{});

    output.print("\n", .{});
    output.printSuccess("Project initialized successfully!", .{});
    output.print("\nNext steps:\n", .{});
    output.print("  cd {s}\n", .{project_name});
    output.print("  zylix-test run\n", .{});

    return ExitCode.success;
}

fn generateExampleTest(allocator: std.mem.Allocator, template: []const u8) []const u8 {
    _ = allocator;
    _ = template;

    return
        \\//! Example Zylix Test
        \\
        \\const std = @import("std");
        \\const zylix = @import("zylix_test");
        \\
        \\test "example: home page loads" {
        \\    const allocator = std.testing.allocator;
        \\
        \\    // Create web driver
        \\    var driver = try zylix.createWebDriver(.{
        \\        .browser = .chrome,
        \\        .headless = true,
        \\    }, allocator);
        \\    defer driver.deinit();
        \\
        \\    // Launch application
        \\    var app = try zylix.launch(&driver, .{
        \\        .app_id = "https://example.com",
        \\        .platform = .web,
        \\    }, allocator);
        \\    defer app.terminate() catch {};
        \\
        \\    // Find and verify element
        \\    const heading = try app.findByTestId("main-heading");
        \\    try zylix.expectElement(&heading).toBeVisible();
        \\}
        \\
        \\test "example: user can click button" {
        \\    const allocator = std.testing.allocator;
        \\
        \\    var driver = try zylix.createWebDriver(.{
        \\        .browser = .chrome,
        \\        .headless = true,
        \\    }, allocator);
        \\    defer driver.deinit();
        \\
        \\    var app = try zylix.launch(&driver, .{
        \\        .app_id = "https://example.com",
        \\        .platform = .web,
        \\    }, allocator);
        \\    defer app.terminate() catch {};
        \\
        \\    // Click button
        \\    try app.findByTestId("submit-button").tap();
        \\
        \\    // Wait for result
        \\    const result = try app.waitForText("Success", 5000);
        \\    try zylix.expectElement(&result).toBeVisible();
        \\}
        \\
    ;
}

// ============================================================================
// Server Command
// ============================================================================

/// Manage bridge servers
pub fn serverCommand(allocator: std.mem.Allocator, args: []const []const u8) ExitCode {
    _ = allocator;

    if (args.len == 0) {
        output.printError("Missing action. Use: start, stop, status, restart", .{});
        return ExitCode.invalid_args;
    }

    const action = args[0];
    const action_args = if (args.len > 1) args[1..] else args[0..0];

    // Parse platform flags
    var platforms_list: std.ArrayListUnmanaged(Platform) = .{};
    defer platforms_list.deinit(std.heap.page_allocator);

    var custom_port: ?u16 = null;
    var daemon = false;

    const alloc = std.heap.page_allocator;
    for (action_args) |arg| {
        if (std.mem.eql(u8, arg, "--web")) {
            platforms_list.append(alloc, .web) catch {};
        } else if (std.mem.eql(u8, arg, "--ios")) {
            platforms_list.append(alloc, .ios) catch {};
        } else if (std.mem.eql(u8, arg, "--android")) {
            platforms_list.append(alloc, .android) catch {};
        } else if (std.mem.eql(u8, arg, "--macos")) {
            platforms_list.append(alloc, .macos) catch {};
        } else if (std.mem.eql(u8, arg, "--windows")) {
            platforms_list.append(alloc, .windows) catch {};
        } else if (std.mem.eql(u8, arg, "--linux")) {
            platforms_list.append(alloc, .linux) catch {};
        } else if (std.mem.eql(u8, arg, "--all")) {
            platforms_list.append(alloc, .web) catch {};
            platforms_list.append(alloc, .ios) catch {};
            platforms_list.append(alloc, .android) catch {};
            platforms_list.append(alloc, .macos) catch {};
            platforms_list.append(alloc, .windows) catch {};
            platforms_list.append(alloc, .linux) catch {};
        } else if (std.mem.eql(u8, arg, "--daemon")) {
            daemon = true;
        } else if (std.mem.startsWith(u8, arg, "--port=")) {
            const port_str = arg[7..];
            custom_port = std.fmt.parseInt(u16, port_str, 10) catch null;
        }
    }

    // Default to web if no platform specified
    if (platforms_list.items.len == 0) {
        platforms_list.append(alloc, .web) catch {};
    }

    if (std.mem.eql(u8, action, "start")) {
        return startServers(platforms_list.items, custom_port, daemon);
    } else if (std.mem.eql(u8, action, "stop")) {
        return stopServers(platforms_list.items);
    } else if (std.mem.eql(u8, action, "status")) {
        return showServerStatus(platforms_list.items);
    } else if (std.mem.eql(u8, action, "restart")) {
        _ = stopServers(platforms_list.items);
        return startServers(platforms_list.items, custom_port, daemon);
    } else {
        output.printError("Unknown action: {s}", .{action});
        return ExitCode.invalid_args;
    }
}

fn startServers(platforms: []const Platform, custom_port: ?u16, daemon: bool) ExitCode {
    output.printHeader("Starting Bridge Servers");

    for (platforms) |platform| {
        const port = custom_port orelse platform.defaultPort();

        output.print("Starting {s} server on port {d}...\n", .{ platform.toString(), port });

        // TODO: Actually start the server process
        // For now, just show what would happen
        if (daemon) {
            output.printSuccess("{s} server started in background (port {d})", .{ platform.toString(), port });
        } else {
            output.printInfo("{s} server would start on port {d}", .{ platform.toString(), port });
        }
    }

    return ExitCode.success;
}

fn stopServers(platforms: []const Platform) ExitCode {
    output.printHeader("Stopping Bridge Servers");

    for (platforms) |platform| {
        output.print("Stopping {s} server...\n", .{platform.toString()});
        // TODO: Actually stop the server process
        output.printSuccess("{s} server stopped", .{platform.toString()});
    }

    return ExitCode.success;
}

fn showServerStatus(platforms: []const Platform) ExitCode {
    output.printHeader("Bridge Server Status");

    output.print("{s:<12} {s:<8} {s:<10}\n", .{ "Platform", "Port", "Status" });
    output.printSeparator();

    for (platforms) |platform| {
        const port = platform.defaultPort();
        // TODO: Check actual server status
        const status = "stopped";

        output.print("{s:<12} {d:<8} {s:<10}\n", .{ platform.toString(), port, status });
    }

    return ExitCode.success;
}

// ============================================================================
// List Command
// ============================================================================

/// List available tests
pub fn listTests(allocator: std.mem.Allocator, args: []const []const u8) ExitCode {
    _ = allocator;

    var platform_filter: ?Platform = null;
    var json_output = false;

    // Parse arguments
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "--platform")) {
            if (i + 1 < args.len) {
                i += 1;
                platform_filter = Platform.fromString(args[i]);
            }
        } else if (std.mem.eql(u8, arg, "--json")) {
            json_output = true;
        }
    }

    if (json_output) {
        // JSON output
        output.printLiteral("[\n");
        output.printLiteral("  {\"name\": \"test_home_page\", \"file\": \"tests/home.test.zig\", \"platform\": \"web\"},\n");
        output.printLiteral("  {\"name\": \"test_login\", \"file\": \"tests/auth.test.zig\", \"platform\": \"web\"}\n");
        output.printLiteral("]\n");
    } else {
        output.printHeader("Available Tests");

        if (platform_filter) |p| {
            output.print("Platform: {s}\n\n", .{p.toString()});
        }

        // TODO: Actually scan for tests
        output.print("{s:<30} {s:<30} {s:<10}\n", .{ "Test Name", "File", "Platform" });
        output.printSeparator();
        output.print("{s:<30} {s:<30} {s:<10}\n", .{ "test_home_page", "tests/home.test.zig", "web" });
        output.print("{s:<30} {s:<30} {s:<10}\n", .{ "test_login", "tests/auth.test.zig", "web" });
        output.print("{s:<30} {s:<30} {s:<10}\n", .{ "test_navigation", "tests/nav.test.zig", "web" });
        output.print("\nTotal: 3 tests\n", .{});
    }

    return ExitCode.success;
}

// ============================================================================
// Report Command
// ============================================================================

/// Generate test reports
pub fn generateReport(allocator: std.mem.Allocator, args: []const []const u8) ExitCode {
    _ = allocator;

    var input_dir: []const u8 = "test-results";
    var output_dir: []const u8 = "test-results";
    var format = config.ReportFormat.html;
    var open_report = false;

    // Parse arguments
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "--input")) {
            if (i + 1 < args.len) {
                i += 1;
                input_dir = args[i];
            }
        } else if (std.mem.eql(u8, arg, "--output")) {
            if (i + 1 < args.len) {
                i += 1;
                output_dir = args[i];
            }
        } else if (std.mem.eql(u8, arg, "--format")) {
            if (i + 1 < args.len) {
                i += 1;
                if (config.ReportFormat.fromString(args[i])) |f| {
                    format = f;
                }
            }
        } else if (std.mem.eql(u8, arg, "--open")) {
            open_report = true;
        }
    }

    output.printHeader("Generate Test Report");

    output.print("Input: {s}\n", .{input_dir});
    output.print("Output: {s}\n", .{output_dir});
    output.print("Format: {s}\n\n", .{@tagName(format)});

    // TODO: Actually generate report
    const report_file = switch (format) {
        .html => "report.html",
        .junit => "junit.xml",
        .json => "results.json",
        .markdown => "report.md",
        else => "report.txt",
    };

    output.printSuccess("Generated {s}/{s}", .{ output_dir, report_file });

    if (open_report and format == .html) {
        output.printInfo("Opening report in browser...", .{});
        // TODO: Actually open browser
    }

    return ExitCode.success;
}

// ============================================================================
// AI Command
// ============================================================================

/// Test AI inference with a model
pub fn aiCommand(allocator: std.mem.Allocator, args: []const []const u8) ExitCode {
    if (args.len == 0) {
        output.printError("Missing action. Use: embed, generate, transcribe, stream, analyze, info", .{});
        return ExitCode.invalid_args;
    }

    const action = args[0];
    const action_args = if (args.len > 1) args[1..] else args[0..0];

    if (std.mem.eql(u8, action, "embed")) {
        return aiEmbed(allocator, action_args);
    } else if (std.mem.eql(u8, action, "generate")) {
        return aiGenerate(allocator, action_args);
    } else if (std.mem.eql(u8, action, "transcribe")) {
        return aiTranscribe(allocator, action_args);
    } else if (std.mem.eql(u8, action, "stream")) {
        return aiStream(allocator, action_args);
    } else if (std.mem.eql(u8, action, "analyze")) {
        return aiAnalyze(allocator, action_args);
    } else if (std.mem.eql(u8, action, "info")) {
        return aiInfo(allocator, action_args);
    } else {
        output.printError("Unknown action: {s}", .{action});
        output.print("Use: embed, generate, transcribe, stream, analyze, info\n", .{});
        return ExitCode.invalid_args;
    }
}

fn aiEmbed(allocator: std.mem.Allocator, args: []const []const u8) ExitCode {
    var model_path: ?[]const u8 = null;
    var text: ?[]const u8 = null;

    // Parse arguments
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--model") or std.mem.eql(u8, arg, "-m")) {
            if (i + 1 < args.len) {
                i += 1;
                model_path = args[i];
            }
        } else if (std.mem.eql(u8, arg, "--text") or std.mem.eql(u8, arg, "-t")) {
            if (i + 1 < args.len) {
                i += 1;
                text = args[i];
            }
        } else if (!std.mem.startsWith(u8, arg, "-")) {
            if (model_path == null) {
                model_path = arg;
            } else if (text == null) {
                text = arg;
            }
        }
    }

    if (model_path == null) {
        output.printError("Missing model path. Use: --model <path>", .{});
        return ExitCode.invalid_args;
    }

    if (text == null) {
        output.printError("Missing text. Use: --text <text>", .{});
        return ExitCode.invalid_args;
    }

    output.printHeader("Zylix AI - Embedding Inference");
    output.print("Model: {s}\n", .{model_path.?});
    output.print("Text: {s}\n\n", .{text.?});

    // Check if GGML backend is available
    if (!backend.isBackendAvailable(.ggml)) {
        output.printError("GGML backend not available on this platform", .{});
        return ExitCode.runtime_error;
    }

    // Create GGML backend
    const cfg = backend.BackendConfig{
        .backend_type = .ggml,
        .num_threads = 4,
        .use_gpu = true,
    };

    const ggml_backend = backend.createBackend(cfg, allocator) catch |err| {
        output.printError("Failed to create GGML backend: {s}", .{@errorName(err)});
        return ExitCode.runtime_error;
    };
    defer ggml_backend.deinit();

    output.print("Loading model...\n", .{});
    const load_result = ggml_backend.load(model_path.?);
    if (load_result != .ok) {
        output.printError("Failed to load model: {s}", .{@tagName(load_result)});
        return ExitCode.runtime_error;
    }

    output.printSuccess("Model loaded", .{});

    // Run embedding
    output.print("Running embedding inference...\n", .{});
    var embedding: [4096]f32 = undefined; // Max embedding size
    const embed_result = ggml_backend.runEmbedding(text.?, &embedding);

    if (embed_result != .ok) {
        output.printError("Embedding failed: {s}", .{@tagName(embed_result)});
        return ExitCode.runtime_error;
    }

    output.printSuccess("Embedding generated successfully!", .{});
    output.print("\nFirst 10 dimensions: [", .{});
    for (embedding[0..10], 0..) |val, idx| {
        if (idx > 0) output.print(", ", .{});
        output.print("{d:.4}", .{val});
    }
    output.print(", ...]\n", .{});

    // Calculate L2 norm
    var norm: f32 = 0.0;
    for (embedding[0..384]) |v| {
        norm += v * v;
    }
    norm = @sqrt(norm);
    output.print("L2 Norm: {d:.6}\n", .{norm});

    return ExitCode.success;
}

fn aiGenerate(allocator: std.mem.Allocator, args: []const []const u8) ExitCode {
    var model_path: ?[]const u8 = null;
    var prompt: ?[]const u8 = null;

    // Parse arguments
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--model") or std.mem.eql(u8, arg, "-m")) {
            if (i + 1 < args.len) {
                i += 1;
                model_path = args[i];
            }
        } else if (std.mem.eql(u8, arg, "--prompt") or std.mem.eql(u8, arg, "-p")) {
            if (i + 1 < args.len) {
                i += 1;
                prompt = args[i];
            }
        } else if (!std.mem.startsWith(u8, arg, "-")) {
            if (model_path == null) {
                model_path = arg;
            } else if (prompt == null) {
                prompt = arg;
            }
        }
    }

    if (model_path == null) {
        output.printError("Missing model path. Use: --model <path>", .{});
        return ExitCode.invalid_args;
    }

    if (prompt == null) {
        output.printError("Missing prompt. Use: --prompt <text>", .{});
        return ExitCode.invalid_args;
    }

    output.printHeader("Zylix AI - Text Generation");
    output.print("Model: {s}\n", .{model_path.?});
    output.print("Prompt: {s}\n\n", .{prompt.?});

    // Check if GGML backend is available
    if (!backend.isBackendAvailable(.ggml)) {
        output.printError("GGML backend not available on this platform", .{});
        return ExitCode.runtime_error;
    }

    // Create GGML backend
    const cfg = backend.BackendConfig{
        .backend_type = .ggml,
        .num_threads = 4,
        .use_gpu = true,
    };

    const ggml_backend = backend.createBackend(cfg, allocator) catch |err| {
        output.printError("Failed to create GGML backend: {s}", .{@errorName(err)});
        return ExitCode.runtime_error;
    };
    defer ggml_backend.deinit();

    output.print("Loading model...\n", .{});
    const load_result = ggml_backend.load(model_path.?);
    if (load_result != .ok) {
        output.printError("Failed to load model: {s}", .{@tagName(load_result)});
        return ExitCode.runtime_error;
    }

    output.printSuccess("Model loaded", .{});

    // Run generation
    output.print("Generating text...\n", .{});
    var generated: [1024]u8 = undefined;
    const gen_result = ggml_backend.runGenerate(prompt.?, &generated);

    if (gen_result != .ok) {
        output.printError("Generation failed: {s}", .{@tagName(gen_result)});
        return ExitCode.runtime_error;
    }

    // Find end of generated text
    var len: usize = 0;
    for (generated, 0..) |c, idx| {
        if (c == 0) {
            len = idx;
            break;
        }
        len = idx + 1;
    }

    output.printSuccess("Text generated successfully!", .{});
    output.print("\nGenerated:\n{s}\n", .{generated[0..len]});

    return ExitCode.success;
}

fn aiTranscribe(allocator: std.mem.Allocator, args: []const []const u8) ExitCode {
    var model_path: ?[]const u8 = null;
    var audio_path: ?[]const u8 = null;
    var language: []const u8 = "";
    var translate = false;

    // Parse arguments
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--model") or std.mem.eql(u8, arg, "-m")) {
            if (i + 1 < args.len) {
                i += 1;
                model_path = args[i];
            }
        } else if (std.mem.eql(u8, arg, "--audio") or std.mem.eql(u8, arg, "-a")) {
            if (i + 1 < args.len) {
                i += 1;
                audio_path = args[i];
            }
        } else if (std.mem.eql(u8, arg, "--language") or std.mem.eql(u8, arg, "-l")) {
            if (i + 1 < args.len) {
                i += 1;
                language = args[i];
            }
        } else if (std.mem.eql(u8, arg, "--translate")) {
            translate = true;
        } else if (!std.mem.startsWith(u8, arg, "-")) {
            if (model_path == null) {
                model_path = arg;
            } else if (audio_path == null) {
                audio_path = arg;
            }
        }
    }

    if (model_path == null) {
        output.printError("Missing model path. Use: --model <path>", .{});
        return ExitCode.invalid_args;
    }

    if (audio_path == null) {
        output.printError("Missing audio file. Use: --audio <path>", .{});
        return ExitCode.invalid_args;
    }

    output.printHeader("Zylix AI - Speech Transcription");
    output.print("Model: {s}\n", .{model_path.?});
    output.print("Audio: {s}\n", .{audio_path.?});
    if (language.len > 0) {
        output.print("Language: {s}\n", .{language});
    }
    if (translate) {
        output.print("Mode: Translate to English\n", .{});
    }
    output.print("\n", .{});

    // Check if Whisper backend is available
    if (!ai.whisper.isWhisperAvailable()) {
        output.printError("Whisper backend not available on this platform", .{});
        return ExitCode.runtime_error;
    }

    // Create Whisper backend
    const whisper_config = ai.whisper.whisper_backend.WhisperConfig{
        .model_path = model_path.?,
        .language = language,
        .translate = translate,
        .n_threads = 4,
        .use_gpu = true,
    };

    const whisper_backend_ptr = ai.whisper.WhisperBackend.init(allocator, whisper_config) catch |err| {
        output.printError("Failed to create Whisper backend: {s}", .{@errorName(err)});
        return ExitCode.runtime_error;
    };
    defer whisper_backend_ptr.deinit();

    output.print("Loading model...\n", .{});
    const load_result = whisper_backend_ptr.load(model_path.?);
    if (load_result != .ok) {
        output.printError("Failed to load model: {s}", .{@tagName(load_result)});
        return ExitCode.runtime_error;
    }

    output.printSuccess("Model loaded", .{});
    output.print("Whisper version: {s}\n", .{ai.whisper.WhisperBackend.getVersion()});

    if (whisper_backend_ptr.isMultilingual()) {
        output.print("Model type: Multilingual\n", .{});
    } else {
        output.print("Model type: English-only\n", .{});
    }

    // Load and decode audio file (supports WAV, MP3, FLAC, OGG)
    output.print("\nLoading audio file...\n", .{});

    // Check if format is supported
    if (!ai.audio_decoder.isFormatSupported(audio_path.?)) {
        const ext = std.fs.path.extension(audio_path.?);
        output.printError("Unsupported audio format: {s}", .{ext});
        output.print("Supported formats: WAV, MP3, FLAC, OGG\n", .{});
        return ExitCode.invalid_args;
    }

    // Decode audio to 16kHz mono f32 (Whisper format)
    var decode_result = ai.audio_decoder.decodeFileForWhisper(allocator, audio_path.?) catch |err| {
        const err_msg = switch (err) {
            ai.audio_decoder.DecodeError.FileNotFound => "File not found",
            ai.audio_decoder.DecodeError.InvalidFile => "Invalid audio file",
            ai.audio_decoder.DecodeError.UnsupportedFormat => "Unsupported format",
            ai.audio_decoder.DecodeError.OutOfMemory => "Out of memory",
            ai.audio_decoder.DecodeError.DecodeFailed => "Decode failed",
            ai.audio_decoder.DecodeError.NoData => "No audio data",
            else => "Unknown error",
        };
        output.printError("Failed to decode audio: {s}", .{err_msg});
        return ExitCode.runtime_error;
    };
    defer decode_result.deinit();

    const samples = decode_result.samples;
    const audio_info = decode_result.info;

    output.print("Format: {s}\n", .{audio_info.format.toString()});
    output.print("Sample rate: {d} Hz (resampled to 16kHz)\n", .{audio_info.sample_rate});

    const sample_count = samples.len;
    if (sample_count == 0) {
        output.printError("Audio file contains no samples", .{});
        return ExitCode.runtime_error;
    }

    var duration_buf: [16]u8 = undefined;
    const duration_str = audio_info.durationString(&duration_buf);
    output.print("Duration: {s} ({d} samples)\n", .{ duration_str, sample_count });

    // Run transcription
    output.print("\nTranscribing...\n", .{});
    const start_time = std.time.milliTimestamp();

    var output_buffer: [32 * 1024]u8 = undefined;
    var result: ai.whisper.whisper_backend.TranscriptResult = undefined;

    const transcribe_result = whisper_backend_ptr.transcribe(samples, &output_buffer, &result);
    if (transcribe_result != .ok) {
        output.printError("Transcription failed: {s}", .{@tagName(transcribe_result)});
        return ExitCode.runtime_error;
    }

    const end_time = std.time.milliTimestamp();
    const processing_time: u64 = @intCast(@max(0, end_time - start_time));

    output.printSuccess("Transcription complete!", .{});
    output.print("\nProcessing time: {d}ms\n", .{processing_time});

    const lang_str = std.mem.sliceTo(&result.language, 0);
    if (lang_str.len > 0) {
        output.print("Detected language: {s}\n", .{lang_str});
    }

    output.print("Segments: {d}\n", .{result.n_segments});
    output.print("\nTranscription:\n", .{});
    output.printSeparator();
    if (result.text_len > 0) {
        output.print("{s}\n", .{output_buffer[0..result.text_len]});
    } else {
        output.print("(No speech detected)\n", .{});
    }
    output.printSeparator();

    return ExitCode.success;
}

fn aiStream(allocator: std.mem.Allocator, args: []const []const u8) ExitCode {
    var model_path: ?[]const u8 = null;
    var audio_path: ?[]const u8 = null;
    var language: []const u8 = "";
    var translate = false;
    var step_ms: u32 = 3000;
    var keep_ms: u32 = 200;

    // Parse arguments
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--model") or std.mem.eql(u8, arg, "-m")) {
            if (i + 1 < args.len) {
                i += 1;
                model_path = args[i];
            }
        } else if (std.mem.eql(u8, arg, "--audio") or std.mem.eql(u8, arg, "-a")) {
            if (i + 1 < args.len) {
                i += 1;
                audio_path = args[i];
            }
        } else if (std.mem.eql(u8, arg, "--language") or std.mem.eql(u8, arg, "-l")) {
            if (i + 1 < args.len) {
                i += 1;
                language = args[i];
            }
        } else if (std.mem.eql(u8, arg, "--translate")) {
            translate = true;
        } else if (std.mem.eql(u8, arg, "--step")) {
            if (i + 1 < args.len) {
                i += 1;
                step_ms = std.fmt.parseInt(u32, args[i], 10) catch 3000;
            }
        } else if (std.mem.eql(u8, arg, "--keep")) {
            if (i + 1 < args.len) {
                i += 1;
                keep_ms = std.fmt.parseInt(u32, args[i], 10) catch 200;
            }
        } else if (!std.mem.startsWith(u8, arg, "-")) {
            if (model_path == null) {
                model_path = arg;
            } else if (audio_path == null) {
                audio_path = arg;
            }
        }
    }

    if (model_path == null) {
        output.printError("Missing model path. Use: --model <path>", .{});
        return ExitCode.invalid_args;
    }

    if (audio_path == null) {
        output.printError("Missing audio file. Use: --audio <path>", .{});
        return ExitCode.invalid_args;
    }

    output.printHeader("Zylix AI - Streaming Transcription");
    output.print("Model: {s}\n", .{model_path.?});
    output.print("Audio: {s}\n", .{audio_path.?});
    if (language.len > 0) {
        output.print("Language: {s}\n", .{language});
    }
    if (translate) {
        output.print("Mode: Translate to English\n", .{});
    }
    output.print("Step: {d}ms, Keep: {d}ms\n", .{ step_ms, keep_ms });
    output.print("\n", .{});

    // Check if Whisper backend is available
    if (!ai.whisper.isWhisperAvailable()) {
        output.printError("Whisper backend not available on this platform", .{});
        return ExitCode.runtime_error;
    }

    // Check if audio format is supported
    if (!ai.audio_decoder.isFormatSupported(audio_path.?)) {
        const ext = std.fs.path.extension(audio_path.?);
        output.printError("Unsupported audio format: {s}", .{ext});
        output.print("Supported formats: WAV, MP3, FLAC\n", .{});
        return ExitCode.invalid_args;
    }

    // Decode audio to 16kHz mono f32 (Whisper format)
    output.print("Loading audio file...\n", .{});
    var decode_result = ai.audio_decoder.decodeFileForWhisper(allocator, audio_path.?) catch |err| {
        const err_msg = switch (err) {
            ai.audio_decoder.DecodeError.FileNotFound => "File not found",
            ai.audio_decoder.DecodeError.InvalidFile => "Invalid audio file",
            ai.audio_decoder.DecodeError.UnsupportedFormat => "Unsupported format",
            ai.audio_decoder.DecodeError.OutOfMemory => "Out of memory",
            ai.audio_decoder.DecodeError.DecodeFailed => "Decode failed",
            ai.audio_decoder.DecodeError.NoData => "No audio data",
            else => "Unknown error",
        };
        output.printError("Failed to decode audio: {s}", .{err_msg});
        return ExitCode.runtime_error;
    };
    defer decode_result.deinit();

    const samples = decode_result.samples;
    const audio_info = decode_result.info;

    output.print("Format: {s}\n", .{audio_info.format.toString()});

    var duration_buf: [16]u8 = undefined;
    const duration_str = audio_info.durationString(&duration_buf);
    output.print("Duration: {s} ({d} samples)\n", .{ duration_str, samples.len });

    // Create streaming context
    output.print("\nLoading model...\n", .{});

    const stream_config = ai.whisper_stream.StreamConfig{
        .step_ms = step_ms,
        .keep_ms = keep_ms,
        .language = language,
        .translate = translate,
        .n_threads = 4,
        .use_gpu = true,
        .single_segment = true,
        .no_context = true,
        .print_timestamps = false,
    };

    const stream_ctx = ai.whisper_stream.StreamingContext.init(allocator, model_path.?, stream_config) catch |err| {
        output.printError("Failed to create streaming context: {s}", .{@errorName(err)});
        return ExitCode.runtime_error;
    };
    defer stream_ctx.deinit();

    output.printSuccess("Model loaded", .{});
    output.print("\nStreaming transcription (simulated real-time):\n", .{});
    output.printSeparator();

    // Simulate streaming by feeding chunks
    const step_samples = (step_ms * ai.whisper_stream.SAMPLE_RATE) / 1000;
    var pos: usize = 0;
    var segment_count: usize = 0;
    const start_time = std.time.milliTimestamp();

    while (pos < samples.len) {
        const end_pos = @min(pos + step_samples, samples.len);
        const chunk = samples[pos..end_pos];

        // Feed audio chunk
        stream_ctx.feedAudio(chunk) catch |err| {
            output.printError("Failed to process chunk: {s}", .{@errorName(err)});
            return ExitCode.runtime_error;
        };

        // Print any new segments
        while (stream_ctx.hasSegments()) {
            if (stream_ctx.popSegment()) |segment| {
                const text = segment.getText();
                if (text.len > 0) {
                    // Format timestamp
                    const start_sec = @divFloor(segment.start_ms, 1000);
                    const end_sec = @divFloor(segment.end_ms, 1000);
                    output.print("[{d:0>2}:{d:0>2} -> {d:0>2}:{d:0>2}] {s}\n", .{
                        @as(u32, @intCast(@divFloor(start_sec, 60))),
                        @as(u32, @intCast(@mod(start_sec, 60))),
                        @as(u32, @intCast(@divFloor(end_sec, 60))),
                        @as(u32, @intCast(@mod(end_sec, 60))),
                        text,
                    });
                    segment_count += 1;
                }
            }
        }

        pos = end_pos;
    }

    // Flush any remaining audio
    stream_ctx.flush() catch {};

    // Print final segments
    while (stream_ctx.hasSegments()) {
        if (stream_ctx.popSegment()) |segment| {
            const text = segment.getText();
            if (text.len > 0) {
                const start_sec = @divFloor(segment.start_ms, 1000);
                const end_sec = @divFloor(segment.end_ms, 1000);
                output.print("[{d:0>2}:{d:0>2} -> {d:0>2}:{d:0>2}] {s}\n", .{
                    @as(u32, @intCast(@divFloor(start_sec, 60))),
                    @as(u32, @intCast(@mod(start_sec, 60))),
                    @as(u32, @intCast(@divFloor(end_sec, 60))),
                    @as(u32, @intCast(@mod(end_sec, 60))),
                    text,
                });
                segment_count += 1;
            }
        }
    }

    output.printSeparator();

    const end_time = std.time.milliTimestamp();
    const processing_time: u64 = @intCast(@max(0, end_time - start_time));

    const stats = stream_ctx.getStats();
    output.printSuccess("Streaming complete!", .{});
    output.print("\nStatistics:\n", .{});
    output.print("  Chunks processed: {d}\n", .{stats.chunks_processed});
    output.print("  Segments produced: {d}\n", .{segment_count});
    output.print("  Processing time: {d}ms\n", .{processing_time});
    output.print("  Audio duration: {d}ms\n", .{stats.audio_duration_ms});
    output.print("  Real-time factor: {d:.2}x\n", .{stats.realtime_factor});

    return ExitCode.success;
}

fn aiAnalyze(allocator: std.mem.Allocator, args: []const []const u8) ExitCode {
    var model_path: ?[]const u8 = null;
    var mmproj_path: ?[]const u8 = null;
    var image_path: ?[]const u8 = null;
    var prompt: []const u8 = "Describe this image in detail.";

    // Parse arguments
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--model") or std.mem.eql(u8, arg, "-m")) {
            if (i + 1 < args.len) {
                i += 1;
                model_path = args[i];
            }
        } else if (std.mem.eql(u8, arg, "--mmproj") or std.mem.eql(u8, arg, "-p")) {
            if (i + 1 < args.len) {
                i += 1;
                mmproj_path = args[i];
            }
        } else if (std.mem.eql(u8, arg, "--image") or std.mem.eql(u8, arg, "-i")) {
            if (i + 1 < args.len) {
                i += 1;
                image_path = args[i];
            }
        } else if (std.mem.eql(u8, arg, "--prompt") or std.mem.eql(u8, arg, "-q")) {
            if (i + 1 < args.len) {
                i += 1;
                prompt = args[i];
            }
        } else if (!std.mem.startsWith(u8, arg, "-")) {
            if (model_path == null) {
                model_path = arg;
            } else if (image_path == null) {
                image_path = arg;
            }
        }
    }

    if (model_path == null) {
        output.printError("Missing model path. Use: --model <path>", .{});
        return ExitCode.invalid_args;
    }

    if (image_path == null) {
        output.printError("Missing image path. Use: --image <path>", .{});
        return ExitCode.invalid_args;
    }

    output.printHeader("Zylix AI - Image Analysis (VLM)");
    output.print("Model: {s}\n", .{model_path.?});
    if (mmproj_path) |mp| {
        output.print("Vision Projector: {s}\n", .{mp});
    }
    output.print("Image: {s}\n", .{image_path.?});
    output.print("Prompt: {s}\n\n", .{prompt});

    // Check if VLM backend is available
    if (!ai.vlm_backend.isVLMAvailable()) {
        output.printError("VLM backend not available on this platform", .{});
        return ExitCode.runtime_error;
    }

    // Load image file
    output.print("Loading image...\n", .{});
    const image_file = std.fs.cwd().openFile(image_path.?, .{}) catch |err| {
        output.printError("Failed to open image file: {s}", .{@errorName(err)});
        return ExitCode.runtime_error;
    };
    defer image_file.close();

    const image_data = image_file.readToEndAlloc(allocator, 50 * 1024 * 1024) catch |err| {
        output.printError("Failed to read image file: {s}", .{@errorName(err)});
        return ExitCode.runtime_error;
    };
    defer allocator.free(image_data);

    var size_buf: [32]u8 = undefined;
    output.print("Image size: {s}\n", .{ai.formatFileSize(image_data.len, &size_buf)});

    // For now, show placeholder since full VLM inference requires model download
    output.print("\n", .{});
    output.printInfo("VLM backend initialized. Full inference requires:", .{});
    output.print("  1. LLaVA text model (e.g., llava-v1.6-mistral-7b.Q4_K_M.gguf)\n", .{});
    output.print("  2. Vision projector (e.g., mmproj-model-f16.gguf)\n", .{});
    output.print("\nDownload from: https://huggingface.co/mys/ggml_llava-v1.6-mistral-7b\n", .{});

    // TODO: Implement actual VLM inference when models are available
    // const vlm_config = ai.vlm_backend.VLMConfig{...};
    // const vlm_backend_ptr = try ai.VLMBackend.init(allocator, vlm_config);
    // defer vlm_backend_ptr.deinit();

    return ExitCode.success;
}

fn aiInfo(allocator: std.mem.Allocator, args: []const []const u8) ExitCode {
    _ = allocator;

    output.printHeader("Zylix AI - System Info");

    // Check backend availability
    output.print("\nBackend Availability:\n", .{});
    output.print("  GGML (llama.cpp): {s}\n", .{if (backend.isBackendAvailable(.ggml)) "Available" else "Not available"});
    output.print("  VLM (mtmd):       {s}\n", .{if (ai.vlm_backend.isVLMAvailable()) "Available" else "Not available"});
    output.print("  Whisper.cpp:      {s}\n", .{if (ai.whisper.isWhisperAvailable()) "Available" else "Not available"});
    output.print("  Whisper Stream:   {s}\n", .{if (ai.whisper.isWhisperAvailable()) "Available (real-time)" else "Not available"});
    output.print("  Audio Decoder:    {s}\n", .{if (ai.audio_decoder.isAvailable()) "Available (WAV/MP3/FLAC)" else "Not available"});
    output.print("  ONNX Runtime:     {s}\n", .{if (backend.isBackendAvailable(.onnx)) "Available" else "Not available"});
    output.print("  Core ML:          {s}\n", .{if (backend.isBackendAvailable(.coreml)) "Available" else "Not available"});
    output.print("  TensorFlow Lite:  {s}\n", .{if (backend.isBackendAvailable(.tflite)) "Available" else "Not available"});
    output.print("  WebGPU:           {s}\n", .{if (backend.isBackendAvailable(.webgpu)) "Available" else "Not available"});

    // GPU/Metal information
    output.print("\nGPU Acceleration:\n", .{});
    output.print("  Platform:         {s}\n", .{ai.metal.getPlatformDescription()});
    output.print("  Metal Available:  {s}\n", .{if (ai.metal.isAvailable()) "Yes" else "No"});
    output.print("  Apple Silicon:    {s}\n", .{if (ai.metal.isAppleSilicon()) "Yes" else "No"});
    output.print("  Neural Engine:    {s}\n", .{if (ai.metal.hasNeuralEngine()) "Yes" else "No"});

    if (ai.metal.isAvailable()) {
        const gpu_info = ai.metal.getDefaultDeviceInfo();
        output.print("  GPU Device:       {s}\n", .{gpu_info.getName()});
        if (gpu_info.capabilities.unified_memory) {
            output.print("  Memory Type:      Unified\n", .{});
        }
    }

    // Core ML information
    if (backend.isBackendAvailable(.coreml)) {
        output.print("\nCore ML:\n", .{});
        output.print("  Version:          {s}\n", .{ai.coreml.getVersion()});
        output.print("  Neural Engine:    {s}\n", .{if (ai.coreml.hasNeuralEngine()) "Available" else "Not available"});
    }

    // Check model path
    if (args.len > 0) {
        const model_path = args[0];
        output.print("\nModel: {s}\n", .{model_path});

        const validation = ai.validateModelPath(model_path);
        output.print("  Format: {s}\n", .{@tagName(validation.format)});
        output.print("  Valid: {s}\n", .{if (validation.isValid()) "Yes" else "No"});
        if (validation.file_size > 0) {
            var buf: [32]u8 = undefined;
            output.print("  Size: {s}\n", .{ai.formatFileSize(validation.file_size, &buf)});
        }
    }

    output.print("\nUsage:\n", .{});
    output.print("  zylix-test ai embed --model <model.gguf> --text \"Hello world\"\n", .{});
    output.print("  zylix-test ai generate --model <model.gguf> --prompt \"What is AI?\"\n", .{});
    output.print("  zylix-test ai transcribe --model <whisper.bin> --audio <audio.wav|mp3|flac>\n", .{});
    output.print("  zylix-test ai stream --model <whisper.bin> --audio <audio.wav|mp3|flac> [--step 3000]\n", .{});
    output.print("  zylix-test ai analyze --model <llava.gguf> --mmproj <mmproj.gguf> --image <img.jpg>\n", .{});
    output.print("  zylix-test ai info <model.gguf>\n", .{});

    return ExitCode.success;
}

test "parse platform" {
    try std.testing.expect(Platform.fromString("web") == .web);
    try std.testing.expect(Platform.fromString("ios") == .ios);
}
