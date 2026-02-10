#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"
set -euo pipefail

# --- Colors ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Current build version from override.properties
get_build_version() {
    if [[ -f "$DEPLOY_OVERRIDE" ]]; then
        grep -E "^project\.name=" "$DEPLOY_OVERRIDE" 2>/dev/null | tail -1 | cut -d'=' -f2
    else
        echo "?"
    fi
}

run_script() {
    local script="$SCRIPT_DIR/scripts/$1"
    if [[ ! -f "$script" ]]; then
        echo -e "${RED}Script not found: $script${NC}"
        return 1
    fi
    echo ""
    "$script"
}

while true; do
    clear
    BUILD_VER=$(get_build_version)

    echo ""
    echo -en "${BOLD}${CYAN}"
    sed -n '1,6s/^/  /p' "$SCRIPT_DIR/banner.txt"
    echo -en "${GREEN}"
    sed -n '7,12s/^/  /p' "$SCRIPT_DIR/banner.txt"
    echo -e "${NC}"
    echo -e "  ${DIM}Developed by Hafiz Syed Muhammad Usman${NC}"
    echo -e "  ${BOLD}Server: ${YELLOW}$SERVER_NAME${NC}    ${BOLD}Build: ${YELLOW}$BUILD_VER${NC}"
    echo ""

    # --- Services ---
    echo -e "  ${BOLD}${GREEN}SERVICES${NC}"
    echo -e "   ${BOLD} 1${NC}  Start MQ"
    echo -e "   ${BOLD} 2${NC}  Start WebSphere   ${DIM}(manager + node)${NC}"
    echo -e "   ${BOLD} 3${NC}  Stop WebSphere    ${DIM}(manager + node)${NC}"
    echo -e "   ${BOLD} 4${NC}  Start App Server   ${DIM}($APP_SERVER)${NC}"
    echo -e "   ${BOLD} 5${NC}  Stop App Server    ${DIM}($APP_SERVER)${NC}"
    echo -e "   ${BOLD} 6${NC}  Restart Cycle      ${DIM}(stop → clean → start)${NC}"
    echo -e "   ${BOLD} 7${NC}  Status"
    echo ""

    # --- Build & Deploy ---
    echo -e "  ${BOLD}${BLUE}BUILD & DEPLOY${NC}"
    echo -e "   ${BOLD} 8${NC}  Set Build Version  ${DIM}(current: $BUILD_VER)${NC}"
    echo -e "   ${BOLD} 9${NC}  Download Build     ${DIM}(FTP only)${NC}"
    echo -e "   ${BOLD}10${NC}  Deploy from Cache  ${DIM}(no FTP, use local)${NC}"
    echo -e "   ${BOLD}11${NC}  Full Upgrade       ${DIM}(clean + FTP + deploy)${NC}"
    echo -e "   ${BOLD}12${NC}  Teardown WAS Apps  ${DIM}(remove apps only)${NC}"
    echo -e "   ${BOLD}13${NC}  Build WAS Apps     ${DIM}(install apps only)${NC}"
    echo -e "   ${BOLD}14${NC}  Set Java 8 SDK"
    echo -e "   ${BOLD}15${NC}  Run Ant Target     ${DIM}(any target)${NC}"
    echo -e "   ${BOLD}16${NC}  End-to-End Build   ${DIM}(full pipeline)${NC}"
    echo ""

    # --- Maintenance ---
    echo -e "  ${BOLD}${MAGENTA}MAINTENANCE${NC}"
    echo -e "   ${BOLD}17${NC}  Clear Logs"
    echo -e "   ${BOLD}18${NC}  Remove Temp Files"
    echo -e "   ${BOLD}19${NC}  Check Disk Space"
    echo -e "   ${BOLD}20${NC}  Check Permissions  ${DIM}(audit only)${NC}"
    echo -e "   ${BOLD}21${NC}  Fix Permissions    ${DIM}(chown ${WAS_USER}:${WAS_GROUP})${NC}"
    echo ""

    # --- Diagnostics ---
    echo -e "  ${BOLD}${YELLOW}DIAGNOSTICS${NC}"
    echo -e "   ${BOLD}22${NC}  Tail Logs          ${DIM}(live follow)${NC}"
    echo -e "   ${BOLD}23${NC}  Kill Stale Procs"
    echo ""

    echo -e "   ${BOLD} 0${NC}  Exit"
    echo ""

    read -p "  Enter choice: " choice

    case "$choice" in
        1)  run_script "services/start-mq.sh" ;;
        2)  run_script "services/start-websphere.sh" ;;
        3)  run_script "services/stop-websphere.sh" ;;
        4)  run_script "services/start-appserver.sh" ;;
        5)  run_script "services/stop-appserver.sh" ;;
        6)  run_script "services/restart-websphere.sh" ;;
        7)  run_script "services/status.sh" ;;
        8)  run_script "deploy/set-build-version.sh" ;;
        9)  run_script "deploy/download-build.sh" ;;
        10) run_script "deploy/deploy-cached.sh" ;;
        11) run_script "deploy/full-upgrade.sh" ;;
        12) run_script "deploy/teardown-ws-apps.sh" ;;
        13) run_script "deploy/build-ws-apps.sh" ;;
        14) run_script "deploy/configure-java-8.sh" ;;
        15) run_script "deploy/run-ant.sh" ;;
        16) run_script "deploy/e2e-build.sh" ;;
        17) run_script "maintenance/clear-logs.sh" ;;
        18) run_script "maintenance/remove-temp-files.sh" ;;
        19) run_script "maintenance/check-disk.sh" ;;
        20) run_script "maintenance/check-permissions.sh" ;;
        21) run_script "maintenance/fix-permissions.sh" ;;
        22) run_script "diagnostics/tail-logs.sh" ;;
        23) run_script "diagnostics/kill-stale-procs.sh" ;;
        0)  echo -e "\n  ${BOLD}Exiting...${NC}"; break ;;
        *)  echo -e "\n  ${RED}Invalid option.${NC}" ;;
    esac

    echo ""
    read -p "  Press Enter to continue..."
done
