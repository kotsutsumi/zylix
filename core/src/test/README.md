# Zylix Test Framework

A unified E2E testing framework for all 6 platforms: iOS, Android, macOS, Windows, Linux, and Web.

## Features

- **Cross-Platform Testing**: Single API for all platforms
- **Parallel Execution**: Multi-threaded test execution with work stealing
- **Visual Testing**: Multiple comparison algorithms (pixel, SSIM, perceptual hash)
- **Comprehensive Reporting**: JUnit XML, HTML, JSON, Markdown formats
- **Flaky Test Handling**: Auto-detection and quarantine
- **Performance Metrics**: Prometheus and JSON export
- **CI/CD Integration**: Test sharding and parallel job support

## Quick Start

```zig
const zylix = @import("zylix_test");

test "user can login" {
    const allocator = std.testing.allocator;

    // Launch application
    var driver = try zylix.createWebDriver(.{
        .browser = .chrome,
        .headless = true,
    }, allocator);

    var app = try zylix.launch(&driver, .{
        .app_id = "https://example.com",
        .platform = .web,
    }, allocator);
    defer app.terminate() catch {};

    // Find and interact with elements
    try app.findByTestId("email-input").typeText("user@example.com");
    try app.findByTestId("password-input").typeText("password123");
    try app.findByTestId("login-button").tap();

    // Wait and assert
    const welcome = try app.waitForText("Welcome", 5000);
    try zylix.expectElement(&welcome).toBeVisible();
}
```

## Platform Configuration

### Web Testing

```zig
const config = zylix.WebDriverConfig{
    .browser = .chrome,      // chrome, firefox, safari, edge
    .headless = true,
    .viewport_width = 1920,
    .viewport_height = 1080,
    .timeout_ms = 30000,
};
```

### iOS Testing

```zig
const config = zylix.IOSDriverConfig{
    .bundle_id = "com.example.myapp",
    .platform_version = "17.0",
    .automation_name = "XCUITest",
    .wda_local_port = 8100,
};
```

### Android Testing

```zig
const config = zylix.AndroidDriverConfig{
    .package_name = "com.example.myapp",
    .activity_name = ".MainActivity",
    .platform_version = "14",
    .automation_name = "UiAutomator2",
};
```

### macOS Testing

```zig
const config = zylix.MacOSDriverConfig{
    .bundle_id = "com.example.MacApp",
    .app_path = "/Applications/MyApp.app",
    .accessibility_enabled = true,
};
```

### Windows Testing

```zig
const config = zylix.WindowsDriverConfig{
    .app_path = "C:\\Program Files\\MyApp\\MyApp.exe",
    .use_winappdriver = true,
    .winappdriver_url = "http://127.0.0.1:4723",
};
```

### Linux Testing

```zig
const config = zylix.LinuxDriverConfig{
    .app_path = "/usr/bin/myapp",
    .use_atspi = true,
    .display = ":0",
};
```

## Selectors

```zig
// By test ID (recommended)
const button = zylix.byTestId("submit-button");

// By text content
const label = zylix.byText("Login");

// By accessibility ID
const input = zylix.byAccessibilityId("email-field");

// Using selector builder
var builder = zylix.SelectorBuilder.init();
const selector = builder
    .withTestId("form")
    .withIndex(0)
    .visible()
    .enabled()
    .build();

// CSS selector (web only)
const css = zylix.Selector.css("button.primary");

// XPath selector
const xpath = zylix.Selector.xpath("//button[@type='submit']");
```

## Parallel Execution

```zig
var executor = zylix.ParallelExecutor.init(allocator, .{
    .worker_count = 0,      // Auto-detect CPUs
    .batch_size = 10,
    .work_stealing = true,
    .shuffle = true,
});
defer executor.deinit();

try executor.addTest(.{
    .id = 1,
    .name = "test_login",
    .suite = "auth",
    .func = &testLogin,
    .priority = 10,
    .retries = 2,
});

const results = try executor.execute();
```

## Visual Testing

```zig
var runner = zylix.VisualTestRunner.init(allocator, .{
    .algorithm = .ssim,      // pixel, ssim, perceptual_hash, histogram
    .threshold = 0.95,
    .ignore_antialiasing = true,
    .mask_regions = &.{
        .{ .x = 0, .y = 0, .width = 100, .height = 50 },
    },
});
defer runner.deinit();

const result = try runner.compare("homepage", screenshot_data, "baselines");
```

