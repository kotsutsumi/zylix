# Web E2E Test Demo

Demonstrates Zylix Test Framework for web browser testing with ChromeDriver.

## Prerequisites

1. **ChromeDriver** - Download from https://chromedriver.chromium.org/
2. **Chrome Browser** - Matching version
3. **Node.js 18+** - For running JavaScript tests

## Setup

```bash
# Start ChromeDriver
chromedriver --port=9515

# Or use Playwright's built-in browser
npx playwright install chromium
```

## Run Tests

```bash
# Using Zig (native)
cd ../../../core
zig build test-e2e

# Using Node.js (wrapper)
npm install
npm test
```

## Test Examples

### Session Management

```javascript
// tests/session.spec.js
const { test, expect } = require('@playwright/test');

test('create and delete session', async ({ page }) => {
    // Zylix Test wraps this automatically
    await page.goto('https://example.com');
    await expect(page).toHaveTitle('Example Domain');
});
```

### Element Finding

```javascript
test('find elements by selector', async ({ page }) => {
    await page.goto('https://example.com');

    // CSS selector
    const heading = await page.locator('h1');
    await expect(heading).toHaveText('Example Domain');

    // XPath
    const paragraph = await page.locator('//p[contains(text(), "for use")]');
    await expect(paragraph).toBeVisible();
});
```

### Form Interaction

```javascript
test('fill and submit form', async ({ page }) => {
    await page.goto('https://httpbin.org/forms/post');

    await page.fill('input[name="custname"]', 'Test User');
    await page.fill('input[name="custemail"]', 'test@example.com');
    await page.click('button[type="submit"]');

    // Verify form submitted
    await expect(page).toHaveURL(/\/post$/);
});
```

### Screenshots

```javascript
test('capture screenshot', async ({ page }) => {
    await page.goto('https://example.com');
    await page.screenshot({ path: 'screenshots/example.png' });
});
```

## Zig Native Usage

```zig
const std = @import("std");
const web_test = @import("web_e2e_test.zig");

test "web session" {
    const allocator = std.testing.allocator;

    if (!web_test.isWebDriverAvailable()) {
        std.debug.print("ChromeDriver not available\n", .{});
        return;
    }

    const response = try web_test.createSession(allocator);
    defer allocator.free(response);

    // Parse session ID and run tests...
}
```

## Configuration

### playwright.config.js

```javascript
module.exports = {
    testDir: './tests',
    timeout: 30000,
    use: {
        baseURL: 'http://localhost:3000',
        headless: true,
        screenshot: 'only-on-failure',
    },
    webServer: {
        command: 'npm run serve',
        port: 3000,
        reuseExistingServer: true,
    },
};
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| ChromeDriver not found | Add to PATH or specify full path |
| Version mismatch | Match ChromeDriver version to Chrome |
| Port in use | Kill existing process or use different port |
| Timeout errors | Increase timeout in config |
