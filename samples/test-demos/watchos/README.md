# watchOS E2E Test Demo

Demonstrates Zylix Test Framework for watchOS app testing with WebDriverAgent.

## Prerequisites

1. **Xcode 15+** - With watchOS SDK
2. **WebDriverAgent** - Build and run on Watch simulator
3. **Watch Simulator** - Apple Watch Series 9 recommended
4. **iPhone Simulator** - For companion app pairing

## Setup

### 1. Create Simulator Pair

```bash
# List available devices
xcrun simctl list devices

# Get UDIDs
PHONE_UDID=$(xcrun simctl list devices | grep "iPhone 15 Pro" | grep -oE '[A-F0-9-]{36}' | head -1)
WATCH_UDID=$(xcrun simctl list devices | grep "Apple Watch Series 9" | grep -oE '[A-F0-9-]{36}' | head -1)

# Pair devices
xcrun simctl pair $WATCH_UDID $PHONE_UDID

# Verify pairing
xcrun simctl list pairs
```

### 2. Boot Simulators

```bash
# Boot iPhone first
xcrun simctl boot $PHONE_UDID

# Then boot Watch
xcrun simctl boot $WATCH_UDID
```

### 3. Start WebDriverAgent

```bash
cd platforms/ios/zylix-test
swift build
.build/debug/zylix-test-server --port 8100
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

### Digital Crown Interaction

```swift
// Tests/WatchOSTestDemoTests/DigitalCrownTests.swift
import XCTest

final class DigitalCrownTests: XCTestCase {
    func testDigitalCrownRotation() async throws {
        let app = try await ZylixWatchApp.launch(
            bundleId: "com.example.watchapp",
            device: .appleWatchSeries9_45mm
        )
        defer { Task { try? await app.terminate() } }

        // Rotate Digital Crown up (clockwise)
        try await app.rotateDigitalCrown(
            direction: .up,
            velocity: 0.5
        )

        // Verify scroll or value change
        let counter = try await app.find(.testId("counter"))
        let value = try await counter.getText()
        XCTAssertEqual(value, "5")
    }

    func testDigitalCrownWithVelocity() async throws {
        let app = try await ZylixWatchApp.launch(
            bundleId: "com.example.watchapp"
        )

        // Fast rotation
        try await app.rotateDigitalCrown(direction: .down, velocity: 1.0)

        // Slow rotation for fine control
        try await app.rotateDigitalCrown(direction: .up, velocity: 0.1)
    }
}
```

### Side Button Interaction

```swift
final class SideButtonTests: XCTestCase {
    func testSideButtonPress() async throws {
        let app = try await ZylixWatchApp.launch(
            bundleId: "com.example.watchapp"
        )
        defer { Task { try? await app.terminate() } }

        // Single press - opens app switcher
        try await app.pressSideButton()

        // Wait for app switcher
        let appSwitcher = try await app.waitFor(
            .accessibilityId("AppSwitcher"),
            timeout: 3.0
        )
        XCTAssertTrue(appSwitcher.exists)
    }

    func testSideButtonDoublePress() async throws {
        let app = try await ZylixWatchApp.launch(
            bundleId: "com.example.watchapp"
        )

        // Double press - opens Wallet/Apple Pay
        try await app.doublePresssSideButton()

        // Verify Apple Pay or Wallet appeared
        // (requires appropriate entitlements)
    }
}
```

### Companion Device Pairing

```swift
final class CompanionTests: XCTestCase {
    func testCompanionDeviceInfo() async throws {
        let app = try await ZylixWatchApp.launch(
            bundleId: "com.example.watchapp"
        )
        defer { Task { try? await app.terminate() } }

        // Get companion iPhone info
        let companionInfo = try await app.getCompanionDeviceInfo()

        XCTAssertNotNil(companionInfo)
        XCTAssertTrue(companionInfo?.isPaired ?? false)
        print("✅ Paired with: \(companionInfo?.deviceName ?? "Unknown")")
    }
}
```

### Small Screen Element Finding

```swift
final class ElementTests: XCTestCase {
    func testFindOnSmallScreen() async throws {
        let app = try await ZylixWatchApp.launch(
            bundleId: "com.example.watchapp"
        )

        // Use compact selectors for watchOS
        let button = try await app.find(.testId("action-btn"))
        XCTAssertTrue(button.exists)

        // Tap with smaller hit target
        try await button.tap()
    }

