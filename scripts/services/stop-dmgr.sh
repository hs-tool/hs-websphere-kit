#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail


echo ""
echo -e "${BOLD}${CYAN}=== Stop Deployment Manager ===${NC}"
echo -e "  Server: ${YELLOW}$SERVER_NAME${NC}"
echo ""

echo -e "  ${BOLD}Stopping Deployment Manager...${NC}"
cd "$NDM_PROFILE/bin" || { echo "ERROR: Cannot cd to $NDM_PROFILE/bin"; exit 1; }
if ./stopManager.sh; then
    echo -e "  ${RED}Deployment Manager stopped${NC}"
else
    echo -e "  ${YELLOW}WARNING: stopManager.sh exited with non-zero status (may already be stopped)${NC}"
fi

cd "$HOME_DIR" || { echo "ERROR: Cannot cd to $HOME_DIR"; exit 1; }
echo ""
