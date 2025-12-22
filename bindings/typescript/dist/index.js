// src/types.ts
var ZylixError = class extends Error {
  constructor(message, code, details) {
    super(message);
    this.code = code;
    this.details = details;
    this.name = "ZylixError";
  }
};
var ConnectionError = class extends ZylixError {
  constructor(message, details) {
    super(message, "CONNECTION_FAILED", details);
    this.name = "ConnectionError";
  }
};
var SessionError = class extends ZylixError {
  constructor(message, details) {
    super(message, "SESSION_ERROR", details);
    this.name = "SessionError";
  }
};
var ElementNotFoundError = class extends ZylixError {
  constructor(selector) {
    super("Element not found", "ELEMENT_NOT_FOUND", { selector });
    this.name = "ElementNotFoundError";
  }
};
var TimeoutError = class extends ZylixError {
  constructor(message, details) {
    super(message, "TIMEOUT", details);
    this.name = "TimeoutError";
  }
};

// src/selectors.ts
function byTestId(id) {
  return { testId: id };
}
function byAccessibilityId(id) {
  return { accessibilityId: id };
}
function byText(text) {
  return { text };
}
function byTextContains(text) {
  return { textContains: text };
}
function byXPath(xpath) {
  return { xpath };
}
function byCss(selector) {
  return { css: selector };
}
function byClassChain(chain) {
  return { classChain: chain };
}
function byPredicate(predicate) {
  return { predicate };
}
function byUIAutomator(selector) {
  return { uiAutomator: selector };
}
function byRole(role, title) {
  return { role, title };
}
function toWebDriverSelector(selector) {
  if (selector.testId) {
    return { using: "css selector", value: `[data-testid="${selector.testId}"]` };
  }
  if (selector.accessibilityId) {
    return { using: "accessibility id", value: selector.accessibilityId };
  }
  if (selector.text) {
    return { using: "link text", value: selector.text };
  }
  if (selector.textContains) {
    return { using: "partial link text", value: selector.textContains };
  }
  if (selector.xpath) {
    return { using: "xpath", value: selector.xpath };
  }
  if (selector.css) {
    return { using: "css selector", value: selector.css };
  }
  if (selector.classChain) {
    return { using: "-ios class chain", value: selector.classChain };
  }
  if (selector.predicate) {
    return { using: "-ios predicate string", value: selector.predicate };
  }
  if (selector.uiAutomator) {
    return { using: "-android uiautomator", value: selector.uiAutomator };
  }
  if (selector.role) {
    let predicate = `role == '${selector.role}'`;
    if (selector.title) {
      predicate += ` AND title == '${selector.title}'`;
    }
    return { using: "predicate string", value: predicate };
  }
  throw new Error("Invalid selector: no valid strategy found");
}

// src/client.ts
var HttpClient = class {
  constructor(host, port, timeout = 3e4) {
    this.host = host;
    this.port = port;
    this.timeout = timeout;
  }
  get baseUrl() {
    return `http://${this.host}:${this.port}`;
  }
  async isAvailable() {
    try {
      const response = await this.get("/status");
      return response.status === 0 || response.status === 200;
    } catch {
      return false;
    }
  }
  async get(path) {
    return this.request("GET", path);
  }
  async post(path, body) {
    return this.request("POST", path, body);
  }
  async delete(path) {
    return this.request("DELETE", path);
  }
  async request(method, path, body) {
    const url = `${this.baseUrl}${path}`;
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), this.timeout);
    try {
      const options = {
        method,
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json"
        },
        signal: controller.signal
      };
      if (body !== void 0) {
        options.body = JSON.stringify(body);
      }
      const response = await fetch(url, options);
      const data = await response.json();
      if (typeof data === "object" && data !== null) {
        if ("status" in data && "value" in data) {
          return data;
        }
        if ("value" in data) {
          return { status: 0, value: data.value };
        }
      }
      return { status: 0, value: data };
    } catch (error) {
      if (error instanceof Error) {
        if (error.name === "AbortError") {
          throw new ZylixError(`Request timeout: ${path}`, "TIMEOUT");
        }
        throw new ConnectionError(`Failed to connect to ${url}: ${error.message}`);
      }
      throw new ConnectionError(`Failed to connect to ${url}`);
    } finally {
      clearTimeout(timeoutId);
    }
  }
};

