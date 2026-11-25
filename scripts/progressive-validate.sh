#!/usr/bin/env bash
# Offline validation for Phase 8 progressive delivery manifests.
# No cluster, cloud API or Helm repository access is used.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -n "${OS:-}" ]]; then
  VENV_BIN=".venv/Scripts"
else
  VENV_BIN=".venv/bin"
fi
export PATH="$ROOT/$VENV_BIN:$ROOT/tools/bin:$PATH"

for bin in python kustomize yq jq promtool; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "ERROR: $bin is not installed. Run 'make tools' first." >&2
    exit 1
  fi
done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/platformbox-progressive.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

echo "==> AnalysisTemplate PromQL syntax"
kustomize build gitops/apps/overlays/dev >"$WORK/dev.yaml"
python - "$WORK/dev.yaml" "$WORK/analysis-rules.yaml" <<'PY'
import sys
from pathlib import Path

import yaml

rendered = list(yaml.safe_load_all(Path(sys.argv[1]).read_text(encoding="utf-8")))
templates = [doc for doc in rendered if doc.get("kind") == "AnalysisTemplate"]
if len(templates) != 2:
    raise SystemExit(f"expected 2 AnalysisTemplates, found {len(templates)}")

rules = []
for index, template in enumerate(templates):
    query = template["spec"]["metrics"][0]["provider"]["prometheus"]["query"]
    if "{{args.canary-hash}}" not in query:
        raise SystemExit(f"{template['metadata']['name']} does not filter by canary hash")
    condition = template["spec"]["metrics"][0]["successCondition"]
    if "result[0]" not in condition:
        raise SystemExit(f"{template['metadata']['name']} has an unsupported successCondition")
    rules.append(
        {
            "record": f"canary:analysis:{index}",
            "expr": query.replace("{{args.canary-hash}}", "testhash"),
        }
    )

Path(sys.argv[2]).write_text(
    yaml.safe_dump(
        {"groups": [{"name": "phase8-analysis-queries", "rules": rules}]},
        sort_keys=False,
    ),
    encoding="utf-8",
)
PY
promtool check rules "$WORK/analysis-rules.yaml"

echo "==> Notification templates and triggers"
for spec in \
  'gitops/bootstrap/argocd-notifications-values.yaml:.notifications.notifiers."service.webhook.alertmanager"' \
  'gitops/bootstrap/argocd-notifications-values.yaml:.notifications.templates."template.platformbox-sync-failed"' \
  'gitops/bootstrap/argocd-notifications-values.yaml:.notifications.templates."template.platformbox-health-degraded"' \
  'gitops/bootstrap/argocd-notifications-values.yaml:.notifications.triggers."trigger.platformbox-sync-failed"' \
  'gitops/bootstrap/argocd-notifications-values.yaml:.notifications.triggers."trigger.platformbox-health-degraded"'; do
  file="${spec%%:*}"
  query="${spec#*:}"
  if [[ "$(yq e "$query" "$file")" == "null" ]]; then
    echo "ERROR: missing notification config $query in $file." >&2
    exit 1
  fi
done

yq e '.spec.source.helm.values' gitops/platform/argo-rollouts.yaml >"$WORK/rollouts-values.yaml"
for query in \
  '.notifications.notifiers."service.webhook.alertmanager"' \
  '.notifications.templates."template.rollout-aborted"' \
  '.notifications.triggers."trigger.on-rollout-aborted"' \
  '.notifications.subscriptions[0].triggers[0]'; do
  if [[ "$(yq e "$query" "$WORK/rollouts-values.yaml")" == "null" ]]; then
    echo "ERROR: missing Rollouts notification config $query." >&2
    exit 1
  fi
done
# Alertmanager is intentionally the only notifier. Slack stays opt-in through
# the Phase 7 AlertmanagerConfig, so no secret is required on kind.
if yq e '.notifications | keys | join(",")' "$WORK/rollouts-values.yaml" | grep -qi slack; then
  echo "ERROR: Rollout notifications must not reference Slack directly." >&2
  exit 1
fi

python - "$WORK/rollouts-values.yaml" <<'PY'
import json
import re
import sys
from pathlib import Path

import yaml

for path in (Path("gitops/bootstrap/argocd-notifications-values.yaml"), Path(sys.argv[1])):
    config = yaml.safe_load(path.read_text(encoding="utf-8"))["notifications"]
    templates = config["templates"]
    if not templates:
        raise SystemExit(f"{path} has no notification templates")
    for name, spec in templates.items():
        # Helm passes each template as a YAML string, not as a nested mapping.
        parsed = yaml.safe_load(spec) if isinstance(spec, str) else spec
        body = parsed.get("webhook", {}).get("alertmanager", {}).get("body")
        if not body:
            raise SystemExit(f"{name} does not define an Alertmanager webhook body")
        rendered = re.sub(r"\{\{[^}]*\}\}", "sample", body)
        alerts = json.loads(rendered)
        if not alerts or "alertname" not in alerts[0].get("labels", {}):
            raise SystemExit(f"{name} does not render a valid Alertmanager alert")
PY

echo "==> Dashboard canary view"
jq -e '[.panels[] | select(.title | test("canary|stable"; "i"))] | length >= 2' \
  gitops/platform/observability/dashboards/api-red.json >/dev/null

echo "==> Demo scripts"
for script in scripts/demo-canary-good.sh scripts/demo-canary-bad.sh; do
  bash -n "$script"
done

python - <<'PY'
from pathlib import Path

overlays = {
    "gitops/apps/local/kustomization.yaml": "local",
    "gitops/apps/overlays/dev/kustomization.yaml": "dev",
}
for file, version in overlays.items():
    text = Path(file).read_text(encoding="utf-8")
    version_patch = (
        "        path: /spec/template/metadata/labels/app.kubernetes.io~1version\n"
        f"        value: {version}\n"
    )
    fault_patch = (
        "        path: /spec/template/spec/containers/0/env/4/value\n"
        '        value: "true"\n'
    )
    if text.count(version_patch) != 1 or text.count(fault_patch) != 1:
        raise SystemExit(f"{file} does not match the demo script patch contract")
PY

echo "==> Progressive delivery validation passed."
