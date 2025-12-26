"""
AI-Powered Price Scraper - Uses vision models to extract prices from store websites.

This approach is more resilient than traditional HTML scraping because:
1. It "reads" pages visually like a human would
2. Less affected by HTML structure changes
3. Can handle dynamic JavaScript-rendered content via screenshots

Supported backends (in priority order):
1. Ollama (local, free) - LLaVA, Llama 3.2 Vision, BakLLaVA
2. Google AI Studio (free tier) - Gemini Pro Vision
3. OpenAI (paid) - GPT-4 Vision (fallback)

Requirements for full functionality:
- playwright: For taking screenshots of web pages
- ollama: For local AI processing (recommended)
- httpx: For API calls

Usage:
    scraper = AIPriceScraper()
    await scraper.initialize()
    prices = await scraper.scrape_store_prices("aldi", "milk", "92101")
"""

import asyncio
import base64
import json
import os
import re
from dataclasses import dataclass, field
from datetime import datetime, date
from typing import Optional
from pathlib import Path
import httpx

from app.config import get_settings


@dataclass
class AIScrapedPrice:
    """A price extracted by AI vision analysis."""
    product_name: str
    price: float
    original_price: Optional[float] = None
    unit: Optional[str] = None
    size: Optional[str] = None
    store_chain: str = ""
    is_on_sale: bool = False
    confidence: float = 0.0  # AI confidence score 0-1
    source: str = "ai_vision"  # Track that this came from AI
    scraped_at: datetime = field(default_factory=datetime.now)


