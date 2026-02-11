#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail


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
        ((issues++)) || true
    fi

    # --- Ownership check ---
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
        echo -e "  ${GREEN}Ownership OK${NC}"
    fi

    # --- Permission bits check ---
    # Directories must be rwx for owner (755+)
    bad_dirs=()
    while IFS= read -r d; do
        bad_dirs+=("$d")
    done < <(find "$profile_dir" -maxdepth 3 -type d ! -perm -u+rwx 2>/dev/null | head -500)

    bad_dir_count=${#bad_dirs[@]}
    if (( bad_dir_count > 0 )); then
        echo -e "  ${RED}$bad_dir_count directories missing owner rwx${NC}"
        for d in "${bad_dirs[@]:0:5}"; do
            d_perms=$(stat -c '%a' "$d" 2>/dev/null || echo "?")
            echo -e "    ${DIM}$d_perms${NC}  ${DIM}$d${NC}"
        done
        if (( bad_dir_count > 5 )); then
            echo -e "    ${DIM}... and $((bad_dir_count - 5)) more${NC}"
        fi
        ((issues += bad_dir_count))
    else
        echo -e "  ${GREEN}Directory permissions OK${NC} ${DIM}(all u+rwx)${NC}"
    fi

    # Files must be rw for owner (644+)
    bad_mode_files=()
    while IFS= read -r f; do
        bad_mode_files+=("$f")
    done < <(find "$profile_dir" -maxdepth 3 -type f ! -perm -u+rw 2>/dev/null | head -500)

    bad_mode_count=${#bad_mode_files[@]}
    if (( bad_mode_count > 0 )); then
        echo -e "  ${RED}$bad_mode_count files missing owner rw${NC}"
        for f in "${bad_mode_files[@]:0:5}"; do
            f_perms=$(stat -c '%a' "$f" 2>/dev/null || echo "?")
            echo -e "    ${DIM}$f_perms${NC}  ${DIM}$f${NC}"
        done
        if (( bad_mode_count > 5 )); then
            echo -e "    ${DIM}... and $((bad_mode_count - 5)) more${NC}"
        fi
        ((issues += bad_mode_count))
    else
        echo -e "  ${GREEN}File permissions OK${NC} ${DIM}(all u+rw)${NC}"
    fi

    # Key WAS config files — explicit check
    security_xml="$profile_dir/config/cells/$CELL_NAME/security.xml"
    if [[ -f "$security_xml" ]]; then
        sec_perms=$(stat -c '%a' "$security_xml" 2>/dev/null || echo "?")
        sec_owner=$(stat -c '%U:%G' "$security_xml" 2>/dev/null || echo "?")
        if [[ $(stat -c '%a' "$security_xml") =~ ^[67] ]]; then
            echo -e "  ${GREEN}security.xml${NC} ${DIM}($sec_perms $sec_owner)${NC}"
        else
            echo -e "  ${RED}security.xml  $sec_perms $sec_owner — needs owner rw${NC}"
            ((issues++)) || true
        fi
    fi

    echo ""
done

# Verdict
if (( issues == 0 )); then
    echo -e "${GREEN}${BOLD}Permissions are correct. No fix needed.${NC}"
else
    echo -e "${YELLOW}${BOLD}Found $issues permission issues. Run 'Fix Permissions' to repair.${NC}"
fi
echo ""
