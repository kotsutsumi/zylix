"""
Zylix Test Framework - Type Definitions
"""

from dataclasses import dataclass, field
from enum import Enum, IntEnum
from typing import Literal, Protocol, TypedDict


# ============================================================================
# Zylix Core Types (matching core/src/events.zig and ABI)
# ============================================================================


class ZylixResult(IntEnum):
    """Result codes returned by Zylix functions.

    Matches ABI specification and platform shells.
    """

    OK = 0
    INVALID_ARGUMENT = 1
    OUT_OF_MEMORY = 2
    INVALID_STATE = 3
    NOT_INITIALIZED = 4


class ZylixPriority(IntEnum):
    """Event priority levels for queue ordering."""

    LOW = 0
    NORMAL = 1
    HIGH = 2
    IMMEDIATE = 3


class ZylixEventType(IntEnum):
    """Event type constants matching core/src/events.zig.

    These values are used when dispatching events to Zylix Core.
    """

    # Lifecycle events (0x0000 - 0x00FF)
    APP_INIT = 0x0001
    APP_TERMINATE = 0x0002
    APP_FOREGROUND = 0x0003
    APP_BACKGROUND = 0x0004
    APP_LOW_MEMORY = 0x0005

    # User interaction (0x0100 - 0x01FF)
    BUTTON_PRESS = 0x0100
    TEXT_INPUT = 0x0101
    TEXT_COMMIT = 0x0102
    SELECTION = 0x0103
    SCROLL = 0x0104
    GESTURE = 0x0105

    # Navigation (0x0200 - 0x02FF)
    NAVIGATE = 0x0200
    NAVIGATE_BACK = 0x0201
    TAB_SWITCH = 0x0202

    # Counter PoC events (0x1000 - 0x1FFF)
    COUNTER_INCREMENT = 0x1000
    COUNTER_DECREMENT = 0x1001
    COUNTER_RESET = 0x1002

    # Todo events (0x2000 - 0x2FFF)
    TODO_ADD = 0x2000
    TODO_REMOVE = 0x2001
    TODO_TOGGLE = 0x2002
    TODO_TOGGLE_ALL = 0x2003
    TODO_CLEAR_COMPLETED = 0x2004
    TODO_SET_FILTER = 0x2005
    TODO_UPDATE_TEXT = 0x2006


class TodoFilterMode(IntEnum):
    """Todo filter modes."""

    ALL = 0
    ACTIVE = 1
    COMPLETED = 2


@dataclass
class TodoItem:
    """Todo item representation."""

    id: int
    text: str
    completed: bool = False


# ============================================================================
# Test Framework Types
# ============================================================================

# Platform Types
Platform = Literal["web", "ios", "watchos", "android", "macos"]
BrowserType = Literal["chrome", "firefox", "safari", "edge"]
SwipeDirection = Literal["up", "down", "left", "right"]
CrownDirection = Literal["up", "down"]
KeyModifier = Literal["command", "control", "option", "shift", "fn"]


# Configuration Types
@dataclass
class DriverConfig:
    """Base driver configuration."""

    host: str = "127.0.0.1"
    port: int = 8100
    timeout: int = 30000


@dataclass
class WebDriverConfig(DriverConfig):
    """Web driver configuration."""

    port: int = 9515
    browser: BrowserType = "chrome"
    headless: bool = False
    viewport_width: int | None = None
    viewport_height: int | None = None


@dataclass
class IOSDriverConfig(DriverConfig):
    """iOS driver configuration."""

    port: int = 8100
    bundle_id: str | None = None
    device_udid: str | None = None
    use_simulator: bool = True
    simulator_type: str | None = None
    platform_version: str | None = None


@dataclass
class WatchOSDriverConfig(DriverConfig):
    """watchOS driver configuration."""

    port: int = 8100
    bundle_id: str | None = None
    simulator_type: str | None = None
    watchos_version: str | None = None
    companion_device_udid: str | None = None


@dataclass
class AndroidDriverConfig(DriverConfig):
    """Android driver configuration."""

    port: int = 4723
    package_name: str | None = None
    activity_name: str | None = None
    device_id: str | None = None
    platform_version: str = "14"
    automation_name: str = "UiAutomator2"


@dataclass
class MacOSDriverConfig(DriverConfig):
    """macOS driver configuration."""

    port: int = 8200
    bundle_id: str | None = None


# Selector Types
class SelectorStrategy(Enum):
    """Selector strategy enumeration."""

    TEST_ID = "test-id"
    ACCESSIBILITY_ID = "accessibility id"
    TEXT = "text"
    TEXT_CONTAINS = "text-contains"
    XPATH = "xpath"
    CSS = "css selector"
    CLASS_CHAIN = "class chain"
    PREDICATE = "predicate string"
    UI_AUTOMATOR = "android uiautomator"
    ROLE = "role"


