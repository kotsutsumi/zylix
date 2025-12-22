/**
 * Zylix Test Framework - TypeScript Types
 */
type Platform = 'ios' | 'watchos' | 'android' | 'macos' | 'windows' | 'linux' | 'web';
type BrowserType = 'chrome' | 'firefox' | 'safari' | 'edge';
type SwipeDirection = 'up' | 'down' | 'left' | 'right';
type CrownDirection = 'up' | 'down';
interface DriverConfig {
    host?: string;
    port: number;
    timeout?: number;
    commandTimeout?: number;
}
interface WebDriverConfig extends DriverConfig {
    browser?: BrowserType;
    headless?: boolean;
    viewportWidth?: number;
    viewportHeight?: number;
}
interface IOSDriverConfig extends DriverConfig {
    bundleId?: string;
    deviceUdid?: string;
    useSimulator?: boolean;
    simulatorType?: string;
    platformVersion?: string;
}
interface WatchOSDriverConfig extends IOSDriverConfig {
    companionDeviceUdid?: string;
    watchosVersion?: string;
}
interface AndroidDriverConfig extends DriverConfig {
    packageName?: string;
    activityName?: string;
    deviceId?: string;
    platformVersion?: string;
    automationName?: string;
}
interface MacOSDriverConfig extends DriverConfig {
    bundleId?: string;
}
interface Selector {
    testId?: string;
    accessibilityId?: string;
    text?: string;
    textContains?: string;
    xpath?: string;
    css?: string;
    classChain?: string;
    predicate?: string;
    uiAutomator?: string;
    role?: string;
    title?: string;
}
interface ElementRect {
    x: number;
    y: number;
    width: number;
    height: number;
}
interface Element {
    id: string;
    exists: boolean;
    tap(): Promise<void>;
    doubleTap(): Promise<void>;
    longPress(durationMs?: number): Promise<void>;
    type(text: string): Promise<void>;
    clear(): Promise<void>;
    swipe(direction: SwipeDirection): Promise<void>;
    getText(): Promise<string>;
    getAttribute(name: string): Promise<string | null>;
    getRect(): Promise<ElementRect>;
    isVisible(): Promise<boolean>;
    isEnabled(): Promise<boolean>;
}
interface Session {
    id: string;
    find(selector: Selector): Promise<Element>;
    findAll(selector: Selector): Promise<Element[]>;
    waitFor(selector: Selector, timeout?: number): Promise<Element>;
    takeScreenshot(): Promise<Buffer>;
    getSource(): Promise<string>;
}
interface WebSession extends Session {
    navigateTo(url: string): Promise<void>;
    getUrl(): Promise<string>;
    getTitle(): Promise<string>;
    executeScript<T>(script: string, args?: unknown[]): Promise<T>;
    back(): Promise<void>;
    forward(): Promise<void>;
    refresh(): Promise<void>;
}
interface IOSSession extends Session {
    tapAt(x: number, y: number): Promise<void>;
    swipe(startX: number, startY: number, endX: number, endY: number, durationMs?: number): Promise<void>;
    shake(): Promise<void>;
    lock(): Promise<void>;
    unlock(): Promise<void>;
}
interface WatchOSSession extends IOSSession {
    rotateDigitalCrown(direction: CrownDirection, velocity?: number): Promise<void>;
    pressSideButton(durationMs?: number): Promise<void>;
    doublePresssSideButton(): Promise<void>;
    getCompanionDeviceInfo(): Promise<CompanionDeviceInfo | null>;
}
interface AndroidSession extends Session {
    pressBack(): Promise<void>;
    pressHome(): Promise<void>;
    pressRecentApps(): Promise<void>;
    openNotifications(): Promise<void>;
}
interface MacOSSession extends Session {
    getWindows(): Promise<WindowInfo[]>;
    activateWindow(windowId: string): Promise<void>;
    pressKey(key: string, modifiers?: KeyModifier[]): Promise<void>;
    typeText(text: string): Promise<void>;
}
interface CompanionDeviceInfo {
    deviceName?: string;
    udid?: string;
    isPaired: boolean;
}
interface WindowInfo {
    id: string;
    title?: string;
    position: {
        x: number;
        y: number;
    };
    size: {
        width: number;
        height: number;
    };
}
type KeyModifier = 'command' | 'option' | 'control' | 'shift' | 'fn';
declare class ZylixError extends Error {
    readonly code: string;
    readonly details?: unknown | undefined;
    constructor(message: string, code: string, details?: unknown | undefined);
}
declare class ConnectionError extends ZylixError {
    constructor(message: string, details?: unknown);
}
declare class SessionError extends ZylixError {
    constructor(message: string, details?: unknown);
}
declare class ElementNotFoundError extends ZylixError {
    constructor(selector: Selector);
}
declare class TimeoutError extends ZylixError {
    constructor(message: string, details?: unknown);
}

