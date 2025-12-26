"""Price comparison API routes."""

from fastapi import APIRouter, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import DbSession
from app.models.grocery_list import GroceryList
from app.models.price import Price
from app.models.product import Product
from app.models.store import Store
from app.schemas.price import (
    ComparisonRequest,
    ComparisonResponse,
    ItemPriceComparison,
    StorePrice,
    StoreTotalComparison,
)
from app.services.product_matcher import ProductMatcher
from app.services.store_discovery import (
    discover_stores_for_zip,
    ensure_stores_with_prices,
)

router = APIRouter()


@router.post(
    "/compare",
    response_model=ComparisonResponse,
    summary="Compare prices across stores",
    description="Compare prices for a grocery list across stores within drive time of a ZIP code.",
)
async def compare_prices(
    request: ComparisonRequest,
    db: DbSession,
) -> ComparisonResponse:
    """Compare prices for a grocery list across stores."""
    # Get the grocery list
    grocery_list = db.query(GroceryList).filter(GroceryList.id == request.list_id).first()

    if not grocery_list:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Grocery list with ID {request.list_id} not found",
        )

    # Discover stores within drive time
    nearby_stores = await discover_stores_for_zip(
        db, 
        request.zip_code, 
        request.max_drive_time_minutes
    )
    
    if not nearby_stores:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No stores found within {request.max_drive_time_minutes} minutes of ZIP code {request.zip_code}",
        )

    # Ensure stores have prices
    stores = [s[0] for s in nearby_stores]
    ensure_stores_with_prices(db, stores)

    # Create a mapping of store info with drive times
    store_drive_info = {s[0].id: (s[1], s[2]) for s in nearby_stores}  # store_id -> (distance, drive_time)

    # Initialize product matcher
    matcher = ProductMatcher(db)

    # Process each item in the list
    item_breakdowns: list[ItemPriceComparison] = []
    store_totals: dict[int, StoreTotalComparison] = {}

    # Initialize store totals
    for store in stores:
        distance, drive_time = store_drive_info.get(store.id, (None, None))
        store_totals[store.id] = StoreTotalComparison(
            store_id=store.id,
            store_name=store.name,
            store_chain=store.chain,
            store_address=store.address,
            total_price=0.0,
            items_found=0,
            items_on_sale=0,
            estimated_drive_time_minutes=drive_time,
            distance_miles=round(distance, 1) if distance else None,
        )

    for list_item in grocery_list.items:
        # Match product
        if list_item.product_id:
            product_id = list_item.product_id
            match_confidence = 100.0
        else:
            match = matcher.find_best_match(list_item.name)
            if match:
                product_id = match["product_id"]
                match_confidence = match["score"]
            else:
                product_id = None
                match_confidence = 0.0

        # Get prices for this product at each store
        prices_by_store: list[StorePrice] = []
        cheapest_price = float("inf")
        cheapest_store_id = None

        for store in stores:
            if product_id:
                price_entry = (
                    db.query(Price)
                    .filter(Price.product_id == product_id, Price.store_id == store.id)
                    .order_by(Price.effective_date.desc())
                    .first()
                )

                if price_entry:
                    current_price = price_entry.current_price
                    is_on_sale = (
                        price_entry.sale_price is not None
                        and current_price == price_entry.sale_price
                    )

                    item_total = current_price * list_item.quantity
                    
                    # Get product size info
                    product = db.query(Product).filter(Product.id == product_id).first()
                    product_size = None
                    if product and product.unit_size and product.unit_type:
                        product_size = f"{product.unit_size:g} {product.unit_type}"

                    store_price = StorePrice(
                        store_id=store.id,
                        store_name=store.name,
                        store_chain=store.chain,
                        regular_price=price_entry.price,
                        current_price=current_price,
                        is_on_sale=is_on_sale,
                        sale_expires=price_entry.expiration_date if is_on_sale else None,
                        unit_price=price_entry.unit_price,
                        product_size=product_size,
                        calculated_total=item_total,
                    )
                    prices_by_store.append(store_price)

                    # Update store totals
                    store_totals[store.id].total_price += item_total
                    store_totals[store.id].items_found += 1
                    if is_on_sale:
                        store_totals[store.id].items_on_sale += 1

                    # Track cheapest
                    if current_price < cheapest_price:
                        cheapest_price = current_price
                        cheapest_store_id = store.id

        item_comparison = ItemPriceComparison(
            item_name=list_item.name,
            product_id=product_id,
            quantity=list_item.quantity,
            unit=list_item.unit,
            match_confidence=match_confidence,
            prices_by_store=prices_by_store,
            cheapest_store_id=cheapest_store_id,
        )
        item_breakdowns.append(item_comparison)

    # Calculate total items in list
    total_items = len(grocery_list.items)
    
    # Mark stores that have all items
    for st in store_totals.values():
        st.has_all_items = st.items_found >= total_items

    # Determine cheapest store overall and cheapest complete store
    store_totals_list = list(store_totals.values())
    stores_with_items = [st for st in store_totals_list if st.items_found > 0]
    complete_stores = [st for st in stores_with_items if st.has_all_items]

    cheapest_overall_id = None
    cheapest_complete_id = None
    potential_savings = 0.0

    if stores_with_items:
        # Find overall cheapest
        stores_with_items.sort(key=lambda x: x.total_price)
        cheapest_overall_id = stores_with_items[0].store_id
        stores_with_items[0].is_cheapest = True

        if len(stores_with_items) > 1:
            potential_savings = stores_with_items[-1].total_price - stores_with_items[0].total_price

    if complete_stores:
        # Find cheapest among complete stores
        complete_stores.sort(key=lambda x: x.total_price)
        cheapest_complete_id = complete_stores[0].store_id

    # Sort store_totals_list: complete stores first (by price), then incomplete (by items found desc, then price)
    store_totals_list.sort(key=lambda x: (
        0 if x.has_all_items else 1,  # Complete stores first
        x.total_price if x.has_all_items else -x.items_found,  # Complete: by price, Incomplete: by items found (desc)
        x.total_price  # Then by price
    ))

    # Round totals to 2 decimal places
    for st in store_totals_list:
        st.total_price = round(st.total_price, 2)

    return ComparisonResponse(
        list_id=grocery_list.id,
        list_name=grocery_list.name,
        zip_code=request.zip_code,
        total_items=total_items,
        store_totals=store_totals_list,
        item_breakdown=item_breakdowns,
        cheapest_store_id=cheapest_overall_id,
        cheapest_complete_store_id=cheapest_complete_id,
        potential_savings=round(potential_savings, 2),
    )
