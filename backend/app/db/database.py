"""Database connection and session management."""

from collections.abc import Generator
from typing import Any

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from app.config import get_settings

settings = get_settings()


class Base(DeclarativeBase):
    """Base class for all database models."""

    pass


# Detect SQLite for connect args and async driver adjustment
is_sqlite = "sqlite" in settings.database_url
connect_args = {"check_same_thread": False} if is_sqlite else {}

# For sync engine, strip aiosqlite driver if present
sync_database_url = settings.database_url
if "+aiosqlite" in sync_database_url:
    sync_database_url = sync_database_url.replace("+aiosqlite", "")

# Sync engine/session (used by legacy paths)
engine = create_engine(
    sync_database_url,
    connect_args=connect_args,
    pool_pre_ping=True if not is_sqlite else False,
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Async engine/session (used by async services like price_crawler)
async_database_url = settings.database_url
if is_sqlite and "+aiosqlite" not in async_database_url:
    async_database_url = async_database_url.replace("sqlite", "sqlite+aiosqlite", 1)

async_engine = create_async_engine(async_database_url, future=True)
async_session_maker = async_sessionmaker(async_engine, expire_on_commit=False)


async def check_async_connection() -> bool:
    """Quickly check if async database connection can be established.

    Returns True if a connection can be opened, False otherwise.
    """
    from sqlalchemy import text
    try:
        async with async_engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
        return True
    except Exception:
        return False


def get_db() -> Generator[Session, Any, None]:
    """Get database session dependency."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def create_tables() -> None:
    """Create all database tables."""
    Base.metadata.create_all(bind=engine)


async def get_async_db() -> AsyncSession:
    """Async session dependency."""
    async with async_session_maker() as session:
        yield session
