// Zylix Test Framework - Basic Test Example
// Demonstrates fundamental test patterns and assertions

const std = @import("std");
const zylix = @import("zylix_test");

// ============================================================================
// Example 1: Simple Element Interaction Test
// ============================================================================

/// Basic test demonstrating element finding and interaction
pub fn testLoginFlow(ctx: *zylix.TestContext) !void {
    ctx.log("Starting login flow test", .{});

    // Create a selector for the email input
    const email_selector = zylix.byTestId("email-input");
    _ = email_selector;

    // Create a selector for the password input
    const password_selector = zylix.byText("Password");
    _ = password_selector;

    // Create a selector by accessibility ID
    const login_button = zylix.byAccessibilityId("login-submit");
    _ = login_button;

    ctx.log("Login flow test completed", .{});
}

// ============================================================================
// Example 2: Using Assertions
// ============================================================================

/// Demonstrates various assertion patterns
pub fn testAssertions() !void {
    const allocator = std.testing.allocator;

    // Basic value expectations
    const value: i32 = 42;
    try zylix.expect(value == 42);

    // String expectations
    const greeting = "Hello, World!";
    var string_exp = zylix.expectString(greeting);
    try string_exp.toContain("World");
    try string_exp.toStartWith("Hello");
    try string_exp.toEndWith("!");

    _ = allocator;
}

// ============================================================================
// Example 3: Selector Building
// ============================================================================

/// Demonstrates the selector builder pattern
pub fn testSelectorBuilder() !void {
    const allocator = std.testing.allocator;

    // Build a complex selector
    var builder = zylix.SelectorBuilder.init();
    const selector = builder
        .withTestId("submit-button")
        .withText("Submit")
        .withIndex(0)
        .visible()
        .enabled()
        .build();

    // Selector is ready to use
    _ = selector.test_id;
    _ = allocator;
}

// ============================================================================
// Example 4: XPath Selectors
// ============================================================================

/// Demonstrates XPath selector usage
pub fn testXPathSelector() !void {
    const allocator = std.testing.allocator;

    // Create XPath selector
    var xpath = zylix.XPathSelector.init(allocator);
    defer xpath.deinit();

    // Build XPath expression
    try xpath.descendant("button");
    try xpath.withAttribute("type", "submit");
    try xpath.withText("Login");

    const expr = try xpath.build();
    _ = expr;
}

// ============================================================================
// Example 5: Test Retry Configuration
// ============================================================================

/// Demonstrates retry configuration for flaky tests
pub fn testWithRetry() !void {
    // Configure retry behavior
    const retry_config = zylix.RetryConfig{
        .max_retries = 3,
        .strategy = .exponential,
        .initial_delay_ms = 100,
        .max_delay_ms = 5000,
        .multiplier = 2.0,
        .jitter = 0.1,
    };

    var executor = zylix.RetryExecutor.init(retry_config);
    _ = executor.getStats();
}

// ============================================================================
// Example 6: Performance Metrics Collection
// ============================================================================

/// Demonstrates metrics collection
pub fn testMetricsCollection() !void {
    const allocator = std.testing.allocator;

    var tracker = try zylix.PerformanceTracker.init(allocator);
    defer tracker.deinit();

    // Record test results
    try tracker.recordTest(true, false); // passed
    try tracker.recordTest(true, false); // passed
    try tracker.recordTest(false, false); // failed

    // Get performance summary
    const summary = try tracker.getSummary();
    _ = summary.total_tests;
    _ = summary.passed_tests;
    _ = summary.avg_duration_ms;
}

// ============================================================================
// Example 7: Visual Testing Configuration
// ============================================================================

/// Demonstrates visual testing setup
pub fn testVisualConfig() !void {
    // Configure visual testing
    const visual_config = zylix.VisualConfig{
        .algorithm = .ssim,
        .threshold = 0.95,
        .fail_on_missing_baseline = false,
        .update_baselines = false,
        .ignore_colors = false,
        .ignore_antialiasing = true,
        .mask_regions = &.{},
    };

    _ = visual_config.algorithm;
}

// ============================================================================
// Unit Tests
// ============================================================================

test "selector creation" {
    const sel = zylix.byTestId("my-element");
    try std.testing.expect(sel.test_id != null);
    try std.testing.expectEqualStrings("my-element", sel.test_id.?);
}

test "text selector" {
    const sel = zylix.byText("Click me");
    try std.testing.expect(sel.text != null);
    try std.testing.expectEqualStrings("Click me", sel.text.?);
}

test "accessibility selector" {
    const sel = zylix.byAccessibilityId("submit-btn");
    try std.testing.expect(sel.accessibility_id != null);
}

test "retry config defaults" {
    const config = zylix.RetryConfig{};
    try std.testing.expectEqual(@as(u32, 3), config.max_retries);
    try std.testing.expectEqual(zylix.RetryStrategy.exponential, config.strategy);
}

test "parallel config defaults" {
    const config = zylix.ParallelConfig{};
    try std.testing.expectEqual(@as(u32, 0), config.worker_count);
    try std.testing.expect(config.work_stealing);
}
