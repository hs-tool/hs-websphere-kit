#!/bin/bash
# ============================================================
# One Shot Deploy — Full Post-Reboot Pipeline
# ============================================================
# After a server reboot, run this ONCE and everything is done:
#
#   Phase 1 — Start MQ
#   Phase 2 — Kill stale WAS processes, clean temp, clear logs
#   Phase 3 — Configure JDK 8, start Dmgr, Node Agent, Sync
#   Phase 4 — Full upgrade build (teardown + upgrade + build)
#   Phase 5 — Start App Server & Verify
#
# Chains existing toolkit scripts in the correct order.
# ============================================================
source "$(dirname "$0")/../../config.sh"
set -uo pipefail

SCRIPTS_DIR="$TOOLKIT_ROOT/scripts"
NDM_NAME="$(basename "$NDM_PROFILE")"
NODE_NAME="$(basename "$NODE_PROFILE")"

STEP=0
TOTAL=10

step() {
    ((STEP++))
    echo ""
    echo -e "  ${BOLD}${CYAN}[$STEP/$TOTAL]${NC} ${BOLD}$1${NC}"
}
ok()   { echo -e "          ${GREEN}$1${NC}"; }
warn() { echo -e "          ${YELLOW}WARNING: $1${NC}"; }
fail() { echo -e "          ${RED}FAILED: $1${NC}"; }

run() {
    local script="$SCRIPTS_DIR/$1"
    if [[ ! -f "$script" ]]; then
        fail "Script not found: $script"
        return 1
    fi
    "$script"
}

# ============================================================
# BANNER
# ============================================================
echo ""
echo -e "${BOLD}${YELLOW}================================================================${NC}"
echo -e "${BOLD}${YELLOW}    One Shot Deploy — Full Post-Reboot Pipeline${NC}"
echo -e "${BOLD}${YELLOW}================================================================${NC}"
echo ""
echo -e "  Server:      ${BOLD}${YELLOW}$SERVER_NAME${NC}"
echo -e "  Dmgr:        ${BOLD}${YELLOW}$NDM_NAME${NC}"
echo -e "  Node:        ${BOLD}${YELLOW}$NODE_NAME${NC}"
echo -e "  App Server:  ${BOLD}${YELLOW}$APP_SERVER${NC}"
echo -e "  MQ:          ${BOLD}${YELLOW}$MQ_QM${NC}"
echo ""
echo -e "  ${DIM}Run this after a reboot. Everything in one go:${NC}"
echo -e "  ${DIM}MQ > kill stale > clean > logs > JDK 8 > Dmgr > Node > Sync > Build > Start${NC}"
echo ""

# ============================================================
# EXECUTION PLAN
# ============================================================
echo -e "  ${BOLD}Execution Plan${NC}"
echo -e "  ${DIM}────────────────────────────────────────${NC}"
echo -e "    ${MAGENTA}Phase 1${NC}  MQ"
echo -e "      ${DIM}[ 1]${NC} Start Queue Manager ($MQ_QM)"
echo -e "    ${RED}Phase 2${NC}  Clean Slate"
echo -e "      ${DIM}[ 2]${NC} Kill stale WebSphere processes"
echo -e "      ${DIM}[ 3]${NC} Remove temp files"
echo -e "      ${DIM}[ 4]${NC} Clear logs"
echo -e "    ${CYAN}Phase 3${NC}  WAS Infrastructure"
echo -e "      ${DIM}[ 5]${NC} Configure Java 8"
echo -e "      ${DIM}[ 6]${NC} Start Dmgr"
echo -e "      ${DIM}[ 7]${NC} Start Node Agent"
echo -e "    ${YELLOW}Phase 4${NC}  Build"
echo -e "      ${DIM}[ 8]${NC} Full Upgrade (teardown + upgrade + deploy)"
echo -e "    ${GREEN}Phase 5${NC}  Go Live"
echo -e "      ${DIM}[ 9]${NC} Start App Server ($APP_SERVER)"
echo -e "      ${DIM}[10]${NC} Verify"
echo ""

read -p "  Continue? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "  Aborted."
    exit 0
fi

start_time=$SECONDS

# ============================================================
# PHASE 1: MQ
# ============================================================
echo ""
echo -e "  ${BOLD}${MAGENTA}━━━ Phase 1: MQ ━━━${NC}"

step "Starting Queue Manager ($MQ_QM)"
if run "services/start-mq.sh"; then
    ok "MQ started"
else
    warn "MQ may need manual attention (continuing)"
fi

# ============================================================
# PHASE 2: CLEAN SLATE
# ============================================================
echo ""
echo -e "  ${BOLD}${RED}━━━ Phase 2: Clean Slate ━━━${NC}"

