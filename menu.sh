#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"
set -euo pipefail

# --- Colors ---
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

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

show_banner() {
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
}

# --- Sub-menus ---

menu_services() {
    while true; do
        show_banner
        echo -e "  ${BOLD}${GREEN}SERVICES${NC}"
        echo ""
        echo -e "   ${BOLD}1${NC}  Start MQ"
        echo -e "   ${BOLD}2${NC}  Start WebSphere   ${DIM}(manager + node)${NC}"
        echo -e "   ${BOLD}3${NC}  Stop WebSphere    ${DIM}(manager + node)${NC}"
        echo -e "   ${BOLD}4${NC}  Start App Server   ${DIM}($APP_SERVER)${NC}"
        echo -e "   ${BOLD}5${NC}  Stop App Server    ${DIM}($APP_SERVER)${NC}"
        echo -e "   ${BOLD}6${NC}  Restart Cycle      ${DIM}(stop > clean > start)${NC}"
        echo -e "   ${BOLD}7${NC}  Status"
        echo ""
        echo -e "   ${BOLD}0${NC}  Back"
        echo ""
        read -p "  Enter choice: " choice
        case "$choice" in
            1) run_script "services/start-mq.sh" ;;
            2) run_script "services/start-websphere.sh" ;;
            3) run_script "services/stop-websphere.sh" ;;
            4) run_script "services/start-appserver.sh" ;;
            5) run_script "services/stop-appserver.sh" ;;
            6) run_script "services/restart-websphere.sh" ;;
            7) run_script "services/status.sh" ;;
            0) return ;;
            *) echo -e "\n  ${RED}Invalid option.${NC}" ;;
        esac
        echo ""
        read -p "  Press Enter to continue..."
    done
}

menu_deploy() {
    while true; do
        show_banner
        BUILD_VER=$(get_build_version)
        echo -e "  ${BOLD}${BLUE}BUILD & DEPLOY${NC}"
        echo ""
        echo -e "   ${BOLD}1${NC}  Set Build Version  ${DIM}(current: $BUILD_VER)${NC}"
        echo -e "   ${BOLD}2${NC}  Download Build     ${DIM}(FTP only)${NC}"
        echo -e "   ${BOLD}3${NC}  Deploy from Cache  ${DIM}(no FTP, use local)${NC}"
        echo -e "   ${BOLD}4${NC}  Full Upgrade       ${DIM}(clean + FTP + deploy)${NC}"
        echo -e "   ${BOLD}5${NC}  Teardown WAS Apps  ${DIM}(remove apps only)${NC}"
        echo -e "   ${BOLD}6${NC}  Build WAS Apps     ${DIM}(install apps only)${NC}"
        echo -e "   ${BOLD}7${NC}  Set Java 8 SDK"
        echo -e "   ${BOLD}8${NC}  Run Ant Target     ${DIM}(any target)${NC}"
        echo -e "   ${BOLD}9${NC}  End-to-End Build   ${DIM}(full pipeline)${NC}"
        echo ""
        echo -e "   ${BOLD}0${NC}  Back"
        echo ""
        read -p "  Enter choice: " choice
        case "$choice" in
            1) run_script "deploy/set-build-version.sh" ;;
            2) run_script "deploy/download-build.sh" ;;
            3) run_script "deploy/deploy-cached.sh" ;;
            4) run_script "deploy/full-upgrade.sh" ;;
            5) run_script "deploy/teardown-ws-apps.sh" ;;
            6) run_script "deploy/build-ws-apps.sh" ;;
            7) run_script "deploy/configure-java-8.sh" ;;
            8) run_script "deploy/run-ant.sh" ;;
            9) run_script "deploy/e2e-build.sh" ;;
            0) return ;;
            *) echo -e "\n  ${RED}Invalid option.${NC}" ;;
        esac
        echo ""
        read -p "  Press Enter to continue..."
    done
}

menu_maintenance() {
    while true; do
        show_banner
        echo -e "  ${BOLD}${MAGENTA}MAINTENANCE${NC}"
        echo ""
        echo -e "   ${BOLD}1${NC}  Clear Logs"
        echo -e "   ${BOLD}2${NC}  Remove Temp Files"
        echo -e "   ${BOLD}3${NC}  Check Disk Space"
        echo -e "   ${BOLD}4${NC}  Check Permissions  ${DIM}(audit only)${NC}"
        echo -e "   ${BOLD}5${NC}  Fix Permissions    ${DIM}(chown ${WAS_USER}:${WAS_GROUP})${NC}"
        echo ""
        echo -e "   ${BOLD}0${NC}  Back"
        echo ""
        read -p "  Enter choice: " choice
        case "$choice" in
            1) run_script "maintenance/clear-logs.sh" ;;
            2) run_script "maintenance/remove-temp-files.sh" ;;
            3) run_script "maintenance/check-disk.sh" ;;
            4) run_script "maintenance/check-permissions.sh" ;;
            5) run_script "maintenance/fix-permissions.sh" ;;
            0) return ;;
            *) echo -e "\n  ${RED}Invalid option.${NC}" ;;
        esac
        echo ""
        read -p "  Press Enter to continue..."
    done
}

menu_diagnostics() {
    while true; do
        show_banner
        echo -e "  ${BOLD}${YELLOW}DIAGNOSTICS${NC}"
        echo ""
        echo -e "   ${BOLD}1${NC}  Tail Logs          ${DIM}(live follow)${NC}"
        echo -e "   ${BOLD}2${NC}  Kill Stale Procs"
        echo ""
        echo -e "   ${BOLD}0${NC}  Back"
        echo ""
        read -p "  Enter choice: " choice
        case "$choice" in
            1) run_script "diagnostics/tail-logs.sh" ;;
            2) run_script "diagnostics/kill-stale-procs.sh" ;;
            0) return ;;
            *) echo -e "\n  ${RED}Invalid option.${NC}" ;;
        esac
        echo ""
        read -p "  Press Enter to continue..."
    done
}

# --- Main menu ---
while true; do
    show_banner
    echo -e "   ${BOLD}1${NC}  ${GREEN}Services${NC}           ${WHITE}(MQ, WebSphere, App Server)${NC}"
    echo -e "   ${BOLD}2${NC}  ${BLUE}Build & Deploy${NC}     ${WHITE}(upgrade, FTP, Ant, deploy)${NC}"
    echo -e "   ${BOLD}3${NC}  ${MAGENTA}Maintenance${NC}        ${WHITE}(logs, disk, permissions)${NC}"
    echo -e "   ${BOLD}4${NC}  ${YELLOW}Diagnostics${NC}        ${WHITE}(tail logs, kill procs)${NC}"
    echo ""
    echo -e "   ${BOLD}0${NC}  Exit"
    echo ""
    read -p "  Enter choice: " choice
    case "$choice" in
        1) menu_services ;;
        2) menu_deploy ;;
        3) menu_maintenance ;;
        4) menu_diagnostics ;;
        0) echo -e "\n  ${BOLD}Exiting...${NC}"; break ;;
        *) echo -e "\n  ${RED}Invalid option.${NC}"; sleep 1 ;;
    esac
done
