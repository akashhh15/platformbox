#!/usr/bin/env bash
# Opt-in node-termination simulation for a disposable kind cluster only.
#
# This never touches AWS. It stops one kind *worker* container, which makes the
# Kubernetes node NotReady, and prints the exact command to start it again.
# The agent never runs this script; a human must set CONFIRM explicitly.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

NODE_NAME="${NODE_NAME:-}"
CONFIRM="${CONFIRM:-}"

if [[ ! "$NODE_NAME" =~ ^kind-worker ]]; then
  echo "ERROR: NODE_NAME must start with 'kind-worker'. Got: '${NODE_NAME}'." >&2
  echo "This guard keeps the kind control plane and every EKS node out of scope." >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker is not installed or not on PATH." >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "ERROR: the Docker daemon is not available." >&2
  exit 1
fi

CONTAINER_ID="$(docker ps --filter "name=^/${NODE_NAME}$" --format '{{.ID}}')"
if [[ -z "$CONTAINER_ID" ]]; then
  echo "ERROR: no running container named '${NODE_NAME}' was found." >&2
  exit 1
fi

ROLE="$(docker inspect --format '{{index .Config.Labels "io.x-k8s.kind.role"}}' "$CONTAINER_ID")"
if [[ "$ROLE" != "worker" ]]; then
  echo "ERROR: '${NODE_NAME}' has role '${ROLE}', not 'worker'. Aborting." >&2
  exit 1
fi

echo "About to stop kind worker '${NODE_NAME}' (container ${CONTAINER_ID:0:12})."
echo "Abort / restore: docker start ${NODE_NAME}"
if [[ "$CONFIRM" != "stop-kind-worker" ]]; then
  echo "Dry run only. Re-run with CONFIRM=stop-kind-worker to inject the fault." >&2
  exit 0
fi

docker stop --time 30 "$NODE_NAME"
echo "Stopped '${NODE_NAME}'. Restore it with: docker start ${NODE_NAME}"
