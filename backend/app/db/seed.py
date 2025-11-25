"""Database seed script with sample data."""

from datetime import date, timedelta
from typing import Optional

from sqlalchemy.orm import Session

from app.db.database import SessionLocal, create_tables
from app.models import GroceryList, GroceryListItem, Price, Product, Store


def create_sample_products(db: Session) -> list[Product]:
    """Create sample grocery products."""
    products_data = [
        # Dairy
        {"name": "Whole Milk", "brand": "Organic Valley", "category": "Dairy", "upc": "093966000016", "unit_size": 1.0, "unit_type": "gallon"},
        {"name": "2% Milk", "brand": "Horizon Organic", "category": "Dairy", "upc": "742365004148", "unit_size": 0.5, "unit_type": "gallon"},
        {"name": "Large Eggs", "brand": "Eggland's Best", "category": "Dairy", "upc": "070097000289", "unit_size": 12.0, "unit_type": "count"},
        {"name": "Greek Yogurt", "brand": "Chobani", "category": "Dairy", "upc": "818290010636", "unit_size": 5.3, "unit_type": "oz"},
        {"name": "Cheddar Cheese", "brand": "Tillamook", "category": "Dairy", "upc": "072830000314", "unit_size": 8.0, "unit_type": "oz"},
        # Bread & Bakery
        {"name": "White Bread", "brand": "Wonder", "category": "Bread", "upc": "045000100022", "unit_size": 20.0, "unit_type": "oz"},
        {"name": "Whole Wheat Bread", "brand": "Nature's Own", "category": "Bread", "upc": "072250017104", "unit_size": 20.0, "unit_type": "oz"},
        {"name": "Bagels", "brand": "Thomas'", "category": "Bread", "upc": "048121212230", "unit_size": 6.0, "unit_type": "count"},
        # Produce
        {"name": "Bananas", "brand": None, "category": "Produce", "upc": "4011", "unit_size": 1.0, "unit_type": "lb"},
        {"name": "Red Apples", "brand": None, "category": "Produce", "upc": "4016", "unit_size": 1.0, "unit_type": "lb"},
        {"name": "Baby Spinach", "brand": "Earthbound Farm", "category": "Produce", "upc": "032601505051", "unit_size": 5.0, "unit_type": "oz"},
        {"name": "Russet Potatoes", "brand": None, "category": "Produce", "upc": "4072", "unit_size": 5.0, "unit_type": "lb"},
        {"name": "Yellow Onions", "brand": None, "category": "Produce", "upc": "4093", "unit_size": 3.0, "unit_type": "lb"},
        # Meat
        {"name": "Chicken Breast", "brand": "Tyson", "category": "Meat", "upc": "023700014500", "unit_size": 1.0, "unit_type": "lb"},
        {"name": "Ground Beef 80/20", "brand": None, "category": "Meat", "upc": None, "unit_size": 1.0, "unit_type": "lb"},
        {"name": "Bacon", "brand": "Oscar Mayer", "category": "Meat", "upc": "044700079751", "unit_size": 16.0, "unit_type": "oz"},
        # Beverages
        {"name": "Coca-Cola", "brand": "Coca-Cola", "category": "Beverages", "upc": "049000042566", "unit_size": 12.0, "unit_type": "count"},
        {"name": "Orange Juice", "brand": "Tropicana", "category": "Beverages", "upc": "048500202822", "unit_size": 52.0, "unit_type": "oz"},
        {"name": "Coffee", "brand": "Folgers", "category": "Beverages", "upc": "025500000121", "unit_size": 30.6, "unit_type": "oz"},
        # Cereals
        {"name": "Cheerios", "brand": "General Mills", "category": "Cereal", "upc": "016000275287", "unit_size": 10.8, "unit_type": "oz"},
        {"name": "Frosted Flakes", "brand": "Kellogg's", "category": "Cereal", "upc": "038000001109", "unit_size": 13.5, "unit_type": "oz"},
        # Canned Goods
        {"name": "Chicken Noodle Soup", "brand": "Campbell's", "category": "Canned", "upc": "051000012524", "unit_size": 10.75, "unit_type": "oz"},
        {"name": "Diced Tomatoes", "brand": "Hunt's", "category": "Canned", "upc": "027000381458", "unit_size": 14.5, "unit_type": "oz"},
        {"name": "Black Beans", "brand": "Goya", "category": "Canned", "upc": "041331024099", "unit_size": 15.5, "unit_type": "oz"},
        # Snacks
        {"name": "Potato Chips", "brand": "Lay's", "category": "Snacks", "upc": "028400055840", "unit_size": 10.0, "unit_type": "oz"},
        {"name": "Oreo Cookies", "brand": "Nabisco", "category": "Snacks", "upc": "044000006150", "unit_size": 14.3, "unit_type": "oz"},
    ]

    products = []
    for data in products_data:
        product = Product(**data)
        db.add(product)
        products.append(product)

    db.commit()
    for product in products:
        db.refresh(product)
    return products


