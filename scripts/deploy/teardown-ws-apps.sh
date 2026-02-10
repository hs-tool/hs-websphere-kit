#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${BOLD}${CYAN}=== Teardown WAS Applications ===${NC}"
echo -e "  Environment: ${YELLOW}$WS_ENV_NAME${NC}"
echo ""
echo -e "  ${RED}This will remove all deployed applications from WebSphere.${NC}"
read -p "  Continue? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "  Aborted."
    exit 0
fi

if [[ ! -d "$WS_ADMIN_BIN" ]]; then
    echo -e "${RED}ERROR: WAS admin bin not found: $WS_ADMIN_BIN${NC}"
    echo "Has a build been deployed at least once?"
    exit 1
fi

start_time=$SECONDS

echo ""
echo -e "  ${BOLD}Running teardown...${NC}"
"$WS_ADMIN_BIN/wasadmin.sh" "$WS_ENV_NAME" teardown

elapsed=$(( SECONDS - start_time ))

echo ""
echo -e "${GREEN}${BOLD}  Teardown complete (${elapsed}s)${NC}"
echo ""
