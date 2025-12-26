"""API routes for price data."""

from datetime import datetime
from typing import Optional

from fastapi import APIRouter, HTTPException, Query, BackgroundTasks
from pydantic import BaseModel

from app.services.price_crawler import PriceCrawler, PriceStorageService, ScrapedPrice
from app.services.price_scheduler import get_scheduler
from app.services.circular_parser import CircularParser, ParsedCircularItem


router = APIRouter()


# ================================================================
# SCHEMAS
# ================================================================

class PriceResponse(BaseModel):
    """A single price result."""
    product_name: str
    price: float
    original_price: Optional[float] = None
    is_on_sale: bool = False
    size: Optional[str] = None
    store_chain: str
    store_name: str
    updated_at: Optional[str] = None
    is_estimate: bool = False


class CircularDealResponse(BaseModel):
    """A deal from a weekly circular."""
    product_name: str
    sale_price: float
    regular_price: Optional[float] = None
    unit: Optional[str] = None
    store_chain: str
    valid_from: Optional[str] = None
    valid_until: Optional[str] = None
    is_bogo: bool = False
    image_url: Optional[str] = None


class CircularSearchResponse(BaseModel):
    """Response for circular deal search."""
    query: str
    results: list[CircularDealResponse]
    count: int


class PriceSearchResponse(BaseModel):
    """Response for price search."""
    query: str
    results: list[PriceResponse]
    from_cache: bool
    crawled_at: Optional[str] = None


class CrawlRequest(BaseModel):
    """Request to crawl prices for a product."""
    query: str
    priority: int = 1


class CrawlResponse(BaseModel):
    """Response for crawl request."""
    message: str
    query: str
    queued: bool


class SchedulerStats(BaseModel):
    """Scheduler statistics."""
    total_crawls: int
    successful_crawls: int
    failed_crawls: int
    success_rate: float
    queue_length: int
    scheduled_jobs: int
    last_crawl: Optional[str]


class PriceCorrectionRequest(BaseModel):
    """Request to submit a price correction."""
    item_name: str
    store_name: str
    store_chain: str
    store_id: Optional[int] = None
    old_price: float
    new_price: float
    product_size: Optional[str] = None


class PriceCorrectionResponse(BaseModel):
    """Response for a price correction."""
    item_name: str
    store_name: str
    store_chain: str
    old_price: float
    new_price: float
    product_size: Optional[str] = None
    submitted_at: str
    is_verified: bool
    upvotes: int
    downvotes: int
    message: str


class PriceVoteRequest(BaseModel):
    """Request to vote on a price correction."""
    item_name: str
    store_name: str
    is_upvote: bool


class CrowdsourceStatsResponse(BaseModel):
    """Statistics about crowdsourced prices."""
    total_corrections: int
    verified_corrections: int
    corrections_last_24h: int
    top_contributors: int


# ================================================================
# ENDPOINTS
# ================================================================

