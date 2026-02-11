#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail


echo ""
echo -e "${BOLD}${CYAN}=== Kill Stale WebSphere Processes ===${NC}"
echo ""

ws_procs=$(ps -ef | grep '[w]ebsphere' || true)

if [[ -z "$ws_procs" ]]; then
    echo "No WebSphere processes found."
    exit 0
fi

echo -e "${BOLD}Current WebSphere processes:${NC}"
echo "$ws_procs"
echo ""

read -p "Enter port/keyword to filter (or 'all' to kill all, blank to skip): " filter

if [[ -z "$filter" ]]; then
    echo "Skipped."
    exit 0
fi

if [[ "$filter" == "all" ]]; then
    pids=$(echo "$ws_procs" | awk '{print $2}')
else
    pids=$(echo "$ws_procs" | grep "$filter" | awk '{print $2}' || true)
fi

if [[ -z "$pids" ]]; then
    echo "No processes matched filter '$filter'."
    exit 0
fi

echo ""
echo -e "${RED}${BOLD}Will kill PIDs:${NC} $pids"
read -p "Confirm? (y/N): " confirm

if [[ "$confirm" =~ ^[Yy]$ ]]; then
    echo -e "  Sending SIGTERM (graceful)..."
    echo "$pids" | xargs kill -15 2>/dev/null || true
    sleep 5
    # Check if any are still running, then force kill
    still_running=""
    for pid in $pids; do
        if kill -0 "$pid" 2>/dev/null; then
            still_running="$still_running $pid"
        fi
    done
    if [[ -n "$still_running" ]]; then
        echo -e "  ${YELLOW}Processes still alive:${NC}$still_running"
        echo -e "  Sending SIGKILL (force)..."
        echo "$still_running" | xargs kill -9 2>/dev/null || true
    fi
    echo -e "${BOLD}Done.${NC}"
else
    echo "Aborted."
fi
