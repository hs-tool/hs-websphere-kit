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
    bad_count=$(find "$profile_dir" -maxdepth 3 \( ! -user "$WAS_USER" -o ! -group "$WAS_GROUP" \) 2>/dev/null | head -1 | wc -l)
    if (( bad_count > 0 )); then
        needs_fix=1
        break
    fi
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
    current_owner=$(stat -c '%U:%G' "$profile_dir" 2>/dev/null || echo "unknown")
    bad_count=$(find "$profile_dir" -maxdepth 3 \( ! -user "$WAS_USER" -o ! -group "$WAS_GROUP" \) 2>/dev/null | head -500 | wc -l)

    if (( bad_count > 0 )); then
        echo -e "  $label  ${RED}$bad_count items with wrong ownership${NC}"
    else
        echo -e "  $label  ${GREEN}OK${NC}"
    fi
done
echo ""

echo "This will recursively chown both profile directories to ${EXPECTED}."
read -p "Continue? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
for profile_dir in "$NDM_PROFILE" "$NODE_PROFILE"; do
    label=$(basename "$profile_dir")
    echo -ne "  Fixing ${BOLD}$label${NC}..."
    sudo chown -R "${EXPECTED}" "$profile_dir"
    echo -e " ${GREEN}done${NC}"
done

# --- Verify ---
echo ""
echo -e "${BOLD}Verification:${NC}"
all_good=true
for profile_dir in "$NDM_PROFILE" "$NODE_PROFILE"; do
    label=$(basename "$profile_dir")
    bad_count=$(find "$profile_dir" -maxdepth 3 \( ! -user "$WAS_USER" -o ! -group "$WAS_GROUP" \) 2>/dev/null | head -1 | wc -l)
    if (( bad_count == 0 )); then
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
