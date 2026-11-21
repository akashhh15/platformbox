#!/usr/bin/env bash
# Verify that the required toolchain is available and print versions.
# Required tools fail the script; optional tools are reported but do not fail
# until the phase that needs them.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export PATH="$ROOT/.venv/Scripts:$ROOT/tools/bin:$PATH"

required=(
  make terraform tflint terraform-docs trivy gitleaks hadolint
  pre-commit yamllint ruff pytest checkov
)
optional=(
  git docker kind kubectl helm kustomize kubeconform actionlint jq yq
  cosign syft kyverno promtool infracost shellcheck
)

version_of() {
  case "$1" in
    make) make --version 2>&1 | head -n 1 ;;
    terraform) terraform version 2>&1 | head -n 1 ;;
    tflint) tflint --version 2>&1 | head -n 1 ;;
    terraform-docs) terraform-docs version 2>&1 | head -n 1 ;;
    trivy) trivy --version 2>&1 | head -n 1 ;;
    gitleaks) gitleaks version 2>&1 | head -n 1 ;;
    hadolint) hadolint --version 2>&1 | head -n 1 ;;
    pre-commit) pre-commit --version 2>&1 | head -n 1 ;;
    yamllint) yamllint --version 2>&1 | head -n 1 ;;
    ruff) ruff --version 2>&1 | head -n 1 ;;
    pytest) pytest --version 2>&1 | head -n 1 ;;
    checkov) bash "$ROOT/scripts/checkov.sh" --version 2>&1 | head -n 1 ;;
    git) git --version 2>&1 | head -n 1 ;;
    docker) docker --version 2>&1 | head -n 1 ;;
    kind) kind version 2>&1 | head -n 1 ;;
    kubectl) kubectl version --client 2>&1 | head -n 1 ;;
    helm) helm version --short 2>&1 | head -n 1 ;;
    kustomize) kustomize version 2>&1 | head -n 1 ;;
    kubeconform) kubeconform -v 2>&1 | head -n 1 ;;
    actionlint) actionlint -version 2>&1 | head -n 1 ;;
    jq) jq --version 2>&1 | head -n 1 ;;
    yq) yq --version 2>&1 | head -n 1 ;;
    cosign) cosign version 2>&1 | grep -m1 'GitVersion' || cosign version 2>&1 | head -n 1 ;;
    syft) syft version 2>&1 | head -n 1 ;;
    kyverno) kyverno version 2>&1 | head -n 1 ;;
    promtool) promtool --version 2>&1 | head -n 1 ;;
    infracost) infracost --version 2>&1 | head -n 1 ;;
    shellcheck) shellcheck --version 2>&1 | grep -m1 'version:' ;;
    *) "$1" --version 2>&1 | head -n 1 ;;
  esac
}

failed=0

echo ""
echo "Required tools:"
for tool in "${required[@]}"; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf '  %-16s %s\n' "$tool" "$(version_of "$tool")"
  else
    printf '  %-16s MISSING\n' "$tool"
    failed=$((failed + 1))
  fi
done

echo ""
echo "Optional tools (needed by later phases):"
for tool in "${optional[@]}"; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf '  %-16s %s\n' "$tool" "$(version_of "$tool")"
  else
    printf '  %-16s missing (install before the phase that needs it)\n' "$tool"
  fi
done

echo ""
if [ "$failed" -ne 0 ]; then
  echo "ERROR: $failed required tool(s) missing. Run: make tools"
  exit 1
fi

echo "All required tools are present."
