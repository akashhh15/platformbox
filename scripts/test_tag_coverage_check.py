"""Unit tests for scripts/tag_coverage_check.py."""

from __future__ import annotations

from copy import deepcopy
from pathlib import Path

from tag_coverage_check import plan_check, static_check

GOOD_TF = """
locals {
  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags,
  )
}

resource "aws_iam_role" "this" {
  name = "role"
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "this" {
  role = aws_iam_role.this.name
}
"""

BAD_TF = """
resource "aws_s3_bucket" "untagged" {
  bucket = "example"
}
"""

GOOD_VARIABLES = """
variable "tags" {
  type = map(string)
  default = {
    Owner = "platform-team"
  }
}
"""

GOOD_PLAN = {
    "resource_changes": [
        {
            "address": "aws_s3_bucket.this",
            "type": "aws_s3_bucket",
            "change": {
                "after": {
                    "tags": {
                        "Project": "platformbox",
                        "Environment": "dev",
                        "ManagedBy": "terraform",
                        "Owner": "platform-team",
                    }
                }
            },
        },
        {
            "address": "aws_iam_role_policy.this",
            "type": "aws_iam_role_policy",
            "change": {"after": {}},
        },
    ]
}


def test_static_check_accepts_tagged_resources(tmp_path: Path) -> None:
    env = tmp_path / "dev"
    env.mkdir()
    (env / "main.tf").write_text(GOOD_TF, encoding="utf-8")
    (env / "variables.tf").write_text(GOOD_VARIABLES, encoding="utf-8")
    assert static_check(tmp_path) == []


def test_static_check_flags_untagged_resource(tmp_path: Path) -> None:
    (tmp_path / "main.tf").write_text(BAD_TF, encoding="utf-8")
    problems = static_check(tmp_path)
    assert len(problems) == 1
    assert "aws_s3_bucket.untagged has no tags argument" in problems[0]


def test_static_check_flags_missing_owner(tmp_path: Path) -> None:
    env = tmp_path / "prod"
    env.mkdir()
    (env / "variables.tf").write_text(
        'variable "tags" { type = map(string) default = {} }', encoding="utf-8"
    )
    problems = static_check(tmp_path)
    assert any("missing Owner" in problem for problem in problems)


def test_plan_check_accepts_required_tags() -> None:
    assert plan_check(GOOD_PLAN) == []


def test_plan_check_flags_missing_tag() -> None:
    plan = deepcopy(GOOD_PLAN)
    plan["resource_changes"][0]["change"]["after"]["tags"].pop("Owner")  # type: ignore[index]
    problems = plan_check(plan)
    assert problems == ["aws_s3_bucket.this: missing tag Owner"]
