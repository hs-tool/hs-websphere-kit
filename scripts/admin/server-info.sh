#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail


echo ""
echo -e "${BOLD}${CYAN}=== Server Runtime Info ===${NC}"
echo -e "  Server: ${YELLOW}$SERVER_NAME${NC}"
echo ""

# Find App Server JVM PID
app_pid=$(ps -ef | grep -v grep | grep "$APP_SERVER" | grep java | awk '{print $2}' | head -1)

if [[ -z "$app_pid" ]]; then
    echo -e "  ${RED}$APP_SERVER is not running${NC}"
    echo ""
else
    echo -e "${BOLD}App Server ($APP_SERVER) — PID $app_pid${NC}"

    # Uptime
    if [[ -f "/proc/$app_pid/stat" ]]; then
        start_time=$(stat -c %Y "/proc/$app_pid" 2>/dev/null || echo 0)
        now=$(date +%s)
        uptime_secs=$((now - start_time))
        uptime_days=$((uptime_secs / 86400))
        uptime_hours=$(( (uptime_secs % 86400) / 3600 ))
        uptime_mins=$(( (uptime_secs % 3600) / 60 ))
        echo -e "  Uptime:       ${GREEN}${uptime_days}d ${uptime_hours}h ${uptime_mins}m${NC}"
    fi

    # Memory from /proc
    if [[ -f "/proc/$app_pid/status" ]]; then
        vm_rss=$(grep "VmRSS:" "/proc/$app_pid/status" 2>/dev/null | awk '{print $2, $3}')
        vm_size=$(grep "VmSize:" "/proc/$app_pid/status" 2>/dev/null | awk '{print $2, $3}')
        threads=$(grep "Threads:" "/proc/$app_pid/status" 2>/dev/null | awk '{print $2}')
        echo -e "  Resident Mem: ${BOLD}$vm_rss${NC}"
        echo -e "  Virtual Mem:  ${DIM}$vm_size${NC}"
        echo -e "  Threads:      ${BOLD}$threads${NC}"
    fi

    # CPU usage
    cpu=$(ps -p "$app_pid" -o %cpu= 2>/dev/null | xargs)
    mem=$(ps -p "$app_pid" -o %mem= 2>/dev/null | xargs)
    echo -e "  CPU:          ${BOLD}${cpu}%${NC}"
    echo -e "  Memory:       ${BOLD}${mem}%${NC}"

    # JVM command line (extract heap settings)
    jvm_cmd=$(cat "/proc/$app_pid/cmdline" 2>/dev/null | tr '\0' ' ')
    heap_min=$(echo "$jvm_cmd" | grep -oP '\-Xms\S+' || echo "default")
    heap_max=$(echo "$jvm_cmd" | grep -oP '\-Xmx\S+' || echo "default")
    gc_policy=$(echo "$jvm_cmd" | grep -oP '\-Xgcpolicy:\S+' || echo "default")
    echo -e "  Heap Min:     ${BOLD}$heap_min${NC}"
    echo -e "  Heap Max:     ${BOLD}$heap_max${NC}"
    echo -e "  GC Policy:    ${DIM}$gc_policy${NC}"
    echo ""

    # Open file descriptors
    if [[ -d "/proc/$app_pid/fd" ]]; then
        fd_count=$(ls "/proc/$app_pid/fd" 2>/dev/null | wc -l)
        fd_limit=$(cat "/proc/$app_pid/limits" 2>/dev/null | grep "open files" | awk '{print $4}')
        echo -e "  Open FDs:     ${BOLD}$fd_count${NC} / ${DIM}$fd_limit${NC}"
    fi
fi

# Dmgr info
dmgr_pid=$(ps -ef | grep -v grep | grep "dmgr" | grep java | awk '{print $2}' | head -1)
echo ""
if [[ -n "$dmgr_pid" ]]; then
    echo -e "${BOLD}Deployment Manager — PID $dmgr_pid${NC}"
    if [[ -f "/proc/$dmgr_pid/status" ]]; then
        vm_rss=$(grep "VmRSS:" "/proc/$dmgr_pid/status" 2>/dev/null | awk '{print $2, $3}')
        threads=$(grep "Threads:" "/proc/$dmgr_pid/status" 2>/dev/null | awk '{print $2}')
        echo -e "  Resident Mem: ${BOLD}$vm_rss${NC}"
        echo -e "  Threads:      ${BOLD}$threads${NC}"
    fi
    cpu=$(ps -p "$dmgr_pid" -o %cpu= 2>/dev/null | xargs)
    echo -e "  CPU:          ${BOLD}${cpu}%${NC}"
else
    echo -e "  ${DIM}Dmgr not running${NC}"
fi

# Java version
echo ""
echo -e "${BOLD}Java Version${NC}"
java_bin="$NODE_PROFILE/java/8.0/bin/java"
if [[ -x "$java_bin" ]]; then
    "$java_bin" -version 2>&1 | head -3 | while read -r line; do
        echo -e "  ${DIM}$line${NC}"
    done
elif command -v java &>/dev/null; then
    java -version 2>&1 | head -3 | while read -r line; do
        echo -e "  ${DIM}$line${NC}"
    done
fi

echo ""
