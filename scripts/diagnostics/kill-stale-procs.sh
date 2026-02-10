#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail

CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

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
    echo "$pids" | xargs kill -9
    echo -e "${BOLD}Done.${NC}"
else
    echo "Aborted."
fi
