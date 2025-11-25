"""Product database model."""

from datetime import datetime
from typing import TYPE_CHECKING, Optional

from sqlalchemy import DateTime, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.database import Base

if TYPE_CHECKING:
    from app.models.price import Price


class Product(Base):
    """Product model representing a grocery item."""

    __tablename__ = "products"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    brand: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    category: Mapped[Optional[str]] = mapped_column(String(100), nullable=True, index=True)
    upc: Mapped[Optional[str]] = mapped_column(String(20), nullable=True, unique=True, index=True)
    unit_size: Mapped[Optional[float]] = mapped_column(nullable=True)
    unit_type: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    # Relationships
    prices: Mapped[list["Price"]] = relationship("Price", back_populates="product")

    def __repr__(self) -> str:
        """String representation of the product."""
        return f"<Product(id={self.id}, name='{self.name}', brand='{self.brand}')>"
