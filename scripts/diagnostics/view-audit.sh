#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail


AUDIT_LOG="/opt/was/audit.log"

echo ""
echo -e "${BOLD}${CYAN}=== Audit Log ===${NC}"
echo -e "  Server: ${YELLOW}$SERVER_NAME${NC}"
echo ""

if [[ ! -f "$AUDIT_LOG" ]]; then
    echo -e "  ${DIM}No audit log found at $AUDIT_LOG${NC}"
    echo -e "  ${DIM}Audit logging starts automatically on next script run.${NC}"
    exit 0
fi

total_lines=$(wc -l < "$AUDIT_LOG" 2>/dev/null || echo 0)
echo -e "  ${DIM}Total entries: $total_lines${NC}"
echo ""

echo -e "  ${BOLD}Show:${NC}"
echo -e "    ${BOLD}1${NC}  Last 20 entries"
echo -e "    ${BOLD}2${NC}  Last 50 entries"
echo -e "    ${BOLD}3${NC}  Today only"
echo -e "    ${BOLD}4${NC}  Search by script name"
echo ""
read -p "  Select (1-4) [1]: " choice
choice="${choice:-1}"

echo ""
printf "  ${BOLD}%-20s %-15s %-12s %-30s${NC}\n" "Timestamp" "Server" "User" "Script"
printf "  ${DIM}%-20s %-15s %-12s %-30s${NC}\n" "--------------------" "---------------" "------------" "------------------------------"

case "$choice" in
    1)
        tail -20 "$AUDIT_LOG" | while IFS='|' read -r ts srv usr scr; do
            printf "  %-20s %-15s %-12s %-30s\n" "$(echo "$ts" | xargs)" "$(echo "$srv" | xargs)" "$(echo "$usr" | xargs)" "$(echo "$scr" | xargs)"
        done
        ;;
    2)
        tail -50 "$AUDIT_LOG" | while IFS='|' read -r ts srv usr scr; do
            printf "  %-20s %-15s %-12s %-30s\n" "$(echo "$ts" | xargs)" "$(echo "$srv" | xargs)" "$(echo "$usr" | xargs)" "$(echo "$scr" | xargs)"
        done
        ;;
    3)
        today=$(date +%Y-%m-%d)
        grep "^$today" "$AUDIT_LOG" 2>/dev/null | while IFS='|' read -r ts srv usr scr; do
            printf "  %-20s %-15s %-12s %-30s\n" "$(echo "$ts" | xargs)" "$(echo "$srv" | xargs)" "$(echo "$usr" | xargs)" "$(echo "$scr" | xargs)"
        done
        ;;
    4)
        read -p "  Script name to search: " search_term
        grep -i "$search_term" "$AUDIT_LOG" 2>/dev/null | tail -30 | while IFS='|' read -r ts srv usr scr; do
            printf "  %-20s %-15s %-12s %-30s\n" "$(echo "$ts" | xargs)" "$(echo "$srv" | xargs)" "$(echo "$usr" | xargs)" "$(echo "$scr" | xargs)"
        done
        ;;
esac

echo ""
