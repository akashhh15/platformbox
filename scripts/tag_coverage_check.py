#!/usr/bin/env python3
"""Fail when Terraform resources can escape the required cost-allocation tags.

Two modes:

* static (default): checks our own HCL for taggable AWS resources with no
  ``tags`` argument, and checks that root ``tags`` variables carry ``Owner``.
  Used by ``make check``; needs no AWS credentials or provider plugins.
* ``--plan-json``: reads ``terraform show -json`` output from a real plan and
  checks the planned post-apply tags, including provider ``default_tags``.
  Used by CI after the plan step.

Resource types that cannot be tagged are listed in UNTAGGABLE and are skipped
with an explanation rather than producing false failures.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

REQUIRED_TAGS = ("Project", "Environment", "ManagedBy", "Owner")

UNTAGGABLE = frozenset(
    {
        "aws_budgets_budget",
        "aws_cloudwatch_event_target",
        "aws_ecr_lifecycle_policy",
        "aws_iam_role_policy",
        "aws_iam_role_policy_attachment",
        "aws_kms_alias",
        "aws_s3_bucket_lifecycle_configuration",
        "aws_s3_bucket_policy",
        "aws_s3_bucket_public_access_block",
        "aws_s3_bucket_server_side_encryption_configuration",
        "aws_s3_bucket_versioning",
        "aws_sqs_queue_policy",
        "helm_release",
        "kubernetes_manifest",
    }
)

RESOURCE_RE = re.compile(r'resource\s+"([^"]+)"\s+"([^"]+)"\s*\{')
COMMON_TAGS_RE = re.compile(r"common_tags\s*=\s*merge\(\s*\{")
TAGS_RE = re.compile(r"\btags\s*=")
VARIABLE_RE = re.compile(r'variable\s+"tags"\s*\{')


def _has_key(body: str, key: str) -> bool:
    """Match both HCL identifier keys and quoted map keys."""
    return re.search(rf'(?:"{re.escape(key)}"|{re.escape(key)})\s*=', body) is not None


def _block(text: str, start: int) -> str:
    """Return the body of a brace-delimited block whose opening brace ends at start."""
    depth = 1
    index = start
    while index < len(text) and depth:
        if text[index] == "{":
            depth += 1
        elif text[index] == "}":
            depth -= 1
        index += 1
    return text[start:index]


def static_check(root: Path) -> list[str]:
    """Return a list of static tag-coverage problems."""
    problems: list[str] = []

    for path in sorted(root.rglob("*.tf")):
        if ".terraform" in path.parts:
            continue
        text = path.read_text(encoding="utf-8")

        for match in RESOURCE_RE.finditer(text):
            resource_type, name = match.group(1), match.group(2)
            if resource_type in UNTAGGABLE or not resource_type.startswith("aws_"):
                continue
            body = _block(text, match.end())
            if not TAGS_RE.search(body):
                problems.append(f"{path}: {resource_type}.{name} has no tags argument")

        if path.parent.name in {"dev", "prod"}:
            if path.name == "variables.tf":
                for match in VARIABLE_RE.finditer(text):
                    body = _block(text, match.end())
                    if not _has_key(body, "Owner"):
                        problems.append(
                            f"{path}: variable tags default is missing Owner"
                        )
            if path.name == "main.tf":
                for match in COMMON_TAGS_RE.finditer(text):
                    body = _block(text, match.end())
                    for tag in ("Project", "Environment", "ManagedBy"):
                        if not _has_key(body, tag):
                            problems.append(f"{path}: common_tags is missing {tag}")

    return problems


def plan_check(plan: dict[str, object]) -> list[str]:
    """Return a list of planned resources missing a required tag."""
    problems: list[str] = []
    changes = plan.get("resource_changes", [])
    if not isinstance(changes, list):
        return ["plan JSON has no resource_changes list"]

    for change in changes:
        if not isinstance(change, dict):
            continue
        address = str(change.get("address", "<unknown>"))
        resource_type = str(change.get("type", ""))
        if resource_type in UNTAGGABLE or not resource_type.startswith("aws_"):
            continue
        change_data = change.get("change", {})
        after = change_data.get("after", {}) if isinstance(change_data, dict) else {}
        if after is None:
            continue
        tags = after.get("tags", {}) if isinstance(after, dict) else {}
        if not isinstance(tags, dict):
            problems.append(f"{address}: tags is not a map")
            continue
        for tag in REQUIRED_TAGS:
            if tag not in tags:
                problems.append(f"{address}: missing tag {tag}")
    return problems


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=Path("infra"),
        help="Terraform source root for static checks",
    )
    parser.add_argument(
        "--plan-json", type=Path, help="terraform show -json output for deep checks"
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.plan_json:
        problems = plan_check(json.loads(args.plan_json.read_text(encoding="utf-8")))
        label = f"plan {args.plan_json}"
    else:
        problems = static_check(args.root)
        label = f"static HCL under {args.root}"

    if problems:
        print(f"FAIL: {len(problems)} tag coverage problem(s) in {label}:", end="\n")
        for problem in problems:
            print(f"  - {problem}")
        return 1
    print(f"PASS: tag coverage in {label}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