// src/element.ts
var ZylixElement = class {
  constructor(id, sessionId, client) {
    this.id = id;
    this.sessionId = sessionId;
    this.client = client;
  }
  get exists() {
    return this.id.length > 0;
  }
  async tap() {
    await this.client.post(
      `/session/${this.sessionId}/element/${this.id}/click`,
      {}
    );
  }
  async doubleTap() {
    await this.tap();
    await new Promise((resolve) => setTimeout(resolve, 50));
    await this.tap();
  }
  async longPress(durationMs = 1e3) {
    const rect = await this.getRect();
    const centerX = rect.x + rect.width / 2;
    const centerY = rect.y + rect.height / 2;
    await this.client.post(`/session/${this.sessionId}/actions`, {
      actions: [
        {
          type: "pointer",
          id: "finger1",
          parameters: { pointerType: "touch" },
          actions: [
            { type: "pointerMove", duration: 0, x: centerX, y: centerY },
            { type: "pointerDown", button: 0 },
            { type: "pause", duration: durationMs },
            { type: "pointerUp", button: 0 }
          ]
        }
      ]
    });
  }
  async type(text) {
    await this.client.post(
      `/session/${this.sessionId}/element/${this.id}/value`,
      { text, value: text.split("") }
    );
  }
  async clear() {
    await this.client.post(
      `/session/${this.sessionId}/element/${this.id}/clear`,
      {}
    );
  }
  async swipe(direction) {
    const rect = await this.getRect();
    const centerX = rect.x + rect.width / 2;
    const centerY = rect.y + rect.height / 2;
    let endX = centerX;
    let endY = centerY;
    const distance = 200;
    switch (direction) {
      case "up":
        endY = centerY - distance;
        break;
      case "down":
        endY = centerY + distance;
        break;
      case "left":
        endX = centerX - distance;
        break;
      case "right":
        endX = centerX + distance;
        break;
    }
    await this.client.post(`/session/${this.sessionId}/actions`, {
      actions: [
        {
          type: "pointer",
          id: "finger1",
          parameters: { pointerType: "touch" },
          actions: [
            { type: "pointerMove", duration: 0, x: centerX, y: centerY },
            { type: "pointerDown", button: 0 },
            { type: "pointerMove", duration: 300, x: endX, y: endY },
            { type: "pointerUp", button: 0 }
          ]
        }
      ]
    });
  }
  async getText() {
    const response = await this.client.get(
      `/session/${this.sessionId}/element/${this.id}/text`
    );
    return String(response.value ?? "");
  }
  async getAttribute(name) {
    const response = await this.client.get(
      `/session/${this.sessionId}/element/${this.id}/attribute/${name}`
    );
    return response.value;
  }
  async getRect() {
    const response = await this.client.get(
      `/session/${this.sessionId}/element/${this.id}/rect`
    );
    const rect = response.value;
    return {
      x: rect.x ?? 0,
      y: rect.y ?? 0,
      width: rect.width ?? 0,
      height: rect.height ?? 0
    };
  }
  async isVisible() {
    const response = await this.client.get(
      `/session/${this.sessionId}/element/${this.id}/displayed`
    );
    return Boolean(response.value);
  }
  async isEnabled() {
    const response = await this.client.get(
      `/session/${this.sessionId}/element/${this.id}/enabled`
    );
    return Boolean(response.value);
  }
};

