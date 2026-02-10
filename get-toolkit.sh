#!/bin/bash
set -euo pipefail

# ============================================================
# get-toolkit.sh — Remote bootstrap installer
# ============================================================
# Usage: curl -fsSL https://raw.githubusercontent.com/hs-tool/hs-websphere-kit/main/get-toolkit.sh | sudo bash
# ============================================================

REPO="hs-tool/hs-websphere-kit"
TMP_DIR="$(mktemp -d)"

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

echo "Downloading latest release..."
TARBALL_URL="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
  | grep -o '"browser_download_url":\s*"[^"]*\.tar\.gz"' \
  | head -1 \
  | cut -d'"' -f4)"

if [[ -z "$TARBALL_URL" ]]; then
    echo "ERROR: Could not find release tarball." >&2
    exit 1
fi

curl -fsSL "$TARBALL_URL" -o "$TMP_DIR/toolkit.tar.gz"
tar xzf "$TMP_DIR/toolkit.tar.gz" -C "$TMP_DIR"
bash "$TMP_DIR/build-toolkit/install.sh" "$@"
