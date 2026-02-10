#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail

RED='\033[91m'
YELLOW='\033[93m'
CYAN='\033[96m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${BOLD}${CYAN}=== Stop Application Server ===${NC}"
echo -e "  Server:     ${YELLOW}$SERVER_NAME${NC}"
echo -e "  App Server: ${BOLD}$APP_SERVER${NC}"
echo ""

echo -e "  ${BOLD}Stopping $APP_SERVER...${NC}"
cd "$NODE_PROFILE/bin" || { echo "ERROR: Cannot cd to $NODE_PROFILE/bin"; exit 1; }
./stopServer.sh "$APP_SERVER"
echo -e "  ${RED}$APP_SERVER stopped${NC}"

cd "$HOME_DIR" || { echo "ERROR: Cannot cd to $HOME_DIR"; exit 1; }
echo ""
