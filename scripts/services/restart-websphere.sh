#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"


echo ""
echo -e "${BOLD}${CYAN}=== Full WebSphere Restart Cycle ===${NC}"
echo -e "Server: ${YELLOW}$SERVER_NAME${NC}"
echo ""
echo "This will: Stop WAS -> Clear Logs -> Remove Temp -> Start WAS"
read -p "Continue? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

start_time=$SECONDS

echo ""
echo -e "${BOLD}[1/4] Stopping WebSphere...${NC}"
"$SCRIPT_DIR/stop-websphere.sh"

echo ""
echo -e "${BOLD}[2/4] Clearing logs...${NC}"
"$TOOLKIT_ROOT/scripts/maintenance/clear-logs.sh"

echo ""
echo -e "${BOLD}[3/4] Removing temp files...${NC}"
"$TOOLKIT_ROOT/scripts/maintenance/remove-temp-files.sh"

echo ""
echo -e "${BOLD}[4/4] Starting WebSphere...${NC}"
"$SCRIPT_DIR/start-websphere.sh"

elapsed=$(( SECONDS - start_time ))
minutes=$(( elapsed / 60 ))
seconds=$(( elapsed % 60 ))

echo ""
echo -e "${GREEN}${BOLD}Restart complete in ${minutes}m ${seconds}s${NC}"
