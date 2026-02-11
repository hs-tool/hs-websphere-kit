#!/bin/bash
set -euo pipefail

# ============================================================
# install.sh — Production installer for HS WebSphere Toolkit
# ============================================================
# Usage: ./install.sh [--prefix /custom/path]
# Default: /home/wasadmin/toolkit
# ============================================================

# Colors only when running in a real terminal
if [[ -t 1 ]]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    BOLD='\033[1m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BOLD=''; NC=''
fi

INSTALL_PREFIX="/home/wasadmin/toolkit"
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION="unknown"

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --prefix)
            INSTALL_PREFIX="$2"
            shift 2
            ;;
        --prefix=*)
            INSTALL_PREFIX="${1#*=}"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--prefix /custom/path]"
            echo "Default install path: /home/wasadmin/toolkit"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Usage: $0 [--prefix /custom/path]"
            exit 1
            ;;
    esac
done

# --- Read version ---
if [[ -f "$SOURCE_DIR/VERSION" ]]; then
    VERSION="$(cat "$SOURCE_DIR/VERSION" | tr -d '[:space:]')"
fi

echo ""
echo -e "${BOLD}HS WebSphere Toolkit Installer v${VERSION}${NC}"
echo "--------------------------------------------"
echo ""

# --- Pre-flight checks ---
echo -e "${BOLD}Pre-flight checks...${NC}"

# Verify wasadmin user exists
if ! id -u wasadmin &>/dev/null; then
    echo -e "${RED}ERROR: User 'wasadmin' does not exist on this system.${NC}"
    echo "Create the user first: useradd -m wasadmin"
    exit 1
fi
echo -e "  ${GREEN}[OK]${NC} User 'wasadmin' exists"

# Verify source files
for f in config.sh menu.sh banner.txt; do
    if [[ ! -f "$SOURCE_DIR/$f" ]]; then
        echo -e "${RED}ERROR: Required file missing: $f${NC}"
        echo "Are you running the installer from an extracted tarball?"
        exit 1
    fi
done

for d in lib scripts; do
    if [[ ! -d "$SOURCE_DIR/$d" ]]; then
        echo -e "${RED}ERROR: $d/ directory missing.${NC}"
        exit 1
    fi
done
echo -e "  ${GREEN}[OK]${NC} Source files verified"

# --- Clean existing installation ---
if [[ -d "$INSTALL_PREFIX" ]]; then
    rm -rf "$INSTALL_PREFIX"
fi

# --- Install ---
echo ""
echo -e "${BOLD}Installing to ${INSTALL_PREFIX}...${NC}"

mkdir -p "$INSTALL_PREFIX"

# Copy core files
cp "$SOURCE_DIR/config.sh"    "$INSTALL_PREFIX/"
cp "$SOURCE_DIR/menu.sh"      "$INSTALL_PREFIX/"
cp "$SOURCE_DIR/banner.txt"   "$INSTALL_PREFIX/"
cp "$SOURCE_DIR/VERSION"      "$INSTALL_PREFIX/"
cp "$SOURCE_DIR/uninstall.sh" "$INSTALL_PREFIX/"

# Copy lib and scripts recursively
cp -r "$SOURCE_DIR/lib"     "$INSTALL_PREFIX/"
cp -r "$SOURCE_DIR/scripts" "$INSTALL_PREFIX/"

echo -e "  ${GREEN}[OK]${NC} Files copied"

# --- Lock down permissions ---
echo -e "${BOLD}Locking down permissions...${NC}"

find "$INSTALL_PREFIX" -type d -exec chmod 700 {} +
find "$INSTALL_PREFIX" -type f -name "*.sh" -exec chmod 700 {} +
find "$INSTALL_PREFIX" -type f ! -name "*.sh" -exec chmod 600 {} +

echo -e "  ${GREEN}[OK]${NC} Permissions: 700 dirs/scripts, 600 data"

# --- Symlink ---
echo -e "${BOLD}Creating symlink...${NC}"

SYMLINK="/usr/local/bin/toolkit"
if ln -sf "$INSTALL_PREFIX/menu.sh" "$SYMLINK" 2>/dev/null; then
    echo -e "  ${GREEN}[OK]${NC} ${SYMLINK} -> ${INSTALL_PREFIX}/menu.sh"
else
    echo -e "  ${YELLOW}[SKIP]${NC} Cannot write to /usr/local/bin"
    echo "         You can run directly: ${INSTALL_PREFIX}/menu.sh"
fi

# --- Done ---
echo ""
echo "--------------------------------------------"
echo -e "${GREEN}${BOLD}Installation complete!${NC}"
echo ""
echo "  Version:  ${VERSION}"
echo "  Location: ${INSTALL_PREFIX}"
echo ""
echo "  Run ${INSTALL_PREFIX}/menu.sh to launch the toolkit."
echo ""
