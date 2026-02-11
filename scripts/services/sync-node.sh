#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail


echo ""
echo -e "${BOLD}${CYAN}=== Sync Node ===${NC}"
echo -e "  Server: ${YELLOW}$SERVER_NAME${NC}"
echo ""

echo -e "  ${BOLD}Synchronizing node configuration with Dmgr...${NC}"
cd "$NODE_PROFILE/bin" || { echo "ERROR: Cannot cd to $NODE_PROFILE/bin"; exit 1; }

if ./syncNode.sh localhost 8879 2>&1; then
    echo ""
    echo -e "  ${GREEN}Node synchronization complete${NC}"
else
    echo ""
    echo -e "  ${YELLOW}WARNING: syncNode.sh exited with non-zero status${NC}"
    echo -e "  ${DIM}Ensure Dmgr is running and accessible on port 8879${NC}"
fi

cd "$HOME_DIR" || { echo "ERROR: Cannot cd to $HOME_DIR"; exit 1; }
echo ""