step "Killing stale WebSphere processes"
# Inline kill — the standalone script has interactive prompts
stale_pids=$(ps -ef | grep -v grep | grep -iE "websphere|dmgr|nodeagent|$APP_SERVER" | awk '{print $2}' || true)
if [[ -n "$stale_pids" ]]; then
    echo -e "          ${DIM}Found stale processes, sending SIGTERM...${NC}"
    echo "$stale_pids" | xargs kill -15 2>/dev/null || true
    sleep 5
    # Force kill survivors
    still_alive=$(ps -ef | grep -v grep | grep -iE "websphere|dmgr|nodeagent|$APP_SERVER" | awk '{print $2}' || true)
    if [[ -n "$still_alive" ]]; then
        echo -e "          ${DIM}Force killing remaining processes...${NC}"
        echo "$still_alive" | xargs kill -9 2>/dev/null || true
        sleep 2
    fi
    ok "Stale processes killed"
else
    ok "No stale WebSphere processes found"
fi

step "Removing temp files"
if run "maintenance/remove-temp-files.sh"; then
    ok "Temp files cleaned"
else
    warn "Temp file cleanup had issues (continuing)"
fi

step "Clearing logs"
if run "maintenance/clear-logs.sh"; then
    ok "Logs cleared"
else
    warn "Log cleanup had issues (continuing)"
fi

# ============================================================
# PHASE 3: WAS INFRASTRUCTURE
# ============================================================
echo ""
echo -e "  ${BOLD}${CYAN}━━━ Phase 3: WAS Infrastructure ━━━${NC}"

step "Configuring Java 8"
if run "deploy/configure-java-8.sh"; then
    ok "JDK 8 configured"
else
    warn "Java 8 config had issues — may already be set (continuing)"
fi

step "Starting Dmgr"
if run "services/start-dmgr.sh"; then
    ok "Dmgr started"
else
    fail "Dmgr failed to start"
    exit 1
fi

step "Starting Node Agent"
if run "services/start-nodeagent.sh"; then
    ok "Node Agent started"
else
    fail "Node Agent failed to start"
    exit 1
fi

# ============================================================
# PHASE 4: BUILD
# ============================================================
echo ""
echo -e "  ${BOLD}${YELLOW}━━━ Phase 4: Full Upgrade Build ━━━${NC}"

step "Running Full Upgrade (teardown + upgrade + deploy)"
echo -e "          ${DIM}This runs the complete build pipeline.${NC}"
echo -e "          ${DIM}May take several minutes. Please wait...${NC}"
if yes y 2>/dev/null | run "deploy/full-upgrade.sh"; then
    ok "Full upgrade build complete"
else
    fail "Build failed — check logs"
    echo -e "          ${YELLOW}WAS infrastructure is running. Fix the build issue and retry.${NC}"
    exit 1
fi

# ============================================================
# PHASE 5: GO LIVE
# ============================================================
echo ""
echo -e "  ${BOLD}${GREEN}━━━ Phase 5: Go Live ━━━${NC}"

step "Starting App Server ($APP_SERVER)"
if run "services/start-appserver.sh"; then
    ok "App Server started"
else
    fail "App Server failed to start — check logs"
    exit 1
fi

step "Verifying"
echo -e "          ${DIM}Waiting 15s for app initialization...${NC}"
sleep 15

LOG_FILE="$NODE_PROFILE/logs/$APP_SERVER/SystemOut.log"
if [[ -f "$LOG_FILE" ]]; then
    if tail -200 "$LOG_FILE" | grep -q "CNTR0075E"; then
        fail "CNTR0075E found in SystemOut.log"
        tail -200 "$LOG_FILE" | grep "CNTR0075E" | while IFS= read -r line; do
            echo -e "          ${RED}$line${NC}"
        done
    else
        ok "No CNTR0075E errors"
    fi

    if tail -200 "$LOG_FILE" | grep -q "WSVR0001I"; then
        ok "App Server open for e-business"
    else
        warn "WSVR0001I not found yet (server may still be initializing)"
    fi

    if tail -200 "$LOG_FILE" | grep -q "ClassNotFoundException"; then
        warn "ClassNotFoundException found — check log for details"
    else
        ok "No ClassNotFoundException errors"
    fi
else
    warn "SystemOut.log not found at $LOG_FILE"
fi

# ============================================================
# SUMMARY
# ============================================================
elapsed=$(( SECONDS - start_time ))
minutes=$(( elapsed / 60 ))
seconds=$(( elapsed % 60 ))

echo ""
echo -e "${BOLD}${YELLOW}================================================================${NC}"
echo -e "${GREEN}${BOLD}  One Shot Deploy complete in ${minutes}m ${seconds}s${NC}"
echo -e "${BOLD}${YELLOW}================================================================${NC}"
echo ""
echo -e "  ${BOLD}What happened:${NC}"
echo -e "    ${GREEN} 1.${NC} MQ Queue Manager started"
echo -e "    ${GREEN} 2.${NC} Stale WebSphere processes killed"
echo -e "    ${GREEN} 3.${NC} Temp files removed, logs cleared"
echo -e "    ${GREEN} 4.${NC} JDK 8 configured"
echo -e "    ${GREEN} 5.${NC} Dmgr > Node Agent started"
echo -e "    ${GREEN} 6.${NC} Full upgrade build deployed"
echo -e "    ${GREEN} 7.${NC} App Server started and verified"
echo ""
echo -e "  ${BOLD}Log:${NC}"
echo -e "    ${DIM}$NODE_PROFILE/logs/$APP_SERVER/SystemOut.log${NC}"
echo ""
