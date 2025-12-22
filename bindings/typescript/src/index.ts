/**
 * Zylix Test Framework - TypeScript Bindings
 *
 * Cross-platform E2E testing for iOS, watchOS, Android, macOS, and Web.
 *
 * @example
 * ```typescript
 * import { WebDriver, byTestId } from '@zylix/test';
 *
 * const driver = new WebDriver();
 * const session = await driver.createSession();
 *
 * await session.navigateTo('https://example.com');
 * const button = await session.find(byTestId('submit'));
 * await button.tap();
 *
 * await driver.deleteSession(session.id);
 * ```
 */

// Types
export type {
    // Platform types
    Platform,
    BrowserType,
    SwipeDirection,
    CrownDirection,

    // Configuration types
    DriverConfig,
    WebDriverConfig,
    IOSDriverConfig,
    WatchOSDriverConfig,
    AndroidDriverConfig,
    MacOSDriverConfig,

    // Selector and Element types
    Selector,
    Element,
    ElementRect,

    // Session types
    Session,
    WebSession,
    IOSSession,
    WatchOSSession,
    AndroidSession,
    MacOSSession,

    // Supporting types
    CompanionDeviceInfo,
    WindowInfo,
    KeyModifier,
} from './types.js';

// Error classes
export {
    ZylixError,
    ConnectionError,
    SessionError,
    ElementNotFoundError,
    TimeoutError,
} from './types.js';

// Selectors
export {
    byTestId,
    byAccessibilityId,
    byText,
    byTextContains,
    byXPath,
    byCss,
    byClassChain,
    byPredicate,
    byUIAutomator,
    byRole,
} from './selectors.js';

// Drivers
export {
    WebDriver,
    WebDriverSession,
    IOSDriver,
    IOSDriverSession,
    WatchOSDriver,
    WatchOSDriverSession,
    AndroidDriver,
    AndroidDriverSession,
    MacOSDriver,
    MacOSDriverSession,
} from './drivers/index.js';

// Default ports for convenience
export const DefaultPorts = {
    web: 9515,        // ChromeDriver
    ios: 8100,        // WebDriverAgent
    watchos: 8100,    // WebDriverAgent (same as iOS)
    android: 4723,    // Appium
    macos: 8200,      // Accessibility Bridge
    linux: 8300,      // AT-SPI Bridge
    windows: 4723,    // WinAppDriver
} as const;
