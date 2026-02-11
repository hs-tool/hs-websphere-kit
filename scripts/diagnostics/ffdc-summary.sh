#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail


echo ""
echo -e "${BOLD}${CYAN}=== FFDC Exception Summary ===${NC}"
echo -e "  Server: ${YELLOW}$SERVER_NAME${NC}"
echo ""

# Find all exception.log files
exception_logs=()
for ffdc_dir in "$NODE_PROFILE/logs/ffdc" "$NDM_PROFILE/logs/ffdc"; do
    if [[ -d "$ffdc_dir" ]]; then
        while IFS= read -r f; do
            exception_logs+=("$f")
        done < <(find "$ffdc_dir" -name "*_exception.log" -type f 2>/dev/null)
    fi
done

if (( ${#exception_logs[@]} == 0 )); then
    echo -e "  ${GREEN}No FFDC exception logs found.${NC}"
    echo ""
    exit 0
fi

for exc_log in "${exception_logs[@]}"; do
    profile_name=$(basename "$(dirname "$(dirname "$(dirname "$exc_log")")")")
    server_name=$(basename "$exc_log" | sed 's/_exception\.log$//')

    echo -e "${BOLD}${CYAN}$profile_name / $server_name${NC}"
    echo -e "${DIM}  File: $exc_log${NC}"

    # Count total entries
    total_entries=$(grep -c "^[[:space:]]*[0-9]" "$exc_log" 2>/dev/null || echo 0)
    echo -e "  Total exceptions: ${BOLD}$total_entries${NC}"

    if (( total_entries == 0 )); then
        echo ""
        continue
    fi

    echo ""
    printf "  ${BOLD}%-6s %-6s %-28s %-45s${NC}\n" "Index" "Count" "Last Occurrence" "Exception"
    printf "  ${DIM}%-6s %-6s %-28s %-45s${NC}\n" "-----" "-----" "----------------------------" "---------------------------------------------"

    # Parse the exception log table
    while IFS= read -r line; do
        # Match data lines: index count first_time last_time exception_class ...
        if [[ "$line" =~ ^[[:space:]]*([0-9]+)[[:space:]]+([0-9]+)[[:space:]]+([0-9/]+[[:space:]][0-9:.]+[[:space:]][A-Z]+)[[:space:]]+([0-9/]+[[:space:]][0-9:.]+[[:space:]][A-Z]+)[[:space:]]+(.+) ]]; then
            idx="${BASH_REMATCH[1]}"
            count="${BASH_REMATCH[2]}"
            last_time="${BASH_REMATCH[4]}"
            exception_full="${BASH_REMATCH[5]}"
            # Extract just the exception class name (first token before space)
            exception_class="${exception_full%% *}"
            # Shorten class name: keep last 2 segments
            short_class=$(echo "$exception_class" | awk -F. '{if(NF>2) print $(NF-1)"."$NF; else print $0}')

            # Color by severity
            if (( count >= 10 )); then
                color="$RED"
            elif (( count >= 3 )); then
                color="$YELLOW"
            else
                color="$DIM"
            fi

            printf "  ${color}%-6s %-6s %-28s %-45s${NC}\n" "$idx" "${count}x" "$last_time" "$short_class"
        fi
    done < "$exc_log"

    # Count FFDC incident files
    ffdc_dir=$(dirname "$exc_log")
    incident_count=$(find "$ffdc_dir" -name "${server_name}_*.txt" -type f 2>/dev/null | wc -l)
    echo ""
    echo -e "  ${DIM}FFDC incident files: $incident_count${NC}"
    echo ""
done

echo -e "${BOLD}----------------------------------------${NC}"
echo -e "${DIM}Tip: Run 'Log Search' with pattern 'Exception' for full stack traces.${NC}"
echo ""