class AIPriceScraper:
    """
    AI-powered price scraper using vision models.
    
    Workflow:
    1. Take screenshot of store's product page
    2. Send screenshot to vision AI
    3. Extract structured price data from AI response
    4. Validate and return prices
    """
    
    # Store URL templates for product searches
    # NOTE: Kroger-family stores are NOT included here because we have Kroger API access
    # Kroger brands: Kroger, Ralphs, Fred Meyer, Fry's, King Soopers, Smith's, QFC,
    #                Food 4 Less, Foods Co, Dillons, City Market, Harris Teeter, etc.
    STORE_URLS = {
        "aldi": "https://www.aldi.us/products/search/?q={query}",
        "walmart": "https://www.walmart.com/search?q={query}",
        "target": "https://www.target.com/s?searchTerm={query}",
        "costco": "https://www.costco.com/CatalogSearch?dept=All&keyword={query}",
        "safeway": "https://www.safeway.com/shop/search-results.html?q={query}",
        "albertsons": "https://www.albertsons.com/shop/search-results.html?q={query}",
        "vons": "https://www.vons.com/shop/search-results.html?q={query}",
        "publix": "https://www.publix.com/shop/search?q={query}",
        "heb": "https://www.heb.com/search?q={query}",
        "wegmans": "https://www.wegmans.com/search/?q={query}",
        "samsclub": "https://www.samsclub.com/s/{query}",
        "wholefood": "https://www.wholefoodsmarket.com/search?text={query}",
        "traderjoes": "https://www.traderjoes.com/home/search?q={query}&global=yes",
        "sprouts": "https://shop.sprouts.com/search?search_term={query}",
        "winco": "https://www.wincofoods.com/search?q={query}",
        "meijer": "https://www.meijer.com/search.html?text={query}",
    }
    
    # Kroger-family store brands (use Kroger API instead of scraping)
    KROGER_BRANDS = {
        "kroger", "ralphs", "fred meyer", "fredmeyer", "fry's", "frys",
        "king soopers", "kingsoopers", "smith's", "smiths", "qfc",
        "food 4 less", "food4less", "foods co", "foodsco", "dillons",
        "city market", "citymarket", "harris teeter", "harristeeter",
        "jay c", "jayc", "pay less", "payless", "baker's", "bakers",
        "gerbes", "owen's", "owens", "pick n save", "picknsave",
        "metro market", "metromarket", "mariano's", "marianos",
    }
    
    # AI prompt for extracting prices
    EXTRACTION_PROMPT = """Analyze this grocery store product listing screenshot and extract all visible product prices.

For each product you can see, extract:
1. Product name (full name as shown)
2. Current price (the main displayed price)
3. Original price (if on sale, the crossed-out price)
4. Size/unit (e.g., "16 oz", "1 gallon", "per lb")

Return your response as a JSON array like this:
[
  {
    "product_name": "Great Value Whole Milk",
    "price": 3.48,
    "original_price": null,
    "size": "1 gallon",
    "is_on_sale": false
  },
  {
    "product_name": "Organic Valley 2% Milk",
    "price": 5.99,
    "original_price": 7.49,
    "size": "64 oz",
    "is_on_sale": true
  }
]

IMPORTANT:
- Only include products that match or relate to grocery items
- Prices should be numbers (not strings)
- Set is_on_sale to true if there's an original/crossed-out price
- If you can't determine a field, use null
- Return ONLY the JSON array, no other text"""

    def __init__(self):
        self.playwright = None
        self.browser = None
        self.http_client = httpx.AsyncClient(timeout=30.0)
        self._initialized = False
        
        # Load config settings
        settings = get_settings()
        
        # AI backend configuration
        self.ollama_url = settings.ollama_url
        self.ollama_model = settings.ollama_vision_model
        self.google_api_key = settings.google_ai_api_key
        self.openai_api_key = settings.openai_api_key
        self.timeout_seconds = settings.ai_scraper_timeout_seconds
        
        # Screenshot cache directory
        self.cache_dir = Path("/tmp/grocery_screenshots")
        self.cache_dir.mkdir(exist_ok=True)
    
    async def initialize(self):
        """Initialize Playwright browser for screenshots."""
        if self._initialized:
            return
        
        try:
            from playwright.async_api import async_playwright
            self.playwright = await async_playwright().start()
            self.browser = await self.playwright.chromium.launch(
                headless=True,
                args=[
                    '--disable-blink-features=AutomationControlled',
                    '--disable-dev-shm-usage',
                    '--no-sandbox',
                ]
            )
            self._initialized = True
            print("AI Price Scraper: Playwright initialized successfully")
        except ImportError:
            print("AI Price Scraper: Playwright not installed. Install with: pip install playwright && playwright install chromium")
            self._initialized = False
        except Exception as e:
            print(f"AI Price Scraper: Failed to initialize Playwright: {e}")
            self._initialized = False
    
    async def close(self):
        """Clean up resources."""
        if self.browser:
            await self.browser.close()
        if self.playwright:
            await self.playwright.stop()
        await self.http_client.aclose()
    
    async def take_screenshot(self, url: str, store: str) -> Optional[bytes]:
        """Take a screenshot of a webpage."""
        if not self._initialized:
            await self.initialize()
        
        if not self.browser:
            print("AI Price Scraper: Browser not available")
            return None
        
        try:
            context = await self.browser.new_context(
                viewport={'width': 1280, 'height': 900},
                user_agent='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            )
            page = await context.new_page()
            
            # Navigate to URL with timeout
            await page.goto(url, wait_until='networkidle', timeout=30000)
            
            # Wait for content to load
            await asyncio.sleep(2)
            
            # Scroll down slightly to trigger lazy loading
            await page.evaluate('window.scrollBy(0, 300)')
            await asyncio.sleep(1)
            
            # Take screenshot
            screenshot = await page.screenshot(full_page=False)
            
            await context.close()
            
            # Cache the screenshot
            cache_path = self.cache_dir / f"{store}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.png"
            cache_path.write_bytes(screenshot)
            
            return screenshot
            
        except Exception as e:
            print(f"AI Price Scraper: Screenshot failed for {store}: {e}")
            return None
    
    async def analyze_with_ollama(self, image_bytes: bytes) -> Optional[list[dict]]:
        """
        Analyze screenshot using Ollama (local, free).
        
        Requires Ollama to be running locally with a vision model:
        - ollama pull llava (recommended, 4.7GB)
        - ollama pull bakllava (alternative)
        - ollama pull llama3.2-vision (newer, larger)
        """
        try:
            # Check if Ollama is available
            health_check = await self.http_client.get(f"{self.ollama_url}/api/tags")
            if health_check.status_code != 200:
                return None
            
            # Convert image to base64
            image_base64 = base64.b64encode(image_bytes).decode('utf-8')
            
            # Make request to Ollama
            response = await self.http_client.post(
                f"{self.ollama_url}/api/generate",
                json={
                    "model": self.ollama_model,
                    "prompt": self.EXTRACTION_PROMPT,
                    "images": [image_base64],
                    "stream": False,
                    "options": {
                        "temperature": 0.1,  # Low temperature for consistent extraction
                    }
                },
                timeout=60.0  # Vision models can be slow
            )
            
            if response.status_code == 200:
                result = response.json()
                text = result.get("response", "")
                return self._parse_ai_response(text)
            
            return None
            
        except Exception as e:
            print(f"Ollama analysis failed: {e}")
            return None
    
    async def analyze_with_google(self, image_bytes: bytes) -> Optional[list[dict]]:
        """
        Analyze screenshot using Google AI Studio (Gemini Pro Vision).
        
        Free tier: 60 requests/minute
        Get API key at: https://makersuite.google.com/app/apikey
        """
        if not self.google_api_key:
            return None
        
        try:
            image_base64 = base64.b64encode(image_bytes).decode('utf-8')
            
            response = await self.http_client.post(
                f"https://generativelanguage.googleapis.com/v1beta/models/gemini-pro-vision:generateContent?key={self.google_api_key}",
                json={
                    "contents": [{
                        "parts": [
                            {"text": self.EXTRACTION_PROMPT},
                            {
                                "inline_data": {
                                    "mime_type": "image/png",
                                    "data": image_base64
                                }
                            }
                        ]
                    }],
                    "generationConfig": {
                        "temperature": 0.1,
                        "maxOutputTokens": 2048,
                    }
                },
                timeout=30.0
            )
            
            if response.status_code == 200:
                result = response.json()
                text = result.get("candidates", [{}])[0].get("content", {}).get("parts", [{}])[0].get("text", "")
                return self._parse_ai_response(text)
            
            return None
            
        except Exception as e:
            print(f"Google AI analysis failed: {e}")
            return None
    
    async def analyze_with_openai(self, image_bytes: bytes) -> Optional[list[dict]]:
        """
        Analyze screenshot using OpenAI GPT-4 Vision (paid).
        
        This is a fallback for when local/free options aren't available.
        """
        if not self.openai_api_key:
            return None
        
        try:
            image_base64 = base64.b64encode(image_bytes).decode('utf-8')
            
            response = await self.http_client.post(
                "https://api.openai.com/v1/chat/completions",
                headers={"Authorization": f"Bearer {self.openai_api_key}"},
                json={
                    "model": "gpt-4-vision-preview",
                    "messages": [
                        {
                            "role": "user",
                            "content": [
                                {"type": "text", "text": self.EXTRACTION_PROMPT},
                                {
                                    "type": "image_url",
                                    "image_url": {
                                        "url": f"data:image/png;base64,{image_base64}",
                                        "detail": "high"
                                    }
                                }
                            ]
                        }
                    ],
                    "max_tokens": 2048,
                    "temperature": 0.1,
                },
                timeout=60.0
            )
            
            if response.status_code == 200:
                result = response.json()
                text = result["choices"][0]["message"]["content"]
                return self._parse_ai_response(text)
            
            return None
            
        except Exception as e:
            print(f"OpenAI analysis failed: {e}")
            return None
    
    def _parse_ai_response(self, text: str) -> Optional[list[dict]]:
        """Parse JSON from AI response, handling various formats."""
        if not text:
            return None
        
        # Try to find JSON array in the response
        # AI sometimes wraps it in markdown code blocks
        json_match = re.search(r'\[[\s\S]*\]', text)
        if json_match:
            try:
                return json.loads(json_match.group())
            except json.JSONDecodeError:
                pass
        
        # Try parsing the whole response
        try:
            return json.loads(text)
        except json.JSONDecodeError:
            pass
        
        return None
    
    async def scrape_store_prices(
        self, 
        store: str, 
        query: str, 
        zip_code: str = "92117"
    ) -> list[AIScrapedPrice]:
        """
        Scrape prices from a store using AI vision.
        
        Args:
            store: Store name (e.g., "aldi", "walmart")
            query: Product search term (e.g., "milk", "eggs")
            zip_code: User's zip code (for location-based pricing)
            
        Returns:
            List of scraped prices
        """
        store_lower = store.lower().replace(" ", "").replace("'", "")
        
        # Get URL template
        url_template = self.STORE_URLS.get(store_lower)
        if not url_template:
            print(f"AI Price Scraper: Unknown store {store}")
            return []
        
        url = url_template.format(query=query.replace(" ", "+"))
        print(f"AI Price Scraper: Scraping {store} for '{query}'...")
        
        # Take screenshot
        screenshot = await self.take_screenshot(url, store_lower)
        if not screenshot:
            return []
        
        # Analyze with available AI backends (in priority order)
        prices_data = None
        
        # 1. Try Ollama (local, free)
        prices_data = await self.analyze_with_ollama(screenshot)
        if prices_data:
            print(f"AI Price Scraper: Used Ollama for analysis")
        
        # 2. Try Google AI (free tier)
        if not prices_data:
            prices_data = await self.analyze_with_google(screenshot)
            if prices_data:
                print(f"AI Price Scraper: Used Google AI for analysis")
        
        # 3. Try OpenAI (paid fallback)
        if not prices_data:
            prices_data = await self.analyze_with_openai(screenshot)
            if prices_data:
                print(f"AI Price Scraper: Used OpenAI for analysis")
        
        if not prices_data:
            print(f"AI Price Scraper: No AI backend available or analysis failed")
            return []
        
        # Convert to AIScrapedPrice objects
        results = []
        store_name = store.title()
        
        # Normalize store names (excludes Kroger brands - use Kroger API)
        store_name_map = {
            "aldi": "ALDI",
            "walmart": "Walmart",
            "target": "Target",
            "costco": "Costco",
            "safeway": "Safeway",
            "albertsons": "Albertsons",
            "vons": "Vons",
            "publix": "Publix",
            "heb": "H-E-B",
            "wegmans": "Wegmans",
            "samsclub": "Sam's Club",
            "wholefood": "Whole Foods",
            "traderjoes": "Trader Joe's",
            "sprouts": "Sprouts",
            "winco": "WinCo",
            "meijer": "Meijer",
        }
        store_name = store_name_map.get(store_lower, store_name)
        
        for item in prices_data:
            try:
                price = float(item.get("price", 0))
                if price <= 0 or price > 1000:  # Sanity check
                    continue
                
                original_price = item.get("original_price")
                if original_price:
                    original_price = float(original_price)
                
                results.append(AIScrapedPrice(
                    product_name=item.get("product_name", "Unknown"),
                    price=price,
                    original_price=original_price,
                    size=item.get("size"),
                    unit=item.get("unit"),
                    store_chain=store_name,
                    is_on_sale=bool(item.get("is_on_sale", False)),
                    confidence=0.8,  # Default confidence
                    source="ai_vision",
                ))
            except (ValueError, TypeError):
                continue
        
        print(f"AI Price Scraper: Found {len(results)} prices for '{query}' at {store_name}")
        return results
    
    async def scrape_all_stores(self, query: str, zip_code: str = "92117") -> list[AIScrapedPrice]:
        """Scrape prices from all supported stores."""
        all_prices = []
        
        for store in self.STORE_URLS.keys():
            try:
                prices = await self.scrape_store_prices(store, query, zip_code)
                all_prices.extend(prices)
            except Exception as e:
                print(f"AI Price Scraper: Error scraping {store}: {e}")
        
        return all_prices


# Background task for scheduled scraping
class AIPriceScraperScheduler:
    """
    Scheduler for periodic AI-powered price scraping.
    
    Runs in the background to keep price data fresh.
    NOTE: Kroger brands use the Kroger API (free), not AI scraping.
    """
    
    # Common grocery items to track
    TRACKED_ITEMS = [
        "milk", "eggs", "bread", "butter", "cheese",
        "chicken", "beef", "pork", "bacon",
        "banana", "apple", "orange", "lettuce", "tomato",
        "rice", "pasta", "cereal", "coffee", "sugar",
    ]
    
    # Stores to scrape (excludes Kroger brands - use Kroger API instead)
    PRIORITY_STORES = ["aldi", "walmart", "target", "costco", "safeway"]
    
    def __init__(self):
        self.scraper = AIPriceScraper()
        self.running = False
        self._task = None
        self.scraped_prices: dict[str, list[AIScrapedPrice]] = {}  # Cache
    
    async def start(self, interval_hours: int = 6):
        """Start the background scraping scheduler."""
        if self.running:
            return
        
        self.running = True
        await self.scraper.initialize()
        
        print(f"AI Price Scraper Scheduler: Starting (interval: {interval_hours}h)")
        self._task = asyncio.create_task(self._run_loop(interval_hours))
    
    async def stop(self):
        """Stop the scheduler."""
        self.running = False
        if self._task:
            self._task.cancel()
        await self.scraper.close()
        print("AI Price Scraper Scheduler: Stopped")
    
    async def _run_loop(self, interval_hours: int):
        """Main scraping loop."""
        while self.running:
            try:
                await self._scrape_round()
            except Exception as e:
                print(f"AI Price Scraper Scheduler: Error in scrape round: {e}")
            
            # Wait for next round
            await asyncio.sleep(interval_hours * 3600)
    
    async def _scrape_round(self):
        """Perform one round of scraping."""
        print("AI Price Scraper Scheduler: Starting scrape round...")
        
        for item in self.TRACKED_ITEMS:
            item_prices = []
            
            for store in self.PRIORITY_STORES:
                try:
                    prices = await self.scraper.scrape_store_prices(store, item)
                    item_prices.extend(prices)
                    
                    # Rate limit between stores
                    await asyncio.sleep(5)
                    
                except Exception as e:
                    print(f"AI Price Scraper Scheduler: Error scraping {store} for {item}: {e}")
            
            # Cache results
            self.scraped_prices[item] = item_prices
            print(f"AI Price Scraper Scheduler: Cached {len(item_prices)} prices for '{item}'")
            
            # Rate limit between items
            await asyncio.sleep(10)
        
        print("AI Price Scraper Scheduler: Scrape round complete")
    
    def get_cached_prices(self, query: str) -> list[AIScrapedPrice]:
        """Get cached prices for a query."""
        query_lower = query.lower()
        
        # Exact match
        if query_lower in self.scraped_prices:
            return self.scraped_prices[query_lower]
        
        # Partial match
        for key, prices in self.scraped_prices.items():
            if query_lower in key or key in query_lower:
                return prices
        
        return []


# Singleton instance
_ai_scraper_scheduler: Optional[AIPriceScraperScheduler] = None

def get_ai_scraper_scheduler() -> AIPriceScraperScheduler:
    """Get or create the AI scraper scheduler singleton."""
    global _ai_scraper_scheduler
    if _ai_scraper_scheduler is None:
        _ai_scraper_scheduler = AIPriceScraperScheduler()
    return _ai_scraper_scheduler
