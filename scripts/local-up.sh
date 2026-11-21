#!/usr/bin/env bash
# Create the local kind cluster and install the platform layer.
# No AWS resources are created. Costs $0.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="$ROOT/tools/bin:$PATH"

CLUSTER_NAME="platformbox"
KIND_CONFIG="$ROOT/kind-config.yaml"

echo "==> Checking prerequisites"
for bin in kind kubectl helm docker; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "ERROR: $bin is not installed. Run 'make tools' first." >&2
    exit 1
  fi
done

if ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker daemon is not running. Start Docker Desktop first." >&2
  exit 1
fi

echo "==> Creating kind cluster '$CLUSTER_NAME'"
if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  echo "    cluster already exists; skipping creation"
else
  kind create cluster --config "$KIND_CONFIG" --wait 120s
fi

echo "==> Installing Argo CD"
echo "    ingress-nginx and the rest of the platform are synced by Argo CD"
echo "    from gitops/platform, so there is a single source of truth."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1 || true
helm upgrade --install argocd argo/argo-cd \
  --version 10.18.2 \
  --namespace argocd \
  --set server.service.type=ClusterIP \
  --wait --timeout 300s

echo "==> Applying AppProjects"
kubectl apply -f "$ROOT/gitops/projects/"

echo "==> Applying Argo CD root application"
kubectl apply -f "$ROOT/gitops/bootstrap/root-app.yaml"

echo ""
echo "==> Local platform is up."
echo "    Argo CD UI: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "    Username: admin, password: (kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
echo "    Ingress: http://localhost"
