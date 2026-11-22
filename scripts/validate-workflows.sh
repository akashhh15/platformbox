#!/usr/bin/env bash
# Offline validation for GitHub Actions and GitLab CI configuration.
#
# GitHub workflows are parsed with the pinned actionlint binary. GitLab CI is
# checked with `glab ci lint` when glab is installed; otherwise a deterministic
# PyYAML structural check is used. No CI API call is made. This is part of
# `make lint` and therefore `make check`.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export PATH="$ROOT/tools/bin:$PATH"

if [ -n "${OS:-}" ]; then
  VENV_BIN=".venv/Scripts"
else
  VENV_BIN=".venv/bin"
fi
export PATH="$ROOT/$VENV_BIN:$PATH"
PYTHON="${PYTHON:-}"
if [ -z "$PYTHON" ]; then
  if [ -x "$ROOT/$VENV_BIN/python" ]; then
    PYTHON="$ROOT/$VENV_BIN/python"
  elif [ -x "$ROOT/$VENV_BIN/python.exe" ]; then
    PYTHON="$ROOT/$VENV_BIN/python.exe"
  elif command -v python3 >/dev/null 2>&1; then
    PYTHON=python3
  elif command -v python >/dev/null 2>&1; then
    PYTHON=python
  else
    echo "ERROR: Python is not available. Install Python 3.12+ and re-run." >&2
    exit 1
  fi
fi

