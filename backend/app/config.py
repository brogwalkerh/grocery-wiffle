"""Application configuration settings."""

from functools import lru_cache
from typing import Optional

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # Application
    app_name: str = "GroceryCompare API"
    app_version: str = "0.1.0"
    debug: bool = False

    # Database
    database_url: str = "postgresql://localhost/grocery_compare"

    # Redis
    redis_url: str = "redis://localhost:6379"
    cache_ttl_seconds: int = 3600  # 1 hour default cache TTL

    # Kroger API (to be configured later)
    kroger_client_id: Optional[str] = None
    kroger_client_secret: Optional[str] = None
    kroger_base_url: str = "https://api.kroger.com/v1"

    # API Settings
    api_prefix: str = "/api"


@lru_cache
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()
