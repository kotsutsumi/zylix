/**
 * Zylix Test Framework - Web Bridge Type Definitions
 *
 * TypeScript type definitions for the Playwright-based web bridge server.
 */

import type { Browser, BrowserContext, Page, Locator } from 'playwright';

// ============================================================================
// Configuration Types
// ============================================================================

export type BrowserType = 'chromium' | 'firefox' | 'webkit';

export interface Viewport {
  width: number;
  height: number;
}

export interface LaunchParams {
  /** Browser type to launch */
  browser?: BrowserType;
  /** Whether to run in headless mode */
  headless?: boolean;
  /** Initial viewport size */
  viewport?: Viewport;
  /** Initial URL to navigate to */
  url?: string;
}

// ============================================================================
// Session Types
// ============================================================================

export interface Session {
  /** Unique session identifier */
  id: string;
  /** Playwright browser instance */
  browser: Browser;
  /** Browser context */
  context: BrowserContext;
  /** Current page */
  page: Page;
  /** Stored element references */
  elements: Map<string, Locator>;
  /** Element ID counter */
  elementCounter: number;

  /** Close the session and cleanup resources */
  close(): Promise<void>;
  /** Store an element and return its ID */
  storeElement(locator: Locator): string;
  /** Get an element by ID */
  getElement(id: string): Locator | undefined;
}

// ============================================================================
// Command Parameter Types
// ============================================================================

export interface NavigateParams {
  /** URL to navigate to */
  url: string;
}

export interface FindElementParams {
  /** CSS/Playwright selector */
  selector: string;
}

export interface FindElementsParams {
  /** CSS/Playwright selector */
  selector: string;
}

export interface WaitForSelectorParams {
  /** CSS/Playwright selector */
  selector: string;
  /** Timeout in milliseconds */
  timeout?: number;
}

export interface ElementIdParams {
  /** Element reference ID */
  elementId: string;
}

export interface ClickParams extends ElementIdParams {}

export interface DblClickParams extends ElementIdParams {}

export interface LongPressParams extends ElementIdParams {
  /** Duration in milliseconds */
  duration?: number;
}

export interface TypeParams extends ElementIdParams {
  /** Text to type */
  text: string;
}

export interface ClearParams extends ElementIdParams {}

export type SwipeDirection = 'up' | 'down' | 'left' | 'right';
export type ScrollDirection = 'up' | 'down' | 'left' | 'right';

export interface SwipeParams extends ElementIdParams {
  /** Swipe direction */
  direction: SwipeDirection;
}

export interface ScrollParams extends ElementIdParams {
  /** Scroll direction */
  direction: ScrollDirection;
  /** Scroll amount (0-1, relative to viewport) */
  amount?: number;
}

export interface GetAttributeParams extends ElementIdParams {
  /** Attribute name */
  name: string;
}

export interface ElementScreenshotParams extends ElementIdParams {}

// ============================================================================
// Response Types
// ============================================================================

export interface LaunchResponse {
  /** Created session ID */
  sessionId: string;
}

export interface SuccessResponse {
  /** Whether the operation succeeded */
  success: true;
}

export interface ErrorResponse {
  /** Error message */
  error: string;
}

export interface FindElementResponse {
  /** Element ID if found, null otherwise */
  elementId: string | null;
}

export interface FindElementsResponse {
  /** Array of element IDs */
  elements: string[];
}

export interface WaitForSelectorResponse {
  /** Element ID if found */
  elementId?: string;
  /** Error type if failed */
  error?: 'timeout';
}

export interface ExistsResponse {
  /** Whether the element exists */
  exists: boolean;
}

export interface IsVisibleResponse {
  /** Whether the element is visible */
  visible: boolean;
}

export interface IsEnabledResponse {
  /** Whether the element is enabled */
  enabled: boolean;
}

export interface GetTextResponse {
  /** Element text content */
  text: string;
}

export interface GetAttributeResponse {
  /** Attribute value or null if not found */
  value: string | null;
}

export interface RectResponse {
  /** X coordinate */
  x: number;
  /** Y coordinate */
  y: number;
  /** Element width */
  width: number;
  /** Element height */
  height: number;
}

export interface ScreenshotResponse {
  /** Base64-encoded PNG data */
  data: string;
  /** Screenshot width */
  width: number;
  /** Screenshot height */
  height: number;
}

// ============================================================================
// Command Types
// ============================================================================

export type Command =
  | 'launch'
  | 'close'
  | 'navigate'
  | 'findElement'
  | 'findElements'
  | 'waitForSelector'
  | 'waitForSelectorHidden'
  | 'click'
  | 'dblclick'
  | 'longPress'
  | 'type'
  | 'clear'
  | 'swipe'
  | 'scroll'
  | 'exists'
  | 'isVisible'
  | 'isEnabled'
  | 'getText'
  | 'getAttribute'
  | 'getRect'
  | 'screenshot'
  | 'elementScreenshot';

// ============================================================================
// Server Types
// ============================================================================

export interface ServerConfig {
  /** Server port (default: 9515) */
  port?: number;
  /** Server host (default: 127.0.0.1) */
  host?: string;
}

export interface CommandRequest {
  /** Session ID */
  sessionId: string;
  /** Command to execute */
  command: Command;
  /** Command parameters */
  params?: Record<string, unknown>;
}

export type CommandResponse =
  | LaunchResponse
  | SuccessResponse
  | ErrorResponse
  | FindElementResponse
  | FindElementsResponse
  | WaitForSelectorResponse
  | ExistsResponse
  | IsVisibleResponse
  | IsEnabledResponse
  | GetTextResponse
  | GetAttributeResponse
  | RectResponse
  | ScreenshotResponse;
