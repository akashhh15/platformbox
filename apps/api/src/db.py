"""PostgreSQL connectivity helpers."""

import logging

from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine
from tenacity import retry, stop_after_attempt, wait_exponential

from config import settings

logger = logging.getLogger(__name__)

_engine: Engine | None = None


def get_engine() -> Engine:
    """Return a lazily-created SQLAlchemy engine."""
    global _engine
    if _engine is None:
        _engine = create_engine(
            settings.database_url,
            pool_pre_ping=True,
            pool_size=5,
            max_overflow=10,
        )
    return _engine


@retry(stop=stop_after_attempt(5), wait=wait_exponential(multiplier=1, min=1, max=8), reraise=True)
def check_database() -> None:
    """Raise if the database is unreachable."""
    with get_engine().connect() as conn:
        conn.execute(text("SELECT 1"))


def close_database() -> None:
    """Dispose of the engine on shutdown."""
    global _engine
    if _engine is not None:
        _engine.dispose()
        _engine = None
        logger.info("database engine disposed")