@router.get("/prices/search", response_model=PriceSearchResponse)
async def search_prices(
    q: str = Query(..., min_length=1, description="Product to search for"),
    zip_code: str = Query(None, description="ZIP code for location-based pricing (e.g., Kroger/Ralphs)"),
    max_age_hours: int = Query(24, ge=1, le=168, description="Maximum age of cached prices in hours"),
    force_crawl: bool = Query(False, description="Force a fresh crawl instead of using cache"),
    background_tasks: BackgroundTasks = None,
):
    """
    Search for prices across all stores.
    
    Returns cached prices if available, otherwise triggers a crawl.
    Pass zip_code to get location-specific pricing for Kroger family stores.
    Note: When zip_code is provided, always fetches fresh data for accurate local pricing.
    """
    storage = PriceStorageService()
    
    # When ZIP code is provided, always crawl fresh to get location-specific pricing
    # Cached prices may be from different locations
    should_crawl = force_crawl or (zip_code is not None)
    
    # Try to get cached prices first (only if no ZIP code specified)
    if not should_crawl:
        cached = await storage.get_prices_for_product(q, max_age_days=max_age_hours // 24 or 1)
        if cached:
            return PriceSearchResponse(
                query=q,
                results=[PriceResponse(**p) for p in cached],
                from_cache=True,
                crawled_at=cached[0].get('updated_at') if cached else None,
            )
    
    # Crawl fresh prices with optional ZIP code for location-based pricing
    crawler = PriceCrawler()
    try:
        prices = await crawler.crawl_all_stores(q, zip_code=zip_code)
        
        # Store in background
        if background_tasks and prices:
            background_tasks.add_task(storage.store_prices, prices)
        
        return PriceSearchResponse(
            query=q,
            results=[
                PriceResponse(
                    product_name=p.product_name,
                    price=p.price,
                    original_price=p.original_price,
                    is_on_sale=p.is_on_sale,
                    size=p.size,
                    store_chain=p.store_chain,
                    store_name=p.store_name,
                )
                for p in prices
            ],
            from_cache=False,
            crawled_at=datetime.now().isoformat(),
        )
    finally:
        await crawler.close()


@router.get("/prices/cached", response_model=PriceSearchResponse)
async def get_cached_prices(
    q: str = Query(..., min_length=1, description="Product to search for"),
    max_age_days: int = Query(7, ge=1, le=30, description="Maximum age of prices in days"),
):
    """
    Get cached prices only (no crawling).
    
    Use this for fast lookups when you don't need fresh data.
    """
    storage = PriceStorageService()
    cached = await storage.get_prices_for_product(q, max_age_days=max_age_days)
    
    return PriceSearchResponse(
        query=q,
        results=[PriceResponse(**p) for p in cached],
        from_cache=True,
        crawled_at=cached[0].get('updated_at') if cached else None,
    )


@router.post("/prices/crawl", response_model=CrawlResponse)
async def request_crawl(request: CrawlRequest):
    """
    Request a price crawl for a product.
    
    Adds the product to the crawl queue for background processing.
    """
    scheduler = get_scheduler()
    
    if not scheduler:
        raise HTTPException(
            status_code=503,
            detail="Price crawl scheduler is not running"
        )
    
    scheduler.schedule_user_product(request.query, priority=request.priority)
    
    return CrawlResponse(
        message=f"Crawl queued for '{request.query}'",
        query=request.query,
        queued=True,
    )


@router.get("/prices/scheduler/stats", response_model=SchedulerStats)
async def get_scheduler_stats():
    """Get price crawler scheduler statistics."""
    scheduler = get_scheduler()
    
    if not scheduler:
        raise HTTPException(
            status_code=503,
            detail="Price crawl scheduler is not running"
        )
    
    stats = scheduler.get_stats()
    return SchedulerStats(**stats)


@router.post("/prices/batch-search")
async def batch_search_prices(
    products: list[str] = Query(..., description="List of products to search"),
    background_tasks: BackgroundTasks = None,
):
    """
    Search for prices for multiple products at once.
    
    Useful for comparing entire grocery lists.
    """
    storage = PriceStorageService()
    results = {}
    
    for product in products[:20]:  # Limit to 20 products
        cached = await storage.get_prices_for_product(product, max_age_days=7)
        results[product] = [PriceResponse(**p) for p in cached]
        
        # Queue fresh crawl if no cached data
        if not cached:
            scheduler = get_scheduler()
            if scheduler:
                scheduler.add_to_queue(product)
    
    return {
        'products': results,
        'queued_for_crawl': [p for p in products if not results.get(p)],
    }


# ================================================================
# CIRCULAR/WEEKLY AD ENDPOINTS
# ================================================================

@router.get("/deals/search", response_model=CircularSearchResponse)
async def search_circular_deals(
    q: str = Query(..., min_length=1, description="Product to search for"),
    zip_code: str = Query("92117", description="ZIP code for local deals"),
    use_ai: bool = Query(False, description="Use AI vision scraper for real-time prices (slower)"),
):
    """
    Search for deals in weekly circulars and store websites.
    
    Data sources:
    1. Kroger API - Real-time prices from Kroger family stores (Ralphs, Food 4 Less, etc.)
    2. Flipp API - Weekly circular deals from major retailers
    3. Open Prices API - Crowdsourced real prices
    4. AI Vision Scraper (if use_ai=true) - Real-time prices from store websites
    5. Estimated everyday prices - Gap-filling for stores without deals
    
    Set use_ai=true for more accurate real-time prices (takes 30-60 seconds).
    """
    parser = CircularParser()
    crawler = PriceCrawler()
    
    try:
        # Get Flipp circular deals
        deals = await parser.search_deals(q, zip_code, use_ai_scraper=use_ai)
        
        # Also get Kroger API prices for accurate Kroger family store pricing
        # This ensures we get real prices (not just weekly circular prices) for Ralphs, Food 4 Less, etc.
        try:
            kroger_prices = await crawler.crawl_kroger(q, zip_code=zip_code)
            
            if kroger_prices:
                # Track Kroger chains we found real prices for
                kroger_chains_with_api_prices = set()
                for price in kroger_prices:
                    kroger_chains_with_api_prices.add(price.store_chain.lower())
                
                # Map common Kroger family chain name variants to normalize
                kroger_name_mapping = {
                    'ralphs': 'ralphs',
                    'ralphs fresh fare': 'ralphs',
                    'food 4 less': 'food 4 less',
                    'food4less': 'food 4 less',
                    'kroger': 'kroger',
                    'king soopers': 'king soopers',
                    'fred meyer': 'fred meyer',
                    "smith's": "smith's",
                    'smiths': "smith's",
                    'qfc': 'qfc',
                    'dillons': 'dillons',
                    'harris teeter': 'harris teeter',
                    "mariano's": "mariano's",
                    'marianos': "mariano's",
                }
                
                # Normalize chains we got from API
                normalized_api_chains = set()
                for chain in kroger_chains_with_api_prices:
                    normalized = kroger_name_mapping.get(chain.lower(), chain.lower())
                    normalized_api_chains.add(normalized)
                
                # Filter out Flipp results for Kroger chains BEFORE adding API results
                # (API prices are more accurate than circular estimates)
                def should_keep_flipp(deal):
                    chain_lower = deal.store_chain.lower()
                    normalized_chain = kroger_name_mapping.get(chain_lower, None)
                    
                    # If not a Kroger family chain, always keep
                    if normalized_chain is None:
                        return True
                    
                    # If we have API prices for this chain, remove Flipp result
                    if normalized_chain in normalized_api_chains:
                        return False
                    
                    return True
                
                deals = [d for d in deals if should_keep_flipp(d)]
                
                # NOW add Kroger API results
                for price in kroger_prices:
                    deals.append(ParsedCircularItem(
                        product_name=price.product_name,
                        sale_price=price.price,
                        regular_price=price.original_price,
                        unit=price.size,
                        store_chain=price.store_chain,
                        valid_from=datetime.now().date(),
                        valid_until=None,
                        is_bogo=False,
                        image_url=None,
                    ))
        except Exception as e:
            # Log but don't fail if Kroger API fails
            import logging
            logging.warning(f"Kroger API error (continuing with Flipp data): {e}")
        
        # Sort by price
        deals.sort(key=lambda d: d.sale_price)
        
        return CircularSearchResponse(
            query=q,
            results=[
                CircularDealResponse(
                    product_name=d.product_name,
                    sale_price=d.sale_price,
                    regular_price=d.regular_price,
                    unit=d.unit,
                    # Preserve real merchant if present; final fallback remains Local Deals
                    store_chain=d.store_chain or "Local Deals",
                    valid_from=d.valid_from.isoformat() if d.valid_from else None,
                    valid_until=d.valid_until.isoformat() if d.valid_until else None,
                    is_bogo=d.is_bogo,
                    image_url=d.image_url,
                )
                for d in deals
            ],
            count=len(deals),
        )
    finally:
        await parser.close()
        await crawler.close()


@router.get("/deals/store/{store_chain}")
async def get_store_deals(
    store_chain: str,
    zip_code: str = Query("92117", description="ZIP code for local deals"),
):
    """
    Get all current deals for a specific store.
    
    Returns the complete weekly circular for a store chain.
    """
    parser = CircularParser()
    
    try:
        deals = await parser.fetch_and_parse(store_chain, zip_code)
        
        return {
            "store_chain": store_chain,
            "zip_code": zip_code,
            "deals": [
                CircularDealResponse(
                    product_name=d.product_name,
                    sale_price=d.sale_price,
                    regular_price=d.regular_price,
                    unit=d.unit,
                    store_chain=d.store_chain or store_chain,
                    valid_from=d.valid_from.isoformat() if d.valid_from else None,
                    valid_until=d.valid_until.isoformat() if d.valid_until else None,
                    is_bogo=d.is_bogo,
                    image_url=d.image_url,
                )
                for d in deals
            ],
            "count": len(deals),
        }
    finally:
        await parser.close()

# ================================================================
# AI VISION SCRAPER ENDPOINTS
# ================================================================

class AIScrapePriceResponse(BaseModel):
    """A price scraped by AI vision."""
    product_name: str
    price: float
    original_price: Optional[float] = None
    size: Optional[str] = None
    store_chain: str
    is_on_sale: bool = False
    source: str = "ai_vision"


class AIScrapeResponse(BaseModel):
    """Response for AI scrape request."""
    query: str
    store: str
    results: list[AIScrapePriceResponse]
    count: int
    ai_backend: Optional[str] = None


class AIScrapeAllResponse(BaseModel):
    """Response for scraping all stores."""
    query: str
    results: list[AIScrapePriceResponse]
    count: int
    stores_scraped: list[str]


# IMPORTANT: Status endpoint must come BEFORE the {store} path parameter route
@router.get("/ai-scrape/status")
async def ai_scraper_status():
    """
    Check AI scraper availability and configuration.
    
    Returns which AI backends are available and their configuration.
    """
    from app.config import get_settings
    
    settings = get_settings()
    
    status = {
        "ai_scraper_enabled": settings.ai_scraper_enabled,
        "playwright_available": False,
        "ollama_configured": False,
        "ollama_url": settings.ollama_url,
        "ollama_model": settings.ollama_vision_model,
        "google_ai_configured": bool(settings.google_ai_api_key),
        "openai_configured": bool(settings.openai_api_key),
        "supported_stores": [],
        "cache_hours": settings.ai_scraper_cache_hours,
        "max_stores_per_query": settings.ai_scraper_max_stores_per_query,
    }
    
    # Check Playwright
    try:
        import playwright
        status["playwright_available"] = True
    except ImportError:
        pass
    
    # Check Ollama
    try:
        import httpx
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(f"{status['ollama_url']}/api/tags")
            if response.status_code == 200:
                status["ollama_configured"] = True
                models = response.json().get("models", [])
                vision_models = [m["name"] for m in models if any(v in m["name"].lower() for v in ["llava", "vision", "bakllava"])]
                status["ollama_vision_models"] = vision_models
    except:
        pass
    
    # List supported stores
    try:
        from app.services.ai_price_scraper import AIPriceScraper
        status["supported_stores"] = list(AIPriceScraper.STORE_URLS.keys())
    except:
        pass
    
    return status


@router.get("/ai-scrape", response_model=AIScrapeAllResponse)
async def ai_scrape_all_stores(
    q: str = Query(..., min_length=1, description="Product to search for"),
    zip_code: str = Query("92117", description="ZIP code"),
    stores: str = Query("aldi,walmart,target", description="Comma-separated list of stores"),
):
    """
    Scrape prices from multiple stores using AI vision.
    
    This can take a while as it screenshots and analyzes each store.
    """
    try:
        from app.services.ai_price_scraper import AIPriceScraper
        
        store_list = [s.strip().lower() for s in stores.split(",")]
        
        scraper = AIPriceScraper()
        await scraper.initialize()
        
        try:
            all_prices = []
            scraped_stores = []
            
            for store in store_list[:5]:  # Limit to 5 stores
                prices = await scraper.scrape_store_prices(store, q, zip_code)
                if prices:
                    all_prices.extend(prices)
                    scraped_stores.append(store)
            
            return AIScrapeAllResponse(
                query=q,
                results=[
                    AIScrapePriceResponse(
                        product_name=p.product_name,
                        price=p.price,
                        original_price=p.original_price,
                        size=p.size,
                        store_chain=p.store_chain,
                        is_on_sale=p.is_on_sale,
                        source=p.source,
                    )
                    for p in all_prices
                ],
                count=len(all_prices),
                stores_scraped=scraped_stores,
            )
        finally:
            await scraper.close()
            
    except ImportError as e:
        raise HTTPException(
            status_code=503,
            detail=f"AI scraper dependencies not installed: {e}"
        )


@router.get("/ai-scrape/{store}", response_model=AIScrapeResponse)
async def ai_scrape_store(
    store: str,
    q: str = Query(..., min_length=1, description="Product to search for"),
    zip_code: str = Query("92117", description="ZIP code"),
):
    """
    Scrape prices from a store using AI vision.
    
    This uses a vision AI model to "read" the store's website like a human would.
    Requires either:
    - Ollama running locally with LLaVA model (free)
    - Google AI API key (GOOGLE_AI_API_KEY env var) - free tier
    - OpenAI API key (OPENAI_API_KEY env var) - paid
    
    Also requires Playwright for screenshots:
    pip install playwright && playwright install chromium
    """
    try:
        from app.services.ai_price_scraper import AIPriceScraper
        
        scraper = AIPriceScraper()
        await scraper.initialize()
        
        try:
            prices = await scraper.scrape_store_prices(store, q, zip_code)
            
            return AIScrapeResponse(
                query=q,
                store=store,
                results=[
                    AIScrapePriceResponse(
                        product_name=p.product_name,
                        price=p.price,
                        original_price=p.original_price,
                        size=p.size,
                        store_chain=p.store_chain,
                        is_on_sale=p.is_on_sale,
                        source=p.source,
                    )
                    for p in prices
                ],
                count=len(prices),
            )
        finally:
            await scraper.close()
            
    except ImportError as e:
        raise HTTPException(
            status_code=503,
            detail=f"AI scraper dependencies not installed: {e}. Install with: pip install playwright && playwright install chromium"
        )
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"AI scraping failed: {str(e)}"
        )


