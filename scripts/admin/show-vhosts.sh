#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail


echo ""
echo -e "${BOLD}${CYAN}=== Virtual Hosts ===${NC}"
echo -e "  Server: ${YELLOW}$SERVER_NAME${NC}"
echo ""

vhosts_xml="$NDM_PROFILE/config/cells/$CELL_NAME/virtualhosts.xml"

if [[ ! -f "$vhosts_xml" ]]; then
    echo -e "  ${RED}virtualhosts.xml not found: $vhosts_xml${NC}"
    exit 1
fi

# Parse virtual hosts
current_vhost=""
while IFS= read -r line; do
    # Virtual host name
    if [[ "$line" =~ name=\"([^\"]+)\" ]] && [[ "$line" == *"VirtualHost"* || "$line" == *"virtualhosts"* ]]; then
        current_vhost="${BASH_REMATCH[1]}"
        echo -e "  ${BOLD}${CYAN}$current_vhost${NC}"
    fi

    # Host aliases (hostname:port)
    if [[ "$line" =~ hostname=\"([^\"]+)\" ]]; then
        hostname="${BASH_REMATCH[1]}"
        port=""
        if [[ "$line" =~ port=\"([^\"]+)\" ]]; then
            port="${BASH_REMATCH[1]}"
        fi
        if [[ "$hostname" == "*" ]]; then
            echo -e "    ${DIM}*:${port:-*}${NC}"
        else
            echo -e "    ${GREEN}${hostname}:${port:-*}${NC}"
        fi
    fi
done < "$vhosts_xml"

echo ""
