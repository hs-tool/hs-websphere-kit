#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail

RED='\033[91m'
YELLOW='\033[93m'
CYAN='\033[96m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${BOLD}${CYAN}=== Stop WebSphere ===${NC}"
echo -e "  Server: ${YELLOW}$SERVER_NAME${NC}"
echo ""

echo -e "  ${BOLD}Stopping Deployment Manager...${NC}"
cd "$NDM_PROFILE/bin" || { echo "ERROR: Cannot cd to $NDM_PROFILE/bin"; exit 1; }
./stopManager.sh
echo -e "  ${RED}Deployment Manager stopped${NC}"

echo ""
echo -e "  ${BOLD}Stopping Node Agent...${NC}"
cd "$NODE_PROFILE/bin" || { echo "ERROR: Cannot cd to $NODE_PROFILE/bin"; exit 1; }
./stopNode.sh
echo -e "  ${RED}Node Agent stopped${NC}"

cd "$HOME_DIR" || { echo "ERROR: Cannot cd to $HOME_DIR"; exit 1; }

echo ""
echo -e "${BOLD}WebSphere shutdown complete.${NC}"
echo ""
