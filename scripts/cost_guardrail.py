#!/usr/bin/env python3
"""Apply repo-side warn/block thresholds to an Infracost PR comment.

Infracost CI writes its Markdown comment to a file with ``--comment-out-file``.
This script reads the total monthly cost change from that file and emits
GitHub Actions outputs. Cloud guardrails remain authoritative; this is a
deterministic local check that does not depend on dashboard configuration.
"""

from __future__ import annotations

import argparse
import re
from decimal import Decimal, InvalidOperation
from pathlib import Path

PERCENT_PATTERNS = (
    re.compile(r"Percent:\s*([+-]?\d+(?:\.\d+)?)%"),
    re.compile(r"\(([+-]?\d+(?:\.\d+)?)%\)"),
)
AMOUNT_PATTERN = re.compile(r"(?:increased|decreased) by \$([0-9,]+(?:\.\d+)?)")


def _decimal(value: str) -> Decimal:
    return Decimal(value.replace(",", ""))


def parse_change(comment: str) -> tuple[Decimal | None, Decimal | None]:
    """Return (percent change, absolute monthly delta) or (None, None)."""
    for pattern in PERCENT_PATTERNS:
        matches = pattern.findall(comment)
        if matches:
            try:
                return _decimal(matches[-1]), None
            except InvalidOperation:
                break

    amount = AMOUNT_PATTERN.search(comment)
    if amount:
        try:
            return None, _decimal(amount.group(1))
        except InvalidOperation:
            pass
    return None, None


def evaluate(
    comment: str, warn_percent: Decimal, block_percent: Decimal
) -> dict[str, str]:
    """Evaluate a comment and return GitHub Actions output key/value pairs."""
    if warn_percent < 0 or block_percent < 0 or block_percent < warn_percent:
        raise ValueError("thresholds must satisfy 0 <= warn <= block")

    percent, amount = parse_change(comment)
    outputs = {
        "percent": "" if percent is None else format(percent, "f"),
        "delta": "" if amount is None else format(amount, "f"),
        "status": "unknown",
        "warned": "false",
        "blocked": "false",
    }
    if percent is None:
        return outputs

    outputs["status"] = (
        "increased" if percent > 0 else "decreased" if percent < 0 else "unchanged"
    )
    if percent >= block_percent:
        outputs["blocked"] = "true"
    elif percent >= warn_percent:
        outputs["warned"] = "true"
    return outputs


def render_summary(
    outputs: dict[str, str], warn_percent: Decimal, block_percent: Decimal
) -> str:
    """Return the Markdown line appended to the posted PR comment."""
    percent = outputs["percent"]
    if not percent:
        return (
            "**Cost guardrail:** change could not be parsed; no local threshold "
            "was applied. Check the Infracost comment format."
        )
    if outputs["blocked"] == "true":
        verdict = "BLOCKED"
    elif outputs["warned"] == "true":
        verdict = "WARNING"
    else:
        verdict = "OK"
    return (
        f"**Cost guardrail:** {verdict} — monthly change {percent}% "
        f"(warn at +{warn_percent}%, block at +{block_percent}%)."
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--comment", type=Path, required=True, help="Infracost comment Markdown file"
    )
    parser.add_argument("--warn-percent", type=Decimal, default=Decimal(10))
    parser.add_argument("--block-percent", type=Decimal, default=Decimal(25))
    parser.add_argument(
        "--output", type=Path, help="Append key=value lines for GITHUB_OUTPUT"
    )
    parser.add_argument(
        "--summary-out", type=Path, help="Write the Markdown verdict line here"
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    outputs = evaluate(
        args.comment.read_text(encoding="utf-8"), args.warn_percent, args.block_percent
    )
    lines = [f"{key}={value}" for key, value in outputs.items()]
    if args.output:
        with args.output.open("a", encoding="utf-8") as handle:
            handle.write("\n".join(lines) + "\n")
    else:
        print("\n".join(lines))
    if args.summary_out:
        args.summary_out.write_text(
            render_summary(outputs, args.warn_percent, args.block_percent) + "\n",
            encoding="utf-8",
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
