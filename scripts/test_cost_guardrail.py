"""Unit tests for scripts/cost_guardrail.py."""

from __future__ import annotations

from decimal import Decimal
from pathlib import Path

import pytest
from cost_guardrail import evaluate, main, parse_change, render_summary

INCREASE_COMMENT = """<h3>💰 Infracost report</h3>
<details><summary><b>Monthly estimate increased by $50 📈</b></summary>
<table><tbody><tr><td align="right">+$50 (+25%)</td></tr></tbody></table>
<details><summary>Estimate details</summary>
Monthly cost change for my-project
Amount:  +$50 ($200 → $250)
Percent: +25%
</details></details>
"""


def test_parse_change_prefers_explicit_percent() -> None:
    assert parse_change(INCREASE_COMMENT)[0] == Decimal(25)


def test_parse_change_falls_back_to_amount() -> None:
    comment = "<summary>Monthly estimate increased by $1,234.50</summary>"
    assert parse_change(comment) == (None, Decimal("1234.50"))


def test_parse_change_returns_none_for_unstructured_text() -> None:
    assert parse_change("no cost data") == (None, None)


def test_evaluate_blocks_at_threshold() -> None:
    outputs = evaluate(INCREASE_COMMENT, Decimal(10), Decimal(25))
    assert outputs["blocked"] == "true"
    assert outputs["warned"] == "false"
    assert outputs["status"] == "increased"


def test_evaluate_warns_between_thresholds() -> None:
    comment = INCREASE_COMMENT.replace("+25%", "+15%").replace("(+25%)", "(+15%)")
    outputs = evaluate(comment, Decimal(10), Decimal(25))
    assert outputs["warned"] == "true"
    assert outputs["blocked"] == "false"


def test_evaluate_unknown_when_percent_absent() -> None:
    assert evaluate("no cost data", Decimal(10), Decimal(25))["status"] == "unknown"


def test_evaluate_rejects_bad_thresholds() -> None:
    with pytest.raises(ValueError, match="0 <= warn <= block"):
        evaluate(INCREASE_COMMENT, Decimal(30), Decimal(20))


def test_render_summary_contains_verdict() -> None:
    outputs = evaluate(INCREASE_COMMENT, Decimal(10), Decimal(25))
    summary = render_summary(outputs, Decimal(10), Decimal(25))
    assert "BLOCKED" in summary
    assert "+25%" in summary


def test_main_writes_outputs_and_summary(tmp_path: Path) -> None:
    comment = tmp_path / "comment.md"
    comment.write_text(INCREASE_COMMENT, encoding="utf-8")
    outputs = tmp_path / "outputs.txt"
    summary = tmp_path / "summary.md"

    code = main(
        [
            "--comment",
            str(comment),
            "--output",
            str(outputs),
            "--summary-out",
            str(summary),
        ]
    )

    assert code == 0
    assert "blocked=true" in outputs.read_text(encoding="utf-8")
    assert "BLOCKED" in summary.read_text(encoding="utf-8")
