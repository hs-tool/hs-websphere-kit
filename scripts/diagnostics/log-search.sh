#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail


echo ""
echo -e "${BOLD}${CYAN}=== Log Search ===${NC}"
echo -e "  Server: ${YELLOW}$SERVER_NAME${NC}"
echo ""

# Collect all log directories
LOG_DIRS=(
    "$NODE_PROFILE/logs/$APP_SERVER"
    "$NODE_PROFILE/logs/nodeagent"
    "$NODE_PROFILE/logs/ffdc"
    "$NDM_PROFILE/logs/dmgr"
    "$NDM_PROFILE/logs/ffdc"
)

# Preset searches
echo -e "  ${BOLD}Quick searches:${NC}"
echo -e "    ${BOLD}1${NC}  Exceptions         ${DIM}(Exception|Error|SEVERE)${NC}"
echo -e "    ${BOLD}2${NC}  ClassNotFound       ${DIM}(ClassNotFoundException)${NC}"
echo -e "    ${BOLD}3${NC}  Out of Memory       ${DIM}(OutOfMemoryError|heap)${NC}"
echo -e "    ${BOLD}4${NC}  Connection errors   ${DIM}(refused|timeout|unreachable)${NC}"
echo -e "    ${BOLD}5${NC}  App start/stop      ${DIM}(WSVR0001I|WSVR0024I|ADMA5)${NC}"
echo -e "    ${BOLD}6${NC}  JNDI errors         ${DIM}(NamingException|JNDI)${NC}"
echo -e "    ${BOLD}c${NC}  Custom pattern      ${DIM}(enter your own regex)${NC}"
echo ""

read -p "  Select (1-6/c): " choice

case "$choice" in
    1) pattern="Exception|Error|SEVERE" ;;
    2) pattern="ClassNotFoundException" ;;
    3) pattern="OutOfMemoryError|heap space|GC overhead" ;;
    4) pattern="Connection refused|timed out|unreachable|ConnectException" ;;
    5) pattern="WSVR0001I|WSVR0024I|ADMA50[0-9][0-9]" ;;
    6) pattern="NamingException|JNDI|CannotInstantiateObject" ;;
    c|C)
        read -p "  Enter search pattern (regex): " pattern
        if [[ -z "$pattern" ]]; then
            echo -e "  ${RED}No pattern specified.${NC}"
            exit 1
        fi
        ;;
    *)
        echo -e "  ${RED}Invalid option.${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "  ${BOLD}Searching for:${NC} ${YELLOW}$pattern${NC}"
echo -e "  ${DIM}Across ${#LOG_DIRS[@]} log directories...${NC}"
echo ""

# Time range filter
echo -e "  ${BOLD}Time filter:${NC}"
echo -e "    ${BOLD}1${NC}  Last 1 hour"
echo -e "    ${BOLD}2${NC}  Last 24 hours"
echo -e "    ${BOLD}3${NC}  All time ${DIM}(no filter)${NC}"
echo ""
read -p "  Select (1-3) [3]: " time_choice
time_choice="${time_choice:-3}"

time_args=""
case "$time_choice" in
    1) time_args="-mmin -60" ;;
    2) time_args="-mmin -1440" ;;
    3) time_args="" ;;
esac

# Search
total_matches=0
for log_dir in "${LOG_DIRS[@]}"; do
    [[ -d "$log_dir" ]] || continue
    dir_label="${log_dir#$WAS_BASE/}"

    # Find log files, optionally filtered by time
    while IFS= read -r log_file; do
        [[ -f "$log_file" ]] || continue
        matches=$(grep -cE "$pattern" "$log_file" 2>/dev/null || true)
        if (( matches > 0 )); then
            file_label=$(basename "$log_file")
            echo -e "${BOLD}${CYAN}--- $dir_label/$file_label${NC} ${DIM}($matches matches)${NC}"
            # Show matches with context
            grep -nE --color=always "$pattern" "$log_file" 2>/dev/null | head -30
            remaining=$((matches - 30))
            if (( remaining > 0 )); then
                echo -e "  ${DIM}... and $remaining more matches${NC}"
            fi
            echo ""
            ((total_matches += matches)) || true
        fi
    done < <(find "$log_dir" -maxdepth 1 -type f -name "*.log" -o -name "*.txt" $time_args 2>/dev/null)
done

echo -e "${BOLD}----------------------------------------${NC}"
if (( total_matches > 0 )); then
    echo -e "${YELLOW}${BOLD}Found $total_matches matches across all logs.${NC}"
else
    echo -e "${GREEN}${BOLD}No matches found.${NC}"
fi
echo ""
