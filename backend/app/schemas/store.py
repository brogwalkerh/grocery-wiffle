"""Store Pydantic schemas."""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class StoreBase(BaseModel):
    """Base store schema."""

    name: str = Field(..., min_length=1, max_length=200, description="Store name")
    chain: str = Field(..., min_length=1, max_length=100, description="Store chain name")
    address: Optional[str] = Field(None, max_length=500, description="Store address")
    zip_code: str = Field(..., min_length=5, max_length=10, description="ZIP code")
    lat: Optional[float] = Field(None, ge=-90, le=90, description="Latitude")
    lng: Optional[float] = Field(None, ge=-180, le=180, description="Longitude")


class StoreCreate(StoreBase):
    """Schema for creating a store."""

    pass


class StoreUpdate(BaseModel):
    """Schema for updating a store."""

    name: Optional[str] = Field(None, min_length=1, max_length=200)
    chain: Optional[str] = Field(None, min_length=1, max_length=100)
    address: Optional[str] = Field(None, max_length=500)
    zip_code: Optional[str] = Field(None, min_length=5, max_length=10)
    lat: Optional[float] = Field(None, ge=-90, le=90)
    lng: Optional[float] = Field(None, ge=-180, le=180)


class StoreResponse(StoreBase):
    """Schema for store response."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    created_at: datetime
    updated_at: datetime
