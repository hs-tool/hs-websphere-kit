#!/bin/bash
source "$(dirname "$0")/../../config.sh"
set -euo pipefail


deleted=0

echo ""
echo -e "${BOLD}${CYAN}=== Remove Temp Files ===${NC}"
echo -e "  Server: ${YELLOW}$SERVER_NAME${NC}"
echo ""

# Helper: remove contents of a directory and report
clean_dir() {
    local dir="$1"
    local label="$2"
    # Safeguard: only allow cleaning inside WAS profiles directory
    if [[ "$dir" != "$WAS_BASE"/* ]]; then
        echo -e "  ${RED}REFUSED${NC}  ${DIM}$label — outside $WAS_BASE${NC}"
        return 1
    fi
    if [[ -d "$dir" ]]; then
        local count
        count=$(find "$dir" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
        if (( count > 0 )); then
            sudo rm -rf "$dir"/*
            echo -e "  ${RED}CLEANED${NC}  ${DIM}$label${NC}  ${DIM}($count items)${NC}"
            ((deleted += count)) || true
        else
            echo -e "  ${DIM}EMPTY    $label${NC}"
        fi
    else
        echo -e "  ${DIM}MISSING  $label (not found)${NC}"
    fi
}

# Helper: remove matching paths by pattern and report
clean_pattern() {
    local base_dir="$1"
    local pattern="$2"
    local label="$3"
    local count=0
    while IFS= read -r -d '' f; do
        echo -e "  ${RED}DELETE${NC}  ${DIM}$label/$(basename "$f")${NC}"
        rm -rf "$f"
        ((count++)) || true
    done < <(find "$base_dir" -maxdepth 1 -name "$pattern" -print0 2>/dev/null)
    if (( count > 0 )); then
        ((deleted += count)) || true
    else
        echo -e "  ${DIM}(none)   $label/$pattern${NC}"
    fi
}

# --- Temp directories ---
echo -e "${BOLD}Cleaning temp directories...${NC}"
clean_dir "$NODE_PROFILE/temp"                "NODE temp (EJB stubs, compiled classes)"
clean_dir "$NODE_PROFILE/wstemp"              "NODE wstemp"
clean_dir "$NODE_PROFILE/config/temp"         "NODE config/temp"
clean_dir "$NDM_PROFILE/temp"                 "NDM temp"
clean_dir "$NDM_PROFILE/wstemp"               "NDM wstemp"
clean_dir "$NDM_PROFILE/config/temp"          "NDM config/temp"

# --- Stale application configs (exact names only) ---
# NOTE: Only remove apps confirmed as broken/orphaned.
# ESI/ESP prefixes are NOT safe — live apps run on ESI_APPSRV_01.
echo ""
echo -e "${BOLD}Removing stale application configs...${NC}"
apps_dir="$NDM_PROFILE/config/cells/$CELL_NAME/applications"
cus_dir="$NDM_PROFILE/config/cells/$CELL_NAME/cus"
blas_dir="$NDM_PROFILE/config/cells/$CELL_NAME/blas"

for stale_app in "ESI-GiftRegistryService-Simulator*"; do
    clean_pattern "$apps_dir" "$stale_app" "applications"
    clean_pattern "$cus_dir"  "$stale_app" "cus"
    clean_pattern "$blas_dir" "$stale_app" "blas"
done

# --- Disk space after cleanup ---
echo ""
echo -e "${BOLD}Disk usage:${NC}"
df -h "$WAS_BASE" 2>/dev/null || df -h /

# --- Summary ---
echo ""
echo -e "${BOLD}----------------------------------------${NC}"
echo -e "${GREEN}${BOLD}Temp cleanup complete: $deleted items removed.${NC}"
echo ""