@dataclass
class Selector:
    """Element selector."""

    strategy: SelectorStrategy
    value: str


# Element Types
@dataclass
class ElementRect:
    """Element rectangle with position and size."""

    x: float
    y: float
    width: float
    height: float


class Element(Protocol):
    """Element protocol for type checking."""

    async def tap(self) -> None: ...
    async def double_tap(self) -> None: ...
    async def long_press(self, duration_ms: int = 1000) -> None: ...
    async def type(self, text: str) -> None: ...
    async def clear(self) -> None: ...
    async def swipe(self, direction: SwipeDirection) -> None: ...
    async def get_text(self) -> str: ...
    async def get_attribute(self, name: str) -> str | None: ...
    async def get_rect(self) -> ElementRect: ...
    async def is_visible(self) -> bool: ...
    async def is_enabled(self) -> bool: ...


# Session Types
class Session(Protocol):
    """Base session protocol."""

    id: str

    async def find(self, selector: Selector) -> Element: ...
    async def find_all(self, selector: Selector) -> list[Element]: ...
    async def wait_for(self, selector: Selector, timeout_ms: int = 10000) -> Element: ...
    async def take_screenshot(self) -> bytes: ...
    async def get_source(self) -> str: ...


class WebSession(Session, Protocol):
    """Web session protocol."""

    async def navigate_to(self, url: str) -> None: ...
    async def get_url(self) -> str: ...
    async def get_title(self) -> str: ...
    async def execute_script(self, script: str, *args: object) -> object: ...
    async def back(self) -> None: ...
    async def forward(self) -> None: ...
    async def refresh(self) -> None: ...


class IOSSession(Session, Protocol):
    """iOS session protocol."""

    async def tap_at(self, x: float, y: float) -> None: ...
    async def swipe(
        self,
        start_x: float,
        start_y: float,
        end_x: float,
        end_y: float,
        duration_ms: int = 500,
    ) -> None: ...
    async def shake(self) -> None: ...
    async def lock(self, duration_seconds: int = 0) -> None: ...
    async def unlock(self) -> None: ...


@dataclass
class CompanionDeviceInfo:
    """watchOS companion device information."""

    device_name: str | None = None
    device_udid: str | None = None
    is_paired: bool = False


class WatchOSSession(IOSSession, Protocol):
    """watchOS session protocol."""

    async def rotate_digital_crown(
        self,
        direction: CrownDirection,
        rotation_amount: float = 1.0,
    ) -> None: ...
    async def press_side_button(self) -> None: ...
    async def double_press_side_button(self) -> None: ...
    async def get_companion_device_info(self) -> CompanionDeviceInfo | None: ...


class AndroidSession(Session, Protocol):
    """Android session protocol."""

    async def press_back(self) -> None: ...
    async def press_home(self) -> None: ...
    async def press_recent_apps(self) -> None: ...
    async def open_notifications(self) -> None: ...


@dataclass
class WindowInfo:
    """macOS window information."""

    id: str
    title: str | None = None
    x: float = 0
    y: float = 0
    width: float = 0
    height: float = 0


class MacOSSession(Session, Protocol):
    """macOS session protocol."""

    async def get_windows(self) -> list[WindowInfo]: ...
    async def activate_window(self, window_id: str) -> None: ...
    async def press_key(self, key: str, modifiers: list[KeyModifier] | None = None) -> None: ...
    async def type_text(self, text: str) -> None: ...


# Error Types
class ZylixError(Exception):
    """Base error for Zylix Test Framework."""

    def __init__(self, message: str, code: str | None = None) -> None:
        super().__init__(message)
        self.message = message
        self.code = code


class ConnectionError(ZylixError):
    """Error connecting to driver."""

    def __init__(self, message: str = "Failed to connect to driver") -> None:
        super().__init__(message, "CONNECTION_ERROR")


class SessionError(ZylixError):
    """Session-related error."""

    def __init__(self, message: str = "Session error occurred") -> None:
        super().__init__(message, "SESSION_ERROR")


class ElementNotFoundError(ZylixError):
    """Element not found error."""

    def __init__(self, selector: str = "unknown") -> None:
        super().__init__(f"Element not found: {selector}", "ELEMENT_NOT_FOUND")
        self.selector = selector


class TimeoutError(ZylixError):
    """Operation timeout error."""

    def __init__(self, operation: str = "unknown", timeout_ms: int = 0) -> None:
        super().__init__(
            f"Operation '{operation}' timed out after {timeout_ms}ms",
            "TIMEOUT",
        )
        self.operation = operation
        self.timeout_ms = timeout_ms
