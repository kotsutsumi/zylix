# @zylix/test

> Cross-platform E2E testing for iOS, watchOS, Android, macOS, and Web

[![npm version](https://badge.fury.io/js/@zylix%2Ftest.svg)](https://www.npmjs.com/package/@zylix/test)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Installation

```bash
npm install @zylix/test
# or
yarn add @zylix/test
# or
pnpm add @zylix/test
```

## Quick Start

### Web Testing

```typescript
import { WebDriver, byTestId, byCss } from '@zylix/test';

async function main() {
    // Create driver (connects to ChromeDriver on port 9515)
    const driver = new WebDriver();

    // Create session
    const session = await driver.createSession();

    try {
        // Navigate and interact
        await session.navigateTo('https://example.com');

        const heading = await session.find(byCss('h1'));
        console.log(await heading.getText());

        const button = await session.find(byTestId('submit'));
        await button.tap();

        // Take screenshot
        const screenshot = await session.takeScreenshot();
    } finally {
        await driver.deleteSession(session.id);
    }
}
```

### iOS Testing

```typescript
import { IOSDriver, byAccessibilityId } from '@zylix/test';

const driver = new IOSDriver({
    bundleId: 'com.example.app',
});

const session = await driver.createSession();

const button = await session.find(byAccessibilityId('submit-button'));
await button.tap();

await driver.deleteSession(session.id);
```

### watchOS Testing

```typescript
import { WatchOSDriver, byAccessibilityId } from '@zylix/test';

const driver = new WatchOSDriver({
    bundleId: 'com.example.watchapp',
    simulatorType: 'Apple Watch Series 9 (45mm)',
});

const session = await driver.createSession();

// Rotate Digital Crown
await session.rotateDigitalCrown('up', 0.5);

// Press Side Button
await session.pressSideButton();

// Double-press for Apple Pay
await session.doublePresssSideButton();

// Get companion device info
const companion = await session.getCompanionDeviceInfo();
console.log('Paired with:', companion?.deviceName);

await driver.deleteSession(session.id);
```

### Android Testing

```typescript
import { AndroidDriver, byUIAutomator } from '@zylix/test';

const driver = new AndroidDriver({
    packageName: 'com.example.app',
});

const session = await driver.createSession();

const element = await session.find(
    byUIAutomator('new UiSelector().text("Login")')
);
await element.tap();

await session.pressBack();
await session.pressHome();

await driver.deleteSession(session.id);
```

### macOS Testing

```typescript
import { MacOSDriver, byRole } from '@zylix/test';

const driver = new MacOSDriver({
    bundleId: 'com.apple.finder',
});

const session = await driver.createSession();

// Get windows
const windows = await session.getWindows();
console.log(`Found ${windows.length} windows`);

// Press keyboard shortcut
await session.pressKey('n', ['command']); // Cmd+N

// Type text
await session.typeText('Hello World');

await driver.deleteSession(session.id);
```

## Selectors

```typescript
import {
    byTestId,          // data-testid attribute (web)
    byAccessibilityId, // Accessibility identifier
    byText,            // Exact text match
    byTextContains,    // Partial text match
    byXPath,           // XPath expression
    byCss,             // CSS selector (web)
    byClassChain,      // iOS class chain
    byPredicate,       // iOS predicate string
    byUIAutomator,     // Android UIAutomator
    byRole,            // Accessibility role (macOS)
} from '@zylix/test';
```

## Element Actions

```typescript
// Tap / Click
await element.tap();
await element.doubleTap();
await element.longPress(1000); // 1 second

// Text input
await element.type('Hello');
await element.clear();

// Gestures
await element.swipe('up');
await element.swipe('down');
await element.swipe('left');
await element.swipe('right');

// Properties
const text = await element.getText();
const visible = await element.isVisible();
const enabled = await element.isEnabled();
const rect = await element.getRect();
const attr = await element.getAttribute('value');
```

## Session Actions

```typescript
// Find elements
const element = await session.find(selector);
const elements = await session.findAll(selector);
const element = await session.waitFor(selector, 10000);

// Screenshot
const screenshot = await session.takeScreenshot();

// Page source
const source = await session.getSource();
```

## Configuration

### Web Driver

```typescript
const driver = new WebDriver({
    host: '127.0.0.1',
    port: 9515,
    browser: 'chrome',    // chrome, firefox, safari, edge
    headless: true,
    viewportWidth: 1920,
    viewportHeight: 1080,
    timeout: 30000,
});
```

### iOS Driver

```typescript
const driver = new IOSDriver({
    host: '127.0.0.1',
    port: 8100,
    bundleId: 'com.example.app',
    deviceUdid: 'DEVICE-UDID',
    useSimulator: true,
    simulatorType: 'iPhone 15 Pro',
    platformVersion: '17.0',
});
```

### watchOS Driver

```typescript
const driver = new WatchOSDriver({
    bundleId: 'com.example.watchapp',
    simulatorType: 'Apple Watch Series 9 (45mm)',
    watchosVersion: '11.0',
    companionDeviceUdid: 'IPHONE-UDID',
});
```

### Android Driver

```typescript
const driver = new AndroidDriver({
    host: '127.0.0.1',
    port: 4723,
    packageName: 'com.example.app',
    activityName: '.MainActivity',
    deviceId: 'emulator-5554',
    platformVersion: '14',
    automationName: 'UiAutomator2',
});
```

### macOS Driver

```typescript
const driver = new MacOSDriver({
    host: '127.0.0.1',
    port: 8200,
    bundleId: 'com.apple.finder',
});
```

## Error Handling

```typescript
import {
    ZylixError,
    ConnectionError,
    SessionError,
    ElementNotFoundError,
    TimeoutError,
} from '@zylix/test';

try {
    const element = await session.find(byTestId('not-exist'));
} catch (error) {
    if (error instanceof ElementNotFoundError) {
        console.log('Element not found');
    } else if (error instanceof TimeoutError) {
        console.log('Timeout waiting for element');
    } else if (error instanceof ConnectionError) {
        console.log('Failed to connect to driver');
    }
}
```

## Default Ports

```typescript
import { DefaultPorts } from '@zylix/test';

console.log(DefaultPorts.web);      // 9515 (ChromeDriver)
console.log(DefaultPorts.ios);      // 8100 (WebDriverAgent)
console.log(DefaultPorts.watchos);  // 8100 (WebDriverAgent)
console.log(DefaultPorts.android);  // 4723 (Appium)
console.log(DefaultPorts.macos);    // 8200 (Accessibility Bridge)
```

## Requirements

- Node.js 18+
- Platform-specific drivers:
  - Web: ChromeDriver, GeckoDriver, or SafariDriver
  - iOS/watchOS: WebDriverAgent
  - Android: Appium with UIAutomator2
  - macOS: Zylix Accessibility Bridge

## License

MIT
