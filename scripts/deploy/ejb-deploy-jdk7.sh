#!/bin/bash
# ============================================================
# EJB Deploy with JDK 7
# ============================================================
# Fixes CNTR0075E / ClassNotFoundException for EJSLocalStateless*
# stubs by temporarily switching the Dmgr to IBM JDK 7 so that
# EJBDeploy runs during AdminApp.install().
#
# WAS 8.5 on Java 8 ignores EJBDeploy (ADMA0254W). Switching the
# Dmgr SDK to JDK 7 for the build step re-enables stub generation.
#
# This script handles the ENTIRE pipeline:
#   Phase 1 — Shutdown all WAS processes
#   Phase 2 — Switch Dmgr to JDK 7, enable deployejb, build
#   Phase 3 — Restore JDK 8, start all services, verify
# ============================================================
source "$(dirname "$0")/../../config.sh"
set -uo pipefail

MANAGE_SDK="$NODE_PROFILE/bin/managesdk.sh"
DEPLOY_CONFIG="$(dirname "$WS_ADMIN_BIN")/config/config.${WS_ENV_NAME}.properties"

# Profile names (basename only, for managesdk)
NDM_NAME="$(basename "$NDM_PROFILE")"

# State tracking for cleanup
ORIGINAL_SDK=""
SDK_SWITCHED=false
DEPLOYEJB_MODIFIED=false

STEP=0
TOTAL=12

step() {
    ((STEP++))
    echo ""
    echo -e "  ${BOLD}${CYAN}[$STEP/$TOTAL]${NC} ${BOLD}$1${NC}"
}
ok()   { echo -e "          ${GREEN}$1${NC}"; }
warn() { echo -e "          ${YELLOW}WARNING: $1${NC}"; }
fail() { echo -e "          ${RED}FAILED: $1${NC}"; }

# ============================================================
# CLEANUP TRAP — always restore JDK 8 + config on exit/error
# ============================================================
cleanup() {
    local rc=$?
    if $SDK_SWITCHED; then
        echo ""
        echo -e "  ${YELLOW}${BOLD}Cleanup: Restoring Dmgr SDK to ${ORIGINAL_SDK}...${NC}"
        cd "$NODE_PROFILE/bin" 2>/dev/null || true
        sudo ./managesdk.sh -enableProfile -profileName "$NDM_NAME" \
             -sdkname "$ORIGINAL_SDK" -enableServers 2>&1 || true
        SDK_SWITCHED=false
        cd "$HOME_DIR" 2>/dev/null || true
    fi
    if $DEPLOYEJB_MODIFIED && [[ -f "$DEPLOY_CONFIG" ]]; then
        echo -e "  ${YELLOW}${BOLD}Cleanup: Restoring deployejb config...${NC}"
        sed -i "s|^pcms\.beanstore\.application\.0\.options\.1\.value=.*|pcms.beanstore.application.0.options.1.value=|" \
            "$DEPLOY_CONFIG" 2>/dev/null || true
        DEPLOYEJB_MODIFIED=false
    fi
    return $rc
}
trap cleanup EXIT

# ============================================================
# BANNER
# ============================================================
echo ""
echo -e "${BOLD}${MAGENTA}================================================================${NC}"
echo -e "${BOLD}${MAGENTA}    EJB Deploy with JDK 7 — Stub Generation Pipeline${NC}"
echo -e "${BOLD}${MAGENTA}================================================================${NC}"
echo ""
echo -e "  Server:      ${BOLD}${YELLOW}$SERVER_NAME${NC}"
echo -e "  Dmgr:        ${BOLD}${YELLOW}$NDM_NAME${NC}"
echo -e "  Environment: ${BOLD}${YELLOW}$WS_ENV_NAME${NC}"
echo ""
echo -e "  ${DIM}Fixes CNTR0075E / ClassNotFoundException for EJSLocalStateless*${NC}"
echo -e "  ${DIM}by running EJBDeploy under IBM JDK 7 during app installation.${NC}"
echo -e "  ${DIM}WAS 8.5 on Java 8 ignores EJBDeploy (ADMA0254W) — JDK 7 re-enables it.${NC}"
echo ""

# ============================================================
# PRE-FLIGHT CHECKS
# ============================================================
echo -e "  ${BOLD}Pre-flight Checks${NC}"
echo -e "  ${DIM}────────────────────────────────────────${NC}"
preflight_ok=true

