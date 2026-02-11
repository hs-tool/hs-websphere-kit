#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail


echo ""
echo -e "${BOLD}${CYAN}=== JVM Configuration ===${NC}"
echo -e "  Server: ${YELLOW}$SERVER_NAME${NC}"
echo ""

node_name="${SERVER_NAME}_NODE01"

# Read server.xml for JVM config
for srv in "$APP_SERVER" "ESI_APPSRV_01"; do
    server_xml="$NODE_PROFILE/config/cells/$CELL_NAME/nodes/$node_name/servers/$srv/server.xml"

    if [[ ! -f "$server_xml" ]]; then
        continue
    fi

    echo -e "${BOLD}${CYAN}$srv${NC}"
    echo -e "  ${DIM}$server_xml${NC}"
    echo ""

    # Extract JVM args
    generic_args=$(grep -oP 'genericJvmArguments="[^"]*"' "$server_xml" 2>/dev/null | head -1 | sed 's/genericJvmArguments="//;s/"$//')
    if [[ -n "$generic_args" ]]; then
        echo -e "  ${BOLD}Generic JVM Arguments:${NC}"
        # Split on space and print each arg
        for arg in $generic_args; do
            if [[ "$arg" == -Xmx* || "$arg" == -Xms* ]]; then
                echo -e "    ${GREEN}$arg${NC}"
            elif [[ "$arg" == -Xgc* || "$arg" == -XX:* ]]; then
                echo -e "    ${YELLOW}$arg${NC}"
            else
                echo -e "    ${DIM}$arg${NC}"
            fi
        done
    else
        echo -e "  ${DIM}No generic JVM arguments set${NC}"
    fi

    # Extract heap sizes from server.xml
    init_heap=$(grep -oP 'initialHeapSize="[0-9]+"' "$server_xml" 2>/dev/null | head -1 | grep -oP '[0-9]+')
    max_heap=$(grep -oP 'maximumHeapSize="[0-9]+"' "$server_xml" 2>/dev/null | head -1 | grep -oP '[0-9]+')
    echo ""
    echo -e "  ${BOLD}Heap Configuration:${NC}"
    echo -e "    Initial Heap: ${BOLD}${init_heap:-default}${NC} MB"
    echo -e "    Maximum Heap: ${BOLD}${max_heap:-default}${NC} MB"

    # Extract verbose GC, debug mode
    verbose_gc=$(grep -oP 'verboseModeGarbageCollection="[^"]*"' "$server_xml" 2>/dev/null | head -1 | grep -oP '(true|false)')
    debug_mode=$(grep -oP 'debugMode="[^"]*"' "$server_xml" 2>/dev/null | head -1 | grep -oP '(true|false)')
    echo ""
    echo -e "  ${BOLD}Flags:${NC}"
    echo -e "    Verbose GC:   ${verbose_gc:-not set}"
    echo -e "    Debug Mode:   ${debug_mode:-not set}"

    # Thread pool info
    echo ""
    echo -e "  ${BOLD}Thread Pools:${NC}"
    # Parse threadPool entries
    while IFS= read -r tp_line; do
        tp_name=$(echo "$tp_line" | grep -oP 'name="[^"]*"' | sed 's/name="//;s/"//')
        tp_min=$(echo "$tp_line" | grep -oP 'minimumSize="[0-9]*"' | grep -oP '[0-9]+')
        tp_max=$(echo "$tp_line" | grep -oP 'maximumSize="[0-9]*"' | grep -oP '[0-9]+')
        if [[ -n "$tp_name" ]]; then
            printf "    %-25s min=%-4s max=%-4s\n" "$tp_name" "${tp_min:-?}" "${tp_max:-?}"
        fi
    done < <(grep "threadPool " "$server_xml" 2>/dev/null || true)

    echo ""
done

echo ""
