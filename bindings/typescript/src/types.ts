/**
 * Zylix Test Framework - TypeScript Types
 */

// ============================================================================
// Zylix Core Types (matching core/src/events.zig and ABI)
// ============================================================================

/**
 * Result codes returned by Zylix functions.
 * Matches ABI specification and platform shells.
 */
export enum ZylixResult {
    OK = 0,
    INVALID_ARGUMENT = 1,
    OUT_OF_MEMORY = 2,
    INVALID_STATE = 3,
    NOT_INITIALIZED = 4,
}

/**
 * Event priority levels for queue ordering.
 */
export enum ZylixPriority {
    LOW = 0,
    NORMAL = 1,
    HIGH = 2,
    IMMEDIATE = 3,
}

/**
 * Event type constants matching core/src/events.zig.
 * These values are used when dispatching events to Zylix Core.
 */
export const ZylixEventType = {
    // Lifecycle events (0x0000 - 0x00FF)
    APP_INIT: 0x0001,
    APP_TERMINATE: 0x0002,
    APP_FOREGROUND: 0x0003,
    APP_BACKGROUND: 0x0004,
    APP_LOW_MEMORY: 0x0005,

    // User interaction (0x0100 - 0x01FF)
    BUTTON_PRESS: 0x0100,
    TEXT_INPUT: 0x0101,
    TEXT_COMMIT: 0x0102,
    SELECTION: 0x0103,
    SCROLL: 0x0104,
    GESTURE: 0x0105,

    // Navigation (0x0200 - 0x02FF)
    NAVIGATE: 0x0200,
    NAVIGATE_BACK: 0x0201,
    TAB_SWITCH: 0x0202,

    // Counter PoC events (0x1000 - 0x1FFF)
    COUNTER_INCREMENT: 0x1000,
    COUNTER_DECREMENT: 0x1001,
    COUNTER_RESET: 0x1002,

    // Todo events (0x2000 - 0x2FFF)
    TODO_ADD: 0x2000,
    TODO_REMOVE: 0x2001,
    TODO_TOGGLE: 0x2002,
    TODO_TOGGLE_ALL: 0x2003,
    TODO_CLEAR_COMPLETED: 0x2004,
    TODO_SET_FILTER: 0x2005,
    TODO_UPDATE_TEXT: 0x2006,
} as const;

export type ZylixEventTypeValue = typeof ZylixEventType[keyof typeof ZylixEventType];

/**
 * Todo filter modes.
 */
export enum TodoFilterMode {
    ALL = 0,
    ACTIVE = 1,
    COMPLETED = 2,
}

/**
 * Todo item representation.
 */
export interface TodoItem {
    id: number;
    text: string;
    completed: boolean;
}

// ============================================================================
// Test Framework Types
// ============================================================================

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
