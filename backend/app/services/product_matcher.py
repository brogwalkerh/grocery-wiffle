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

    def __init__(self, db: Session, min_score: float = 50.0):
        """Initialize the product matcher.

        Args:
            db: SQLAlchemy database session
            min_score: Minimum matching score (0-100) to consider a match
        """
        self.db = db
        self.min_score = min_score
        self._product_cache: Optional[list[Product]] = None
        self._name_cache: Optional[list[str]] = None
        
        # Common item aliases for better matching
        self._aliases: dict[str, list[str]] = {
            "milk": ["whole milk", "2% milk", "skim milk", "1% milk"],
            "eggs": ["large eggs", "eggs dozen", "medium eggs"],
            "bread": ["white bread", "wheat bread", "whole wheat bread"],
            "chicken": ["chicken breast", "chicken thighs", "whole chicken"],
            "beef": ["ground beef", "ground beef 80/20", "beef steak"],
            "cheese": ["cheddar cheese", "american cheese", "shredded cheese"],
            "butter": ["butter", "unsalted butter"],
            "yogurt": ["greek yogurt", "plain yogurt"],
            "juice": ["orange juice", "apple juice"],
            "cereal": ["cheerios", "frosted flakes", "corn flakes"],
            "chips": ["potato chips", "tortilla chips"],
            "cookies": ["oreo cookies", "chocolate chip cookies"],
            "apples": ["red apples", "green apples", "gala apples"],
            "potatoes": ["russet potatoes", "red potatoes", "yukon gold potatoes"],
            "onions": ["yellow onions", "red onions", "white onions"],
            "spinach": ["baby spinach", "fresh spinach"],
            "soup": ["chicken noodle soup", "tomato soup"],
            "beans": ["black beans", "pinto beans", "kidney beans"],
            "tomatoes": ["diced tomatoes", "crushed tomatoes", "tomato sauce"],
            "soda": ["coca-cola", "pepsi", "sprite"],
            "coke": ["coca-cola"],
            "cola": ["coca-cola"],
            "cream cheese": ["cream cheese", "philadelphia cream cheese"],
            "sour cream": ["sour cream", "daisy sour cream"],
        }

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
        query_lower = query.lower().strip()
        
        # Check if query matches an alias - if so, search for the alias targets
        alias_queries = [normalized_query]
        if query_lower in self._aliases:
            alias_queries.extend([self._normalize_name(a) for a in self._aliases[query_lower]])

        # Collect all matches across query variations
        all_results = []
        for q in alias_queries:
            results = process.extract(
                q,
                self._name_cache,
                scorer=fuzz.token_sort_ratio,
                limit=limit,
            )
            all_results.extend(results)
        
        # Also try partial ratio for short queries (better for "milk" matching "whole milk")
        if len(query_lower) <= 6:
            partial_results = process.extract(
                normalized_query,
                self._name_cache,
                scorer=fuzz.partial_ratio,
                limit=limit,
            )
            all_results.extend(partial_results)

        # Deduplicate by index, keeping highest score
        best_by_idx: dict[int, tuple[str, float]] = {}
        for name, score, idx in all_results:
            if idx not in best_by_idx or score > best_by_idx[idx][1]:
                best_by_idx[idx] = (name, score)

        matches = []
        for idx, (name, score) in best_by_idx.items():
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

        # Sort by score descending
        matches.sort(key=lambda x: x["score"], reverse=True)
        return matches[:limit]

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
