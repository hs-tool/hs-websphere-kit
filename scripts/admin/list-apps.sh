#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail


echo ""
echo -e "${BOLD}${CYAN}=== Deployed Applications ===${NC}"
echo -e "  Server: ${YELLOW}$SERVER_NAME${NC}"
echo -e "  Cell:   ${BOLD}$CELL_NAME${NC}"
echo ""

# Method 1: Read from cell config (works without running wsadmin)
apps_dir="$NDM_PROFILE/config/cells/$CELL_NAME/applications"

if [[ ! -d "$apps_dir" ]]; then
    echo -e "  ${RED}Applications directory not found: $apps_dir${NC}"
    exit 1
fi

echo -e "  ${BOLD}Applications in cell config:${NC}"
echo ""

printf "  ${BOLD}%-4s %-45s %10s %-15s${NC}\n" "#" "Application" "Size" "Type"
printf "  ${DIM}%-4s %-45s %10s %-15s${NC}\n" "---" "---------------------------------------------" "----------" "---------------"

idx=0
while IFS= read -r app_dir; do
    [[ -d "$app_dir" ]] || continue
    app_name=$(basename "$app_dir")
    ((idx++)) || true

    # Get size
    app_size=$(du -sh "$app_dir" 2>/dev/null | cut -f1)

    # Check for deployment.xml to determine type
    if [[ -f "$app_dir/deployments/$app_name/deployment.xml" ]]; then
        # Try to detect EAR vs WAR
        if find "$app_dir" -name "*.ear" -maxdepth 3 2>/dev/null | grep -q .; then
            app_type="EAR"
        elif find "$app_dir" -name "*.war" -maxdepth 3 2>/dev/null | grep -q .; then
            app_type="WAR"
        else
            app_type="Enterprise"
        fi
    else
        app_type="Unknown"
    fi

    printf "  %-4s %-45s %10s %-15s\n" "$idx" "$app_name" "$app_size" "$app_type"
done < <(find "$apps_dir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort)

# Method 2: Check which are mapped to our app server (from serverindex.xml)
echo ""
echo -e "  ${BOLD}Server mappings:${NC}"

node_name="${SERVER_NAME}_NODE01"
serverindex="$NODE_PROFILE/config/cells/$CELL_NAME/nodes/$node_name/serverindex.xml"

if [[ -f "$serverindex" ]]; then
    # Extract app server entries
    for srv in "$APP_SERVER"; do
        app_count=$(grep -c "serverName=\"$srv\"" "$serverindex" 2>/dev/null || echo 0)
        echo -e "    $srv: ${BOLD}$app_count${NC} applications mapped"
    done
    # Check for ESI_APPSRV_01
    esi_count=$(grep -c "serverName=\"ESI_APPSRV_01\"" "$serverindex" 2>/dev/null || echo 0)
    if (( esi_count > 0 )); then
        echo -e "    ESI_APPSRV_01: ${BOLD}$esi_count${NC} applications mapped"
    fi
else
    echo -e "    ${DIM}serverindex.xml not found${NC}"
fi

echo ""
echo -e "${BOLD}----------------------------------------${NC}"
echo -e "  Total applications: ${BOLD}$idx${NC}"
echo ""
