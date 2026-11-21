"""Shared pytest fixtures for the API tests."""

import os

# Configure settings before importing the app.
os.environ.setdefault("DATABASE_URL", "postgresql+psycopg://app:app@localhost:5432/app")
os.environ.setdefault("REDIS_URL", "redis://localhost:6379/0")
os.environ.setdefault("LOG_LEVEL", "WARNING")

import pytest
from fastapi.testclient import TestClient

from main import app


@pytest.fixture
def client() -> TestClient:
    """A test client with dependency checks stubbed out."""
    with TestClient(app) as c:
        yield c
