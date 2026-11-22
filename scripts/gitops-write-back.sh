#!/usr/bin/env bash
# Write signed image digests into the dev overlay and push one commit to GitHub.
#
# This helper is called by the GitLab `deploy-gitops` job. It never talks to a
# cluster: Argo CD is the only deployer (ADR-003). It writes only the dev
# overlay; staging and prod are promoted by pull requests.
#
# Required environment:
#   GITHUB_REPOSITORY   owner/name of the GitHub repository
#   GITOPS_WRITE_TOKEN  fine-grained token with Contents: Read and write
#   CI_COMMIT_SHORT_SHA commit that produced the images
#   artifacts/*.image   fully qualified ECR image references
#   artifacts/*.digest  matching 64-character sha256 digests
#   artifacts/registry.txt  ECR registry host from the build job

set -euo pipefail

KUSTOMIZE_VERSION="5.8.3"
KUSTOMIZE_SHA256="cb9e31198d3f63b44848bd0afc4c8efc56e6cfef9c93a4a39a211940e6decd61"
BASE_IMAGE_PREFIX="ghcr.io/akashhh15/platformbox"
OVERLAY="gitops/apps/overlays/dev/kustomization.yaml"
ARTIFACT_DIR="${ARTIFACT_DIR:-artifacts}"

: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required (owner/name)}"
: "${GITOPS_WRITE_TOKEN:?GITOPS_WRITE_TOKEN is required}"
: "${CI_COMMIT_SHORT_SHA:?CI_COMMIT_SHORT_SHA is required}"

for path in "$ARTIFACT_DIR/registry.txt" \
  "$ARTIFACT_DIR/api.image" "$ARTIFACT_DIR/api.digest" \
  "$ARTIFACT_DIR/worker.image" "$ARTIFACT_DIR/worker.digest" \
  "$ARTIFACT_DIR/frontend.image" "$ARTIFACT_DIR/frontend.digest"; do
  if [[ ! -s "$path" ]]; then
    echo "ERROR: missing or empty build artifact: $path" >&2
    exit 1
  fi
done

ECR_REGISTRY="$(tr -d '[:space:]' <"$ARTIFACT_DIR/registry.txt")"
if [[ ! "$ECR_REGISTRY" =~ ^[0-9]{12}\.dkr\.ecr\.[a-z0-9-]+\.amazonaws\.com$ ]]; then
  echo "ERROR: invalid ECR registry in artifacts/registry.txt: $ECR_REGISTRY" >&2
  exit 1
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/platformbox-writeback.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

if command -v kustomize >/dev/null 2>&1; then
  KUSTOMIZE_BIN="$(command -v kustomize)"
else
  KUSTOMIZE_BIN="$WORK/bin/kustomize"
  mkdir -p "$WORK/bin"
  KUSTOMIZE_URL="https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz"
  curl -fsSL --retry 3 --max-time 300 "$KUSTOMIZE_URL" -o "$WORK/kustomize.tar.gz"
  printf '%s  %s\n' "$KUSTOMIZE_SHA256" "$WORK/kustomize.tar.gz" | sha256sum -c -
  tar -xzf "$WORK/kustomize.tar.gz" -C "$WORK/bin" kustomize
  chmod +x "$KUSTOMIZE_BIN"
fi

REPO_DIR="$WORK/repo"
git -c http.extraheader="AUTHORIZATION: bearer ${GITOPS_WRITE_TOKEN}" \
  clone --depth 1 --branch main \
  "https://github.com/${GITHUB_REPOSITORY}.git" "$REPO_DIR"
git -C "$REPO_DIR" config user.name "platformbox-ci"
git -C "$REPO_DIR" config user.email "ci@users.noreply.github.com"

commit_body=""
for svc in api worker frontend; do
  digest="$(tr -d '[:space:]' <"$ARTIFACT_DIR/$svc.digest")"
  image="$(tr -d '[:space:]' <"$ARTIFACT_DIR/$svc.image")"
  if [[ ! "$digest" =~ ^[0-9a-f]{64}$ ]]; then
    echo "ERROR: $svc digest is not a 64-character sha256" >&2
    exit 1
  fi
  expected="$ECR_REGISTRY/$svc@sha256:$digest"
  if [[ "$image" != "$expected" ]]; then
    echo "ERROR: $svc image artifact does not match its digest" >&2
    echo "  expected: $expected" >&2
    echo "  actual:   $image" >&2
    exit 1
  fi
  commit_body+="$svc@sha256:$digest"$'\n'
done

for attempt in 1 2 3; do
  echo "==> write-back attempt $attempt/3"
  git -C "$REPO_DIR" fetch --depth 1 origin main
  git -C "$REPO_DIR" reset --hard origin/main

  for svc in api worker frontend; do
    digest="$(tr -d '[:space:]' <"$ARTIFACT_DIR/$svc.digest")"
    (
      cd "$REPO_DIR/gitops/apps/overlays/dev"
      "$KUSTOMIZE_BIN" edit set image \
        "$BASE_IMAGE_PREFIX/$svc=$ECR_REGISTRY/$svc@sha256:$digest"
    )
  done

  if git -C "$REPO_DIR" diff --quiet -- "$OVERLAY"; then
    echo "No image changes; nothing to commit."
    exit 0
  fi

  git -C "$REPO_DIR" add "$OVERLAY"
  git -C "$REPO_DIR" commit \
    -m "chore(gitops): deploy dev images ${CI_COMMIT_SHORT_SHA} [skip ci]" \
    -m "$commit_body"

  if git -C "$REPO_DIR" -c http.extraheader="AUTHORIZATION: bearer ${GITOPS_WRITE_TOKEN}" \
    push origin HEAD:main; then
    echo "Pushed dev image digests to ${GITHUB_REPOSITORY}:main."
    exit 0
  fi
  echo "Push was rejected; refreshing and retrying." >&2
done

echo "ERROR: GitOps write-back failed after 3 attempts." >&2
exit 1
