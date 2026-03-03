#!/bin/bash
set -euo pipefail

# ============================================================
# uninstall.sh — Remove HS WebSphere Toolkit
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

INSTALL_PREFIX="/home/wasadmin/hs-websphere-kit"
SYMLINK="/usr/local/bin/hs-websphere-kit"

echo ""
echo -e "${BOLD}HS WebSphere Toolkit Uninstaller${NC}"
echo -e "────────────────────────────────────────────"
echo ""

# --- Confirm ---
echo -e "${YELLOW}This will permanently remove:${NC}"
echo -e "  ${INSTALL_PREFIX}"
echo -e "  ${SYMLINK}"
echo ""
read -p "Are you sure? (y/N): " confirm

if [[ "${confirm,,}" != "y" ]]; then
    echo -e "\n${BOLD}Cancelled.${NC}"
    exit 0
fi

# --- Remove symlink ---
if [[ -L "$SYMLINK" || -e "$SYMLINK" ]]; then
    if rm -f "$SYMLINK" 2>/dev/null; then
        echo -e "  ${GREEN}[OK]${NC} Removed ${SYMLINK}"
    else
        echo -e "  ${YELLOW}[SKIP]${NC} Cannot remove ${SYMLINK} (run with sudo)"
    fi
else
    echo -e "  ${YELLOW}[SKIP]${NC} ${SYMLINK} not found"
fi

# --- Remove install directory ---
if [[ -d "$INSTALL_PREFIX" ]]; then
    rm -rf "$INSTALL_PREFIX"
    echo -e "  ${GREEN}[OK]${NC} Removed ${INSTALL_PREFIX}"
else
    echo -e "  ${YELLOW}[SKIP]${NC} ${INSTALL_PREFIX} not found"
fi

echo ""
echo -e "${GREEN}${BOLD}Uninstall complete.${NC}"
echo ""
