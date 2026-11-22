"""Sample items endpoint backed by Postgres and Redis."""

import logging
import uuid
from datetime import UTC, datetime

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import text

from db import get_engine
from redis_client import get_redis

router = APIRouter(prefix="/items", tags=["items"])
logger = logging.getLogger(__name__)


class ItemCreate(BaseModel):
    """Payload for creating an item."""

    name: str = Field(min_length=1, max_length=100)
    description: str = Field(default="", max_length=500)


class Item(BaseModel):
    """An item stored in the database."""

    id: str
    name: str
    description: str
    created_at: str


@router.post("", response_model=Item, status_code=201)
def create_item(payload: ItemCreate) -> Item:
    """Create an item and cache it in Redis."""
    item_id = str(uuid.uuid4())
    now = datetime.now(UTC).isoformat()
    with get_engine().begin() as conn:
        conn.execute(
            text(
                "INSERT INTO items (id, name, description, created_at) "
                "VALUES (:id, :name, :description, :created_at)"
            ),
            {
                "id": item_id,
                "name": payload.name,
                "description": payload.description,
                "created_at": now,
            },
        )
    get_redis().set(f"item:{item_id}", payload.name, ex=300)
    logger.info("item created", extra={"item_id": item_id})
    return Item(id=item_id, name=payload.name, description=payload.description, created_at=now)


@router.get("/{item_id}", response_model=Item)
def get_item(item_id: str) -> Item:
    """Fetch an item by id."""
    with get_engine().connect() as conn:
        row = conn.execute(
            text("SELECT id, name, description, created_at FROM items WHERE id = :id"),
            {"id": item_id},
        ).fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="item not found")
    return Item(id=row[0], name=row[1], description=row[2], created_at=row[3])


@router.get("", response_model=list[Item])
def list_items(limit: int = 50) -> list[Item]:
    """List items (newest first)."""
    with get_engine().connect() as conn:
        rows = conn.execute(
            text(
                "SELECT id, name, description, created_at FROM items "
                "ORDER BY created_at DESC LIMIT :limit"
            ),
            {"limit": limit},
        ).fetchall()
    return [Item(id=r[0], name=r[1], description=r[2], created_at=r[3]) for r in rows]