// src/drivers/base.ts
var BaseSession = class {
  constructor(id, config) {
    this.id = id;
    this.config = config;
    this.client = new HttpClient(
      config.host ?? "127.0.0.1",
      config.port,
      config.timeout ?? 3e4
    );
  }
  client;
  async find(selector) {
    const { using, value } = toWebDriverSelector(selector);
    const response = await this.client.post(`/session/${this.id}/element`, {
      using,
      value
    });
    const result = response.value;
    const elementId = result.ELEMENT ?? result["element-6066-11e4-a52e-4f735466cecf"];
    if (!elementId) {
      throw new ElementNotFoundError(selector);
    }
    return new ZylixElement(elementId, this.id, this.client);
  }
  async findAll(selector) {
    const { using, value } = toWebDriverSelector(selector);
    const response = await this.client.post(`/session/${this.id}/elements`, {
      using,
      value
    });
    const results = response.value;
    return results.map((result) => {
      const elementId = result.ELEMENT ?? result["element-6066-11e4-a52e-4f735466cecf"];
      return new ZylixElement(elementId, this.id, this.client);
    });
  }
  async waitFor(selector, timeout = 1e4) {
    const startTime = Date.now();
    const pollInterval = 500;
    while (Date.now() - startTime < timeout) {
      try {
        const element = await this.find(selector);
        if (element.exists) {
          return element;
        }
      } catch (error) {
      }
      await new Promise((resolve) => setTimeout(resolve, pollInterval));
    }
    throw new TimeoutError(`Element not found within ${timeout}ms`, { selector });
  }
  async takeScreenshot() {
    const response = await this.client.get(`/session/${this.id}/screenshot`);
    const base64 = response.value;
    return Buffer.from(base64, "base64");
  }
  async getSource() {
    const response = await this.client.get(`/session/${this.id}/source`);
    return response.value;
  }
};
var BaseDriver = class {
  constructor(config) {
    this.config = config;
    this.client = new HttpClient(
      config.host ?? "127.0.0.1",
      config.port,
      config.timeout ?? 3e4
    );
  }
  client;
  async isAvailable() {
    return this.client.isAvailable();
  }
  async deleteSession(sessionId) {
    await this.client.delete(`/session/${sessionId}`);
  }
};

// src/drivers/web.ts
var WebDriverSession = class extends BaseSession {
  constructor(id, config) {
    super(id, config);
  }
  async navigateTo(url) {
    await this.client.post(`/session/${this.id}/url`, { url });
  }
  async getUrl() {
    const response = await this.client.get(`/session/${this.id}/url`);
    return response.value;
  }
  async getTitle() {
    const response = await this.client.get(`/session/${this.id}/title`);
    return response.value;
  }
  async executeScript(script, args = []) {
    const response = await this.client.post(`/session/${this.id}/execute/sync`, {
      script,
      args
    });
    return response.value;
  }
  async back() {
    await this.client.post(`/session/${this.id}/back`, {});
  }
  async forward() {
    await this.client.post(`/session/${this.id}/forward`, {});
  }
  async refresh() {
    await this.client.post(`/session/${this.id}/refresh`, {});
  }
};
var WebDriver = class extends BaseDriver {
  constructor(config = {}) {
    super({
      host: config.host ?? "127.0.0.1",
      port: config.port ?? 9515,
      timeout: config.timeout ?? 3e4,
      browser: config.browser ?? "chrome",
      headless: config.headless ?? false,
      viewportWidth: config.viewportWidth ?? 1920,
      viewportHeight: config.viewportHeight ?? 1080
    });
  }
  async createSession(options) {
    const mergedConfig = { ...this.config, ...options };
    const capabilities = {
      capabilities: {
        alwaysMatch: {
          browserName: mergedConfig.browser
        }
      }
    };
    if (mergedConfig.browser === "chrome") {
      const chromeOptions = {
        args: []
      };
      if (mergedConfig.headless) {
        chromeOptions.args.push("--headless=new");
      }
      if (mergedConfig.viewportWidth && mergedConfig.viewportHeight) {
        chromeOptions.args.push(
          `--window-size=${mergedConfig.viewportWidth},${mergedConfig.viewportHeight}`
        );
      }
      capabilities.capabilities.alwaysMatch = {
        ...capabilities.capabilities.alwaysMatch,
        "goog:chromeOptions": chromeOptions
      };
    }
    const response = await this.client.post("/session", capabilities);
    const value = response.value;
    const sessionId = value.sessionId;
    return new WebDriverSession(sessionId, mergedConfig);
  }
};