def create_sample_stores(db: Session) -> list[Store]:
    """Create sample store locations."""
    stores_data = [
        # Kroger family
        {"name": "Kroger - Main St", "chain": "Kroger", "address": "100 Main Street", "zip_code": "92101", "lat": 32.7157, "lng": -117.1611},
        {"name": "Ralphs - Downtown", "chain": "Kroger", "address": "200 Broadway", "zip_code": "92101", "lat": 32.7190, "lng": -117.1625},
        # Walmart
        {"name": "Walmart Supercenter", "chain": "Walmart", "address": "500 Commerce Way", "zip_code": "92101", "lat": 32.7220, "lng": -117.1580},
        {"name": "Walmart Neighborhood Market", "chain": "Walmart", "address": "350 Park Blvd", "zip_code": "92102", "lat": 32.7100, "lng": -117.1500},
        # Target
        {"name": "Target - Mission Valley", "chain": "Target", "address": "1400 Camino de la Reina", "zip_code": "92108", "lat": 32.7650, "lng": -117.1550},
        # Albertsons/Vons
        {"name": "Vons - Hillcrest", "chain": "Albertsons", "address": "711 University Ave", "zip_code": "92103", "lat": 32.7490, "lng": -117.1600},
        # Whole Foods
        {"name": "Whole Foods - Hillcrest", "chain": "Whole Foods", "address": "711 University Ave", "zip_code": "92103", "lat": 32.7495, "lng": -117.1605},
        # Trader Joe's
        {"name": "Trader Joe's - Pacific Beach", "chain": "Trader Joe's", "address": "1211 Garnet Ave", "zip_code": "92109", "lat": 32.7970, "lng": -117.2360},
    ]

    stores = []
    for data in stores_data:
        store = Store(**data)
        db.add(store)
        stores.append(store)

    db.commit()
    for store in stores:
        db.refresh(store)
    return stores