WORKFLOWS=(.github/workflows/*.yml)
if [ ! -e "${WORKFLOWS[0]}" ]; then
  echo "ERROR: no GitHub workflows found." >&2
  exit 1
fi

ACTIONLINT="${ACTIONLINT:-actionlint}"
if ! command -v "$ACTIONLINT" >/dev/null 2>&1; then
  if [ -x tools/bin/actionlint.exe ]; then
    ACTIONLINT=tools/bin/actionlint.exe
  else
    echo "ERROR: actionlint is not installed. Run 'make tools' first." >&2
    exit 1
  fi
fi

echo "==> actionlint ($( "$ACTIONLINT" -version 2>&1 | head -n 1 ))"
"$ACTIONLINT" -color "${WORKFLOWS[@]}"

echo "==> image artifact contract"
ARTIFACT_TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/platformbox-artifacts.XXXXXX")"
trap 'rm -rf "$ARTIFACT_TEST_DIR"' EXIT
export ARTIFACT_DIR="$ARTIFACT_TEST_DIR"
DIGEST_HEX="$(printf 'a%.0s' {1..64})"
REGISTRY_HOST="123456789012.dkr.ecr.ap-south-1.amazonaws.com"
printf 'sha256:%s\n' "$DIGEST_HEX" >"$ARTIFACT_DIR/api.digest"
bash scripts/image-artifacts.sh write api \
  "$REGISTRY_HOST/api:test" "$REGISTRY_HOST" >/dev/null
if [[ "$(cat "$ARTIFACT_DIR/api.digest")" != "$DIGEST_HEX" ]]; then
  echo "ERROR: digest artifact was not normalized to a bare 64-character hex value." >&2
  exit 1
fi
if [[ "$(cat "$ARTIFACT_DIR/api.image")" != "$REGISTRY_HOST/api@sha256:$DIGEST_HEX" ]]; then
  echo "ERROR: image artifact has an unexpected digest reference." >&2
  exit 1
fi
bash scripts/image-artifacts.sh verify api "$REGISTRY_HOST" >/dev/null
printf 'bad-digest\n' >"$ARTIFACT_DIR/api.digest"
if bash scripts/image-artifacts.sh verify api "$REGISTRY_HOST" >/dev/null 2>&1; then
  echo "ERROR: image artifact verification accepted an invalid digest." >&2
  exit 1
fi
unset ARTIFACT_DIR
rm -rf "$ARTIFACT_TEST_DIR"
trap - EXIT

if command -v glab >/dev/null 2>&1; then
  echo "==> glab ci lint"
  glab ci lint
else
  echo "==> glab ci lint not installed; using offline GitLab CI structural checks"
fi

"$PYTHON" - <<'PY'
import pathlib
import re
import sys

import yaml

root = pathlib.Path(".")
failures = []
sha_re = re.compile(r"@[0-9a-f]{40}$")
uses_re = re.compile(r"^[^./][^@\s]*@([0-9a-f]{40})$")
access_key_re = re.compile(r"\bAKIA[0-9A-Z]{16}\b")
digest_re = re.compile(r"@sha256:[0-9a-f]{64}$")
expected_stages = [
    "lint",
    "test",
    "build",
    "scan",
    "sign",
    "publish",
    "deploy-gitops",
]

workflow_paths = sorted((root / ".github/workflows").glob("*.yml"))
for path in workflow_paths:
    text = path.read_text(encoding="utf-8")
    try:
        doc = yaml.safe_load(text)
    except yaml.YAMLError as exc:
        failures.append(f"{path}: invalid YAML: {exc}")
        continue
    if not isinstance(doc, dict):
        failures.append(f"{path}: top level must be a mapping")
        continue
    if "permissions" not in doc:
        failures.append(f"{path}: missing top-level permissions")
    if "concurrency" not in doc:
        failures.append(f"{path}: missing concurrency group")
    jobs = doc.get("jobs")
    if not isinstance(jobs, dict) or not jobs:
        failures.append(f"{path}: no jobs defined")
        continue
    for name, job in jobs.items():
        if not isinstance(job, dict):
            failures.append(f"{path}: job {name} must be a mapping")
            continue
        if "permissions" not in job:
            failures.append(f"{path}: job {name} has no explicit permissions")
        for step in job.get("steps", []) or []:
            if not isinstance(step, dict) or "uses" not in step:
                continue
            uses = str(step["uses"])
            if uses.startswith("./"):
                continue
            if not uses_re.match(uses):
                failures.append(f"{path}: job {name} uses unpinned action {uses!r}")
    if access_key_re.search(text):
        failures.append(f"{path}: contains an AWS access-key-shaped literal")

gitlab = root / ".gitlab-ci.yml"
if not gitlab.exists():
    failures.append(".gitlab-ci.yml is missing")
else:
    text = gitlab.read_text(encoding="utf-8")
    try:
        doc = yaml.safe_load(text)
    except yaml.YAMLError as exc:
        failures.append(f".gitlab-ci.yml: invalid YAML: {exc}")
        doc = None
    if doc is not None:
        if doc.get("stages") != expected_stages:
            failures.append(f".gitlab-ci.yml: stages must be {expected_stages}")
        jobs = {k: v for k, v in doc.items() if isinstance(v, dict) and "stage" in v}
        if len(jobs) < 10:
            failures.append(".gitlab-ci.yml: expected at least 10 CI jobs")
        for name, job in jobs.items():
            image = job.get("image")
            if isinstance(image, dict):
                image = image.get("name")
            if image is not None and not digest_re.search(str(image)):
                failures.append(f".gitlab-ci.yml: job {name} image is not pinned by digest")
        flattened = yaml.safe_dump(doc, sort_keys=False)
        required_strings = [
            "[skip ci]",
            "gitops/**",
            "apps/**/*",
            "SIGSTORE_ID_TOKEN",
            "sts.amazonaws.com",
            "cyclonedx",
            "trivyignore",
        ]
        for value in required_strings:
            if value not in flattened:
                failures.append(f".gitlab-ci.yml: missing required string {value!r}")
        id_tokens = []
        for name, job in jobs.items():
            for token_name, token in (job.get("id_tokens") or {}).items():
                audience = token.get("aud") if isinstance(token, dict) else None
                id_tokens.append((name, token_name, audience))
        if not any(name == "SIGSTORE_ID_TOKEN" and aud == "sigstore" for _, name, aud in id_tokens):
            failures.append(".gitlab-ci.yml: no SIGSTORE_ID_TOKEN with aud sigstore")
        if not any(name == "AWS_OIDC_TOKEN" and aud == "sts.amazonaws.com" for _, name, aud in id_tokens):
            failures.append(".gitlab-ci.yml: no AWS_OIDC_TOKEN with aud sts.amazonaws.com")
    if access_key_re.search(text):
        failures.append(".gitlab-ci.yml: contains an AWS access-key-shaped literal")

if failures:
    print("Workflow validation failed:", file=sys.stderr)
    for failure in failures:
        print(f"  - {failure}", file=sys.stderr)
    sys.exit(1)

print(f"==> Workflow contract OK ({len(workflow_paths)} GitHub workflows, 1 GitLab CI file)")
PY
