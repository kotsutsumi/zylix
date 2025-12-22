"""
Zylix Test Framework - iOS Driver
"""

from typing import Any

from ..types import IOSDriverConfig
from .base import BaseDriver, BaseSession


class IOSDriverSession(BaseSession[IOSDriverConfig]):
    """iOS driver session with iOS-specific functionality."""

    def __init__(self, session_id: str, config: IOSDriverConfig) -> None:
        """Initialize iOS session."""
        super().__init__(session_id, config)

    async def tap_at(self, x: float, y: float) -> None:
        """Tap at specific coordinates.

        Args:
            x: X coordinate
            y: Y coordinate
        """
        await self._client.post(
            f"/session/{self._id}/actions",
            {
                "actions": [
                    {
                        "type": "pointer",
                        "id": "finger1",
                        "parameters": {"pointerType": "touch"},
                        "actions": [
                            {"type": "pointerMove", "x": x, "y": y},
                            {"type": "pointerDown", "button": 0},
                            {"type": "pointerUp", "button": 0},
                        ],
                    }
                ]
            },
        )

    async def swipe(
        self,
        start_x: float,
        start_y: float,
        end_x: float,
        end_y: float,
        duration_ms: int = 500,
    ) -> None:
        """Perform a swipe gesture.

        Args:
            start_x: Starting X coordinate
            start_y: Starting Y coordinate
            end_x: Ending X coordinate
            end_y: Ending Y coordinate
            duration_ms: Swipe duration in milliseconds
        """
        await self._client.post(
            f"/session/{self._id}/actions",
            {
                "actions": [
                    {
                        "type": "pointer",
                        "id": "finger1",
                        "parameters": {"pointerType": "touch"},
                        "actions": [
                            {"type": "pointerMove", "x": start_x, "y": start_y},
                            {"type": "pointerDown", "button": 0},
                            {
                                "type": "pointerMove",
                                "x": end_x,
                                "y": end_y,
                                "duration": duration_ms,
                            },
                            {"type": "pointerUp", "button": 0},
                        ],
                    }
                ]
            },
        )

    async def shake(self) -> None:
        """Shake the device."""
        await self._client.post(f"/session/{self._id}/wda/shake", {})

    async def lock(self, duration_seconds: int = 0) -> None:
        """Lock the device.

        Args:
            duration_seconds: Lock duration (0 for permanent lock)
        """
        await self._client.post(
            f"/session/{self._id}/wda/lock",
            {"seconds": duration_seconds},
        )

    async def unlock(self) -> None:
        """Unlock the device."""
        await self._client.post(f"/session/{self._id}/wda/unlock", {})


class IOSDriver(BaseDriver[IOSDriverConfig, IOSDriverSession]):
    """iOS driver for iOS app automation."""

    def __init__(
        self,
        host: str = "127.0.0.1",
        port: int = 8100,
        timeout: int = 30000,
        bundle_id: str | None = None,
        device_udid: str | None = None,
        use_simulator: bool = True,
        simulator_type: str | None = None,
        platform_version: str | None = None,
    ) -> None:
        """Initialize iOS driver.

        Args:
            host: Driver host address
            port: Driver port (default: 8100 for WebDriverAgent)
            timeout: Request timeout in milliseconds
            bundle_id: App bundle identifier
            device_udid: Device UDID
            use_simulator: Use simulator instead of device
            simulator_type: Simulator type (e.g., 'iPhone 15 Pro')
            platform_version: iOS version
        """
        config = IOSDriverConfig(
            host=host,
            port=port,
            timeout=timeout,
            bundle_id=bundle_id,
            device_udid=device_udid,
            use_simulator=use_simulator,
            simulator_type=simulator_type,
            platform_version=platform_version,
        )
        super().__init__(config)

    async def create_session(self, **kwargs: Any) -> IOSDriverSession:
        """Create a new iOS session.

        Args:
            **kwargs: Additional session options

        Returns:
            New iOS session
        """
        bundle_id = kwargs.get("bundle_id", self._config.bundle_id)
        device_udid = kwargs.get("device_udid", self._config.device_udid)
        use_simulator = kwargs.get("use_simulator", self._config.use_simulator)
        simulator_type = kwargs.get("simulator_type", self._config.simulator_type)
        platform_version = kwargs.get("platform_version", self._config.platform_version)

        capabilities: dict[str, Any] = {
            "capabilities": {
                "alwaysMatch": {
                    "platformName": "iOS",
                }
            }
        }

        always_match = capabilities["capabilities"]["alwaysMatch"]

        if bundle_id:
            always_match["bundleId"] = bundle_id

        if device_udid:
            always_match["udid"] = device_udid

        if use_simulator and simulator_type:
            always_match["deviceName"] = simulator_type

        if platform_version:
            always_match["platformVersion"] = platform_version

        response = await self._client.post("/session", capabilities)
        value: dict[str, Any] = response.get("value", {})
        session_id = str(value.get("sessionId", ""))

        return IOSDriverSession(session_id, self._config)