@router.get("/ai-scrape", response_model=AIScrapeAllResponse)
async def ai_scrape_all_stores(
    q: str = Query(..., min_length=1, description="Product to search for"),
    zip_code: str = Query("92117", description="ZIP code"),
    stores: str = Query("aldi,walmart,target", description="Comma-separated list of stores"),
):
    """
    Scrape prices from multiple stores using AI vision.
    
    This can take a while as it screenshots and analyzes each store.
    """
    try:
        from app.services.ai_price_scraper import AIPriceScraper
        
        store_list = [s.strip().lower() for s in stores.split(",")]
        
        scraper = AIPriceScraper()
        await scraper.initialize()
        
        try:
            all_prices = []
            scraped_stores = []
            
            for store in store_list[:5]:  # Limit to 5 stores
                prices = await scraper.scrape_store_prices(store, q, zip_code)
                if prices:
                    all_prices.extend(prices)
                    scraped_stores.append(store)
            
            return AIScrapeAllResponse(
                query=q,
                results=[
                    AIScrapePriceResponse(
                        product_name=p.product_name,
                        price=p.price,
                        original_price=p.original_price,
                        size=p.size,
                        store_chain=p.store_chain,
                        is_on_sale=p.is_on_sale,
                        source=p.source,
                    )
                    for p in all_prices
                ],
                count=len(all_prices),
                stores_scraped=scraped_stores,
            )
        finally:
            await scraper.close()
            
    except ImportError as e:
        raise HTTPException(
            status_code=503,
            detail=f"AI scraper dependencies not installed: {e}"
        )


