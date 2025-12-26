"""FastAPI main application entry point."""

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import compare, lists, prices, websocket
from app.config import get_settings
from app.services.price_crawler import PriceCrawler, PriceStorageService
from app.services.price_scheduler import init_scheduler, shutdown_scheduler

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager - handles startup and shutdown."""
    # Startup
    print("Starting price crawler scheduler...")
    crawler = PriceCrawler()
    storage = PriceStorageService()
    await init_scheduler(crawler, storage)
    print("Price crawler scheduler started!")
    
    yield
    
    # Shutdown
    print("Shutting down price crawler scheduler...")
    await shutdown_scheduler()
    await crawler.close()
    print("Price crawler scheduler stopped!")


app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description="A grocery price comparison API that helps users find the best prices across local stores.",
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
    lifespan=lifespan,
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
async def root() -> dict[str, str]:
    """Root endpoint returning API information."""
    return {
        "name": settings.app_name,
        "version": settings.app_version,
        "docs": "/docs",
        "prices_api": "/api/v1/prices/search?q=milk",
        "websocket": "/ws/prices/{user_id}",
    }


@app.get("/health")
async def health_check() -> dict[str, str]:
    """Health check endpoint."""
    return {"status": "healthy"}


# Include routers
app.include_router(lists.router, prefix=settings.api_prefix, tags=["Grocery Lists"])
app.include_router(compare.router, prefix=settings.api_prefix, tags=["Price Comparison"])
app.include_router(prices.router, prefix=settings.api_prefix, tags=["Price Data"])
app.include_router(websocket.router, tags=["WebSocket"])
