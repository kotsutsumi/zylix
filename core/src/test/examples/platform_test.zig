// Zylix Test Framework - Platform-Specific Test Examples
// Demonstrates testing across iOS, Android, macOS, Windows, Linux, and Web

const std = @import("std");
const zylix = @import("zylix_test");

// ============================================================================
// Web Platform Testing
// ============================================================================

/// Web browser testing example
pub fn testWebApplication() !void {
    const allocator = std.testing.allocator;

    // Configure web driver
    const web_config = zylix.WebDriverConfig{
        .browser = .chrome,
        .headless = true,
        .viewport_width = 1920,
        .viewport_height = 1080,
        .user_agent = null,
        .proxy = null,
        .timeout_ms = 30000,
    };

    // Create web driver
    var driver = zylix.createWebDriver(web_config, allocator);
    _ = driver;
}

/// Web element interaction patterns
pub fn testWebInteractions() !void {
    // Selectors for web elements
    const button = zylix.Selector.css("button.primary");
    const input = zylix.Selector.css("input[type='email']");
    const link = zylix.Selector.xpath("//a[@href='/login']");

    _ = button;
    _ = input;
    _ = link;
}

// ============================================================================
// iOS Platform Testing
// ============================================================================

/// iOS application testing example
pub fn testIOSApplication() !void {
    const allocator = std.testing.allocator;

    // Configure iOS driver
    const ios_config = zylix.IOSDriverConfig{
        .device_id = null, // Use first available device
        .bundle_id = "com.example.myapp",
        .platform_version = "17.0",
        .automation_name = "XCUITest",
        .use_new_wda = false,
        .wda_local_port = 8100,
        .timeout_ms = 60000,
    };

    var driver = zylix.createIOSDriver(ios_config, allocator);
    _ = driver;
}

/// iOS-specific selectors
pub fn testIOSSelectors() !void {
    // iOS accessibility selectors
    const button = zylix.Selector.byAccessibilityId("loginButton");
    const label = zylix.Selector.byType(.static_text);
    const cell = zylix.Selector.predicate("type == 'XCUIElementTypeCell' AND name CONTAINS 'Item'");

    _ = button;
    _ = label;
    _ = cell;
}

// ============================================================================
// Android Platform Testing
// ============================================================================

/// Android application testing example
pub fn testAndroidApplication() !void {
    const allocator = std.testing.allocator;

    // Configure Android driver
    const android_config = zylix.AndroidDriverConfig{
        .device_id = null, // Use first available device
        .package_name = "com.example.myapp",
        .activity_name = ".MainActivity",
        .platform_version = "14",
        .automation_name = "UiAutomator2",
        .adb_exec_timeout = 20000,
        .timeout_ms = 60000,
    };

    var driver = zylix.createAndroidDriver(android_config, allocator);
    _ = driver;
}

/// Android-specific selectors
pub fn testAndroidSelectors() !void {
    // Android UI Automator selectors
    const button = zylix.Selector.uiAutomator("new UiSelector().resourceId(\"com.example:id/login_button\")");
    const text = zylix.Selector.byText("Welcome");
    const view = zylix.Selector.byType(.view);

    _ = button;
    _ = text;
    _ = view;
}

// ============================================================================
// macOS Platform Testing
// ============================================================================

/// macOS application testing example
pub fn testMacOSApplication() !void {
    const allocator = std.testing.allocator;

    // Configure macOS driver
    const macos_config = zylix.MacOSDriverConfig{
        .bundle_id = "com.example.MacApp",
        .app_path = "/Applications/MyApp.app",
        .launch_timeout_ms = 30000,
        .use_apple_script = true,
        .accessibility_enabled = true,
    };

    _ = macos_config;
    _ = allocator;
}

/// macOS accessibility selectors
pub fn testMacOSSelectors() !void {
    // macOS accessibility hierarchy
    const menu = zylix.Selector.byType(.menu);
    const window = zylix.Selector.byType(.window);
    const button = zylix.Selector.byAccessibilityId("closeButton");

    _ = menu;
    _ = window;
    _ = button;
}

// ============================================================================
// Windows Platform Testing
// ============================================================================

