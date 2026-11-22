#!/usr/bin/env bash
# Offline contract and parity tests for the application overlays.
#
# The AWS path cannot be applied in the zero-cost local mode (ADR-000), so this
# script turns the differences between the local and AWS overlays into explicit
# assertions. It proves that the four overlays render the same workload
# contract and that only the documented substitutions differ. No cluster and no
# cloud API are used. See ADR-020.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export PATH="$ROOT/tools/bin:$PATH"

for bin in kustomize yq; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "ERROR: $bin is not installed. Run 'make tools' first." >&2
    exit 1
  fi
done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/platformbox-contract.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0

check() {
  local desc="$1" actual="$2" expected="$3"
  if [[ "$actual" == "$expected" ]]; then
    PASS=$((PASS + 1))
  else
    echo "    FAIL: $desc (expected '$expected', got '$actual')"
    FAIL=$((FAIL + 1))
  fi
}

# Values expected to differ between the local substitute and the AWS overlays.
declare -A NAMESPACE STORE_KIND STORE_NAME INGRESS_CLASS CHAOS IMAGE_TAG IMAGE_PREFIX

for env in dev staging prod local; do
  case "$env" in
    local)
      dir="gitops/apps/local"
      NAMESPACE[$env]="app-local"
      STORE_KIND[$env]="SecretStore"
      STORE_NAME[$env]="local-fake"
      INGRESS_CLASS[$env]="nginx"
      CHAOS[$env]="true"
      IMAGE_TAG[$env]="local"
      IMAGE_PREFIX[$env]="platformbox"
      ;;
    *)
      dir="gitops/apps/overlays/$env"
      NAMESPACE[$env]="app-$env"
      STORE_KIND[$env]="ClusterSecretStore"
      STORE_NAME[$env]="aws-secretsmanager"
      INGRESS_CLASS[$env]="alb"
      if [[ "$env" == "prod" ]]; then
        CHAOS[$env]="false"
      else
        CHAOS[$env]="true"
      fi
      IMAGE_TAG[$env]="$env"
      IMAGE_PREFIX[$env]="ghcr.io/akashhh15/platformbox"
      ;;
  esac

  render="$WORK/$env.yaml"
  kustomize build "$dir" >"$render"

  echo "==> contract: $env"

  # One workload per service, with api as a Rollout (ADR-018).
  check "$env api Rollout count" "$(yq ea '[select(.kind == "Rollout" and .metadata.name == "api")] | length' "$render")" "1"
  check "$env worker Deployment count" "$(yq ea '[select(.kind == "Deployment" and .metadata.name == "worker")] | length' "$render")" "1"
  check "$env frontend Deployment count" "$(yq ea '[select(.kind == "Deployment" and .metadata.name == "frontend")] | length' "$render")" "1"

  # Workload hardening contract shared by all overlays.
  workloads='select(.kind == "Deployment" or .kind == "Rollout")'
  check "$env standard labels" "$(yq ea "[$workloads | ((.metadata.labels | has(\"app.kubernetes.io/name\")) and (.metadata.labels | has(\"app.kubernetes.io/instance\")) and (.metadata.labels | has(\"app.kubernetes.io/component\")) and (.metadata.labels | has(\"app.kubernetes.io/part-of\")))] | all" "$render")" "true"
  check "$env runAsNonRoot" "$(yq ea "[$workloads | .spec.template.spec.securityContext.runAsNonRoot] | all" "$render")" "true"
  check "$env seccomp RuntimeDefault" "$(yq ea "[$workloads | .spec.template.spec.securityContext.seccompProfile.type == \"RuntimeDefault\"] | all" "$render")" "true"
  check "$env no privilege escalation" "$(yq ea "[$workloads | .spec.template.spec.containers[0].securityContext.allowPrivilegeEscalation == false] | all" "$render")" "true"
  check "$env read-only root filesystem" "$(yq ea "[$workloads | .spec.template.spec.containers[0].securityContext.readOnlyRootFilesystem == true] | all" "$render")" "true"
  check "$env drop ALL capabilities" "$(yq ea "[$workloads | .spec.template.spec.containers[0].securityContext.capabilities.drop | contains([\"ALL\"])] | all" "$render")" "true"
  check "$env resource requests and limits" "$(yq ea "[$workloads | ((.spec.template.spec.containers[0].resources.requests.cpu != null) and (.spec.template.spec.containers[0].resources.requests.memory != null) and (.spec.template.spec.containers[0].resources.limits.cpu != null) and (.spec.template.spec.containers[0].resources.limits.memory != null))] | all" "$render")" "true"
  check "$env liveness and readiness probes" "$(yq ea "[$workloads | ((.spec.template.spec.containers[0].livenessProbe != null) and (.spec.template.spec.containers[0].readinessProbe != null))] | all" "$render")" "true"

  # Per-service supporting resources.
  for svc in api worker frontend; do
    check "$env $svc ServiceAccount" "$(yq ea "[select(.kind == \"ServiceAccount\" and .metadata.name == \"$svc\")] | length" "$render")" "1"
    check "$env $svc Service" "$(yq ea "[select(.kind == \"Service\" and .metadata.name == \"$svc\")] | length" "$render")" "1"
    check "$env $svc PDB" "$(yq ea "[select(.kind == \"PodDisruptionBudget\" and .metadata.name == \"$svc\")] | length" "$render")" "1"
    check "$env $svc HPA" "$(yq ea "[select(.kind == \"HorizontalPodAutoscaler\" and .metadata.name == \"$svc\")] | length" "$render")" "1"
  done
  for svc in api worker; do
    check "$env $svc ServiceMonitor" "$(yq ea "[select(.kind == \"ServiceMonitor\" and .metadata.name == \"$svc\")] | length" "$render")" "1"
  done

  # Default-deny plus explicit allows.
  check "$env default-deny NetworkPolicy" "$(yq ea '[select(.kind == "NetworkPolicy" and .metadata.name == "default-deny")] | length' "$render")" "1"
  check "$env NetworkPolicy count" "$(yq ea '[select(.kind == "NetworkPolicy")] | length' "$render")" "7"

  # Rollout uses a step-less canary as a basic rolling update (ADR-018).
  check "$env canary without steps" "$(yq ea '[select(.kind == "Rollout") | ((.spec.strategy.canary != null) and (.spec.strategy.canary.steps == null))] | all' "$render")" "true"

  # Documented substitutions: store, ingress class, images and chaos toggle.
  check "$env ExternalSecret count" "$(yq ea '[select(.kind == "ExternalSecret")] | length' "$render")" "2"
  check "$env secret store kind" "$(yq ea '[select(.kind == "ExternalSecret") | .spec.secretStoreRef.kind == "'"${STORE_KIND[$env]}"'"] | all' "$render")" "true"
  check "$env secret store name" "$(yq ea '[select(.kind == "ExternalSecret") | .spec.secretStoreRef.name == "'"${STORE_NAME[$env]}"'"] | all' "$render")" "true"
  check "$env ingress class" "$(yq ea '[select(.kind == "Ingress") | .spec.ingressClassName == "'"${INGRESS_CLASS[$env]}"'"] | all' "$render")" "true"
  check "$env chaos toggle" "$(yq ea 'select(.kind == "Rollout") | .spec.template.spec.containers[0].env[] | select(.name == "FAULT_INJECTION_ENABLED") | .value' "$render")" "${CHAOS[$env]}"
  for svc in api worker frontend; do
    if [[ "$env" == "local" ]]; then
      expected_image="${IMAGE_PREFIX[$env]}-$svc:${IMAGE_TAG[$env]}"
    else
      expected_image="${IMAGE_PREFIX[$env]}/$svc:${IMAGE_TAG[$env]}"
    fi
    check "$env $svc image" "$(yq ea "select(.kind == \"Deployment\" or .kind == \"Rollout\") | select(.metadata.name == \"$svc\") | .spec.template.spec.containers[0].image" "$render")" "$expected_image"
  done
  check "$env namespace" "$(yq ea '[select(.kind != null and .kind != "Namespace") | .metadata.namespace == "'"${NAMESPACE[$env]}"'"] | all' "$render")" "true"

  if [[ "$env" != "local" ]]; then
    check "$env ALB annotations" "$(yq ea '[select(.kind == "Ingress") | ((.metadata.annotations | has("alb.ingress.kubernetes.io/scheme")) and (.metadata.annotations | has("alb.ingress.kubernetes.io/target-type")) and (.metadata.annotations | has("alb.ingress.kubernetes.io/healthcheck-path")))] | all' "$render")" "true"
  fi

  if grep -Eq 'AKIA[0-9A-Z]{16}|arn:aws:iam::[0-9]{12}:' "$render"; then
    echo "    FAIL: $env rendered output contains a credential-like value"
    FAIL=$((FAIL + 1))
  fi
done

echo "==> parity: resource identities across overlays"
identities() {
  yq e 'select(.kind != null and .kind != "Namespace" and .kind != "SecretStore") | .kind + "/" + .metadata.name' "$1" | grep -v '^---$' | sort
}
for env in staging prod local; do
  identities "$WORK/dev.yaml" >"$WORK/dev.ids"
  identities "$WORK/$env.yaml" >"$WORK/$env.ids"
  if diff -u "$WORK/dev.ids" "$WORK/$env.ids" >"$WORK/$env.diff"; then
    echo "    ok - $env matches dev ($(wc -l <"$WORK/dev.ids") shared resources)"
    PASS=$((PASS + 1))
  else
    echo "    FAIL: $env resource identities differ from dev"
    cat "$WORK/$env.diff"
    FAIL=$((FAIL + 1))
  fi
done

echo "==> Contract summary: $PASS passed, $FAIL failed"
if ((FAIL > 0)); then
  exit 1
fi
