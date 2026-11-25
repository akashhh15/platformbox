"""FastAPI application entrypoint for the worker."""

import asyncio
from contextlib import asynccontextmanager

from fastapi import FastAPI, Response, status
from prometheus_fastapi_instrumentator import Instrumentator

from config import settings
from logging_config import configure_logging, get_logger
from redis_client import check_redis, close_redis
from worker import is_running, processed_count, run_worker

configure_logging()
logger = get_logger(__name__)

_stop_event: asyncio.Event | None = None
_worker_task: asyncio.Task | None = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Start the background worker on startup, stop it on shutdown."""
    global _stop_event, _worker_task
    _stop_event = asyncio.Event()
    _worker_task = asyncio.create_task(run_worker(_stop_event))
    logger.info("starting %s", settings.service_name)
    yield
    if _stop_event is not None:
        _stop_event.set()
    if _worker_task is not None:
        await _worker_task
    close_redis()
    logger.info("stopped %s", settings.service_name)


app = FastAPI(
    title="Platform in a Box - Worker",
    version="0.1.0",
    lifespan=lifespan,
)

Instrumentator().instrument(app).expose(app, endpoint="/metrics")

logger = get_logger(__name__)


@app.get("/", tags=["root"])
def root() -> dict[str, str | int]:
    """Service metadata."""
    return {
        "service": settings.service_name,
        "environment": settings.environment,
        "version": settings.service_version,
        "processed": processed_count(),
    }


@app.get("/health", tags=["health"])
def health() -> dict[str, str]:
    """Liveness probe."""
    return {"status": "ok", "service": settings.service_name}


@app.get("/ready", tags=["health"])
def ready(response: Response) -> dict[str, str]:
    """Readiness probe: Redis is reachable."""
    try:
        check_redis()
    except Exception as exc:  # noqa: BLE001
        logger.warning("readiness check failed: %s", exc)
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
        return {"status": "not_ready", "service": settings.service_name}
    return {"status": "ready", "service": settings.service_name}


@app.get("/stats", tags=["stats"])
def stats() -> dict[str, object]:
    """Worker statistics."""
    return {
        "service": settings.service_name,
        "running": is_running(),
        "processed": processed_count(),
    }