## Reporting

```zig
var reporter = zylix.Reporter.init(allocator, .{
    .format = .all,          // junit, html, json, markdown, console, all
    .output_dir = "test-results",
    .include_screenshots = true,
});
defer reporter.deinit();

try reporter.addResult(.{
    .name = "test_login",
    .suite = "auth",
    .status = .passed,
    .duration_ns = 1_500_000_000,
});

try reporter.generateReports();
```

## Retry and Flaky Test Handling

```zig
// Configure retry behavior
const config = zylix.RetryConfig{
    .max_retries = 3,
    .strategy = .exponential,
    .initial_delay_ms = 100,
    .max_delay_ms = 10000,
    .jitter = 0.1,
};

// Flaky test handler
var handler = zylix.FlakyHandler.init(allocator, .{
    .auto_quarantine = true,
    .quarantine_threshold = 3,
});
defer handler.deinit();

// Record results
try handler.recordResult("my_test", passed);

// Check flakiness
const score = handler.getFlakinessScore("my_test");
```

## Performance Metrics

```zig
var tracker = try zylix.PerformanceTracker.init(allocator);
defer tracker.deinit();

// Time tests
var timer = tracker.startTest();
// ... run test ...
try timer.stop();

// Record results
try tracker.recordTest(true, false);  // passed, not skipped

// Export metrics
const prometheus = try tracker.collector.exportPrometheus(allocator);
const json = try tracker.collector.exportJSON(allocator);
```

## Test Sharding (CI/CD)

```zig
// Configure for CI parallel jobs
const shard = zylix.TestShard.init(
    0,  // Current shard index (CI_NODE_INDEX)
    4   // Total shards (CI_NODE_TOTAL)
);

// Filter tests for this shard
const tests = try shard.filterTests(&all_tests, allocator);
```

## GitHub Actions Example

```yaml
jobs:
  test:
    strategy:
      matrix:
        shard: [0, 1, 2, 3]

    steps:
      - uses: actions/checkout@v4

      - name: Run tests
        env:
          CI_NODE_INDEX: ${{ matrix.shard }}
          CI_NODE_TOTAL: 4
        run: zig build test

      - name: Upload results
        uses: actions/upload-artifact@v4
        with:
          name: test-results-${{ matrix.shard }}
          path: test-results/
```

## Architecture

```
zylix_test.zig          # Main module entry point
├── selector.zig        # Element selectors and builders
├── driver.zig          # Platform driver interface
├── element.zig         # Element abstraction
├── app.zig             # Application lifecycle
├── assert.zig          # Assertions and expectations
├── screenshot.zig      # Screenshot capture
├── runner.zig          # Test runner
├── reporter.zig        # Multi-format reporting
├── parallel.zig        # Parallel execution
├── metrics.zig         # Performance metrics
├── retry.zig           # Retry and flaky handling
├── visual.zig          # Visual regression testing
├── web_driver.zig      # WebDriver (Selenium/Playwright)
├── ios_driver.zig      # iOS (XCUITest/Appium)
├── android_driver.zig  # Android (UiAutomator2/Appium)
├── macos_driver.zig    # macOS (XCTest)
├── windows_driver.zig  # Windows (WinAppDriver)
└── linux_driver.zig    # Linux (AT-SPI/Dogtail)
```

## API Reference

### Core Types

| Type | Description |
|------|-------------|
| `Selector` | Element locator specification |
| `Driver` | Platform driver interface |
| `Element` | UI element abstraction |
| `App` | Application lifecycle manager |
| `TestRunner` | Test execution orchestrator |
| `Reporter` | Test result reporter |

### Enums

| Enum | Values |
|------|--------|
| `Platform` | `ios`, `android`, `macos`, `windows`, `linux`, `web`, `auto` |
| `BrowserType` | `chrome`, `firefox`, `safari`, `edge` |
| `RetryStrategy` | `none`, `fixed`, `exponential`, `linear`, `immediate` |
| `CompareAlgorithm` | `pixel`, `perceptual_hash`, `ssim`, `feature`, `histogram` |
| `ReportFormat` | `junit`, `html`, `json`, `markdown`, `console`, `all` |

## Version

Current version: **0.9.0**

## License

MIT License
