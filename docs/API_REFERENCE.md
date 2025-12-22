# Zylix Test Framework - API Reference

> **Version**: v0.8.0
> **Last Updated**: 2025-12-23

## Overview

This document provides a comprehensive API reference for the Zylix Test Framework, covering all platforms: iOS, watchOS, Android, macOS, Windows, Linux, and Web.

---

## Table of Contents

1. [Core Types](#core-types)
2. [Driver Interface](#driver-interface)
3. [Selector API](#selector-api)
4. [Element API](#element-api)
5. [Platform Drivers](#platform-drivers)
6. [E2E Test Framework](#e2e-test-framework)
7. [Build Commands](#build-commands)

---

## Core Types

### Platform Enum

```zig
pub const Platform = enum {
    ios,
    watchos,
    android,
    macos,
    windows,
    linux,
    web,
    auto,

    /// Check if platform is Apple mobile (iOS or watchOS)
    pub fn isAppleMobile(self: Platform) bool;
};
```

### CrownRotationDirection (watchOS)

```zig
pub const CrownRotationDirection = enum {
    up,
    down,
};
```

### SwipeDirection

```zig
pub const SwipeDirection = enum {
    up,
    down,
    left,
    right,
};
```

### DriverError

```zig
pub const DriverError = error{
    ConnectionFailed,
    SessionNotCreated,
    ElementNotFound,
    Timeout,
    CommandFailed,
    InvalidResponse,
    NotSupported,
};
```

---

## Driver Interface

### Base Driver Configuration

```zig
pub const DriverConfig = struct {
    host: []const u8 = "127.0.0.1",
    port: u16,
    timeout_ms: u32 = 30000,
    command_timeout_ms: u32 = 10000,
};
```

### iOS Driver Configuration

```zig
pub const IOSDriverConfig = struct {
    host: []const u8 = "127.0.0.1",
    port: u16 = 8100,
    device_udid: ?[]const u8 = null,
    bundle_id: ?[]const u8 = null,
    use_simulator: bool = true,
    simulator_type: SimulatorType = .iphone_15_pro,
    launch_timeout_ms: u32 = 30000,
    command_timeout_ms: u32 = 10000,

    // watchOS-specific
    is_watchos: bool = false,
    watchos_version: []const u8 = "11.0",
    companion_device_udid: ?[]const u8 = null,

    pub fn isWatchOS(self: *const Self) bool;
    pub fn platformVersion(self: *const Self) []const u8;
    pub fn platformName(self: *const Self) []const u8;
    pub fn simulatorName(self: *const Self) []const u8;
};
```

### SimulatorType (iOS/watchOS)

```zig
pub const SimulatorType = enum {
    // iPhone devices
    iphone_15,
    iphone_15_pro,
    iphone_15_pro_max,
    iphone_se,

    // iPad devices
    ipad_pro_11,
    ipad_pro_12_9,
    ipad_air,

    // Apple Watch devices (watchOS)
    apple_watch_series_9_41mm,
    apple_watch_series_9_45mm,
    apple_watch_series_10_42mm,
    apple_watch_series_10_46mm,
    apple_watch_ultra_2,
    apple_watch_se_40mm,
    apple_watch_se_44mm,
};
```

### Android Driver Configuration

```zig
pub const AndroidDriverConfig = struct {
    host: []const u8 = "127.0.0.1",
    port: u16 = 4723,
    device_id: ?[]const u8 = null,
    package_name: ?[]const u8 = null,
    activity_name: ?[]const u8 = null,
    platform_version: []const u8 = "14",
    automation_name: []const u8 = "UiAutomator2",
    command_timeout_ms: u32 = 10000,
};
```

### Web Driver Configuration

```zig
pub const WebDriverConfig = struct {
    host: []const u8 = "127.0.0.1",
    port: u16 = 9515,
    browser: BrowserType = .chrome,
    headless: bool = false,
    viewport_width: u16 = 1920,
    viewport_height: u16 = 1080,
    timeout_ms: u32 = 30000,
};

pub const BrowserType = enum {
    chrome,
    firefox,
    safari,
    edge,
};
```

---

## Selector API

### Selector Structure

```zig
pub const Selector = struct {
    test_id: ?[]const u8 = null,
    accessibility_id: ?[]const u8 = null,
    text: ?[]const u8 = null,
    text_contains: ?[]const u8 = null,
    xpath: ?[]const u8 = null,
    css: ?[]const u8 = null,
    class_chain: ?[]const u8 = null,
    predicate: ?[]const u8 = null,
    ui_automator: ?[]const u8 = null,

    // Factory methods
    pub fn byTestId(id: []const u8) Selector;
    pub fn byAccessibilityId(id: []const u8) Selector;
    pub fn byText(text: []const u8) Selector;
    pub fn byTextContains(text: []const u8) Selector;
    pub fn byXPath(xpath: []const u8) Selector;
    pub fn css(selector: []const u8) Selector;
    pub fn classChain(chain: []const u8) Selector;
    pub fn predicate(pred: []const u8) Selector;
    pub fn uiAutomator(selector: []const u8) Selector;
};
```

---

## Element API

### Element Actions

```zig
pub const Element = struct {
    /// Tap/click the element
    pub fn tap(self: *Element) DriverError!void;

    /// Double tap the element
    pub fn doubleTap(self: *Element) DriverError!void;

    /// Long press the element
    pub fn longPress(self: *Element, duration_ms: u32) DriverError!void;

    /// Type text into the element
    pub fn type(self: *Element, text: []const u8) DriverError!void;

    /// Clear the element's text
    pub fn clear(self: *Element) DriverError!void;

    /// Swipe on the element
    pub fn swipe(self: *Element, direction: SwipeDirection) DriverError!void;

    /// Check if element exists
    pub fn exists(self: *Element) bool;

    /// Check if element is visible
    pub fn isVisible(self: *Element) bool;

    /// Check if element is enabled
    pub fn isEnabled(self: *Element) bool;

    /// Get element's text content
    pub fn getText(self: *Element) DriverError![]const u8;

    /// Get element's attribute
    pub fn getAttribute(self: *Element, name: []const u8) DriverError![]const u8;

    /// Get element's bounding rectangle
    pub fn getRect(self: *Element) DriverError!Rect;
};

pub const Rect = struct {
    x: i32,
    y: i32,
    width: u32,
    height: u32,
};
```

---

## Platform Drivers

### iOS/watchOS Actions

```zig
// iOS-specific actions
pub fn tapAtCoordinates(ctx: *DriverContext, x: u32, y: u32) DriverError!void;
pub fn swipe(ctx: *DriverContext, start_x: u32, start_y: u32, end_x: u32, end_y: u32) DriverError!void;
pub fn takeScreenshot(ctx: *DriverContext) DriverError![]const u8;

// watchOS-specific actions
pub fn rotateDigitalCrown(ctx: *DriverContext, direction: CrownDirection, velocity: f32) DriverError!void;
pub fn pressSideButton(ctx: *DriverContext, duration_ms: u32) DriverError!void;
pub fn doublePresssSideButton(ctx: *DriverContext) DriverError!void;
pub fn getCompanionDeviceInfo(ctx: *DriverContext) DriverError!?[]const u8;
```

### Android Actions

```zig
pub fn pressBack(ctx: *DriverContext) DriverError!void;
pub fn pressHome(ctx: *DriverContext) DriverError!void;
pub fn pressRecentApps(ctx: *DriverContext) DriverError!void;
pub fn getSource(ctx: *DriverContext) DriverError![]const u8;
pub fn takeScreenshot(ctx: *DriverContext) DriverError![]const u8;
```

### Web Actions

```zig
pub fn navigateTo(ctx: *DriverContext, url: []const u8) DriverError!void;
pub fn getTitle(ctx: *DriverContext) DriverError![]const u8;
pub fn getUrl(ctx: *DriverContext) DriverError![]const u8;
pub fn executeScript(ctx: *DriverContext, script: []const u8) DriverError![]const u8;
pub fn takeScreenshot(ctx: *DriverContext) DriverError![]const u8;
```

---

## E2E Test Framework

### E2E Configuration

```zig
pub const E2EConfig = struct {
    skip_unavailable: bool = true,
    connection_timeout_ms: u32 = 5000,
    command_timeout_ms: u32 = 30000,
    retry_count: u8 = 3,
    verbose: bool = false,
};
```

### Production Ports

```zig
pub const ProductionPorts = struct {
    pub const web: u16 = 9515;       // ChromeDriver/Playwright
    pub const ios: u16 = 8100;       // WebDriverAgent
    pub const android: u16 = 4723;   // Appium/UIAutomator2
    pub const macos: u16 = 8200;     // Accessibility bridge
    pub const linux: u16 = 8300;     // AT-SPI bridge
    pub const windows: u16 = 4723;   // WinAppDriver
};
```

### Test Ports (for Mock Servers)

```zig
pub const TestPorts = struct {
    pub const web: u16 = 19515;
    pub const ios: u16 = 18100;
    pub const watchos: u16 = 18101;
    pub const android: u16 = 16790;
    pub const macos: u16 = 18200;
    pub const linux: u16 = 18300;
};
```

### Helper Functions

```zig
/// Check if a server is available
pub fn isServerAvailable(host: []const u8, port: u16, timeout_ms: u32) bool;

/// Send HTTP request and get response
pub fn sendHttpRequest(
    allocator: std.mem.Allocator,
    host: []const u8,
    port: u16,
    method: []const u8,
    path: []const u8,
    body: ?[]const u8,
) ![]u8;

/// Parse session ID from JSON response
pub fn parseSessionId(response: []const u8) ?[]const u8;

/// Parse status code from JSON response
pub fn parseStatus(response: []const u8) ?i32;
```

### E2E Test Runner

```zig
pub const E2ERunner = struct {
    pub fn init(allocator: std.mem.Allocator, config: E2EConfig) E2ERunner;
    pub fn deinit(self: *E2ERunner) void;
    pub fn addResult(self: *E2ERunner, result: TestResult) !void;
    pub fn printSummary(self: *E2ERunner) void;
};

pub const TestResult = struct {
    name: []const u8,
    passed: bool,
    skipped: bool,
    duration_ms: u64,
    error_message: ?[]const u8,
};
```

---

## Build Commands

### Unit Tests

```bash
cd core
zig build test                # Run unit tests
```

### Integration Tests

```bash
cd core
zig build test-integration    # Run integration tests (with mock servers)
```

### E2E Tests

```bash
cd core
zig build test-e2e            # Run E2E tests (requires running bridge servers)
```

### All Tests

```bash
cd core
zig build test-all            # Run unit + integration tests
zig build test-everything     # Run all tests including E2E
```

### Cross-Compilation

```bash
cd core

# iOS
zig build ios                 # iOS arm64
zig build ios-sim             # iOS Simulator arm64

# Android
zig build android             # All ABIs
zig build android-arm64       # arm64-v8a only
zig build android-x64         # x86_64 only

# macOS
zig build macos-arm64         # Apple Silicon
zig build macos-x64           # Intel

# Windows
zig build windows-x64         # x86_64
zig build windows-arm64       # ARM64

# Linux
zig build linux-x64           # x86_64
zig build linux-arm64         # ARM64

# WebAssembly
zig build wasm                # WASM32

# All platforms
zig build all                 # Build for all platforms
```

---

## WebDriver Protocol Endpoints

### Session Management

| Method | Path | Description |
|--------|------|-------------|
| POST | /session | Create new session |
| DELETE | /session/{id} | Delete session |
| GET | /status | Get server status |

### Element Operations

| Method | Path | Description |
|--------|------|-------------|
| POST | /session/{id}/element | Find element |
| POST | /session/{id}/elements | Find elements |
| POST | /session/{id}/element/{eid}/click | Click element |
| POST | /session/{id}/element/{eid}/value | Send keys |
| GET | /session/{id}/element/{eid}/text | Get text |
| GET | /session/{id}/element/{eid}/displayed | Check visibility |
| GET | /session/{id}/element/{eid}/enabled | Check enabled |
| GET | /session/{id}/element/{eid}/rect | Get bounding rect |

### Platform-Specific Endpoints

#### iOS/watchOS (WebDriverAgent)

| Method | Path | Description |
|--------|------|-------------|
| POST | /session/{id}/wda/tap/0 | Tap at coordinates |
| POST | /session/{id}/wda/dragfromtoforduration | Swipe |
| POST | /session/{id}/wda/digitalCrown/rotate | Rotate Digital Crown |
| POST | /session/{id}/wda/sideButton/press | Press Side Button |
| POST | /session/{id}/wda/sideButton/doublePress | Double-press Side Button |
| GET | /session/{id}/wda/companion/info | Get companion device info |
| GET | /session/{id}/source | Get UI hierarchy |
| GET | /session/{id}/screenshot | Take screenshot |

#### Android (UIAutomator2)

| Method | Path | Description |
|--------|------|-------------|
| POST | /session/{id}/back | Press back button |
| GET | /session/{id}/source | Get UI hierarchy |
| GET | /session/{id}/screenshot | Take screenshot |

#### Web (WebDriver)

| Method | Path | Description |
|--------|------|-------------|
| POST | /session/{id}/url | Navigate to URL |
| GET | /session/{id}/url | Get current URL |
| GET | /session/{id}/title | Get page title |
| POST | /session/{id}/execute/sync | Execute JavaScript |
| GET | /session/{id}/screenshot | Take screenshot |

---

## Error Handling

### Error Response Format

```json
{
    "status": 7,
    "value": {
        "error": "no such element",
        "message": "An element could not be located on the page using the given search parameters.",
        "stacktrace": "..."
    }
}
```

### Common Status Codes

| Code | Name | Description |
|------|------|-------------|
| 0 | Success | Command completed successfully |
| 6 | NoSuchDriver | Session does not exist |
| 7 | NoSuchElement | Element not found |
| 11 | ElementNotVisible | Element is not visible |
| 12 | InvalidElementState | Element state prevents interaction |
| 13 | UnknownError | Unknown server error |
| 21 | Timeout | Operation timed out |

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 0.8.0 | 2025-12-23 | Added watchOS support, E2E test framework |
| 0.7.0 | 2025-12 | Initial test framework release |
