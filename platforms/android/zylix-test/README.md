# Zylix Test Framework - Android Driver

UIAutomator2-based test driver for Android platform E2E testing.

## Overview

This Android library provides an HTTP server that bridges the Zylix Test Framework (Zig) with UIAutomator2 for Android app automation.

## Requirements

- Android SDK 24+ (Android 7.0 Nougat)
- Kotlin 1.9+
- Android Gradle Plugin 8.0+

## Installation

### Gradle

Add to your app's `build.gradle.kts`:

```kotlin
dependencies {
    androidTestImplementation("com.zylix:test-android:0.8.0")
}
```

Or include as a local module:

```kotlin
dependencies {
    androidTestImplementation(project(":zylix-test"))
}
```

## Usage

### Start the Server

```kotlin
import com.zylix.test.ZylixTestServer

class MyInstrumentedTest {
    private lateinit var server: ZylixTestServer

    @Before
    fun setUp() {
        server = ZylixTestServer(port = 6790)
        server.start()
    }

    @After
    fun tearDown() {
        server.stop()
    }
}
```

### From Zig Test Code

```zig
const zylix_test = @import("zylix_test");

test "Android login flow" {
    // Create Android driver
    var driver = try zylix_test.createAndroidDriver(allocator, .{
        .use_emulator = true,
        .api_level = 34,
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

All endpoints follow the WebDriver/UIAutomator2 protocol pattern.

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
- `POST /session/{id}/actions` - W3C Actions API for gestures

### Element Queries

- `GET /session/{id}/element/{elementId}/text` - Get element text
- `GET /session/{id}/element/{elementId}/displayed` - Check visibility
- `GET /session/{id}/element/{elementId}/enabled` - Check if enabled
- `GET /session/{id}/element/{elementId}/rect` - Get bounding rect
- `GET /session/{id}/element/{elementId}/attribute/{name}` - Get attribute

### Screenshots

- `GET /session/{id}/screenshot` - Take full screenshot

## Selector Strategies

| Strategy | Description | Example |
|----------|-------------|---------|
| `accessibility id` | Content description | `"login-button"` |
| `id` | Resource ID | `"com.example:id/button"` |
| `class name` | Android class | `"android.widget.Button"` |
| `-android uiautomator` | UiSelector syntax | `"new UiSelector().text(\"Login\")"` |

## UiSelector Examples

```zig
// By text
const selector = Selector{ .text = "Submit" };

// By resource ID
const selector = Selector{ .resource_id = "com.example:id/submit" };

// By accessibility ID (content-desc)
const selector = Selector{ .accessibility_id = "submit-button" };

// By class name
const selector = Selector{ .class_name = "android.widget.Button" };
```

## W3C Actions API

The server supports W3C Actions API for complex gestures:

```json
{
  "actions": [{
    "type": "pointer",
    "id": "finger1",
    "actions": [
      {"type": "pointerMove", "x": 100, "y": 200},
      {"type": "pointerDown"},
      {"type": "pause", "duration": 500},
      {"type": "pointerUp"}
    ]
  }]
}
```

## Running Tests

### Start Emulator

```bash
# List available emulators
emulator -list-avds

# Start emulator
emulator -avd Pixel_7_API_34
```

### Forward Port

```bash
adb forward tcp:6790 tcp:6790
```

### Run Instrumented Tests

```bash
./gradlew connectedAndroidTest
```

## Troubleshooting

### Server not responding

1. Ensure ADB port forwarding is set up
2. Check emulator/device is connected: `adb devices`
3. Verify instrumentation test is running

### Element not found

- Use Layout Inspector in Android Studio to find correct resource IDs
- Check content-description for accessibility IDs
- Use UiAutomator Viewer: `uiautomatorviewer`

### Connection refused

```bash
# Check if port is forwarded
adb forward --list

# Re-forward port
adb forward tcp:6790 tcp:6790
```

## Device Management

```bash
# List connected devices
adb devices

# Connect to specific device
adb -s <device-serial> shell
```

## License

MIT
