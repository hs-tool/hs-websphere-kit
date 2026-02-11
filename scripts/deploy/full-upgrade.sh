#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail


echo ""
echo -e "${BOLD}${CYAN}=== Full Upgrade (Clean + FTP + Deploy) ===${NC}"
echo ""

# Show current build version
current_name=$(grep -E "^project\.name=" "$DEPLOY_OVERRIDE" 2>/dev/null | tail -1 | cut -d'=' -f2)
echo -e "  Build:  ${BOLD}${YELLOW}${current_name:-<not set>}${NC}"
echo -e "  Server: ${YELLOW}$SERVER_NAME${NC}"
echo ""

echo "  This will:"
echo "    1. Clean old deployment and archives"
echo "    2. Download build from FTP"
echo "    3. Unpack release"
echo "    4. Teardown current WAS apps"
echo "    5. Build new WAS apps"
echo ""

read -p "  Continue? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "  Aborted."
    exit 0
fi

start_time=$SECONDS

echo ""
echo -e "  ${BOLD}Running full upgrade...${NC}"
echo ""

run_deploy_script "upgrade.sh"

elapsed=$(( SECONDS - start_time ))
minutes=$(( elapsed / 60 ))
seconds=$(( elapsed % 60 ))

echo ""
echo -e "${GREEN}${BOLD}  Full upgrade complete in ${minutes}m ${seconds}s${NC}"
echo ""
