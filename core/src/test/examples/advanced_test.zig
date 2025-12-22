// Zylix Test Framework - Advanced Testing Patterns
// Demonstrates parallel execution, visual testing, and CI/CD integration

const std = @import("std");
const zylix = @import("zylix_test");

// ============================================================================
// Parallel Test Execution
// ============================================================================

/// Configure and run tests in parallel
pub fn testParallelExecution() !void {
    const allocator = std.testing.allocator;

    // Configure parallel execution
    const parallel_config = zylix.ParallelConfig{
        .worker_count = 0, // Auto-detect CPU count
        .batch_size = 10,
        .test_timeout_ms = 60000,
        .work_stealing = true,
        .isolate = false,
        .shuffle = true,
        .seed = 0, // Random seed
    };

    var executor = zylix.ParallelExecutor.init(allocator, parallel_config);
    defer executor.deinit();

    // Add tests to the queue
    try executor.addTest(.{
        .id = 1,
        .name = "test_login",
        .suite = "auth",
        .func = &dummyTest,
        .priority = 10, // Higher priority runs first
        .timeout_ms = 30000,
        .retries = 2,
        .tags = &.{ "smoke", "critical" },
    });

    try executor.addTest(.{
        .id = 2,
        .name = "test_registration",
        .suite = "auth",
        .func = &dummyTest,
        .priority = 5,
        .timeout_ms = 30000,
        .retries = 1,
        .tags = &.{"regression"},
    });

    // Execute all tests
    const results = try executor.execute();
    _ = results;
}

fn dummyTest(_: *zylix.parallel.TestContext) anyerror!void {
    // Test implementation
}

// ============================================================================
// Visual Regression Testing
// ============================================================================

/// Configure visual testing with baselines
pub fn testVisualRegression() !void {
    const allocator = std.testing.allocator;

    // Configure visual testing
    var runner = zylix.VisualTestRunner.init(allocator, .{
        .algorithm = .ssim,
        .threshold = 0.95,
        .fail_on_missing_baseline = false,
        .update_baselines = false,
        .ignore_colors = false,
        .ignore_antialiasing = true,
        .mask_regions = &.{
            // Ignore dynamic content areas
            .{ .x = 0, .y = 0, .width = 100, .height = 50 }, // Header with timestamp
        },
    });
    defer runner.deinit();
}

/// Different comparison algorithms
pub fn testComparisonAlgorithms() !void {
    // Pixel-by-pixel comparison (fastest, most strict)
    const pixel_config = zylix.VisualConfig{
        .algorithm = .pixel,
        .threshold = 0.99, // 99% match required
    };

    // Perceptual hash (fast, handles minor variations)
    const phash_config = zylix.VisualConfig{
        .algorithm = .perceptual_hash,
        .threshold = 0.90,
    };

    // SSIM (balanced accuracy and tolerance)
    const ssim_config = zylix.VisualConfig{
        .algorithm = .ssim,
        .threshold = 0.95,
    };

    // Histogram comparison (color distribution)
    const histogram_config = zylix.VisualConfig{
        .algorithm = .histogram,
        .threshold = 0.85,
    };

    _ = pixel_config;
    _ = phash_config;
    _ = ssim_config;
    _ = histogram_config;
}

// ============================================================================
// Test Reporting
// ============================================================================

/// Configure multi-format test reporting
pub fn testReporting() !void {
    const allocator = std.testing.allocator;

    var reporter = zylix.Reporter.init(allocator, .{
        .format = .all,
        .output_dir = "test-results",
        .include_screenshots = true,
        .include_console_output = true,
        .include_timing = true,
        .suite_name = "E2E Tests",
        .environment = "CI",
    });
    defer reporter.deinit();

    // Record test results
    try reporter.addResult(.{
        .name = "test_login",
        .suite = "auth",
        .status = .passed,
        .duration_ns = 1_500_000_000, // 1.5 seconds
        .message = null,
        .stdout = "Login successful",
        .stderr = null,
        .screenshot = null,
    });

    try reporter.addResult(.{
        .name = "test_invalid_login",
        .suite = "auth",
        .status = .failed,
        .duration_ns = 500_000_000,
        .message = "Expected error message not displayed",
        .stdout = null,
        .stderr = "AssertionError at auth_test.zig:45",
        .screenshot = null,
    });

    // Generate all report formats
    try reporter.generateReports();
}

