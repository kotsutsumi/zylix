"""
Zylix Test Framework - watchOS Driver
"""

from typing import Any

from ..types import CompanionDeviceInfo, CrownDirection, WatchOSDriverConfig
from .base import BaseDriver
from .ios import IOSDriverSession


class WatchOSDriverSession(IOSDriverSession):
    """watchOS driver session with watchOS-specific functionality."""

    def __init__(self, session_id: str, config: WatchOSDriverConfig) -> None:
        """Initialize watchOS session."""
        # Create a compatible IOSDriverConfig for parent
        super().__init__(session_id, config)  # type: ignore[arg-type]
        self._watchos_config = config

    async def rotate_digital_crown(
        self,
        direction: CrownDirection,
        rotation_amount: float = 1.0,
    ) -> None:
        """Rotate the Digital Crown.

        Args:
            direction: Direction to rotate ('up' or 'down')
            rotation_amount: Amount to rotate (0.0 to 1.0)
        """
        velocity = rotation_amount if direction == "up" else -rotation_amount
        await self._client.post(
            f"/session/{self._id}/wda/digitalCrown",
            {"velocity": velocity},
        )

    async def press_side_button(self) -> None:
        """Press the Side Button."""
        await self._client.post(
            f"/session/{self._id}/wda/sideButton",
            {"action": "press"},
        )

    async def double_press_side_button(self) -> None:
        """Double-press the Side Button (for Apple Pay, etc.)."""
        await self._client.post(
            f"/session/{self._id}/wda/sideButton",
            {"action": "doublePress"},
        )

    async def get_companion_device_info(self) -> CompanionDeviceInfo | None:
        """Get paired iPhone information.

        Returns:
            Companion device info or None if not paired
        """
        try:
            response = await self._client.get(f"/session/{self._id}/wda/companionDevice")
            value: dict[str, Any] = response.get("value", {})

            if not value:
                return None

            return CompanionDeviceInfo(
                device_name=value.get("deviceName"),
                device_udid=value.get("deviceUdid"),
                is_paired=value.get("isPaired", False),
            )
        except Exception:
            return None


class WatchOSDriver(BaseDriver[WatchOSDriverConfig, WatchOSDriverSession]):
    """watchOS driver for watchOS app automation."""

    def __init__(
        self,
        host: str = "127.0.0.1",
        port: int = 8100,
        timeout: int = 30000,
        bundle_id: str | None = None,
        simulator_type: str | None = None,
        watchos_version: str | None = None,
        companion_device_udid: str | None = None,
    ) -> None:
        """Initialize watchOS driver.

        Args:
            host: Driver host address
            port: Driver port (default: 8100 for WebDriverAgent)
            timeout: Request timeout in milliseconds
            bundle_id: watchOS app bundle identifier
            simulator_type: Simulator type (e.g., 'Apple Watch Series 9 (45mm)')
            watchos_version: watchOS version
            companion_device_udid: Paired iPhone UDID
        """
        config = WatchOSDriverConfig(
            host=host,
            port=port,
            timeout=timeout,
            bundle_id=bundle_id,
            simulator_type=simulator_type,
            watchos_version=watchos_version,
            companion_device_udid=companion_device_udid,
        )
        super().__init__(config)

    async def create_session(self, **kwargs: Any) -> WatchOSDriverSession:
        """Create a new watchOS session.

        Args:
            **kwargs: Additional session options

        Returns:
            New watchOS session
        """
        bundle_id = kwargs.get("bundle_id", self._config.bundle_id)
        simulator_type = kwargs.get("simulator_type", self._config.simulator_type)
        watchos_version = kwargs.get("watchos_version", self._config.watchos_version)
        companion_device_udid = kwargs.get(
            "companion_device_udid",
            self._config.companion_device_udid,
        )

        capabilities: dict[str, Any] = {
            "capabilities": {
                "alwaysMatch": {
                    "platformName": "watchOS",
                }
            }
        }

        always_match = capabilities["capabilities"]["alwaysMatch"]

        if bundle_id:
            always_match["bundleId"] = bundle_id

        if simulator_type:
            always_match["deviceName"] = simulator_type

        if watchos_version:
            always_match["platformVersion"] = watchos_version

        if companion_device_udid:
            always_match["companionDeviceUdid"] = companion_device_udid

        response = await self._client.post("/session", capabilities)
        value: dict[str, Any] = response.get("value", {})
        session_id = str(value.get("sessionId", ""))

        return WatchOSDriverSession(session_id, self._config)
