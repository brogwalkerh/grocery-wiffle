"""Product Pydantic schemas."""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class ProductBase(BaseModel):
    """Base product schema."""

    name: str = Field(..., min_length=1, max_length=255, description="Product name")
    brand: Optional[str] = Field(None, max_length=100, description="Product brand")
    category: Optional[str] = Field(None, max_length=100, description="Product category")
    upc: Optional[str] = Field(None, max_length=20, description="Universal Product Code")
    unit_size: Optional[float] = Field(None, gt=0, description="Unit size value")
    unit_type: Optional[str] = Field(None, max_length=20, description="Unit type (oz, lb, count, etc.)")


class ProductCreate(ProductBase):
    """Schema for creating a product."""

    pass


class ProductUpdate(BaseModel):
    """Schema for updating a product."""

    name: Optional[str] = Field(None, min_length=1, max_length=255)
    brand: Optional[str] = Field(None, max_length=100)
    category: Optional[str] = Field(None, max_length=100)
    upc: Optional[str] = Field(None, max_length=20)
    unit_size: Optional[float] = Field(None, gt=0)
    unit_type: Optional[str] = Field(None, max_length=20)


class ProductResponse(ProductBase):
    """Schema for product response."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    created_at: datetime
    updated_at: datetime


class ProductSearchResult(BaseModel):
    """Schema for product search results with matching score."""

    product: ProductResponse
    score: float = Field(..., ge=0, le=100, description="Match confidence score (0-100)")