// src/drivers/ios.ts
var IOSDriverSession = class extends BaseSession {
  constructor(id, config) {
    super(id, config);
  }
  async tapAt(x, y) {
    await this.client.post(`/session/${this.id}/actions`, {
      actions: [
        {
          type: "pointer",
          id: "finger1",
          parameters: { pointerType: "touch" },
          actions: [
            { type: "pointerMove", duration: 0, x, y },
            { type: "pointerDown", button: 0 },
            { type: "pointerUp", button: 0 }
          ]
        }
      ]
    });
  }
  async swipe(startX, startY, endX, endY, durationMs = 500) {
    await this.client.post(`/session/${this.id}/actions`, {
      actions: [
        {
          type: "pointer",
          id: "finger1",
          parameters: { pointerType: "touch" },
          actions: [
            { type: "pointerMove", duration: 0, x: startX, y: startY },
            { type: "pointerDown", button: 0 },
            { type: "pointerMove", duration: durationMs, x: endX, y: endY },
            { type: "pointerUp", button: 0 }
          ]
        }
      ]
    });
  }
  async shake() {
    await this.client.post(`/session/${this.id}/wda/shake`, {});
  }
  async lock() {
    await this.client.post(`/session/${this.id}/wda/lock`, {});
  }
  async unlock() {
    await this.client.post(`/session/${this.id}/wda/unlock`, {});
  }
};
var IOSDriver = class extends BaseDriver {
  constructor(config = {}) {
    super({
      host: config.host ?? "127.0.0.1",
      port: config.port ?? 8100,
      timeout: config.timeout ?? 3e4,
      bundleId: config.bundleId,
      deviceUdid: config.deviceUdid,
      useSimulator: config.useSimulator ?? true,
      simulatorType: config.simulatorType ?? "iPhone 15 Pro",
      platformVersion: config.platformVersion ?? "17.0"
    });
  }
  async createSession(options) {
    const mergedConfig = { ...this.config, ...options };
    const capabilities = {
      capabilities: {
        alwaysMatch: {
          platformName: "iOS",
          "appium:automationName": "XCUITest",
          "appium:deviceName": mergedConfig.simulatorType,
          "appium:platformVersion": mergedConfig.platformVersion
        }
      }
    };
    if (mergedConfig.bundleId) {
      capabilities.capabilities.alwaysMatch = {
        ...capabilities.capabilities.alwaysMatch,
        "appium:bundleId": mergedConfig.bundleId
      };
    }
    if (mergedConfig.deviceUdid) {
      capabilities.capabilities.alwaysMatch = {
        ...capabilities.capabilities.alwaysMatch,
        "appium:udid": mergedConfig.deviceUdid
      };
    }
    const response = await this.client.post("/session", capabilities);
    const value = response.value;
    const sessionId = value.sessionId;
    return new IOSDriverSession(sessionId, mergedConfig);
  }
};

