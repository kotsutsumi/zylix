# zylix-test

> Cross-platform E2E testing for iOS, watchOS, Android, macOS, and Web

[![PyPI version](https://badge.fury.io/py/zylix-test.svg)](https://pypi.org/project/zylix-test/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python 3.10+](https://img.shields.io/badge/python-3.10+-blue.svg)](https://www.python.org/downloads/)

## Installation

```bash
pip install zylix-test
# or
uv add zylix-test
# or
poetry add zylix-test
```

## Quick Start

### Web Testing

```python
import asyncio
from zylix_test import WebDriver, by_test_id, by_css

async def main():
    # Create driver (connects to ChromeDriver on port 9515)
    driver = WebDriver()

    # Create session
    session = await driver.create_session()

    try:
        # Navigate and interact
        await session.navigate_to("https://example.com")

        heading = await session.find(by_css("h1"))
        print(await heading.get_text())

        button = await session.find(by_test_id("submit"))
        await button.tap()

        # Take screenshot
        screenshot = await session.take_screenshot()
    finally:
        await driver.delete_session(session.id)

asyncio.run(main())
```

### iOS Testing

```python
import asyncio
from zylix_test import IOSDriver, by_accessibility_id

async def main():
    driver = IOSDriver(bundle_id="com.example.app")
    session = await driver.create_session()

    button = await session.find(by_accessibility_id("submit-button"))
    await button.tap()

    await driver.delete_session(session.id)

asyncio.run(main())
```

### watchOS Testing

```python
import asyncio
from zylix_test import WatchOSDriver, by_accessibility_id

async def main():
    driver = WatchOSDriver(
        bundle_id="com.example.watchapp",
        simulator_type="Apple Watch Series 9 (45mm)",
    )
    session = await driver.create_session()

    # Rotate Digital Crown
    await session.rotate_digital_crown("up", 0.5)

    # Press Side Button
    await session.press_side_button()

    # Double-press for Apple Pay
    await session.double_press_side_button()

    # Get companion device info
    companion = await session.get_companion_device_info()
    if companion:
        print(f"Paired with: {companion.device_name}")

    await driver.delete_session(session.id)

asyncio.run(main())
```

### Android Testing

```python
import asyncio
from zylix_test import AndroidDriver, by_ui_automator

async def main():
    driver = AndroidDriver(package_name="com.example.app")
    session = await driver.create_session()

    element = await session.find(
        by_ui_automator('new UiSelector().text("Login")')
    )
    await element.tap()

    await session.press_back()
    await session.press_home()

    await driver.delete_session(session.id)

asyncio.run(main())
```

### macOS Testing

```python
import asyncio
from zylix_test import MacOSDriver, by_role

async def main():
    driver = MacOSDriver(bundle_id="com.apple.finder")
    session = await driver.create_session()

    # Get windows
    windows = await session.get_windows()
    print(f"Found {len(windows)} windows")

    # Press keyboard shortcut
    await session.press_key("n", ["command"])  # Cmd+N

    # Type text
    await session.type_text("Hello World")

    await driver.delete_session(session.id)

asyncio.run(main())
```

## Selectors

```python
from zylix_test import (
    by_test_id,          # data-testid attribute (web)
    by_accessibility_id, # Accessibility identifier
    by_text,             # Exact text match
    by_text_contains,    # Partial text match
    by_xpath,            # XPath expression
    by_css,              # CSS selector (web)
    by_class_chain,      # iOS class chain
    by_predicate,        # iOS predicate string
    by_ui_automator,     # Android UIAutomator
    by_role,             # Accessibility role (macOS)
)
```

## Element Actions

```python
# Tap / Click
await element.tap()
await element.double_tap()
await element.long_press(1000)  # 1 second

# Text input
await element.type("Hello")
await element.clear()

# Gestures
await element.swipe("up")
await element.swipe("down")
await element.swipe("left")
await element.swipe("right")

# Properties
text = await element.get_text()
visible = await element.is_visible()
enabled = await element.is_enabled()
rect = await element.get_rect()
attr = await element.get_attribute("value")
```

## Session Actions

```python
# Find elements
element = await session.find(selector)
elements = await session.find_all(selector)
element = await session.wait_for(selector, timeout_ms=10000)

# Screenshot
screenshot = await session.take_screenshot()

# Page source
source = await session.get_source()
```

## Configuration

### Web Driver

```python
driver = WebDriver(
    host="127.0.0.1",
    port=9515,
    browser="chrome",    # chrome, firefox, safari, edge
    headless=True,
    viewport_width=1920,
    viewport_height=1080,
    timeout=30000,
)
```

### iOS Driver

```python
driver = IOSDriver(
    host="127.0.0.1",
    port=8100,
    bundle_id="com.example.app",
    device_udid="DEVICE-UDID",
    use_simulator=True,
    simulator_type="iPhone 15 Pro",
    platform_version="17.0",
)
```

### watchOS Driver

```python
driver = WatchOSDriver(
    bundle_id="com.example.watchapp",
    simulator_type="Apple Watch Series 9 (45mm)",
    watchos_version="11.0",
    companion_device_udid="IPHONE-UDID",
)
```

### Android Driver

```python
driver = AndroidDriver(
    host="127.0.0.1",
    port=4723,
    package_name="com.example.app",
    activity_name=".MainActivity",
    device_id="emulator-5554",
    platform_version="14",
    automation_name="UiAutomator2",
)
```

### macOS Driver

```python
driver = MacOSDriver(
    host="127.0.0.1",
    port=8200,
    bundle_id="com.apple.finder",
)
```

## Error Handling

```python
from zylix_test import (
    ZylixError,
    ConnectionError,
    SessionError,
    ElementNotFoundError,
    TimeoutError,
)

try:
    element = await session.find(by_test_id("not-exist"))
except ElementNotFoundError:
    print("Element not found")
except TimeoutError:
    print("Timeout waiting for element")
except ConnectionError:
    print("Failed to connect to driver")
```

## Default Ports

```python
from zylix_test import DEFAULT_PORTS

print(DEFAULT_PORTS["web"])      # 9515 (ChromeDriver)
print(DEFAULT_PORTS["ios"])      # 8100 (WebDriverAgent)
print(DEFAULT_PORTS["watchos"])  # 8100 (WebDriverAgent)
print(DEFAULT_PORTS["android"])  # 4723 (Appium)
print(DEFAULT_PORTS["macos"])    # 8200 (Accessibility Bridge)
```

## Requirements

- Python 3.10+
- Platform-specific drivers:
  - Web: ChromeDriver, GeckoDriver, or SafariDriver
  - iOS/watchOS: WebDriverAgent
  - Android: Appium with UIAutomator2
  - macOS: Zylix Accessibility Bridge

## License

MIT
