"""
Price Crawler Service - Scrapes prices from grocery store websites.

This service runs as background tasks to:
1. Crawl store websites for current prices
2. Store prices in the database
3. Notify connected clients of updates
"""

import asyncio
import re
from datetime import date, datetime, timedelta
from typing import Optional
from dataclasses import dataclass

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.database import async_session_maker
from app.models.product import Product
from app.models.price import Price
from app.models.store import Store


@dataclass
class ScrapedPrice:
    """A price scraped from a store website."""
    product_name: str
    price: float
    original_price: Optional[float]
    is_on_sale: bool
    size: Optional[str]
    store_chain: str
    store_name: str
    product_url: Optional[str] = None
    image_url: Optional[str] = None
    upc: Optional[str] = None


def _product_matches_query(product_name: str, query: str, min_score: float = 0.6) -> bool:
    """Check if a product name reasonably matches a search query.
    
    This helps filter out results that don't actually match what was searched for.
    For example, searching for "envy apple" should not return "red delicious apple"
    or generic "apple" results.
    
    Args:
        product_name: The product name returned from the API
        query: The original search query
        min_score: Minimum match score (0-1) to consider a match
        
    Returns:
        True if the product reasonably matches the query
    """
    # Normalize strings
    product_lower = product_name.lower().strip()
    query_lower = query.lower().strip()
    
    # Split into words (keep original for word matching)
    product_words = set(re.split(r'[\s,]+', product_lower))
    query_words = set(re.split(r'[\s,]+', query_lower))
    
    # Remove common filler words and size info for matching
    filler = {'the', 'a', 'an', 'of', 'and', 'or', '-', '&'}
    size_words = {'oz', 'lb', 'ct', 'count', 'pack', 'gallon', 'quart', 'pint', 'liter'}
    product_words_clean = product_words - filler - size_words
    # Also remove numeric values
    product_words_clean = {w for w in product_words_clean if not re.match(r'^\d+\.?\d*$', w)}
    query_words_clean = query_words - filler - size_words
    
    if not query_words_clean or not product_words_clean:
        return True  # Can't validate, allow it
    
    # List of compound products that contain ingredients but aren't those ingredients
    compound_products = {
        'tortillas', 'cookies', 'crackers', 'cakes', 'cake', 'chips', 
        'bars', 'bar', 'cereal', 'muffins', 'muffin', 'chocolate', 'candy',
        'pudding', 'yogurt', 'spread', 'sauce', 'syrup', 'drink', 'drinks',
        'powder', 'baking', 'mix', 'dressing', 'coating', 'breading',
        'peanut', 'almond', 'cashew', 'sunflower',  # For "peanut butter" etc.
    }
    
    # For single-word ingredient queries (like "flour", "sugar", "butter"),
    # the product should BE that ingredient, not just contain it as a modifier
    # These are products where the query word should be the PRIMARY product, not a descriptor
    if len(query_words_clean) == 1:
        query_word = list(query_words_clean)[0]
        
        # If the product contains the query word AND a compound product word,
        # it's probably not what we want (e.g., "flour tortillas" when searching "flour")
        if query_word in product_words_clean:
            if product_words_clean & compound_products:
                return False
            return True
        else:
            return False
    
    # For multi-word queries, check how many query words appear in the product
    matched_words = query_words_clean & product_words_clean
    
    # Calculate match score - need all query words (or their plural/singular variants)
    for qw in query_words_clean:
        # Check for the word or its singular/plural variant
        singular = qw.rstrip('s') if qw.endswith('s') else qw
        plural = qw + 's' if not qw.endswith('s') else qw
        if qw not in product_words_clean and singular not in product_words_clean and plural not in product_words_clean:
            return False
    
    # All query words found
    return True


