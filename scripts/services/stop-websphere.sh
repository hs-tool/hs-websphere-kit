#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail

CYAN='\033[96m'
YELLOW='\033[93m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${BOLD}${CYAN}=== Stop WebSphere ===${NC}"
echo -e "  Server: ${YELLOW}$SERVER_NAME${NC}"
echo ""

bash "$(dirname "$0")/stop-nodeagent.sh"
bash "$(dirname "$0")/stop-dmgr.sh"

echo -e "${BOLD}WebSphere shutdown complete.${NC}"
echo ""
