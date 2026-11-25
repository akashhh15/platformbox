#!/usr/bin/env bash
# Lint the exact third-party chart versions pinned in gitops/platform.
#
# This needs network access to the public chart repositories, so it is a CI job
# rather than part of the offline `make check`. No cluster is contacted.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

HELM="${HELM:-helm}"
if ! command -v "$HELM" >/dev/null 2>&1; then
  if [ -x tools/bin/helm.exe ]; then
    HELM=tools/bin/helm.exe
  else
    echo "ERROR: helm is not installed. Run 'make tools' first." >&2
    exit 1
  fi
fi
if ! command -v yq >/dev/null 2>&1; then
  echo "ERROR: yq is not installed. Run 'make tools' first." >&2
  exit 1
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/platformbox-helm.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

declare -A REPOS=(
  [argo]=https://argoproj.github.io/argo-helm
  [ingress-nginx]=https://kubernetes.github.io/ingress-nginx
  [kyverno]=https://kyverno.github.io/kyverno
  [prom]=https://prometheus-community.github.io/helm-charts
  [grafana]=https://grafana.github.io/helm-charts
  [external-secrets]=https://charts.external-secrets.io
  [chaos-mesh]=https://charts.chaos-mesh.org
)
for alias in "${!REPOS[@]}"; do
  "$HELM" repo add "$alias" "${REPOS[$alias]}" --force-update >/dev/null
done
"$HELM" repo update >/dev/null

CHARTS=(
  "argo/argo-cd:10.18.2"
  "argo/argo-cd:7.0.0"
  "argo/argo-rollouts:2.38.0"
  "ingress-nginx/ingress-nginx:4.11.3"
  "kyverno/kyverno:3.10.0"
  "prom/kube-prometheus-stack:65.8.1"
  "grafana/loki-stack:2.10.2"
  "external-secrets/external-secrets:2.15.0"
  "chaos-mesh/chaos-mesh:2.8.8"
)

for entry in "${CHARTS[@]}"; do
  ref="${entry%%:*}"
  version="${entry##*:}"
  chart="${ref##*/}"
  printf '==> helm lint %s %s\n' "$ref" "$version"
  "$HELM" pull "$ref" --version "$version" --destination "$WORK" >/dev/null
  chart_dir="$WORK/$chart-$version"
  rm -rf "$chart_dir"
  mkdir -p "$chart_dir"
  tar -xzf "$WORK/$chart-$version.tgz" -C "$chart_dir" --strip-components=1
  "$HELM" lint "$chart_dir"
done

echo "==> All pinned Helm charts linted."

echo "==> Helm values used by Phase 8 notification configuration"
VALUES_WORK="$WORK/values-charts"
mkdir -p "$VALUES_WORK"
for entry in "argo/argo-cd:10.18.2" "argo/argo-cd:7.0.0" "argo/argo-rollouts:2.38.0"; do
  ref="${entry%%:*}"
  version="${entry##*:}"
  chart="${ref##*/}"
  chart_dir="$VALUES_WORK/$chart-$version"
  "$HELM" pull "$ref" --version "$version" --destination "$VALUES_WORK" >/dev/null
  mkdir -p "$chart_dir"
  tar -xzf "$VALUES_WORK/$chart-$version.tgz" -C "$chart_dir" --strip-components=1
  if [[ "$chart" == "argo-cd" ]]; then
    "$HELM" template argocd "$chart_dir" \
      --values gitops/bootstrap/argocd-notifications-values.yaml >/dev/null
  fi
done
yq e '.spec.source.helm.values' gitops/platform/argo-rollouts.yaml \
  >"$VALUES_WORK/rollouts-values.yaml"
"$HELM" template argo-rollouts "$VALUES_WORK/argo-rollouts-2.38.0" \
  --values "$VALUES_WORK/rollouts-values.yaml" >/dev/null

echo "==> Helm values used by Phase 9 Chaos Mesh configuration"
"$HELM" pull chaos-mesh/chaos-mesh --version 2.8.8 --destination "$VALUES_WORK" >/dev/null
mkdir -p "$VALUES_WORK/chaos-mesh-2.8.8"
tar -xzf "$VALUES_WORK/chaos-mesh-2.8.8.tgz" -C "$VALUES_WORK/chaos-mesh-2.8.8" --strip-components=1
yq e '.spec.template.spec.source.helm.values' \
  gitops/platform/chaos-mesh-applicationset.yaml >"$VALUES_WORK/chaos-values.yaml"
"$HELM" template chaos-mesh "$VALUES_WORK/chaos-mesh-2.8.8" \
  --values "$VALUES_WORK/chaos-values.yaml" >/dev/null

echo "==> Shared Helm values render with all pinned chart versions."
