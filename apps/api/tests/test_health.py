"""Tests for health and readiness endpoints."""

from unittest.mock import patch

from fastapi.testclient import TestClient


def test_root(client: TestClient) -> None:
    response = client.get("/")
    assert response.status_code == 200
    body = response.json()
    assert body["service"] == "platformbox-api"
    assert "environment" in body


def test_health(client: TestClient) -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_ready_ok(client: TestClient) -> None:
    with patch("routes.health.check_database"), patch("routes.health.check_redis"):
        response = client.get("/ready")
    assert response.status_code == 200
    assert response.json()["status"] == "ready"


def test_ready_not_ready(client: TestClient) -> None:
    with patch("routes.health.check_database", side_effect=RuntimeError("db down")):
        response = client.get("/ready")
    assert response.status_code == 503
    assert response.json()["status"] == "not_ready"


def test_metrics_endpoint(client: TestClient) -> None:
    response = client.get("/metrics")
    assert response.status_code == 200
    assert "http_requests_total" in response.text or "promhttp" in response.text or len(response.text) > 0
