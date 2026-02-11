#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail


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
if command -v dspmq &>/dev/null || [[ -d /opt/mqm/bin ]]; then
    local_dspmq="dspmq"
    command -v dspmq &>/dev/null || local_dspmq="/opt/mqm/bin/dspmq"
    dspmq_out=$(timeout 10 sudo -u "$MQ_USER" "$local_dspmq" 2>/dev/null || true)
    if [[ -n "$dspmq_out" ]]; then
        echo "$dspmq_out"
    else
        echo -e "  ${YELLOW}Could not query MQ (dspmq returned empty or timed out)${NC}"
    fi
else
    echo -e "  ${YELLOW}MQ not found on this system${NC}"
fi

# Disk space summary
echo ""
echo -e "${BOLD}${CYAN}=== Disk Usage ===${NC}"
df -h "$WAS_BASE" 2>/dev/null || df -h /
echo ""
