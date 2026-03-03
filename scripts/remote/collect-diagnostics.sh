#!/bin/bash
# collect-diagnostics.sh — Runs on remote server to gather WAS config diagnostics
# Creates /tmp/was-diagnostics.txt with full config state report
# Runs as wasadmin via sudo from downloadLogs.cmd
set +e

SERVER_NAME="$(hostname)"
WAS_BASE="/opt/was/profiles"
NDM_PROFILE="${WAS_BASE}/${SERVER_NAME}_NDM"
NODE_PROFILE="${WAS_BASE}/${SERVER_NAME}_NODE01"
CELL_NAME="BS_Cell"
NODE_NAME="${SERVER_NAME}_NODE01"
REPORT="/tmp/was-diagnostics.txt"

# Config paths
NDM_CELL_DIR="${NDM_PROFILE}/config/cells/${CELL_NAME}"
NODE_CELL_DIR="${NODE_PROFILE}/config/cells/${CELL_NAME}"
NDM_SERVERS_DIR="${NDM_CELL_DIR}/nodes/${NODE_NAME}/servers"
NODE_SERVERS_DIR="${NODE_CELL_DIR}/nodes/${NODE_NAME}/servers"

divider() {
    echo "================================================================================" >> "$REPORT"
}

section() {
    echo "" >> "$REPORT"
    divider
    echo "  $1" >> "$REPORT"
    divider
    echo "" >> "$REPORT"
}

# Start report
cat > "$REPORT" <<HEADER
================================================================================
  WAS Configuration Diagnostics — ${SERVER_NAME}
  Generated: $(date '+%Y-%m-%d %H:%M:%S %Z')
  Running as: $(whoami)
================================================================================
HEADER

# ---------------------------------------------------------------------------
# 1. Server definitions — NDM (dmgr master config)
# ---------------------------------------------------------------------------
section "1. SERVER DEFINITIONS — NDM MASTER CONFIG"

echo "Path: ${NDM_SERVERS_DIR}" >> "$REPORT"
echo "" >> "$REPORT"

if [ -d "$NDM_SERVERS_DIR" ]; then
    echo "Servers found in dmgr master repository:" >> "$REPORT"
    for srv_dir in "$NDM_SERVERS_DIR"/*/; do
        srv_name=$(basename "$srv_dir")
        if [ -f "${srv_dir}server.xml" ]; then
            size=$(stat -c%s "${srv_dir}server.xml" 2>/dev/null || echo "?")
            mod=$(stat -c%y "${srv_dir}server.xml" 2>/dev/null | cut -d. -f1)
            echo "  [OK]    ${srv_name}/server.xml  (${size} bytes, modified: ${mod})" >> "$REPORT"
        else
            echo "  [MISS]  ${srv_name}/server.xml  — FILE MISSING" >> "$REPORT"
        fi
    done
    echo "" >> "$REPORT"
    echo "Full directory listing:" >> "$REPORT"
    ls -laR "$NDM_SERVERS_DIR" >> "$REPORT" 2>&1
else
    echo "  [ERROR] Directory does not exist: ${NDM_SERVERS_DIR}" >> "$REPORT"
fi

# ---------------------------------------------------------------------------
# 2. Server definitions — NODE (local config)
# ---------------------------------------------------------------------------
section "2. SERVER DEFINITIONS — NODE LOCAL CONFIG"

echo "Path: ${NODE_SERVERS_DIR}" >> "$REPORT"
echo "" >> "$REPORT"

if [ -d "$NODE_SERVERS_DIR" ]; then
    echo "Servers found in node local config:" >> "$REPORT"
    for srv_dir in "$NODE_SERVERS_DIR"/*/; do
        srv_name=$(basename "$srv_dir")
        if [ -f "${srv_dir}server.xml" ]; then
            size=$(stat -c%s "${srv_dir}server.xml" 2>/dev/null || echo "?")
            mod=$(stat -c%y "${srv_dir}server.xml" 2>/dev/null | cut -d. -f1)
            echo "  [OK]    ${srv_name}/server.xml  (${size} bytes, modified: ${mod})" >> "$REPORT"
        else
            echo "  [MISS]  ${srv_name}/server.xml  — FILE MISSING" >> "$REPORT"
        fi
    done
    echo "" >> "$REPORT"
    echo "Full directory listing:" >> "$REPORT"
    ls -laR "$NODE_SERVERS_DIR" >> "$REPORT" 2>&1
else
    echo "  [ERROR] Directory does not exist: ${NODE_SERVERS_DIR}" >> "$REPORT"
fi

# ---------------------------------------------------------------------------
# 3. serverindex.xml — NDM
# ---------------------------------------------------------------------------
section "3. serverindex.xml — NDM MASTER"

NDM_SERVERINDEX="${NDM_CELL_DIR}/nodes/${NODE_NAME}/serverindex.xml"
echo "Path: ${NDM_SERVERINDEX}" >> "$REPORT"
echo "" >> "$REPORT"

if [ -f "$NDM_SERVERINDEX" ]; then
    cat "$NDM_SERVERINDEX" >> "$REPORT" 2>&1
else
    echo "  [ERROR] File not found" >> "$REPORT"
fi

# ---------------------------------------------------------------------------
# 4. serverindex.xml — NODE
# ---------------------------------------------------------------------------
section "4. serverindex.xml — NODE LOCAL"

NODE_SERVERINDEX="${NODE_CELL_DIR}/nodes/${NODE_NAME}/serverindex.xml"
echo "Path: ${NODE_SERVERINDEX}" >> "$REPORT"
echo "" >> "$REPORT"

if [ -f "$NODE_SERVERINDEX" ]; then
    cat "$NODE_SERVERINDEX" >> "$REPORT" 2>&1
