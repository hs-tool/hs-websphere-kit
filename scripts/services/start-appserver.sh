#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail

GREEN='\033[92m'
YELLOW='\033[93m'
CYAN='\033[96m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${BOLD}${CYAN}=== Start Application Server ===${NC}"
echo -e "  Server:     ${YELLOW}$SERVER_NAME${NC}"
echo -e "  App Server: ${BOLD}$APP_SERVER${NC}"
echo ""

echo -e "  ${BOLD}Starting $APP_SERVER...${NC}"
cd "$NODE_PROFILE/bin" || { echo "ERROR: Cannot cd to $NODE_PROFILE/bin"; exit 1; }
./startServer.sh "$APP_SERVER"
echo -e "  ${GREEN}$APP_SERVER started${NC}"

cd "$HOME_DIR" || { echo "ERROR: Cannot cd to $HOME_DIR"; exit 1; }
echo ""
