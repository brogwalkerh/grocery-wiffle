"""
Public APIs for grocery product and price data.

These are legal, free APIs that provide product information:
1. Open Prices API (prices.openfoodfacts.org) - Crowdsourced PRICES with store locations
2. Open Food Facts - Crowdsourced product database
3. USDA FoodData Central - Nutritional data with some pricing
4. UPC Item DB - Product lookup by barcode

No web scraping needed - these are official APIs!
"""

import asyncio
import httpx
from typing import Optional
from dataclasses import dataclass, field
from datetime import datetime, timedelta


@dataclass
class ProductInfo:
    """Product information from public APIs."""
    name: str
    brand: Optional[str]
    barcode: Optional[str]
    category: Optional[str]
    size: Optional[str]
    image_url: Optional[str]
    # Price info (when available)
    price: Optional[float] = None
    price_currency: Optional[str] = None
    price_source: Optional[str] = None
    price_date: Optional[datetime] = None
    store_name: Optional[str] = None
    store_location: Optional[str] = None
    is_estimated: bool = True


@dataclass
class OpenPrice:
    """A price record from Open Prices API."""
    price: float
    currency: str
    product_code: Optional[str]
    product_name: Optional[str]
    location_name: Optional[str]
    location_id: Optional[str]
    date: Optional[datetime]
    proof_id: Optional[int] = None


class OpenPricesAPI:
    """
    Open Prices API - Crowdsourced grocery prices with store locations.
    https://prices.openfoodfacts.org/
    
    This is the PRIMARY source for actual prices with store attribution.
    - ~125,000+ prices globally
    - Real store locations (name + address)
    - Community-contributed, verified prices
    - Free API, no key required
    
    API Docs: https://prices.openfoodfacts.org/api/docs
    """
    
    BASE_URL = "https://prices.openfoodfacts.org/api/v1"
    
    def __init__(self):
        self.client = httpx.AsyncClient(
            timeout=15.0,
            headers={
                "User-Agent": "GroceryCompare/1.0 (grocery-compare-app)",
                "Accept": "application/json",
            }
        )
    
    async def search_prices(
        self, 
        product_code: Optional[str] = None,
        product_name: Optional[str] = None,
        location_osm_id: Optional[str] = None,
        price_min: Optional[float] = None,
        price_max: Optional[float] = None,
        order_by: str = "-date",  # Most recent first
        page: int = 1,
        size: int = 50,
    ) -> list[OpenPrice]:
        """
        Search for prices in the Open Prices database.
        
        Args:
            product_code: Barcode/EAN to search for
            product_name: Product name (partial match)
            location_osm_id: OpenStreetMap ID for location filtering
            price_min/max: Price range filter
            order_by: Sort order (-date = newest first)
        """
        try:
            params = {
                "page": page,
                "size": size,
                "order_by": order_by,
            }
            
            if product_code:
                params["product_code"] = product_code
            if location_osm_id:
                params["location_osm_id"] = location_osm_id
            if price_min is not None:
                params["price__gte"] = price_min
            if price_max is not None:
                params["price__lte"] = price_max
            
            response = await self.client.get(f"{self.BASE_URL}/prices", params=params)
            response.raise_for_status()
            data = response.json()
            
            prices = []
            for item in data.get("items", []):
                prices.append(self._parse_price(item))
            
            print(f"Open Prices API: Found {len(prices)} prices")
            return prices
            
        except Exception as e:
            print(f"Open Prices API error: {e}")
            return []
    
    async def get_prices_by_barcode(self, barcode: str) -> list[OpenPrice]:
        """Get all prices for a specific product barcode."""
        return await self.search_prices(product_code=barcode)
    
    async def get_locations(
        self,
        osm_name_contains: Optional[str] = None,
        page: int = 1,
        size: int = 50,
    ) -> list[dict]:
        """
        Get store locations from Open Prices.
        
        Args:
            osm_name_contains: Filter by store name (partial match)
        """
        try:
            params = {"page": page, "size": size}
            if osm_name_contains:
                params["osm_name__contains"] = osm_name_contains
            
            response = await self.client.get(f"{self.BASE_URL}/locations", params=params)
            response.raise_for_status()
            data = response.json()
            
            return data.get("items", [])
            
        except Exception as e:
            print(f"Open Prices locations error: {e}")
            return []
    
    async def get_products(
        self,
        code: Optional[str] = None,
        page: int = 1,
        size: int = 50,
    ) -> list[dict]:
        """Get products from Open Prices database."""
        try:
            params = {"page": page, "size": size}
            if code:
                params["code"] = code
            
            response = await self.client.get(f"{self.BASE_URL}/products", params=params)
            response.raise_for_status()
            data = response.json()
            
            return data.get("items", [])
            
        except Exception as e:
            print(f"Open Prices products error: {e}")
            return []
    
    async def get_recent_prices(self, limit: int = 100) -> list[OpenPrice]:
        """Get most recent price contributions."""
        return await self.search_prices(order_by="-date", size=limit)
    
    def _parse_price(self, item: dict) -> OpenPrice:
        """Parse an Open Prices API price item."""
        # Parse date
        date = None
        if item.get("date"):
            try:
                date = datetime.fromisoformat(item["date"].replace("Z", "+00:00"))
            except:
                pass
        
        # Get location info
        location = item.get("location", {}) or {}
        location_name = location.get("osm_name") or location.get("osm_display_name")
        
        # Get product info  
        product = item.get("product", {}) or {}
        product_name = product.get("product_name") or product.get("name")
        
        return OpenPrice(
            price=item.get("price", 0),
            currency=item.get("currency", "USD"),
            product_code=item.get("product_code"),
            product_name=product_name,
            location_name=location_name,
            location_id=str(location.get("osm_id")) if location.get("osm_id") else None,
            date=date,
            proof_id=item.get("proof_id"),
        )
    
    async def close(self):
        """Close the HTTP client."""
        await self.client.aclose()


