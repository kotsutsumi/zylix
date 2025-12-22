# Zylix Test Framework - Web Driver

Playwright-based test driver for web platform E2E testing.

## Overview

This package provides an HTTP server that bridges the Zylix Test Framework (Zig) with Playwright for browser automation.

## Installation

```bash
cd platforms/web/zylix-test
npm install
```

## Usage

### Start the Server

```bash
npm start
```

The server runs on `http://127.0.0.1:9515` by default.

### Environment Variables

- `ZYLIX_TEST_PORT` - Server port (default: 9515)
- `ZYLIX_TEST_HOST` - Server host (default: 127.0.0.1)

### From Zig Test Code

```zig
const zylix_test = @import("zylix_test");

test "web login flow" {
    // Create web driver
    var driver = try zylix_test.createWebDriver(allocator, .{
        .browser = .chromium,
        .headless = true,
    });
    defer driver.deinit();

    // Launch app
    var app = try zylix_test.App.launch(&driver, .{
        .app_id = "web",
        .base_url = "http://localhost:3000",
    }, allocator);
    defer app.terminate() catch {};

    // Interact with elements
    try app.findByTestId("email-input").typeText("user@example.com");
    try app.findByTestId("login-button").tap();

    // Assert
    const welcome = try app.waitForText("Welcome", 5000);
    try zylix_test.expectElement(&welcome).toBeVisible();
}
```

## API Endpoints

All endpoints follow the pattern: `POST /session/{sessionId}/{command}`

### Session Management

- `POST /session/new/launch` - Create new browser session
- `POST /session/{id}/close` - Close session
- `POST /session/{id}/navigate` - Navigate to URL

### Element Finding

- `POST /session/{id}/findElement` - Find single element
- `POST /session/{id}/findElements` - Find all matching elements
- `POST /session/{id}/waitForSelector` - Wait for element to appear
- `POST /session/{id}/waitForSelectorHidden` - Wait for element to disappear

### Element Interactions

- `POST /session/{id}/click` - Click element
- `POST /session/{id}/dblclick` - Double-click element
- `POST /session/{id}/longPress` - Long press element
- `POST /session/{id}/type` - Type text into element
- `POST /session/{id}/clear` - Clear element text
- `POST /session/{id}/swipe` - Swipe on element
- `POST /session/{id}/scroll` - Scroll element

### Element Queries

- `POST /session/{id}/exists` - Check if element exists
- `POST /session/{id}/isVisible` - Check element visibility
- `POST /session/{id}/isEnabled` - Check if element is enabled
- `POST /session/{id}/getText` - Get element text
- `POST /session/{id}/getAttribute` - Get element attribute
- `POST /session/{id}/getRect` - Get element bounding rect

### Screenshots

- `POST /session/{id}/screenshot` - Take page screenshot
- `POST /session/{id}/elementScreenshot` - Take element screenshot

## Supported Browsers

- Chromium (default)
- Firefox
- WebKit (Safari)

## License

MIT
