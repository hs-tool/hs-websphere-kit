#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -uo pipefail


echo ""
echo -e "${BOLD}${CYAN}=== Health Check ===${NC}"
echo -e "  Server: ${YELLOW}$SERVER_NAME${NC}"
echo ""

passed=0
failed=0
warnings=0

check() {
    local label="$1"
    local result="$2"  # 0=pass, 1=fail, 2=warn
    local detail="${3:-}"

    if (( result == 0 )); then
        printf "  ${GREEN}PASS${NC}  %-35s %s\n" "$label" "$detail"
        ((passed++)) || true
    elif (( result == 2 )); then
        printf "  ${YELLOW}WARN${NC}  %-35s %s\n" "$label" "$detail"
        ((warnings++)) || true
    else
        printf "  ${RED}FAIL${NC}  %-35s %s\n" "$label" "$detail"
        ((failed++)) || true
    fi
}

# --- Process checks ---
echo -e "${BOLD}Processes${NC}"
ps_snap=$(ps -ef 2>/dev/null)

if echo "$ps_snap" | grep -v grep | grep -q "dmgr"; then
    check "Deployment Manager" 0 "running"
else
    check "Deployment Manager" 1 "not running"
fi

if echo "$ps_snap" | grep -v grep | grep -q "nodeagent"; then
    check "Node Agent" 0 "running"
else
    check "Node Agent" 1 "not running"
fi

if echo "$ps_snap" | grep -v grep | grep -q "$APP_SERVER"; then
    check "App Server ($APP_SERVER)" 0 "running"
else
    check "App Server ($APP_SERVER)" 1 "not running"
fi

# --- Port checks ---
echo ""
echo -e "${BOLD}Ports${NC}"

check_port() {
    local port="$1"
    local label="$2"
    if timeout 5 bash -c "echo >/dev/tcp/localhost/$port" 2>/dev/null; then
        check "$label" 0 "port $port listening"
    else
        check "$label" 1 "port $port not responding"
    fi
}

check_port 9060  "Admin Console (HTTP)"
check_port 9043  "Admin Console (HTTPS)"
check_port 9080  "App Server HTTP"
check_port 9443  "App Server HTTPS"
check_port 8879  "SOAP Connector (Dmgr)"
check_port 8880  "SOAP Connector (Node)"

# --- MQ check ---
echo ""
echo -e "${BOLD}MQ${NC}"

if command -v dspmq &>/dev/null || [[ -d /opt/mqm/bin ]]; then
    dspmq_cmd="dspmq"
    command -v dspmq &>/dev/null || dspmq_cmd="/opt/mqm/bin/dspmq"
    mq_out=$(timeout 10 sudo -u "$MQ_USER" "$dspmq_cmd" 2>/dev/null || true)
    if echo "$mq_out" | grep -qi "Running"; then
        check "Queue Manager ($MQ_QM)" 0 "running"
    else
        check "Queue Manager ($MQ_QM)" 1 "not running"
    fi

    # MQ listener port (1414 default)
    if timeout 5 bash -c "echo >/dev/tcp/localhost/1414" 2>/dev/null; then
        check "MQ Listener" 0 "port 1414 listening"
    else
        check "MQ Listener" 2 "port 1414 not responding (may use different port)"
    fi
else
    check "MQ" 2 "not installed"
fi

# --- Disk check ---
echo ""
echo -e "${BOLD}Disk${NC}"

if df -h "$WAS_BASE" &>/dev/null; then
    disk_pct=$(df -h "$WAS_BASE" | awk 'NR==2{print $5}' | tr -d '%')
    disk_used=$(df -h "$WAS_BASE" | awk 'NR==2{print $3"/"$2}')
    if (( disk_pct >= 90 )); then
        check "Disk ($WAS_BASE)" 1 "$disk_used ($disk_pct%)"
    elif (( disk_pct >= 80 )); then
        check "Disk ($WAS_BASE)" 2 "$disk_used ($disk_pct%)"
    else
        check "Disk ($WAS_BASE)" 0 "$disk_used ($disk_pct%)"
    fi
fi

# --- Recent errors check ---
echo ""
echo -e "${BOLD}Recent Errors (last 30 min)${NC}"

app_log="$NODE_PROFILE/logs/$APP_SERVER/SystemOut.log"
if [[ -f "$app_log" ]]; then
    recent_errors=$(find "$app_log" -mmin -30 -exec grep -c "E " {} \; 2>/dev/null || echo 0)
    if (( recent_errors > 20 )); then
        check "SystemOut.log errors" 1 "$recent_errors errors in last 30 min"
    elif (( recent_errors > 5 )); then
        check "SystemOut.log errors" 2 "$recent_errors errors in last 30 min"
    else
        check "SystemOut.log errors" 0 "${recent_errors:-0} errors"
    fi
else
    check "SystemOut.log" 2 "file not found"
fi

# FFDC count in last hour
ffdc_recent=0
for ffdc_dir in "$NODE_PROFILE/logs/ffdc" "$NDM_PROFILE/logs/ffdc"; do
    if [[ -d "$ffdc_dir" ]]; then
        count=$(find "$ffdc_dir" -name "*.txt" -mmin -60 2>/dev/null | wc -l)
        ((ffdc_recent += count)) || true
    fi
done
if (( ffdc_recent > 5 )); then
    check "Recent FFDC incidents" 1 "$ffdc_recent in last hour"
elif (( ffdc_recent > 0 )); then
    check "Recent FFDC incidents" 2 "$ffdc_recent in last hour"
else
    check "Recent FFDC incidents" 0 "none"
fi

# Heap dumps present
dump_count=0
for profile_dir in "$NDM_PROFILE" "$NODE_PROFILE"; do
    count=$(find "$profile_dir" -maxdepth 1 \( -name "heapdump.*.phd" -o -name "javacore.*.txt" -o -name "core.*.dmp" \) 2>/dev/null | wc -l)
    ((dump_count += count)) || true
done
if (( dump_count > 0 )); then
    check "Heap dumps / javacores" 1 "$dump_count found (indicates past crashes)"
else
    check "Heap dumps / javacores" 0 "none"
fi

# --- Summary ---
echo ""
echo -e "${BOLD}----------------------------------------${NC}"
total=$((passed + failed + warnings))
if (( failed == 0 )); then
    echo -e "${GREEN}${BOLD}Health check: $passed/$total passed, $warnings warnings${NC}"
else
    echo -e "${RED}${BOLD}Health check: $failed FAILED, $passed passed, $warnings warnings${NC}"
fi
echo ""