// ============================================================================
// Metrics and Performance Tracking
// ============================================================================

/// Track test performance over time
pub fn testPerformanceTracking() !void {
    const allocator = std.testing.allocator;

    var collector = zylix.MetricsCollector.init(allocator);
    defer collector.deinit();

    // Register custom metrics
    _ = try collector.register("api_response_time", "API response time", .histogram, "ms");
    _ = try collector.register("page_load_time", "Page load time", .histogram, "ms");
    _ = try collector.register("memory_usage", "Memory usage", .gauge, "bytes");
    _ = try collector.register("test_count", "Tests executed", .counter, "count");

    // Record values
    try collector.record("api_response_time", 150.0);
    try collector.record("api_response_time", 180.0);
    try collector.record("api_response_time", 120.0);
    try collector.record("page_load_time", 2500.0);
    try collector.record("memory_usage", 1024 * 1024 * 50); // 50MB
    try collector.increment("test_count");

    // Export to Prometheus format
    const prometheus_output = try collector.exportPrometheus(allocator);
    defer allocator.free(prometheus_output);

    // Export to JSON format
    const json_output = try collector.exportJSON(allocator);
    defer allocator.free(json_output);
}

/// Use timer for precise measurements
pub fn testTimerUsage() !void {
    const allocator = std.testing.allocator;

    var tracker = try zylix.PerformanceTracker.init(allocator);
    defer tracker.deinit();

    // Time a test execution
    var timer = tracker.startTest();

    // Simulate test execution
    std.time.sleep(10 * std.time.ns_per_ms);

    // Stop timer and record
    try timer.stop();

    // Get elapsed time
    const elapsed = timer.elapsedMs();
    _ = elapsed;

    // Get summary
    const summary = try tracker.getSummary();
    _ = summary;
}

// ============================================================================
// Flaky Test Detection
// ============================================================================

/// Detect and manage flaky tests
pub fn testFlakyDetection() !void {
    const allocator = std.testing.allocator;

    var handler = zylix.FlakyHandler.init(allocator, .{
        .auto_quarantine = true,
        .quarantine_threshold = 3, // Quarantine after 3 consecutive failures
        .auto_unquarantine = true,
        .unquarantine_threshold = 5, // Remove from quarantine after 5 passes
        .flakiness_threshold = 0.3,
    });
    defer handler.deinit();

    // Record test history
    try handler.recordResult("flaky_test", true); // pass
    try handler.recordResult("flaky_test", false); // fail
    try handler.recordResult("flaky_test", true); // pass
    try handler.recordResult("flaky_test", false); // fail
    try handler.recordResult("flaky_test", true); // pass

    // Check flakiness
    const score = handler.getFlakinessScore("flaky_test");
    _ = score;

    // Get all flaky tests
    const flaky_tests = try handler.getFlakyTests(0.3, allocator);
    defer allocator.free(flaky_tests);

    // Check quarantine status
    const is_quarantined = handler.isQuarantined("flaky_test");
    _ = is_quarantined;
}

// ============================================================================
// CI/CD Integration Patterns
// ============================================================================

/// GitHub Actions integration example
pub fn testGitHubActionsIntegration() !void {
    const allocator = std.testing.allocator;

    // Parse environment variables for CI
    const ci_env = struct {
        github_actions: bool = false,
        github_run_id: ?[]const u8 = null,
        github_sha: ?[]const u8 = null,
        github_ref: ?[]const u8 = null,
    }{};

    // Configure reporter for CI
    var reporter = zylix.Reporter.init(allocator, .{
        .format = .junit, // JUnit XML for CI parsing
        .output_dir = "test-results",
        .suite_name = if (ci_env.github_run_id) |id| id else "Local",
        .environment = if (ci_env.github_actions) "github-actions" else "local",
    });
    defer reporter.deinit();
}

/// Test sharding for parallel CI jobs
pub fn testCISharding() !void {
    const allocator = std.testing.allocator;

    // Read shard configuration from environment
    // CI_NODE_INDEX and CI_NODE_TOTAL are common CI variables
    const shard_index: u32 = 0; // std.process.getEnvVarOwned("CI_NODE_INDEX")
    const total_shards: u32 = 4; // std.process.getEnvVarOwned("CI_NODE_TOTAL")

    const shard = zylix.TestShard.init(shard_index, total_shards);

    // Filter tests for this shard
    const all_tests = [_]zylix.TestTask{
        .{ .id = 0, .name = "test_1", .suite = "suite", .func = &dummyTest },
        .{ .id = 1, .name = "test_2", .suite = "suite", .func = &dummyTest },
        .{ .id = 2, .name = "test_3", .suite = "suite", .func = &dummyTest },
        .{ .id = 3, .name = "test_4", .suite = "suite", .func = &dummyTest },
    };

    const shard_tests = try shard.filterTests(&all_tests, allocator);
    defer allocator.free(shard_tests);
}

