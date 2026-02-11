#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail


echo ""
echo -e "${BOLD}${CYAN}=== Stop Application Server ===${NC}"
echo -e "  Server:     ${YELLOW}$SERVER_NAME${NC}"
echo -e "  App Server: ${BOLD}$APP_SERVER${NC}"
echo ""

echo -e "  ${BOLD}Stopping $APP_SERVER...${NC}"
cd "$NODE_PROFILE/bin" || { echo "ERROR: Cannot cd to $NODE_PROFILE/bin"; exit 1; }
if ./stopServer.sh "$APP_SERVER"; then
    echo -e "  ${RED}$APP_SERVER stopped${NC}"
else
    echo -e "  ${YELLOW}WARNING: stopServer.sh exited with non-zero status (may already be stopped)${NC}"
fi

cd "$HOME_DIR" || { echo "ERROR: Cannot cd to $HOME_DIR"; exit 1; }
echo ""