class OpenFoodFactsAPI:
    """
    Open Food Facts - Free, open database of food products.
    https://world.openfoodfacts.org/
    
    - Over 2 million products
    - Community-contributed data
    - Includes some price data from contributors
    """
    
    BASE_URL = "https://world.openfoodfacts.org"
    
    def __init__(self):
        self.client = httpx.AsyncClient(
            timeout=10.0,
            headers={
                "User-Agent": "GroceryCompare/1.0 (contact@grocerycompare.app)"
            }
        )
    
    async def search_products(self, query: str, page: int = 1, page_size: int = 10) -> list[ProductInfo]:
        """Search for products by name."""
        try:
            url = f"{self.BASE_URL}/cgi/search.pl"
            params = {
                "search_terms": query,
                "search_simple": 1,
                "action": "process",
                "json": 1,
                "page": page,
                "page_size": page_size,
                "countries_tags_en": "united-states",  # Focus on US products
            }
            
            response = await self.client.get(url, params=params)
            response.raise_for_status()
            data = response.json()
            
            products = []
            for product in data.get("products", []):
                products.append(self._parse_product(product))
            
            return products
            
        except Exception as e:
            print(f"Open Food Facts search error: {e}")
            return []
    
    async def get_product_by_barcode(self, barcode: str) -> Optional[ProductInfo]:
        """Look up a product by its barcode/UPC."""
        try:
            url = f"{self.BASE_URL}/api/v0/product/{barcode}.json"
            response = await self.client.get(url)
            response.raise_for_status()
            data = response.json()
            
            if data.get("status") == 1:
                return self._parse_product(data.get("product", {}))
            return None
            
        except Exception as e:
            print(f"Open Food Facts barcode lookup error: {e}")
            return None
    
    def _parse_product(self, product: dict) -> ProductInfo:
        """Parse Open Food Facts product data."""
        # Try to extract price if available (some products have it)
        price = None
        price_source = None
        
        # Open Food Facts sometimes has price data in stores field
        stores = product.get("stores", "")
        
        return ProductInfo(
            name=product.get("product_name", product.get("product_name_en", "Unknown")),
            brand=product.get("brands"),
            barcode=product.get("code"),
            category=product.get("categories_tags", [None])[0] if product.get("categories_tags") else None,
            size=product.get("quantity"),
            image_url=product.get("image_url"),
            price=price,
            price_source=price_source,
            is_estimated=True,
        )


