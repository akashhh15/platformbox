#!/usr/bin/env bash
# Install the pinned toolchain into tools/bin and .venv.
#
# Supported platform: Windows 10/11 with Git Bash (MINGW/MSYS).
# Linux and macOS users should follow docs/SETUP.md and use their package
# manager; the versions in scripts/tool-versions.env are the source of truth.
#
# This script does not use administrator rights and writes only inside the
# repository (tools/ and .venv/, both gitignored).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# shellcheck source=tool-versions.env
source scripts/tool-versions.env

case "$(uname -s)" in
  MINGW*|MSYS*) ;;
  *)
    echo "This installer supports Windows + Git Bash only."
    echo "On Linux/macOS, follow docs/SETUP.md and use your package manager."
    exit 1
    ;;
esac

BIN="$ROOT/tools/bin"
TMP="$ROOT/tools/tmp"
FORCE="${FORCE:-0}"
mkdir -p "$BIN" "$TMP"

need() {
  [ "$FORCE" = "1" ] || [ ! -x "$BIN/$1.exe" ]
}

fetch() {
  local url="$1" out="$2"
  echo "  downloading $(basename "$out")"
  rm -f "$TMP/$out"
  # --max-time keeps a throttled GitHub release from hanging the installer.
  if ! curl -fL --retry 3 --retry-delay 2 --connect-timeout 20 --max-time 900 \
      -o "$TMP/$out" "$url"; then
    echo "ERROR: download failed: $url" >&2
    echo "If GitHub releases are slow on this network, install the tool with" >&2
    echo "winget (see docs/SETUP.md, Troubleshooting) and re-run this script." >&2
    exit 1
  fi
}

extract() {
  local zip="$1" dir="$2"
  rm -rf "$TMP/$dir"
  unzip -o -q "$TMP/$zip" -d "$TMP/$dir"
}

copy_exe() {
  local src="$1" dest="$2"
  cp "$src" "$BIN/$dest"
  chmod +x "$BIN/$dest" 2>/dev/null || true
}

copy_first_exe() {
  local dir="$1" dest="$2" src
  src="$(find "$TMP/$dir" -type f -iname '*.exe' | head -n 1)"
  if [ -z "$src" ]; then
    echo "ERROR: no .exe found in $TMP/$dir" >&2
    exit 1
  fi
  copy_exe "$src" "$dest"
}

echo "==> Installing binaries into tools/bin"

if need make; then
  fetch "https://downloads.sourceforge.net/project/ezwinports/make-${MAKE_VERSION}-without-guile-w32-bin.zip" make.zip
  extract make.zip make
  copy_exe "$TMP/make/bin/make.exe" make.exe
fi

if need terraform; then
  fetch "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_windows_amd64.zip" terraform.zip
  extract terraform.zip terraform
  copy_exe "$TMP/terraform/terraform.exe" terraform.exe
fi

if need tflint; then
  fetch "https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_windows_amd64.zip" tflint.zip
  extract tflint.zip tflint
  copy_exe "$TMP/tflint/tflint.exe" tflint.exe
fi

if need terraform-docs; then
  fetch "https://github.com/terraform-docs/terraform-docs/releases/download/v${TERRAFORM_DOCS_VERSION}/terraform-docs-v${TERRAFORM_DOCS_VERSION}-windows-amd64.zip" terraform-docs.zip
  extract terraform-docs.zip terraform-docs
  copy_exe "$TMP/terraform-docs/terraform-docs.exe" terraform-docs.exe
fi

if need trivy; then
  fetch "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Windows-64bit.zip" trivy.zip
  extract trivy.zip trivy
  copy_exe "$TMP/trivy/trivy.exe" trivy.exe
fi

if need gitleaks; then
  fetch "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_windows_x64.zip" gitleaks.zip
  extract gitleaks.zip gitleaks
  copy_exe "$TMP/gitleaks/gitleaks.exe" gitleaks.exe
fi

if need hadolint; then
  fetch "https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-windows-x86_64.exe" hadolint.exe
  copy_exe "$TMP/hadolint.exe" hadolint.exe
fi