    func testScrollToFind() async throws {
        let app = try await ZylixWatchApp.launch(
            bundleId: "com.example.watchapp"
        )

        // Use Digital Crown to scroll to element
        for _ in 0..<5 {
            let element = try? await app.find(.testId("hidden-item"))
            if element?.exists == true {
                break
            }
            try await app.rotateDigitalCrown(direction: .down, velocity: 0.3)
        }
    }
}
```

## Zig Native Usage

```zig
const std = @import("std");
const ios_test = @import("ios_e2e_test.zig");

test "watchOS Digital Crown" {
    const allocator = std.testing.allocator;

    if (!ios_test.isWebDriverAgentAvailable()) {
        std.debug.print("WDA not available\n", .{});
        return;
    }

    // Create watchOS session
    var body_buf: [512]u8 = undefined;
    const body = try std.fmt.bufPrint(&body_buf,
        \\{{"capabilities":{{"alwaysMatch":{{"platformName":"iOS","bundleId":"com.example.watchapp","platformVersion":"11.0","deviceName":"Apple Watch Series 9"}}}}}}
    , .{});

    const response = try ios_test.sendHttpRequest(
        allocator,
        "127.0.0.1",
        8100,
        "POST",
        "/session",
        body
    );
    defer allocator.free(response);

    const session_id = ios_test.parseSessionId(response) orelse return;

    // Rotate Digital Crown
    var crown_path_buf: [256]u8 = undefined;
    const crown_path = try std.fmt.bufPrint(
        &crown_path_buf,
        "/session/{s}/wda/digitalCrown/rotate",
        .{session_id}
    );

    const crown_body =
        \\{"direction":"up","velocity":0.5}
    ;

    const crown_response = try ios_test.sendHttpRequest(
        allocator,
        "127.0.0.1",
        8100,
        "POST",
        crown_path,
        crown_body
    );
    defer allocator.free(crown_response);

    std.debug.print("✅ Digital Crown rotated\n", .{});
}
```

## watchOS-Specific Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/session/{id}/wda/digitalCrown/rotate` | Rotate Digital Crown |
| POST | `/session/{id}/wda/sideButton/press` | Press Side Button |
| POST | `/session/{id}/wda/sideButton/doublePress` | Double-press Side Button |
| GET | `/session/{id}/wda/companion/info` | Get companion device info |

### Request/Response Examples

#### Digital Crown Rotation

```bash
# Request
curl -X POST http://localhost:8100/session/{id}/wda/digitalCrown/rotate \
  -H "Content-Type: application/json" \
  -d '{"direction":"up","velocity":0.5}'

# Response
{"status":0,"value":null}
```

#### Side Button Press

```bash
# Request
curl -X POST http://localhost:8100/session/{id}/wda/sideButton/press \
  -H "Content-Type: application/json" \
  -d '{"duration":100}'

# Response
{"status":0,"value":null}
```

## Device Specifications

| Device | Screen Size | Resolution | Test Port |
|--------|-------------|------------|-----------|
| Series 9 (41mm) | 352x430 | @2x | 8100 |
| Series 9 (45mm) | 396x484 | @2x | 8100 |
| Series 10 (42mm) | 374x446 | @2x | 8100 |
| Series 10 (46mm) | 416x496 | @2x | 8100 |
| Ultra 2 | 502x410 | @2x | 8100 |
| SE (40mm) | 324x394 | @2x | 8100 |
| SE (44mm) | 368x448 | @2x | 8100 |

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Watch not paired | Run `xcrun simctl pair` with correct UDIDs |
| Watch not booting | Boot iPhone simulator first |
| Digital Crown not working | Ensure app has focus |
| Elements too small | Use testId/accessibilityId instead of coordinates |
| Companion info null | Verify pairing status with `xcrun simctl list pairs` |
