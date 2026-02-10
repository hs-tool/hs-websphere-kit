#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

echo ""
echo -e "${BOLD}${CYAN}=== Run Ant Target ===${NC}"
echo ""

# Show current build version
current_name=$(grep -E "^project\.name=" "$DEPLOY_OVERRIDE" 2>/dev/null | tail -1 | cut -d'=' -f2)
echo -e "  Build:  ${BOLD}${YELLOW}${current_name:-<not set>}${NC}"
echo ""

echo -e "  ${BOLD}Available targets:${NC}"
echo ""
echo -e "   ${BOLD}1${NC}  upgrade-test       ${DIM}(clean + FTP + unpack + deploy)${NC}"
echo -e "   ${BOLD}2${NC}  upgrade-live        ${DIM}(unpack cached + deploy, no FTP)${NC}"
echo -e "   ${BOLD}3${NC}  get-release         ${DIM}(FTP download + unpack only)${NC}"
echo -e "   ${BOLD}4${NC}  deploy-release      ${DIM}(deploy software only)${NC}"
echo -e "   ${BOLD}5${NC}  upgrade-clean       ${DIM}(delete archives, cache, logs)${NC}"
echo ""
echo -e "   ${BOLD}c${NC}  Custom target       ${DIM}(type any target name)${NC}"
echo ""

read -p "  Select target (1-5/c): " choice

case "$choice" in
    1) target="upgrade-test" ;;
    2) target="upgrade-live" ;;
    3) target="get-release" ;;
    4) target="deploy-release" ;;
    5) target="upgrade-clean" ;;
    c|C)
        read -p "  Enter target name: " target
        if [[ -z "$target" ]]; then
            echo -e "  ${RED}No target specified. Aborted.${NC}"
            exit 1
        fi
        ;;
    *)
        echo -e "  ${RED}Invalid option.${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "  Target:  ${BOLD}${YELLOW}$target${NC}"
echo -e "  Build:   ${YELLOW}${current_name:-<not set>}${NC}"
echo ""
read -p "  Run this target? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "  Aborted."
    exit 0
fi

start_time=$SECONDS

echo ""
echo -e "  ${BOLD}Running: $target${NC}"
echo ""

run_ant_target "$target"

elapsed=$(( SECONDS - start_time ))
minutes=$(( elapsed / 60 ))
seconds=$(( elapsed % 60 ))

echo ""
echo -e "${GREEN}${BOLD}  '$target' complete in ${minutes}m ${seconds}s${NC}"
echo ""
