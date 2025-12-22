# iOS E2E Test Demo

Demonstrates Zylix Test Framework for iOS app testing with WebDriverAgent.

## Prerequisites

1. **Xcode 15+** - With iOS SDK
2. **WebDriverAgent** - Build and run on simulator
3. **iOS Simulator** - iPhone 15 Pro recommended

## Setup

### 1. Start WebDriverAgent

```bash
# Build and run WDA on simulator
cd platforms/ios/zylix-test
swift build
.build/debug/zylix-test-server

# Or use Appium's WDA
appium driver install xcuitest
```

### 2. Launch Simulator

```bash
# List available simulators
xcrun simctl list devices | grep iPhone

# Boot simulator
xcrun simctl boot "iPhone 15 Pro"
```

## Run Tests

```bash
# Using Zig (native)
cd ../../../core
zig build test-e2e

# Using Swift
swift test
```

## Test Examples

### Session Management

```swift
// Tests/IOSTestDemoTests/SessionTests.swift
import XCTest

final class SessionTests: XCTestCase {
    func testSessionLifecycle() async throws {
        let driver = try await ZylixTestDriver(port: 8100)

        let session = try await driver.createSession(
            bundleId: "com.apple.Preferences"
        )

        XCTAssertNotNil(session.id)

        try await driver.deleteSession(session.id)
    }
}
```

### Element Finding

```swift
func testFindByAccessibilityId() async throws {
    let app = try await ZylixTestApp.launch(
        bundleId: "com.apple.Preferences"
    )
    defer { Task { try? await app.terminate() } }

    // Find by accessibility identifier
    let element = try await app.find(
        .accessibilityId("General")
    )

    XCTAssertTrue(element.exists)
}

func testFindByPredicate() async throws {
    let app = try await ZylixTestApp.launch(
        bundleId: "com.apple.Preferences"
    )

    // iOS-specific predicate string
    let cells = try await app.findAll(
        .predicate("type == 'XCUIElementTypeCell'")
    )

    XCTAssertGreaterThan(cells.count, 0)
}
```

### Touch Gestures

```swift
func testTapElement() async throws {
    let app = try await ZylixTestApp.launch(
        bundleId: "com.apple.Preferences"
    )

    let general = try await app.find(.accessibilityId("General"))
    try await general.tap()

    // Verify navigation
    let aboutCell = try await app.waitFor(
        .accessibilityId("About"),
        timeout: 5.0
    )
    XCTAssertTrue(aboutCell.exists)
}

func testSwipeGesture() async throws {
    let app = try await ZylixTestApp.launch(
        bundleId: "com.apple.Preferences"
    )

    // Swipe up to scroll
    try await app.swipe(.up)

    // Verify scroll happened
    let visibleCells = try await app.findAll(.predicate("visible == true"))
    XCTAssertGreaterThan(visibleCells.count, 0)
}

func testLongPress() async throws {
    let app = try await ZylixTestApp.launch(
        bundleId: "com.example.notes"
    )

    let note = try await app.find(.accessibilityId("note-1"))
    try await note.longPress(duration: 1.0)

    // Context menu should appear
    let deleteOption = try await app.waitFor(
        .text("Delete"),
        timeout: 3.0
    )
    XCTAssertTrue(deleteOption.exists)
}
```

### Screenshots

```swift
func testScreenshot() async throws {
    let app = try await ZylixTestApp.launch(
        bundleId: "com.apple.Preferences"
    )

    let screenshot = try await app.takeScreenshot()
    XCTAssertGreaterThan(screenshot.count, 0)

    // Save to file
    let data = Data(screenshot)
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("screenshot.png")
    try data.write(to: url)
}
```

## Zig Native Usage

```zig
const std = @import("std");
const ios_test = @import("ios_e2e_test.zig");

test "iOS app launch" {
    const allocator = std.testing.allocator;

    if (!ios_test.isWebDriverAgentAvailable()) {
        std.debug.print("WDA not available\n", .{});
        return;
    }

    const response = try ios_test.createSession(
        allocator,
        "com.apple.Preferences"
    );
    defer allocator.free(response);

    const session_id = ios_test.parseSessionId(response) orelse return;

    // Find element
    const element_resp = try ios_test.findByAccessibilityId(
        allocator,
        session_id,
        "General"
    );
    defer allocator.free(element_resp);

    // Verify element found
    try std.testing.expect(
        std.mem.indexOf(u8, element_resp, "ELEMENT") != null
    );
}
```

## Configuration

### Info.plist Requirements

For testing your own app, ensure:

```xml
<key>UIAccessibilityEnabled</key>
<true/>
```

### Capabilities

```json
{
    "platformName": "iOS",
    "platformVersion": "17.0",
    "deviceName": "iPhone 15 Pro",
    "bundleId": "com.example.app",
    "automationName": "XCUITest"
}
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| WDA build fails | Check Xcode version and signing |
| Element not found | Use Accessibility Inspector to verify identifiers |
| Simulator not booting | Reset simulator state |
| Timeout on launch | Increase launch timeout in config |
