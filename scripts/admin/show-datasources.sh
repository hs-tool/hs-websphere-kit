#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail


echo ""
echo -e "${BOLD}${CYAN}=== Data Sources ===${NC}"
echo -e "  Server: ${YELLOW}$SERVER_NAME${NC}"
echo ""

node_name="${SERVER_NAME}_NODE01"

# Search for resources.xml files which define data sources
resources_files=()
while IFS= read -r f; do
    resources_files+=("$f")
done < <(find "$NDM_PROFILE/config/cells/$CELL_NAME" -name "resources.xml" -type f 2>/dev/null)

if (( ${#resources_files[@]} == 0 )); then
    echo -e "  ${YELLOW}No resources.xml files found${NC}"
    exit 0
fi

ds_count=0

for res_file in "${resources_files[@]}"; do
    # Extract data source entries
    while IFS= read -r ds_line; do
        ds_name=$(echo "$ds_line" | grep -oP 'name="[^"]*"' | head -1 | sed 's/name="//;s/"//')
        jndi=$(echo "$ds_line" | grep -oP 'jndiName="[^"]*"' | head -1 | sed 's/jndiName="//;s/"//')
        ds_helper=$(echo "$ds_line" | grep -oP 'datasourceHelperClassname="[^"]*"' | head -1 | sed 's/datasourceHelperClassname="//;s/"//')

        if [[ -n "$ds_name" ]]; then
            ((ds_count++)) || true
            echo -e "  ${BOLD}$ds_name${NC}"
            echo -e "    JNDI:   ${GREEN}$jndi${NC}"

            # Determine DB type from helper class
            if [[ "$ds_helper" == *"Oracle"* ]]; then
                echo -e "    Type:   Oracle"
            elif [[ "$ds_helper" == *"DB2"* ]]; then
                echo -e "    Type:   DB2"
            elif [[ "$ds_helper" == *"SQL"* || "$ds_helper" == *"Microsoft"* ]]; then
                echo -e "    Type:   SQL Server"
            else
                echo -e "    Type:   ${DIM}${ds_helper:-unknown}${NC}"
            fi

            # Extract connection pool settings from nearby connectionPool entries
            echo -e "    ${DIM}Source: ${res_file#$NDM_PROFILE/}${NC}"
            echo ""
        fi
    done < <(grep -i "dataSource\b\|WAS40DataSource" "$res_file" 2>/dev/null || true)
done

# Also check for JDBC provider info
echo -e "${BOLD}JDBC Providers:${NC}"
echo ""
for res_file in "${resources_files[@]}"; do
    while IFS= read -r jdbc_line; do
        prov_name=$(echo "$jdbc_line" | grep -oP 'name="[^"]*"' | head -1 | sed 's/name="//;s/"//')
        impl_class=$(echo "$jdbc_line" | grep -oP 'implementationClassName="[^"]*"' | head -1 | sed 's/implementationClassName="//;s/"//')
        if [[ -n "$prov_name" ]]; then
            echo -e "  ${BOLD}$prov_name${NC}"
            echo -e "    ${DIM}$impl_class${NC}"
            echo ""
        fi
    done < <(grep "JDBCProvider" "$res_file" 2>/dev/null || true)
done

echo -e "${BOLD}----------------------------------------${NC}"
echo -e "  Total data sources: ${BOLD}$ds_count${NC}"
echo ""