/// Windows application testing example
pub fn testWindowsApplication() !void {
    const allocator = std.testing.allocator;

    // Configure Windows driver
    const windows_config = zylix.WindowsDriverConfig{
        .app_path = "C:\\Program Files\\MyApp\\MyApp.exe",
        .app_arguments = "",
        .use_winappdriver = true,
        .winappdriver_url = "http://127.0.0.1:4723",
        .launch_timeout_ms = 30000,
    };

    _ = windows_config;
    _ = allocator;
}

/// Windows UI Automation selectors
pub fn testWindowsSelectors() !void {
    // Windows automation IDs
    const button = zylix.Selector.byAccessibilityId("btnSubmit");
    const textbox = zylix.Selector.byType(.edit);
    const window = zylix.Selector.byName("Main Window");

    _ = button;
    _ = textbox;
    _ = window;
}

// ============================================================================
// Linux Platform Testing
// ============================================================================

/// Linux application testing example
pub fn testLinuxApplication() !void {
    const allocator = std.testing.allocator;

    // Configure Linux driver
    const linux_config = zylix.LinuxDriverConfig{
        .app_path = "/usr/bin/myapp",
        .app_arguments = &.{},
        .desktop_file = null,
        .use_atspi = true,
        .use_dogtail = false,
        .display = ":0",
        .launch_timeout_ms = 30000,
    };

    _ = linux_config;
    _ = allocator;
}

/// Linux AT-SPI selectors
pub fn testLinuxSelectors() !void {
    // AT-SPI accessibility selectors
    const button = zylix.Selector.byRole("push button");
    const entry = zylix.Selector.byRole("text");
    const label = zylix.Selector.byName("Username:");

    _ = button;
    _ = entry;
    _ = label;
}

// ============================================================================
// Cross-Platform Testing
// ============================================================================

/// Demonstrates platform-agnostic testing
pub fn testCrossPlatform(platform: zylix.Platform) !void {
    // Create platform-appropriate selectors
    const login_button = switch (platform) {
        .web => zylix.Selector.css("button#login"),
        .ios => zylix.Selector.byAccessibilityId("loginButton"),
        .android => zylix.Selector.byTestId("login_button"),
        .macos, .windows, .linux => zylix.Selector.byAccessibilityId("btnLogin"),
    };

    _ = login_button;
}

/// Platform detection and configuration
pub fn testPlatformDetection() !void {
    // Detect current platform
    const platform = zylix.Platform.auto;

    // Platform-specific configuration
    const config = switch (platform) {
        .web => "WebDriver configuration",
        .ios => "XCUITest configuration",
        .android => "UiAutomator2 configuration",
        .macos => "XCTest configuration",
        .windows => "WinAppDriver configuration",
        .linux => "AT-SPI configuration",
        .auto => "Auto-detected configuration",
    };

    _ = config;
}

// ============================================================================
// Test Sharding for CI/CD
// ============================================================================

/// Demonstrates test sharding for parallel CI execution
pub fn testSharding() !void {
    const allocator = std.testing.allocator;

    // Configure sharding (e.g., for 4 CI runners)
    const shard = zylix.TestShard.init(0, 4); // Shard 0 of 4

    // Check if tests should run in this shard
    _ = shard.shouldRun(0); // true for shard 0
    _ = shard.shouldRun(1); // false for shard 0
    _ = shard.shouldRun(4); // true for shard 0 (4 % 4 == 0)

    _ = allocator;
}

// ============================================================================
// Unit Tests
// ============================================================================

test "platform enum values" {
    try std.testing.expectEqual(zylix.Platform.ios, .ios);
    try std.testing.expectEqual(zylix.Platform.android, .android);
    try std.testing.expectEqual(zylix.Platform.web, .web);
}

test "web driver config defaults" {
    const config = zylix.WebDriverConfig{};
    try std.testing.expectEqual(zylix.BrowserType.chrome, config.browser);
    try std.testing.expect(!config.headless);
}

test "test sharding distribution" {
    const shard0 = zylix.TestShard.init(0, 3);
    const shard1 = zylix.TestShard.init(1, 3);
    const shard2 = zylix.TestShard.init(2, 3);

    // Test 0 goes to shard 0
    try std.testing.expect(shard0.shouldRun(0));
    try std.testing.expect(!shard1.shouldRun(0));
    try std.testing.expect(!shard2.shouldRun(0));

    // Test 1 goes to shard 1
    try std.testing.expect(!shard0.shouldRun(1));
    try std.testing.expect(shard1.shouldRun(1));
    try std.testing.expect(!shard2.shouldRun(1));
}
