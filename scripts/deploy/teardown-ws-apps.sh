#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail


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
if "$WS_ADMIN_BIN/wasadmin.sh" "$WS_ENV_NAME" teardown; then
    elapsed=$(( SECONDS - start_time ))
    echo ""
    echo -e "${GREEN}${BOLD}  Teardown complete (${elapsed}s)${NC}"
else
    elapsed=$(( SECONDS - start_time ))
    echo ""
    echo -e "${RED}${BOLD}  Teardown FAILED (${elapsed}s)${NC}"
fi
echo ""
