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
    database_url: str = "sqlite:////Users/brog/grocery-wiffle/backend/grocery_compare.db"

    # Redis
    redis_url: str = "redis://localhost:6379"
    cache_ttl_seconds: int = 3600  # 1 hour default cache TTL

    # Kroger API (to be configured later)
    kroger_client_id: Optional[str] = None
    kroger_client_secret: Optional[str] = None
    kroger_base_url: str = "https://api.kroger.com/v1"
    kroger_redirect_uri: Optional[str] = None
    kroger_scopes: str = "product.compact profile.compact"
    # Default Kroger store location ID for price lookups
    # Can be overridden per-request or set via KROGER_DEFAULT_LOCATION_ID env
    kroger_default_location_id: Optional[str] = "01400513"  # Kroger Cincinnati downtown

    # Flipp API (weekly circulars - most reliable source)
    # Get your key at: https://flipp.com/business (for businesses)
    # Or use the public endpoints (limited access)
    flipp_api_key: Optional[str] = None
    flipp_publisher_id: Optional[str] = None
    
    # USDA FoodData Central API
    # Get free key at: https://fdc.nal.usda.gov/api-key-signup.html
    usda_api_key: str = "DEMO_KEY"  # Replace with real key for production
    
    # Instacart Developer API (if available)
    # https://www.instacart.com/developer
    instacart_api_key: Optional[str] = None
    
    # Google Maps API
    google_maps_api_key: Optional[str] = None
    
    # AI Vision Scraping Configuration
    # Ollama (local, free) - recommended
    ollama_url: str = "http://localhost:11434"
    ollama_vision_model: str = "llava"  # or bakllava, llama3.2-vision
    
    # Google AI (free tier) - Get key at: https://makersuite.google.com/app/apikey
    google_ai_api_key: Optional[str] = None
    
    # OpenAI (paid fallback)
    openai_api_key: Optional[str] = None
    
    # AI Scraper settings
    ai_scraper_enabled: bool = True
    ai_scraper_cache_hours: int = 4  # Cache scraped prices for 4 hours
    ai_scraper_max_stores_per_query: int = 5
    ai_scraper_timeout_seconds: int = 60

    # API Settings
    api_prefix: str = "/api"
    
    # Price data freshness settings
    price_cache_hours: int = 24  # How long to cache scraped prices
    circular_cache_hours: int = 168  # 7 days for weekly circulars

    # Price crawler
    crawler_enabled: bool = True
    crawler_interval_hours: int = 6
    crawler_rate_limit_rps: float = 0.5

    # CORS
    cors_origins: str = "http://localhost:3000,http://localhost:8080"


@lru_cache
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()
