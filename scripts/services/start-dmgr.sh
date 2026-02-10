#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail

GREEN='\033[92m'
YELLOW='\033[93m'
CYAN='\033[96m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${BOLD}${CYAN}=== Start Deployment Manager ===${NC}"
echo -e "  Server: ${YELLOW}$SERVER_NAME${NC}"
echo ""

echo -e "  ${BOLD}Starting Deployment Manager...${NC}"
cd "$NDM_PROFILE/bin" || { echo "ERROR: Cannot cd to $NDM_PROFILE/bin"; exit 1; }
./startManager.sh
echo -e "  ${GREEN}Deployment Manager started${NC}"

cd "$HOME_DIR" || { echo "ERROR: Cannot cd to $HOME_DIR"; exit 1; }
echo ""