class USDAFoodDataAPI:
    """
    USDA FoodData Central API - Official US government food database.
    https://fdc.nal.usda.gov/
    
    Free API key required (instant signup at https://fdc.nal.usda.gov/api-key-signup.html).
    Contains detailed nutritional data and some market prices.
    
    IMPORTANT: Replace DEMO_KEY with your real API key!
    DEMO_KEY is severely rate-limited (25 requests/hour per IP).
    Real keys get 3,600 requests/hour.
    """
    
    BASE_URL = "https://api.nal.usda.gov/fdc/v1"
    
    def __init__(self, api_key: str = "DEMO_KEY"):
        if api_key == "DEMO_KEY":
            print("⚠️  WARNING: Using DEMO_KEY for USDA API. Get a free key at https://fdc.nal.usda.gov/api-key-signup.html")
        self.api_key = api_key
        self.client = httpx.AsyncClient(timeout=10.0)
    
    async def search_foods(self, query: str, page_size: int = 10) -> list[ProductInfo]:
        """Search for foods by name."""
        try:
            url = f"{self.BASE_URL}/foods/search"
            params = {
                "api_key": self.api_key,
                "query": query,
                "pageSize": page_size,
                "dataType": ["Branded", "Survey (FNDDS)"],  # Focus on branded products
            }
            
            response = await self.client.get(url, params=params)
            response.raise_for_status()
            data = response.json()
            
            products = []
            for food in data.get("foods", []):
                products.append(self._parse_food(food))
            
            return products
            
        except Exception as e:
            print(f"USDA API search error: {e}")
            return []
    
    def _parse_food(self, food: dict) -> ProductInfo:
        """Parse USDA food data."""
        return ProductInfo(
            name=food.get("description", "Unknown"),
            brand=food.get("brandOwner") or food.get("brandName"),
            barcode=food.get("gtinUpc"),
            category=food.get("foodCategory"),
            size=food.get("servingSize"),
            image_url=None,  # USDA doesn't provide images
            is_estimated=True,
        )


