"""Product matching service using fuzzy string matching."""

import re
from typing import Any, Optional

from rapidfuzz import fuzz, process
from sqlalchemy.orm import Session

from app.models.product import Product


class ProductMatcher:
    """Service for matching product names using fuzzy string matching."""

    # Common brand name variations
    BRAND_ALIASES: dict[str, list[str]] = {
        "coca-cola": ["coke", "coca cola", "cocacola"],
        "pepsi": ["pepsi-cola", "pepsicola"],
        "general mills": ["gm"],
        "kellogg's": ["kelloggs", "kellogg"],
        "nabisco": [],
        "kraft": [],
        "nestle": ["nestlé"],
        "campbell's": ["campbells", "campbell"],
        "oscar mayer": ["oscar meyer"],
        "tyson": [],
        "tropicana": [],
        "folgers": ["folger's"],
    }

    # Unit type normalization mapping
    UNIT_NORMALIZATION: dict[str, str] = {
        "ounce": "oz",
        "ounces": "oz",
        "pound": "lb",
        "pounds": "lb",
        "lbs": "lb",
        "gallon": "gal",
        "gallons": "gal",
        "liter": "l",
        "liters": "l",
        "litre": "l",
        "litres": "l",
        "count": "ct",
        "ct": "ct",
        "pack": "ct",
        "each": "ea",
        "piece": "ea",
        "pieces": "ea",
    }

    def __init__(self, db: Session, min_score: float = 60.0):
        """Initialize the product matcher.

        Args:
            db: SQLAlchemy database session
            min_score: Minimum matching score (0-100) to consider a match
        """
        self.db = db
        self.min_score = min_score
        self._product_cache: Optional[list[Product]] = None
        self._name_cache: Optional[list[str]] = None

    def _load_products(self) -> None:
        """Load all products from the database into cache."""
        if self._product_cache is None:
            self._product_cache = self.db.query(Product).all()
            self._name_cache = [self._normalize_name(p.name, p.brand) for p in self._product_cache]

    def _normalize_name(self, name: str, brand: Optional[str] = None) -> str:
        """Normalize a product name for matching.

        Args:
            name: Product name to normalize
            brand: Optional brand name to include

        Returns:
            Normalized product name
        """
        # Combine brand and name
        if brand:
            full_name = f"{brand} {name}"
        else:
            full_name = name

        # Convert to lowercase
        normalized = full_name.lower()

        # Normalize brand aliases
        for canonical, aliases in self.BRAND_ALIASES.items():
            for alias in aliases:
                normalized = normalized.replace(alias, canonical)

        # Remove common filler words
        filler_words = ["the", "a", "an", "original", "classic", "natural", "organic"]
        for word in filler_words:
            normalized = re.sub(rf"\b{word}\b", "", normalized)

        # Remove extra whitespace
        normalized = re.sub(r"\s+", " ", normalized).strip()

        return normalized

    def normalize_unit(self, unit: str) -> str:
        """Normalize a unit type string.

        Args:
            unit: Unit string to normalize

        Returns:
            Normalized unit string
        """
        unit_lower = unit.lower().strip()
        return self.UNIT_NORMALIZATION.get(unit_lower, unit_lower)

    def calculate_unit_price(
        self, price: float, size: float, unit_type: str
    ) -> float:
        """Calculate price per unit.

        Args:
            price: Total price
            size: Size value
            unit_type: Unit type (oz, lb, etc.)

        Returns:
            Price per unit
        """
        if size <= 0:
            return price

        normalized_unit = self.normalize_unit(unit_type)
        return round(price / size, 4)

    def find_best_match(
        self, query: str, limit: int = 1
    ) -> Optional[dict[str, Any]]:
        """Find the best matching product for a query string.

        Args:
            query: Product name to search for
            limit: Maximum number of results to return

        Returns:
            Best matching product or None if no match above threshold
        """
        matches = self.find_matches(query, limit=limit)
        return matches[0] if matches else None

    def find_matches(
        self, query: str, limit: int = 5
    ) -> list[dict[str, Any]]:
        """Find matching products for a query string.

        Args:
            query: Product name to search for
            limit: Maximum number of results to return

        Returns:
            List of matching products with scores
        """
        self._load_products()

        if not self._product_cache or not self._name_cache:
            return []

        # Normalize the query
        normalized_query = self._normalize_name(query)

        # Use rapidfuzz to find matches
        results = process.extract(
            normalized_query,
            self._name_cache,
            scorer=fuzz.token_sort_ratio,
            limit=limit,
        )

        matches = []
        for name, score, idx in results:
            if score >= self.min_score:
                product = self._product_cache[idx]
                matches.append({
                    "product_id": product.id,
                    "product_name": product.name,
                    "brand": product.brand,
                    "category": product.category,
                    "score": score,
                    "upc": product.upc,
                })

        return matches

    def match_by_upc(self, upc: str) -> Optional[dict[str, Any]]:
        """Find a product by UPC code.

        Args:
            upc: UPC code to search for

        Returns:
            Matching product or None
        """
        product = self.db.query(Product).filter(Product.upc == upc).first()

        if product:
            return {
                "product_id": product.id,
                "product_name": product.name,
                "brand": product.brand,
                "category": product.category,
                "score": 100.0,
                "upc": product.upc,
            }

        return None

    def get_similar_products(
        self, product_id: int, limit: int = 5
    ) -> list[dict[str, Any]]:
        """Find products similar to a given product.

        Args:
            product_id: ID of the reference product
            limit: Maximum number of results to return

        Returns:
            List of similar products with scores
        """
        self._load_products()

        if not self._product_cache:
            return []

        # Find the reference product
        reference = None
        for product in self._product_cache:
            if product.id == product_id:
                reference = product
                break

        if not reference:
            return []

        # Search for similar products by name
        normalized_name = self._normalize_name(reference.name, reference.brand)

        results = process.extract(
            normalized_name,
            self._name_cache,
            scorer=fuzz.token_sort_ratio,
            limit=limit + 1,  # +1 to exclude self
        )

        matches = []
        for name, score, idx in results:
            product = self._product_cache[idx]
            if product.id != product_id and score >= self.min_score:
                matches.append({
                    "product_id": product.id,
                    "product_name": product.name,
                    "brand": product.brand,
                    "category": product.category,
                    "score": score,
                    "upc": product.upc,
                })

        return matches[:limit]

    def refresh_cache(self) -> None:
        """Clear and reload the product cache."""
        self._product_cache = None
        self._name_cache = None
        self._load_products()
