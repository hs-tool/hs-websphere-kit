#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail


TOTAL_PHASES=7
CURRENT_PHASE=0
TOTAL_START=$SECONDS

run_phase() {
    local script="$1"
    local label="$2"
    ((CURRENT_PHASE++)) || true

    local phase_start=$SECONDS
    echo ""
    echo -e "${BOLD}${CYAN}[$CURRENT_PHASE/$TOTAL_PHASES] $label${NC}"
    echo -e "${DIM}$(printf '%.0s─' {1..50})${NC}"

    if "$TOOLKIT_ROOT/scripts/$script"; then
        local elapsed=$(( SECONDS - phase_start ))
        echo -e "${GREEN}  Done${NC} ${DIM}(${elapsed}s)${NC}"
    else
        local elapsed=$(( SECONDS - phase_start ))
        echo -e "${RED}${BOLD}  FAILED after ${elapsed}s${NC}"
        echo -e "${RED}Pipeline aborted at phase $CURRENT_PHASE/$TOTAL_PHASES: $label${NC}"
        exit 1
    fi
}

echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║       End-to-End Build Pipeline      ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════╝${NC}"
echo -e "  Server: ${YELLOW}$SERVER_NAME${NC}"
echo -e "  Phases: ${BOLD}$TOTAL_PHASES${NC}"
echo ""

run_phase "services/start-mq.sh"            "Start MQ"
run_phase "services/start-websphere.sh"     "Start WebSphere"
run_phase "maintenance/remove-temp-files.sh" "Remove Temp Files"
run_phase "deploy/full-upgrade.sh"           "Full Upgrade"
run_phase "services/stop-websphere.sh"       "Stop WebSphere"
run_phase "maintenance/remove-temp-files.sh" "Remove Temp Files (post-stop)"

# Final start — outside the pipeline phases since it's the "result"
echo ""
echo -e "${BOLD}${CYAN}[Final] Starting WebSphere...${NC}"
echo -e "${DIM}$(printf '%.0s─' {1..50})${NC}"
"$TOOLKIT_ROOT/scripts/services/start-websphere.sh"

total_elapsed=$(( SECONDS - TOTAL_START ))
minutes=$(( total_elapsed / 60 ))
seconds=$(( total_elapsed % 60 ))

echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║   Pipeline complete: ${minutes}m ${seconds}s            ║${NC}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════╝${NC}"
echo ""