@router.get("/ai-scrape/status")
async def ai_scraper_status():
    """
    Check AI scraper availability and configuration.
    
    Returns which AI backends are available.
    """
    import os
    
    status = {
        "playwright_available": False,
        "ollama_configured": False,
        "ollama_url": os.getenv("OLLAMA_URL", "http://localhost:11434"),
        "google_ai_configured": bool(os.getenv("GOOGLE_AI_API_KEY")),
        "openai_configured": bool(os.getenv("OPENAI_API_KEY")),
        "supported_stores": [],
    }
    
    # Check Playwright
    try:
        import playwright
        status["playwright_available"] = True
    except ImportError:
        pass
    
    # Check Ollama
    try:
        import httpx
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(f"{status['ollama_url']}/api/tags")
            if response.status_code == 200:
                status["ollama_configured"] = True
                models = response.json().get("models", [])
                vision_models = [m["name"] for m in models if any(v in m["name"].lower() for v in ["llava", "vision", "bakllava"])]
                status["ollama_vision_models"] = vision_models
    except:
        pass
    
    # List supported stores
    try:
        from app.services.ai_price_scraper import AIPriceScraper
        status["supported_stores"] = list(AIPriceScraper.STORE_URLS.keys())
    except:
        pass
    
    return status

# ================================================================
# CROWDSOURCED PRICE CORRECTION ENDPOINTS
# ================================================================

