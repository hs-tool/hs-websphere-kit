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

ACCEPTED_GROUPS=("${WAS_GROUP}" "users")
issues=0

echo ""
echo -e "${BOLD}${CYAN}=== Permission Audit ===${NC}"
echo -e "  Expected owner: ${BOLD}${WAS_USER}${NC} with group ${BOLD}${WAS_GROUP}${NC} or ${BOLD}users${NC}"
echo -e "  Server:         ${YELLOW}$SERVER_NAME${NC}"
echo ""

is_ok_owner() {
    local file="$1"
    local owner group
    owner=$(stat -c '%U' "$file" 2>/dev/null || echo "unknown")
    group=$(stat -c '%G' "$file" 2>/dev/null || echo "unknown")
    [[ "$owner" == "$WAS_USER" ]] || return 1
    for g in "${ACCEPTED_GROUPS[@]}"; do
        [[ "$group" == "$g" ]] && return 0
    done
    return 1
}

for profile_dir in "$NDM_PROFILE" "$NODE_PROFILE"; do
    label=$(basename "$profile_dir")
    echo -e "${BOLD}$label${NC}"

    # Check top-level directory
    top_owner=$(stat -c '%U:%G' "$profile_dir" 2>/dev/null || echo "unknown")
    if is_ok_owner "$profile_dir"; then
        echo -e "  ${GREEN}root dir:  $top_owner${NC}"
    else
        echo -e "  ${RED}root dir:  $top_owner${NC}"
        ((issues++))
    fi

    # Scan for files NOT owned by wasadmin with an accepted group
    bad_files=()
    while IFS= read -r f; do
        is_ok_owner "$f" || bad_files+=("$f")
    done < <(find "$profile_dir" -maxdepth 3 2>/dev/null | head -500)

    bad_count=${#bad_files[@]}
    if (( bad_count > 0 )); then
        echo -e "  ${RED}$bad_count items with wrong ownership (top 3 levels)${NC}"
        for f in "${bad_files[@]:0:5}"; do
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