def create_sample_prices(db: Session, products: list[Product], stores: list[Store]) -> list[Price]:
    """Create sample price data for products at stores."""
    import random

    today = date.today()
    prices = []

    # Base prices for each product (roughly realistic)
    base_prices = {
        "Whole Milk": 5.99,
        "2% Milk": 5.49,
        "Large Eggs": 4.99,
        "Greek Yogurt": 1.49,
        "Cheddar Cheese": 4.99,
        "White Bread": 3.49,
        "Whole Wheat Bread": 4.29,
        "Bagels": 4.99,
        "Bananas": 0.59,
        "Red Apples": 1.99,
        "Baby Spinach": 4.99,
        "Russet Potatoes": 4.99,
        "Yellow Onions": 3.49,
        "Chicken Breast": 3.99,
        "Ground Beef 80/20": 5.99,
        "Bacon": 7.99,
        "Coca-Cola": 7.99,
        "Orange Juice": 4.99,
        "Coffee": 9.99,
        "Cheerios": 5.49,
        "Frosted Flakes": 4.99,
        "Chicken Noodle Soup": 1.99,
        "Diced Tomatoes": 1.49,
        "Black Beans": 1.29,
        "Potato Chips": 4.49,
        "Oreo Cookies": 5.49,
    }

    # Price variation by chain
    chain_multipliers = {
        "Kroger": 1.0,
        "Walmart": 0.95,  # Usually cheapest
        "Target": 1.02,
        "Albertsons": 1.05,
        "Whole Foods": 1.25,  # Premium
        "Trader Joe's": 0.98,
    }

    for product in products:
        base_price = base_prices.get(product.name, 3.99)

        for store in stores:
            multiplier = chain_multipliers.get(store.chain, 1.0)
            variation = random.uniform(0.95, 1.05)
            final_price = round(base_price * multiplier * variation, 2)

            # Some items are on sale
            sale_price: Optional[float] = None
            expiration: Optional[date] = None
            if random.random() < 0.2:  # 20% chance of sale
                sale_price = round(final_price * random.uniform(0.7, 0.9), 2)
                expiration = today + timedelta(days=random.randint(3, 14))

            price = Price(
                product_id=product.id,
                store_id=store.id,
                price=final_price,
                sale_price=sale_price,
                effective_date=today,
                expiration_date=expiration,
            )
            db.add(price)
            prices.append(price)

    db.commit()
    return prices


def create_sample_grocery_lists(db: Session, products: list[Product]) -> list[GroceryList]:
    """Create sample grocery lists."""
    grocery_lists = []

    # Sample list 1: Weekly basics
    list1 = GroceryList(name="Weekly Basics", user_id="demo_user_1")
    db.add(list1)
    db.commit()
    db.refresh(list1)

    items1 = [
        ("Whole Milk", 1.0, "gallon"),
        ("Large Eggs", 1.0, "dozen"),
        ("Bananas", 2.0, "lb"),
        ("White Bread", 1.0, "loaf"),
        ("Chicken Breast", 2.0, "lb"),
    ]

    for i, (name, qty, unit) in enumerate(items1):
        product = next((p for p in products if p.name == name), None)
        item = GroceryListItem(
            grocery_list_id=list1.id,
            product_id=product.id if product else None,
            name=name,
            quantity=qty,
            unit=unit,
            position=i,
        )
        db.add(item)

    # Sample list 2: BBQ prep
    list2 = GroceryList(name="BBQ Weekend", user_id="demo_user_1")
    db.add(list2)
    db.commit()
    db.refresh(list2)

    items2 = [
        ("Ground Beef 80/20", 3.0, "lb"),
        ("Potato Chips", 2.0, "bag"),
        ("Coca-Cola", 1.0, "pack"),
        ("Yellow Onions", 1.0, "bag"),
    ]

    for i, (name, qty, unit) in enumerate(items2):
        product = next((p for p in products if p.name == name), None)
        item = GroceryListItem(
            grocery_list_id=list2.id,
            product_id=product.id if product else None,
            name=name,
            quantity=qty,
            unit=unit,
            position=i,
        )
        db.add(item)

    db.commit()
    grocery_lists.extend([list1, list2])
    return grocery_lists


def seed_database() -> None:
    """Seed the database with sample data."""
    print("Creating database tables...")
    create_tables()

    db = SessionLocal()
    try:
        # Check if data already exists
        existing_products = db.query(Product).first()
        if existing_products:
            print("Database already contains data. Skipping seed.")
            return

        print("Creating sample products...")
        products = create_sample_products(db)
        print(f"Created {len(products)} products.")

        print("Creating sample stores...")
        stores = create_sample_stores(db)
        print(f"Created {len(stores)} stores.")

        print("Creating sample prices...")
        prices = create_sample_prices(db, products, stores)
        print(f"Created {len(prices)} price entries.")

        print("Creating sample grocery lists...")
        lists = create_sample_grocery_lists(db, products)
        print(f"Created {len(lists)} grocery lists.")

        print("Database seeding complete!")

    finally:
        db.close()


if __name__ == "__main__":
    seed_database()