class UPCItemDBAPI:
    """
    UPC Item DB - Free barcode lookup API.
    https://www.upcitemdb.com/
    
    100 free lookups per day.
    """
    
    BASE_URL = "https://api.upcitemdb.com/prod/trial"
    
    def __init__(self):
        self.client = httpx.AsyncClient(timeout=10.0)
    
    async def lookup_barcode(self, upc: str) -> Optional[ProductInfo]:
        """Look up a product by UPC barcode."""
        try:
            url = f"{self.BASE_URL}/lookup"
            params = {"upc": upc}
            
            response = await self.client.get(url, params=params)
            response.raise_for_status()
            data = response.json()
            
            items = data.get("items", [])
            if items:
                item = items[0]
                
                # UPC Item DB sometimes has price offers
                offers = item.get("offers", [])
                price = None
                price_source = None
                if offers:
                    # Get the lowest price from offers
                    prices = [o.get("price") for o in offers if o.get("price")]
                    if prices:
                        price = min(prices)
                        price_source = "UPC Item DB offers"
                
                return ProductInfo(
                    name=item.get("title", "Unknown"),
                    brand=item.get("brand"),
                    barcode=item.get("upc"),
                    category=item.get("category"),
                    size=item.get("size"),
                    image_url=item.get("images", [None])[0] if item.get("images") else None,
                    price=price,
                    price_source=price_source,
                    is_estimated=price is None,
                )
            
            return None
            
        except Exception as e:
            print(f"UPC Item DB lookup error: {e}")
            return None
    
    async def search_products(self, query: str) -> list[ProductInfo]:
        """Search for products by name."""
        try:
            url = f"{self.BASE_URL}/search"
            params = {"s": query, "type": "product"}
            
            response = await self.client.get(url, params=params)
            response.raise_for_status()
            data = response.json()
            
            products = []
            for item in data.get("items", [])[:10]:
                offers = item.get("offers", [])
                price = None
                if offers:
                    prices = [o.get("price") for o in offers if o.get("price")]
                    if prices:
                        price = min(prices)
                
                products.append(ProductInfo(
                    name=item.get("title", "Unknown"),
                    brand=item.get("brand"),
                    barcode=item.get("upc"),
                    category=item.get("category"),
                    size=item.get("size"),
                    image_url=item.get("images", [None])[0] if item.get("images") else None,
                    price=price,
                    price_source="UPC Item DB" if price else None,
                    is_estimated=price is None,
                ))
            
            return products
            
        except Exception as e:
            print(f"UPC Item DB search error: {e}")
            return []


class AggregatedProductAPI:
    """
    Aggregates data from multiple public APIs for best coverage.
    
    Priority order:
    1. Open Prices API - Real crowdsourced prices with store names (BEST)
    2. UPC Item DB - Sometimes has price offers
    3. Open Food Facts - Product info, rarely has prices
    4. USDA - Nutrition data, no prices
    5. Category estimates - Fallback only
    """
    
    def __init__(self, usda_api_key: Optional[str] = None):
        if usda_api_key is None:
            from app.config import get_settings
            settings = get_settings()
            usda_api_key = settings.usda_api_key
        
        # Primary price source - Open Prices has actual store prices!
        self.open_prices = OpenPricesAPI()
        self.open_food_facts = OpenFoodFactsAPI()
        self.usda = USDAFoodDataAPI(usda_api_key)
        self.upc_db = UPCItemDBAPI()
    
    async def search_products_with_prices(self, query: str, barcode: Optional[str] = None) -> list[ProductInfo]:
        """
        Search for products and get real prices where available.
        
        This is the main entry point - combines product info with real prices.
        """
        products = []
        
        # If we have a barcode, try Open Prices first (most reliable)
        if barcode:
            open_prices = await self.open_prices.get_prices_by_barcode(barcode)
            if open_prices:
                for op in open_prices:
                    products.append(ProductInfo(
                        name=op.product_name or query,
                        brand=None,
                        barcode=op.product_code,
                        category=None,
                        size=None,
                        image_url=None,
                        price=op.price,
                        price_currency=op.currency,
                        price_source="Open Prices (crowdsourced)",
                        price_date=op.date,
                        store_name=op.location_name,
                        store_location=None,
                        is_estimated=False,  # Real price!
                    ))
        
        # Search all APIs in parallel for product info
        results = await asyncio.gather(
            self.open_food_facts.search_products(query),
            self.upc_db.search_products(query),
            return_exceptions=True,
        )
        
        for result in results:
            if isinstance(result, list):
                products.extend(result)
        
        # Sort: real prices first, then by name relevance
        products.sort(key=lambda p: (
            p.is_estimated,  # Real prices first
            p.price is None,  # Then any price
            query.lower() not in (p.name or "").lower(),
        ))
        
        # Deduplicate
        seen = set()
        unique = []
        for p in products:
            key = (p.barcode or p.name, p.store_name or "")
            if key not in seen:
                seen.add(key)
                unique.append(p)
        
        return unique[:30]
    
    async def search_products(self, query: str) -> list[ProductInfo]:
        """
        Search all APIs and combine results.
        Prioritizes results with actual prices.
        """
        # Search all APIs in parallel
        results = await asyncio.gather(
            self.open_food_facts.search_products(query),
            self.usda.search_foods(query),
            self.upc_db.search_products(query),
            return_exceptions=True,
        )
        
        all_products = []
        
        for result in results:
            if isinstance(result, list):
                all_products.extend(result)
        
        # Sort: products with prices first, then by name relevance
        all_products.sort(key=lambda p: (
            p.price is None,  # Products with prices first
            query.lower() not in (p.name or "").lower(),  # Exact matches first
        ))
        
        # Deduplicate by barcode if possible
        seen_barcodes = set()
        unique_products = []
        for product in all_products:
            if product.barcode:
                if product.barcode not in seen_barcodes:
                    seen_barcodes.add(product.barcode)
                    unique_products.append(product)
            else:
                unique_products.append(product)
        
        return unique_products[:20]  # Return top 20
    
    async def lookup_barcode(self, barcode: str) -> Optional[ProductInfo]:
        """Look up a product by barcode across all APIs."""
        results = await asyncio.gather(
            self.open_food_facts.get_product_by_barcode(barcode),
            self.upc_db.lookup_barcode(barcode),
            return_exceptions=True,
        )
        
        # Return the first successful result with most data
        best_result = None
        for result in results:
            if isinstance(result, ProductInfo):
                if best_result is None:
                    best_result = result
                elif result.price is not None and best_result.price is None:
                    best_result = result
        
        return best_result


