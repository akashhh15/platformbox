"""Tests for the opt-in fault injection endpoint."""

from unittest.mock import patch

from fastapi.testclient import TestClient


def test_fault_injection_disabled_by_default(client: TestClient) -> None:
    with patch("routes.chaos.settings.fault_injection_enabled", False):
        response = client.post("/chaos/fail")
    assert response.status_code == 404


def test_fault_injection_enabled(client: TestClient) -> None:
    with patch("routes.chaos.settings.fault_injection_enabled", True):
        response = client.post("/chaos/fail")
    assert response.status_code == 503
    assert response.json() == {"status": "injected_failure"}
