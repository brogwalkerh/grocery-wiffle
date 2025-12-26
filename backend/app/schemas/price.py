"""Price Pydantic schemas."""

from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class PriceBase(BaseModel):
    """Base price schema."""

    product_id: int = Field(..., description="Product ID")
    store_id: int = Field(..., description="Store ID")
    price: float = Field(..., gt=0, description="Regular price")
    sale_price: Optional[float] = Field(None, gt=0, description="Sale price if applicable")
    unit_price: Optional[float] = Field(None, gt=0, description="Price per unit")
    effective_date: date = Field(..., description="Date when price becomes effective")
    expiration_date: Optional[date] = Field(None, description="Date when sale price expires")


class PriceCreate(PriceBase):
    """Schema for creating a price entry."""

    pass


class PriceResponse(PriceBase):
    """Schema for price response."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    created_at: datetime
    updated_at: datetime


class StorePrice(BaseModel):
    """Schema for store price in comparison results."""

    store_id: int
    store_name: str
    store_chain: str
    regular_price: float
    current_price: float
    is_on_sale: bool = False
    sale_expires: Optional[date] = None
    unit_price: Optional[float] = None
    product_size: Optional[str] = None
    calculated_total: Optional[float] = None
    is_estimate: bool = False


class ItemPriceComparison(BaseModel):
    """Schema for item-level price comparison."""

    item_name: str
    product_id: Optional[int] = None
    quantity: float
    unit: Optional[str] = None
    match_confidence: float = Field(..., ge=0, le=100)
    prices_by_store: list[StorePrice]
    cheapest_store_id: Optional[int] = None


class StoreTotalComparison(BaseModel):
    """Schema for store total in comparison results."""

    store_id: int
    store_name: str
    store_chain: str
    store_address: Optional[str] = None
    total_price: float
    items_found: int
    items_on_sale: int
    is_cheapest: bool = False
    has_all_items: bool = False
    estimated_drive_time_minutes: Optional[int] = None
    distance_miles: Optional[float] = None


class ComparisonRequest(BaseModel):
    """Schema for comparison request."""

    list_id: int = Field(..., description="Grocery list ID to compare")
    zip_code: str = Field(..., min_length=5, max_length=10, description="ZIP code for store lookup")
    max_drive_time_minutes: int = Field(15, ge=5, le=60, description="Maximum drive time in minutes")


class ComparisonResponse(BaseModel):
    """Schema for comparison response."""

    list_id: int
    list_name: str
    zip_code: str
    total_items: int = Field(..., description="Total number of items in the list")
    store_totals: list[StoreTotalComparison]
    item_breakdown: list[ItemPriceComparison]
    cheapest_store_id: Optional[int] = None
    cheapest_complete_store_id: Optional[int] = Field(None, description="Cheapest store with all items")
    potential_savings: float = Field(..., description="Savings compared to most expensive option")