class PriceCrawler:
    """
    Crawls grocery store websites for product prices.
    
    Designed to run server-side where we can:
    - Use proper user agents and headers
    - Handle rate limiting gracefully
    - Retry failed requests
    - Cache and store results in database
    """
    
    # Request configuration
    REQUEST_TIMEOUT = 15.0
    MAX_RETRIES = 3
    RETRY_DELAY = 2.0
    
    # Rate limiting - requests per second per store
    RATE_LIMITS = {
        'walmart': 0.5,  # 1 request per 2 seconds
        'target': 0.5,
        'kroger': 1.0,
        'costco': 0.5,
        'aldi': 1.0,
    }

    # Enable/disable scraping per store to avoid noisy failures
    # NOTE: HTML scraping is unreliable for JS-heavy sites. Prefer:
    # - Official APIs (Kroger API, Target Redsky)
    # - Flipp weekly circulars
    # - Structured data sources
    ENABLE_SCRAPERS = {
        'walmart': False,  # HTML scraping unreliable, use Flipp circulars
        'target': True,    # Uses Redsky API
        'kroger': True,    # Uses official API when credentials configured
        'costco': False,   # Site blocks scraping, use Flipp circulars
        'aldi': True,      # Nuxt.js data extraction works
    }
    
    # Last request times for rate limiting
    _last_request: dict[str, datetime] = {}
    
    def __init__(self):
        self.client = httpx.AsyncClient(
            timeout=self.REQUEST_TIMEOUT,
            follow_redirects=True,
            headers={
                'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
                'Accept-Language': 'en-US,en;q=0.5',
                'Accept-Encoding': 'gzip, deflate, br',
                'Connection': 'keep-alive',
            }
        )
    
    async def close(self):
        """Close the HTTP client."""
        await self.client.aclose()
    
    async def _rate_limit(self, store: str):
        """Enforce rate limiting for a store."""
        rate = self.RATE_LIMITS.get(store.lower(), 1.0)
        min_interval = 1.0 / rate
        
        last = self._last_request.get(store.lower())
        if last:
            elapsed = (datetime.now() - last).total_seconds()
            if elapsed < min_interval:
                await asyncio.sleep(min_interval - elapsed)
        
        self._last_request[store.lower()] = datetime.now()
    
    async def _get_with_retry(self, url: str, store: str) -> Optional[str]:
        """Make an HTTP GET request with retry logic."""
        await self._rate_limit(store)
        
        for attempt in range(self.MAX_RETRIES):
            try:
                response = await self.client.get(url)
                if response.status_code == 200:
                    return response.text
                if response.status_code in (403, 429):  # blocked or rate-limited
                    print(f"{store} blocked request ({response.status_code}) for {url}")
                    return None
                elif response.status_code == 429:  # Rate limited
                    await asyncio.sleep(self.RETRY_DELAY * (attempt + 1) * 2)
                elif response.status_code >= 500:  # Server error
                    await asyncio.sleep(self.RETRY_DELAY * (attempt + 1))
                else:
                    return None
            except Exception as e:
                print(f"Request error for {url}: {e}")
                if attempt < self.MAX_RETRIES - 1:
                    await asyncio.sleep(self.RETRY_DELAY * (attempt + 1))
        
        return None
    
    # ================================================================
    # WALMART CRAWLER
    # ================================================================
    async def crawl_walmart(self, query: str) -> list[ScrapedPrice]:
        """Crawl Walmart for product prices.
        
        NOTE: Walmart's website is heavily JavaScript-rendered with anti-bot 
        protection, making HTML scraping unreliable. The regex parser would
        extract random dollar amounts from the page (ads, shipping thresholds,
        unrelated products).
        
        For better Walmart prices, rely on:
        - Flipp weekly circular data (via CircularParser)
        - Price estimates based on Walmart's known pricing tier
        
        TODO: Implement Walmart's official affiliate API if available.
        """
        if not self.ENABLE_SCRAPERS.get('walmart', True):
            return []
        
        # Skip unreliable HTML scraping - Walmart prices come from Flipp circulars
        # and estimate generation instead
        return []
    
    # NOTE: _parse_walmart removed - HTML scraping was extracting random prices
    # from page elements (shipping, ads, gift cards) without product context.
    
    # ================================================================
    # TARGET CRAWLER
    # ================================================================
    async def crawl_target(self, query: str) -> list[ScrapedPrice]:
        """Crawl Target for product prices.
        
        NOTE: Target's website is heavily JavaScript-rendered, making simple
        HTML scraping unreliable. We try to use their Redsky API first.
        For better Target prices, rely on Flipp weekly circular data.
        """
        if not self.ENABLE_SCRAPERS.get('target', True):
            return []
        
        # Try Target's Redsky API first (more reliable than HTML scraping)
        try:
            redsky_url = (
                'https://redsky.target.com/redsky_aggregations/v1/web/plp_search_v2'
                f'?key=9f36aeafbe60771e321a7cc95a78140772ab3e96'
                f'&channel=WEB&count=10'
                f'&keyword={query}'
                f'&offset=0&pricing_store_id=1'
            )
            
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.get(redsky_url, headers={
                    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
                    'Accept': 'application/json',
                })
                
                if response.status_code == 200:
                    results = self._parse_target_redsky(response.text, query)
                    if results:
                        return results
        except Exception as e:
            print(f"Target Redsky API error: {e}")
        
        # Redsky didn't work, skip unreliable HTML scraping
        # Target prices will come from Flipp weekly circulars instead
        return []
    
    def _parse_target_redsky(self, json_text: str, query: str) -> list[ScrapedPrice]:
        """Parse Target's Redsky API JSON response."""
        results = []
        
        try:
            import json
            data = json.loads(json_text)
            
            # Navigate the Redsky response structure
            products = (
                data.get('data', {})
                .get('search', {})
                .get('products', [])
            )
            
            for product in products[:10]:
                try:
                    # Get product info
                    item = product.get('item', {})
                    title = item.get('product_description', {}).get('title', '')
                    
                    # Get price from the price object
                    price_obj = product.get('price', {})
                    current_price = price_obj.get('current_retail')
                    regular_price = price_obj.get('reg_retail')
                    
                    if not current_price or not title:
                        continue
                    
                    # Validate this product matches the query
                    if not _product_matches_query(title, query):
                        continue
                    
                    is_on_sale = (
                        regular_price is not None and 
                        current_price < regular_price
                    )
                    
                    results.append(ScrapedPrice(
                        product_name=title,
                        price=float(current_price),
                        original_price=float(regular_price) if regular_price else None,
                        is_on_sale=is_on_sale,
                        size=None,
                        store_chain='Target',
                        store_name='Target',
                    ))
                except (KeyError, TypeError, ValueError) as e:
                    continue
                    
        except Exception as e:
            print(f"Error parsing Target Redsky response: {e}")
        
        return results
    
    # ================================================================
    # KROGER CRAWLER (using API if available)
    # ================================================================
    async def crawl_kroger(self, query: str, zip_code: str | None = None) -> list[ScrapedPrice]:
        """Crawl Kroger for product prices using official API."""
        if not self.ENABLE_SCRAPERS.get('kroger', True):
            return []
        
        from app.config import get_settings
        settings = get_settings()
        
        # Use official API if credentials are configured
        if settings.kroger_client_id and settings.kroger_client_secret:
            results = await self._crawl_kroger_api(query, zip_code=zip_code)
            if results:
                return results
            # Fall through to scraping if API returns nothing
        
        # Otherwise fall back to web scraping
        url = httpx.URL(
            'https://www.kroger.com/search',
            params={'query': query},
        )
        html = await self._get_with_retry(str(url), 'kroger')
        
        if not html:
            return []
        
        return self._parse_kroger(html, query)
    
    async def _crawl_kroger_api(self, query: str, zip_code: str | None = None) -> list[ScrapedPrice]:
        """Use Kroger's official API for product search.
        
        Fetches prices from ALL nearby Kroger-family stores (Kroger, Ralphs, 
        Fred Meyer, Food 4 Less, etc.) for the given ZIP code.
        """
        from app.services.kroger_client import KrogerClient
        from app.config import get_settings
        
        results = []
        client = KrogerClient()
        settings = get_settings()
        
        try:
            # Find all nearby Kroger-family stores for this ZIP code
            locations_to_check = []
            
            if zip_code:
                # Get multiple stores within radius to cover different banners
                all_locations = await client.get_locations(zip_code, radius_miles=15, limit=10)
                
                # Group by store chain/banner to get one of each type
                seen_chains = set()
                for loc in all_locations:
                    # Extract chain name from Kroger API response
                    chain = loc.get('chain', '').upper()
                    name = loc.get('name', '')
                    name_upper = name.upper()
                    
                    # Normalize chain name - Complete Kroger Co. Family of Stores
                    # See: https://www.thekrogerco.com/about-kroger/our-business/
                    chain_key = 'KROGER'  # Default
                    
                    if 'BAKER' in chain or 'BAKER' in name_upper:
                        chain_key = 'BAKERS'
                    elif 'CITY MARKET' in chain or 'CITY MARKET' in name_upper:
                        chain_key = 'CITY_MARKET'
                    elif 'DILLONS' in chain or 'DILLONS' in name_upper:
                        chain_key = 'DILLONS'
                    elif 'FOOD 4 LESS' in chain or 'FOOD4LESS' in chain or 'FOOD 4 LESS' in name_upper or 'FOOD4LESS' in name_upper:
                        chain_key = 'FOOD4LESS'
                    elif 'FOODS CO' in chain or 'FOODSCO' in chain or 'FOODS CO' in name_upper:
                        chain_key = 'FOODS_CO'
                    elif 'FRED MEYER' in chain or 'FRED MEYER' in name_upper:
                        chain_key = 'FRED_MEYER'
                    elif "FRY'S" in chain or 'FRYS' in chain or "FRY'S" in name_upper or 'FRYS' in name_upper:
                        chain_key = 'FRYS'
                    elif 'GERBES' in chain or 'GERBES' in name_upper:
                        chain_key = 'GERBES'
                    elif 'JAY C' in chain or 'JAY C' in name_upper:
                        chain_key = 'JAY_C'
                    elif 'KING SOOPERS' in chain or 'KING SOOPERS' in name_upper:
                        chain_key = 'KING_SOOPERS'
                    elif 'MARIANO' in chain or 'MARIANO' in name_upper:
                        chain_key = 'MARIANOS'
                    elif 'METRO MARKET' in chain or 'METRO MARKET' in name_upper:
                        chain_key = 'METRO_MARKET'
                    elif 'PAY-LESS' in chain or 'PAYLESS' in chain or 'PAY LESS' in name_upper or 'PAYLESS' in name_upper:
                        chain_key = 'PAY_LESS'
                    elif "PICK'N SAVE" in chain or 'PICKNSAVE' in chain or "PICK'N SAVE" in name_upper or 'PICK N SAVE' in name_upper:
                        chain_key = 'PICK_N_SAVE'
                    elif 'QFC' in chain or 'QFC' in name_upper or 'QUALITY FOOD' in name_upper:
                        chain_key = 'QFC'
                    elif 'RALPHS' in chain or 'RALPHS' in name_upper:
                        chain_key = 'RALPHS'
                    elif 'RULER' in chain or 'RULER' in name_upper:
                        chain_key = 'RULER'
                    elif "SMITH'S" in chain or 'SMITHS' in chain or "SMITH'S" in name_upper or 'SMITHS' in name_upper:
                        chain_key = 'SMITHS'
                    elif 'HARRIS TEETER' in chain or 'HARRIS TEETER' in name_upper:
                        chain_key = 'HARRIS_TEETER'
                    
                    # Add one store per chain type
                    if chain_key not in seen_chains:
                        seen_chains.add(chain_key)
                        # Get display name - use friendly names
                        display_names = {
                            'BAKERS': "Baker's",
                            'CITY_MARKET': 'City Market',
                            'DILLONS': 'Dillons',
                            'FOOD4LESS': 'Food 4 Less',
                            'FOODS_CO': 'Foods Co',
                            'FRED_MEYER': 'Fred Meyer',
                            'FRYS': "Fry's",
                            'GERBES': 'Gerbes',
                            'JAY_C': 'Jay C Food Store',
                            'KING_SOOPERS': 'King Soopers',
                            'KROGER': 'Kroger',
                            'MARIANOS': "Mariano's",
                            'METRO_MARKET': 'Metro Market',
                            'PAY_LESS': 'Pay-Less Super Markets',
                            'PICK_N_SAVE': "Pick'n Save",
                            'QFC': 'QFC',
                            'RALPHS': 'Ralphs',
                            'RULER': 'Ruler',
                            'SMITHS': "Smith's Food and Drug",
                            'HARRIS_TEETER': 'Harris Teeter',
                        }
                        store_name = display_names.get(chain_key, chain_key.replace('_', ' ').title())
                        locations_to_check.append({
                            'location_id': loc.get('locationId'),
                            'store_name': store_name,
                        })
            
            # Fall back to default location if no ZIP or no stores found
            if not locations_to_check:
                locations_to_check.append({
                    'location_id': settings.kroger_default_location_id,
                    'store_name': 'Kroger',
                })
            
            # Fetch prices from each store
            for store_info in locations_to_check:
                location_id = store_info['location_id']
                store_name = store_info['store_name']
                
                try:
                    # Search for products at this location
                    products = await client.search_products(query, location_id=location_id, limit=10)
                    
                    for product in products:
                        try:
                            # Extract product info
                            description = product.get('description', query)
                            brand = product.get('brand', '')
                            product_name = f"{brand} {description}".strip() if brand else description
                            
                            # Validate that this product matches what was searched for
                            # This prevents returning generic "apple" for "envy apple" search
                            if not _product_matches_query(product_name, query):
                                continue
                            
                            # Get pricing info - Kroger API returns items array with price
                            items = product.get('items', [])
                            if items:
                                item = items[0]
                                size = item.get('size') or product.get('productSize')
                                
                                price_info = item.get('price', {})
                                regular_price = price_info.get('regular')
                                promo_price = price_info.get('promo')
                                
                                if regular_price:
                                    current_price = promo_price if promo_price and promo_price < regular_price else regular_price
                                    is_on_sale = promo_price is not None and promo_price < regular_price
                                    
                                    results.append(ScrapedPrice(
                                        product_name=product_name,
                                        price=current_price,
                                        original_price=regular_price if is_on_sale else None,
                                        is_on_sale=is_on_sale,
                                        size=size,
                                        store_chain=store_name,
                                        store_name=store_name,
                                        upc=product.get('upc'),
                                    ))
                        except Exception as e:
                            print(f"Error parsing Kroger product: {e}")
                            continue
                except Exception as e:
                    print(f"Error fetching from {store_name}: {e}")
                    continue
                    
        except Exception as e:
            # Only log if it's not an auth error (expected without valid credentials)
            if "401" not in str(e) and "Unauthorized" not in str(e):
                print(f"Kroger API error: {e}")
        
        return results
    
    def _parse_kroger(self, html: str, query: str) -> list[ScrapedPrice]:
        """Parse Kroger search results HTML.
        
        NOTE: This fallback parser is disabled because simple regex parsing
        extracts random prices from the page without context. Kroger prices
        should come from the official Kroger API (when credentials are configured)
        or from Flipp weekly circulars.
        
        The regex pattern `\$X.XX` matches any dollar amount on the page including:
        - Shipping thresholds
        - Ad prices for unrelated products
        - Loyalty card values
        - Gift card amounts
        """
        # Skip unreliable HTML parsing - use Kroger API instead
        return []
    
    # ================================================================
    # COSTCO CRAWLER
    # ================================================================
    async def crawl_costco(self, query: str) -> list[ScrapedPrice]:
        """Crawl Costco for product prices."""
        if not self.ENABLE_SCRAPERS.get('costco', True):
            return []
        # Costco scraping is disabled - site blocks scrapers aggressively
        # Use Flipp weekly circulars for Costco deals instead
        return []
    
    # NOTE: _parse_costco removed - Costco blocks scrapers and simple regex
    # parsing extracts random prices without product context.
    
    # ================================================================
    # ALDI CRAWLER
    # ================================================================
    async def crawl_aldi(self, query: str) -> list[ScrapedPrice]:
        """Crawl Aldi for product prices."""
        if not self.ENABLE_SCRAPERS.get('aldi', True):
            return []
        url = httpx.URL(
            'https://www.aldi.us/results',
            params={'q': query},
        )
        html = await self._get_with_retry(str(url), 'aldi')
        
        if not html:
            return []
        
        return self._parse_aldi(html, query)
    
    def _parse_aldi(self, html: str, query: str) -> list[ScrapedPrice]:
        """Parse Aldi search results - extract from Nuxt.js embedded data."""
        results = []
        
        try:
            # Aldi uses Nuxt.js which embeds data in __NUXT_DATA__ script
            import json
            
            nuxt_match = re.search(r'<script[^>]*id="__NUXT_DATA__"[^>]*>(.*?)</script>', html, re.DOTALL)
            if not nuxt_match:
                return self._parse_aldi_legacy(html, query)
            
            nuxt_data = nuxt_match.group(1).strip()
            
            try:
                data = json.loads(nuxt_data)
            except json.JSONDecodeError:
                return self._parse_aldi_legacy(html, query)
            
            # Helper to resolve index references in Nuxt data
            def resolve(value, depth=0):
                """Resolve a value that might be an index reference."""
                if depth > 3:  # Prevent infinite recursion
                    return value
                if isinstance(value, int) and 0 <= value < len(data):
                    resolved = data[value]
                    # Handle ['Ref', index] and ['Reactive', index] patterns
                    if isinstance(resolved, list) and len(resolved) == 2:
                        if resolved[0] in ('Ref', 'Reactive') and isinstance(resolved[1], int):
                            return resolve(resolved[1], depth + 1)
                    return resolved
                return value
            
            # Find search result data - look for {'meta': X, 'data': Y} structure
            # where 'data' contains the array of products
            search_products = []
            
            for i, item in enumerate(data):
                if isinstance(item, dict) and 'meta' in item and 'data' in item:
                    # This might be the search result container
                    data_ref = item.get('data')
                    data_array = resolve(data_ref)
                    
                    if isinstance(data_array, list):
                        # This is an array of product indices
                        for prod_ref in data_array:
                            prod = resolve(prod_ref)
                            if isinstance(prod, dict) and 'sku' in prod and 'name' in prod:
                                search_products.append(prod)
            
            # Parse the found products
            for item in search_products:
                try:
                    # Resolve the name
                    name = resolve(item.get('name'))
                    if not isinstance(name, str):
                        continue
                    
                    # Skip if it doesn't look like a product name
                    if len(name) < 3 or len(name) > 200:
                        continue
                    
                    # Get price - it's a nested object with 'amount' 
                    price_ref = item.get('price')
                    if price_ref is None:
                        continue
                        
                    price_obj = resolve(price_ref)
                    if not isinstance(price_obj, dict):
                        continue
                    
                    # Get amount from price object
                    amount = resolve(price_obj.get('amount'))
                    if not isinstance(amount, (int, float)):
                        continue
                    
                    # Amount is in cents (e.g., 329 = $3.29)
                    price = amount / 100.0
                    
                    # Skip unreasonable prices
                    if price > 100 or price < 0.10:
                        continue
                    
                    # Get selling size if available
                    size = resolve(item.get('sellingSize'))
                    if not isinstance(size, str):
                        size = None
                    
                    # Also try to extract size from name (e.g., "Envy Apples, 2 lb")
                    if not size and ',' in name:
                        parts = name.rsplit(',', 1)
                        if len(parts) == 2:
                            size = parts[1].strip()
                    
                    results.append(ScrapedPrice(
                        product_name=name,
                        price=price,
                        original_price=None,
                        is_on_sale=False,
                        size=size,
                        store_chain='Aldi',
                        store_name='Aldi',
                    ))
                    
                except (IndexError, KeyError, TypeError):
                    continue
            
            # If no results from Nuxt parsing, try legacy method
            if not results:
                return self._parse_aldi_legacy(html, query)
            
        except Exception as e:
            print(f"Error parsing Aldi Nuxt data: {e}")
            return self._parse_aldi_legacy(html, query)
        
        # Filter results to only include products that match the query
        validated_results = [r for r in results if _product_matches_query(r.product_name, query)]
        return validated_results[:5]
    
    def _parse_aldi_legacy(self, html: str, query: str) -> list[ScrapedPrice]:
        """Legacy parser for Aldi - fallback if Nuxt parsing fails."""
        results = []
        
        try:
            # Find product tiles with title attribute
            tile_pattern = re.compile(
                r'class="product-tile"[^>]*title="([^"]+)"',
                re.IGNORECASE
            )
            product_names = tile_pattern.findall(html)
            
            # Find displayed prices in format >$X.XX<
            price_pattern = re.compile(r'>\$(\d+\.\d{2})<')
            prices = price_pattern.findall(html)
            
            # Match products with prices (they appear in order)
            for i, name in enumerate(product_names[:10]):
                if i < len(prices):
                    try:
                        price = float(prices[i])
                        
                        # Skip unreasonable prices
                        if price > 100 or price < 0.10:
                            continue
                        
                        # Extract size from name if present
                        size = None
                        if ',' in name:
                            parts = name.rsplit(',', 1)
                            if len(parts) == 2:
                                size = parts[1].strip()
                        
                        results.append(ScrapedPrice(
                            product_name=name,
                            price=price,
                            original_price=None,
                            is_on_sale=False,
                            size=size,
                            store_chain='Aldi',
                            store_name='Aldi',
                        ))
                    except ValueError:
                        continue
            
        except Exception as e:
            print(f"Error parsing Aldi legacy data: {e}")
        
        # Filter results to only include products that match the query
        validated_results = [r for r in results if _product_matches_query(r.product_name, query)]
        return validated_results[:5]
    
    # ================================================================
    # MAIN CRAWL METHOD
    # ================================================================
    async def crawl_all_stores(self, query: str, zip_code: str | None = None) -> list[ScrapedPrice]:
        """Crawl all supported stores for a product.
        
        Args:
            query: Product search term
            zip_code: Optional ZIP code for location-based pricing (used by Kroger/Ralphs)
        """
        tasks = []
        if self.ENABLE_SCRAPERS.get('walmart', True):
            tasks.append(self.crawl_walmart(query))
        if self.ENABLE_SCRAPERS.get('target', True):
            tasks.append(self.crawl_target(query))
        if self.ENABLE_SCRAPERS.get('kroger', True):
            tasks.append(self.crawl_kroger(query, zip_code=zip_code))
        if self.ENABLE_SCRAPERS.get('costco', False):
            tasks.append(self.crawl_costco(query))
        if self.ENABLE_SCRAPERS.get('aldi', True):
            tasks.append(self.crawl_aldi(query))
        
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        all_prices = []
        for result in results:
            if isinstance(result, list):
                all_prices.extend(result)
            elif isinstance(result, Exception):
                print(f"Crawl error: {result}")
        
        # Sort by price
        all_prices.sort(key=lambda x: x.price)
        
        return all_prices