// src/drivers/watchos.ts
var WatchOSDriverSession = class extends IOSDriverSession {
  constructor(id, config) {
    super(id, config);
  }
  /**
   * Rotate the Digital Crown
   * @param direction - 'up' (clockwise) or 'down' (counter-clockwise)
   * @param velocity - Rotation speed (0.0 to 1.0)
   */
  async rotateDigitalCrown(direction, velocity = 0.5) {
    await this.client.post(`/session/${this.id}/wda/digitalCrown/rotate`, {
      direction,
      velocity
    });
  }
  /**
   * Press the Side Button
   * @param durationMs - Press duration in milliseconds
   */
  async pressSideButton(durationMs = 100) {
    await this.client.post(`/session/${this.id}/wda/sideButton/press`, {
      duration: durationMs
    });
  }
  /**
   * Double-press the Side Button (Apple Pay / Wallet)
   */
  async doublePresssSideButton() {
    await this.client.post(`/session/${this.id}/wda/sideButton/doublePress`, {});
  }
  /**
   * Get companion iPhone device info
   */
  async getCompanionDeviceInfo() {
    try {
      const response = await this.client.get(`/session/${this.id}/wda/companion/info`);
      const value = response.value;
      if (!value) {
        return null;
      }
      return {
        deviceName: value.deviceName,
        udid: value.udid,
        isPaired: Boolean(value.isPaired)
      };
    } catch {
      return null;
    }
  }
};
var WatchOSDriver = class extends IOSDriver {
  watchConfig;
  constructor(config = {}) {
    super({
      host: config.host ?? "127.0.0.1",
      port: config.port ?? 8100,
      timeout: config.timeout ?? 3e4,
      bundleId: config.bundleId,
      deviceUdid: config.deviceUdid,
      useSimulator: config.useSimulator ?? true,
      simulatorType: config.simulatorType ?? "Apple Watch Series 9 (45mm)",
      platformVersion: config.platformVersion ?? "11.0"
    });
    this.watchConfig = {
      ...this.config,
      companionDeviceUdid: config.companionDeviceUdid,
      watchosVersion: config.watchosVersion ?? "11.0"
    };
  }
  async createSession(options) {
    const mergedConfig = { ...this.watchConfig, ...options };
    const capabilities = {
      capabilities: {
        alwaysMatch: {
          platformName: "iOS",
          "appium:automationName": "XCUITest",
          "appium:deviceName": mergedConfig.simulatorType,
          "appium:platformVersion": mergedConfig.watchosVersion
        }
      }
    };
    if (mergedConfig.bundleId) {
      capabilities.capabilities.alwaysMatch = {
        ...capabilities.capabilities.alwaysMatch,
        "appium:bundleId": mergedConfig.bundleId
      };
    }
    if (mergedConfig.deviceUdid) {
      capabilities.capabilities.alwaysMatch = {
        ...capabilities.capabilities.alwaysMatch,
        "appium:udid": mergedConfig.deviceUdid
      };
    }
    if (mergedConfig.companionDeviceUdid) {
      capabilities.capabilities.alwaysMatch = {
        ...capabilities.capabilities.alwaysMatch,
        "appium:companionUdid": mergedConfig.companionDeviceUdid
      };
    }
    const response = await this.client.post("/session", capabilities);
    const value = response.value;
    const sessionId = value.sessionId;
    return new WatchOSDriverSession(sessionId, mergedConfig);
  }
};