/**
 * Zylix Test Framework - Selector Builders
 */

/**
 * Create a selector by test ID
 */
declare function byTestId(id: string): Selector;
/**
 * Create a selector by accessibility ID
 */
declare function byAccessibilityId(id: string): Selector;
/**
 * Create a selector by exact text
 */
declare function byText(text: string): Selector;
/**
 * Create a selector by text containing
 */
declare function byTextContains(text: string): Selector;
/**
 * Create a selector by XPath
 */
declare function byXPath(xpath: string): Selector;
/**
 * Create a selector by CSS (web only)
 */
declare function byCss(selector: string): Selector;
/**
 * Create a selector by iOS class chain
 */
declare function byClassChain(chain: string): Selector;
/**
 * Create a selector by iOS predicate string
 */
declare function byPredicate(predicate: string): Selector;
/**
 * Create a selector by Android UIAutomator
 */
declare function byUIAutomator(selector: string): Selector;
/**
 * Create a selector by accessibility role (macOS)
 */
declare function byRole(role: string, title?: string): Selector;

/**
 * Zylix Test Framework - HTTP Client
 */
interface HttpResponse {
    status: number;
    value: unknown;
}
declare class HttpClient {
    private readonly host;
    private readonly port;
    private readonly timeout;
    constructor(host: string, port: number, timeout?: number);
    get baseUrl(): string;
    isAvailable(): Promise<boolean>;
    get(path: string): Promise<HttpResponse>;
    post(path: string, body?: unknown): Promise<HttpResponse>;
    delete(path: string): Promise<HttpResponse>;
    private request;
}

/**
 * Zylix Test Framework - Base Driver
 */

declare abstract class BaseSession implements Session {
    readonly id: string;
    protected readonly config: DriverConfig;
    protected client: HttpClient;
    constructor(id: string, config: DriverConfig);
    find(selector: Selector): Promise<Element>;
    findAll(selector: Selector): Promise<Element[]>;
    waitFor(selector: Selector, timeout?: number): Promise<Element>;
    takeScreenshot(): Promise<Buffer>;
    getSource(): Promise<string>;
}
declare abstract class BaseDriver<TConfig extends DriverConfig, TSession extends Session> {
    protected readonly config: TConfig;
    protected client: HttpClient;
    constructor(config: TConfig);
    isAvailable(): Promise<boolean>;
    abstract createSession(options?: Partial<TConfig>): Promise<TSession>;
    deleteSession(sessionId: string): Promise<void>;
}

/**
 * Zylix Test Framework - Web Driver
 */

declare class WebDriverSession extends BaseSession implements WebSession {
    constructor(id: string, config: WebDriverConfig);
    navigateTo(url: string): Promise<void>;
    getUrl(): Promise<string>;
    getTitle(): Promise<string>;
    executeScript<T>(script: string, args?: unknown[]): Promise<T>;
    back(): Promise<void>;
    forward(): Promise<void>;
    refresh(): Promise<void>;
}
declare class WebDriver extends BaseDriver<WebDriverConfig, WebDriverSession> {
    constructor(config?: Partial<WebDriverConfig>);
    createSession(options?: Partial<WebDriverConfig>): Promise<WebDriverSession>;
}

/**
 * Zylix Test Framework - iOS Driver
 */

