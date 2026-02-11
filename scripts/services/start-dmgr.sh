#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail


echo ""
echo -e "${BOLD}${CYAN}=== Start Deployment Manager ===${NC}"
echo -e "  Server: ${YELLOW}$SERVER_NAME${NC}"
echo ""

echo -e "  ${BOLD}Starting Deployment Manager...${NC}"
cd "$NDM_PROFILE/bin" || { echo "ERROR: Cannot cd to $NDM_PROFILE/bin"; exit 1; }
if ./startManager.sh; then
    echo -e "  ${GREEN}Deployment Manager started${NC}"
else
    echo -e "  ${YELLOW}WARNING: startManager.sh exited with non-zero status${NC}"
fi

cd "$HOME_DIR" || { echo "ERROR: Cannot cd to $HOME_DIR"; exit 1; }
echo ""
