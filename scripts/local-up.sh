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

echo "==> Preloading slow container images"
bash "$ROOT/scripts/preload-images.sh" "$CLUSTER_NAME"

echo "==> Installing Argo CD"
echo "    ingress-nginx and the rest of the platform are synced by Argo CD"
echo "    from gitops/platform, so there is a single source of truth."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1 || true
# Dex is SSO only. Disabling it keeps the local demo on the built-in admin
# user and avoids pulling an extra image from ghcr.io on slow networks.
# The repo-server timeouts give large Helm charts (kube-prometheus-stack)
# enough time to download on slow networks; the defaults are 60s/90s.
helm upgrade --install argocd argo/argo-cd \
  --version 10.18.2 \
  --namespace argocd \
  --set server.service.type=ClusterIP \
  --set dex.enabled=false \
  --set-json 'configs.params={"server.repo.server.timeout.seconds":"300","controller.repo.server.timeout.seconds":"300"}' \
  --set-json 'repoServer.env=[{"name":"ARGOCD_EXEC_TIMEOUT","value":"300s"}]' \
  --wait --timeout 300s

echo "==> Applying AppProjects"
kubectl apply -f "$ROOT/gitops/projects/"

echo "==> Applying Argo CD root application"
kubectl apply -f "$ROOT/gitops/bootstrap/root-app.yaml"

# The committed manifest follows `main`. While a phase branch is under review,
# follow it instead so `make local-up` deploys the manifests in this checkout.
# Without this, a missing path on main renders as a healthy but empty app.
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"
if git ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
  echo "    root app will follow branch '$BRANCH' (present on origin)"
  kubectl patch application root -n argocd --type merge \
    -p "{\"spec\":{\"source\":{\"targetRevision\":\"$BRANCH\"}}}"
else
  echo "    branch '$BRANCH' is not on origin; root app follows 'main'"
fi

echo ""
echo "==> Local platform is up."
echo "    Argo CD UI: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "    Username: admin, password: (kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
echo "    Ingress: http://localhost"
