"""Tests for the items endpoint."""

from unittest.mock import MagicMock, patch

from fastapi.testclient import TestClient


def _mock_engine(rows=None, fetchone=None, fetchall=None):
    conn = MagicMock()
    conn.execute.return_value.fetchone.return_value = fetchone
    conn.execute.return_value.fetchall.return_value = fetchall or []
    engine = MagicMock()
    engine.begin.return_value.__enter__.return_value = conn
    engine.begin.return_value.__exit__.return_value = False
    engine.connect.return_value.__enter__.return_value = conn
    engine.connect.return_value.__exit__.return_value = False
    return engine, conn


def test_list_items_empty(client: TestClient) -> None:
    engine, conn = _mock_engine(fetchall=[])
    with patch("routes.items.get_engine", return_value=engine), patch("routes.items.get_redis"):
        response = client.get("/items")
    assert response.status_code == 200
    assert response.json() == []


def test_create_item(client: TestClient) -> None:
    engine, conn = _mock_engine()
    redis_mock = MagicMock()
    with (
        patch("routes.items.get_engine", return_value=engine),
        patch("routes.items.get_redis", return_value=redis_mock),
    ):
        response = client.post("/items", json={"name": "widget", "description": "a widget"})
    assert response.status_code == 201
    body = response.json()
    assert body["name"] == "widget"
    assert body["description"] == "a widget"
    assert "id" in body
    redis_mock.set.assert_called_once()


def test_create_item_validation(client: TestClient) -> None:
    response = client.post("/items", json={"name": ""})
    assert response.status_code == 422


def test_get_item_not_found(client: TestClient) -> None:
    engine, conn = _mock_engine(fetchone=None)
    with patch("routes.items.get_engine", return_value=engine), patch("routes.items.get_redis"):
        response = client.get("/items/does-not-exist")
    assert response.status_code == 404
