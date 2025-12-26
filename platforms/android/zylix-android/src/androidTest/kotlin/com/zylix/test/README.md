# Zylix Android E2E Testing Framework

Espresso-based End-to-End testing framework for Zylix Android applications.

## Overview

The Zylix Android E2E Testing Framework provides a unified testing context for Espresso integration, making it easy to write comprehensive UI tests for Zylix-based Android apps.

## Components

### ZylixTestContext

The main testing context class that provides:

- **App Lifecycle Management**: Launch, close, and verify initialization
- **Interaction Helpers**: Tap, swipe, type text, clear text, press back
- **Wait Helpers**: Wait for views, state changes, and custom conditions
- **View Query Helpers**: Find views by ID, text, content description, or tag
- **Assertion Helpers**: Verify visibility, enabled state, text content
- **Screenshot Capture**: Capture screenshots using UiAutomator
- **Component Verification**: Verify Zylix-specific components by tag pattern

### ZylixBaseTest

Base class for Zylix Espresso test cases:

```kotlin
@RunWith(AndroidJUnit4::class)
class MyAppUITests : ZylixBaseTest<MainActivity>() {

    override val activityClass: Class<MainActivity>
        get() = MainActivity::class.java

    @Test
    fun testMyFeature() {
        // Tap button by ID
        context.tapById(R.id.submit_button)

        // Verify text is displayed
        context.assertDisplayedByText("Success")
    }
}
```

### ZylixTestConfig

Configuration options for test execution:

```kotlin
val config = ZylixTestConfig(
    defaultTimeout = 15_000L,
    captureScreenshotOnFailure = true,
    logLevel = ZylixTestConfig.LogLevel.DEBUG,
    resetStateBeforeTest = true
)
```

## Usage

### Basic Test

```kotlin
@RunWith(AndroidJUnit4::class)
class BasicUITests : ZylixBaseTest<MainActivity>() {

    override val activityClass = MainActivity::class.java

    @Test
    fun testAppLaunches() {
        assertEquals(ZylixTestAppState.READY, context.getState())
    }
}
```

### Testing Components

```kotlin
@Test
fun testButtonInteraction() {
    // Find Zylix button component by tag
    val exists = context.verifyComponent("button", "submit")
    assertTrue(exists)

    // Interact with component
    context.component("button", "submit").perform(click())
}
```

### State Verification

```kotlin
@Test
fun testStateTransitions() {
    // Wait for loading state
    val loadingStarted = context.waitForStateChange(ZylixTestAppState.LOADING, timeout = 5000)
    assertTrue(loadingStarted)

    // Wait for ready state
    val completed = context.waitForStateChange(ZylixTestAppState.READY, timeout = 10000)
    assertTrue(completed)
}
```

### Screenshot Capture

```kotlin
@Test
fun testWithScreenshots() {
    // Capture initial state
    val screenshot = context.captureScreenshot("initial-state")
    assertNotNull(screenshot)

    // Perform actions
    context.tapById(R.id.next_button)

    // Capture after action
    context.captureScreenshot("after-action")
}
```

### Input Handling

```kotlin
@Test
fun testTextInput() {
    // Type text into field
    context.typeTextById("hello@example.com", R.id.email_input)

    // Close keyboard
    context.closeKeyboard()

    // Verify input
    context.assertHasText(withId(R.id.email_input), "hello@example.com")
}
```

### Navigation

```kotlin
@Test
fun testBackNavigation() {
    // Navigate forward
    context.tapById(R.id.details_button)
    context.waitFor(500)

    // Press back
    context.pressBack()

    // Verify we're back
    context.assertDisplayedById(R.id.main_content)
}
```

## Test Categories

The framework includes sample tests in these categories:

1. **ZylixSampleUITests**: Basic app functionality tests
2. **ZylixAccessibilityTests**: Accessibility compliance tests
3. **ZylixPerformanceTests**: Performance measurement tests
4. **ZylixErrorStateTests**: Error handling and recovery tests
5. **ZylixComponentTests**: Zylix component-specific tests
6. **ZylixIntegrationTests**: Integration tests for Zylix core

## CI/CD Integration

The framework includes a GitHub Actions workflow (`.github/workflows/android-e2e-tests.yml`) that:

- Builds the Zylix core for Android
- Runs E2E tests on multiple API levels (34, 33)
- Runs unit tests without emulator
- Runs lint and static analysis
- Uploads test results and screenshots as artifacts

### Running Tests Locally

```bash
# Run instrumented tests on connected device/emulator
cd platforms/android
./gradlew :zylix-android:connectedDebugAndroidTest

# Run specific test class
./gradlew :zylix-android:connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.zylix.test.ZylixIntegrationTests

# Run unit tests
./gradlew :zylix-android:test
```

### Using Android Emulator

```bash
# Create emulator
avdmanager create avd -n test_avd -k "system-images;android-34;google_apis;x86_64"

# Start emulator
emulator -avd test_avd -no-audio -no-window &

# Wait for boot
adb wait-for-device shell getprop sys.boot_completed | grep -m 1 1

# Run tests
./gradlew connectedAndroidTest
```

## Best Practices

1. **Use Zylix Component Tags**: Add `zylix-{type}-{id}` tags to components for reliable targeting
2. **Avoid Hard-coded Delays**: Use `waitForView` and `waitForStateChange` instead of `Thread.sleep`
3. **Capture Screenshots**: Use `captureScreenshot` at key points for debugging
4. **Close Keyboard**: Call `closeKeyboard()` after text input to avoid view obstruction
5. **Idle Sync**: Use `idleSync()` to wait for all pending UI operations

## Configuration

### Custom Timeout

```kotlin
class MyTests : ZylixBaseTest<MainActivity>() {
    override val testConfig: ZylixTestConfig
        get() = ZylixTestConfig(
            defaultTimeout = 20_000L,
            logLevel = ZylixTestConfig.LogLevel.DEBUG
        )
}
```

### Intent Extras

```kotlin
context.launch(
    intentExtras = mapOf(
        "user_id" to 123,
        "debug_mode" to true
    )
)
```

## API Reference

### ZylixTestContext Methods

| Method | Description |
|--------|-------------|
| `launch(intentExtras, launchFlags)` | Launch the activity |
| `close()` | Close the activity |
| `verifyInitialization(timeout)` | Verify Zylix core is initialized |
| `getState()` | Get current app state |
| `tap(viewMatcher, timeout)` | Tap a view |
| `tapById(viewId, timeout)` | Tap view by ID |
| `tapByText(text, timeout)` | Tap view by text |
| `doubleTap(viewMatcher, timeout)` | Double tap a view |
| `longPress(viewMatcher, timeout)` | Long press a view |
| `swipe(direction, viewMatcher)` | Swipe gesture |
| `typeText(text, viewMatcher, timeout)` | Type text into view |
| `clearText(viewMatcher, timeout)` | Clear text in view |
| `closeKeyboard()` | Close soft keyboard |
| `pressBack()` | Press back button |
| `waitForView(viewMatcher, timeout)` | Wait for view to be visible |
| `waitForViewToDisappear(viewMatcher, timeout)` | Wait for view to disappear |
| `waitForStateChange(targetState, timeout)` | Wait for app state change |
| `viewExists(viewId)` | Check if view exists |
| `assertDisplayed(viewMatcher)` | Assert view is displayed |
| `assertNotDisplayed(viewMatcher)` | Assert view is not displayed |
| `assertEnabled(viewMatcher)` | Assert view is enabled |
| `assertHasText(viewMatcher, expectedText)` | Assert view has text |
| `captureScreenshot(name)` | Capture screenshot |

### ZylixTestAppState

| State | Description |
|-------|-------------|
| `IDLE` | App not active |
| `LOADING` | App is loading |
| `READY` | App is ready for interaction |
| `ERROR` | App encountered an error |
| `UNKNOWN` | State cannot be determined |

## Dependencies

The framework requires these dependencies (included in build.gradle.kts):

```kotlin
androidTestImplementation("androidx.test.ext:junit:1.1.5")
androidTestImplementation("androidx.test.espresso:espresso-core:3.5.1")
androidTestImplementation("androidx.test.espresso:espresso-contrib:3.5.1")
androidTestImplementation("androidx.test.espresso:espresso-intents:3.5.1")
androidTestImplementation("androidx.test.uiautomator:uiautomator:2.3.0")
androidTestImplementation("androidx.test:rules:1.5.0")
androidTestImplementation("androidx.test:runner:1.5.2")
```

## License

Part of the Zylix project. See main LICENSE file for details.