declare class IOSDriverSession extends BaseSession implements IOSSession {
    constructor(id: string, config: IOSDriverConfig);
    tapAt(x: number, y: number): Promise<void>;
    swipe(startX: number, startY: number, endX: number, endY: number, durationMs?: number): Promise<void>;
    shake(): Promise<void>;
    lock(): Promise<void>;
    unlock(): Promise<void>;
}
declare class IOSDriver extends BaseDriver<IOSDriverConfig, IOSDriverSession> {
    constructor(config?: Partial<IOSDriverConfig>);
    createSession(options?: Partial<IOSDriverConfig>): Promise<IOSDriverSession>;
}

/**
 * Zylix Test Framework - watchOS Driver
 */

declare class WatchOSDriverSession extends IOSDriverSession implements WatchOSSession {
    constructor(id: string, config: WatchOSDriverConfig);
    /**
     * Rotate the Digital Crown
     * @param direction - 'up' (clockwise) or 'down' (counter-clockwise)
     * @param velocity - Rotation speed (0.0 to 1.0)
     */
    rotateDigitalCrown(direction: CrownDirection, velocity?: number): Promise<void>;
    /**
     * Press the Side Button
     * @param durationMs - Press duration in milliseconds
     */
    pressSideButton(durationMs?: number): Promise<void>;
    /**
     * Double-press the Side Button (Apple Pay / Wallet)
     */
    doublePresssSideButton(): Promise<void>;
    /**
     * Get companion iPhone device info
     */
    getCompanionDeviceInfo(): Promise<CompanionDeviceInfo | null>;
}
declare class WatchOSDriver extends IOSDriver {
    protected readonly watchConfig: WatchOSDriverConfig;
    constructor(config?: Partial<WatchOSDriverConfig>);
    createSession(options?: Partial<WatchOSDriverConfig>): Promise<WatchOSDriverSession>;
}

/**
 * Zylix Test Framework - Android Driver
 */

declare class AndroidDriverSession extends BaseSession implements AndroidSession {
    constructor(id: string, config: AndroidDriverConfig);
    pressBack(): Promise<void>;
    pressHome(): Promise<void>;
    pressRecentApps(): Promise<void>;
    openNotifications(): Promise<void>;
}
declare class AndroidDriver extends BaseDriver<AndroidDriverConfig, AndroidDriverSession> {
    constructor(config?: Partial<AndroidDriverConfig>);
    createSession(options?: Partial<AndroidDriverConfig>): Promise<AndroidDriverSession>;
}

/**
 * Zylix Test Framework - macOS Driver
 */

declare class MacOSDriverSession extends BaseSession implements MacOSSession {
    constructor(id: string, config: MacOSDriverConfig);
    getWindows(): Promise<WindowInfo[]>;
    activateWindow(windowId: string): Promise<void>;
    pressKey(key: string, modifiers?: KeyModifier[]): Promise<void>;
    typeText(text: string): Promise<void>;
}
declare class MacOSDriver extends BaseDriver<MacOSDriverConfig, MacOSDriverSession> {
    constructor(config?: Partial<MacOSDriverConfig>);
    createSession(options?: Partial<MacOSDriverConfig>): Promise<MacOSDriverSession>;
}

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

declare const DefaultPorts: {
    readonly web: 9515;
    readonly ios: 8100;
    readonly watchos: 8100;
    readonly android: 4723;
    readonly macos: 8200;
    readonly linux: 8300;
    readonly windows: 4723;
};

export { AndroidDriver, type AndroidDriverConfig, AndroidDriverSession, type AndroidSession, type BrowserType, type CompanionDeviceInfo, ConnectionError, type CrownDirection, DefaultPorts, type DriverConfig, type Element, ElementNotFoundError, type ElementRect, IOSDriver, type IOSDriverConfig, IOSDriverSession, type IOSSession, type KeyModifier, MacOSDriver, type MacOSDriverConfig, MacOSDriverSession, type MacOSSession, type Platform, type Selector, type Session, SessionError, type SwipeDirection, TimeoutError, WatchOSDriver, type WatchOSDriverConfig, WatchOSDriverSession, type WatchOSSession, WebDriver, type WebDriverConfig, WebDriverSession, type WebSession, type WindowInfo, ZylixError, byAccessibilityId, byClassChain, byCss, byPredicate, byRole, byTestId, byText, byTextContains, byUIAutomator, byXPath };
