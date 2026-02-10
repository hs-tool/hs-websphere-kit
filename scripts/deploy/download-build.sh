#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

echo ""
echo -e "${BOLD}${CYAN}=== Download Build (FTP) ===${NC}"
echo ""

# Show current build version
current_name=$(grep -E "^project\.name=" "$DEPLOY_OVERRIDE" 2>/dev/null | tail -1 | cut -d'=' -f2)
echo -e "  Build:  ${BOLD}${YELLOW}${current_name:-<not set>}${NC}"
echo ""

# Check if already cached
archive_dir="$DEPLOY_PATH/archive"
if [[ -n "$current_name" && -d "$archive_dir/product/$current_name" ]]; then
    echo -e "  ${GREEN}This build is already cached locally.${NC}"
    echo -e "  ${DIM}$archive_dir/product/$current_name${NC}"
    echo ""
    read -p "  Re-download anyway? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "  Skipped."
        exit 0
    fi
fi

echo ""
echo -e "  ${BOLD}Downloading from FTP...${NC}"
echo ""

start_time=$SECONDS

run_deploy_script "getbuild.sh"

elapsed=$(( SECONDS - start_time ))
minutes=$(( elapsed / 60 ))
seconds=$(( elapsed % 60 ))

echo ""
echo -e "${GREEN}${BOLD}  Download complete in ${minutes}m ${seconds}s${NC}"
echo ""