# Check managesdk.sh
if [[ ! -x "$MANAGE_SDK" ]]; then
    echo -e "    ${RED}[FAIL]${NC} managesdk.sh not found at $MANAGE_SDK"
    preflight_ok=false
else
    echo -e "    ${GREEN}[OK]${NC}   managesdk.sh"
fi

# Check WAS admin bin
if [[ ! -d "$WS_ADMIN_BIN" ]]; then
    echo -e "    ${RED}[FAIL]${NC} WAS admin bin not found: $WS_ADMIN_BIN"
    echo -e "           ${DIM}Has a build been downloaded and unpacked?${NC}"
    preflight_ok=false
else
    echo -e "    ${GREEN}[OK]${NC}   WAS admin bin"
fi

# Check deploy config
if [[ ! -f "$DEPLOY_CONFIG" ]]; then
    echo -e "    ${RED}[FAIL]${NC} Deploy config not found: $DEPLOY_CONFIG"
    preflight_ok=false
else
    echo -e "    ${GREEN}[OK]${NC}   Deploy config (config.${WS_ENV_NAME}.properties)"
fi

# Check profile directories exist
if [[ ! -d "$NDM_PROFILE/bin" ]]; then
    echo -e "    ${RED}[FAIL]${NC} Dmgr profile not found: $NDM_PROFILE"
    preflight_ok=false
else
    echo -e "    ${GREEN}[OK]${NC}   Dmgr profile ($NDM_NAME)"
fi

if [[ ! -d "$NODE_PROFILE/bin" ]]; then
    echo -e "    ${RED}[FAIL]${NC} Node profile not found: $NODE_PROFILE"
    preflight_ok=false
else
    echo -e "    ${GREEN}[OK]${NC}   Node profile ($(basename "$NODE_PROFILE"))"
fi

if ! $preflight_ok; then
    echo ""
    echo -e "  ${RED}${BOLD}Pre-flight checks failed. Fix the issues above and retry.${NC}"
    exit 1
fi

# Discover available SDKs
echo ""
echo -e "  ${BOLD}SDK Discovery${NC}"
echo -e "  ${DIM}────────────────────────────────────────${NC}"

sdk_list=$(cd "$NODE_PROFILE/bin" && sudo ./managesdk.sh -listAvailable 2>&1)

# Show available SDKs
echo "$sdk_list" | grep -iE "SDK|sdk" | while IFS= read -r line; do
    echo -e "    ${DIM}$line${NC}"
done

# Find JDK 7 SDK name
JDK7_SDK=""
for candidate in "1.7.1_64" "1.7_64" "1.7.1" "1.7"; do
    if echo "$sdk_list" | grep -q "$candidate"; then
        JDK7_SDK="$candidate"
        break
    fi
done

if [[ -z "$JDK7_SDK" ]]; then
    echo ""
    echo -e "    ${RED}[FAIL]${NC} IBM JDK 7 SDK not found!"
    echo -e "           ${DIM}Install IBM JDK 7 via IBM Installation Manager, then retry.${NC}"
    echo -e "           ${DIM}  imcl install com.ibm.websphere.IBMJAVA.v71${NC}"
    exit 1
fi
echo -e "    ${GREEN}[OK]${NC}   JDK 7 found: ${BOLD}$JDK7_SDK${NC}"

# Get current Dmgr SDK
current_sdk_out=$(cd "$NODE_PROFILE/bin" && sudo ./managesdk.sh -getCommandDefault -profileName "$NDM_NAME" 2>&1 || true)
ORIGINAL_SDK=$(echo "$current_sdk_out" | grep -oE '1\.[0-9._]+' | head -1)
ORIGINAL_SDK="${ORIGINAL_SDK:-1.8_64}"
echo -e "    ${GREEN}[OK]${NC}   Current Dmgr SDK: ${BOLD}$ORIGINAL_SDK${NC}"

