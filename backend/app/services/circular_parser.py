"""Circular (weekly ad) parser service.

Integrates with Flipp API to get real weekly ad deals from major retailers.
Flipp aggregates circulars from most grocery stores, making this a reliable
source of sale prices.
"""

import re
import httpx
import asyncio
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from typing import Any, Optional


@dataclass
class ParsedCircularItem:
    """Represents a parsed item from a weekly ad circular."""

    product_name: str
    sale_price: float
    regular_price: Optional[float] = None
    unit_price: Optional[float] = None
    unit: Optional[str] = None
    quantity_required: Optional[int] = None
    valid_from: Optional[date] = None
    valid_until: Optional[date] = None
    store_chain: Optional[str] = None
    category: Optional[str] = None
    image_url: Optional[str] = None
    is_bogo: bool = False
    requires_loyalty_card: bool = False


class FlippAPIClient:
    """
    Client for the Flipp API / website.
    
    Flipp (flipp.com) aggregates weekly circulars from most major retailers.
    This is a more reliable data source than scraping individual store sites
    because stores actively provide their circular data to Flipp.
    
    IMPORTANT: For production use, get API credentials from Flipp:
    - Business API: https://flipp.com/business
    - Or use Shopular/Flipp mobile APIs (reverse-engineered endpoints)
    
    Current implementation uses public endpoints which may have rate limits.
    """
    
    # Multiple endpoint options for redundancy
    BASE_URL = "https://backflipp.wishabi.com/flipp"
    WEB_URL = "https://flipp.com"
    MOBILE_API = "https://api.flipp.com/api/v4"  # Mobile app endpoint
    
    def __init__(self, api_key: Optional[str] = None, publisher_id: Optional[str] = None):
        self.api_key = api_key
        self.publisher_id = publisher_id
        
        headers = {
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            "Accept": "application/json",
        }
        
        # Add authentication if provided
        if api_key:
            headers["X-Flipp-Api-Key"] = api_key
        if publisher_id:
            headers["X-Flipp-Publisher-Id"] = publisher_id
            
        self.client = httpx.AsyncClient(
            timeout=15.0,
            headers=headers
        )
    
    async def search_deals(
        self, 
        query: str, 
        postal_code: str = "92117",
    ) -> list[dict]:
        """
        Search for deals across all store circulars.
        
        Uses multiple endpoints with fallback strategy:
        1. Try official API (if authenticated)
        2. Try mobile API endpoint
        3. Try web scraping as last resort
        
        Args:
            query: Product to search for (e.g., "milk", "chicken")
            postal_code: User's zip code for local deals
            
        Returns:
            List of deal dictionaries from Flipp
        """
        # Try multiple endpoints in order
        endpoints = [
            (f"{self.MOBILE_API}/flyers/items/search", "mobile"),
            (f"{self.BASE_URL}/items/search", "api"),
        ]
        
        for url, source in endpoints:
            try:
                params = {
                    "q": query,
                    "postal_code": postal_code,
                    "locale": "en-us",
                }
                
                response = await self.client.get(url, params=params)
                
                if response.status_code == 200:
                    data = response.json()
                    items = data.get("items", []) or data.get("flyer_items", [])
                    if items:
                        print(f"Flipp: Got {len(items)} deals from {source} endpoint")
                        return items
                        
            except Exception as e:
                print(f"Flipp {source} endpoint error: {e}")
                continue
        
        # Final fallback to web search
        print("Flipp: Falling back to web scraping")
        return await self._search_web(query, postal_code)
    
    async def _search_web(self, query: str, postal_code: str) -> list[dict]:
        """Fallback web search if API is unavailable."""
        try:
            url = f"{self.WEB_URL}/flyers"
            params = {
                "q": query,
                "postal_code": postal_code,
            }
            
            response = await self.client.get(url, params=params)
            
            if response.status_code != 200:
                return []
            
            # Try to extract embedded JSON data
            import json
            
            # Look for __NEXT_DATA__ or similar embedded data
            text = response.text
            
            # Pattern to find JSON data in script tags
            import re
            json_match = re.search(r'__NEXT_DATA__.*?({.*?})\s*</script>', text, re.DOTALL)
            if json_match:
                try:
                    data = json.loads(json_match.group(1))
                    # Navigate to items in Next.js data structure
                    items = data.get("props", {}).get("pageProps", {}).get("items", [])
                    return items
                except:
                    pass
            
            return []
            
        except Exception as e:
            print(f"Flipp web search error: {e}")
            return []
    
    async def get_store_flyers(self, postal_code: str, store_chain: str) -> list[dict]:
        """Get all current flyer items for a specific store."""
        try:
            url = f"{self.BASE_URL}/flyers"
            params = {
                "postal_code": postal_code,
                "locale": "en-us",
            }
            
            response = await self.client.get(url, params=params)
            
            if response.status_code != 200:
                return []
            
            data = response.json()
            
            # Filter for the specific store chain
            store_lower = store_chain.lower()
            matching_flyers = [
                f for f in data.get("flyers", [])
                if store_lower in f.get("merchant", "").lower()
            ]
            
            # Get items from matching flyers
            all_items = []
            for flyer in matching_flyers:
                flyer_id = flyer.get("id")
                if flyer_id:
                    items = await self._get_flyer_items(flyer_id)
                    all_items.extend(items)
            
            return all_items
            
        except Exception as e:
            print(f"Flipp flyer error: {e}")
            return []
    
    async def _get_flyer_items(self, flyer_id: str) -> list[dict]:
        """Get all items from a specific flyer."""
        try:
            url = f"{self.BASE_URL}/flyers/{flyer_id}/items"
            response = await self.client.get(url)
            
            if response.status_code == 200:
                data = response.json()
                return data.get("items", [])
            
            return []
            
        except Exception as e:
            print(f"Flipp flyer items error: {e}")
            return []
    
    async def close(self):
        """Close the HTTP client."""
        await self.client.aclose()


