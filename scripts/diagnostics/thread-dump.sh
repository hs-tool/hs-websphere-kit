#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -uo pipefail


echo ""
echo -e "${BOLD}${CYAN}=== Thread Dump Capture ===${NC}"
echo -e "  Server: ${YELLOW}$SERVER_NAME${NC}"
echo ""

# Find the App Server JVM PID
app_pid=$(ps -ef | grep -v grep | grep "$APP_SERVER" | grep java | awk '{print $2}' | head -1)

if [[ -z "$app_pid" ]]; then
    echo -e "  ${RED}ERROR: $APP_SERVER JVM process not found. Is the server running?${NC}"
    exit 1
fi

echo -e "  App Server PID: ${BOLD}$app_pid${NC}"
echo ""

# Select target
echo -e "  ${BOLD}Capture thread dump for:${NC}"
echo -e "    ${BOLD}1${NC}  $APP_SERVER  ${DIM}(PID $app_pid)${NC}"

dmgr_pid=$(ps -ef | grep -v grep | grep "dmgr" | grep java | awk '{print $2}' | head -1)
if [[ -n "$dmgr_pid" ]]; then
    echo -e "    ${BOLD}2${NC}  Dmgr          ${DIM}(PID $dmgr_pid)${NC}"
fi

nodeagent_pid=$(ps -ef | grep -v grep | grep "nodeagent" | grep java | awk '{print $2}' | head -1)
if [[ -n "$nodeagent_pid" ]]; then
    echo -e "    ${BOLD}3${NC}  Node Agent    ${DIM}(PID $nodeagent_pid)${NC}"
fi
echo ""

read -p "  Select (1-3) [1]: " choice
choice="${choice:-1}"

case "$choice" in
    1) target_pid="$app_pid"; target_name="$APP_SERVER" ;;
    2) target_pid="${dmgr_pid:-}"; target_name="Dmgr" ;;
    3) target_pid="${nodeagent_pid:-}"; target_name="Node Agent" ;;
    *) echo -e "  ${RED}Invalid.${NC}"; exit 1 ;;
esac

if [[ -z "$target_pid" ]]; then
    echo -e "  ${RED}Process not found for $target_name.${NC}"
    exit 1
fi

# Output file
timestamp=$(date +%Y%m%d_%H%M%S)
dump_dir="$NODE_PROFILE"
javacore_pattern="javacore.${timestamp}*"

echo -e "  ${BOLD}Sending SIGQUIT (kill -3) to PID $target_pid ($target_name)...${NC}"
kill -3 "$target_pid"

# Wait for javacore file to appear
echo -e "  ${DIM}Waiting for thread dump file...${NC}"
sleep 3

# Find the most recent javacore
latest_dump=$(find "$dump_dir" -maxdepth 1 -name "javacore.*.txt" -newer "$0" -type f 2>/dev/null | sort | tail -1)

if [[ -z "$latest_dump" ]]; then
    # Also check native_stderr which IBM JVM may write to
    native_err="$NODE_PROFILE/logs/$APP_SERVER/native_stderr.log"
    echo -e "  ${YELLOW}No javacore file found in $dump_dir${NC}"
    echo -e "  ${DIM}Thread dump may have been written to:${NC}"
    echo -e "    ${DIM}$native_err${NC}"
    echo -e "    ${DIM}or stdout of the JVM process${NC}"
else
    echo -e "  ${GREEN}Thread dump captured:${NC}"
    echo -e "    ${BOLD}$latest_dump${NC}"
    dump_size=$(du -sh "$latest_dump" 2>/dev/null | cut -f1)
    echo -e "    ${DIM}Size: $dump_size${NC}"

    # Quick summary
    echo ""
    echo -e "  ${BOLD}Thread summary:${NC}"
    total_threads=$(grep -c "^\"" "$latest_dump" 2>/dev/null || echo "?")
    blocked=$(grep -c "BLOCKED" "$latest_dump" 2>/dev/null || echo 0)
    waiting=$(grep -c "WAITING" "$latest_dump" 2>/dev/null || echo 0)
    runnable=$(grep -c "RUNNABLE" "$latest_dump" 2>/dev/null || echo 0)

    echo -e "    Total threads: ${BOLD}$total_threads${NC}"
    echo -e "    Runnable:      ${GREEN}$runnable${NC}"
    echo -e "    Waiting:       ${YELLOW}$waiting${NC}"
    echo -e "    Blocked:       ${RED}$blocked${NC}"

    if (( blocked > 5 )); then
        echo ""
        echo -e "  ${RED}${BOLD}WARNING: $blocked blocked threads detected — possible deadlock!${NC}"
    fi
fi

echo ""
