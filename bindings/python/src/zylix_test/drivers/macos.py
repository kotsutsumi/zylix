"""
Zylix Test Framework - macOS Driver
"""

from typing import Any

from ..types import KeyModifier, MacOSDriverConfig, WindowInfo
from .base import BaseDriver, BaseSession


class MacOSDriverSession(BaseSession[MacOSDriverConfig]):
    """macOS driver session with macOS-specific functionality."""

    def __init__(self, session_id: str, config: MacOSDriverConfig) -> None:
        """Initialize macOS session."""
        super().__init__(session_id, config)

    async def get_windows(self) -> list[WindowInfo]:
        """Get all windows for the application.

        Returns:
            List of window information
        """
        response = await self._client.get(f"/session/{self._id}/windows")
        windows: list[dict[str, Any]] = response.get("value", [])

        return [
            WindowInfo(
                id=str(w.get("id", "")),
                title=w.get("title"),
                x=float(w.get("x", 0)),
                y=float(w.get("y", 0)),
                width=float(w.get("width", 0)),
                height=float(w.get("height", 0)),
            )
            for w in windows
        ]

    async def activate_window(self, window_id: str) -> None:
        """Activate/focus a window.

        Args:
            window_id: Window ID to activate
        """
        await self._client.post(
            f"/session/{self._id}/window/{window_id}/activate",
            {},
        )

    async def press_key(
        self,
        key: str,
        modifiers: list[KeyModifier] | None = None,
    ) -> None:
        """Press a keyboard key with optional modifiers.

        Args:
            key: Key to press
            modifiers: Modifier keys (command, control, option, shift, fn)
        """
        await self._client.post(
            f"/session/{self._id}/keys",
            {
                "key": key,
                "modifiers": modifiers or [],
            },
        )

    async def type_text(self, text: str) -> None:
        """Type text into the focused element.

        Args:
            text: Text to type
        """
        await self._client.post(
            f"/session/{self._id}/type",
            {"text": text},
        )


class MacOSDriver(BaseDriver[MacOSDriverConfig, MacOSDriverSession]):
    """macOS driver for macOS app automation."""

    def __init__(
        self,
        host: str = "127.0.0.1",
        port: int = 8200,
        timeout: int = 30000,
        bundle_id: str | None = None,
    ) -> None:
        """Initialize macOS driver.

        Args:
            host: Driver host address
            port: Driver port (default: 8200 for Accessibility Bridge)
            timeout: Request timeout in milliseconds
            bundle_id: App bundle identifier
        """
        config = MacOSDriverConfig(
            host=host,
            port=port,
            timeout=timeout,
            bundle_id=bundle_id,
        )
        super().__init__(config)

    async def create_session(self, **kwargs: Any) -> MacOSDriverSession:
        """Create a new macOS session.

        Args:
            **kwargs: Additional session options

        Returns:
            New macOS session
        """
        bundle_id = kwargs.get("bundle_id", self._config.bundle_id)

        capabilities: dict[str, Any] = {
            "capabilities": {
                "bundleId": bundle_id,
                "platformName": "macOS",
            }
        }

        response = await self._client.post("/session", capabilities)
        value: dict[str, Any] = response.get("value", {})
        session_id = str(value.get("sessionId", ""))

        return MacOSDriverSession(session_id, self._config)
