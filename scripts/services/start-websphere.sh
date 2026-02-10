#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail

CYAN='\033[96m'
GREEN='\033[92m'
YELLOW='\033[93m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${BOLD}${CYAN}=== Start WebSphere ===${NC}"
echo -e "  Server: ${YELLOW}$SERVER_NAME${NC}"
echo ""

bash "$(dirname "$0")/start-dmgr.sh"
bash "$(dirname "$0")/start-nodeagent.sh"

echo -e "${GREEN}${BOLD}WebSphere startup complete.${NC}"
echo ""
