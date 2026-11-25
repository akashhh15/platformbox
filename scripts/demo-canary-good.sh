#!/usr/bin/env bash
# Prepare a safe, reviewable Git branch for the good-release canary demo.
# The script edits one overlay and never pushes or deploys by itself.
# TARGET=local (default) uses kind; TARGET=dev prepares an EKS dev PR.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -n "${OS:-}" ]]; then
  VENV_BIN=".venv/Scripts"
else
  VENV_BIN=".venv/bin"
fi
export PATH="$ROOT/$VENV_BIN:$ROOT/tools/bin:$PATH"

TARGET="${TARGET:-local}"
case "$TARGET" in
  local) OVERLAY="gitops/apps/local"; NAMESPACE="app-local"; OLD_VERSION="local" ;;
  dev)   OVERLAY="gitops/apps/overlays/dev"; NAMESPACE="app-dev"; OLD_VERSION="dev" ;;
  *) echo "ERROR: TARGET must be 'local' or 'dev'." >&2; exit 1 ;;
esac

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: commit or stash local changes before running the demo." >&2
  exit 1
fi

BRANCH="demo/canary-good-$TARGET-$(date -u +%Y%m%d%H%M%S)"
RELEASE="v0.8.1-good"

git checkout -b "$BRANCH"

python - "$OVERLAY" "$OLD_VERSION" "$RELEASE" <<'PY'
import sys
from pathlib import Path

overlay, old_version, release = sys.argv[1:4]
path = Path(overlay) / "kustomization.yaml"
text = path.read_text(encoding="utf-8")

version_old = (
    "        path: /spec/template/metadata/labels/app.kubernetes.io~1version\n"
    f"        value: {old_version}\n"
)
version_new = version_old.replace(f"value: {old_version}", f"value: {release}")
fault_old = (
    "        path: /spec/template/spec/containers/0/env/4/value\n"
    '        value: "true"\n'
)
fault_new = (
    "        path: /spec/template/spec/containers/0/env/4/value\n"
    '        value: "false"\n'
)

for fragment in (version_old, fault_old):
    if text.count(fragment) != 1:
        raise SystemExit(f"expected exactly one match for {fragment!r}")

path.write_text(
    text.replace(version_old, version_new).replace(fault_old, fault_new),
    encoding="utf-8",
)
PY

kustomize build "$OVERLAY" >/dev/null
git add "$OVERLAY/kustomization.yaml"
git commit -m "demo: trigger good canary ($TARGET)"

if [[ "$TARGET" == "local" ]]; then
  DEPLOY_COMMAND="kubectl apply -k $OVERLAY"
  PUSH_COMMAND="# Local kind demo: no push or PR is required."
else
  DEPLOY_COMMAND="# Merge the PR; Argo CD syncs app-dev automatically."
  PUSH_COMMAND="git push -u origin \"$BRANCH\""
fi

cat <<EOF

Good-release demo branch '$BRANCH' is ready for target '$TARGET'.

The version label change creates a canary ReplicaSet with the same pinned image;
a real release would also change images.newTag through CI (ADR-014). Fault
injection is disabled so the canary should pass both analyses.

Next steps (run them yourself):
  $PUSH_COMMAND
  $DEPLOY_COMMAND

Watch the rollout:
  kubectl -n $NAMESPACE argo rollouts get rollout api --watch

In another terminal, generate steady traffic:
  kubectl -n $NAMESPACE port-forward svc/api 8080:8000
  for i in \$(seq 1 120); do curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/items; sleep 1; done

Expected result: weights 10 -> 25 -> 50 -> 100 with no analysis failures.
EOF
