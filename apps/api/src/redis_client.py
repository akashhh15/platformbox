"""Redis connectivity helpers."""

import logging

import redis
from tenacity import retry, stop_after_attempt, wait_exponential

from config import settings

logger = logging.getLogger(__name__)

_client: redis.Redis | None = None


def get_redis() -> redis.Redis:
    """Return a lazily-created Redis client."""
    global _client
    if _client is None:
        _client = redis.from_url(settings.redis_url, decode_responses=True, socket_timeout=2.0)
    return _client


@retry(stop=stop_after_attempt(5), wait=wait_exponential(multiplier=1, min=1, max=8), reraise=True)
def check_redis() -> None:
    """Raise if Redis is unreachable."""
    get_redis().ping()


def close_redis() -> None:
    """Close the Redis client on shutdown."""
    global _client
    if _client is not None:
        _client.close()
        _client = None
        logger.info("redis client closed")
