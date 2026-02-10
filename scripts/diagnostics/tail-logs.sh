#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail

CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

APPSERVER_OUT="$NODE_PROFILE/logs/$APP_SERVER/SystemOut.log"
APPSERVER_ERR="$NODE_PROFILE/logs/$APP_SERVER/SystemErr.log"
DMGR_OUT="$NDM_PROFILE/logs/dmgr/SystemOut.log"
NODEAGENT_OUT="$NODE_PROFILE/logs/nodeagent/SystemOut.log"

echo ""
echo -e "${BOLD}${CYAN}Select logs to tail:${NC}"
echo "  1. App Server SystemOut  (most common)"
echo "  2. App Server SystemErr"
echo "  3. App Server Out + Err  (combined)"
echo "  4. Deployment Manager SystemOut"
echo "  5. Node Agent SystemOut"
echo "  6. All key logs          (multi-tail)"
echo ""
read -p "Choice [1]: " choice
choice="${choice:-1}"

case "$choice" in
    1)
        echo -e "Tailing ${BOLD}$APPSERVER_OUT${NC} ..."
        tail -f "$APPSERVER_OUT"
        ;;
    2)
        echo -e "Tailing ${BOLD}$APPSERVER_ERR${NC} ..."
        tail -f "$APPSERVER_ERR"
        ;;
    3)
        echo -e "Tailing ${BOLD}App Server Out + Err${NC} ..."
        tail -f "$APPSERVER_OUT" "$APPSERVER_ERR"
        ;;
    4)
        echo -e "Tailing ${BOLD}$DMGR_OUT${NC} ..."
        tail -f "$DMGR_OUT"
        ;;
    5)
        echo -e "Tailing ${BOLD}$NODEAGENT_OUT${NC} ..."
        tail -f "$NODEAGENT_OUT"
        ;;
    6)
        echo -e "Tailing ${BOLD}all key logs${NC} (Ctrl+C to stop)..."
        tail -f "$APPSERVER_OUT" "$APPSERVER_ERR" "$DMGR_OUT" "$NODEAGENT_OUT"
        ;;
    *)
        echo "Invalid choice."
        exit 1
        ;;
esac
