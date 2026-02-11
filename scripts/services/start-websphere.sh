#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail


echo ""
echo -e "${BOLD}${CYAN}=== Start WebSphere ===${NC}"
echo -e "  Server: ${YELLOW}$SERVER_NAME${NC}"
echo ""

bash "$(dirname "$0")/start-dmgr.sh"

# Brief wait for Dmgr to accept connections before starting Node Agent
echo -e "  ${BOLD}Waiting for Dmgr to initialize...${NC}"
sleep 10

bash "$(dirname "$0")/start-nodeagent.sh"

echo -e "${GREEN}${BOLD}WebSphere startup complete.${NC}"
echo ""
