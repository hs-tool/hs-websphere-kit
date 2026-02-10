#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${BOLD}${CYAN}=== Build WAS Applications ===${NC}"
echo -e "  Environment: ${YELLOW}$WS_ENV_NAME${NC}"
echo ""

if [[ ! -d "$WS_ADMIN_BIN" ]]; then
    echo -e "${RED}ERROR: WAS admin bin not found: $WS_ADMIN_BIN${NC}"
    echo "Has a build been downloaded and unpacked?"
    exit 1
fi

echo "  This will install/rebuild applications into WebSphere."
read -p "  Continue? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "  Aborted."
    exit 0
fi

start_time=$SECONDS

echo ""
echo -e "  ${BOLD}Running build...${NC}"
"$WS_ADMIN_BIN/wasadmin.sh" "$WS_ENV_NAME" build

elapsed=$(( SECONDS - start_time ))

echo ""
echo -e "${GREEN}${BOLD}  Build complete (${elapsed}s)${NC}"
echo ""
