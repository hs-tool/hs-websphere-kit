#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail


echo ""
echo -e "${BOLD}${CYAN}=== MQ Queue Depths ===${NC}"
echo -e "  Server: ${YELLOW}$SERVER_NAME${NC}"
echo -e "  QM:     ${BOLD}$MQ_QM${NC}"
echo ""

# Check MQ is available
runmqsc_cmd="runmqsc"
if ! command -v runmqsc &>/dev/null; then
    if [[ -f /opt/mqm/bin/runmqsc ]]; then
        runmqsc_cmd="/opt/mqm/bin/runmqsc"
    else
        echo -e "  ${RED}ERROR: runmqsc not found${NC}"
        exit 1
    fi
fi

# Query all local queues
echo -e "  ${DIM}Querying queue depths...${NC}"
echo ""

mq_output=$(echo "DISPLAY QLOCAL(*) CURDEPTH MAXDEPTH" | timeout 15 sudo -u "$MQ_USER" "$runmqsc_cmd" "$MQ_QM" 2>/dev/null || true)

if [[ -z "$mq_output" ]]; then
    echo -e "  ${RED}ERROR: Could not query MQ (is $MQ_QM running?)${NC}"
    exit 1
fi

# Parse output
printf "  ${BOLD}%-45s %8s %8s %6s${NC}\n" "Queue Name" "Depth" "MaxDepth" "%Full"
printf "  ${DIM}%-45s %8s %8s %6s${NC}\n" "---------------------------------------------" "--------" "--------" "------"

queue_name=""
cur_depth=""
max_depth=""
total_queues=0
queues_with_msgs=0

# Regex patterns (stored in vars to avoid bash parsing issues with parentheses)
re_queue='QUEUE\(([^)]+)\)'
re_curdepth='CURDEPTH\(([0-9]+)\)'
re_maxdepth='MAXDEPTH\(([0-9]+)\)'

while IFS= read -r line; do
    # Extract queue name
    if [[ "$line" =~ $re_queue ]]; then
        queue_name="${BASH_REMATCH[1]}"
    fi
    # Extract current depth
    if [[ "$line" =~ $re_curdepth ]]; then
        cur_depth="${BASH_REMATCH[1]}"
    fi
    # Extract max depth
    if [[ "$line" =~ $re_maxdepth ]]; then
        max_depth="${BASH_REMATCH[1]}"
    fi

    # When we have all 3, print the line
    if [[ -n "$queue_name" && -n "$cur_depth" && -n "$max_depth" ]]; then
        ((total_queues++)) || true

        # Skip SYSTEM.* queues with 0 depth
        if [[ "$queue_name" == SYSTEM.* && "$cur_depth" == "0" ]]; then
            queue_name=""; cur_depth=""; max_depth=""
            continue
        fi

        # Calculate percentage
        if (( max_depth > 0 )); then
            pct=$(( (cur_depth * 100) / max_depth ))
        else
            pct=0
        fi

        # Color based on depth
        if (( cur_depth == 0 )); then
            color="$DIM"
        elif (( pct >= 80 )); then
            color="$RED"
            ((queues_with_msgs++)) || true
        elif (( cur_depth > 0 )); then
            color="$YELLOW"
            ((queues_with_msgs++)) || true
        fi

        printf "  ${color}%-45s %8s %8s %5s%%${NC}\n" "$queue_name" "$cur_depth" "$max_depth" "$pct"

        queue_name=""; cur_depth=""; max_depth=""
    fi
done <<< "$mq_output"

echo ""
echo -e "${BOLD}----------------------------------------${NC}"
echo -e "  Total queues: ${BOLD}$total_queues${NC}  |  With messages: ${BOLD}$queues_with_msgs${NC}"
if (( queues_with_msgs > 0 )); then
    echo -e "  ${YELLOW}${BOLD}$queues_with_msgs queues have pending messages${NC}"
fi
echo ""
