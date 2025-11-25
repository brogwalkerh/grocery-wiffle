"""Redis caching service."""

import json
from datetime import timedelta
from typing import Any, Optional, Union

import redis

from app.config import get_settings


class CacheManager:
    """Service for managing Redis cache operations."""

    # Cache key prefixes
    PREFIX_PRICE = "price"
    PREFIX_PRODUCT = "product"
    PREFIX_STORE = "store"
    PREFIX_COMPARISON = "comparison"

    def __init__(self) -> None:
        """Initialize the cache manager."""
        settings = get_settings()
        self.redis_url = settings.redis_url
        self.default_ttl = settings.cache_ttl_seconds
        self._client: Optional[redis.Redis[str]] = None

    @property
    def client(self) -> redis.Redis[str]:
        """Get or create Redis client.

        Returns:
            Redis client instance
        """
        if self._client is None:
            self._client = redis.from_url(
                self.redis_url,
                decode_responses=True,
            )
        return self._client

    def _make_key(self, prefix: str, *args: Union[str, int]) -> str:
        """Create a cache key with prefix and components.

        Args:
            prefix: Key prefix
            *args: Key components

        Returns:
            Formatted cache key
        """
        parts = [prefix] + [str(arg) for arg in args]
        return ":".join(parts)

    def get(self, key: str) -> Optional[Any]:
        """Get a value from cache.

        Args:
            key: Cache key

        Returns:
            Cached value or None if not found
        """
        try:
            value = self.client.get(key)
            if value:
                return json.loads(value)
            return None
        except redis.RedisError:
            return None
        except json.JSONDecodeError:
            return None

    def set(
        self,
        key: str,
        value: Any,
        ttl: Optional[int] = None,
    ) -> bool:
        """Set a value in cache.

        Args:
            key: Cache key
            value: Value to cache
            ttl: Time-to-live in seconds (uses default if not specified)

        Returns:
            True if successful, False otherwise
        """
        try:
            ttl = ttl or self.default_ttl
            serialized = json.dumps(value)
            self.client.setex(key, ttl, serialized)
            return True
        except (redis.RedisError, TypeError):
            return False

    def delete(self, key: str) -> bool:
        """Delete a value from cache.

        Args:
            key: Cache key

        Returns:
            True if deleted, False otherwise
        """
        try:
            return bool(self.client.delete(key))
        except redis.RedisError:
            return False

    def delete_pattern(self, pattern: str) -> int:
        """Delete all keys matching a pattern.

        Args:
            pattern: Key pattern (e.g., "price:*")

        Returns:
            Number of keys deleted
        """
        try:
            keys = list(self.client.scan_iter(match=pattern))
            if keys:
                return self.client.delete(*keys)
            return 0
        except redis.RedisError:
            return 0

    def exists(self, key: str) -> bool:
        """Check if a key exists in cache.

        Args:
            key: Cache key

        Returns:
            True if key exists, False otherwise
        """
        try:
            return bool(self.client.exists(key))
        except redis.RedisError:
            return False

    def get_ttl(self, key: str) -> int:
        """Get remaining TTL for a key.

        Args:
            key: Cache key

        Returns:
            TTL in seconds, -1 if no TTL, -2 if key doesn't exist
        """
        try:
            return self.client.ttl(key)
        except redis.RedisError:
            return -2

    # High-level caching methods

    def get_price(
        self, product_id: int, store_id: int
    ) -> Optional[dict[str, Any]]:
        """Get cached price data.

        Args:
            product_id: Product ID
            store_id: Store ID

        Returns:
            Cached price data or None
        """
        key = self._make_key(self.PREFIX_PRICE, product_id, store_id)
        return self.get(key)

    def set_price(
        self,
        product_id: int,
        store_id: int,
        price_data: dict[str, Any],
        ttl: Optional[int] = None,
    ) -> bool:
        """Cache price data.

        Args:
            product_id: Product ID
            store_id: Store ID
            price_data: Price information to cache
            ttl: Optional TTL override

        Returns:
            True if successful
        """
        key = self._make_key(self.PREFIX_PRICE, product_id, store_id)
        return self.set(key, price_data, ttl)

    def invalidate_store_prices(self, store_id: int) -> int:
        """Invalidate all cached prices for a store.

        Args:
            store_id: Store ID

        Returns:
            Number of keys deleted
        """
        pattern = f"{self.PREFIX_PRICE}:*:{store_id}"
        return self.delete_pattern(pattern)

    def invalidate_product_prices(self, product_id: int) -> int:
        """Invalidate all cached prices for a product.

        Args:
            product_id: Product ID

        Returns:
            Number of keys deleted
        """
        pattern = f"{self.PREFIX_PRICE}:{product_id}:*"
        return self.delete_pattern(pattern)

    def get_comparison(
        self, list_id: int, zip_code: str
    ) -> Optional[dict[str, Any]]:
        """Get cached comparison results.

        Args:
            list_id: Grocery list ID
            zip_code: ZIP code

        Returns:
            Cached comparison results or None
        """
        key = self._make_key(self.PREFIX_COMPARISON, list_id, zip_code)
        return self.get(key)

    def set_comparison(
        self,
        list_id: int,
        zip_code: str,
        comparison_data: dict[str, Any],
        ttl: Optional[int] = None,
    ) -> bool:
        """Cache comparison results.

        Args:
            list_id: Grocery list ID
            zip_code: ZIP code
            comparison_data: Comparison results to cache
            ttl: Optional TTL override

        Returns:
            True if successful
        """
        key = self._make_key(self.PREFIX_COMPARISON, list_id, zip_code)
        # Comparisons should have shorter TTL as list might change
        ttl = ttl or (self.default_ttl // 2)
        return self.set(key, comparison_data, ttl)

    def invalidate_list_comparisons(self, list_id: int) -> int:
        """Invalidate all cached comparisons for a grocery list.

        Args:
            list_id: Grocery list ID

        Returns:
            Number of keys deleted
        """
        pattern = f"{self.PREFIX_COMPARISON}:{list_id}:*"
        return self.delete_pattern(pattern)

    def health_check(self) -> bool:
        """Check if Redis connection is healthy.

        Returns:
            True if Redis is reachable, False otherwise
        """
        try:
            return self.client.ping()
        except redis.RedisError:
            return False
