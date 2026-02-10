#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail

# --- Colors ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

print_status() {
    local label="$1"
    local pattern="$2"

    if ps -ef | grep -v grep | grep -q "$pattern"; then
        printf "  %-25s ${GREEN}RUNNING${NC}\n" "$label"
    else
        printf "  %-25s ${RED}STOPPED${NC}\n" "$label"
    fi
}

echo ""
echo -e "${BOLD}${CYAN}=== Service Status ===${NC}"
echo -e "${BOLD}Server: ${YELLOW}$SERVER_NAME${NC}"
echo ""

# WebSphere Deployment Manager
print_status "Deployment Manager" "dmgr"

# WebSphere Node Agent
print_status "Node Agent" "nodeagent"

# Application Server
print_status "App Server ($APP_SERVER)" "$APP_SERVER"

# MQ Queue Manager
echo ""
echo -e "${BOLD}${CYAN}=== MQ Status ===${NC}"
if command -v dspmq &>/dev/null; then
    dspmq_out=$(su -c "dspmq" "$MQ_USER" 2>/dev/null || true)
    if [[ -n "$dspmq_out" ]]; then
        echo "$dspmq_out"
    else
        echo -e "  ${YELLOW}Could not query MQ (dspmq returned empty)${NC}"
    fi
elif [[ -d /opt/mqm/bin ]]; then
    dspmq_out=$(su -c "/opt/mqm/bin/dspmq" "$MQ_USER" 2>/dev/null || true)
    if [[ -n "$dspmq_out" ]]; then
        echo "$dspmq_out"
    else
        echo -e "  ${YELLOW}Could not query MQ${NC}"
    fi
else
    echo -e "  ${YELLOW}MQ not found on this system${NC}"
fi

# Disk space summary
echo ""
echo -e "${BOLD}${CYAN}=== Disk Usage ===${NC}"
df -h "$WAS_BASE" 2>/dev/null || df -h /
echo ""
