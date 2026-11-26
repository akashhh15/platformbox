#!/usr/bin/env python3
"""Write actual AWS spend by service into docs/costs.md.

The script uses the AWS Cost Explorer API, filtered by the ``Project`` tag.
Cost Explorer is a paid API: every request costs USD 0.01 with the primary
billing view (verified 2026-11-26 at
https://aws.amazon.com/aws-cost-management/aws-cost-explorer/pricing/).
This script makes one request per page of results and prints the request count
so a human can see the cost of running it.

Credentials come from the normal boto3 chain (environment, shared config,
SSO or an instance/IRSA role). No credentials are read or stored by this file.
"""

from __future__ import annotations

import argparse
import logging
from datetime import date
from pathlib import Path
from typing import Any

import boto3
from botocore.exceptions import BotoCoreError, ClientError

LOGGER = logging.getLogger("cost_report")

START_MARKER = "<!-- cost-report:start -->"
END_MARKER = "<!-- cost-report:end -->"
COST_EXPLORER_REGION = "us-east-1"


def month_start(today: date) -> date:
    """Return the first day of the month containing *today*."""
    return today.replace(day=1)


def fetch_cost_by_service(
    client: Any,
    project: str,
    start: date,
    end: date,
) -> tuple[dict[str, float], int]:
    """Return service -> unblended USD cost and the number of API requests."""
    costs: dict[str, float] = {}
    next_token: str | None = None
    requests = 0

    while True:
        params: dict[str, Any] = {
            "TimePeriod": {"Start": start.isoformat(), "End": end.isoformat()},
            "Granularity": "MONTHLY",
            "Filter": {"Tags": {"Key": "Project", "Values": [project]}},
            "Metrics": ["UnblendedCost"],
            "GroupBy": [{"Type": "DIMENSION", "Key": "SERVICE"}],
        }
        if next_token:
            params["NextToken"] = next_token

        response = client.get_cost_and_usage(**params)
        requests += 1

        for result in response.get("ResultsByTime", []):
            for group in result.get("Groups", []):
                service = group.get("Keys", ["Unknown"])[0]
                amount = float(
                    group.get("Metrics", {}).get("UnblendedCost", {}).get("Amount", 0)
                )
                costs[service] = costs.get(service, 0.0) + amount

        next_token = response.get("NextToken")
        if not next_token:
            break

    return costs, requests


def render_section(
    costs: dict[str, float], project: str, start: date, end: date, requests: int
) -> str:
    """Render the Markdown block that replaces the marker section."""
    lines = [
        START_MARKER,
        "### Actual spend (AWS Cost Explorer)",
        "",
        (
            f"Project tag: `{project}`. Period: {start.isoformat()} to {end.isoformat()} "
            f"(end is exclusive). Currency: USD, unblended cost."
        ),
        "",
        "| Service | Unblended cost (USD) |",
        "|---|---:|",
    ]
    for service in sorted(costs):
        lines.append(f"| {service} | {costs[service]:.2f} |")
    if not costs:
        lines.append("| _No tagged usage in this period_ | 0.00 |")
    lines.extend(
        [
            "",
            (
                f"Cost Explorer API requests for this report: {requests} "
                "(USD 0.01 each with the primary billing view)."
            ),
            "",
            END_MARKER,
        ]
    )
    return "\n".join(lines)


def update_document(document: str, section: str) -> str:
    """Replace the marker section in *document*, or append it when absent."""
    start = document.find(START_MARKER)
    end = document.find(END_MARKER)
    if start == -1 and end == -1:
        return document.rstrip("\n") + "\n\n" + section + "\n"
    if start == -1 or end == -1 or end < start:
        raise ValueError("cost report markers are unbalanced")
    return document[:start] + section + document[end + len(END_MARKER) :]


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "--project",
        default="cloud-platform-in-a-box",
        help="Value of the Project tag to filter on",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("docs/costs.md"),
        help="Markdown file to update",
    )
    parser.add_argument(
        "--start", type=date.fromisoformat, help="Start date (YYYY-MM-DD), inclusive"
    )
    parser.add_argument(
        "--end", type=date.fromisoformat, help="End date (YYYY-MM-DD), exclusive"
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    today = date.today()
    start = args.start or month_start(today)
    end = args.end or today

    if end <= start:
        LOGGER.error("--end must be after --start")
        return 2

    client = boto3.client("ce", region_name=COST_EXPLORER_REGION)
    try:
        costs, requests = fetch_cost_by_service(client, args.project, start, end)
    except (BotoCoreError, ClientError) as exc:
        LOGGER.error("Cost Explorer request failed: %s", exc)
        return 1

    section = render_section(costs, args.project, start, end, requests)
    document = args.output.read_text(encoding="utf-8") if args.output.exists() else ""
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(update_document(document, section), encoding="utf-8")
    print(
        f"Wrote {len(costs)} service rows to {args.output} using {requests} Cost Explorer request(s)."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
