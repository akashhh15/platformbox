"""Background worker that consumes jobs from a Redis list."""

import asyncio
import json
import logging

from config import settings
from metrics import JOB_DURATION_SECONDS, JOBS_TOTAL, QUEUE_DEPTH
from redis_client import get_redis

logger = logging.getLogger(__name__)

_processed_count = 0
_running = False


def processed_count() -> int:
    """Number of jobs processed since startup."""
    return _processed_count


async def run_worker(stop_event: asyncio.Event) -> None:
    """Consume jobs from the configured Redis list until stop_event is set."""
    global _processed_count, _running
    _running = True
    logger.info("worker started", extra={"queue": settings.job_queue})
    redis_client = get_redis()
    while not stop_event.is_set():
        try:
            depth = redis_client.llen(settings.job_queue)
            QUEUE_DEPTH.labels(settings.job_queue).set(max(depth, 0))
            item = redis_client.lpop(settings.job_queue)
            if item is not None:
                _processed_count += 1
                with JOB_DURATION_SECONDS.labels(settings.job_queue).time():
                    try:
                        payload = json.loads(item)
                    except (ValueError, TypeError):
                        logger.warning("job is not valid JSON", extra={"job": item})
                        JOBS_TOTAL.labels(settings.job_queue, "invalid_json").inc()
                    else:
                        # Placeholder processing step.
                        logger.debug("job payload", extra={"payload": payload})
                        JOBS_TOTAL.labels(settings.job_queue, "success").inc()
                logger.info("processed job", extra={"job": item, "count": _processed_count})
            else:
                await asyncio.sleep(settings.poll_interval_seconds)
        except Exception as exc:  # noqa: BLE001 - worker must not crash on transient errors
            logger.warning("worker loop error: %s", exc)
            await asyncio.sleep(settings.poll_interval_seconds)
    _running = False
    logger.info("worker stopped", extra={"processed": _processed_count})


def is_running() -> bool:
    """Whether the worker loop is currently running."""
    return _running
