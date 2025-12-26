# Zylix Cross-Platform Testing Guide

This document describes the unified testing framework for Zylix, covering all supported platforms.

## Overview

Zylix provides comprehensive testing support across all platforms:

| Platform | Framework | Type |
|----------|-----------|------|
| Core (Zig) | Built-in | Unit/Integration |
| iOS | XCUITest | E2E |
| Android | Espresso | E2E |
| Web | Jest/Vitest | Unit/E2E |

## Quick Start

### Run All Tests

```bash
# Run tests across all platforms
./scripts/test.sh --all

# Run specific platforms
./scripts/test.sh --core --ios

# Generate report
./scripts/test.sh --all --report
```

### Platform-Specific Tests

```bash
# Core (Zig) tests
cd core && zig build test

# iOS tests
cd platforms/ios
xcodebuild test -scheme ZylixUITests -destination 'platform=iOS Simulator,name=iPhone 15'

# Android tests
cd platforms/android
./gradlew :zylix-android:connectedDebugAndroidTest

# Web tests
cd tests && npm test
```

## Test Frameworks

### Core (Zig)

The Zylix core uses Zig's built-in testing framework:

```zig
test "example test" {
    const result = someFunction();
    try std.testing.expectEqual(@as(u32, 42), result);
}
```

Run with:
```bash
cd core && zig build test --summary all
```

### iOS (XCUITest)

iOS E2E tests use XCUITest with the ZylixTestContext framework:

```swift
import XCTest

final class MyTests: ZylixUITestCase {
    func testExample() throws {
        context.tap(context.button(withLabel: "Submit"))
        context.assertDisplayed(context.staticText(containing: "Success"))
    }
}
```

See: `platforms/ios/ZylixUITests/README.md`

### Android (Espresso)

Android E2E tests use Espresso with the ZylixTestContext framework:

```kotlin
@RunWith(AndroidJUnit4::class)
class MyTests : ZylixBaseTest<MainActivity>() {
    override val activityClass = MainActivity::class.java

    @Test
    fun testExample() {
        context.tapById(R.id.submit_button)
        context.assertDisplayedByText("Success")
    }
}
```

See: `platforms/android/zylix-android/src/androidTest/kotlin/com/zylix/test/README.md`

### Web

Web tests use Jest or Vitest:

```javascript
test('example test', () => {
    expect(someFunction()).toBe(42);
});
```

## CI/CD Integration

### GitHub Actions Workflows

| Workflow | File | Trigger |
|----------|------|---------|
| Cross-Platform Tests | `cross-platform-tests.yml` | Push/PR to main, develop |
| iOS E2E Tests | `ios-e2e-tests.yml` | Changes to platforms/ios |
| Android E2E Tests | `android-e2e-tests.yml` | Changes to platforms/android |
| CI | `ci.yml` | All changes |

### Running Workflows Manually

```bash
# Trigger cross-platform tests
gh workflow run cross-platform-tests.yml

# Trigger with specific platforms
gh workflow run cross-platform-tests.yml \
  -f run_core=true \
  -f run_ios=true \
  -f run_android=false \
  -f run_web=false
```

## Test Report Aggregation

The cross-platform workflow generates aggregated reports:

1. **GitHub Summary**: Visible in the Actions tab
2. **JSON Report**: Downloaded as artifact (`cross-platform-report`)
3. **Platform-Specific Reports**: Downloaded as individual artifacts

### Report Format

```json
{
  "timestamp": "2025-12-26T12:00:00Z",
  "commit": "abc123",
  "branch": "main",
  "results": {
    "core": "success",
    "ios": "success",
    "android": "success",
    "web": "skipped"
  }
}
```

## Local Development

### Prerequisites

| Platform | Requirements |
|----------|--------------|
| Core | Zig 0.15.x |
| iOS | Xcode 15+, macOS |
| Android | JDK 17, Android SDK, Emulator |
| Web | Node.js 20+ |

### Running Tests Locally

```bash
# Install all dependencies
make setup

# Run core tests
make test-core

# Run iOS tests (macOS only)
make test-ios

# Run Android tests
make test-android

# Run web tests
make test-web

# Run all tests
make test
```

## Best Practices

### Writing Tests

1. **Isolation**: Each test should be independent
2. **Clarity**: Use descriptive test names
3. **Coverage**: Test critical paths and edge cases
4. **Speed**: Keep tests fast; mock external dependencies

### Test Organization

```
project/
├── core/
│   └── src/
│       └── *.zig          # Unit tests inline or in test blocks
├── platforms/
│   ├── ios/
│   │   └── ZylixUITests/  # iOS E2E tests
│   └── android/
│       └── src/androidTest/  # Android E2E tests
└── tests/                 # Web tests
```

### Naming Conventions

| Platform | Pattern | Example |
|----------|---------|---------|
| Zig | `test "description"` | `test "should parse config"` |
| Swift | `testXxx` | `testButtonInteraction` |
| Kotlin | `testXxx` | `testStateTransitions` |
| JS | `test('xxx')` | `test('should render')` |

## Debugging

### iOS Tests

```bash
# Run with verbose output
xcodebuild test \
  -scheme ZylixUITests \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -resultBundlePath Results.xcresult

# Extract results
xcrun xcresulttool get --format json --path Results.xcresult
```

### Android Tests

```bash
# Run with debug output
./gradlew connectedAndroidTest --info --stacktrace

# Capture logcat
adb logcat -d > logcat.txt
```

### Core Tests

```bash
# Run with verbose output
zig build test --summary all 2>&1 | tee test.log
```

## Troubleshooting

### iOS Simulator Issues

```bash
# Reset simulator
xcrun simctl erase all

# List available simulators
xcrun simctl list devices available
```

### Android Emulator Issues

```bash
# List AVDs
emulator -list-avds

# Start with clean state
emulator -avd <avd_name> -wipe-data

# Check ADB connection
adb devices
```

### Zig Build Issues

```bash
# Clean build
rm -rf core/zig-cache core/zig-out
zig build
```

## Contributing

When adding new tests:

1. Follow the platform-specific patterns
2. Add corresponding CI workflow coverage
3. Update documentation
4. Verify locally before pushing

See [CONTRIBUTING.md](../CONTRIBUTING.md) for general guidelines.
