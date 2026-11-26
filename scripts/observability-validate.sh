#!/usr/bin/env bash
# Offline validation for Phase 7 observability manifests.
#
# The PrometheusRule is a Kubernetes CRD, while promtool expects a plain rules
# file. Extract .spec into a temporary file so there is only one source of
# truth. No cluster and no cloud API are used.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -n "${OS:-}" ]]; then
  VENV_BIN=".venv/Scripts"
else
  VENV_BIN=".venv/bin"
fi
export PATH="$ROOT/$VENV_BIN:$ROOT/tools/bin:$PATH"

for bin in promtool jq yq kustomize; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "ERROR: $bin is not installed. Run 'make tools' first." >&2
    exit 1
  fi
done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/platformbox-observability.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

RULES_CRD="gitops/platform/observability/prometheus-rules.yaml"
TEST_FILE="gitops/platform/observability/prometheus-rules.test.yaml"
DASHBOARD_DIR="gitops/platform/observability/dashboards"

echo "==> Prometheus rules: syntax and unit tests"
yq e '.spec' "$RULES_CRD" >"$WORK/rules.yaml"
promtool check rules "$WORK/rules.yaml"
cp "$TEST_FILE" "$WORK/test.yaml"
promtool test rules "$WORK/test.yaml"

echo "==> Grafana dashboards: JSON validity"
mapfile -t dashboards < <(find "$DASHBOARD_DIR" -maxdepth 1 -name '*.json' -type f | sort)
if [[ "${#dashboards[@]}" -ne 7 ]]; then
  echo "ERROR: expected 7 dashboard JSON files, found ${#dashboards[@]}." >&2
  exit 1
fi

declare -A UIDS=()
for dashboard in "${dashboards[@]}"; do
  jq -e . "$dashboard" >/dev/null
  uid="$(jq -r '.uid // empty' "$dashboard")"
  title="$(jq -r '.title // empty' "$dashboard")"
  panels="$(jq -r '.panels | length' "$dashboard")"
  if [[ -z "$uid" || -z "$title" || "$panels" -eq 0 ]]; then
    echo "ERROR: $dashboard needs a uid, title and at least one panel." >&2
    exit 1
  fi
  if [[ -n "${UIDS[$uid]:-}" ]]; then
    echo "ERROR: duplicate Grafana dashboard uid '$uid'." >&2
    exit 1
  fi
  UIDS[$uid]=1
  printf '    %-28s %s panels\n' "$(basename "$dashboard")" "$panels"
done

echo "==> Alert metadata and runbook links"
mapfile -t alerts < <(yq e '.spec.groups[].rules[] | select(.alert != null) | .alert' "$RULES_CRD")
if [[ "${#alerts[@]}" -ne 10 ]]; then
  echo "ERROR: expected 10 alerting rules, found ${#alerts[@]}." >&2
  exit 1
fi

for alert in "${alerts[@]}"; do
  selector=".spec.groups[].rules[] | select(.alert == \"$alert\")"
  severity="$(yq e "$selector | .labels.severity" "$RULES_CRD")"
  summary="$(yq e "$selector | .annotations.summary" "$RULES_CRD")"
  description="$(yq e "$selector | .annotations.description" "$RULES_CRD")"
  url="$(yq e "$selector | .annotations.runbook_url" "$RULES_CRD")"
  if [[ "$severity" == "null" || "$summary" == "null" || "$description" == "null" || "$url" == "null" || -z "$severity" || -z "$summary" || -z "$description" || -z "$url" ]]; then
    echo "ERROR: $alert is missing severity, summary, description or runbook_url." >&2
    exit 1
  fi
  runbook="docs/runbooks/$(basename "$url")"
  if [[ ! -f "$runbook" ]]; then
    echo "ERROR: $alert points at a missing runbook: $runbook" >&2
    exit 1
  fi
  printf '    %-40s %s\n' "$alert" "$severity"
done

echo "==> Rendered observability resources"
kustomize build gitops/platform/observability >"$WORK/rendered.yaml"
dashboard_count="$(yq ea '[select(.kind == "ConfigMap" and .metadata.labels.grafana_dashboard == "1")] | length' "$WORK/rendered.yaml")"
if [[ "$dashboard_count" -ne 7 ]]; then
  echo "ERROR: expected 7 sidecar-labelled dashboard ConfigMaps, found $dashboard_count." >&2
  exit 1
fi
rule_scope="$(yq ea '[select(.kind == "PrometheusRule")] | map((.metadata.namespace == "monitoring") and (.metadata.labels["app.kubernetes.io/part-of"] == "platformbox")) | all' "$WORK/rendered.yaml")"
if [[ "$rule_scope" != "true" ]]; then
  echo "ERROR: PrometheusRule must be in monitoring with the platformbox part-of label." >&2
  exit 1
fi
monitor_count="$(yq ea '[select(.kind == "ServiceMonitor")] | length' "$WORK/rendered.yaml")"
if [[ "$monitor_count" -ne 3 ]]; then
  echo "ERROR: expected 3 platform ServiceMonitors, found $monitor_count." >&2
  exit 1
fi

echo "==> Slack remains opt-in on the default platform render"
kustomize build gitops/platform >"$WORK/platform.yaml"
slack_resources="$(yq ea '[select(.kind == "AlertmanagerConfig" or (.kind == "ExternalSecret" and .metadata.name == "alertmanager-slack"))] | length' "$WORK/platform.yaml")"
if [[ "$slack_resources" -ne 0 ]]; then
  echo "ERROR: Slack resources must only come from the gated ApplicationSet." >&2
  exit 1
fi

echo "==> Observability validation passed."