@router.post("/prices/correction", response_model=PriceCorrectionResponse)
async def submit_price_correction(request: PriceCorrectionRequest):
    """
    Submit a crowdsourced price correction.
    
    Similar to GasBuddy, users can report when prices are wrong.
    Corrections with multiple upvotes become verified.
    """
    from app.services.crowdsource_prices import get_crowdsource_service
    
    service = get_crowdsource_service()
    correction = service.submit_correction(
        item_name=request.item_name,
        store_name=request.store_name,
        store_chain=request.store_chain,
        old_price=request.old_price,
        new_price=request.new_price,
        product_size=request.product_size,
        store_id=request.store_id,
    )
    
    return PriceCorrectionResponse(
        item_name=correction.item_name,
        store_name=correction.store_name,
        store_chain=correction.store_chain,
        old_price=correction.old_price,
        new_price=correction.new_price,
        product_size=correction.product_size,
        submitted_at=correction.submitted_at,
        is_verified=correction.is_verified,
        upvotes=correction.upvotes,
        downvotes=correction.downvotes,
        message="Price correction submitted successfully! Others can vote to verify it.",
    )


@router.post("/prices/correction/vote")
async def vote_on_correction(request: PriceVoteRequest):
    """
    Vote on a price correction.
    
    Upvote if the price is correct, downvote if it's wrong.
    Corrections with 3+ net upvotes become verified.
    """
    from app.services.crowdsource_prices import get_crowdsource_service
    
    service = get_crowdsource_service()
    result = service.vote(
        item_name=request.item_name,
        store_name=request.store_name,
        is_upvote=request.is_upvote,
    )
    
    if result is None:
        raise HTTPException(status_code=404, detail="Price correction not found")
    
    return {
        "message": "Vote recorded",
        "upvotes": result.get("upvotes", 0),
        "downvotes": result.get("downvotes", 0),
        "is_verified": result.get("is_verified", False),
    }