# Average price estimates by category (fallback when no API data)
# Based on December 2024 US grocery prices
CATEGORY_PRICE_ESTIMATES = {
    # Dairy
    "milk": {"price": 3.99, "unit": "gallon"},
    "butter": {"price": 4.49, "unit": "lb"},
    "eggs": {"price": 3.99, "unit": "dozen"},
    "cheese": {"price": 4.99, "unit": "8 oz"},
    "yogurt": {"price": 1.29, "unit": "6 oz"},
    
    # Produce
    "apple": {"price": 1.99, "unit": "lb"},
    "banana": {"price": 0.59, "unit": "lb"},
    "orange": {"price": 1.49, "unit": "lb"},
    "lettuce": {"price": 2.49, "unit": "head"},
    "tomato": {"price": 2.99, "unit": "lb"},
    "potato": {"price": 0.99, "unit": "lb"},
    "onion": {"price": 1.29, "unit": "lb"},
    "carrot": {"price": 1.49, "unit": "lb"},
    "broccoli": {"price": 2.49, "unit": "lb"},
    
    # Meat
    "chicken": {"price": 3.99, "unit": "lb"},
    "beef": {"price": 5.99, "unit": "lb"},
    "pork": {"price": 3.49, "unit": "lb"},
    "bacon": {"price": 6.99, "unit": "lb"},
    
    # Pantry
    "bread": {"price": 2.99, "unit": "loaf"},
    "flour": {"price": 3.49, "unit": "5 lb"},
    "sugar": {"price": 3.29, "unit": "4 lb"},
    "rice": {"price": 2.99, "unit": "2 lb"},
    "pasta": {"price": 1.49, "unit": "lb"},
    "cereal": {"price": 4.49, "unit": "box"},
    "oil": {"price": 4.99, "unit": "48 oz"},
    
    # Beverages
    "juice": {"price": 3.99, "unit": "64 oz"},
    "soda": {"price": 6.99, "unit": "12 pack"},
    "water": {"price": 4.99, "unit": "24 pack"},
    "coffee": {"price": 8.99, "unit": "12 oz"},
}


def get_category_estimate(query: str) -> Optional[dict]:
    """Get a price estimate based on product category."""
    query_lower = query.lower()
    for category, estimate in CATEGORY_PRICE_ESTIMATES.items():
        if category in query_lower:
            return estimate
    return None
