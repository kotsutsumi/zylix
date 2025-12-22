#!/usr/bin/env node

/**
 * Zylix Test Framework - Playwright Bridge Server
 *
 * HTTP server that receives commands from Zig web driver and executes them using Playwright.
 */

import { createServer } from 'http';
import { chromium, firefox, webkit } from 'playwright';

const PORT = process.env.ZYLIX_TEST_PORT || 9515;
const HOST = process.env.ZYLIX_TEST_HOST || '127.0.0.1';

// Session management
const sessions = new Map();
let sessionCounter = 0;

/**
 * Session class manages a browser instance and page
 */
class Session {
  constructor(id, browser, context, page) {
    this.id = id;
    this.browser = browser;
    this.context = context;
    this.page = page;
    this.elements = new Map();
    this.elementCounter = 0;
  }

  async close() {
    await this.context.close();
    await this.browser.close();
  }

  storeElement(locator) {
    const id = String(++this.elementCounter);
    this.elements.set(id, locator);
    return id;
  }

  getElement(id) {
    return this.elements.get(String(id));
  }
}

/**
 * Parse request body as JSON
 */
async function parseBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => {
      try {
        resolve(body ? JSON.parse(body) : {});
      } catch (e) {
        reject(e);
      }
    });
    req.on('error', reject);
  });
}

/**
 * Send JSON response
 */
function sendJson(res, data, status = 200) {
  res.writeHead(status, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(data));
}

/**
 * Send error response
 */
function sendError(res, message, status = 500) {
  sendJson(res, { error: message }, status);
}

/**
 * Handle launch command - create new browser session
 */
async function handleLaunch(params) {
  const browserType = params.browser || 'chromium';
  const headless = params.headless !== false;
  const viewport = params.viewport || { width: 1280, height: 720 };
  const url = params.url || 'about:blank';

  let browserLauncher;
  switch (browserType) {
    case 'firefox':
      browserLauncher = firefox;
      break;
    case 'webkit':
      browserLauncher = webkit;
      break;
    default:
      browserLauncher = chromium;
  }

  const browser = await browserLauncher.launch({ headless });
  const context = await browser.newContext({ viewport });
  const page = await context.newPage();

  if (url !== 'about:blank') {
    await page.goto(url);
  }

  const sessionId = String(++sessionCounter);
  const session = new Session(sessionId, browser, context, page);
  sessions.set(sessionId, session);

  return { sessionId };
}

/**
 * Handle close command - close browser session
 */
async function handleClose(session) {
  await session.close();
  sessions.delete(session.id);
  return { success: true };
}

/**
 * Handle navigate command
 */
async function handleNavigate(session, params) {
  await session.page.goto(params.url);
  return { success: true };
}

/**
 * Handle findElement command
 */
async function handleFindElement(session, params) {
  const selector = params.selector;
  const locator = session.page.locator(selector).first();

  try {
    await locator.waitFor({ state: 'attached', timeout: 5000 });
    const elementId = session.storeElement(locator);
    return { elementId };
  } catch (e) {
    return { elementId: null };
  }
}

/**
 * Handle findElements command
 */
async function handleFindElements(session, params) {
  const selector = params.selector;
  const locator = session.page.locator(selector);
  const count = await locator.count();

  const elements = [];
  for (let i = 0; i < count; i++) {
    const elementId = session.storeElement(locator.nth(i));
    elements.push(elementId);
  }

  return { elements };
}

/**
 * Handle waitForSelector command
 */
async function handleWaitForSelector(session, params) {
  const selector = params.selector;
  const timeout = params.timeout || 30000;

  try {
    const locator = session.page.locator(selector).first();
    await locator.waitFor({ state: 'visible', timeout });
    const elementId = session.storeElement(locator);
    return { elementId };
  } catch (e) {
    return { error: 'timeout' };
  }
}

/**
 * Handle waitForSelectorHidden command
 */
async function handleWaitForSelectorHidden(session, params) {
  const selector = params.selector;
  const timeout = params.timeout || 30000;

  try {
    await session.page.locator(selector).first().waitFor({ state: 'hidden', timeout });
    return { success: true };
  } catch (e) {
    return { error: 'timeout' };
  }
}

