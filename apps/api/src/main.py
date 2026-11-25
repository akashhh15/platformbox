"""FastAPI application entrypoint."""

from contextlib import asynccontextmanager

from fastapi import FastAPI
from prometheus_fastapi_instrumentator import Instrumentator

from config import settings
from db import close_database
from logging_config import configure_logging, get_logger
from redis_client import close_redis
from routes import chaos, health, items

configure_logging()
logger = get_logger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown hooks."""
    logger.info("starting %s", settings.service_name)
    yield
    close_database()
    close_redis()
    logger.info("stopped %s", settings.service_name)


app = FastAPI(
    title="Platform in a Box - API",
    version="0.1.0",
    lifespan=lifespan,
)

Instrumentator().instrument(app).expose(app, endpoint="/metrics")

app.include_router(health.router)
app.include_router(items.router)
app.include_router(chaos.router)


@app.get("/", tags=["root"])
def root() -> dict[str, str]:
    """Service metadata."""
    return {
        "service": settings.service_name,
        "environment": settings.environment,
        "version": settings.service_version,
    }
