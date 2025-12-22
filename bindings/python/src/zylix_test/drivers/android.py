"""
Zylix Test Framework - Android Driver
"""

from typing import Any

from ..types import AndroidDriverConfig
from .base import BaseDriver, BaseSession


class AndroidDriverSession(BaseSession[AndroidDriverConfig]):
    """Android driver session with Android-specific functionality."""

    def __init__(self, session_id: str, config: AndroidDriverConfig) -> None:
        """Initialize Android session."""
        super().__init__(session_id, config)

    async def press_back(self) -> None:
        """Press the Back button."""
        await self._client.post(f"/session/{self._id}/back", {})

    async def press_home(self) -> None:
        """Press the Home button."""
        await self._client.post(
            f"/session/{self._id}/appium/device/press_keycode",
            {"keycode": 3},  # KEYCODE_HOME
        )

    async def press_recent_apps(self) -> None:
        """Press the Recent Apps button."""
        await self._client.post(
            f"/session/{self._id}/appium/device/press_keycode",
            {"keycode": 187},  # KEYCODE_APP_SWITCH
        )

    async def open_notifications(self) -> None:
        """Open the notification shade."""
        await self._client.post(
            f"/session/{self._id}/appium/device/open_notifications",
            {},
        )


class AndroidDriver(BaseDriver[AndroidDriverConfig, AndroidDriverSession]):
    """Android driver for Android app automation."""

    def __init__(
        self,
        host: str = "127.0.0.1",
        port: int = 4723,
        timeout: int = 30000,
        package_name: str | None = None,
        activity_name: str | None = None,
        device_id: str | None = None,
        platform_version: str = "14",
        automation_name: str = "UiAutomator2",
    ) -> None:
        """Initialize Android driver.

        Args:
            host: Driver host address
            port: Driver port (default: 4723 for Appium)
            timeout: Request timeout in milliseconds
            package_name: App package name
            activity_name: Main activity name
            device_id: Device/emulator ID
            platform_version: Android version
            automation_name: Automation engine name
        """
        config = AndroidDriverConfig(
            host=host,
            port=port,
            timeout=timeout,
            package_name=package_name,
            activity_name=activity_name,
            device_id=device_id,
            platform_version=platform_version,
            automation_name=automation_name,
        )
        super().__init__(config)

    async def create_session(self, **kwargs: Any) -> AndroidDriverSession:
        """Create a new Android session.

        Args:
            **kwargs: Additional session options

        Returns:
            New Android session
        """
        package_name = kwargs.get("package_name", self._config.package_name)
        activity_name = kwargs.get("activity_name", self._config.activity_name)
        device_id = kwargs.get("device_id", self._config.device_id)
        platform_version = kwargs.get("platform_version", self._config.platform_version)
        automation_name = kwargs.get("automation_name", self._config.automation_name)

        capabilities: dict[str, Any] = {
            "capabilities": {
                "alwaysMatch": {
                    "platformName": "Android",
                    "appium:automationName": automation_name,
                    "appium:platformVersion": platform_version,
                }
            }
        }

        always_match = capabilities["capabilities"]["alwaysMatch"]

        if package_name:
            always_match["appium:appPackage"] = package_name

        if activity_name:
            always_match["appium:appActivity"] = activity_name

        if device_id:
            always_match["appium:udid"] = device_id

        response = await self._client.post("/session", capabilities)
        value: dict[str, Any] = response.get("value", {})
        session_id = str(value.get("sessionId", ""))

        return AndroidDriverSession(session_id, self._config)
