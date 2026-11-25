"""Tests for structured logging fields used by Loki queries."""

import json
import logging


def test_json_logs_include_service_identity() -> None:
    handler = logging.getLogger().handlers[0]
    record = logging.LogRecord(
        name="api-test",
        level=logging.INFO,
        pathname=__file__,
        lineno=1,
        msg="hello",
        args=(),
        exc_info=None,
    )
    payload = json.loads(handler.formatter.format(record))

    assert payload["service"] == "platformbox-api"
    assert payload["environment"] == "dev"
    assert payload["version"] == "0.1.0"
    assert payload["level"] == "INFO"
    assert payload["message"] == "hello"
