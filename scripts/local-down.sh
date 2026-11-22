#!/usr/bin/env bash
# Delete the local kind cluster and everything in it.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="$ROOT/tools/bin:$PATH"

CLUSTER_NAME="platformbox"

echo "==> Deleting kind cluster '$CLUSTER_NAME'"
if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  kind delete cluster --name "$CLUSTER_NAME"
  echo "    cluster deleted"
else
  echo "    cluster does not exist; nothing to do"
fi

echo "==> Done. No AWS resources were touched."
