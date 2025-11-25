"""Pytest fixtures and configuration."""

from typing import Generator

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.db.database import Base
from app.models import Product


# Use SQLite in-memory database for tests
TEST_DATABASE_URL = "sqlite:///:memory:"


@pytest.fixture
def db_engine():
    """Create a test database engine."""
    engine = create_engine(
        TEST_DATABASE_URL,
        connect_args={"check_same_thread": False},
    )
    Base.metadata.create_all(bind=engine)
    yield engine
    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def db_session(db_engine) -> Generator[Session, None, None]:
    """Create a test database session."""
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=db_engine)
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()


@pytest.fixture
def sample_products(db_session: Session) -> list[Product]:
    """Create sample products for testing."""
    products = [
        Product(
            name="Whole Milk",
            brand="Organic Valley",
            category="Dairy",
            upc="093966000016",
            unit_size=1.0,
            unit_type="gallon",
        ),
        Product(
            name="2% Milk",
            brand="Horizon Organic",
            category="Dairy",
            upc="742365004148",
            unit_size=0.5,
            unit_type="gallon",
        ),
        Product(
            name="Large Eggs",
            brand="Eggland's Best",
            category="Dairy",
            upc="070097000289",
            unit_size=12.0,
            unit_type="count",
        ),
        Product(
            name="Cheerios",
            brand="General Mills",
            category="Cereal",
            upc="016000275287",
            unit_size=10.8,
            unit_type="oz",
        ),
        Product(
            name="Coca-Cola",
            brand="Coca-Cola",
            category="Beverages",
            upc="049000042566",
            unit_size=12.0,
            unit_type="count",
        ),
        Product(
            name="Frosted Flakes",
            brand="Kellogg's",
            category="Cereal",
            upc="038000001109",
            unit_size=13.5,
            unit_type="oz",
        ),
        Product(
            name="Chicken Breast",
            brand="Tyson",
            category="Meat",
            upc="023700014500",
            unit_size=1.0,
            unit_type="lb",
        ),
        Product(
            name="Bananas",
            brand=None,
            category="Produce",
            upc="4011",
            unit_size=1.0,
            unit_type="lb",
        ),
    ]

    for product in products:
        db_session.add(product)

    db_session.commit()

    for product in products:
        db_session.refresh(product)

    return products
