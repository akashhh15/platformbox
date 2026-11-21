#!/usr/bin/env bash
# Run checkov from the repository virtual environment.
#
# Why this wrapper exists: on Windows, pip installs checkov as an extensionless
# Python script plus a .cmd shim, but no .exe launcher. Git Bash then resolves
# `checkov` to the extensionless script, whose shebang contains the absolute
# path to the venv Python. If the repository path contains a space (for example
# "D:\Devops Projects"), the kernel splits the shebang and execution fails with
# "bad interpreter". Calling the venv Python explicitly avoids the shebang.
#
# The wrapper is used by `make scan` and by the pre-commit hook, so both behave
# identically on Windows, Linux and macOS.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -x "$ROOT/.venv/Scripts/python.exe" ]; then
  PY="$ROOT/.venv/Scripts/python.exe"
  SCRIPT="$ROOT/.venv/Scripts/checkov"
else
  PY="$ROOT/.venv/bin/python"
  SCRIPT="$ROOT/.venv/bin/checkov"
fi

if [ ! -x "$PY" ]; then
  echo "ERROR: checkov is not installed. Run: make tools" >&2
  exit 1
fi

exec "$PY" "$SCRIPT" "$@"
