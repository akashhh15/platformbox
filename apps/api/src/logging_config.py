"""Structured JSON logging setup."""

import logging
import sys

from pythonjsonlogger import jsonlogger

from config import settings


def configure_logging() -> None:
    """Configure the root logger to emit JSON lines."""
    root = logging.getLogger()
    root.setLevel(settings.log_level.upper())

    # Remove any pre-existing handlers so we don't double-log.
    for handler in list(root.handlers):
        root.removeHandler(handler)

    handler = logging.StreamHandler(sys.stdout)
    formatter = jsonlogger.JsonFormatter(
        "%(asctime)s %(name)s %(levelname)s %(message)s",
        rename_fields={"asctime": "timestamp", "levelname": "level"},
        static_fields={
            "service": settings.service_name,
            "environment": settings.environment,
            "version": settings.service_version,
        },
    )
    handler.setFormatter(formatter)
    root.addHandler(handler)


def get_logger(name: str) -> logging.Logger:
    """Return a module-level logger."""
    return logging.getLogger(name)
