"""Health and readiness endpoints."""

import logging

from fastapi import APIRouter, Response, status

from config import settings
from db import check_database
from redis_client import check_redis

router = APIRouter()
logger = logging.getLogger(__name__)


@router.get("/health", tags=["health"])
def health() -> dict[str, str]:
    """Liveness probe: the process is alive."""
    return {"status": "ok", "service": settings.service_name}


@router.get("/ready", tags=["health"])
def ready(response: Response) -> dict[str, str]:
    """Readiness probe: dependencies are reachable."""
    try:
        check_database()
        check_redis()
    except Exception as exc:  # noqa: BLE001 - readiness must not crash the process
        logger.warning("readiness check failed: %s", exc)
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
        return {"status": "not_ready", "service": settings.service_name}
    return {"status": "ready", "service": settings.service_name}
