# Zylix Test Framework - macOS Driver

Accessibility API-based test driver for macOS platform E2E testing.

## Overview

This Swift package provides an HTTP server that bridges the Zylix Test Framework (Zig) with macOS Accessibility API for desktop app automation.

## Requirements

- macOS 12.0+ (Monterey)
- Xcode 15.0+
- Swift 5.9+
- Accessibility permissions enabled

## Installation

### Build from Source

```bash
cd platforms/macos/zylix-test
swift build -c release
```

### Run the Server

```bash
.build/release/zylix-test-server
```

The server runs on `http://127.0.0.1:8200` by default.

## Usage

### Enable Accessibility Permissions

1. Open System Preferences → Security & Privacy → Privacy → Accessibility
2. Add your terminal app or the test runner
3. Enable the checkbox

### From Zig Test Code

```zig
const zylix_test = @import("zylix_test");

test "macOS app login flow" {
    // Create macOS driver
    var driver = try zylix_test.createMacOSDriver(allocator, .{
        .enable_accessibility = true,
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

### Session Management

- `POST /session/new/launch` - Launch app and create session
- `POST /session/{id}/close` - Close session and terminate app

### Element Finding

- `POST /session/{id}/findElement` - Find single element
- `POST /session/{id}/findElements` - Find all matching elements

### Element Interactions

- `POST /session/{id}/click` - Click element
- `POST /session/{id}/doubleClick` - Double-click element
- `POST /session/{id}/longPress` - Long press element
- `POST /session/{id}/type` - Type text into element
- `POST /session/{id}/clear` - Clear element text

### Element Queries

- `POST /session/{id}/exists` - Check if element exists
- `POST /session/{id}/isVisible` - Check element visibility
- `POST /session/{id}/isEnabled` - Check if element is enabled
- `POST /session/{id}/getText` - Get element text
- `POST /session/{id}/getAttribute` - Get element attribute
- `POST /session/{id}/getRect` - Get element bounding rect

### Screenshots

- `POST /session/{id}/screenshot` - Take app screenshot
- `POST /session/{id}/elementScreenshot` - Take element screenshot

## Selector Strategies

| Strategy | Description | Example |
|----------|-------------|---------|
| `identifier` | Accessibility identifier | `"login-button"` |
| `title` | Element title/label | `"Submit"` |
| `role` | Accessibility role | `"AXButton"` |
| `predicate` | NSPredicate format | `"title CONTAINS 'Log'"` |

## Accessibility Roles

Common macOS accessibility roles:

- `AXButton` - Button elements
- `AXTextField` - Text input fields
- `AXStaticText` - Static text labels
- `AXWindow` - Application windows
- `AXMenu` - Menu elements
- `AXMenuItem` - Menu items
- `AXCheckBox` - Checkbox elements
- `AXRadioButton` - Radio buttons
- `AXTable` - Table/list views
- `AXScrollArea` - Scrollable areas

## Troubleshooting

### Accessibility Denied

```
Error: accessDenied
```

Enable accessibility permissions in System Preferences.

### Element Not Found

- Use Accessibility Inspector (Xcode → Open Developer Tool → Accessibility Inspector)
- Verify element has accessibility attributes
- Check element hierarchy

### App Not Found

Ensure the bundle identifier is correct:

```bash
# Find bundle ID for running apps
osascript -e 'id of app "App Name"'
```

## Development

### Run Tests

```bash
swift test
```

### Build Debug

```bash
swift build
```

## License

MIT