// ============================================================================
// Custom Retry Strategies
// ============================================================================

/// Configure custom retry behavior
pub fn testCustomRetryStrategies() !void {
    // Exponential backoff with jitter
    const exponential_config = zylix.RetryConfig{
        .max_retries = 5,
        .strategy = .exponential,
        .initial_delay_ms = 100,
        .max_delay_ms = 30000,
        .multiplier = 2.0,
        .jitter = 0.2, // 20% randomness
    };

    // Linear backoff
    const linear_config = zylix.RetryConfig{
        .max_retries = 3,
        .strategy = .linear,
        .initial_delay_ms = 500,
        .max_delay_ms = 5000,
        .multiplier = 1.5,
    };

    // Fixed delay
    const fixed_config = zylix.RetryConfig{
        .max_retries = 3,
        .strategy = .fixed,
        .initial_delay_ms = 1000,
    };

    // Immediate retry (no delay)
    const immediate_config = zylix.RetryConfig{
        .max_retries = 2,
        .strategy = .immediate,
    };

    _ = exponential_config;
    _ = linear_config;
    _ = fixed_config;
    _ = immediate_config;
}

// ============================================================================
// Test Suite Organization
// ============================================================================

/// Organize tests into suites and categories
pub fn testSuiteOrganization() !void {
    const allocator = std.testing.allocator;

    var runner = zylix.TestRunner.init(allocator, .{
        .parallel = true,
        .timeout_ms = 300000,
        .retry_count = 2,
        .output_format = .all,
        .capture_screenshots = true,
        .fail_fast = false,
    });
    defer runner.deinit();

    // Add test suites
    try runner.addSuite(.{
        .name = "Authentication",
        .setup = null,
        .teardown = null,
        .tests = &.{
            .{ .name = "login", .func = &dummyTestCase, .tags = &.{ "smoke", "critical" } },
            .{ .name = "logout", .func = &dummyTestCase, .tags = &.{"smoke"} },
            .{ .name = "password_reset", .func = &dummyTestCase, .tags = &.{"regression"} },
        },
    });

    try runner.addSuite(.{
        .name = "Dashboard",
        .setup = null,
        .teardown = null,
        .tests = &.{
            .{ .name = "load_widgets", .func = &dummyTestCase, .tags = &.{"smoke"} },
            .{ .name = "filter_data", .func = &dummyTestCase, .tags = &.{"regression"} },
        },
    });
}

fn dummyTestCase(_: *zylix.TestContext) anyerror!void {
    // Test implementation
}

// ============================================================================
// Unit Tests
// ============================================================================

test "parallel config" {
    const config = zylix.ParallelConfig{
        .worker_count = 4,
        .work_stealing = true,
    };
    try std.testing.expectEqual(@as(u32, 4), config.worker_count);
}

test "retry strategies" {
    try std.testing.expectEqual(zylix.RetryStrategy.exponential, .exponential);
    try std.testing.expectEqual(zylix.RetryStrategy.linear, .linear);
    try std.testing.expectEqual(zylix.RetryStrategy.fixed, .fixed);
    try std.testing.expectEqual(zylix.RetryStrategy.immediate, .immediate);
}

test "visual algorithms" {
    try std.testing.expectEqual(zylix.CompareAlgorithm.pixel, .pixel);
    try std.testing.expectEqual(zylix.CompareAlgorithm.ssim, .ssim);
    try std.testing.expectEqual(zylix.CompareAlgorithm.perceptual_hash, .perceptual_hash);
    try std.testing.expectEqual(zylix.CompareAlgorithm.histogram, .histogram);
}

test "report formats" {
    try std.testing.expectEqual(zylix.ReportFormat.junit, .junit);
    try std.testing.expectEqual(zylix.ReportFormat.html, .html);
    try std.testing.expectEqual(zylix.ReportFormat.json, .json);
    try std.testing.expectEqual(zylix.ReportFormat.markdown, .markdown);
}
