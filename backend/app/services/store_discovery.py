"""Store discovery service for finding nearby grocery stores using real APIs."""

import asyncio
import math
from typing import Optional
import httpx
from sqlalchemy.orm import Session

from app.config import get_settings
from app.models.store import Store

settings = get_settings()


# Grocery store types to search for
GROCERY_STORE_TYPES = ["grocery_or_supermarket", "supermarket"]

# Known grocery chains (for better identification)
GROCERY_CHAINS = {
    "vons": "Albertsons",
    "albertsons": "Albertsons", 
    "safeway": "Albertsons",
    "ralphs": "Kroger",
    "kroger": "Kroger",
    "fred meyer": "Kroger",
    "food 4 less": "Kroger",
    "target": "Target",
    "walmart": "Walmart",
    "walmart supercenter": "Walmart",
    "walmart neighborhood market": "Walmart",
    "costco": "Costco",
    "trader joe's": "Trader Joe's",
    "trader joes": "Trader Joe's",
    "whole foods": "Whole Foods",
    "whole foods market": "Whole Foods",
    "sprouts": "Sprouts",
    "sprouts farmers market": "Sprouts",
    "smart & final": "Smart & Final",
    "grocery outlet": "Grocery Outlet",
    "aldi": "Aldi",
    "food lion": "Food Lion",
    "publix": "Publix",
    "h-e-b": "H-E-B",
    "heb": "H-E-B",
    "wegmans": "Wegmans",
    "stop & shop": "Stop & Shop",
    "giant": "Giant",
    "food maxx": "Food Maxx",
    "winco": "WinCo Foods",
    "stater bros": "Stater Bros",
    "gelson's": "Gelson's",
    "bristol farms": "Bristol Farms",
    "northgate market": "Northgate Market",
    "cardenas": "Cardenas Markets",
    "el super": "El Super",
    "99 ranch": "99 Ranch Market",
    "h mart": "H Mart",
    "mitsuwa": "Mitsuwa Marketplace",
    "vallarta": "Vallarta Supermarkets",
    "food city": "Food City",
    "ranch market": "Ranch Market",
    "superior grocers": "Superior Grocers",
    "jon's": "Jon's Markets",
    "number one market": "Number One Market",
}


def identify_chain(store_name: str) -> str:
    """Identify the chain from a store name."""
    name_lower = store_name.lower()
    for keyword, chain in GROCERY_CHAINS.items():
        if keyword in name_lower:
            return chain
    return "Independent"