class CircularParser:
    """Service for parsing weekly ad circulars from various sources.
    
    Now integrated with Flipp API for real circular data.
    """

    # Patterns for extracting price information
    PRICE_PATTERNS = [
        # "$X.XX" format
        r"\$(\d+\.?\d*)",
        # "X for $Y" format
        r"(\d+)\s+for\s+\$(\d+\.?\d*)",
        # "$X.XX/lb" format
        r"\$(\d+\.?\d*)\s*/\s*(lb|oz|ea|each)",
        # "Buy X Get Y Free" format
        r"buy\s+(\d+)\s+get\s+(\d+)\s+free",
    ]

    # Unit abbreviation mappings
    UNIT_MAP = {
        "lb": "lb",
        "lbs": "lb",
        "pound": "lb",
        "pounds": "lb",
        "oz": "oz",
        "ounce": "oz",
        "ounces": "oz",
        "ea": "each",
        "each": "each",
        "ct": "count",
        "count": "count",
    }

    def __init__(self, store_chain: Optional[str] = None):
        """Initialize the circular parser.

        Args:
            store_chain: Optional store chain name to associate with parsed items
        """
        from app.config import get_settings
        
        settings = get_settings()
        self.store_chain = store_chain
        
        # Initialize Flipp client with credentials from config
        self.flipp_client = FlippAPIClient(
            api_key=settings.flipp_api_key,
            publisher_id=settings.flipp_publisher_id,
        )
        # Track a small sample of items missing store names to help debugging
        self._missing_store_seen = set()

    def parse_flipp_item(self, item: dict) -> Optional[ParsedCircularItem]:
        """Parse a single Flipp API item into a ParsedCircularItem.
        
        Args:
            item: Raw item dictionary from Flipp API
            
        Returns:
            Parsed circular item or None if parsing fails
        """
        try:
            # Extract price from price_text or sale_price
            price_text = item.get("price_text", "") or item.get("sale_price_text", "") or ""
            price = self._extract_price(price_text)
            
            if price is None:
                # Try direct price field
                price = item.get("current_price") or item.get("price")
            
            if price is None:
                return None
            
            # Extract unit from price text
            unit = self._extract_unit(price_text)
            
            # Parse regular price if available
            regular_price = None
            pre_price = item.get("pre_price_text", "") or item.get("was_price", "")
            if pre_price:
                regular_price = self._extract_price(pre_price)
            
            # Parse dates
            valid_from = None
            valid_until = None
            if item.get("valid_from"):
                try:
                    valid_from = datetime.fromisoformat(item["valid_from"].replace("Z", "+00:00")).date()
                except:
                    pass
            if item.get("valid_to"):
                try:
                    valid_until = datetime.fromisoformat(item["valid_to"].replace("Z", "+00:00")).date()
                except:
                    pass
            
            # Check for BOGO deals
            is_bogo = False
            lower_text = price_text.lower()
            if "buy" in lower_text and "get" in lower_text:
                is_bogo = True
            if "bogo" in lower_text or "b1g1" in lower_text:
                is_bogo = True
            
            store_name = self._extract_store_name(item)

            # If store name is missing or falls back to Local Deals, log one sample
            if not store_name or store_name.strip().lower() in ("local deals", "unknown", ""):
                # fingerprint some identifying fields to avoid spammy repeats
                fingerprint = f"{item.get('name')}-{item.get('merchant')}-{item.get('retailer')}-{item.get('store_name')}"
                if fingerprint not in self._missing_store_seen:
                    self._missing_store_seen.add(fingerprint)
                    try:
                        import json
                        preview = {k: item.get(k) for k in ('name', 'merchant', 'store_name', 'retailer', 'price_text')}
                        print(f"Flipp item missing store name sample: {json.dumps(preview)}")
                    except Exception:
                        print("Flipp item missing store name (details unavailable)")

            return ParsedCircularItem(
                product_name=item.get("name", item.get("title", "Unknown")),
                sale_price=price,
                regular_price=regular_price,
                unit=unit,
                valid_from=valid_from,
                valid_until=valid_until,
                # Prefer real merchant/retailer; only fall back to Local Deals if missing
                store_chain=store_name or "Local Deals",
                category=item.get("category"),
                image_url=item.get("image_url") or item.get("cutout_image_url"),
                is_bogo=is_bogo,
                requires_loyalty_card=item.get("requires_card", False),
            )
            
        except Exception as e:
            print(f"Error parsing Flipp item: {e}")
            return None

    def _extract_store_name(self, item: dict) -> Optional[str]:
        """Best-effort extraction of a store name from Flipp data."""
        candidate_fields = [
            item.get("merchant"),
            item.get("merchant_name"),
            item.get("merchant_short_name"),
            item.get("store_name"),
            item.get("store"),
            item.get("retailer"),
            item.get("retailer_name"),
            item.get("branding"),
            item.get("brand"),
            item.get("flyer", {}).get("merchant"),
            item.get("flyer", {}).get("merchant_name"),
            item.get("flyer_item", {}).get("merchant"),
            item.get("flyer_item", {}).get("merchant_name"),
            self.store_chain,
        ]

        for name in candidate_fields:
            if isinstance(name, str) and name.strip():
                return name.strip()
        return None
    
    def _extract_price(self, text: str) -> Optional[float]:
        """Extract numeric price from text."""
        if not text:
            return None
        
        # Handle "2/$5" or "3 for $5" format
        multi_match = re.search(r'(\d+)\s*(?:for|/)\s*\$(\d+\.?\d*)', text, re.IGNORECASE)
        if multi_match:
            count = int(multi_match.group(1))
            total = float(multi_match.group(2))
            return round(total / count, 2)
        
        # Handle standard "$X.XX" format
        price_match = re.search(r'\$(\d+\.?\d*)', text)
        if price_match:
            return float(price_match.group(1))
        
        # Handle "X.XX" without dollar sign
        num_match = re.search(r'(\d+\.\d{2})', text)
        if num_match:
            return float(num_match.group(1))
        
        return None
    
    def _extract_unit(self, text: str) -> Optional[str]:
        """Extract unit from price text."""
        if not text:
            return None
        
        text_lower = text.lower()
        
        if '/lb' in text_lower or 'per lb' in text_lower or 'per pound' in text_lower:
            return 'lb'
        if '/oz' in text_lower or 'per oz' in text_lower:
            return 'oz'
        if '/ea' in text_lower or 'each' in text_lower:
            return 'each'
        if '/gal' in text_lower or 'gallon' in text_lower:
            return 'gallon'
        
        return None

    def parse_flipp_data(self, items: list[dict], query: str = "") -> list[ParsedCircularItem]:
        """Parse circular data from Flipp API format.

        Args:
            items: List of raw items from Flipp API
            query: Original search query for filtering mismatched results

        Returns:
            List of parsed circular items
        """
        parsed = []
        for item in items:
            parsed_item = self.parse_flipp_item(item)
            if parsed_item:
                # If query is provided, validate the product matches
                if query and not self._product_matches_query(parsed_item.product_name, query):
                    continue
                parsed.append(parsed_item)
        return parsed
    
    def _product_matches_query(self, product_name: str, query: str, min_score: float = 0.6) -> bool:
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
        
        # Split into words
        product_words = set(re.split(r'\s+', product_lower))
        query_words = set(re.split(r'\s+', query_lower))
        
        # Remove common filler words
        filler = {'the', 'a', 'an', 'of', 'and', 'or', '-', '&'}
        product_words -= filler
        query_words -= filler
        
        if not query_words or not product_words:
            return True  # Can't validate, allow it
        
        # Check for exact phrase match
        if query_lower in product_lower:
            return True
        
        # Core product words that MUST match if they're in the query
        # These are the main nouns that define what the product IS
        core_product_words = {
            'flour', 'sugar', 'salt', 'butter', 'milk', 'eggs', 'bread', 'rice',
            'pasta', 'chicken', 'beef', 'pork', 'fish', 'salmon', 'shrimp',
            'cheese', 'yogurt', 'cream', 'oil', 'vinegar', 'sauce', 'soup',
            'cereal', 'oatmeal', 'coffee', 'tea', 'juice', 'soda', 'water',
            'apple', 'orange', 'banana', 'grape', 'lemon', 'lime', 'tomato',
            'potato', 'onion', 'garlic', 'carrot', 'celery', 'lettuce', 'spinach',
            'beans', 'corn', 'peas', 'broccoli', 'pepper', 'cucumber',
            'chips', 'crackers', 'cookies', 'candy', 'chocolate',
            'detergent', 'soap', 'shampoo', 'toothpaste', 'paper', 'towels',
        }
        
        # Check if any core word from query is missing from product
        for word in query_words:
            if word in core_product_words and word not in product_words:
                # Check for plural/singular variants
                singular = word.rstrip('s')
                plural = word + 's' if not word.endswith('s') else word
                if singular not in product_words and plural not in product_words:
                    return False
        
        # Check how many query words appear in the product
        matched_words = query_words & product_words
        
        # Calculate match score
        # For multi-word queries, we need most words to match
        score = len(matched_words) / len(query_words)
        
        # Special handling for specific/varietal products
        # If query has a specific modifier (like "envy" in "envy apple"),
        # that modifier should appear in the result
        specific_modifiers = {
            # Apple varieties
            'envy', 'honeycrisp', 'gala', 'fuji', 'granny', 'pink', 'braeburn',
            'jazz', 'cosmic', 'opal', 'ambrosia', 'mcintosh', 'golden',
            'red', 'jonagold', 'cortland', 'empire',
            # Other produce varieties
            'organic', 'heirloom', 'roma', 'beefsteak', 'cherry', 'grape',
            'russet', 'yukon', 'sweet', 'baby', 'mini',
            # Brands that matter
            'kirkland', 'great', 'market', 'good',
        }
        
        # Check if query contains a specific modifier
        for modifier in specific_modifiers:
            if modifier in query_lower:
                # This modifier MUST appear in the product name
                if modifier not in product_lower:
                    return False
        
        return score >= min_score

    def parse_html_circular(self, html_content: str) -> list[ParsedCircularItem]:
        """Parse circular data from HTML content.

        Args:
            html_content: Raw HTML content from a store's weekly ad page

        Returns:
            List of parsed circular items

        Note:
            This is a stub. Implement with BeautifulSoup for specific store formats.
        """
        # TODO: Implement HTML parsing for store-specific formats
        # Each store has different HTML structure
        # Will need per-store parsing logic
        return []

    def parse_pdf_circular(self, pdf_path: str) -> list[ParsedCircularItem]:
        """Parse circular data from a PDF file.

        Args:
            pdf_path: Path to the PDF file

        Returns:
            List of parsed circular items

        Note:
            This is a stub. Implement with pdfplumber or PyPDF2.
        """
        # TODO: Implement PDF parsing
        # PDFs are challenging due to layout extraction
        # Consider using OCR for image-based PDFs
        return []

    def extract_price_info(self, text: str) -> dict[str, Any]:
        """Extract price information from a text string.

        Args:
            text: Text containing price information

        Returns:
            Dictionary with extracted price details
        """
        result: dict[str, Any] = {
            "price": None,
            "unit": None,
            "quantity": None,
            "is_bogo": False,
        }

        text_lower = text.lower()

        # Check for simple price
        simple_price_match = re.search(r"\$(\d+\.?\d*)", text)
        if simple_price_match:
            result["price"] = float(simple_price_match.group(1))

        # Check for "X for $Y" format
        multi_price_match = re.search(r"(\d+)\s+for\s+\$(\d+\.?\d*)", text_lower)
        if multi_price_match:
            quantity = int(multi_price_match.group(1))
            total_price = float(multi_price_match.group(2))
            result["price"] = total_price / quantity
            result["quantity"] = quantity

        # Check for unit price
        unit_price_match = re.search(r"\$(\d+\.?\d*)\s*/\s*(\w+)", text_lower)
        if unit_price_match:
            result["price"] = float(unit_price_match.group(1))
            unit = unit_price_match.group(2)
            result["unit"] = self.UNIT_MAP.get(unit, unit)

        # Check for BOGO
        if "buy" in text_lower and "get" in text_lower and "free" in text_lower:
            result["is_bogo"] = True
            bogo_match = re.search(r"buy\s+(\d+)\s+get\s+(\d+)", text_lower)
            if bogo_match:
                buy = int(bogo_match.group(1))
                get = int(bogo_match.group(2))
                result["quantity"] = buy + get

        return result

    def normalize_product_name(self, name: str) -> str:
        """Normalize a product name from circular data.

        Args:
            name: Raw product name from circular

        Returns:
            Normalized product name
        """
        # Remove common circular-specific text
        noise_patterns = [
            r"save\s+\$?\d+\.?\d*",
            r"limit\s+\d+",
            r"with\s+card",
            r"must\s+buy\s+\d+",
            r"selected\s+varieties",
            r"while\s+supplies\s+last",
        ]

        normalized = name
        for pattern in noise_patterns:
            normalized = re.sub(pattern, "", normalized, flags=re.IGNORECASE)

        # Clean up whitespace
        normalized = re.sub(r"\s+", " ", normalized).strip()

        return normalized

    def get_current_week_dates(self) -> tuple[date, date]:
        """Get the date range for the current week's circulars.

        Returns:
            Tuple of (start_date, end_date) for current week
        """
        today = date.today()

        # Most circulars run Wednesday to Tuesday or Sunday to Saturday
        # Assuming Sunday to Saturday
        days_since_sunday = today.weekday() + 1
        if days_since_sunday == 7:
            days_since_sunday = 0

        start_date = today - timedelta(days=days_since_sunday)
        end_date = start_date + timedelta(days=6)

        return start_date, end_date

    async def fetch_and_parse(self, store_chain: str, zip_code: str) -> list[ParsedCircularItem]:
        """Fetch and parse circular data for a store chain and location.

        Args:
            store_chain: Name of the store chain
            zip_code: ZIP code for local pricing

        Returns:
            List of parsed circular items
        """
        try:
            # Use Flipp API to get real circular data
            items = await self.flipp_client.get_store_flyers(zip_code, store_chain)
            
            if items:
                return self.parse_flipp_data(items)
            
            # Fallback to mock data if API fails
            print(f"No Flipp data for {store_chain}, using mock data")
            return self._get_mock_circular_data(store_chain, zip_code)
            
        except Exception as e:
            print(f"Error fetching circular for {store_chain}: {e}")
            return self._get_mock_circular_data(store_chain, zip_code)
    
    async def search_deals(self, query: str, zip_code: str, use_ai_scraper: bool = False) -> list[ParsedCircularItem]:
        """Search for deals across all stores.
        
        Uses multiple data sources:
        1. Flipp API - Weekly circulars from major retailers
        2. Open Prices API - Crowdsourced real prices with store names
        3. AI Vision Scraper - Real-time prices from store websites (optional)
        4. Estimated everyday prices for major US retailers
        
        Args:
            query: Product to search for
            zip_code: User's zip code
            use_ai_scraper: Whether to use AI vision scraping (slower but more accurate)
            
        Returns:
            List of matching deals, sorted by price
        """
        all_deals = []
        stores_with_deals = set()
        
        # Source 1: Flipp weekly circulars (sales/deals)
        try:
            items = await self.flipp_client.search_deals(query, zip_code)
            flipp_deals = self.parse_flipp_data(items, query)  # Pass query for filtering
            all_deals.extend(flipp_deals)
            # Track which stores have real deals
            for deal in flipp_deals:
                if deal.store_chain:
                    stores_with_deals.add(deal.store_chain.lower())
            print(f"Flipp: Found {len(flipp_deals)} deals for '{query}'")
        except Exception as e:
            print(f"Flipp search error for {query}: {e}")
        
        # Source 2: Open Prices API (crowdsourced real prices)
        try:
            from app.services.public_price_apis import OpenPricesAPI
            open_prices_api = OpenPricesAPI()
            
            # Open Prices doesn't have text search, but we can get recent prices
            # In a production system, you'd match product barcodes
            recent_prices = await open_prices_api.get_recent_prices(limit=50)
            
            # Filter for relevant products (simple keyword match)
            query_lower = query.lower()
            for price in recent_prices:
                if price.product_name and query_lower in price.product_name.lower():
                    store_name = price.location_name or "Community Price"
                    all_deals.append(ParsedCircularItem(
                        product_name=price.product_name,
                        sale_price=price.price,
                        regular_price=None,
                        store_chain=store_name,
                        valid_from=price.date.date() if price.date else None,
                        valid_until=None,
                        is_bogo=False,
                    ))
                    stores_with_deals.add(store_name.lower())
            
            await open_prices_api.close()
            print(f"Open Prices: Added {len([d for d in all_deals if d.store_chain and 'Community' not in d.store_chain])} community prices")
        except Exception as e:
            print(f"Open Prices API error: {e}")
        
        # Source 3: AI Vision Scraper (real-time prices from store websites)
        if use_ai_scraper:
            try:
                from app.services.ai_price_scraper import AIPriceScraper
                from app.config import get_settings
                
                settings = get_settings()
                if settings.ai_scraper_enabled:
                    scraper = AIPriceScraper()
                    await scraper.initialize()
                    
                    try:
                        # Get region-appropriate stores to scrape
                        stores_to_scrape = self._get_ai_scrape_stores(zip_code, stores_with_deals)
                        
                        for store in stores_to_scrape[:settings.ai_scraper_max_stores_per_query]:
                            ai_prices = await scraper.scrape_store_prices(store, query, zip_code)
                            for p in ai_prices:
                                all_deals.append(ParsedCircularItem(
                                    product_name=p.product_name,
                                    sale_price=p.price,
                                    regular_price=p.original_price,
                                    unit=p.unit or p.size,
                                    store_chain=p.store_chain,
                                    valid_from=date.today(),
                                    valid_until=None,
                                    is_bogo=False,
                                ))
                                stores_with_deals.add(p.store_chain.lower())
                        
                        print(f"AI Scraper: Added prices from {len(stores_to_scrape)} stores")
                    finally:
                        await scraper.close()
            except Exception as e:
                print(f"AI Scraper error: {e}")
        
        # Source 4: Price Crawler (direct scraping from Walmart, Target, Aldi, etc.)
        # This provides real scraped prices from store websites
        try:
            from app.services.price_crawler import PriceCrawler
            crawler = PriceCrawler()
            scraped_prices = await crawler.crawl_all_stores(query, zip_code=zip_code)
            
            scraped_count = 0
            for p in scraped_prices:
                # Skip if we already have a deal from this store
                store_key = p.store_chain.lower() if p.store_chain else ''
                if store_key in stores_with_deals:
                    continue
                
                all_deals.append(ParsedCircularItem(
                    product_name=p.product_name,
                    sale_price=p.price,
                    regular_price=p.original_price,
                    unit=p.size,
                    store_chain=p.store_chain,
                    valid_from=date.today(),
                    valid_until=None,
                    is_bogo=False,
                ))
                stores_with_deals.add(store_key)
                scraped_count += 1
            
            if scraped_count:
                print(f"Price Crawler: Added {scraped_count} scraped prices")
        except Exception as e:
            print(f"Price Crawler error: {e}")
        
        # Source 5: Estimated everyday prices for major US retailers
        # This fills gaps for stores without current deals/circulars
        # Now passes zip_code for regional filtering
        estimated_prices = self._get_estimated_prices(query, stores_with_deals, zip_code)
        if estimated_prices:
            all_deals.extend(estimated_prices)
            print(f"Estimated: Added {len(estimated_prices)} everyday prices")
        
        # Sort by price (lowest first)
        all_deals.sort(key=lambda d: d.sale_price)
        
        return all_deals
    
    def _get_ai_scrape_stores(self, zip_code: str, already_have: set[str]) -> list[str]:
        """Get stores to AI-scrape based on region, excluding stores we already have.
        
        NOTE: Kroger brands (Kroger, Ralphs, Fred Meyer, Fry's, etc.) are excluded
        because we have free access to the Kroger API for real prices.
        """
        # Priority stores for AI scraping (excludes Kroger brands)
        PRIORITY_STORES = {
            "national": ["walmart", "target", "costco", "aldi"],
            "socal": ["vons", "albertsons", "sprouts"],
            "norcal": ["safeway", "sprouts"],
            "texas": ["heb"],
            "southeast": ["publix"],
            "northeast": ["wegmans"],
            "midwest": ["meijer"],
            "pacific_nw": ["safeway", "winco"],
        }
        
        # Kroger brands to exclude (use Kroger API instead)
        KROGER_BRANDS = {
            "kroger", "ralphs", "fred meyer", "frys", "king soopers",
            "smiths", "qfc", "food 4 less", "dillons", "city market",
            "harris teeter", "mariano's", "pick n save",
        }
        
        # Get region from zip
        try:
            prefix = int(zip_code[:3])
        except (ValueError, IndexError):
            prefix = 0
        
        region = "national"
        if 900 <= prefix <= 928:
            region = "socal"
        elif 929 <= prefix <= 961:
            region = "norcal"
        elif 750 <= prefix <= 799:
            region = "texas"
        elif 300 <= prefix <= 399:
            region = "southeast"
        elif 10 <= prefix <= 196:
            region = "northeast"
        elif 400 <= prefix <= 699:
            region = "midwest"
        elif 970 <= prefix <= 994:
            region = "pacific_nw"
        
        # Get stores for this region
        stores = PRIORITY_STORES.get("national", []).copy()
        if region in PRIORITY_STORES:
            stores.extend(PRIORITY_STORES[region])
        
        # Filter out stores we already have data for AND Kroger brands
        return [s for s in stores if s.lower() not in already_have and s.lower() not in KROGER_BRANDS]
    
    async def close(self):
        """Clean up resources."""
        await self.flipp_client.close()
    
    def _get_estimated_prices(
        self, query: str, stores_with_deals: set[str], zip_code: str = ""
    ) -> list[ParsedCircularItem]:
        """Get estimated everyday prices for major US retailers.
        
        This fills gaps when stores don't have active deals/circulars.
        Prices are based on typical US grocery prices and updated periodically.
        Stores are filtered by regional availability based on zip code.
        
        Args:
            query: Product search term
            stores_with_deals: Set of store names (lowercase) that already have deals
            zip_code: User's zip code for regional filtering
            
        Returns:
            List of estimated prices for stores without deals
        """
        # Regional store availability by state/region
        # Only show stores that actually operate in the user's area
        # More granular to account for stores with limited CA presence
        REGIONAL_STORES = {
            # National chains (available almost everywhere)
            "national": {
                "Walmart", "Target", "Costco", "ALDI", "Sam's Club",
                "Whole Foods", "Trader Joe's", "CVS Pharmacy", "Walgreens",
            },
            # Southeast (FL, GA, SC, NC, AL, TN, etc.)
            "southeast": {
                "Publix", "Food Lion", "Harris Teeter", "Winn-Dixie",
                "Piggly Wiggly", "BI-LO",
            },
            # Northeast (NY, NJ, PA, CT, MA, etc.)
            "northeast": {
                "Stop & Shop", "ShopRite", "Wegmans", "Giant", "Acme",
                "Price Chopper", "Market Basket", "Big Y",
            },
            # Midwest (OH, MI, IN, IL, WI, MN, etc.)
            "midwest": {
                "Meijer", "Kroger", "Giant Eagle", "Jewel-Osco",
                "Hy-Vee", "Festival Foods", "Woodman's",
            },
            # Texas
            "texas": {
                "H-E-B", "Kroger", "Fiesta Mart", "Brookshire's",
            },
            # Southern California (San Diego, LA, Orange County - 900-928)
            "socal": {
                "Vons", "Ralphs", "Albertsons", "Food 4 Less",
                "Smart & Final", "Stater Bros.", "Sprouts", "Grocery Outlet",
                "Gelson's", "Bristol Farms", "Northgate Market",
            },
            # Northern California (SF Bay Area, Sacramento - 930-961)
            "norcal": {
                "Safeway", "Raley's", "Lucky", "Grocery Outlet",
                "WinCo", "FoodMaxx", "Sprouts", "Smart & Final",
            },
            # Pacific Northwest (OR, WA - 970-994)
            "pacific_nw": {
                "Safeway", "Albertsons", "Fred Meyer", "WinCo",
                "Grocery Outlet", "QFC", "Haggen",
            },
            # Arizona (850-865)
            "arizona": {
                "Fry's", "Safeway", "Albertsons", "Sprouts", "WinCo",
                "Food City", "Bashas'",
            },
            # Nevada (889-898)
            "nevada": {
                "Smith's", "Albertsons", "WinCo", "Raley's",
            },
        }
        
        # ZIP code prefix to region mapping
        def get_region_from_zip(zip_code: str) -> str:
            try:
                prefix = int(zip_code[:3])
            except (ValueError, IndexError):
                return "national"
            
            # Northeast
            if 1 <= prefix <= 9 or 10 <= prefix <= 149 or 150 <= prefix <= 196:
                return "northeast"
            # Mid-Atlantic / Southeast
            if 200 <= prefix <= 299 or 300 <= prefix <= 399:
                return "southeast"
            # Midwest
            if 400 <= prefix <= 499 or 500 <= prefix <= 599 or 600 <= prefix <= 699:
                return "midwest"
            # Texas
            if 750 <= prefix <= 799 or 730 <= prefix <= 749:
                return "texas"
            # Southern California (San Diego 919-921, LA 900-918, OC 926-928)
            if 900 <= prefix <= 928:
                return "socal"
            # Northern California (929-961)
            if 929 <= prefix <= 961:
                return "norcal"
            # Pacific Northwest (OR 970-979, WA 980-994)
            if 970 <= prefix <= 994:
                return "pacific_nw"
            # Arizona (850-865)
            if 850 <= prefix <= 865:
                return "arizona"
            # Nevada (889-898)
            if 889 <= prefix <= 898:
                return "nevada"
            # Other western states default to national only
            if 800 <= prefix <= 849 or 866 <= prefix <= 888 or 899 <= prefix <= 899:
                return "national"
            return "national"
        
        # Get available stores for this region
        region = get_region_from_zip(zip_code) if zip_code else "national"
        available_stores = REGIONAL_STORES["national"].copy()
        if region in REGIONAL_STORES:
            available_stores.update(REGIONAL_STORES[region])
        
        # Major US grocery chains with typical price points
        # Prices are estimates based on typical US grocery costs
        STORE_PRICE_TIERS = {
            # Value/Discount stores (lowest prices)
            "ALDI": 0.85,
            "WinCo": 0.88,
            "Grocery Outlet": 0.82,
            "Food 4 Less": 0.90,
            "Foods Co": 0.90,  # Kroger family
            "Save-A-Lot": 0.87,
            "Lidl": 0.86,
            "Ruler": 0.88,  # Kroger family discount
            
            # Warehouse clubs (low per-unit, bulk)
            "Costco": 0.92,
            "Sam's Club": 0.93,
            "BJ's Wholesale": 0.94,
            
            # Traditional supermarkets (mid-tier)
            "Walmart": 1.00,  # Baseline
            # Kroger Co. Family of Stores
            "Kroger": 1.02,
            "Ralphs": 1.05,
            "Fry's": 1.02,
            "King Soopers": 1.03,
            "Smith's Food and Drug": 1.03,
            "Fred Meyer": 1.04,
            "QFC": 1.08,
            "Dillons": 1.02,
            "Baker's": 1.02,
            "City Market": 1.03,
            "Gerbes": 1.02,
            "Jay C Food Store": 1.02,
            "Mariano's": 1.10,
            "Metro Market": 1.05,
            "Pay-Less Super Markets": 1.02,
            "Pick'n Save": 1.03,
            "Harris Teeter": 1.12,
            # Other chains
            "Safeway": 1.08,
            "Albertsons": 1.07,
            "Publix": 1.10,
            "H-E-B": 0.98,
            "Meijer": 1.01,
            "Giant": 1.06,
            "Stop & Shop": 1.09,
            "Food Lion": 1.03,
            "Vons": 1.08,
            "Smart & Final": 0.96,
            "Stater Bros.": 1.04,
            "ShopRite": 1.04,
            "Wegmans": 1.15,
            
            # Convenience stores (skip Target - use Redsky API/Flipp for real prices)
            "CVS Pharmacy": 1.25,
            "Walgreens": 1.28,
            
            # Premium/organic
            "Whole Foods": 1.35,
            "Sprouts": 1.18,
            "Trader Joe's": 1.05,
            "Natural Grocers": 1.30,
            "Fresh Market": 1.25,
        }
        
        # Base prices for common grocery items (Walmart = baseline)
        BASE_PRICES = {
            # Dairy
            "milk": ("Whole Milk, Gallon", 3.48),
            "eggs": ("Large Eggs, 12 ct", 4.98),
            "butter": ("Salted Butter, 1 lb", 4.47),
            "cheese": ("Shredded Cheddar, 8 oz", 2.98),
            "yogurt": ("Greek Yogurt, 32 oz", 4.98),
            "cream": ("Heavy Cream, 16 oz", 4.28),
            "sour cream": ("Sour Cream, 16 oz", 2.48),
            
            # Bread/Bakery
            "bread": ("White Bread Loaf", 1.48),
            "flour": ("All Purpose Flour, 5 lb", 2.98),
            "sugar": ("Granulated Sugar, 4 lb", 2.98),
            
            # Meat
            "chicken": ("Chicken Breast, boneless", 3.48),
            "beef": ("Ground Beef, 80/20, lb", 4.97),
            "pork": ("Pork Chops, lb", 3.48),
            "bacon": ("Bacon, 16 oz", 5.98),
            "turkey": ("Ground Turkey, lb", 4.48),
            "sausage": ("Breakfast Sausage, 16 oz", 3.98),
            
            # Produce  
            "banana": ("Bananas, lb", 0.57),
            "apple": ("Apples, lb", 1.67),
            "orange": ("Oranges, lb", 1.47),
            "lettuce": ("Romaine Lettuce", 2.48),
            "tomato": ("Tomatoes, lb", 1.98),
            "onion": ("Yellow Onions, lb", 0.98),
            "potato": ("Russet Potatoes, 5 lb", 3.48),
            "carrot": ("Carrots, 2 lb bag", 1.98),
            "celery": ("Celery Bunch", 1.98),
            "broccoli": ("Broccoli Crowns, lb", 1.98),
            "spinach": ("Baby Spinach, 5 oz", 2.98),
            "avocado": ("Avocados, each", 0.98),
            "lemon": ("Lemons, each", 0.50),
            "garlic": ("Garlic, head", 0.50),
            "grape": ("Grapes, lb", 2.48),
            
            # Pantry
            "rice": ("Long Grain Rice, 2 lb", 2.18),
            "pasta": ("Spaghetti, 16 oz", 1.28),
            "cereal": ("Cheerios, 18 oz", 4.98),
            "oatmeal": ("Oats, 42 oz", 3.98),
            "peanut butter": ("Creamy Peanut Butter, 16 oz", 2.98),
            "jelly": ("Grape Jelly, 20 oz", 2.28),
            "oil": ("Vegetable Oil, 48 oz", 3.98),
            "olive oil": ("Extra Virgin Olive Oil, 17 oz", 5.98),
            "vinegar": ("White Vinegar, 32 oz", 1.98),
            "salt": ("Table Salt, 26 oz", 0.78),
            "pepper": ("Ground Black Pepper, 4 oz", 3.48),
            "ketchup": ("Ketchup, 32 oz", 2.98),
            "mustard": ("Yellow Mustard, 20 oz", 1.48),
            "mayonnaise": ("Mayonnaise, 30 oz", 3.98),
            "soup": ("Chicken Noodle Soup, can", 1.28),
            "beans": ("Black Beans, can", 0.88),
            "tuna": ("Chunk Light Tuna, can", 1.18),
            "coffee": ("Ground Coffee, 12 oz", 5.98),
            "tea": ("Tea Bags, 100 ct", 3.98),
            
            # Frozen
            "ice cream": ("Vanilla Ice Cream, 48 oz", 4.98),
            "frozen pizza": ("Frozen Pizza", 4.98),
            "frozen vegetables": ("Frozen Mixed Veggies, 12 oz", 1.48),
            
            # Beverages
            "water": ("Spring Water, 24 pk", 3.98),
            "soda": ("Cola, 12 pk", 5.48),
            "juice": ("Orange Juice, 52 oz", 3.48),
        }
        
        # Find matching base product
        query_lower = query.lower().strip()
        base_product = None
        base_price = None
        
        # Check for specific modifiers that indicate we shouldn't use generic estimates
        # These are varieties/brands where a generic price estimate would be misleading
        specific_modifiers = {
            # Apple varieties
            'envy', 'honeycrisp', 'gala', 'fuji', 'granny', 'pink lady', 'braeburn',
            'jazz', 'cosmic', 'opal', 'ambrosia', 'mcintosh', 'golden delicious',
            'red delicious', 'jonagold', 'cortland', 'empire',
            # Other produce varieties  
            'heirloom', 'roma', 'beefsteak', 'grape tomato', 'cherry tomato',
            'yukon gold', 'fingerling', 'purple',
            # Specific brands to skip estimating
            'kirkland', 'organic',
        }
        
        # If query contains a specific modifier, don't generate generic estimates
        for modifier in specific_modifiers:
            if modifier in query_lower:
                return []  # Don't return generic estimates for specific product searches
        
        for keyword, (product_name, price) in BASE_PRICES.items():
            if keyword in query_lower or query_lower in keyword:
                base_product = product_name
                base_price = price
                break
        
        if not base_product:
            # Try partial matches
            for keyword, (product_name, price) in BASE_PRICES.items():
                # Check if any word matches
                query_words = query_lower.split()
                keyword_words = keyword.split()
                if any(qw in keyword_words or kw in query_words 
                       for qw in query_words for kw in keyword_words):
                    base_product = product_name
                    base_price = price
                    break
        
        if not base_product:
            return []  # Unknown product category
        
        # Generate estimated prices for stores without deals
        estimated = []
        today = date.today()
        
        for store_name, price_multiplier in STORE_PRICE_TIERS.items():
            # Skip stores that already have real deals
            if store_name.lower() in stores_with_deals:
                continue
            
            # Skip stores not available in this region
            if store_name not in available_stores:
                continue
            
            # Calculate estimated price
            estimated_price = round(base_price * price_multiplier, 2)
            
            estimated.append(ParsedCircularItem(
                product_name=f"{base_product} (est.)",
                sale_price=estimated_price,
                regular_price=None,
                unit=None,
                valid_from=today,
                valid_until=None,
                store_chain=store_name,
                category=None,
                is_bogo=False,
                image_url=None,
            ))
        
        return estimated

    def _get_mock_circular_data(
        self, store_chain: str, zip_code: str
    ) -> list[ParsedCircularItem]:
        """Return mock circular data for development.

        Args:
            store_chain: Store chain name
            zip_code: ZIP code

        Returns:
            Mock circular items
        """
        start_date, end_date = self.get_current_week_dates()

        mock_items = [
            ParsedCircularItem(
                product_name="Whole Milk Gallon",
                sale_price=2.99,
                regular_price=4.49,
                valid_from=start_date,
                valid_until=end_date,
                store_chain=store_chain,
                category="Dairy",
            ),
            ParsedCircularItem(
                product_name="Large Eggs 12ct",
                sale_price=3.49,
                regular_price=4.99,
                valid_from=start_date,
                valid_until=end_date,
                store_chain=store_chain,
                category="Dairy",
            ),
            ParsedCircularItem(
                product_name="Chicken Breast",
                sale_price=2.99,
                regular_price=4.99,
                unit="lb",
                valid_from=start_date,
                valid_until=end_date,
                store_chain=store_chain,
                category="Meat",
            ),
            ParsedCircularItem(
                product_name="Bananas",
                sale_price=0.49,
                regular_price=0.59,
                unit="lb",
                valid_from=start_date,
                valid_until=end_date,
                store_chain=store_chain,
                category="Produce",
            ),
        ]

        return mock_items
