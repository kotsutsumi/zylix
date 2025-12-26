# Zylix iOS E2E Testing Framework

XCUITest-based End-to-End testing framework for Zylix iOS applications.

## Overview

The Zylix E2E Testing Framework provides a unified testing context for XCUITest integration, making it easy to write comprehensive UI tests for Zylix-based iOS apps.

## Components

### ZylixTestContext

The main testing context class that provides:

- **App Lifecycle Management**: Launch, terminate, and verify initialization
- **Interaction Helpers**: Tap, swipe, type text, and clear text
- **Wait Helpers**: Wait for elements, state changes, and property values
- **Element Query Helpers**: Find elements by identifier, label, or type
- **Assertion Helpers**: Verify element existence, hittability, and values
- **Screenshot Capture**: Capture and attach screenshots to test reports

### ZylixUITestCase

Base class for Zylix XCUITest test cases:

```swift
import XCTest

final class MyAppUITests: ZylixUITestCase {
    func testMyFeature() throws {
        // Access the app through context
        let button = context.button(withLabel: "Submit")
        context.tap(button)

        // Verify state
        context.assertExists(context.staticText(containing: "Success"))
    }
}
```

### ZylixTestConfig

Configuration options for test execution:

```swift
var config = ZylixTestConfig()
config.defaultTimeout = 15.0
config.captureScreenshotOnFailure = true
config.logLevel = .debug
config.resetStateBeforeTest = true
```

## Usage

### Basic Test

```swift
final class BasicUITests: ZylixUITestCase {
    func testAppLaunches() throws {
        XCTAssertEqual(context.getState(), .ready)
    }
}
```

### Testing Components

```swift
func testButtonInteraction() throws {
    // Find Zylix button component
    let button = context.component(type: "button", identifier: "submit")

    // Verify and interact
    context.assertExists(button)
    context.tap(button)
}
```

### State Verification

```swift
func testStateTransitions() throws {
    // Wait for loading state
    let loadingStarted = context.waitForStateChange(to: .loading, timeout: 5.0)
    XCTAssertTrue(loadingStarted)

    // Wait for ready state
    let completed = context.waitForStateChange(to: .ready, timeout: 10.0)
    XCTAssertTrue(completed)
}
```

### Screenshot Capture

```swift
func testWithScreenshots() throws {
    // Capture and attach screenshot
    let attachment = context.captureAndAttach(name: "initial-state")
    add(attachment)

    // Perform actions
    context.tap(context.button(withLabel: "Next"))

    // Capture after action
    let afterAttachment = context.captureAndAttach(name: "after-action")
    add(afterAttachment)
}
```

### Performance Testing

```swift
func testLaunchPerformance() throws {
    context.terminate()

    measure(metrics: [XCTApplicationLaunchMetric()]) {
        context.app.launch()
    }
}
```

## Test Categories

The framework includes sample tests in these categories:

1. **ZylixSampleUITests**: Basic app functionality tests
2. **ZylixComponentUITests**: Zylix component-specific tests
3. **ZylixPerformanceUITests**: Performance measurement tests
4. **ZylixScreenshotUITests**: Visual regression capture
5. **ZylixErrorStateUITests**: Error handling and recovery tests

## CI/CD Integration

The framework includes a GitHub Actions workflow (`.github/workflows/ios-e2e-tests.yml`) that:

- Builds the Zylix core for iOS
- Runs E2E tests on multiple devices (iPhone 15, iPhone 15 Pro, iPad Pro)
- Runs accessibility audits
- Measures performance baselines
- Uploads test results and screenshots as artifacts

### Running Tests Locally

```bash
# Build for testing
xcodebuild build-for-testing \
  -project platforms/ios/Zylix.xcodeproj \
  -scheme Zylix \
  -destination "platform=iOS Simulator,name=iPhone 15"

# Run UI tests
xcodebuild test-without-building \
  -project platforms/ios/Zylix.xcodeproj \
  -scheme ZylixUITests \
  -destination "platform=iOS Simulator,name=iPhone 15"
```

## Best Practices

1. **Use Accessibility Identifiers**: Add `zylix-{type}-{id}` identifiers to components
2. **Avoid Hard-coded Delays**: Use `waitForElement` and `waitForStateChange` instead
3. **Capture Screenshots**: Capture screenshots at key points for debugging
4. **Skip Unavailable Tests**: Use `throw XCTSkip()` when features aren't available
5. **Reset State**: Enable `resetStateBeforeTest` for independent tests

## Configuration

### Bundle Identifier

Override the bundle identifier if needed:

```swift
final class MyTests: ZylixUITestCase {
    override var bundleIdentifier: String? {
        return "com.example.myapp"
    }
}
```

### Custom Configuration

```swift
final class MyTests: ZylixUITestCase {
    override var testConfig: ZylixTestConfig {
        var config = ZylixTestConfig()
        config.defaultTimeout = 20.0
        config.logLevel = .debug
        return config
    }
}
```

## API Reference

### ZylixTestContext Methods

| Method | Description |
|--------|-------------|
| `launch(arguments:environment:)` | Launch the app |
| `terminate()` | Terminate the app |
| `verifyInitialization(timeout:)` | Verify Zylix core is initialized |
| `getState()` | Get current app state |
| `tap(_:timeout:)` | Tap an element |
| `doubleTap(_:timeout:)` | Double tap an element |
| `longPress(_:duration:timeout:)` | Long press an element |
| `swipe(_:on:)` | Swipe gesture |
| `typeText(_:into:timeout:)` | Type text into element |
| `clearText(in:timeout:)` | Clear text in element |
| `waitForElement(_:timeout:)` | Wait for element to exist |
| `waitForElementToDisappear(_:timeout:)` | Wait for element to disappear |
| `waitForStateChange(to:timeout:)` | Wait for app state change |
| `element(withIdentifier:)` | Find element by identifier |
| `button(withLabel:)` | Find button by label |
| `textField(withIdentifier:)` | Find text field |
| `staticText(containing:)` | Find text containing string |
| `assertExists(_:message:)` | Assert element exists |
| `assertNotExists(_:message:)` | Assert element doesn't exist |
| `assertHittable(_:message:)` | Assert element is hittable |
| `assertEnabled(_:message:)` | Assert element is enabled |
| `captureScreenshot(name:)` | Capture screenshot |
| `captureAndAttach(name:)` | Capture and attach screenshot |

### ZylixTestAppState

| State | Description |
|-------|-------------|
| `.idle` | App not running |
| `.loading` | App is loading |
| `.ready` | App is ready for interaction |
| `.error` | App encountered an error |
| `.unknown` | State cannot be determined |

## License

Part of the Zylix project. See main LICENSE file for details.