def calculate_distance_miles(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate distance between two points in miles using Haversine formula."""
    R = 3959  # Earth's radius in miles
    
    lat1_rad = math.radians(lat1)
    lat2_rad = math.radians(lat2)
    delta_lat = math.radians(lat2 - lat1)
    delta_lon = math.radians(lon2 - lon1)
    
    a = math.sin(delta_lat / 2) ** 2 + \
        math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(delta_lon / 2) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    
    return R * c


def estimate_drive_time_minutes(distance_miles: float) -> int:
    """Estimate drive time based on distance.
    
    Uses average speed assumptions:
    - Urban: ~25 mph average with traffic
    - This gives roughly 2.4 minutes per mile
    """
    minutes = distance_miles * 2.4
    return max(1, int(round(minutes)))


def miles_for_drive_time(minutes: int) -> float:
    """Convert drive time to approximate radius in miles."""
    return minutes / 2.4


async def geocode_zip_code(zip_code: str) -> Optional[tuple[float, float]]:
    """Convert ZIP code to lat/lng using Google Geocoding API or free alternatives."""
    
    # Try Google Maps first if API key is available
    if settings.google_maps_api_key:
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(
                    "https://maps.googleapis.com/maps/api/geocode/json",
                    params={
                        "address": zip_code,
                        "components": "country:US",
                        "key": settings.google_maps_api_key,
                    },
                    timeout=10.0,
                )
                data = response.json()
                if data.get("status") == "OK" and data.get("results"):
                    location = data["results"][0]["geometry"]["location"]
                    return (location["lat"], location["lng"])
        except Exception as e:
            print(f"Google geocoding failed: {e}")
    
    # Try free Zippopotam API
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"https://api.zippopotam.us/us/{zip_code}",
                timeout=10.0,
            )
            if response.status_code == 200:
                data = response.json()
                places = data.get("places", [])
                if places:
                    return (float(places[0]["latitude"]), float(places[0]["longitude"]))
    except Exception as e:
        print(f"Zippopotam geocoding failed: {e}")
    
    return None


async def search_nearby_stores_google(
    lat: float, 
    lng: float, 
    radius_meters: int = 8000
) -> list[dict]:
    """Search for grocery stores using Google Places API."""
    
    if not settings.google_maps_api_key:
        return []
    
    stores = []
    
    try:
        async with httpx.AsyncClient() as client:
            # Search for grocery stores and supermarkets
            response = await client.get(
                "https://maps.googleapis.com/maps/api/place/nearbysearch/json",
                params={
                    "location": f"{lat},{lng}",
                    "radius": radius_meters,
                    "type": "supermarket",
                    "key": settings.google_maps_api_key,
                },
                timeout=15.0,
            )
            data = response.json()
            
            if data.get("status") == "OK":
                for place in data.get("results", []):
                    store_info = {
                        "name": place.get("name", "Unknown Store"),
                        "address": place.get("vicinity", ""),
                        "lat": place["geometry"]["location"]["lat"],
                        "lng": place["geometry"]["location"]["lng"],
                        "place_id": place.get("place_id"),
                        "rating": place.get("rating"),
                        "chain": identify_chain(place.get("name", "")),
                    }
                    stores.append(store_info)
    except Exception as e:
        print(f"Google Places search failed: {e}")
    
    return stores


async def search_nearby_stores_overpass(
    lat: float, 
    lng: float, 
    radius_meters: int = 8000
) -> list[dict]:
    """Search for grocery stores using OpenStreetMap Overpass API (free, no key needed)."""
    
    stores = []
    
    # Overpass QL query for supermarkets and grocery stores
    query = f"""
[out:json][timeout:25];
(
  node["shop"="supermarket"](around:{radius_meters},{lat},{lng});
  way["shop"="supermarket"](around:{radius_meters},{lat},{lng});
  node["shop"="grocery"](around:{radius_meters},{lat},{lng});
  way["shop"="grocery"](around:{radius_meters},{lat},{lng});
  node["shop"="convenience"]["name"](around:{radius_meters},{lat},{lng});
);
out center;
"""
    
    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                "https://overpass-api.de/api/interpreter",
                content=query.strip(),
                headers={"Content-Type": "application/x-www-form-urlencoded"},
                timeout=30.0,
            )
            
            # Check if we got a valid response
            if response.status_code != 200:
                print(f"Overpass API returned status {response.status_code}")
                return await search_nearby_stores_nominatim(lat, lng, radius_meters)
            
            # Check if response is JSON
            content_type = response.headers.get("content-type", "")
            if "json" not in content_type:
                print(f"Overpass returned non-JSON content: {content_type}")
                return await search_nearby_stores_nominatim(lat, lng, radius_meters)
            
            data = response.json()
            
            for element in data.get("elements", []):
                tags = element.get("tags", {})
                name = tags.get("name") or tags.get("brand") or "Unknown Store"
                
                # Skip if no useful name
                if name == "Unknown Store" and not tags.get("brand"):
                    continue
                
                # Get coordinates (center for ways, direct for nodes)
                if element.get("type") == "way":
                    center = element.get("center", {})
                    store_lat = center.get("lat")
                    store_lng = center.get("lon")
                else:
                    store_lat = element.get("lat")
                    store_lng = element.get("lon")
                
                if store_lat and store_lng:
                    # Build address from available tags
                    addr_parts = []
                    if tags.get("addr:housenumber"):
                        addr_parts.append(tags["addr:housenumber"])
                    if tags.get("addr:street"):
                        addr_parts.append(tags["addr:street"])
                    if tags.get("addr:city"):
                        addr_parts.append(tags["addr:city"])
                    
                    address = " ".join(addr_parts) if addr_parts else ""
                    
                    store_info = {
                        "name": name,
                        "address": address,
                        "lat": store_lat,
                        "lng": store_lng,
                        "place_id": f"osm_{element.get('id')}",
                        "chain": identify_chain(name),
                        "brand": tags.get("brand"),
                    }
                    stores.append(store_info)
            
            print(f"Overpass found {len(stores)} stores")
                    
    except Exception as e:
        print(f"Overpass search failed: {e}")
        # Try Nominatim as fallback
        return await search_nearby_stores_nominatim(lat, lng, radius_meters)
    
    return stores


async def search_nearby_stores_nominatim(
    lat: float,
    lng: float, 
    radius_meters: int = 8000
) -> list[dict]:
    """Fallback search using Nominatim (OSM's geocoding service)."""
    
    stores = []
    search_terms = ["supermarket", "grocery store", "Vons", "Ralphs", "Trader Joe's", "Target", "Walmart"]
    
    try:
        async with httpx.AsyncClient() as client:
            for term in search_terms:
                response = await client.get(
                    "https://nominatim.openstreetmap.org/search",
                    params={
                        "q": term,
                        "format": "json",
                        "viewbox": f"{lng-0.1},{lat+0.1},{lng+0.1},{lat-0.1}",
                        "bounded": 1,
                        "limit": 10,
                    },
                    headers={"User-Agent": "GroceryCompare/1.0"},
                    timeout=10.0,
                )
                
                if response.status_code == 200:
                    results = response.json()
                    for place in results:
                        store_lat = float(place.get("lat", 0))
                        store_lng = float(place.get("lon", 0))
                        
                        # Check distance
                        distance = calculate_distance_miles(lat, lng, store_lat, store_lng)
                        if distance * 1609.34 > radius_meters:
                            continue
                        
                        name = place.get("display_name", "").split(",")[0]
                        if not name or len(name) < 3:
                            continue
                            
                        stores.append({
                            "name": name,
                            "address": place.get("display_name", ""),
                            "lat": store_lat,
                            "lng": store_lng,
                            "place_id": f"nom_{place.get('place_id')}",
                            "chain": identify_chain(name),
                        })
                
                # Rate limit - Nominatim requires 1 req/sec
                await asyncio.sleep(1)
                        
    except Exception as e:
        print(f"Nominatim search failed: {e}")
    
    # Deduplicate by name
    seen = set()
    unique = []
    for s in stores:
        if s["name"] not in seen:
            seen.add(s["name"])
            unique.append(s)
    
    print(f"Nominatim found {len(unique)} stores")
    return unique


async def discover_stores_for_zip(
    db: Session,
    zip_code: str,
    max_drive_time_minutes: int = 15,
) -> list[tuple[Store, float, int]]:
    """Discover real stores within drive time of a ZIP code.
    
    Returns:
        List of (Store, distance_miles, estimated_drive_time) tuples
    """
    # Get coordinates for ZIP code
    coords = await geocode_zip_code(zip_code)
    if not coords:
        print(f"Could not geocode ZIP code: {zip_code}")
        return []
    
    user_lat, user_lng = coords
    max_distance = miles_for_drive_time(max_drive_time_minutes)
    radius_meters = int(max_distance * 1609.34)  # Convert miles to meters
    
    # Search for new stores using APIs
    print(f"Searching for stores near {zip_code} ({user_lat}, {user_lng})...")
    
    # Try Google Places first, fall back to OpenStreetMap
    if settings.google_maps_api_key:
        found_stores = await search_nearby_stores_google(user_lat, user_lng, radius_meters)
    else:
        found_stores = await search_nearby_stores_overpass(user_lat, user_lng, radius_meters)
    
    print(f"Found {len(found_stores)} stores from API")
    
    # Add new stores to database
    for store_info in found_stores:
        # Check if store already exists (by name and approximate location)
        existing = db.query(Store).filter(
            Store.name == store_info["name"],
            Store.lat.between(store_info["lat"] - 0.001, store_info["lat"] + 0.001),
            Store.lng.between(store_info["lng"] - 0.001, store_info["lng"] + 0.001),
        ).first()
        
        if not existing:
            new_store = Store(
                name=store_info["name"],
                chain=store_info["chain"],
                address=store_info.get("address", ""),
                zip_code=zip_code,
                lat=store_info["lat"],
                lng=store_info["lng"],
            )
            db.add(new_store)
    
    db.commit()
    
    # Query all stores and filter by distance
    all_db_stores = db.query(Store).all()
    nearby_stores = []
    
    for store in all_db_stores:
        if store.lat and store.lng:
            distance = calculate_distance_miles(user_lat, user_lng, store.lat, store.lng)
            drive_time = estimate_drive_time_minutes(distance)
            if drive_time <= max_drive_time_minutes:
                nearby_stores.append((store, distance, drive_time))
    
    nearby_stores.sort(key=lambda x: x[2])
    return nearby_stores


def ensure_stores_with_prices(
    db: Session,
    stores: list[Store],
) -> None:
    """Ensure stores have prices for products.
    
    Creates simulated prices since we don't have real price APIs yet.
    In production, this would fetch from store APIs.
    """
    from app.models.price import Price
    from app.models.product import Product
    from datetime import date
    import random
    
    today = date.today()
    products = db.query(Product).all()
    
    if not products:
        return
    
    # Base prices (approximate real prices)
    base_prices = {
        "Whole Milk": 4.99, "2% Milk": 4.49, "Large Eggs": 5.99, "Greek Yogurt": 1.29,
        "Cheddar Cheese": 4.49, "White Bread": 2.99, "Whole Wheat Bread": 3.99, "Bagels": 4.29,
        "Bananas": 0.59, "Red Apples": 1.79, "Baby Spinach": 4.49, "Russet Potatoes": 4.99,
        "Yellow Onions": 2.99, "Chicken Breast": 4.99, "Ground Beef 80/20": 5.99, "Bacon": 6.99,
        "Coca-Cola": 8.99, "Orange Juice": 4.49, "Coffee": 8.99, "Cheerios": 4.49,
        "Frosted Flakes": 3.99, "Chicken Noodle Soup": 1.99, "Diced Tomatoes": 1.49,
        "Black Beans": 1.29, "Potato Chips": 3.99, "Oreo Cookies": 4.99
    }
    
    # Price adjustments by chain
    chain_multipliers = {
        "Whole Foods": 1.25,
        "Trader Joe's": 0.95,
        "Costco": 0.85,
        "Walmart": 0.90,
        "Target": 1.0,
        "Aldi": 0.80,
        "Kroger": 0.95,
        "Albertsons": 1.05,
        "Sprouts": 1.10,
        "Independent": 1.05,
    }
    
    for store in stores:
        # Check if store already has prices
        existing = db.query(Price).filter(Price.store_id == store.id).first()
        if existing:
            continue
        
        chain_mult = chain_multipliers.get(store.chain, 1.0)
        
        for product in products:
            base = base_prices.get(product.name, 3.99)
            # Add some random variation (±10%)
            variation = random.uniform(0.90, 1.10)
            final_price = round(base * chain_mult * variation, 2)
            
            # Occasionally put items on sale
            is_on_sale = random.random() < 0.2
            sale_price = round(final_price * 0.75, 2) if is_on_sale else None
            
            price = Price(
                product_id=product.id,
                store_id=store.id,
                price=final_price,
                unit_price=round(final_price / max(product.unit_size, 1), 2),
                sale_price=sale_price,
                effective_date=today,
            )
            db.add(price)
    
    db.commit()
