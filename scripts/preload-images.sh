#!/usr/bin/env bash
# Preload the slow third-party images into a kind cluster.
# This keeps `make local-up` usable on networks where registry.k8s.io or
# reg.kyverno.io time out. No cloud resources are created and nothing is priced.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="$ROOT/tools/bin:$PATH"

CLUSTER_NAME="${1:-platformbox}"

for bin in docker kind jq; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "ERROR: $bin is not installed. Run 'make tools' first." >&2
    exit 1
  fi
done

if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  echo "ERROR: kind cluster '$CLUSTER_NAME' does not exist." >&2
  exit 1
fi

FIRST_NODE="$(kind get nodes --name "$CLUSTER_NAME" | head -n 1)"

# Keep this list in sync with the charts pinned in docs/VERSIONS.md.
IMAGES=(
  "quay.io/argoproj/argocd:v3.6.2"
  "ecr-public.aws.com/docker/library/redis:8.6.4-alpine"
  "reg.kyverno.io/kyverno/kyverno:v1.20.0"
  "reg.kyverno.io/kyverno/background-controller:v1.20.0"
  "reg.kyverno.io/kyverno/cleanup-controller:v1.20.0"
  "reg.kyverno.io/kyverno/reports-controller:v1.20.0"
  "reg.kyverno.io/kyverno/kyvernopre:v1.20.0"
  "registry.k8s.io/ingress-nginx/controller:v1.11.3@sha256:d56f135b6462cfc476447cfe564b83a45e8bb7da2774963b00d12161112270b7"
  "registry.k8s.io/ingress-nginx/kube-webhook-certgen:v20221220-controller-v1.5.1-58-g787ea74b6"
  "quay.io/prometheus-operator/prometheus-operator:v0.77.2"
  "quay.io/prometheus-operator/prometheus-config-reloader:v0.77.2"
  "quay.io/prometheus/prometheus:v2.55.0"
  "quay.io/prometheus/alertmanager:v0.27.0"
  "registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.13.0"
  "quay.io/prometheus/node-exporter:v1.8.2"
  "quay.io/kiwigrid/k8s-sidecar:1.28.0"
  "docker.io/grafana/grafana:11.3.0"
  "grafana/loki:2.6.1"
  "docker.io/grafana/promtail:2.9.3"
  "quay.io/argoproj/argo-rollouts:v1.7.2"
  "quay.io/argoproj/kubectl-argo-rollouts:v1.7.2"
)

WORK="$(mktemp -d "${TMPDIR:-/tmp}/platformbox-images.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

echo "==> Preloading ${#IMAGES[@]} platform images into kind '$CLUSTER_NAME'"

for index in "${!IMAGES[@]}"; do
  image="${IMAGES[$index]}"
  tag_ref="${image%%@*}"
  digest=""
  if [[ "$image" == *"@"* ]]; then
    digest="${image##*@}"
  fi
  repo="${tag_ref%:*}"

  if docker exec "$FIRST_NODE" ctr -n k8s.io images ls >"$WORK/node-images.txt" 2>/dev/null &&
    grep -qF "$tag_ref" "$WORK/node-images.txt"; then
    echo "    skip (already on node): $tag_ref"
    continue
  fi

  echo "    pull: $image"
  docker pull "$image" >/dev/null
  docker tag "$image" "$tag_ref"

  raw_archive="$WORK/$index-raw.tar"
  clean_archive="$WORK/$index-clean.tar"
  extract_dir="$WORK/$index-extract"

  docker save "$tag_ref" -o "$raw_archive"
  mkdir -p "$extract_dir"
  tar -xf "$raw_archive" -C "$extract_dir"

  # Docker 29 writes an OCI layout as well as the classic Docker manifest.
  # kind only consumes the classic layout; index.json and oci-layout confuse it.
  rm -f "$extract_dir/index.json" "$extract_dir/oci-layout"

  # A chart pin such as image@sha256:... resolves by digest. Record that digest
  # in the archive so kind imports it under the name the kubelet asks for.
  if [[ -n "$digest" ]]; then
    jq --arg ref "$repo@$digest" '.[0].RepoDigests = [$ref]' \
      "$extract_dir/manifest.json" >"$WORK/manifest.json"
    mv "$WORK/manifest.json" "$extract_dir/manifest.json"
  fi

  tar -cf "$clean_archive" -C "$extract_dir" .
  kind load image-archive "$clean_archive" --name "$CLUSTER_NAME" >/dev/null
done

echo "==> Platform images are available locally."
