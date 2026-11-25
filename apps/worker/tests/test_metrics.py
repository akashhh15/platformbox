"""Tests for worker-specific Prometheus metrics."""

from fastapi.testclient import TestClient


def test_metrics_exposes_worker_instruments(client: TestClient) -> None:
    client.get("/")
    response = client.get("/metrics")

    assert response.status_code == 200
    assert "platformbox_worker_queue_depth{" in response.text
    assert "platformbox_worker_jobs_total{" in response.text
    assert "platformbox_worker_job_duration_seconds_bucket{" in response.text
