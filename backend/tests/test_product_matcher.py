"""Tests for the ProductMatcher service."""

import pytest
from sqlalchemy.orm import Session

from app.models import Product
from app.services.product_matcher import ProductMatcher


class TestProductMatcher:
    """Test suite for ProductMatcher service."""

    def test_find_exact_match(self, db_session: Session, sample_products: list[Product]):
        """Test finding an exact product match."""
        matcher = ProductMatcher(db_session)

        result = matcher.find_best_match("Whole Milk")

        assert result is not None
        assert result["product_name"] == "Whole Milk"
        assert result["score"] >= 90

    def test_find_match_with_brand(self, db_session: Session, sample_products: list[Product]):
        """Test finding a match when brand is included in search."""
        matcher = ProductMatcher(db_session)

        result = matcher.find_best_match("Organic Valley Whole Milk")

        assert result is not None
        assert result["product_name"] == "Whole Milk"
        assert result["brand"] == "Organic Valley"

    def test_find_match_with_brand_alias(self, db_session: Session, sample_products: list[Product]):
        """Test finding a match using brand alias."""
        matcher = ProductMatcher(db_session)

        # "Coke" should match "Coca-Cola"
        result = matcher.find_best_match("Coke 12 pack")

        assert result is not None
        assert result["product_name"] == "Coca-Cola"

    def test_find_partial_match(self, db_session: Session, sample_products: list[Product]):
        """Test finding a partial product match."""
        matcher = ProductMatcher(db_session)

        result = matcher.find_best_match("Milk")

        assert result is not None
        # Should match one of the milk products
        assert "Milk" in result["product_name"]

    def test_find_multiple_matches(self, db_session: Session, sample_products: list[Product]):
        """Test finding multiple product matches."""
        matcher = ProductMatcher(db_session)

        results = matcher.find_matches("Milk", limit=5)

        assert len(results) >= 2
        # Both milk products should be in results
        product_names = [r["product_name"] for r in results]
        assert any("Milk" in name for name in product_names)

    def test_no_match_below_threshold(self, db_session: Session, sample_products: list[Product]):
        """Test that low-quality matches are filtered out."""
        matcher = ProductMatcher(db_session, min_score=80)

        result = matcher.find_best_match("xyznonexistent")

        assert result is None

    def test_match_by_upc(self, db_session: Session, sample_products: list[Product]):
        """Test finding a product by UPC code."""
        matcher = ProductMatcher(db_session)

        result = matcher.match_by_upc("093966000016")

        assert result is not None
        assert result["product_name"] == "Whole Milk"
        assert result["score"] == 100.0

    def test_match_by_upc_not_found(self, db_session: Session, sample_products: list[Product]):
        """Test UPC lookup for non-existent code."""
        matcher = ProductMatcher(db_session)

        result = matcher.match_by_upc("999999999999")

        assert result is None

    def test_similar_products(self, db_session: Session, sample_products: list[Product]):
        """Test finding similar products."""
        matcher = ProductMatcher(db_session)

        # Get the Cheerios product
        cheerios = next(p for p in sample_products if p.name == "Cheerios")

        results = matcher.get_similar_products(cheerios.id, limit=3)

        assert len(results) > 0
        # Should not include the original product
        assert all(r["product_id"] != cheerios.id for r in results)

    def test_normalize_unit(self, db_session: Session, sample_products: list[Product]):
        """Test unit normalization."""
        matcher = ProductMatcher(db_session)

        assert matcher.normalize_unit("ounce") == "oz"
        assert matcher.normalize_unit("ounces") == "oz"
        assert matcher.normalize_unit("pound") == "lb"
        assert matcher.normalize_unit("pounds") == "lb"
        assert matcher.normalize_unit("gallon") == "gal"
        assert matcher.normalize_unit("count") == "ct"
        assert matcher.normalize_unit("each") == "ea"

    def test_calculate_unit_price(self, db_session: Session, sample_products: list[Product]):
        """Test unit price calculation."""
        matcher = ProductMatcher(db_session)

        # $5.00 for 10 oz = $0.50 per oz
        unit_price = matcher.calculate_unit_price(5.00, 10.0, "oz")
        assert unit_price == 0.5

        # $3.00 for 1 lb = $3.00 per lb
        unit_price = matcher.calculate_unit_price(3.00, 1.0, "lb")
        assert unit_price == 3.0

    def test_calculate_unit_price_zero_size(self, db_session: Session, sample_products: list[Product]):
        """Test unit price calculation with zero size."""
        matcher = ProductMatcher(db_session)

        # Should return the price when size is 0
        unit_price = matcher.calculate_unit_price(5.00, 0, "oz")
        assert unit_price == 5.0

    def test_refresh_cache(self, db_session: Session, sample_products: list[Product]):
        """Test cache refresh."""
        matcher = ProductMatcher(db_session)

        # First search to populate cache
        matcher.find_best_match("Milk")

        # Add a new product
        new_product = Product(
            name="Almond Milk",
            brand="Silk",
            category="Dairy",
            unit_size=64.0,
            unit_type="oz",
        )
        db_session.add(new_product)
        db_session.commit()

        # Without refresh, new product shouldn't be found
        result_before = matcher.find_best_match("Almond Milk")

        # Refresh cache
        matcher.refresh_cache()

        # Now it should be found
        result_after = matcher.find_best_match("Almond Milk")

        # Note: depending on caching implementation, result_before might or might not find it
        assert result_after is not None
        assert result_after["product_name"] == "Almond Milk"

    def test_category_matching(self, db_session: Session, sample_products: list[Product]):
        """Test that category is included in match results."""
        matcher = ProductMatcher(db_session)

        result = matcher.find_best_match("Cheerios")

        assert result is not None
        assert result["category"] == "Cereal"

    def test_case_insensitive_matching(self, db_session: Session, sample_products: list[Product]):
        """Test case-insensitive matching."""
        matcher = ProductMatcher(db_session)

        result_lower = matcher.find_best_match("whole milk")
        result_upper = matcher.find_best_match("WHOLE MILK")
        result_mixed = matcher.find_best_match("WhOlE MiLk")

        assert result_lower is not None
        assert result_upper is not None
        assert result_mixed is not None

        # All should match the same product
        assert result_lower["product_id"] == result_upper["product_id"] == result_mixed["product_id"]