if need kustomize; then
  fetch "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/v${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_windows_amd64.zip" kustomize.zip
  extract kustomize.zip kustomize
  copy_exe "$TMP/kustomize/kustomize.exe" kustomize.exe
fi

if need helm; then
  fetch "https://get.helm.sh/helm-v${HELM_VERSION}-windows-amd64.zip" helm.zip
  extract helm.zip helm
  copy_first_exe helm helm.exe
fi

if need kind; then
  fetch "https://github.com/kubernetes-sigs/kind/releases/download/v${KIND_VERSION}/kind-windows-amd64" kind.exe
  copy_exe "$TMP/kind.exe" kind.exe
fi

if need kubeconform; then
  fetch "https://github.com/yannh/kubeconform/releases/download/v${KUBECONFORM_VERSION}/kubeconform-windows-amd64.zip" kubeconform.zip
  extract kubeconform.zip kubeconform
  copy_exe "$TMP/kubeconform/kubeconform.exe" kubeconform.exe
fi

if need actionlint; then
  fetch "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/actionlint_${ACTIONLINT_VERSION}_windows_amd64.zip" actionlint.zip
  extract actionlint.zip actionlint
  copy_exe "$TMP/actionlint/actionlint.exe" actionlint.exe
fi

if need jq; then
  fetch "https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-windows-amd64.exe" jq.exe
  copy_exe "$TMP/jq.exe" jq.exe
fi

if need yq; then
  fetch "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_windows_amd64.exe" yq.exe
  copy_exe "$TMP/yq.exe" yq.exe
fi

if need cosign; then
  fetch "https://github.com/sigstore/cosign/releases/download/v${COSIGN_VERSION}/cosign-windows-amd64.exe" cosign.exe
  copy_exe "$TMP/cosign.exe" cosign.exe
fi

if need syft; then
  fetch "https://github.com/anchore/syft/releases/download/v${SYFT_VERSION}/syft_${SYFT_VERSION}_windows_amd64.zip" syft.zip
  extract syft.zip syft
  copy_exe "$TMP/syft/syft.exe" syft.exe
fi

if need kyverno; then
  fetch "https://github.com/kyverno/kyverno/releases/download/v${KYVERNO_VERSION}/kyverno-cli_v${KYVERNO_VERSION}_windows_x86_64.zip" kyverno.zip
  extract kyverno.zip kyverno
  copy_first_exe kyverno kyverno.exe
fi

if need promtool; then
  fetch "https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.windows-amd64.zip" prometheus.zip
  extract prometheus.zip prometheus
  copy_exe "$(find "$TMP/prometheus" -type f -name prometheus.exe | head -n 1)" prometheus.exe
  copy_exe "$(find "$TMP/prometheus" -type f -name promtool.exe | head -n 1)" promtool.exe
fi

if need infracost; then
  fetch "https://github.com/infracost/infracost/releases/download/v${INFRACOST_VERSION}/infracost-windows-amd64.zip" infracost.zip
  extract infracost.zip infracost
  copy_first_exe infracost infracost.exe
fi

if need shellcheck; then
  fetch "https://github.com/koalaman/shellcheck/releases/download/v${SHELLCHECK_VERSION}/shellcheck-v${SHELLCHECK_VERSION}.zip" shellcheck.zip
  extract shellcheck.zip shellcheck
  copy_first_exe shellcheck shellcheck.exe
fi

echo "==> Installing Python tooling into .venv"

if [ ! -x "$ROOT/.venv/Scripts/python.exe" ]; then
  if command -v python >/dev/null 2>&1; then
    PYTHON=python
  elif command -v py >/dev/null 2>&1; then
    PYTHON="py -3"
  else
    echo "ERROR: Python 3.12+ is required but was not found." >&2
    exit 1
  fi
  $PYTHON -m venv "$ROOT/.venv"
fi

"$ROOT/.venv/Scripts/python.exe" -m pip install --upgrade pip
"$ROOT/.venv/Scripts/python.exe" -m pip install -r "$ROOT/requirements-dev.txt"

echo "==> Installed tool versions"
bash "$ROOT/scripts/check-tools.sh"
