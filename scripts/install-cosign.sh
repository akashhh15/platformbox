#!/usr/bin/env bash
# Install the pinned Cosign CLI inside a CI job and print its path.
#
# The SHA-256 is decoded from the release's cosign-linux-amd64.sigstore.json
# metadata. The download is verified before the binary is made executable.

set -euo pipefail

COSIGN_VERSION="3.1.4"
COSIGN_SHA256="424e2c97d0b45fd7a6b608a87f090f35633f4c23ece5f092d48bba11aaf4bbfa"
COSIGN_URL="https://github.com/sigstore/cosign/releases/download/v${COSIGN_VERSION}/cosign-linux-amd64"
BIN_DIR="${1:-${CI_PROJECT_DIR:-.}/.ci-bin}"
TARGET="$BIN_DIR/cosign-$COSIGN_VERSION"

mkdir -p "$BIN_DIR"
curl -fsSL --retry 3 --connect-timeout 20 --max-time 900 "$COSIGN_URL" -o "$TARGET"
printf '%s  %s\n' "$COSIGN_SHA256" "$TARGET" | sha256sum -c -
chmod +x "$TARGET"
printf '%s\n' "$TARGET"
