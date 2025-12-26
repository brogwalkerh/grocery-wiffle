"""Kroger API client service."""

from time import time
from typing import Any, Optional

import httpx

from app.config import get_settings


class KrogerClient:
    """Service for interacting with the Kroger API using OAuth2 client credentials.

    Falls back to mock data when credentials are missing.
    """

    def __init__(self) -> None:
        """Initialize the Kroger client."""
        settings = get_settings()
        self.client_id = settings.kroger_client_id
        self.client_secret = settings.kroger_client_secret
        self.base_url = settings.kroger_base_url.rstrip("/")
        self.scopes = settings.kroger_scopes
        self.redirect_uri = getattr(settings, "kroger_redirect_uri", None)
        self._access_token: Optional[str] = None
        self._token_expires_at: Optional[float] = None
        self._http = httpx.AsyncClient(base_url=self.base_url, timeout=15.0)

    def _is_configured(self) -> bool:
        """Check if the client is properly configured with credentials."""
        return bool(self.client_id and self.client_secret)

    async def _ensure_access_token(self) -> None:
        """Ensure we have a valid access token using client credentials."""
        if not self._is_configured():
            raise ValueError("Kroger API credentials not configured")

        # Reuse token if still valid (60s buffer)
        if self._access_token and self._token_expires_at:
            if time() < self._token_expires_at - 60:
                return

        token_url = f"{self.base_url}/connect/oauth2/token"
        data = {
            "grant_type": "client_credentials",
            "scope": self.scopes,
        }

        auth = (self.client_id or "", self.client_secret or "")

        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.post(token_url, data=data, auth=auth)
            resp.raise_for_status()
            payload = resp.json()

        self._access_token = payload.get("access_token")
        expires_in = payload.get("expires_in", 1800)  # default 30m
        self._token_expires_at = time() + float(expires_in)

        if not self._access_token:
            raise ValueError("Failed to obtain Kroger access token")

    def _auth_headers(self) -> dict[str, str]:
        return {"Authorization": f"Bearer {self._access_token}"} if self._access_token else {}

    async def search_products(
        self,
        query: str,
        location_id: Optional[str] = None,
        limit: int = 10,
    ) -> list[dict[str, Any]]:
        """Search for products in the Kroger catalog.

        Args:
            query: Search query string
            location_id: Optional store location ID
            limit: Maximum number of results

        Returns:
            List of matching products

        Note:
            This is a stub that returns mock data.
            Implement actual API call when credentials are available.
        """
        if not self._is_configured():
            # Return mock data for development
            return self._get_mock_search_results(query)

        await self._ensure_access_token()

        params = {
            "filter.term": query,
            "filter.limit": limit,
        }
        if location_id:
            params["filter.locationId"] = location_id

        resp = await self._http.get(
            "/products",
            params=params,
            headers=self._auth_headers(),
        )
        resp.raise_for_status()
        data = resp.json()
        return data.get("data", [])

    async def get_product_by_id(self, product_id: str) -> Optional[dict[str, Any]]:
        """Get product details by Kroger product ID.

        Args:
            product_id: Kroger product ID

        Returns:
            Product details or None if not found
        """
        if not self._is_configured():
            return None

        # TODO: Implement actual API call
        # GET /products/{productId}
        return None

    async def get_product_by_upc(self, upc: str) -> Optional[dict[str, Any]]:
        """Get product details by UPC code.

        Args:
            upc: Universal Product Code

        Returns:
            Product details or None if not found
        """
        if not self._is_configured():
            return None

        await self._ensure_access_token()
        resp = await self._http.get(
            "/products",
            params={"filter.upc": upc, "filter.limit": 1},
            headers=self._auth_headers(),
        )
        resp.raise_for_status()
        data = resp.json().get("data", [])
        return data[0] if data else None

    async def get_locations(
        self,
        zip_code: str,
        radius_miles: int = 10,
        limit: int = 10,
    ) -> list[dict[str, Any]]:
        """Get Kroger store locations near a ZIP code.

        Args:
            zip_code: ZIP code to search near
            radius_miles: Search radius in miles
            limit: Maximum number of results

        Returns:
            List of store locations
        """
        if not self._is_configured():
            # Return mock data for development
            return self._get_mock_locations(zip_code)

        await self._ensure_access_token()
        params = {
            "filter.zipCode.near": zip_code,
            "filter.radiusInMiles": radius_miles,
            "filter.limit": limit,
        }
        resp = await self._http.get(
            "/locations",
            params=params,
            headers=self._auth_headers(),
        )
        resp.raise_for_status()
        data = resp.json()
        return data.get("data", [])

    async def get_product_prices(
        self,
        location_id: str,
        product_ids: list[str],
    ) -> list[dict[str, Any]]:
        """Get prices for products at a specific location.

        Args:
            location_id: Kroger store location ID
            product_ids: List of product IDs to get prices for

        Returns:
            List of product prices
        """
        if not self._is_configured():
            return []

        await self._ensure_access_token()
        # Kroger returns pricing when locationId provided on /products
        params = {
            "filter.locationId": location_id,
            "filter.productId": ",".join(product_ids),
        }
        resp = await self._http.get(
            "/products",
            params=params,
            headers=self._auth_headers(),
        )
        resp.raise_for_status()
        return resp.json().get("data", [])

    async def close(self) -> None:
        """Close underlying HTTP client."""
        await self._http.aclose()

    def _get_mock_search_results(self, query: str) -> list[dict[str, Any]]:
        """Return mock search results for development.

        Args:
            query: Search query

        Returns:
            Mock product list
        """
        mock_products = [
            {
                "productId": "0001111060903",
                "upc": "0001111060903",
                "aisleLocations": [{"description": "Dairy"}],
                "brand": "Kroger",
                "categories": ["Dairy"],
                "description": "Kroger 2% Reduced Fat Milk",
                "items": [
                    {
                        "itemId": "0001111060903",
                        "price": {
                            "regular": 3.49,
                            "promo": 2.99,
                        },
                        "size": "1 gal",
                    }
                ],
            },
            {
                "productId": "0001111041700",
                "upc": "0001111041700",
                "aisleLocations": [{"description": "Dairy"}],
                "brand": "Kroger",
                "categories": ["Dairy"],
                "description": "Kroger Whole Milk",
                "items": [
                    {
                        "itemId": "0001111041700",
                        "price": {
                            "regular": 3.99,
                            "promo": None,
                        },
                        "size": "1 gal",
                    }
                ],
            },
        ]

        # Simple filtering based on query
        query_lower = query.lower()
        return [p for p in mock_products if query_lower in p["description"].lower()]

    def _get_mock_locations(self, zip_code: str) -> list[dict[str, Any]]:
        """Return mock store locations for development.

        Args:
            zip_code: ZIP code

        Returns:
            Mock location list
        """
        return [
            {
                "locationId": "01400943",
                "chain": "KROGER",
                "name": "Kroger",
                "address": {
                    "addressLine1": "100 Main Street",
                    "city": "San Diego",
                    "state": "CA",
                    "zipCode": zip_code,
                },
                "geolocation": {
                    "latitude": 32.7157,
                    "longitude": -117.1611,
                },
                "hours": {
                    "open24": False,
                    "monday": {"open": "06:00", "close": "22:00"},
                    "tuesday": {"open": "06:00", "close": "22:00"},
                    "wednesday": {"open": "06:00", "close": "22:00"},
                    "thursday": {"open": "06:00", "close": "22:00"},
                    "friday": {"open": "06:00", "close": "22:00"},
                    "saturday": {"open": "06:00", "close": "22:00"},
                    "sunday": {"open": "06:00", "close": "22:00"},
                },
            },
            {
                "locationId": "01400281",
                "chain": "RALPHS",
                "name": "Ralphs",
                "address": {
                    "addressLine1": "200 Broadway",
                    "city": "San Diego",
                    "state": "CA",
                    "zipCode": zip_code,
                },
                "geolocation": {
                    "latitude": 32.7190,
                    "longitude": -117.1625,
                },
                "hours": {
                    "open24": False,
                    "monday": {"open": "06:00", "close": "23:00"},
                    "tuesday": {"open": "06:00", "close": "23:00"},
                    "wednesday": {"open": "06:00", "close": "23:00"},
                    "thursday": {"open": "06:00", "close": "23:00"},
                    "friday": {"open": "06:00", "close": "23:00"},
                    "saturday": {"open": "06:00", "close": "23:00"},
                    "sunday": {"open": "06:00", "close": "23:00"},
                },
            },
        ]
