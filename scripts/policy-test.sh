#!/usr/bin/env bash
# Run Kyverno unit tests for every admission policy. No cluster is needed.
# This is the policy half of `make test`.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -n "${OS:-}" ]]; then
  VENV_BIN=".venv/Scripts"
else
  VENV_BIN=".venv/bin"
fi
export PATH="$ROOT/$VENV_BIN:$ROOT/tools/bin:$PATH"

if ! command -v kyverno >/dev/null 2>&1; then
  echo "ERROR: kyverno is not installed. Run 'make tools' first." >&2
  exit 1
fi

echo "==> Kyverno CLI: policy unit tests"
kyverno test gitops/platform/kyverno-policies/tests \
  --remove-color --require-tests
