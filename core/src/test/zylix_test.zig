// Zylix Test Framework
// Unified E2E testing framework for all 6 platforms

//! Zylix Test Framework provides a unified API for end-to-end testing
//! across iOS, Android, macOS, Windows, Linux, and Web platforms.
//!
//! ## Quick Start
//!
//! ```zig
//! const zylix_test = @import("zylix_test");
//!
//! test "user can login" {
//!     var app = try zylix_test.App.launch(.{
//!         .app_id = "com.example.myapp",
//!         .platform = .auto,
//!     });
//!     defer app.terminate() catch {};
//!
//!     // Find and interact with elements
//!     try app.findByTestId("email-input").typeText("user@example.com");
//!     try app.findByTestId("password-input").typeText("password123");
//!     try app.findByTestId("login-button").tap();
//!
//!     // Wait and assert
//!     const welcome = try app.waitForText("Welcome", 5000);
//!     try zylix_test.expectElement(&welcome).toBeVisible();
//! }
//! ```

const std = @import("std");

// Re-export all public APIs
pub const selector = @import("selector.zig");
pub const driver = @import("driver.zig");
pub const element = @import("element.zig");
pub const app = @import("app.zig");
pub const assert = @import("assert.zig");
pub const screenshot = @import("screenshot.zig");
pub const runner = @import("runner.zig");

// Platform drivers
pub const web_driver = @import("web_driver.zig");
pub const ios_driver = @import("ios_driver.zig");
pub const android_driver = @import("android_driver.zig");
pub const macos_driver = @import("macos_driver.zig");
pub const windows_driver = @import("windows_driver.zig");
pub const linux_driver = @import("linux_driver.zig");

// Primary types
pub const Selector = selector.Selector;
pub const SelectorBuilder = selector.SelectorBuilder;
pub const XPathSelector = selector.XPathSelector;

pub const Driver = driver.Driver;
pub const DriverVTable = driver.DriverVTable;
pub const DriverError = driver.DriverError;
pub const DriverRegistry = driver.DriverRegistry;
pub const Platform = driver.Platform;
pub const AppConfig = driver.AppConfig;
pub const ElementHandle = driver.ElementHandle;
pub const Rect = driver.Rect;
pub const SwipeDirection = driver.SwipeDirection;
pub const ScrollDirection = driver.ScrollDirection;
pub const Screenshot = driver.Screenshot;
pub const CompareResult = driver.CompareResult;

pub const Element = element.Element;
pub const ElementList = element.ElementList;
pub const ElementQuery = element.ElementQuery;

pub const App = app.App;
pub const TestContext = app.TestContext;
pub const TestFixture = app.TestFixture;

pub const AssertionError = assert.AssertionError;
pub const AssertionResult = assert.AssertionResult;
pub const Expectation = assert.Expectation;
pub const StringExpectation = assert.StringExpectation;
pub const ElementExpectation = assert.ElementExpectation;

pub const CompareConfig = screenshot.CompareConfig;
pub const VisualTest = screenshot.VisualTest;

pub const TestRunner = runner.TestRunner;

// Web driver types
pub const WebDriverConfig = web_driver.WebDriverConfig;
pub const WebDriverContext = web_driver.WebDriverContext;
pub const BrowserType = web_driver.BrowserType;
pub const createWebDriver = web_driver.createWebDriver;

// iOS driver types
pub const IOSDriverConfig = ios_driver.IOSDriverConfig;
pub const IOSDriverContext = ios_driver.IOSDriverContext;
pub const createIOSDriver = ios_driver.createIOSDriver;

// Android driver types
pub const AndroidDriverConfig = android_driver.AndroidDriverConfig;
pub const AndroidDriverContext = android_driver.AndroidDriverContext;
pub const createAndroidDriver = android_driver.createAndroidDriver;

// macOS driver types
pub const MacOSDriverConfig = macos_driver.MacOSDriverConfig;
pub const MacOSDriver = macos_driver.MacOSDriver;

// Windows driver types
pub const WindowsDriverConfig = windows_driver.WindowsDriverConfig;
pub const WindowsDriver = windows_driver.WindowsDriver;

// Linux driver types
pub const LinuxDriverConfig = linux_driver.LinuxDriverConfig;
pub const LinuxDriver = linux_driver.LinuxDriver;

pub const TestSuite = runner.TestSuite;
pub const TestCase = runner.TestCase;
pub const TestResult = runner.TestResult;
pub const SuiteResult = runner.SuiteResult;
pub const TestStatus = runner.TestStatus;
pub const RunnerConfig = runner.RunnerConfig;
pub const OutputFormat = runner.OutputFormat;

// Convenience functions
pub const expect = assert.expect;
pub const expectString = assert.expectString;
pub const expectElement = assert.expectElement;

/// Create a new test runner with default configuration
pub fn createRunner(allocator: std.mem.Allocator) TestRunner {
    return TestRunner.init(allocator, .{});
}

/// Create a new test runner with custom configuration
pub fn createRunnerWithConfig(allocator: std.mem.Allocator, config: RunnerConfig) TestRunner {
    return TestRunner.init(allocator, config);
}

/// Create a selector by test ID
pub fn byTestId(id: []const u8) Selector {
    return Selector.byTestId(id);
}

/// Create a selector by text content
pub fn byText(text: []const u8) Selector {
    return Selector.byText(text);
}

/// Create a selector by accessibility ID
pub fn byAccessibilityId(id: []const u8) Selector {
    return Selector.byAccessibilityId(id);
}

/// Create a selector by component type
pub fn byType(comptime T: selector.ComponentType) Selector {
    return Selector.byType(T);
}

/// Launch application with configuration
pub fn launch(driver_instance: *Driver, config: AppConfig, allocator: std.mem.Allocator) DriverError!App {
    return App.launch(driver_instance, config, allocator);
}

/// Compare screenshots
pub fn compareScreenshots(actual: Screenshot, baseline_path: []const u8, allocator: std.mem.Allocator) DriverError!CompareResult {
    return screenshot.compare(actual, baseline_path, allocator);
}

/// Create visual test helper
pub fn visualTest(baseline_dir: []const u8, diff_dir: []const u8, allocator: std.mem.Allocator) VisualTest {
    return VisualTest.init(baseline_dir, diff_dir, allocator);
}

// Version info
pub const version = struct {
    pub const major = 0;
    pub const minor = 9;
    pub const patch = 0;
    pub const string = "0.9.0";
};

// Tests
test "zylix_test module" {
    // Test that all imports work
    _ = selector;
    _ = driver;
    _ = element;
    _ = app;
    _ = assert;
    _ = screenshot;
    _ = runner;
    _ = web_driver;
    _ = ios_driver;
    _ = android_driver;
    _ = macos_driver;
    _ = windows_driver;
    _ = linux_driver;
}

test "convenience functions" {
    const sel1 = byTestId("my-button");
    try std.testing.expect(sel1.test_id != null);

    const sel2 = byText("Hello");
    try std.testing.expect(sel2.text != null);

    const sel3 = byAccessibilityId("submit");
    try std.testing.expect(sel3.accessibility_id != null);
}

test "version info" {
    try std.testing.expectEqualStrings("0.9.0", version.string);
    try std.testing.expect(version.major == 0);
    try std.testing.expect(version.minor == 9);
}
