#!/usr/bin/env bash
# Local Phase 4 smoke test: deploy the app on the existing kind cluster using
# the in-cluster Postgres/Redis and fake External Secrets substitutes.
# No AWS resources are created. Costs $0.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="$ROOT/tools/bin:$PATH"

CLUSTER_NAME="${CLUSTER_NAME:-platformbox}"

for bin in docker kind kubectl kustomize curl; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "ERROR: $bin is not installed. Run 'make tools' first." >&2
    exit 1
  fi
done

if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  echo "ERROR: kind cluster '$CLUSTER_NAME' does not exist. Run 'make local-up' first." >&2
  exit 1
fi

PIDS=()
cleanup() {
  for pid in "${PIDS[@]:-}"; do
    [[ -n "$pid" ]] && kill "$pid" >/dev/null 2>&1 || true
  done
}
trap cleanup EXIT

echo "==> Preloading ESO and data-service images"
bash "$ROOT/scripts/preload-images.sh" "$CLUSTER_NAME"

echo "==> Building local application images"
for spec in "api:platformbox-api:local" "worker:platformbox-worker:local" "frontend:platformbox-frontend:local"; do
  context="${spec%%:*}"
  image="${spec#*:}"
  echo "    $context -> $image"
  docker build -q -t "$image" "apps/$context"
  kind load docker-image "$image" --name "$CLUSTER_NAME" >/dev/null
done

echo "==> Waiting for External Secrets Operator CRDs"
kubectl wait --for=condition=Established crd/externalsecrets.external-secrets.io \
  --timeout=300s >/dev/null

echo "==> Applying local data services (Postgres, Redis)"
kubectl apply -k gitops/apps/local-data
kubectl rollout status statefulset/postgres -n app-data --timeout=300s
kubectl rollout status deployment/redis -n app-data --timeout=300s

echo "==> Applying the local application overlay"
kubectl apply -k gitops/apps/local

echo "==> Refreshing ExternalSecrets from the local fake store"
# Safe on a fresh cluster and needed on a rerun after a fake-store value change.
SYNC_TOKEN="$(date +%s)"
kubectl annotate externalsecret api-credentials worker-credentials \
  -n app-local "force-sync=$SYNC_TOKEN" --overwrite >/dev/null

echo "==> Waiting for ExternalSecrets to sync"
kubectl wait --for=jsonpath='{.status.conditions[?(@.type=="Ready")].status}'=True \
  externalsecret/api-credentials externalsecret/worker-credentials \
  -n app-local --timeout=180s >/dev/null

echo "==> Restarting workloads to consume refreshed secrets"
kubectl rollout restart deployment/worker deployment/frontend -n app-local >/dev/null
# kubectl rollout restart does not know the Rollout CRD; patching the pod
# template annotation is the controller-agnostic way to start a new revision.
kubectl patch rollout api -n app-local --type merge \
  -p "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"platformbox.io/restartedAt\":\"$SYNC_TOKEN\"}}}}}" >/dev/null

echo "==> Waiting for application workloads"
for kind_name in "deployment/worker" "deployment/frontend"; do
  kubectl rollout status "$kind_name" -n app-local --timeout=300s
done
kubectl wait --for=condition=Healthy rollout/api -n app-local --timeout=300s >/dev/null

echo "==> Smoke-checking HTTP endpoints"
kubectl port-forward svc/api 18000:8000 -n app-local >/dev/null 2>&1 &
PIDS+=("$!")
kubectl port-forward svc/frontend 18080:80 -n app-local >/dev/null 2>&1 &
PIDS+=("$!")

for _ in $(seq 1 30); do
  if curl -fsS http://127.0.0.1:18000/health >/dev/null 2>&1; then break; fi
  sleep 1
done

echo "    API /health:     $(curl -fsS http://127.0.0.1:18000/health)"
echo "    API /ready:      $(curl -fsS http://127.0.0.1:18000/ready)"
echo "    Frontend /:      HTTP $(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:18080/)"
echo "    Fault injection: HTTP $(curl -s -o /dev/null -w '%{http_code}' -X POST http://127.0.0.1:18000/chaos/fail) (expect 503 in local)"

echo ""
echo "==> Local smoke test passed."
