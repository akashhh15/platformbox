#!/usr/bin/env bash
# Normalize and verify the image artifacts passed between GitLab CI stages.
#
# Buildah writes a digest as "sha256:<hex>"; GitOps and Cosign need the bare
# 64-character hex value. Keeping this conversion in one place prevents a
# double "sha256:" prefix and lets the sign stage prove it received the exact
# immutable reference that the build stage pushed (ADR-022).
#
# Usage:
#   image-artifacts.sh write SERVICE IMAGE REGISTRY
#   image-artifacts.sh verify SERVICE REGISTRY
#
# ARTIFACT_DIR overrides the artifact directory (default: artifacts).

set -euo pipefail

MODE="${1:?mode is required (write|verify)}"
SERVICE="${2:?service is required}"
ARTIFACT_DIR="${ARTIFACT_DIR:-artifacts}"

case "$MODE" in
  write)
    IMAGE="${3:?image is required for write}"
    REGISTRY="${4:?registry is required for write}"
    ;;
  verify)
    REGISTRY="${3:?registry is required for verify}"
    ;;
  *)
    echo "ERROR: unknown mode '$MODE' (expected write or verify)" >&2
    exit 2
    ;;
esac

digest_file="$ARTIFACT_DIR/$SERVICE.digest"
image_file="$ARTIFACT_DIR/$SERVICE.image"
registry_file="$ARTIFACT_DIR/registry.txt"

if [[ ! -s "$digest_file" ]]; then
  echo "ERROR: missing or empty digest artifact: $digest_file" >&2
  exit 1
fi

digest="$(tr -d '[:space:]' <"$digest_file" | sed -E 's/^sha256://')"
if [[ ! "$digest" =~ ^[0-9a-f]{64}$ ]]; then
  echo "ERROR: $digest_file does not contain a 64-character sha256 digest" >&2
  exit 1
fi

if [[ "$MODE" == "write" ]]; then
  # Buildah's IMAGE includes the immutable tag. A digest reference must not
  # carry both a tag and a digest, so strip either before appending @sha256.
  canonical="${IMAGE%%@*}"
  if [[ "${canonical##*/}" == *:* ]]; then
    canonical="${canonical%:*}"
  fi
  printf '%s\n' "$digest" >"$digest_file"
  printf '%s\n' "$canonical@sha256:$digest" >"$image_file"
  printf '%s\n' "$REGISTRY" >"$registry_file"
  echo "Wrote $image_file"
  exit 0
fi

if [[ ! -s "$image_file" ]]; then
  echo "ERROR: missing or empty image artifact: $image_file" >&2
  exit 1
fi
if [[ ! -s "$registry_file" ]]; then
  echo "ERROR: missing or empty registry artifact: $registry_file" >&2
  exit 1
fi

image="$(tr -d '[:space:]' <"$image_file")"
registry="$(tr -d '[:space:]' <"$registry_file")"
expected="$REGISTRY/$SERVICE@sha256:$digest"

if [[ "$image" != "$expected" ]]; then
  echo "ERROR: image artifact does not match its digest" >&2
  echo "  expected: $expected" >&2
  echo "  actual:   $image" >&2
  exit 1
fi
if [[ "$registry" != "$REGISTRY" ]]; then
  echo "ERROR: registry artifact does not match the expected registry" >&2
  echo "  expected: $REGISTRY" >&2
  echo "  actual:   $registry" >&2
  exit 1
fi

echo "Verified $image"
