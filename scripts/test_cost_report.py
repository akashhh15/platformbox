"""Unit tests for scripts/cost_report.py. No AWS calls are made."""

from __future__ import annotations

from datetime import date
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest
from cost_report import (
    END_MARKER,
    START_MARKER,
    fetch_cost_by_service,
    month_start,
    render_section,
    update_document,
)


def test_month_start() -> None:
    assert month_start(date(2026, 11, 26)) == date(2026, 11, 1)


def test_fetch_cost_by_service_paginates() -> None:
    client = MagicMock()
    client.get_cost_and_usage.side_effect = [
        {
            "ResultsByTime": [
                {
                    "Groups": [
                        {
                            "Keys": ["Amazon EC2"],
                            "Metrics": {"UnblendedCost": {"Amount": "12.5"}},
                        },
                        {
                            "Keys": ["Amazon S3"],
                            "Metrics": {"UnblendedCost": {"Amount": "1.25"}},
                        },
                    ]
                }
            ],
            "NextToken": "page-2",
        },
        {
            "ResultsByTime": [
                {
                    "Groups": [
                        {
                            "Keys": ["Amazon EC2"],
                            "Metrics": {"UnblendedCost": {"Amount": "2.5"}},
                        }
                    ]
                }
            ]
        },
    ]

    costs, requests = fetch_cost_by_service(
        client, "platformbox", date(2026, 11, 1), date(2026, 12, 1)
    )

    assert costs == {"Amazon EC2": 15.0, "Amazon S3": 1.25}
    assert requests == 2
    assert client.get_cost_and_usage.call_args_list[1].kwargs["NextToken"] == "page-2"
    assert client.get_cost_and_usage.call_args_list[0].kwargs["Filter"] == {
        "Tags": {"Key": "Project", "Values": ["platformbox"]}
    }


def test_render_section_contains_markers_and_request_count() -> None:
    section = render_section(
        {"Amazon EC2": 15.0}, "platformbox", date(2026, 11, 1), date(2026, 12, 1), 1
    )
    assert section.startswith(START_MARKER)
    assert section.endswith(END_MARKER)
    assert "| Amazon EC2 | 15.00 |" in section
    assert "Cost Explorer API requests for this report: 1" in section


def test_update_document_replaces_existing_section(tmp_path: Path) -> None:
    original = (
        "# Costs\n\nkeep this\n\n"
        + START_MARKER
        + "\nold\n"
        + END_MARKER
        + "\n\ntail\n"
    )
    updated = update_document(original, START_MARKER + "\nnew\n" + END_MARKER)
    assert "keep this" in updated
    assert "old" not in updated
    assert "tail" in updated
    assert "new" in updated


def test_update_document_appends_when_markers_absent() -> None:
    updated = update_document("# Costs\n", START_MARKER + "\nnew\n" + END_MARKER)
    assert updated.startswith("# Costs\n\n")
    assert updated.rstrip().endswith(END_MARKER)


def test_update_document_rejects_unbalanced_markers() -> None:
    with pytest.raises(ValueError, match="unbalanced"):
        update_document(START_MARKER + "\nonly start\n", "x")


def test_main_uses_boto3_client_and_writes_output(tmp_path: Path) -> None:
    from cost_report import main

    output = tmp_path / "costs.md"
    output.write_text("# Costs\n", encoding="utf-8")
    client = MagicMock()
    client.get_cost_and_usage.return_value = {
        "ResultsByTime": [
            {
                "Groups": [
                    {
                        "Keys": ["AWS Lambda"],
                        "Metrics": {"UnblendedCost": {"Amount": "0.42"}},
                    }
                ]
            }
        ]
    }
    with patch("cost_report.boto3.client", return_value=client) as mocked_client:
        code = main(
            [
                "--project",
                "platformbox",
                "--output",
                str(output),
                "--start",
                "2026-11-01",
                "--end",
                "2026-12-01",
            ]
        )

    assert code == 0
    mocked_client.assert_called_once_with("ce", region_name="us-east-1")
    assert "AWS Lambda" in output.read_text(encoding="utf-8")