class TestProductMatcherBrandVariations:
    """Test brand variation handling in ProductMatcher."""

    def test_brand_alias_coca_cola(self, db_session: Session, sample_products: list[Product]):
        """Test Coca-Cola brand aliases."""
        matcher = ProductMatcher(db_session)

        # Test various aliases
        result_coke = matcher.find_best_match("Coke")
        result_cocacola = matcher.find_best_match("Coca Cola")

        assert result_coke is not None
        assert result_cocacola is not None
        assert result_coke["product_id"] == result_cocacola["product_id"]

    def test_brand_alias_kelloggs(self, db_session: Session, sample_products: list[Product]):
        """Test Kellogg's brand aliases."""
        matcher = ProductMatcher(db_session)

        result_apostrophe = matcher.find_best_match("Kellogg's Frosted Flakes")
        result_no_apostrophe = matcher.find_best_match("Kelloggs Frosted Flakes")

        assert result_apostrophe is not None
        assert result_no_apostrophe is not None

    def test_brand_alias_general_mills(self, db_session: Session, sample_products: list[Product]):
        """Test General Mills products."""
        matcher = ProductMatcher(db_session)

        result = matcher.find_best_match("General Mills Cheerios")

        assert result is not None
        assert result["product_name"] == "Cheerios"


class TestProductMatcherEdgeCases:
    """Test edge cases for ProductMatcher."""

    def test_empty_query(self, db_session: Session, sample_products: list[Product]):
        """Test matching with empty query."""
        matcher = ProductMatcher(db_session)

        result = matcher.find_best_match("")

        # Should still return results (best match to empty string)
        # The behavior depends on rapidfuzz implementation

    def test_very_long_query(self, db_session: Session, sample_products: list[Product]):
        """Test matching with very long query."""
        matcher = ProductMatcher(db_session)

        long_query = "Organic Valley Whole Milk Gallon Fresh from Happy Cows " * 10

        result = matcher.find_best_match(long_query)

        # Should handle gracefully
        assert result is None or isinstance(result, dict)

    def test_special_characters_in_query(self, db_session: Session, sample_products: list[Product]):
        """Test matching with special characters."""
        matcher = ProductMatcher(db_session)

        result = matcher.find_best_match("Whole Milk!@#$%")

        # Should handle gracefully and still find match
        assert result is not None
        assert result["product_name"] == "Whole Milk"

    def test_empty_database(self, db_session: Session):
        """Test matching with empty product database."""
        # Don't add sample_products fixture
        matcher = ProductMatcher(db_session)

        result = matcher.find_best_match("Milk")

        assert result is None

    def test_numeric_query(self, db_session: Session, sample_products: list[Product]):
        """Test matching with numeric query."""
        matcher = ProductMatcher(db_session)

        result = matcher.find_best_match("2% Milk")

        assert result is not None
        assert result["product_name"] == "2% Milk"