/**
 * Handle click command
 */
async function handleClick(session, params) {
  const locator = session.getElement(params.elementId);
  if (!locator) return { error: 'element not found' };

  await locator.click();
  return { success: true };
}

/**
 * Handle dblclick command
 */
async function handleDblClick(session, params) {
  const locator = session.getElement(params.elementId);
  if (!locator) return { error: 'element not found' };

  await locator.dblclick();
  return { success: true };
}

/**
 * Handle longPress command (simulated with click and hold)
 */
async function handleLongPress(session, params) {
  const locator = session.getElement(params.elementId);
  if (!locator) return { error: 'element not found' };

  const duration = params.duration || 500;
  const box = await locator.boundingBox();
  if (!box) return { error: 'element not visible' };

  const x = box.x + box.width / 2;
  const y = box.y + box.height / 2;

  await session.page.mouse.move(x, y);
  await session.page.mouse.down();
  await new Promise(resolve => setTimeout(resolve, duration));
  await session.page.mouse.up();

  return { success: true };
}

/**
 * Handle type command
 */
async function handleType(session, params) {
  const locator = session.getElement(params.elementId);
  if (!locator) return { error: 'element not found' };

  await locator.fill(params.text);
  return { success: true };
}

/**
 * Handle clear command
 */
async function handleClear(session, params) {
  const locator = session.getElement(params.elementId);
  if (!locator) return { error: 'element not found' };

  await locator.clear();
  return { success: true };
}

/**
 * Handle swipe command
 */
async function handleSwipe(session, params) {
  const locator = session.getElement(params.elementId);
  if (!locator) return { error: 'element not found' };

  const box = await locator.boundingBox();
  if (!box) return { error: 'element not visible' };

  const centerX = box.x + box.width / 2;
  const centerY = box.y + box.height / 2;
  const distance = 100;

  let endX = centerX, endY = centerY;
  switch (params.direction) {
    case 'up': endY -= distance; break;
    case 'down': endY += distance; break;
    case 'left': endX -= distance; break;
    case 'right': endX += distance; break;
  }

  await session.page.mouse.move(centerX, centerY);
  await session.page.mouse.down();
  await session.page.mouse.move(endX, endY, { steps: 10 });
  await session.page.mouse.up();

  return { success: true };
}

/**
 * Handle scroll command
 */
async function handleScroll(session, params) {
  const locator = session.getElement(params.elementId);
  if (!locator) return { error: 'element not found' };

  const amount = params.amount || 0.5;
  const pixels = Math.round(amount * 500);

  let deltaX = 0, deltaY = 0;
  switch (params.direction) {
    case 'up': deltaY = -pixels; break;
    case 'down': deltaY = pixels; break;
    case 'left': deltaX = -pixels; break;
    case 'right': deltaX = pixels; break;
  }

  await locator.hover();
  await session.page.mouse.wheel(deltaX, deltaY);

  return { success: true };
}

/**
 * Handle exists command
 */
async function handleExists(session, params) {
  const locator = session.getElement(params.elementId);
  if (!locator) return { exists: false };

  const count = await locator.count();
  return { exists: count > 0 };
}

/**
 * Handle isVisible command
 */
async function handleIsVisible(session, params) {
  const locator = session.getElement(params.elementId);
  if (!locator) return { visible: false };

  const visible = await locator.isVisible();
  return { visible };
}

/**
 * Handle isEnabled command
 */
async function handleIsEnabled(session, params) {
  const locator = session.getElement(params.elementId);
  if (!locator) return { enabled: false };

  const enabled = await locator.isEnabled();
  return { enabled };
}

/**
 * Handle getText command
 */
async function handleGetText(session, params) {
  const locator = session.getElement(params.elementId);
  if (!locator) return { text: '' };

  const text = await locator.textContent();
  return { text: text || '' };
}

/**
 * Handle getAttribute command
 */
async function handleGetAttribute(session, params) {
  const locator = session.getElement(params.elementId);
  if (!locator) return { value: null };

  const value = await locator.getAttribute(params.name);
  return { value };
}

/**
 * Handle getRect command
 */
