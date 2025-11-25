"""Grocery list database model."""

from datetime import datetime
from typing import TYPE_CHECKING, Optional

from sqlalchemy import DateTime, Float, ForeignKey, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.database import Base

if TYPE_CHECKING:
    from app.models.product import Product


class GroceryList(Base):
    """Grocery list model representing a user's shopping list."""

    __tablename__ = "grocery_lists"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    user_id: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    # Relationships
    items: Mapped[list["GroceryListItem"]] = relationship(
        "GroceryListItem", back_populates="grocery_list", cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:
        """String representation of the grocery list."""
        return f"<GroceryList(id={self.id}, name='{self.name}', user_id='{self.user_id}')>"


class GroceryListItem(Base):
    """Grocery list item model representing an item in a shopping list."""

    __tablename__ = "grocery_list_items"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    grocery_list_id: Mapped[int] = mapped_column(
        ForeignKey("grocery_lists.id", ondelete="CASCADE"), nullable=False, index=True
    )
    product_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("products.id"), nullable=True, index=True
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    quantity: Mapped[float] = mapped_column(Float, default=1.0, nullable=False)
    unit: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    notes: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    position: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    # Relationships
    grocery_list: Mapped["GroceryList"] = relationship("GroceryList", back_populates="items")
    product: Mapped[Optional["Product"]] = relationship("Product")

    def __repr__(self) -> str:
        """String representation of the grocery list item."""
        return f"<GroceryListItem(id={self.id}, name='{self.name}', quantity={self.quantity})>"
