/**
 * Zylix Test Framework - TypeScript Types
 */

// Platform types
export type Platform = 'ios' | 'watchos' | 'android' | 'macos' | 'windows' | 'linux' | 'web';

export type BrowserType = 'chrome' | 'firefox' | 'safari' | 'edge';

export type SwipeDirection = 'up' | 'down' | 'left' | 'right';

export type CrownDirection = 'up' | 'down';

// Configuration types
export interface DriverConfig {
    host?: string;
    port: number;
    timeout?: number;
    commandTimeout?: number;
}

export interface WebDriverConfig extends DriverConfig {
    browser?: BrowserType;
    headless?: boolean;
    viewportWidth?: number;
    viewportHeight?: number;
}

export interface IOSDriverConfig extends DriverConfig {
    bundleId?: string;
    deviceUdid?: string;
    useSimulator?: boolean;
    simulatorType?: string;
    platformVersion?: string;
}

export interface WatchOSDriverConfig extends IOSDriverConfig {
    companionDeviceUdid?: string;
    watchosVersion?: string;
}

export interface AndroidDriverConfig extends DriverConfig {
    packageName?: string;
    activityName?: string;
    deviceId?: string;
    platformVersion?: string;
    automationName?: string;
}

export interface MacOSDriverConfig extends DriverConfig {
    bundleId?: string;
}

// Selector types
export interface Selector {
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

// Element types
export interface ElementRect {
    x: number;
    y: number;
    width: number;
    height: number;
}

export interface Element {
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

// Session types
export interface Session {
    id: string;
    find(selector: Selector): Promise<Element>;
    findAll(selector: Selector): Promise<Element[]>;
    waitFor(selector: Selector, timeout?: number): Promise<Element>;
    takeScreenshot(): Promise<Buffer>;
    getSource(): Promise<string>;
}

// Platform-specific session extensions
export interface WebSession extends Session {
    navigateTo(url: string): Promise<void>;
    getUrl(): Promise<string>;
    getTitle(): Promise<string>;
    executeScript<T>(script: string, args?: unknown[]): Promise<T>;
    back(): Promise<void>;
    forward(): Promise<void>;
    refresh(): Promise<void>;
}

export interface IOSSession extends Session {
    tapAt(x: number, y: number): Promise<void>;
    swipe(startX: number, startY: number, endX: number, endY: number, durationMs?: number): Promise<void>;
    shake(): Promise<void>;
    lock(): Promise<void>;
    unlock(): Promise<void>;
}

export interface WatchOSSession extends IOSSession {
    rotateDigitalCrown(direction: CrownDirection, velocity?: number): Promise<void>;
    pressSideButton(durationMs?: number): Promise<void>;
    doublePresssSideButton(): Promise<void>;
    getCompanionDeviceInfo(): Promise<CompanionDeviceInfo | null>;
}

export interface AndroidSession extends Session {
    pressBack(): Promise<void>;
    pressHome(): Promise<void>;
    pressRecentApps(): Promise<void>;
    openNotifications(): Promise<void>;
}

export interface MacOSSession extends Session {
    getWindows(): Promise<WindowInfo[]>;
    activateWindow(windowId: string): Promise<void>;
    pressKey(key: string, modifiers?: KeyModifier[]): Promise<void>;
    typeText(text: string): Promise<void>;
}

// Supporting types
export interface CompanionDeviceInfo {
    deviceName?: string;
    udid?: string;
    isPaired: boolean;
}

export interface WindowInfo {
    id: string;
    title?: string;
    position: { x: number; y: number };
    size: { width: number; height: number };
}

export type KeyModifier = 'command' | 'option' | 'control' | 'shift' | 'fn';

// Error types
export class ZylixError extends Error {
    constructor(
        message: string,
        public readonly code: string,
        public readonly details?: unknown
    ) {
        super(message);
        this.name = 'ZylixError';
    }
}

export class ConnectionError extends ZylixError {
    constructor(message: string, details?: unknown) {
        super(message, 'CONNECTION_FAILED', details);
        this.name = 'ConnectionError';
    }
}

export class SessionError extends ZylixError {
    constructor(message: string, details?: unknown) {
        super(message, 'SESSION_ERROR', details);
        this.name = 'SessionError';
    }
}

export class ElementNotFoundError extends ZylixError {
    constructor(selector: Selector) {
        super('Element not found', 'ELEMENT_NOT_FOUND', { selector });
        this.name = 'ElementNotFoundError';
    }
}

export class TimeoutError extends ZylixError {
    constructor(message: string, details?: unknown) {
        super(message, 'TIMEOUT', details);
        this.name = 'TimeoutError';
    }
}
