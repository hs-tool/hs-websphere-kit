#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail


echo ""
echo -e "${BOLD}${CYAN}=== Port Configuration ===${NC}"
echo -e "  Server: ${YELLOW}$SERVER_NAME${NC}"
echo ""

node_name="${SERVER_NAME}_NODE01"
serverindex="$NODE_PROFILE/config/cells/$CELL_NAME/nodes/$node_name/serverindex.xml"

if [[ ! -f "$serverindex" ]]; then
    echo -e "  ${RED}serverindex.xml not found: $serverindex${NC}"
    exit 1
fi

# Parse server entries and their endpoints
current_server=""
while IFS= read -r line; do
    # Server entry
    if [[ "$line" =~ serverName=\"([^\"]+)\" ]]; then
        current_server="${BASH_REMATCH[1]}"
        echo -e "  ${BOLD}${CYAN}$current_server${NC}"
    fi

    # Named endpoint
    if [[ "$line" =~ endPointName=\"([^\"]+)\" ]]; then
        ep_name="${BASH_REMATCH[1]}"
        host=""
        port=""
        [[ "$line" =~ host=\"([^\"]+)\" ]] && host="${BASH_REMATCH[1]}"
        [[ "$line" =~ port=\"([^\"]+)\" ]] && port="${BASH_REMATCH[1]}"

        if [[ -n "$port" ]]; then
            # Check if port is actually listening
            if timeout 2 bash -c "echo >/dev/tcp/localhost/$port" 2>/dev/null; then
                status="${GREEN}OPEN${NC}"
            else
                status="${DIM}closed${NC}"
            fi
            printf "    %-35s ${BOLD}%-6s${NC}  %s\n" "$ep_name" "$port" "$status"
        fi
    fi
done < "$serverindex"

echo ""
