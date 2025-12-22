"""
Zylix Test Framework - Element Implementation
"""

from typing import TYPE_CHECKING, Any

from .types import ElementRect, SwipeDirection

if TYPE_CHECKING:
    from .client import HttpClient


class ZylixElement:
    """Element implementation for interacting with UI elements."""

    def __init__(self, element_id: str, session_id: str, client: "HttpClient") -> None:
        """Initialize element.

        Args:
            element_id: WebDriver element ID
            session_id: Session ID
            client: HTTP client for communication
        """
        self._element_id = element_id
        self._session_id = session_id
        self._client = client

    @property
    def id(self) -> str:
        """Get element ID."""
        return self._element_id

    async def tap(self) -> None:
        """Tap/click the element."""
        await self._client.post(
            f"/session/{self._session_id}/element/{self._element_id}/click",
            {},
        )

    async def double_tap(self) -> None:
        """Double tap the element."""
        # Get element center and perform double tap
        rect = await self.get_rect()
        center_x = rect.x + rect.width / 2
        center_y = rect.y + rect.height / 2

        await self._client.post(
            f"/session/{self._session_id}/actions",
            {
                "actions": [
                    {
                        "type": "pointer",
                        "id": "finger1",
                        "parameters": {"pointerType": "touch"},
                        "actions": [
                            {"type": "pointerMove", "x": center_x, "y": center_y},
                            {"type": "pointerDown", "button": 0},
                            {"type": "pointerUp", "button": 0},
                            {"type": "pause", "duration": 50},
                            {"type": "pointerDown", "button": 0},
                            {"type": "pointerUp", "button": 0},
                        ],
                    }
                ]
            },
        )

    async def long_press(self, duration_ms: int = 1000) -> None:
        """Long press the element.

        Args:
            duration_ms: Duration of the press in milliseconds
        """
        rect = await self.get_rect()
        center_x = rect.x + rect.width / 2
        center_y = rect.y + rect.height / 2

        await self._client.post(
            f"/session/{self._session_id}/actions",
            {
                "actions": [
                    {
                        "type": "pointer",
                        "id": "finger1",
                        "parameters": {"pointerType": "touch"},
                        "actions": [
                            {"type": "pointerMove", "x": center_x, "y": center_y},
                            {"type": "pointerDown", "button": 0},
                            {"type": "pause", "duration": duration_ms},
                            {"type": "pointerUp", "button": 0},
                        ],
                    }
                ]
            },
        )

    async def type(self, text: str) -> None:
        """Type text into the element.

        Args:
            text: Text to type
        """
        await self._client.post(
            f"/session/{self._session_id}/element/{self._element_id}/value",
            {"text": text},
        )

    async def clear(self) -> None:
        """Clear the element's text content."""
        await self._client.post(
            f"/session/{self._session_id}/element/{self._element_id}/clear",
            {},
        )

    async def swipe(self, direction: SwipeDirection) -> None:
        """Swipe in a direction from the element.

        Args:
            direction: Direction to swipe (up, down, left, right)
        """
        rect = await self.get_rect()
        center_x = rect.x + rect.width / 2
        center_y = rect.y + rect.height / 2
        swipe_distance = 200

        direction_offsets = {
            "up": (0, -swipe_distance),
            "down": (0, swipe_distance),
            "left": (-swipe_distance, 0),
            "right": (swipe_distance, 0),
        }

        offset_x, offset_y = direction_offsets[direction]

        await self._client.post(
            f"/session/{self._session_id}/actions",
            {
                "actions": [
                    {
                        "type": "pointer",
                        "id": "finger1",
                        "parameters": {"pointerType": "touch"},
                        "actions": [
                            {"type": "pointerMove", "x": center_x, "y": center_y},
                            {"type": "pointerDown", "button": 0},
                            {
                                "type": "pointerMove",
                                "x": center_x + offset_x,
                                "y": center_y + offset_y,
                                "duration": 300,
                            },
                            {"type": "pointerUp", "button": 0},
                        ],
                    }
                ]
            },
        )

    async def get_text(self) -> str:
        """Get the element's text content.

        Returns:
            Element text
        """
        response = await self._client.get(
            f"/session/{self._session_id}/element/{self._element_id}/text"
        )
        return str(response.get("value", ""))

    async def get_attribute(self, name: str) -> str | None:
        """Get an attribute value from the element.

        Args:
            name: Attribute name

        Returns:
            Attribute value or None if not found
        """
        response = await self._client.get(
            f"/session/{self._session_id}/element/{self._element_id}/attribute/{name}"
        )
        value = response.get("value")
        return str(value) if value is not None else None

    async def get_rect(self) -> ElementRect:
        """Get the element's position and size.

        Returns:
            ElementRect with x, y, width, height
        """
        response = await self._client.get(
            f"/session/{self._session_id}/element/{self._element_id}/rect"
        )
        value: dict[str, Any] = response.get("value", {})
        return ElementRect(
            x=float(value.get("x", 0)),
            y=float(value.get("y", 0)),
            width=float(value.get("width", 0)),
            height=float(value.get("height", 0)),
        )

    async def is_visible(self) -> bool:
        """Check if the element is visible.

        Returns:
            True if visible, False otherwise
        """
        response = await self._client.get(
            f"/session/{self._session_id}/element/{self._element_id}/displayed"
        )
        return bool(response.get("value", False))

    async def is_enabled(self) -> bool:
        """Check if the element is enabled.

        Returns:
            True if enabled, False otherwise
        """
        response = await self._client.get(
            f"/session/{self._session_id}/element/{self._element_id}/enabled"
        )
        return bool(response.get("value", False))