class PriceStorageService:
    """Service for storing and retrieving prices from the database."""
    _db_unavailable_warned = False
    
    async def store_prices(self, prices: list[ScrapedPrice]) -> int:
        """Store scraped prices in the database. Returns count of prices stored."""
        stored = 0

        # Check DB connectivity first to avoid repeated connection refused logs
        from app.db.database import check_async_connection

        if not await check_async_connection():
            if not self._db_unavailable_warned:
                print("Database unavailable; skipping price storage (check DATABASE_URL)")
                self._db_unavailable_warned = True
            return 0

        async with async_session_maker() as session:
            for scraped in prices:
                try:
                    # Find or create product
                    product = await self._get_or_create_product(
                        session, 
                        scraped.product_name,
                        scraped.size,
                        scraped.upc
                    )
                    
                    # Find or create store
                    store = await self._get_or_create_store(
                        session,
                        scraped.store_chain,
                        scraped.store_name
                    )
                    
                    # Create price record
                    price = Price(
                        product_id=product.id,
                        store_id=store.id,
                        price=scraped.original_price or scraped.price,
                        sale_price=scraped.price if scraped.is_on_sale else None,
                        effective_date=date.today(),
                        expiration_date=date.today() + timedelta(days=7) if scraped.is_on_sale else None,
                    )
                    
                    session.add(price)
                    stored += 1
                    
                except Exception as e:
                    print(f"Error storing price: {e}")
                    continue
            
            await session.commit()
        
        return stored
    
    async def _get_or_create_product(
        self, 
        session: AsyncSession, 
        name: str, 
        size: Optional[str],
        upc: Optional[str]
    ) -> Product:
        """Get existing product or create new one."""
        # Try to find by UPC first
        if upc:
            result = await session.execute(
                select(Product).where(Product.upc == upc)
            )
            product = result.scalar_one_or_none()
            if product:
                return product
        
        # Try to find by name
        result = await session.execute(
            select(Product).where(Product.name == name)
        )
        product = result.scalar_one_or_none()
        if product:
            return product
        
        # Create new product
        unit_size = None
        unit_type = None
        if size:
            # Parse size like "16 oz" or "1 lb"
            match = re.match(r'(\d+\.?\d*)\s*(\w+)', size)
            if match:
                unit_size = float(match.group(1))
                unit_type = match.group(2)
        
        product = Product(
            name=name,
            unit_size=unit_size,
            unit_type=unit_type,
            upc=upc,
        )
        session.add(product)
        await session.flush()
        
        return product
    
    async def _get_or_create_store(
        self,
        session: AsyncSession,
        chain: str,
        name: str,
        zip_code: str = "00000"  # Default for web-scraped prices without location
    ) -> Store:
        """Get existing store or create new one."""
        result = await session.execute(
            select(Store).where(Store.chain == chain, Store.name == name)
        )
        store = result.scalar_one_or_none()
        if store:
            return store
        
        store = Store(
            name=name,
            chain=chain,
            zip_code=zip_code,
        )
        session.add(store)
        await session.flush()
        
        return store
    
    async def get_prices_for_product(
        self, 
        product_name: str,
        max_age_days: int = 7
    ) -> list[dict]:
        """Get recent prices for a product from all stores."""
        async with async_session_maker() as session:
            cutoff = date.today() - timedelta(days=max_age_days)
            
            result = await session.execute(
                select(Price, Product, Store)
                .join(Product, Price.product_id == Product.id)
                .join(Store, Price.store_id == Store.id)
                .where(
                    Product.name.ilike(f'%{product_name}%'),
                    Price.effective_date >= cutoff
                )
                .order_by(Price.price)
            )
            
            prices = []
            for price, product, store in result:
                prices.append({
                    'product_name': product.name,
                    'price': price.current_price,
                    'original_price': price.price,
                    'is_on_sale': price.sale_price is not None,
                    'store_chain': store.chain,
                    'store_name': store.name,
                    'size': f"{product.unit_size} {product.unit_type}" if product.unit_size else None,
                    'updated_at': price.updated_at.isoformat(),
                })
            
            return prices