@router.get("/prices/corrections")
async def get_corrections(
    store_name: Optional[str] = Query(None, description="Filter by store name"),
    verified_only: bool = Query(False, description="Only return verified corrections"),
    max_age_hours: int = Query(168, ge=1, le=720, description="Maximum age in hours"),
):
    """
    Get crowdsourced price corrections.
    
    Returns recent corrections that can be used to improve prices.
    """
    from app.services.crowdsource_prices import get_crowdsource_service
    
    service = get_crowdsource_service()
    
    if store_name:
        corrections = service.get_corrections_for_store(store_name, max_age_hours)
    else:
        corrections = service.get_all_corrections(max_age_hours, verified_only)
    
    return {
        "corrections": corrections,
        "count": len(corrections),
    }


@router.get("/prices/corrections/stats", response_model=CrowdsourceStatsResponse)
async def get_crowdsource_stats():
    """
    Get statistics about crowdsourced prices.
    """
    from app.services.crowdsource_prices import get_crowdsource_service
    
    service = get_crowdsource_service()
    stats = service.get_stats()
    
    return CrowdsourceStatsResponse(**stats)


# ================================================================
# AI SCRAPER SCHEDULER CONTROL ENDPOINTS
# ================================================================

@router.post("/ai-scrape/scheduler/start")
async def start_ai_scraper_scheduler(
    interval_hours: int = Query(6, ge=1, le=24, description="Scraping interval in hours"),
):
    """
    Start the AI scraper background scheduler.
    
    The scheduler will periodically scrape prices for common grocery items
    from priority stores and cache the results.
    """
    from app.services.ai_price_scraper import get_ai_scraper_scheduler
    
    scheduler = get_ai_scraper_scheduler()
    
    if scheduler.running:
        return {"status": "already_running", "message": "Scheduler is already running"}
    
    await scheduler.start(interval_hours)
    
    return {
        "status": "started",
        "message": f"AI scraper scheduler started with {interval_hours}h interval",
        "tracked_items": scheduler.TRACKED_ITEMS,
        "priority_stores": scheduler.PRIORITY_STORES,
    }


