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

for bin in kustomize kubeconform yamllint yq kyverno promtool jq; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "ERROR: $bin is not installed. Run 'make tools' first." >&2
    exit 1
  fi
done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/platformbox-gitops.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# CRDs whose schemas are not part of kubeconform's bundled Kubernetes schemas.
SKIP='Application,ApplicationSet,ValidatingPolicy,Rollout,AnalysisTemplate,ServiceMonitor,PrometheusRule,AlertmanagerConfig,ExternalSecret,SecretStore,ClusterSecretStore'

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
# The CLI treats a non-policy YAML file in a directory as a load hint and can
# silently apply zero policies when kustomization.yaml is present. Give it a
# clean directory containing only the ValidatingPolicy manifests.
POLICY_DIR="$WORK/policies"
mkdir -p "$POLICY_DIR"
for policy in gitops/platform/kyverno-policies/*.yaml; do
  [[ "$(basename "$policy")" == "kustomization.yaml" ]] && continue
  cp "$policy" "$POLICY_DIR/"
done
POLICY_COUNT="$(find "$POLICY_DIR" -type f -name '*.yaml' | wc -l | tr -d ' ')"
if [[ "$POLICY_COUNT" -eq 0 ]]; then
  echo "ERROR: no Kyverno policies found to apply." >&2
  exit 1
fi

render_pods() {
  local render="$1"
  local namespace="$2"
  local out="$3"
  NS="$namespace" yq e 'select(.kind == "Deployment" or .kind == "Rollout" or .kind == "StatefulSet") | . as $item | {"apiVersion": "v1", "kind": "Pod", "metadata": ($item.spec.template.metadata | .name = $item.metadata.name | .namespace = strenv(NS)), "spec": $item.spec.template.spec}' "$render" >"$out"
}

check_pods() {
  local name="$1"
  local pods="$2"
  local log="$WORK/$name-kyverno.log"
  printf '    %-12s %s pods  ' "$name" "$(grep -c '^kind: Pod' "$pods" || true)"
  kyverno apply "$POLICY_DIR" -r "$pods" >"$log" 2>&1
  if ! grep -q "Applying $POLICY_COUNT policy rule(s)" "$log"; then
    echo "ERROR: Kyverno did not load all $POLICY_COUNT policies for $name." >&2
    cat "$log" >&2
    exit 1
  fi
  tail -n 1 "$log"
}

for env in dev staging prod; do
  render_pods "$WORK/$env.yaml" "app-$env" "$WORK/$env-pods.yaml"
  check_pods "$env" "$WORK/$env-pods.yaml"
done

render_pods "$WORK/local.yaml" app-local "$WORK/local-pods.yaml"
check_pods local "$WORK/local-pods.yaml"

render_pods "$WORK/local-data.yaml" app-data "$WORK/local-data-pods.yaml"
check_pods local-data "$WORK/local-data-pods.yaml"

echo "==> All GitOps manifests valid."

bash "$ROOT/scripts/observability-validate.sh"

echo
bash "$ROOT/scripts/progressive-validate.sh"

echo
bash "$ROOT/scripts/resilience-validate.sh"
