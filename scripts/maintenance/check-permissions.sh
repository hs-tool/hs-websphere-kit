#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

EXPECTED="${WAS_USER}:${WAS_GROUP}"
issues=0

echo ""
echo -e "${BOLD}${CYAN}=== Permission Audit ===${NC}"
echo -e "  Expected owner: ${BOLD}$EXPECTED${NC}"
echo -e "  Server:         ${YELLOW}$SERVER_NAME${NC}"
echo ""

for profile_dir in "$NDM_PROFILE" "$NODE_PROFILE"; do
    label=$(basename "$profile_dir")
    echo -e "${BOLD}$label${NC}"

    # Check top-level directory
    top_owner=$(stat -c '%U:%G' "$profile_dir" 2>/dev/null || echo "unknown")
    if [[ "$top_owner" != "$EXPECTED" ]]; then
        echo -e "  ${RED}root dir:  $top_owner${NC}"
        ((issues++))
    else
        echo -e "  ${GREEN}root dir:  $top_owner${NC}"
    fi

    # Scan for any files/dirs NOT owned by expected user (sample up to 500)
    bad_count=$(find "$profile_dir" -maxdepth 3 \( ! -user "$WAS_USER" -o ! -group "$WAS_GROUP" \) 2>/dev/null | head -500 | wc -l)

    if (( bad_count > 0 )); then
        echo -e "  ${RED}$bad_count items with wrong ownership (top 3 levels)${NC}"
        # Show up to 5 examples
        find "$profile_dir" -maxdepth 3 \( ! -user "$WAS_USER" -o ! -group "$WAS_GROUP" \) 2>/dev/null | head -5 | while read -r f; do
            f_owner=$(stat -c '%U:%G' "$f" 2>/dev/null || echo "?")
            echo -e "    ${DIM}$f_owner${NC}  ${DIM}$f${NC}"
        done
        if (( bad_count > 5 )); then
            echo -e "    ${DIM}... and $((bad_count - 5)) more${NC}"
        fi
        ((issues += bad_count))
    else
        echo -e "  ${GREEN}All files OK${NC}"
    fi
    echo ""
done

# Verdict
if (( issues == 0 )); then
    echo -e "${GREEN}${BOLD}Permissions are correct. No fix needed.${NC}"
else
    echo -e "${YELLOW}${BOLD}Found permission issues. Run 'Fix Permissions' (option 15) to repair.${NC}"
fi
echo ""
