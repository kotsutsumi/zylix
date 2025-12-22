# Zylix Test Framework - Demo Suite

> **Version**: v0.8.0 | **Last Updated**: 2025-12-23

Cross-platform E2E test examples demonstrating the Zylix Test Framework capabilities.

## Overview

This directory contains working test examples for each supported platform:

| Platform | Directory | Bridge Server | Status |
|----------|-----------|---------------|--------|
| Web | `web/` | ChromeDriver | Ready |
| iOS | `ios/` | WebDriverAgent | Ready |
| watchOS | `watchos/` | WebDriverAgent | Ready |
| Android | `android/` | UIAutomator2 | Ready |
| macOS | `macos/` | Accessibility Bridge | Ready |

## Quick Start

### Prerequisites

1. **Zig 0.15.0+** - Core test framework
2. **Platform-specific bridge servers** - See individual platform READMEs

### Run All Tests

```bash
cd core
zig build test-e2e
```

### Run Platform-Specific Tests

```bash
# Web (requires ChromeDriver on port 9515)
cd samples/test-demos/web && npm test

# iOS (requires WebDriverAgent on port 8100)
cd samples/test-demos/ios && swift test

# Android (requires Appium on port 4723)
cd samples/test-demos/android && ./gradlew test
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Zylix Test Framework                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │   Web    │  │   iOS    │  │ watchOS  │  │ Android  │    │
│  │  Tests   │  │  Tests   │  │  Tests   │  │  Tests   │    │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘    │
│       │             │             │             │           │
│       ▼             ▼             ▼             ▼           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │ChromeDrv │  │   WDA    │  │   WDA    │  │ Appium/  │    │
│  │ :9515    │  │  :8100   │  │  :8100   │  │ UIA2     │    │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘    │
│       │             │             │             │           │
│       ▼             ▼             ▼             ▼           │
│   Browser       Simulator      Simulator       Emulator    │
│                   /Device        /Device        /Device     │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Platform Demos

### Web (`web/`)
- Session lifecycle management
- Element finding (CSS, XPath, ID)
- Navigation and screenshots
- Form interaction

### iOS (`ios/`)
- App launch and teardown
- Touch gestures (tap, swipe, long press)
- Accessibility ID selectors
- Screenshot capture

### watchOS (`watchos/`)
- Digital Crown rotation
- Side Button interactions
- Companion device pairing
- Small screen element finding

### Android (`android/`)
- UIAutomator selectors
- Intent launching
- Screenshot and UI hierarchy
- Back/Home button handling

### macOS (`macos/`)
- Accessibility API integration
- Window management
- Menu bar interaction
- Keyboard shortcuts

## Test Patterns

### Basic Session Lifecycle

```zig
const std = @import("std");
const zylix_test = @import("zylix_test");

test "session lifecycle" {
    var driver = try zylix_test.Driver.init(.{
        .platform = .web,
        .port = 9515,
    });
    defer driver.deinit();

    const session = try driver.createSession(.{
        .browser = .chrome,
    });
    defer driver.deleteSession(session.id);

    try session.navigateTo("https://example.com");
    const title = try session.getTitle();
    try std.testing.expectEqualStrings("Example Domain", title);
}
```

### Element Interaction

```zig
test "element interaction" {
    var app = try zylix_test.App.launch(.{
        .platform = .ios,
        .bundle_id = "com.example.app",
    });
    defer app.terminate();

    // Find and tap button
    const button = try app.find(.byAccessibilityId("submit-button"));
    try button.tap();

    // Verify result
    const label = try app.find(.byText("Success"));
    try std.testing.expect(label.exists());
}
```

### watchOS-Specific

```zig
test "digital crown" {
    var app = try zylix_test.App.launch(.{
        .platform = .watchos,
        .device = "Apple Watch Series 9",
    });
    defer app.terminate();

    // Rotate Digital Crown up
    try app.rotateDigitalCrown(.up, 0.5);

    // Verify scroll position changed
    const counter = try app.find(.byTestId("counter"));
    const value = try counter.getText();
    try std.testing.expect(std.mem.eql(u8, value, "5"));
}
```

## Error Handling

All tests handle bridge server unavailability gracefully:

```zig
test "graceful skip" {
    if (!zylix_test.isServerAvailable("127.0.0.1", 9515, 1000)) {
        std.debug.print("⏭️  Bridge not available, skipping\n", .{});
        return;
    }
    // Proceed with test...
}
```

## Contributing

See [CONTRIBUTING.md](../../CONTRIBUTING.md) for guidelines.

## License

MIT - Part of the Zylix framework
