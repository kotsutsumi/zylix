# Zylix Test Framework - iOS Driver

XCUITest-based test driver for iOS platform E2E testing.

## Overview

This Swift package provides an HTTP server that bridges the Zylix Test Framework (Zig) with XCUITest for iOS app automation.

## Requirements

- iOS 15.0+ / macOS 12.0+
- Xcode 15.0+
- Swift 5.9+

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/kotsutsumi/zylix.git", from: "0.8.0")
]
```

Or add via Xcode: File → Add Package Dependencies → Enter repository URL.

### Manual Integration

1. Copy the `ZylixTest` folder to your project
2. Add the source files to your UI Test target
3. Import `ZylixTest` in your test files

## Usage

### Start the Server

```swift
import ZylixTest

class MyUITests: XCTestCase {
    var server: ZylixTestServer!

    override func setUp() {
        super.setUp()
        server = ZylixTestServer(port: 8100)
        try! server.start()
    }

    override func tearDown() {
        server.stop()
        super.tearDown()
    }
}
```

### From Zig Test Code

```zig
const zylix_test = @import("zylix_test");

test "iOS login flow" {
    // Create iOS driver
    var driver = try zylix_test.createIOSDriver(allocator, .{
        .use_simulator = true,
        .simulator_type = .iphone_15,
        .ios_version = "17.0",
    });
    defer driver.deinit();

    // Launch app
    var app = try zylix_test.App.launch(&driver, .{
        .app_id = "com.example.myapp",
    }, allocator);
    defer app.terminate() catch {};

    // Interact with elements
    try app.findByTestId("email-input").typeText("user@example.com");
    try app.findByTestId("password-input").typeText("password123");
    try app.findByTestId("login-button").tap();

    // Assert
    const welcome = try app.waitForText("Welcome", 5000);
    try zylix_test.expectElement(&welcome).toBeVisible();
}
```

## API Endpoints

All endpoints follow the WebDriverAgent (WDA) protocol pattern.

### Session Management

- `POST /session` - Create new session with capabilities
- `DELETE /session/{id}` - Close session

### Element Finding

- `POST /session/{id}/element` - Find single element
- `POST /session/{id}/elements` - Find all matching elements

### Element Interactions

- `POST /session/{id}/element/{elementId}/click` - Tap element
- `POST /session/{id}/element/{elementId}/value` - Type text
- `POST /session/{id}/element/{elementId}/clear` - Clear text
- `POST /session/{id}/wda/element/{elementId}/doubleTap` - Double tap
- `POST /session/{id}/wda/element/{elementId}/touchAndHold` - Long press
- `POST /session/{id}/wda/element/{elementId}/swipe` - Swipe gesture
- `POST /session/{id}/wda/element/{elementId}/scroll` - Scroll

### Element Queries

- `GET /session/{id}/element/{elementId}/text` - Get element text
- `GET /session/{id}/element/{elementId}/displayed` - Check visibility
- `GET /session/{id}/element/{elementId}/enabled` - Check if enabled
- `GET /session/{id}/element/{elementId}/rect` - Get bounding rect
- `GET /session/{id}/element/{elementId}/attribute/{name}` - Get attribute

### Screenshots

- `GET /session/{id}/screenshot` - Take full screenshot
- `GET /session/{id}/element/{elementId}/screenshot` - Element screenshot

## Selector Strategies

| Strategy | Description | Example |
|----------|-------------|---------|
| `accessibility id` | Accessibility identifier | `"login-button"` |
| `name` | Element label text | `"Submit"` |
| `-ios predicate string` | NSPredicate format | `"label BEGINSWITH 'Log'"` |
| `-ios class chain` | XCUITest class chain | `"**/XCUIElementTypeButton"` |
| `xpath` | XPath expression | `"//XCUIElementTypeButton[@name='Login']"` |

## Simulator Types

- `iphone_15` - iPhone 15
- `iphone_15_pro` - iPhone 15 Pro
- `iphone_15_pro_max` - iPhone 15 Pro Max
- `iphone_se` - iPhone SE (3rd generation)
- `ipad_pro_11` - iPad Pro 11-inch
- `ipad_pro_12_9` - iPad Pro 12.9-inch
- `ipad_air` - iPad Air

## Running with Real Devices

1. Connect device via USB
2. Get device UDID: `xcrun xctrace list devices`
3. Configure driver:

```zig
var driver = try zylix_test.createIOSDriver(allocator, .{
    .device_udid = "your-device-udid",
    .use_simulator = false,
});
```

## Troubleshooting

### Server not responding

Ensure the XCUITest runner is active and the port is accessible.

### Element not found

- Check accessibility identifiers are set in your app
- Use Xcode Accessibility Inspector to verify identifiers
- Increase timeout in waitForElement calls

### Simulator issues

```bash
# Reset simulator
xcrun simctl shutdown all
xcrun simctl erase all
```

## License

MIT
