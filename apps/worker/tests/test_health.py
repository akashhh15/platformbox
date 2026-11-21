"""Tests for worker health and stats endpoints."""

from unittest.mock import patch

from fastapi.testclient import TestClient


def test_root(client: TestClient) -> None:
    response = client.get("/")
    assert response.status_code == 200
    body = response.json()
    assert body["service"] == "platformbox-worker"
    assert "processed" in body


def test_health(client: TestClient) -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_ready_ok(client: TestClient) -> None:
    with patch("main.check_redis"):
        response = client.get("/ready")
    assert response.status_code == 200
    assert response.json()["status"] == "ready"


def test_ready_not_ready(client: TestClient) -> None:
    with patch("main.check_redis", side_effect=RuntimeError("redis down")):
        response = client.get("/ready")
    assert response.status_code == 503
    assert response.json()["status"] == "not_ready"


def test_stats(client: TestClient) -> None:
    response = client.get("/stats")
    assert response.status_code == 200
    body = response.json()
    assert body["running"] is True
    assert isinstance(body["processed"], int)


def test_metrics(client: TestClient) -> None:
    response = client.get("/metrics")
    assert response.status_code == 200
    assert len(response.text) > 0
