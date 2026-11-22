#!/usr/bin/env bash
# Render and validate every GitOps overlay, then check the rendered pod specs
# against the basic Kyverno policies. No cluster and no cloud API are used.
# This is the GitOps half of `make check`.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -n "${OS:-}" ]]; then
  VENV_BIN=".venv/Scripts"
else
  VENV_BIN=".venv/bin"
fi
export PATH="$ROOT/$VENV_BIN:$ROOT/tools/bin:$PATH"

for bin in kustomize kubeconform yamllint yq kyverno; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "ERROR: $bin is not installed. Run 'make tools' first." >&2
    exit 1
  fi
done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/platformbox-gitops.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# CRDs whose schemas are not part of kubeconform's bundled Kubernetes schemas.
SKIP='Application,ApplicationSet,ValidatingPolicy,Rollout,ServiceMonitor,ExternalSecret,SecretStore'

echo "==> yamllint: GitOps manifests"
yamllint -c .yamllint.yaml gitops

echo "==> Kustomize build + kubeconform"
OVERLAYS=(
  "bootstrap:gitops/bootstrap"
  "platform:gitops/platform"
  "policies:gitops/platform/kyverno-policies"
  "base:gitops/apps/base"
  "dev:gitops/apps/overlays/dev"
  "staging:gitops/apps/overlays/staging"
  "prod:gitops/apps/overlays/prod"
  "local:gitops/apps/local"
  "local-data:gitops/apps/local-data"
)

for entry in "${OVERLAYS[@]}"; do
  name="${entry%%:*}"
  dir="${entry#*:}"
  out="$WORK/$name.yaml"
  kustomize build "$dir" >"$out"
  resources="$(grep -c '^kind:' "$out" || true)"
  printf '    %-12s %3s resources  ' "$name" "$resources"
  kubeconform -summary -strict -skip "$SKIP" "$out" >"$WORK/$name.kubeconform" 2>&1
  tail -n 1 "$WORK/$name.kubeconform"
done

echo "==> Kyverno CLI: rendered pod specs"
render_pods() {
  local render="$1"
  local namespace="$2"
  local out="$3"
  NS="$namespace" yq e 'select(.kind == "Deployment" or .kind == "Rollout" or .kind == "StatefulSet") | . as $item | {"apiVersion": "v1", "kind": "Pod", "metadata": ($item.spec.template.metadata | .name = $item.metadata.name | .namespace = strenv(NS)), "spec": $item.spec.template.spec}' "$render" >"$out"
}

for env in dev staging prod; do
  render_pods "$WORK/$env.yaml" "app-$env" "$WORK/$env-pods.yaml"
  pod_count="$(grep -c '^kind: Pod' "$WORK/$env-pods.yaml" || true)"
  printf '    %-12s %s pods  ' "$env" "$pod_count"
  kyverno apply gitops/platform/kyverno-policies/ -r "$WORK/$env-pods.yaml" \
    >"$WORK/$env-kyverno.log" 2>&1
  tail -n 1 "$WORK/$env-kyverno.log"
done

render_pods "$WORK/local.yaml" app-local "$WORK/local-pods.yaml"
printf '    %-12s %s pods  ' local "$(grep -c '^kind: Pod' "$WORK/local-pods.yaml" || true)"
kyverno apply gitops/platform/kyverno-policies/ -r "$WORK/local-pods.yaml" \
  >"$WORK/local-kyverno.log" 2>&1
tail -n 1 "$WORK/local-kyverno.log"

render_pods "$WORK/local-data.yaml" app-data "$WORK/local-data-pods.yaml"
printf '    %-12s %s pods  ' local-data "$(grep -c '^kind: Pod' "$WORK/local-data-pods.yaml" || true)"
kyverno apply gitops/platform/kyverno-policies/ -r "$WORK/local-data-pods.yaml" \
  >"$WORK/local-data-kyverno.log" 2>&1
tail -n 1 "$WORK/local-data-kyverno.log"

echo "==> All GitOps manifests valid."
