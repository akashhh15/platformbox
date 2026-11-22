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

WORK="$(mktemp -d "${TMPDIR:-/tmp}/platformbox-helm.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

declare -A REPOS=(
  [argo]=https://argoproj.github.io/argo-helm
  [ingress-nginx]=https://kubernetes.github.io/ingress-nginx
  [kyverno]=https://kyverno.github.io/kyverno
  [prom]=https://prometheus-community.github.io/helm-charts
  [grafana]=https://grafana.github.io/helm-charts
  [external-secrets]=https://charts.external-secrets.io
)
for alias in "${!REPOS[@]}"; do
  "$HELM" repo add "$alias" "${REPOS[$alias]}" --force-update >/dev/null
done
"$HELM" repo update >/dev/null

CHARTS=(
  "argo/argo-cd:10.18.2"
  "argo/argo-rollouts:2.38.0"
  "ingress-nginx/ingress-nginx:4.11.3"
  "kyverno/kyverno:3.10.0"
  "prom/kube-prometheus-stack:65.8.1"
  "grafana/loki-stack:2.10.2"
  "external-secrets/external-secrets:2.15.0"
)

for entry in "${CHARTS[@]}"; do
  ref="${entry%%:*}"
  version="${entry##*:}"
  chart="${ref##*/}"
  printf '==> helm lint %s %s\n' "$ref" "$version"
  "$HELM" pull "$ref" --version "$version" --destination "$WORK" >/dev/null
  rm -rf "$WORK/$chart"
  tar -xzf "$WORK/$chart-$version.tgz" -C "$WORK"
  "$HELM" lint "$WORK/$chart"
done

echo "==> All pinned Helm charts linted."
