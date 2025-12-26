"""
Zylix Test Framework - Python Bindings

Cross-platform E2E testing for iOS, watchOS, Android, macOS, and Web.

Example:
    >>> from zylix_test import WebDriver, by_test_id
    >>>
    >>> async def main():
    ...     driver = WebDriver()
    ...     session = await driver.create_session()
    ...
    ...     await session.navigate_to("https://example.com")
    ...     button = await session.find(by_test_id("submit"))
    ...     await button.tap()
    ...
    ...     await driver.delete_session(session.id)
"""

# Zylix Core Types
from .types import (
    ZylixResult,
    ZylixPriority,
    ZylixEventType,
    TodoFilterMode,
    TodoItem,
)

# Test Framework Types
from .types import (
    # Platform types
    Platform,
    BrowserType,
    SwipeDirection,
    CrownDirection,
    KeyModifier,
    # Configuration types
    DriverConfig,
    WebDriverConfig,
    IOSDriverConfig,
    WatchOSDriverConfig,
    AndroidDriverConfig,
    MacOSDriverConfig,
    # Selector types
    Selector,
    SelectorStrategy,
    # Element types
    Element,
    ElementRect,
    # Session types
    Session,
    WebSession,
    IOSSession,
    WatchOSSession,
    AndroidSession,
    MacOSSession,
    # Supporting types
    CompanionDeviceInfo,
    WindowInfo,
    # Error types
    ZylixError,
    ConnectionError,
    SessionError,
    ElementNotFoundError,
    TimeoutError,
)

# Selectors
from .selectors import (
    by_test_id,
    by_accessibility_id,
    by_text,
    by_text_contains,
    by_xpath,
    by_css,
    by_class_chain,
    by_predicate,
    by_ui_automator,
    by_role,
    to_webdriver_selector,
)

# Element
from .element import ZylixElement

# Drivers
from .drivers import (
    BaseDriver,
    BaseSession,
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
)

# Default ports
DEFAULT_PORTS = {
    "web": 9515,      # ChromeDriver
    "ios": 8100,      # WebDriverAgent
    "watchos": 8100,  # WebDriverAgent (same as iOS)
    "android": 4723,  # Appium
    "macos": 8200,    # Accessibility Bridge
    "linux": 8300,    # AT-SPI Bridge
    "windows": 4723,  # WinAppDriver
}

__version__ = "0.23.0"

__all__ = [
    # Version
    "__version__",
    # Constants
    "DEFAULT_PORTS",
    # Zylix Core Types
    "ZylixResult",
    "ZylixPriority",
    "ZylixEventType",
    "TodoFilterMode",
    "TodoItem",
    # Platform types
    "Platform",
    "BrowserType",
    "SwipeDirection",
    "CrownDirection",
    "KeyModifier",
    # Configuration types
    "DriverConfig",
    "WebDriverConfig",
    "IOSDriverConfig",
    "WatchOSDriverConfig",
    "AndroidDriverConfig",
    "MacOSDriverConfig",
    # Selector types
    "Selector",
    "SelectorStrategy",
    # Element types
    "Element",
    "ElementRect",
    "ZylixElement",
    # Session types
    "Session",
    "WebSession",
    "IOSSession",
    "WatchOSSession",
    "AndroidSession",
    "MacOSSession",
    # Supporting types
    "CompanionDeviceInfo",
    "WindowInfo",
    # Error types
    "ZylixError",
    "ConnectionError",
    "SessionError",
    "ElementNotFoundError",
    "TimeoutError",
    # Selectors
    "by_test_id",
    "by_accessibility_id",
    "by_text",
    "by_text_contains",
    "by_xpath",
    "by_css",
    "by_class_chain",
    "by_predicate",
    "by_ui_automator",
    "by_role",
    "to_webdriver_selector",
    # Drivers
    "BaseDriver",
    "BaseSession",
    "WebDriver",
    "WebDriverSession",
    "IOSDriver",
    "IOSDriverSession",
    "WatchOSDriver",
    "WatchOSDriverSession",
    "AndroidDriver",
    "AndroidDriverSession",
    "MacOSDriver",
    "MacOSDriverSession",
]
