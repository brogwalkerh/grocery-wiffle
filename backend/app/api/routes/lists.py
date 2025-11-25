"""Grocery list CRUD API routes."""

from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.deps import DbSession
from app.models.grocery_list import GroceryList, GroceryListItem
from app.schemas.grocery_list import (
    GroceryListCreate,
    GroceryListResponse,
    GroceryListSummary,
    GroceryListUpdate,
)

router = APIRouter()


@router.post(
    "/lists",
    response_model=GroceryListResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new grocery list",
    description="Create a new grocery list with optional initial items.",
)
def create_grocery_list(
    list_data: GroceryListCreate,
    db: DbSession,
) -> GroceryList:
    """Create a new grocery list."""
    grocery_list = GroceryList(
        name=list_data.name,
        user_id=list_data.user_id,
    )
    db.add(grocery_list)
    db.commit()
    db.refresh(grocery_list)

    # Add initial items if provided
    for i, item_data in enumerate(list_data.items):
        item = GroceryListItem(
            grocery_list_id=grocery_list.id,
            name=item_data.name,
            quantity=item_data.quantity,
            unit=item_data.unit,
            notes=item_data.notes,
            product_id=item_data.product_id,
            position=i,
        )
        db.add(item)

    db.commit()
    db.refresh(grocery_list)
    return grocery_list


@router.get(
    "/lists",
    response_model=list[GroceryListSummary],
    summary="Get all grocery lists",
    description="Get all grocery lists for a specific user.",
)
def get_grocery_lists(
    db: DbSession,
    user_id: str = Query(..., description="User ID to filter lists"),
    skip: int = Query(0, ge=0, description="Number of records to skip"),
    limit: int = Query(100, ge=1, le=100, description="Maximum number of records to return"),
) -> list[GroceryListSummary]:
    """Get all grocery lists for a user."""
    lists = (
        db.query(GroceryList)
        .filter(GroceryList.user_id == user_id)
        .offset(skip)
        .limit(limit)
        .all()
    )

    return [
        GroceryListSummary(
            id=grocery_list.id,
            name=grocery_list.name,
            user_id=grocery_list.user_id,
            item_count=len(grocery_list.items),
            created_at=grocery_list.created_at,
            updated_at=grocery_list.updated_at,
        )
        for grocery_list in lists
    ]


@router.get(
    "/lists/{list_id}",
    response_model=GroceryListResponse,
    summary="Get a specific grocery list",
    description="Get a specific grocery list by ID with all its items.",
)
def get_grocery_list(
    list_id: int,
    db: DbSession,
) -> GroceryList:
    """Get a specific grocery list by ID."""
    grocery_list = db.query(GroceryList).filter(GroceryList.id == list_id).first()

    if not grocery_list:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Grocery list with ID {list_id} not found",
        )

    return grocery_list


@router.put(
    "/lists/{list_id}",
    response_model=GroceryListResponse,
    summary="Update a grocery list",
    description="Update a grocery list name and/or replace all items.",
)
def update_grocery_list(
    list_id: int,
    list_data: GroceryListUpdate,
    db: DbSession,
) -> GroceryList:
    """Update a grocery list."""
    grocery_list = db.query(GroceryList).filter(GroceryList.id == list_id).first()

    if not grocery_list:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Grocery list with ID {list_id} not found",
        )

    # Update name if provided
    if list_data.name is not None:
        grocery_list.name = list_data.name

    # Replace items if provided
    if list_data.items is not None:
        # Delete existing items
        db.query(GroceryListItem).filter(
            GroceryListItem.grocery_list_id == list_id
        ).delete()

        # Add new items
        for i, item_data in enumerate(list_data.items):
            item = GroceryListItem(
                grocery_list_id=list_id,
                name=item_data.name,
                quantity=item_data.quantity,
                unit=item_data.unit,
                notes=item_data.notes,
                product_id=item_data.product_id,
                position=i,
            )
            db.add(item)

    db.commit()
    db.refresh(grocery_list)
    return grocery_list


@router.delete(
    "/lists/{list_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a grocery list",
    description="Delete a grocery list and all its items.",
)
def delete_grocery_list(
    list_id: int,
    db: DbSession,
) -> None:
    """Delete a grocery list."""
    grocery_list = db.query(GroceryList).filter(GroceryList.id == list_id).first()

    if not grocery_list:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Grocery list with ID {list_id} not found",
        )

    db.delete(grocery_list)
    db.commit()
