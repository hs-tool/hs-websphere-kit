#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail


echo ""
echo -e "${BOLD}${CYAN}=== Stop Node Agent ===${NC}"
echo -e "  Server: ${YELLOW}$SERVER_NAME${NC}"
echo ""

echo -e "  ${BOLD}Stopping Node Agent...${NC}"
cd "$NODE_PROFILE/bin" || { echo "ERROR: Cannot cd to $NODE_PROFILE/bin"; exit 1; }
if ./stopNode.sh; then
    echo -e "  ${RED}Node Agent stopped${NC}"
else
    echo -e "  ${YELLOW}WARNING: stopNode.sh exited with non-zero status (may already be stopped)${NC}"
fi

cd "$HOME_DIR" || { echo "ERROR: Cannot cd to $HOME_DIR"; exit 1; }
echo ""
