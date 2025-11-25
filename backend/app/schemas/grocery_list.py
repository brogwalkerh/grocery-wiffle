"""Grocery list Pydantic schemas."""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class GroceryListItemBase(BaseModel):
    """Base grocery list item schema."""

    name: str = Field(..., min_length=1, max_length=255, description="Item name")
    quantity: float = Field(1.0, gt=0, description="Quantity of the item")
    unit: Optional[str] = Field(None, max_length=20, description="Unit of measurement")
    notes: Optional[str] = Field(None, max_length=500, description="Additional notes")


class GroceryListItemCreate(GroceryListItemBase):
    """Schema for creating a grocery list item."""

    product_id: Optional[int] = Field(None, description="Linked product ID if matched")


class GroceryListItemUpdate(BaseModel):
    """Schema for updating a grocery list item."""

    name: Optional[str] = Field(None, min_length=1, max_length=255)
    quantity: Optional[float] = Field(None, gt=0)
    unit: Optional[str] = Field(None, max_length=20)
    notes: Optional[str] = Field(None, max_length=500)
    product_id: Optional[int] = None
    position: Optional[int] = None


class GroceryListItemResponse(GroceryListItemBase):
    """Schema for grocery list item response."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    grocery_list_id: int
    product_id: Optional[int]
    position: int
    created_at: datetime


class GroceryListBase(BaseModel):
    """Base grocery list schema."""

    name: str = Field(..., min_length=1, max_length=200, description="List name")


class GroceryListCreate(GroceryListBase):
    """Schema for creating a grocery list."""

    user_id: str = Field(..., min_length=1, max_length=100, description="User ID")
    items: list[GroceryListItemCreate] = Field(default_factory=list, description="Initial items")


class GroceryListUpdate(BaseModel):
    """Schema for updating a grocery list."""

    name: Optional[str] = Field(None, min_length=1, max_length=200)
    items: Optional[list[GroceryListItemCreate]] = None


class GroceryListResponse(GroceryListBase):
    """Schema for grocery list response."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: str
    created_at: datetime
    updated_at: datetime
    items: list[GroceryListItemResponse] = Field(default_factory=list)


class GroceryListSummary(BaseModel):
    """Schema for grocery list summary (without items)."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    user_id: str
    item_count: int
    created_at: datetime
    updated_at: datetime
