"""Circular (weekly ad) parser service."""

import re
from dataclasses import dataclass
from datetime import date, timedelta
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


class CircularParser:
    """Service for parsing weekly ad circulars from various sources.

    This is a scaffold for future implementation of circular parsing
    from various public sources.
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
        self.store_chain = store_chain

    def parse_flipp_data(self, data: dict[str, Any]) -> list[ParsedCircularItem]:
        """Parse circular data from Flipp API format.

        Args:
            data: Raw data from Flipp API

        Returns:
            List of parsed circular items

        Note:
            This is a stub. Implement when Flipp integration is available.
        """
        # TODO: Implement Flipp API parsing
        # Flipp provides weekly ad data in JSON format
        # Structure typically includes:
        # - flyer_items: list of sale items
        # - merchant: store information
        # - valid_from, valid_to: date range
        return []

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

        Note:
            This is the main entry point for getting circular data.
            Implement specific fetching logic based on store chain.
        """
        # TODO: Implement per-chain fetching
        # This would:
        # 1. Determine the data source for the chain
        # 2. Fetch the data (HTML, PDF, or API)
        # 3. Call the appropriate parser
        # 4. Return normalized items

        # For now, return mock data
        return self._get_mock_circular_data(store_chain, zip_code)

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