else
    echo "  [ERROR] File not found" >> "$REPORT"
fi

# ---------------------------------------------------------------------------
# 5. WAS processes running
# ---------------------------------------------------------------------------
section "5. RUNNING WAS / JAVA PROCESSES"

ps -ef | grep -E "(java|was|dmgr|nodeagent|AppSrv)" | grep -v grep >> "$REPORT" 2>&1
if [ $? -ne 0 ]; then
    echo "  No WAS/Java processes found" >> "$REPORT"
fi

# ---------------------------------------------------------------------------
# 6. Disk space
# ---------------------------------------------------------------------------
section "6. DISK SPACE"

df -h /opt/was /tmp / 2>/dev/null >> "$REPORT"

# ---------------------------------------------------------------------------
# 7. Profile directory ownership & permissions
# ---------------------------------------------------------------------------
section "7. PROFILE DIRECTORY OWNERSHIP"

echo "NDM profile:" >> "$REPORT"
ls -ld "$NDM_PROFILE" >> "$REPORT" 2>&1
echo "" >> "$REPORT"

echo "NODE profile:" >> "$REPORT"
ls -ld "$NODE_PROFILE" >> "$REPORT" 2>&1
echo "" >> "$REPORT"

echo "Config directories:" >> "$REPORT"
ls -la "$NDM_PROFILE/config/" >> "$REPORT" 2>&1
echo "" >> "$REPORT"
ls -la "$NODE_PROFILE/config/" >> "$REPORT" 2>&1

# ---------------------------------------------------------------------------
# 8. Recent config sync timestamps
# ---------------------------------------------------------------------------
section "8. RECENT CONFIG SYNC STATE"

SYNC_STATUS="${NODE_PROFILE}/config/syncstate.dat"
if [ -f "$SYNC_STATUS" ]; then
    echo "Sync state file:" >> "$REPORT"
    ls -la "$SYNC_STATUS" >> "$REPORT" 2>&1
    echo "" >> "$REPORT"
    cat "$SYNC_STATUS" >> "$REPORT" 2>&1
else
    echo "  syncstate.dat not found" >> "$REPORT"
fi

echo "" >> "$REPORT"
echo "Last 10 sync-related entries from nodeagent SystemOut.log:" >> "$REPORT"
NODEAGENT_LOG="${NODE_PROFILE}/logs/nodeagent/SystemOut.log"
if [ -f "$NODEAGENT_LOG" ]; then
    grep -i "ADMS\|sync\|configSync" "$NODEAGENT_LOG" | tail -10 >> "$REPORT" 2>&1
else
    echo "  nodeagent SystemOut.log not found" >> "$REPORT"
fi

# ---------------------------------------------------------------------------
# 9. Recent wsadmin history
# ---------------------------------------------------------------------------
section "9. RECENT WSADMIN ACTIVITY"

for profile in "$NDM_PROFILE" "$NODE_PROFILE"; do
    pname=$(basename "$profile")
    wsadmin_log="${profile}/logs/wsadmin.traceout"
    if [ -f "$wsadmin_log" ]; then
        echo "${pname}/logs/wsadmin.traceout (last 30 lines):" >> "$REPORT"
        tail -30 "$wsadmin_log" >> "$REPORT" 2>&1
        echo "" >> "$REPORT"
    fi
done

# ---------------------------------------------------------------------------
# 10. Recent startServer / stopServer logs (last attempts)
# ---------------------------------------------------------------------------
section "10. RECENT START/STOP SERVER LOGS"

for srv in BS_APPSRV_01 ESI_APPSRV_01 nodeagent; do
    log_dir="${NODE_PROFILE}/logs/${srv}"
    if [ -d "$log_dir" ]; then
        for logfile in startServer.log stopServer.log; do
            if [ -f "${log_dir}/${logfile}" ]; then
                echo "--- ${srv}/${logfile} (last 20 lines) ---" >> "$REPORT"
                tail -20 "${log_dir}/${logfile}" >> "$REPORT" 2>&1
                echo "" >> "$REPORT"
            fi
        done
    fi
done

# dmgr start/stop
for logfile in startServer.log stopServer.log; do
    dmgr_log="${NDM_PROFILE}/logs/dmgr/${logfile}"
    if [ -f "$dmgr_log" ]; then
        echo "--- dmgr/${logfile} (last 20 lines) ---" >> "$REPORT"
        tail -20 "$dmgr_log" >> "$REPORT" 2>&1
        echo "" >> "$REPORT"
    fi
done

# ---------------------------------------------------------------------------
# 11. FFDC summary
# ---------------------------------------------------------------------------
section "11. FFDC SUMMARY (last 7 days)"

for profile in "$NDM_PROFILE" "$NODE_PROFILE"; do
    pname=$(basename "$profile")
    ffdc_dir="${profile}/logs/ffdc"
    if [ -d "$ffdc_dir" ]; then
        recent=$(find "$ffdc_dir" -name "*.txt" -mtime -7 2>/dev/null)
        if [ -n "$recent" ]; then
            echo "${pname} — Recent FFDC files:" >> "$REPORT"
            echo "$recent" | while read f; do
                echo "  $(ls -la "$f" 2>/dev/null)" >> "$REPORT"
                echo "  First 5 lines:" >> "$REPORT"
                head -5 "$f" >> "$REPORT" 2>&1
                echo "" >> "$REPORT"
            done
        else
            echo "${pname} — No FFDC files in last 7 days" >> "$REPORT"
        fi
    fi
done

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
section "END OF DIAGNOSTICS REPORT"

chmod 644 "$REPORT" 2>/dev/null
echo "DIAGNOSTICS_COLLECTED"
