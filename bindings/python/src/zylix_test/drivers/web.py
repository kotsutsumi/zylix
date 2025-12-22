"""
Zylix Test Framework - Web Driver
"""

from typing import Any

from ..client import HttpClient
from ..types import WebDriverConfig
from .base import BaseDriver, BaseSession


class WebDriverSession(BaseSession[WebDriverConfig]):
    """Web driver session with browser-specific functionality."""

    def __init__(self, session_id: str, config: WebDriverConfig) -> None:
        """Initialize web session."""
        super().__init__(session_id, config)

    async def navigate_to(self, url: str) -> None:
        """Navigate to a URL.

        Args:
            url: URL to navigate to
        """
        await self._client.post(f"/session/{self._id}/url", {"url": url})

    async def get_url(self) -> str:
        """Get current URL.

        Returns:
            Current page URL
        """
        response = await self._client.get(f"/session/{self._id}/url")
        return str(response.get("value", ""))

    async def get_title(self) -> str:
        """Get page title.

        Returns:
            Current page title
        """
        response = await self._client.get(f"/session/{self._id}/title")
        return str(response.get("value", ""))

    async def execute_script(self, script: str, *args: object) -> Any:
        """Execute JavaScript in the browser.

        Args:
            script: JavaScript code to execute
            *args: Arguments to pass to the script

        Returns:
            Script execution result
        """
        response = await self._client.post(
            f"/session/{self._id}/execute/sync",
            {"script": script, "args": list(args)},
        )
        return response.get("value")

    async def back(self) -> None:
        """Navigate back in browser history."""
        await self._client.post(f"/session/{self._id}/back", {})

    async def forward(self) -> None:
        """Navigate forward in browser history."""
        await self._client.post(f"/session/{self._id}/forward", {})

    async def refresh(self) -> None:
        """Refresh the current page."""
        await self._client.post(f"/session/{self._id}/refresh", {})


class WebDriver(BaseDriver[WebDriverConfig, WebDriverSession]):
    """Web driver for browser automation."""

    def __init__(
        self,
        host: str = "127.0.0.1",
        port: int = 9515,
        timeout: int = 30000,
        browser: str = "chrome",
        headless: bool = False,
        viewport_width: int | None = None,
        viewport_height: int | None = None,
    ) -> None:
        """Initialize web driver.

        Args:
            host: Driver host address
            port: Driver port (default: 9515 for ChromeDriver)
            timeout: Request timeout in milliseconds
            browser: Browser type (chrome, firefox, safari, edge)
            headless: Run browser in headless mode
            viewport_width: Viewport width
            viewport_height: Viewport height
        """
        config = WebDriverConfig(
            host=host,
            port=port,
            timeout=timeout,
            browser=browser,  # type: ignore[arg-type]
            headless=headless,
            viewport_width=viewport_width,
            viewport_height=viewport_height,
        )
        super().__init__(config)

    async def create_session(self, **kwargs: Any) -> WebDriverSession:
        """Create a new browser session.

        Args:
            **kwargs: Additional session options

        Returns:
            New web session
        """
        # Merge config with kwargs
        browser = kwargs.get("browser", self._config.browser)
        headless = kwargs.get("headless", self._config.headless)

        capabilities: dict[str, Any] = {
            "capabilities": {
                "alwaysMatch": {
                    "browserName": browser,
                }
            }
        }

        # Add browser-specific options
        if browser == "chrome":
            chrome_options: dict[str, Any] = {"args": []}
            if headless:
                chrome_options["args"].append("--headless")
            capabilities["capabilities"]["alwaysMatch"]["goog:chromeOptions"] = chrome_options
        elif browser == "firefox":
            firefox_options: dict[str, Any] = {"args": []}
            if headless:
                firefox_options["args"].append("-headless")
            capabilities["capabilities"]["alwaysMatch"]["moz:firefoxOptions"] = firefox_options

        response = await self._client.post("/session", capabilities)
        value: dict[str, Any] = response.get("value", {})
        session_id = str(value.get("sessionId", ""))

        return WebDriverSession(session_id, self._config)