// src/drivers/android.ts
var AndroidDriverSession = class extends BaseSession {
  constructor(id, config) {
    super(id, config);
  }
  async pressBack() {
    await this.client.post(`/session/${this.id}/back`, {});
  }
  async pressHome() {
    await this.client.post(`/session/${this.id}/appium/device/press_keycode`, {
      keycode: 3
      // KEYCODE_HOME
    });
  }
  async pressRecentApps() {
    await this.client.post(`/session/${this.id}/appium/device/press_keycode`, {
      keycode: 187
      // KEYCODE_APP_SWITCH
    });
  }
  async openNotifications() {
    await this.client.post(`/session/${this.id}/appium/device/open_notifications`, {});
  }
};
var AndroidDriver = class extends BaseDriver {
  constructor(config = {}) {
    super({
      host: config.host ?? "127.0.0.1",
      port: config.port ?? 4723,
      timeout: config.timeout ?? 3e4,
      packageName: config.packageName,
      activityName: config.activityName,
      deviceId: config.deviceId,
      platformVersion: config.platformVersion ?? "14",
      automationName: config.automationName ?? "UiAutomator2"
    });
  }
  async createSession(options) {
    const mergedConfig = { ...this.config, ...options };
    const capabilities = {
      capabilities: {
        alwaysMatch: {
          platformName: "Android",
          "appium:automationName": mergedConfig.automationName,
          "appium:platformVersion": mergedConfig.platformVersion
        }
      }
    };
    const alwaysMatch = capabilities.capabilities.alwaysMatch;
    if (mergedConfig.packageName) {
      alwaysMatch["appium:appPackage"] = mergedConfig.packageName;
    }
    if (mergedConfig.activityName) {
      alwaysMatch["appium:appActivity"] = mergedConfig.activityName;
    }
    if (mergedConfig.deviceId) {
      alwaysMatch["appium:udid"] = mergedConfig.deviceId;
    }
    const response = await this.client.post("/session", capabilities);
    const value = response.value;
    const sessionId = value.sessionId;
    return new AndroidDriverSession(sessionId, mergedConfig);
  }
};

// src/drivers/macos.ts
var MacOSDriverSession = class extends BaseSession {
  constructor(id, config) {
    super(id, config);
  }
  async getWindows() {
    const response = await this.client.get(`/session/${this.id}/windows`);
    const windows = response.value;
    return windows.map((w) => ({
      id: w.id,
      title: w.title,
      position: {
        x: w.x ?? 0,
        y: w.y ?? 0
      },
      size: {
        width: w.width ?? 0,
        height: w.height ?? 0
      }
    }));
  }
  async activateWindow(windowId) {
    await this.client.post(`/session/${this.id}/window/${windowId}/activate`, {});
  }
  async pressKey(key, modifiers = []) {
    await this.client.post(`/session/${this.id}/keys`, {
      key,
      modifiers
    });
  }
  async typeText(text) {
    await this.client.post(`/session/${this.id}/type`, { text });
  }
};
var MacOSDriver = class extends BaseDriver {
  constructor(config = {}) {
    super({
      host: config.host ?? "127.0.0.1",
      port: config.port ?? 8200,
      timeout: config.timeout ?? 3e4,
      bundleId: config.bundleId
    });
  }
  async createSession(options) {
    const mergedConfig = { ...this.config, ...options };
    const capabilities = {
      capabilities: {
        bundleId: mergedConfig.bundleId,
        platformName: "macOS"
      }
    };
    const response = await this.client.post("/session", capabilities);
    const value = response.value;
    const sessionId = value.sessionId;
    return new MacOSDriverSession(sessionId, mergedConfig);
  }
};

// src/index.ts
var DefaultPorts = {
  web: 9515,
  // ChromeDriver
  ios: 8100,
  // WebDriverAgent
  watchos: 8100,
  // WebDriverAgent (same as iOS)
  android: 4723,
  // Appium
  macos: 8200,
  // Accessibility Bridge
  linux: 8300,
  // AT-SPI Bridge
  windows: 4723
  // WinAppDriver
};
export {
  AndroidDriver,
  AndroidDriverSession,
  ConnectionError,
  DefaultPorts,
  ElementNotFoundError,
  IOSDriver,
  IOSDriverSession,
  MacOSDriver,
  MacOSDriverSession,
  SessionError,
  TimeoutError,
  WatchOSDriver,
  WatchOSDriverSession,
  WebDriver,
  WebDriverSession,
  ZylixError,
  byAccessibilityId,
  byClassChain,
  byCss,
  byPredicate,
  byRole,
  byTestId,
  byText,
  byTextContains,
  byUIAutomator,
  byXPath
};
//# sourceMappingURL=index.js.map