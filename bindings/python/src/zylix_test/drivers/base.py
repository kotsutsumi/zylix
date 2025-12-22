"""
Zylix Test Framework - Base Driver
"""

import asyncio
import base64
from abc import ABC, abstractmethod
from typing import Any, Generic, TypeVar

from ..client import HttpClient
from ..element import ZylixElement
from ..selectors import to_webdriver_selector
from ..types import DriverConfig, ElementNotFoundError, Selector
from ..types import TimeoutError as ZylixTimeoutError

ConfigT = TypeVar("ConfigT", bound=DriverConfig)
SessionT = TypeVar("SessionT", bound="BaseSession[Any]")


class BaseSession(Generic[ConfigT]):
    """Base session implementation with common functionality."""

    def __init__(self, session_id: str, config: ConfigT) -> None:
        """Initialize session.

        Args:
            session_id: WebDriver session ID
            config: Driver configuration
        """
        self._id = session_id
        self._config = config
        self._client = HttpClient(config.host, config.port, config.timeout)

    @property
    def id(self) -> str:
        """Get session ID."""
        return self._id

    @property
    def client(self) -> HttpClient:
        """Get HTTP client."""
        return self._client

    async def find(self, selector: Selector) -> ZylixElement:
        """Find an element by selector.

        Args:
            selector: Element selector

        Returns:
            Found element

        Raises:
            ElementNotFoundError: If element not found
        """
        wd_selector = to_webdriver_selector(selector)
        try:
            response = await self._client.post(
                f"/session/{self._id}/element",
                wd_selector,
            )
            value: dict[str, Any] = response.get("value", {})
            element_id = value.get("ELEMENT") or value.get("element-6066-11e4-a52e-4f735466cecf")

            if not element_id:
                raise ElementNotFoundError(selector.value)

            return ZylixElement(str(element_id), self._id, self._client)
        except Exception as e:
            if "no such element" in str(e).lower():
                raise ElementNotFoundError(selector.value) from e
            raise

    async def find_all(self, selector: Selector) -> list[ZylixElement]:
        """Find all elements matching selector.

        Args:
            selector: Element selector

        Returns:
            List of found elements
        """
        wd_selector = to_webdriver_selector(selector)
        response = await self._client.post(
            f"/session/{self._id}/elements",
            wd_selector,
        )
        elements: list[dict[str, Any]] = response.get("value", [])

        result: list[ZylixElement] = []
        for elem in elements:
            element_id = elem.get("ELEMENT") or elem.get("element-6066-11e4-a52e-4f735466cecf")
            if element_id:
                result.append(ZylixElement(str(element_id), self._id, self._client))

        return result

    async def wait_for(
        self,
        selector: Selector,
        timeout_ms: int = 10000,
        poll_interval_ms: int = 500,
    ) -> ZylixElement:
        """Wait for an element to appear.

        Args:
            selector: Element selector
            timeout_ms: Maximum wait time in milliseconds
            poll_interval_ms: Polling interval in milliseconds

        Returns:
            Found element

        Raises:
            TimeoutError: If element not found within timeout
        """
        start_time = asyncio.get_event_loop().time()
        timeout_seconds = timeout_ms / 1000

        while True:
            try:
                return await self.find(selector)
            except ElementNotFoundError:
                elapsed = asyncio.get_event_loop().time() - start_time
                if elapsed >= timeout_seconds:
                    raise ZylixTimeoutError(f"wait_for({selector.value})", timeout_ms)
                await asyncio.sleep(poll_interval_ms / 1000)

    async def take_screenshot(self) -> bytes:
        """Take a screenshot of the current screen.

        Returns:
            Screenshot as PNG bytes
        """
        response = await self._client.get(f"/session/{self._id}/screenshot")
        screenshot_base64 = response.get("value", "")
        return base64.b64decode(screenshot_base64)

    async def get_source(self) -> str:
        """Get the page/screen source.

        Returns:
            Page source as string
        """
        response = await self._client.get(f"/session/{self._id}/source")
        return str(response.get("value", ""))


class BaseDriver(ABC, Generic[ConfigT, SessionT]):
    """Base driver implementation."""

    def __init__(self, config: ConfigT) -> None:
        """Initialize driver.

        Args:
            config: Driver configuration
        """
        self._config = config
        self._client = HttpClient(config.host, config.port, config.timeout)

    @property
    def config(self) -> ConfigT:
        """Get driver configuration."""
        return self._config

    @property
    def client(self) -> HttpClient:
        """Get HTTP client."""
        return self._client

    @abstractmethod
    async def create_session(self, **kwargs: Any) -> SessionT:
        """Create a new driver session.

        Args:
            **kwargs: Additional session options

        Returns:
            New session instance
        """
        ...

    async def delete_session(self, session_id: str) -> None:
        """Delete/close a session.

        Args:
            session_id: Session ID to delete
        """
        await self._client.delete(f"/session/{session_id}")

    async def is_available(self) -> bool:
        """Check if driver is available.

        Returns:
            True if driver is responding
        """
        return await self._client.is_available()
