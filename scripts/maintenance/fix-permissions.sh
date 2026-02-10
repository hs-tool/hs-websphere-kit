#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

EXPECTED="${WAS_USER}:${WAS_GROUP}"

echo ""
echo -e "${BOLD}${CYAN}=== Fix Permissions ===${NC}"
echo -e "  Owner:  ${BOLD}$EXPECTED${NC}"
echo -e "  Server: ${YELLOW}$SERVER_NAME${NC}"
echo ""

# --- Pre-check: is there anything to fix? ---
needs_fix=0
for profile_dir in "$NDM_PROFILE" "$NODE_PROFILE"; do
    # Wrong ownership
    bad=$(find "$profile_dir" -maxdepth 3 \( ! -user "$WAS_USER" -o ! -group "$WAS_GROUP" \) 2>/dev/null | head -1 | wc -l)
    if (( bad > 0 )); then needs_fix=1; fi
    # Directories missing owner rwx
    bad=$(find "$profile_dir" -maxdepth 3 -type d ! -perm -u+rwx 2>/dev/null | head -1 | wc -l)
    if (( bad > 0 )); then needs_fix=1; fi
    # Files missing owner rw
    bad=$(find "$profile_dir" -maxdepth 3 -type f ! -perm -u+rw 2>/dev/null | head -1 | wc -l)
    if (( bad > 0 )); then needs_fix=1; fi
done

if (( needs_fix == 0 )); then
    echo -e "${GREEN}${BOLD}All permissions are already correct. Nothing to fix.${NC}"
    echo ""
    exit 0
fi

# --- Show what's wrong ---
echo -e "${BOLD}Current state:${NC}"
for profile_dir in "$NDM_PROFILE" "$NODE_PROFILE"; do
    label=$(basename "$profile_dir")

    owner_bad=$(find "$profile_dir" -maxdepth 3 \( ! -user "$WAS_USER" -o ! -group "$WAS_GROUP" \) 2>/dev/null | head -500 | wc -l)
    dir_bad=$(find "$profile_dir" -maxdepth 3 -type d ! -perm -u+rwx 2>/dev/null | head -500 | wc -l)
    file_bad=$(find "$profile_dir" -maxdepth 3 -type f ! -perm -u+rw 2>/dev/null | head -500 | wc -l)

    echo -e "  ${BOLD}$label${NC}"
    if (( owner_bad > 0 )); then
        echo -e "    ${RED}$owner_bad items with wrong ownership${NC}"
    else
        echo -e "    ${GREEN}Ownership OK${NC}"
    fi
    if (( dir_bad > 0 )); then
        echo -e "    ${RED}$dir_bad directories missing owner rwx${NC}"
    else
        echo -e "    ${GREEN}Directory permissions OK${NC}"
    fi
    if (( file_bad > 0 )); then
        echo -e "    ${RED}$file_bad files missing owner rw${NC}"
    else
        echo -e "    ${GREEN}File permissions OK${NC}"
    fi
done
echo ""

echo "This will fix ownership and permission bits on both profile directories:"
echo "  - chown -R ${EXPECTED}"
echo "  - Directories: ensure owner rwx (u+rwx)"
echo "  - Files:       ensure owner rw  (u+rw)"
read -p "Continue? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
for profile_dir in "$NDM_PROFILE" "$NODE_PROFILE"; do
    label=$(basename "$profile_dir")
    echo -ne "  Fixing ${BOLD}$label${NC} ownership..."
    sudo chown -R "${EXPECTED}" "$profile_dir"
    echo -e " ${GREEN}done${NC}"

    echo -ne "  Fixing ${BOLD}$label${NC} directory permissions..."
    sudo find "$profile_dir" -type d ! -perm -u+rwx -exec chmod u+rwx {} +
    echo -e " ${GREEN}done${NC}"

    echo -ne "  Fixing ${BOLD}$label${NC} file permissions..."
    sudo find "$profile_dir" -type f ! -perm -u+rw -exec chmod u+rw {} +
    echo -e " ${GREEN}done${NC}"
done

# --- Verify ---
echo ""
echo -e "${BOLD}Verification:${NC}"
all_good=true
for profile_dir in "$NDM_PROFILE" "$NODE_PROFILE"; do
    label=$(basename "$profile_dir")
    owner_bad=$(find "$profile_dir" -maxdepth 3 \( ! -user "$WAS_USER" -o ! -group "$WAS_GROUP" \) 2>/dev/null | head -1 | wc -l)
    dir_bad=$(find "$profile_dir" -maxdepth 3 -type d ! -perm -u+rwx 2>/dev/null | head -1 | wc -l)
    file_bad=$(find "$profile_dir" -maxdepth 3 -type f ! -perm -u+rw 2>/dev/null | head -1 | wc -l)
    total_bad=$(( owner_bad + dir_bad + file_bad ))

    if (( total_bad == 0 )); then
        echo -e "  $label  ${GREEN}OK${NC}"
    else
        echo -e "  $label  ${RED}STILL HAS ISSUES${NC}"
        all_good=false
    fi
done

echo ""
if $all_good; then
    echo -e "${GREEN}${BOLD}All permissions fixed.${NC}"
else
    echo -e "${RED}${BOLD}Some issues remain — check manually.${NC}"
fi
echo ""