@router.post("/ai-scrape/scheduler/stop")
async def stop_ai_scraper_scheduler():
    """
    Stop the AI scraper background scheduler.
    """
    from app.services.ai_price_scraper import get_ai_scraper_scheduler
    
    scheduler = get_ai_scraper_scheduler()
    
    if not scheduler.running:
        return {"status": "not_running", "message": "Scheduler is not running"}
    
    await scheduler.stop()
    
    return {"status": "stopped", "message": "AI scraper scheduler stopped"}


@router.get("/ai-scrape/scheduler/status")
async def get_ai_scraper_scheduler_status():
    """
    Get the AI scraper scheduler status and cached prices.
    """
    from app.services.ai_price_scraper import get_ai_scraper_scheduler
    
    scheduler = get_ai_scraper_scheduler()
    
    return {
        "running": scheduler.running,
        "tracked_items": scheduler.TRACKED_ITEMS,
        "priority_stores": scheduler.PRIORITY_STORES,
        "cached_items": list(scheduler.scraped_prices.keys()),
        "cache_counts": {k: len(v) for k, v in scheduler.scraped_prices.items()},
    }


@router.get("/ai-scrape/cached/{query}")
async def get_cached_ai_prices(query: str):
    """
    Get cached AI-scraped prices for a query.
    
    This returns prices that were scraped by the background scheduler,
    without triggering a new scrape.
    """
    from app.services.ai_price_scraper import get_ai_scraper_scheduler
    
    scheduler = get_ai_scraper_scheduler()
    prices = scheduler.get_cached_prices(query)
    
    return {
        "query": query,
        "results": [
            {
                "product_name": p.product_name,
                "price": p.price,
                "original_price": p.original_price,
                "size": p.size,
                "store_chain": p.store_chain,
                "is_on_sale": p.is_on_sale,
                "scraped_at": p.scraped_at.isoformat(),
            }
            for p in prices
        ],
        "count": len(prices),
        "from_cache": True,
    }