# ============================================================
# EXECUTION PLAN
# ============================================================
echo ""
echo -e "  ${BOLD}Execution Plan${NC}"
echo -e "  ${DIM}────────────────────────────────────────${NC}"
echo -e "    ${YELLOW}Phase 1${NC}  Shutdown"
echo -e "      ${DIM}[ 1]${NC} Stop App Server ($APP_SERVER)"
echo -e "      ${DIM}[ 2]${NC} Stop Node Agent"
echo -e "      ${DIM}[ 3]${NC} Stop Dmgr"
echo -e "    ${CYAN}Phase 2${NC}  JDK 7 + Build"
echo -e "      ${DIM}[ 4]${NC} Switch Dmgr SDK to $JDK7_SDK"
echo -e "      ${DIM}[ 5]${NC} Enable deployejb in config"
echo -e "      ${DIM}[ 6]${NC} Start Dmgr (on JDK 7)"
echo -e "      ${DIM}[ 7]${NC} Teardown existing apps"
echo -e "      ${DIM}[ 8]${NC} Build apps (EJBDeploy generates stubs)"
echo -e "      ${DIM}[ 9]${NC} Stop Dmgr"
echo -e "    ${GREEN}Phase 3${NC}  Restore + Start"
echo -e "      ${DIM}[10]${NC} Restore Dmgr SDK to $ORIGINAL_SDK"
echo -e "      ${DIM}[11]${NC} Restore deployejb config"
echo -e "      ${DIM}[12]${NC} Start all (Dmgr > Node > Sync > App Server)"
echo ""

read -p "  Continue? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "  Aborted."
    exit 0
fi

start_time=$SECONDS

# ============================================================
# PHASE 1: SHUTDOWN
# ============================================================
echo ""
echo -e "  ${BOLD}${YELLOW}━━━ Phase 1: Shutdown ━━━${NC}"

step "Stopping App Server ($APP_SERVER)"
cd "$NODE_PROFILE/bin" || { fail "Cannot cd to $NODE_PROFILE/bin"; exit 1; }
if ./stopServer.sh "$APP_SERVER" 2>&1; then
    ok "App Server stopped"
else
    warn "App Server may already be stopped (continuing)"
fi

step "Stopping Node Agent"
if ./stopNode.sh 2>&1; then
    ok "Node Agent stopped"
else
    warn "Node Agent may already be stopped (continuing)"
fi

step "Stopping Dmgr"
cd "$NDM_PROFILE/bin" || { fail "Cannot cd to $NDM_PROFILE/bin"; exit 1; }
if ./stopManager.sh 2>&1; then
    ok "Dmgr stopped"
else
    warn "Dmgr may already be stopped (continuing)"
fi
cd "$HOME_DIR"

# ============================================================
# PHASE 2: JDK 7 + DEPLOY
# ============================================================
echo ""
echo -e "  ${BOLD}${CYAN}━━━ Phase 2: JDK 7 + Build ━━━${NC}"

step "Switching Dmgr SDK to JDK 7 ($JDK7_SDK)"
cd "$NODE_PROFILE/bin"
if sudo ./managesdk.sh -enableProfile -profileName "$NDM_NAME" \
       -sdkname "$JDK7_SDK" -enableServers 2>&1; then
    ok "Dmgr SDK switched to $JDK7_SDK"
    SDK_SWITCHED=true
else
    fail "Cannot switch SDK — aborting"
    exit 1
fi
cd "$HOME_DIR"

step "Enabling deployejb in config"
if sed -i "s|^pcms\.beanstore\.application\.0\.options\.1\.value=.*|pcms.beanstore.application.0.options.1.value=true|" "$DEPLOY_CONFIG"; then
    ok "deployejb=true set in config.${WS_ENV_NAME}.properties"
    DEPLOYEJB_MODIFIED=true
else
    fail "Cannot update deploy config — aborting"
    exit 1
fi

step "Starting Dmgr (on JDK 7)"
cd "$NDM_PROFILE/bin"
if ./startManager.sh 2>&1; then
    ok "Dmgr started on JDK 7"
else
    fail "Dmgr failed to start on JDK 7 — aborting"
    exit 1
fi
cd "$HOME_DIR"

step "Teardown existing WS apps"
if "$WS_ADMIN_BIN/wasadmin.sh" "$WS_ENV_NAME" teardown 2>&1; then
    ok "Teardown complete"
else
    warn "Teardown exited with warnings (may be OK if no apps installed)"
fi

