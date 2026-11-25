#!/usr/bin/env bash
# Prepare a safe, reviewable Git branch for the bad-release canary demo.
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

BRANCH="demo/canary-bad-$TARGET-$(date -u +%Y%m%d%H%M%S)"
RELEASE="v0.8.1-bad"

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

if text.count(version_old) != 1 or text.count(fault_old) != 1:
    raise SystemExit("expected one version-label patch and one fault-injection patch")

# Keep FAULT_INJECTION_ENABLED=true so only the canary returns 503 for
# POST /chaos/fail. The stable ReplicaSet retains the previous release.
path.write_text(text.replace(version_old, version_new), encoding="utf-8")
PY

kustomize build "$OVERLAY" >/dev/null
git add "$OVERLAY/kustomization.yaml"
git commit -m "demo: trigger bad canary ($TARGET)"

if [[ "$TARGET" == "local" ]]; then
  DEPLOY_COMMAND="kubectl apply -k $OVERLAY"
  PUSH_COMMAND="# Local kind demo: no push or PR is required."
else
  DEPLOY_COMMAND="# Merge the PR; Argo CD syncs app-dev automatically."
  PUSH_COMMAND="git push -u origin \"$BRANCH\""
fi

cat <<EOF

Bad-release demo branch '$BRANCH' is ready for target '$TARGET'.

Fault injection stays enabled for the canary. The success-rate analysis counts
POST /chaos/fail responses (unlike the 30-day SLO), so two failed measurements
abort the rollout and restore the stable ReplicaSet.

Next steps (run them yourself):
  $PUSH_COMMAND
  $DEPLOY_COMMAND

Watch the rollout:
  kubectl -n $NAMESPACE argo rollouts get rollout api --watch

In another terminal, send failures only to the canary through the shared Service:
  kubectl -n $NAMESPACE port-forward svc/api 8080:8000
  for i in \$(seq 1 60); do curl -s -o /dev/null -w '%{http_code}\n' -X POST http://localhost:8080/chaos/fail; sleep 1; done

Expected result: the rollout aborts before 100%, and the stable version serves
all traffic again. Do not merge this demo branch into long-lived branches.
EOF
