"""
Zylix Test Framework - HTTP Client
"""

from typing import Any

import httpx

from .types import ConnectionError


class HttpClient:
    """HTTP client for WebDriver protocol communication."""

    def __init__(self, host: str, port: int, timeout: int = 30000) -> None:
        """Initialize HTTP client.

        Args:
            host: Driver host address
            port: Driver port number
            timeout: Request timeout in milliseconds
        """
        self.base_url = f"http://{host}:{port}"
        self.timeout = timeout / 1000  # Convert to seconds

    async def get(self, path: str) -> dict[str, Any]:
        """Send GET request.

        Args:
            path: Request path

        Returns:
            Response data

        Raises:
            ConnectionError: If connection fails
        """
        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.get(f"{self.base_url}{path}")
                response.raise_for_status()
                return response.json()
        except httpx.ConnectError as e:
            raise ConnectionError(f"Failed to connect to {self.base_url}: {e}") from e
        except httpx.HTTPStatusError as e:
            raise ConnectionError(f"HTTP error: {e.response.status_code}") from e

    async def post(self, path: str, data: dict[str, Any] | None = None) -> dict[str, Any]:
        """Send POST request.

        Args:
            path: Request path
            data: Request body data

        Returns:
            Response data

        Raises:
            ConnectionError: If connection fails
        """
        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.post(
                    f"{self.base_url}{path}",
                    json=data or {},
                )
                response.raise_for_status()
                return response.json()
        except httpx.ConnectError as e:
            raise ConnectionError(f"Failed to connect to {self.base_url}: {e}") from e
        except httpx.HTTPStatusError as e:
            raise ConnectionError(f"HTTP error: {e.response.status_code}") from e

    async def delete(self, path: str) -> dict[str, Any]:
        """Send DELETE request.

        Args:
            path: Request path

        Returns:
            Response data

        Raises:
            ConnectionError: If connection fails
        """
        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.delete(f"{self.base_url}{path}")
                response.raise_for_status()
                return response.json()
        except httpx.ConnectError as e:
            raise ConnectionError(f"Failed to connect to {self.base_url}: {e}") from e
        except httpx.HTTPStatusError as e:
            raise ConnectionError(f"HTTP error: {e.response.status_code}") from e

    async def is_available(self) -> bool:
        """Check if driver is available.

        Returns:
            True if driver is responding, False otherwise
        """
        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                response = await client.get(f"{self.base_url}/status")
                return response.status_code == 200
        except (httpx.ConnectError, httpx.TimeoutException):
            return False