step "Building WS apps (EJBDeploy generating stubs)"
echo -e "          ${DIM}This step generates EJSLocalStateless* classes...${NC}"
echo -e "          ${DIM}May take several minutes. Please wait.${NC}"
if "$WS_ADMIN_BIN/wasadmin.sh" "$WS_ENV_NAME" build 2>&1; then
    ok "Build complete — EJB stubs generated successfully"
else
    fail "Build FAILED — check $NDM_PROFILE/logs/dmgr/SystemOut.log"
    echo ""
    echo -e "          ${YELLOW}The cleanup trap will restore JDK 8 and config on exit.${NC}"
    exit 1
fi

step "Stopping Dmgr"
cd "$NDM_PROFILE/bin"
if ./stopManager.sh 2>&1; then
    ok "Dmgr stopped"
else
    warn "Dmgr stop had warnings"
fi
cd "$HOME_DIR"

# ============================================================
# PHASE 3: RESTORE & START
# ============================================================
echo ""
echo -e "  ${BOLD}${GREEN}━━━ Phase 3: Restore JDK 8 & Start ━━━${NC}"

step "Restoring Dmgr SDK to $ORIGINAL_SDK"
cd "$NODE_PROFILE/bin"
if sudo ./managesdk.sh -enableProfile -profileName "$NDM_NAME" \
       -sdkname "$ORIGINAL_SDK" -enableServers 2>&1; then
    ok "Dmgr SDK restored to $ORIGINAL_SDK"
    SDK_SWITCHED=false
else
    fail "SDK restore failed — run 'Configure Java 8' from menu to fix"
fi
cd "$HOME_DIR"

step "Restoring deployejb config"
if sed -i "s|^pcms\.beanstore\.application\.0\.options\.1\.value=.*|pcms.beanstore.application.0.options.1.value=|" "$DEPLOY_CONFIG" 2>/dev/null; then
    ok "deployejb reset to empty"
    DEPLOYEJB_MODIFIED=false
else
    warn "Could not reset deployejb — check $DEPLOY_CONFIG manually"
fi

step "Starting all services"
echo ""
echo -e "          ${DIM}[a] Starting Dmgr...${NC}"
cd "$NDM_PROFILE/bin"
if ./startManager.sh 2>&1; then
    ok "Dmgr started"
else
    fail "Dmgr failed to start"
fi
cd "$HOME_DIR"

echo -e "          ${DIM}[b] Starting Node Agent...${NC}"
cd "$NODE_PROFILE/bin"
if ./startNode.sh 2>&1; then
    ok "Node Agent started"
else
    fail "Node Agent failed to start"
fi

echo -e "          ${DIM}[c] Syncing Node...${NC}"
if ./syncNode.sh localhost 8879 2>&1; then
    ok "Node sync complete"
else
    warn "syncNode had warnings — Dmgr may still be initializing"
fi

echo -e "          ${DIM}[d] Starting App Server ($APP_SERVER)...${NC}"
if ./startServer.sh "$APP_SERVER" 2>&1; then
    ok "App Server started"
else
    fail "App Server failed to start — check logs"
fi
cd "$HOME_DIR"

# ============================================================
# SUMMARY
# ============================================================
elapsed=$(( SECONDS - start_time ))
minutes=$(( elapsed / 60 ))
seconds=$(( elapsed % 60 ))

echo ""
echo -e "${BOLD}${MAGENTA}================================================================${NC}"
echo -e "${GREEN}${BOLD}  EJB Deploy complete in ${minutes}m ${seconds}s${NC}"
echo -e "${BOLD}${MAGENTA}================================================================${NC}"
echo ""
echo -e "  ${BOLD}What happened:${NC}"
echo -e "    ${GREEN}1.${NC} Dmgr was temporarily switched to JDK 7 ($JDK7_SDK)"
echo -e "    ${GREEN}2.${NC} EJBDeploy generated EJSLocalStateless* stub classes"
echo -e "    ${GREEN}3.${NC} Dmgr was restored to JDK 8 ($ORIGINAL_SDK)"
echo -e "    ${GREEN}4.${NC} All services restarted"
echo ""
echo -e "  ${BOLD}Verify:${NC}"
echo -e "    ${DIM}Check SystemOut.log — CNTR0075E should no longer appear.${NC}"
echo -e "    ${DIM}Log: $NODE_PROFILE/logs/$APP_SERVER/SystemOut.log${NC}"
echo ""
