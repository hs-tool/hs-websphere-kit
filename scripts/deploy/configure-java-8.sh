#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail


echo ""
echo -e "${BOLD}${CYAN}=== Configure Java 8 SDK ===${NC}"
echo -e "  Server: ${YELLOW}$SERVER_NAME${NC}"
echo -e "  SDK:    ${BOLD}1.8_64${NC}"
echo ""

echo -e "  ${BOLD}Setting Java 8 as default profile SDK...${NC}"
cd "$NODE_PROFILE/bin" || { echo "ERROR: Cannot cd to $NODE_PROFILE/bin"; exit 1; }

if [[ ! -x "./managesdk.sh" ]]; then
    echo -e "  ${YELLOW}ERROR: managesdk.sh not found or not executable in $NODE_PROFILE/bin${NC}"
    exit 1
fi

if sudo ./managesdk.sh -setNewProfileDefault -sdkname 1.8_64; then
    echo -e "  ${GREEN}Default profile SDK set${NC}"
else
    echo -e "  ${YELLOW}WARNING: setNewProfileDefault exited with non-zero status${NC}"
fi

echo ""
echo -e "  ${BOLD}Enabling Java 8 for all profiles and servers...${NC}"
if sudo ./managesdk.sh -enableProfileAll -sdkname 1.8_64 -enableServers; then
    echo -e "  ${GREEN}All profiles enabled${NC}"
else
    echo -e "  ${YELLOW}WARNING: enableProfileAll exited with non-zero status${NC}"
fi

cd "$HOME_DIR" || { echo "ERROR: Cannot cd to $HOME_DIR"; exit 1; }

echo ""
echo -e "${GREEN}${BOLD}Java 8 SDK configuration complete.${NC}"
echo ""