async function handleGetRect(session, params) {
  const locator = session.getElement(params.elementId);
  if (!locator) return { x: 0, y: 0, width: 0, height: 0 };

  const box = await locator.boundingBox();
  if (!box) return { x: 0, y: 0, width: 0, height: 0 };

  return {
    x: box.x,
    y: box.y,
    width: box.width,
    height: box.height
  };
}

/**
 * Handle screenshot command
 */
async function handleScreenshot(session) {
  const buffer = await session.page.screenshot({ type: 'png' });
  const base64 = buffer.toString('base64');

  const viewport = session.page.viewportSize();
  return {
    data: base64,
    width: viewport?.width || 1280,
    height: viewport?.height || 720
  };
}

/**
 * Handle elementScreenshot command
 */
async function handleElementScreenshot(session, params) {
  const locator = session.getElement(params.elementId);
  if (!locator) return { error: 'element not found' };

  const buffer = await locator.screenshot({ type: 'png' });
  const base64 = buffer.toString('base64');

  const box = await locator.boundingBox();
  return {
    data: base64,
    width: Math.round(box?.width || 100),
    height: Math.round(box?.height || 100)
  };
}

/**
 * Route request to appropriate handler
 */
async function handleRequest(req, res) {
  const url = new URL(req.url, `http://${HOST}:${PORT}`);
  const pathParts = url.pathname.split('/').filter(Boolean);

  // Parse path: /session/{sessionId}/{command}
  if (pathParts[0] !== 'session') {
    return sendError(res, 'Invalid path', 404);
  }

  const sessionIdOrNew = pathParts[1];
  const command = pathParts[2];

  try {
    const params = await parseBody(req);

    // Handle new session (launch)
    if (sessionIdOrNew === 'new' && command === 'launch') {
      const result = await handleLaunch(params);
      return sendJson(res, result);
    }

    // Get existing session
    const session = sessions.get(sessionIdOrNew);
    if (!session) {
      return sendError(res, 'Session not found', 404);
    }

    // Route to command handler
    let result;
    switch (command) {
      case 'close':
        result = await handleClose(session);
        break;
      case 'navigate':
        result = await handleNavigate(session, params);
        break;
      case 'findElement':
        result = await handleFindElement(session, params);
        break;
      case 'findElements':
        result = await handleFindElements(session, params);
        break;
      case 'waitForSelector':
        result = await handleWaitForSelector(session, params);
        break;
      case 'waitForSelectorHidden':
        result = await handleWaitForSelectorHidden(session, params);
        break;
      case 'click':
        result = await handleClick(session, params);
        break;
      case 'dblclick':
        result = await handleDblClick(session, params);
        break;
      case 'longPress':
        result = await handleLongPress(session, params);
        break;
      case 'type':
        result = await handleType(session, params);
        break;
      case 'clear':
        result = await handleClear(session, params);
        break;
      case 'swipe':
        result = await handleSwipe(session, params);
        break;
      case 'scroll':
        result = await handleScroll(session, params);
        break;
      case 'exists':
        result = await handleExists(session, params);
        break;
      case 'isVisible':
        result = await handleIsVisible(session, params);
        break;
      case 'isEnabled':
        result = await handleIsEnabled(session, params);
        break;
      case 'getText':
        result = await handleGetText(session, params);
        break;
      case 'getAttribute':
        result = await handleGetAttribute(session, params);
        break;
      case 'getRect':
        result = await handleGetRect(session, params);
        break;
      case 'screenshot':
        result = await handleScreenshot(session);
        break;
      case 'elementScreenshot':
        result = await handleElementScreenshot(session, params);
        break;
      default:
        return sendError(res, `Unknown command: ${command}`, 400);
    }

    sendJson(res, result);
  } catch (e) {
    console.error('Error handling request:', e);
    sendError(res, e.message);
  }
}

// Create and start server
const server = createServer(handleRequest);

server.listen(PORT, HOST, () => {
  console.log(`Zylix Test Server running at http://${HOST}:${PORT}`);
  console.log('Ready to accept connections from Zylix Test Framework');
});

// Graceful shutdown
process.on('SIGINT', async () => {
  console.log('\nShutting down...');
  for (const session of sessions.values()) {
    await session.close().catch(() => {});
  }
  server.close();
  process.exit(0);
});
