#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail

GREEN='\033[92m'
YELLOW='\033[93m'
CYAN='\033[96m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

echo ""
echo -e "${BOLD}${CYAN}=== Configure Java 8 SDK ===${NC}"
echo -e "  Server: ${YELLOW}$SERVER_NAME${NC}"
echo -e "  SDK:    ${BOLD}1.8_64${NC}"
echo ""

echo -e "  ${BOLD}Setting Java 8 as default profile SDK...${NC}"
cd "$NODE_PROFILE/bin" || { echo "ERROR: Cannot cd to $NODE_PROFILE/bin"; exit 1; }
sudo ./managesdk.sh -setNewProfileDefault -sdkname 1.8_64
echo -e "  ${GREEN}Default profile SDK set${NC}"

echo ""
echo -e "  ${BOLD}Enabling Java 8 for all profiles and servers...${NC}"
sudo ./managesdk.sh -enableProfileAll -sdkname 1.8_64 -enableServers
echo -e "  ${GREEN}All profiles enabled${NC}"

cd "$HOME_DIR" || { echo "ERROR: Cannot cd to $HOME_DIR"; exit 1; }

echo ""
echo -e "${GREEN}${BOLD}Java 8 SDK configuration complete.${NC}"
echo ""
