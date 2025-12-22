# Android E2E Test Demo

Demonstrates Zylix Test Framework for Android app testing with Appium/UIAutomator2.

## Prerequisites

1. **Android Studio** - With Android SDK
2. **Appium 2.x** - With UIAutomator2 driver
3. **Android Emulator** - API 33+ recommended
4. **JDK 17+** - For Kotlin tests

## Setup

### 1. Install Appium and UIAutomator2

```bash
# Install Appium
npm install -g appium

# Install UIAutomator2 driver
appium driver install uiautomator2

# Verify installation
appium driver list --installed
```

### 2. Start Android Emulator

```bash
# List available AVDs
emulator -list-avds

# Start emulator
emulator -avd Pixel_7_API_33

# Or use Android Studio Emulator
```

### 3. Start Appium Server

```bash
# Default port 4723
appium

# Or specify port
appium --port 4723
```

## Run Tests

```bash
# Using Zig (native)
cd ../../../core
zig build test-e2e

# Using Gradle
./gradlew test
```

## Test Examples

### Session Management

```kotlin
// src/test/kotlin/SessionTests.kt
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.AfterEach

class SessionTests {
    private lateinit var client: ZylixTestClient

    @BeforeEach
    fun setup() {
        client = ZylixTestClient(port = 4723)
    }

    @Test
    fun `should create and delete session`() {
        val session = client.createSession(
            packageName = "com.android.settings"
        )

        assertNotNull(session.id)
        println("✅ Created session: ${session.id}")

        client.deleteSession(session.id)
        println("✅ Deleted session")
    }
}
```

### Element Finding

```kotlin
@Test
fun `should find element by UIAutomator selector`() {
    val session = client.createSession(
        packageName = "com.android.settings"
    )

    // UIAutomator selector
    val element = session.find(
        uiAutomator = "new UiSelector().text(\"Network & internet\")"
    )

    assertTrue(element.exists)
}

@Test
fun `should find element by accessibility id`() {
    val session = client.createSession(
        packageName = "com.example.app"
    )

    val button = session.find(accessibilityId = "submit_button")
    assertTrue(button.exists)
}

@Test
fun `should find element by resource id`() {
    val session = client.createSession(
        packageName = "com.android.settings"
    )

    val element = session.find(
        resourceId = "com.android.settings:id/search_bar"
    )
    assertTrue(element.exists)
}
```

### Touch Gestures

```kotlin
@Test
fun `should tap element`() {
    val session = client.createSession(
        packageName = "com.android.settings"
    )

    val networkItem = session.find(
        uiAutomator = "new UiSelector().text(\"Network & internet\")"
    )

    networkItem.tap()
    println("✅ Tapped element")

    // Verify navigation
    val wifiItem = session.waitFor(
        uiAutomator = "new UiSelector().text(\"Wi-Fi\")",
        timeout = 5000
    )
    assertTrue(wifiItem.exists)
}

@Test
fun `should perform swipe gesture`() {
    val session = client.createSession(
        packageName = "com.android.settings"
    )

    // Swipe up to scroll down
    session.swipe(
        startX = 500,
        startY = 1500,
        endX = 500,
        endY = 500,
        duration = 500
    )

    println("✅ Swipe gesture completed")
}
```

### System Buttons

```kotlin
@Test
fun `should press back button`() {
    val session = client.createSession(
        packageName = "com.android.settings"
    )

    // Navigate into settings
    val networkItem = session.find(
        uiAutomator = "new UiSelector().text(\"Network & internet\")"
    )
    networkItem.tap()

    // Press back
    session.pressBack()

    // Should be back at main settings
    println("✅ Back button pressed")
}

@Test
fun `should press home button`() {
    val session = client.createSession(
        packageName = "com.android.settings"
    )

    session.pressHome()
    println("✅ Home button pressed")
}
```

### Screenshots

```kotlin
@Test
fun `should capture screenshot`() {
    val session = client.createSession(
        packageName = "com.android.settings"
    )

    val screenshot = session.takeScreenshot()

    assertTrue(screenshot.isNotEmpty())
    println("✅ Captured screenshot: ${screenshot.size} bytes")

    // Save to file
    File("screenshot.png").writeBytes(screenshot)
}
```

## Zig Native Usage

```zig
const std = @import("std");
const android_test = @import("android_e2e_test.zig");

test "Android session" {
    const allocator = std.testing.allocator;

    if (!android_test.isAppiumAvailable()) {
        std.debug.print("Appium not available\n", .{});
        return;
    }

    const response = try android_test.createSession(
        allocator,
        "com.android.settings"
    );
    defer allocator.free(response);

    const session_id = android_test.parseSessionId(response) orelse return;

    // Find element using UIAutomator
    const element_resp = try android_test.findByUIAutomator(
        allocator,
        session_id,
        "new UiSelector().text(\"Network & internet\")"
    );
    defer allocator.free(element_resp);

    std.debug.print("✅ Found element on Android\n", .{});
}
```

## Configuration

### Gradle Dependencies

```kotlin
// build.gradle.kts
dependencies {
    testImplementation("org.junit.jupiter:junit-jupiter:5.10.0")
    testImplementation("io.appium:java-client:9.0.0")
}
```

### Capabilities

```json
{
    "platformName": "Android",
    "platformVersion": "14",
    "deviceName": "Pixel 7",
    "automationName": "UiAutomator2",
    "appPackage": "com.example.app",
    "appActivity": ".MainActivity"
}
```

## UIAutomator Selectors

| Selector Type | Example |
|--------------|---------|
| Text | `new UiSelector().text("Button")` |
| Text Contains | `new UiSelector().textContains("But")` |
| Resource ID | `new UiSelector().resourceId("com.app:id/button")` |
| Class Name | `new UiSelector().className("android.widget.Button")` |
| Description | `new UiSelector().description("Submit button")` |
| Index | `new UiSelector().className("Button").index(0)` |
| Scrollable | `new UiScrollable(new UiSelector().scrollable(true))` |

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Appium not connecting | Check ADB connection: `adb devices` |
| Element not found | Use UI Automator Viewer to inspect hierarchy |
| Session creation fails | Verify app package/activity names |
| Emulator too slow | Use hardware acceleration (HAXM/KVM) |
| UIAutomator2 not found | Run `appium driver install uiautomator2` |
