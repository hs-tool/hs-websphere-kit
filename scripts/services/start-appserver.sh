#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail


echo ""
echo -e "${BOLD}${CYAN}=== Start Application Server ===${NC}"
echo -e "  Server:     ${YELLOW}$SERVER_NAME${NC}"
echo -e "  App Server: ${BOLD}$APP_SERVER${NC}"
echo ""

echo -e "  ${BOLD}Starting $APP_SERVER...${NC}"
cd "$NODE_PROFILE/bin" || { echo "ERROR: Cannot cd to $NODE_PROFILE/bin"; exit 1; }
if ./startServer.sh "$APP_SERVER"; then
    echo -e "  ${GREEN}$APP_SERVER started${NC}"
else
    echo -e "  ${YELLOW}WARNING: startServer.sh exited with non-zero status${NC}"
fi

cd "$HOME_DIR" || { echo "ERROR: Cannot cd to $HOME_DIR"; exit 1; }
echo ""
