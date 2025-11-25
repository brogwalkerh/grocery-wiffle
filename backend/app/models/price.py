"""Price database model."""

from datetime import date, datetime
from typing import TYPE_CHECKING, Optional

from sqlalchemy import Date, DateTime, Float, ForeignKey, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.database import Base

if TYPE_CHECKING:
    from app.models.product import Product
    from app.models.store import Store


class Price(Base):
    """Price model representing a product price at a specific store."""

    __tablename__ = "prices"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    product_id: Mapped[int] = mapped_column(ForeignKey("products.id"), nullable=False, index=True)
    store_id: Mapped[int] = mapped_column(ForeignKey("stores.id"), nullable=False, index=True)
    price: Mapped[float] = mapped_column(Float, nullable=False)
    sale_price: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    unit_price: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    effective_date: Mapped[date] = mapped_column(Date, nullable=False)
    expiration_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    # Relationships
    product: Mapped["Product"] = relationship("Product", back_populates="prices")
    store: Mapped["Store"] = relationship("Store", back_populates="prices")

    @property
    def current_price(self) -> float:
        """Get the current effective price (sale price if available)."""
        if self.sale_price is not None and self.expiration_date:
            if date.today() <= self.expiration_date:
                return self.sale_price
        return self.price

    def __repr__(self) -> str:
        """String representation of the price."""
        return f"<Price(id={self.id}, product_id={self.product_id}, store_id={self.store_id}, price={self.price})>"
