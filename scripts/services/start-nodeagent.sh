#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail


echo ""
echo -e "${BOLD}${CYAN}=== Start Node Agent ===${NC}"
echo -e "  Server: ${YELLOW}$SERVER_NAME${NC}"
echo ""

echo -e "  ${BOLD}Starting Node Agent...${NC}"
cd "$NODE_PROFILE/bin" || { echo "ERROR: Cannot cd to $NODE_PROFILE/bin"; exit 1; }
if ./startNode.sh; then
    echo -e "  ${GREEN}Node Agent started${NC}"
else
    echo -e "  ${YELLOW}WARNING: startNode.sh exited with non-zero status${NC}"
fi

cd "$HOME_DIR" || { echo "ERROR: Cannot cd to $HOME_DIR"; exit 1; }
echo ""
