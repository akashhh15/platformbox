#!/usr/bin/env bash
# Offline validation for Phase 9 resilience files.
# No cluster, cloud API or load generator run is started.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -n "${OS:-}" ]]; then
  VENV_BIN=".venv/Scripts"
else
  VENV_BIN=".venv/bin"
fi
export PATH="$ROOT/$VENV_BIN:$ROOT/tools/bin:$PATH"

for bin in python k6; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "ERROR: $bin is not installed. Run 'make tools' first." >&2
    exit 1
  fi
done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/platformbox-resilience.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

echo "==> k6 version and profile syntax"
K6_VERSION="$(k6 version | grep -Eo 'v[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)"
if [[ "$K6_VERSION" != "v2.4.0" ]]; then
  echo "ERROR: expected k6 v2.4.0, found '$K6_VERSION'." >&2
  exit 1
fi
for script in loadtest/smoke.js loadtest/load.js loadtest/spike.js; do
  name="$(basename "$script" .js)"
  k6 inspect "$script" >"$WORK/$name.json"
done

python - "$WORK" <<'PY'
import json
import sys
from pathlib import Path

work = Path(sys.argv[1])
expected_thresholds = {
    "smoke": {"http_req_failed", "checks", "http_req_duration"},
    "load": {"http_req_failed", "checks", "http_req_duration"},
    "spike": {"http_req_failed", "checks", "http_req_duration"},
}
for name, metrics in expected_thresholds.items():
    config = json.loads((work / f"{name}.json").read_text(encoding="utf-8"))
    actual = set(config.get("thresholds") or {})
    if metrics - actual:
        raise SystemExit(f"{name}.js is missing thresholds: {sorted(metrics - actual)}")
    if name == "smoke" and config.get("vus") != 1:
        raise SystemExit("smoke.js must use exactly one VU")
    if name in {"load", "spike"} and not config.get("stages"):
        raise SystemExit(f"{name}.js must declare ramp stages")
PY

echo "==> Chaos Mesh installation is opt-in"
python - <<'PY'
from pathlib import Path

import yaml

path = Path("gitops/platform/chaos-mesh-applicationset.yaml")
doc = yaml.safe_load(path.read_text(encoding="utf-8"))
selector = doc["spec"]["generators"][0]["clusters"]["selector"]["matchLabels"]
if selector.get("platformbox.io/chaos-enabled") != "true":
    raise SystemExit("Chaos Mesh ApplicationSet is not cluster-gated")
source = doc["spec"]["template"]["spec"]["source"]
if source.get("targetRevision") != "2.8.8":
    raise SystemExit("Chaos Mesh chart is not pinned to 2.8.8")
values = source["helm"]["values"]
for expected in ("enableFilterNamespace: true", "runtime: containerd", "create: false"):
    if expected not in values:
        raise SystemExit(f"Chaos Mesh values are missing '{expected}'")
project = Path("gitops/projects/platform-project.yaml").read_text(encoding="utf-8")
if "https://charts.chaos-mesh.org" not in project:
    raise SystemExit("Chaos Mesh chart repo is not allowed by the platform AppProject")
PY

echo "==> Chaos experiment contracts"
python - <<'PY'
from pathlib import Path

import yaml

contracts = {
    "chaos/experiments/api-pod-kill.yaml": {
        "kind": "PodChaos",
        "name": "api-pod-kill-dev",
        "namespace": "app-dev",
        "action": "pod-kill",
    },
    "chaos/experiments/postgres-network-delay.yaml": {
        "kind": "NetworkChaos",
        "name": "api-to-postgres-latency-dev",
        "namespace": "app-dev",
        "action": "delay",
    },
}
for file, expected in contracts.items():
    doc = yaml.safe_load(Path(file).read_text(encoding="utf-8"))
    if doc.get("apiVersion") != "chaos-mesh.org/v1alpha1":
        raise SystemExit(f"{file} has an unexpected apiVersion")
    if doc.get("kind") != expected["kind"]:
        raise SystemExit(f"{file} has unexpected kind: {doc.get('kind')}")
    if doc["spec"].get("action") != expected["action"]:
        raise SystemExit(f"{file} has unexpected action: {doc['spec'].get('action')}")
    if doc["metadata"]["name"] != expected["name"]:
        raise SystemExit(f"{file} has an unexpected name")
    if doc["metadata"]["namespace"] != expected["namespace"]:
        raise SystemExit(f"{file} is not scoped to {expected['namespace']}")
    selector = doc["spec"].get("selector", {})
    if not selector.get("namespaces") or not selector.get("labelSelectors"):
        raise SystemExit(f"{file} has an unrestricted selector")
    if "secretName" in doc["spec"]:
        raise SystemExit(f"{file} must not reference cloud credentials")
    if "duration" in doc["spec"] and doc["spec"]["duration"] not in {"2m"}:
        raise SystemExit(f"{file} has an unexpected duration")

network = yaml.safe_load(Path("chaos/experiments/postgres-network-delay.yaml").read_text())
if network["spec"].get("direction") != "to":
    raise SystemExit("network delay must set direction explicitly")
if network["spec"]["target"]["selector"]["namespaces"] != ["app-data"]:
    raise SystemExit("network delay must target only the local data namespace")
PY

echo "==> Node-stop guard and shell syntax"
for script in chaos/experiments/kind-node-stop.sh scripts/resilience-validate.sh; do
  bash -n "$script"
done
python - <<'PY'
from pathlib import Path

text = Path("chaos/experiments/kind-node-stop.sh").read_text(encoding="utf-8")
if "^kind-worker" not in text or "CONFIRM=stop-kind-worker" not in text:
    raise SystemExit("kind-node-stop.sh lost its name guard or confirmation gate")
if "docker start" not in text:
    raise SystemExit("kind-node-stop.sh must print a restore command")
PY

echo "==> Game day and recovery documentation"
python - <<'PY'
from pathlib import Path

gameday = Path("chaos/gameday-template.md").read_text(encoding="utf-8")
for heading in (
    "## Hypothesis",
    "## Steady state (before injection)",
    "## Injection",
    "## Expected behaviour",
    "## Observed behaviour",
    "## Outcome",
    "## Fixes and follow-ups",
    "TODO(measure)",
):
    if heading not in gameday:
        raise SystemExit(f"gameday-template.md is missing '{heading}'")

resilience = Path("docs/resilience.md").read_text(encoding="utf-8")
for expected in (
    "kubectl drain",
    "kubectl cordon",
    "maxUnavailable: 1",
    "backup_retention_period",
    "Velero",
    "TODO(measure)",
):
    if expected not in resilience:
        raise SystemExit(f"docs/resilience.md is missing '{expected}'")

architecture = Path("docs/architecture.md").read_text(encoding="utf-8")
if "## Disaster recovery" not in architecture:
    raise SystemExit("docs/architecture.md has no disaster recovery section")
PY

echo "==> Resilience validation passed."
